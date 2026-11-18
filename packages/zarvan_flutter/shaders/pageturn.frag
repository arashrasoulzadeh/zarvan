#include <flutter/runtime_effect.glsl>

// A page turn over a snapshot: the sheet (a frozen picture of the screen that
// is leaving) lifts from its right edge and rolls up over a cylinder as the
// fold travels left, showing the paper's back where it has folded over and the
// scene underneath where it has left. Progress 0 = the sheet lies flat, 1 =
// it is gone.
//
//   uSize      - size of the rect being painted, in canvas units
//   uImageSize - size of the snapshot, in its own pixels (unused: the sampler
//                takes normalised coordinates)
//   uProgress  - 0..1
//   uRadius    - radius of the roll, in canvas units
//   uTilt      - how far the fold leans (0 straight up and down)
//   uPaper     - colour of the page's back
//   uImage     - the snapshot

uniform vec2 uSize;
uniform vec2 uImageSize;
uniform float uProgress;
uniform float uRadius;
uniform float uTilt;
uniform vec4 uPaper;
uniform sampler2D uImage;

out vec4 fragColor;

vec4 front(vec2 p) {
  vec2 uv = clamp(p / uSize, 0.0, 1.0);
  return texture(uImage, uv);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float W = uSize.x;
  float H = uSize.y;
  float R = uRadius;
  float PI = 3.14159265;

  // The page is sheared so the fold leans: work in u = x + (H - y) * tilt.
  float lean = (H - p.y) * uTilt;
  float u = p.x + lean;
  float Wu = W + H * uTilt; // the page's width in this space

  // Where the fold is: from the far right edge to past the left edge.
  float t = clamp(uProgress, 0.0, 1.0);
  float ease = t * t * (3.0 - 2.0 * t);
  float xf = Wu - ease * (Wu + R * 1.4);

  float L = Wu - xf; // length of the page beyond the fold

  vec4 outc = vec4(0.0);

  if (u <= xf) {
    // Flat. Is the folded-back part lying over it here?
    float a = PI * R + (xf - u);
    if (a <= L) {
      // The back of the page, lying on top. Faintly shows the page's own
      // picture through the paper, mirrored.
      float uo = xf + a;
      vec2 po = vec2(uo - lean, p.y);
      vec4 pic = front(po);
      vec3 back = mix(uPaper.rgb, pic.rgb, 0.14);
      // A little shade near the fold where the paper curves down.
      float near = smoothstep(0.0, R * 1.6, xf - u);
      back *= 0.86 + 0.14 * near;
      outc = vec4(back, 1.0);
    } else {
      vec4 c = front(p);
      // Ambient shade where the roll rises above the page.
      float shade = 1.0 - 0.28 * exp(-(xf - u) / (R * 1.4)) * smoothstep(0.0, 0.05, t);
      outc = vec4(c.rgb * shade, c.a);
    }
  } else if (u <= xf + R) {
    float s = (u - xf) / R; // 0..1 across the roll
    float a1 = R * asin(clamp(s, 0.0, 1.0));       // near (lower) layer
    float a2 = PI * R - R * asin(clamp(s, 0.0, 1.0)); // far (upper) layer
    if (a2 <= L) {
      // The upper layer faces us with its back, curving away.
      float ang = a2 / R; // PI/2..PI
      vec3 back = uPaper.rgb;
      float light = 0.62 + 0.38 * pow(sin(clamp(ang, 0.0, PI)), 0.6);
      back *= light;
      // A bright catch of light along the top of the roll.
      back += 0.18 * pow(max(0.0, 1.0 - abs(s - 0.9) * 7.0), 2.0);
      outc = vec4(back, 1.0);
    } else {
      // Only the near layer (the page's front, curving up).
      float uo = xf + a1;
      vec4 c = front(vec2(uo - lean, p.y));
      float ang = a1 / R;
      float light = 0.55 + 0.45 * cos(ang);
      outc = vec4(c.rgb * light, c.a);
    }
  } else {
    // Past the roll: the scene underneath, with the page's shadow on it.
    float d = u - (xf + R);
    float sh = exp(-d / (R * 1.7)) * 0.4 * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.92, 1.0, t));
    outc = vec4(0.0, 0.0, 0.0, sh);
  }

  fragColor = vec4(outc.rgb * outc.a, outc.a);
}
