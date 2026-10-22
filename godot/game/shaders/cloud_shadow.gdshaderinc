// Drifting patches of cloud shadow on the land. Partly cloudy days get moving light and dark patches;
// full overcast has no patches at all (the light is already soft), so the effect fades out there.
global uniform vec4 g_cloud;   // x cover, y,z drift (m/s), w time
global uniform vec4 g_fx;      // graphics switches: x cloud shadows, y tree colour variety
global uniform vec4 g_dsA;     // drone shadow: x, z of its centre on the ground, drone heading, arm offset
global uniform vec4 g_dsB;     // silhouette strength, blob strength, blob width, blob stretch along the light
global uniform vec4 g_dsC;     // direction the shadow is cast (x, z), prop radius, drone height
float cs_hash(vec2 p) { p = fract(p * vec2(0.1031, 0.1030)); p += dot(p, p.yx + 33.33); return fract((p.x + p.y) * p.x); }
float cs_noise(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(cs_hash(i), cs_hash(i + vec2(1, 0)), f.x), mix(cs_hash(i + vec2(0, 1)), cs_hash(i + vec2(1, 1)), f.x), f.y); }
// the drone's own shadow: a soft blob stretched along the light, and the plan view of the drone turned with it
float drone_shadow(vec3 wp) {
	if (g_dsB.x + g_dsB.y < 0.001) return 1.0;
	vec2 d = wp.xz - g_dsA.xy;
	if (dot(d, d) > 900.0) return 1.0;
	float below = 1.0 - smoothstep(g_dsC.w - 0.3, g_dsC.w + 0.6, wp.y);       // only things lower than the drone are in its shadow
	vec2 dir = g_dsC.xy;
	vec2 perp = vec2(-dir.y, dir.x);
	float bu = dot(d, dir) / (0.5 * g_dsB.z * g_dsB.w);
	float bv = dot(d, perp) / (0.5 * g_dsB.z);
	float blob = pow(1.0 - smoothstep(0.0, 1.0, sqrt(bu * bu + bv * bv)), 1.6) * g_dsB.y;
	float ch = cos(g_dsA.z); float sh = sin(g_dsA.z);
	vec2 loc = vec2(ch * d.x - sh * d.y, sh * d.x + ch * d.y) / 1.9;     // drawn 1.9 times life size so it can be seen       // the point in the drone's own axes
	float k = g_dsA.w / 0.0795;
	float body = 1.0 - smoothstep(0.85, 1.05, length(vec2(loc.x / (0.05 * k), loc.y / (0.085 * k))));
	vec2 a = abs(loc);
	vec2 m = vec2(g_dsA.w);
	float t = clamp(dot(a, m) / dot(m, m), 0.0, 1.0);
	float arm = (1.0 - smoothstep(0.006 * k, 0.012 * k, length(a - m * t))) * 0.95;
	float dm = length(a - m);
	float prop = (1.0 - smoothstep(g_dsC.z * 0.92, g_dsC.z * 1.02, dm)) * 0.30;
	float core = (1.0 - smoothstep(0.012 * k, 0.018 * k, dm)) * 0.95;
	float sil = max(max(body, arm), max(prop, core)) * g_dsB.x;
	return 1.0 - clamp(max(sil, blob), 0.0, 1.0) * below;
}

float cloud_shade(vec3 wp) {
	if (g_fx.x < 0.5) return 1.0;
	vec2 q = (wp.xz - g_cloud.yz * g_cloud.w) * 0.0028;
	float n = cs_noise(q) * 0.6 + cs_noise(q * 2.3 + 5.0) * 0.3 + cs_noise(q * 5.1 + 9.0) * 0.1;
	float thr = mix(0.78, 0.30, g_cloud.x);
	float patch = smoothstep(thr, thr + 0.12, n);
	float flat_out = 1.0 - smoothstep(0.55, 0.95, g_cloud.x);
	return 1.0 - 0.5 * patch * flat_out * smoothstep(0.05, 0.3, g_cloud.x);
}

float world_shade(vec3 wp) { return cloud_shade(wp) * drone_shadow(wp); }
