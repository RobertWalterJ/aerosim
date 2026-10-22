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
	var scene := load("res://assets/%s.glb" % name) as PackedScene
	if scene == null:
		push_warning("missing model " + name)
		_cache[name] = out
		return out
	var inst := scene.instantiate()
	_collect(inst, Transform3D.IDENTITY, out)
	inst.free()
	_tint_far(name, out)
	_cache[name] = out
	return out

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
		# the exporter parented each model directly under the root, so drop the node's own transform
		_cache["env/" + str(c.name)] = out
	inst.free()

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

static func _tame(m: Material) -> void:
	# the web version's stone is authored a little over 1.0 for its own exposure; bring it in line with this lighting
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if b.albedo_color.r > 1.0: b.albedo_color = Color(0.82, 0.82, 0.82)

static func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var here := xf
	if n is Node3D: here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count(): _tame(mesh.surface_get_material(s))
		out.append({"mesh": mesh, "xf": here, "name": n.name})
	for c in n.get_children(): _collect(c, here, out)

## Adds one MultiMeshInstance3D per part of the model, one instance for each transform in `xfs`.
static func scatter(parent: Node, name: String, xfs: Array[Transform3D], shadows := true, range_begin := 0.0, range_end := 0.0) -> void:
	if xfs.is_empty(): return
	for p in parts(name):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = p["mesh"]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i] * (p["xf"] as Transform3D))
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
