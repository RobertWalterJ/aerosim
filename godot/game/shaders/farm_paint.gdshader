// Painted metal, hulls and sails' fittings (game/new_models5.gd): machinery paint (a combine's green, a seed drill's red), boat
// hulls, tanks and doors. The vertex colour is the paint; the vertex ALPHA is how worn it is (0 new, 1 ruined):
// wear chalks and fades the paint, breaks it into rust patches along a noise, rubs bare metal at the worst spots, and the
// lowest part of a machine is splashed with dried mud. New paint has a clear coat that catches the sun; worn paint does not.
// Rain darkens and glosses it, snow lies on what faces up, and the cloud and drone shadows fall on it.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform float gloss = 0.3;             // paint roughness when new
uniform float metal_amt = 0.0;         // 0 painted, 1 raw metal (the vertex colour is the metal)
uniform float mud_to = 0.0;            // height (model metres) up to which dried mud splashes the paint
uniform vec3 rust_col = vec3(0.34, 0.16, 0.07);
uniform float ripple = 0.0;            // corrugation (galvanised bins): ridges per metre across the model's y
uniform float snow_from = 0.55;

varying vec3 vP;
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
	vCol = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vR0 = MODEL_MATRIX[0].xyz; vR1 = MODEL_MATRIX[1].xyz; vR2 = MODEL_MATRIX[2].xyz;
}

void fragment() {
	vec3 n = normalize(vN);
	float wear = vCol.a;
	float n1 = vn(vP * 4.0 + 1.3);
	float n2 = vn(vP * 17.0);
	float n3 = vn(vP * 53.0);
	vec3 a = vCol.rgb * (0.94 + 0.12 * n1);
	float rough = gloss;
	float metal = metal_amt;
	float clear = 0.0;
	// chalking: worn paint goes paler and flatter
	a = mix(a, a * 1.25 + 0.04, wear * 0.4 * n1);
	rough = mix(rough, 0.75, wear * 0.8);
	// rust: breaks out where a mid-size noise and the wear agree, with a rim of darker staining
	float rm = smoothstep(0.62, 0.72, n1 * 0.55 + n2 * 0.35 + n3 * 0.1 + wear * 0.55 - 0.38);
	if (wear < 0.02) rm = 0.0;
	vec3 rc = rust_col * (0.7 + 0.6 * n3);
	a = mix(a, rc, rm);
	rough = mix(rough, 0.85, rm);
	metal = mix(metal, 0.0, rm);
	// rubbed bare: a few bright scratches in the worst places
	float sc = smoothstep(0.86, 0.95, n3) * smoothstep(0.55, 0.9, wear);
	a = mix(a, vec3(0.55, 0.55, 0.57), sc * 0.6);
	metal = mix(metal, 1.0, sc * 0.6);
	// the clear coat of good paint
	if (metal_amt < 0.5) clear = 0.55 * (1.0 - wear) * (1.0 - rm);
	// dried mud thrown up from the ground
	if (mud_to > 0.0) {
		float mh = mud_to * (0.5 + 0.7 * n2) ;
		float mud = 1.0 - smoothstep(mh * 0.6, mh, vP.y);
		a = mix(a, vec3(0.16, 0.115, 0.075) * (0.8 + 0.4 * n3), mud * 0.85);
		rough = mix(rough, 0.95, mud);
		metal = mix(metal, 0.0, mud);
		clear *= 1.0 - mud;
	}
	vec3 nm = n;
	if (ripple > 0.0) {
		float s = sin(vP.y * ripple * 6.2831853);
		vec3 up = vec3(0.0, 1.0, 0.0);
		nm = normalize(n + up * s * 0.35);
		a *= 0.9 + 0.12 * s;
	}
	a *= world_shade(vWorld);
	a *= mix(1.0, 0.72, g_wet);
	rough = mix(rough, max(rough * 0.5, 0.15), g_wet);
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.3, n.y) * (0.8 + 0.2 * n1);
	a = mix(a, vec3(0.66, 0.69, 0.76), clamp(snow * 1.3, 0.0, 1.0));
	rough = mix(rough, 0.82, clamp(snow, 0.0, 1.0));
	metal *= 1.0 - clamp(snow, 0.0, 1.0);
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	SPECULAR = 0.5 + 0.1 * g_wet;
	CLEARCOAT = clear;
	CLEARCOAT_ROUGHNESS = 0.12;
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nm, 0.0)).xyz);
}
