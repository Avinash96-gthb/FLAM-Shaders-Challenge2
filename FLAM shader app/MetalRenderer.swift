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
    private var pipelineState: MTLComputePipelineState!
    private let processingQueue = DispatchQueue(label: "MetalRenderQueue", qos: .userInitiated)

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "grayscaleTexture") else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        
        do {
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create pipeline state: \(error)")
            return nil
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

    func applyGrayscaleAsync(input: MTLTexture, completion: @escaping (MTLTexture?) -> Void) {
        processingQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // Process completely asynchronously
            self.processGrayscaleAsync(input: input, completion: completion)
        }
    }
    
    private func processGrayscaleAsync(input: MTLTexture, completion: @escaping (MTLTexture?) -> Void) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: input.width,
            height: input.height,
            mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        guard let output = device.makeTexture(descriptor: desc) else { 
            completion(nil)
            return 
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            completion(nil)
            return
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
        let threadsPerGrid = MTLSize(width: input.width, height: input.height, depth: 1)

        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        // Use completion handler to wait for GPU completion
        commandBuffer.addCompletedHandler { _ in
            completion(output)
        }
        
        commandBuffer.commit()
    }

    // Remove the problematic sync version completely
    var metalDevice: MTLDevice { device }
}