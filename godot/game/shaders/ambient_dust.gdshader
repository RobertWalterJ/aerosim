// A soft puff of dust (or powder snow) blown out by the rotor wash. Unshaded and cheap: the script sets how bright the
// light is, and a puff facing the sun glows a little, the way dust does against the light.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float light = 1.0;          // overall light level (sun and sky)
uniform vec3 sun_view = vec3(0.0, 0.0, -1.0);   // direction to the sun in view space
uniform float sun_k = 1.0;          // how much direct sun there is

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r2 = dot(d, d);
	float puff = exp(-r2 * 2.6) * (1.0 - smoothstep(0.7, 1.0, r2));
	// forward scatter: a puff between the camera and the sun lights up
	float mu = max(dot(normalize(VERTEX), sun_view), 0.0);
	float glow = 1.0 + sun_k * 1.5 * pow(mu, 6.0);
	ALBEDO = COLOR.rgb * light * glow;
	ALPHA = COLOR.a * puff;
}
