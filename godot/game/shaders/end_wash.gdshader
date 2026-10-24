shader_type canvas_item;
// The end wash: the lens loses the valley. A wide soft blur, a heavy lift of the colour, a warm paper wash,
// a slow vignette and a little grain. Driven from game/ending.gd over about eight seconds.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 1.0) = 0.0;
uniform float wash : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.65;
uniform float grain : hint_range(0.0, 0.08) = 0.035;
uniform vec2 texel_size = vec2(0.0009, 0.0016);

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = texel_size * mix(0.0, 14.0, blur_amount);

	vec3 acc = texture(screen_tex, uv).rgb * 0.16;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982;
		vec2 d = vec2(cos(a), sin(a));
		acc += texture(screen_tex, uv + d * px).rgb * 0.085;
		acc += texture(screen_tex, uv + d * px * 2.3).rgb * 0.045;
	}
	vec3 c = acc;

	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), wash * 0.58);
	c = mix(c, vec3(0.90, 0.865, 0.785), wash * 0.34);
	c = pow(c, vec3(1.0 - wash * 0.34));
	c *= mix(1.0, 1.06, wash);

	float v = smoothstep(1.05, 0.18, length((uv - 0.5) * vec2(1.02, 1.18)));
	c *= mix(1.0, v, vignette);

	c += (h21(uv * vec2(1920.0, 1080.0) + vec2(TIME * 7.0, TIME * 3.0)) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
