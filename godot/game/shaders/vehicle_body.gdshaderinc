// The body of game/shaders/vehicle.gdshader, shared with vehicle_pbr.gdshader and vehicle_pbr_ds.gdshader (the Blender
// vehicles of Blender 3). See vehicle.gdshader for the kinds. With VEHICLE_MAPS defined (the .glb vehicles):
//   - the colour comes from the uniform `tint` (paint per instance), times the vertex colour's red (baked ambient
//     occlusion); the vertex alpha stays the condition (1 clean, lower = worn, faded and rusty);
//   - photographed detail maps can be given: `detail_nor` (a normal map at `detail_scale` repeats per metre of the
//     model's metre-scaled UVs), `rust_tex` (rust colour where the paint has rusted through).
// Without it (batch 6 code models) nothing changes: the vertex colour is the finish, as before.

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;

uniform int kind = 0;
uniform float glow = 0.0;            // lamp lens emission
uniform float dirt = 0.5;            // road dirt on the lower panels, 0 to 1
uniform float dirt_h = 0.7;          // metres up from the ground that the spray reaches
uniform float snow_from = 0.55;
#ifdef VEHICLE_MAPS
uniform vec4 tint : source_color = vec4(1.0);
uniform float ao_amount = 1.0;
uniform float cond_scale = 1.0;      // scales the vertex condition (metal: lower = duller)
uniform sampler2D detail_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_scale = 0.0;    // repeats per metre; 0 = no detail map
uniform float detail_depth = 0.5;
uniform sampler2D rust_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rust_scale = 0.0;      // repeats per metre; 0 = procedural rust colour
uniform sampler2D dirt_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float dirt_scale = 0.0;      // repeats per metre; 0 = procedural mud colour
// lane/wreckvan: a wreck that has lain in a lake. Below `silt_line` (metres above the model's origin) everything takes a
// coat of lake silt and algae, thickest just under the line; above it, dried silt on what faces up. `paint_tex` is a
// photographed painted-and-rusting sheet that multiplies the paint colour (rust spotting, blistering). kind 8 is the silt bed.
uniform float silt_line = -100.0;    // -100 = no wreck
uniform sampler2D silt_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float silt_scale = 0.0;      // repeats per metre; 0 = procedural silt colour
uniform sampler2D paint_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float paint_scale = 0.0;     // repeats per metre; 0 = no paint photo
uniform float paint_amount = 1.0;
#endif

varying vec3 vP;
varying vec3 vN;
varying vec3 vWorld;
varying vec4 vCol;
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
#ifdef VEHICLE_MAPS
	float ao = mix(1.0, COLOR.r, ao_amount);
	vCol = vec4(tint.rgb * ao, COLOR.a * cond_scale);
#else
	vCol = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);     // the models' colours are written in sRGB
#endif
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
		vec3 ptint = vec3(1.0);
#ifdef VEHICLE_MAPS
		if (paint_scale > 0.0) {
			// the photo is white paint with rust coming through: normalised to its white, it tints the paint where it rusts
			vec3 pt = texture(paint_tex, UV * paint_scale).rgb;
			ptint = mix(vec3(1.0), clamp(pt / 0.8, vec3(0.0), vec3(1.15)), paint_amount);
			wear = clamp(wear + paint_amount * max(0.0, 0.75 - dot(pt, vec3(0.333))) * 0.6, 0.0, 1.0);
		}
#endif
		float rust = smoothstep(0.66, 0.8, fbm(vP * 7.0 + 7.0) * 0.8 + vn(vP * 40.0) * 0.2 + wear * 0.3 - 0.12) * smoothstep(0.12, 0.5, wear);
		float fade = wear * 0.5 * smoothstep(0.3, 0.7, n1);
		vec3 faded = mix(a, vec3(dot(a, vec3(0.299, 0.587, 0.114))) * 1.25, fade) * ptint;
		vec3 rustc = mix(vec3(0.20, 0.075, 0.03), vec3(0.34, 0.15, 0.06), n2);
#ifdef VEHICLE_MAPS
		if (rust_scale > 0.0) rustc = texture(rust_tex, UV * rust_scale).rgb;
#endif
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
#ifdef VEHICLE_MAPS
		a *= vCol.rgb / max(tint.rgb, vec3(0.001));     // keep the baked occlusion on the tyre
#endif
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
	} else if (kind == 8) {
		// the silt bed round a wreck: wet lake mud (photo), darker and glossier in the hollows
		vec3 sc = mix(vec3(0.10, 0.085, 0.06), vec3(0.17, 0.145, 0.10), n1);
#ifdef VEHICLE_MAPS
		if (silt_scale > 0.0) sc = texture(silt_tex, UV * silt_scale).rgb;
		sc *= vCol.rgb / max(tint.rgb, vec3(0.001));     // keep the baked occlusion against the body
#endif
		float wetm = smoothstep(0.55, 0.3, fbm(vP * 1.7 + 4.0));
		a = sc * mix(1.0, 0.72, wetm);
		rough = mix(0.86, 0.38, wetm);
		spec = 0.4;
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
#ifdef VEHICLE_MAPS
	if (dirt_scale > 0.0) mud = texture(dirt_tex, UV * dirt_scale).rgb * 0.9;
#endif
	float sm = clamp(soil, 0.0, 0.85);
	a = mix(a, mud, sm);
	rough = mix(rough, 0.92, sm);
	metal *= 1.0 - sm;
	coat *= 1.0 - sm;
#ifdef VEHICLE_MAPS
	if (silt_line > -50.0 && kind != 8 && kind != 5) {
		// the lake wreck: silt and algae up to the old water line, a hard tide mark, dried silt on top surfaces above it
		vec3 sc = mix(vec3(0.12, 0.10, 0.07), vec3(0.2, 0.17, 0.12), n1);
		if (silt_scale > 0.0) sc = texture(silt_tex, UV * silt_scale * 1.7).rgb * 1.1;
		float edge = silt_line + 0.035 * (fbm(vP * 4.0 + 1.0) - 0.5) + 0.01 * sin(vP.x * 9.0 + vP.z * 7.0);
		float below = 1.0 - smoothstep(edge - 0.012, edge + 0.006, vGround);
		float depth = clamp((edge - vGround) / 0.5, 0.0, 1.0);
		vec3 algae = mix(vec3(0.075, 0.095, 0.035), vec3(0.15, 0.16, 0.07), vn(vP * 23.0)) * (0.75 + 0.5 * fbm(vP * 7.0));
		// algae thickest in a band under the line, silt below that, patchy so the paint shows through in places
		float alg = smoothstep(0.35, 0.0, depth) * (0.45 + 0.55 * smoothstep(0.35, 0.65, fbm(vP * 6.0 + 9.0)));
		vec3 coatc = mix(sc, algae, alg);
		float cover = below * clamp(0.55 + 0.6 * fbm(vP * 3.2 + 2.0) + depth * 0.4, 0.0, 1.0);
		float tide = (1.0 - smoothstep(0.0, 0.025, abs(vGround - edge - 0.01))) * 0.55;
		a = mix(a, coatc, cover);
		a = mix(a, vec3(0.08, 0.075, 0.05), tide);
		rough = mix(rough, 0.9, max(cover, tide));
		metal *= 1.0 - cover;
		coat *= 1.0 - max(cover, tide * 0.5);
		// dried silt and bleaching above the line, on what faces up
		float upf = smoothstep(0.35, 0.85, n.y) * (1.0 - below);
		float dry = upf * smoothstep(0.3, 0.7, fbm(vP * 2.3 + 6.0)) * 0.75;
		a = mix(a, sc * 1.35, dry);
		rough = mix(rough, 0.95, dry);
		coat *= 1.0 - dry;
	}
#endif
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
#ifdef VEHICLE_MAPS
	if (detail_scale > 0.0) {
		NORMAL_MAP = texture(detail_nor, UV * detail_scale).rgb;
		NORMAL_MAP_DEPTH = detail_depth * (1.0 - snow);
	}
#endif
}
