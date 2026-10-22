// Trees and meadow plants: a hierarchical wind sway and the drone's rotor downwash, with backlit translucency on leaves.
// Per-vertex data comes from the exported models: COLOR = baked shading and tint, UV2 = (stem phase, branch flex).
//   1 trunk sway (height squared), 2 branch flex, 3 leaf flutter, plus a radial push away from the drone.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

global uniform float g_time;
global uniform vec3 g_wind;
global uniform vec4 g_drone;
global uniform float g_wash;
global uniform float g_snow;
global uniform float g_wet;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform bool use_normal = false;
uniform bool use_alpha = true;
uniform float alpha_cut = 0.5;
uniform float roughness = 0.7;
uniform float translucency = 0.5;     // backlight strength
uniform float sway = 1.0;             // overall sway scale (trunks use the same, leaves flutter on top)
uniform float flutter = 1.0;          // leaf flutter amount (0 for bare wood)
uniform vec3 tint = vec3(1.0);

varying vec3 vCol;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wv = vec3(0.0);
	float s = length(g_wind.xz) + 0.4;
	vec2 d = normalize(g_wind.xz + vec2(0.001));
	float gust = 0.55 + 0.45 * sin(dot(wp.xz, d) * 0.045 - g_time * 0.9 * (0.6 + 0.1 * s) + 0.7 * sin(wp.x * 0.013 + g_time * 0.21));
	float h = max(VERTEX.y, 0.0);
	float phase = UV2.x;
	float flex = UV2.y;
	float t1 = sin(g_time * 1.9 + wp.x * 0.13 + wp.z * 0.09) * h * h * 0.00075 * s * gust;
	float t2 = sin(g_time * 6.8 + phase * 6.28 + wp.x * 0.5) * flex * 0.07 * s * gust;
	float t3 = sin(g_time * 28.0 + phase * 40.0 + wp.z * 3.0) * 0.025 * (0.3 + s * 0.35) * gust * flutter * step(0.001, flex);
	wv = vec3(d.x, 0.0, d.y) * (t1 * 2.0 + t2 * 1.2) * sway + vec3(t3, t3 * 0.7, -t3);
	wv.y += (t2 + t3) * 0.2;
	// rotor downwash: radial push and flatten inside the drone's radius
	vec3 rv = wp - g_drone.xyz;
	float rd = length(rv);
	float wk = smoothstep(g_drone.w, 0.2, rd) * g_wash;
	wv += (normalize(vec3(rv.x, 0.0, rv.z) + vec3(1e-4)) * 0.5 + vec3(0.0, -0.35, 0.0)) * wk * (0.25 + flex + flutter * 0.3);
	// world displacement back into the model's own space (instances are uniformly scaled and turned about Y)
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wv;
	vCol = COLOR.rgb;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (use_alpha && t.a < alpha_cut) discard;
	vec3 c = t.rgb * vCol * tint;
	c = mix(c, vec3(0.62, 0.66, 0.74), g_snow * 0.35 * smoothstep(0.2, 1.0, vCol.r));
	c *= mix(1.0, 0.72, g_wet);
	ALBEDO = c;
	ROUGHNESS = roughness * mix(1.0, 0.5, g_wet);
	SPECULAR = mix(0.3, 0.75, g_wet);
	BACKLIGHT = c * translucency;
	if (use_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
}
