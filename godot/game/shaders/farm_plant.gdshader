// Crop plants (game/new_models3.gd): corn, barley, alfalfa and field-edge weeds. Two-sided, with the wind: the whole plant leans
// and sways with g_wind (more the higher it is), the leaves flutter about their midrib, the rotor downwash pushes them aside.
// The vertex colour is the leaf colour; for a leaf ribbon the vertex alpha is the way across it (0 one edge, 0.5 the midrib, 1
// the other), which draws the parallel veins, the pale midrib and darker edges, and lets light through (backlit green).
// Every instance is a touch different in colour, from where it stands.
//   kind 0 leaf ribbon   kind 1 stem, husk and heads (solid colour, a little roughness variation)
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

global uniform float g_time;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
global uniform vec3 g_wind;
global uniform vec4 g_drone;
global uniform float g_wash;
global uniform float g_snow;
global uniform float g_wet;

uniform int kind = 0;
uniform float translucency = 0.2;
uniform float sway = 1.0;

varying vec3 vCol;
varying float vAcross;
varying vec3 vWorld;
varying vec3 vVar;
varying float vShade;

float h11(float x) { return fract(sin(x * 127.1) * 43758.5453); }

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = length(g_wind.xz) + 0.4;
	vec2 d = normalize(g_wind.xz + vec2(0.001));
	float gust = 0.55 + 0.45 * sin(dot(wp.xz, d) * 0.045 - g_time * 0.9 * (0.6 + 0.1 * s) + 0.7 * sin(wp.x * 0.013 + g_time * 0.21));
	float h = max(VERTEX.y, 0.0);
	// the plant leans downwind and sways (taller sways more), wind phase from where it stands so a field rolls in waves
	float sw = sin(g_time * 1.7 + wp.x * 0.35 + wp.z * 0.27) * 0.5 + 0.7;
	float t1 = 0.014 * s * pow(h, 1.5) * gust * sw * sway;
	// leaves flutter more away from the midrib (alpha), a quick small motion
	float edge = kind == 0 ? abs(COLOR.a - 0.5) * 2.0 : 0.0;
	float t3 = sin(g_time * 11.0 + wp.x * 2.1 + wp.z * 1.7 + VERTEX.y * 4.0) * 0.012 * (0.3 + 0.4 * s) * gust * edge * smoothstep(0.1, 0.6, h);
	vec3 wv = vec3(d.x, 0.0, d.y) * t1 + vec3(t3 * 0.5, t3, t3 * 0.4);
	// rotor downwash: push aside and flatten inside the drone's radius
	vec3 rv = wp - g_drone.xyz;
	float wk = smoothstep(g_drone.w, 0.2, length(rv)) * g_wash;
	wv += (normalize(vec3(rv.x, 0.0, rv.z) + vec3(1e-4)) * 0.5 + vec3(0.0, -0.35, 0.0)) * wk * min(h * 0.5, 0.5);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wv;
	vWorld = wp + wv;
	vCol = pow(COLOR.rgb, vec3(2.2));
	vAcross = COLOR.a;
	vShade = world_shade(vWorld);
	vec2 oc = MODEL_MATRIX[3].xz;
	float h1 = h11(dot(oc, vec2(12.9898, 78.233)));
	float h2 = h11(dot(oc, vec2(39.346, 11.135)));
	vVar = mix(vec3(1.0), vec3(0.9 + 0.2 * h1 + 0.06 * (h2 - 0.5), 0.92 + 0.16 * h1, 0.86 + 0.28 * h2), g_fx.y);
}

void fragment() {
	vec3 c = vCol * vVar;
	float rough = 0.7;
	vec3 back = vec3(0.0);
	if (kind == 0) {
		float cc = vAcross - 0.5;
		float ac = abs(cc) * 2.0;
		float veins = 0.5 + 0.5 * cos(cc * 78.0);
		float rib = 1.0 - smoothstep(0.0, 0.07, abs(cc));
		c *= 0.88 + 0.16 * veins;
		c = mix(c, c * vec3(1.25, 1.2, 0.9) + vec3(0.02, 0.03, 0.0), rib * 0.55);   // the pale midrib
		c *= 1.0 - 0.14 * smoothstep(0.7, 1.0, ac);
		rough = 0.5 - 0.12 * rib;
		back = c * vec3(0.9, 1.15, 0.45) * translucency;
	} else {
		c *= 0.92 + 0.14 * fract(sin(dot(floor(vWorld * 90.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	}
	c = mix(c, vec3(0.62, 0.66, 0.74), g_snow * 0.3 * clamp(vWorld.y * 0.0 + 0.5, 0.0, 1.0));
	c *= mix(1.0, 0.72, g_wet);
	c *= clamp(vShade, 0.0, 1.0);
	ALBEDO = c;
	ROUGHNESS = rough * mix(1.0, 0.55, g_wet);
	SPECULAR = mix(0.25, 0.6, g_wet);
	BACKLIGHT = back * clamp(vShade, 0.0, 1.0);
}
