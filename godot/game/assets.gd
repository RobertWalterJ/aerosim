class_name Assets
extends RefCounted
## Loads the exported tree and cemetery models (godot/assets, made by tools/export_assets.ts from the web version's
## generators) and places many copies cheaply with MultiMeshes. Each model is a list of parts (mesh + material).

static var _cache := {}

## Returns [{mesh: Mesh, xf: Transform3D, name: String}] for a model, e.g. "trees/maple_red_l0".
static func parts(name: String) -> Array:
	if _cache.has(name): return _cache[name]
	var out := []
	if name.begins_with("env/"):
		_load_env()
		return _cache.get(name, [])
	if name.begins_with("world/"):
		_load_world()
		return _cache.get(name, [])
	var scene := load("res://assets/%s.glb" % name) as PackedScene
	if scene == null:
		push_warning("missing model " + name)
		_cache[name] = out
		return out
	var inst := scene.instantiate()
	_collect(inst, Transform3D.IDENTITY, out)
	inst.free()
	_tint_far(name, out)
	_swap_foliage(name, out)
	_cache[name] = out
	return out

static var _world_loaded := false

## The web world's prop families and instanced park pieces, all in one file. Nodes are named family__variant__lod.
static func _load_world() -> void:
	if _world_loaded: return
	_world_loaded = true
	var scene := load("res://assets/world/props.glb") as PackedScene
	if scene == null:
		push_warning("missing res://assets/world/props.glb")
		return
	var inst := scene.instantiate()
	var holder: Node = inst
	while holder.get_child_count() == 1: holder = holder.get_child(0)
	for c in holder.get_children():
		var out := []
		_collect(c, Transform3D.IDENTITY, out)
		var fam := str(c.name).split("__")[0]
		if fam in ["meadow", "hedge-boxwood", "hedge-yew", "shrubs"]:
			_swap_foliage_parts(out)
		elif fam in STONE_FAMILIES:
			_swap_stone(out, STONE_FAMILIES[fam])
		elif fam == "park":
			_swap_stone(out, "granite")       # the park's headstones (park__inst0..3); lamps and benches have no stone texture
		_cache["world/" + str(c.name)] = out
	inst.free()
	_swap_park_stone()

static var _env_loaded := false

## The cemetery, fence, hedge and clutter models all live in one file (shared textures); split it by node name.
static func _load_env() -> void:
	if _env_loaded: return
	_env_loaded = true
	var scene := load("res://assets/env/all.glb") as PackedScene
	if scene == null:
		push_warning("missing res://assets/env/all.glb")
		return
	var inst := scene.instantiate()
	var holder: Node = inst
	while holder.get_child_count() == 1: holder = holder.get_child(0)   # the importer adds wrapper nodes
	for c in holder.get_children():
		var out := []
		_collect(c, Transform3D.IDENTITY, out)
		_swap_stone(out, _env_stone_look(str(c.name)))
		_swap_foliage("env/" + str(c.name), out)
		_cache["env/" + str(c.name)] = out
	inst.free()

## Trees and ground cover get the wind-sway shader in place of the imported standard material.
static func _swap_foliage(name: String, out: Array) -> void:
	if name.begins_with("trees/far_"): return
	if not (name.begins_with("trees/") or name.begins_with("env/meadowClump") or name.begins_with("env/lawnTuft")): return
	_swap_foliage_parts(out)

static func _swap_foliage_parts(out: Array) -> void:
	var shader := load("res://game/shaders/foliage.gdshader") as Shader
	for p in out:
		var mesh: Mesh = p["mesh"]
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if not (src is BaseMaterial3D): continue
			var b := src as BaseMaterial3D
			var wood := b.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter("albedo_tex", b.albedo_texture)
			if b.normal_texture != null:
				m.set_shader_parameter("normal_tex", b.normal_texture)
				m.set_shader_parameter("use_normal", true)
			m.set_shader_parameter("use_alpha", not wood)
			m.set_shader_parameter("alpha_cut", b.alpha_scissor_threshold if not wood else 0.5)
			m.set_shader_parameter("roughness", b.roughness)
			m.set_shader_parameter("flutter", 0.0 if wood else 1.0)
			m.set_shader_parameter("translucency", 0.0 if wood else 0.55)
			m.set_shader_parameter("tint", Vector3(b.albedo_color.r, b.albedo_color.g, b.albedo_color.b))
			mesh.surface_set_material(i, m)

## ---- stone and brick ----
## The cemetery's stone gets its own shader (polish, lichen, rain and snow response), and most of it a photographed
## PBR set from assets/textures (see the README there) laid on at real size. Looks:
##   memorial  weathered limestone over the model's stone (Victorian memorials, headstones in env)
##   granite   the model's polished or honed granite; polish follows the imported roughness (park headstones, obelisks)
##   rubble    random rubble wall (the boundary wall)      rock    lichened natural rock (outcrops)
##   brick     red brick (chapel plinth)                    ashlar  dressed stone blocks (memorial steps, gate piers)
const STONE_FAMILIES := {"memorials": "memorial", "stone-wall": "rubble", "rocks": "rock"}
## Each set's metres per repeat.
const STONE_SETS := {"rubble": 2.4, "mossrock": 3.0, "limestone": 1.2, "ashlar": 3.0, "brick": 1.0}

static var _stone_mats := {}     # one shared material per look and source material, never one per instance
static var _stone_tex := {}
static var _park_scene: PackedScene

static func _swap_stone(out: Array, look := "memorial") -> void:
	if look == "": return
	for p in out:
		var mesh: Mesh = p["mesh"]
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if not (src is BaseMaterial3D): continue
			var b := src as BaseMaterial3D
			if b.albedo_texture == null: continue
			if look == "granite" and b.normal_texture == null: continue    # e.g. the park bench's wood
			mesh.surface_set_material(i, _stone_mat(b, look))

static func _env_stone_look(node: String) -> String:
	if node.begins_with("stoneWall"): return "rubble"
	if node.begins_with("rockOutcrop"): return "rock"
	for k in ["headstone", "willowMarker", "urnMonument", "crossMonument", "angelMonument", "kerbedPlot"]:
		if node.begins_with(k): return "memorial"
	return ""     # wood, foliage and ground in the same file keep their own material

static func _stone_mat(b: BaseMaterial3D, look: String) -> ShaderMaterial:
	var key := "%s:%d" % [look, b.get_instance_id()]
	if _stone_mats.has(key): return _stone_mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/stone.gdshader") as Shader
	m.set_shader_parameter("albedo_tex", b.albedo_texture)
	if b.normal_texture != null: m.set_shader_parameter("normal_tex", b.normal_texture)
	match look:
		"memorial":
			_stone_set(m, "limestone", 2)
			m.set_shader_parameter("set_mix", 0.6); m.set_shader_parameter("set_tint", Vector3(0.78, 0.77, 0.74))
			m.set_shader_parameter("set_jitter", 1.0); m.set_shader_parameter("set_normal_amt", 0.8)
		"granite":
			var polish := clampf(inverse_lerp(0.62, 0.14, b.roughness), 0.0, 1.0)
			_stone_set(m, "limestone", 2)
			m.set_shader_parameter("polish_override", polish); m.set_shader_parameter("tint", Vector3(0.8, 0.8, 0.8))
			m.set_shader_parameter("set_mix", 0.15); m.set_shader_parameter("set_tint", Vector3(0.7, 0.7, 0.68))
			m.set_shader_parameter("set_jitter", 1.0); m.set_shader_parameter("set_normal_amt", 0.45)
		"rubble":
			_stone_set(m, "rubble", 1)
			m.set_shader_parameter("polish_override", 0.0); m.set_shader_parameter("set_tint", Vector3(1.05, 1.02, 0.98))
		"rock":
			_stone_set(m, "mossrock", 1)
			m.set_shader_parameter("polish_override", 0.0); m.set_shader_parameter("set_jitter", 1.0); m.set_shader_parameter("moss_amt", 0.5)
		"brick":
			_stone_set(m, "brick", 1)
			m.set_shader_parameter("polish_override", 0.0); m.set_shader_parameter("set_tint", Vector3(0.92, 0.9, 0.9)); m.set_shader_parameter("moss_amt", 0.4)
		"ashlar":
			_stone_set(m, "ashlar", 1)
			m.set_shader_parameter("polish_override", 0.1); m.set_shader_parameter("moss_amt", 0.6)
	_stone_mats[key] = m
	return m

static func _stone_set(m: ShaderMaterial, set_name: String, mode: int) -> void:
	if not _stone_tex.has(set_name):
		var t := []
		for map in ["diff", "nor", "arm"]: t.append(load("res://assets/textures/%s_%s.jpg" % [set_name, map]))
		_stone_tex[set_name] = t
	var tex: Array = _stone_tex[set_name]
	if tex[0] == null: return      # set missing: keep the model's own stone
	m.set_shader_parameter("set_mode", mode)
	m.set_shader_parameter("set_albedo", tex[0]); m.set_shader_parameter("set_normal", tex[1]); m.set_shader_parameter("set_arm", tex[2])
	m.set_shader_parameter("set_metres", float(STONE_SETS[set_name]))
	if mode == 1: m.set_shader_parameter("model_normal_amt", 0.0)

## The one-off park pieces (world.gd instances park.glb itself). Its meshes are shared with that instance, so swapping
## their materials here re-dresses the memorial, obelisks, gate piers and chapel plinth. The node names are generic,
## so pieces are told apart by size and imported roughness; the chapel's clapboard, roofs and trim are left alone.
static func _swap_park_stone() -> void:
	_park_scene = load("res://assets/world/park.glb") as PackedScene
	if _park_scene == null: return
	var inst := _park_scene.instantiate()
	_park_stone_walk(inst)
	inst.free()

static func _park_stone_walk(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		var sz := mesh.get_aabb().size
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			if not (src is BaseMaterial3D): continue
			var b := src as BaseMaterial3D
			if b.albedo_texture == null or b.normal_texture == null: continue
			var r := b.roughness
			var look := ""
			if sz.y > 0.5 and sz.y < 1.5 and sz.x > 5.0 and sz.z > 5.0 and r >= 0.8: look = "brick"            # chapel plinth
			elif sz.y < 0.4 and sz.x > 1.5 and absf(sz.x - sz.z) < 0.05 and r >= 0.5 and r < 0.7: look = "ashlar"   # memorial steps
			elif sz.y > 3.0 and sz.y < 4.0 and sz.x < 1.2 and r >= 0.5 and r < 0.7: look = "ashlar"           # gate piers
			elif r < 0.7: look = "granite"                                                                     # pedestal, plaques, obelisks
			if look != "":
				var sm := _stone_mat(b, look)
				sm.set_shader_parameter("base_y", mesh.get_aabb().position.y)   # one-off pieces: their own ground line
				mesh.surface_set_material(i, sm)
	for c in n.get_children(): _park_stone_walk(c)

static func _tint_far(name: String, out: Array) -> void:
	# the far silhouettes carry only baked shading; give them their colour here
	if not name.begins_with("trees/far_"): return
	var col := Color(0.15, 0.27, 0.13) if name.ends_with("conifer") else Color(0.55, 0.34, 0.13)
	for p in out:
		var mesh: Mesh = p["mesh"]
		for i in mesh.get_surface_count():
			var m := StandardMaterial3D.new()
			m.albedo_color = col; m.vertex_color_use_as_albedo = true; m.roughness = 1.0
			mesh.surface_set_material(i, m)

static var _manifest := {}

## Manifest entry for a model name such as "env/ironFence_0" (bbox, collider, tris), or {}.
static func info(name: String) -> Dictionary:
	if _manifest.is_empty():
		var f := FileAccess.open("res://assets/manifest.json", FileAccess.READ)
		if f != null:
			for e in JSON.parse_string(f.get_as_text()):
				_manifest[("trees/" if e["kind"] == "tree" else "env/") + str(e["name"])] = e
	return _manifest.get(name, {})

## Rain makes stone, iron and bark darker and glossier. Each material remembers its dry values the first time it is seen.
static func set_wetness(wet: float) -> void:
	for name in _cache:
		for p in _cache[name]:
			var mesh: Mesh = p["mesh"]
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					var b := m as BaseMaterial3D
					if not b.has_meta("dry_r"):
						b.set_meta("dry_r", b.roughness); b.set_meta("dry_c", b.albedo_color)
					b.roughness = float(b.get_meta("dry_r")) * (1.0 - 0.6 * wet)
					var dc: Color = b.get_meta("dry_c")
					var k := 1.0 - 0.32 * wet
					b.albedo_color = Color(dc.r * k, dc.g * k, dc.b * k, dc.a)
					b.metallic_specular = lerpf(0.5, 0.8, wet)

static func _tame(m: Material) -> void:
	# the web version's stone is authored a little over 1.0 for its own exposure; bring it in line with this lighting
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.albedo_color.r > 1.0: b.albedo_color = Color(0.82, 0.82, 0.82)
		elif b.albedo_texture == null and b.albedo_color.r > 0.55: b.albedo_color = Color(b.albedo_color.r * 0.72, b.albedo_color.g * 0.72, b.albedo_color.b * 0.72)

static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var here := xf
	if n is Node3D: here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count(): _tame(mesh.surface_get_material(s))
		out.append({"mesh": mesh, "xf": here, "name": n.name})
	for c in n.get_children(): _collect(c, here, out)

## Adds one MultiMeshInstance3D per part of the model, one instance for each transform in `xfs`.
static func scatter(parent: Node, name: String, xfs: Array[Transform3D], shadows := true, range_begin := 0.0, range_end := 0.0, colors: Array[Color] = []) -> void:
	if xfs.is_empty(): return
	for p in parts(name):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p["mesh"]
		mm.use_colors = not colors.is_empty()
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i] * (p["xf"] as Transform3D))
			if not colors.is_empty(): mm.set_instance_color(i, colors[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if range_begin > 0.0 or range_end > 0.0:
			mi.visibility_range_begin = range_begin; mi.visibility_range_end = range_end
			mi.visibility_range_begin_margin = 8.0 if range_begin > 0.0 else 0.0; mi.visibility_range_end_margin = 10.0 if range_end > 0.0 else 0.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		parent.add_child(mi)

## One placed copy (for single props such as a monument).
static func place(parent: Node, name: String, xf: Transform3D) -> void:
	for p in parts(name):
		var mi := MeshInstance3D.new()
		mi.mesh = p["mesh"]
		mi.transform = xf * (p["xf"] as Transform3D)
		parent.add_child(mi)
