#include <flutter/runtime_effect.glsl>

// A poetic screen transition: ink bleeds across the screen from a point like
// a calligrapher's wash, feathered at its edge with gold-leaf dust. Once it
// has spread, faint gold lines of flowing script appear in it, and rose
// petals drift across the whole time. Progress 0 -> 1 covers the screen, and
// 1 -> 0 lets it dry away.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold of the leaf dust and script
//   uArm    - the petals
//   uCore   - the ink
//   uParams - x: progress 0..1, y: origin x (0..1), z: origin y (0..1)

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
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.05 + vec2(3.1, 7.4);
    a *= 0.5;
  }
  return v;
}

// A petal: a rotated ellipse with a pointed tip, 0..1 coverage.
float petal(vec2 p, float rot, float size) {
  float c = cos(rot);
  float s = sin(rot);
  p = mat2(c, -s, s, c) * p;
  p.x /= size;
  p.y /= size * 0.55;
  float r = length(p);
  float tip = 1.0 + 0.35 * smoothstep(0.0, 1.0, p.x / max(r, 0.001));
  return 1.0 - smoothstep(tip - 0.12, tip, r);
}

void main() {
  float prog = clamp(uParams.x, 0.0, 1.0);
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 rel = (uv - uParams.yz) * vec2(aspect, 1.0);
  float dist = length(rel);
  vec2 far = max(uParams.yz, 1.0 - uParams.yz) * vec2(aspect, 1.0);
  float reach = max(length(far), 0.2);

  // How far the ink has bled here: nearest the origin first, with the ink's
  // own grain pulling the front into feathery tendrils.
  vec2 warp = vec2(fbm(uv * 3.0 + uTime * 0.05), fbm(uv * 3.0 + 9.0 - uTime * 0.04));
  float grain = fbm((uv + (warp - 0.5) * 0.35) * vec2(aspect, 1.0) * 4.5);
  float value = prog * 1.85 - dist / reach * 0.85 + (grain - 0.5) * 0.55;
  float threshold = 0.4;
  float cover = smoothstep(threshold - 0.015, threshold + 0.03, value);
  float front = 1.0 - smoothstep(0.0, 0.09, abs(value - threshold)); // the wet edge

  // The ink: deep, with darker pools and a faint sheen.
  float pool = fbm(uv * vec2(aspect, 1.0) * 2.2 - uTime * 0.03);
  vec3 ink = uCore.rgb * (0.65 + 0.7 * pool);
  ink += uRim.rgb * 0.05 * smoothstep(0.55, 0.9, grain);

  // Flowing script: rows of wavy gold strokes with small dots, fading in once
  // the ink has spread.
  float rows = 13.0;
  float ry = uv.y * rows;
  float row = floor(ry);
  float fy = fract(ry) - 0.5;
  float wave = 0.2 * sin(uv.x * (14.0 + hash(vec2(row, 1.0)) * 10.0) + row * 2.3 + uTime * 0.4);
  float stroke = 1.0 - smoothstep(0.02, 0.07, abs(fy - wave * 0.6));
  float gap = smoothstep(0.35, 0.5, noise(vec2(uv.x * 9.0 + row * 7.0, row)));
  float dots = 1.0 - smoothstep(0.03, 0.06, length(vec2(fract(uv.x * 9.0 + row * 1.7) - 0.5, fy + 0.28)));
  dots *= step(0.6, hash(vec2(floor(uv.x * 9.0 + row * 1.7), row)));
  float script = (stroke * gap + dots) * smoothstep(0.55, 1.0, prog);
  ink = mix(ink, uRim.rgb * 0.9, script * 0.35);

  // The wet edge glows with gold-leaf dust.
  vec2 dg = uv * vec2(aspect, 1.0) * 70.0;
  float dot = 1.0 - smoothstep(0.12, 0.3, length(fract(dg) - 0.5));
  float flake = step(0.9, hash(floor(dg))) * dot * (0.5 + 0.5 * sin(uTime * 6.0 + hash(floor(dg)) * 30.0));
  float inkA = clamp(cover + front * 0.55, 0.0, 1.0);
  vec3 inkCol = ink * cover + uRim.rgb * (front * 0.5 + front * flake * 0.9);
  vec4 layer = vec4(min(inkCol, vec3(1.0)), inkA); // premultiplied

  // Rose petals drifting down and sideways, small and loose, over everything.
  float petals = 0.0;
  float shade = 0.0;
  for (int k = 0; k < 2; k++) {
    float sc = k == 0 ? 7.0 : 11.0;
    vec2 g = uv * vec2(aspect, 1.0) * sc;
    g.y -= uTime * (k == 0 ? 0.55 : 0.9);
    g.x += sin(uTime * 0.7 + g.y * 1.3) * 0.3;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float h = hash(id + float(k) * 17.0);
    if (h > 0.5) {
      vec2 off = (vec2(hash(id + 3.3), hash(id + 6.6)) - 0.5) * 0.4;
      float pa = petal(f - off, h * 6.28 + uTime * (0.5 + h), 0.09 + 0.05 * h);
      if (pa > petals) {
        petals = pa;
        shade = h;
      }
    }
  }
  float live = smoothstep(0.0, 0.1, prog) * (1.0 - smoothstep(0.88, 1.0, prog));
  float petalA = petals * live * 0.9;
  vec3 pc = mix(uArm.rgb, uRim.rgb, 0.15 + 0.35 * shade);
  layer = vec4(pc * petalA + layer.rgb * (1.0 - petalA), petalA + layer.a * (1.0 - petalA));
  fragColor = layer;
}
