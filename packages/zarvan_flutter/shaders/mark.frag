#include <flutter/runtime_effect.glsl>

// An answer mark in the game's own style: an eight-pointed star medallion (the
// same star as the progress seals) edged in gold, carrying a calligraphic tick
// or isCross that is drawn in by a pen of light: thin where the pen enters,
// thick where it presses, thin where it lifts. When it is finished the
// medallion breathes and a few sparks circle it.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels (the medallion fills the middle ~70%, the
//             rest is room for its glow)
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold of the edge, pen and sparks
//   uArm    - the medallion's colour (green for right, red for wrong)
//   uCore   - the dark at its centre
//   uParams - x: 0 tick, 1 isCross; y: how much has been drawn, 0..1

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float box(vec2 p, float r) {
  return max(abs(p.x), abs(p.y)) - r;
}

// Distance to the segment a-b, and how far along it (0..1) the nearest point is.
vec2 seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return vec2(length(pa - ba * h), h);
}

// A brush-like pen: the width follows the pen's pressure along it.
// d: distance, t: position along the pen (0..1), drawn: how far it is drawn.
float pen(vec2 dt, float drawn, float w) {
  float t = dt.y;
  float press = 0.28 + 0.72 * pow(sin(3.14159 * clamp(t, 0.0, 1.0)), 0.7);
  float width = w * press;
  float inside = 1.0 - smoothstep(width * 0.8, width, dt.x);
  return inside * (1.0 - smoothstep(drawn - 0.02, drawn, t));
}

void main() {
  vec2 p = ((FlutterFragCoord().xy - uOrigin) / uSize - 0.5) * 2.0;
  float px = 2.0 / uSize.x;
  bool isCross = uParams.x > 0.5;
  float prog = clamp(uParams.y, 0.0, 1.0);
  float eased = 1.0 - pow(1.0 - prog, 2.0);
  float done = smoothstep(0.92, 1.0, prog);

  // The star medallion.
  float R = 0.36;
  vec2 p45 = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
  float outer = min(box(p, R), box(p45, R));
  float inner = min(box(p, R * 0.66), box(p45, R * 0.66));
  float body = 1.0 - smoothstep(-px, px, outer);

  float breathe = 0.5 + 0.5 * sin(uTime * 2.4);
  float r = length(p);
  float halo = exp(-max(outer, 0.0) * 7.0) * (0.3 + 0.25 * done * breathe);
  halo *= 1.0 - smoothstep(0.72, 1.0, r);
  halo *= smoothstep(0.0, 0.2, prog);

  vec3 col = mix(uCore.rgb, uArm.rgb, 0.55 + 0.35 * (1.0 - smoothstep(0.0, R, r)));
  col = mix(col, uArm.rgb * 1.25, (1.0 - smoothstep(-px, px, inner)) * 0.25);
  float edge = 1.0 - smoothstep(0.0, 0.03, abs(outer));
  float edge2 = 1.0 - smoothstep(0.0, 0.02, abs(inner));
  col = mix(col, uRim.rgb, clamp(edge + edge2 * 0.55, 0.0, 1.0));

  // The mark.
  vec3 ink = mix(uRim.rgb, vec3(1.0, 0.97, 0.88), 0.55);
  float m = 0.0;
  float head = 0.0;
  float w = 0.062;
  if (!isCross) {
    vec2 A = vec2(-0.15, 0.0);
    vec2 B = vec2(-0.05, 0.11);
    vec2 C = vec2(0.19, -0.14);
    float l1 = length(B - A);
    float l2 = length(C - B);
    float L = l1 + l2;
    float drawn = eased * L; // length drawn so far
    vec2 s1 = seg(p, A, B);
    vec2 s2 = seg(p, B, C);
    float t1 = s1.y * l1;       // length along from A
    float t2 = l1 + s2.y * l2;
    float a1 = pen(vec2(s1.x, t1 / L), drawn / L, w);
    float a2 = pen(vec2(s2.x, t2 / L), drawn / L, w);
    m = max(a1, a2);
    // The pen's bright tip while it is moving.
    float at = clamp(drawn, 0.0, L);
    vec2 tip = at <= l1 ? mix(A, B, at / l1) : mix(B, C, (at - l1) / l2);
    head = (1.0 - done) * smoothstep(0.0, 0.2, prog) * exp(-length(p - tip) * 26.0);
  } else {
    vec2 A1 = vec2(-0.14, -0.14);
    vec2 B1 = vec2(0.14, 0.14);
    vec2 A2 = vec2(0.14, -0.14);
    vec2 B2 = vec2(-0.14, 0.14);
    float firstDone = clamp(eased * 2.0, 0.0, 1.0);        // first pen, then second
    float secondDone = clamp(eased * 2.0 - 1.0, 0.0, 1.0);
    float a1 = pen(seg(p, A1, B1), firstDone, w * 0.95);
    float a2 = pen(seg(p, A2, B2), secondDone, w * 0.95);
    m = max(a1, a2);
    // Fine cracks that spread from the centre once the isCross is done.
    float crack = 0.0;
    crack = max(crack, 1.0 - smoothstep(0.0, 0.006, seg(p, vec2(0.02, 0.0), vec2(0.17, 0.02)).x));
    crack = max(crack, 1.0 - smoothstep(0.0, 0.006, seg(p, vec2(-0.02, 0.0), vec2(-0.17, -0.03)).x));
    crack = max(crack, 1.0 - smoothstep(0.0, 0.006, seg(p, vec2(0.0, -0.02), vec2(-0.02, -0.17)).x));
    crack = max(crack, 1.0 - smoothstep(0.0, 0.006, seg(p, vec2(0.0, 0.02), vec2(0.03, 0.17)).x));
    m = max(m, crack * done * 0.8);
    vec2 A = firstDone < 1.0 ? A1 : A2;
    vec2 B = firstDone < 1.0 ? B1 : B2;
    float f = firstDone < 1.0 ? firstDone : secondDone;
    head = (1.0 - done) * smoothstep(0.0, 0.2, prog) * exp(-length(p - mix(A, B, f)) * 26.0);
  }
  col = mix(col, ink, m * body);
  col += vec3(1.0, 0.95, 0.75) * head * 0.9;

  // Sparks circling the finished medallion.
  float sparks = 0.0;
  for (int i = 0; i < 5; i++) {
    float f = float(i);
    float ang = uTime * 0.9 + f * 1.2566;
    vec2 c = vec2(cos(ang), sin(ang)) * (0.55 + 0.05 * sin(uTime * 2.0 + f));
    float tw = 0.5 + 0.5 * sin(uTime * 5.0 + f * 2.3);
    sparks += exp(-length(p - c) * 55.0) * tw;
  }
  sparks *= done;

  vec3 lit = col * body + uArm.rgb * halo * (1.0 - body) + uRim.rgb * sparks * 0.8;
  float a = clamp(max(body, max(halo * 0.9, sparks * 0.7)), 0.0, 1.0);
  fragColor = vec4(min(lit, vec3(1.0)), a);
}
