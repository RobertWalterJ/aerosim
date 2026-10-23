// The funnel body as thousands of condensing wisps (SPEC-VORTEX-LOOK, session B). Each particle follows a spiral path
// down and inward from the cloud base: it starts high on the funnel, descends while spinning faster as the funnel
// narrows, and fades as it reaches the ground. The funnel profile changes with `stage`: 0 cone, 1 wedge, 2 rope.
// The particles live in world space, so one emitter can sit under a moving funnel.
shader_type particles;

uniform int mode = 0;              // 0 wisps, 1 droplets
uniform vec3 centre = vec3(0.0);
uniform float height = 500.0;
uniform float base_radius = 25.0;
uniform float top_ratio = 2.0;
uniform float stage = 0.0;         // 0 cone, 1 wedge, 2 rope
uniform float strength = 1.0;
uniform float spin = 1.15;
uniform float seed_off = 0.0;

uint hash_u(uint n) { n = (n << 13u) ^ n; n = n * (n * n * 15731u + 789221u) + 1376312589u; return n; }
float h1(uint n) { return float(hash_u(n) & 0x7fffffffu) / 2147483647.0; }

void start() {
	uint s = hash_u(NUMBER * 747796405u + RANDOM_SEED * 2891336453u + uint(seed_off) * 26699u + 173u);
	float r1 = h1(s + 1u), r2 = h1(s + 2u), r3 = h1(s + 3u), r4 = h1(s + 4u), r5 = h1(s + 5u);
	// wisps begin high in the cloud base and stream down; droplets can begin anywhere in the column
	float t0 = (mode == 1) ? mix(0.35, 1.0, r1) : ((mode == 2) ? mix(0.0, 0.95, r1) : mix(0.55, 1.0, r1));
	float a0 = r2 * 6.2831853;
	float rad = (mode == 2) ? mix(0.15, 0.75, r3 * r3) : mix(0.80, 2.6, r3 * r3);            // outside the core there are loose strands
	float sz = (mode == 0) ? (0.9 + 3.2 * r4) : ((mode == 2) ? (2.2 + 4.5 * r4) : (0.30 + 1.2 * r4));
	CUSTOM = vec4(t0, 0.0, a0, rad);
	COLOR = vec4(sz, 0.0, 0.0, 1.0);
	TRANSFORM = mat4(vec4(sz, 0.0, 0.0, 0.0), vec4(0.0, sz, 0.0, 0.0), vec4(0.0, 0.0, sz, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) { ACTIVE = false; }
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	// the particle falls from its starting height to the ground, slowing as it reaches the bottom
	float t = mix(CUSTOM.x, 0.0, pow(age, 0.65));
	// the funnel profile: cone widens upward, wedge is nearly a cylinder, rope is thin and bent
	float profile;
	float top_ratio_now = top_ratio;
	if (stage < 0.5) {
		profile = mix(1.0, top_ratio_now, smoothstep(0.0, 1.0, t));
	} else if (stage < 1.5) {
		profile = mix(1.0, 1.15, t);
	} else {
		profile = mix(1.0, 0.55, t) * mix(1.0, 0.45, age);      // the rope thins as it dies
	}
	// the axis wobbles and, in the rope stage, bends into an S
	vec3 axis = vec3(0.0);
	axis.y += t * height;
	float bow = sin(t * 3.1 + seed_off) * base_radius * 0.16;
	if (stage > 1.5) {
		bow += sin(t * 4.2 + TIME * 0.35 + seed_off) * base_radius * 0.55;
	}
	axis.x += bow;
	axis.z += cos(t * 2.3 + seed_off) * base_radius * 0.11;
	// angular speed rises toward the ground (smaller radius, faster air)
	float ang = CUSTOM.z + TIME * spin * (0.55 + 1.45 * (1.0 - t)) + age * ((mode == 0) ? 1.4 : 2.2);
	float rr = base_radius * profile * CUSTOM.w * 1.15;
	if (mode == 2) { rr *= 0.62; }
	// a little outward turbulence on the wisps so the edge is ragged
	float jitter = 1.0 + 0.22 * sin(age * 9.0 + CUSTOM.z * 3.0 + seed_off);
	rr *= jitter;
	vec3 p = axis + vec3(cos(ang) * rr, 0.0, sin(ang) * rr);
	p.y += sin(ang * 1.7 + age * 6.0) * 3.0 * rr / max(base_radius, 1.0);
	float sz = COLOR.r * (1.0 + 1.8 * age);
	float fade = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.62, 1.0, age));
	float alpha = fade * strength * ((mode == 0) ? 0.42 : ((mode == 2) ? 0.32 : 0.90));
	COLOR = vec4(COLOR.r, 0.0, 0.0, alpha);
	TRANSFORM = mat4(vec4(sz, 0.0, 0.0, 0.0), vec4(0.0, sz, 0.0, 0.0), vec4(0.0, 0.0, sz, 0.0), vec4(p, 1.0));
}
