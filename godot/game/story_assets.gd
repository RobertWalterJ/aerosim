class_name StoryAssets
extends RefCounted
## Loads the story batch (models8: the Lake Car and Halloway assets, game/new_models6.gd and its group files) as scenes ready
## to place. The .glb files under assets/models/story/ are the interchange; here they are loaded, given the farm kit's
## photographed materials back (the file carries plain vertex-colour stand-ins named after the kit key) and returned as a
## Node3D. If a file is missing, the model is built from code instead, so a fresh checkout still works.
## Usage: `StoryAssets.place(self, "festival_bus_restored", Transform3D(basis, pos))` or `StoryAssets.instance(name, lod)`.
## Frame: metres, +Z is the front, origin at the base. Named children: wheel_fl etc., door, destination_board, headlamp_glass,
## interior_light, lamp_glass where a model has them. Collision comes from the `hullN-colonly` boxes the importer turns into a
## StaticBody3D (people, cloth and soft goods have none).

static func path_of(name: String, lod := 0) -> String:
	return "res://assets/models/story/%s/%s%s.glb" % [NewModels6.group_of(name), name, "" if lod == 0 else "_lod%d" % lod]

static func instance(name: String, lod := 0) -> Node3D:
	if PeopleAssets.handles(name):     # Blender 2: the rigged Blender people replace the code-built figures when their file is present
		var pn := PeopleAssets.instance(name)
		if pn != null: return pn
	var p := path_of(name, lod)
	if lod > 0 and not ResourceLoader.exists(p): p = path_of(name, 0)
	var ps := load(p) as PackedScene if ResourceLoader.exists(p) else null
	if ps == null:
		return NewModels6.scene(name, lod, false)
	var root := ps.instantiate() as Node3D
	root.name = name
	_remap(root)
	return root

static func _remap(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				if m != null and m.resource_name != "":
					mi.set_surface_override_material(s, NewModels6.mat(m.resource_name))
	for c in n.get_children(): _remap(c)

static func place(parent: Node, name: String, xf: Transform3D, lod := 0) -> Node3D:
	var n := instance(name, lod)
	n.transform = xf
	parent.add_child(n)
	return n

## Dev hook (main.gd `story<distance>_<name>+<name>...`): a row of models on the ground ahead of the camera, faces turned to it.
static func dev_row(parent: Node, terrain: Object, cam: Camera3D, dist: float, names: PackedStringArray) -> void:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := f.cross(Vector3.UP).normalized()
	var origin := cam.global_position + f * dist
	var widths: Array[float] = []
	var total := 0.0
	for nm in names:
		var probe := instance(nm, 0)
		var w := 1.0
		for ch in probe.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
				var bb := (ch as MeshInstance3D).mesh.get_aabb()
				w = maxf(w, maxf(bb.size.x, bb.size.z))
		probe.free()
		widths.append(w + 0.8)
		total += w + 0.8
	var x := -total * 0.5
	for i in names.size():
		var c := origin + r * (x + widths[i] * 0.5)
		c.y = terrain.height(c.x, c.z)
		var look := Basis.looking_at(f, Vector3.UP)     # -Z along the view direction, so +Z (the front) faces the camera
		place(parent, names[i], Transform3D(look, c))
		x += widths[i]
