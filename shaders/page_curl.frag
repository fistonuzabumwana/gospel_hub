#include <flutter/runtime_effect.glsl>

// Uniforms - float uniforms
uniform vec2 uSize;          // Widget size in pixels
uniform vec2 uCurlPos;       // Current curl axis position (normalized 0-1)
uniform vec2 uCurlDir;       // Curl direction vector (normalized)
uniform float uRadius;       // Cylinder radius (normalized, default ~0.08)
uniform float uShadowWidth;  // Shadow width multiplier (default 0.15)
uniform float uPaperR;       // Blank back-of-page paper color
uniform float uPaperG;
uniform float uPaperB;
uniform float uReverse;      // 1.0 = reverse (previous page), 0.0 = forward (next page)

// Texture samplers
uniform sampler2D uCurrentPage;  // Current page texture (front only)
uniform sampler2D uNextPage;     // Next page texture (or previous when reverse)

out vec4 fragColor;

const float M_PI = 3.14159265359;

vec4 blankPaper(float shade) {
    // Entirely blank underside — no mirrored text.
    return vec4(vec3(uPaperR, uPaperG, uPaperB) * shade, 1.0);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // Flip UV.x when in reverse mode so the math works symmetrically
    if (uReverse > 0.5) {
        uv.x = 1.0 - uv.x;
    }

    // Direction from curl axis (safe normalize — zero vectors NaN and crash GPUs)
    vec2 dir = uCurlDir;
    float dirLen = length(dir);
    dir = dirLen > 0.001 ? dir / dirLen : vec2(1.0, 0.0);
    // Mirror direction along X in reverse mode (matching UV and curlPos mirroring)
    if (uReverse > 0.5) {
        dir.x = -dir.x;
    }

    // Compute curl axis position along the direction vector
    // origin = intersection of direction ray from curlPos with the left edge
    vec2 curlPos = uCurlPos;
    if (uReverse > 0.5) {
        curlPos.x = 1.0 - curlPos.x;
    }

    vec2 origin;
    if (abs(dir.x) > 0.001) {
        origin = curlPos - dir * (curlPos.x / dir.x);
    } else {
        origin = vec2(0.0, curlPos.y);
    }
    origin = clamp(origin, 0.0, 1.0);

    // Distance of fragment from curl axis
    vec2 fragVec = uv - origin;
    float fragDist = dot(fragVec, dir);

    // Distance of curl axis from origin
    vec2 curlVec = curlPos - origin;
    float curlDist = dot(curlVec, dir);

    // d = distance of fragment from the curl axis
    float d = fragDist - curlDist;
    float r = uRadius;

    // Left spine staple (edge near TT / Home): while the curl is still on the
    // page, never let the fold visually pass the left edge of the sheet.
    float spine = 1.0 - smoothstep(0.0, 0.03, uv.x);
    if (spine > 0.0 && curlPos.x > 0.02) {
        d = mix(d, min(d, 0.0), spine);
    }

    // Point on curl axis line perpendicular to fragment
    vec2 linePoint = uv - d * dir;

    vec4 color;
    float shadowFactor = 1.0;

    if (d > r) {
        // ============================================
        // Scenario 1: Ahead of curl — show NEXT page
        // ============================================
        vec2 sampleUV = uv;
        if (uReverse > 0.5) {
            sampleUV.x = 1.0 - sampleUV.x;
        }
        color = texture(uNextPage, sampleUV);
        color.a = 1.0;

        float shadowDist = d - r;
        if (shadowDist < uShadowWidth * r * 4.0) {
            shadowFactor = mix(0.7, 1.0, clamp(shadowDist / (uShadowWidth * r * 4.0), 0.0, 1.0));
        }
    } else if (d > 0.0 && r > 0.0) {
        // ============================================
        // Scenario 2: On the curl cylinder
        // ============================================
        float theta = asin(clamp(d / r, -1.0, 1.0));

        float d1 = theta * r;
        vec2 p1 = linePoint + dir * d1;

        float d2 = (M_PI - theta) * r;
        vec2 p2 = linePoint + dir * d2;

        vec2 p1Sample = p1;
        if (uReverse > 0.5) {
            p1Sample.x = 1.0 - p1Sample.x;
        }

        // Back of the turning page (blank paper — never show mirrored text)
        if (p2.x >= 0.0 && p2.x <= 1.0 && p2.y >= 0.0 && p2.y <= 1.0) {
            float shade = mix(0.78, 0.92, clamp(theta / (M_PI * 0.5), 0.0, 1.0));
            color = blankPaper(shade);
            shadowFactor = mix(0.8, 1.0, clamp(theta / (M_PI * 0.5), 0.0, 1.0));
        } else if (p1.x >= 0.0 && p1.x <= 1.0 && p1.y >= 0.0 && p1.y <= 1.0) {
            // Front of current page
            color = texture(uCurrentPage, p1Sample);
            color.a = 1.0;
            shadowFactor = mix(0.9, 1.0, clamp(theta / (M_PI * 0.5), 0.0, 1.0));
        } else {
            // Outside page bounds → next page
            vec2 sampleUV = uv;
            if (uReverse > 0.5) {
                sampleUV.x = 1.0 - sampleUV.x;
            }
            color = texture(uNextPage, sampleUV);
            color.a = 1.0;
            float shadowDist = r - d;
            shadowFactor = mix(0.7, 1.0, clamp(shadowDist / (uShadowWidth * r * 4.0), 0.0, 1.0));
        }
    } else {
        // ============================================
        // Scenario 3: Behind the curl axis
        // ============================================
        if (r > 0.0) {
            float unrollDist = M_PI * r - d;
            vec2 p = linePoint + dir * unrollDist;

            if (p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0) {
                // Underside of curled sheet — blank paper only
                float shade = mix(0.72, 0.9, clamp(-d / (r * 2.0), 0.0, 1.0));
                color = blankPaper(shade);
                shadowFactor = mix(0.75, 1.0, clamp(-d / (r * 2.0), 0.0, 1.0));
            } else {
                // Flat current page
                vec2 sampleUV = uv;
                if (uReverse > 0.5) {
                    sampleUV.x = 1.0 - sampleUV.x;
                }
                color = texture(uCurrentPage, sampleUV);
                color.a = 1.0;
            }
        } else {
            vec2 sampleUV = uv;
            if (uReverse > 0.5) {
                sampleUV.x = 1.0 - sampleUV.x;
            }
            color = texture(uCurrentPage, sampleUV);
            color.a = 1.0;
        }
    }

    color.rgb *= shadowFactor;
    fragColor = vec4(color.rgb, 1.0);
}
