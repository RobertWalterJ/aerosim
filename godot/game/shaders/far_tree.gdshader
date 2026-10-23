// Low-poly trees along the far hills' crests (game/far_hills.gd). Colour = the model's baked shading x the instance
// colour x uTint, faded to the haze colour with distance exactly as the hills under them are.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

global uniform vec4 g_haze;
global uniform float g_snow;
uniform vec3 uTint = vec3(1.0);
uniform float uHazeDist = 9000.0;
uniform float uHazeAmt = 0.2;

varying vec3 wp;

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec3 c = COLOR.rgb * uTint;
	c = mix(c, vec3(0.62, 0.66, 0.74), g_snow * 0.3);
	float dist = length(wp - CAMERA_POSITION_WORLD);
	float a = (1.0 - exp(-dist / uHazeDist)) * uHazeAmt * g_haze.a;
	ALBEDO = c * (1.0 - a);
	EMISSION = g_haze.rgb * a;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
