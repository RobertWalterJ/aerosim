shader_type canvas_item;
// Night vision (session B marketplace add-on): amplify the green channel of the camera feed, add grain, scanlines and a
// soft vignette. A cheap image-intensifier look, not a simulation.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float gain = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = pow(clamp(l, 0.0, 1.0), 0.55) * 1.9 * gain;
	vec3 green = vec3(l * 0.32, l * 1.0, l * 0.42);
	green += vec3(0.01, 0.035, 0.012);
	float scan = 0.92 + 0.08 * sin(uv.y * 840.0);
	float grain = (hash(uv * 640.0 + vec2(TIME * 13.0, TIME * 7.0)) - 0.5) * 0.13;
	float vig = smoothstep(0.80, 0.18, length(uv - vec2(0.5)));
	vec2 r = abs(uv - vec2(0.5));
	float ret = (step(r.x, 0.0012) + step(r.y, 0.0012)) * 0.12;
	green = green * scan * vig + vec3(ret * 0.3, ret, ret * 0.4);
	COLOR = vec4(green * (1.0 + grain), 1.0);
}
