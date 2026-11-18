#include <flutter/runtime_effect.glsl>

// Lanterns lifting a page: the frozen screen that is leaving hangs from
// strings tied to a row of paper lanterns, and they carry it up and off the
// top while the next screen is revealed underneath. Three layers of lanterns
// (far, middle, near) sway and flicker; each glows warm and lights the page's
// underside and the air around it. Progress 0 = the page hangs in place,
// 1 = it and the lanterns are gone.
//
//   uSize      - size of the rect being painted, in canvas units
//   uImageSize - size of the snapshot (unused: the sampler is normalised)
//   uProgress  - 0..1
//   uImage     - the snapshot

uniform vec2 uSize;
uniform vec2 uImageSize;
uniform float uProgress;
uniform sampler2D uImage;

out vec4 fragColor;

float hash(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

// One lantern at centre c (in uv), with half-width w: returns body coverage in
// x, glow in y, and the paper's warmth (brighter toward the flame) in z.
vec3 lantern(vec2 uv, vec2 c, float w, float aspect, float flick) {
  vec2 q = (uv - c) * vec2(aspect, 1.0) / w;
  // A rounded paper body, slightly taller than wide, with a flat top and base.
  float body = length(vec2(q.x, q.y * 0.78)) - 1.0;
  body = max(body, abs(q.y) - 1.25);
  float cover = 1.0 - smoothstep(-0.04, 0.04, body);
  float glow = exp(-max(body, 0.0) * 4.5) * flick;
  float heat = (1.0 - clamp(length(vec2(q.x, q.y * 0.9)), 0.0, 1.0)) * flick;
  // Paper ribs.
  float rib = 0.5 + 0.5 * cos(q.x * 9.0);
  return vec3(cover * (0.55 + 0.45 * rib), glow, heat);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;
  float aspect = uSize.x / uSize.y;
  float t = clamp(uProgress, 0.0, 1.0);
  float ease = t * t * (3.0 - 2.0 * t);

  // The page rises: its lower edge goes from the bottom to above the top.
  float rise = ease * 1.22;
  float edge = 1.0 - rise; // the page's bottom edge, in screen y
  float sway = 0.006 * sin(t * 9.0 + uv.y * 3.0) * (1.0 - t * 0.5);

  vec3 col = vec3(0.0);
  float alpha = 0.0;

  // The page itself.
  if (uv.y <= edge) {
    vec2 src = vec2(uv.x + sway, uv.y + rise);
    vec4 c = texture(uImage, clamp(src, 0.0, 1.0));
    col = c.rgb;
    alpha = c.a;
    // Lit from below by the lanterns, strongest at the lower edge.
    float lit = exp(-(edge - uv.y) * 9.0);
    col += vec3(1.0, 0.62, 0.22) * lit * 0.32 * (1.0 - smoothstep(0.85, 1.0, t));
    // A faint darkening at the bottom lip, as if it had thickness.
    col *= 1.0 - 0.06 * smoothstep(0.02, 0.0, edge - uv.y);
  }

  // Lanterns, far to near.
  vec3 warm = vec3(1.0, 0.55, 0.18);
  vec3 hot = vec3(1.0, 0.86, 0.5);
  vec3 add = vec3(0.0);
  float addA = 0.0;
  float fade = 1.0 - smoothstep(0.86, 1.0, t);
  for (int layer = 0; layer < 3; layer++) {
    float L = float(layer);
    float cols = 5.0 + L * 1.0;
    float size = 0.034 + 0.02 * L; // half width in screen-width units
    float hang = 0.12 + 0.13 * L;  // how far below the edge they hang
    float colIdx = floor(uv.x * cols);
    for (int dx = -1; dx <= 1; dx++) {
      float ci = colIdx + float(dx);
      float seed = ci * 7.31 + L * 31.7;
      float cx = (ci + 0.25 + 0.5 * hash(seed)) / cols;
      float bob = 0.012 * sin(t * 11.0 + hash(seed + 1.0) * 6.28);
      float drop = hang * (0.55 + 0.45 * hash(seed + 2.0)) * (1.0 - 0.75 * ease);
      vec2 c = vec2(cx + 0.012 * sin(t * 7.0 + seed), edge + drop + bob);
      float flick = 0.82 + 0.18 * sin(t * 53.0 + seed * 5.0) * sin(t * 31.0 + seed);
      vec3 l = lantern(uv, c, size, aspect, flick);
      // The string from the page's edge down to the lantern's top.
      float top = c.y - size * aspect * 1.25;
      float onString = step(abs((uv.x - c.x) * aspect), 0.0016 + 0.0004 * L)
                     * step(edge, uv.y) * step(uv.y, top);
      col = mix(col, vec3(0.9, 0.78, 0.5), onString * 0.8 * fade);
      alpha = max(alpha, onString * 0.8 * fade);
      // The lantern: paper body tinted by its flame, and its glow around.
      vec3 paper = mix(warm * 0.7, hot, l.z * l.z) * (0.75 + 0.25 * l.z);
      float a = l.x * fade;
      col = mix(col, paper, a);
      alpha = max(alpha, a);
      add = max(add, warm * l.y * 0.55 * fade);
      addA = max(addA, clamp(l.y * 0.32, 0.0, 0.4) * fade);
    }
  }
  // The glow lights what is behind the lanterns without covering their paper.
  col = max(col, add * 0.0) + add * (1.0 - alpha * 0.6);
  alpha = clamp(max(alpha, addA), 0.0, 1.0);
  fragColor = vec4(min(col, vec3(1.0)) * alpha, alpha);
}
