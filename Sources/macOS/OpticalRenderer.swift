import MetalKit
import os

private struct GridUniforms {
    var viewportSize: SIMD2<Float>
    var columns: UInt32
    var rows: UInt32
    var sequence: UInt32
    var profile: UInt32
    var running: UInt32
    var contentInset: Float
    var borderWidth: Float
}

private struct RenderConfiguration {
    var profile: BenchmarkProfile = .balanced
    var isRunning = false
    var displayFramesPerSymbol = 2
}

final class OpticalRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let lock = OSAllocatedUnfairLock(initialState: RenderConfiguration())
    private var sequence: UInt32 = 0
    private var heldDisplayFrames = 0
    private var wasRunning = false

    init?(device: MTLDevice) {
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "gridVertex"),
              let fragmentFunction = library.makeFunction(name: "gridFragment")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.commandQueue = commandQueue
        self.pipeline = pipeline
        super.init()
    }

    func update(
        profile: BenchmarkProfile,
        isRunning: Bool,
        displayFramesPerSymbol: Int
    ) {
        lock.withLock {
            $0.profile = profile
            $0.isRunning = isRunning
            $0.displayFramesPerSymbol = max(1, displayFramesPerSymbol)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let passDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        let configuration = lock.withLock { $0 }
        if configuration.isRunning && !wasRunning {
            sequence = 0
            heldDisplayFrames = 0
        }
        wasRunning = configuration.isRunning

        var uniforms = GridUniforms(
            viewportSize: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            columns: UInt32(configuration.profile.columns),
            rows: UInt32(configuration.profile.rows),
            sequence: sequence,
            profile: UInt32(configuration.profile.rawValue),
            running: configuration.isRunning ? 1 : 0,
            contentInset: 0.04,
            borderWidth: 0.012
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GridUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        guard configuration.isRunning else { return }
        heldDisplayFrames += 1
        if heldDisplayFrames >= configuration.displayFramesPerSymbol {
            heldDisplayFrames = 0
            sequence &+= 1
        }
    }
}
