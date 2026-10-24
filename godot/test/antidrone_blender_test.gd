extends SceneTree
## Headless checks for lane/antidrone. Run: Godot_console.exe --headless --path godot -s res://test/antidrone_blender_test.gd
## Every file loads through AntiDroneAssets (no stand-in), has its nested named nodes under the right parents with LOD0
## (and LOD1 where built), finite vertices, the manifest's size, sits on its base (lowest point between -buried_ok and
## +6 cm; the hunters on their skids), no floating parts and no inside-out solids (Blender-side checks), front probes
## re-measured on the imported scene, winding that matches the normals, every material an ad_* / site_* key the loader
## knows, the triangle budgets of the brief, lamps emissive, the moving parts (mast hinge at the deck and 14 m top, rotors
## on their motors and spinning, the eye at the nose, the door on its hinge), lower_mast, the stand-ins and text faces.
## Prints PASS/FAIL lines and exits 1 on any failure.

var fails := 0
var passes := 0
const NOT_ON_GROUND := ["pike_beacon", "pike_strobe_card", "hunter_net_pod"]
const NEEDED := ["pike_jammer_trailer", "pike_jammer_mast", "pike_beacon", "pike_manifesto_board", "pike_warning_sign",
	"pike_shack", "pike_generator", "pike_fence", "pike_fence_8m", "pike_cable_run", "hunter_drone_a", "hunter_drone_b",
	"hunter_drone_c", "hunter_rotor", "hunter_net_pod", "pike_tarp", "pike_toolbox", "pike_chair", "pike_floodlight",
	"pike_radio", "pike_log_pile", "pike_mast_wreck", "pike_smoke"]
## the brief's triangle ranges (LOD0): trailer 3 to 8k, hunters 2 to 5k, shack 3 to 7k
const BUDGET := {"pike_jammer_trailer": [3000, 8000], "pike_shack": [3000, 7000], "hunter_drone_a": [2000, 5000],
	"hunter_drone_b": [2000, 5000], "hunter_drone_c": [2000, 5000]}

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

## lowest/highest point, finiteness, triangles and flipped windings of the LOD0 meshes under `under`, in top's frame
func measure(under: Node3D, top: Node3D, lod := 0, own_only := false) -> Dictionary:
	var ms: Array = []
	if own_only:
		for c in under.get_children(): if c is MeshInstance3D: ms.append(c)
	else:
		_meshes(under, ms)
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

func _initialize() -> void:
	_files()
	_parts()
	_fallbacks()
	print("antidrone test: %d passed, %d failed" % [passes, fails])
	quit(1 if fails > 0 else 0)

func _files() -> void:
	var names: Array = AntiDroneAssets.names()
	names.sort()
	for need: String in NEEDED:
		check("brief asset " + need, names.has(need), "")
	for nm: String in names:
		var e: Dictionary = AntiDroneAssets.info(nm)
		check(nm + " file", ResourceLoader.exists(AntiDroneAssets.path_of(nm)), AntiDroneAssets.path_of(nm))
		var inst := AntiDroneAssets.instance(nm)
		get_root().add_child(inst)
		var nodes: Dictionary = e.get("nodes", {})
		for node_name: String in nodes:
			var n := inst.find_child(node_name, true, false) as Node3D
			check(nm + " node " + node_name, n != null, "")
			if n == null: continue
			var par := String(nodes[node_name].get("parent", ""))
			if par != "":
				check(nm + " " + node_name + " under " + par, n.get_parent() != null and String(n.get_parent().name) == par, String(n.get_parent().name))
			else:
				check(nm + " " + node_name + " at the top", n.get_parent() == inst, "")
			var tl: Array = nodes[node_name]["tris"]
			if tl.size() > 0:
				var has0 := false; var has1 := false
				for c in n.get_children():
					if String(c.name).ends_with("_LOD0"): has0 = true
					if String(c.name).ends_with("_LOD1"): has1 = true
				check(nm + "/" + node_name + " LOD0", has0, "")
				if tl.size() > 1: check(nm + "/" + node_name + " LOD1", has1, "")
			# the pivot in the file is where the manifest says (asset frame)
			var want_p: Vector3 = nodes[node_name]["pivot"]
			var got_p := _xf(n, inst).origin
			check(nm + " " + node_name + " pivot", got_p.distance_to(want_p) < 0.01, "%s vs %s" % [str(got_p), str(want_p)])
		var m := measure(inst, inst)
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
		for p: Dictionary in ck.get("probes", []):
			var pr: Dictionary = p["probe"]
			var pn := inst.find_child(String(pr["node"]), true, false) as Node3D
			if pn == null: check(nm + " probe node", false, String(pr["node"])); continue
			if pr.has("side"):
				var pm := measure(pn, inst)
				var ax := "xyz".find(String(pr["axis"]))
				var c_node: float = ((pm["lo"] as Vector3)[ax] + (pm["hi"] as Vector3)[ax]) * 0.5
				var c_all: float = ((m["lo"] as Vector3)[ax] + (m["hi"] as Vector3)[ax]) * 0.5
				check(nm + " probe " + String(pr["node"]) + " on " + ("+" if int(pr["side"]) > 0 else "-") + String(pr["axis"]),
					(c_node - c_all) * float(pr["side"]) > 0.0, "node %.2f, asset %.2f" % [c_node, c_all])
			else:
				var acc := Vector3.ZERO
				var ms2: Array = []
				for c in pn.get_children(): if c is MeshInstance3D and String(c.name).ends_with("_LOD0"): ms2.append(c)
				for mi: MeshInstance3D in ms2:
					var b := _xf(mi, inst).basis
					for s in mi.mesh.get_surface_count():
						var mm := mi.mesh.surface_get_material(s)
						if mm == null or mm.resource_name != String(pr["mat"]): continue
						var arr := mi.mesh.surface_get_arrays(s)
						var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
						var ia: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
						for t in range(0, ia.size(), 3):
							acc += b * -((pos[ia[t + 1]] - pos[ia[t]]).cross(pos[ia[t + 2]] - pos[ia[t]])) * 0.5
				var wd := Vector3(pr["dir"][0], pr["dir"][1], pr["dir"][2]).normalized()
				check(nm + " probe " + String(pr["mat"]) + " faces " + str(wd), acc.length() > 0 and acc.normalized().dot(wd) > 0.7, str(acc.normalized()))
		var tr: Array = e["tris"]
		if BUDGET.has(nm):
			check(nm + " triangle budget", int(tr[0]) >= int(BUDGET[nm][0]) and int(tr[0]) <= int(BUDGET[nm][1]), "%d (brief %s)" % [tr[0], str(BUDGET[nm])])
		var ms: Array = []
		_meshes(inst, ms)
		var lod_ok := true
		for mi: MeshInstance3D in ms:
			if String(mi.name).ends_with("_LOD1") and mi.visibility_range_begin <= 0.0: lod_ok = false
			for s in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(s)
				var key := src.resource_name if src else ""
				var mat := mi.get_surface_override_material(s)
				check(nm + " material " + key, (key.begins_with("ad_") or key.begins_with("site_")) and mat != null and mat.resource_name == key, "")
				if key.begins_with("ad_lamp"):
					check(nm + " " + key + " emissive", (mat as StandardMaterial3D).emission_enabled, "")
		check(nm + " LOD ranges set", lod_ok, "")
		inst.queue_free()

func _parts() -> void:
	# the mast: hinge at the deck, 14 m to the head, the beacon on top, lowering lays it forward and puts the beacon out
	var t := AntiDroneAssets.instance("pike_jammer_trailer")
	get_root().add_child(t)
	var mast := t.find_child("mast", true, false) as Node3D
	var deck := float(AntiDroneAssets.meta("pike_jammer_trailer").get("deck_y", 0.62))
	check("trailer mast hinge at the deck", absf(mast.position.y - deck) < 0.02, "pivot y %.3f" % mast.position.y)
	var bc := t.find_child("beacon", true, false) as Node3D
	var by := _xf(bc, t).origin.y
	check("trailer beacon at the mast head (13.5 to 14.2 m)", by > 13.5 and by < 14.2, "%.2f m" % by)
	var dish := t.find_child("dish", true, false) as Node3D
	var dm := measure(dish, t)
	check("dish 1.1 m across", absf(((dm["hi"] as Vector3) - (dm["lo"] as Vector3)).x - 1.12) < 0.06, str((dm["hi"] as Vector3) - (dm["lo"] as Vector3)))
	AntiDroneAssets.lower_mast(t, 1.0)
	var by2 := _xf(bc, t).origin
	check("lower_mast lays the head forward (+z) and low", by2.y < 1.6 and by2.z > 10.0, str(by2))
	check("lower_mast hides the guy wires", not (t.find_child("guy_wires", true, false) as Node3D).visible, "")
	var lit := false
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			var mm := (mi as MeshInstance3D).get_active_material(s) as StandardMaterial3D
			if mm != null and mm.resource_name == "ad_lamp_red" and mm.emission_energy_multiplier > 0.0: lit = true
	check("lower_mast puts the beacon out", not lit, "")
	t.queue_free()
	# hunters: eye at the nose (+z) and lit, rotors on their motors (pivot in the middle of the blades), spinning
	for h: String in AntiDroneAssets.HUNTERS:
		var n := AntiDroneAssets.instance(h)
		get_root().add_child(n)
		var e := n.find_child("eye", true, false) as Node3D
		var whole := measure(n, n)
		var body_hi: Vector3 = measure(n.find_child("body", true, false) as Node3D, n)["hi"]
		check(h + " eye at the nose", e != null and _xf(e, n).origin.z > 0.4 * body_hi.z and absf(_xf(e, n).origin.x) < 0.01,
			"eye z %.3f, body front %.3f" % [_xf(e, n).origin.z if e else -1.0, body_hi.z])
		var spin: Dictionary = AntiDroneAssets.meta(h).get("spin", {})
		var nr := 0
		for i in range(1, 7):
			var r := n.find_child("rotor_%d" % i, true, false) as Node3D
			if r == null: continue
			nr += 1
			var rm := measure(r, r)
			var c: Vector3 = ((rm["lo"] as Vector3) + (rm["hi"] as Vector3)) * 0.5
			check(h + " rotor_%d hub on its pivot" % i, Vector2(c.x, c.z).length() < 0.03 and absf(c.y) < 0.03, str(c))
			check(h + " rotor_%d has a spin direction" % i, spin.has("rotor_%d" % i), "")
			var b0 := r.transform.basis
			AntiDroneAssets.spin_rotors(n, 0.004)
			check(h + " rotor_%d spins about y" % i, not r.transform.basis.is_equal_approx(b0) and r.transform.basis.y.is_equal_approx(b0.y), "")
		check(h + " rotor count", nr == (6 if h == "hunter_drone_b" else 4), "%d" % nr)
		var span: float = ((whole["hi"] as Vector3) - (whole["lo"] as Vector3)).x
		var want := {"hunter_drone_a": 0.9, "hunter_drone_b": 1.0, "hunter_drone_c": 0.46}[h] as float
		check(h + " across", absf(span - want) < 0.12, "%.2f m (brief %.2f)" % [span, want])
		n.queue_free()
	# the shack door hinges on its edge (rotating it 80 degrees keeps the hinge side still)
	var s := AntiDroneAssets.instance("pike_shack")
	get_root().add_child(s)
	var door := s.find_child("door", true, false) as Node3D
	var d0 := measure(door, s)
	door.rotation.y = deg_to_rad(80.0)
	var d1 := measure(door, s)
	check("shack door hinged on its right edge", absf((d1["hi"] as Vector3).x - (d0["hi"] as Vector3).x) < 0.08 and (d1["hi"] as Vector3).z > (d0["hi"] as Vector3).z + 0.4,
		"%s -> %s" % [str(d0["hi"]), str(d1["hi"])])
	s.queue_free()
	# text faces
	for nm in ["pike_manifesto_board", "pike_warning_sign"]:
		var tr := AntiDroneAssets.text_rect(nm)
		check(nm + " text rect", tr.has("centre") and tr.has("size"), str(tr))

func _fallbacks() -> void:
	var miss := AntiDroneAssets.instance("no_such_antidrone_asset")
	check("stand-in for a missing file", miss != null and miss.get_child_count() == 1, "")
	miss.free()
	var h := AntiDroneAssets._stand_in("hunter_drone_b")
	check("hunter stand-in keeps the node names", h.find_child("eye", false, false) != null and h.find_child("rotor_6", false, false) != null, "")
	AntiDroneAssets.spin_rotors(h, 0.01)
	h.free()
