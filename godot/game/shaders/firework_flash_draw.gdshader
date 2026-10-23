// The first flash of a firework burst: a big soft additive glow at the burst point that fades in a quarter of a
// second. It is what makes the burst read as an explosion instead of a scatter of stars, and the sensor bloom
// spreads it through the smoke. Drawn as a camera-facing billboard (see game/fireworks.gd, the flash pool).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 flash_colour = vec3(1.0, 0.8, 0.5);
uniform float alpha = 0.0;
uniform float px_per_m = 0.0016;

varying float v_alpha;
varying float v_depth;

void vertex() {
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float sz = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
	float depth = max(-vp.z, 0.05);
	sz = max(sz, 6.0 * depth * px_per_m);
	vec3 vpos = vp.xyz;
	vpos.xy += VERTEX.xy * sz;
	POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);
	v_depth = depth;
	v_alpha = alpha * smoothstep(2.0, 20.0, depth);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	float core = exp(-r2 * 4.0);
	ALBEDO = flash_colour * 2.4;
	ALPHA = clamp(core * v_alpha, 0.0, 1.0);
}
