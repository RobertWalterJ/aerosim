// A weather-driven sky: analytic clear-sky colour from the sun's height (zenith blue, horizon haze, sunset warmth),
// Mie glow around the sun, a sun disc that clouds can hide, and two procedural cloud layers: puffy low cumulus that
// thickens into overcast and storm cloud, and thin high cirrus. Cloud cover, darkness, haze and fog come from the
// current weather, so the sky always matches the light on the ground.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 0.5, -0.8);   // unit vector towards the sun
uniform float cover : hint_range(0.0, 1.0) = 0.2;     // 0 clear .. 1 solid overcast
uniform float dark : hint_range(0.0, 1.0) = 0.0;      // 0 white cloud .. 1 storm grey
uniform float cirrus : hint_range(0.0, 1.0) = 0.3;
uniform float haze : hint_range(0.0, 1.0) = 0.2;      // dust and moisture: washes out the blue
uniform float fog : hint_range(0.0, 1.0) = 0.0;       // ground fog: the whole lower sky goes milky
uniform vec2 drift = vec2(0.6, 0.2);                  // cloud movement in noise units per second
uniform float flash : hint_range(0.0, 1.0) = 0.0;     // lightning

float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.07 + vec3(11.3, 5.7, 3.1); a *= 0.5; } return s; }

// density of a low cloud layer at a point on the cloud plane
float cumulus(vec2 q, float t) {
	vec3 p = vec3(q * 0.9 + drift * t * 0.05, t * 0.02);
	float base = fbm(p);
	float detail = fbm(p * 3.1 + 7.0);
	float shape = base * 0.78 + detail * 0.22;
	// coverage remaps the noise: more cover lowers the threshold, and overcast fills the gaps
	float thr = mix(0.78, 0.30, cover);
	float d = smoothstep(thr, thr + 0.18 + 0.25 * cover, shape);
	return clamp(d + smoothstep(0.75, 1.0, cover) * 0.8, 0.0, 1.0);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = max(dir.y, 0.0);
	float sun_h = sun_dir.y;
	float mu = dot(dir, normalize(sun_dir));
	float day = smoothstep(-0.12, 0.12, sun_h);                 // 0 night .. 1 day
	float warm = 1.0 - smoothstep(0.06, 0.42, sun_h);           // sunrise and sunset
	// ---- clear sky
	vec3 zenith = mix(vec3(0.03, 0.05, 0.12), vec3(0.16, 0.34, 0.72), day);
	vec3 horizon = mix(vec3(0.06, 0.07, 0.12), vec3(0.62, 0.74, 0.90), day);
	horizon = mix(horizon, vec3(0.95, 0.62, 0.38), warm * day * (0.5 + 0.5 * pow(max(mu, 0.0), 2.0)));
	zenith = mix(zenith, vec3(0.28, 0.32, 0.50), warm * 0.4);
	vec3 col = mix(horizon, zenith, pow(up, 0.42));
	// haze and ground fog wash the colour towards a milky grey, most strongly near the horizon
	vec3 milk = mix(vec3(0.5, 0.54, 0.60), vec3(0.74, 0.76, 0.80), day) * (0.6 + 0.4 * day);
	col = mix(col, milk, clamp(haze * 0.5 + fog * (0.55 + 0.45 * (1.0 - up)), 0.0, 1.0));
	// Mie glow and sun disc
	float glow = pow(max(mu, 0.0), 6.0) * 0.35 + pow(max(mu, 0.0), 64.0) * 0.8;
	col += vec3(1.0, 0.82, 0.58) * glow * day * (1.0 - 0.8 * cover);
	float disc = smoothstep(0.99955, 0.99975, mu) * 60.0 * day;
	// ---- clouds on a plane above the viewer
	float cloud_a = 0.0;
	vec3 cloud_col = vec3(1.0);
	if (dir.y > 0.01 && (cover > 0.02 || cirrus > 0.02)) {
		float horizon_fade = smoothstep(0.01, 0.22, dir.y);
		vec2 q = dir.xz / (dir.y + 0.12);
		float d = cumulus(q, TIME) * horizon_fade;
		// light: compare with a point nudged towards the sun; thick cloud towards the sun is shaded
		vec2 toward = normalize(sun_dir.xz + vec2(1e-3)) * 0.12;
		float d2 = cumulus(q + toward, TIME);
		float shade = clamp(1.0 - 0.75 * d2 * d, 0.0, 1.0);
		vec3 lit = mix(vec3(0.55, 0.60, 0.70), vec3(1.0, 0.98, 0.95), day) * (0.35 + 0.9 * shade);
		lit = mix(lit, vec3(1.0, 0.72, 0.5) * (0.4 + 0.8 * shade), warm * day * 0.7);
		vec3 grey = mix(vec3(0.30, 0.32, 0.36), vec3(0.12, 0.13, 0.16), dark) * (0.35 + 0.65 * day);
		cloud_col = mix(lit, grey, clamp(dark + 0.55 * cover * d2, 0.0, 1.0));
		cloud_a = d * (1.0 - 0.15 * (1.0 - cover));
		// thin high cirrus: stretched streaks
		vec2 cq = dir.xz / (dir.y + 0.35);
		float ci = fbm(vec3(cq.x * 0.6 + drift.x * TIME * 0.01, cq.y * 3.2, 1.7));
		ci = smoothstep(0.55, 0.85, ci) * cirrus * (1.0 - cloud_a) * smoothstep(0.02, 0.25, dir.y) * (1.0 - 0.7 * dark);
		cloud_col = mix(cloud_col, mix(vec3(0.85, 0.88, 0.95), vec3(1.0, 0.8, 0.6), warm * day), ci / max(cloud_a + ci, 1e-3));
		cloud_a = clamp(cloud_a + ci * 0.7, 0.0, 1.0);
	}
	// the sun is hidden by cloud
	vec3 sky_col = col + vec3(1.0, 0.95, 0.85) * disc * (1.0 - cloud_a);
	sky_col = mix(sky_col, cloud_col * (0.9 + 0.5 * day), cloud_a);
	// below the horizon: ground haze colour
	if (dir.y < 0.0) {
		vec3 g = mix(vec3(0.08, 0.09, 0.08), vec3(0.30, 0.31, 0.26), day);
		sky_col = mix(sky_col, g, smoothstep(0.0, -0.08, dir.y));
	}
	// lightning lights the whole cloud deck for an instant
	sky_col += vec3(0.7, 0.75, 1.0) * flash * (0.4 + 0.8 * cloud_a) * 3.0;
	COLOR = sky_col;
}
