// Puts the finished video frame on the screen, letterboxed to its own aspect ratio.
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform float uAspectScreen = 1.7778;
uniform float uAspectSrc = 1.7778;
void fragment() {
	vec2 uv = UV; vec2 s = vec2(1.0);
	if (uAspectScreen > uAspectSrc) { s.x = uAspectScreen / uAspectSrc; } else { s.y = uAspectSrc / uAspectScreen; }
	uv = (uv - 0.5) * s + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { COLOR = vec4(0.0, 0.0, 0.0, 1.0); }
	else { COLOR = vec4(texture(uSrc, uv).rgb, 1.0); }
}
