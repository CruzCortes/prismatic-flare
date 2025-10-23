//
//  AnamorphicFlareView.swift
//  Nebula
//
//  Metal rendering view for the anamorphic lens flare effect
//  Bridges SwiftUI with Metal for GPU-accelerated rendering
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI
import MetalKit
import simd

// MARK: - SwiftUI View
struct AnamorphicFlareView: NSViewRepresentable {
    @ObservedObject var config: AnamorphicFlareConfig
    @Binding var windowCenter: CGPoint

    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.delegate = context.coordinator
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
        metalView.preferredFramesPerSecond = 60
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.layer?.isOpaque = false
        metalView.layer?.backgroundColor = NSColor.clear.cgColor
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        context.coordinator.setupMetal(metalView: metalView)

        return metalView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.config = config
        context.coordinator.windowCenter = windowCenter
        nsView.isPaused = !config.isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(config: config, windowCenter: windowCenter)
    }

    // MARK: - Metal Coordinator
    class Coordinator: NSObject, MTKViewDelegate {
        var config: AnamorphicFlareConfig
        var windowCenter: CGPoint

        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var uniformBuffer: MTLBuffer?
        private var startTime: CFTimeInterval = 0

        private var blurPipelineState: MTLComputePipelineState?
        private var horizontalBlurKernel: MTLComputePipelineState?
        private var verticalBlurKernel: MTLComputePipelineState?
        private var intermediateTexture: MTLTexture?

        init(config: AnamorphicFlareConfig, windowCenter: CGPoint) {
            self.config = config
            self.windowCenter = windowCenter
            super.init()
            self.startTime = CACurrentMediaTime()
        }

        func setupMetal(metalView: MTKView) {
            guard let device = metalView.device else { return }
            self.device = device
            self.commandQueue = device.makeCommandQueue()

            setupVertexBuffer()
            setupUniformBuffer()
            setupPipeline()
            setupBlurKernels()
        }

        private func setupVertexBuffer() {
            guard let device = device else { return }

            let vertices: [Float] = [
                // Position (x,y,z,w)    TexCoord (u,v)
                -1.0, -1.0, 0.0, 1.0,    0.0, 1.0,
                 1.0, -1.0, 0.0, 1.0,    1.0, 1.0,
                -1.0,  1.0, 0.0, 1.0,    0.0, 0.0,
                 1.0,  1.0, 0.0, 1.0,    1.0, 0.0
            ]

            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.size,
                options: []
            )
        }

        private func setupUniformBuffer() {
            guard let device = device else { return }

            // Allocate uniform buffer
            let uniformSize = MemoryLayout<AnamorphicFlareUniforms>.size
            uniformBuffer = device.makeBuffer(
                length: uniformSize,
                options: [.storageModeShared]
            )
        }

        private func setupPipeline() {
            guard let device = device else { return }

            // Load shader library
            guard let library = device.makeDefaultLibrary() else {
                return
            }

            // Get shader functions
            let vertexFunction = library.makeFunction(name: "anamorphicFlareVertex")
            let fragmentFunction = library.makeFunction(name: "anamorphicFlareFragment")

            // Create pipeline descriptor
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Configure blending for transparency
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

            // Setup vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()

            // Position attribute
            vertexDescriptor.attributes[0].format = .float4
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0

            // TexCoord attribute
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 4
            vertexDescriptor.attributes[1].bufferIndex = 0

            // Layout
            vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 6
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex

            pipelineDescriptor.vertexDescriptor = vertexDescriptor

            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }

        private func setupBlurKernels() {
            guard let device = device else { return }
            guard let library = device.makeDefaultLibrary() else { return }

            do {
                if let horizontalFunction = library.makeFunction(name: "horizontalBlurKernel") {
                    horizontalBlurKernel = try device.makeComputePipelineState(function: horizontalFunction)
                }

                if let verticalFunction = library.makeFunction(name: "verticalBlurKernel") {
                    verticalBlurKernel = try device.makeComputePipelineState(function: verticalFunction)
                }
            } catch {
                print("Failed to create blur kernels: \(error)")
            }
        }

        private func updateUniforms(size: CGSize) {
            guard let uniformBuffer = uniformBuffer else { return }

            var uniforms = AnamorphicFlareUniforms()

            uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))

            let scale = NSScreen.main?.backingScaleFactor ?? 2.0

            uniforms.lightPosition = SIMD2<Float>(
                Float(windowCenter.x * scale),
                Float(size.height - (windowCenter.y * scale))
            )

            if Int.random(in: 0...60) == 0 {
                print("Shader uniforms - resolution: \(size), window center: \(windowCenter), flipped Y: \(size.height - windowCenter.y)")
            }
            uniforms.time = Float(CACurrentMediaTime() - startTime)

            uniforms.intensity = config.intensity
            uniforms.streakLength = config.streakLength
            uniforms.streakWidth = config.streakWidth
            uniforms.falloffPower = config.falloffPower
            uniforms.chromaticAberration = config.chromaticAberration
            uniforms.rayCount = config.rayCount
            uniforms.threshold = config.threshold

            let tintComponents = NSColor(config.tintColor).cgColor.components ?? [1.0, 1.0, 1.0, 1.0]
            uniforms.tintColor = SIMD4<Float>(
                Float(tintComponents[0]),
                Float(tintComponents[1]),
                Float(tintComponents[2]),
                Float(tintComponents[3])
            )

            uniforms.dispersion = config.dispersion
            uniforms.noiseAmount = config.noiseAmount
            uniforms.rotationAngle = config.rotationAngle
            uniforms.glowRadius = config.glowRadius
            uniforms.edgeFade = config.edgeFade

            uniforms.direction = SIMD2<Float>(1.0, 0.0)

            uniforms.colorCount = Int32(min(config.flareColors.count, 6))
            for i in 0..<min(config.flareColors.count, 6) {
                let colorComponents = NSColor(config.flareColors[i]).cgColor.components ?? [1.0, 1.0, 1.0, 1.0]
                let color = SIMD4<Float>(
                    Float(colorComponents[0]),
                    Float(colorComponents[1]),
                    Float(colorComponents[2]),
                    1.0
                )

                switch i {
                case 0: uniforms.flareColors.0 = color
                case 1: uniforms.flareColors.1 = color
                case 2: uniforms.flareColors.2 = color
                case 3: uniforms.flareColors.3 = color
                case 4: uniforms.flareColors.4 = color
                case 5: uniforms.flareColors.5 = color
                default: break
                }
            }

            uniformBuffer.contents().copyMemory(
                from: &uniforms,
                byteCount: MemoryLayout<AnamorphicFlareUniforms>.size
            )
        }

        // MARK: - MTKViewDelegate
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle size changes if needed
        }

        func draw(in view: MTKView) {
            guard config.isEnabled else {
                print("DEBUG: Flare disabled")
                return
            }
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else {
                print("DEBUG: No command buffer")
                return
            }
            guard let drawable = view.currentDrawable else {
                print("DEBUG: No drawable")
                return
            }
            guard let pipelineState = pipelineState else {
                print("DEBUG: No pipeline state")
                return
            }

            updateUniforms(size: view.drawableSize)

            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            renderPassDescriptor.colorAttachments[0].storeAction = .store

            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
                renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                renderEncoder.endEncoding()
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Uniform Structure
private struct AnamorphicFlareUniforms {
    var resolution: SIMD2<Float> = .zero                            // 8 bytes
    var lightPosition: SIMD2<Float> = .zero                         // 8 bytes
    var time: Float = 0                                             // 4 bytes
    var intensity: Float = 1.0                                      // 4 bytes
    var streakLength: Float = 2.0                                   // 4 bytes
    var streakWidth: Float = 0.3                                    // 4 bytes
    var falloffPower: Float = 2.0                                   // 4 bytes
    var chromaticAberration: Float = 1.0                            // 4 bytes
    var rayCount: Int32 = 12                                        // 4 bytes
    var threshold: Float = 0.1                                      // 4 bytes
    var tintColor: SIMD4<Float> = SIMD4<Float>(1.0, 0.95, 0.9, 1.0) // 16 bytes
    var dispersion: Float = 0.3                                     // 4 bytes
    var noiseAmount: Float = 0.2                                    // 4 bytes
    var rotationAngle: Float = 0.0                                  // 4 bytes
    var glowRadius: Float = 0.5                                     // 4 bytes
    var flareColors: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) = (
        SIMD4<Float>(1.0, 0.4, 0.1, 1.0),                           // Warm orange - 16 bytes
        SIMD4<Float>(0.2, 0.5, 1.0, 1.0),                           // Cool blue - 16 bytes
        SIMD4<Float>(1.0, 0.2, 0.6, 1.0),                           // Magenta - 16 bytes
        SIMD4<Float>(0.3, 1.0, 0.7, 1.0),                           // Cyan - 16 bytes
        SIMD4<Float>(1.0, 0.8, 0.3, 1.0),                           // Yellow - 16 bytes
        SIMD4<Float>(0.6, 0.3, 1.0, 1.0)                            // Purple - 16 bytes
    )                                                               // Total: 96 bytes
    
    var colorCount: Int32 = 6                                       // 4 bytes
    var direction: SIMD2<Float> = SIMD2<Float>(1.0, 0.0)            // 8 bytes
    var edgeFade: Float = 1.0                                       // 4 bytes
                                                                    // Total should be = 196 bytes
                                                                    // But Metal expects 208, so we need padding
    var _padding: SIMD4<Float> = .zero                              // 16 bytes padding
}
