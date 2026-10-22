// Stage 2a: centre-weighted metering. 70% of the weight in the centre third, 6x6 log-luminance taps per cell of a 32x32 grid.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uScene : filter_linear, repeat_disable;
uniform float uS = 1.15;
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec2 cell = vec2(1.0 / 32.0);
	float sumL = 0.0;
	for (int j = 0; j < 6; j++) for (int i = 0; i < 6; i++) {
		vec2 o = (vec2(float(i), float(j)) + 0.5) / 6.0;
		vec2 uvF = vUv - 0.5 * cell + o * cell;
		vec2 uvS = 0.5 + (uvF - 0.5) / uS;
		float L = lum(T(uScene, uvS).rgb);
		sumL += log2(clamp(L, 1e-4, 60.0));
	}
	vec2 c = abs(vUv - 0.5);
	float inC = (1.0 - smoothstep(0.155, 0.185, c.x)) * (1.0 - smoothstep(0.155, 0.185, c.y));
	float w = mix(0.3375, 6.3, inC);
	COLOR = vec4(w * sumL / 36.0, w, 0.0, 1.0);
}
