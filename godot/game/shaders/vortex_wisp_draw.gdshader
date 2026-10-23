// The draw pass for the funnel wisps and droplets: a soft camera-facing sprite with a few ragged lobes so it reads as
// condensing vapour rather than a round dot. Alpha blended, no depth write, no glow.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float px_per_m = 0.0016;
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 1.0;

varying vec3 v_col;
varying float v_alpha;
varying float v_seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float sz = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
	float depth = max(-vp.z, 0.05);
	sz = max(sz, 2.0 * depth * px_per_m);
	vec3 vpos = vp.xyz;
	vpos.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);
	v_col = tint;
	v_alpha = COLOR.a * smoothstep(1.0, 6.0, depth);
	v_seed = fract(wpos.x * 0.317 + wpos.y * 0.113 + wpos.z * 0.071);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	// a soft body with two slowly drifting lobes: a ragged, vapour-like edge
	float lobes = 0.7 + 0.3 * sin(uv.x * 7.0 + v_seed * 6.0 + TIME * 0.8) * sin(uv.y * 5.0 - TIME * 0.6 + v_seed * 4.0);
	float a = exp(-r2 * 3.4) * lobes;
	a *= 0.7 + 0.3 * noise(uv * 4.0 + v_seed * 20.0);
	ALBEDO = v_col;
	ALPHA = clamp(v_alpha * a * opacity, 0.0, 1.0);
}
