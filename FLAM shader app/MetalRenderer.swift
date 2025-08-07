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
    private let settingsQueue = DispatchQueue(label: "SettingsQueue", attributes: .concurrent)
    private var _settings = ShaderSettings()
    
    var settings: ShaderSettings {
        get {
            return settingsQueue.sync { _settings }
        }
        set {
            settingsQueue.async(flags: .barrier) { [weak self] in
                self?._settings = newValue
            }
        }
    }
    
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
        
        // Setup vertex layout - FIXED: Match the actual vertex data structure
        let vertexDescriptor = MTLVertexDescriptor()
        // Position attribute (4 floats = 16 bytes)
        vertexDescriptor.attributes[0].format = .float4
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // Texture coordinate attribute (2 floats = 8 bytes)
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 0
        // Total stride = 24 bytes (16 + 8)
        vertexDescriptor.layouts[0].stride = 24
        descriptor.vertexDescriptor = vertexDescriptor
        
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
        // FIXED: Quad vertices with correct 24-byte stride (4 floats + 2 floats per vertex)
        let vertices: [Float] = [
            // Position (x, y, z, w)     // TexCoord (u, v)
            -1.0, -1.0, 0.0, 1.0,       0.0, 1.0,    // Bottom-left
             1.0, -1.0, 0.0, 1.0,       1.0, 1.0,    // Bottom-right  
            -1.0,  1.0, 0.0, 1.0,       0.0, 0.0,    // Top-left
             1.0,  1.0, 0.0, 1.0,       1.0, 0.0     // Top-right
        ]
        
        // FIXED: Create vertex buffer with exact size needed (4 vertices × 6 floats × 4 bytes = 96 bytes)
        let vertexBufferSize = vertices.count * MemoryLayout<Float>.size
        quadVertexBuffer = device.makeBuffer(bytes: vertices, length: vertexBufferSize, options: [])
        
        // FIXED: Create uniform buffer with exact Uniforms struct size (12 bytes aligned to 16)
        let uniformSize = MemoryLayout<Uniforms>.stride
        uniformBuffer = device.makeBuffer(length: uniformSize, options: [])
    }
    
    struct Uniforms {
        var time: Float        // 4 bytes
        var resolution: SIMD2<Float>  // 8 bytes
        var warpStrength: Float       // 4 bytes
        // Total: 16 bytes (automatically padded by Metal)
        
        init(time: Float = 0.0, resolution: SIMD2<Float> = SIMD2<Float>(1.0, 1.0), warpStrength: Float = 0.3) {
            self.time = time
            self.resolution = resolution
            self.warpStrength = warpStrength
        }
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
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let currentSettings = self.settings
            let result = self.processTexture(input: input, settings: currentSettings)
            
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    private func processTexture(input: MTLTexture, settings: ShaderSettings) -> MTLTexture? {
        var currentTexture = input
        
        // Apply compute shader first
        if settings.computeShader != .none {
            if let processed = applyComputeShader(input: currentTexture, shaderType: settings.computeShader) {
                currentTexture = processed
            }
        }
        
        // Apply vertex and fragment shaders
        if settings.vertexShader != .none || settings.fragmentShader != .none {
            if let processed = applyRenderShaders(input: currentTexture, settings: settings) {
                currentTexture = processed
            }
        }
        
        return currentTexture
    }
    
    private func applyComputeShader(input: MTLTexture, shaderType: ComputeShaderType) -> MTLTexture? {
        let pipeline: MTLComputePipelineState?
        
        switch shaderType {
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
        
        // Use async completion instead of waitUntilCompleted
        commandBuffer.addCompletedHandler { _ in
            // Command completed on GPU
        }
        commandBuffer.commit()
        
        return output
    }
    
    private func applyRenderShaders(input: MTLTexture, settings: ShaderSettings) -> MTLTexture? {
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
        
        // Update uniforms properly with correct size
        var uniforms = Uniforms(
            time: settings.time,
            resolution: SIMD2<Float>(Float(input.width), Float(input.height)),
            warpStrength: 0.3
        )
        
        let uniformsPointer = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniformsPointer.pointee = uniforms
        
        let pipeline = getRenderPipeline(settings: settings)
        guard let renderPipeline = pipeline else {
            renderEncoder.endEncoding()
            return input
        }
        
        renderEncoder.setRenderPipelineState(renderPipeline)
        
        // FIXED: Correct buffer binding with proper sizes
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)      // Vertex data (96 bytes)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)         // Uniforms for vertex stage (16 bytes)
        renderEncoder.setFragmentTexture(input, index: 0)                         // Input texture
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)       // Uniforms for fragment stage (16 bytes)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Use async completion instead of waitUntilCompleted
        commandBuffer.addCompletedHandler { _ in
            // Command completed on GPU
        }
        commandBuffer.commit()
        
        return output
    }
    
    private func getRenderPipeline(settings: ShaderSettings) -> MTLRenderPipelineState? {
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
        settingsQueue.async(flags: .barrier) { [weak self] in
            self?._settings.time += 0.016 // ~60fps
        }
    }
    
    var metalDevice: MTLDevice { device }
}