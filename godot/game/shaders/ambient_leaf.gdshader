// A drifting autumn leaf (see ambient_particles.gdshader). The texture holds two leaf shapes side by side,
// a lobed maple and a wavy oak: r = shading and veins, g = browned edge, a = the leaf's outline.
// The colour comes from the particle; light through the leaf shows when it is between the camera and the sun.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D leaf_tex : filter_linear, repeat_disable;     // no mipmaps: averaged alpha would cut small leaves away
uniform float wet = 0.0;
uniform float px_per_m = 0.0025;  // one pixel across at 1 m, set from the camera
varying float v_kind;

void vertex() {
	v_kind = INSTANCE_CUSTOM.z;
	// a distant leaf is drawn at least about four pixels across, so it reads as a fleck of colour instead of shimmering away
	float s = max(length(MODEL_MATRIX[0].xyz), 1e-4);
	float depth = max(-(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z, 0.05);
	float px = depth * px_per_m;
	VERTEX *= max(1.0, 4.0 * px / s);
}

void fragment() {
	vec2 uv = UV * vec2(0.5, 1.0) + vec2(fract(v_kind * 7.0) < 0.6 ? 0.0 : 0.5, 0.0);
	vec4 t = texture(leaf_tex, uv);
	vec3 c = COLOR.rgb * (0.55 + 0.6 * t.r);
	c = mix(c, vec3(0.13, 0.06, 0.02), t.g * 0.55);
	c *= 1.0 - 0.3 * wet;
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = mix(0.8, 0.35, wet);
	SPECULAR = 0.35;
	BACKLIGHT = c * 0.7;
}
