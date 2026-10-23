// Firework sparks (driven by game/fireworks.gd). One GPU emitter per burst type. Every burst restarts its emitter
// and sets the shell's colours, size and a random seed, so no two bursts look the same.
// The burst shapes are made in start(): a sphere (peony), a sphere with long streaks (chrysanthemum), a drooping
// sphere (willow), nine arms (palm), a ring, a heart outline, a cloud of tiny flickering sparks (crackle), the
// rising launch trail, and the big white and gold finale shell.
// In process() the stars fall with gravity and air drag, cool from white hot to their colour to dim orange, and
// settle into a transform that the draw shader stretches along their motion (see firework_spark_draw.gdshader).
shader_type particles;

uniform int mode = 0;                 // 0 peony, 1 chrysanthemum, 2 willow, 3 palm, 4 ring, 5 heart, 6 crackle, 7 trail, 8 finale
uniform vec3 col_a = vec3(1.0, 0.12, 0.03);
uniform vec3 col_b = vec3(1.0, 0.55, 0.10);
uniform vec3 col_c = vec3(1.0, 0.42, 0.10);   // burn-out ember colour
uniform vec3 plane_n = vec3(1.0, 0.0, 0.0);   // ring and heart face this way (toward the park)
uniform float speed = 30.0;           // star speed at the burst, m/s
uniform float radius = 1.0;           // burst size, 1 = normal
uniform float seed_off = 0.0;         // random per burst

uint hash_u(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return n;
}

float h(uint n) {
	return float(hash_u(n) & 0x7fffffffu) / 2147483647.0;
}

vec3 unit_dir(float a, float b) {
	float z = 2.0 * a - 1.0;
	float r = sqrt(max(0.0, 1.0 - z * z));
	float phi = b * 6.2831853;
	return vec3(r * cos(phi), z, r * sin(phi));
}

// two axes in the plane whose normal is n
void plane_axes(vec3 n, out vec3 t1, out vec3 t2) {
	vec3 helper = abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	t1 = normalize(cross(n, helper));
	t2 = cross(n, t1);
}

void start() {
	uint s = hash_u(NUMBER * 747796405u + RANDOM_SEED * 2891336453u + uint(seed_off) * 26699u + 17u);
	float r1 = h(s + 1u), r2 = h(s + 2u), r3 = h(s + 3u), r4 = h(s + 4u);
	float r5 = h(s + 5u), r6 = h(s + 6u), r7 = h(s + 7u), r8 = h(s + 8u);
	vec3 origin = EMISSION_TRANSFORM[3].xyz;
	vec3 p = origin;
	vec3 v = vec3(0.0);
	float sz = mix(0.18, 0.34, r6) * mix(0.85, 1.3, radius);

	if (mode == 0 || mode == 1) {
		// sphere of stars, thrown out from the middle
		vec3 d = unit_dir(r4, r5);
		v = d * speed * mix(0.80, 1.12, r6);
		p = origin + d * mix(0.4, 2.5, r7);
	} else if (mode == 2) {
		// willow: a ball with a lift, the stars then droop
		vec3 d = normalize(unit_dir(r4, r5) + vec3(0.0, 0.55, 0.0));
		v = d * speed * mix(0.65, 1.0, r6);
		p = origin + d * mix(0.4, 3.5, r7);
	} else if (mode == 3) {
		// palm: nine thick arms of stars
		float arm = floor(r4 * 9.0);
		float z = 1.0 - 2.0 * (arm + 0.5) / 9.0;
		float rr = sqrt(max(0.0, 1.0 - z * z));
		float phi = arm * 2.399963;
		vec3 base = vec3(rr * cos(phi), z, rr * sin(phi));
		vec3 jit = (vec3(r5, r2, r7) * 2.0 - 1.0) * 0.10;
		vec3 d = normalize(base + jit);
		v = d * speed * mix(0.78, 1.05, r6);
		p = origin + d * 2.0;
	} else if (mode == 4) {
		// ring: a flat circle of stars, facing the park
		vec3 t1, t2;
		plane_axes(normalize(plane_n), t1, t2);
		float a = r4 * 6.2831853;
		vec3 d = t1 * cos(a) + t2 * sin(a);
		p = origin + d * (24.0 * radius + mix(-1.2, 1.2, r7));
		v = d * speed * mix(0.86, 1.04, r6);
	} else if (mode == 5) {
		// heart: stars on a heart outline, moving outward from the middle
		vec3 t1, t2;
		plane_axes(normalize(plane_n), t1, t2);
		float t = r4 * 6.2831853;
		float hx = 16.0 * pow(sin(t), 3.0);
		float hy = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t);
		vec2 hp = vec2(hx, hy) / 17.0 * 30.0 * radius;
		p = origin + t1 * hp.x + t2 * hp.y + normalize(plane_n) * mix(-0.8, 0.8, r7);
		vec3 d = normalize(t1 * hp.x + t2 * hp.y + normalize(plane_n) * 0.2 * (r6 - 0.5));
		v = d * speed * mix(0.55, 0.85, r6);
	} else if (mode == 6) {
		// crackle: a cloud of tiny fast flashing sparks
		vec3 d = unit_dir(r4, r5);
		p = origin + d * (16.0 * radius * r7);
		v = d * speed * mix(0.35, 1.0, r6);
	} else if (mode == 7) {
		// launch trail: sparks left where the shell was, so the shell draws its own rising line
		p = origin + (vec3(r4, r5, r6) * 2.0 - 1.0) * 0.05;
		v = vec3((r4 - 0.5) * 0.5, -0.3 - 0.5 * r7, (r5 - 0.5) * 0.5);
	} else if (mode == 9) {
		// lift sparks: a short gold shower thrown up out of the mortar with the shell
		float a = r4 * 6.2831853;
		vec3 d = normalize(vec3(cos(a) * (0.15 + 0.45 * r5), 1.0, sin(a) * (0.15 + 0.45 * r5)));
		v = d * speed * mix(0.45, 0.9, r6);
		p = origin + vec3(0.0, 0.3, 0.0) + vec3((r7 - 0.5) * 0.3, 0.0, (r8 - 0.5) * 0.3);
	} else if (mode == 10) {
		// crossette: stars that split; here they are a sphere that gives each star a hard outward kick at mid life
		vec3 d = unit_dir(r4, r5);
		v = d * speed * mix(0.75, 0.95, r6);
		p = origin + d * mix(0.4, 2.2, r7);
	} else if (mode == 11) {
		// fish: small stars that swim sideways as they fall
		vec3 d = unit_dir(r4, r5);
		v = d * speed * mix(0.55, 0.95, r6);
		p = origin + d * mix(0.5, 2.0, r7);
	} else if (mode == 12) {
		// strobe: a wide sphere of stars that blink together and separately
		vec3 d = unit_dir(r4, r5);
		v = d * speed * mix(0.7, 0.95, r6);
		p = origin + d * mix(0.5, 3.0, r7);
	} else if (mode == 13) {
		// horsetail: a dense, low, gold spray that droops straight down
		vec3 d = normalize(unit_dir(r4, r5) + vec3(0.0, 0.35, 0.0));
		v = d * speed * mix(0.45, 0.8, r6);
		p = origin + d * mix(0.4, 2.5, r7);
	} else {
		// finale: a big dense shell
		vec3 d = unit_dir(r4, r5);
		v = d * speed * mix(0.92, 1.15, r6);
		p = origin + d * mix(0.8, 4.0, r7);
	}

	CUSTOM = vec4(r2, 0.0, r3, sz);
	VELOCITY = v;
	COLOR = vec4(col_a, 1.0);
	TRANSFORM = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 1.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	vec3 p = TRANSFORM[3].xyz;

	float drag_k = 0.7;
	float grav = 2.6;
	if (mode == 1) { drag_k = 0.6; grav = 2.0; }
	else if (mode == 2) { drag_k = 1.4; grav = 3.7; }
	else if (mode == 3) { drag_k = 0.5; grav = 1.9; }
	else if (mode == 6) { drag_k = 1.2; grav = 3.2; }
	else if (mode == 7) { drag_k = 3.5; grav = 0.3; }
	else if (mode == 8) { drag_k = 0.6; grav = 2.2; }
	else if (mode == 9) { drag_k = 1.8; grav = 5.0; }
	else if (mode == 10) { drag_k = 0.6; grav = 2.2; }
	else if (mode == 11) { drag_k = 0.9; grav = 2.4; }
	else if (mode == 12) { drag_k = 0.5; grav = 1.4; }
	else if (mode == 13) { drag_k = 0.8; grav = 3.4; }

	// crossette: a hard outward kick at mid life reads as the star splitting in four
	if (mode == 10 && CUSTOM.x < 0.5 && age > 0.48) {
		CUSTOM.x = 1.0;
		VELOCITY *= 1.85;
	}
	// fish: a sideways swim on top of the fall
	if (mode == 11) {
		vec3 sv = cross(normalize(VELOCITY + vec3(0.0, 0.01, 0.0)), vec3(0.0, 1.0, 0.0));
		VELOCITY += normalize(sv + vec3(1e-4, 0.0, 0.0)) * sin(TIME * 6.0 + CUSTOM.z * 50.0) * 2.6 * DELTA;
	}

	VELOCITY.y -= grav * DELTA;
	VELOCITY *= exp(-drag_k * DELTA);

	vec3 vdir = length(VELOCITY) > 0.05 ? normalize(VELOCITY) : vec3(0.0, 1.0, 0.0);
	vec3 up0 = abs(vdir.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 xa = normalize(cross(up0, vdir));
	vec3 ya = cross(vdir, xa);

	float sz = CUSTOM.w * mix(1.0, 0.45, age);
	// cooling: white hot, then the shell colour, then the second colour and a dull ember
	vec3 base = mix(col_a, col_b, smoothstep(0.0, 0.35, age));
	vec3 c = mix(vec3(2.6, 2.3, 1.9), base * 1.7, smoothstep(0.0, 0.07, age));
	c = mix(c, col_c * 1.2, smoothstep(0.50, 0.90, age));
	c = mix(c, vec3(0.50, 0.14, 0.03), smoothstep(0.90, 1.0, age));
	float a = smoothstep(0.0, 0.02, age) * pow(max(1.0 - age, 0.0), 1.4);
	if (mode == 7 || mode == 9) {
		c = mix(vec3(2.4, 1.7, 0.7), vec3(1.0, 0.45, 0.10), age);
		a = (1.0 - age) * (1.0 - age);
		sz *= 0.8;
	} else if (mode == 6) {
		// crackle: the tiny sparks blink on and off
		float fl = 0.5 + 0.5 * sin(TIME * 57.0 + CUSTOM.z * 61.0);
		c *= 0.25 + 0.75 * step(0.35, fl);
		a *= mix(0.45, 1.0, step(0.3, fl));
	} else if (mode == 12) {
		// strobe: a slower, bigger blink, some stars in phase and some out
		float on = step(0.30, fract(TIME * 2.4 + CUSTOM.z * 7.0));
		c = mix(vec3(1.0, 0.97, 0.9) * 2.0, col_a * 1.4, age);
		c *= 0.12 + 0.88 * on;
		a *= 0.10 + 0.90 * on;
	} else if (mode == 10) {
		// a white flash at the split
		c = mix(c, vec3(2.2, 2.2, 2.0), (age > 0.48 && age < 0.54) ? 0.8 : 0.0);
	}
	c *= 0.9 + 0.1 * sin(TIME * 31.0 + CUSTOM.z * 47.0);
	COLOR = vec4(c, a);
	TRANSFORM = mat4(vec4(xa * sz, 0.0), vec4(ya * sz, 0.0), vec4(vdir, 0.0), vec4(p, 1.0));
}
