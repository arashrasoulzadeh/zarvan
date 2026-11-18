#include <flutter/runtime_effect.glsl>

// Water: a drop falls on the frozen screen that is leaving and rings spread
// from it. The picture bends as the rings pass (the way a reflection shivers),
// and behind the leading ring it is gone, revealing the next screen through
// settling water: a faint cool sheen and glints on the slopes of the waves that
// die away. The leading ring itself is a thin line of light. Progress 0 = the
// picture lies still, 1 = the water has cleared.
//
//   uSize      - size of the rect being painted, in canvas units
//   uOrigin    - where the drop fell, in canvas units
//   uProgress  - 0..1
//   uImage     - the snapshot (normalised coordinates)

uniform vec2 uSize;
uniform vec2 uOrigin;
uniform float uProgress;
uniform sampler2D uImage;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  float H = uSize.y;
  float t = clamp(uProgress, 0.0, 1.0);
  float ease = t * t * (3.0 - 2.0 * t);

  // How far the farthest corner is, so the front always clears the screen.
  vec2 far = max(uOrigin, uSize - uOrigin);
  float reach = length(far);
  float R = ease * reach * 1.12;

  vec2 off = p - uOrigin;
  float d = length(off);
  vec2 dir = d > 0.001 ? off / d : vec2(0.0, 1.0);

  // The rings: a wave train that is strongest at the front and dies off
  // behind it, with a short precursor ahead.
  float wavelength = H * 0.075;
  float k = 6.2831853 / wavelength;
  float behind = max(R - d, 0.0);
  float ahead = max(d - R, 0.0);
  float env = exp(-behind / (reach * 0.22)) * exp(-ahead / (H * 0.035));
  float calm = 1.0 - smoothstep(0.55, 1.0, t); // the water settles toward the end
  float phase = k * (d - R * 1.0);
  float wave = sin(phase);
  float slope = cos(phase);

  // The picture bends along the rings.
  float amp = H * 0.016 * env * calm * smoothstep(0.0, 0.08, t);
  vec2 q = p + dir * wave * amp;
  vec4 pic = texture(uImage, clamp(q / uSize, 0.0, 1.0));

  // The picture is gone behind the leading ring, softly.
  float edge = H * 0.02;
  float seen = smoothstep(R - edge, R + edge, d) * step(0.0005, t);
  seen = max(seen, 1.0 - step(0.0005, t));

  // Sheen over the revealed screen, and glints on the wave slopes.
  float water = (1.0 - seen) * env * calm;
  vec3 tint = vec3(0.45, 0.78, 0.9);
  float glint = pow(max(slope, 0.0), 6.0) * env * calm * (1.0 - seen);
  // The leading ring: a thin bright line.
  float ring = exp(-pow((d - R) / (H * 0.0085), 2.0)) * smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.92, 1.0, t));

  vec3 col = pic.rgb * seen * pic.a;
  float a = seen * pic.a;
  vec3 add = tint * water * 0.22 + vec3(0.9, 1.0, 1.0) * (glint * 0.34 + ring * 0.7);
  float addA = clamp(water * 0.22 + glint * 0.3 + ring * 0.6, 0.0, 0.7);
  col += add * (1.0 - a);
  a = clamp(a + addA * (1.0 - a), 0.0, 1.0);
  fragColor = vec4(min(col, vec3(1.0)), a);
}
