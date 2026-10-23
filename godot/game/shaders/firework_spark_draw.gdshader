// One firework spark: a soft additive point of light, brighter than white so the camera bloom picks it up.
// The particle shader hands over a transform whose z axis is the star's motion and whose x scale is its size;
// the quad is turned to face the camera and stretched along that motion, which is what makes the long trails.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float px_per_m = 0.0016;   // metres of picture per pixel at 1 m, set from the camera each frame
uniform float hdr = 3.2;           // brightness over white, so the sensor's bloom glows
uniform float stretch = 1.0;       // how far a spark trails along its own motion

varying vec3 v_col;
varying float v_alpha;
varying float v_depth;

void vertex() {
	vec3 wpos = MODEL_MATRIX[3].xyz;
	vec3 vdir = normalize(MODEL_MATRIX[2].xyz + vec3(0.0, 1e-6, 0.0));
	float sz = length(MODEL_MATRIX[0].xyz);
	vec4 vp = VIEW_MATRIX * vec4(wpos, 1.0);
	float depth = max(-vp.z, 0.05);
	vec2 dv = (VIEW_MATRIX * vec4(vdir, 0.0)).xy;
	float dl = length(dv);
	dv = dl > 1e-4 ? dv / dl : vec2(0.0, 1.0);
	vec2 rt = vec2(-dv.y, dv.x);
	// a distant spark is drawn at least about two pixels across, so it reads as a point of light
	float szm = max(sz, 2.4 * depth * px_per_m);
	vec3 vpos = vp.xyz;
	vpos.xy += rt * VERTEX.x * szm + dv * VERTEX.y * szm * stretch;
	POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);
	v_col = COLOR.rgb;
	// a spark right in front of the lens must not fill the screen
	v_alpha = COLOR.a * smoothstep(0.4, 3.0, depth);
	v_depth = depth;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r2 = dot(uv, uv);
	float core = exp(-r2 * 18.0);
	float halo = exp(-r2 * 3.2) * 0.5;
	ALBEDO = v_col * hdr;
	ALPHA = clamp((core + halo) * v_alpha, 0.0, 1.0);
}
