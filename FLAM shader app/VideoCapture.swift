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
    private weak var drawRenderer: Renderer?
    private let metalQueue = DispatchQueue(label: "MetalProcessing", qos: .userInitiated)
    private var displayLink: CADisplayLink?
    
    func setRenderer(_ renderer: Renderer) {
        self.drawRenderer = renderer
    }
    
    func updateShaderSettings(_ settings: ShaderSettings) {
        renderer.settings = settings
    }
    
    func startCapture() {
        checkCameraPermission { [weak self] granted in
            guard granted else {
                print("Camera permission denied")
                return
            }
            self?.setupCaptureSession()
            self?.startDisplayLink()
        }
    }
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateTime))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc private func updateTime() {
        renderer.updateTime()
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    private func setupCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.captureSession.canAddInput(input) else { 
                print("Failed to setup camera input")
                return 
            }

            self.captureSession.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: self.metalQueue)
            
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
            }
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                  let inputTexture = renderer.makeTexture(from: pixelBuffer) else { return }
            
            renderer.processTextureAsync(input: inputTexture) { [weak self] outputTexture in
                guard let outputTexture = outputTexture else { return }
                
                DispatchQueue.main.async {
                    self?.drawRenderer?.updateTexture(outputTexture)
                }
            }
        }
    }

    var metalDevice: MTLDevice {
        renderer.metalDevice
    }
}