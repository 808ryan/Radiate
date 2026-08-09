import SwiftUI

@MainActor
final class SenderModel: ObservableObject {
    @Published var profile: BenchmarkProfile = .balanced
    @Published private(set) var isRunning = false
    @Published private(set) var runGeneration: UInt64 = 0
    @Published var targetDisplayRate = 120
    @Published var displayFramesPerSymbol = 2

    var targetSymbolRate: Double {
        Double(targetDisplayRate) / Double(displayFramesPerSymbol)
    }

    var estimatedRawBytesPerSecond: Double {
        profile.rawBytesPerSecond(symbolRate: targetSymbolRate)
    }

    func start() {
        guard !isRunning else { return }
        runGeneration &+= 1
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
    }

    func toggleRunning() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
}
