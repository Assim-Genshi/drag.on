#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Uniform structure matching the Swift ShaderUniforms layout
struct ShaderUniforms {
    float time;
    float padding1;
    float padding2;
    float padding3;
    float4 color1;  // main accent color
    float4 color2;  // secondary accent color
};

#define S(a,b,t) smoothstep(a,b,t)
#define sat(x) clamp(x, 0., 1.)

float f(float2 p, float time) {
    return sin(p.x + sin(p.y + (time + 20.) * 0.1)) * sin(p.y * p.x * 0.1 + (time + 20.) * 0.2);
}

float2 field(float2 p, float time) {
    float2 ep = float2(.05, 0.);
    float2 rz = float2(0);
    for (int i = 0; i < 7; i++) {
        float t0 = f(p, time);
        float t1 = f(p + ep.xy, time);
        float t2 = f(p + ep.yx, time);
        float2 g = float2((t1 - t0), (t2 - t0)) / ep.xx;
        float2 t = float2(-g.y, g.x);

        p += .9 * t + g * 0.3;
        rz = t;
    }

    return rz;
}

float4 Main(float2 uv, float time, float2 iResolution, float3 foreground, float3 background) {
    float2 p = uv.xy;
    p *= iResolution.y / 200.0;

    float2 fld = field(p, time);
    float3 pass = sin(float3(mix(foreground, background, (p.x - 5.0) * .5)) + (fld.x - fld.y));
    float3 col = mix(pass, mix(foreground, background, fld.x), 0.8) * 1.5;

    return float4(col, 1.0);
}

kernel void compute(texture2d<float, access::write> output [[texture(0)]],
                    constant ShaderUniforms &uniforms [[buffer(0)]],
                    uint2 gid [[thread_position_in_grid]])
{
    uint width = output.get_width();
    uint height = output.get_height();

    if (gid.x >= width || gid.y >= height) return;

    float2 iResolution = float2(width, height);

    float2 uv = float2(gid.x, height - gid.y) / iResolution;
    uv -= 0.5;
    uv.x *= iResolution.x / iResolution.y;

    float time = uniforms.time;
    float3 foreground = uniforms.color1.rgb;
    float3 background = uniforms.color2.rgb;

    float4 col = Main(uv, time, iResolution, foreground, background);
    output.write(col, gid);
}
