//
//  ComputeShaderType.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//


import Foundation

enum ComputeShaderType: CaseIterable {
    case none
    case grayscale
    case gaussianBlur
    case edgeDetection
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .grayscale: return "Grayscale"
        case .gaussianBlur: return "Blur"
        case .edgeDetection: return "Edge"
        }
    }
}

enum VertexShaderType: CaseIterable {
    case none
    case warpEffect
    case waveDistortion
    case sineDisplacement
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .warpEffect: return "Warp"
        case .waveDistortion: return "Wave"
        case .sineDisplacement: return "Sine"
        }
    }
}

enum FragmentShaderType: CaseIterable {
    case none
    case chromaticAberration
    case toneMapping
    case filmGrain
    case vignette
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .chromaticAberration: return "Chroma"
        case .toneMapping: return "Tone"
        case .filmGrain: return "Grain"
        case .vignette: return "Vignette"
        }
    }
}

struct ShaderSettings {
    var computeShader: ComputeShaderType = .grayscale
    var vertexShader: VertexShaderType = .warpEffect
    var fragmentShader: FragmentShaderType = .chromaticAberration
    var time: Float = 0.0
}