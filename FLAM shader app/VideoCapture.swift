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
    private weak var drawRenderer: Renderer? // Make this weak to prevent retain cycles
    private let metalQueue = DispatchQueue(label: "MetalProcessing", qos: .userInitiated)

    func setRenderer(_ renderer: Renderer) {
        self.drawRenderer = renderer
    }

    func startCapture() {
        // Check camera permission first
        checkCameraPermission { [weak self] granted in
            guard granted else {
                print("Camera permission denied")
                return
            }
            self?.setupCaptureSession()
        }
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
            
            // Process asynchronously with better error handling
            renderer.applyGrayscaleAsync(input: inputTexture) { [weak self] outputTexture in
                guard let outputTexture = outputTexture,
                      let self = self else { return }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.drawRenderer?.updateTexture(outputTexture)
                }
            }
        }
    }

    var metalDevice: MTLDevice {
        renderer.metalDevice
    }
}

