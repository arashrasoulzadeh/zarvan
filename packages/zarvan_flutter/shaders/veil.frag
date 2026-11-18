#include <flutter/runtime_effect.glsl>

// A screen transition: a swirling veil that spreads from a point until it
// covers everything (progress 0 -> 1), or shrinks away again (1 -> 0). Its edge
// is a wavering ring of gold light shedding embers; the veil itself is deep
// colour crossed by a faint rotating lattice of diamonds.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - unused (kept so every effect shares one uniform layout)
//   uRim    - the gold of the edge and embers
//   uArm    - the lattice and glow colour
//   uCore   - the veil's body colour
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

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void main() {
  float prog = clamp(uParams.x, 0.0, 1.0);
  if (prog <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 rel = (uv - uParams.yz) * vec2(aspect, 1.0);
  float dist = length(rel);
  float ang = atan(rel.y, rel.x);

  // The farthest corner is where the veil must reach to cover the screen.
  vec2 far = max(uParams.yz, 1.0 - uParams.yz) * vec2(aspect, 1.0);
  float reach = length(far) * 1.15;
  float ease = prog * prog * (3.0 - 2.0 * prog);
  float radius = ease * reach;

  // The edge wavers and swirls.
  float wob = 0.016 * sin(ang * 7.0 + uTime * 3.0 + dist * 6.0)
            + 0.009 * sin(ang * 13.0 - uTime * 4.5)
            + 0.02 * (noise(vec2(ang * 3.0, uTime * 0.8)) - 0.5);
  float edge = dist + wob * min(1.0, ease * 3.0) - radius;
  float inside = 1.0 - smoothstep(-0.012, 0.012, edge);

  // The veil: body colour, a rotating lattice, a glow rising to the edge.
  float rot = 0.35 * ease + uTime * 0.12;
  mat2 r = mat2(cos(rot), -sin(rot), sin(rot), cos(rot));
  vec2 g = (r * rel) * 9.0;
  vec2 f = fract(g) - 0.5;
  float k = abs(f.x) + abs(f.y);
  float lattice = (1.0 - smoothstep(0.0, 0.06, abs(k - 0.4))) * 0.5
                + (1.0 - smoothstep(0.0, 0.05, abs(k - 0.18))) * 0.3;
  float swirl = noise(vec2(ang * 2.0 + dist * 5.0 - uTime * 0.7, dist * 3.0));
  vec3 body = uCore.rgb * (0.8 + 0.4 * swirl);
  body = mix(body, uArm.rgb, lattice * 0.35);
  float rising = smoothstep(0.35, 0.0, -edge); // brighter near the rim
  body += uArm.rgb * rising * 0.35;

  // The rim: a bright line with a soft halo, and embers beside it.
  float rim = 1.0 - smoothstep(0.0, 0.022, abs(edge));
  float halo = exp(-abs(edge) * 22.0);
  // Embers: small round dots drifting up beside the edge.
  vec2 eg = rel * 42.0 + vec2(0.0, uTime * 4.0);
  vec2 ec = floor(eg);
  float spark = step(0.965, hash(ec)) * (1.0 - smoothstep(0.12, 0.3, length(fract(eg) - 0.5)));
  float ember = spark * smoothstep(0.16, 0.0, abs(edge));
  float live = smoothstep(0.0, 0.08, prog) * (1.0 - smoothstep(0.94, 1.0, prog));
  vec3 gold = uRim.rgb;
  vec3 col = mix(vec3(0.0), body, inside);
  col += gold * (rim * 0.75 + halo * 0.22 + ember * 0.8) * live;
  float a = clamp(inside + (rim * 0.8 + halo * 0.25 + ember) * live, 0.0, 1.0);
  fragColor = vec4(min(col, vec3(1.0)), a);
}
