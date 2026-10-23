// The draw pass for funnel and storm particles: a soft camera-facing sprite, optionally stretched along the vertical
// (rain and spray streaks). Additive for spray and rain so it glows, normal blend for dust.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform float px_per_m = 0.0016;
uniform float stretch = 1.0;        // vertical stretch, for rain streaks
uniform float tint_k = 1.0;         // brightness
uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 0.5;

varying vec3 v_col;
varying float v_alpha;
varying float v_depth;

void vertex() {
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float sz = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
	float depth = max(-vp.z, 0.05);
	sz = max(sz, 2.0 * depth * px_per_m);
	vec3 vpos = vp.xyz;
	vpos.xy += VERTEX.xy * sz * vec2(1.0, stretch);
	POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);
	v_col = COLOR.rgb * tint;
	v_alpha = COLOR.a * smoothstep(1.0, 6.0, depth);
	v_depth = depth;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	float soft = exp(-r2 * 3.0);
	ALBEDO = v_col * tint_k;
	ALPHA = clamp(soft * v_alpha * opacity, 0.0, 1.0);
}
