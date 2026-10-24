// Vehicles and road furniture (game/new_models4.gd): car paint with a clear coat, rubber, chrome, glass, trim, lamp lenses,
// painted sheet metal and concrete. Everything is procedural (no photographs): a fine metallic flake in the paint, hairline
// scratches and rust freckles where the vertex alpha says the finish is worn, road dirt thrown up the lower panels, rain that
// darkens and glosses, snow on what faces up, and the cloud and drone shadows like the rest of the world.
//   kind 0 car paint:   rgb is the paint; alpha is the condition (1 clean, lower = dirty, faded and rusty)
//   kind 1 rubber:      tyre black; alpha 1 new, lower = dusty grey
//   kind 2 metal:       rgb is the metal (chrome, aluminium, zinc, steel); alpha 1 polished, lower = dull
//   kind 3 glass:       dark mirror glass; rgb tints it
//   kind 4 trim:        black and grey plastic, seats, cloth, rubber seals; alpha lowers the sheen
//   kind 5 lamp lens:   glossy coloured plastic; glows with the uniform `glow` (headlamps, tail lamps at night)
//   kind 6 sheet:       painted sheet steel and signs (flat colour, satin); alpha is the condition
//   kind 7 concrete:    cast concrete with pits and stains; alpha is the condition
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform int kind = 0;
uniform float glow = 0.0;            // lamp lens emission
uniform float dirt = 0.5;            // road dirt on the lower panels, 0 to 1
uniform float dirt_h = 0.7;          // metres up from the ground that the spray reaches
uniform float snow_from = 0.55;

varying vec3 vP;
varying vec3 vN;
varying vec3 vWorld;
varying vec4 vCol;
varying vec3 vR0;
varying vec3 vR1;
varying vec3 vR2;
varying float vGround;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.55 + vn(p * 2.1) * 0.3 + vn(p * 4.3) * 0.15; }

void vertex() {
	vP = VERTEX;
	vN = NORMAL;
	vCol = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);     // the models' colours are written in sRGB
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vR0 = MODEL_MATRIX[0].xyz; vR1 = MODEL_MATRIX[1].xyz; vR2 = MODEL_MATRIX[2].xyz;
	vGround = vWorld.y - MODEL_MATRIX[3].y;              // height above the model's own origin (the ground, for bodies)
}

void fragment() {
	vec3 n = normalize(vN);
	vec3 a = vCol.rgb;
	float cond = vCol.a;
	float rough = 0.5;
	float metal = 0.0;
	float spec = 0.5;
	float coat = 0.0;
	float coat_r = 0.05;
	float soil = 0.0;
	vec3 emit = vec3(0.0);
	float n1 = fbm(vP * 3.0);
	float n2 = vn(vP * 31.0);
	// road dirt: spray and mud up the lower panels, heavier behind the wheels and on the sills
	float up = clamp(vGround / dirt_h, 0.0, 1.0);
	float dirty = dirt * (1.0 - smoothstep(0.0, 1.0, up)) * (0.55 + 0.9 * fbm(vP * 6.0 + 3.0));
	if (kind == 0) {
		float flake = vn(vP * 420.0);
		float scr = smoothstep(0.78, 0.83, vn(vec3(vP.x * 70.0, vP.y * 5.0, vP.z * 9.0)) * 0.5 + vn(vec3(vP.z * 80.0, vP.y * 6.0, vP.x * 7.0)) * 0.5);
		float wear = 1.0 - cond;
		float rust = smoothstep(0.66, 0.8, fbm(vP * 7.0 + 7.0) * 0.8 + vn(vP * 40.0) * 0.2 + wear * 0.3 - 0.12) * smoothstep(0.12, 0.5, wear);
		float fade = wear * 0.5 * smoothstep(0.3, 0.7, n1);
		vec3 faded = mix(a, vec3(dot(a, vec3(0.299, 0.587, 0.114))) * 1.25, fade);
		vec3 rustc = mix(vec3(0.20, 0.075, 0.03), vec3(0.34, 0.15, 0.06), n2);
		a = mix(faded, rustc, rust);
		rough = mix(0.34 + 0.12 * flake, 0.85, rust);
		rough = mix(rough, 0.6, fade);
		metal = mix(0.22 * (0.7 + 0.5 * flake), 0.0, rust);
		coat = mix(1.0, 0.0, clamp(fade * 1.4 + rust, 0.0, 1.0));
		coat_r = 0.04 + 0.12 * wear;
		a *= 1.0 - 0.12 * scr * (1.0 - rust);
		soil = dirty;
	} else if (kind == 1) {
		float dust = (1.0 - cond) * (0.5 + 0.6 * n1);
		a = mix(vec3(0.018, 0.018, 0.02), vec3(0.2, 0.185, 0.16), dust) * (0.9 + 0.2 * n2);
		rough = 0.78 - 0.1 * (1.0 - dust);
		spec = 0.35;
		soil = dirty * 0.5;
	} else if (kind == 2) {
		a = a * (0.92 + 0.16 * n2 * (1.0 - cond));
		metal = 0.95;
		rough = mix(0.1, 0.5, 1.0 - cond) + 0.08 * n1;
		spec = 0.6;
		float rustm = smoothstep(0.66, 0.82, fbm(vP * 14.0 + 1.0) + (1.0 - cond) * 0.3 - 0.1) * (1.0 - cond);
		a = mix(a, vec3(0.26, 0.11, 0.045), rustm);
		metal = mix(metal, 0.2, rustm);
		rough = mix(rough, 0.8, rustm);
	} else if (kind == 3) {
		a = vec3(0.02, 0.026, 0.032) * mix(vec3(1.0), a * 6.0, 0.6);
		rough = 0.03 + 0.05 * (1.0 - cond);
		metal = 0.45;
		spec = 1.0;
		coat = 0.0;
		soil = dirty * 0.35;
	} else if (kind == 4) {
		a = a * (0.9 + 0.2 * n2);
		rough = mix(0.5, 0.88, 1.0 - cond);
		spec = 0.32;
		soil = dirty * 0.6;
	} else if (kind == 5) {
		rough = 0.08;
		spec = 0.9;
		emit = vCol.rgb * glow;
	} else if (kind == 6) {
		float wear = 1.0 - cond;
		float chip = smoothstep(0.7, 0.85, fbm(vP * 13.0) + wear * 0.3 - 0.1) * smoothstep(0.05, 0.4, wear);
		a = mix(a, vec3(0.30, 0.13, 0.055), chip * 0.7);
		rough = mix(0.42, 0.75, wear) + 0.1 * n2;
		metal = 0.0;
		spec = 0.45;
		soil = dirty * 0.8 + wear * 0.25 * n1;
	} else {
		float pit = smoothstep(0.7, 0.85, vn(vP * 60.0));
		float stain = smoothstep(0.4, 0.8, fbm(vP * 4.0 + 5.0));
		a = a * (0.8 + 0.4 * fbm(vP * 12.0)) * (1.0 - 0.18 * pit);
		a = mix(a, a * vec3(0.78, 0.85, 0.7), stain * (1.0 - cond) * 0.8);
		rough = 0.88;
		spec = 0.25;
		soil = dirty * 0.8;
	}
	// road dirt over everything that takes it
	vec3 mud = mix(vec3(0.16, 0.125, 0.09), vec3(0.26, 0.21, 0.16), n1);
	float sm = clamp(soil, 0.0, 0.85);
	a = mix(a, mud, sm);
	rough = mix(rough, 0.92, sm);
	metal *= 1.0 - sm;
	coat *= 1.0 - sm;
	// cloud and drone shadows
	a *= world_shade(vWorld);
	// rain: darker, glossier
	float wet = g_wet * (kind == 1 ? 0.5 : 1.0);
	a *= mix(1.0, kind == 3 ? 1.0 : 0.78, wet);
	rough = mix(rough, max(rough * 0.5, 0.06), wet);
	coat = max(coat, 0.0);
	// snow on what faces up
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.3, n.y) * (0.7 + 0.3 * n1);
	snow = clamp(snow * (1.0 + 0.5 * g_snow), 0.0, 1.0) * (kind == 5 ? 0.0 : 1.0);
	a = mix(a, vec3(0.68, 0.71, 0.78), snow);
	rough = mix(rough, 0.82, snow);
	metal *= 1.0 - snow;
	coat *= 1.0 - snow;
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	METALLIC = metal;
	SPECULAR = spec;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_r;
	EMISSION = emit;
	AO_LIGHT_AFFECT = 0.35;
}
