// Crop plants (game/new_models3.gd): corn, barley, alfalfa and field-edge weeds. Two-sided, with the wind: the whole plant leans
// and sways with g_wind (more the higher it is), the leaves flutter about their midrib, the rotor downwash pushes them aside.
// The vertex colour is the leaf colour; for a leaf ribbon the vertex alpha is the way across it (0 one edge, 0.5 the midrib, 1
// the other), which draws the parallel veins, the pale midrib and darker edges, and lets light through (backlit green).
// Every instance is a touch different in colour, from where it stands.
//   kind 0 leaf ribbon   kind 1 stem, husk and heads (solid colour, a little roughness variation)
//   kind 2 leaf card (a standing quad cut out by a drawn plant texture, assets/textures/cards: r light, g stem, b accent, a cut-out)
//   kind 3 canopy top (a flat quad, the same texture family seen from above)
// For cards the vertex colour is: r the shift along the texture, g a brightness, a 0.5 standing / 1.0 flat. The texture coordinates
// come from where the vertex is: along the card (its tangent is up x normal) and up it, so the quads need no UVs.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_schlick_ggx;

global uniform float g_time;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
global uniform vec3 g_wind;
global uniform vec4 g_drone;
global uniform float g_wash;
global uniform float g_snow;
global uniform float g_wet;

uniform int kind = 0;
uniform float translucency = 0.08;
uniform float sway = 1.0;
uniform sampler2D card_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 col_leaf : source_color = vec3(0.30, 0.46, 0.14);
uniform vec3 col_stem : source_color = vec3(0.50, 0.55, 0.26);
uniform vec3 col_acc1 : source_color = vec3(0.85, 0.82, 0.62);
uniform vec3 col_acc2 : source_color = vec3(0.55, 0.30, 0.62);
uniform vec2 card_tile = vec2(1.0, 2.35);   // metres of plant the texture shows across and up
uniform float canopy_var = 1.0;             // the patchy lighter and darker of a field seen from far

varying vec3 vCol;
varying float vAcross;
varying vec3 vWorld;
varying vec3 vVar;
varying float vShade;
varying vec2 vUV;
varying float vBright;

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
	float edge = kind == 0 ? abs(COLOR.a - 0.5) * 2.0 : (kind >= 2 ? 0.55 : 0.0);
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
	vUV = vec2(0.0);
	vBright = 1.0;
	if (kind == 2) {
		vec3 tg = normalize(cross(vec3(0.0, 1.0, 0.0), NORMAL) + vec3(1e-5));
		vUV = vec2(dot(VERTEX, tg) / card_tile.x + 0.5 + COLOR.r, 1.0 - VERTEX.y / card_tile.y);
		vBright = COLOR.g;
	} else if (kind == 3) {
		vUV = VERTEX.xz / card_tile + vec2(0.5 + COLOR.r, 0.0);
		vBright = COLOR.g;
	}
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
	if (kind >= 2) {
		vec4 t = texture(card_tex, vUV);
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = 0.4;
		vec3 base = mix(col_leaf, col_stem, smoothstep(0.35, 0.65, t.g));
		float a1 = smoothstep(0.25, 0.4, t.b) * (1.0 - smoothstep(0.7, 0.8, t.b));
		float a2 = smoothstep(0.75, 0.9, t.b);
		base = mix(base, col_acc1, a1);
		base = mix(base, col_acc2, a2);
		c = base * vVar * clamp(t.r * 1.05, 0.0, 1.2) * vBright;
		// a field seen from far is patchy: lighter, yellower swathes and darker hollows
		float pn = 0.5 + 0.25 * sin(vWorld.x * 0.071 + 1.7 * sin(vWorld.z * 0.043)) + 0.25 * sin(vWorld.z * 0.113 + 1.3 * sin(vWorld.x * 0.057 + 2.0));
		c *= mix(vec3(1.0), vec3(mix(0.86, 1.1, pn), mix(0.92, 1.04, pn), mix(1.0, 0.8, pn)), canopy_var);
		rough = 0.8 - 0.1 * a2;
		back = c * vec3(0.55, 0.9, 0.2) * translucency;
		// a canopy is lit all over, not only where a card happens to face the sun: lean the card's normal toward the sky
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.5));
	} else if (kind == 0) {
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
	SPECULAR = mix(kind >= 2 ? 0.12 : 0.25, 0.6, g_wet);
	BACKLIGHT = back * clamp(vShade, 0.0, 1.0);
}
