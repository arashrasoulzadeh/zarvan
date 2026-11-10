#include <flutter/runtime_effect.glsl>

// A band of light that sweeps across a picture now and then, only where that
// picture is opaque (so it follows the shape of a button or a banner). Drawn
// additively over the sprite it belongs to.
//
//   uOrigin - top-left of the rect, in pixels
//   uSize   - rect size, in pixels
//   uTime   - seconds (already multiplied by the effect's speed)
//   uPic    - y: seconds between sweeps
//   uColor  - colour of the light; its alpha is the intensity
//   uImg0   - the picture whose opaque pixels are lit (the whole image)

uniform vec2 uOrigin;
uniform vec2 uSize;
uniform float uTime;
uniform vec3 uPic;
uniform vec4 uColor;
uniform sampler2D uImg0;
uniform sampler2D uImg1;

out vec4 fragColor;

void main() {
  vec2 uv = (FlutterFragCoord().xy - uOrigin) / uSize;
  float mask = texture(uImg0, clamp(uv, 0.0, 1.0)).a;

  float period = max(uPic.y, 0.5);
  float phase = fract(uTime / period);
  // The band travels across in the first ~40% of each period, then rests.
  float travel = clamp(phase / 0.4, 0.0, 1.0);
  float pos = -0.3 + travel * 1.6;
  float x = uv.x + uv.y * 0.35;
  float band = smoothstep(0.13, 0.0, abs(x - pos)) * step(phase, 0.4);

  float a = band * mask * uColor.a;
  fragColor = vec4(uColor.rgb * a, a);
}
