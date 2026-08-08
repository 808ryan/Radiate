import AppKit
import SwiftUI

struct TransmitterView: View {
    @EnvironmentObject private var sender: SenderModel

    var body: some View {
        MetalGridView(
            profile: sender.profile,
            isRunning: sender.isRunning,
            preferredFramesPerSecond: sender.targetDisplayRate,
            displayFramesPerSymbol: sender.displayFramesPerSymbol
        )
        .background(.black)
        .ignoresSafeArea()
        .toolbar {
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
