#include <flutter/runtime_effect.glsl>

// A magical night sky filling the rect: a slow nebula, ribbons of aurora light,
// a field of twinkling stars and motes of dust rising. Meant as a backdrop
// behind a menu, so it stays dark enough for text to read on top.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the night sky's base colour
//   uArm    - nebula and aurora colour
//   uCore   - star, mote and aurora highlight colour

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;

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
  for (int i = 0; i < 4; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

// One layer of stars on a grid; each cell holds at most one that twinkles.
float stars(vec2 uv, float density, float t) {
  vec2 g = uv * density;
  vec2 id = floor(g);
  vec2 f = fract(g) - 0.5;
  float h = hash(id);
  if (h < 0.78) return 0.0;
  vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
  float d = length(f - off * 0.6);
  float size = 0.04 + 0.05 * hash(id + 1.3);
  float tw = 0.55 + 0.45 * sin(t * (1.0 + 3.0 * h) + h * 40.0);
  float core = smoothstep(size, 0.0, d);
  float cross = smoothstep(0.012, 0.0, abs(f.x - off.x * 0.6)) * smoothstep(size * 3.0, 0.0, abs(f.y - off.y * 0.6))
              + smoothstep(0.012, 0.0, abs(f.y - off.y * 0.6)) * smoothstep(size * 3.0, 0.0, abs(f.x - off.x * 0.6));
  return (core + cross * 0.5) * tw;
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime;

  // Sky: deepest at the top, a touch lighter at the bottom horizon.
  vec3 col = uRim.rgb * (0.75 + 0.5 * uv.y);

  // Nebula: two drifting layers of noise tinted with the arm colour.
  float n1 = fbm(p * 2.2 + vec2(t * 0.02, -t * 0.015));
  float n2 = fbm(p * 3.4 - vec2(t * 0.025, t * 0.01) + 5.0);
  float neb = smoothstep(0.35, 0.95, n1 * 0.7 + n2 * 0.5);
  col += uArm.rgb * neb * 0.28;

  // Aurora: soft curtains hanging from a wavy line, brighter at their lower edge.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float wave = 0.22 + 0.12 * fi
        + 0.07 * sin(p.x * (2.6 + fi) + t * (0.25 + 0.1 * fi) + fi * 2.0)
        + 0.04 * sin(p.x * 7.0 - t * 0.4 + fi);
    float d = uv.y - wave;
    float band = smoothstep(0.0, 0.025, d) * exp(-max(d, 0.0) * 9.0);
    band *= 0.55 + 0.45 * noise(vec2(p.x * 6.0 + fi * 3.0, t * 0.3));
    vec3 tint = mix(uArm.rgb, uCore.rgb, 0.25 + 0.3 * fi);
    col += tint * band * 0.2;
  }

  // Stars in two depths, fading a little toward the bottom so text stays calm.
  float fade = 1.0 - 0.55 * uv.y;
  float s = stars(p, 14.0, t) + 0.6 * stars(p + 4.2, 26.0, t * 1.3);
  col += uCore.rgb * s * 0.95 * fade;

  // Motes of dust drifting upward, each on its own slow sway.
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    vec2 q = vec2(p.x * (5.0 + 2.0 * fi), uv.y * (4.0 + fi) + t * (0.08 + 0.04 * fi));
    q.x += sin(q.y * 1.7 + fi) * 0.3;
    vec2 id = floor(q);
    vec2 f = fract(q) - 0.5;
    float h = hash(id + fi * 11.0);
    if (h > 0.82) {
      float d = length(f - (vec2(hash(id + 2.0), hash(id + 5.0)) - 0.5) * 0.5);
      float life = 0.5 + 0.5 * sin(t * (0.6 + h) + h * 30.0);
      col += uCore.rgb * smoothstep(0.09, 0.0, d) * life * 0.5;
    }
  }

  // Shooting stars: every few seconds one streaks across the upper sky.
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    float period = 6.5 + 3.0 * fi;
    float k = floor((t + fi * 3.1) / period);
    float ph = fract((t + fi * 3.1) / period);
    float r = hash(vec2(k, fi + 1.0));
    vec2 head = vec2(mix(0.2, 1.4, r) * aspect - ph * 0.9, 0.05 + 0.3 * hash(vec2(k, 9.0)) + ph * 0.35);
    vec2 dir = normalize(vec2(-0.9, 0.35));
    vec2 rel = p - head;
    float along = dot(rel, -dir);
    float across = abs(dot(rel, vec2(dir.y, -dir.x)));
    float tail = smoothstep(0.0, 0.01, along) * exp(-along * 22.0) * smoothstep(0.006, 0.0, across - 0.002 * along);
    float vis = smoothstep(0.0, 0.1, ph) * smoothstep(0.7, 0.45, ph);
    col += uCore.rgb * tail * vis * 1.3;
  }

  // Slow beams of light falling from the top, like light through a window.
  float beam = 0.0;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float x0 = 0.2 + 0.3 * fi + 0.04 * sin(t * 0.15 + fi * 2.0);
    float dx = uv.x - x0 - uv.y * 0.25;
    beam += smoothstep(0.09, 0.0, abs(dx)) * (1.0 - uv.y) * (0.6 + 0.4 * sin(t * 0.3 + fi * 1.9));
  }
  col += uArm.rgb * beam * 0.06;

  // Vignette keeps the middle (where the content is) the brightest.
  float v = smoothstep(1.15, 0.35, length((uv - 0.5) * vec2(1.0, 1.25)));
  col *= 0.55 + 0.45 * v;

  col += vec3(uPic.y * 0.001);
  fragColor = vec4(col, 1.0);
}
