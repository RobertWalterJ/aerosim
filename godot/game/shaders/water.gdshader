// A lake: dark teal water that mirrors the sky at low angles (fresnel), with small moving ripples that break up the sun's glint.
shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always;

global uniform float g_time;
global uniform vec3 g_wind;
global uniform float g_snow;

uniform float uLevel = 76.0;
uniform vec3 deep : source_color = vec3(0.03, 0.12, 0.15);
uniform vec3 shallow : source_color = vec3(0.10, 0.28, 0.27);

varying vec3 wp;

float hs(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hs(i), hs(i + vec2(1, 0)), f.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), f.x), f.y); }

vec2 ripple(vec2 p, float t, vec2 dir) {
	float e = 0.35;
	vec2 q = p + dir * t;
	float h0 = vn(q * 0.9) * 0.6 + vn(q * 2.3 - t * 0.3) * 0.3 + vn(q * 5.7 + t * 0.2) * 0.1;
	float hx = vn((q + vec2(e, 0)) * 0.9) * 0.6 + vn((q + vec2(e, 0)) * 2.3 - t * 0.3) * 0.3 + vn((q + vec2(e, 0)) * 5.7 + t * 0.2) * 0.1;
	float hz = vn((q + vec2(0, e)) * 0.9) * 0.6 + vn((q + vec2(0, e)) * 2.3 - t * 0.3) * 0.3 + vn((q + vec2(0, e)) * 5.7 + t * 0.2) * 0.1;
	return vec2(hx - h0, hz - h0) / e;
}

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	float w = clamp(length(g_wind.xz) / 8.0, 0.0, 1.0);
	vec2 dir = normalize(g_wind.xz + vec2(0.001)) * (0.6 + 1.4 * w);
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float calm = 1.0 - smoothstep(150.0, 900.0, dist);         // far away the ripples would only shimmer, so fade them out
	vec2 g = ripple(wp.xz, g_time, dir) * (0.25 + 0.6 * w) * calm;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, 0.3 * vn(wp.xz * 0.02)) * (1.0 - g_snow * 0.5) + vec3(0.6, 0.7, 0.8) * g_snow * 0.5;
	ROUGHNESS = mix(0.03, 0.12, w);
	SPECULAR = mix(0.55, 1.0, fres);
	METALLIC = 0.0;
}
