// Far tree silhouettes (60,000 copies in MultiMeshes): every copy is reshaped and recoloured a little from where it
// stands, so a hillside reads as a mix of tall and squat, round and lumpy trees in many colours, not identical lollipops.
// COLOR = baked shading times the copy's colour (from the layout, or the species colour for near trees seen far off).
shader_type spatial;
render_mode specular_disabled;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
global uniform float g_snow;
global uniform float g_wet;

uniform vec3 tint = vec3(1.0);             // sRGB
uniform float lumps = 1.0;             // broadleaf 1, conifer less

varying vec3 vCol;
varying float vShade;
varying float vSnow;

float fh(vec2 p, float k) { return fract(sin(dot(p, vec2(12.9898 + k, 78.233 - k))) * 43758.5453); }

void vertex() {
	vec2 oc = MODEL_MATRIX[3].xz;
	float h1 = fh(oc, 0.0), h2 = fh(oc, 3.1), h3 = fh(oc, 7.7);
	// lumps: a smooth wobble along the normal, different on every copy
	float n = sin(VERTEX.x * 0.85 + h1 * 31.0) * sin(VERTEX.y * 0.6 + h2 * 17.0) * sin(VERTEX.z * 0.8 + h3 * 23.0);
	float up = smoothstep(2.0, 6.0, VERTEX.y);
	VERTEX += NORMAL * n * 0.95 * lumps * up;
	// shape: some taller and narrower, some wider and lower
	float tall = mix(0.82, 1.22, h2);
	VERTEX.y *= tall;
	VERTEX.xz *= mix(1.12, 0.84, h2) * mix(0.92, 1.08, h3);
	vec3 col = COLOR.rgb * pow(tint, vec3(2.2));      // the tint is written as an sRGB colour, like the material colour it replaced
	// colour: a hue and brightness lean per copy; the top catches more light, the base sits in its own shade
	col *= vec3(0.86 + 0.28 * h1, 0.88 + 0.22 * h3, 0.88 + 0.2 * h2);
	vCol = col;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vShade = world_shade(wp);
	vSnow = g_snow * smoothstep(0.1, 0.7, normalize(mat3(MODEL_MATRIX) * NORMAL).y);
}

void fragment() {
	vec3 c = vCol * mix(1.0, 0.8, g_wet);
	c = mix(c, vec3(0.8, 0.82, 0.86), clamp(vSnow * 0.7, 0.0, 0.7));
	ALBEDO = c * clamp(vShade, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
