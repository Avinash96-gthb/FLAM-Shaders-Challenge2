//
//  CameraView.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//


import SwiftUI
import MetalKit

struct CameraView: UIViewRepresentable {
    let videoCapture = VideoCapture()
    let mtkView = MTKView()

    func makeUIView(context: Context) -> MTKView {
        mtkView.device = videoCapture.metalDevice
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = true // We manually draw

        videoCapture.onFrameAvailable = { texture in
            DispatchQueue.main.async {
                self.mtkView.drawableSize = CGSize(width: texture.width, height: texture.height)
                if let drawable = self.mtkView.currentDrawable {
                    let commandBuffer = self.videoCapture.metalDevice.makeCommandQueue()?.makeCommandBuffer()
                    let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
                    blitEncoder?.copy(from: texture,
                                      sourceSlice: 0,
                                      sourceLevel: 0,
                                      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                                      sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                                      to: drawable.texture,
                                      destinationSlice: 0,
                                      destinationLevel: 0,
                                      destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                    blitEncoder?.endEncoding()
                    commandBuffer?.present(drawable)
                    commandBuffer?.commit()
                }
            }
        }

        videoCapture.startCapture()
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
