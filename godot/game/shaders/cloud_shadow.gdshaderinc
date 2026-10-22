// Drifting patches of cloud shadow on the land. Partly cloudy days get moving light and dark patches;
// full overcast has no patches at all (the light is already soft), so the effect fades out there.
global uniform vec4 g_cloud;   // x cover, y,z drift (m/s), w time
global uniform vec4 g_fx;      // graphics switches: x cloud shadows, y tree colour variety
float cs_hash(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float cs_noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(cs_hash(i), cs_hash(i + vec2(1, 0)), f.x), mix(cs_hash(i + vec2(0, 1)), cs_hash(i + vec2(1, 1)), f.x), f.y); }
float cloud_shade(vec3 wp) {
	if (g_fx.x < 0.5) return 1.0;
	vec2 q = (wp.xz - g_cloud.yz * g_cloud.w) * 0.0028;
	float n = cs_noise(q) * 0.6 + cs_noise(q * 2.3 + 5.0) * 0.3 + cs_noise(q * 5.1 + 9.0) * 0.1;
	float thr = mix(0.78, 0.30, g_cloud.x);
	float patch = smoothstep(thr, thr + 0.12, n);
	float flat_out = 1.0 - smoothstep(0.55, 0.95, g_cloud.x);
	return 1.0 - 0.5 * patch * flat_out * smoothstep(0.05, 0.3, g_cloud.x);
}
