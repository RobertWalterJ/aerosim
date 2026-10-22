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
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);          // unit vector towards the moon
uniform float moon_illum : hint_range(0.0, 1.0) = 0.5; // fraction of the moon's face that is lit

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
	vec3 zenith = mix(vec3(0.004, 0.007, 0.018), vec3(0.10, 0.26, 0.70), day);
	vec3 horizon = mix(vec3(0.009, 0.011, 0.022), vec3(0.55, 0.72, 0.92), day);
	horizon = mix(horizon, vec3(0.95, 0.62, 0.38), warm * day * (0.5 + 0.5 * pow(max(mu, 0.0), 2.0)));
	zenith = mix(zenith, vec3(0.28, 0.32, 0.50), warm * 0.4);
	vec3 col = mix(horizon, zenith, pow(up, 0.42));
	// haze and ground fog wash the colour towards a milky grey, most strongly near the horizon
	vec3 milk = mix(vec3(0.5, 0.54, 0.60), vec3(0.74, 0.76, 0.80), day) * (0.6 + 0.4 * day);
	col = mix(col, milk, clamp(haze * 0.5 + fog * (0.55 + 0.45 * (1.0 - up)), 0.0, 1.0));
	// Mie glow and sun disc
	float glow = pow(max(mu, 0.0), 6.0) * 0.35 + pow(max(mu, 0.0), 64.0) * 0.8;
	col += vec3(1.0, 0.82, 0.58) * glow * day * (1.0 - 0.8 * cover);
	// distant ridges beyond the edge of the modelled land: two hazy silhouettes, the far one paler
	float az = atan(dir.x, dir.z);
	float ridge_far = 0.010 + 0.042 * vnoise(vec3(az * 1.7, 0.5, 0.5)) + 0.014 * vnoise(vec3(az * 6.0, 2.0, 0.5));
	float ridge_near = 0.004 + 0.026 * vnoise(vec3(az * 2.6, 4.0, 1.5)) + 0.008 * vnoise(vec3(az * 9.0, 7.0, 0.5));
	float vis = (1.0 - clamp(fog * 1.1, 0.0, 1.0)) * step(0.0, dir.y) * day;
	vec3 far_c = mix(horizon, vec3(0.36, 0.50, 0.66), 0.55);
	vec3 near_c = mix(horizon, vec3(0.20, 0.33, 0.38), 0.65);
	col = mix(col, far_c, (1.0 - smoothstep(ridge_far - 0.0015, ridge_far + 0.0015, dir.y)) * vis * 0.85);
	col = mix(col, near_c, (1.0 - smoothstep(ridge_near - 0.0015, ridge_near + 0.0015, dir.y)) * vis * 0.8);
	float disc = smoothstep(0.99955, 0.99975, mu) * 60.0 * day;
	// ---- night: stars, and the moon with its phase
	float night = 1.0 - smoothstep(-0.16, 0.04, sun_h);
	vec3 night_extra = vec3(0.0);
	float moon_up = smoothstep(-0.08, 0.04, moon_dir.y);
	if (night > 0.01) {
		// stars: a jittered point in each cell of a fine grid on the sphere, each with its own brightness and twinkle
		vec3 sp = dir * 90.0;
		vec3 cell = floor(sp);
		vec3 fp = fract(sp) - 0.5;
		float h = hash13(cell);
		vec3 jit = vec3(hash13(cell + 7.1), hash13(cell + 13.7), hash13(cell + 29.3)) - 0.5;
		float star = smoothstep(0.07, 0.0, length(fp - jit * 0.5)) * step(0.80, h);
		float tw = 0.75 + 0.25 * sin(TIME * (2.0 + 5.0 * h) + h * 40.0);
		float mag = pow((h - 0.80) / 0.20, 2.0) * 3.0 + 0.4;
		vec3 starc = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.88, 0.7), fract(h * 91.7));
		float hide = smoothstep(0.0, 0.1, dir.y) * (1.0 - 0.9 * haze) * (1.0 - fog) * (1.0 - 0.8 * moon_illum * moon_up);
		night_extra += starc * star * mag * tw * hide * 1.6;
		// the faint band of the Milky Way
		float band = exp(-pow(dot(dir, normalize(vec3(0.3, 0.8, -0.5))) * 4.0, 2.0));
		night_extra += vec3(0.30, 0.34, 0.46) * band * (0.25 + 0.75 * fbm(dir * 7.0)) * 0.05 * hide;
		// moonlight lifts the whole sky a little
		col += vec3(0.0035, 0.0055, 0.012) * moon_illum * moon_up * night * (1.0 - 0.5 * up);
		float mu_m = dot(dir, moon_dir);
		// the disc, drawn a little larger than life so it reads on a small screen
		float rad = 0.02;
		float ang = acos(clamp(mu_m, -1.0, 1.0));
		if (ang < rad * 1.25 && moon_dir.y > -0.08) {
			vec3 t1 = normalize(cross(vec3(0.0, 1.0, 0.0), moon_dir));
			vec3 t2 = cross(moon_dir, t1);
			vec2 pm = vec2(dot(dir, t1), dot(dir, t2)) / sin(rad);
			float r2 = dot(pm, pm);
			if (r2 < 1.0) {
				vec3 sdn = normalize(sun_dir);
				float cos_e = dot(sdn, moon_dir);
				float sin_e = sqrt(max(1.0 - cos_e * cos_e, 0.0));
				vec2 toward = vec2(dot(sdn, t1), dot(sdn, t2));
				toward = length(toward) > 1e-4 ? normalize(toward) : vec2(1.0, 0.0);
				vec3 nrm = vec3(pm, sqrt(1.0 - r2));
				vec3 lgt = vec3(toward * sin_e, -cos_e);
				float lit = smoothstep(-0.04, 0.10, dot(nrm, lgt));
				float maria = 0.55 + 0.45 * fbm(vec3(pm * 2.2, 3.0));
				float shade = (lit * maria + 0.02) * smoothstep(1.0, 0.92, r2);
				night_extra += vec3(1.0, 0.97, 0.9) * shade * 0.22 * moon_up;
			}
		}
		night_extra += vec3(0.55, 0.65, 1.0) * (pow(max(mu_m, 0.0), 220.0) * 0.12 + pow(max(mu_m, 0.0), 24.0) * 0.012) * moon_illum * moon_up;
		night_extra *= night;
	}
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
	vec3 sky_col = col + vec3(1.0, 0.95, 0.85) * disc * (1.0 - cloud_a) + night_extra * (1.0 - cloud_a);
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
