import AppKit
import SwiftUI

struct TransmitterView: View {
    @EnvironmentObject private var sender: SenderModel

    var body: some View {
        MetalGridView(
            profile: sender.profile,
            isRunning: sender.isRunning,
            runGeneration: sender.runGeneration,
            preferredFramesPerSecond: sender.targetDisplayRate,
            displayFramesPerSymbol: sender.displayFramesPerSymbol
        )
        .background(.black)
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sender.toggleRunning()
                } label: {
                    Label(
                        sender.isRunning ? "Stop Benchmark" : "Start Benchmark",
                        systemImage: sender.isRunning ? "stop.fill" : "play.fill"
                    )
                }
                .keyboardShortcut(.space, modifiers: [])
                .help(sender.isRunning ? "Stop benchmark" : "Start benchmark")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                } label: {
                    Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .help("Toggle full screen")
            }
        }
    }
}
