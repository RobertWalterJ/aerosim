// The hills beyond the valley (game/far_hills.gd). COLOR carries r = forest, g = conifer share, b = crest.
// Forest: dark conifer stands mixed with warm autumn broadleaf, with the dark gaps between crowns as a fine speckle.
// Open ground: a patchwork of fields (pasture, stubble, ploughed earth) with dark hedgerow lines on their borders.
// Detail fades out as it gets smaller than a pixel, so nothing shimmers. Aerial perspective fades the colour
// towards the haze colour g_haze with distance (the in-scattered light is added as emission).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

global uniform vec4 g_haze;      // rgb haze colour (the fog colour), a strength
global uniform float g_snow;
global uniform float g_wet;
uniform float uHazeDist = 9000.0;
uniform float uHazeAmt = 0.2;

varying vec3 wp;
varying vec3 vF;

float gh(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float gn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(gh(i), gh(i + vec2(1, 0)), f.x), mix(gh(i + vec2(0, 1)), gh(i + vec2(1, 1)), f.x), f.y); }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vF = COLOR.rgb;
}

void fragment() {
	vec2 xz = wp.xz;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float mpp = max(length(fwidth(xz)), 0.01);          // metres per pixel here
	float fine = 1.0 - smoothstep(6.0, 22.0, mpp);      // detail that is still bigger than a pixel
	float mid = 1.0 - smoothstep(40.0, 140.0, mpp);
	// where the forest stands, with a ragged edge
	float fe = vF.r + (gn(xz * 0.006) - 0.5) * 0.45 + (gn(xz * 0.03) - 0.5) * 0.25 * mid;
	float forest = smoothstep(0.47, 0.53, fe);
	float con = smoothstep(0.35, 0.65, vF.g + (gn(xz * 0.004 + 7.0) - 0.5) * 0.5 + (gn(xz * 0.025) - 0.5) * 0.3 * mid);
	vec3 broad = mix(lin(vec3(0.45, 0.20, 0.07)), lin(vec3(0.55, 0.40, 0.11)), gn(xz * 0.018 + 3.0));
	broad = mix(broad, lin(vec3(0.32, 0.30, 0.13)), smoothstep(0.4, 0.8, gn(xz * 0.008 + 1.0)) * 0.6);   // some still green-brown
	vec3 conif = mix(lin(vec3(0.07, 0.11, 0.07)), lin(vec3(0.10, 0.14, 0.08)), gn(xz * 0.02));
	vec3 fc = mix(broad, conif, con);
	// crowns and the shadowed gaps between them; once smaller than a pixel only their average darkening remains
	float crowns = gn(xz * 0.11) * 0.6 + gn(xz * 0.27) * 0.4;
	fc *= mix(0.72, 0.45 + 0.6 * crowns, fine);
	// fields: a patchwork turned to a different angle in each district
	float ang = gh(floor(xz / 2600.0)) * 3.14159;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = rot * xz;
	vec2 fsz = vec2(240.0, 170.0);
	vec2 cell = floor(q / fsz);
	float h = gh(cell + 11.0);
	vec3 field = h < 0.34 ? lin(vec3(0.31, 0.36, 0.15)) : h < 0.58 ? lin(vec3(0.50, 0.43, 0.26)) : h < 0.78 ? lin(vec3(0.33, 0.25, 0.16)) : lin(vec3(0.40, 0.40, 0.19));
	field *= 0.88 + 0.24 * gn(xz * 0.02 + cell);
	field *= 0.92 + 0.12 * sin(dot(q, vec2(0.9, 0.2)) * 0.5) * fine * step(0.34, h) * step(h, 0.78);   // drill rows and plough lines
	vec2 f = fract(q / fsz);
	vec2 e = min(f, 1.0 - f) * fsz;
	float edge = min(e.x, e.y);
	float hw = max(4.0, mpp * 0.7);
	float hedge = (1.0 - smoothstep(hw * 0.5, hw, edge)) * step(0.25, gh(cell * 1.7 + vec2(3.0, 9.0))) * clamp(9.0 / max(mpp, 9.0), 0.0, 1.0);
	field = mix(field, lin(vec3(0.10, 0.12, 0.06)), hedge * 0.85);
	vec3 c = mix(field, fc, forest);
	// snow: the open fields go white, the forest stays dark with white in its gaps
	c = mix(c, vec3(0.66, 0.70, 0.78), g_snow * mix(0.92, 0.35, forest));
	c *= mix(1.0, 0.78, g_wet);
	// aerial perspective: layered ridges get paler and bluer with distance
	float a = (1.0 - exp(-dist / uHazeDist)) * uHazeAmt * g_haze.a;
	ALBEDO = c * (1.0 - a);
	EMISSION = g_haze.rgb * a;
	ROUGHNESS = mix(0.95, 0.6, g_wet * (1.0 - forest));
	SPECULAR = 0.3;
}
