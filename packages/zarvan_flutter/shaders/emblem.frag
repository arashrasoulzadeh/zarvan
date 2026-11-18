#include <flutter/runtime_effect.glsl>

// A small line-art emblem that says what a poet is known for: a wine cup, a
// rose, a reed flute, a jug, a book, a crown, a bird, a lute, a shepherd's
// staff or a quill. Drawn with distance-field strokes, edged with a soft glow,
// with a slow shimmer sweeping across and a twinkle in the corner.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels (the icon fills the middle ~70%)
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the line colour
//   uArm    - the glow colour
//   uCore   - unused
//   uParams - x: which emblem, 0 cup, 1 rose, 2 reed flute, 3 jug, 4 book,
//             5 crown, 6 bird, 7 lute, 8 staff, 9 quill

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float sg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

// Distance to the outline of an ellipse (approximate).
float el(vec2 p, vec2 c, vec2 r) {
  return abs(length((p - c) / r) - 1.0) * min(r.x, r.y);
}

float ci(vec2 p, vec2 c, float r) {
  return abs(length(p - c) - r);
}

float shape(vec2 p, int id) {
  float d = 1e9;
  if (id == 0) { // wine cup
    float bowl = el(p, vec2(0.0, -0.2), vec2(0.55, 0.5));
    if (p.y >= -0.2) d = min(d, bowl);
    d = min(d, sg(p, vec2(-0.55, -0.2), vec2(0.55, -0.2)));
    d = min(d, sg(p, vec2(0.0, 0.3), vec2(0.0, 0.62)));
    d = min(d, sg(p, vec2(-0.34, 0.66), vec2(0.34, 0.66)));
    d = min(d, ci(p, vec2(0.0, 0.0), 0.04));
  } else if (id == 1) { // rose
    d = min(d, ci(p, vec2(0.0, -0.18), 0.4));
    d = min(d, ci(p, vec2(0.04, -0.2), 0.24));
    d = min(d, ci(p, vec2(0.0, -0.16), 0.09));
    d = min(d, sg(p, vec2(0.0, 0.22), vec2(0.05, 0.82)));
    d = min(d, el(p, vec2(0.27, 0.52), vec2(0.22, 0.1)));
    d = min(d, el(p, vec2(-0.22, 0.62), vec2(0.18, 0.08)));
  } else if (id == 2) { // reed flute (ney)
    vec2 a = vec2(-0.7, 0.72);
    vec2 b = vec2(0.7, -0.72);
    d = min(d, abs(sg(p, a, b) - 0.11));
    for (int i = 0; i < 4; i++) {
      d = min(d, ci(p, mix(a, b, 0.3 + 0.13 * float(i)), 0.035));
    }
    d = min(d, sg(p, a + vec2(-0.06, -0.06), a + vec2(0.06, 0.06)));
  } else if (id == 3) { // jug
    d = min(d, el(p, vec2(0.0, 0.22), vec2(0.45, 0.5)));
    d = min(d, sg(p, vec2(-0.16, -0.22), vec2(-0.12, -0.62)));
    d = min(d, sg(p, vec2(0.16, -0.22), vec2(0.12, -0.62)));
    d = min(d, sg(p, vec2(-0.22, -0.66), vec2(0.22, -0.66)));
    if (p.x > 0.42) d = min(d, ci(p, vec2(0.5, 0.08), 0.26));
  } else if (id == 4) { // open book
    d = min(d, sg(p, vec2(-0.72, -0.45), vec2(-0.04, -0.3)));
    d = min(d, sg(p, vec2(-0.04, -0.3), vec2(-0.04, 0.55)));
    d = min(d, sg(p, vec2(-0.04, 0.55), vec2(-0.72, 0.42)));
    d = min(d, sg(p, vec2(-0.72, 0.42), vec2(-0.72, -0.45)));
    d = min(d, sg(p, vec2(0.72, -0.45), vec2(0.04, -0.3)));
    d = min(d, sg(p, vec2(0.04, -0.3), vec2(0.04, 0.55)));
    d = min(d, sg(p, vec2(0.04, 0.55), vec2(0.72, 0.42)));
    d = min(d, sg(p, vec2(0.72, 0.42), vec2(0.72, -0.45)));
    d = min(d, sg(p, vec2(-0.56, -0.18), vec2(-0.2, -0.1)));
    d = min(d, sg(p, vec2(-0.56, 0.04), vec2(-0.2, 0.12)));
    d = min(d, sg(p, vec2(0.56, -0.18), vec2(0.2, -0.1)));
    d = min(d, sg(p, vec2(0.56, 0.04), vec2(0.2, 0.12)));
  } else if (id == 5) { // crown
    vec2 q0 = vec2(-0.62, 0.45);
    vec2 q1 = vec2(-0.68, -0.38);
    vec2 q2 = vec2(-0.32, 0.05);
    vec2 q3 = vec2(0.0, -0.52);
    vec2 q4 = vec2(0.32, 0.05);
    vec2 q5 = vec2(0.68, -0.38);
    vec2 q6 = vec2(0.62, 0.45);
    d = min(d, sg(p, q0, q1));
    d = min(d, sg(p, q1, q2));
    d = min(d, sg(p, q2, q3));
    d = min(d, sg(p, q3, q4));
    d = min(d, sg(p, q4, q5));
    d = min(d, sg(p, q5, q6));
    d = min(d, sg(p, q6, q0));
    d = min(d, ci(p, q1 + vec2(0.0, -0.1), 0.04));
    d = min(d, ci(p, q3 + vec2(0.0, -0.1), 0.04));
    d = min(d, ci(p, q5 + vec2(0.0, -0.1), 0.04));
  } else if (id == 6) { // bird
    d = min(d, el(p, vec2(-0.06, 0.1), vec2(0.42, 0.27)));
    d = min(d, ci(p, vec2(0.36, -0.14), 0.15));
    d = min(d, sg(p, vec2(0.5, -0.18), vec2(0.76, -0.1)));
    d = min(d, sg(p, vec2(0.76, -0.1), vec2(0.5, -0.06)));
    d = min(d, sg(p, vec2(-0.46, 0.04), vec2(-0.9, -0.2)));
    d = min(d, sg(p, vec2(-0.46, 0.16), vec2(-0.9, 0.06)));
    d = min(d, sg(p, vec2(-0.3, 0.06), vec2(-0.05, -0.2)));
    d = min(d, sg(p, vec2(-0.05, -0.2), vec2(0.18, 0.02)));
    d = min(d, sg(p, vec2(-0.06, 0.37), vec2(-0.1, 0.66)));
    d = min(d, sg(p, vec2(0.12, 0.36), vec2(0.14, 0.66)));
    d = min(d, ci(p, vec2(0.4, -0.16), 0.02));
  } else if (id == 7) { // lute
    d = min(d, el(p, vec2(-0.16, 0.26), vec2(0.42, 0.5)));
    d = min(d, sg(p, vec2(0.0, -0.1), vec2(0.52, -0.72)));
    d = min(d, sg(p, vec2(0.14, 0.0), vec2(0.68, -0.62)));
    d = min(d, sg(p, vec2(0.5, -0.8), vec2(0.78, -0.54)));
    d = min(d, ci(p, vec2(-0.16, 0.26), 0.13));
  } else if (id == 8) { // shepherd's staff
    d = min(d, sg(p, vec2(0.0, 0.82), vec2(0.0, -0.42)));
    if (p.y <= -0.42) d = min(d, ci(p, vec2(0.26, -0.42), 0.26));
    d = min(d, ci(p, vec2(0.0, 0.82), 0.04));
    d = min(d, sg(p, vec2(-0.2, 0.7), vec2(0.2, 0.7)));
  } else { // quill
    vec2 a = vec2(-0.62, 0.72);
    vec2 b = vec2(0.62, -0.72);
    vec2 ba = b - a;
    float t = clamp(dot(p - a, ba) / dot(ba, ba), 0.0, 1.0);
    float ds = sg(p, a, b);
    d = min(d, ds);
    if (t > 0.22) {
      float w = 0.24 * sin(3.14159 * clamp((t - 0.22) / 0.78, 0.0, 1.0));
      d = min(d, abs(ds - w));
    }
    d = min(d, sg(p, a, a + vec2(-0.12, 0.16)));
    d = min(d, ci(p, a + vec2(-0.2, 0.26), 0.05));
  }
  return d;
}

void main() {
  vec2 p = ((FlutterFragCoord().xy - uOrigin) / uSize - 0.5) * 2.0;
  p /= 0.72; // the icon fills the middle of the rect, leaving room for its glow
  float px = 2.0 / uSize.x / 0.72;
  int id = int(uParams.x + 0.5);
  float d = shape(p, id);

  float w = 0.075;
  float ink = 1.0 - smoothstep(w - px, w + px, d);
  float glow = exp(-max(d - w, 0.0) * 5.5) * 0.45;
  glow *= 1.0 - smoothstep(0.9, 1.4, length(p));

  // A shimmer sweeping slowly across the icon, and a twinkle in the corner.
  float shimmer = pow(max(0.0, sin((p.x - p.y) * 2.2 - uTime * 1.6)), 14.0);
  vec3 line = mix(uRim.rgb, vec3(1.0, 0.97, 0.88), shimmer * 0.8);
  float tw = 0.5 + 0.5 * sin(uTime * 3.0);
  float star = exp(-length(p - vec2(0.82, -0.82)) * 11.0) * tw;

  vec3 col = line * ink + uArm.rgb * glow * (1.0 - ink) + vec3(1.0, 0.95, 0.8) * star;
  float a = clamp(max(ink, max(glow * 0.9, star)), 0.0, 1.0);
  fragColor = vec4(min(col, vec3(1.0)), a);
}
