// The ground under the grass: mown lawn with faint mowing stripes, tall dry meadow with bare patches, and woodland
// floor with fallen leaves, all blended by the cover texture (r = woodland, b = mown lawn). Snow settles on flat ground.
// The lawn is broken up the way a real one is: clover and moss patches, bare compacted soil, worn short cuts (desire
// lines), leaf litter and damp darker ground under the tree crowns (uCanopy), and the paths have a cobble kerb with a
// gravel verge spilling into the grass. Maps that only matter near a path or a tree are only read there.
shader_type spatial;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

global uniform float g_snow;
global uniform float g_wet;
global uniform vec3 g_cam;

uniform sampler2D uCover : filter_linear, repeat_disable;
uniform sampler2D uDetail : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uDetailN : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float uSize = 4000.0;
uniform sampler2D uPath : filter_linear, repeat_disable;       // r = distance to the nearest path, in 8 m units, over the 512 m park square
uniform sampler2D uAsphalt : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uAsphaltN : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D uAsphaltARM : repeat_enable, filter_linear_mipmap;   // r occlusion, g roughness, b metal
// set by GroundDetail.dress (game/ground_detail.gd)
uniform sampler2D uCanopy : filter_linear, repeat_disable;     // r = tree crown overhead, 0..1
uniform float uCanopySpan = 1200.0;
uniform vec4 uDesire[8];                                       // worn short cuts: x0, z0, x1, z1
uniform int uDesireN = 0;
uniform sampler2D uCobble : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uCobbleN : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D uCobbleARM : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D uGravel : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uGravelN : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D uLitterT : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uLitterN : hint_normal, repeat_enable, filter_linear_mipmap;

varying vec3 wpos;

float gh(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float gn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(gh(i), gh(i + vec2(1, 0)), f.x), mix(gh(i + vec2(0, 1)), gh(i + vec2(1, 1)), f.x), f.y); }
float gfbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * gn(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

// how worn a point is by the desire lines (0 none .. 1 bare middle of the track)
float desire_at(vec2 xz) {
	float w = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= uDesireN) break;
		vec4 s = uDesire[i];
		vec2 pa = xz - s.xy; vec2 ba = s.zw - s.xy;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		float d0 = length(pa - ba * h);
		if (d0 > 1.8) continue;                                     // far from this track: skip the noise
		float dd = d0 + (gn(xz * 0.35 + float(i) * 7.0) - 0.5) * 0.9;    // the track wanders a little
		float hw = 0.45 + 0.3 * gn(xz * 0.12 + float(i));
		w = max(w, (1.0 - smoothstep(hw * 0.3, hw, abs(dd))) * smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.9, 1.0, h)));
	}
	return w;
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 xz = wpos.xz;
	vec3 cover = texture(uCover, xz / uSize + 0.5).rgb;
	float forest = cover.r;
	float mowed = cover.b;
	float dist = length(wpos - g_cam);
	float near = 1.0 - smoothstep(20.0, 70.0, dist);
	vec3 d1 = texture(uDetail, xz * 0.35).rgb;
	vec3 d2 = texture(uDetail, xz * 0.04).rgb;
	float n1 = gfbm(xz * 0.045);
	float n2 = gfbm(xz * 0.011 + 7.0);
	vec3 lawn = mix(lin(vec3(0.255, 0.355, 0.115)), lin(vec3(0.355, 0.405, 0.135)), n1);
	vec3 meadow = mix(lin(vec3(0.45, 0.40, 0.17)), lin(vec3(0.33, 0.34, 0.13)), n2);
	vec3 woods = mix(lin(vec3(0.17, 0.14, 0.085)), lin(vec3(0.30, 0.19, 0.075)), n2 * n1 * 1.6);
	// dry upland straw and the odd patch of bare soil in the meadow
	meadow = mix(meadow, lin(vec3(0.55, 0.47, 0.25)), smoothstep(0.55, 0.8, gfbm(xz * 0.006 + 3.0)) * 0.6);
	meadow = mix(meadow, lin(vec3(0.28, 0.20, 0.12)), smoothstep(0.72, 0.86, gfbm(xz * 0.03 + 11.0)) * 0.55);
	vec3 g = mix(meadow, lawn, mowed);
	g = mix(g, woods, forest);
	// mowing stripes on the lawn
	float stripe = 0.5 + 0.5 * sin(dot(xz, vec2(0.9, 0.43)) * 1.05);
	g *= 1.0 + mowed * 0.10 * (stripe - 0.5);
	// fine texture, fading out with distance so the far ground stays calm
	float fine = mix(1.0, 0.55 + 0.9 * d1.r, 1.0 - smoothstep(30.0, 140.0, dist));
	g *= fine * (0.75 + 0.5 * d2.r);
	// fallen leaves in the woods
	float leaf = step(0.78, gn(xz * 3.1)) * forest;
	vec3 lc = mix(lin(vec3(0.62, 0.20, 0.08)), lin(vec3(0.82, 0.55, 0.12)), gh(floor(xz * 3.1)));
	g = mix(g, lc * 0.7, leaf * 0.55);
	vec3 nm = texture(uDetailN, xz * 0.35).rgb;
	float nd = 0.6;
	// ---- the life of a park lawn
	float can = 0.0;
	vec2 cuv = xz / uCanopySpan + 0.5;
	if (cuv.x > 0.0 && cuv.y > 0.0 && cuv.x < 1.0 && cuv.y < 1.0) can = texture(uCanopy, cuv).r;
	float open_lawn = mowed * (1.0 - forest);
	// clover: bluer, rounder-leaved patches in the mown grass (the grass shader adds its white flower heads)
	float clover = smoothstep(0.6, 0.76, gn(xz * 0.21 + 3.7) * 0.75 + gn(xz * 1.3) * 0.25) * open_lawn * (1.0 - can);
	g = mix(g, lin(vec3(0.22, 0.34, 0.13)) * (0.8 + 0.4 * d1.g), clover * 0.7);
	// moss in damp shade: under the crowns, and in patches on the open lawn
	float moss = smoothstep(0.5, 0.8, gn(xz * 0.31 + 11.0) * 0.7 + can * 0.45) * (0.3 + 0.7 * can) * (1.0 - forest * 0.4);
	g = mix(g, lin(vec3(0.30, 0.35, 0.10)) * (0.75 + 0.5 * d1.g), moss * 0.7);
	// bare compacted soil, commoner under trees where the grass struggles
	float bare = smoothstep(0.68, 0.86, gn(xz * 0.13 + 21.0) * 0.6 + gn(xz * 0.9) * 0.25 + can * 0.3) * (1.0 - forest * 0.5);
	vec3 soil = lin(vec3(0.30, 0.23, 0.155)) * (0.7 + 0.6 * d1.r);
	g = mix(g, soil, bare * 0.7);
	// leaf litter under the crowns (a photographed mud and leaves set), thinning at the drip line
	float lm = 0.0;
	if (can > 0.02) {
		lm = smoothstep(0.2, 0.6, can + (gn(xz * 0.55) - 0.5) * 0.55);
		vec3 lt = texture(uLitterT, xz / 2.5).rgb;
		g = mix(g, lt * vec3(1.3, 1.12, 0.9), lm * 0.8);
		nm = mix(nm, texture(uLitterN, xz / 2.5).rgb, lm);
		nd = mix(nd, 1.0, lm);
	}
	g *= mix(1.0, 0.76, can);                                                     // damp, darker ground in the shade of the crowns
	// desire lines: a bare middle with thin, yellowed grass along the sides
	float wear = desire_at(xz) * (1.0 - forest);
	vec3 trodden = mix(lin(vec3(0.46, 0.43, 0.24)), lin(vec3(0.42, 0.34, 0.235)) * (0.8 + 0.4 * d1.r), smoothstep(0.5, 0.95, wear));
	g = mix(g, trodden, smoothstep(0.0, 0.5, wear) * 0.9);
	// dark root zone so the blades read as the lit surface layer
	g *= mix(1.0, 0.62, (1.0 - forest) * (1.0 - smoothstep(30.0, 100.0, dist)) * 0.7 * (1.0 - wear) * (1.0 - lm * 0.6));
	// the park's paths: real asphalt (shared PBR set) edged with a cobble kerb, then a ragged gravel verge
	vec2 puv = (xz + 256.0) / 512.0;
	float pd = 99.0;
	if (puv.x > 0.001 && puv.y > 0.001 && puv.x < 0.999 && puv.y < 0.999) pd = texture(uPath, puv).r * 8.0;
	float wob = (gfbm(xz * 0.45) - 0.5) * 0.42;
	float hw = 1.55 + wob * 0.25;
	float asph = 1.0 - smoothstep(hw - 0.03, hw + 0.03, pd);
	float kerb_out = hw + 0.30;
	float kerb = (1.0 - asph) * (1.0 - smoothstep(kerb_out - 0.025, kerb_out + 0.025, pd));
	float grav = 0.0;
	float rough_edge = 0.96;
	vec3 arm = vec3(1.0, 0.96, 0.0);
	if (pd < hw + 2.0) {
		float gw = 0.25 + 0.55 * gn(xz * 0.9) + wob;
		grav = (1.0 - asph) * (1.0 - kerb) * (1.0 - smoothstep(kerb_out + gw * 0.5, kerb_out + gw, pd)) * smoothstep(0.15, 0.45, gn(xz * 2.3) + 0.35);
		vec3 gcol = texture(uGravel, xz / 2.0).rgb * 0.95;
		g = mix(g, gcol, grav * 0.9);
		nm = mix(nm, texture(uGravelN, xz / 2.0).rgb, grav);
		vec3 ccol = texture(uCobble, xz / 2.0).rgb * 0.72;
		vec3 carm = texture(uCobbleARM, xz / 2.0).rgb;
		ccol *= mix(0.7, 1.0, smoothstep(kerb_out, kerb_out - 0.06, pd));         // a dark joint where the kerb meets the verge
		g = mix(g, ccol, kerb);
		nm = mix(nm, texture(uCobbleN, xz / 2.0).rgb, kerb);
		rough_edge = mix(mix(0.96, 0.9, grav), carm.g, kerb);
		nd = mix(nd, 1.0, max(kerb, grav));
	}
	vec3 acol = texture(uAsphalt, xz / 5.0).rgb * (0.85 + 0.3 * gfbm(xz * 0.6));
	if (asph > 0.0) arm = texture(uAsphaltARM, xz / 5.0).rgb;
	g = mix(g, acol * mix(1.0, 0.85, smoothstep(0.0, 0.6, gn(xz * 0.9) * gfbm(xz * 0.08))), asph);
	nm = mix(nm, texture(uAsphaltN, xz / 5.0).rgb, asph);
	nd = mix(nd, 0.8, asph);
	float hard = max(asph, kerb);
	// steep banks show rock and soil
	vec3 nrm = normalize(cross(dFdx(wpos), dFdy(wpos)));
	float slope = 1.0 - abs(nrm.y);
	g = mix(g, mix(lin(vec3(0.40, 0.37, 0.32)), lin(vec3(0.30, 0.22, 0.15)), n2), smoothstep(0.14, 0.34, slope) * (1.0 - hard));
	// the lake shore: wet mud at the water line, sand above it, then scattered rock, and a mud and sand bed under the water
	float wl = 68.9;
	float above = wpos.y - wl;
	float shore_n = gfbm(xz * 0.15);
	vec3 mud = lin(vec3(0.20, 0.15, 0.10));
	vec3 sand = lin(vec3(0.55, 0.47, 0.32));
	vec3 rockc = lin(vec3(0.36, 0.34, 0.31));
	float band = 1.0 - smoothstep(1.2, 4.0 + 3.0 * shore_n, above);                         // how close to the water
	float under = 1.0 - smoothstep(-0.2, 0.2, above);
	vec3 shore = mix(sand, mud, 1.0 - smoothstep(0.0, 0.9 + 0.6 * shore_n, above));
	float rocks = smoothstep(0.55, 0.75, gfbm(xz * 0.5 + 11.0)) * smoothstep(0.3, 1.6, above) * (1.0 - smoothstep(2.5, 5.5, above));
	shore = mix(shore, rockc * (0.7 + 0.6 * gn(xz * 3.0)), clamp(rocks + 0.7 * smoothstep(0.25, 0.4, 1.0 - abs(nrm.y)) * band, 0.0, 1.0));
	shore = mix(shore, mud * 0.8, under);
	g = mix(g, shore, band * (1.0 - hard));
	// snow in uneven drifts on flat ground (thinner under the crowns, which catch it)
	float drift = smoothstep(0.2, 0.8, d2.g + 0.3 * d1.g);
	float cov = g_snow * smoothstep(0.55, 0.9, abs(nrm.y)) * mix(0.7, 1.0, drift) * (1.0 - 0.35 * can);
	g = mix(g, vec3(0.62, 0.66, 0.74), cov);
	// wet ground: darker and glossier, with standing water in the low flat patches, the worn soil and the gravel
	float wet = g_wet * (1.0 - cov);
	float pool = smoothstep(0.60, 0.70, gfbm(xz * 0.09 + 5.0) + 0.12 * max(wear, bare) + 0.1 * grav);
	float puddle = wet * pool * smoothstep(0.55, 0.9, abs(nrm.y)) * (1.0 - forest * 0.5) * (1.0 - kerb);
	g *= mix(1.0, 0.62, wet);
	g = mix(g, g * 0.55, puddle);
	g *= world_shade(wpos);
	ALBEDO = g;
	float base_rough = mix(mix(rough_edge, 0.98, lm * (1.0 - kerb)), arm.g, asph);
	ROUGHNESS = mix(mix(base_rough, 0.7, cov), mix(mix(0.55, 0.3, hard), 0.04, puddle), wet);
	SPECULAR = mix(0.5, 1.0, max(puddle, wet * hard));
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = nd * (1.0 - smoothstep(20.0, 90.0, dist)) * (1.0 - 0.7 * cov) * (1.0 - puddle);
}
