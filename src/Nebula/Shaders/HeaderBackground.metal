//
//  HeaderBackground.metal
//  Nebula
//
//  Shader for the animated prismatic burst header background
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct HeaderBackgroundUniforms {
    float2 resolution;
    float time;
    float intensity;
    float speed;
    int animationType;
    float2 mousePosition;
    float distortion;
    float2 offset;
    float noiseAmount;
    int rayCount;
    float4 colors[8];
    int colorCount;
};

namespace ShaderUtils {
    float hash21(float2 p) {
        p = floor(p);
        float f = 52.9829189 * fract(dot(p, float2(0.065, 0.005)));
        return fract(f);
    }

    float2x2 rot30() {
        return float2x2(0.8, -0.5, 0.5, 0.8);
    }

    float layeredNoise(float2 fragPx, float time) {
        float2 p = fmod(fragPx + float2(time * 30.0, -time * 21.0), 1024.0);
        float2 q = rot30() * p;
        float n = 0.0;
        n += 0.40 * hash21(q);
        n += 0.25 * hash21(q * 2.0 + 17.0);
        n += 0.20 * hash21(q * 4.0 + 47.0);
        n += 0.10 * hash21(q * 8.0 + 113.0);
        n += 0.05 * hash21(q * 16.0 + 191.0);
        return n;
    }

    float3x3 rotationX(float angle) {
        float c = cos(angle);
        float s = sin(angle);
        return float3x3(1.0, 0.0, 0.0,
                       0.0, c, -s,
                       0.0, s, c);
    }

    float3x3 rotationY(float angle) {
        float c = cos(angle);
        float s = sin(angle);
        return float3x3(c, 0.0, s,
                       0.0, 1.0, 0.0,
                       -s, 0.0, c);
    }

    float3x3 rotationZ(float angle) {
        float c = cos(angle);
        float s = sin(angle);
        return float3x3(c, -s, 0.0,
                       s, c, 0.0,
                       0.0, 0.0, 1.0);
    }

    float2 rotate2D(float2 v, float angle) {
        float s = sin(angle);
        float c = cos(angle);
        return float2x2(c, -s, s, c) * v;
    }
}

namespace HeaderBackground {
    float3 rayDirection(float2 fragCoord, float2 resolution, float2 offset, float distance) {
        float focal = resolution.y * max(distance, 0.001);
        return normalize(float3(2.0 * (fragCoord - offset) - resolution, focal));
    }

    float edgeFade(float2 fragCoord, float2 resolution, float2 offset, float time) {
        float2 toCenter = fragCoord - 0.5 * resolution - offset;
        float radius = length(toCenter) / (0.5 * min(resolution.x, resolution.y));
        float x = saturate(radius);

        // Smooth step quintic interpolation
        float q = x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
        float s = q * 0.5;
        s = pow(s, 1.5);

        float tail = 1.0 - pow(1.0 - s, 2.0);
        s = mix(s, tail, 0.2);

        float dn = (ShaderUtils::layeredNoise(fragCoord * 0.15, time) - 0.5) * 0.0015 * s;
        return saturate(s + dn);
    }

    float bendAngle(float3 q, float t) {
        float a = 0.8 * sin(q.x * 0.55 + t * 0.6)
                + 0.7 * sin(q.y * 0.50 - t * 0.5)
                + 0.6 * sin(q.z * 0.60 + t * 0.7);
        return a;
    }

    float3 sampleGradient(float t, constant HeaderBackgroundUniforms& uniforms) {
        if (uniforms.colorCount <= 0) {
            // Default spectral colors
            return 1.0 + float3(
                cos(t * 3.0 + 0.0),
                cos(t * 3.0 + 1.0),
                cos(t * 3.0 + 2.0)
            );
        }

        // Sample from user-defined gradient
        t = saturate(t);
        float scaledT = t * float(uniforms.colorCount - 1);
        int idx1 = int(floor(scaledT));
        int idx2 = min(idx1 + 1, uniforms.colorCount - 1);
        float fract = scaledT - float(idx1);

        float3 color1 = uniforms.colors[idx1].rgb;
        float3 color2 = uniforms.colors[idx2].rgb;

        return mix(color1, color2, fract) * 2.0;
    }
}

// Vertex shader for header background
vertex VertexOut headerBackgroundVertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Fragment shader for header background
fragment float4 headerBackgroundFragment(VertexOut in [[stage_in]],
                                        constant HeaderBackgroundUniforms& uniforms [[buffer(0)]]) {
    float2 fragCoord = in.position.xy;
    float t = uniforms.time * uniforms.speed;
    float jitterAmp = 0.1 * saturate(uniforms.noiseAmount);

    // Calculate ray direction
    float3 dir = HeaderBackground::rayDirection(fragCoord, uniforms.resolution, uniforms.offset, 1.0);

    // Ray marching variables
    float marchT = 0.0;
    float3 color = float3(0.0);

    float noise = ShaderUtils::layeredNoise(fragCoord, uniforms.time);

    // 2D rotation matrix for basic rotation
    float4 c = cos(t * 0.2 + float4(0.0, 33.0, 11.0, 0.0));
    float2x2 rotMatrix2D = float2x2(c.x, c.y, c.z, c.w);

    float amplitude = saturate(uniforms.distortion * 0.15);

    // Setup rotation matrices based on animation type
    float3x3 rot3dMatrix = float3x3(1.0);
    if (uniforms.animationType == 1) {
        float3 angles = float3(t * 0.31, t * 0.21, t * 0.17);
        rot3dMatrix = ShaderUtils::rotationZ(angles.z) *
                     ShaderUtils::rotationY(angles.y) *
                     ShaderUtils::rotationX(angles.x);
    }

    float3x3 hoverMatrix = float3x3(1.0);
    if (uniforms.animationType == 2) {
        float2 mouse = uniforms.mousePosition * 2.0 - 1.0;
        float3 angles = float3(mouse.y * 0.6, mouse.x * 0.6, 0.0);
        hoverMatrix = ShaderUtils::rotationY(angles.y) * ShaderUtils::rotationX(angles.x);
    }

    // Ray marching loop
    for (int i = 0; i < 44; ++i) {
        float3 P = marchT * dir;
        P.z -= 2.0;

        float radius = length(P);
        float3 Pl = P * (10.0 / max(radius, 0.000001));

        // Apply rotation based on animation type
        if (uniforms.animationType == 0) {
            Pl.xz = rotMatrix2D * Pl.xz;
        } else if (uniforms.animationType == 1) {
            Pl = rot3dMatrix * Pl;
        } else {
            Pl = hoverMatrix * Pl;
        }

        // Calculate step length
        float stepLen = min(radius - 0.3, noise * jitterAmp) + 0.1;

        // Apply distortion
        float grow = smoothstep(0.35, 3.0, marchT);
        float a1 = amplitude * grow * HeaderBackground::bendAngle(Pl * 0.6, t);
        float a2 = 0.5 * amplitude * grow * HeaderBackground::bendAngle(Pl.zyx * 0.5 + 3.1, t * 0.9);

        float3 Pb = Pl;
        Pb.xz = ShaderUtils::rotate2D(Pb.xz, a1);
        Pb.xy = ShaderUtils::rotate2D(Pb.xy, a2);

        float rayPattern = smoothstep(
            0.5, 0.7,
            sin(Pb.x + cos(Pb.y) * cos(Pb.z)) *
            sin(Pb.z + sin(Pb.y) * cos(Pb.x + t))
        );

        if (uniforms.rayCount > 0) {
            float angle = atan2(Pb.y, Pb.x);
            float comb = 0.5 + 0.5 * cos(float(uniforms.rayCount) * angle);
            comb = pow(comb, 3.0);
            rayPattern *= smoothstep(0.15, 0.95, comb);
        }

        // Sample color from gradient
        float saw = fract(marchT * 0.25);
        float tRay = saw * saw * (3.0 - 2.0 * saw);
        float3 spectral = HeaderBackground::sampleGradient(tRay, uniforms);

        float3 base = (0.05 / (0.4 + stepLen))
                    * smoothstep(5.0, 0.0, radius)
                    * spectral;

        color += base * rayPattern;
        marchT += stepLen;
    }

    color *= HeaderBackground::edgeFade(fragCoord, uniforms.resolution, uniforms.offset, uniforms.time);
    color *= uniforms.intensity;

    return float4(saturate(color), 1.0);
}
