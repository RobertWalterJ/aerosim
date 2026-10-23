// Cemetery stone. The model's own weathered albedo and engraved normal map are kept; this adds how stone behaves:
// polished faces are glossy and rough faces are matte, grime and lichen collect in damp patches and on up-facing
// surfaces, rain darkens the stone and fills its pores so it turns shiny, and snow settles on top.
// UV2.x carries the model's polish value (0 honed or weathered .. 1 polished); polish_override replaces it.
// Weathering (weather_amt): dark rain streaks running down upright faces, crusty lichen blotches (grey-green on the
// sides, orange on the tops), moss favouring the north (-z) side and the foot, dirt splashed up at the base (base_y is
// the model's ground line in its own space), and paler chipped stone on worn edges (found from the surface curvature).
//
// A photographed PBR set (albedo, OpenGL normal, AO/roughness/metal) can be laid over the part at its real size. The
// set is projected from three sides in the part's own axes but at world position, so a run of wall segments with the
// same heading lines up, bricks stay level, and parts with poor UVs still look right. set_mode 1: the set is the
// surface (rubble wall, brick, ashlar, natural rock). set_mode 2: the set weathers the model's own stone (memorials).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float g_wet;
global uniform float g_snow;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float normal_depth = 0.45;
uniform vec3 tint = vec3(0.62);
uniform float polish_override = -1.0;   // 0..1 replaces UV2.x when set
uniform float moss_amt = 1.0;

uniform int set_mode = 0;                // 0 none, 1 the set is the surface, 2 the set weathers the model's stone
uniform sampler2D set_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D set_arm : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;   // r occlusion, g roughness
uniform float set_metres = 2.0;          // metres per repeat
uniform vec3 set_tint = vec3(1.0);
uniform float set_mix = 1.0;             // mode 2: how far unpolished stone takes the set's colour
uniform float set_normal_amt = 1.0;
uniform float set_jitter = 0.0;          // 1 shifts the set per instance (rocks, memorials); 0 keeps runs of wall continuous
uniform float model_normal_amt = 1.0;    // the model's own normal map (engraving)
uniform float weather_amt = 1.0;         // 0 keeps the stone clean
uniform float base_y = 0.0;              // the model's ground line, in its own space
uniform float base_dirt = 1.0;

varying float vPolish;
varying vec3 vCol;
varying vec3 vWorld;
varying vec3 vWorldN;
varying vec3 vFrame;
varying vec3 vFrameN;
varying vec3 vR0;
varying vec3 vR1;
varying vec3 vR2;
varying float vVar;
varying float vLocalY;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
vec2 nxy(vec4 t) { return t.xy * 2.0 - 1.0; }

void vertex() {
	vPolish = polish_override >= 0.0 ? polish_override : clamp(UV2.x, 0.0, 1.0);
	vCol = COLOR.rgb;
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vWorldN = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vR0 = normalize(MODEL_MATRIX[0].xyz); vR1 = normalize(MODEL_MATRIX[1].xyz); vR2 = normalize(MODEL_MATRIX[2].xyz);
	mat3 rt = transpose(mat3(vR0, vR1, vR2));
	vFrame = rt * vWorld;
	vFrameN = rt * vWorldN;
	vVar = h31(MODEL_MATRIX[3].xyz * 1.37 + 0.5);
	vLocalY = VERTEX.y - base_y;
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * vCol * tint;
	float n1 = vn(vWorld * 2.5);
	float n2 = vn(vWorld * 16.0);
	float polish = vPolish;
	float rough = mix(0.88, 0.2, polish);
	float ao = 1.0;
	vec3 nF = vec3(0.0);
	if (set_mode > 0) {
		// three projections in the part's frame, weighted by its normal
		vec3 gn = normalize(vFrameN);
		vec3 w = pow(abs(gn), vec3(4.0)); w /= (w.x + w.y + w.z);
		vec3 sg = vec3(gn.x < 0.0 ? -1.0 : 1.0, gn.y < 0.0 ? -1.0 : 1.0, gn.z < 0.0 ? -1.0 : 1.0);
		vec3 p = (vFrame + set_jitter * vec3(vVar * 13.7, fract(vVar * 7.3) * 5.0, fract(vVar * 3.1) * 11.0)) / set_metres;
		vec2 uX = vec2(-sg.x * p.z, -p.y);
		vec2 uY = vec2(-sg.y * p.x, -p.z);
		vec2 uZ = vec2(sg.z * p.x, -p.y);
		vec3 sa = texture(set_albedo, uX).rgb * w.x + texture(set_albedo, uY).rgb * w.y + texture(set_albedo, uZ).rgb * w.z;
		vec3 arm = texture(set_arm, uX).rgb * w.x + texture(set_arm, uY).rgb * w.y + texture(set_arm, uZ).rgb * w.z;
		vec2 tX = nxy(texture(set_normal, uX)); vec2 tY = nxy(texture(set_normal, uY)); vec2 tZ = nxy(texture(set_normal, uZ));
		float amt = set_normal_amt * (set_mode == 2 ? mix(1.0, 0.12, polish) : 1.0);
		// each projection's tangent frame (u along T, image-up along B) with the true surface normal as the third axis
		vec3 nX = vec3(0.0, 0.0, -sg.x) * tX.x + vec3(0.0, 1.0, 0.0) * tX.y;
		vec3 nY = vec3(-sg.y, 0.0, 0.0) * tY.x + vec3(0.0, 0.0, 1.0) * tY.y;
		vec3 nZ = vec3(sg.z, 0.0, 0.0) * tZ.x + vec3(0.0, 1.0, 0.0) * tZ.y;
		nF = normalize(gn + amt * (nX * w.x + nY * w.y + nZ * w.z));
		ao = arm.r;
		// slow, broad colour variation so long runs of wall and many rocks don't read as one repeat
		float macro = 0.88 + 0.24 * vn(vWorld * 0.35) + 0.12 * (vVar - 0.5);
		if (set_mode == 1) {
			a = sa * set_tint * vCol * macro;
			rough = mix(arm.g, 0.18, polish);
		} else {
			float lum = dot(sa, vec3(0.299, 0.587, 0.114));
			float weather = set_mix * (1.0 - polish);
			a = mix(a * mix(1.0, lum * 2.2, 0.35 * (1.0 - polish)), sa * set_tint * vCol * macro, weather);
			rough = mix(rough + (arm.g - 0.5) * 0.12, arm.g, 0.85 * (1.0 - polish));
			ao = mix(1.0, ao, 1.0 - polish);
		}
	}
	float lum = dot(a, vec3(0.299, 0.587, 0.114));
	float top = smoothstep(0.35, 0.95, vWorldN.y);
	float damp = 0.25 + 0.75 * g_wet;
	float upright = 1.0 - smoothstep(0.35, 0.7, abs(vWorldN.y));
	float north = smoothstep(-0.2, 0.8, -vWorldN.z);
	float wa = weather_amt * (1.0 - polish * 0.75);
	// rain streaks: water running down from the top edges leaves long dark stains on upright faces
	vec3 hz = normalize(vec3(-vWorldN.z, 0.0, vWorldN.x) + vec3(1e-4, 0.0, 0.0));
	float hc = dot(vWorld, hz);
	float streak = smoothstep(0.5, 0.8, vn(vec3(hc * 9.0, vWorld.y * 0.3, vVar * 17.0)) * 0.75 + vn(vec3(hc * 33.0, vWorld.y * 1.1, 3.0)) * 0.35) * upright * wa;
	a = mix(a, a * vec3(0.45, 0.47, 0.43), streak * (0.6 + 0.3 * g_wet));
	// lichen: crusty round blotches; grey-green or pale grey on the sides, yellow-orange on the tops where birds perch
	float ln = vn(vWorld * 7.0 + 3.1);
	float lichen = smoothstep(0.56, 0.62, ln) * smoothstep(0.2, 0.5, n1) * wa * (0.55 + 0.45 * max(top, north));
	vec3 lcol = mix(vec3(0.50, 0.53, 0.40), vec3(0.70, 0.70, 0.64), step(0.6, h31(floor(vWorld * 3.0) + 7.0)));
	lcol = mix(lcol, vec3(0.72, 0.52, 0.16), top * step(0.45, h31(floor(vWorld * 2.0))));
	a = mix(a, lcol * (0.7 + 0.5 * n2), lichen * 0.9);
	rough = mix(rough, 0.95, lichen);
	// moss: patchy, on rough up-facing stone, in its hollows, on the shaded north side and near the damp ground
	float foot = 1.0 - smoothstep(0.02, 0.32 + 0.18 * n2, vLocalY);
	float moss = smoothstep(0.58, 0.82, n1 * 0.7 + n2 * 0.3 + (1.0 - ao) * 0.25 + 0.18 * north * upright + 0.2 * foot) * damp * (0.35 + 0.65 * max(top, north * upright)) * (1.0 - polish * 0.85) * moss_amt;
	a = mix(a, vec3(0.16, 0.22, 0.07), moss * 0.55);
	rough = mix(rough, 0.92, moss);
	// dirt splashed up from the ground at the base
	a = mix(a, a * vec3(0.5, 0.46, 0.38), foot * base_dirt * weather_amt * 0.85);
	// chipped edges: worn corners show paler, fresher stone under the weathered skin
	float curv = length(fwidth(vWorldN)) / max(length(fwidth(vWorld)), 1e-4);
	float chip = smoothstep(4.0, 14.0, curv) * smoothstep(0.5, 0.72, vn(vWorld * 23.0)) * weather_amt * (1.0 - polish * 0.5);
	a = mix(a, a * 1.3 + vec3(0.025), chip);
	rough = mix(rough, 0.95, chip);
	if (set_mode > 0) nF = normalize(nF + chip * (vec3(vn(vWorld * 41.0), vn(vWorld * 41.0 + 9.0), vn(vWorld * 41.0 + 5.0)) - 0.5) * 0.8);
	rough += (n2 - 0.5) * (0.22 - 0.14 * lum) * (set_mode == 1 ? 0.4 : 1.0);   // pitting and mottling
	// rain: darker stone, shinier surface, and water standing in the hollows of flat tops
	float wk = g_wet * (1.0 - 0.3 * polish);
	a *= mix(1.0, 0.58, wk);
	rough = mix(rough, rough * 0.32, g_wet);
	float level = smoothstep(0.88, 0.97, vWorldN.y);
	float puddle = g_wet * level * smoothstep(0.5, 0.75, (1.0 - ao) * 0.9 + n1 * 0.55 + 0.1 * g_wet);
	a *= mix(1.0, 0.7, puddle);
	rough = mix(rough, 0.03, puddle);
	// snow on the tops
	float snow = g_snow * smoothstep(0.55, 0.9, vWorldN.y) * (0.6 + 0.4 * n1);
	a = mix(a, vec3(0.65, 0.68, 0.76), snow);
	rough = mix(rough, 0.85, snow);
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.03, 1.0);
	SPECULAR = mix(0.4, 0.65, polish) + 0.3 * g_wet + 0.2 * puddle;
	if (set_mode > 0) {
		AO = ao;
		AO_LIGHT_AFFECT = 0.25;
		vec3 nn = normalize(mix(nF, normalize(vFrameN), max(snow * 0.6, puddle)));
		NORMAL = normalize((VIEW_MATRIX * vec4(mat3(vR0, vR1, vR2) * nn, 0.0)).xyz);
	}
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth * model_normal_amt * (1.0 - 0.5 * snow) * (1.0 - puddle);
}
