// The rotating cloud base above a funnel (SPEC-VORTEX-LOOK): a wide, soft, dark cloud disc at the top of the column,
// darker in the middle, with a slow swirl and a bright ragged rim, so the funnel visibly hangs from a storm base even
// when the sky hooks are quiet. Viewed from below it is a flat disc with soft edges.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 1.0;
uniform float seed = 0.0;
uniform vec3 dark_col : source_color = vec3(0.15, 0.16, 0.15);
uniform vec3 light_col : source_color = vec3(0.34, 0.35, 0.34);

varying vec2 v_uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { v_uv = UV; }

void fragment() {
	vec2 p = (v_uv - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	// a slow rotation and two octaves of cloud noise
	float n = noise(vec2(ang * 2.2 + TIME * 0.05 + seed, r * 3.5 - TIME * 0.03));
	n = 0.6 * n + 0.4 * noise(vec2(ang * 5.5 - TIME * 0.08 + seed * 2.0, r * 8.0));
	float disc = 1.0 - smoothstep(0.55, 1.0, r);
	float edge = smoothstep(0.35, 0.85, r) * disc;
	vec3 c = mix(dark_col, light_col, n * 0.5 + 0.18 + edge * 0.25);
	c *= 1.0 - 0.35 * (1.0 - disc);
	ALBEDO = c;
	ALPHA = clamp(disc * (0.55 + 0.45 * n) * strength, 0.0, 1.0);
}
