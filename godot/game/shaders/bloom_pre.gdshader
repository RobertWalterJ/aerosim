// Bloom: bright-pass of the exposed scene (veiling glow from bright sources).
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uScene : filter_linear, repeat_disable;
uniform sampler2D uExp : filter_nearest, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
uniform float uKnee = 1.0;
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	float e = exp2(texture(uExp, vec2(0.5)).r);
	vec3 c = vec3(0.0);
	c += T(uScene, vUv + uTexel * vec2(-1.0, -1.0)).rgb; c += T(uScene, vUv + uTexel * vec2(1.0, -1.0)).rgb;
	c += T(uScene, vUv + uTexel * vec2(-1.0, 1.0)).rgb; c += T(uScene, vUv + uTexel * vec2(1.0, 1.0)).rgb;
	c *= 0.25 * e;
	float l = max(c.r, max(c.g, c.b));
	float soft = clamp(l - uKnee + 0.5, 0.0, 1.0); soft = soft * soft * 0.5;
	float w = max(soft, l - uKnee) / max(l, 1e-4);
	COLOR = vec4(min(c * w, vec3(300.0)), 1.0);
}
