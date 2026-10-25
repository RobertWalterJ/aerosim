// Funnel and weather particles (driven by game/weather_events.gd): spray and mist at a waterspout foot, the dust skirt
// and orbiting debris of a tornado, dust motes in a thermal, and the rain of a storm shaft. One process shader, a mode
// uniform and a single draw pass.
shader_type particles;

uniform int mode = 0;            // 0 spray ring, 1 dust skirt, 2 orbiting debris, 3 thermal motes, 4 rain shaft
uniform vec3 centre = vec3(0.0);
uniform float radius = 20.0;     // base radius for the rings and the rain cylinder
uniform float height = 300.0;
uniform float strength = 1.0;
uniform float seed_off = 0.0;

uint hash_u(uint n) { n = (n << 13u) ^ n; n = n * (n * n * 15731u + 789221u) + 1376312589u; return n; }
float h(uint n) { return float(hash_u(n) & 0x7fffffffu) / 2147483647.0; }
vec3 unit_dir(float a, float b) {
	float z = 2.0 * a - 1.0;
	float r = sqrt(max(0.0, 1.0 - z * z));
	float phi = b * 6.2831853;
	return vec3(r * cos(phi), z, r * sin(phi));
}

void start() {
	uint s = hash_u(NUMBER * 747796405u + RANDOM_SEED * 2891336453u + uint(seed_off) * 26699u + 17u);
	float r1 = h(s + 1u), r2 = h(s + 2u), r3 = h(s + 3u), r4 = h(s + 4u), r5 = h(s + 5u), r6 = h(s + 6u);
	vec3 p = centre;
	vec3 v = vec3(0.0);
	float size = 0.6;
	if (mode == 0) {
		// waterspout spray ring: water thrown outward and up at the foot
		float a = r1 * 6.2831853;
		float rr = radius * (0.55 + 0.55 * r2);
		p += vec3(cos(a) * rr, 0.4 + 2.0 * r3, sin(a) * rr);
		v = vec3(cos(a), 0.0, sin(a)) * (3.0 + 5.0 * r4) + vec3(0.0, 5.0 + 7.0 * r5, 0.0);
		size = 0.9 + 2.2 * r6;
	} else if (mode == 1) {
		// tornado dust skirt: a dense ring of dust dragged outward at the ground
		float a = r1 * 6.2831853;
		float rr = radius * (1.05 + 0.8 * sqrt(r2));
		p += vec3(cos(a) * rr, 0.2 + 2.5 * r3, sin(a) * rr);
		v = vec3(cos(a), 0.0, sin(a)) * (2.5 + 4.5 * r4) + vec3(0.0, 0.8 + 2.2 * r5, 0.0);
		size = 4.0 + 9.0 * r6;
	} else if (mode == 2) {
		// orbiting debris: leaves and twigs circling the base, climbing a little
		float a = r1 * 6.2831853;
		float rr = radius * (0.9 + 0.7 * r2);
		p += vec3(cos(a) * rr, 1.0 + height * 0.12 * r3, sin(a) * rr);
		v = vec3(-sin(a), 0.0, cos(a)) * (9.0 + 8.0 * r4) + vec3(0.0, 3.0 + 6.0 * r5, 0.0);
		size = 0.5 + 1.4 * r6;
	} else if (mode == 3) {
		// thermal motes: seeds and dust rising slowly in a wide column
		vec3 d = unit_dir(r1, r2);
		float rr = sqrt(r3) * radius;
		p += vec3(d.x * rr, 1.0 + height * 0.5 * r4, d.z * rr);
		v = vec3(d.x * 0.6, 1.0 + 2.2 * r5, d.z * 0.6);
		size = 0.5 + 1.2 * r6;
	} else {
		// rain shaft: drops in a tall cylinder around the cell
		float a = r1 * 6.2831853;
		float rr = sqrt(r2) * radius;
		p += vec3(cos(a) * rr, 3.0 + height * r6, sin(a) * rr);
		v = vec3(1.5, -18.0 - 10.0 * r4, 1.0);
		size = 1.0 + 0.8 * r5;
	}
	CUSTOM = vec4(size, 0.0, r3, r4);
	VELOCITY = v;
	COLOR = vec4(1.0);
	TRANSFORM = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 1.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) { ACTIVE = false; }
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	vec3 p = TRANSFORM[3].xyz;
	if (mode == 2) {
		// orbit around the funnel axis: a tangential pull plus a little centripetal in
		vec3 axis = centre + vec3(0.0, p.y, 0.0);
		vec3 d = p - axis;
		float r = max(length(d.xz), 0.5);
		vec3 tang = vec3(-d.z, 0.0, d.x) / r;
		VELOCITY += tang * 16.0 * DELTA - d / r * 2.5 * DELTA;
		VELOCITY.y += 5.0 * DELTA;
	} else if (mode == 4) {
		VELOCITY.y -= 6.0 * DELTA;
	} else {
		VELOCITY.y -= (mode == 0 ? 4.0 : 1.2) * DELTA;
	}
	VELOCITY *= exp(-(mode == 1 ? 1.4 : 0.5) * DELTA);
	float sz = CUSTOM.x * (1.0 + 1.5 * age);
	if (mode == 4) { sz *= 0.5; }
	COLOR = vec4(1.0, 1.0, 1.0, pow(1.0 - age, 1.3) * smoothstep(0.0, 0.06, age));
	TRANSFORM = mat4(vec4(sz, 0.0, 0.0, 0.0), vec4(0.0, sz, 0.0, 0.0), vec4(0.0, 0.0, sz, 0.0), vec4(p, 1.0));
}
