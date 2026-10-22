// Stages 1, 3, 4 + exposure + sensor noise: rolling shutter and motor jello, sun streak + cyan ghost + veiling glare
// (evaluated in the lens plane), Brown-Conrady distortion with lateral chromatic aberration, vignette, ISO noise.
// Ported from SENSOR in SensorPipeline.glsl.ts. vUv below is the web version's bottom-left-origin uv.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uScene : filter_linear, repeat_disable;
uniform sampler2D uBloom : filter_linear, repeat_disable;
uniform sampler2D uExp : filter_nearest, repeat_disable;
uniform float uS = 1.15;
uniform float uAspect = 1.7778;
uniform float uTime = 0.0;
uniform float uReadout = 0.012;
uniform float uVibAmp = 0.0;
uniform float uVibFreq = 60.0;
uniform float uBloomK = 0.08;
uniform vec2 uTan = vec2(1.0, 0.5);
uniform vec2 uK = vec2(0.0);
uniform vec2 uSunS = vec2(2.0, 2.0);
uniform vec2 uWRS = vec2(0.0);
uniform float uSunVis = 0.0;
uniform float uInView = 0.0;
uniform float uWRoll = 0.0;
uniform float uGlare = 0.0;
uniform float uIso = 1.0;
uniform float uCA = 0.004;
uniform float uGhostK = 0.55;
uniform float uFrame = 0.0;
uniform float uFlareI = 1.0;
uniform float uVig = 0.28;
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
float hash(vec2 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973).xy); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
const vec3 ghostCol = vec3(0.0513, 1.0, 0.402);

vec3 flare(vec2 uvS, float gSunVis) {
	vec2 d = (uvS - uSunS) * uS * vec2(uAspect, 1.0);
	float ang = radians(10.0); vec2 n = vec2(sin(ang), cos(ang)); vec2 pp = vec2(n.y, -n.x);
	float al = dot(d, n); float pe = dot(d, pp);
	float streak = exp(-pe * pe / (2.0 * 0.0025 * 0.0025)) * exp(-al * al / (2.0 * 0.28 * 0.28));
	float halo = exp(-dot(d, d) / (2.0 * 0.02 * 0.02)) * 0.8 + exp(-dot(d, d) / (2.0 * 0.12 * 0.12)) * 0.08;
	vec3 c = (vec3(1.0, 0.93, 0.82) * streak * 0.35 + vec3(1.0, 0.82, 0.6) * halo) * gSunVis * uFlareI;
	vec2 sf = (uSunS - 0.5) * uS;
	vec2 gp = -uGhostK * sf;
	vec2 gd = ((uvS - 0.5) * uS - gp) * vec2(uAspect, 1.0);
	float r = length(gd);
	float ring = exp(-pow((r - 0.075) / 0.0065, 2.0)) + 0.55 * exp(-pow((r - 0.052) / 0.0045, 2.0)) + 0.12 * smoothstep(0.075, 0.0, r);
	float fadeG = smoothstep(1.4, 0.15, length(sf));
	c += ghostCol * ring * 0.55 * gSunVis * uFlareI * (0.35 + fadeG);
	vec2 gp2 = -0.28 * sf; float r2 = length(((uvS - 0.5) * uS - gp2) * vec2(uAspect, 1.0));
	c += vec3(0.9, 0.5, 0.35) * exp(-pow((r2 - 0.03) / 0.005, 2.0)) * 0.25 * gSunVis * uFlareI * fadeG;
	return c;
}

void fragment() {
	float gSunVis = uSunVis * uInView;
	vec2 vUv = vec2(UV.x, 1.0 - UV.y);
	vec2 uv = vUv;
	// rolling shutter (12 ms readout) and motor jello
	float tl = (uv.y - 0.5) * uReadout;
	vec2 shift = vec2(uWRS.x * tl / (2.0 * uTan.x), -uWRS.y * tl / (2.0 * uTan.y));
	vec2 pc = uv - 0.5;
	shift += vec2(-pc.y, pc.x) * uWRoll * tl * 0.9 * vec2(1.0 / uAspect, 1.0);
	float jello = sin(uv.y * 190.0 + uTime * uVibFreq) * 0.6 + sin(uv.y * 71.0 - uTime * uVibFreq * 0.37) * 0.4;
	shift.x += jello * uVibAmp;
	shift.y += jello * uVibAmp * 0.25 * sin(uv.x * 40.0 + uTime * uVibFreq * 0.5);
	vec2 uvd = uv - vec2(shift.x, -shift.y);
	// Brown-Conrady radial distortion; lateral CA scales channels radially
	vec2 a = (uvd - 0.5) * 2.0;
	vec2 tanXY = a * uTan;
	float r = length(tanXY) / length(uTan);
	float f = 1.0 + uK.x * r * r + uK.y * r * r * r * r;
	vec2 sR = 0.5 + 0.5 * a * f * (1.0 + uCA) / uS;
	vec2 sG = 0.5 + 0.5 * a * f / uS;
	vec2 sB = 0.5 + 0.5 * a * f * (1.0 - uCA) / uS;
	float e = exp2(texture(uExp, vec2(0.5)).r);
	vec3 col = vec3(T(uScene, sR).r, T(uScene, sG).g, T(uScene, sB).b) * e;
	vec3 bl = vec3(T(uBloom, sR).r, T(uBloom, sG).g, T(uBloom, sB).b);
	col += bl * uBloomK;
	// anamorphic streak, cyan ghost and veiling glare
	col += flare(sG, gSunVis);
	col += vec3(0.020, 0.022, 0.026) * uGlare * (0.4 + 0.6 * gSunVis);
	// optical vignette
	float vr = length(a) * 0.7071; col *= 1.0 - uVig * vr * vr;
	// sensor ISO noise (shot + read), luminance and chroma, scaled by analogue gain
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	vec2 np = FRAGCOORD.xy + vec2(uFrame * 17.0, uFrame * 31.0);
	float n1 = hash(np) - 0.5; float n2 = hash(np + 7.7) - 0.5; float n3 = hash(np + 13.1) - 0.5;
	float amp = (0.004 + 0.045 * sqrt(max(lum, 0.0))) * uIso * 0.45;
	col += vec3(n1) * amp + vec3(n1 * 0.3 + n2, n2 * 0.3 - n3, n3 * 0.3 + n1) * amp * 0.45;
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
