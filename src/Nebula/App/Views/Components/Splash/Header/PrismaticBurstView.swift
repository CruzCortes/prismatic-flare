//
//  PrismaticBurstView.swift
//  Nebula
//
//  SwiftUI Metal view wrapper for the prismatic burst effect
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

import SwiftUI
import MetalKit
import AppKit

// MARK: - Animation Type
enum PrismaticAnimationType: Int32 {
    case rotate = 0
    case rotate3d = 1
    case hover = 2
}

// MARK: - Configuration
struct PrismaticBurstConfig {
    var intensity: Float = 2.0
    var speed: Float = 0.5
    var animationType: PrismaticAnimationType = .rotate3d
    var colors: [Color] = []
    var distortion: Float = 0.0
    var isPaused: Bool = false
    var offset: CGPoint = .zero
    var hoverDampness: Float = 0.0
    var rayCount: Int32 = 0
    var noiseAmount: Float = 0.8
}

// MARK: - Custom MTKView for mouse tracking
class TrackingMTKView: MTKView {
    weak var coordinator: PrismaticBurstCoordinator?
    
    override func mouseMoved(with event: NSEvent) {
        coordinator?.handleMouseMoved(event, in: self)
        super.mouseMoved(with: event)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
}

// MARK: - SwiftUI View
struct PrismaticBurstView: NSViewRepresentable {
    @Binding var config: PrismaticBurstConfig

    func makeNSView(context: Context) -> TrackingMTKView {
        let metalView = TrackingMTKView()
        metalView.coordinator = context.coordinator
        metalView.delegate = context.coordinator
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = config.isPaused
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        metalView.layer?.backgroundColor = NSColor.clear.cgColor

        if let device = MTLCreateSystemDefaultDevice() {
            metalView.device = device
            context.coordinator.setupMetal(device: device, metalView: metalView)
        }

        return metalView
    }

    func updateNSView(_ metalView: TrackingMTKView, context: Context) {
        context.coordinator.config = config
        metalView.isPaused = config.isPaused
    }

    func makeCoordinator() -> PrismaticBurstCoordinator {
        PrismaticBurstCoordinator(config: config)
    }
}

// MARK: - Metal Coordinator
class PrismaticBurstCoordinator: NSObject, MTKViewDelegate {
    var config: PrismaticBurstConfig

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var accumulatedTime: Float = 0
    private var lastUpdateTime: CFTimeInterval = CACurrentMediaTime()

    private var mousePosition = SIMD2<Float>(0.5, 0.5)
    private var targetMousePosition = SIMD2<Float>(0.5, 0.5)

    private let vertices: [Float] = [
        -1.0, -1.0, 0.0, 1.0,    0.0, 1.0,
         1.0, -1.0, 0.0, 1.0,    1.0, 1.0,
        -1.0,  1.0, 0.0, 1.0,    0.0, 0.0,
         1.0,  1.0, 0.0, 1.0,    1.0, 0.0
    ]

    init(config: PrismaticBurstConfig) {
        self.config = config
        super.init()
    }

    func setupMetal(device: MTLDevice, metalView: MTKView) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                        length: vertices.count * MemoryLayout<Float>.size,
                                        options: [])

        let uniformsSize = MemoryLayout<HeaderBackgroundUniforms>.stride
        uniformBuffer = device.makeBuffer(length: uniformsSize,
                                         options: [])

        guard let library = device.makeDefaultLibrary() else {
            print("Failed to create goofy ahh Metal library")
            return
        }

        let vertexFunction = library.makeFunction(name: "headerBackgroundVertex")
        let fragmentFunction = library.makeFunction(name: "headerBackgroundFragment")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 4 * MemoryLayout<Float>.size
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 6 * MemoryLayout<Float>.size
        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    @objc func handleMouseMoved(_ event: NSEvent, in view: NSView) {
        guard config.animationType == .hover else { return }
        
        let location = view.convert(event.locationInWindow, from: nil)
        targetMousePosition.x = Float(location.x / view.bounds.width)
        targetMousePosition.y = Float(1.0 - location.y / view.bounds.height)
    }

    func updateUniforms(size: CGSize) {
        guard let uniformBuffer = uniformBuffer else { return }

        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        if !config.isPaused {
            accumulatedTime += deltaTime
        }

        let tau: Float = 0.02 + max(0, min(1, config.hoverDampness)) * 0.5
        let alpha: Float = 1.0 - exp(-deltaTime / tau)
        mousePosition += (targetMousePosition - mousePosition) * alpha

        var uniforms = HeaderBackgroundUniforms()
        uniforms.resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        uniforms.time = accumulatedTime
        uniforms.intensity = config.intensity
        uniforms.speed = config.speed
        uniforms.animationType = config.animationType.rawValue
        uniforms.mousePosition = mousePosition
        uniforms.distortion = config.distortion
        uniforms.offset = SIMD2<Float>(Float(config.offset.x), Float(config.offset.y))
        uniforms.noiseAmount = config.noiseAmount
        uniforms.rayCount = config.rayCount

        uniforms.colorCount = Int32(min(config.colors.count, 8))
        var colorArray: [SIMD4<Float>] = Array(repeating: .zero, count: 8)
        for (index, color) in config.colors.prefix(8).enumerated() {
            let nsColor = NSColor(color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            colorArray[index] = SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
        }
        uniforms.colors = (colorArray[0], colorArray[1], colorArray[2], colorArray[3],
                          colorArray[4], colorArray[5], colorArray[6], colorArray[7])

        let uniformsStride = MemoryLayout<HeaderBackgroundUniforms>.stride
        withUnsafeBytes(of: &uniforms) { bytes in
            uniformBuffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: uniformsStride)
        }
    }

    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle size changes if needed
    }

    func draw(in view: MTKView) {
        guard let commandQueue = commandQueue,
              let pipelineState = pipelineState,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        updateUniforms(size: view.drawableSize)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Uniforms Structure (Must match Metal shader)
struct HeaderBackgroundUniforms {
    var resolution: SIMD2<Float> = SIMD2<Float>(1920, 1080)
    var time: Float = 0
    var intensity: Float = 2.0
    var speed: Float = 0.5
    var animationType: Int32 = 1
    var mousePosition: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
    var distortion: Float = 0
    var offset: SIMD2<Float> = SIMD2<Float>(0, 0)
    var noiseAmount: Float = 0.8
    var rayCount: Int32 = 0
    var colors: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
                  SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) = (
        .zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero
    )
    var colorCount: Int32 = 0
}

// MARK: - Preview
struct PrismaticBurstView_Previews: PreviewProvider {
    static var previews: some View {
        PrismaticBurstView(config: .constant(PrismaticBurstConfig()))
            .frame(width: 800, height: 600)
    }
}
