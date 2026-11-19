#include <flutter/runtime_effect.glsl>

// A cloud in the manner of a Persian miniature, in four quite different
// shapes: a curled head with a long double tail, a long low streak with a
// small curl, a round heap of puffs with a stub of tail, and a twin-curl
// ("ruyi") cloud. Pale blue with a cream rim and a thin gold outline, its body
// drawn with contour lines that spiral into the heads. Its puffs breathe and
// its tail wanders very slightly as it drifts, so it never holds one shape.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels (a wide shape)
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold outline
//   uArm    - the blue of the body
//   uCore   - the cream of the rim and contour lines
//   uParams - x: shape 0..3, y: 1 mirrors it (head at the right), z: opacity
//             0..1 (0 = 1), w: a seed that offsets its motion

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float hash2(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x),
             mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float circ(vec2 p, vec2 c, float r) {
  return length(p - c) - r;
}

// A tapering wavy ribbon running right from x0 to x1.
float ribbon(vec2 p, float x0, float x1, float yc, float amp, float freq,
             float phase, float thick) {
  float s = clamp((p.x - x0) / (x1 - x0), 0.0, 1.0);
  float y = yc + amp * sin(p.x * freq + phase) * (0.4 + 0.6 * s);
  float th = thick * pow(1.0 - s, 1.25) + 0.004;
  float d = abs(p.y - y) - th;
  return max(d, max(p.x - x1, x0 - p.x));
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  float aspect = uSize.x / uSize.y;
  vec2 p = frag / uSize.y;
  if (uParams.y > 0.5) p.x = aspect - p.x;

  float v = floor(uParams.x + 0.5);
  float t = uTime + uParams.w * 17.0;
  // Very slight breathing: each puff swells a few percent, at its own pace.
  float b1 = 1.0 + 0.035 * sin(t * 0.55);
  float b2 = 1.0 + 0.04 * sin(t * 0.7 + 1.7);
  float b3 = 1.0 + 0.04 * sin(t * 0.45 + 3.1);
  float ph = t * 0.4;

  vec2 hc;
  float hr;
  float d;
  if (v < 0.5) {
    // A curled head and a long double tail.
    hc = vec2(0.36, 0.56 + 0.012 * sin(t * 0.5));
    hr = 0.27 * b1;
    d = circ(p, hc, hr);
    d = smin(d, circ(p, hc + vec2(-0.24, 0.07), hr * 0.58 * b2), 0.09);
    d = smin(d, circ(p, hc + vec2(0.2, -0.17), hr * 0.62 * b3), 0.09);
    d = smin(d, circ(p, hc + vec2(0.05, -0.28), hr * 0.5 * b2), 0.08);
    d = smin(d, circ(p, hc + vec2(-0.1, 0.21), hr * 0.5 * b3), 0.08);
    float end = aspect * 0.95;
    d = smin(d, ribbon(p, hc.x, end, 0.56, 0.07, 5.2, ph, 0.17), 0.1);
    d = smin(d, ribbon(p, hc.x + 0.1, end * 0.86, 0.66, 0.06, 6.4, -ph + 1.3, 0.09), 0.08);
  } else if (v < 1.5) {
    // A long low streak with a small curl at the front.
    hc = vec2(0.2, 0.52 + 0.01 * sin(t * 0.5));
    hr = 0.15 * b1;
    d = circ(p, hc, hr);
    d = smin(d, circ(p, hc + vec2(0.13, -0.1), hr * 0.65 * b2), 0.06);
    float end = aspect * 0.98;
    d = smin(d, ribbon(p, hc.x, end, 0.52, 0.045, 3.4, ph, 0.11), 0.07);
    d = smin(d, ribbon(p, hc.x + 0.2, end * 0.92, 0.6, 0.04, 4.1, -ph + 0.6, 0.06), 0.05);
    d = smin(d, ribbon(p, hc.x + 0.1, end * 0.8, 0.45, 0.04, 4.8, ph + 2.0, 0.05), 0.05);
  } else if (v < 2.5) {
    // A round heap of puffs with a stub of tail.
    hc = vec2(0.42, 0.55 + 0.01 * sin(t * 0.5));
    hr = 0.24 * b1;
    d = circ(p, hc, hr);
    d = smin(d, circ(p, hc + vec2(-0.26, 0.1), hr * 0.62 * b2), 0.08);
    d = smin(d, circ(p, hc + vec2(0.27, 0.08), hr * 0.66 * b3), 0.08);
    d = smin(d, circ(p, hc + vec2(0.12, -0.22), hr * 0.55 * b2), 0.07);
    d = smin(d, circ(p, hc + vec2(-0.12, -0.2), hr * 0.5 * b3), 0.07);
    d = smin(d, circ(p, hc + vec2(0.0, 0.22), hr * 0.7 * b1), 0.07);
    d = smin(d, ribbon(p, hc.x + 0.2, aspect * 0.9, 0.62, 0.04, 6.0, ph, 0.09), 0.06);
  } else {
    // A twin-curl cloud: two heads joined by a swelling, tails both ways.
    hc = vec2(0.3, 0.5 + 0.012 * sin(t * 0.5));
    hr = 0.2 * b1;
    vec2 h2 = vec2(0.72, 0.6 + 0.012 * sin(t * 0.6 + 1.0));
    float r2 = 0.17 * b3;
    d = circ(p, hc, hr);
    d = smin(d, circ(p, hc + vec2(-0.16, -0.12), hr * 0.55 * b2), 0.07);
    d = smin(d, circ(p, h2, r2), 0.08);
    d = smin(d, circ(p, h2 + vec2(0.14, 0.1), r2 * 0.6 * b2), 0.07);
    d = smin(d, ribbon(p, hc.x, h2.x, 0.56, 0.05, 6.0, ph, 0.09), 0.08);
    d = smin(d, ribbon(p, h2.x, aspect * 0.97, 0.64, 0.06, 5.0, -ph, 0.1), 0.08);
  }

  float depth = -d;
  float aa = 1.2 / uSize.y;
  float body = smoothstep(-aa, aa, depth);
  if (body <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Contours that follow the outline inward, plus a spiral into the head.
  float contour = abs(fract(depth * (v > 1.5 && v < 2.5 ? 22.0 : 17.0)) - 0.5);
  float lines = 1.0 - smoothstep(0.05, 0.13, contour);
  vec2 rel = p - hc;
  float spiral = fract(length(rel) * 11.0 - atan(rel.y, rel.x) / 6.2832 * 2.0);
  float inHead = 1.0 - smoothstep(hr * 0.35, hr * 1.05, length(rel));
  float curl = (1.0 - smoothstep(0.06, 0.16, abs(spiral - 0.5))) * inHead;
  float rings = max(lines * (1.0 - inHead * 0.7), curl);

  vec3 blue = uArm.rgb;
  vec3 cream = uCore.rgb;
  vec3 col = mix(blue * 1.18, blue * 0.92, smoothstep(0.0, 0.2, depth));
  // Brushed washes of colour: the body is darker in patches, lighter in
  // others, as a painter's loaded brush leaves it.
  col *= 0.93 + 0.14 * vnoise(p * 9.0 + vec2(t * 0.02, 0.0)) + 0.05 * vnoise(p * 40.0);
  col = mix(col, cream, rings * 0.55);
  float rim = 1.0 - smoothstep(0.012, 0.03, depth);
  col = mix(col, cream, rim * 0.85);
  float outline = 1.0 - smoothstep(0.004, 0.009, depth);
  float glint = 0.6 + 0.4 * sin(p.x * 9.0 - t * 1.4 + p.y * 3.0);
  col = mix(col, uRim.rgb * (0.85 + 0.3 * glint), outline);

  float alpha = body * (uParams.z > 0.0 ? uParams.z : 1.0);
  fragColor = vec4(col * alpha, alpha);
}
