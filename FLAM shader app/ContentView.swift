//
//  ContentView.swift
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//

import SwiftUI

struct ContentView: View {
    @State private var shaderSettings = ShaderSettings()
    @State private var showComputeOptions = false
    @State private var showVertexOptions = false
    @State private var showFragmentOptions = false
    
    var body: some View {
        ZStack {
            CameraView(shaderSettings: $shaderSettings)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Main control buttons
                HStack(spacing: 50) {
                    ShaderTypeButton(
                        icon: "cpu",
                        title: "Compute",
                        isActive: shaderSettings.computeShader != .none,
                        action: { showComputeOptions.toggle() }
                    )
                    
                    ShaderTypeButton(
                        icon: "triangle",
                        title: "Vertex",
                        isActive: shaderSettings.vertexShader != .none,
                        action: { showVertexOptions.toggle() }
                    )
                    
                    ShaderTypeButton(
                        icon: "paintbrush",
                        title: "Fragment",
                        isActive: shaderSettings.fragmentShader != .none,
                        action: { showFragmentOptions.toggle() }
                    )
                }
                .padding(.bottom, 50)
                
                // Compute shader options
                if showComputeOptions {
                    EffectOptionsView(
                        title: "Compute Effects",
                        options: ComputeShaderType.allCases.map { $0.displayName },
                        selectedIndex: ComputeShaderType.allCases.firstIndex(of: shaderSettings.computeShader) ?? 0,
                        onSelection: { index in
                            shaderSettings.computeShader = ComputeShaderType.allCases[index]
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Vertex shader options
                if showVertexOptions {
                    EffectOptionsView(
                        title: "Vertex Effects",
                        options: VertexShaderType.allCases.map { $0.displayName },
                        selectedIndex: VertexShaderType.allCases.firstIndex(of: shaderSettings.vertexShader) ?? 0,
                        onSelection: { index in
                            shaderSettings.vertexShader = VertexShaderType.allCases[index]
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                
                // Fragment shader options
                if showFragmentOptions {
                    EffectOptionsView(
                        title: "Fragment Effects",
                        options: FragmentShaderType.allCases.map { $0.displayName },
                        selectedIndex: FragmentShaderType.allCases.firstIndex(of: shaderSettings.fragmentShader) ?? 0,
                        onSelection: { index in
                            shaderSettings.fragmentShader = FragmentShaderType.allCases[index]
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .onTapGesture {
            withAnimation {
                showComputeOptions = false
                showVertexOptions = false
                showFragmentOptions = false
            }
        }
    }
}

struct ShaderTypeButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isActive ? .blue : .white)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isActive ? .blue : .white)
            }
            .padding()
            .background(
                Circle()
                    .fill(isActive ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                    .frame(width: 70, height: 70)
            )
        }
    }
}

struct EffectOptionsView: View {
    let title: String
    let options: [String]
    let selectedIndex: Int
    let onSelection: (Int) -> Void
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 10)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<options.count, id: \.self) { index in
                        Button(options[index]) {
                            onSelection(index)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(index == selectedIndex ? Color.blue : Color.black.opacity(0.5))
                        )
                        .foregroundColor(.white)
                        .font(.caption)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
        )
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}