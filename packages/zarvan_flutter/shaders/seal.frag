#include <flutter/runtime_effect.glsl>

// A small eight-pointed seal for a step of progress: a star of two squares,
// teal inside and edged with gold. Upcoming steps are dim, the current one is
// bright, breathes light, throws slow rays and has sparks circling it, and a
// done one carries a gold brush tick. The glow stays inside the rect (the
// star fills only its middle ~70%), so nothing is cut off at the edge. The
// number of an upcoming or current step is drawn on top by the game as text.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - gold
//   uArm    - teal
//   uCore   - the dark of the inner star
//   uParams - x: 0 upcoming, 1 current, 2 done

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

vec2 seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return vec2(length(pa - ba * h), h);
}

void main() {
  vec2 p = ((FlutterFragCoord().xy - uOrigin) / uSize - 0.5) * 2.0;
  float px = 2.0 / uSize.x; // one pixel in these units
  float state = uParams.x;
  bool current = state > 0.5 && state < 1.5;
  bool done = state >= 1.5;
  float r = length(p);

  float R = 0.34;
  vec2 p45 = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
  float outer = min(box(p, R), box(p45, R));
  float inner = min(box(p, R * 0.64), box(p45, R * 0.64));
  float w = max(px * 1.4, current ? 0.026 : 0.018);

  float breathe = 0.5 + 0.5 * sin(uTime * 2.2);
  float fadeOut = 1.0 - smoothstep(0.6, 1.0, r); // nothing reaches the rect edge
  float halo = current ? exp(-max(outer, 0.0) * 7.0) * (0.35 + 0.35 * breathe) * fadeOut : 0.0;

  // Slow rays behind the current seal, turning.
  float rays = 0.0;
  if (current) {
    float ang = atan(p.y, p.x);
    float spin = uTime * 0.35;
    float ray = pow(max(0.0, cos((ang - spin) * 8.0)), 24.0);
    rays = ray * smoothstep(R * 0.9, R * 1.4, r) * (1.0 - smoothstep(0.55, 0.92, r)) * (0.5 + 0.4 * breathe);
  }

  // Sparks circling the current seal.
  float sparks = 0.0;
  if (current) {
    for (int i = 0; i < 3; i++) {
      float f = float(i);
      float a = uTime * 0.8 + f * 2.0944;
      vec2 c = vec2(cos(a), sin(a)) * (0.56 + 0.04 * sin(uTime * 2.0 + f));
      float tw = 0.5 + 0.5 * sin(uTime * 4.0 + f * 2.1);
      sparks += exp(-length(p - c) * 60.0) * tw;
    }
  }

  float body = 1.0 - smoothstep(-px, px, outer);
  vec3 col = mix(uCore.rgb, uArm.rgb, done || current ? 0.75 : 0.4);
  col = mix(col, uArm.rgb * 1.2, (1.0 - smoothstep(-px, px, inner)) * (current ? 0.6 : 0.3));
  float dim = current ? 1.0 : (done ? 0.9 : 0.62);

  float edge = 1.0 - smoothstep(0.0, w, abs(outer));
  float edge2 = 1.0 - smoothstep(0.0, w * 0.7, abs(inner));
  col = mix(col, uRim.rgb, clamp(edge + edge2 * 0.6, 0.0, 1.0) * dim);

  if (done) {
    // A brush tick: thin where the pen enters, thick where it presses.
    vec2 A = vec2(-0.14, 0.0);
    vec2 B = vec2(-0.05, 0.10);
    vec2 C = vec2(0.17, -0.12);
    vec2 s1 = seg(p, A, B);
    vec2 s2 = seg(p, B, C);
    float l1 = length(B - A);
    float l2 = length(C - B);
    float L = l1 + l2;
    float t1 = s1.y * l1 / L;
    float t2 = (l1 + s2.y * l2) / L;
    float w1 = 0.05 * (0.28 + 0.72 * pow(sin(3.14159 * t1), 0.7));
    float w2 = 0.05 * (0.28 + 0.72 * pow(sin(3.14159 * t2), 0.7));
    float tick = max(1.0 - smoothstep(w1 * 0.8, w1, s1.x), 1.0 - smoothstep(w2 * 0.8, w2, s2.x));
    col = mix(col, mix(uRim.rgb, vec3(1.0, 0.97, 0.88), 0.5), tick);
  }

  float bodyAlpha = body * (current || done ? 1.0 : 0.75);
  float glowA = max(halo, max(rays * 0.8, sparks * 0.8));
  float a = max(bodyAlpha, glowA);
  vec3 lit = col * bodyAlpha + uRim.rgb * (halo * 0.9 + rays * 0.7 + sparks) * (1.0 - body);
  fragColor = vec4(min(lit, vec3(1.0)), a);
}
