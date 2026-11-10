#include <flutter/runtime_effect.glsl>

// A glossy orb/sphere window: masked to the circle inscribed in the rect (the
// rest of the rect is transparent, so the shape reads as round even when the
// rect itself isn't square), showing up to two background layers (bottom
// layer first) through a fisheye-distorted spherical sample that slowly
// spins, with sphere-style limb shading, a soft rim glow and a fixed
// specular highlight so it reads as glass/crystal, not a flat cropped photo.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - x: picture count (0/1/2), y: unused, z: share of the image's
//             width the sample crops to (keeps the picture's own aspect)
//   uRim    - rim glow / no-picture base colour
//   uArm    - no-picture secondary colour
//   uCore   - specular highlight / edge-glow colour
//   uImg0 / uImg1 - the pictures, bottom layer first

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uRim;
uniform vec4 uArm;
uniform vec4 uCore;
uniform sampler2D uImg0;
uniform sampler2D uImg1;

out vec4 fragColor;

vec3 picture(vec2 uv) {
  vec2 c = vec2(0.5 + (uv.x - 0.5) * uPic.z, uv.y);
  vec4 b = texture(uImg0, clamp(c, 0.0, 1.0));
  vec3 col = b.rgb;
  if (uPic.x > 1.5) {
    vec4 f = texture(uImg1, clamp(c, 0.0, 1.0));
    col = mix(col, f.rgb, f.a);
  }
  return col;
}

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float side = min(uSize.x, uSize.y);
  vec2 q = (uv * 2.0 - 1.0) * uSize / side;
  float r = length(q);

  if (r > 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Fake sphere normal (z toward the viewer) bends the sample toward the
  // limb like a glass globe instead of a flat porthole, and slowly spins.
  float z = sqrt(max(1.0 - r * r, 0.0));
  vec3 n = vec3(q, z);
  float ang = uTime * 0.15;
  float ca = cos(ang), sa = sin(ang);
  vec2 spin = vec2(n.x * ca - z * sa, n.y);
  vec2 sampleUv = vec2(0.5) + spin * 0.46;

  vec3 col = uPic.x > 0.5 ? picture(sampleUv) : mix(uRim.rgb, uArm.rgb, 0.5);

  // Sphere shading: darker toward the limb, a fixed specular highlight.
  col *= mix(0.55, 1.05, z);
  vec3 lightDir = normalize(vec3(-0.45, -0.55, 0.7));
  float spec = pow(max(dot(n, lightDir), 0.0), 24.0);
  col += uCore.rgb * spec * 0.9;

  // Rim glow and a thin bright edge, feathered for anti-aliasing.
  float rim = smoothstep(0.78, 1.0, r);
  col = mix(col, uRim.rgb, rim * 0.5);
  float edgeGlow = smoothstep(0.90, 1.0, r);
  col += uCore.rgb * edgeGlow * 0.35;

  float alpha = smoothstep(1.0, 0.96, r);
  fragColor = vec4(col * alpha, alpha);
}
