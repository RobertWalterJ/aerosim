// Vehicle glass for the Blender vehicles (Blender 3, lane/vehicles): see-through glass that reflects more at grazing angles (Fresnel),
// a light film of road grime toward the bottom edges, raindrops and running water when it rains (g_wet), snow on glass
// that faces up (g_snow), and the cloud and drone shadows. Also the clear headlamp lenses (`glow` lights them).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;
global uniform float g_time;

uniform vec4 tint : source_color = vec4(0.10, 0.12, 0.13, 1.0);
uniform float opacity = 0.16;        // seen straight on
uniform float grime = 0.35;          // road film near the lower edge
uniform float glow = 0.0;            // lamp lens light
uniform vec4 glow_col : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float silt_line = -100.0;    // lane/wreckvan: a lake wreck's old water line; below it the glass is silted over

varying vec3 vP;
varying vec3 vWorld;
varying float vGround;
varying float vAO;

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vP = VERTEX;
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vGround = vWorld.y - MODEL_MATRIX[3].y;
	vAO = COLOR.r;
}

void fragment() {
	vec3 n = NORMAL;
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 4.0);
	float wet = g_wet;
	// raindrops: a cell pattern of beads, and streaks running down on the steep glass
	vec2 uv = vec2(vP.x + vP.z * 0.7, vP.y) * 24.0;
	float drops = 0.0;
	if (wet > 0.01) {
		vec2 c = floor(uv); vec2 f = fract(uv) - 0.5;
		vec2 o = vec2(h21(c), h21(c + 7.1)) - 0.5;
		float r = 0.18 + 0.2 * h21(c + 3.3);
		float d = length(f - o * 0.5);
		drops = (1.0 - smoothstep(r * 0.6, r, d)) * step(0.45, h21(c + 1.7)) * wet;
		vec2 sv = vec2(vP.x * 40.0, vP.y * 3.0 + g_time * 0.6);
		float streak = smoothstep(0.82, 0.95, vn2(sv)) * wet * 0.6;
		drops = max(drops, streak);
		// tilt the normal on the beads so they catch the light
		vec2 b = (f - o * 0.5) * drops;
		NORMAL = normalize(n + (VIEW_MATRIX * vec4(b.x, b.y, b.x * 0.5, 0.0)).xyz * 0.9);
	}
	float low = 1.0 - smoothstep(0.75, 1.15, vGround);
	float film = grime * (0.25 + 0.75 * low) * (0.6 + 0.4 * vn2(vP.xz * 3.0 + vP.y));
	vec3 a = tint.rgb;
	a = mix(a, vec3(0.42, 0.38, 0.32), film * 0.4);
	a *= world_shade(vWorld);
	float alpha = mix(opacity, 0.94, fres) + film * 0.18 + drops * 0.25;
	if (silt_line > -50.0) {
		float sub = 1.0 - smoothstep(silt_line - 0.02, silt_line + 0.01, vGround + 0.03 * (vn2(vP.xz * 4.0 + vP.y) - 0.5));
		float blot = smoothstep(0.3, 0.7, vn2(vP.xy * 6.0 + vP.z * 3.0));
		a = mix(a, vec3(0.16, 0.14, 0.09) * (0.8 + 0.4 * blot), clamp(sub + film * 0.6, 0.0, 1.0));
		alpha += sub * (0.55 + 0.3 * blot) + film * 0.25;
	}
	// snow on glass that faces up
	float upw = (INV_VIEW_MATRIX * vec4(n, 0.0)).y;
	float snow = g_snow * smoothstep(0.45, 0.8, upw);
	a = mix(a, vec3(0.7, 0.73, 0.8), snow);
	alpha = mix(alpha, 1.0, snow);
	ALBEDO = a;
	ALPHA = clamp(alpha, 0.0, 1.0);
	ROUGHNESS = mix(0.02, 0.12, film) * (1.0 - snow) + snow * 0.8;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = glow_col.rgb * glow;
}
