extends SceneTree
## Headless check of the fourth batch of models (game/new_models4.gd, new_models4_big.gd, new_models4_props.gd): builds every
## model at every level of detail and checks there is no NaN, that every triangle faces the way its normals point, that the
## triangle counts are within budget (and fall from near to far), that the sizes are real metres, that vehicles have the right
## wheels (named, on the ground, outer faces at the model's width, left and right apart, spinning about x), that the
## colliders sit round their models and that building twice gives the same mesh. Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models4_test.gd

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

func measure(mesh: ArrayMesh) -> Dictionary:
	var tris := 0
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var flipped := 0
	var colour_ok := true
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var col = arr[Mesh.ARRAY_COLOR]
		if col == null or (col as PackedColorArray).size() != pos.size(): colour_ok = false
		tris += pos.size() / 3
		for k in pos.size():
			var p := pos[k]
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): finite = false
			lo = lo.min(p); hi = hi.max(p)
		for n in nrm:
			if not (is_finite(n.x) and is_finite(n.y) and is_finite(n.z)): finite = false
		for k in range(0, pos.size(), 3):
			var f := (pos[k + 1] - pos[k]).cross(pos[k + 2] - pos[k])
			var n := nrm[k] + nrm[k + 1] + nrm[k + 2]
			if f.dot(n) > 1e-9 * f.length() * n.length() and f.length_squared() > 1e-16: flipped += 1
	return {"tris": tris, "size": hi - lo, "lo": lo, "hi": hi, "finite": finite, "flipped": flipped, "surfaces": mesh.get_surface_count(), "colour_ok": colour_ok}

## name: [near budget, middle budget, far budget, height min, max, width (x) min, max, length (z) min, max]
const SPEC := {
	"car_hatch_a": [9000, 5000, 1300, 1.4, 1.8, 1.8, 2.4, 3.95, 4.35],
	"car_hatch_b": [9000, 5000, 1300, 1.4, 1.8, 1.85, 2.5, 4.25, 4.65],
	"car_estate_a": [9500, 5200, 1300, 1.45, 1.85, 1.9, 2.5, 4.65, 5.05],
	"pickup_a": [10000, 5600, 1400, 1.75, 2.1, 2.05, 2.8, 5.25, 5.6],
	"pickup_b": [10000, 5600, 1400, 1.65, 2.0, 1.9, 2.6, 4.85, 5.2],
	"van_a": [9500, 5000, 1300, 2.05, 2.35, 2.05, 2.8, 5.25, 5.6],
	"van_b": [9500, 5000, 1300, 1.85, 2.15, 1.85, 2.6, 4.35, 4.7],
	"tractor_a": [12000, 7500, 3000, 2.85, 3.3, 2.3, 2.8, 4.5, 5.2],
	"tractor_wheels_a": [7000, 5000, 1700, 1.6, 1.8, 2.3, 2.5, 2.4, 4.3],
	"tractor_trailer_a": [14000, 6500, 2700, 1.9, 2.3, 2.3, 3.4, 6.2, 7.0],
	"milk_tanker_a": [21000, 10000, 4200, 3.2, 3.8, 2.4, 3.2, 9.0, 9.9],
	"bus_a": [13000, 6000, 2800, 3.0, 3.5, 2.4, 3.6, 10.4, 11.2],
	"motorcycle_a": [7000, 3400, 1700, 1.1, 1.5, 0.7, 1.2, 2.0, 2.4],
	"telegraph_pole_a": [6000, 3000, 900, 8.5, 9.0, 1.9, 2.2, 0.2, 0.4],
	"telegraph_pole_b": [6000, 3000, 900, 10.2, 11.0, 2.4, 2.8, 0.3, 0.6],
	"power_pylon_a": [24000, 8000, 2500, 33.0, 36.0, 10.0, 12.0, 5.0, 8.0],
	"power_pylon_b": [8000, 3500, 1000, 18.5, 20.5, 5.0, 6.0, 1.0, 2.0],
	"road_sign_bend_a": [900, 400, 200, 2.5, 3.0, 0.9, 1.2, 0.05, 0.3],
	"road_sign_junction_a": [900, 400, 200, 2.5, 3.0, 0.9, 1.2, 0.05, 0.3],
	"road_sign_speed_a": [900, 400, 200, 2.3, 2.7, 0.5, 0.8, 0.05, 0.3],
	"road_marker_a": [300, 150, 80, 1.05, 1.2, 0.05, 0.14, 0.05, 0.14],
	"cattle_grid_a": [2500, 1500, 700, 0.0, 0.2, 3.5, 4.4, 2.3, 3.4],
	"field_gate_a": [2500, 1200, 500, 1.4, 1.7, 3.5, 4.0, 0.1, 0.5],
	"field_gate_b": [2500, 1200, 500, 1.4, 1.7, 3.7, 4.1, 0.1, 0.5],
	"bus_shelter_a": [2500, 1200, 600, 2.4, 2.8, 3.0, 4.2, 1.4, 2.0],
	"post_box_a": [800, 400, 200, 1.2, 1.5, 0.1, 0.4, 0.5, 1.3],
	"road_works_a": [4000, 2200, 1000, 0.9, 1.9, 3.0, 4.4, 1.7, 3.0],
	"milestone_a": [1500, 600, 150, 0.85, 1.0, 0.3, 0.6, 0.2, 0.4],
	"road_bridge_rail_a": [1200, 600, 300, 1.05, 1.25, 3.9, 4.4, 0.35, 0.5],
}

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	Grass.add_globals()
	for name in NewModels4.NAMES:
		var spec: Array = SPEC[name]
		var prev := 1 << 30
		var m0: Dictionary
		for lod in 3:
			var m := measure(NewModels4.mesh(name, lod))
			if lod == 0: m0 = m
			var tag := "%s lod %d" % [name, lod]
			var sz: Vector3 = m["size"]
			print("  %-26s %6d tris  %d surfaces  size x %.2f  y %.2f  z %.2f m" % [tag, m["tris"], m["surfaces"], sz.x, sz.y, sz.z])
			check(tag + " finite", m["finite"] and m["colour_ok"], "")
			check(tag + " winding", int(m["flipped"]) == 0, "%d triangles wound against their normals" % m["flipped"])
			check(tag + " budget", int(m["tris"]) > 0 and int(m["tris"]) <= int(spec[lod]), "%d of %d" % [m["tris"], spec[lod]])
			check(tag + " fewer than the nearer level", int(m["tris"]) < prev, "%d under %d" % [m["tris"], prev])
			prev = int(m["tris"])
			if lod == 0:
				var hi: Vector3 = m["hi"]; var lo: Vector3 = m["lo"]
				check(name + " real size", hi.y >= float(spec[3]) and hi.y <= float(spec[4]) and sz.x >= float(spec[5]) and sz.x <= float(spec[6])
					and sz.z >= float(spec[7]) and sz.z <= float(spec[8]), "height %.2f, %.2f x %.2f m" % [hi.y, sz.x, sz.z])
				check(name + " sits on the ground", lo.y > -0.3 and lo.y < 0.06, "lowest point %.3f m" % lo.y)
			else:
				var s0: Vector3 = m0["size"]
				check(tag + " keeps the size", absf(sz.y - s0.y) < maxf(0.4 * s0.y, 0.1) and sz.x > 0.3 * s0.x and sz.x < 1.3 * s0.x and sz.z > 0.3 * s0.z and sz.z < 1.3 * s0.z,
					"%.2f x %.2f x %.2f against %.2f x %.2f x %.2f" % [sz.x, sz.y, sz.z, s0.x, s0.y, s0.z])
		var cols: Array = NewModels4.colliders(name)
		var wants_col := name != "tractor_wheels_a" and name != "cattle_grid_a"
		check(name + " colliders", (cols.size() > 0) == wants_col, "%d box strips" % cols.size())
		for c: AABB in cols:
			var meshbox := AABB(m0["lo"], m0["size"]).grow(0.2)
			check(name + " collider inside its model", meshbox.encloses(c), "%s in %s" % [c, AABB(m0["lo"], m0["size"])])
	# vehicles: the wheels
	for name in NewModels4.CARS + NewModels4.BIG:
		if name == "tractor_wheels_a": continue
		for lod in 3:
			var v := NewModels4.vehicle(name, lod)
			var ws: Array = v["wheels"]
			var want := 2 if name == "motorcycle_a" else (6 if name == "milk_tanker_a" else 4)
			check("%s lod %d wheels" % [name, lod], ws.size() == want, "%d wheels" % ws.size())
			var names := {}
			var ok := true
			var info := ""
			for w: Dictionary in ws:
				names[w["name"]] = true
				var pos: Vector3 = w["pos"]
				var R: float = w["radius"]
				if absf(pos.y - R) > 0.01: ok = false; info += "%s hub at %.2f not %.2f; " % [w["name"], pos.y, R]
				var wm := measure(w["mesh"])
				var lo: Vector3 = wm["lo"]; var hi: Vector3 = wm["hi"]
				if absf(hi.y - R) > (0.03 if lod == 0 else 0.1 * R + 0.02) and absf(hi.y) > 0.0: ok = false; info += "%s radius %.3f not %.3f; " % [w["name"], hi.y, R]
				var outward := (-lo.x if pos.x < -0.01 else hi.x)
				var inward := (hi.x if pos.x < -0.01 else -lo.x)
				if pos.x != 0.0 and outward < inward: ok = false; info += "%s faces inward; " % w["name"]
				if wm["flipped"] != 0 or not wm["finite"]: ok = false; info += "%s bad mesh; " % w["name"]
			check("%s lod %d wheels on the ground and facing out" % [name, lod], ok and names.size() == ws.size(), info)
		# the node builder gives named pivots
		var node := NewModels4.build_node(name, 0)
		var found := true
		for w: Dictionary in NewModels4.vehicle(name, 0)["wheels"]:
			if node.get_node_or_null(NodePath(String(w["name"]))) == null: found = false
		check(name + " build_node has its wheel pivots", found and node.get_node_or_null("Body") != null, "")
		node.free()
	# built twice gives the same thing
	var a: int = measure(NewModels4.mesh("car_hatch_a", 0))["tris"]
	NewModels4._cache.clear(); NewModels4._veh.clear()
	var b: int = measure(NewModels4.mesh("car_hatch_a", 0))["tris"]
	check("rebuild is identical", a == b, "%d and %d triangles" % [a, b])
	# the wire attachment points sit on the poles and pylons
	for name in ["telegraph_pole_a", "telegraph_pole_b", "power_pylon_a", "power_pylon_b"]:
		var pts: Array = NewModels4Props.attachments(name)
		var mb := measure(NewModels4.mesh(name, 0))
		var box := AABB(mb["lo"], mb["size"]).grow(0.5)
		var ok2 := pts.size() >= 3
		for q: Vector3 in pts: if not box.has_point(q): ok2 = false
		check(name + " wire attachment points", ok2, "%d points" % pts.size())
	# materials load
	var mats_ok := true
	for key in ["paint", "rubber", "metal", "glass", "trim", "lens", "sheet", "concrete"]:
		var mat := NewModels4._mat(key) as ShaderMaterial
		if mat == null or mat.shader == null: mats_ok = false
	check("materials", mats_ok, "")
	print("built and checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
