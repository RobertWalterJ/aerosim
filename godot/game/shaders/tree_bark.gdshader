// Tree trunks and branches: photographed bark (assets/textures/bark_*.jpg) laid on at real size, with its normal map,
// moss low on the north side, rain (darker and glossier, wettest in the furrows) and snow on the upper faces of limbs.
// UV from tools/tree_gen.ts is in metres (around, along); tile_m is the size of one repeat.
shader_type spatial;
render_mode depth_draw_opaque, specular_schlick_ggx;
#include "res://game/shaders/tree_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec2 tile_m = vec2(1.0);
uniform vec3 tint = vec3(1.0);
uniform float desat = 0.0;            // takes colour out of a photographed set (beech grey from a yellowish bark)
uniform float normal_amt = 1.0;
uniform float moss = 0.35;
uniform float sway = 1.0;

varying vec3 vCol;
varying vec3 vVar;
varying float vShade;
varying vec3 vN;
varying float vH;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wv = tree_wind(VERTEX, wp, UV2.x, UV2.y, 0.0, sway);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wv;
	vCol = COLOR.rgb;
	vShade = world_shade(wp + wv);
	vVar = mix(vec3(1.0), tree_variety(MODEL_MATRIX[3].xz), 0.5);
	vN = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vH = VERTEX.y;
}

void fragment() {
	vec2 uv = UV / tile_m;
	vec3 t = texture(albedo_tex, uv).rgb;
	float lum = dot(t, vec3(0.3, 0.5, 0.2));
	t = mix(t, vec3(lum), desat);
	vec3 c = t * vCol * tint * vVar;
	// green algae and moss on the shaded north side, low on the trunk
	float m = moss * smoothstep(0.2, -0.75, vN.z) * (1.0 - smoothstep(0.4, 3.5, vH)) * (0.6 + 0.8 * (1.0 - lum));
	c = mix(c, vec3(0.13, 0.19, 0.07) * (0.7 + lum), clamp(m, 0.0, 0.8));
	// rain: the bark darkens and shines, the dark furrows most
	float crev = 1.0 - smoothstep(0.08, 0.35, lum);
	c *= mix(1.0, 0.58 - 0.12 * crev, g_wet);
	float rough = mix(0.95, 0.78, lum);
	rough = mix(rough, 0.3 + 0.25 * (1.0 - crev), g_wet);
	// snow on the upper faces of limbs and on the windward side of the trunk
	float sn = g_snow * (smoothstep(0.3, 0.8, vN.y) + 0.25 * smoothstep(0.4, 0.9, dot(vN.xz, -normalize(g_wind.xz + vec2(0.001)))));
	sn = clamp(sn, 0.0, 0.9);
	c = mix(c, vec3(0.86, 0.88, 0.92), sn);
	c *= clamp(vShade, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = mix(rough, 0.65, sn);
	SPECULAR = mix(0.3, 0.6, g_wet);
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_amt * (1.0 - 0.7 * sn);
}
