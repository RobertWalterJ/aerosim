// A flag on its pole, waving in the wind (NewModels2.flag cloth mesh, driven by game/sky_life.gd). The vertex shader
// moves the cloth with a travelling wave whose amplitude grows towards the fly end; the uniform wind is the wind speed
// in m/s. No time uniform of its own: uses TIME.
shader_type spatial;
render_mode cull_disabled;

uniform float wind = 3.0;
uniform float wave = 1.0;
uniform vec3 tint : source_color = vec3(1.0);

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
	float fly = UV.x;                                  // 0 at the hoist, 1 at the fly
	float amp = wave * clamp(wind / 8.0, 0.2, 1.6) * (0.10 + 0.35 * fly);
	float ph = TIME * (2.0 + 0.5 * clamp(wind, 0.0, 12.0)) - fly * 5.0 + UV.y * 1.5;
	VERTEX.z += sin(ph) * amp;
	VERTEX.y += cos(ph * 0.8) * amp * 0.25 + sin(ph * 1.7) * amp * 0.1;
	VERTEX.x -= abs(sin(ph)) * amp * 0.15;
}

void fragment() {
	vec3 c = COLOR.rgb * tint;
	// the cloth is thinner at the fly end, and looks a little brighter when the light is behind it
	float edge = smoothstep(0.0, 0.04, v_uv.x) * smoothstep(1.0, 0.96, v_uv.x);
	ALBEDO = c * (0.92 + 0.08 * sin(v_uv.y * 12.0 + v_uv.x * 8.0));
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.4;
	ALPHA = edge;
	if (edge < 0.99) { ALPHA_SCISSOR_THRESHOLD = 0.5; }
}
