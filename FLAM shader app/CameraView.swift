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
    let renderer: Renderer

    init() {
        let device = MTLCreateSystemDefaultDevice()!
        self.renderer = Renderer(device: device)
        self.mtkView.device = device
        self.videoCapture.setRenderer(renderer)
    }

    func makeUIView(context: Context) -> MTKView {
        mtkView.framebufferOnly = false
        mtkView.delegate = renderer
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        videoCapture.startCapture()

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}
