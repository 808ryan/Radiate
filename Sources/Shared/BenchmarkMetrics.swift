import Foundation

struct BenchmarkMetrics: Sendable {
    var startedAt = Date()
    var capturedFrames = 0
    var validFrames = 0
    var uniqueFrames = 0
    var perfectFrames = 0
    var duplicateFrames = 0
    var testedBits: UInt64 = 0
    var incorrectBits: UInt64 = 0
    var lastSequence: UInt32?

    var elapsedSeconds: Double {
        Date().timeIntervalSince(startedAt)
    }

    var bitErrorRate: Double {
        testedBits == 0 ? 0 : Double(incorrectBits) / Double(testedBits)
    }

    var uniqueFramesPerSecond: Double {
        elapsedSeconds > 0 ? Double(uniqueFrames) / elapsedSeconds : 0
    }

    func rawBytesPerSecond(for profile: BenchmarkProfile) -> Double {
        uniqueFramesPerSecond * Double(profile.payloadByteCount)
    }

    func verifiedBytesPerSecond(for profile: BenchmarkProfile) -> Double {
        elapsedSeconds > 0
            ? Double(perfectFrames * profile.payloadByteCount) / elapsedSeconds
            : 0
    }

    mutating func reset() {
        self = BenchmarkMetrics()
    }
}
