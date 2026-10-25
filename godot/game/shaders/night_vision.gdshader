shader_type canvas_item;
// Night vision (session B marketplace add-on): amplify the green channel of the camera feed, add grain, scanlines and a
// soft vignette. A cheap image-intensifier look, not a simulation. Moonlight and the scene darkness feed the gain and
// the noise; a firework burst adds a local flash and a wash from its own screen position, so the bloom comes from the
// burst, not from the middle of the lens.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float gain = 1.0;
uniform float moon_light = 0.4;
uniform float night_dark = 0.0;
uniform vec2 burst_uv[4];
uniform float burst_k[4];
uniform vec3 burst_c[4];
uniform float burst_wash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	// The intensifier sees a noisy, dark image. In a moonless scene it must not invent daylight: subtract a black
	// floor, let photon grain dominate, and only lift what the lens actually caught.
	float raw = dot(c, vec3(0.299, 0.587, 0.114));
	float floor_l = mix(0.004, 0.040, night_dark);
	float signal = max(raw - floor_l, 0.0);
	float gain_eff = gain * mix(1.0, 0.68, night_dark) * (0.78 + 0.28 * clamp(moon_light, 0.0, 1.0));
	float l = pow(clamp(signal, 0.0, 1.0), 0.55) * 1.45 * gain_eff;
	l = l / (1.0 + 0.28 * l);
	float scan = 0.92 + 0.08 * sin(uv.y * 840.0);
	float grain = (hash(uv * 640.0 + vec2(TIME * 13.0, TIME * 7.0)) - 0.5) * (0.08 + 0.10 * night_dark);
	float speck = step(0.992, hash(uv * 1300.0 + vec2(TIME * 31.0, TIME * 19.0))) * (0.04 + 0.08 * night_dark);
	l += grain + speck;
	// The tube's own green glow is kept low in a dark scene.
	vec3 green = vec3(l * 0.32, l * 1.0, l * 0.42);
	green += vec3(0.01, 0.035, 0.012) * mix(0.35, 1.0, night_dark);

	// A firework burst is a bright source in the tube: a hot core at its screen position, a soft halo, and a
	// shorter-lived wash that can overwhelm the gain for a moment.
	float flash = 0.0;
	vec3 flash_col = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float k = burst_k[i];
		if (k <= 0.001) { continue; }
		float d = distance(uv, burst_uv[i]);
		float core = exp(-d * d * 2200.0) * k;
		float halo = exp(-d * 7.0) * k;
		flash += core * 2.3 + halo * 0.55;
		flash_col += burst_c[i] * (core * 1.6 + halo * 0.30);
	}
	vec3 col = green * (1.0 + flash * 1.1) + flash_col;
	col = mix(col, vec3(0.92, 1.0, 0.90), clamp(flash * 0.95 + burst_wash * 0.65, 0.0, 0.95));
	col = mix(col, vec3(0.96, 1.0, 0.94), clamp(burst_wash * 0.5, 0.0, 0.7));

	float vig = smoothstep(0.80, 0.18, length(uv - vec2(0.5)));
	vec2 r = abs(uv - vec2(0.5));
	float ret = (step(r.x, 0.0012) + step(r.y, 0.0012)) * 0.12;
	col = col * scan * vig + vec3(ret * 0.3, ret, ret * 0.4);
	COLOR = vec4(col, 1.0);
}
