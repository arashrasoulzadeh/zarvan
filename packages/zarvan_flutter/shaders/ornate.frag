#include <flutter/runtime_effect.glsl>

// An ornate Persian panel border, drawn entirely in the shader: a rounded
// rectangle whose band is tiled with a lattice of diamonds, stars and gold
// dots on teal, edged with gold lines, with a rosette in each corner and a
// light that glints along it. Inside the band it can lay a sheet of
// parchment (paper grain, darkened toward the edge, with a scalloped border)
// or leave the middle clear for whatever is drawn under it.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold of the lines, dots and rosettes
//   uArm    - the band's teal
//   uCore   - the middle: parchment colour; alpha 0 leaves it clear
//   uBand   - band thickness, in pixels
//   uCell   - size of one lattice cell, in pixels
//   uRadius - corner radius of the outer edge, in pixels
//   uPaper  - 0..1 how much grain and edge darkening the parchment has
//   uCusp   - 0..1 depth of the scallops on the band's inner edge, as a
//             share of the band

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform float uBand;
uniform float uCell;
uniform float uRadius;
uniform float uPaper;
uniform float uCusp;

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

float sdRoundBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float line(float x, float w) {
  return 1.0 - smoothstep(0.0, w, abs(x));
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  vec2 hs = uSize * 0.5;
  vec2 c = frag - hs;
  float d = -sdRoundBox(c, hs, uRadius);
  float outer = smoothstep(-1.0, 1.0, d);
  if (outer <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  float band = max(uBand, 2.0);
  float cell = max(uCell, 4.0);
  vec2 q = hs - abs(c); // distance to the nearest vertical / horizontal edge

  // The band's inner edge: scallops along each side that fade out near the
  // corners, where the rosettes sit.
  float along = q.y < q.x ? c.x : c.y;
  float edgeRoom = q.y < q.x ? q.x : q.y;
  float t = abs(fract(along / (cell * 3.0)) - 0.5) * 2.0;
  float ripple = band * uCusp * sqrt(max(0.0, 1.0 - t * t));
  ripple *= smoothstep(band * 1.5, band * 2.4, q.y < q.x ? hs.x - abs(c.x) : hs.y - abs(c.y));
  float inner = band + ripple;
  float inBand = 1.0 - smoothstep(inner - 1.0, inner + 1.0, d);

  // Lattice: diamonds with a second diamond inside, a dot in each centre and
  // a star-point where four meet.
  vec2 g = frag / cell;
  vec2 f = fract(g) - 0.5;
  float k = abs(f.x) + abs(f.y);
  float lattice = max(line(k - 0.46, 0.06), line(k - 0.22, 0.05) * 0.8);
  float dots = 1.0 - smoothstep(0.05, 0.1, length(f));
  float stars = 1.0 - smoothstep(0.07, 0.14, length(fract(g + 0.5) - 0.5));
  vec3 teal = uArm.rgb;
  vec3 gold = uRim.rgb;
  float grain = noise(frag / (cell * 0.35));
  vec3 bandCol = teal * (0.5 + 0.35 * grain);
  bandCol = mix(bandCol, teal * 1.15, 0.35 * smoothstep(0.0, band, d) * (1.0 - smoothstep(band * 0.5, band, d)));
  bandCol = mix(bandCol, gold * 0.85, clamp(lattice * 0.75 + stars * 0.5, 0.0, 1.0));
  bandCol = mix(bandCol, gold, dots * 0.9);

  // Gold lines: outside, a thin one in the band, and along the inner edge.
  float w = max(1.0, band * 0.05);
  float lines = max(line(d - w * 1.6, w), line(d - band * 0.3, w * 0.7));
  lines = max(lines, max(line(d - inner, w * 1.2), line(d - (inner - band * 0.22), w * 0.7)));
  bandCol = mix(bandCol, gold, lines * 0.95);

  // A rosette in each corner.
  vec2 v = q - vec2(band * 0.9);
  if (q.x < band * 1.8 && q.y < band * 1.8) {
    float r = length(v);
    float ang = atan(v.y, v.x);
    float petal = 0.5 + 0.5 * cos(ang * 8.0);
    float pulse = 1.0 + 0.04 * sin(uTime * 1.6);
    float disc = 1.0 - smoothstep(band * 0.78 * pulse, band * 0.82 * pulse, r);
    bandCol = mix(bandCol, teal * 0.45, disc);
    float ring = line(r - band * (0.42 + 0.22 * petal) * pulse, w);
    float ring2 = line(r - band * 0.7 * pulse, w * 0.8);
    float core = 1.0 - smoothstep(band * 0.1, band * 0.16, r);
    bandCol = mix(bandCol, gold, clamp(ring + ring2 * 0.8 + core, 0.0, 1.0) * disc);
  }

  // A glint travelling around the frame.
  float run = (c.x + c.y) / max(uSize.x, 1.0) * 3.0 - uTime * 0.9;
  float glint = pow(max(0.0, sin(run * 3.14159)), 14.0);
  bandCol += uCore.rgb * glint * 0.18 * inBand;

  // The middle: parchment, or clear.
  float depth = max(d - inner, 0.0);
  float fibre = noise(vec2(frag.x * 0.5, frag.y * 0.07) / (cell * 0.12));
  float mottle = noise(frag / (cell * 1.4));
  vec3 paper = uCore.rgb * (1.0 + uPaper * (0.12 * (mottle - 0.5) + 0.06 * (fibre - 0.5)));
  float edge = smoothstep(0.0, band * 1.6, depth);
  paper = mix(paper * vec3(0.78, 0.62, 0.42), paper, mix(1.0, edge, uPaper));

  vec3 col = mix(paper, bandCol, inBand);
  float a = outer * mix(uCore.a, 1.0, inBand);
  fragColor = vec4(min(col, vec3(1.0)) * a, a);
}
