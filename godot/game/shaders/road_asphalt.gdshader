// A rural asphalt road laid over the terrain. The worn albedo, normal and roughness maps sit over a procedural pattern
// of aggregate, wheel tracks, tar cracks, repaired patches and gravelly edges. UV.x runs across the road, UV.y is metres/8.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D uAlbedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D uNormal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D uArm : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D uJunctionMask : filter_linear, repeat_disable;
varying vec3 vWorld;

uniform vec3 asphalt : source_color = vec3(0.145, 0.145, 0.155);
uniform vec3 line_col : source_color = vec3(0.82, 0.82, 0.78);
uniform vec3 dirt_col : source_color = vec3(0.29, 0.26, 0.20);
uniform float edge_marks = 1.0;
uniform float center_line = 1.0;
uniform float wetness = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x;
	float v = UV.y * 8.0;
	vec2 uv = vec2(UV.x * 1.55, UV.y * 0.92);
	vec3 tex = texture(uAlbedo, uv).rgb;
	float arm = texture(uArm, uv).g;
	// two scales of aggregate, then the worn asphalt texture
	float n = noise(vec2(u * 36.0, v * 2.8)) * 0.55 + noise(vec2(u * 105.0, v * 11.0)) * 0.45;
	vec3 c = mix(asphalt, tex * 1.35, 0.62);
	c *= 0.86 + n * 0.24;
	// wheel tracks either side of the centre, polished slightly smoother
	float tracks = smoothstep(0.105, 0.015, abs(u - 0.30)) + smoothstep(0.105, 0.015, abs(u - 0.70));
	c = mix(c, c * 0.82, clamp(tracks, 0.0, 1.0) * 0.40);
	// tar cracks and older patches
	float cr = abs(noise(vec2(v * 0.85, u * 3.2)) - 0.5);
	float crack = 1.0 - smoothstep(0.016, 0.045, cr);
	c *= 1.0 - crack * 0.24;
	float patch_n = noise(vec2(v * 0.10, u * 0.62));
	float patch = smoothstep(0.64, 0.82, patch_n);
	c = mix(c, c * 0.74 + vec3(0.02, 0.02, 0.025), patch * 0.32);
	// the edges break up into gravel and dirt
	float edge = smoothstep(0.060, 0.0, min(u, 1.0 - u));
	float edge_noise = 0.45 + 0.35 * noise(vec2(v * 3.2, u * 34.0));
	c = mix(c, dirt_col, edge * edge_noise);
	// markings: solid edge line and dashed centre line, both worn and optional on narrow lanes
	float wear = 0.48 + 0.52 * noise(vec2(u * 9.0, v * 1.6));
	float edge_line = smoothstep(0.0115, 0.0015, abs(u - 0.075)) + smoothstep(0.0115, 0.0015, abs(u - 0.925));
	float dash = step(fract(v * 0.095), 0.56);
	float centre = smoothstep(0.0105, 0.0015, abs(u - 0.5)) * dash;
	float marks = clamp(edge_line * edge_marks + centre * center_line, 0.0, 1.0) * max(wear, 0.72);
	// no lane paint runs through the middle of a junction
	vec2 juv = vWorld.xz / 4000.0 + 0.5;
	if (juv.x > 0.0 && juv.y > 0.0 && juv.x < 1.0 && juv.y < 1.0) {
		float junction = texture(uJunctionMask, juv).r;
		marks *= 1.0 - smoothstep(0.15, 0.65, junction);
		c = mix(c, c * 0.88, junction * 0.35);
	}
	c = mix(c, line_col, marks * 0.92);
	// rain darkens the asphalt and makes the polished tracks reflect
	c = mix(c, c * 0.68, wetness * 0.45);
	ALBEDO = c;
	NORMAL_MAP = texture(uNormal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = clamp(mix(mix(0.90, arm, 0.45), 0.62, marks) - tracks * 0.08, 0.18, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.20, wetness * 0.55);
	METALLIC = 0.0;
	AO = mix(1.0, texture(uArm, uv).r, 0.5);
}
