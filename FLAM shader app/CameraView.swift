//
//  CameraView.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//

import SwiftUI
import MetalKit

struct CameraView: UIViewRepresentable {
    @Binding var shaderSettings: ShaderSettings
    private let videoCapture = VideoCapture()
    private let mtkView = MTKView()
    private let renderer: Renderer

    init(shaderSettings: Binding<ShaderSettings>) {
        self._shaderSettings = shaderSettings
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.renderer = Renderer(device: device)
        self.mtkView.device = device
        self.videoCapture.setRenderer(self.renderer)
    }

    func makeUIView(context: Context) -> MTKView {
        mtkView.framebufferOnly = false
        mtkView.delegate = renderer
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 30

        // Start capture after a slight delay to ensure everything is initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.videoCapture.startCapture()
        }

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update settings in thread-safe manner
        videoCapture.updateShaderSettings(shaderSettings)
    }
}