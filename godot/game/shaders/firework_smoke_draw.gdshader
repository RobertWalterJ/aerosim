// A puff of firework smoke drawn as a soft billboard. It is not lit by the scene (night smoke would be black
// against the sky anyway); instead it is lit by the burst light through the global g_fire, so a burst makes the
// smoke around it glow pink or gold for a moment.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

global uniform vec4 g_fire;      // xyz = the strongest burst colour, w = its strength 0..1

uniform float px_per_m = 0.0016;
uniform vec3 tint = vec3(0.55, 0.55, 0.58);
uniform float opacity = 0.05;
uniform float self_light = 0.03;   // a little light of its own for launch smoke, which has no burst to light it yet

varying float v_alpha;
varying float v_depth;
varying float v_phase;
varying vec2 v_uv;

void vertex() {
	vec3 wpos = MODEL_MATRIX[3].xyz;
	float sz = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
	float depth = max(-vp.z, 0.05);
	sz = max(sz, 4.0 * depth * px_per_m);
	POSITION = PROJECTION_MATRIX * vec4(vp.xyz + vec3(VERTEX.x * sz, VERTEX.y * sz, 0.0), 1.0);
	v_depth = depth;
	v_alpha = COLOR.a;
	v_phase = INSTANCE_CUSTOM.z * 17.0;
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv * 2.0 - 1.0;
	float r = length(uv);
	float soft = pow(smoothstep(1.0, 0.0, r), 1.5);
	// a slow curl in the UV makes the puff uneven instead of a clean circle
	float n = sin(uv.x * 5.0 + v_phase + TIME * 0.10) * sin(uv.y * 4.0 - v_phase * 0.7 + TIME * 0.07);
	float a = soft * v_alpha * opacity * (0.65 + 0.35 * n);
	vec3 lit = tint * (self_light + 0.28 * g_fire.rgb * g_fire.a) + tint * 0.05;
	ALBEDO = lit;
	ALPHA = clamp(a * smoothstep(2.5, 22.0, v_depth), 0.0, 0.5);
}
