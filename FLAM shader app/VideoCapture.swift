//
//  VideoCapture.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//


import AVFoundation
import MetalKit

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let renderer = MetalRenderer()!
    private var drawRenderer: Renderer?

    func setRenderer(_ renderer: Renderer) {
        self.drawRenderer = renderer
    }

    func startCapture() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { return }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoQueue"))
        captureSession.addOutput(output)
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let inputTexture = renderer.makeTexture(from: pixelBuffer),
              let outputTexture = renderer.applyGrayscale(input: inputTexture) else { return }

        drawRenderer?.updateTexture(outputTexture)
    }

    var metalDevice: MTLDevice {
        renderer.metalDevice
    }
}

