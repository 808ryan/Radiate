import MetalKit
import SwiftUI

struct MetalGridView: NSViewRepresentable {
    let profile: BenchmarkProfile
    let isRunning: Bool
    let runGeneration: UInt64
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
                runGeneration: runGeneration,
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
            runGeneration: runGeneration,
            displayFramesPerSymbol: displayFramesPerSymbol
        )

        // A full-screen transmitter can be occluded while the control window is
        // active in another Space. Restart its display link and force one draw
        // so start/stop changes cannot leave the previous frame on screen.
        view.isPaused = true
        view.draw()
        view.isPaused = false
    }

    final class Coordinator {
        var renderer: OpticalRenderer?
    }
}
