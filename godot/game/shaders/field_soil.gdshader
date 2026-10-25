// Tilled field soil seen from above: dark furrows and lighter ridges with a little green at the headlands.
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

uniform vec3 soil : source_color = vec3(0.19, 0.14, 0.09);
uniform vec3 ridge : source_color = vec3(0.27, 0.20, 0.13);
uniform vec3 weed : source_color = vec3(0.24, 0.32, 0.16);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float across = UV.x;              // metres across the rows
	float along = UV.y;               // metres along the field
	float furrow = 0.5 + 0.5 * sin(across * 6.2831853 / 0.9);
	vec3 c = mix(soil, ridge, furrow * 0.85);
	c *= 0.85 + 0.30 * noise(vec2(across * 1.6, along * 0.35));
	// rough weedy headland at the ends
	float head = smoothstep(0.0, 3.0, min(along, UV.y)) * 0.0;
	c = mix(c, weed, head);
	ALBEDO = c;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
