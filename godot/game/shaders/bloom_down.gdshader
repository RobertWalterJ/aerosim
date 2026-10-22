shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec3 a = T(uSrc, vUv + uTexel * vec2(-2., -2.)).rgb; vec3 b = T(uSrc, vUv + uTexel * vec2(0., -2.)).rgb; vec3 c = T(uSrc, vUv + uTexel * vec2(2., -2.)).rgb;
	vec3 d = T(uSrc, vUv + uTexel * vec2(-2., 0.)).rgb; vec3 e = T(uSrc, vUv).rgb; vec3 f = T(uSrc, vUv + uTexel * vec2(2., 0.)).rgb;
	vec3 g = T(uSrc, vUv + uTexel * vec2(-2., 2.)).rgb; vec3 h = T(uSrc, vUv + uTexel * vec2(0., 2.)).rgb; vec3 i = T(uSrc, vUv + uTexel * vec2(2., 2.)).rgb;
	vec3 j = T(uSrc, vUv + uTexel * vec2(-1., -1.)).rgb; vec3 k = T(uSrc, vUv + uTexel * vec2(1., -1.)).rgb; vec3 l = T(uSrc, vUv + uTexel * vec2(-1., 1.)).rgb; vec3 m = T(uSrc, vUv + uTexel * vec2(1., 1.)).rgb;
	COLOR = vec4(e * 0.125 + (a + c + g + i) * 0.03125 + (b + d + f + h) * 0.0625 + (j + k + l + m) * 0.125, 1.0);
}
