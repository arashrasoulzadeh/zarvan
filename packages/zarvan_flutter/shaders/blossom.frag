#include <flutter/runtime_effect.glsl>

// A flowering branch, as painted in the corners of a Persian page: a gnarled
// bark-textured limb climbing from the bottom edge with thin twigs, pointed
// leaves with a midrib, buds, and cherry blossoms: five notched petals that
// blush from white to coral toward the heart, veined, with a deep-pink eye
// and a ring of stamens tipped with pollen. The branch bends very slightly in
// an unseen breeze, the flowers nod, and now and then a petal lets go and
// drifts down.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels (taller than wide)
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the petals' coral edge
//   uArm    - the bark
//   uCore   - the leaves' green
//   uParams - x: 1 mirrors it (branch leaning left), y: bloom 0..1 (how many
//             flowers are open; 0 is read as fully open)

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform vec4 uParams;

out vec4 fragColor;

float n2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
  float b2 = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
  float c2 = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
  float d2 = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
  return mix(mix(a, b2, f.x), mix(c2, d2, f.x), f.y);
}

// One breeze for the whole page: a slow sway with a gust that comes and goes,
// reaching each part a little later than the one before (lag, in seconds), so
// the limb bends first and the leaves and flowers follow it. About -0.35..1.
float wind(float lag) {
  float t = uTime - uOrigin.x * 0.004 - lag;
  float gust = pow(0.5 + 0.5 * sin(t * 0.3 + 1.0), 2.0);
  return 0.45 * sin(t * 0.45) + gust * (0.8 + 0.4 * sin(t * 1.7));
}

float hash(float n) {
  return fract(sin(n * 127.1) * 43758.5453);
}

float seg(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h);
}

// The main limb, t in 0..1 from the foot to the tip.
vec2 limb(float t, float w) {
  return vec2(w * (0.2 + 0.5 * t + 0.16 * sin(t * 6.0 + 0.4) * (1.0 - t * 0.4)),
              1.04 - 0.98 * t);
}

// Distance to the limb and how far along it the nearest point lies.
vec2 limbDist(vec2 p, float w) {
  float best = 9.0;
  float at = 0.0;
  vec2 prev = limb(0.0, w);
  for (int i = 1; i <= 10; i++) {
    float t = float(i) / 10.0;
    vec2 cur = limb(t, w);
    float d = seg(p, prev, cur);
    if (d < best) {
      best = d;
      at = t;
    }
    prev = cur;
  }
  return vec2(best, at);
}

// A side branch that leaves the limb a third of the way up and reaches out
// and upward the other way.
vec2 fork(float t, float w) {
  return limb(0.3, w) + vec2(-w * 0.62 * t * (1.0 - 0.35 * t), -0.5 * t + 0.05 * sin(t * 5.0));
}

float forkDist(vec2 p, float w) {
  float best = 9.0;
  vec2 prev = fork(0.0, w);
  for (int i = 1; i <= 6; i++) {
    vec2 cur = fork(float(i) / 6.0, w);
    best = min(best, seg(p, prev, cur));
    prev = cur;
  }
  return best;
}

// The mound of boulders at the foot, painted the way the miniaturists did:
// angular faceted stone in layered blues, violets and ochres, each plane a
// flat wash, lit from the upper left, with a dark ink outline, strata lines,
// tufts of grass and a few gold touches. rgb and cover.
vec4 rocks(vec2 p, float w) {
  float best = 9.0;
  float which = 0.0;
  vec2 loc = vec2(0.0);
  for (int i = 0; i < 3; i++) {
    float f = float(i);
    // A pile: two boulders side by side and one riding on them, all inside
    // the rectangle so nothing is cut off at the sides.
    vec2 c = vec2(w * (0.29 + 0.21 * f), 0.945 - 0.065 * step(0.5, 1.0 - abs(f - 1.0)));
    vec2 r = vec2(w * (0.2 + 0.03 * sin(f * 3.0)), 0.09 + 0.015 * sin(f * 5.0));
    vec2 q = (p - c) / r;
    float a = atan(q.y, q.x);
    // An angular outline: a rounded polygon, not a smooth blob.
    float poly = 1.0 + 0.1 * (abs(sin(a * 2.5 + f * 1.7)) - 0.5) + 0.05 * sin(a * 7.0 + f);
    float d = (length(q) - poly) * min(r.x, r.y);
    if (d < best) {
      best = d;
      which = f;
      loc = q;
    }
  }
  float cover = (1.0 - smoothstep(-0.0015, 0.0015, best)) * step(p.y, 1.06);
  if (cover <= 0.0) return vec4(0.0);

  // Facets: slanted bands of the stone, each its own flat wash.
  float slant = loc.x * 1.3 + loc.y * 2.1 + which * 3.7 + 0.35 * sin(loc.y * 5.0);
  float facet = floor(slant * 1.6);
  float fh = hash(facet + which * 11.0);
  vec3 blue = vec3(0.34, 0.44, 0.7);
  vec3 violet = vec3(0.5, 0.42, 0.66);
  vec3 ochre = vec3(0.72, 0.6, 0.42);
  vec3 col = mix(blue, violet, smoothstep(0.2, 0.6, fh));
  col = mix(col, ochre, smoothstep(0.7, 0.95, fh));
  // Light from the upper left: the top and left of each stone are brighter.
  float lit = clamp(0.55 - 0.35 * loc.y - 0.2 * loc.x, 0.0, 1.0);
  col *= 0.7 + 0.5 * lit;
  // A thin darker wash along the lower edge, ink lines between facets, strata.
  col = mix(col, col * 0.55, smoothstep(-0.03, 0.0, -best) * 0.0 + smoothstep(0.2, 1.0, loc.y) * 0.35);
  float seam = abs(fract(slant * 1.6) - 0.5);
  col = mix(col, col * 0.6, (1.0 - smoothstep(0.46, 0.5, seam)) * 0.0 + smoothstep(0.455, 0.5, seam) * 0.8);
  float strata = abs(sin(loc.y * 14.0 + loc.x * 2.0 + which));
  col = mix(col, col * 1.18, smoothstep(0.93, 1.0, strata) * 0.5);
  // Granulation: the stone is flecked, not flat.
  col *= 0.88 + 0.24 * n2(p * 170.0) + 0.06 * n2(p * 60.0);
  // The dark ink outline and a thread of gold just inside it.
  col = mix(col, vec3(0.1, 0.12, 0.25), 1.0 - smoothstep(0.0015, 0.004, -best));
  col = mix(col, vec3(0.93, 0.74, 0.3), (1.0 - smoothstep(0.0, 0.002, abs(-best - 0.007))) * 0.7);
  // Tufts of grass on the tops.
  float tuft = smoothstep(0.55, 1.0, lit) * (0.5 + 0.5 * sin(p.x * 70.0 + which));
  col = mix(col, vec3(0.3, 0.5, 0.25), tuft * smoothstep(0.0, 0.02, -best) * 0.45);
  return vec4(col, cover);
}

float bloomT(float f) {
  return 0.12 + 0.19 * f + 0.03 * sin(f * 4.3);
}

// Where blossom number [f] opens: on the limb at an irregular place, a little
// to one side, so they cluster like real ones.
vec2 bloomAt(float f, float w) {
  float side = mod(f, 2.0) < 0.5 ? 1.0 : -1.0;
  return limb(bloomT(f), w) +
         vec2(side * w * (0.1 + 0.12 * fract(f * 0.618)), -0.03 * sin(f * 2.0));
}

// Where blossom [f] hangs now: nodding, and swung by the breeze a beat after
// the limb it grows from.
vec2 bloomMoved(float f, float w, float dirW) {
  vec2 c = bloomAt(f, w);
  c.y += 0.004 * sin(uTime * 0.9 + f * 2.1);
  c.x += dirW * 0.017 * wind(0.2 + 0.07 * f);
  return c;
}

// A leaf from [a] along [dir]: distance to its outline (negative inside).
float leaf(vec2 p, vec2 a, vec2 dir, float len, float wid) {
  vec2 q = p - a;
  float along = dot(q, dir) / len;
  float across = dot(q, vec2(-dir.y, dir.x));
  float wd = wid * pow(sin(clamp(along, 0.0, 1.0) * 3.14159), 0.8);
  return max(abs(across) - wd, max(-along, along - 1.0) * len);
}

// A five-petalled blossom at [c], radius [r], turned by [rot]. rgb and cover.
vec4 blossom(vec2 p, vec2 c, float r, float rot, vec3 edge, float seed) {
  // No two flowers alike: size, tint and sometimes a sixth petal differ, and
  // each opens and closes a few percent at its own slow pace.
  r *= (0.92 + 0.16 * hash(seed * 3.1 + 1.0)) *
       (1.0 + 0.05 * sin(uTime * 0.5 + seed * 2.3));
  edge *= 0.86 + 0.28 * hash(seed + 5.0);
  edge.g += 0.07 * (hash(seed + 8.0) - 0.5);
  float petals = hash(seed * 5.7 + 2.0) > 0.75 ? 6.0 : 5.0;
  vec2 q = p - c;
  float rad = length(q);
  if (rad > r * 1.15) return vec4(0.0);
  float ang = atan(q.y, q.x) + rot;
  float sector = 6.2832 / petals;
  float a5 = mod(ang + sector * 0.5, sector) - sector * 0.5;
  float t = abs(a5) / (sector * 0.5);
  // A petal: broad at the tip, narrowing to the heart, with a small notch at
  // the tip's middle.
  float reach = r * (1.0 - 0.5 * t * t) - r * 0.13 * exp(-pow(t / 0.14, 2.0));
  float cover = 1.0 - smoothstep(reach - r * 0.025, reach + r * 0.01, rad);
  if (cover <= 0.0) return vec4(0.0);
  float k = rad / r;
  // White at the rim blushing to coral toward the heart, deeper in the notch.
  vec3 col = mix(vec3(1.0, 0.985, 0.97), edge, smoothstep(0.85, 0.2, k) * 0.75);
  col = mix(col, edge * 0.92, exp(-pow(t / 0.16, 2.0)) * smoothstep(0.55, 1.0, k) * 0.4);
  // Veins out from the heart along each petal.
  float vein = exp(-pow(a5 * rad / (r * 0.035), 2.0)) *
               smoothstep(0.12, 0.4, k) * (1.0 - smoothstep(0.6, 0.92, k));
  col = mix(col, edge * 0.8, vein * 0.4);
  // The painter's fine outline round each petal, and a lit edge inside it.
  float edgeD = reach - rad;
  col = mix(col, edge * 0.62, 1.0 - smoothstep(r * 0.012, r * 0.045, edgeD));
  col = mix(col, vec3(1.0, 0.99, 0.97), smoothstep(r * 0.05, r * 0.09, edgeD) *
            (1.0 - smoothstep(r * 0.09, r * 0.16, edgeD)) * 0.35);
  // A little shade where petals overlap.
  col *= 1.0 - 0.1 * smoothstep(0.6, 1.0, t) * smoothstep(0.2, 0.7, k);
  // The eye: deep pink fading to a golden heart.
  col = mix(col, vec3(0.8, 0.18, 0.3), 1.0 - smoothstep(0.1, 0.3, k));
  col = mix(col, vec3(1.0, 0.78, 0.25), 1.0 - smoothstep(0.03, 0.12, k));
  // Stamens: ten threads with pollen at the ends, each a little different.
  float sa = mod(ang, 0.62832) - 0.31416;
  float ring = floor(ang / 0.62832);
  float reachS = 0.38 + 0.18 * hash(ring + seed * 7.0);
  float thread = (1.0 - smoothstep(0.006, 0.018, abs(sa) * rad / r)) *
                 step(0.1, k) * step(k, reachS);
  col = mix(col, vec3(0.9, 0.35, 0.4), thread * 0.85);
  vec2 tip = vec2(cos(sa), sin(sa)) * rad - vec2(reachS * r, 0.0);
  float anther = 1.0 - smoothstep(0.02 * r, 0.05 * r, length(tip));
  col = mix(col, vec3(1.0, 0.8, 0.22), anther);
  return vec4(col, cover);
}

// A bud: a teardrop at [c] pointing along [dir].
vec4 bud(vec2 p, vec2 c, vec2 dir, float r, vec3 edge) {
  vec2 q = p - c;
  float along = dot(q, dir);
  float across = dot(q, vec2(-dir.y, dir.x));
  float d = length(vec2(along / 1.5, across)) - r * (0.7 + 0.3 * smoothstep(-r, r, along));
  float cover = 1.0 - smoothstep(-0.003, 0.003, d);
  vec3 col = mix(vec3(1.0, 0.96, 0.94), edge, smoothstep(-r, r, along) * 0.8);
  return vec4(col, cover);
}

void main() {
  vec2 frag = FlutterFragCoord().xy - uOrigin;
  float w = uSize.x / uSize.y;
  vec2 p = frag / uSize.y;
  if (uParams.x > 0.5) p.x = w - p.x;
  // The whole branch leans a hair with the breeze, more toward the tip.
  float tipness = clamp(1.0 - p.y, 0.0, 1.0);
  // The breeze blows one way on the page, so a mirrored branch pushes the
  // other way in its own frame.
  float dirW = uParams.x > 0.5 ? -1.0 : 1.0;
  p.x -= dirW * 0.03 * tipness * tipness * wind(0.0);
  p.x += 0.004 * tipness * tipness * sin(uTime * 0.7 + p.y * 2.0);
  float bloom = uParams.y > 0.0 ? uParams.y : 1.0;
  vec3 green = uCore.rgb;

  vec4 outc = vec4(0.0);

  // Rocks at the foot, under everything else.
  vec4 rk = rocks(p, w);
  outc = vec4(rk.rgb * rk.a, rk.a);

  // Leaves behind the branch: a deeper green at the stalk, lighter at the
  // tip, a midrib with side veins, an ink outline, and a little curl.
  for (int i = 0; i < 6; i++) {
    float f = float(i);
    vec2 a = limb(0.1 + 0.15 * f, w);
    float side = mod(f, 2.0) < 0.5 ? 1.0 : -1.0;
    float an = 0.9 * side - 1.2 + 0.1 * sin(uTime * 0.6 + f * 1.3) +
               dirW * 0.5 * wind(0.3 + 0.08 * f);
    vec2 dir = vec2(cos(an), sin(an));
    float len = 0.17 - 0.008 * f;
    vec2 q = p - a;
    float along = dot(q, dir) / len;
    float across = dot(q, vec2(-dir.y, dir.x));
    // The leaf bends: its spine curves a little to one side.
    float spine = 0.16 * len * side * along * along;
    float across2 = across - spine;
    float wd = len * 0.3 * pow(sin(clamp(along, 0.0, 1.0) * 3.14159), 0.75);
    float ld = max(abs(across2) - wd, max(-along, along - 1.0) * len);
    float m = 1.0 - smoothstep(-0.0025, 0.0025, ld);
    vec3 deep = green * 0.62;
    vec3 light = mix(vec3(0.55, 0.68, 0.26), vec3(0.78, 0.74, 0.3), fract(f * 0.37));
    vec3 lc = mix(deep, light, smoothstep(0.0, 1.0, along));
    // Lit on one half, in shade on the other.
    lc *= across2 * side > 0.0 ? 1.12 : 0.9;
    // Veins: a midrib and side veins slanting toward the tip.
    float rib = 1.0 - smoothstep(0.001, 0.0035, abs(across2));
    float vein = 1.0 - smoothstep(0.02, 0.06,
        abs(fract((along + abs(across2) / (len * 0.9) + 0.03 * sin(uTime * 0.7 + f)) * 5.0) - 0.5));
    lc = mix(lc, lc * 1.45 + 0.08, max(rib * 0.8, vein * 0.3 * step(0.05, along)));
    // The painted outline.
    lc = mix(lc, deep * 0.45, 1.0 - smoothstep(0.0015, 0.0045, -ld));
    lc *= 0.9 + 0.2 * n2(p * 140.0);
    outc = outc * (1.0 - m) + vec4(lc, 1.0) * m;
  }

  // The limb: bark with a dark edge, a lit side and grain.
  vec2 lm = limbDist(p, w);
  float th = 0.03 * (1.0 - lm.y) + 0.007;
  float bark = 1.0 - smoothstep(th - 0.002, th + 0.002, lm.x);
  float edgeShade = smoothstep(th * 0.55, th, lm.x);
  vec3 bc = uArm.rgb * (1.1 - 0.5 * edgeShade);
  bc += vec3(0.22, 0.16, 0.08) * smoothstep(th * 0.6, 0.0, abs(lm.x - th * 0.3));
  // Bark: long grain with knots and fine cracks.
  bc *= 0.88 + 0.24 * n2(vec2(lm.y * 70.0, lm.x * 260.0)) + 0.08 * n2(p * 220.0);
  outc = outc * (1.0 - bark) + vec4(bc, 1.0) * bark;

  // The side branch, tapering to its tip.
  float fd = forkDist(p, w);
  float fth = 0.011;
  float fb = 1.0 - smoothstep(fth - 0.002, fth + 0.002, fd);
  outc = outc * (1.0 - fb) + vec4(uArm.rgb * (1.0 - 0.3 * smoothstep(0.004, fth, fd)), 1.0) * fb;

  // Thin twigs carry each blossom to the limb.
  for (int i = 0; i < 5; i++) {
    float f = float(i);
    float td = seg(p, limb(bloomT(f), w), bloomMoved(f, w, dirW));
    float tb = 1.0 - smoothstep(0.004, 0.008, td);
    outc = outc * (1.0 - tb) + vec4(uArm.rgb * 0.9, 1.0) * tb;
  }

  // Buds on short stalks.
  for (int i = 0; i < 2; i++) {
    float f = float(i);
    float side = mod(f, 2.0) < 0.5 ? -1.0 : 1.0;
    vec2 a = limb(0.25 + 0.3 * f, w);
    float an = -1.1 + side * 0.9;
    vec2 dir = vec2(cos(an), sin(an));
    vec2 tipP = a + dir * 0.09;
    float sb = 1.0 - smoothstep(0.003, 0.006, seg(p, a, tipP));
    outc = outc * (1.0 - sb) + vec4(uArm.rgb, 1.0) * sb;
    vec4 b = bud(p, tipP, dir, 0.02, uRim.rgb);
    outc = outc * (1.0 - b.a) + vec4(b.rgb, 1.0) * b.a;
  }

  // Blossoms: nodding a little, each at its own pace.
  for (int i = 0; i < 5; i++) {
    float f = float(i);
    if (f / 5.0 > bloom) continue;
    vec2 c = bloomMoved(f, w, dirW);
    float r = 0.062 - 0.004 * f + 0.006 * sin(f * 3.1);
    float rot = f * 0.9 + 0.1 * sin(uTime * 0.6 + f * 1.7) -
                dirW * 0.55 * wind(0.45 + 0.1 * f);
    vec4 b = blossom(p, c, r, rot, uRim.rgb, f);
    outc = outc * (1.0 - b.a) + vec4(b.rgb, 1.0) * b.a;
  }
  vec4 tipb = blossom(p, limb(1.0, w) + vec2(dirW * 0.02 * wind(0.15), 0.025), 0.056,
                      0.4 + 0.1 * sin(uTime * 0.6) - dirW * 0.55 * wind(0.4), uRim.rgb, 9.0);
  outc = outc * (1.0 - tipb.a) + vec4(tipb.rgb, 1.0) * tipb.a;

  // Blossoms and a bud on the side branch.
  for (int i = 0; i < 2; i++) {
    float f = float(i);
    vec2 c = fork(0.5 + 0.4 * f, w) + vec2(0.0, -0.02);
    c.y += 0.004 * sin(uTime * 0.8 + f * 2.7);
    c.x += dirW * 0.019 * wind(0.25 + 0.1 * f);
    float r = 0.05 - 0.006 * f;
    vec4 b = blossom(p, c, r, f * 1.7 + 0.1 * sin(uTime * 0.5 + f) - dirW * 0.5 * wind(0.5 + 0.1 * f),
                     uRim.rgb, f + 20.0);
    outc = outc * (1.0 - b.a) + vec4(b.rgb, 1.0) * b.a;
  }

  // Now and then a petal lets go of its flower and drifts down, turning.
  for (int k = 0; k < 2; k++) {
    float kf = float(k);
    float life = fract(uTime / (6.0 + kf * 1.7) + kf * 0.37);
    vec2 from = bloomAt(kf * 2.0 + 1.0, w);
    // It zigzags as it falls and is carried off by the breeze.
    vec2 pc = from + vec2(0.05 * sin(life * 9.0 + kf) * (0.4 + life) +
                          dirW * life * (0.05 + 0.2 * max(wind(life * 3.0), 0.0)),
                          life * 0.45);
    float ang = life * 7.0 + kf;
    vec2 d2 = p - pc;
    vec2 rp = vec2(cos(ang) * d2.x + sin(ang) * d2.y, -sin(ang) * d2.x + cos(ang) * d2.y);
    // Turning edge-on and back as it tumbles, so it flutters.
    float flutter = 0.35 + 0.65 * abs(cos(life * 11.0 + kf * 2.0));
    float pd = length(rp * vec2(1.0 / flutter, 1.7)) - 0.014;
    float fade = smoothstep(0.0, 0.06, life) * (1.0 - smoothstep(0.7, 1.0, life));
    float pm = (1.0 - smoothstep(-0.002, 0.002, pd)) * fade;
    vec3 pcol = mix(vec3(1.0, 0.95, 0.92), uRim.rgb, 0.45 + 0.3 * clamp(rp.x / 0.014, -1.0, 1.0));
    outc = outc * (1.0 - pm) + vec4(pcol, 1.0) * pm;
  }

  // Small stones in front of the stem, for depth.
  for (int k = 0; k < 3; k++) {
    float kf = float(k);
    vec2 c = vec2(w * (0.1 + 0.25 * kf + 0.03 * sin(kf * 4.0)), 0.985 + 0.006 * sin(kf * 3.0));
    vec2 r = vec2(w * (0.035 + 0.02 * hash(kf + 3.0)), 0.016 + 0.01 * hash(kf + 9.0));
    vec2 q = (p - c) / r;
    float a = atan(q.y, q.x);
    float d = (length(q) - 1.0 - 0.1 * sin(a * 3.0 + kf)) * min(r.x, r.y);
    float cov = (1.0 - smoothstep(-0.0015, 0.0015, d)) * step(p.y, 1.0);
    float lit = clamp(0.55 - 0.5 * q.y - 0.25 * q.x, 0.0, 1.0);
    vec3 sc = mix(vec3(0.3, 0.38, 0.62), vec3(0.72, 0.74, 0.88), lit);
    sc = mix(sc, vec3(0.1, 0.12, 0.25), 1.0 - smoothstep(0.0012, 0.0035, -d));
    outc = outc * (1.0 - cov) + vec4(sc, 1.0) * cov;
  }

  fragColor = outc;
}
