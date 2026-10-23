// Drifting patches of cloud shadow on the land. The pattern comes from the same coverage function and
// drift as the sky's clouds (cloud_coverage.gdshaderinc), projected down along the sun, so a shadow on
// the ground lines up with its cloud. Partly cloudy days get strong moving patches; full overcast has none.
#include "cloud_coverage.gdshaderinc"

global uniform vec4 g_cloud;   // x cover, y,z drift (m/s), w time
global uniform vec4 g_csun;    // x,z shadow offset from the sun (metres), w unused
global uniform vec4 g_fx;      // graphics switches: x cloud shadows, y tree colour variety
global uniform vec4 g_dsA;     // drone shadow: x, z of its centre on the ground, drone heading, arm offset
global uniform vec4 g_dsB;     // silhouette strength, blob strength, blob width, blob stretch along the light
global uniform vec4 g_dsC;     // direction the shadow is cast (x, z), prop radius, drone height

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
	// the cloud overhead that casts this shadow, displaced by the sun's angle
	vec2 w = wp.xz + g_csun.xy;
	float shape = cloud_shape(w, g_cloud.yz, g_cloud.w, 3);
	float lo = 1.0 - g_cloud.x;
	float cov = clamp((shape - lo) / max(g_cloud.x, 1e-3), 0.0, 1.0);
	float flat_out = 1.0 - smoothstep(0.55, 0.95, g_cloud.x);   // overcast has no hard patches
	return 1.0 - 0.5 * cov * flat_out * smoothstep(0.05, 0.3, g_cloud.x);
}

float world_shade(vec3 wp) { return cloud_shade(wp) * drone_shadow(wp); }
