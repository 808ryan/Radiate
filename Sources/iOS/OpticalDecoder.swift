import CoreImage
import CoreVideo
import Vision

enum OpticalDecodeResult {
    case waitingForCalibration
    case detectingScreen
    case calibrationFailed
    case calibrated
    case invalidHeader
    case duplicate(FrameHeader)
    case decoded(FrameHeader, testedBits: UInt64, incorrectBits: UInt64)
}

final class OpticalDecoder {
    private var profile: BenchmarkProfile = .balanced
    private var sampleMap: SampleMap?
    private var screenDetectionDeadline: TimeInterval?
    private var lastSequence: UInt32?

    var isCalibrated: Bool { sampleMap != nil }

    func setProfile(_ profile: BenchmarkProfile) {
        guard self.profile != profile else { return }
        self.profile = profile
        sampleMap = nil
        screenDetectionDeadline = nil
        lastSequence = nil
    }

    func requestScreenDetection() {
        screenDetectionDeadline = ProcessInfo.processInfo.systemUptime + 2.0
        sampleMap = nil
        lastSequence = nil
    }

    func resetSequenceTracking() {
        lastSequence = nil
    }

    func decode(_ pixelBuffer: CVPixelBuffer) -> OpticalDecodeResult {
        if let deadline = screenDetectionDeadline {
            if let quadrilateral = detectScreen(in: pixelBuffer),
               let map = SampleMap(
                    profile: profile,
                    quadrilateral: quadrilateral,
                    pixelWidth: CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                    pixelHeight: CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
               ) {
                screenDetectionDeadline = nil
                sampleMap = map
                return .calibrated
            }

            if ProcessInfo.processInfo.systemUptime >= deadline {
                screenDetectionDeadline = nil
                return .calibrationFailed
            }
            return .detectingScreen
        }

        guard let sampleMap else { return .waitingForCalibration }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            return .invalidHeader
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let luma = baseAddress.assumingMemoryBound(to: UInt8.self)
        let threshold = sampleMap.estimateThreshold(luma: luma, bytesPerRow: bytesPerRow)
        let headerBits = sampleMap.readHeader(
            luma: luma,
            bytesPerRow: bytesPerRow,
            threshold: threshold
        )

        guard let header = FrameHeader(bits: headerBits), header.profile == profile else {
            return .invalidHeader
        }

        guard header.sequence != lastSequence else {
            return .duplicate(header)
        }
        lastSequence = header.sequence

        let errors = sampleMap.countPayloadErrors(
            sequence: header.sequence,
            luma: luma,
            bytesPerRow: bytesPerRow,
            threshold: threshold
        )
        return .decoded(
            header,
            testedBits: UInt64(sampleMap.payloadPoints.count),
            incorrectBits: UInt64(errors)
        )
    }

    private func detectScreen(in pixelBuffer: CVPixelBuffer) -> ScreenQuadrilateral? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.35
        request.maximumAspectRatio = 1.0
        request.minimumSize = 0.35
        request.quadratureTolerance = 35

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let rectangle = request.results?.first else { return nil }
        let width = CGFloat(CVPixelBufferGetWidthOfPlane(pixelBuffer, 0))
        let height = CGFloat(CVPixelBufferGetHeightOfPlane(pixelBuffer, 0))

        func imagePoint(_ normalized: CGPoint) -> CGPoint {
            CGPoint(x: normalized.x * width, y: (1 - normalized.y) * height)
        }

        return ScreenQuadrilateral(
            topLeft: imagePoint(rectangle.topLeft),
            topRight: imagePoint(rectangle.topRight),
            bottomRight: imagePoint(rectangle.bottomRight),
            bottomLeft: imagePoint(rectangle.bottomLeft)
        )
    }
}

private struct PixelPoint {
    let x: Int
    let y: Int
}

private struct SampleMap {
    let headerPoints: [[PixelPoint]]
    let payloadPoints: [PixelPoint]
    let thresholdPoints: [PixelPoint]

    init?(
        profile: BenchmarkProfile,
        quadrilateral: ScreenQuadrilateral,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        guard let homography = Homography(quadrilateral: quadrilateral) else { return nil }

        // Vision generally returns the outer edge of the white border. The data
        // begins slightly inside it; this margin avoids sampling the border.
        let dataInset = 0.013

        func point(column: Int, row: Int) -> PixelPoint {
            let localU = (Double(column) + 0.5) / Double(profile.columns)
            let localV = (Double(row) + 0.5) / Double(profile.rows)
            let u = dataInset + localU * (1 - 2 * dataInset)
            let v = dataInset + localV * (1 - 2 * dataInset)
            let mapped = homography.map(u: u, v: v)
            return PixelPoint(
                x: min(max(Int(mapped.x.rounded()), 0), pixelWidth - 1),
                y: min(max(Int(mapped.y.rounded()), 0), pixelHeight - 1)
            )
        }

        var header = Array(repeating: [PixelPoint](), count: FrameHeader.bitCount)
        for bit in 0..<FrameHeader.bitCount {
            for row in 0..<BenchmarkProfile.headerRowCount {
                for copy in 0..<BenchmarkProfile.headerRepeatCount {
                    let column = bit * BenchmarkProfile.headerRepeatCount + copy
                    header[bit].append(point(column: column, row: row))
                }
            }
        }

        var payload: [PixelPoint] = []
        payload.reserveCapacity(profile.payloadCellCount)
        for row in BenchmarkProfile.headerRowCount..<profile.rows {
            for column in 0..<profile.columns {
                payload.append(point(column: column, row: row))
            }
        }

        let stride = max(1, payload.count / 4_096)
        var threshold: [PixelPoint] = []
        threshold.reserveCapacity(min(4_096, payload.count))
        for index in Swift.stride(from: 0, to: payload.count, by: stride) {
            threshold.append(payload[index])
        }

        headerPoints = header
        payloadPoints = payload
        thresholdPoints = threshold
    }

    func estimateThreshold(luma: UnsafePointer<UInt8>, bytesPerRow: Int) -> UInt8 {
        guard !thresholdPoints.isEmpty else { return 128 }
        var total: UInt64 = 0
        for point in thresholdPoints {
            total += UInt64(luma[point.y * bytesPerRow + point.x])
        }
        let mean = UInt8(clamping: Int(total / UInt64(thresholdPoints.count)))
        return min(max(mean, 72), 184)
    }

    func readHeader(
        luma: UnsafePointer<UInt8>,
        bytesPerRow: Int,
        threshold: UInt8
    ) -> [Bool] {
        headerPoints.map { copies in
            let white = copies.reduce(into: 0) { count, point in
                if luma[point.y * bytesPerRow + point.x] >= threshold {
                    count += 1
                }
            }
            return white * 2 >= copies.count
        }
    }

    func countPayloadErrors(
        sequence: UInt32,
        luma: UnsafePointer<UInt8>,
        bytesPerRow: Int,
        threshold: UInt8
    ) -> Int {
        var errors = 0
        for (index, point) in payloadPoints.enumerated() {
            let observed = luma[point.y * bytesPerRow + point.x] >= threshold
            let expected = PRBS.bit(sequence: sequence, cellIndex: UInt32(index))
            if observed != expected { errors += 1 }
        }
        return errors
    }
}
