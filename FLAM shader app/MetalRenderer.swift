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

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "grayscaleTexture") else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = try? device.makeComputePipelineState(function: function)
    }

    func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        var texture: MTLTexture?
        var cvTextureOut: CVMetalTexture?
        var textureCache: CVMetalTextureCache?
        
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        guard let cache = textureCache else { return nil }

        CVMetalTextureCacheCreateTextureFromImage(nil, cache, pixelBuffer, nil, .bgra8Unorm, textureDescriptor.width, textureDescriptor.height, 0, &cvTextureOut)

        if let metalTexture = cvTextureOut {
            texture = CVMetalTextureGetTexture(metalTexture)
        }

        return texture
    }

    func applyGrayscale(input: MTLTexture) -> MTLTexture? {
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

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(input, index: 0)
        encoder.setTexture(output, index: 1)

        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
        let threadsPerGrid = MTLSize(width: input.width, height: input.height, depth: 1)

        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return output
    }

    var metalDevice: MTLDevice { device }
}
