#include <flutter/runtime_effect.glsl>

// A screen transition in the game's own style: Persian tilework. The screen is
// a grid of tiles that flip over one after another, spreading outward from a
// point. Each tile carries the same motifs as the ornate frames: an eight-
// pointed star in gold lines on teal, a ring and dot in the middle, and a
// diamond in every corner, with a flash of gold as it turns. Progress 0 -> 1
// tiles the screen, 1 -> 0 turns the tiles back.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold lines and flash
//   uArm    - the tile teal
//   uCore   - the darker tile body and the grout
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

float box(vec2 p, float r) {
  return max(abs(p.x), abs(p.y)) - r;
}

float line(float d, float w) {
  return 1.0 - smoothstep(0.0, w, abs(d));
}

void main() {
  float prog = clamp(uParams.x, 0.0, 1.0);
  if (prog <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float aspect = uSize.x / uSize.y;

  const float rows = 9.0;
  vec2 g = vec2(uv.x * aspect, uv.y) * rows;
  vec2 id = floor(g);
  vec2 f = fract(g) - 0.5;

  // When this tile turns: nearest the origin first, a little jittered.
  vec2 cell = (id + 0.5) / rows;
  vec2 origin = vec2(uParams.y * aspect, uParams.z);
  vec2 far = max(origin, vec2(aspect, 1.0) - origin);
  float reach = length(far) + 0.2;
  float delay = length(cell - origin) / reach * 0.9 + hash(id) * 0.1;
  float lp = clamp((prog * 1.75 - delay) / 0.55, 0.0, 1.0);
  if (lp <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // The tile turns about its middle and grows into place.
  float turn = (1.0 - lp) * 1.5708;
  float grow = 1.0 - pow(1.0 - lp, 3.0);
  mat2 r = mat2(cos(turn), -sin(turn), sin(turn), cos(turn));
  vec2 q = (r * f) / max(grow, 0.001);
  float inTile = 1.0 - smoothstep(0.495, 0.505, max(abs(q.x), abs(q.y)));
  if (inTile <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // The tile's face.
  float checker = mod(id.x + id.y, 2.0);
  vec3 body = mix(uCore.rgb, uArm.rgb * 0.55, 0.45 + 0.35 * checker);
  float lw = 0.018;
  vec2 q45 = vec2(q.x + q.y, q.y - q.x) * 0.70710678;
  float star = min(box(q, 0.34), box(q45, 0.34));
  float star2 = min(box(q, 0.2), box(q45, 0.2));
  float ring = length(q) - 0.1;
  vec3 col = body;
  col = mix(col, uArm.rgb, (1.0 - smoothstep(-0.02, 0.02, star)) * 0.7);
  col = mix(col, uCore.rgb * 1.2, (1.0 - smoothstep(-0.02, 0.02, star2)) * 0.5);
  float lines = max(max(line(star, lw), line(star2, lw * 0.8)), line(ring, lw));
  lines = max(lines, 1.0 - smoothstep(0.0, 0.035, length(q) - 0.025));
  // A diamond in each corner, and the tile's own edge.
  vec2 cq = abs(q) - 0.5;
  lines = max(lines, line(abs(cq.x) + abs(cq.y) - 0.17, lw));
  lines = max(lines, line(max(abs(q.x), abs(q.y)) - 0.47, lw * 0.9));
  col = mix(col, uRim.rgb, lines * 0.92);

  // A flash of gold as the tile turns, and a slow glint once it has settled.
  float flash = sin(lp * 3.14159);
  col += uRim.rgb * flash * 0.55;
  float glint = pow(max(0.0, sin(uTime * 1.3 + (id.x + id.y) * 0.9)), 18.0);
  col += uRim.rgb * glint * 0.12 * lp;

  float a = inTile * smoothstep(0.0, 0.12, lp);
  fragColor = vec4(min(col, vec3(1.0)) * a, a);
}
