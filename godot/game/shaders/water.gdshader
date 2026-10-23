// A lake: dark water that mirrors the sky and the hills at low angles, wind-driven waves, foam along the shore and a
// darker, deader colour in the deep middle. Rewritten for realism stage 2.5 (lane/water, session B).
//
// What this shader does:
//  - reflections: on a computer the scene's screen-space reflections mirror the hills and trees (env.ssr is on); every
//    renderer also gets a cheap fresnel sky colour from the haze global, so the Mobile renderer and the simple camera
//    still read as water. The sun's own specular on the ripples gives the glint.
//  - waves: one large swell plus wind chop and fine ripple layers, all travelling with the wind and growing with it
//    (g_wind is the wind 30 m up). The normal comes from the wave height gradient, exaggerated a little so the ripples
//    still catch the light at a distance.
//  - shore: the terrain height map (uHeight) against the lake level gives the water depth under every pixel. The
//    shallow band gets foam that breathes with the ripples, the deep water turns dark and still. The lake shape and the
//    shore logic do not change: this only paints the water the lake already has.
//  - the Display > Graphics "Water detail" switch (g_fx.z, 0 = on) turns the waves, foam and reflection colour off,
//    leaving plain dark water for a slow phone.
//  - g_fire (from the fireworks) still adds a glittery glint when a burst is over the lake.

shader_type spatial;
render_mode specular_schlick_ggx, depth_draw_always, cull_back;

global uniform float g_time;
global uniform vec3 g_wind;
global uniform float g_snow;
global uniform vec4 g_fire;
global uniform vec4 g_fx;          // x cloud shadows, y tree colour variety, z water detail off
global uniform vec4 g_water;       // the haze/sky colour the lake mirrors, set from the fog colour every frame

uniform float uLevel = 76.0;       // Lake.LEVEL
uniform sampler2D uHeight : filter_nearest, repeat_disable;
uniform vec3 deep : source_color = vec3(0.012, 0.050, 0.065);
uniform vec3 shallow : source_color = vec3(0.065, 0.190, 0.180);
uniform vec3 foam_col : source_color = vec3(0.80, 0.85, 0.86);

varying vec3 wp;

float hs(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float vn(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hs(i), hs(i + vec2(1, 0)), f.x), mix(hs(i + vec2(0, 1)), hs(i + vec2(1, 1)), f.x), f.y); }

// the terrain height (bilinear, the same grid as Terrain.height)
float ground(vec2 xz) {
	vec2 f = clamp((xz + 2000.0) / 4000.0 * 2048.0, vec2(0.0), vec2(2048.0));
	ivec2 i = ivec2(f);
	vec2 t = f - vec2(i);
	float a = texelFetch(uHeight, i, 0).r;
	float b = texelFetch(uHeight, i + ivec2(1, 0), 0).r;
	float c = texelFetch(uHeight, i + ivec2(0, 1), 0).r;
	float d = texelFetch(uHeight, i + ivec2(1, 1), 0).r;
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

// the swell: three long crossing waves, in metres
float swell(vec2 p, float t, vec2 d) {
	float h = sin(dot(p, d) * 0.045 + t * 1.05) * 0.60;
	h += sin(dot(p, vec2(-d.y, d.x)) * 0.062 + t * 0.83) * 0.38;
	h += sin(dot(p, d) * 0.115 - t * 1.35) * 0.24;
	return h;
}

// wind chop and fine ripples: three scrolling noise layers
float chop(vec2 p, float t, vec2 d) {
	float h = vn(p * 0.12 - d * t * 0.55) * 0.55;
	h += vn(p * 0.42 + vec2(-d.y, d.x) * t * 0.35) * 0.30;
	h += vn(p * 0.95 + d * t * 0.80) * 0.15;
	return h;
}

float height_at(vec2 p, float t, vec2 d, float wind, float big) {
	return swell(p, t, d) * big + chop(p, t, d) * (0.18 + 0.70 * wind) * 1.6;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// g_fx.z = 1 means "water detail off" (default 0, on)
	float detail = 1.0 - step(0.5, g_fx.z);
	float w = clamp(length(g_wind.xz) / 8.0, 0.0, 1.0);
	vec2 d = normalize(g_wind.xz + vec2(0.001));
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float near_k = 1.0 - smoothstep(700.0, 2600.0, dist);      // far away the ripples would only shimmer
	float amp = (0.15 + 0.85 * w) * near_k * detail;

	// the water surface normal from the wave gradient
	float e = 0.9;
	float big = 0.55 + 0.75 * w;
	float h0 = height_at(wp.xz, g_time, d, w, big);
	float hx = height_at(wp.xz + vec2(e, 0.0), g_time, d, w, big);
	float hz = height_at(wp.xz + vec2(0.0, e), g_time, d, w, big);
	vec3 n = normalize(vec3(-(hx - h0) / e * (4.2 + 2.2 * w), 1.0, -(hz - h0) / e * (4.2 + 2.2 * w)));
	n = normalize(mix(vec3(0.0, 1.0, 0.0), n, amp));

	// depth under this pixel from the terrain texture: the deep middle is darker and calmer
	float depth = uLevel - ground(wp.xz);
	float deep_k = smoothstep(1.0, 16.0, depth);
	vec3 water = mix(shallow, deep, deep_k);
	water = mix(water, vec3(0.55, 0.62, 0.68), g_snow * 0.55);

	// shore foam: a shallow band that breathes with the waves, plus a thin hard edge where the water meets the land
	float band = 1.0 - smoothstep(0.05, 0.60, depth);
	float breath = 0.55 + 0.45 * sin(g_time * 1.3 + wp.x * 0.11 + wp.z * 0.07);
	float foam_n = vn(wp.xz * 1.7 + vec2(g_time * 0.22, -g_time * 0.16));
	float foam = clamp(band * (0.35 + 0.65 * breath) * (0.50 + 0.70 * foam_n), 0.0, 1.0) * detail;
	foam += (1.0 - smoothstep(0.0, 0.18, depth)) * 0.8 * detail;

	ALBEDO = mix(water, foam_col, clamp(foam, 0.0, 1.0) * 0.9);
	ROUGHNESS = mix(mix(0.045, 0.16, w), 0.45, clamp(foam, 0.0, 1.0));
	METALLIC = 0.0;

	vec3 nv = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	NORMAL = nv;
	float cosv = clamp(dot(normalize(VIEW), nv), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cosv, 5.0);          // Schlick, the honest fresnel of water
	SPECULAR = mix(0.45, 1.0, clamp(fres + 0.25 * w, 0.0, 1.0));

	// the sky and haze mirrored at low angles (the fallback where screen-space reflections are missing, e.g. a phone)
	vec3 sky = g_water.rgb * (0.45 + 0.75 * g_water.a) + vec3(0.02, 0.025, 0.03);
	vec3 emit = sky * fres * 0.85 * detail;
	// a firework burst over the lake glints on the ripples
	float sparkle = 0.25 + 0.75 * smoothstep(0.55, 0.95, vn(wp.xz * 3.5 + g_time * 0.6));
	emit += g_fire.rgb * clamp(g_fire.a, 0.0, 1.0) * (0.05 + 0.40 * fres) * sparkle * 0.25;
	// foam does not mirror the sky
	emit *= 1.0 - clamp(foam, 0.0, 1.0) * 0.7;
	EMISSION = emit;
}
