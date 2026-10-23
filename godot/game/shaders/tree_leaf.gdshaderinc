// Leaf cards of the trees (body shared by tree_leaf.gdshader, desktop, and tree_leaf_mobile.gdshader, phones).
// The cards carry a crown-shaped normal (set in tools/tree_gen.ts), so the canopy lights as one volume: bright on the
// sunlit side, darker inside, and glowing at the rim when the sun is behind it (BACKLIGHT). Cheap per pixel: one
// texture read, no loops.
#include "res://game/shaders/tree_common.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut = 0.5;
uniform float roughness = 0.62;
uniform float translucency = 0.6;     // how much light comes through a leaf from behind
uniform float sway = 1.0;
uniform float flutter = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float snow_hold = 0.6;        // how much snow the foliage holds (conifers more than broadleaf)

varying vec4 vCol;
varying vec3 vVar;
varying float vShade;
varying float vSnow;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wv = tree_wind(VERTEX, wp, UV2.x, UV2.y, flutter, sway);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wv;
	vCol = COLOR;
	vShade = world_shade(wp + wv);       // per vertex: cheap, and safe on phone GPUs
	vVar = tree_variety(MODEL_MATRIX[3].xz);
	// snow settles on the upper, outer foliage
	vec3 wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vSnow = g_snow * snow_hold * smoothstep(0.05, 0.75, wn.y) * (0.35 + 0.65 * COLOR.a);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// mipmaps average the leaf edges away; scaling alpha with the mip level keeps distant crowns from thinning out
	vec2 tsz = vec2(textureSize(albedo_tex, 0));
	vec2 dx = dFdx(UV * tsz), dy = dFdy(UV * tsz);
	float mip = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	float a = t.a * (1.0 + mip * 0.28);
	vec3 c = t.rgb * vCol.rgb * 1.12 * tint * vVar;
	c = mix(c, vec3(0.84, 0.86, 0.9) * (0.55 + 0.45 * vCol.r), clamp(vSnow, 0.0, 0.85));
	c *= mix(1.0, 0.78, g_wet);
	c *= clamp(vShade, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = roughness * mix(1.0, 0.55, g_wet);
	SPECULAR = mix(0.14, 0.55, g_wet);
	// cards are two-sided: the renderer turns the normal round on the back face; undo that so both faces share the
	// crown's outward normal (no black leaves on the far side of a card)
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// light through a leaf is deeper in colour than light off it (it passes the pigment twice); thin outer leaves
	// pass more than inner ones; warmed a little, as leaves are against a low sun
	vec3 through = mix(c, c * c * 3.0, 0.5);
	BACKLIGHT = through * vec3(1.1, 1.0, 0.8) * translucency * (0.5 + 0.5 * vCol.a) * (1.0 - vSnow);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
#ifdef TREE_A2C
	ALPHA_ANTIALIASING_EDGE = 0.35;
	ALPHA_TEXTURE_COORDINATE = UV * tsz;
#endif
}

