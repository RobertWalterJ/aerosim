// Constable Rennick's ghost (lane/rennick). Used on rennick_1984_ghost.glb, whose textures are already drained to a pale,
// faintly cool grey-white (tools/blender/people_rennick.py ghostify): this shader only adds a soft cool rim, a little
// self-light so she reads in the storm, and an optional fade. It is OPAQUE with a dithered cut (no alpha blending), so the
// depth buffer is right and inner layers (eyeballs behind the lids, scalp under the hair, skin under the uniform) never
// show through; the old blended ghost let them. No glowing eyes, no hard edges, no horror.
//   fade          1 = fully there, 0 = gone (PeopleAssets.set_ghost_fade animates it)
//   translucency  0 = solid; up to ~0.5 lets the scene show through the middle of the figure (the rim stays)
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform bool alpha_cut = false;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float translucency : hint_range(0.0, 0.8) = 0.0;
// drain 1 = drain a living texture here (fallback when only rennick_1984.glb exists); 0 for the baked ghost file
uniform float drain : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.96, 0.98, 1.0);
uniform vec3 rim_color : source_color = vec3(0.80, 0.88, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.55;
uniform float rim_power : hint_range(0.5, 8.0) = 2.6;
uniform float glow : hint_range(0.0, 1.0) = 0.16;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.72;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (alpha_cut && t.a < 0.45) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float breath = 0.92 + 0.08 * sin(TIME * 0.6);
	float a = fade * (1.0 - translucency * (1.0 - rim));
	// interleaved gradient noise: a fine, stable screen dither for the fade
	float n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (a < 0.999 && a <= n) {
		discard;
	}
	float lum = dot(t.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = mix(t.rgb, vec3(0.55 + 0.37 * sqrt(lum)) * vec3(0.915, 0.95, 1.0), drain) * tint;
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.3;
	EMISSION = c * glow + rim_color * rim * rim_strength * breath;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}
