// Farm props (game/new_models3.gd): fences, hay, field ground. Photographed CC0 PBR sets (albedo, OpenGL normal, ARM) laid on
// every face at real size in the model's own axes (triplanar, so a post, a rail and a bale all take the grain the right way),
// with rain, snow and the cloud and drone shadows like the barn and the ground. The vertex colour picks the finish.
//   kind 0 weathered wood: rgb tints the grey timber; alpha says which way the grain runs (1 up, 0.75 along x, 0.5 along z, 0 none)
//   kind 1 galvanised wire and steel: rgb is the metal; a little bloom of zinc and rust from noise
//   kind 2 hay and straw: rgb is the straw colour; fine chaff from the photographed set and stalk streaks along alpha's axis
//   kind 3 plastic bale wrap: glossy stretched film with soft wrinkles; rgb is the film, hay shows through darker patches
//   kind 4 tilled soil: rgb darker where the soil is damp (furrow bottoms), crumb normals, lies flat on the ground plane
//   kind 5 muddy track: like soil but the damp spots hold water and shine
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform int kind = 0;
uniform sampler2D set_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_arm : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;   // r occlusion, g roughness, b metal
uniform float metres = 1.0;          // metres per repeat
uniform float normal_amt = 1.0;
uniform float tint_gain = 1.0;       // albedo = photographed luminance x vertex colour x gain
uniform float lum_avg = 0.25;       // the photograph's mean luminance, so the vertex colour keeps its own brightness
uniform float nat = 0.0;             // how much of the photograph's own colour is kept (0 only its light and dark)
uniform float snow_from = 0.5;

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

float streak_at(vec3 p, int ax) {
	// stalks: a noise stretched along the grain
	if (ax == 0) return vn(vec3(p.x * 90.0, p.y * 7.0, p.z * 90.0)) * 0.6 + vn(vec3(p.x * 30.0, p.y * 3.0, p.z * 30.0)) * 0.4;
	if (ax == 1) return vn(vec3(p.x * 7.0, p.y * 90.0, p.z * 90.0)) * 0.6 + vn(vec3(p.x * 3.0, p.y * 30.0, p.z * 30.0)) * 0.4;
	if (ax == 2) return vn(vec3(p.x * 90.0, p.y * 90.0, p.z * 7.0)) * 0.6 + vn(vec3(p.x * 30.0, p.y * 30.0, p.z * 3.0)) * 0.4;
	return vn(p * 45.0);
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
	vec3 alb;
	vec3 arm;
	vec3 off;                    // the normal map's push, in model space
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	int ax = 3;
	if (vCol.a > 0.9) ax = 0; else if (vCol.a > 0.6) ax = 1; else if (vCol.a > 0.35) ax = 2;
	if (kind == 1 || kind == 3 || kind == 4 || kind == 5) ax = 3;
	if (kind == 4 || kind == 5) {
		// ground: one flat projection on the ground plane (the mud's wheel lines run along z)
		vec2 uv = (kind == 5 ? vec2(vP.z, vP.x) : vec2(vP.x, vP.z)) / metres;
		alb = texture(set_albedo, uv).rgb;
		arm = texture(set_arm, uv).rgb;
		vec2 tn = texture(set_normal, uv).xy * 2.0 - 1.0;
		off = kind == 5 ? vec3(tn.y, 0.0, tn.x) : vec3(tn.x, 0.0, tn.y);
	} else {
		// triplanar. Wood and hay choose the axis the grain runs along from the vertex alpha, so v follows it.
		vec2 uX; vec2 uY; vec2 uZ;      // the (u, v) of the x-facing, y-facing and z-facing planes
		vec3 oX_u = vec3(0, 0, 1); vec3 oX_v = vec3(0, 1, 0);
		vec3 oY_u = vec3(1, 0, 0); vec3 oY_v = vec3(0, 0, 1);
		vec3 oZ_u = vec3(1, 0, 0); vec3 oZ_v = vec3(0, 1, 0);
		if (ax == 1) {              // grain along x
			uX = vP.zy; uY = vec2(vP.z, vP.x); uZ = vec2(vP.y, vP.x);
			oX_u = vec3(0, 0, 1); oX_v = vec3(0, 1, 0);
			oY_u = vec3(0, 0, 1); oY_v = vec3(1, 0, 0);
			oZ_u = vec3(0, 1, 0); oZ_v = vec3(1, 0, 0);
		} else if (ax == 2) {       // grain along z
			uX = vec2(vP.y, vP.z); uY = vec2(vP.x, vP.z); uZ = vP.xy;
			oX_u = vec3(0, 1, 0); oX_v = vec3(0, 0, 1);
			oY_u = vec3(1, 0, 0); oY_v = vec3(0, 0, 1);
			oZ_u = vec3(1, 0, 0); oZ_v = vec3(0, 1, 0);
		} else {                    // grain up (or none)
			uX = vP.zy; uY = vP.xz; uZ = vP.xy;
		}
		uX /= metres; uY /= metres; uZ /= metres;
		vec3 ax_ = texture(set_albedo, uX).rgb; vec3 ay_ = texture(set_albedo, uY).rgb; vec3 az_ = texture(set_albedo, uZ).rgb;
		alb = ax_ * w.x + ay_ * w.y + az_ * w.z;
		arm = texture(set_arm, uX).rgb * w.x + texture(set_arm, uY).rgb * w.y + texture(set_arm, uZ).rgb * w.z;
		vec2 tx = texture(set_normal, uX).xy * 2.0 - 1.0;
		vec2 ty = texture(set_normal, uY).xy * 2.0 - 1.0;
		vec2 tz = texture(set_normal, uZ).xy * 2.0 - 1.0;
		off = (oX_u * tx.x + oX_v * tx.y) * w.x + (oY_u * ty.x + oY_v * ty.y) * w.y + (oZ_u * tz.x + oZ_v * tz.y) * w.z;
	}
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	float rel = clamp(lum / lum_avg, 0.3, 2.4);
	float n1 = vn(vWorld * 0.7);
	float n2 = vn(vP * 23.0);
	vec3 a = vCol.rgb;
	float rough = arm.g;
	float metal = 0.0;
	float nd = normal_amt;
	float spec = 0.4;
	float damp = 0.0;
	if (kind == 0) {
		a = vCol.rgb * rel * tint_gain * mix(vec3(1.0), alb / max(lum, 0.01), nat) * (0.9 + 0.2 * n1);
		rough = mix(rough, 0.9, 0.2);
	} else if (kind == 1) {
		// galvanised and rusty steel: bright zinc, a few rusty freckles, a sheen that rain makes stronger
		float rust = smoothstep(0.62, 0.8, vn(vP * 55.0 + vWorld * 0.0) * 0.6 + n1 * 0.5);
		a = mix(vCol.rgb * (0.9 + 0.2 * n2), vec3(0.36, 0.18, 0.09), rust * 0.55);
		metal = mix(0.9, 0.25, rust);
		rough = mix(0.34 + 0.2 * n2, 0.7, rust);
		nd = 0.0;
		spec = 0.6;
	} else if (kind == 2) {
		// hay: the chaff of the photographed set in the straw colour, with stalks streaked along the bale's grain
		float streak = streak_at(vP, ax);
		a = vCol.rgb * rel * tint_gain * (0.78 + 0.4 * streak) * (0.9 + 0.2 * n1);
		rough = 0.95;
		spec = 0.2;
	} else if (kind == 3) {
		// stretched film: pale, glossy, wrinkled; where the film is thin the hay shows through
		float wr = vn(vP * 14.0) * 0.6 + vn(vP * 31.0) * 0.4;
		a = mix(vCol.rgb, vCol.rgb * vec3(0.72, 0.84, 0.5), 0.45 * smoothstep(0.35, 0.8, wr));
		rough = 0.2 + 0.25 * wr;
		spec = 0.7;
		off = vec3(vn(vP * 20.0 + 3.0) - 0.5, vn(vP * 20.0 + 9.0) - 0.5, vn(vP * 20.0 + 15.0) - 0.5) * 0.9;
		nd = 0.5;
	} else if (kind == 4) {
		damp = 1.0 - smoothstep(0.015, 0.06, dot(vCol.rgb, vec3(0.299, 0.587, 0.114)));
		a = vCol.rgb * rel * tint_gain * (0.9 + 0.2 * n1);
		a *= mix(1.0, 0.7, damp * 0.6);
		rough = mix(rough, 0.55, damp * 0.6);
	} else {
		damp = 1.0 - smoothstep(0.012, 0.05, dot(vCol.rgb, vec3(0.299, 0.587, 0.114)));
		a = vCol.rgb * rel * tint_gain * (0.9 + 0.2 * n1);
		a *= mix(1.0, 0.65, damp * 0.7);
		rough = mix(rough, 0.12, damp * 0.85);       // water standing in the wheel ruts
		spec = mix(0.4, 0.9, damp);
	}
	// cloud and drone shadows
	a *= world_shade(vWorld);
	// rain: darker and shinier
	a *= mix(1.0, kind == 1 ? 0.9 : 0.68, g_wet);
	rough = mix(rough, kind == 1 ? rough * 0.5 : max(rough * 0.55, 0.3), g_wet);
	// snow on what faces up
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.3, n.y) * (0.75 + 0.25 * n1) * (kind == 1 ? 0.5 : 1.0);
	snow = clamp(snow * (1.0 + 0.5 * g_snow), 0.0, 1.0);
	a = mix(a, vec3(0.66, 0.69, 0.76), snow);
	rough = mix(rough, 0.82, snow);
	metal *= 1.0 - snow;
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metal;
	SPECULAR = spec + 0.1 * g_wet;
	AO = mix(arm.r, 1.0, snow);
	AO_LIGHT_AFFECT = 0.3;
	vec3 nm = normalize(n + nd * (1.0 - 0.8 * snow) * (off - n * dot(off, n)));
	NORMAL = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nm, 0.0)).xyz);
}
