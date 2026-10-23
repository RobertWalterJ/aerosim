// Shared cloud coverage: the exact noise and coverage map the volumetric sky clouds and the ground cloud
// shadows both sample, so a shadow on the land lines up with the cloud overhead. Pure GLSL with no
// uniforms; callers pass the world xz, the drift (world metres per second), the time and the octave count.
// Included by game/shaders/sky.gdshader and game/shaders/cloud_shadow.gdshaderinc.
float cc_hash(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float cc_noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cc_hash(i), cc_hash(i + vec3(1, 0, 0)), f.x), mix(cc_hash(i + vec3(0, 1, 0)), cc_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(cc_hash(i + vec3(0, 0, 1)), cc_hash(i + vec3(1, 0, 1)), f.x), mix(cc_hash(i + vec3(0, 1, 1)), cc_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
// fbm normalised by the full five-octave amplitude, so fewer octaves stay in the same 0..1 range
// and a low-detail shadow still lines up with the fuller sky cloud.
float cc_fbm(vec3 p, int oct) {
	float s = 0.0; float a = 0.5;
	for (int i = 0; i < 5; i++) {
		if (i >= oct) break;
		s += a * cc_noise(p);
		p = p * 2.07 + vec3(11.3, 5.7, 3.1); a *= 0.5;
	}
	return s / 0.96875;
}
// raw coverage shape (0..1) of the cloud field at world xz, drifting and morphing slowly.
float cloud_shape(vec2 w, vec2 drift_m, float t, int oct) {
	vec3 q = vec3((w - drift_m * t) * (1.0 / 950.0), t * 0.002);
	return cc_fbm(q, oct) * 0.72 + cc_fbm(q * 3.1 + 7.0, oct) * 0.28;
}
