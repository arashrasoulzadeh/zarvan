#include <flutter/runtime_effect.glsl>

// A theatre / tent curtain transition: two embroidered panels slide shut from
// the sides and meet in the middle (progress 0 -> 1), or part again (1 -> 0).
// The cloth is deep velvet with vertical folds that gather toward the leading
// edge, a gold braided border, faint gold lattice embroidery with a rosette,
// and a beam of moonlight that slides over it. The panels cast a soft shadow
// on what they are about to cover, and billow a little at the hem.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold of the braid and embroidery
//   uArm    - the moonlight
//   uCore   - the velvet
//   uParams - x: progress 0..1

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
  float ease = prog * prog * (3.0 - 2.0 * prog);

  // Which panel this pixel is under, and how far it is from the middle.
  float side = uv.x < 0.5 ? -1.0 : 1.0;
  float fromEdge = side < 0.0 ? uv.x : 1.0 - uv.x; // 0 at the screen edge

  // The leading edge of each panel: it travels from the screen edge to a little
  // past the middle, billowing at the hem and swaying.
  float billow = 0.018 * sin(3.14159 * uv.y) + 0.006 * sin(uv.y * 9.0 + uTime * 1.6);
  float lead = ease * 0.53 - billow * ease;
  float d = lead - fromEdge; // > 0 inside the cloth

  // Shadow thrown ahead of the edge.
  float shadow = (1.0 - smoothstep(0.0, 0.09, -d)) * step(d, 0.0) * 0.42 * smoothstep(0.0, 0.1, prog);

  if (d <= 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }

  // Velvet folds, tighter near the leading edge, swaying gently.
  float gather = 1.0 + 2.2 * (1.0 - smoothstep(0.0, 0.25, d));
  float fold = sin(fromEdge * aspect * 26.0 * gather + sin(uv.y * 2.6 + uTime * 0.7) * 0.7 + side);
  float shade = 0.62 + 0.38 * (0.5 + 0.5 * fold);
  // Darker toward the top, as light falls from the stage.
  shade *= 0.8 + 0.3 * smoothstep(0.0, 0.7, uv.y);
  vec3 cloth = uCore.rgb * shade;

  // Embroidery: a faint gold lattice of diamonds, and a rosette on each panel.
  vec2 g = vec2(fromEdge * aspect, uv.y) * 7.0;
  vec2 f = fract(g) - 0.5;
  float k = abs(f.x) + abs(f.y);
  float lattice = line(k - 0.42, 0.05) * 0.5 + line(k - 0.2, 0.04) * 0.3;
  vec2 rc = vec2(0.34 * aspect, 0.5);
  float rr = length(vec2(fromEdge * aspect, uv.y) - rc);
  float ang = atan(uv.y - rc.y, fromEdge * aspect - rc.x);
  float rose = line(rr - (0.16 + 0.05 * cos(ang * 8.0)), 0.006) + line(rr - 0.07, 0.005) * 0.8;
  rose += 1.0 - smoothstep(0.01, 0.018, rr);
  float emb = clamp(lattice * 0.55 + rose, 0.0, 1.0);
  cloth = mix(cloth, uRim.rgb * 0.9, emb * 0.4 * shade);

  // The gold braid along the leading edge: a plain band with a twisted pattern.
  float braidW = 0.028;
  float inBraid = 1.0 - smoothstep(braidW - 0.003, braidW, d);
  float twist = 0.5 + 0.5 * sin((uv.y * 70.0) + (d / braidW) * 6.0 * side);
  vec3 braid = mix(uRim.rgb * 0.55, uRim.rgb * 1.1, twist);
  float edgeLine = line(d - braidW, 0.0035);
  cloth = mix(cloth, braid, inBraid);
  cloth = mix(cloth, uRim.rgb, edgeLine * 0.9);

  // Moonlight: a soft beam sliding across, and a few cold glints.
  float beamPos = fract(uTime * 0.12 + 0.2) * 1.8 - 0.4;
  float beam = exp(-pow((uv.x * 0.75 + uv.y * 0.55 - beamPos) * 3.2, 2.0));
  cloth += uArm.rgb * beam * 0.28 * (0.6 + 0.4 * (0.5 + 0.5 * fold));
  vec2 sg = vec2(fromEdge * aspect, uv.y) * 38.0;
  float star = step(0.985, hash(floor(sg))) * (0.5 + 0.5 * sin(uTime * 3.0 + hash(floor(sg)) * 40.0));
  cloth += uArm.rgb * star * 0.5 * (1.0 - smoothstep(0.35, 0.5, length(fract(sg) - 0.5)));

  fragColor = vec4(min(cloth, vec3(1.0)), 1.0);
}
