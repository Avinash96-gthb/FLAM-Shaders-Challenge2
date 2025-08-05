//
//  Shaders.metal
//  FLAM shader app
//
//  Created by A Avinash Chidambaram on 05/08/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void grayscaleTexture(
    texture2d<float, access::read>  inTexture  [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height())
        return;

    float4 color = inTexture.read(gid);
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    outTexture.write(float4(gray, gray, gray, 1.0), gid);
}
