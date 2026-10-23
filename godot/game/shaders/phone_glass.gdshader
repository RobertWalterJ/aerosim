// Frosted glass notification card for game/phone_notes.gd (session B). A canvas item that samples the screen behind
// it, blurs it with nine taps, tints it, adds the fine grain and the top sheen of a real iOS or Android notification,
// and masks itself to a rounded rectangle. The same shader serves the iPhone (more transparent, more blur) and the
// Android Material style (nearly opaque, less blur) through its uniforms.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(420.0, 130.0);
uniform float radius = 22.0;
uniform vec3 tint : source_color = vec3(0.10, 0.105, 0.12);
uniform float tint_amount = 0.62;
uniform float blur_px = 9.0;
uniform float alpha = 1.0;
uniform float grain = 1.0;
uniform float edge_light = 1.0;

float sd_round(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 halfsize = card_size * 0.5;
	vec2 p = (UV - 0.5) * card_size;
	float d = sd_round(p, halfsize, radius);
	if (d > 1.2) {
		discard;
	}
	// nine taps of the screen behind the card, in screen pixels, so it reads as a real blurred backdrop
	vec2 sp = SCREEN_PIXEL_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb * 0.24;
	col += texture(screen_tex, SCREEN_UV + vec2(1.0, 0.0) * sp * blur_px).rgb * 0.095;
	col += texture(screen_tex, SCREEN_UV + vec2(-1.0, 0.0) * sp * blur_px).rgb * 0.095;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0, 1.0) * sp * blur_px).rgb * 0.095;
	col += texture(screen_tex, SCREEN_UV + vec2(0.0, -1.0) * sp * blur_px).rgb * 0.095;
	col += texture(screen_tex, SCREEN_UV + vec2(0.71, 0.71) * sp * blur_px).rgb * 0.07;
	col += texture(screen_tex, SCREEN_UV + vec2(-0.71, 0.71) * sp * blur_px).rgb * 0.07;
	col += texture(screen_tex, SCREEN_UV + vec2(0.71, -0.71) * sp * blur_px).rgb * 0.07;
	col += texture(screen_tex, SCREEN_UV + vec2(-0.71, -0.71) * sp * blur_px).rgb * 0.07;
	col = mix(col, tint, tint_amount);
	// a soft top sheen and a slightly brighter rim, like glass edge light
	col += vec3(0.055) * smoothstep(0.55, 1.0, 1.0 - UV.y);
	float edge = smoothstep(-1.3, -0.1, d);
	col = mix(col, vec3(0.85, 0.88, 0.93), edge * 0.08 * edge_light);
	// very faint fixed grain so the glass does not look like a flat colour fill
	col += (hash(UV * card_size) - 0.5) * 0.012 * grain;
	COLOR = vec4(col, alpha * (1.0 - smoothstep(-0.6, 0.6, d)));
}
