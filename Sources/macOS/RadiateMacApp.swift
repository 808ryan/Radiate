import SwiftUI

@main
struct RadiateMacApp: App {
    @StateObject private var sender = SenderModel()

    var body: some Scene {
        WindowGroup("Radiate Benchmark", id: "control") {
            SenderControlView()
                .environmentObject(sender)
        }
        .defaultSize(width: 520, height: 470)
        .windowResizability(.contentMinSize)

        Window("Optical Transmitter", id: "transmitter") {
            TransmitterView()
                .environmentObject(sender)
        }
        .defaultSize(width: 1_200, height: 800)
        .windowResizability(.contentMinSize)
    }
}
