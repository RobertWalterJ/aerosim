class_name Grass
extends Node3D
## GPU grass: three layers of instanced blades or leaves that follow the camera (see shaders/grass.gdshader).
##   lawn   short blades 10 to 28 cm in a 13 m patch around the camera
##   meadow taller blades 18 to 55 cm (up to about 1.9 m in the tall patches) in a 46 m patch
##   litter fallen autumn leaves in a 16 m patch
## Each layer is one MultiMesh of identity transforms; the shader places every blade from its instance number.

const QUALITY_COUNTS := {"low": [30000, 40000, 15000], "medium": [80000, 100000, 40000], "high": [120000, 150000, 60000], "ultra": [200000, 250000, 100000]}

var _mats: Array[ShaderMaterial] = []

static func add_globals() -> void:
	# shared by every vegetation shader; set once, then updated each frame by main.gd
	for g in [["g_cam", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO], ["g_time", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
			["g_wind", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(2, 0, 1)], ["g_drone", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, -999, 0, 3.5)],
			["g_wash", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0], ["g_snow", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0],
			["g_wet", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0], ["g_cloud", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.2, 0, 0, 0)], ["g_fx", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(1, 1, 0, 0)], ["g_dsA", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, 0.1)], ["g_dsB", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 1, 1)], ["g_dsC", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 1, 0.064, 0)]]:
		RenderingServer.global_shader_parameter_add(g[0], g[1], g[2])

func build(terrain: Terrain, quality: String, excl: Array[Rect2], pad_centre: Vector2) -> void:
	var counts: Array = QUALITY_COUNTS.get(quality, QUALITY_COUNTS["medium"])
	var layers := [
		{"patch": 13.0, "count": counts[0], "h": Vector2(0.10, 0.28), "w": 0.0085, "litter": 0.0, "clump": 0.3, "tall": 0.0},
		{"patch": 46.0, "count": counts[1], "h": Vector2(0.18, 0.55), "w": 0.02, "litter": 0.0, "clump": 0.6, "tall": 0.0},
		{"patch": 30.0, "count": int(counts[1] * 0.45), "h": Vector2(0.45, 1.05), "w": 0.03, "litter": 0.0, "clump": 0.8, "tall": 1.0},
		{"patch": 16.0, "count": counts[2], "h": Vector2(0.05, 0.09), "w": 0.045, "litter": 1.0},
	]
	var shader := load("res://game/shaders/grass.gdshader") as Shader
	for L in layers:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _blade_mesh(L["litter"] > 0.5)
		mm.instance_count = L["count"]
		var buf := PackedFloat32Array()
		buf.resize(int(L["count"]) * 12)
		for i in int(L["count"]):
			var o := i * 12
			buf[o] = 1.0; buf[o + 5] = 1.0; buf[o + 10] = 1.0
		mm.buffer = buf
		mm.custom_aabb = AABB(Vector3(-3000, -500, -3000), Vector3(6000, 2000, 6000))
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("uPatch", L["patch"])
		mat.set_shader_parameter("uBH", L["h"])
		mat.set_shader_parameter("uWidth", L["w"])
		mat.set_shader_parameter("uLitter", L["litter"])
		mat.set_shader_parameter("uClump", L.get("clump", 0.4))
		mat.set_shader_parameter("uTall", L.get("tall", 0.0))
		mat.set_shader_parameter("uHT", terrain.height_tex)
		mat.set_shader_parameter("uCV", terrain.cover_tex)
		mat.set_shader_parameter("uSize", Terrain.SIZE)
		mat.set_shader_parameter("uCells", float(Terrain.CELLS))
		var ex := PackedVector4Array()
		for r in excl: ex.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
		ex.resize(16)
		mat.set_shader_parameter("uExcl", ex)
		mat.set_shader_parameter("uExclN", mini(excl.size(), 16))
		mat.set_shader_parameter("uPad", pad_centre)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16384.0
		add_child(mi)
		_mats.append(mat)

func _blade_mesh(litter: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	if litter:
		verts = PackedVector3Array([Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)])
		idx = PackedInt32Array([0, 2, 1, 1, 2, 3])
	else:
		# a flat blade: wide base, narrowing to a tip
		verts = PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(-0.78, 0.5, 0), Vector3(0.78, 0.5, 0), Vector3(0, 1, 0)])
		idx = PackedInt32Array([0, 1, 2, 1, 3, 2, 2, 3, 4])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
