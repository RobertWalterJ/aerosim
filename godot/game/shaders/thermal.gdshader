// Thermal camera post-process (session B finale). Turns the camera feed into a false-colour heat image: cool ground
// and sky go deep blue and purple, warm surfaces go red and orange, and the hottest points go yellow to white.
// Scanlines, grain and a vignette sell the small sensor. Drawn on its own CanvasLayer under the HUD.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float gain = 1.0;
uniform float grain_amount = 0.10;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// lift the warm midtones a little so bodies and windows separate from cold vegetation
	l = pow(clamp(l, 0.0, 1.0), 0.72) * 1.35 * gain;
	vec3 pal;
	if (l < 0.22) {
		pal = mix(vec3(0.015, 0.02, 0.07), vec3(0.15, 0.04, 0.32), l / 0.22);
	} else if (l < 0.45) {
		pal = mix(vec3(0.15, 0.04, 0.32), vec3(0.62, 0.06, 0.12), (l - 0.22) / 0.23);
	} else if (l < 0.70) {
		pal = mix(vec3(0.62, 0.06, 0.12), vec3(1.0, 0.52, 0.04), (l - 0.45) / 0.25);
	} else {
		pal = mix(vec3(1.0, 0.52, 0.04), vec3(1.0, 0.97, 0.80), clamp((l - 0.70) / 0.30, 0.0, 1.0));
	}
	float scan = 0.94 + 0.06 * sin(uv.y * 900.0);
	float grain = (hash(uv * 760.0 + vec2(TIME * 11.0, TIME * 17.0)) - 0.5) * grain_amount;
	float vig = smoothstep(0.78, 0.22, length(uv - vec2(0.5)));
	// a faint fixed reticle so it feels like a camera feed
	vec2 r = abs(uv - vec2(0.5));
	float ret = (step(r.x, 0.0012) + step(r.y, 0.0012)) * 0.10;
	pal = pal * scan * vig + vec3(ret);
	COLOR = vec4(pal * (1.0 + grain), 1.0);
}
