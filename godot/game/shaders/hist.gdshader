// Downsamples the finished frame for the luma histogram readout.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
void fragment() {
	vec3 s = vec3(0.0);
	for (int j = 0; j < 4; j++) for (int i = 0; i < 4; i++) s += texture(uSrc, UV + (vec2(float(i), float(j)) - 1.5) * uTexel * 3.0).rgb;
	COLOR = vec4(s / 16.0, 1.0);
}
