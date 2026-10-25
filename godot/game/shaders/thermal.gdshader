// Thermal camera post-process (session B realism pass). A white-hot false-colour thermal image: cold air and water are
// deep indigo, cool grass and stone are purple to maroon, warm surfaces go red and orange, bodies go yellow, and
// engines and exhausts go white. Heat shells add a colour code the shader decodes (magenta body, red engine), so the
// readings follow the object rather than the daylight brightness of its paint.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float gain = 1.0;
uniform float grain_amount = 0.055;
uniform float scan_strength = 0.045;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 thermal_ramp(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c;
	if (t < 0.16) {
		c = mix(vec3(0.010, 0.012, 0.055), vec3(0.08, 0.025, 0.22), t / 0.16);
	} else if (t < 0.34) {
		c = mix(vec3(0.08, 0.025, 0.22), vec3(0.40, 0.035, 0.20), (t - 0.16) / 0.18);
	} else if (t < 0.54) {
		c = mix(vec3(0.40, 0.035, 0.20), vec3(0.82, 0.20, 0.055), (t - 0.34) / 0.20);
	} else if (t < 0.74) {
		c = mix(vec3(0.82, 0.20, 0.055), vec3(1.0, 0.64, 0.10), (t - 0.54) / 0.20);
	} else if (t < 0.88) {
		c = mix(vec3(1.0, 0.64, 0.10), vec3(1.0, 0.94, 0.62), (t - 0.74) / 0.14);
	} else {
		c = mix(vec3(1.0, 0.94, 0.62), vec3(1.0, 1.0, 1.0), (t - 0.88) / 0.12);
	}
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));

	// The base reading: a cool valley. Vegetation and water are colder than exposed stone, road and metal.
	float green = smoothstep(0.015, 0.16, c.g - max(c.r, c.b));
	float blue = smoothstep(0.015, 0.18, c.b - max(c.r, c.g));
	float base = pow(clamp(l, 0.0, 1.0), 0.88) * 0.72 + 0.02;
	base *= 1.0 - 0.58 * green;
	base *= 1.0 - 0.78 * blue;

	// Heat-shell codes. Every shell is a low-green magenta: a violet body, a pink cabin, a red-pink engine.
	// The red detection subtracts the greens and blues so autumn leaves and red paint do not read as engines.
	float pink = clamp((min(c.r, c.b) - c.g) * 1.5, 0.0, 1.0);
	float red_code = clamp((c.r - c.g * 2.2 - c.b * 1.1) * 1.5, 0.0, 1.0);
	float body_heat = pink * 0.88;
	float engine_heat = red_code * 0.96;
	float heat = max(max(base, body_heat), engine_heat);

	// Isotherm bands: keep the false-colour steps readable instead of a smooth, gamey gradient.
	float t = heat * gain;
	t = floor(t * 42.0 + 0.5) / 42.0;
	vec3 pal = thermal_ramp(t);

	float scan = 1.0 - scan_strength * (0.5 + 0.5 * sin(uv.y * 940.0));
	float grain = (hash(uv * 720.0 + vec2(TIME * 13.0, TIME * 19.0)) - 0.5) * grain_amount;
	float vignette = smoothstep(0.82, 0.24, length(uv - vec2(0.5)));
	// A faint fixed reticle so it feels like a camera feed.
	vec2 r = abs(uv - vec2(0.5));
	float ret = (step(r.x, 0.0012) + step(r.y, 0.0012)) * 0.10;
	pal = pal * scan * vignette + vec3(ret);
	COLOR = vec4(pal * (1.0 + grain), 1.0);
}
