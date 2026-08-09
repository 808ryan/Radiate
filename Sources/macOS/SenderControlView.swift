import SwiftUI

struct SenderControlView: View {
    @EnvironmentObject private var sender: SenderModel
    @Environment(\.openWindow) private var openWindow

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter
    }()

    var body: some View {
        Form {
            Section {
                Picker("Grid profile", selection: $sender.profile) {
                    ForEach(BenchmarkProfile.allCases) { profile in
                        Text("\(profile.name) — \(profile.dimensions)")
                            .tag(profile)
                    }
                }

                LabeledContent("Logical symbol rate") {
                    Text("\(sender.targetSymbolRate, format: .number.precision(.fractionLength(0))) fps")
                        .monospacedDigit()
                }

                LabeledContent("Payload per frame") {
                    Text(byteFormatter.string(fromByteCount: Int64(sender.profile.payloadByteCount)))
                        .monospacedDigit()
                }

                LabeledContent("Theoretical raw rate") {
                    Text("\(byteFormatter.string(fromByteCount: Int64(sender.estimatedRawBytesPerSecond)))/s")
                        .monospacedDigit()
                }
            } header: {
                Text("Signal")
            } footer: {
                Text("Each logical symbol is held for two 120 Hz display frames. The receiver measures the actual unique-frame rate and bit errors.")
            }

            Section("Transmitter") {
                HStack {
                    Button {
                        openWindow(id: "transmitter")
                    } label: {
                        Label("Open Transmitter", systemImage: "rectangle.on.rectangle")
                    }

                    Spacer()

                    Button(sender.isRunning ? "Stop Benchmark" : "Start Benchmark") {
                        sender.toggleRunning()
                    }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                }

                Text(sender.isRunning ? "Sending deterministic test frames" : "Showing the white calibration target")
                    .foregroundStyle(sender.isRunning ? .green : .secondary)
            }

            Section("Before you start") {
                Text("Make the transmitter window full screen, set the iPhone to the same profile, and keep the complete white calibration target inside the camera view. Disable Night Shift and automatic brightness for repeatable results.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(minWidth: 480, minHeight: 420)
    }
}
