//
//  Renderer.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//

import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var latestTexture: MTLTexture?
    private let textureQueue = DispatchQueue(label: "TextureQueue", qos: .userInitiated)
    private let drawQueue = DispatchQueue(label: "DrawQueue", qos: .userInitiated)
    private var isDrawing = false

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        super.init()
    }

    func updateTexture(_ texture: MTLTexture) {
        textureQueue.async { [weak self] in
            self?.latestTexture = texture
        }
    }

    func draw(in view: MTKView) {
        // Use serial queue to prevent concurrent drawing issues
        drawQueue.async { [weak self] in
            self?.performDraw(in: view)
        }
    }
    
    private func performDraw(in view: MTKView) {
        // Prevent concurrent drawing
        guard !isDrawing else { return }
        isDrawing = true
        
        defer { isDrawing = false }
        
        var currentTexture: MTLTexture?
        
        // Use async read to avoid blocking
        textureQueue.sync {
            currentTexture = self.latestTexture
        }
        
        guard let drawable = view.currentDrawable,
              let texture = currentTexture else { return }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

        let copyWidth = min(texture.width, drawable.texture.width)
        let copyHeight = min(texture.height, drawable.texture.height)

        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: copyWidth, height: copyHeight, depth: 1),
                         to: drawable.texture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

        blitEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
        // REMOVED: commandBuffer.waitUntilCompleted() - not needed here
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
}