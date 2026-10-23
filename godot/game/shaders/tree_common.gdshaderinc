// Shared by the tree shaders (tree_leaf, tree_bark): hierarchical wind sway, the drone's rotor wash, and per-tree variety.
// Per-vertex data from tools/tree_gen.ts: COLOR.rgb = baked occlusion and tint, COLOR.a = outer crown (leaves),
// UV2 = (phase, branch flex). Same motion as foliage.gdshader, so trees and meadow move together.
global uniform float g_time;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
global uniform vec3 g_wind;
global uniform vec4 g_drone;
global uniform float g_wash;
global uniform float g_snow;
global uniform float g_wet;

// World-space displacement for one vertex: 1 trunk sway (height squared), 2 branch flex, 3 leaf flutter, plus rotor wash.
vec3 tree_wind(vec3 vtx, vec3 wp, float phase, float flex, float flutter, float sway) {
	float s = length(g_wind.xz) + 0.4;
	vec2 d = normalize(g_wind.xz + vec2(0.001));
	float gust = 0.55 + 0.45 * sin(dot(wp.xz, d) * 0.045 - g_time * 0.9 * (0.6 + 0.1 * s) + 0.7 * sin(wp.x * 0.013 + g_time * 0.21));
	float h = max(vtx.y, 0.0);
	float t1 = sin(g_time * 1.9 + wp.x * 0.13 + wp.z * 0.09) * h * h * 0.00075 * s * gust;
	float t2 = sin(g_time * 6.8 + phase * 6.28 + wp.x * 0.5) * flex * 0.07 * s * gust;
	float t3 = sin(g_time * 28.0 + phase * 40.0 + wp.z * 3.0) * 0.025 * (0.3 + s * 0.35) * gust * flutter * step(0.001, flex);
	vec3 wv = vec3(d.x, 0.0, d.y) * (t1 * 2.0 + t2 * 1.2) * sway + vec3(t3, t3 * 0.7, -t3);
	wv.y += (t2 + t3) * 0.2;
	vec3 rv = wp - g_drone.xyz;
	float rd = length(rv);
	float wk = smoothstep(g_drone.w, 0.2, rd) * g_wash;
	wv += (normalize(vec3(rv.x, 0.0, rv.z) + vec3(1e-4)) * 0.5 + vec3(0.0, -0.35, 0.0)) * wk * (0.25 + flex + flutter * 0.3);
	return wv;
}

// Every tree is a touch different: brightness and a slight hue lean, from where it stands (switch: g_fx.y).
vec3 tree_variety(vec2 oc) {
	float h1 = fract(sin(dot(oc, vec2(12.9898, 78.233))) * 43758.5453);
	float h2 = fract(sin(dot(oc, vec2(39.346, 11.135))) * 24634.6345);
	return mix(vec3(1.0), vec3(0.88 + 0.24 * h1 + 0.06 * (h2 - 0.5), 0.9 + 0.2 * h1, 0.86 + 0.28 * h2), g_fx.y);
}
