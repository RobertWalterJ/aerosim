// Tornado and waterspout funnel surface (driven by game/funnel.gd). A tube mesh, unshaded and semi transparent:
// dark grey-brown core, lighter torn edges, bands that scroll upward and spin faster near the base, plus a fine dust
// streak layer. The alpha fades at the top and bottom edges and at the UV seam.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 dark_col : source_color = vec3(0.10, 0.10, 0.095);
uniform vec3 light_col : source_color = vec3(0.44, 0.41, 0.37);
uniform float alpha = 0.85;
uniform float spin = 2.4;           // bands per second at the base
uniform float scroll = 1.5;         // upward scroll, bands per second
uniform float seed = 0.0;

varying float v_t;      // 0 base .. 1 top
varying float v_ang;    // 0..1 round
varying vec3 v_wp;

float hs(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hs(i), hs(i + vec2(1, 0)), f.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), f.x), f.y); }

void vertex() {
	v_t = UV.y;
	v_ang = UV.x;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ang = v_ang * 6.2831853 + TIME * spin * (1.55 - 0.95 * v_t) + seed;
	float band = vn(vec2(ang * 2.0, v_t * 5.0 - TIME * scroll));
	float band2 = vn(vec2(ang * 5.0 + 3.1, v_t * 12.0 - TIME * scroll * 1.8));
	float streaks = vn(vec2(ang * 1.4, v_t * 26.0 - TIME * scroll * 2.6));
	float k = clamp(0.62 * band + 0.28 * band2 + 0.20 * streaks, 0.0, 1.0);
	vec3 c = mix(dark_col, light_col, k);
	// a torn edge on the two sides of the tube, and a darker core down the middle
	float edge = pow(max(sin(v_ang * 3.14159265), 0.0), 0.55);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	c = mix(c * 0.72, light_col * 0.95, rim * 0.28);
	// the inside wall of the tube is darker and thinner than the outside
	if (!FRONT_FACING) { c *= 0.75; }
	float a = alpha * (0.55 + 0.45 * k) * edge;
	a *= smoothstep(0.0, 0.04, v_t) * (1.0 - smoothstep(0.90, 1.0, v_t));
	a *= 1.0 - clamp(0.50 * rim, 0.0, 0.45);
	if (!FRONT_FACING) { a *= 0.55; }
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
