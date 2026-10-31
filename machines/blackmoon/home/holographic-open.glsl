#version 320 es
// @duration @duration@
// Palette substitutions are owned by window-animation.nix / sekai-palette.json.
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
uniform float progress;
uniform float seed;
uniform vec4 window_rect;
out vec4 fragColor;
const bool closing = @closing@;
const vec3 ink = @sekaiInk@;
const vec3 teal = @sekaiTeal@;
const vec3 mint = @sekaiMint@;
const vec3 lavender = @sekaiLavender@;
const vec3 pink = @sekaiPink@;
const vec3 pearl = @sekaiSurface@;

float random(vec2 cell) {
    return fract(sin(dot(cell, vec2(127.1, 311.7)) + seed * 19.19) * 43758.5453);
}

float roundedBox(vec2 local, float radius) {
    vec2 corner = abs(local - 0.5) - vec2(0.5 - radius);
    return length(max(corner, vec2(0.0))) + min(max(corner.x, corner.y), 0.0) - radius;
}

// Independent falling speeds with lateral flutter; vertical travel never reverses.
vec2 flight(float age, vec4 trajectory, float phase) {
    float t = pow(age, mix(0.85, 1.65, phase));
    float travel = mix(85.0, 180.0, trajectory.y);
    float drift = mix(-55.0, 55.0, trajectory.x);
    float flutter = sin(age * mix(2.0, 5.0, trajectory.w) + phase * 6.2831853)
                  * mix(10.0, 38.0, trajectory.z);
    return vec2((age - 0.45) * drift + flutter, (t - 0.45) * travel);
}

// Decorations are independent points, never cells containing window pixels.
void main() {
    float clock = clamp(progress, 0.0, 1.0);
    float p = 1.0 - pow(1.0 - clock, closing ? 1.25 : 1.65);
    vec4 original = texture(tex, v_texcoord);
    if (clock >= 0.995) { fragColor = closing ? vec4(0.0) : original; return; }
    // Close snapshots cover the monitor; effects must use the window sub-rect.
    vec2 extent = max(window_rect.zw, vec2(0.00001));
    vec2 windowUV = (v_texcoord - window_rect.xy) / extent;
    vec2 resolution = vec2(textureSize(tex, 0)) * extent;
    vec2 pixel = windowUV * resolution;
    float front = mix(-0.16, 1.22, p);
    // A slightly bowed, slanting veil keeps the reveal fluid and continuous.
    float contour = windowUV.y + 0.065 * (windowUV.x - 0.5)
                  + 0.025 * sin(windowUV.x * 5.0 + seed - clock * 4.0);
    float distance = contour - front;
    float reveal = 1.0 - smoothstep(-0.065, 0.045, distance);
    vec4 result = original * (closing ? 1.0 - reveal : reveal);
    float envelope = smoothstep(0.0, 0.08, clock) * (1.0 - smoothstep(0.78, 1.0, clock));
    float ribbon = exp(-pow(distance / 0.037, 2.0)) * envelope;
    vec3 ribbonColor = mix(mint, pink, smoothstep(0.15, 0.85, windowUV.x));
    float ribbonAlpha = ribbon * 0.20 * original.a;
    result = vec4(mix(ribbonColor, pearl, 0.45) * ribbonAlpha, ribbonAlpha)
           + result * (1.0 - ribbonAlpha);

    for (int i = 0; i < 34; ++i) {
        vec2 key = vec2(float(i) * 1.37, float(i) + 8.2);
        float r = random(key);
        float variant = random(key + 31.7);
        float motion = random(key + 71.2);
        vec2 anchor = vec2(random(key + 3.2), random(key + 19.4));
        float timing = random(key + vec2(103.4, 27.1));
        float duration = mix(0.28, 0.50, random(key + vec2(8.7, 147.2)));
        float birth = closing ? 0.015 + timing * 0.10 + anchor.y * 0.38
                              : 0.015 + timing * 0.35 + anchor.y * 0.075;
        float age = (clock - birth) / duration;
        if (age <= 0.0 || age >= 1.0) continue;
        float fadeIn = mix(0.08, 0.22, random(key + 187.1));
        float fadeOut = mix(0.52, 0.78, random(key + 211.4));
        float life = smoothstep(0.0, fadeIn, age) * (1.0 - smoothstep(fadeOut, 1.0, age));
        vec4 trajectory = vec4(random(key + vec2(12.4, 91.8)),
                               random(key + vec2(57.6, 13.9)),
                               random(key + vec2(32.8, 171.3)),
                               random(key + vec2(95.4, 42.7)));
        float phase = random(key + vec2(231.5, 16.8));
        float spin = random(key + vec2(17.9, 263.4));
        float side = mix(9.0, 38.0, pow(variant, 2.0));
        vec2 center = anchor * resolution + flight(age, trajectory, phase);
        vec2 delta = pixel - center;
        vec3 tint = r < 0.50 ? mint : (r < 0.78 ? pink : lavender);
        // Short tapered wakes make direction readable without smearing the face.
        vec2 tail = flight(max(0.0, age - mix(0.08, 0.18, motion)), trajectory, phase) - flight(age, trajectory, phase);
        float along = clamp(dot(delta, tail) / max(dot(tail, tail), 1.0), 0.0, 1.0);
        float trailDistance = length(delta - tail * along);
        float trail = exp(-pow(trailDistance / mix(3.8, 1.0, along), 2.0))
                    * (1.0 - along) * 0.20 * life * original.a;
        result = vec4(mix(tint, pearl, 0.45) * trail, trail) + result * (1.0 - trail);
        if (max(abs(delta.x), abs(delta.y)) > side * 2.4) continue;
        float direction = spin < 0.5 ? -1.0 : 1.0;
        float angle = phase * 6.2831853 + direction * age * mix(1.3, 6.2, spin);
        float c = cos(angle), s = sin(angle);
        vec2 local = mat2(c, -s, s, c) * delta / side;
        // A full tilt-and-return changes the silhouette visibly during flight.
        local.x /= 0.38 + 0.62 * abs(cos(age * mix(1.8, 5.5, motion) + phase * 6.2831853));
        // Shape selection is independent of size, so every silhouette can be legible.
        float shape = random(key + vec2(307.2, 61.9));
        float sd;
        if (shape < 0.32) {
            sd = roundedBox(local + 0.5, 0.23);
        } else if (shape < 0.52) {
            sd = (abs(local.x) + abs(local.y) - 0.48) * 0.707;
        } else if (shape < 0.70) {
            // Four-point anime sparkle, with concave sides.
            vec2 a = abs(local);
            sd = (sqrt(a.x) + sqrt(a.y) - sqrt(0.55)) * 0.27;
        } else if (shape < 0.84) {
            sd = length(local) - 0.32;
        } else {
            // Rounded ribbon/sliver, distinct from the square cards.
            vec2 strip = vec2(local.x, max(abs(local.y) - 0.36, 0.0));
            sd = length(strip) - 0.13;
        }
        float aa = 1.2 / side;
        float face = 1.0 - smoothstep(-aa, aa, sd);
        float outside = max(sd, 0.0);
        float halo = (0.24 * exp(-outside * outside / 0.035)
                    + 0.08 * exp(-outside * outside / 0.22)) * life * original.a;
        result = vec4(mix(tint, pearl, 0.35) * halo, halo) + result * (1.0 - halo);
        float rim = 1.0 - smoothstep(0.025, 0.09, -sd);
        float light = clamp(0.65 - local.x * 0.5 - local.y * 0.7, 0.0, 1.0);
        vec3 color = mix(tint, pearl, 0.35 + 0.25 * light);
        color = mix(color, mix(teal, pearl, light), rim * 0.85);
        float inset = exp(-pow((sd + 0.105) / 0.025, 2.0));
        color = mix(color, pearl, inset * 0.55);
        float alpha = face * life * original.a * 0.86;
        result = vec4(color * alpha, alpha) + result * (1.0 - alpha);
    }
    fragColor = mix(result, closing ? vec4(0.0) : original, smoothstep(0.92, 1.0, clock));
}
