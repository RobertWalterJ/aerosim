// The bright spray ring at the foot of a waterspout (SPEC-VORTEX-LOOK). An annulus mesh lying on the water, additive
// and soft, with a slow inward drift and a little noise so it reads as spray being thrown outward at the base.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float strength = 1.0;
uniform vec3 tint : source_color = vec3(0.85, 0.90, 0.95);
uniform float seed = 0.0;

varying vec2 v_uv;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() { v_uv = UV; }

void fragment() {
	float r = v_uv.y;                       // 0 inner, 1 outer
	float n = noise(vec2(v_uv.x * 9.0 + seed, r * 5.0 - TIME * 0.35));
	float band = (0.45 + 0.55 * n) * smoothstep(0.0, 0.18, r) * (1.0 - smoothstep(0.55, 1.0, r));
	ALBEDO = tint;
	ALPHA = clamp(strength * band * 0.55, 0.0, 1.0);
}
