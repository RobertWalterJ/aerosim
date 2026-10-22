// Atmospheric particles that make the air feel alive (driven by game/ambient_particles.gd).
//   mode 0  autumn leaves drifting on the wind around the camera; they flutter, tumble and settle on the ground
//   mode 1  dust and pollen motes (and the odd seed or insect) in a small box around the camera
//   mode 2  leaves flung out of the litter by the drone's rotor wash
//   mode 3  dust (or powder snow) blown out in a ring under the drone
// Modes 0 and 1 wrap around the camera, so the field stays full however fast the drone flies.
// Everything reads the same wind and the same rotor wash, and lands on the real ground (the terrain height map).
shader_type particles;
render_mode disable_force;

uniform int mode = 0;
uniform vec3 center;                                  // camera (modes 0, 1) or the ground under the drone (2, 3)
uniform vec3 box = vec3(18.0, 14.0, 18.0);            // half extents in x and z; y = top height above ground (0) or half height (1)
uniform vec3 wind = vec3(0.0);                        // m/s about 6 m above the ground
uniform float gust = 0.45;
uniform float wet = 0.0;                              // wet leaves fall straighter and faster
uniform vec4 drone = vec4(0.0, -1000.0, 0.0, 2.0);    // xyz position, w = wash radius on the ground
uniform float wash = 0.0;                             // 0..1
uniform float wash_speed = 4.0;                       // m/s outflow at full wash for this airframe
uniform vec2 size_range = vec2(0.04, 0.07);
uniform vec4 tint = vec4(1.0);                        // dust colour and opacity (mode 3)
uniform sampler2D height_tex : filter_nearest, repeat_disable;

float hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / 2147483647.0;
}

// the terrain height (bilinear, the same as Terrain.height)
float ground(vec2 xz) {
	vec2 f = clamp((xz + 2000.0) / 4000.0 * 2048.0, vec2(0.0), vec2(2047.999));
	ivec2 i = ivec2(f);
	vec2 t = f - vec2(i);
	float a = texelFetch(height_tex, i, 0).r;
	float b = texelFetch(height_tex, i + ivec2(1, 0), 0).r;
	float c = texelFetch(height_tex, i + ivec2(0, 1), 0).r;
	float d = texelFetch(height_tex, i + ivec2(1, 1), 0).r;
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

// autumn maples and oaks: orange, scarlet, gold, crimson, brown, and a few still half green
vec3 leaf_colour(float r, float v) {
	vec3 c;
	if (r < 0.26) c = vec3(0.86, 0.36, 0.06);
	else if (r < 0.46) c = vec3(0.74, 0.13, 0.05);
	else if (r < 0.66) c = vec3(0.90, 0.62, 0.10);
	else if (r < 0.78) c = vec3(0.55, 0.08, 0.07);
	else if (r < 0.92) c = vec3(0.46, 0.26, 0.10);
	else c = vec3(0.62, 0.58, 0.16);
	c *= mix(0.75, 1.1, v);
	return pow(c, vec3(2.2));       // to linear
}

mat3 rot(vec3 a, float ang) {
	float c = cos(ang), s = sin(ang), k = 1.0 - c;
	return mat3(vec3(c + a.x * a.x * k, a.y * a.x * k + a.z * s, a.z * a.x * k - a.y * s),
				vec3(a.x * a.y * k - a.z * s, c + a.y * a.y * k, a.z * a.y * k + a.x * s),
				vec3(a.x * a.z * k + a.y * s, a.y * a.z * k - a.x * s, c + a.z * a.z * k));
}

void start() {
	uint s = NUMBER * 747796405u + RANDOM_SEED * 2891336453u + 17u;
	float r1 = hash(s), r2 = hash(s + 1u), r3 = hash(s + 2u), r4 = hash(s + 3u);
	float r5 = hash(s + 4u), r6 = hash(s + 5u), r7 = hash(s + 6u), r8 = hash(s + 7u);
	// CUSTOM: x spin angle, y age 0..1, z this particle's own random number, w size (negative once a leaf has landed)
	CUSTOM = vec4(r1 * 6.2832, 0.0, r2, mix(size_range.x, size_range.y, r3));
	vec3 p;
	if (mode == 0) {
		p.xz = center.xz + (vec2(r4, r5) * 2.0 - 1.0) * box.xz;
		p.y = ground(p.xz) + 0.4 + r6 * box.y;
		VELOCITY = wind * 0.7 + vec3(0.0, -1.0, 0.0);
		COLOR = vec4(leaf_colour(r7, r8), 1.0);
	} else if (mode == 1) {
		p = center + (vec3(r4, r6, r5) * 2.0 - 1.0) * box;
		VELOCITY = wind * 0.5;
		COLOR = vec4(1.0, 1.0, 1.0, 0.0);
		if (r2 < 0.07) CUSTOM.w *= 3.5;       // a seed or a small insect
	} else {
		float a = r4 * 6.2832;
		float rr = sqrt(r5) * drone.w * 0.85;
		vec2 dir = vec2(cos(a), sin(a));
		p.xz = center.xz + dir * rr;
		p.y = ground(p.xz) + 0.03;
		float out_v = wash_speed * wash * mix(0.5, 1.2, r6) * (0.5 + 0.7 * rr / max(drone.w, 0.1));
		VELOCITY = vec3(dir.x * out_v, wash_speed * wash * mix(0.2, 0.7, r7), dir.y * out_v);
		COLOR = mode == 2 ? vec4(leaf_colour(r7, r8), 1.0) : vec4(tint.rgb, 0.0);
	}
	TRANSFORM = mat4(vec4(0.001, 0.0, 0.0, 0.0), vec4(0.0, 0.001, 0.0, 0.0), vec4(0.0, 0.0, 0.001, 0.0), vec4(p, 1.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) ACTIVE = false;
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	float sd = CUSTOM.z;
	uint s = uint(sd * 16777215.0);
	vec3 p = TRANSFORM[3].xyz;
	bool leaf = mode == 0 || mode == 2;

	// wrap around the camera: whatever drifts out of one side comes back in at the other
	if (mode <= 1) {
		vec3 rel = p - center;
		vec2 jump = vec2(0.0);
		if (abs(rel.x) > box.x) jump.x = -sign(rel.x) * 2.0 * box.x;
		if (abs(rel.z) > box.z) jump.y = -sign(rel.z) * 2.0 * box.z;
		if (jump != vec2(0.0)) {
			float h_old = ground(p.xz);
			p.xz += jump;
			if (mode == 0) p.y = ground(p.xz) + (p.y - h_old);
		}
		if (mode == 1 && abs(rel.y) > box.y) p.y -= sign(rel.y) * 2.0 * box.y;
	}
	float gy = ground(p.xz);
	float hag = max(p.y - gy, 0.05);
	float ph = sd * 40.0;
	// gusts: a slow swell drifting over the land, plus a quicker wobble of each particle's own
	float g = 1.0 + gust * (0.6 * sin(TIME * 0.7 + p.x * 0.05 + p.z * 0.04) + 0.3 * sin(TIME * 2.3 + ph));
	float prof = clamp(log(hag / 0.05) / log(6.0 / 0.05), 0.15, 1.35);    // log wind profile, 1 at 6 m
	vec3 air = wind * prof * g;

	// rotor wash: air driven down under the drone, then out along the ground in a ring
	vec3 wv = vec3(0.0);
	vec3 dd = p - drone.xyz;
	float rh = length(dd.xz);
	if (wash > 0.001 && dd.y < 0.6 && rh < drone.w * 2.6) {
		float fo = 1.0 - smoothstep(drone.w * 0.5, drone.w * 2.6, rh);
		vec2 od = rh > 0.01 ? dd.xz / rh : vec2(1.0, 0.0);
		float near_g = 1.0 - smoothstep(0.0, 1.5, hag);
		// the ground vortex: where the outflow meets still air, about one to two wash radii out, it rolls up and lifts
		float ring = smoothstep(drone.w * 0.6, drone.w * 1.1, rh) * (1.0 - smoothstep(drone.w * 1.6, drone.w * 2.4, rh));
		wv = vec3(od.x, mix(-0.7, 0.45, near_g) + 0.9 * ring * (1.0 - smoothstep(0.5, 2.0, hag)), od.y) * wash * wash_speed * fo;
	}

	vec3 target;
	float drag;
	if (leaf) {
		// falling-paper flutter: a side-to-side swing on top of a slow fall; a wet leaf falls straight and fast
		float fall = mix(mix(0.8, 1.4, hash(s + 11u)), 2.4, wet);
		float amp = mix(0.75, 0.15, wet) * mix(0.6, 1.2, hash(s + 12u));
		float w = mix(2.0, 4.2, hash(s + 13u));
		float a = hash(s + 14u) * 6.2832;
		float sw = sin(TIME * w + ph);
		target = air + wv + vec3(cos(a) * sw * amp, -fall * (1.0 - 0.4 * abs(sw)), sin(a) * sw * amp);
		drag = mode == 0 ? 2.2 : 1.3;
	} else if (mode == 1) {
		float big = step(sd, 0.07);
		vec3 wander = vec3(sin(TIME * 0.9 + ph), 0.5 * sin(TIME * 0.6 + ph * 1.3), cos(TIME * 0.8 + ph * 0.7)) * mix(0.08, 0.45, big);
		target = air * 0.8 + wv + wander + vec3(0.0, 0.02, 0.0);
		drag = 3.0;
	} else {
		target = air + wv + vec3(0.0, 0.12, 0.0);
		drag = 1.6;
	}

	bool landed = CUSTOM.w < 0.0;
	if (leaf && landed) {
		// a leaf on the ground stays put unless the rotor wash or a strong gust picks it up again
		if (length(wv) > 1.2 || length(air) * (0.5 + 0.5 * hash(s + 21u)) > 6.5) {
			CUSTOM.w = -CUSTOM.w;
			VELOCITY = wv * 0.8 + vec3(0.0, 0.8 + length(wv) * 0.25, 0.0);
			landed = false;
		} else {
			VELOCITY = vec3(0.0);
		}
	} else {
		VELOCITY = mix(VELOCITY, target, 1.0 - exp(-drag * DELTA));
	}
	// the ground
	if (leaf && !landed && p.y + VELOCITY.y * DELTA < gy + 0.015 && age > 0.02) {
		p.y = gy + 0.015;
		VELOCITY = vec3(0.0);
		CUSTOM.w = -abs(CUSTOM.w);
		landed = true;
		// a drifting leaf that lands joins the litter soon (it is recycled into the air); a kicked-up one lies a while
		CUSTOM.y = max(CUSTOM.y, mode == 0 ? 0.84 : 0.55);
	} else if (mode == 3 && p.y + VELOCITY.y * DELTA < gy + 0.05) {
		p.y = gy + 0.05;
		VELOCITY.y = max(VELOCITY.y, 0.0);
	}

	float sz = abs(CUSTOM.w);
	mat3 b = mat3(1.0);
	if (leaf) {
		float yaw = CUSTOM.x;
		if (landed) {
			b = rot(vec3(0.0, 1.0, 0.0), yaw);
		} else {
			float spin = mix(2.0, 7.0, hash(s + 15u)) * (1.0 - 0.6 * wet) * (0.6 + 0.4 * min(length(VELOCITY) / 3.0, 2.0));
			CUSTOM.x += spin * DELTA;
			vec3 ax = normalize(vec3(hash(s + 16u), hash(s + 17u), hash(s + 18u)) * 2.0 - 1.0 + vec3(0.0, 0.001, 0.0));
			b = rot(ax, CUSTOM.x);
		}
		sz *= smoothstep(0.0, 0.03, age) * (1.0 - smoothstep(0.86, 1.0, age));
	} else if (mode == 1) {
		float tw = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(TIME * mix(3.0, 9.0, hash(s + 19u)) + ph), 3.0);
		COLOR.a = smoothstep(0.0, 0.15, age) * (1.0 - smoothstep(0.8, 1.0, age)) * tw;
	} else {
		sz *= mix(0.35, 1.7, sqrt(age));
		COLOR.a = tint.a * pow(1.0 - age, 1.5) * smoothstep(0.0, 0.08, age);
	}
	TRANSFORM = mat4(vec4(b[0] * sz, 0.0), vec4(b[1] * sz, 0.0), vec4(b[2] * sz, 0.0), vec4(p, 1.0));
}
