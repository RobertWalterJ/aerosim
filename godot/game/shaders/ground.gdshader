// The ground under the grass: mown lawn with faint mowing stripes, tall dry meadow with bare patches, and woodland
// floor with fallen leaves, all blended by the cover texture (r = woodland, b = mown lawn). Snow settles on flat ground.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float g_snow;
global uniform float g_wet;
global uniform vec3 g_cam;

uniform sampler2D uCover : filter_linear, repeat_disable;
uniform sampler2D uDetail : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D uDetailN : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float uSize = 1600.0;

varying vec3 wpos;

float gh(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float gn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(gh(i), gh(i + vec2(1, 0)), f.x), mix(gh(i + vec2(0, 1)), gh(i + vec2(1, 1)), f.x), f.y); }
float gfbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * gn(p); p = p * 2.03 + 17.1; a *= 0.5; } return s; }
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 xz = wpos.xz;
	vec3 cover = texture(uCover, xz / uSize + 0.5).rgb;
	float forest = cover.r;
	float mowed = cover.b;
	float dist = length(wpos - g_cam);
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
	// dark root zone so the blades read as the lit surface layer
	g *= mix(1.0, 0.62, (1.0 - forest) * (1.0 - smoothstep(30.0, 100.0, dist)) * 0.7);
	// steep banks show rock and soil
	vec3 nrm = normalize(cross(dFdx(wpos), dFdy(wpos)));
	float slope = 1.0 - abs(nrm.y);
	g = mix(g, mix(lin(vec3(0.40, 0.37, 0.32)), lin(vec3(0.30, 0.22, 0.15)), n2), smoothstep(0.14, 0.34, slope));
	// snow in uneven drifts on flat ground
	float drift = smoothstep(0.2, 0.8, d2.g + 0.3 * d1.g);
	float cov = g_snow * smoothstep(0.55, 0.9, abs(nrm.y)) * mix(0.7, 1.0, drift);
	g = mix(g, vec3(0.62, 0.66, 0.74), cov);
	// wet ground: darker and glossier, with standing water in the low flat patches
	float wet = g_wet * (1.0 - cov);
	float puddle = wet * smoothstep(0.60, 0.70, gfbm(xz * 0.09 + 5.0)) * smoothstep(0.55, 0.9, abs(nrm.y)) * (1.0 - forest * 0.5);
	g *= mix(1.0, 0.62, wet);
	g = mix(g, g * 0.55, puddle);
	ALBEDO = g;
	ROUGHNESS = mix(mix(0.96, 0.7, cov), mix(0.55, 0.04, puddle), wet);
	SPECULAR = mix(0.5, 1.0, puddle);
	NORMAL_MAP = texture(uDetailN, xz * 0.35).rgb;
	NORMAL_MAP_DEPTH = 0.6 * (1.0 - smoothstep(20.0, 90.0, dist));
}
