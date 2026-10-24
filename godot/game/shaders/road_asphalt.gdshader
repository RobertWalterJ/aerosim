// A rural asphalt road laid over the terrain: worn dark asphalt, two slightly darker wheel tracks, frayed gravelly
// edges, a solid white edge line and a dashed centre line. UV.x runs across the road (0 to 1), UV.y is metres / 8.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform vec3 asphalt : source_color = vec3(0.145, 0.145, 0.155);
uniform vec3 line_col : source_color = vec3(0.82, 0.82, 0.78);
uniform vec3 dirt_col : source_color = vec3(0.29, 0.26, 0.20);
uniform float lane_marks = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float u = UV.x;
	float v = UV.y * 8.0;
	// asphalt grain at two scales
	float n = noise(vec2(u * 34.0, v * 2.6)) * 0.6 + noise(vec2(u * 90.0, v * 9.0)) * 0.4;
	vec3 c = mix(asphalt, asphalt * 1.28, n * 0.55);
	// wheel tracks either side of the centre
	float tracks = smoothstep(0.10, 0.02, abs(u - 0.30)) + smoothstep(0.10, 0.02, abs(u - 0.70));
	c = mix(c, c * 0.82, clamp(tracks, 0.0, 1.0) * 0.45);
	// the edges break up into gravel and dirt
	float edge = smoothstep(0.055, 0.0, min(u, 1.0 - u));
	c = mix(c, dirt_col, edge * (0.45 + 0.3 * noise(vec2(v * 3.0, u * 30.0))));
	// markings: solid edge line, dashed centre line, both worn
	float wear = 0.55 + 0.45 * noise(vec2(u * 10.0, v * 1.7));
	float edge_line = smoothstep(0.0075, 0.0015, abs(u - 0.075)) + smoothstep(0.0075, 0.0015, abs(u - 0.925));
	float dash = step(fract(v * 0.12), 0.58);
	float centre = smoothstep(0.0065, 0.0015, abs(u - 0.5)) * dash;
	float marks = clamp(edge_line + centre, 0.0, 1.0) * wear * lane_marks;
	c = mix(c, line_col, marks * 0.85);
	ALBEDO = c;
	ROUGHNESS = mix(0.82, 0.62, marks);
	METALLIC = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
