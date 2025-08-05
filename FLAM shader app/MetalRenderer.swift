//
//  MetalRenderer.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//


import Metal
import MetalKit
import AVFoundation

class MetalRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    // Compute pipelines
    private var grayscalePipeline: MTLComputePipelineState!
    private var gaussianBlurPipeline: MTLComputePipelineState!
    private var edgeDetectionPipeline: MTLComputePipelineState!
    
    // Render pipelines
    private var warpRenderPipeline: MTLRenderPipelineState!
    private var waveRenderPipeline: MTLRenderPipelineState!
    private var sineRenderPipeline: MTLRenderPipelineState!
    private var chromaticAberrationPipeline: MTLRenderPipelineState!
    private var toneMappingPipeline: MTLRenderPipelineState!
    private var filmGrainPipeline: MTLRenderPipelineState!
    private var vignettePipeline: MTLRenderPipelineState!
    
    private var quadVertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    private let processingQueue = DispatchQueue(label: "MetalRenderQueue", qos: .userInitiated)
    
    var settings = ShaderSettings()
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        setupPipelines()
        setupBuffers()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else { return }
        
        // Compute pipelines
        if let function = library.makeFunction(name: "grayscaleTexture") {
            grayscalePipeline = try? device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "gaussianBlurTexture") {
            gaussianBlurPipeline = try? device.makeComputePipelineState(function: function)
        }
        if let function = library.makeFunction(name: "edgeDetectionTexture") {
            edgeDetectionPipeline = try? device.makeComputePipelineState(function: function)
        }
        
        // Render pipelines
        setupRenderPipelines(library: library)
    }
    
    private func setupRenderPipelines(library: MTLLibrary) {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Vertex shader pipelines
        if let vertexFunc = library.makeFunction(name: "warpVertexShader"),
           let fragmentFunc = library.makeFunction(name: "chromaticAberrationFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            warpRenderPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        if let vertexFunc = library.makeFunction(name: "waveVertexShader"),
           let fragmentFunc = library.makeFunction(name: "chromaticAberrationFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            waveRenderPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        if let vertexFunc = library.makeFunction(name: "sineVertexShader"),
           let fragmentFunc = library.makeFunction(name: "chromaticAberrationFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            sineRenderPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        // Fragment shader pipelines
        if let vertexFunc = library.makeFunction(name: "vertexShader"),
           let fragmentFunc = library.makeFunction(name: "chromaticAberrationFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            chromaticAberrationPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        if let vertexFunc = library.makeFunction(name: "vertexShader"),
           let fragmentFunc = library.makeFunction(name: "toneMappingFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            toneMappingPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        if let vertexFunc = library.makeFunction(name: "vertexShader"),
           let fragmentFunc = library.makeFunction(name: "filmGrainFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            filmGrainPipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        if let vertexFunc = library.makeFunction(name: "vertexShader"),
           let fragmentFunc = library.makeFunction(name: "vignetteFragment") {
            descriptor.vertexFunction = vertexFunc
            descriptor.fragmentFunction = fragmentFunc
            vignettePipeline = try? device.makeRenderPipelineState(descriptor: descriptor)
        }
    }
    
    private func setupBuffers() {
        // Quad vertices for rendering
        let vertices: [Float] = [
            -1.0, -1.0, 0.0, 1.0,  0.0, 1.0,
             1.0, -1.0, 0.0, 1.0,  1.0, 1.0,
            -1.0,  1.0, 0.0, 1.0,  0.0, 0.0,
             1.0,  1.0, 0.0, 1.0,  1.0, 0.0
        ]
        
        quadVertexBuffer = device.makeBuffer(bytes: vertices,
                                           length: vertices.count * MemoryLayout<Float>.size,
                                           options: [])
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
    }
    
    struct Uniforms {
        var time: Float
        var resolution: SIMD2<Float>
        var warpStrength: Float
    }
    
    func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        guard let cache = textureCache else { return nil }

        var cvTextureOut: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            0, &cvTextureOut)

        guard result == kCVReturnSuccess,
              let metalTexture = cvTextureOut else { return nil }

        return CVMetalTextureGetTexture(metalTexture)
    }
    
    func processTextureAsync(input: MTLTexture, completion: @escaping (MTLTexture?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            var currentTexture = input
            
            // Apply compute shader
            if self.settings.computeShader != .none {
                if let processed = self.applyComputeShader(input: currentTexture) {
                    currentTexture = processed
                }
            }
            
            // Apply vertex and fragment shaders
            if self.settings.vertexShader != .none || self.settings.fragmentShader != .none {
                if let processed = self.applyRenderShaders(input: currentTexture) {
                    currentTexture = processed
                }
            }
            
            completion(currentTexture)
        }
    }
    
    private func applyComputeShader(input: MTLTexture) -> MTLTexture? {
        let pipeline: MTLComputePipelineState?
        
        switch settings.computeShader {
        case .grayscale:
            pipeline = grayscalePipeline
        case .gaussianBlur:
            pipeline = gaussianBlurPipeline
        case .edgeDetection:
            pipeline = edgeDetectionPipeline
        case .none:
            return input
        }
        
        guard let computePipeline = pipeline else { return input }
        
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: input.width,
            height: input.height,
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        guard let output = device.makeTexture(descriptor: desc) else { return nil }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let w = computePipeline.threadExecutionWidth
        let h = computePipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
        let threadsPerGrid = MTLSize(width: input.width, height: input.height, depth: 1)

        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return output
    }
    
    private func applyRenderShaders(input: MTLTexture) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: input.width,
            height: input.height,
            mipmapped: false)
        desc.usage = [.shaderRead, .renderTarget]
        guard let output = device.makeTexture(descriptor: desc) else { return nil }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }
        
        // Update uniforms
        var uniforms = Uniforms(
            time: settings.time,
            resolution: SIMD2<Float>(Float(input.width), Float(input.height)),
            warpStrength: 0.3
        )
        
        let uniformsPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformsPointer.pointee = uniforms
        
        // Choose pipeline based on settings
        let pipeline = getRenderPipeline()
        guard let renderPipeline = pipeline else {
            renderEncoder.endEncoding()
            return input
        }
        
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(input, index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return output
    }
    
    private func getRenderPipeline() -> MTLRenderPipelineState? {
        // Prioritize vertex shaders, then fragment shaders
        if settings.vertexShader != .none {
            switch settings.vertexShader {
            case .warpEffect:
                return warpRenderPipeline
            case .waveDistortion:
                return waveRenderPipeline
            case .sineDisplacement:
                return sineRenderPipeline
            case .none:
                break
            }
        }
        
        if settings.fragmentShader != .none {
            switch settings.fragmentShader {
            case .chromaticAberration:
                return chromaticAberrationPipeline
            case .toneMapping:
                return toneMappingPipeline
            case .filmGrain:
                return filmGrainPipeline
            case .vignette:
                return vignettePipeline
            case .none:
                break
            }
        }
        
        return nil
    }
    
    func updateTime() {
        settings.time += 0.016 // ~60fps
    }
    
    var metalDevice: MTLDevice { device }
}