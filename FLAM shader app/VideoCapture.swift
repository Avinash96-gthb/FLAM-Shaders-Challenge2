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
    private let sessionQueue = DispatchQueue(label: "CaptureSession", qos: .userInitiated)
    private var displayLink: CADisplayLink?
    
    func setRenderer(_ renderer: Renderer) {
        self.drawRenderer = renderer
    }
    
    func updateShaderSettings(_ settings: ShaderSettings) {
        // Thread-safe settings update
        renderer.settings = settings
    }
    
    func startCapture() {
        sessionQueue.async { [weak self] in
            self?.checkCameraPermission { [weak self] granted in
                guard granted else {
                    print("Camera permission denied")
                    return
                }
                self?.setupCaptureSession()
                
                // Start display link on main thread
                DispatchQueue.main.async {
                    self?.startDisplayLink()
                }
            }
        }
    }
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateTime))
        displayLink?.add(to: .current, forMode: .default)
    }
    
    @objc private func updateTime() {
        // Update time in thread-safe manner
        renderer.updateTime()
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else { 
            print("Failed to setup camera input")
            return 
        }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: metalQueue)
        
        // Ensure we can add output
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Use autoreleasepool to manage memory better
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                  let inputTexture = renderer.makeTexture(from: pixelBuffer) else { return }
            
            // Process asynchronously - completion already handles main queue dispatch
            renderer.processTextureAsync(input: inputTexture) { [weak self] outputTexture in
                guard let outputTexture = outputTexture else { return }
                
                // The completion is already called on main thread from MetalRenderer
                self?.drawRenderer?.updateTexture(outputTexture)
            }
        }
    }

    var metalDevice: MTLDevice {
        renderer.metalDevice
    }
    
    deinit {
        displayLink?.invalidate()
        captureSession.stopRunning()
    }
}