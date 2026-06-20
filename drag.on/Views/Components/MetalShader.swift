import MetalKit
import simd
import SwiftUI

// MARK: - Shader Uniforms

/// Matches the Metal `ShaderUniforms` struct layout exactly.
/// Alignment: time (4) + 3×padding (12) = 16 bytes, then two float4 (16 each) = 48 bytes total.
struct ShaderUniforms {
    var time: Float
    var padding1: Float = 0
    var padding2: Float = 0
    var padding3: Float = 0
    var color1: simd_float4
    var color2: simd_float4
}

// MARK: - Metal Resource Cache (Singleton)

/// Caches the Metal device, command queue, and compute pipeline so they are
/// created exactly once and shared across all shader instances.
/// This eliminates the repeated `MTLCreateSystemDefaultDevice()` and
/// `makeDefaultLibrary()` calls that caused slow window loads.
final class MetalShaderCache: @unchecked Sendable {
    static let shared = MetalShaderCache()

    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let pipelineState: MTLComputePipelineState?

    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            self.device = nil
            self.commandQueue = nil
            self.pipelineState = nil
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        // Build the compute pipeline once
        var pipeline: MTLComputePipelineState?
        if let library = device.makeDefaultLibrary(),
           let kernel = library.makeFunction(name: "compute") {
            pipeline = try? device.makeComputePipelineState(function: kernel)
        }
        self.pipelineState = pipeline

        if pipeline == nil {
            print("[MetalShader] Failed to create compute pipeline")
        }
    }

    /// Whether Metal rendering is available.
    var isAvailable: Bool {
        device != nil && commandQueue != nil && pipelineState != nil
    }
}

// MARK: - AccentMetalShaderView (NSViewRepresentable)

/// An `NSViewRepresentable` that renders the accent-themed flowing Metal shader via `MTKView`.
struct AccentMetalShaderView: NSViewRepresentable {
    /// The main accent color for the shader foreground.
    var color1: simd_float4
    /// The secondary accent color for the shader background.
    var color2: simd_float4

    func makeCoordinator() -> Coordinator {
        Coordinator(color1: color1, color2: color2)
    }

    func makeNSView(context: Context) -> MTKView {
        let cache = MetalShaderCache.shared
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.device = cache.device
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.layer?.isOpaque = false

        return mtkView
    }

    func updateNSView(_ mtkView: MTKView, context: Context) {
        // Push updated colors to the coordinator whenever SwiftUI re-renders
        context.coordinator.color1 = color1
        context.coordinator.color2 = color2
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        let timeStep = Float(1.0 / 30.0)
        var time = Float(0)

        var color1: simd_float4
        var color2: simd_float4

        // References from the shared cache — no per-instance allocation
        let device: MTLDevice?
        let commandQueue: MTLCommandQueue?
        let pipelineState: MTLComputePipelineState?
        let uniformBuffer: MTLBuffer?

        init(color1: simd_float4, color2: simd_float4) {
            self.color1 = color1
            self.color2 = color2

            let cache = MetalShaderCache.shared
            self.device = cache.device
            self.commandQueue = cache.commandQueue
            self.pipelineState = cache.pipelineState
            self.uniformBuffer = cache.device?.makeBuffer(
                length: MemoryLayout<ShaderUniforms>.size,
                options: []
            )

            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pipelineState,
                  let commandQueue,
                  let uniformBuffer,
                  let drawable = view.currentDrawable else { return }

            time += timeStep

            // Write uniforms
            var uniforms = ShaderUniforms(
                time: time,
                color1: color1,
                color2: color2
            )
            memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<ShaderUniforms>.size)

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }

            commandEncoder.setComputePipelineState(pipelineState)
            commandEncoder.setTexture(drawable.texture, index: 0)
            commandEncoder.setBuffer(uniformBuffer, offset: 0, index: 0)

            let width = pipelineState.threadExecutionWidth
            let height = pipelineState.maxTotalThreadsPerThreadgroup / width
            let threadGroupCount = MTLSize(width: width, height: height, depth: 1)
            let threadGroups = MTLSize(
                width: (drawable.texture.width + width - 1) / width,
                height: (drawable.texture.height + height - 1) / height,
                depth: 1
            )

            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
