#include <flutter/runtime_effect.glsl>

// A soft additive glow: an ellipse that fills the rect and fades to nothing at
// its edge. Drawn with additive blending, it lights whatever is behind it, e.g.
// the stone and floor around a portal. With pictures bound its colour is taken
// from them (heavily blurred, mixed with the base colour), so it matches
// wherever the portal leads. It breathes in step with the portal shader.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - x: pictures (0..2), y: unused, z: share of the image's width shown
//   uColor  - base colour; its alpha is the intensity
//   uImg0 / uImg1 - the pictures, bottom layer first

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uColor;
uniform sampler2D uImg0;
uniform sampler2D uImg1;

out vec4 fragColor;

vec3 pictureTint() {
  vec3 sum = vec3(0.0);
  for (int i = 0; i < 9; i++) {
    float a = float(i) * 0.698;
    vec2 p = clamp(vec2(0.5 + cos(a) * 0.25 * uPic.z, 0.5 + sin(a) * 0.3), 0.0, 1.0);
    vec3 col = texture(uImg0, p).rgb;
    if (uPic.x > 1.5) {
      vec4 f = texture(uImg1, p);
      col = mix(col, f.rgb, f.a);
    }
    sum += col;
  }
  return sum / 9.0;
}

void main() {
  vec2 p = (FlutterFragCoord().xy - uOrigin) / uSize * 2.0 - 1.0;
  float d = length(p);
  float f = pow(max(0.0, 1.0 - d), 2.0);

  vec3 tint = uColor.rgb;
  if (uPic.x > 0.5) {
    // Brighter and more saturated than the picture itself, kept warm.
    vec3 pic = pictureTint();
    float l = dot(pic, vec3(0.299, 0.587, 0.114));
    pic = clamp(mix(vec3(l), pic, 1.5) * 1.5, 0.0, 1.0);
    tint = mix(tint, pic, 0.5);
  }

  float breathe = 0.9 + 0.1 * sin(uTime * 1.7);
  float a = f * uColor.a * breathe;
  fragColor = vec4(tint * a, a);
}
