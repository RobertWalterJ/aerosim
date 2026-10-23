// Firework smoke (driven by game/fireworks.gd): a puff of grey powder smoke from each burst that drifts downwind,
// grows and thins out. The burst light and the colour of the next burst (global g_fire) light it up, which is
// what makes the smoke glow from inside during a show.
shader_type particles;

global uniform vec3 g_wind;

uniform float seed_off = 0.0;
uniform float size_from = 6.0;
uniform float size_to = 42.0;

uint hash_u(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return n;
}

float h(uint n) {
	return float(hash_u(n) & 0x7fffffffu) / 2147483647.0;
}

void start() {
	uint s = hash_u(NUMBER * 747796405u + RANDOM_SEED * 2891336453u + uint(seed_off) * 26699u + 17u);
	float r1 = h(s + 1u), r2 = h(s + 2u), r3 = h(s + 3u), r4 = h(s + 4u);
	vec3 origin = EMISSION_TRANSFORM[3].xyz;
	float z = 2.0 * r1 - 1.0;
	float rr = sqrt(max(0.0, 1.0 - z * z));
	float phi = r2 * 6.2831853;
	vec3 d = vec3(rr * cos(phi), z, rr * sin(phi));
	vec3 p = origin + d * mix(1.5, 10.0, r3);
	VELOCITY = vec3(g_wind.x * 1.4, 0.3 + 0.7 * r4, g_wind.z * 1.4);
	CUSTOM = vec4(r4, 0.0, r3, 0.0);
	COLOR = vec4(1.0);
	TRANSFORM = mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(p, 1.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	if (CUSTOM.y >= 1.0) {
		ACTIVE = false;
	}
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	vec3 p = TRANSFORM[3].xyz;
	// the smoke is carried by the wind high above the valley; it eases into the flow
	vec3 want = vec3(g_wind.x * 1.7, 0.35, g_wind.z * 1.7);
	VELOCITY = mix(VELOCITY, want, 1.0 - exp(-0.30 * DELTA));
	float sz = mix(size_from, size_to, pow(age, 0.6)) * mix(0.7, 1.3, CUSTOM.z);
	COLOR = vec4(1.0, 1.0, 1.0, smoothstep(0.0, 0.05, age) * pow(1.0 - age, 1.1));
	TRANSFORM = mat4(vec4(sz, 0.0, 0.0, 0.0), vec4(0.0, sz, 0.0, 0.0), vec4(0.0, 0.0, sz, 0.0), vec4(p, 1.0));
}
