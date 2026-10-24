// Fur and wool (game/new_models5.gd): shell fur. The animal's body is drawn once as skin and then again in a stack of thin shells, each pushed
// out along the surface normal a little further; a strand only exists in a shell if it is long enough to reach that high, so the shells
// together make a field of tapering hairs with a soft, hairy silhouette. The same shader is the skin pass (shell_t = 0) and every shell
// (shell_t = 1/n ... 1): the materials are chained with next_pass in game/new_models5.gd.
//
// What it does for the eye:
//  - strands: a hash of the cell a point is in decides each strand's length and tint; strands thin toward the tip; roots are darker and
//    in shadow (ambient occlusion in the coat), tips lighter
//  - Kajiya-Kay highlights: two lobes (a white one near the tip, a coloured, wider one deeper in) along the direction the hair lies, which
//    is what makes a sleek coat shine in a band and a woolly one only glimmer
//  - wrap lighting and translucency: the thin strands let sunlight through, so a backlit coat glows warmly at its edge
//  - markings (Holstein patches) from a noise on the model's own axes, never from vertex colour, with soft furred edges
//  - wool: bigger cells, curl (the strand position drifts with height so strands twist) and clumps (a slow noise that shortens whole tufts)
//  - gravity and wind sway the tips (g_wind), rain darkens and glosses, snow lies on the upward-facing strands
// The vertex colour is the coat colour; its ALPHA is how much fur there is (1 full, ~0.1 short hair on a sheep's face and legs, 0 a bare hoof).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

#include "res://game/shaders/cloud_shadow.gdshaderinc"

global uniform float g_wet;
global uniform float g_snow;
global uniform vec3 g_wind;

uniform float shell_t = 0.0;             // 0: the skin pass; 1/n .. 1: a shell
uniform float flat_coat = 0.0;           // 1: no shells at all (far level of detail): the skin pass wears the coat colour itself
uniform float fur_len = 0.008;           // metres
uniform float density = 300.0;           // strand cells per metre
uniform float taper = 0.5;               // strand radius at its root, as a fraction of the cell
uniform float root_dark = 0.42;          // colour at the root against the tip
uniform float tip_light = 1.1;
uniform float wool = 0.0;                // 0 hair; 1 curly, clumped wool
uniform float curl = 0.0;
uniform float sway = 1.0;
uniform vec3 flow = vec3(0.0, -0.25, 1.0);   // the way the hair lies, in model space (toward the tail)
uniform vec3 patch_col = vec3(0.02);
uniform float patch_thr = 1.0;           // 1: no markings; less: more of the coat is the patch colour
uniform float patch_soft = 0.02;
uniform vec3 patch_axis = vec3(2.6, 3.6, 1.5);
uniform float patch_seed = 0.0;
uniform float leg_h = 0.6;               // markings fade out below this height (white legs)
uniform vec3 part_off = vec3(0.0);       // a part's mesh is drawn about its own pivot: this puts the noise back in the model's frame
uniform float spec1 = 0.45;
uniform float spec1_pow = 110.0;
uniform float spec2 = 0.2;
uniform float spec2_pow = 24.0;
uniform vec3 spec2_tint = vec3(1.0, 0.8, 0.6);
uniform float scatter = 0.5;
uniform vec3 scatter_col = vec3(1.0, 0.72, 0.45);
uniform float dirt = 0.0;                // wool: how much dirty brown and yellow lanolin shows
uniform vec3 hoof_col = vec3(0.07, 0.06, 0.05);
uniform float snow_from = 0.55;

varying vec3 vPo;                        // the point in the model's frame, before the shell pushes it out
varying vec3 vNo;                        // the surface normal, model frame
varying vec3 vCol;
varying float vA;
varying vec3 vWorld;
varying vec3 vT;                         // the hair direction, view space
varying vec3 vR0;
varying vec3 vR1;
varying vec3 vR2;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return vn(p) * 0.55 + vn(p * 2.07 + 7.1) * 0.3 + vn(p * 4.3 + 13.7) * 0.15; }

void vertex() {
	vec3 n = normalize(NORMAL);
	vPo = VERTEX + part_off;
	vNo = n;
	vR0 = MODEL_MATRIX[0].xyz; vR1 = MODEL_MATRIX[1].xyz; vR2 = MODEL_MATRIX[2].xyz;
	vCol = pow(COLOR.rgb, vec3(2.2));
	vA = COLOR.a;
	vec3 fl = normalize(flow);
	vec3 T = fl - n * dot(fl, n);
	T = length(T) > 0.05 ? normalize(T) : normalize(cross(n, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
	vT = normalize((MODELVIEW_MATRIX * vec4(T, 0.0)).xyz);
	if (shell_t > 0.0) {
		float lf = clamp(COLOR.a, 0.0, 1.0);
		float t = shell_t;
		vec3 w = (inverse(MODEL_MATRIX) * vec4(g_wind, 0.0)).xyz;
		VERTEX += n * (fur_len * lf * t);
		VERTEX += vec3(0.0, -1.0, 0.0) * (fur_len * lf * t * t * 0.35);                    // gravity
		VERTEX += w * (fur_len * lf * t * t * 0.06 * sway);                                 // wind
		VERTEX += T * (fur_len * lf * t * t * 0.3);                                         // the hair lies down
	}
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool hoof = vA < 0.04;
	bool skin = vA >= 0.04 && vA < 0.1;          // bare skin: a muzzle, a udder
	vec3 base = vCol;
	vec3 pos = vPo;
	// markings
	if (patch_thr < 0.999) {
		float f = fbm(pos * patch_axis + patch_seed) + (vn(pos * 38.0 + patch_seed) - 0.5) * 0.06;
		float m = 1.0 - smoothstep(patch_thr - patch_soft, patch_thr + patch_soft, f);
		m *= smoothstep(leg_h * 0.35, leg_h * 0.95, pos.y);
		base = mix(base, patch_col, m);
	}
	// slow mottling, and for wool the dirt
	float mott = vn(pos * 6.0 + 3.0);
	base *= 0.9 + 0.2 * mott;
	if (wool > 0.0) {
		float d = smoothstep(0.45, 0.8, vn(pos * 9.0 + 2.0)) * dirt;
		base = mix(base, vec3(0.34, 0.27, 0.19), d * 0.55);
	}
	float t = shell_t;
	float hs = 0.0;
	float tint = 1.0;
	if (t > 0.0) {
		if (hoof || skin) discard;
		// strands
		vec3 q = pos * density;
		if (wool > 0.0) {
			// curl: the strand's place drifts round a small circle as it rises, so it twists; clumps share a drift
			float ph = vn(pos * 11.0) * 6.2831;
			q.xz += curl * t * vec2(cos(ph + t * 5.0), sin(ph + t * 5.0)) * 1.1;
			q.y += curl * t * 0.7 * sin(ph * 2.0 + t * 4.0);
		}
		q = vec3(q.x * 0.94 + q.z * 0.34, q.y, q.z * 0.94 - q.x * 0.34);              // turned off the grid of the body's axes
		vec3 cell = floor(q);
		hs = h31(cell);
		float lenvar = mix(0.4, 1.0, hs);
		if (wool > 0.0) lenvar *= mix(0.45, 1.0, vn(pos * 16.0 + 5.0));              // tufts
		vec3 jit = (vec3(h31(cell + 3.0), h31(cell + 5.0), h31(cell + 9.0)) - 0.5) * 0.7;
		vec3 f = fract(q) - 0.5 - jit;
		vec3 n0 = normalize(vNo);
		float d = length(f - n0 * dot(f, n0));
		float r = (1.0 - t) * taper + 0.04;
		if (t > lenvar || d > r) discard;
		tint = 0.85 + 0.3 * h31(cell + 11.0);
		float rootk = mix(root_dark, tip_light, pow(t, 0.8));
		base *= rootk * tint;
		if (wool > 0.0) base = mix(base * vec3(1.06, 0.98, 0.84), base, t);           // lanolin yellow at the root
	} else {
		if (hoof) {
			base = hoof_col;
		} else if (skin) {
			base = vCol * (0.9 + 0.2 * vn(pos * 40.0));
		} else if (flat_coat > 0.5) {
			base *= 0.92 * (0.9 + 0.2 * vn(pos * 70.0));                              // the far level: just the coat's colour with a little grain
		} else {
			base *= root_dark * 0.7;                                                   // the skin under the coat: dark
		}
	}
	// a little macro shading of the muscle: slow bumps on the normal
	vec3 nm = normalize(vNo);
	vec3 qq = pos * 4.0;
	float c0 = vn(qq);
	vec3 g = vec3(vn(qq + vec3(0.4, 0, 0)) - c0, vn(qq + vec3(0, 0.4, 0)) - c0, vn(qq + vec3(0, 0, 0.4)) - c0);
	nm = normalize(nm + 0.35 * (g - nm * dot(g, nm)));
	vec3 nview = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nm, 0.0)).xyz);
	NORMAL = nview;
	// weather
	base *= world_shade(vWorld);
	base *= mix(1.0, 0.72, g_wet);
	float snow = g_snow * smoothstep(snow_from, snow_from + 0.3, nm.y) * (wool > 0.0 ? 0.9 : 0.6) * (t > 0.0 ? 1.0 : 0.5);
	base = mix(base, vec3(0.66, 0.69, 0.76), clamp(snow, 0.0, 1.0));
	ALBEDO = base;
	ROUGHNESS = hoof ? 0.35 : (skin ? 0.3 : mix(0.75, 0.55, g_wet));
	SPECULAR = (skin || hoof) ? 0.6 : 0.0;                                             // the coat's highlights are ours, in light()
	AO = t > 0.0 ? mix(0.4, 1.0, t) : 0.5;
	AO_LIGHT_AFFECT = 0.5;
	// the soft glow at grazing angles (a coat catches the sky at its edge)
	float fres = pow(1.0 - clamp(dot(nview, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * fres * 0.06;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	vec3 lc = LIGHT_COLOR * ATTENUATION;
	vec3 H = normalize(LIGHT + VIEW);
	if (SPECULAR_AMOUNT > 0.01) {
		// skin and hoof: ordinary wrap diffuse and a glossy highlight
		DIFFUSE_LIGHT += lc * clamp((nl + 0.3) / 1.3, 0.0, 1.0) / PI;
		SPECULAR_LIGHT += lc * pow(clamp(dot(NORMAL, H), 0.0, 1.0), 120.0) * 0.8 * clamp(nl * 4.0, 0.0, 1.0);
	} else {
		float wrapk = 0.35;
		float diff = clamp((nl + wrapk) / (1.0 + wrapk), 0.0, 1.0);
		float rootshade = shell_t > 0.0 ? mix(0.4, 1.0, shell_t) : 0.5;     // roots sit in the coat's own shadow
		DIFFUSE_LIGHT += lc * diff * (0.45 + 0.55 * rootshade) / PI;
		// translucency: sun through the strands, strongest looking into the sun
		float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 3.0);
		float thin = (shell_t > 0.0 ? mix(0.35, 1.0, shell_t) : 0.2);
		DIFFUSE_LIGHT += lc * scatter_col * back * scatter * thin / PI * (1.0 - clamp(nl, 0.0, 1.0) * 0.5);
		// Kajiya-Kay: a highlight along the strand, and a second, wider, tinted one from deeper in the coat
		float th = dot(normalize(vT), H);
		float sth = sqrt(max(1.0 - th * th, 0.0));
		float lit = smoothstep(-0.1, 0.35, nl);
		float s1 = pow(sth, spec1_pow) * spec1;
		float th2 = dot(normalize(vT + NORMAL * 0.25), H);
		float s2 = pow(sqrt(max(1.0 - th2 * th2, 0.0)), spec2_pow) * spec2;
		SPECULAR_LIGHT += lc * (vec3(s1) + spec2_tint * s2) * lit * (0.3 + 0.7 * shell_t) / PI * 3.0;
	}
}
