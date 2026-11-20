#include <flutter/runtime_effect.glsl>

// A sheet of hand-made blue paper, like the sky behind a Persian miniature:
// a mottled lapis ground with long paper fibres, soft darker clouds of
// pigment, a vignette toward the edges and a few flecks of gold leaf that
// glint now and then. Opaque, so draw it behind everything.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the base blue
//   uArm    - the lighter blue the paper mottles toward
//   uCore   - the gold of the flecks
//   uParams - x: the width, in pixels, one "screen" of paper is measured by (0 =
//             the rect's own width), so a rect drawn wider than the screen, to
//             fill the bars of a wide window, keeps the same grain and flecks

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.7);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  float unit = uParams.x > 0.0 ? uParams.x : uSize.x;
  // The vignette belongs to the central screen, not to the (wider) rect.
  vec2 uv = (frag - vec2((uSize.x - unit) * 0.5, 0.0)) / vec2(unit, uSize.y);
  // Square units, so nothing is stretched on a tall screen: one unit is the
  // screen's width.
  vec2 q = frag / unit;

  float t = uTime * 0.01;
  // Washes of pigment: a warped field read through soft thresholds gives the
  // blotchy light and dark patches of gouache on paper.
  vec2 w = vec2(noise(q * 3.0 + vec2(t, 0.0)), noise(q * 3.0 + vec2(5.2, 1.3 - t)));
  float wash = fbm(q * 2.4 + w * 1.6);
  vec3 col = mix(uRim.rgb, uArm.rgb, smoothstep(0.25, 0.85, wash) * 0.45);
  col = mix(col, uRim.rgb * vec3(0.78, 0.84, 0.98), smoothstep(0.55, 0.95, wash) * 0.12);
  // Where a wash dried, pigment gathered in a thin darker tide line.
  float tide = smoothstep(0.015, 0.0, abs(wash - 0.52));
  col *= 1.0 - 0.0 * tide;

  // Ground lapis: granules of pigment, the same in every direction, a coarser
  // and a finer grain, with the odd pale grain of the mineral.
  float g1 = noise(q * 300.0);
  float g2 = noise(q * 120.0 + 4.0);
  col *= 0.92 + 0.1 * g1 + 0.08 * g2;
  col += step(0.93, g1) * 0.06;
  // A few short paper fibres lying at random angles.
  vec2 cell = q * 70.0;
  vec2 id = floor(cell);
  float hh = hash(id);
  if (hh > 0.72) {
    float ang = hash(id + 3.1) * 6.2832;
    vec2 dir = vec2(cos(ang), sin(ang));
    vec2 c = fract(cell) - 0.5 - (vec2(hash(id + 1.7), hash(id + 8.3)) - 0.5) * 0.4;
    float along = dot(c, dir);
    float across = dot(c, vec2(-dir.y, dir.x));
    float fibre = (1.0 - smoothstep(0.015, 0.05, abs(across))) *
                  (1.0 - smoothstep(0.2, 0.38, abs(along)));
    col += fibre * (hh > 0.86 ? 0.07 : -0.05);
  }

  float edge = length((uv - 0.5) * vec2(1.0, 0.8));
  col *= 1.0 - 0.25 * smoothstep(0.35, 0.85, edge);

  // Gold leaf: sparse flecks that glint at different times.
  vec2 g = frag / (unit * 0.045);
  vec2 gid = floor(g);
  vec2 gf = fract(g) - 0.5;
  float gh = hash(gid + 7.0);
  if (gh > 0.93) {
    vec2 off = (vec2(hash(gid + 1.3), hash(gid + 4.9)) - 0.5) * 0.5;
    float r = length(gf - off);
    float size = 0.05 + 0.1 * hash(gid + 9.1);
    float glint = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(uTime * (0.6 + gh) + gh * 90.0), 3.0);
    col += uCore.rgb * (1.0 - smoothstep(size * 0.4, size, r)) * glint * 0.7;
  }

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
