class_name BuildingMats
extends RefCounted
## The photographed materials of the Blender-made buildings (lane/buildings: tools/blender/build_buildings.py). The .glb
## files carry plain materials named `bld_*` with UVs in metres and a vertex colour (paint tint times weathering);
## StoryAssets swaps these in by name through NewModels6.mat(). Each textured key is an ORM material: albedo times vertex
## colour, OpenGL normal map, ARM (occlusion, roughness, metal) and, for the brick, a height map for parallax so the mortar
## joints sink at a grazing angle. uv1_scale is 1 / the real size of one repeat (Poly Haven's published size), so a brick
## course is 75 mm and a slate course about 190 mm. Sources and licences: assets/textures/README.md.

## key -> [texture prefix, metres per repeat, roughness fallback, height scale]
const SETS := {
	"bld_brick": ["bld_brick", 1.4, 0.9, 0.025],
	"bld_brick2": ["bld_brick2", 2.0, 0.9, 0.025],
	"bld_render": ["bld_render", 2.0, 0.85, 0.0],
	"bld_slate": ["bld_slate", 3.0, 0.7, 0.0],
	"bld_slate2": ["bld_slate2", 3.0, 0.75, 0.0],
	"bld_corrugated": ["bld_corrugated", 2.7, 0.5, 0.0],
	"bld_corrugated_rust": ["bld_corrugated_rust", 1.8, 0.7, 0.0],
	"bld_weatherboard": ["bld_weatherboard", 1.6, 0.8, 0.0],
	"bld_timber": ["bld_timber", 1.57, 0.85, 0.0],
	"bld_paint": ["bld_paint", 2.23, 0.6, 0.0],
	"bld_wood": ["bld_wood", 2.0, 0.85, 0.0],
	"bld_floor": ["bld_floor", 2.0, 0.6, 0.0],
	"bld_concrete": ["bld_concrete", 2.0, 0.85, 0.0],
	"bld_stone": ["bld_render", 1.2, 0.8, 0.0],
	"bld_ashlar": ["ashlar", 2.6, 0.85, 0.0],
	"bld_clay": ["bld_render", 0.8, 0.8, 0.0],
}

static var _cache := {}

static func has(key: String) -> bool:
	return key.begins_with("bld_")

static func get_mat(key: String) -> Material:
	if _cache.has(key): return _cache[key]
	var m: BaseMaterial3D
	if SETS.has(key):
		var s: Array = SETS[key]
		var o := ORMMaterial3D.new()
		var pre: String = s[0]
		o.albedo_texture = load("res://assets/textures/%s_diff.jpg" % pre)
		o.normal_enabled = true
		o.normal_texture = load("res://assets/textures/%s_nor.jpg" % pre)
		o.orm_texture = load("res://assets/textures/%s_arm.jpg" % pre)
		var rep := 1.0 / float(s[1])
		o.uv1_scale = Vector3(rep, rep, rep)
		if float(s[3]) > 0.0 and ResourceLoader.exists("res://assets/textures/%s_disp.jpg" % pre):
			o.heightmap_enabled = true
			o.heightmap_texture = load("res://assets/textures/%s_disp.jpg" % pre)
			o.heightmap_scale = float(s[3]) * 40.0
			o.heightmap_deep_parallax = false
		if key == "bld_clay": o.normal_scale = 0.5
		m = o
	else:
		var sm := StandardMaterial3D.new()
		match key:
			"bld_glass":
				# window glass: nearly black and clear, a sharp reflection of the sky, the room behind seen through it
				sm.albedo_color = Color(0.02, 0.025, 0.03, 0.32)
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.roughness = 0.03
				sm.metallic = 0.0
				sm.metallic_specular = 1.0
				sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			"bld_iron": sm.roughness = 0.42; sm.metallic = 0.35
			"bld_lead": sm.roughness = 0.6; sm.metallic = 0.55
			"bld_brass": sm.roughness = 0.32; sm.metallic = 1.0
			"bld_cloth": sm.roughness = 0.95; sm.metallic_specular = 0.25
			"bld_canvas": sm.roughness = 0.9; sm.metallic_specular = 0.25; sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			"bld_goods": sm.roughness = 0.55
			"bld_plaster_int": sm.roughness = 0.95; sm.metallic_specular = 0.3
			"bld_grime":
				sm.albedo_texture = load("res://assets/textures/bld_grime.png")
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sm.roughness = 0.9
				sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			_: sm.roughness = 0.8
		m = sm
	m.resource_name = key
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	if key == "bld_glass": m.vertex_color_use_as_albedo = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m
