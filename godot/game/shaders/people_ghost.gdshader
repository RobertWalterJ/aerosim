// Constable Rennick's apparition (Blender 2 people): pale, translucent, a soft rim, no hard edges, a slow breath of
// brightness. Not a glowing monster: mostly see-through, the outline carries the figure.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.78, 0.86, 0.95);
uniform float body_alpha = 0.10;
uniform float rim_alpha = 0.55;
uniform float rim_power = 2.2;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float breath = 0.85 + 0.15 * sin(TIME * 0.7);
	// a faint drift of brightness up the figure
	float drift = 0.85 + 0.15 * sin(VERTEX.y * 3.0 + TIME * 0.5);
	ALBEDO = tint * (0.6 + 0.6 * rim);
	ALPHA = clamp((body_alpha + rim_alpha * rim) * breath * drift, 0.0, 0.8);
}
