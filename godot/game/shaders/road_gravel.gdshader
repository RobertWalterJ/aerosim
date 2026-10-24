// The gravel shoulder of a rural road: loose stone, dirt and the first grass creeping in at the outer edge.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 gravel : source_color = vec3(0.34, 0.31, 0.25);
uniform vec3 dirt : source_color = vec3(0.26, 0.22, 0.16);
uniform vec3 grass : source_color = vec3(0.30, 0.36, 0.20);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float across = UV.x;              // 0 at the outer edge, 1 at the road edge (left shoulder); mirrored on the right
	float along = UV.y * 4.0;
	float n = noise(vec2(across * 26.0, along * 3.0));
	vec3 c = mix(dirt, gravel, n);
	// a little grass at the outer lip
	float lip = smoothstep(0.75, 1.0, abs(across - 0.5) * 2.0);
	c = mix(c, grass, lip * 0.35 * noise(vec2(along * 1.5, across * 8.0)));
	// stones
	c = mix(c, c * 1.25, step(0.86, noise(vec2(across * 70.0, along * 14.0))));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
