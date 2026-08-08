import SwiftUI

@MainActor
final class SenderModel: ObservableObject {
    @Published var profile: BenchmarkProfile = .balanced
    @Published var isRunning = false
    @Published var targetDisplayRate = 120
    @Published var displayFramesPerSymbol = 2

    var targetSymbolRate: Double {
        Double(targetDisplayRate) / Double(displayFramesPerSymbol)
    }

    var estimatedRawBytesPerSecond: Double {
        profile.rawBytesPerSecond(symbolRate: targetSymbolRate)
    }

    func start() { isRunning = true }
    func stop() { isRunning = false }
}
