import AVFoundation
import Combine
import CoreMedia
import UIKit

final class CameraPipeline: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published private(set) var isRunning = false
    @Published private(set) var isCalibrated = false
    @Published private(set) var isDetectingScreen = false
    @Published private(set) var status = "Starting camera…"
    @Published private(set) var captureFormat = "Selecting high-speed format"
    @Published private(set) var metrics = BenchmarkMetrics()
    @Published private(set) var previewDevice: AVCaptureDevice?

    private let sessionQueue = DispatchQueue(label: "com.radiate.camera.session")
    private let processingQueue = DispatchQueue(
        label: "com.radiate.camera.processing",
        qos: .userInteractive
    )
    private let decoder = OpticalDecoder()
    private var workingMetrics = BenchmarkMetrics()
    private var lastPublishTime: TimeInterval = 0
    private var cameraDevice: AVCaptureDevice?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var hasReceivedFrames = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.configureAndStart()
                } else {
                    self?.publishStatus("Camera access was denied")
                }
            }
        case .denied, .restricted:
            publishStatus("Enable camera access in Settings")
        @unknown default:
            publishStatus("Camera authorization is unavailable")
        }
    }

    func setProfile(_ profile: BenchmarkProfile) {
        processingQueue.async { [weak self] in
            self?.decoder.setProfile(profile)
            self?.workingMetrics.reset()
            self?.hasReceivedFrames = false
            self?.publishMetrics(force: true)
            DispatchQueue.main.async {
                self?.isCalibrated = false
                self?.isDetectingScreen = false
                self?.status = "Aim at the complete white target"
            }
        }
    }

    func requestScreenDetection() {
        processingQueue.async { [weak self] in
            self?.decoder.requestScreenDetection()
            self?.hasReceivedFrames = false
            DispatchQueue.main.async {
                self?.isCalibrated = false
                self?.isDetectingScreen = true
                self?.status = "Detecting — hold the full target steady"
            }
        }
    }

    func setCaptureRotationAngle(_ angle: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let connection = self?.videoOutput?.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle),
                  connection.videoRotationAngle != angle
            else { return }
            connection.videoRotationAngle = angle
        }
    }

    func resetMetrics() {
        processingQueue.async { [weak self] in
            self?.workingMetrics.reset()
            self?.decoder.resetSequenceTracking()
            self?.hasReceivedFrames = false
            self?.publishMetrics(force: true)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        workingMetrics.capturedFrames += 1

        switch decoder.decode(pixelBuffer) {
        case .waitingForCalibration:
            break
        case .detectingScreen:
            break
        case .calibrationFailed:
            DispatchQueue.main.async { [weak self] in
                self?.isCalibrated = false
                self?.isDetectingScreen = false
                self?.status = "Screen not found — keep the full white target visible"
            }
        case .calibrated:
            lockCameraForBenchmark()
            DispatchQueue.main.async { [weak self] in
                self?.isCalibrated = true
                self?.isDetectingScreen = false
                self?.status = "Calibrated — waiting for valid frames"
            }
        case .invalidHeader:
            break
        case .duplicate(let header):
            workingMetrics.validFrames += 1
            workingMetrics.duplicateFrames += 1
            workingMetrics.lastSequence = header.sequence
        case .decoded(let header, let testedBits, let incorrectBits):
            if !hasReceivedFrames {
                workingMetrics.reset()
                hasReceivedFrames = true
                DispatchQueue.main.async { [weak self] in
                    self?.status = "Receiving \(header.profile.name) frames"
                }
            }
            workingMetrics.validFrames += 1
            workingMetrics.uniqueFrames += 1
            if incorrectBits == 0 {
                workingMetrics.perfectFrames += 1
            }
            workingMetrics.testedBits += testedBits
            workingMetrics.incorrectBits += incorrectBits
            workingMetrics.lastSequence = header.sequence
        }

        publishMetrics(force: false)
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            do {
                let formatSummary = try self.configureSession()
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.captureFormat = formatSummary
                    self.previewDevice = self.cameraDevice
                    self.status = "Aim at the complete white target"
                }
            } catch {
                self.publishStatus("Camera setup failed: \(error.localizedDescription)")
            }
        }
    }

    private func configureSession() throws -> String {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .inputPriority

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { throw CameraError.noCamera }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        let selected = try selectFormat(for: device)
        try device.lockForConfiguration()
        device.activeFormat = selected.format
        let frameRate: Double
        let duration: CMTime
        if selected.frameRateRange.minFrameRate <= 120,
           selected.frameRateRange.maxFrameRate >= 120 {
            frameRate = 120
            duration = CMTime(value: 1, timescale: 120)
        } else {
            frameRate = selected.frameRateRange.maxFrameRate
            duration = selected.frameRateRange.minFrameDuration
        }
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.unlockForConfiguration()
        cameraDevice = device

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)
        videoOutput = output

        return "\(selected.width) × \(selected.height) at \(Int(frameRate)) fps"
    }

    private func selectFormat(for device: AVCaptureDevice) throws -> FormatChoice {
        let choices: [FormatChoice] = device.formats.compactMap { format in
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dimensions.width >= 1_920, dimensions.height >= 1_080 else { return nil }
            guard let range = format.videoSupportedFrameRateRanges.max(by: {
                $0.maxFrameRate < $1.maxFrameRate
            }), range.maxFrameRate >= 60 else { return nil }
            return FormatChoice(
                format: format,
                width: dimensions.width,
                height: dimensions.height,
                frameRateRange: range
            )
        }

        guard let best = choices.max(by: { $0.score < $1.score }) else {
            throw CameraError.noHighSpeedFormat
        }
        return best
    }

    private func lockCameraForBenchmark() {
        guard let cameraDevice else { return }
        do {
            try cameraDevice.lockForConfiguration()
            if cameraDevice.isFocusModeSupported(.locked) {
                cameraDevice.focusMode = .locked
            }
            if cameraDevice.isExposureModeSupported(.locked) {
                cameraDevice.exposureMode = .locked
            }
            if cameraDevice.isWhiteBalanceModeSupported(.locked) {
                cameraDevice.whiteBalanceMode = .locked
            }
            cameraDevice.unlockForConfiguration()
        } catch {
            publishStatus("Calibrated; camera lock was unavailable")
        }
    }

    private func publishMetrics(force: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || now - lastPublishTime >= 0.25 else { return }
        lastPublishTime = now
        let snapshot = workingMetrics
        DispatchQueue.main.async { [weak self] in
            self?.metrics = snapshot
        }
    }

    private func publishStatus(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.status = message
        }
    }
}

private struct FormatChoice {
    let format: AVCaptureDevice.Format
    let width: Int32
    let height: Int32
    let frameRateRange: AVFrameRateRange

    var score: Double {
        let maximumFrameRate = frameRateRange.maxFrameRate
        let reaches120FPS = maximumFrameRate >= 119 ? 1_000_000_000_000.0 : 0
        let frameRateScore = min(maximumFrameRate, 120) * 1_000_000
        let pixelScore = Double(width) * Double(height)
        return reaches120FPS + frameRateScore + pixelScore
    }
}

private enum CameraError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput
    case noHighSpeedFormat

    var errorDescription: String? {
        switch self {
        case .noCamera: "No rear camera is available."
        case .cannotAddInput: "The camera input could not be attached."
        case .cannotAddOutput: "The video output could not be attached."
        case .noHighSpeedFormat: "No 1080p 60 fps or faster camera format is available."
        }
    }
}
