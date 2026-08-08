import SwiftUI

struct ReceiverView: View {
    @StateObject private var camera = CameraPipeline()
    @State private var profile: BenchmarkProfile = .balanced

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            LinearGradient(
                colors: [.black.opacity(0.72), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 14) {
                topBar
                Spacer()
                metricsPanel
            }
            .padding(18)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear {
            camera.start()
            camera.setProfile(profile)
        }
        .onChange(of: profile) { _, value in
            camera.setProfile(value)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: camera.isCalibrated ? "viewfinder.circle.fill" : "viewfinder.circle")
                .font(.title2)
                .foregroundStyle(camera.isCalibrated ? .green : .white)

            VStack(alignment: .leading, spacing: 2) {
                Text(camera.status)
                    .font(.headline)
                Text(camera.captureFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            Picker("Profile", selection: $profile) {
                ForEach(BenchmarkProfile.allCases) { item in
                    Text(item.name).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 390)

            Button {
                camera.requestScreenDetection()
            } label: {
                Label("Detect Screen", systemImage: "viewfinder")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metricsPanel: some View {
        HStack(spacing: 22) {
            metric("Valid fps", camera.metrics.uniqueFramesPerSecond, suffix: "")
            metric("BER", camera.metrics.bitErrorRate * 100, suffix: "%", precision: 4)
            metric("Raw", camera.metrics.rawBytesPerSecond(for: profile) / 1_000_000, suffix: " MB/s")
            metric("Verified", camera.metrics.verifiedBytesPerSecond(for: profile) / 1_000_000, suffix: " MB/s")

            Divider()
                .frame(height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(camera.metrics.uniqueFrames) unique · \(camera.metrics.duplicateFrames) duplicate")
                    .font(.caption)
                    .monospacedDigit()
                Text("\(camera.metrics.incorrectBits) / \(camera.metrics.testedBits) bits wrong")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button {
                camera.resetMetrics()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Reset metrics")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metric(
        _ title: String,
        _ value: Double,
        suffix: String,
        precision: Int = 2
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value, format: .number.precision(.fractionLength(precision)))\(suffix)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }
}
