import MetalKit
import SwiftUI

struct MetalGridView: NSViewRepresentable {
    let profile: BenchmarkProfile
    let isRunning: Bool
    let preferredFramesPerSecond: Int
    let displayFramesPerSymbol: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return MTKView()
        }

        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = preferredFramesPerSecond

        if let renderer = OpticalRenderer(device: device) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
            renderer.update(
                profile: profile,
                isRunning: isRunning,
                displayFramesPerSymbol: displayFramesPerSymbol
            )
        }

        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        view.preferredFramesPerSecond = preferredFramesPerSecond
        context.coordinator.renderer?.update(
            profile: profile,
            isRunning: isRunning,
            displayFramesPerSymbol: displayFramesPerSymbol
        )
    }

    final class Coordinator {
        var renderer: OpticalRenderer?
    }
}
