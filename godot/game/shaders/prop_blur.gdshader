// A spinning propeller as a camera actually records it. The sensor reads the picture one row at a time, so each row
// catches the blades at a slightly later angle: the blades bend into sweeping arcs, and in each row the shutter is open
// only briefly, so the blur is a short smear, not a solid disc. Frame to frame the arcs change, as in real drone video.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;          // blade angle at the start of the frame (rad)
uniform float omega = 600.0;        // shaft speed, signed (rad/s)
uniform float n_blades = 2.0;
uniform float radius = 0.064;       // m
uniform float chord = 0.011;        // m, blade width near mid-span
uniform float exposure = 0.00035;    // shutter open time (s)
uniform float readout = 0.012;      // time to read the sensor top to bottom (s)
uniform float sweep = 0.35;         // how far the blade tip trails the root (rad)
uniform vec3 body_col : source_color = vec3(0.025, 0.027, 0.03);
uniform vec3 tip_col : source_color = vec3(0.75, 0.77, 0.8);
uniform float strength = 1.0;

varying vec2 vLocal;

void vertex() { vLocal = VERTEX.xz; }

void fragment() {
	vec2 p = vLocal / radius;
	float rr = length(p);
	if (rr > 1.0 || rr < 0.1) discard;
	float th = atan(p.y, p.x);
	float t_row = (SCREEN_UV.y - 0.5) * readout;
	float hw = clamp(chord * (1.0 - 0.35 * rr) / (2.0 * rr * radius), 0.02, 0.45 * 3.14159 / n_blades);
	float seg = 6.2831853 / n_blades;
	float cov = 0.0;
	const int N = 10;
	for (int i = 0; i < N; i++) {
		float s = exposure * float(i) / float(N - 1);
		float ang = phase + omega * (t_row + s) - sweep * rr * rr * sign(omega);
		float d = mod(th - ang + 0.5 * seg, seg) - 0.5 * seg;
		cov += smoothstep(hw, hw * 0.55, abs(d));
	}
	cov /= float(N);
	// a faint haze for the part of the turn the shutter smears more slowly than this, and the thin hub
	float haze = 0.05 * (1.0 - smoothstep(0.6, 1.0, rr));
	float a = clamp((1.0 - exp(-3.2 * cov)) * 0.95 + haze, 0.0, 1.0) * strength;
	float tip = smoothstep(0.9, 0.99, rr);
	ALBEDO = mix(body_col, tip_col, tip * 0.8);
	ALPHA = a;
}
