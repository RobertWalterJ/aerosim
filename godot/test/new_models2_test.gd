extends SceneTree
## Headless check of the second batch of models (game/new_models2.gd): builds every model, checks there is no NaN, that every
## triangle faces the way its normals point, that the triangle counts are within the phone budgets and that the sizes are
## real. Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models2_test.gd

var fails := 0
const TF := 0.025          # wheel flange depth below the tread

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
	# models4: the locomotive body (with its trucks) is at most 2500 triangles; every car body under 1500. The wheelsets come
	# in three levels: close (counted per wheelset), middle and far, and a whole vehicle on far wheels stays cheap.
	var wheels: Dictionary = tr["wheels"]
	for kind in ["locomotive", "boxcar", "hopper", "tanker", "flatcar", "flatcar_empty"]:
		var wd: Dictionary = wheels[kind]
		var parts: Array = [[tr[kind], I]]
		var far_parts: Array = [[tr[kind], I]]
		var mid_parts: Array = [[tr[kind], I]]
		for p: Vector3 in wd["positions"]:
			parts.append([wd["mesh"], Transform3D(Basis.IDENTITY, p)])
			mid_parts.append([wd["mesh_mid"], Transform3D(Basis.IDENTITY, p)])
			far_parts.append([wd["mesh_far"], Transform3D(Basis.IDENTITY, p)])
		var cm := measure(parts)
		var body := measure([[tr[kind], I]])
		var mid := measure(mid_parts)
		var far := measure(far_parts)
		var ws := measure([[wd["mesh"], I]])
		var nw := (wd["positions"] as PackedVector3Array).size()
		basic(kind + " body", body, (2500 if kind == "locomotive" else 1500))
		check(kind + " close", bool(cm["finite"]) and int(cm["flipped"]) == 0, "%d triangles with %d close wheelsets of %d" % [cm["tris"], nw, ws["tris"]])
		check(kind + " middle and far wheels", bool(mid["finite"]) and int(mid["flipped"]) == 0 and bool(far["finite"]) and int(far["flipped"]) == 0 and absf(float(far["lo"].y)) < 0.01 and int(far["tris"]) < int(body["tris"]) + nw * 60,
			"%d triangles on middle wheels, %d on far wheels" % [mid["tris"], far["tris"]])
		check(kind + " body clear of the rails", float(body["lo"].y) > 0.05, "lowest body point %.2f m above the rail" % body["lo"].y)
		if kind == "locomotive":
			check("locomotive size", near(cm["size"].z, 21.4, 22.2) and near(cm["hi"].y, 4.55, 4.8) and absf(float(cm["lo"].y) + TF) < 0.004, "%.2f m long, %.2f m high, flanges to %.3f" % [cm["size"].z, cm["hi"].y, cm["lo"].y])
		else:
			check(kind + " size", near(cm["size"].z, 15.0, 17.0) and cm["size"].x < 3.35 and absf(float(cm["lo"].y) + TF) < 0.004, "%.2f m long, %.2f wide, flanges to %.3f" % [cm["size"].z, cm["size"].x, cm["lo"].y])
	for kind in ["locomotive", "boxcar"]:
		var wd2: Dictionary = wheels[kind]
		var r: float = wd2["radius"]
		var wm2 := measure([[wd2["mesh"], I]])
		var dia := 1.016 if kind == "locomotive" else 0.9144
		check(kind + " wheelset", (wd2["positions"] as PackedVector3Array).size() == (6 if kind == "locomotive" else 4) and absf(2.0 * r - dia) < 0.002 and near(wm2["size"].y, 2.0 * r + 2.0 * TF - 0.002, 2.0 * r + 2.0 * TF + 0.002) and near(wm2["size"].x, 2.1, 2.2),
			"%d axles, wheel %.3f m across the tread, %.3f m over the flanges, %.2f m along the axle with the bearings" % [(wd2["positions"] as PackedVector3Array).size(), 2.0 * r, wm2["size"].y, wm2["size"].x])
		# the wheel itself, measured from its vertices: where the rim begins and ends across the track, where the full tread
		# radius runs, and the thin plate between the rim and the hub
		var arr := (wd2["mesh"] as ArrayMesh).surface_get_arrays(0)
		var rim_lo := INF; var rim_hi := 0.0; var tread_lo := INF; var tread_hi := 0.0; var plate_lo := INF; var plate_hi := 0.0
		for v: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var rad := Vector2(v.y, v.z).length(); var ax := absf(v.x)
			if ax > 1.0: continue
			if rad > r - 0.06: rim_lo = minf(rim_lo, ax); rim_hi = maxf(rim_hi, ax)
			if absf(rad - r) < 0.008: tread_lo = minf(tread_lo, ax); tread_hi = maxf(tread_hi, ax)
			if rad > 0.28 and rad < r - 0.14: plate_lo = minf(plate_lo, ax); plate_hi = maxf(plate_hi, ax)
		check(kind + " wheel tread", tread_lo > 0.7 and tread_hi < 0.84 and tread_hi - tread_lo < 0.16 and rim_hi - rim_lo < 0.16,
			"tread %.1f cm wide (%.3f to %.3f m from the centre line), rim with the flange %.1f cm" % [(tread_hi - tread_lo) * 100.0, tread_lo, tread_hi, (rim_hi - rim_lo) * 100.0])
		check(kind + " wheel flange inside the rails", rim_lo > 0.67 and rim_lo < NewModels2.TR_GAUGE * 0.5, "back of the flange %.3f m from the centre line (back to back %.3f m), rail head from %.4f m" % [rim_lo, 2.0 * rim_lo, NewModels2.TR_GAUGE * 0.5])
		check(kind + " wheel plate thin", plate_hi - plate_lo < 0.06, "the plate web spans %.1f cm across (dished)" % ((plate_hi - plate_lo) * 100.0))
	check("gauge", absf(float(tr["gauge"]) - 1.435) < 0.0005, "%.3f m" % tr["gauge"])
	check("wheel spin axis", tr["wheel_axis"] == Vector3.RIGHT, "")
	check("consist", (tr["consist"] as Array).size() == 13 and absf(float(tr["car_length"]) - 16.6) < 0.01, "%d entries" % (tr["consist"] as Array).size())
	var tm := measure([[NewModels2.track_section(), I]])
	basic("track section", tm, 400)
	check("track size", near(tm["size"].z, 19.99, 20.01) and absf(float(tm["hi"].y)) < 0.001 and near(tm["lo"].y, -0.63, -0.61), "%.2f m long, rail top %.3f, foot %.2f" % [tm["size"].z, tm["hi"].y, tm["lo"].y])
	# ---- helicopter and far airliner
	var hc := NewModels2.helicopter()
	var hmm := measure([[hc["body"], I], [hc["main_rotor"], Transform3D(Basis.IDENTITY, hc["rotor_pivot"])], [hc["tail_rotor"], Transform3D(Basis.IDENTITY, hc["tail_pivot"])]])
	basic("helicopter", hmm, 5000)
	var hb := measure([[hc["body"], I]])
	check("helicopter body", near(hb["size"].z, 10.8, 11.3) and absf(float(hb["lo"].y)) < 0.02 and near(hb["size"].x, 2.7, 3.0), "%.2f m long, %.2f m wide over the stabiliser, skids at %.3f" % [hb["size"].z, hb["size"].x, hb["lo"].y])
	var see_through := false
	for s in (hc["body"] as ArrayMesh).get_surface_count():
		var hm := (hc["body"] as ArrayMesh).surface_get_material(s) as StandardMaterial3D
		if hm and hm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and hm.albedo_color.a < 0.7: see_through = true
	check("helicopter cockpit glass see-through", see_through, "")
	var mr := measure([[hc["main_rotor"], I]])
	check("helicopter main rotor", near(mr["hi"].x, 5.05, 5.15) and mr["size"].y < 0.4 and near(mr["size"].z, 10.1, 10.3), "blade tip %.2f m from the hub, %.2f m across" % [mr["hi"].x, mr["size"].z])
	var trm := measure([[hc["tail_rotor"], I]])
	check("helicopter tail rotor", near(trm["size"].y, 1.9, 1.98) and trm["size"].x < 0.2, "%.2f m across, %.2f m thick along +x" % [trm["size"].y, trm["size"].x])
	var tp: Vector3 = hc["tail_pivot"]
	check("helicopter tail rotor clears the boom and ground", tp.y - float(hc["tail_radius"]) > 1.5 and tp.x < -0.2, "lowest tip %.2f m up, hub %.2f m left of the fin" % [tp.y - float(hc["tail_radius"]), -tp.x])
	for gear in [false, true]:
		var al := NewModels2.airliner_far(gear)
		var am := measure([[al["mesh"], I]])
		basic("airliner gear %s" % ("down" if gear else "up"), am, 2200)
		check("airliner size %s" % gear, near(am["size"].z, 37.8, 38.2) and near(am["size"].x, 33.6, 34.4) and absf(float(am["size"].x) - float(al["wingspan"])) < 0.15,
			"%.2f m long, %.2f m span (wingspan key %.2f), %.2f m high" % [am["size"].z, am["size"].x, al["wingspan"], am["size"].y])
		if gear:
			check("airliner gear reaches down", float(am["lo"].y) < -4.0, "wheels down to %.2f m below the fuselage axis" % am["lo"].y)
		var af := measure([[al["mesh_far"], I]])
		basic("airliner far mesh", af, 320)
		check("airliner far outline", near(af["size"].z, 37.8, 38.2) and near(af["size"].x, 33.6, 34.4), "%.2f x %.2f m" % [af["size"].z, af["size"].x])
	# ---- kites and flag
	for kind in 2:
		var km := measure([[NewModels2.kite(kind), I]])
		basic("kite %d" % kind, km, 120)
		check("kite %d span" % kind, near(km["size"].x, 0.95, 1.05), "%.2f m across" % km["size"].x)
	var lnm := measure([[NewModels2.kite_line(), I]])
	check("kite line", near(lnm["size"].z, 0.999, 1.001) and int(lnm["tris"]) == 4, "%.3f m along +z, %d tris" % [lnm["size"].z, lnm["tris"]])
	for sc in 5:
		var fl := NewModels2.flag(sc)
		var fm := measure([[fl["pole"], I], [fl["cloth"], Transform3D(Basis.IDENTITY, fl["cloth_origin"])]])
		var cl := measure([[fl["cloth"], I]])
		var arr := (fl["cloth"] as ArrayMesh).surface_get_arrays(0)
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var cps: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv_ok := true
		for k in uvs.size():
			var uvk := uvs[k]
			if uvk.x < -0.001 or uvk.x > 1.001 or uvk.y < -0.001 or uvk.y > 1.001: uv_ok = false
			# UV follows the cloth: x / 1.8 along the fly (the hoist rope sits just outside x = 0)
			if cps[k].x > 0.0 and absf(uvk.x - cps[k].x / 1.8) > 0.002: uv_ok = false
		basic("flag %d" % sc, fm, 6000)
		check("flag %d cloth" % sc, int(cl["tris"]) >= 2 * 40 * 24 and uv_ok and near(cl["size"].x, 1.8, 1.83) and near(cl["size"].y, 0.9, 1.1) and cl["size"].z < 0.1 and int(cl["flipped"]) == 0,
			"%d tris, %d vertices, UV ok %s, %.2f x %.2f m, %.3f m deep at rest" % [cl["tris"], uvs.size(), uv_ok, cl["size"].x, cl["size"].y, cl["size"].z])
		if sc == 0:
			var pm2 := measure([[fl["pole"], I]])
			check("flag pole", near(pm2["hi"].y, 9.1, 9.2) and absf(float(pm2["lo"].y)) < 0.01 and int(pm2["tris"]) < 1500, "%.2f m to the top of the ball, %d tris" % [pm2["hi"].y, pm2["tris"]])
			check("flag grid key", fl["grid"] == Vector2i(40, 24), "")
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
