// A dust or pollen mote. It has no colour of its own: it only shows the light that falls on it, scattered forward
// towards the camera, so motes glitter against a low sun, vanish in shade (the sun's shadow map is applied), stay dim
// under cloud, and at night show only in the drone's light. Drawn additive, so the sensor's bloom picks them up.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, ambient_light_disabled, fog_disabled;

uniform float strength = 1.0;     // golden-hour boost and overall brightness, set from the script
uniform vec3 warm = vec3(1.0);    // pollen and dust are faintly warm
uniform float px_per_m = 0.0025;  // one pixel across at 1 m, set from the camera (VIEWPORT_SIZE is not reliable here)

varying float v_energy;

void vertex() {
	// face the camera, keep the particle's size
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	// never smaller than about two pixels (a sub-pixel mote would flicker); a mote drawn larger than it is gets dimmer
	float depth = max(-(VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).z, 0.05);
	float px = depth * px_per_m;
	float s_min = 3.5 * px;
	v_energy = sqrt(s / max(s, s_min));
	s = max(s, s_min);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float disc = exp(-dot(d, d) * 3.5) * (1.0 - smoothstep(0.85, 1.0, length(d)));
	ALBEDO = vec3(0.0);
	ALPHA = disc * COLOR.a * v_energy;
	// the normal faces the camera, so every light reaches it
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void light() {
	// Henyey-Greenstein forward scattering: brightest looking towards the light
	float mu = dot(LIGHT, -VIEW);
	float g = 0.6;
	float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * mu, 1.5);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * warm * (0.3 + 3.0 * hg) * strength;
}
