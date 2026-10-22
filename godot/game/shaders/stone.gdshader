// Cemetery stone. The model's own weathered albedo and engraved normal map are kept; this adds how stone behaves:
// polished faces are glossy and rough faces are matte, grime and lichen collect in damp patches and on up-facing
// surfaces, rain darkens the stone and fills its pores so it turns shiny, and snow settles on top.
// UV2.x carries the model's polish value (0 honed or weathered .. 1 polished).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float g_wet;
global uniform float g_snow;

uniform sampler2D albedo_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float normal_depth = 0.45;
uniform vec3 tint = vec3(0.62);

varying float vPolish;
varying vec3 vCol;
varying vec3 vWorld;
varying vec3 vWorldN;

float h31(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vPolish = clamp(UV2.x, 0.0, 1.0);
	vCol = COLOR.rgb;
	vWorld = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vWorldN = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * vCol * tint;
	float lum = dot(a, vec3(0.299, 0.587, 0.114));
	float n1 = vn(vWorld * 2.5);
	float n2 = vn(vWorld * 16.0);
	float top = smoothstep(0.35, 0.95, vWorldN.y);
	float damp = 0.25 + 0.75 * g_wet;
	// lichen and moss: patchy, mostly on rough up-facing stone, spreading in the wet
	float moss = smoothstep(0.58, 0.82, n1 * 0.7 + n2 * 0.3) * damp * (0.35 + 0.65 * top) * (1.0 - vPolish * 0.85);
	a = mix(a, vec3(0.16, 0.22, 0.07), moss * 0.55);
	float rough = mix(0.88, 0.2, vPolish);
	rough = mix(rough, 0.92, moss);
	rough += (n2 - 0.5) * (0.22 - 0.14 * lum);          // pitting and mottling
	// rain: darker stone, shinier surface
	float w = g_wet * (1.0 - 0.3 * vPolish);
	a *= mix(1.0, 0.58, w);
	rough = mix(rough, rough * 0.32, g_wet);
	// snow on the tops
	float snow = g_snow * smoothstep(0.55, 0.9, vWorldN.y) * (0.6 + 0.4 * n1);
	a = mix(a, vec3(0.65, 0.68, 0.76), snow);
	rough = mix(rough, 0.85, snow);
	ALBEDO = a;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	SPECULAR = mix(0.4, 0.65, vPolish) + 0.3 * g_wet;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - 0.5 * snow);
}
