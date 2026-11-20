#include <flutter/runtime_effect.glsl>

// Drifting motes of light: three layers of fireflies / gold dust that rise and
// sway slowly, each with a soft halo and a twinkle, over a transparent rect.
// Meant to float around something precious (a card of poetry), not to cover
// it, so it stays sparse.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the main colour of the motes (gold)
//   uArm    - the colour of the occasional second kind (warm white)
//   uCore   - unused
//   uParams - x: how many motes, 0..2 (0 means the default, 1)

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

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float aspect = uSize.x / uSize.y;
  float density = uParams.x > 0.0 ? uParams.x : 1.0;
  vec3 col = vec3(0.0);
  float a = 0.0;
  for (int layer = 0; layer < 3; layer++) {
    float L = float(layer);
    float cells = 5.0 + L * 3.0;
    vec2 g = vec2(uv.x * aspect, uv.y) * cells;
    g.y += uTime * (0.16 + 0.1 * L); // rising
    g.x += sin(uTime * (0.4 + 0.2 * L) + g.y * 1.7) * 0.25; // swaying
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float h = hash(id + L * 19.0);
    if (h > 0.34 * density) continue;
    vec2 off = (vec2(hash(id + 3.7), hash(id + 8.1)) - 0.5) * 0.6;
    float r = length(f - off);
    float size = 0.018 + 0.03 * hash(id + 5.5) + 0.008 * L;
    float tw = 0.45 + 0.55 * sin(uTime * (1.5 + 3.0 * h) + h * 60.0);
    float core = 1.0 - smoothstep(size * 0.5, size, r);
    float halo = exp(-r / (size * 3.0)) * 0.35;
    float m = (core + halo) * tw;
    vec3 c = hash(id + 11.0) > 0.8 ? uArm.rgb : uRim.rgb;
    col += c * m;
    a = max(a, clamp(m, 0.0, 1.0));
  }
  // Fade out toward the rectangle's edge so a mote's halo is never cut off.
  vec2 e = min(uv, 1.0 - uv);
  float edge = smoothstep(0.0, 0.08, e.x) * smoothstep(0.0, 0.08, e.y);
  fragColor = vec4(min(col, vec3(1.0)) * edge, a * edge);
}
