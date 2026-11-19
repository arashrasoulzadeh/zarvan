#include <flutter/runtime_effect.glsl>

// A flat, anti-aliased disc: solid colours only, no shading, no highlight. For
// games whose look is plain geometry (a board of identical circles) where the
// glossy `orb` would read as a bubble. It is masked to the circle inscribed in
// the rect, so a non-square rect still gives a round disc.
//
// It can also be alive while staying flat: the edge can wobble like a drop of
// water, two eyes can look around and blink, and a thin ripple can spread from
// the middle now and then. Everything is a single flat colour; nothing is
// shaded.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - y: edge softness as a share of the radius (the effect's `blur`);
//             0 is a crisp edge, larger values feather it like an out-of-focus
//             dot
//   uRim    - the body colour (its alpha scales the disc)
//   uArm    - the eyes' colour
//   uCore   - the ripple's colour; its alpha is the ripple's strength (0 = none)
//   uParams - x: ring thickness as a share of the radius, 0..1; 0 is a solid
//                 disc, above 0 only that outer band is drawn (an outline)
//             y: how far the edge wobbles inwards, 0..0.5; 0 is a perfect circle
//             z: above 0.5 draws the eyes
//             w: a per-disc seed so neighbours do not move in step

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float eye(vec2 q, vec2 c, float open) {
  vec2 d = (q - c) / vec2(0.115, 0.115 * open);
  return 1.0 - smoothstep(0.9, 1.0, length(d));
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float side = min(uSize.x, uSize.y);
  vec2 q = (uv * 2.0 - 1.0) * uSize / side;
  float r = length(q);
  float aa = 2.0 / side;
  float t = uTime;
  float seed = uParams.w;

  // The edge: a slow blend of lobes, never reaching past the unit circle.
  float edge = 1.0;
  float wob = clamp(uParams.y, 0.0, 0.5);
  if (wob > 0.0) {
    float a = atan(q.y, q.x);
    float s = 0.5 + 0.5 * (0.6 * sin(3.0 * a + t * 1.4 + seed * 6.28) +
                           0.4 * sin(5.0 * a - t * 1.9 + seed * 3.7));
    edge = 1.0 - wob * (1.0 - s);
  }

  float feather = max(aa, clamp(uPic.y, 0.0, 1.0));
  float alpha = 1.0 - smoothstep(edge - feather, edge, r);
  float ring = clamp(uParams.x, 0.0, 1.0);
  if (ring > 0.0) {
    alpha *= smoothstep(edge - ring - aa, edge - ring, r);
  }

  vec3 col = uRim.rgb;

  // A thin ripple spreading from the middle, fading as it reaches the edge.
  if (uCore.a > 0.01) {
    float k = fract(t * 0.28 + seed * 2.7);
    float rr = k * 0.92;
    float line = 1.0 - smoothstep(0.0, 0.035, abs(r - rr));
    col = mix(col, uCore.rgb, line * uCore.a * (1.0 - k));
  }

  // Eyes that wander and blink every few seconds.
  if (uParams.z > 0.5) {
    float b = fract(t * 0.23 + seed * 1.9);
    float open = b < 0.045 ? 0.12 : 1.0;
    vec2 look = vec2(sin(t * 0.7 + seed * 5.0) * 0.07, cos(t * 0.5 + seed * 4.0) * 0.04);
    float e = max(eye(q, vec2(-0.27, -0.06) + look, open),
                  eye(q, vec2(0.27, -0.06) + look, open));
    col = mix(col, uArm.rgb, e * uArm.a);
  }

  alpha *= uRim.a;
  fragColor = vec4(col * alpha, alpha);
}
