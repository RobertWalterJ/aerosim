shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uLow : filter_linear, repeat_disable;
uniform sampler2D uHigh : filter_linear, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
uniform float uWeight = 1.0;
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec3 s = T(uLow, vUv + uTexel * vec2(-1., -1.)).rgb + 2. * T(uLow, vUv + uTexel * vec2(0., -1.)).rgb + T(uLow, vUv + uTexel * vec2(1., -1.)).rgb
		+ 2. * T(uLow, vUv + uTexel * vec2(-1., 0.)).rgb + 4. * T(uLow, vUv).rgb + 2. * T(uLow, vUv + uTexel * vec2(1., 0.)).rgb
		+ T(uLow, vUv + uTexel * vec2(-1., 1.)).rgb + 2. * T(uLow, vUv + uTexel * vec2(0., 1.)).rgb + T(uLow, vUv + uTexel * vec2(1., 1.)).rgb;
	COLOR = vec4(T(uHigh, vUv).rgb + s / 16.0 * uWeight, 1.0);
}
