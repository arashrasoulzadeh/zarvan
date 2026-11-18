#include <flutter/runtime_effect.glsl>

// A minimal line portrait of a poet (head, beard, headwear, shoulders), drawn
// with distance-field strokes so it needs no image. The drawing space is the
// 160 x 200 grid the portraits were designed on; the rect is stretched to it.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the line colour (alpha is its opacity)
//   uArm    - unused
//   uCore   - unused
//   uParams - x: beard length (0 = none), y: beard spread,
//             z: headwear (0 turban with tail, 1 turban, 2 tall sikke,
//                3 skull cap, 4 headband, 5 dervish hat, 6 scarf),
//             w: flags, a sum of 1 closed eyes, 2 feather, 4 collar, 8 woman

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

// A cubic Bezier as eight chords: close enough for strokes this thin.
float cubic(vec2 p, vec2 p0, vec2 c1, vec2 c2, vec2 p3) {
  float d = 1e9;
  vec2 prev = p0;
  for (int i = 1; i <= 8; i++) {
    float t = float(i) / 8.0;
    float u = 1.0 - t;
    vec2 cur = u * u * u * p0 + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * p3;
    d = min(d, seg(p, prev, cur));
    prev = cur;
  }
  return d;
}

float quad(vec2 p, vec2 a, vec2 c, vec2 b) {
  float d = 1e9;
  vec2 prev = a;
  for (int i = 1; i <= 5; i++) {
    float t = float(i) / 5.0;
    float u = 1.0 - t;
    vec2 cur = u * u * a + 2.0 * u * t * c + t * t * b;
    d = min(d, seg(p, prev, cur));
    prev = cur;
  }
  return d;
}

float ellipse(vec2 p, vec2 c, vec2 r) {
  return abs(length((p - c) / r) - 1.0) * min(r.x, r.y);
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 p = uv * vec2(160.0, 200.0);
  float scale = uSize.x / 160.0;

  float beardLen = uParams.x;
  float spread = uParams.y;
  int hat = int(uParams.z + 0.5);
  int flags = int(uParams.w + 0.5);
  bool closed = mod(float(flags), 2.0) >= 1.0;
  bool feather = mod(floor(float(flags) / 2.0), 2.0) >= 1.0;
  bool collar = mod(floor(float(flags) / 4.0), 2.0) >= 1.0;
  bool woman = mod(floor(float(flags) / 8.0), 2.0) >= 1.0;

  float thick = 1e9; // thick strokes (3.2 units)
  float thin = 1e9;  // thin strokes (2 units)

  // Face, eyes, brows, nose.
  thick = min(thick, ellipse(p, vec2(80.0, 91.0), vec2(28.0, 39.0)));
  if (closed) {
    thick = min(thick, quad(p, vec2(62.0, 89.0), vec2(68.0, 92.0), vec2(74.0, 89.0)));
    thick = min(thick, quad(p, vec2(86.0, 89.0), vec2(92.0, 92.0), vec2(98.0, 89.0)));
  } else {
    thick = min(thick, quad(p, vec2(62.0, 88.0), vec2(68.0, 84.0), vec2(74.0, 88.0)));
    thick = min(thick, quad(p, vec2(86.0, 88.0), vec2(92.0, 84.0), vec2(98.0, 88.0)));
  }
  thick = min(thick, quad(p, vec2(60.0, 80.0), vec2(68.0, 75.0), vec2(76.0, 79.0)));
  thick = min(thick, quad(p, vec2(84.0, 79.0), vec2(92.0, 75.0), vec2(100.0, 80.0)));
  thin = min(thin, quad(p, vec2(80.0, 90.0), vec2(76.0, 103.0), vec2(83.0, 107.0)));

  if (woman) {
    thin = min(thin, seg(p, vec2(60.0, 86.0), vec2(57.0, 83.0)));
    thin = min(thin, seg(p, vec2(74.0, 86.0), vec2(76.0, 83.0)));
    thin = min(thin, seg(p, vec2(86.0, 86.0), vec2(84.0, 83.0)));
    thin = min(thin, seg(p, vec2(100.0, 86.0), vec2(103.0, 83.0)));
    thin = min(thin, quad(p, vec2(72.0, 119.0), vec2(80.0, 115.0), vec2(88.0, 119.0)));
    thin = min(thin, quad(p, vec2(88.0, 119.0), vec2(80.0, 126.0), vec2(72.0, 119.0)));
  } else {
    thick = min(thick, quad(p, vec2(60.0, 111.0), vec2(70.0, 103.0), vec2(80.0, 111.0)));
    thick = min(thick, quad(p, vec2(80.0, 111.0), vec2(90.0, 103.0), vec2(100.0, 111.0)));
    thin = min(thin, quad(p, vec2(72.0, 120.0), vec2(80.0, 124.0), vec2(88.0, 120.0)));
  }

  // Beard.
  if (beardLen > 0.5) {
    float b = 128.0 + beardLen;
    thick = min(thick, cubic(p, vec2(52.0, 100.0), vec2(50.0 - 6.0 * spread, 132.0), vec2(66.0, b - 4.0), vec2(80.0, b)));
    thick = min(thick, cubic(p, vec2(80.0, b), vec2(94.0, b - 4.0), vec2(110.0 + 6.0 * spread, 132.0), vec2(108.0, 100.0)));
    thin = min(thin, cubic(p, vec2(66.0, 124.0), vec2(66.0, b - 24.0), vec2(72.0, b - 12.0), vec2(74.0, b - 8.0)));
    thin = min(thin, seg(p, vec2(80.0, 128.0), vec2(80.0, b - 12.0)));
    thin = min(thin, cubic(p, vec2(94.0, 124.0), vec2(94.0, b - 24.0), vec2(88.0, b - 12.0), vec2(86.0, b - 8.0)));
  }

  // Headwear.
  if (hat <= 1) {
    thick = min(thick, cubic(p, vec2(50.0, 66.0), vec2(48.0, 28.0), vec2(112.0, 28.0), vec2(110.0, 66.0)));
    thin = min(thin, cubic(p, vec2(52.0, 58.0), vec2(72.0, 46.0), vec2(94.0, 46.0), vec2(108.0, 58.0)));
    thick = min(thick, cubic(p, vec2(52.0, 70.0), vec2(72.0, 60.0), vec2(92.0, 60.0), vec2(108.0, 70.0)));
    if (hat == 0) {
      thick = min(thick, cubic(p, vec2(108.0, 56.0), vec2(132.0, 66.0), vec2(132.0, 100.0), vec2(122.0, 124.0)));
    }
  } else if (hat == 2) {
    thick = min(thick, seg(p, vec2(58.0, 70.0), vec2(62.0, 12.0)));
    thick = min(thick, cubic(p, vec2(62.0, 12.0), vec2(70.0, 6.0), vec2(90.0, 6.0), vec2(98.0, 12.0)));
    thick = min(thick, seg(p, vec2(98.0, 12.0), vec2(102.0, 70.0)));
    thick = min(thick, seg(p, vec2(58.0, 60.0), vec2(102.0, 60.0)));
    thick = min(thick, cubic(p, vec2(59.0, 70.0), vec2(72.0, 64.0), vec2(90.0, 64.0), vec2(101.0, 70.0)));
  } else if (hat == 3) {
    thick = min(thick, cubic(p, vec2(52.0, 68.0), vec2(54.0, 38.0), vec2(106.0, 38.0), vec2(108.0, 68.0)));
    thick = min(thick, cubic(p, vec2(52.0, 68.0), vec2(72.0, 60.0), vec2(90.0, 60.0), vec2(108.0, 68.0)));
  } else if (hat == 4) {
    thick = min(thick, cubic(p, vec2(52.0, 70.0), vec2(70.0, 58.0), vec2(92.0, 58.0), vec2(108.0, 70.0)));
    thin = min(thin, cubic(p, vec2(52.0, 72.0), vec2(44.0, 92.0), vec2(46.0, 112.0), vec2(54.0, 124.0)));
    thin = min(thin, cubic(p, vec2(108.0, 72.0), vec2(116.0, 92.0), vec2(114.0, 112.0), vec2(106.0, 124.0)));
    thin = min(thin, cubic(p, vec2(62.0, 62.0), vec2(70.0, 36.0), vec2(90.0, 36.0), vec2(98.0, 62.0)));
  } else if (hat == 5) {
    thick = min(thick, cubic(p, vec2(54.0, 70.0), vec2(50.0, 18.0), vec2(110.0, 18.0), vec2(106.0, 70.0)));
    thin = min(thin, cubic(p, vec2(56.0, 58.0), vec2(72.0, 52.0), vec2(90.0, 52.0), vec2(104.0, 58.0)));
    thick = min(thick, cubic(p, vec2(52.0, 70.0), vec2(72.0, 62.0), vec2(90.0, 62.0), vec2(108.0, 70.0)));
  } else {
    thick = min(thick, cubic(p, vec2(52.0, 90.0), vec2(44.0, 40.0), vec2(116.0, 40.0), vec2(108.0, 90.0)));
    thick = min(thick, cubic(p, vec2(50.0, 100.0), vec2(40.0, 130.0), vec2(46.0, 170.0), vec2(36.0, 196.0)));
    thick = min(thick, cubic(p, vec2(110.0, 100.0), vec2(120.0, 130.0), vec2(114.0, 170.0), vec2(124.0, 196.0)));
    thin = min(thin, cubic(p, vec2(52.0, 76.0), vec2(62.0, 60.0), vec2(98.0, 60.0), vec2(108.0, 76.0)));
  }
  if (feather) {
    thin = min(thin, cubic(p, vec2(80.0, 28.0), vec2(84.0, 14.0), vec2(96.0, 10.0), vec2(100.0, 4.0)));
  }

  // Neck and shoulders (a dervish has his own).
  thick = min(thick, seg(p, vec2(70.0, 128.0), vec2(68.0, 152.0)));
  thick = min(thick, seg(p, vec2(90.0, 128.0), vec2(92.0, 152.0)));
  if (hat == 5) {
    thick = min(thick, cubic(p, vec2(30.0, 200.0), vec2(34.0, 172.0), vec2(50.0, 160.0), vec2(68.0, 152.0)));
    thick = min(thick, cubic(p, vec2(130.0, 200.0), vec2(126.0, 172.0), vec2(110.0, 160.0), vec2(92.0, 152.0)));
  } else {
    float l = woman ? 20.0 : 8.0;
    float r = woman ? 140.0 : 152.0;
    thick = min(thick, cubic(p, vec2(l, 200.0), vec2(l + 10.0, 168.0), vec2(48.0, 160.0), vec2(68.0, 152.0)));
    thick = min(thick, cubic(p, vec2(r, 200.0), vec2(r - 10.0, 168.0), vec2(112.0, 160.0), vec2(92.0, 152.0)));
  }
  if (collar) {
    thin = min(thin, seg(p, vec2(68.0, 152.0), vec2(80.0, 176.0)));
    thin = min(thin, seg(p, vec2(80.0, 176.0), vec2(92.0, 152.0)));
  }

  float pxThick = (thick - 1.6) * scale;
  float pxThin = (thin - 1.0) * scale;
  float line = max(1.0 - smoothstep(-0.5, 0.8, pxThick), 1.0 - smoothstep(-0.5, 0.8, pxThin));
  // A soft shimmer so the drawing feels alive without moving.
  float shimmer = 0.92 + 0.08 * sin(uTime * 1.4 + p.y * 0.05);
  float a = line * uRim.a * shimmer;
  fragColor = vec4(uRim.rgb * a, a);
}
