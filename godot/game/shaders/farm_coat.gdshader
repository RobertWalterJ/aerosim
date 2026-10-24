// Animal coats (game/new_models5.gd): cattle, sheep, horses, dogs and hens. The vertex colour is the base coat (smooth from point
// to point, so a pale belly and a dark leg fade into each other); the shader adds what vertex colours cannot: crisp patches
// (Holstein black and white, a Hereford white face), fine hair streaks that lie along the body, a woolly clumped surface for
// sheep, a soft sheen at grazing angles (the way a coat catches the low sun), rain, snow, and the cloud and drone shadows.
//   vertex alpha: how much of the patch pattern shows (1 on the body, 0 on the lower legs, which are white)
//   patch_thr  1 = no patches; lower = more of the coat is the patch colour (a noise on the model's own axes)
//   wool       0 = smooth hair; 1 = clumped curls (bumps from a noise gradient)
//   barring    stripes across the feathers (hens)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform vec3 patch_col = vec3(0.02, 0.02, 0.02);
uniform float patch_thr = 1.0;
uniform float patch_soft = 0.025;
uniform vec3 patch_axis = vec3(2.2, 3.2, 1.7);
uniform float patch_seed = 0.0;
uniform float hair = 1.0;
uniform float wool = 0.0;
uniform float wool_scale = 9.0;
uniform float barring = 0.0;
uniform float scallop = 0.0;           // feathers: overlapping rows that shade the lower edge of each and give dark plumage a green-purple sheen
uniform float sheen = 0.45;
uniform float rough_base = 0.85;
uniform float snow_from = 0.55;

varying vec3 vP;
varying vec3 vN;
varying vec3 vWorld;
varying vec3 vCol;
varying float vA;
varying vec3 vR0;
varying vec3 vR1;
varying vec3 vR2;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.55 + vn(p * 2.07 + 7.1) * 0.3 + vn(p * 4.3 + 13.7) * 0.15; }

void vertex() {
	vP = VERTEX;
	vN = NORMAL;
	vCol = pow(COLOR.rgb, vec3(2.2));
	vA = COLOR.a;
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vR0 = MODEL_MATRIX[0].xyz; vR1 = MODEL_MATRIX[1].xyz; vR2 = MODEL_MATRIX[2].xyz;
}

void fragment() {
	vec3 n = normalize(vN);
	vec3 a = vCol;
	float irid = 0.0;
	// patches: a lumpy, stretched-along-the-body noise, thresholded with a soft edge, ragged with a finer noise
	if (patch_thr < 0.999) {
		float f = fbm(vP * patch_axis + patch_seed) + (vn(vP * 38.0 + patch_seed) - 0.5) * 0.06;
		float m = 1.0 - smoothstep(patch_thr - patch_soft, patch_thr + patch_soft, f);
		a = mix(a, patch_col, m * vA);
	}
	// hair: fine streaks lying along the body (z) and a slower mottling
	float streak = vn(vP * vec3(210.0, 210.0, 34.0)) * 0.6 + vn(vP * vec3(90.0, 90.0, 16.0)) * 0.4;
	float mott = vn(vP * 5.0 + 3.0);
	a *= (1.0 - 0.14 * hair + 0.28 * hair * streak) * (0.92 + 0.16 * mott);
	if (barring > 0.0) {
		float bar = smoothstep(0.35, 0.65, sin(vP.y * 150.0 + vP.z * 60.0 + vn(vP * 20.0) * 3.0) * 0.5 + 0.5);
		a *= 1.0 - barring * 0.45 * bar;
	}
	if (scallop > 0.0) {
		float row = vP.z * 40.0 + vP.y * 14.0;
		float rz = fract(row);
		float arc = abs(fract(vP.x * 36.0 + floor(row) * 0.5) - 0.5);
		float sc = smoothstep(0.0, 0.6, rz - arc * 0.9);
		a *= (0.68 + 0.42 * sc);
		float lum = dot(a, vec3(0.299, 0.587, 0.114));
		irid = smoothstep(0.12, 0.02, lum) * scallop;
	}
	vec3 nm = n;
	if (wool > 0.0) {
		// clumped curls: the gradient of a noise at curl size pushes the normal, and the crevices go darker
		vec3 q = vP * wool_scale;
		float c0 = vn(q);
		vec3 g = vec3(vn(q + vec3(0.35, 0, 0)) - c0, vn(q + vec3(0, 0.35, 0)) - c0, vn(q + vec3(0, 0, 0.35)) - c0);
		nm = normalize(n + wool * 1.7 * (g - n * dot(g, n)));
		a *= 0.72 + 0.5 * c0;
	} else {
		vec3 q = vP * vec3(160.0, 160.0, 40.0);
		float c0 = vn(q);
		vec3 g = vec3(vn(q + vec3(0.3, 0, 0)) - c0, vn(q + vec3(0, 0.3, 0)) - c0, vn(q + vec3(0, 0, 0.3)) - c0);
		nm = normalize(n + 0.35 * hair * (g - n * dot(g, n)));
	}
	a *= world_shade(vWorld);
	float rough = rough_base;
	a *= mix(1.0, 0.7, g_wet);
	rough = mix(rough, 0.55, g_wet);
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.3, n.y) * (wool > 0.0 ? 0.9 : 0.6);
	a = mix(a, vec3(0.66, 0.69, 0.76), clamp(snow, 0.0, 1.0));
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.3, 1.0);
	SPECULAR = 0.25 + 0.1 * g_wet;
	RIM = sheen;
	RIM_TINT = 0.55;
	AO_LIGHT_AFFECT = 0.4;
	float fr = pow(1.0 - clamp(dot(n, vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 2.0);
	EMISSION = irid * vec3(0.02, 0.09, 0.07) * (0.5 + 0.5 * sin(vP.x * 40.0 + vP.z * 30.0)) * 0.6;
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nm, 0.0)).xyz);
}
