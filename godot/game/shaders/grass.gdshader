// GPU grass. Every blade is one instance of a tiny mesh; its position, height, colour and sway are worked out here
// from the instance number, a lattice that follows the camera, and two ground textures (height and cover).
// Nothing is computed on the CPU per frame. Two layers use the blade shape (a short lawn layer close to the camera and a
// taller meadow layer further out); a third draws fallen autumn leaves (uLitter = 1).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

global uniform vec3 g_cam;
global uniform float g_time;
#include "res://game/shaders/cloud_shadow.gdshaderinc"
global uniform vec3 g_wind;       // canopy-level wind in m/s
global uniform vec4 g_drone;      // xyz drone position, w = downwash radius
global uniform float g_wash;      // downwash strength 0..1
global uniform float g_snow;
global uniform float g_wet;

uniform float uPatch = 13.0;      // side of the square patch that follows the camera
uniform vec2 uBH = vec2(0.1, 0.28);
uniform float uWidth = 0.0085;
uniform float uSize = 4000.0;     // terrain size in metres
uniform float uCells = 2048.0;    // terrain grid squares
uniform vec4 uExcl[16];           // rectangles with no grass (buildings, monuments): xmin, zmin, xmax, zmax
uniform int uExclN = 0;
uniform vec2 uPad = vec2(0.0);    // centre of the bare take-off pad
uniform float uPadR = 11.0;
uniform float uLitter = 0.0;
uniform float uClump = 0.4;      // how strongly blades gather into tufts (0 scattered .. 1 tight clumps)
uniform float uTall = 0.0;       // 1 for the tall-tuft layer: meadow and woodland edge only, thinner, taller
uniform sampler2D uHT : filter_linear, repeat_disable;
uniform sampler2D uCV : filter_linear, repeat_disable;

varying vec3 vCol;

float hsh(float x) { return fract(sin(x * 127.1) * 43758.5453); }
float gh(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float gn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(gh(i), gh(i + vec2(1, 0)), f.x), mix(gh(i + vec2(0, 1)), gh(i + vec2(1, 1)), f.x), f.y); }
float gfbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { s += a * gn(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() {
	float id = float(INSTANCE_ID);
	vec4 seed = vec4(hsh(id * 0.1371 + 0.17), hsh(id * 0.2917 + 3.1), hsh(id * 0.5313 + 7.7), hsh(id * 0.7137 + 11.3));
	vec2 baseP = seed.xy * uPatch;
	vec2 wxz = baseP + uPatch * floor((g_cam.xz - baseP) / uPatch + 0.5);
	// tufts: each blade is drawn towards the centre of its 0.55 m cell, and leans out from it, so the ground reads as clumps
	vec2 toC = vec2(0.0);
	float clump = 0.5;
	if (uLitter < 0.5) {
		vec2 cell = floor(wxz / 0.55);
		vec2 cc = (cell + vec2(hsh(cell.x * 7.31 + cell.y * 1.97), hsh(cell.x * 3.17 + cell.y * 9.73))) * 0.55;
		toC = cc - wxz;
		wxz += toC * 0.55 * uClump;
		clump = hsh(cell.x * 12.9 + cell.y * 78.2);
	}
	float dc = length(wxz - g_cam.xz);
	float fade = 1.0 - smoothstep(0.28 * uPatch, 0.5 * uPatch, dc);
	vec2 huv = ((wxz / uSize + 0.5) * uCells + 0.5) / (uCells + 1.0);
	float gy = textureLod(uHT, huv, 0.0).r - 0.02;
	vec3 cv = textureLod(uCV, wxz / uSize + 0.5, 0.0).rgb;   // r forest floor, b mown lawn
	float keep = 1.0;
	for (int i = 0; i < 16; i++) { if (i < uExclN) { vec4 e = uExcl[i]; if (wxz.x > e.x && wxz.y > e.y && wxz.x < e.z && wxz.y < e.w) keep = 0.0; } }
	keep *= smoothstep(uPadR, uPadR + 4.0, length(wxz - uPad));
	float dens = mix(1.0, 0.22, cv.r);
	keep *= step(fract(seed.z * 37.7), dens);
	keep *= mix(1.0, step(fract(seed.z * 91.3), 0.55) * (1.0 - cv.b) * (1.0 - cv.r * 0.4), uTall);
	float mowed = cv.b;
	float ang = seed.z * 6.2831853;
	vec3 right = vec3(cos(ang), 0.0, sin(ang));
	vec3 fwd = vec3(-sin(ang), 0.0, cos(ang));
	vec3 wp;
	if (uLitter < 0.5) {
		float hMul = mix(mix(0.9, 3.4, smoothstep(0.35, 0.75, gfbm(wxz * 0.02))), 0.75, mowed);
		float stalk = step(0.9, hsh(seed.w * 5.3 + 1.1)) * (1.0 - cv.b);
		float flower = step(0.972, hsh(seed.z * 23.1 + 0.7)) * (1.0 - cv.b) * (1.0 - cv.r);
		float H = mix(uBH.x, uBH.y, seed.w) * hMul * keep * fade * (1.0 - 0.5 * g_snow) * (0.65 + 0.7 * clump) * (1.0 + 0.7 * stalk + 0.4 * flower);
		float yy = VERTEX.y;
		float side = VERTEX.x;
		float curl = (0.2 + 0.55 * hsh(seed.w * 91.7)) * yy * yy * H;
		vec2 wd = normalize(g_wind.xz + vec2(0.001));
		float ws = length(g_wind.xz) * 0.55;
		float gust = 0.5 + 0.5 * sin(dot(wxz, wd) * 0.33 - g_time * (1.3 + 0.25 * ws) + seed.z * 6.28);
		// a wave of wind rolling across the field in broad bands, with the sheen of bent blades riding on it
		float wave = gn(wxz * 0.11 - wd * g_time * (1.6 + ws * 1.5));
		gust = mix(gust, wave, 0.65);
		vec2 wl = wd * (0.05 + 0.04 * ws) * (0.4 + gust) * yy * yy * H;
		vec3 rv = vec3(wxz.x, gy, wxz.y) - g_drone.xyz;
		float rd = length(rv.xz);
		float wk = smoothstep(g_drone.w + 1.0, 0.3, rd) * g_wash;
		vec2 push = normalize(rv.xz + vec2(1e-3)) * wk * 0.85 * yy * H + wd * wk * 0.1 * yy * H;
		float flat1 = 1.0 - 0.35 * wk * yy;
		vec2 outward = normalize(-toC + vec2(1e-4)) * yy * yy * H * 0.35 * uClump;
		float fw = 1.0 + flower * 3.5 * smoothstep(0.78, 0.9, yy);
		wp = vec3(wxz.x, gy, wxz.y) + right * side * uWidth * (1.0 - 0.78 * yy) * fw * step(0.001, H) + fwd * curl + vec3(wl.x + push.x + outward.x, 0.0, wl.y + push.y + outward.y) + vec3(0.0, yy * H * flat1, 0.0);
		vec3 root = lin(vec3(0.10, 0.17, 0.05));
		vec3 tipLawn = mix(lin(vec3(0.32, 0.45, 0.13)), lin(vec3(0.46, 0.52, 0.17)), hsh(seed.z * 53.3));
		vec3 tipMead = mix(lin(vec3(0.72, 0.62, 0.30)), lin(vec3(0.52, 0.50, 0.20)), hsh(seed.z * 17.9));
		vec3 tip = mix(tipMead, tipLawn, mowed);
		tip = mix(tip, lin(vec3(0.25, 0.20, 0.10)), cv.r * 0.7);
		vCol = mix(root, tip, pow(yy, 0.75)) * (0.8 + 0.4 * hsh(seed.w * 7.7));
		vCol *= mix(0.5, 1.0, smoothstep(0.0, 0.5, yy));                  // dark near the ground, where the blades shade each other
		vCol *= 1.0 + 0.5 * (gust - 0.5) * yy;                             // bent blades catch more light
		vCol *= 0.85 + 0.3 * clump;
		vCol = mix(vCol, lin(vec3(0.62, 0.50, 0.24)), stalk * smoothstep(0.78, 0.86, yy) * 0.9);      // seed heads
		int fi = int(floor(hsh(seed.z * 61.7) * 4.0));
		vec3 fcol = fi == 0 ? lin(vec3(0.95, 0.95, 0.9)) : fi == 1 ? lin(vec3(0.95, 0.78, 0.15)) : fi == 2 ? lin(vec3(0.55, 0.38, 0.78)) : lin(vec3(0.95, 0.9, 0.5));
		vCol = mix(vCol, fcol, flower * smoothstep(0.8, 0.88, yy));                                  // wildflowers
		NORMAL = normalize(vec3(-sin(ang) * 0.55, 1.0, cos(ang) * 0.55));
	} else {
		float sz = (0.035 + 0.045 * hsh(seed.w * 13.3)) * keep * fade * step(0.35, gn(wxz * 0.7) + cv.r * 0.5);
		wp = vec3(wxz.x, gy + 0.010 + 0.01 * hsh(seed.w * 5.0), wxz.y) + (right * VERTEX.x + fwd * VERTEX.z) * sz;
		int pi_ = int(floor(hsh(seed.z * 71.3) * 5.0));
		vec3 lc = pi_ == 0 ? lin(vec3(0.62, 0.17, 0.08)) : pi_ == 1 ? lin(vec3(0.82, 0.38, 0.09)) : pi_ == 2 ? lin(vec3(0.85, 0.62, 0.14)) : pi_ == 3 ? lin(vec3(0.45, 0.26, 0.10)) : lin(vec3(0.66, 0.50, 0.17));
		vCol = lc * (0.7 + 0.5 * hsh(seed.w * 3.1));
		NORMAL = normalize(vec3(sin(ang) * 0.35, 1.0, cos(ang) * 0.35));
	}
	vCol = mix(vCol, vec3(0.62, 0.66, 0.74), g_snow * 0.8);
	vCol *= mix(1.0, 0.7, g_wet);
	VERTEX = wp;
}

void fragment() {
	ALBEDO = vCol * world_shade((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ROUGHNESS = (uLitter < 0.5 ? 0.62 : 0.8) * mix(1.0, 0.45, g_wet);
	SPECULAR = mix(0.25, 0.7, g_wet);
	BACKLIGHT = uLitter < 0.5 ? vCol * 0.95 : vec3(0.0);
}
