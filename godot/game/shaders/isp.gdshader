// Stages 5 and 6: a 10-stop dynamic range S-curve (Rec.709 / D-Cinelike-ish), veiling-glare lift and ISP unsharp-mask halos.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
uniform float uGlare = 0.0;
uniform float uSharp = 1.4;
uniform float uRadius = 1.2;
uniform float uSat = 1.22;
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
vec3 curve(vec3 x) {
	vec3 st = log2(max(x, vec3(1e-5)) / 0.18);
	vec3 t = clamp((st + 6.2) / 10.0, 0.0, 1.0);
	vec3 s = t * t * (3.0 - 2.0 * t);
	vec3 v = mix(t, s, 0.62);
	v = pow(v, vec3(1.07));
	v = mix(v, vec3(0.5), 0.34 * uGlare) + 0.05 * uGlare;
	return v;
}
vec3 sat(vec3 c) { float l = dot(c, vec3(0.299, 0.587, 0.114)); return mix(vec3(l), c, uSat); }
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec3 c0 = sat(curve(T(uSrc, vUv).rgb));
	vec2 o = uTexel * uRadius;
	vec3 blur = sat(curve(T(uSrc, vUv + vec2(o.x, 0.)).rgb)) + sat(curve(T(uSrc, vUv - vec2(o.x, 0.)).rgb))
		+ sat(curve(T(uSrc, vUv + vec2(0., o.y)).rgb)) + sat(curve(T(uSrc, vUv - vec2(0., o.y)).rgb));
	blur += 0.7071 * (sat(curve(T(uSrc, vUv + o).rgb)) + sat(curve(T(uSrc, vUv - o).rgb)) + sat(curve(T(uSrc, vUv + vec2(o.x, -o.y)).rgb)) + sat(curve(T(uSrc, vUv + vec2(-o.x, o.y)).rgb)));
	blur /= 4.0 + 4.0 * 0.7071;
	vec3 hp = c0 - blur;
	vec3 res = c0 + uSharp * hp;
	res = clamp(res, vec3(-0.02), vec3(1.02));
	COLOR = vec4(clamp(res, vec3(0.0), vec3(1.0)), 1.0);
}
