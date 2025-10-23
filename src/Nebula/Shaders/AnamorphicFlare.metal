//
//  AnamorphicFlare.metal
//  Nebula
//
//  Created by Gonzalo Cruz Cortes on 10/21/25.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct AnamorphicFlareUniforms {
    float2 resolution;          // Screen resolution
    float2 lightPosition;       // Position of light source (window center)
    float time;                 // Time for animation
    float intensity;            // Overall intensity
    float streakLength;         // How far rays shoot out
    float streakWidth;          // Width of the rays
    float falloffPower;         // Ray falloff curve
    float chromaticAberration;  // Color separation
    int rayCount;               // Number of rays
    float threshold;            // Brightness threshold
    float4 tintColor;           // Base tint
    float dispersion;           // Color dispersion
    float noiseAmount;          // Noise/flicker
    float rotationAngle;        // Base rotation
    float glowRadius;           // Central glow size
    float4 flareColors[6];      // Custom colors
    int colorCount;             // Number of colors
    float2 direction;           // Direction bias
    float edgeFade;             // Edge vignette
    float _padding[3];          // Padding for alignment
};

namespace AnamorphicUtils {
    float rand(float2 p, float time) {
        float PI = 3.14159265;
        return fract(sin(fmod(dot(p, float2(12.9898, 78.233)), PI)) * 43758.5453 + time * 0.35);
    }

    float noise(float2 x, float time) {
        float2 i = floor(x);
        float2 f = fract(x);

        f = f * f * (f * -2.0 + 3.0);

        float a = rand(i + float2(0.0, 0.0), time);
        float b = rand(i + float2(1.0, 0.0), time);
        float c = rand(i + float2(0.0, 1.0), time);
        float d = rand(i + float2(1.0, 1.0), time);

        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }

    float starBurst(float2 p, float time) {
        float k0 = 1.0;
        float k1 = 1.0;
        float k2 = 0.5;
        float k3 = 12.0;
        float k4 = 12.0;
        float k5 = 2.0;
        float k6 = 5.2;
        float k7 = 4.0;
        float k8 = 6.2;

        float l = length(p);
        float l2 = pow(l * k1, k2);

        float n0 = noise(float2(atan2(p.y, p.x) * k0, l2) * k3, time);
        float n1 = noise(float2(atan2(-p.y, -p.x) * k0, l2) * k3, time);

        float n = pow(max(n0, n1), k4) * pow(saturate(1.0 - l * k5), k6);

        n += pow(saturate(1.0 - (l * k7 - 0.1)), k8);

        return n;
    }

    float edgeFade(float2 fragCoord, float2 resolution, float2 lightPos, float time) {
        float2 toCenter = fragCoord - lightPos;
        float radius = length(toCenter) / (0.5 * min(resolution.x, resolution.y));
        float x = saturate(radius);

        float q = x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
        float s = q * 0.5;
        s = pow(s, 1.5);

        float tail = 1.0 - pow(1.0 - s, 2.0);
        s = mix(s, tail, 0.2);

        float dn = (noise(fragCoord * 0.15, time) - 0.5) * 0.0015 * s;
        return saturate(s + dn);
    }

    float3 sampleGradient(float t, constant float4* colors, int count) {
        if (count <= 0) {
            float3 c1 = float3(0.2, 0.5, 1.0);
            float3 c2 = float3(0.0, 0.8, 1.0);
            float3 c3 = float3(1.0, 0.5, 0.1);
            float3 c4 = float3(1.0, 0.2, 0.4);

            t = saturate(t);
            if (t < 0.33) {
                return mix(c1, c2, t * 3.0);
            } else if (t < 0.66) {
                return mix(c2, c3, (t - 0.33) * 3.0);
            } else {
                return mix(c3, c4, (t - 0.66) * 3.0);
            }
        }

        t = saturate(t) * float(count - 1);
        int idx = int(t);
        float frac = fract(t);

        if (idx >= count - 1) {
            return colors[count - 1].rgb;
        }

        return mix(colors[idx].rgb, colors[idx + 1].rgb, frac);
    }
}

vertex VertexOut anamorphicFlareVertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 anamorphicFlareFragment(
    VertexOut in [[stage_in]],
    constant AnamorphicFlareUniforms& uniforms [[buffer(0)]]
) {
    float2 fragCoord = in.texCoord * uniforms.resolution;
    float2 uv = fragCoord / uniforms.resolution;

    float2 center = uniforms.lightPosition / uniforms.resolution;

    float3 finalColor = float3(0.0);

    for (int i = 0; i < 6; i++) {
        float angle = float(i) * 1.047198;

        float randomOffset = float(i * 7 % 11) / 11.0;
        float speedVariation = 0.4 + (float(i * 3 % 7) / 7.0) * 0.4;

        float time = fmod(uniforms.time * speedVariation + randomOffset * 2.0, 2.5);

        float normalizedTime = time / 2.5;
        float distance = normalizedTime * normalizedTime * 0.7;

        float2 ovalCenter = center + float2(cos(angle), sin(angle)) * distance;

        float2 pos = uv - ovalCenter;

        float2 rotated;
        rotated.x = pos.x * cos(-angle) - pos.y * sin(-angle);
        rotated.y = pos.x * sin(-angle) + pos.y * cos(-angle);

        float widthExpansion = 1.0 + distance * 2.0;
        float2 ovalPos = rotated * float2(4, 15.0 / widthExpansion);
        float dist = length(ovalPos);

        float mask = smoothstep(0.6, 0.0, dist);

        if (mask > 0.01) {
            float gradPos = saturate(-rotated.x * 10.0 + 0.5);

            float3 blue1 = float3(0.0, 0.5, 1.0);
            float3 blue2 = float3(0.0, 0.9, 1.0);
            float3 green = float3(0.6, 1.0, 0.6);
            float3 yellow = float3(1.0, 0.95, 0.3);
            float3 orange = float3(1.0, 0.5, 0.0);

            float lifeProgress = distance / 0.7;

            float warmthShift = smoothstep(0.3, 1.0, lifeProgress) * 0.4;

            float3 color = blue1;
            color = mix(color, blue2, smoothstep(0.0, 0.35 - warmthShift, gradPos));
            color = mix(color, green, smoothstep(0.0, 0.50 - warmthShift, gradPos));
            color = mix(color, yellow, smoothstep(0.0, 0.75 - warmthShift, gradPos));
            color = mix(color, orange, smoothstep(0.0, 0.90 - warmthShift, gradPos));

            float intensity = mask * 0.8;

            float deathPhase = lifeProgress;
            float lastBreath = smoothstep(0.6, 0.8, deathPhase) * (1.0 - smoothstep(0.8, 1.0, deathPhase));
            intensity *= (1.0 + lastBreath * 0.6);

            intensity *= saturate(1.0 - distance * 0.95);

            finalColor += color * intensity;
        }
    }

    finalColor *= uniforms.intensity * 0.7;

    float alpha = length(finalColor) * 0.7;
    alpha = saturate(alpha) * 0.6;

    return float4(saturate(finalColor), alpha);
}
