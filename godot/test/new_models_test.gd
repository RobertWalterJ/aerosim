extends SceneTree
## Headless check of the new models (game/new_models.gd): builds every model and pose, checks there is no NaN, that the
## triangle counts are within the phone budgets and that the sizes are real. Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models_test.gd

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

## Triangles, bounding box and whether every position and normal is a finite number, over several meshes placed by xf.
func measure(parts: Array) -> Dictionary:
	var tris := 0
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var surfaces := 0
	for part in parts:
		var mesh: ArrayMesh = part[0]
		var xf: Transform3D = part[1]
		for s in mesh.get_surface_count():
			surfaces += 1
			var arr := mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			tris += pos.size() / 3
			for k in pos.size():
				var p := xf * pos[k]
				if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): finite = false
				lo = lo.min(p); hi = hi.max(p)
			for n in nrm:
				if not (is_finite(n.x) and is_finite(n.y) and is_finite(n.z)): finite = false
	return {"tris": tris, "size": hi - lo, "lo": lo, "hi": hi, "finite": finite, "surfaces": surfaces}

func row(name: String, m: Dictionary) -> void:
	var sz: Vector3 = m["size"]
	print("  %-22s %6d tris  %d surfaces  size x %.3f  y %.3f  z %.3f m" % [name, m["tris"], m["surfaces"], sz.x, sz.y, sz.z])

func near(v: float, lo: float, hi: float) -> bool:
	return v >= lo and v <= hi

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var I := Transform3D.IDENTITY
	print("New models: triangles, draw calls (surfaces) and real sizes")
	# ---- the plane
	var pl := NewModels.plane()
	var pm := measure([[pl["body"], I], [pl["prop"], Transform3D(Basis.IDENTITY, pl["prop_pivot"])]])
	row("plane", pm)
	check("plane finite", pm["finite"], "")
	check("plane triangles", int(pm["tris"]) < 12000, "%d < 12000" % pm["tris"])
	check("plane span", near(pm["size"].x, 1.05, 1.15), "%.3f m (1.1 m)" % pm["size"].x)
	check("plane length", near(pm["size"].z, 0.95, 1.12), "%.3f m" % pm["size"].z)
	check("plane outlines", (pl["outline_plan"] as PackedVector2Array).size() > 8 and (pl["outline_side"] as PackedVector2Array).size() > 8 and (pl["plan"] as Array).size() > 10,
		"plan %d pts, side %d pts, %d parts" % [(pl["outline_plan"] as PackedVector2Array).size(), (pl["outline_side"] as PackedVector2Array).size(), (pl["plan"] as Array).size()])
	var pp := measure([[pl["prop"], I]])
	check("prop diameter", near(maxf(pp["size"].x, pp["size"].y), 0.18, 0.2), "%.3f m, %d tris" % [maxf(pp["size"].x, pp["size"].y), pp["tris"]])
	check("prop is flat in its disc", pp["size"].z < 0.045, "%.3f m along +z" % pp["size"].z)
	# ---- birds, every pose
	var budgets := {"goose": 400, "gull": 400, "starling": 150, "hawk": 400}
	var spans := {"goose": [1.6, 1.9], "gull": [1.25, 1.5], "starling": [0.33, 0.43], "hawk": [1.1, 1.4]}
	var lengths := {"goose": [0.9, 1.08], "gull": [0.5, 0.65], "starling": [0.18, 0.23], "hawk": [0.45, 0.58]}
	check("bird pose count", NewModels.bird_wing_pose_count() == 8, "")
	for kind in ["goose", "gull", "starling", "hawk"]:
		var worst := 0
		var ok := true
		var min_y := INF; var max_y := -INF
		for k in NewModels.bird_wing_pose_count():
			var bm := measure([[NewModels.bird(kind, float(k) / NewModels.bird_wing_pose_count()), I]])
			worst = maxi(worst, int(bm["tris"]))
			ok = ok and bool(bm["finite"]) and int(bm["surfaces"]) == 1
			min_y = minf(min_y, bm["hi"].y); max_y = maxf(max_y, bm["hi"].y)
		var g := measure([[NewModels.bird(kind, 0.25), I]])
		row(kind + " (glide)", g)
		check(kind + " finite, one surface", ok, "")
		check(kind + " triangles", worst < int(budgets[kind]), "%d < %d" % [worst, budgets[kind]])
		check(kind + " span", near(g["size"].x, spans[kind][0], spans[kind][1]), "%.3f m" % g["size"].x)
		check(kind + " length", near(g["size"].z, lengths[kind][0], lengths[kind][1]), "%.3f m" % g["size"].z)
		check(kind + " wings beat", max_y - min_y > float(spans[kind][0]) * 0.15, "wing tips move %.3f m up and down" % (max_y - min_y))
	# ---- balloon, all three colour schemes
	for sc in 3:
		var b := NewModels.balloon(sc)
		var bm2 := measure([[b["envelope"], I], [b["basket"], I]])
		var em := measure([[b["envelope"], I]])
		var km := measure([[b["basket"], I]])
		row("balloon %d" % sc, bm2)
		check("balloon %d finite" % sc, bm2["finite"], "")
		check("balloon %d triangles" % sc, int(bm2["tris"]) < 6000, "%d < 6000 (envelope %d, basket %d)" % [bm2["tris"], em["tris"], km["tris"]])
		check("balloon %d envelope height" % sc, near(em["size"].y, 21.0, 23.5), "%.2f m" % em["size"].y)
		check("balloon %d envelope width" % sc, near(em["size"].x, 16.0, 18.5), "%.2f m" % em["size"].x)
		var fl: Vector3 = b["flame"]
		check("balloon %d basket" % sc, absf(float(km["lo"].y)) < 0.02 and near(fl.y, 2.3, 3.0) and near(km["hi"].y, 4.3, 4.5), "floor at %.3f, flame at %.2f m, cables up to the mouth at %.2f m" % [km["lo"].y, fl.y, km["hi"].y])
	# ---- deer, both poses
	var d := NewModels.deer()
	for pose in [["head_up", "body"], ["head_down", "body"], ["head_up", "body_flag"]]:
		var dm := measure([[d[pose[1]], I], [d[pose[0]], I]])
		row("deer %s %s" % [pose[1], pose[0]], dm)
		check("deer %s finite" % pose[0], dm["finite"], "")
		check("deer %s triangles" % pose[0], int(dm["tris"]) < 3000, "%d < 3000" % dm["tris"])
		check("deer %s on the ground" % pose[0], absf(float(dm["lo"].y)) < 0.03, "lowest point %.3f m" % dm["lo"].y)
	var bd := measure([[d["body"], I]])
	var up := measure([[d["body"], I], [d["head_up"], I]])
	check("deer shoulder height", near(bd["hi"].y, 0.88, 1.05), "%.2f m" % bd["hi"].y)
	check("deer length", near(up["size"].z, 1.5, 2.0), "%.2f m" % up["size"].z)
	check("deer head up height", near(up["hi"].y, 1.4, 1.8), "%.2f m" % up["hi"].y)
	# ---- fireworks
	var sm := measure([[NewModels.firework_shell_proxy(), I]])
	row("firework shell", sm)
	check("shell size", near(sm["size"].x, 0.05, 0.07) and bool(sm["finite"]), "%.3f m" % sm["size"].x)
	var gm := measure([[NewModels.barge(), I]])
	row("barge", gm)
	check("barge finite", gm["finite"], "")
	check("barge size", near(gm["size"].z, 11.8, 12.3) and near(gm["size"].x, 4.9, 5.4), "%.2f x %.2f m" % [gm["size"].z, gm["size"].x])
	check("barge tubes", NewModels.barge_tubes().size() == 20, "")
	print("built and checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
