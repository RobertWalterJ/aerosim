// Farm buildings (the barn and the silo in game/new_models2.gd). A photographed PBR set (albedo, OpenGL normal, ARM) is
// laid on each face at its real size, projected in the model's own axes so boards, sheets and blocks stay square to the
// building. The vertex colour picks the finish of each face:
//   kind 0 painted wood: rgb is the paint (barn red, white trim, black ironwork); alpha is how much paint is left
//          (1 painted, 0 bare grey boards). Each board fades a little differently and the paint wears off in patches.
//   kind 1 sheet steel: rgb tints the galvanised sheet (grey roof, rust streaks); the corrugations run down the slope.
//   kind 2 masonry (fieldstone foundation): rgb tints the stones.
//   kind 3 concrete (silo staves): rgb tints the concrete (grime, rain streaks, steel hoops).
// proj 0 lays the set on flat faces (u runs level along the face, v up it, so wall boards stand upright and roof
// corrugations run from eave to ridge); proj 1 wraps it round the model's y axis (the silo) with whole repeats.
// Rain darkens and glosses every surface (g_wet), snow settles on up-facing faces (g_snow), and cloud and drone
// shadows fall on it like on the ground (world_shade).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform int kind = 0;
uniform int proj = 0;
uniform sampler2D set_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_arm : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;   // r occlusion, g roughness, b metal
uniform vec2 set_metres = vec2(1.5, 1.5);     // metres per repeat across (u) and up (v)
uniform float tint_gain = 1.0;                // kinds 1 to 3: albedo = set x vertex colour x gain
uniform float normal_amt = 1.0;
uniform float metal_amt = 0.0;
uniform float cyl_radius = 2.5;               // proj 1: the radius the repeats are counted round
uniform float boards = 5.0;                   // kind 0: boards across one repeat (wood_planks_grey has five)
uniform float snow_from = 0.45;               // the up-facing slope (normal y) where snow starts to lie

varying vec3 vP;          // model space
varying vec3 vN;
varying vec3 vWorld;
varying vec4 vCol;
varying vec3 vR0;
varying vec3 vR1;
varying vec3 vR2;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vP = VERTEX;
	vN = NORMAL;
	vCol = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);     // the models' colours are written in sRGB
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vR0 = MODEL_MATRIX[0].xyz; vR1 = MODEL_MATRIX[1].xyz; vR2 = MODEL_MATRIX[2].xyz;
}

void fragment() {
	vec3 n = normalize(vN);
	// the face frame: t level along the face, b up it (b = n x t, so t, b, n is a right-handed tangent frame)
	vec3 t;
	vec2 uv;
	vec2 gx; vec2 gy;
	if (abs(n.y) > 0.985) {
		t = vec3(1.0, 0.0, 0.0);
		uv = vec2(vP.x, vP.z) / set_metres;
		gx = dFdx(uv); gy = dFdy(uv);
	} else if (proj == 1) {
		// round the y axis: a whole number of repeats, and the derivatives taken from whichever angle has no wrap here
		vec2 hz = normalize(vec2(vP.x, vP.z) + vec2(1e-5));
		t = vec3(-hz.y, 0.0, hz.x);
		float reps = max(1.0, floor(6.2831853 * cyl_radius / set_metres.x + 0.5));
		float a = atan(vP.z, vP.x) / 6.2831853;
		float ua = fract(a) * reps;
		float ub = (fract(a + 0.5) - 0.5) * reps;
		float v = vP.y / set_metres.y;      // b points down here (n x t), so v grows up and the map's green stays right
		uv = vec2(ua, v);
		float use_b = step(fwidth(ub), fwidth(ua) - 1e-6);
		float uu = mix(ua, ub, use_b);
		gx = vec2(dFdx(uu), dFdx(v)); gy = vec2(dFdy(uu), dFdy(v));
	} else {
		t = normalize(vec3(n.z, 0.0, -n.x));
		vec3 bb = cross(n, t);
		uv = vec2(dot(vP, t), -dot(vP, bb)) / set_metres;
		gx = dFdx(uv); gy = dFdy(uv);
	}
	vec3 b = cross(n, t);
	vec3 sa = textureGrad(set_albedo, uv, gx, gy).rgb;
	vec3 arm = textureGrad(set_arm, uv, gx, gy).rgb;
	vec2 tn = textureGrad(set_normal, uv, gx, gy).xy * 2.0 - 1.0;
	float n1 = vn(vWorld * 0.9);
	float n2 = vn(vWorld * 7.0);
	vec3 a;
	float rough = arm.g;
	float metal = arm.b * metal_amt;
	float nd = normal_amt;
	if (kind == 0) {
		// painted boards: the paint takes the grain of the grey wood under it, each board fades its own way,
		// and the paint has worn through in patches (most at the foot and on the weather side of the boards)
		float board = floor(uv.x * boards);
		float bh = h31(vec3(board, floor(uv.y) * 3.1, dot(n, vec3(1.0, 3.0, 5.0))));
		float wl = dot(sa, vec3(0.299, 0.587, 0.114));
		vec3 paint = vCol.rgb * mix(0.98, 0.78, bh * bh);
		paint = mix(paint, paint * vec3(1.18, 1.0, 0.95) + vec3(0.05, 0.03, 0.03), 0.3 * h31(vec3(board, 7.0, 1.0)));   // sun-faded boards
		vec3 painted = paint * clamp(0.55 + 2.2 * wl, 0.55, 1.35);
		// worn streaks run along the grain (stretched up the board), mostly near the foot and on a few tired boards
		float streaks = vn(vec3(uv.x * boards * 3.0, uv.y * 1.2, bh * 9.0)) * 0.6 + vn(vec3(uv.x * boards * 9.0, uv.y * 4.0, 3.0)) * 0.4;
		float wear = smoothstep(0.66, 0.86, streaks * 0.75 + 0.2 * n1 + 0.3 * (1.0 - smoothstep(0.0, 1.0, vP.y)) + 0.12 * bh);
		float cover = vCol.a * (1.0 - 0.9 * wear);
		a = mix(sa * 1.05, painted, cover);
		rough = mix(rough, 0.72, cover * 0.6);
	} else {
		a = sa * vCol.rgb * tint_gain;
		if (kind == 1) {
			// weathered galvanising: duller sheets here and there, darker where water runs off
			a *= 0.9 + 0.2 * n1;
			rough = mix(rough, 0.75, 0.3 * n1);
		}
		a *= 0.92 + 0.16 * n1;
	}
	// cloud and drone shadows
	a *= world_shade(vWorld);
	// rain: darker, shinier, a sheen of water on the steel
	float wk = g_wet * (kind == 1 ? 0.6 : 1.0);
	a *= mix(1.0, kind == 0 ? 0.62 : 0.66, wk);
	rough = mix(rough, kind == 1 ? rough * 0.25 : max(rough * 0.7, 0.55), g_wet);   // wet steel shines, wet boards only dull-sheen
	// snow on the faces that look up (in the building's own axes, so a tipped model would shed it)
	float up = n.y;
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.35, up) * (0.75 + 0.25 * n1);
	snow = clamp(snow * (1.0 + 0.5 * g_snow), 0.0, 1.0);
	a = mix(a, vec3(0.66, 0.69, 0.76), snow);
	rough = mix(rough, 0.82, snow);
	metal *= 1.0 - snow;
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metal;
	SPECULAR = kind == 1 ? 0.5 + 0.3 * g_wet : 0.4 + 0.1 * g_wet;
	AO = mix(arm.r, 1.0, snow);
	AO_LIGHT_AFFECT = 0.3;
	vec3 nm = normalize(n + nd * (1.0 - 0.8 * snow) * (t * tn.x + b * tn.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nm, 0.0)).xyz);
}
