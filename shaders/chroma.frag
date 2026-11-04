#version 460 core
#include <flutter/runtime_effect.glsl>

// Green-screen preview: removes pixels close to uKey, matching FFmpeg's
// colorkey (RGB distance / sqrt(3), soft edge of uBlend).
uniform vec2 uSize;
uniform vec3 uKey;
uniform float uSimilarity;
uniform float uBlend;
uniform sampler2D uInput;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 c = texture(uInput, uv);
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : c.rgb;
  float d = distance(rgb, uKey) / 1.7320508;
  float a = smoothstep(uSimilarity, uSimilarity + uBlend, d);
  fragColor = c * a;
}
