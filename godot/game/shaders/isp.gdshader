// Stages 5 and 6: a 10-stop dynamic range S-curve (Rec.709 / D-Cinelike-ish), veiling-glare lift and ISP unsharp-mask halos.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uSrc : filter_linear, repeat_disable;
uniform vec2 uTexel = vec2(0.001);
uniform float uGlare = 0.0;
uniform float uSharp = 1.4;
uniform float uRadius = 1.2;
uniform float uSat = 1.22;
uniform int uLook = 0;              // 0 Natural (current), 1 Flat (D-Cinelike), 2 Vivid
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
vec3 curve(vec3 x) {
	vec3 st = log2(max(x, vec3(1e-5)) / 0.18);
	// dynamic range, shoulder and black lift by look: Flat opens up to about 12 stops, Vivid closes to 8.5
	float dr = (uLook == 1) ? 12.0 : (uLook == 2 ? 8.5 : 10.0);
	float sm = (uLook == 1) ? 0.8 : (uLook == 2 ? 0.5 : 0.62);
	float pw = (uLook == 1) ? 0.95 : (uLook == 2 ? 1.15 : 1.07);
	float lift = (uLook == 1) ? 0.08 : 0.0;
	vec3 t = clamp((st + dr * 0.5) / dr, 0.0, 1.0);
	vec3 s = t * t * (3.0 - 2.0 * t);
	vec3 v = mix(t, s, sm);
	v = pow(v, vec3(pw));
	v = mix(v, vec3(0.5), 0.34 * uGlare) + 0.05 * uGlare + lift * (1.0 - v);
	return v;
}
vec3 sat(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float s = (uLook == 1) ? 0.85 : (uLook == 2 ? 1.5 : uSat);
	return mix(vec3(l), c, s);
}
void fragment() {
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec3 c0 = sat(curve(T(uSrc, vUv).rgb));
	vec2 o = uTexel * uRadius;
	vec3 blur = sat(curve(T(uSrc, vUv + vec2(o.x, 0.)).rgb)) + sat(curve(T(uSrc, vUv - vec2(o.x, 0.)).rgb))
		+ sat(curve(T(uSrc, vUv + vec2(0., o.y)).rgb)) + sat(curve(T(uSrc, vUv - vec2(0., o.y)).rgb));
	blur += 0.7071 * (sat(curve(T(uSrc, vUv + o).rgb)) + sat(curve(T(uSrc, vUv - o).rgb)) + sat(curve(T(uSrc, vUv + vec2(o.x, -o.y)).rgb)) + sat(curve(T(uSrc, vUv + vec2(-o.x, o.y)).rgb)));
	blur /= 4.0 + 4.0 * 0.7071;
	vec3 hp = c0 - blur;
	// corner softness: the unsharp mask fades toward the corners, so the lens is softer at the edges
	float rr = length(vUv - 0.5) * 2.0;
	float edge_soft = smoothstep(0.6, 1.3, rr);
	vec3 res = c0 + uSharp * (1.0 - 0.55 * edge_soft) * hp;
	res = clamp(res, vec3(-0.02), vec3(1.02));
	COLOR = vec4(clamp(res, vec3(0.0), vec3(1.0)), 1.0);
}
