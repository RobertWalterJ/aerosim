shader_type canvas_item;
// Ghost epilogue overlay: a dead camera feed that keeps slipping out of signal. It sits above the world and
// below the title card, so the HUD can disappear while the valley remains visible as a cold, drifting image.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.35;
uniform float fade = 1.0;
uniform float time_scale = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_scale;
	float band = step(0.94, hash(vec2(floor(uv.y * 42.0), floor(t * 2.0))));
	float slide = (hash(vec2(floor(uv.y * 28.0), floor(t * 1.7))) - 0.5) * 0.055 * intensity;
	vec2 warped = uv + vec2(slide * band, 0.0);
	vec3 c = texture(screen_tex, warped).rgb;
	vec3 r = texture(screen_tex, warped + vec2(0.0035 * intensity, 0.0)).rgb;
	vec3 b = texture(screen_tex, warped - vec2(0.0035 * intensity, 0.0)).rgb;
	c = vec3(r.r, c.g, b.b);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ghost = mix(vec3(l * 0.64, l * 0.90, l * 0.96), c, 0.34);
	ghost += vec3(0.01, 0.045, 0.055);
	float scan = 0.90 + 0.10 * sin(uv.y * 860.0 + t * 3.0);
	float grain = (hash(uv * 740.0 + vec2(t * 17.0, t * 9.0)) - 0.5) * 0.16;
	float vig = smoothstep(0.86, 0.22, length(uv - vec2(0.5)));
	// brief app-UI ghosts: faint horizontal fragments near the edges
	float edges = smoothstep(0.80, 1.0, abs(uv.x - 0.5) * 2.0);
	ghost += vec3(0.04, 0.075, 0.085) * band * edges * intensity;
	ghost = ghost * scan * vig + vec3(grain);
	float a = clamp(fade, 0.0, 1.0);
	COLOR = vec4(ghost * a + vec3(0.008, 0.012, 0.018) * (1.0 - a), a * 0.62);
}
