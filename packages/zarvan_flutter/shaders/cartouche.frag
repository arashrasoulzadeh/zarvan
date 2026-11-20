#include <flutter/runtime_effect.glsl>

// A gilded Persian cartouche, drawn entirely in the shader, in two shapes:
//
//   banner - a long panel whose ends draw out to points, with a gold
//            medallion on the middle of its top and bottom edges, filled with
//            green velvet or with parchment;
//   arch   - a tall card with a pointed arch for a crown: parchment edged
//            with a border of tiny flowers around a window of colour (where a
//            portrait is drawn on top), and a scalloped parchment plaque for a
//            name across its foot.
//
// Both have a bevelled gold band with light running along it, and a thin line
// inside it.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels (the shape fills it exactly: put any glow
//             in another effect)
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold
//   uArm    - the blue of the thin line and the medallions
//   uCore   - banner: the velvet (used when parchment is off); arch: the
//             colour of the window
//   uParams - x: 0 banner, 1 arch, 2 card (a wide panel for text: parchment in
//                a blue vine band, medallions on its peaks, sprays of blossom in
//                its corners; w is then how much of those sprays show)
//                3 dialog (a tall panel: deep blue paper edged in gold with sprays of
//                blossom in its corners, a parchment header that narrows to a peak
//                at the top, medallions on its peaks; w is the header's height as
//                a share of the panel's)
//             y: 0..1 how brightly the gold gleams (a lit or chosen card)
//             z: banner: 1 for parchment, 0 for velvet
//             w: arch: the plaque's share of the card's height (0 for none);
//                banner: 0..1 how much the sprays of flowers at its ends show
//                (they sway a little and are clipped to the banner)

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
// uPic.y is the effect's `blur` here: 0 shows it, 1 hides it, so a caller can
// fade a cartouche in and out.
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
  for (int i = 0; i < 3; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(17.1, 9.7);
    a *= 0.5;
  }
  return v;
}

float sdRoundBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// ---- Outlines: each returns how far inside the shape a point is. ----

// Half the banner's height at x: full along the middle, drawing out to a point
// at each end, with a small peak under the medallions.
float bannerH(float x, vec2 hs) {
  float u = clamp(abs(x) / hs.x, 0.0, 1.0);
  float t = clamp((u - 0.8) / 0.2, 0.0, 1.0);
  float ends = (1.0 - smoothstep(0.0, 1.0, t)) * 0.55 + (1.0 - t) * 0.45;
  float peak = 0.1 * hs.y * exp(-pow(x / (hs.x * 0.07), 2.0));
  return (0.8 * hs.y + peak) * ends;
}

float depthBanner(vec2 c, vec2 hs) {
  float h = bannerH(c.x, hs);
  float slope = (bannerH(c.x + 1.0, hs) - bannerH(c.x - 1.0, hs)) * 0.5;
  float d = (h - abs(c.y)) / sqrt(1.0 + slope * slope);
  return min(d, hs.x - abs(c.x));
}

// The crown of the arch: pointed at the middle, falling to the shoulders.
float archTop(float x, vec2 hs) {
  float u = clamp(abs(x) / hs.x, 0.0, 1.0);
  return -hs.y + hs.y * 0.3 * (0.5 * u + 0.5 * smoothstep(0.08, 0.85, u));
}

// The poem card: a wide panel with rounded corners and a low peak at the
// middle of its top and bottom edges, [pk] tall.
float cardH(float x, vec2 hs, float pk) {
  return hs.y - pk + pk * exp(-pow(x / (hs.x * 0.16), 2.0));
}

float depthCard(vec2 c, vec2 hs, float pk) {
  vec2 box = vec2(hs.x, hs.y - pk);
  float dBox = -sdRoundBox(c, box, hs.x * 0.07);
  float h = cardH(c.x, hs, pk);
  float slope = (cardH(c.x + 1.0, hs, pk) - cardH(c.x - 1.0, hs, pk)) * 0.5;
  float dPeak = min((h - abs(c.y)) / sqrt(1.0 + slope * slope), hs.x * 0.5 - abs(c.x));
  return max(dBox, dPeak);
}

float dialogH(float x, vec2 hs, float pk) {
  return hs.y - pk + pk * exp(-pow(x / (hs.x * 0.26), 2.0));
}

float depthDialog(vec2 c, vec2 hs, float pk) {
  vec2 box = vec2(hs.x, hs.y - pk);
  float dBox = -sdRoundBox(c, box, hs.x * 0.1);
  float h = dialogH(c.x, hs, pk);
  float slope = (dialogH(c.x + 1.0, hs, pk) - dialogH(c.x - 1.0, hs, pk)) * 0.5;
  float dPeak = min((h - abs(c.y)) / sqrt(1.0 + slope * slope), hs.x * 0.5 - abs(c.x));
  return max(dBox, dPeak);
}

float depthArch(vec2 c, vec2 hs) {
  float side = -sdRoundBox(c, hs, hs.x * 0.3);
  float top = archTop(c.x, hs);
  float slope = (archTop(c.x + 1.0, hs) - archTop(c.x - 1.0, hs)) * 0.5;
  return min(side, (c.y - top) / sqrt(1.0 + slope * slope));
}

// ---- Small ornaments. ----

// A quatrefoil medallion at the origin of [p], radius [r]: a gold rim, a blue
// field and a small gold flower with an orange heart. rgb and coverage.
vec4 medallion(vec2 p, float r, vec3 gold, vec3 blue) {
  float rad = length(p);
  float ang = atan(p.y, p.x);
  float shape = r * (0.8 + 0.2 * cos(4.0 * ang));
  float cover = 1.0 - smoothstep(shape - 0.8, shape + 0.8, rad);
  if (cover <= 0.0) return vec4(0.0);
  float rim = smoothstep(shape - r * 0.2, shape - r * 0.12, rad);
  vec3 col = mix(blue, gold * 1.05, rim);
  float fl = r * 0.5 * (0.72 + 0.28 * cos(6.0 * ang));
  float petal = 1.0 - smoothstep(fl - 0.6, fl + 0.6, rad);
  col = mix(col, gold * 1.1 + 0.08, petal * (1.0 - rim));
  col = mix(col, vec3(0.95, 0.45, 0.15), (1.0 - smoothstep(r * 0.1, r * 0.16, rad)) * (1.0 - rim));
  return vec4(col, cover);
}

// A tiny five-petalled flower at [p], radius [r]. rgb and coverage.
vec4 floret(vec2 p, float r, vec3 petals) {
  float rad = length(p);
  float ang = atan(p.y, p.x);
  float shape = r * (0.62 + 0.38 * pow(abs(cos(2.5 * ang)), 0.6));
  float cover = 1.0 - smoothstep(shape - 0.06, shape + 0.06, rad / 1.0);
  vec3 col = mix(petals, vec3(1.0, 0.82, 0.3), 1.0 - smoothstep(0.1 * r, 0.3 * r, rad));
  return vec4(col, cover);
}

// An ellipse centred at [c], turned by [ang], semi-axes [a] and [b]: how far
// inside it (negative) or outside (positive), roughly.
float ellipse(vec2 p, vec2 c, float ang, vec2 ab) {
  vec2 q = p - c;
  vec2 r = vec2(cos(ang) * q.x + sin(ang) * q.y, -sin(ang) * q.x + cos(ang) * q.y);
  return (length(r / ab) - 1.0) * min(ab.x, ab.y);
}

// A five-petalled blossom at the origin of [p], radius [r]: white at the rim
// blushing to [tint] toward a golden heart. rgb and coverage.
vec4 blossom5(vec2 p, float r, float rot, vec3 tint) {
  float rad = length(p);
  float ang = atan(p.y, p.x) + rot;
  float sector = 1.25664;
  float a5 = mod(ang + sector * 0.5, sector) - sector * 0.5;
  float t = abs(a5) / (sector * 0.5);
  float reach = r * (1.0 - 0.5 * t * t) - r * 0.12 * exp(-pow(t / 0.14, 2.0));
  float cover = 1.0 - smoothstep(reach - 0.8, reach + 0.4, rad);
  if (cover <= 0.0) return vec4(0.0);
  float k = rad / r;
  vec3 col = mix(vec3(1.0, 0.98, 0.95), tint, smoothstep(0.9, 0.15, k) * 0.8);
  col = mix(col, vec3(0.82, 0.2, 0.3), 1.0 - smoothstep(0.1, 0.28, k));
  col = mix(col, vec3(1.0, 0.8, 0.28), 1.0 - smoothstep(0.03, 0.12, k));
  return vec4(col, cover);
}

// The spray of flowers at one end of a banner: [p] is measured from the
// spray's root, x pointing in toward the banner's middle, in units of [u]
// (the banner's half height). It sways a little. rgb and coverage.
vec4 spray(vec2 p, float u, float time, float seed, vec3 tint) {
  vec2 q = p / u;
  float sway = 0.05 * sin(time * 0.9 + seed);
  q.y += sway;
  vec4 outc = vec4(0.0);
  // Leaves reaching in.
  for (int i = 0; i < 3; i++) {
    float f = float(i);
    float ang = -0.5 + 0.5 * f + 0.1 * sin(time * 0.8 + seed + f);
    float d = ellipse(q, vec2(0.38 + 0.12 * f, -0.2 + 0.2 * f), ang, vec2(0.34, 0.12));
    float m = 1.0 - smoothstep(-0.02, 0.02, d);
    vec3 lc = mix(vec3(0.24, 0.5, 0.26), vec3(0.5, 0.64, 0.28), 0.4 * f);
    outc = outc * (1.0 - m) + vec4(lc, 1.0) * m;
  }
  // Blossoms: a large one and two smaller, each nodding.
  for (int i = 0; i < 3; i++) {
    float f = float(i);
    float r = (i == 0 ? 0.52 : 0.3) * u;
    vec2 c = (i == 0 ? vec2(0.0, 0.0) : (i == 1 ? vec2(0.42, -0.42) : vec2(0.5, 0.42))) * u;
    vec4 b = blossom5(p - c + vec2(0.0, sway * u), r, 0.5 * f + 0.15 * sin(time * 0.7 + seed + f * 2.0), tint);
    outc = outc * (1.0 - b.a) + vec4(b.rgb, 1.0) * b.a;
  }
  return outc;
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  vec2 hs = uSize * 0.5;
  vec2 c = frag - hs;
  bool dialog = uParams.x > 2.5;
  bool card = uParams.x > 1.5 && !dialog;
  bool arch = uParams.x > 0.5 && !card && !dialog;
  bool banner = !arch && !card && !dialog;
  float lit = uParams.y;
  vec2 q = frag / uSize.y;
  float pk = (dialog ? 0.05 : 0.045) * uSize.x;

  float d = dialog ? depthDialog(c, hs, pk)
          : (card ? depthCard(c, hs, pk) : (arch ? depthArch(c, hs) : depthBanner(c, hs)));
  float aa = 0.9;
  float body = smoothstep(-aa, aa, d);

  float gw = dialog ? 0.014 * uSize.x : card ? 0.018 * uSize.x : (arch ? 0.04 * uSize.x : 0.085 * uSize.y);
  float bw = card ? 0.045 * uSize.x : 0.0;
  float ir = gw * 0.36;
  vec3 gold = uRim.rgb;
  vec3 blue = uArm.rgb;

  // ---- The one spray of blossom this pixel can be in. Banner, card and
  // dialog each want sprays at their ends or corners; the nearest is chosen
  // from the pixel's side, so the (large) spray code exists once. ----
  vec4 sprayFl = vec4(0.0);
  {
    float sx = c.x < 0.0 ? -1.0 : 1.0;
    float sy = c.y < 0.0 ? -1.0 : 1.0;
    float seed = (sy < 0.0 ? 0.0 : 3.4) + (sx < 0.0 ? 0.0 : 1.7);
    vec2 sp;
    float su;
    vec3 stint = vec3(0.96, 0.45, 0.4);
    if (banner) {
      sp = vec2(hs.x * 0.86 - sx * c.x, c.y);
      su = hs.y * 0.8;
      stint = uParams.z > 0.5 ? vec3(0.96, 0.42, 0.34) : vec3(0.98, 0.62, 0.62);
    } else {
      float inset = dialog ? 0.075 : 0.06;
      vec2 cp = vec2(sx * (hs.x - inset * uSize.x), sy * (hs.y - pk * 0.7 - (dialog ? 0.05 : (sy < 0.0 ? 0.04 : 0.075)) * uSize.x));
      vec2 inward = normalize(vec2(-sx, -sy * (dialog ? 1.0 : 0.55)));
      vec2 rv = c - cp;
      sp = vec2(dot(rv, inward), dot(rv, vec2(-inward.y, inward.x)));
      su = (dialog ? 0.15 : (sy < 0.0 ? 0.11 : 0.135)) * uSize.x;
    }
    if (banner || card || dialog) sprayFl = spray(sp, su, uTime, banner ? (sx < 0.0 ? 0.0 : 2.0) : seed, stint);
  }

  // ---- The fill. ----
  vec3 col;
  float df = d - gw - ir - bw;
  float grain = fbm(q * 22.0);
  // Crossed paper fibres, and a few foxing stains where age has browned it.
  float fibre = noise(q * vec2(120.0, 9.0)) * noise(q * vec2(9.0, 120.0)) * 3.2;
  float foxing = smoothstep(0.62, 0.86, noise(q * 3.2 + 7.0));
  vec3 parchment = mix(vec3(0.98, 0.88, 0.64), vec3(0.8, 0.6, 0.34), foxing * 0.35);
  if (dialog) {
    // Deep blue paper, mottled, darker toward the edge.
    float wash = fbm(q * 5.0 + 3.0);
    col = uCore.rgb * (0.82 + 0.4 * wash) * (0.92 + 0.14 * grain);
    col = mix(col, col * 0.7, 1.0 - smoothstep(0.0, 0.14 * uSize.x, df));
  } else if (card) {
    col = parchment * (0.9 + 0.2 * grain) + (fibre - 0.5) * 0.04;
    col = mix(col, vec3(0.86, 0.62, 0.32), (1.0 - smoothstep(0.0, 0.12 * uSize.y, df)) * 0.3);
  } else if (arch) {
    float bor = 0.1 * uSize.x;
    float dw = df - bor;
    col = parchment * (0.86 + 0.22 * grain) + (fibre - 0.5) * 0.04;
    col = mix(col, vec3(0.86, 0.62, 0.32), (1.0 - smoothstep(0.0, bor, df)) * 0.25);
    // The border of tiny flowers.
    float cell = bor * 0.95;
    vec2 g = frag / cell;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float hh = hash(id + 3.0);
    vec2 jit = (vec2(hash(id + 1.0), hash(id + 7.0)) - 0.5) * 0.3;
    vec3 petals = hh < 0.34 ? vec3(0.86, 0.26, 0.2)
                : hh < 0.67 ? vec3(0.16, 0.32, 0.72) : vec3(0.93, 0.66, 0.2);
    vec4 fl = floret(f - jit, 0.34, petals);
    float leafd = length((f - jit - vec2(0.3, 0.18)) * vec2(1.0, 2.4)) - 0.16;
    float inBorder = smoothstep(-1.0, 1.0, df) * (1.0 - smoothstep(-1.0, 1.0, dw));
    col = mix(col, vec3(0.3, 0.5, 0.28), (1.0 - smoothstep(-0.03, 0.03, leafd)) * inBorder);
    col = mix(col, fl.rgb, fl.a * inBorder);
    // The window.
    vec3 win = uCore.rgb * (0.7 + 0.5 * fbm(q * 9.0));
    win *= 1.0 + 0.3 * (0.5 - c.y / uSize.y);
    win = mix(win, win * 0.6, smoothstep(0.1, 0.5, length(c / uSize) * 1.6));
    float wm = smoothstep(-aa, aa, dw);
    col = mix(col, win, wm);
    float wl = 1.0 - smoothstep(0.0, ir * 0.9, abs(dw));
    col = mix(col, gold * (0.85 + 0.3 * lit), wl * 0.9);
  } else if (uParams.z > 0.5) {
    col = parchment * (0.88 + 0.2 * grain) + (fibre - 0.5) * 0.04;
    col = mix(col, vec3(0.86, 0.62, 0.32),
              (1.0 - smoothstep(0.0, 0.2 * uSize.y, df)) * 0.35);
  } else {
    col = uCore.rgb * (0.78 + 0.4 * grain);
    col *= 0.85 + 0.25 * smoothstep(0.0, 0.3 * uSize.y, df);
    float sheen = smoothstep(0.85, 1.0, sin(q.x * 6.0 - uTime * 0.5 + q.y * 3.0));
    col += sheen * 0.05;
  }

  // ---- Sprays of flowers at both ends of a banner, clipped to it. ----
  if (banner && uParams.w > 0.0) {
    // Only the end this pixel is nearest to is evaluated: one spray, not two.
    vec4 fl = sprayFl;
    float inside = smoothstep(0.0, 2.0, d - gw);
    col = mix(col, fl.rgb, fl.a * inside * uParams.w);
  }

  // ---- Blue lozenges at the ends of a banner, when w is below 0. ----
  if (banner && uParams.w < 0.0) {
    float s = c.x < 0.0 ? -1.0 : 1.0;
    vec4 m = medallion(c - vec2(s * hs.x * 0.84, 0.0), hs.y * 0.42, gold, blue);
    col = mix(col, m.rgb, m.a * smoothstep(0.0, 2.0, d - gw));
  }

  // ---- The thin line just inside the gold, then the gold band itself. ----
  float inLine = smoothstep(gw - aa, gw, d) * (1.0 - smoothstep(gw + ir - aa, gw + ir + aa, d));
  vec3 lineCol = (arch || uParams.z > 0.5) ? blue : gold * 0.65;
  if (dialog) {
    float fine = 1.0 - smoothstep(0.0, ir * 0.6, abs(d - gw - 0.02 * uSize.x));
    col = mix(col, gold * (0.75 + 0.3 * lit), fine * 0.9);
  } else if (card) {
    // The blue band between the gold edge and a thin inner gold line, with a
    // vine of gold flowers and leaves running along it.
    float v = d - gw - ir;
    float inBand = smoothstep(-aa, 0.0, v) * (1.0 - smoothstep(bw - ir * 0.0, bw + aa, v)) * step(gw * 0.9, d);
    float along = abs(c.y) / hs.y > abs(c.x) / hs.x ? c.x : c.y;
    float sp = bw * 1.7;
    float u = fract(along / sp) - 0.5;
    float vv = (v - bw * 0.5);
    vec3 bandCol = blue * (0.85 + 0.3 * fbm(q * 40.0));
    float dotm = 1.0 - smoothstep(bw * 0.12, bw * 0.2, length(vec2(u * sp, vv)));
    float vine = 1.0 - smoothstep(bw * 0.03, bw * 0.07,
                                  abs(vv - bw * 0.2 * sin(along / sp * 6.2832)));
    float leafm = 1.0 - smoothstep(0.0, bw * 0.05,
                  length(vec2((u - 0.28) * sp, vv * 1.8)) - bw * 0.14);
    bandCol = mix(bandCol, vec3(0.45, 0.62, 0.3), max(vine * 0.7, leafm * 0.9));
    bandCol = mix(bandCol, gold * 1.05, dotm);
    col = mix(col, bandCol, inBand);
    float innerLine = (1.0 - smoothstep(0.0, ir * 0.7, abs(d - gw - bw - ir * 0.5)));
    col = mix(col, gold * (0.75 + 0.3 * lit), innerLine);
  } else {
    col = mix(col, lineCol, inLine);
  }

  float t = clamp(d / gw, 0.0, 1.0);
  float bev = sin(t * 3.14159);
  float top = clamp(0.5 - c.y / uSize.y, 0.0, 1.0);
  float shade = 0.55 + 0.4 * bev + 0.3 * (top - 0.5) + 0.35 * lit;
  float glint = smoothstep(0.88, 1.0, sin(c.x / uSize.x * 6.0 - uTime * 1.1 + c.y / uSize.y * 2.0));
  vec3 band = gold * (0.55 + 0.6 * shade) + vec3(glint * (0.25 + 0.3 * lit)) * bev;
  band *= 0.94 + 0.12 * noise(q * 60.0);
  // Flakes of gold leaf catching the light.
  band += vec3(0.55, 0.42, 0.2) * step(0.955, noise(q * 380.0)) * (0.3 + 0.4 * lit);
  col = mix(col, band, 1.0 - smoothstep(gw - aa, gw + aa * 0.3, d));

  float alpha = body;

  if (arch) {
    // ---- The plaque for a name, scalloped at the top. ----
    float plq = uParams.w;
    if (plq > 0.0) {
      float ph = plq * uSize.y * 0.5;
      float cy = hs.y - ph - gw * 1.05;
      float pw = hs.x - gw * 2.3;
      vec2 pc = c - vec2(0.0, cy);
      float dp = -sdRoundBox(pc, vec2(pw, ph), ph * 0.5);
      float bump = ph * 0.52 - length(c - vec2(0.0, cy - ph));
      dp = max(dp, bump);
      float pm = smoothstep(-aa, aa, dp) * smoothstep(-aa, aa, d - gw * 0.8);
      vec3 pcol = vec3(1.0, 0.95, 0.8) * (0.9 + 0.14 * grain);
      pcol = mix(pcol, vec3(0.9, 0.7, 0.4), (1.0 - smoothstep(0.0, ph * 0.5, dp)) * 0.3);
      float ring = 1.0 - smoothstep(gw * 0.2, gw * 0.5, dp);
      pcol = mix(pcol, gold * (0.8 + 0.4 * lit), ring);
      col = mix(col, pcol, pm);
    }
  } else if (dialog) {
    // ---- The parchment header: a lotus arch narrowing to a peak. ----
    float yTop = -hs.y + 0.045 * uSize.y;
    float yBot = -hs.y + uParams.w * uSize.y;
    float tt = clamp((c.y - yTop) / max(yBot - yTop, 1.0), 0.0, 1.0);
    float hw = hs.x * 0.7 * (0.16 + 0.84 * smoothstep(0.0, 0.8, tt));
    float dh = min(min(hw - abs(c.x), yBot - c.y), (c.y - yTop) * 2.5);
    float hm = smoothstep(-aa, aa, dh) * smoothstep(-aa, aa, d - gw * 1.5);
    vec3 pcol = parchment * (0.92 + 0.16 * grain);
    pcol = mix(pcol, vec3(0.86, 0.62, 0.32), (1.0 - smoothstep(0.0, 0.05 * uSize.x, dh)) * 0.3);
    float ring = 1.0 - smoothstep(0.0, 0.01 * uSize.x, abs(dh - 0.004 * uSize.x));
    pcol = mix(pcol, gold * (0.8 + 0.3 * lit), ring);
    col = mix(col, pcol, hm);
    // ---- Medallions on the peaks, sprays of blossom in the corners. ----
    float mr = 0.06 * uSize.x;
    float h0 = dialogH(0.0, hs, pk);
    float ms = c.y < 0.0 ? -1.0 : 1.0;
    vec4 mdl = medallion(c - vec2(0.0, ms * (h0 - mr)), mr, gold * (0.9 + 0.2 * lit), blue);
    col = mix(col, mdl.rgb, mdl.a);
    alpha = max(alpha, mdl.a);
    // Drawn over the frame, not masked to the panel, so no blossom is sliced
    // flat by the panel's edge.
    float sprayCov = sprayFl.a * (1.0 - hm);
    col = mix(col, sprayFl.rgb, sprayCov);
    alpha = max(alpha, sprayCov);
  } else if (card) {
    // ---- Medallions on the peaks, and sprays of blossom in the corners. ----
    float mr = 0.07 * uSize.x;
    float h0 = cardH(0.0, hs, pk);
    float ms = c.y < 0.0 ? -1.0 : 1.0;
    vec4 mdl = medallion(c - vec2(0.0, ms * (h0 - mr)), mr, gold * (0.9 + 0.2 * lit), blue);
    col = mix(col, mdl.rgb, mdl.a);
    alpha = max(alpha, mdl.a);
    float sprayAmt = uParams.w;
    if (sprayAmt > 0.0) {
      col = mix(col, sprayFl.rgb, sprayFl.a * sprayAmt);
      alpha = max(alpha, sprayFl.a * sprayAmt);
    }
  } else {
    // ---- Medallions on the top and bottom edges. ----
    float h0 = bannerH(0.0, hs);
    float mr = hs.y * 0.17;
    float ms = c.y < 0.0 ? -1.0 : 1.0;
    vec4 mdl = medallion(c - vec2(0.0, ms * (h0 - mr * 0.55)), mr, gold * (0.9 + 0.2 * lit), blue);
    col = mix(col, mdl.rgb, mdl.a);
    alpha = max(alpha, mdl.a);
  }

  alpha *= 1.0 - uPic.y;
  fragColor = vec4(col * alpha, alpha);
}
