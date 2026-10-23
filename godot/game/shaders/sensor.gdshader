// Stages 1, 3, 4 + exposure + sensor noise: rolling shutter and motor jello, sun streak + cyan ghost + veiling glare
// (evaluated in the lens plane), Brown-Conrady distortion with lateral chromatic aberration, vignette, ISO noise.
// Ported from SENSOR in SensorPipeline.glsl.ts. vUv below is the web version's bottom-left-origin uv.
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D uScene : filter_linear, repeat_disable;
uniform sampler2D uBloom : filter_linear, repeat_disable;
uniform float uExpV = 0.0;     // log2 exposure, worked out on the CPU
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
uniform vec3 uWB = vec3(1.0);   // white balance gain from the camera's auto white balance
uniform float uRain = 0.0;     // water on the lens, 0 dry .. 1 streaming
uniform float uWash = 0.0;      // rotor wash over the lens, 0..1
uniform vec3 uAir = vec3(0.0);  // air moving over the lens, in the camera's own axes (m/s): sideways, up, and head-on speed
vec4 T(sampler2D s, vec2 v) { return texture(s, vec2(v.x, 1.0 - v.y)); }
float hash(vec2 p) { p = fract(p * vec3(0.1031, 0.1030, 0.0973).xy); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
const vec3 ghostCol = vec3(0.0513, 1.0, 0.402);

vec3 flare(vec2 uvS, float gSunVis) {
	vec2 d = (uvS - uSunS) * uS * vec2(uAspect, 1.0);
	float ang = radians(10.0); vec2 n = vec2(sin(ang), cos(ang)); vec2 pp = vec2(n.y, -n.x);
	float al = dot(d, n); float pe = dot(d, pp);
	float streak = exp(-pe * pe / (2.0 * 0.0025 * 0.0025)) * exp(-al * al / (2.0 * 0.14 * 0.14));
	float halo = exp(-dot(d, d) / (2.0 * 0.02 * 0.02)) * 0.8 + exp(-dot(d, d) / (2.0 * 0.12 * 0.12)) * 0.08;
	vec3 c = (vec3(1.0, 0.93, 0.82) * streak * 0.3 + vec3(1.0, 0.82, 0.6) * halo) * gSunVis * uFlareI;
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

// drops of water on the lens: each bends the picture like a tiny fisheye, so the scene shows through it upside down.
// Two layers of drops (a few big, many small) on tilted, jittered grids, so the pattern looks random. Drops grow, then run:
// down under their own weight, sideways with the air, and outward from the middle when the drone flies into the rain.
// Fast air stretches them into streaks, shrinks them and blows them off, so the lens clears in flight. The rotor wash shakes
// drops and flings some of them off in random directions.
vec4 drop_layer(vec2 uv, float scale, float tilt, float seed, float cover, float size_mul, float clear) {
	float ct = cos(tilt); float st = sin(tilt);
	mat2 rot = mat2(vec2(ct, st), vec2(-st, ct));
	vec2 g = rot * (uv * vec2(uAspect, 1.0) * scale) + vec2(seed * 7.13, seed * 3.71);
	vec2 id = floor(g); vec2 f = fract(g) - 0.5;
	float h0 = hash(id + seed);
	if (h0 > cover * (0.10 + 0.90 * clear) * (1.0 - 0.45 * uWash)) return vec4(0.0);
	float h1 = hash(id + 3.1 + seed); float h2 = hash(id + 7.7 + seed); float h3 = hash(id + 1.3 + seed); float h4 = hash(id + 5.9 + seed);
	vec2 radial = length(uv - 0.5) > 1e-4 ? normalize((uv - 0.5) * vec2(uAspect, 1.0)) : vec2(0.0, 1.0);
	vec2 scatter = vec2(h1 - 0.5, h4 - 0.5) * 2.0;                                     // each drop's own random direction in the wash
	vec2 flow = vec2(0.0, -0.045) + uAir.xy * 0.035 + radial * uAir.z * 0.06 + scatter * uWash * 0.10;   // cell widths per second
	float fl = length(flow);
	vec2 fdir = fl > 1e-5 ? flow / fl : vec2(0.0, -1.0);
	vec2 fdc = rot * fdir;
	float life = 5.0 + 7.0 * h3 - 3.0 * (1.0 - clear) - 2.5 * uWash;
	float phase = fract(uTime / life + h2);
	float travel = min(fl * phase * life, 0.38);
	vec2 shake = vec2(sin(uTime * 37.0 + h1 * 40.0), cos(uTime * 41.0 + h2 * 40.0)) * 0.012 * uWash;      // drops shiver in the wash
	vec2 p = (vec2(h1, h2) - 0.5) * 0.36 + fdc * travel + shake;
	float grow = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.85, 1.0, phase));
	float size = (0.06 + 0.17 * h3 * h3 + 0.05 * h4) * size_mul * (0.5 + 0.5 * grow) * (0.55 + 0.45 * clear);
	size = min(size, 0.2);
	vec2 d = f - p;
	vec2 pc = vec2(-fdc.y, fdc.x);
	float along = dot(d, fdc); float across = dot(d, pc);
	float stretch = 1.0 + min(fl * 10.0, 1.6);                                          // a drop under the wind draws out into a tail
	float r = length(vec2(along / stretch, across));
	float m = smoothstep(size, size * 0.55, r) * grow;
	float rim = smoothstep(size * 0.55, size * 0.85, r) * (1.0 - smoothstep(size * 0.85, size, r)) * grow;
	vec2 lens_c = -vec2(along / stretch, across) / size * m * 0.05;
	vec2 bend_c = fdc * lens_c.x + pc * lens_c.y;
	vec2 bend = vec2(ct * bend_c.x + st * bend_c.y, -st * bend_c.x + ct * bend_c.y) * vec2(1.0 / uAspect, 1.0);
	return vec4(bend, m, rim);
}

vec4 droplets(vec2 uv) {
	float clear = 1.0 - smoothstep(2.0, 11.0, length(uAir));        // faster air, fewer drops left on the glass
	vec4 big = drop_layer(uv, 5.5, 0.52, 1.0, uRain * 0.30, 1.0, clear);
	vec4 small = drop_layer(uv, 13.0, -0.31, 4.0, uRain * 0.55, 0.8, clear);
	vec4 mid = drop_layer(uv, 9.0, 1.05, 9.0, uRain * 0.40, 0.95, clear);
	float m = max(max(big.z, small.z), mid.z);
	return vec4(big.xy + small.xy + mid.xy, m, max(max(big.w, small.w), mid.w));
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
	vec4 drops = droplets(vUv) * step(0.001, uRain);
	vec2 dr = drops.xy;
	sR += dr; sG += dr; sB += dr;
	float e = exp2(uExpV);
	vec3 col = vec3(T(uScene, sR).r, T(uScene, sG).g, T(uScene, sB).b) * e;
	vec3 bl = vec3(T(uBloom, sR).r, T(uBloom, sG).g, T(uBloom, sB).b);
	col *= uWB;
	col = col * (1.0 - 0.10 * drops.z) + vec3(0.9, 0.95, 1.0) * drops.w * 0.035 * (0.3 + dot(col, vec3(0.33)));
	col += bl * uBloomK;
	// anamorphic streak, cyan ghost and veiling glare
	col += flare(sG, gSunVis);
	col += vec3(0.020, 0.022, 0.026) * uGlare * (0.4 + 0.6 * gSunVis) * 3.0;
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
