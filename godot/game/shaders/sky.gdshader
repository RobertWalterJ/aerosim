// A weather-driven sky: analytic clear-sky colour from the sun's height (zenith blue, horizon haze, sunset warmth),
// Mie glow around the sun, a sun disc that clouds can hide, raymarched volumetric cumulus with lit edges and shaded
// undersides, thin high cirrus, night (stars, Milky Way, moon disc with phase), and lightning flash. Cloud cover,
// darkness, haze and fog come from the current weather, so the sky always matches the light on the ground.
shader_type sky;

#include "cloud_coverage.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 0.5, -0.8);   // unit vector towards the sun
uniform float cover : hint_range(0.0, 1.0) = 0.2;     // 0 clear .. 1 solid overcast
uniform float dark : hint_range(0.0, 1.0) = 0.0;      // 0 white cloud .. 1 storm grey
uniform float cirrus : hint_range(0.0, 1.0) = 0.3;
uniform float haze : hint_range(0.0, 1.0) = 0.2;      // dust and moisture: washes out the blue
uniform float fog : hint_range(0.0, 1.0) = 0.0;       // ground fog: the whole lower sky goes milky
uniform vec2 drift = vec2(0.6, 0.2);                  // cloud movement in metres per second (wind)
uniform float flash : hint_range(0.0, 1.0) = 0.0;     // lightning
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);          // unit vector towards the moon
uniform float moon_illum : hint_range(0.0, 1.0) = 0.5; // fraction of the moon's face that is lit
uniform vec3 cam_pos = vec3(0.0, 100.0, 0.0);         // camera world position (for the cloud raymarch)
uniform int cloud_quality = 1;                        // 0 low, 1 medium, 2 high
uniform vec3 haze_col = vec3(0.62, 0.70, 0.80);       // horizon haze colour (set from env.fog_light_color, = g_haze)

float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p = p * 2.07 + vec3(11.3, 5.7, 3.1); a *= 0.5; } return s; }

// normalised fbm with a runtime octave cap (constant loop bound for the GPU)
float fbmn(vec3 p, int oct) {
	float s = 0.0; float a = 0.5; float tot = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) break;
		s += a * vnoise(p); tot += a;
		p = p * 2.07 + vec3(11.3, 5.7, 3.1); a *= 0.5;
	}
	return s / max(tot, 1e-4);
}

// ------------------------------------------------------------------ volumetric cumulus
const float CBASE = 1500.0;    // cloud base, world metres
const float CTHICK = 2000.0;   // slab thickness, so the top is 3500 m

float cloud_density(vec3 p, float t) {
	float h = (p.y - CBASE) / CTHICK;
	if (h < 0.0 || h > 1.0) return 0.0;
	int oct = 5; if (cloud_quality == 1) oct = 4; else if (cloud_quality == 0) oct = 2;
	// the shared coverage (the same noise and drift the ground shadows use)
	float shape = cloud_shape(p.xz, drift, t, oct);
	// coverage: more cover lowers the noise threshold, so the sky fills in
	float lo = 1.0 - cover;
	float cov = clamp((shape - lo) / max(cover, 1e-3), 0.0, 1.0);
	// flat-ish base, rounded tops: density where the coverage exceeds the height
	float d = cov - h;
	// ragged undersides (sky-only detail)
	vec3 q = vec3((p.xz - drift * t) * (1.0 / 950.0), t * 0.002);
	d -= fbmn(q * 2.4 + 13.0, oct) * 0.16 * (1.0 - smoothstep(0.0, 0.4, h));
	d = smoothstep(0.0, 0.26, d);
	return clamp(d, 0.0, 1.0);
}

// how much direct sun reaches a point in the cloud (0 shaded .. 1 lit)
float cloud_light(vec3 p, vec3 sd, int lsteps, float t) {
	float h = (p.y - CBASE) / CTHICK;
	if (lsteps <= 0) {
		// phones fake the light with the height gradient (bases darker, tops lighter)
		return 0.30 + 0.70 * smoothstep(0.0, 0.6, h);
	}
	float tau = 0.0; float ld = 0.0;
	const float LST = 70.0;
	for (int i = 0; i < 4; i++) {
		if (i >= lsteps) break;
		ld += LST;
		tau += cloud_density(p + sd * ld, t);
	}
	return exp(-tau * 1.1);
}

// raymarch the slab: returns rgb (scattered light, HDR) and a (coverage 0..1)
vec4 march_clouds(vec3 ro, vec3 rd, vec3 sun_c, vec3 fill, vec3 grey, float t, int steps, int lsteps) {
	if (rd.y < 0.02) return vec4(0.0);
	float tb = (CBASE - ro.y) / rd.y;
	float tt = (CBASE + CTHICK - ro.y) / rd.y;
	if (tt < 0.0) return vec4(0.0);
	float t0 = max(tb, 0.0);
	float t1 = min(tt, 30000.0);   // distant clouds fade into the haze
	if (t0 >= t1) return vec4(0.0);
	float dt = (t1 - t0) / float(max(steps, 1));
	float step_t = t0 + dt * 0.5;
	vec3 acc = vec3(0.0);
	float trans = 1.0;
	const float SIGMA = 0.0033;
	for (int i = 0; i < 12; i++) {
		if (i >= steps) break;
		vec3 p = ro + rd * step_t;
		float dens = cloud_density(p, t);
		if (dens > 0.0015) {
			float light = cloud_light(p, sun_dir, lsteps, t);
			float powder = 1.0 - exp(-dens * 2.0);
			vec3 lc = sun_c * light + fill;                        // sun plus blue sky fill in the shade
			lc = mix(lc, grey * (0.4 + 0.6 * light), dark);        // storm greys and darkens the shade
			vec3 sc = lc + sun_c * powder * light * 1.1;           // silver lining on lit edges
			float step_ext = exp(-dens * dt * SIGMA);
			acc += sc * trans * (1.0 - step_ext);
			trans *= step_ext;
		}
		if (trans < 0.02) break;
		step_t += dt;
	}
	return vec4(acc, 1.0 - trans);
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
	// haze and ground fog wash the colour towards the fog colour, most strongly near the horizon, and
	// brighten toward the sun (forward scattering), so the sky and the far hills share one haze colour
	vec3 milk = haze_col * (1.15 + 0.7 * pow(max(mu, 0.0), 3.0) * day);
	col = mix(col, milk, clamp(haze * 0.6 + fog * (0.55 + 0.45 * (1.0 - up)), 0.0, 1.0));
	// Mie glow and sun disc
	float glow = pow(max(mu, 0.0), 6.0) * 0.35 + pow(max(mu, 0.0), 64.0) * 0.8;
	col += vec3(1.0, 0.82, 0.58) * glow * day * (1.0 - 0.8 * cover);
	// distant ridges beyond the edge of the modelled land: two hazy silhouettes, the far one paler
	float az = atan(dir.x, dir.z);
	float ridge_far = 0.010 + 0.042 * vnoise(vec3(az * 1.7, 0.5, 0.5)) + 0.014 * vnoise(vec3(az * 6.0, 2.0, 0.5));
	float ridge_near = 0.004 + 0.026 * vnoise(vec3(az * 2.6, 4.0, 1.5)) + 0.008 * vnoise(vec3(az * 9.0, 7.0, 0.5));
	float vis = (1.0 - clamp(fog * 1.1, 0.0, 1.0)) * step(0.0, dir.y) * day;
	vec3 far_c = mix(horizon, haze_col, 0.7);
	vec3 near_c = mix(horizon, haze_col, 0.82);
	col = mix(col, far_c, (1.0 - smoothstep(ridge_far - 0.0015, ridge_far + 0.0015, dir.y)) * vis * 0.85);
	col = mix(col, near_c, (1.0 - smoothstep(ridge_near - 0.0015, ridge_near + 0.0015, dir.y)) * vis * 0.8);
	float disc = smoothstep(0.99955, 0.99975, mu) * 60.0 * day;
	// ---- night: stars, and the moon with its phase
	float night = 1.0 - smoothstep(-0.16, 0.04, sun_h);
	vec3 night_extra = vec3(0.0);
	float moon_up = smoothstep(-0.08, 0.04, moon_dir.y);
	if (night > 0.01) {
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
		night_extra += starc * star * mag * tw * hide * 1.25;
		float band = exp(-pow(dot(dir, normalize(vec3(0.3, 0.8, -0.5))) * 4.0, 2.0));
		night_extra += vec3(0.30, 0.34, 0.46) * band * (0.25 + 0.75 * fbm(dir * 7.0)) * 0.05 * hide;
		col += vec3(0.0035, 0.0055, 0.012) * moon_illum * moon_up * night * (1.0 - 0.5 * up);
		float mu_m = dot(dir, moon_dir);
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
				night_extra += vec3(1.0, 0.97, 0.9) * shade * 0.18 * moon_up;
			}
		}
		night_extra += vec3(0.55, 0.65, 1.0) * (pow(max(mu_m, 0.0), 220.0) * 0.12 + pow(max(mu_m, 0.0), 24.0) * 0.012) * moon_illum * moon_up;
		// a soft halo around the moon
		night_extra += vec3(0.6, 0.7, 0.9) * exp(-pow(acos(clamp(mu_m, -1.0, 1.0)) / 0.06, 2.0)) * 0.05 * moon_illum * moon_up;
		night_extra *= night;
	}
	// ---- volumetric clouds
	vec3 sun_c = mix(vec3(1.0, 1.0, 1.0), vec3(1.0, 0.60, 0.34), warm * day) * day;
	vec3 fill = mix(vec3(0.03, 0.04, 0.07), vec3(0.30, 0.42, 0.62), day);
	fill = mix(fill, vec3(0.55, 0.36, 0.20), warm * day * 0.55);   // sunset warms the cloud shade (reds on the undersides)
	fill *= (0.4 + 0.6 * day);
	vec3 grey = mix(vec3(0.30, 0.32, 0.36), vec3(0.09, 0.10, 0.14), dark);
	vec3 cloud_col = vec3(0.0);
	float cloud_a = 0.0;
	if (dir.y > 0.005 && cover > 0.01) {
		int steps = 12; int lsteps = 3;
		if (cloud_quality <= 0) { steps = 4; lsteps = 0; }
		else if (cloud_quality == 1) { steps = 8; lsteps = 2; }
		vec4 mc = march_clouds(cam_pos, dir, sun_c, fill, grey, TIME, steps, lsteps);
		cloud_col = mc.rgb;
		cloud_a = clamp(mc.a, 0.0, 1.0) * smoothstep(0.005, 0.05, dir.y);
		// thin high cirrus: wispy streaks on broad bands, warm when the low sun lights them
		if (cirrus > 0.02) {
			vec2 cq = dir.xz / (dir.y + 0.45);
			cq += drift * TIME * 0.001;
			float bands = fbm(vec3(cq.x * 0.5, cq.y * 2.4, 2.1));
			float wisps = fbm(vec3(cq.x * 1.6 + 9.0, cq.y * 5.5, 5.2));
			float ci = smoothstep(0.58, 0.78, bands * 0.5 + wisps * 0.5);
			ci *= 0.55 + 0.45 * smoothstep(0.5, 0.75, bands);   // mostly where a broad band sits
			ci = clamp(ci, 0.0, 1.0) * cirrus * (1.0 - cloud_a) * smoothstep(0.02, 0.28, dir.y) * (1.0 - 0.7 * dark);
			vec3 ci_col = mix(vec3(0.88, 0.92, 1.0), vec3(1.0, 0.66, 0.42), warm * day * (0.4 + 0.6 * smoothstep(0.0, 0.7, mu)));
			cloud_col = mix(cloud_col, ci_col, ci / max(cloud_a + ci, 1e-3));
			cloud_a = clamp(cloud_a + ci * 0.65, 0.0, 1.0);
		}
	}
	// faint moonlight lifts the clouds at night
	cloud_col += vec3(0.10, 0.14, 0.22) * moon_illum * moon_up * (1.0 - day) * cloud_a;
	// the sun is hidden by cloud
	vec3 sky_col = col + vec3(1.0, 0.95, 0.85) * disc * (1.0 - cloud_a) + night_extra * (1.0 - cloud_a);
	sky_col = mix(sky_col, cloud_col, cloud_a);
	// below the horizon: ground haze colour
	if (dir.y < 0.0) {
		vec3 g = mix(vec3(0.08, 0.09, 0.08), vec3(0.30, 0.31, 0.26), day);
		sky_col = mix(sky_col, g, smoothstep(0.0, -0.08, dir.y));
	}
	// lightning lights the whole cloud deck for an instant
	sky_col += vec3(0.7, 0.75, 1.0) * flash * (0.4 + 0.8 * cloud_a) * 3.0;
	COLOR = sky_col;
}
