// A drifting wall of mist for a fog bank or a snow squall, drawn on a big curved sheet. A scrolling noise field and a
// soft top and bottom edge give a defined bank edge you can fly around. Unshaded and semi transparent.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.80, 0.84, 0.88);
uniform float alpha = 0.55;
uniform float seed = 0.0;
uniform float density = 0.8;

varying vec2 v_uv;

float hs(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hs(i), hs(i + vec2(1, 0)), f.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), f.x), f.y); }

void vertex() { v_uv = UV; }

void fragment() {
	vec2 p = v_uv * vec2(6.0, 2.0) + vec2(TIME * 0.03 + seed, 0.0);
	float n = vn(p) * 0.55 + vn(p * 2.3 + 7.0) * 0.30 + vn(p * 5.1 + 19.0) * 0.15;
	// the bank has a defined edge: strong in the middle, fading at the top and bottom and at the far ends
	float top = smoothstep(1.0, 0.75, v_uv.y);
	float bottom = smoothstep(0.0, 0.18, v_uv.y);
	float ends = smoothstep(0.0, 0.10, v_uv.x) * smoothstep(1.0, 0.90, v_uv.x);
	float a = alpha * density * (0.35 + 0.65 * n) * top * bottom * ends;
	ALBEDO = tint * (0.85 + 0.3 * n);
	ALPHA = clamp(a, 0.0, 0.9);
}
