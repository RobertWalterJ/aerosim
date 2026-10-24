extends SceneTree
## Headless checks for lane/sites. Run: Godot_console.exe --headless --path godot -s res://test/sites_blender_test.gd
## Site assets (SiteAssets, assets/models/sites): every file loads through SiteAssets (no stand-in), has its named nodes with
## LOD0 (and LOD1 where built), finite vertices, the manifest's size, sits on its base (lowest point between -buried_ok and
## +6 cm), no floating parts and no inside-out solids (Blender-side checks), front probes re-measured on the imported scene
## (node on the stated side; a material's faces facing the stated way), winding that matches the normals, every material a
## site_* key the loader knows, LOD ranges set, the cave mouth unshaded black.
## Vehicle brief files (assets/traffic/manifest.json): load raw like traffic.gd; wheel_* nodes with the origin at the hub
## (spin about local X), lamp_head/_tail nodes in front / behind (front is -Z), a `headlight` StandardMaterial3D with
## emission on, on the ground, parked ones carry a collider.
## Prints PASS/FAIL lines and exits 1 on any failure.

var fails := 0
var passes := 0
const NOT_ON_GROUND := ["boat_cover_tarp", "cave_damp_stain", "cave_chalk_mark", "boat_launch_damage_decals"]

func check(name: String, ok: bool, info := "") -> void:
	if ok: passes += 1
	else: fails += 1
	if not ok or OS.get_cmdline_user_args().has("verbose"):
		print(("PASS " if ok else "FAIL ") + name + "  " + info)

func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _meshes(c, out)

func _xf(n: Node3D, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != top:
		if p is Node3D: t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

## lowest/highest point, finiteness, triangles and flipped windings of the LOD0 meshes (or all, lod=-1) under top
func measure(top: Node3D, lod := 0) -> Dictionary:
	var ms: Array = []
	_meshes(top, ms)
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var tris := 0; var flipped := 0
	for mi: MeshInstance3D in ms:
		var nm := String(mi.name)
		if lod >= 0 and nm.contains("_LOD") and not nm.ends_with("_LOD%d" % lod): continue
		if mi.mesh == null: continue
		var xf := _xf(mi, top)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null:
				var ia: PackedInt32Array = idx
				tris += ia.size() / 3
				for t in range(0, ia.size(), 3):
					var a := pos[ia[t]]; var b := pos[ia[t + 1]]; var c := pos[ia[t + 2]]
					var fn := (b - a).cross(c - a)
					if fn.length_squared() < 1e-14: continue
					var vn := nrm[ia[t]] + nrm[ia[t + 1]] + nrm[ia[t + 2]]
					if fn.dot(vn) > 0.0: flipped += 1        # Godot front faces wind clockwise
			for v in pos:
				if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)): finite = false; continue
				var w := xf * v
				lo = lo.min(w); hi = hi.max(w)
	return {"lo": lo, "hi": hi, "finite": finite, "tris": tris, "flipped": flipped}

## area-weighted normal of the surfaces using material `key` under node (in the top frame)
func face_dir(node: Node3D, top: Node3D, key: String) -> Vector3:
	var acc := Vector3.ZERO
	var ms: Array = []
	_meshes(node, ms)
	for mi: MeshInstance3D in ms:
		if not String(mi.name).ends_with("_LOD0"): continue
		var b := _xf(mi, top).basis
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m == null or m.resource_name != key: continue
			var arr := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in range(0, ia.size(), 3):
				var a := pos[ia[t]]; var bb := pos[ia[t + 1]]; var c := pos[ia[t + 2]]
				acc += b * -((bb - a).cross(c - a)) * 0.5      # clockwise front faces: the outward normal is -cross
	return acc

func _initialize() -> void:
	_sites()
	_aliases()
	print("sites test: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)

func _sites() -> void:
	var names: Array = SiteAssets.names()
	names.sort()
	check("site manifest", names.size() >= 50, "%d assets" % names.size())
	for nm: String in names:
		var e: Dictionary = SiteAssets.info(nm)
		check(nm + " file", ResourceLoader.exists(SiteAssets.path_of(nm)), SiteAssets.path_of(nm))
		var inst := SiteAssets.instance(nm)
		get_root().add_child(inst)
		var nodes: Dictionary = e.get("nodes", {})
		for node_name: String in nodes:
			var n := inst.find_child(node_name, false, false) as Node3D
			check(nm + " node " + node_name, n != null, "")
			if n == null: continue
			var has0 := false; var has1 := false
			for c in n.get_children():
				if String(c.name).ends_with("_LOD0"): has0 = true
				if String(c.name).ends_with("_LOD1"): has1 = true
			check(nm + "/" + node_name + " LOD0", has0, "")
			if (nodes[node_name]["tris"] as Array).size() > 1:
				check(nm + "/" + node_name + " LOD1", has1, "")
		var m := measure(inst)
		check(nm + " finite", m["finite"])
		var sz: Vector3 = (m["hi"] as Vector3) - (m["lo"] as Vector3)
		var want: Vector3 = e["size"]
		check(nm + " size", sz.distance_to(want) < 0.05, "%s vs manifest %s" % [str(sz), str(want)])
		var lo_y: float = (m["lo"] as Vector3).y
		if not nm in NOT_ON_GROUND:
			check(nm + " on its base", lo_y <= 0.06 and lo_y >= -float(e.get("buried_ok", 0.0)) - 0.03,
				"lowest %.3f (buried allowance %.2f)" % [lo_y, float(e.get("buried_ok", 0.0))])
		check(nm + " winding matches normals", int(m["flipped"]) <= int(m["tris"]) / 100 + 1, "%d of %d flipped" % [m["flipped"], m["tris"]])
		var ck: Dictionary = e.get("checks", {})
		check(nm + " no floating parts", (ck.get("floating", []) as Array).is_empty(), str(ck.get("floating", [])))
		check(nm + " no inside-out solids", (ck.get("inside_out", []) as Array).is_empty(), str(ck.get("inside_out", [])))
		var tr: Array = e["tris"]
		var any_lod1 := false
		for node_name: String in nodes: if (nodes[node_name]["tris"] as Array).size() > 1: any_lod1 = true
		if any_lod1:
			check(nm + " LOD1 lighter", int(tr[1]) < int(tr[0]), str(tr))
		# front probes measured again on the imported scene
		var whole := AABB(m["lo"], sz)
		for p: Dictionary in ck.get("probes", []):
			var pr: Dictionary = p["probe"]
			var pn := inst.find_child(String(pr["node"]), false, false) as Node3D
			if pn == null: check(nm + " probe node", false, String(pr["node"])); continue
			if pr.has("side"):
				var pm := measure(pn, 0)
				var ax := "xyz".find(String(pr["axis"]))
				var c_node: float = ((pm["lo"] as Vector3)[ax] + (pm["hi"] as Vector3)[ax]) * 0.5
				var c_all: float = whole.get_center()[ax]
				# pn's points are measured in its own frame: add its transform
				var off: float = pn.position[ax]
				check(nm + " probe " + String(pr["node"]) + " on " + ("+" if int(pr["side"]) > 0 else "-") + String(pr["axis"]),
					(c_node + off - c_all) * float(pr["side"]) > 0.0, "node %.2f, asset %.2f" % [c_node + off, c_all])
			else:
				var d := face_dir(pn, inst, String(pr["mat"]))
				var want_d := Vector3(pr["dir"][0], pr["dir"][1], pr["dir"][2]).normalized()
				check(nm + " probe " + String(pr["mat"]) + " faces " + str(want_d), d.length() > 0 and d.normalized().dot(want_d) > 0.7,
					"measured %s" % str(d.normalized()))
		# materials and LOD ranges
		var ms: Array = []
		_meshes(inst, ms)
		var lod_ok := true
		for mi: MeshInstance3D in ms:
			if String(mi.name).ends_with("_LOD0") and nodes.size() > 0:
				var has_lod1 := false
				for c in mi.get_parent().get_children(): if String(c.name).ends_with("_LOD1"): has_lod1 = true
				if has_lod1 and mi.visibility_range_end <= 0.0: lod_ok = false
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(s)
				var key := mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) else ""
				check(nm + " material " + key, key.begins_with("site_") and mat != null and mat.resource_name == key, "")
				if key == "site_cave_dark":
					check(nm + " cave mouth unshaded black", (mat as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
						and (mat as BaseMaterial3D).albedo_color.v < 0.01, "")
		check(nm + " LOD ranges set", lod_ok, "")
		inst.queue_free()
	# brief part names resolve to a node of their file
	for part: String in SiteAssets.PARTS:
		var p := SiteAssets.instance(part)
		check("part " + part, p.get_child_count() >= 1 and p.get_child_count() <= 2, "%d nodes" % p.get_child_count())
		p.free()
	# a missing name gives a stand-in, not a crash
	var miss := SiteAssets.instance("no_such_site_asset")
	check("stand-in for a missing file", miss != null and miss.get_child_count() == 1, "")
	miss.free()
	# fit_ramp: the waterline mark (z 24) lands on the water
	var r := SiteAssets.instance("boat_ramp")
	get_root().add_child(r)
	SiteAssets.fit_ramp(r, 84.0, 76.0)
	var mark := r.transform * Vector3(0.0, 0.05, 24.0)
	check("fit_ramp waterline", absf(mark.y - 76.05) < 0.02, "mark at y %.3f" % mark.y)
	r.queue_free()

func _aliases() -> void:
	var man = JSON.parse_string(FileAccess.get_file_as_string("res://assets/traffic/manifest.json"))
	check("vehicle brief manifest", man is Dictionary and (man as Dictionary).size() >= 8, "")
	if not man is Dictionary: return
	for key: String in man:
		var e: Dictionary = man[key]
		var p := String(e["file"])
		var ps := load(p) as PackedScene
		check(key + " loads", ps != null, p)
		if ps == null: continue
		var inst := ps.instantiate() as Node3D
		get_root().add_child(inst)
		var wheels: Array = inst.find_children("wheel_*", "Node3D", true, false)
		check(key + " wheel nodes", wheels.size() == (e["wheels"] as Array).size() and wheels.size() >= 2, "%d" % wheels.size())
		var r := float(e["wheel_radius"]) if e["wheel_radius"] != null else 0.3
		for w: Node3D in wheels:
			var wm := measure(w, -1)
			var c: Vector3 = ((wm["lo"] as Vector3) + (wm["hi"] as Vector3)) * 0.5
			var wy := w.position.y
			check(key + " " + String(w.name) + " origin at the hub", absf(c.y) < 0.12 and absf(c.z) < 0.08 and wy > r * 0.6 and wy < r * 1.25,
				"hub y %.2f (radius %.2f), mesh centre offset %s" % [wy, r, str(c)])
		var lamp_ok := true
		var heads := 0
		for ln in ["lamp_head_l", "lamp_head_r", "lamp_tail_l", "lamp_tail_r"]:
			var n := inst.find_child(ln, true, false) as Node3D
			if n == null:
				if ln.begins_with("lamp_tail"): lamp_ok = false
				continue
			if ln.begins_with("lamp_head"): heads += 1
			var lm := measure(n, -1)
			var cz: float = ((lm["lo"] as Vector3).z + (lm["hi"] as Vector3).z) * 0.5
			check(key + " " + ln + (" at the front (-z)" if ln.begins_with("lamp_head") else " at the back (+z)"),
				cz < 0.0 if ln.begins_with("lamp_head") else cz > 0.0, "z %.2f" % cz)
		check(key + " tail lamps", lamp_ok, "")
		var hl := false
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var mat := (mi as MeshInstance3D).get_active_material(s) as StandardMaterial3D
				if mat != null and mat.resource_name.to_lower().contains("headlight") and mat.emission_enabled: hl = true
		if heads > 0:
			check(key + " headlight material (emissive)", hl, "")
		var m := measure(inst, -1)
		check(key + " on the ground", absf((m["lo"] as Vector3).y) < 0.06, "lowest %.3f" % (m["lo"] as Vector3).y)
		check(key + " finite", m["finite"])
		if bool(e.get("collider", false)):
			check(key + " collider", inst.find_children("*", "StaticBody3D", true, false).size() > 0, "")
		inst.queue_free()
