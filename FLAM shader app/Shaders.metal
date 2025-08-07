//
//  Shaders.metal
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Compute Shaders

kernel void grayscaleTexture(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height())
        return;

    float4 color = inTexture.read(gid);
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    outTexture.write(float4(gray, gray, gray, color.a), gid);
}

kernel void gaussianBlurTexture(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height())
        return;
    
    const int radius = 3;
    const float weights[7] = {0.006, 0.061, 0.242, 0.383, 0.242, 0.061, 0.006};
    
    float4 color = float4(0.0);
    for (int i = -radius; i <= radius; i++) {
        uint2 coord = uint2(clamp(int(gid.x) + i, 0, int(inTexture.get_width()) - 1), gid.y);
        color += inTexture.read(coord) * weights[i + radius];
    }
    
    outTexture.write(color, gid);
}

kernel void edgeDetectionTexture(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height())
        return;
    
    const float sobelX[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
    const float sobelY[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};
    
    float2 grad = 0.0;
    
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            uint2 coord = uint2(clamp(int(gid.x) + j, 0, int(inTexture.get_width()) - 1),
                               clamp(int(gid.y) + i, 0, int(inTexture.get_height()) - 1));
            float4 color = inTexture.read(coord);
            float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
            
            int kernelIndex = (i + 1) * 3 + (j + 1);
            grad.x += gray * sobelX[kernelIndex];
            grad.y += gray * sobelY[kernelIndex];
        }
    }
    
    float magnitude = length(grad);
    outTexture.write(float4(magnitude, magnitude, magnitude, 1.0), gid);
}

// MARK: - Vertex Shaders

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float time;
    float2 resolution;
    float warpStrength;
};

// FIXED: Update buffer index for uniforms
vertex VertexOut warpVertexShader(VertexIn in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float2 center = float2(0.5, 0.5);
    float2 offset = in.texCoord - center;
    float dist = length(offset);
    
    // Magnifying glass effect
    float warpFactor = 1.0 + uniforms.warpStrength * exp(-dist * 8.0);
    float2 warpedTexCoord = center + offset * warpFactor;
    
    out.position = in.position;
    out.texCoord = warpedTexCoord;
    return out;
}

vertex VertexOut waveVertexShader(VertexIn in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float wave = sin(in.texCoord.x * 10.0 + uniforms.time * 2.0) * 0.05;
    float2 waveTexCoord = in.texCoord + float2(0.0, wave);
    
    out.position = in.position;
    out.texCoord = waveTexCoord;
    return out;
}

vertex VertexOut sineVertexShader(VertexIn in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float displacement = sin(in.texCoord.y * 15.0 + uniforms.time * 3.0) * 0.03;
    float2 displacedTexCoord = in.texCoord + float2(displacement, 0.0);
    
    out.position = in.position;
    out.texCoord = displacedTexCoord;
    return out;
}

// MARK: - Fragment Shaders

fragment float4 chromaticAberrationFragment(VertexOut in [[stage_in]],
                                          texture2d<float> texture [[texture(0)]],
                                          constant Uniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float2 center = float2(0.5, 0.5);
    float2 direction = normalize(in.texCoord - center);
    float distance = length(in.texCoord - center);
    
    float aberrationStrength = 0.01 * distance * distance;
    
    float2 redOffset = in.texCoord - direction * aberrationStrength;
    float2 greenOffset = in.texCoord;
    float2 blueOffset = in.texCoord + direction * aberrationStrength;
    
    float red = texture.sample(textureSampler, redOffset).r;
    float green = texture.sample(textureSampler, greenOffset).g;
    float blue = texture.sample(textureSampler, blueOffset).b;
    
    return float4(red, green, blue, 1.0);
}

fragment float4 toneMappingFragment(VertexOut in [[stage_in]],
                                   texture2d<float> texture [[texture(0)]],
                                   constant Uniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    // Reinhard tone mapping
    float3 mapped = color.rgb / (color.rgb + float3(1.0));
    
    // Gamma correction
    mapped = pow(mapped, float3(1.0/2.2));
    
    return float4(mapped, color.a);
}

fragment float4 filmGrainFragment(VertexOut in [[stage_in]],
                                 texture2d<float> texture [[texture(0)]],
                                 constant Uniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    // Pseudo-random noise
    float2 seed = in.texCoord * uniforms.time;
    float noise = fract(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
    noise = (noise - 0.5) * 0.1;
    
    color.rgb += noise;
    return color;
}

fragment float4 vignetteFragment(VertexOut in [[stage_in]],
                                texture2d<float> texture [[texture(0)]],
                                constant Uniforms& uniforms [[buffer(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    float4 color = texture.sample(textureSampler, in.texCoord);
    
    float2 center = float2(0.5, 0.5);
    float distance = length(in.texCoord - center);
    float vignette = 1.0 - smoothstep(0.3, 0.8, distance);
    
    color.rgb *= vignette;
    return color;
}

// Default vertex shader for fragment effects
vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}
