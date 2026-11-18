#include <flutter/runtime_effect.glsl>

// A small eight-pointed seal for a step of progress: a star of two squares,
// teal inside and edged with gold. Upcoming steps are dim, the current one is
// bright and breathes light, and a done one carries a gold tick. The number of
// an upcoming or current step is drawn on top by the game as text.
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

float seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

void main() {
  vec2 p = ((FlutterFragCoord().xy - uOrigin) / uSize - 0.5) * 2.0;
  float px = 2.0 / uSize.x; // one pixel in these units
  float state = uParams.x;
  bool current = state > 0.5 && state < 1.5;
  bool done = state >= 1.5;

  vec2 p45 = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
  float outer = min(box(p, 0.62), box(p45, 0.62));
  float inner = min(box(p, 0.4), box(p45, 0.4));
  float w = max(px * 1.4, current ? 0.045 : 0.03);

  float breathe = 0.5 + 0.5 * sin(uTime * 2.2);
  float halo = current ? exp(-max(outer, 0.0) * 5.0) * (0.35 + 0.35 * breathe) : 0.0;

  float body = 1.0 - smoothstep(-px, px, outer);
  vec3 col = mix(uCore.rgb, uArm.rgb, done || current ? 0.75 : 0.4);
  col = mix(col, uArm.rgb * 1.2, (1.0 - smoothstep(-px, px, inner)) * (current ? 0.6 : 0.3));
  float dim = current ? 1.0 : (done ? 0.9 : 0.62);

  float edge = 1.0 - smoothstep(0.0, w, abs(outer));
  float edge2 = 1.0 - smoothstep(0.0, w * 0.7, abs(inner));
  col = mix(col, uRim.rgb, clamp(edge + edge2 * 0.6, 0.0, 1.0) * dim);

  if (done) {
    float t = seg(p, vec2(-0.3, 0.02), vec2(-0.1, 0.24));
    t = min(t, seg(p, vec2(-0.1, 0.24), vec2(0.3, -0.2)));
    col = mix(col, uRim.rgb, 1.0 - smoothstep(0.045, 0.045 + px * 1.5, t));
  }

  float bodyAlpha = body * (current || done ? 1.0 : 0.75);
  float a = max(bodyAlpha, halo);
  vec3 lit = col * bodyAlpha + uRim.rgb * halo * (1.0 - body);
  fragColor = vec4(min(lit, vec3(1.0)), a);
}
