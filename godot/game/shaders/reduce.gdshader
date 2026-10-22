// Sums the 32x32 metering grid down to one weighted mean log-luminance.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_nearest, repeat_disable;
void fragment() {
	float a = 0.0; float b = 0.0;
	for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) {
		vec4 s = texture(uSrc, (vec2(float(i), float(j)) + 0.5) / 32.0);
		a += s.r; b += s.g;
	}
	COLOR = vec4(a / max(b, 1e-5), 0.0, 0.0, 1.0);
}
