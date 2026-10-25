// The gravel shoulder of a rural road: loose stone, dirt and the first grass creeping in at the outer edge. The texture
// maps add the stone and ruts; the procedural layer keeps the shoulders from looking like wallpaper.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D uAlbedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D uNormal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D uArm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D uJunctionMask : filter_linear, repeat_disable;
uniform float use_junction_mask = 1.0;
varying vec3 vWorld;

uniform vec3 gravel : source_color = vec3(0.34, 0.31, 0.25);
uniform vec3 dirt : source_color = vec3(0.26, 0.22, 0.16);
uniform vec3 grass : source_color = vec3(0.30, 0.36, 0.20);
uniform float wetness = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() {
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 juv = vWorld.xz / 4000.0 + 0.5;
	if (use_junction_mask > 0.5 && juv.x > 0.0 && juv.y > 0.0 && juv.x < 1.0 && juv.y < 1.0) {
		if (texture(uJunctionMask, juv).r > 0.35) discard;
	}
	float across = UV.x;
	float along = UV.y * 4.0;
	vec2 uv = vec2(UV.x * 2.4, UV.y * 1.1);
	vec3 tex = texture(uAlbedo, uv).rgb;
	float n = noise(vec2(across * 26.0, along * 3.0));
	vec3 c = mix(dirt, gravel, n * 0.65 + 0.20);
	c = mix(c, tex * 1.25, 0.45);
	// a little grass and soil at the outer lip
	float lip = smoothstep(0.72, 1.0, abs(across - 0.5) * 2.0);
	c = mix(c, grass, lip * 0.42 * noise(vec2(along * 1.5, across * 8.0)));
	// stones and ruts
	float stones = step(0.84, noise(vec2(across * 72.0, along * 15.0)));
	c = mix(c, c * 1.30, stones * 0.55);
	float rut = smoothstep(0.08, 0.0, abs(across - 0.28)) + smoothstep(0.08, 0.0, abs(across - 0.72));
	c = mix(c, c * 0.82, rut * 0.25);
	c = mix(c, c * 0.70, wetness * 0.35);
	ALBEDO = c;
	NORMAL_MAP = texture(uNormal, uv).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(0.96, 0.72, wetness * 0.5);
	METALLIC = 0.0;
	AO = mix(1.0, texture(uArm, uv).r, 0.5);
}
