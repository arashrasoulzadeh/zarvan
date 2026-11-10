#include <flutter/runtime_effect.glsl>

// A magical doorway portal filling the whole rect, edge to edge, in chunky
// pixel steps: a bright glowing rim hugging the frame, a deep void inside
// whose clouds spiral in from the rim to a glowing core, light streaks falling
// down the opening, sparks rising, and a pool of light on the floor. Computed
// per pixel from the clock; no texture.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - see above; uImg0 / uImg1 are the pictures, bottom layer first
//   uRim    - colour of the deep void between the clouds
//   uArm    - colour of the spiral clouds and the rim glow
//   uCore   - colour of the core, the brightest rim, streaks and sparks

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
// x: pictures (0..2), y: blur (fraction of the image), z: share of the image's
// width the rect shows.
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform sampler2D uImg0;
uniform sampler2D uImg1;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  return 0.55 * noise(p) + 0.30 * noise(p * 2.1) + 0.15 * noise(p * 4.3);
}

// The blurred picture behind the portal: both layers composited, averaged over
// a ring of taps.
vec3 picture(vec2 uv) {
  vec2 c = vec2(0.5 + (uv.x - 0.5) * uPic.z, uv.y);
  vec3 sum = vec3(0.0);
  float w = 0.0;
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 0.5236;
    vec2 off = vec2(cos(a) * uPic.z, sin(a)) * uPic.y;
    for (int j = 0; j < 2; j++) {
      vec2 p = clamp(c + off * (0.5 + 0.5 * float(j)), 0.0, 1.0);
      vec4 b = texture(uImg0, p);
      vec3 col = b.rgb;
      if (uPic.x > 1.5) {
        vec4 f = texture(uImg1, p);
        col = mix(col, f.rgb, f.a);
      }
      sum += col;
      w += 1.0;
    }
  }
  return sum / w;
}

void main() {
  float t = uTime;
  vec2 cells = vec2(30.0, 30.0 * uSize.y / uSize.x);
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  vec2 px = (floor(uv * cells) + 0.5) / cells;

  // Round centred coordinates (narrow side spans -1..1).
  vec2 q = (px * 2.0 - 1.0) * uSize / min(uSize.x, uSize.y);
  float r = length(q);
  float ang = atan(q.y, q.x);

  // Clouds wound into a spiral that turns slowly.
  vec2 sp = vec2(ang / 6.2831853 * 3.0 + r * 1.4 - t * 0.12, r * 2.2 - t * 0.35);
  float n = fbm(sp * 2.0);
  n = floor(n * 5.0) / 5.0;
  float cloud = smoothstep(0.38, 0.72, n);

  vec3 col = mix(uRim.rgb * 0.62, uArm.rgb, cloud);
  if (uPic.x > 0.5) {
    // Show where the portal leads, warmed and dimmed a little, and let the
    // spiral clouds drift over it.
    vec3 pic = picture(px) * vec3(1.05, 0.95, 0.85) * 0.85;
    col = mix(pic, mix(pic, uArm.rgb, 0.6), cloud * 0.55);
  }

  // Glowing core.
  col = mix(col, uCore.rgb, smoothstep(0.42, 0.0, r) * 0.9);

  // Glowing rim hugging the frame, brighter along the bottom (floor glow).
  float edge = min(min(px.x, 1.0 - px.x) * uSize.x,
                   min(px.y, 1.0 - px.y) * uSize.y) / uSize.x;
  float rimN = 0.75 + 0.25 * noise(vec2(ang * 3.0 + t * 0.8, r * 4.0));
  float rim = smoothstep(0.22, 0.0, edge) * rimN;
  col = mix(col, mix(uArm.rgb, uCore.rgb, 0.55), rim);
  float pool = smoothstep(0.82, 1.0, px.y) * (0.65 + 0.35 * noise(vec2(px.x * 8.0, t)));
  col = mix(col, uCore.rgb, pool * 0.85);

  // Light streaks falling down the opening.
  float colId = floor(uv.x * cells.x);
  float hc = hash(vec2(colId, 3.0));
  float fall = fract(px.y * 0.8 - t * (0.25 + 0.35 * hc) + hc * 5.0);
  float streak = step(0.9, hc) * smoothstep(0.35, 0.0, fall) * 0.12;
  col += uCore.rgb * streak;

  // Sparks rising, one pixel each.
  float rise = floor(uv.y * cells.y + t * (3.0 + 5.0 * hc));
  float hs = hash(vec2(colId, rise));
  col += uCore.rgb * step(0.978, hs) * 0.9;

  col *= 0.94 + 0.06 * sin(t * 1.7);
  fragColor = vec4(min(col, vec3(1.0)), 1.0);
}
