extends SceneTree
## Headless check of the second batch of models (game/new_models2.gd): builds every model, checks there is no NaN, that every
## triangle faces the way its normals point, that the triangle counts are within the phone budgets and that the sizes are
## real. Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models2_test.gd

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

## Triangles, bounding box, whether every position and normal is finite, and how many triangles are wound against their
## normals, over several meshes placed by xf. Indexed meshes (the funnel, the flag cloth) are read through their indices.
func measure(parts: Array) -> Dictionary:
	var tris := 0
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var surfaces := 0
	var flipped := 0
	for part in parts:
		var mesh: ArrayMesh = part[0]
		var xf: Transform3D = part[1]
		for s in mesh.get_surface_count():
			surfaces += 1
			var arr := mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var idx := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null: idx = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				idx.resize(pos.size())
				for k in pos.size(): idx[k] = k
			tris += idx.size() / 3
			for k in pos.size():
				var p := xf * pos[k]
				if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): finite = false
				lo = lo.min(p); hi = hi.max(p)
			for n in nrm:
				if not (is_finite(n.x) and is_finite(n.y) and is_finite(n.z)): finite = false
			for k in range(0, idx.size(), 3):
				var a := pos[idx[k]]; var b := pos[idx[k + 1]]; var c := pos[idx[k + 2]]
				var f := (b - a).cross(c - a)
				var n := nrm[idx[k]] + nrm[idx[k + 1]] + nrm[idx[k + 2]]
				if f.dot(n) > 1e-9 * f.length() * n.length() and f.length_squared() > 1e-16: flipped += 1   # Godot's front faces wind clockwise
	return {"tris": tris, "size": hi - lo, "lo": lo, "hi": hi, "finite": finite, "surfaces": surfaces, "flipped": flipped}

func row(name: String, m: Dictionary) -> void:
	var sz: Vector3 = m["size"]
	print("  %-24s %6d tris  %d surfaces  size x %.2f  y %.2f  z %.2f m" % [name, m["tris"], m["surfaces"], sz.x, sz.y, sz.z])

func near(v: float, lo: float, hi: float) -> bool:
	return v >= lo and v <= hi

## The common checks: finite, wound right, under the budget.
func basic(name: String, m: Dictionary, budget: int) -> void:
	row(name, m)
	check(name + " finite", m["finite"], "")
	check(name + " winding", int(m["flipped"]) == 0, "%d triangles wound against their normals" % m["flipped"])
	check(name + " triangles", int(m["tris"]) < budget, "%d < %d" % [m["tris"], budget])

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var I := Transform3D.IDENTITY
	print("New models, batch 2: triangles, draw calls (surfaces) and real sizes")
	# ---- barn and silo
	var bm := measure([[NewModels2.barn(), I]])
	basic("barn", bm, 3000)
	# the barn and silo carry the textured farm shader on every surface but the glass, and their textures stay small
	var shaded := true
	for mesh: ArrayMesh in [NewModels2.barn(), NewModels2.silo()]:
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat is ShaderMaterial:
				var sm2 := mat as ShaderMaterial
				if not (sm2.shader.resource_path.ends_with("farm.gdshader") and sm2.get_shader_parameter("set_albedo") is Texture2D and sm2.get_shader_parameter("set_normal") is Texture2D): shaded = false
			elif not (mat is StandardMaterial3D and (mat as StandardMaterial3D).metallic > 0.8): shaded = false   # only the glass may be standard
	check("barn and silo textured", shaded, "")
	var tex_bytes := 0
	for set_name in ["barnwood", "roofsteel", "silocrete"]:
		for map in ["diff", "nor", "arm"]:
			var f := FileAccess.open("res://assets/textures/%s_%s.jpg" % [set_name, map], FileAccess.READ)
			if f: tex_bytes += f.get_length()
	check("farm textures compact", tex_bytes > 0 and tex_bytes < 6 * 1024 * 1024, "%.2f MB of new JPEGs (fieldstone reuses rubble_*)" % (tex_bytes / 1048576.0))
	check("barn footprint", near(bm["size"].x, 12.0, 13.6) and near(bm["size"].z, 24.0, 27.0), "%.2f x %.2f m" % [bm["size"].x, bm["size"].z])
	check("barn height", near(bm["hi"].y, 9.8, 11.2) and absf(float(bm["lo"].y)) < 0.01, "%.2f m to the vane, ground at %.3f" % [bm["hi"].y, bm["lo"].y])
	var sm := measure([[NewModels2.silo(), I]])
	basic("silo", sm, 800)
	check("silo size", near(sm["size"].y, 17.8, 18.2) and near(sm["size"].z, 5.0, 5.6), "%.2f m high, %.2f m wide" % [sm["size"].y, sm["size"].z])
	# ---- windmill and wind pump
	var wm := NewModels2.windmill()
	var wpv: Vector3 = wm["sail_pivot"]
	var wmm := measure([[wm["tower"], I], [wm["cap"], I], [wm["sails"], Transform3D(Basis.IDENTITY, wpv)]])
	basic("windmill", wmm, 3500)
	var tw := measure([[wm["tower"], I]])
	check("windmill tower height", near(tw["hi"].y, 15.5, 16.6), "%.2f m" % tw["hi"].y)
	var sl := measure([[wm["sails"], I]])
	check("windmill sails", near(sl["size"].x, 15.5, 16.5) and near(sl["size"].y, 15.5, 16.5) and sl["size"].z < 1.7, "%.2f x %.2f m, %.2f m deep" % [sl["size"].x, sl["size"].y, sl["size"].z])
	# the sails read at distance: a spread cloth on each (a double-sided surface of its own) and no part under 15 cm
	var sails: ArrayMesh = wm["sails"]
	var cloth_tris := 0
	for s in sails.get_surface_count():
		var cm2 := sails.surface_get_material(s) as StandardMaterial3D
		if cm2 and cm2.cull_mode == BaseMaterial3D.CULL_DISABLED: cloth_tris += (sails.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	check("windmill sail cloths", cloth_tris >= 8 and cloth_tris < 200, "%d cloth triangles (spread panels and the rolled cloth)" % cloth_tris)
	check("windmill sail bars bold", NewModels2.WM_BAR >= 0.15, "sail bars %.0f cm across" % (NewModels2.WM_BAR * 100.0))
	check("windmill sails clear the gallery", wpv.y - float(wm["sail_radius"]) > NewModels2.WM_GAL + 1.2, "tips down to %.2f m, rail at %.2f m" % [wpv.y - float(wm["sail_radius"]), NewModels2.WM_GAL + 1.15])
	var wp := NewModels2.wind_pump()
	var ppv: Vector3 = wp["wheel_pivot"]
	var wpm := measure([[wp["tower"], I], [wp["tail"], I], [wp["wheel"], Transform3D(Basis.IDENTITY, ppv)]])
	basic("wind pump", wpm, 2000)
	check("wind pump height", near(wpm["hi"].y, 11.7, 12.3), "%.2f m" % wpm["hi"].y)
	var wh := measure([[wp["wheel"], I]])
	check("wind pump wheel", near(wh["size"].x, 3.5, 3.75), "%.2f m across" % wh["size"].x)
	# ---- freight train and track
	var tr := NewModels2.freight_train(12)
	# with the far wheelsets a vehicle may cost at most 150 triangles more than in batch 2 (when the wheels were drums in
	# the body); close up the flanged wheelsets add more (counted below), on the few cars near the camera
	var old_tris := {"locomotive": 1392, "boxcar": 606, "hopper": 640, "tanker": 670, "flatcar": 504, "flatcar_empty": 408}
	var wheels: Dictionary = tr["wheels"]
	for kind in ["locomotive", "boxcar", "hopper", "tanker", "flatcar", "flatcar_empty"]:
		var wd: Dictionary = wheels[kind]
		var parts: Array = [[tr[kind], I]]
		var far_parts: Array = [[tr[kind], I]]
		for p: Vector3 in wd["positions"]:
			parts.append([wd["mesh"], Transform3D(Basis.IDENTITY, p)])
			far_parts.append([wd["mesh_far"], Transform3D(Basis.IDENTITY, p)])
		var cm := measure(parts)
		var body := measure([[tr[kind], I]])
		var far := measure(far_parts)
		var ws := measure([[wd["mesh"], I]])
		basic(kind, cm, (2900 if kind == "locomotive" else 1700))
		check(kind + " triangles with far wheels", int(far["tris"]) <= int(old_tris[kind]) + 150, "%d <= %d + 150 (body %d; close wheelsets %d x %d)" % [far["tris"], old_tris[kind], body["tris"], (wd["positions"] as PackedVector3Array).size(), ws["tris"]])
		check(kind + " far wheels", bool(far["finite"]) and int(far["flipped"]) == 0 and absf(float(far["lo"].y)) < 0.01, "")
		check(kind + " body clear of the rails", float(body["lo"].y) > 0.05, "lowest body point %.2f m above the rail" % body["lo"].y)
		if kind == "locomotive":
			check("locomotive size", near(cm["size"].z, 20.8, 22.0) and near(cm["hi"].y, 4.5, 4.95) and absf(float(cm["lo"].y)) < 0.04, "%.2f m long, %.2f m high, flanges to %.3f" % [cm["size"].z, cm["hi"].y, cm["lo"].y])
		else:
			check(kind + " size", near(cm["size"].z, 15.0, 17.0) and cm["size"].x < 3.35 and absf(float(cm["lo"].y)) < 0.04, "%.2f m long, %.2f wide, flanges to %.3f" % [cm["size"].z, cm["size"].x, cm["lo"].y])
	for kind in ["locomotive", "boxcar"]:
		var wd2: Dictionary = wheels[kind]
		var r: float = wd2["radius"]
		var wm2 := measure([[wd2["mesh"], I]])
		check(kind + " wheelset", (wd2["positions"] as PackedVector3Array).size() == (6 if kind == "locomotive" else 4) and near(wm2["size"].y, 2.0 * r + 0.05, 2.0 * r + 0.07) and near(wm2["size"].x, 1.6, 1.75),
			"%d axles, %.2f m over the flanges (wheel radius %.2f), %.2f m along the axle" % [(wd2["positions"] as PackedVector3Array).size(), wm2["size"].y, r, wm2["size"].x])
		# the running surface (vertices at the full tread radius) must sit over the rail heads
		var arr := (wd2["mesh"] as ArrayMesh).surface_get_arrays(0)
		var tread_ok := true
		for v: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(Vector2(v.y, v.z).length() - r) < 0.005 and not near(absf(v.x), 0.7, 0.83): tread_ok = false
		check(kind + " treads on the rails", tread_ok, "gauge %.3f m" % tr["gauge"])
	check("wheel spin axis", tr["wheel_axis"] == Vector3.RIGHT, "")
	check("consist", (tr["consist"] as Array).size() == 13 and absf(float(tr["car_length"]) - 16.6) < 0.01, "%d entries" % (tr["consist"] as Array).size())
	var tm := measure([[NewModels2.track_section(), I]])
	basic("track section", tm, 400)
	check("track size", near(tm["size"].z, 19.99, 20.01) and absf(float(tm["hi"].y)) < 0.001 and near(tm["lo"].y, -0.63, -0.61), "%.2f m long, rail top %.3f, foot %.2f" % [tm["size"].z, tm["hi"].y, tm["lo"].y])
	# ---- helicopter and far airliner
	var hc := NewModels2.helicopter()
	var hmm := measure([[hc["body"], I], [hc["main_rotor"], Transform3D(Basis.IDENTITY, hc["rotor_pivot"])], [hc["tail_rotor"], Transform3D(Basis.IDENTITY, hc["tail_pivot"])]])
	basic("helicopter", hmm, 3500)
	var hb := measure([[hc["body"], I]])
	check("helicopter body", near(hb["size"].z, 10.5, 11.5) and absf(float(hb["lo"].y)) < 0.02, "%.2f m long, skids at %.3f" % [hb["size"].z, hb["lo"].y])
	var mr := measure([[hc["main_rotor"], I]])
	check("helicopter main rotor", near(mr["hi"].x, 4.9, 5.1) and mr["size"].y < 0.4, "blade tip %.2f m from the hub (10 m across)" % mr["hi"].x)
	var trm := measure([[hc["tail_rotor"], I]])
	check("helicopter tail rotor", near(trm["size"].y, 1.8, 1.95) and trm["size"].x < 0.2, "%.2f m across, %.2f m thick along +x" % [trm["size"].y, trm["size"].x])
	var am := measure([[NewModels2.airliner_far(), I]])
	basic("airliner (far)", am, 600)
	check("airliner size", near(am["size"].z, 37.5, 38.5) and near(am["size"].x, 35.5, 36.2), "%.2f m long, %.2f m span" % [am["size"].z, am["size"].x])
	# ---- kites and flag
	for kind in 2:
		var km := measure([[NewModels2.kite(kind), I]])
		basic("kite %d" % kind, km, 120)
		check("kite %d span" % kind, near(km["size"].x, 0.95, 1.05), "%.2f m across" % km["size"].x)
	var lnm := measure([[NewModels2.kite_line(), I]])
	check("kite line", near(lnm["size"].z, 0.999, 1.001) and int(lnm["tris"]) == 4, "%.3f m along +z, %d tris" % [lnm["size"].z, lnm["tris"]])
	for sc in 4:
		var fl := NewModels2.flag(sc)
		var fm := measure([[fl["pole"], I], [fl["cloth"], Transform3D(Basis.IDENTITY, fl["cloth_origin"])]])
		if sc == 0:
			basic("flag", fm, 800)
			var cl := measure([[fl["cloth"], I]])
			var arr := (fl["cloth"] as ArrayMesh).surface_get_arrays(0)
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			check("flag cloth grid", int(cl["tris"]) == 480 and uvs.size() == 21 * 13, "%d tris, %d vertices with UV" % [cl["tris"], uvs.size()])
			check("flag pole height", near(fm["hi"].y, 9.0, 9.2) and absf(float(fm["lo"].y)) < 0.01, "%.2f m" % fm["hi"].y)
		check("flag %d finite" % sc, fm["finite"], "")
	# ---- debris and funnels
	var deb := NewModels2.debris_pieces()
	check("debris count", deb.size() == 6, "%d pieces" % deb.size())
	for k in deb.size():
		var dm := measure([[deb[k], I]])
		check("debris %d" % k, bool(dm["finite"]) and int(dm["flipped"]) == 0 and int(dm["tris"]) < 30 and dm["size"].length() < 2.0, "%d tris, %.2f m" % [dm["tris"], dm["size"].length()])
	var fu := measure([[NewModels2.funnel_tube(), I]])
	basic("funnel tube", fu, 1200)
	check("funnel unit height", near(fu["size"].y, 0.999, 1.001) and absf(float(fu["lo"].y)) < 0.001, "%.3f high" % fu["size"].y)
	var farr := NewModels2.funnel_tube().surface_get_arrays(0)
	var fpos: PackedVector3Array = farr[Mesh.ARRAY_VERTEX]
	var fn: PackedVector3Array = farr[Mesh.ARRAY_NORMAL]
	var fuv: PackedVector2Array = farr[Mesh.ARRAY_TEX_UV]
	var outward := true
	for k in fpos.size():
		var cx := 0.06 * sin(PI * fpos[k].y)
		if fn[k].dot(Vector3(fpos[k].x - cx, 0, fpos[k].z)) <= 0.0: outward = false
	check("funnel normals outward, UV up", outward and fuv[0].y == 0.0 and fuv[fuv.size() - 1].y == 1.0 and fpos[0].y < fpos[fpos.size() - 1].y, "")
	check("funnel wide top", fu["size"].x > 0.95, "top %.2f wide" % fu["size"].x)
	var rd := measure([[NewModels2.funnel_ring_disc(), I]])
	basic("funnel ring disc", rd, 200)
	check("ring disc flat", rd["size"].y < 0.001 and near(rd["size"].x, 1.99, 2.01), "")
	print("built and checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
