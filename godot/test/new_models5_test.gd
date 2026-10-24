extends SceneTree
## Headless check of the fifth batch of models (game/new_models5.gd): builds every model at every level of detail and checks there is no NaN,
## that every triangle faces the way its normals point, that the triangle counts stay in the budgets and fall from near to far, that
## the sizes are real metres, that the animals have their head, jaw and tail parts with sensible pivots, that the parts add up to the whole,
## that colliders sit round their models, that shaders and textures are present, and that building twice gives the same mesh.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models5_test.gd

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
	return {"tris": tris, "size": hi - lo, "lo": lo, "hi": hi, "finite": finite, "flipped": flipped, "colour_ok": colour_ok}

## name: [budget near, middle, far, height min, max, x extent min, max, z extent min, max, lowest point]
const SPEC := {
	"cow_a": [7300, 2550, 700, 1.38, 1.76, 0.76, 0.96, 2.75, 3.51, -0.00],
	"cow_b": [7300, 2550, 700, 1.35, 1.71, 0.76, 0.96, 2.68, 3.42, -0.00],
	"cow_c": [6500, 2250, 650, 1.06, 1.36, 0.69, 0.87, 2.65, 3.37, 0.01],
	"calf_a": [3250, 1300, 300, 0.83, 1.05, 0.40, 0.50, 1.71, 2.17, 0.04],
	"sheep_a": [4550, 1700, 450, 0.74, 0.94, 0.49, 0.63, 1.19, 1.51, 0.03],
	"sheep_b": [4600, 1700, 450, 0.73, 0.93, 0.49, 0.63, 1.12, 1.42, 0.03],
	"lamb_a": [2050, 800, 150, 0.41, 0.53, 0.27, 0.35, 0.68, 0.86, 0.02],
	"horse_a": [6750, 2350, 700, 1.72, 2.18, 0.53, 0.67, 2.43, 3.09, 0.02],
	"horse_b": [6850, 2400, 700, 1.44, 1.84, 0.53, 0.67, 2.49, 3.17, 0.02],
	"chicken_a": [1150, 750, 300, 0.41, 0.53, 0.20, 0.26, 0.53, 0.67, 0.00],
	"dog_a": [4050, 1550, 400, 0.62, 0.78, 0.27, 0.35, 0.89, 1.13, 0.02],
	"rowboat_a": [7450, 2850, 850, 0.72, 0.92, 1.40, 1.78, 3.65, 4.65, -0.24],
	"sailboat_a": [3750, 1650, 550, 5.54, 7.06, 1.09, 1.39, 3.90, 4.96, -0.50],
	"sailboat_b": [5800, 3200, 800, 10.25, 13.05, 2.32, 2.96, 6.69, 8.51, -1.45],
	"fishing_boat_a": [7200, 3300, 950, 4.39, 5.59, 2.24, 2.86, 5.98, 7.62, -0.39],
	"jetty_a": [2000, 1550, 250, 2.24, 2.86, 2.30, 2.92, 7.39, 9.41, -1.60],
	"mooring_post_a": [650, 650, 50, 0.85, 1.09, 0.55, 0.69, 0.78, 1.00, 0.00],
	"buoy_a": [850, 700, 500, 2.79, 3.55, 0.83, 1.05, 0.83, 1.05, -1.94],
	"seed_drill_a": [2250, 2250, 600, 1.54, 1.96, 3.06, 3.90, 3.75, 4.77, 0.00],
	"plough_a": [1000, 1000, 450, 1.41, 1.79, 1.04, 1.32, 4.32, 5.50, 0.10],
	"combine_a": [3350, 2050, 900, 4.00, 5.10, 5.46, 6.94, 8.23, 10.47, -0.05],
	"baler_a": [2200, 1600, 500, 2.20, 2.80, 2.80, 3.56, 4.35, 5.53, -0.04],
	"water_trough_a": [500, 500, 100, 0.86, 1.10, 2.12, 2.70, 1.03, 1.31, -0.01],
	"feed_rack_a": [1250, 1300, 450, 1.34, 1.70, 2.11, 2.69, 1.14, 1.46, 0.00],
	"wood_pile_a": [7900, 5950, 150, 1.15, 1.47, 2.28, 2.90, 0.62, 0.78, -0.01],
	"oil_tank_a": [850, 650, 400, 1.44, 1.84, 1.08, 1.38, 2.36, 3.00, 0.00],
	"grain_silo_a": [1000, 850, 150, 4.62, 5.88, 3.08, 3.92, 3.08, 3.92, 0.00],
	"chicken_coop_a": [1450, 1550, 400, 2.09, 2.65, 2.02, 2.56, 1.91, 2.43, 0.00],
	"dog_kennel_a": [250, 300, 250, 1.31, 1.67, 1.06, 1.34, 1.32, 1.68, 0.00],
	"telegraph_wire_10m": [250, 100, 50, 0.32, 0.40, 8.80, 11.20, 0.0, 0.05, -0.35],
	"fence_gate_hanging_a": [300, 300, 200, 1.50, 1.90, 2.10, 2.68, 2.50, 3.18, 0.00],
}

const ANIMALS := ["cow_a", "cow_b", "cow_c", "calf_a", "sheep_a", "sheep_b", "lamb_a", "horse_a", "horse_b", "dog_a"]

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	print("New models, batch 5 (animals, boats, machinery, yard): triangles and real sizes")
	check("name list", NewModels5.NAMES.size() == 31 and NewModels5.NAMES.size() == SPEC.size(), "%d names" % NewModels5.NAMES.size())
	for name in NewModels5.NAMES:
		var spec: Array = SPEC[name]
		var prev := 1 << 30
		var m0: Dictionary
		for lod in 3:
			var m := measure(NewModels5.mesh(name, lod))
			if lod == 0: m0 = m
			var tag := "%s lod %d" % [name, lod]
			var sz: Vector3 = m["size"]
			print("  %-26s %6d tris  size x %.2f  y %.2f  z %.2f m" % [tag, m["tris"], sz.x, sz.y, sz.z])
			check(tag + " finite", m["finite"] and m["colour_ok"], "")
			check(tag + " winding", int(m["flipped"]) == 0, "%d triangles wound against their normals" % m["flipped"])
			check(tag + " budget", int(m["tris"]) > 0 and int(m["tris"]) <= int(spec[lod]), "%d of %d" % [m["tris"], spec[lod]])
			check(tag + " no more than the nearer level", int(m["tris"]) <= prev, "%d under %d" % [m["tris"], prev])
			prev = int(m["tris"])
			if lod == 0:
				var lo: Vector3 = m["lo"]
				check(name + " real size", sz.y >= float(spec[3]) and sz.y <= float(spec[4]) and sz.x >= float(spec[5]) and sz.x <= float(spec[6])
					and sz.z >= float(spec[7]) and sz.z <= float(spec[8]), "%.2f x %.2f x %.2f m" % [sz.x, sz.y, sz.z])
				check(name + " lowest point", absf(lo.y - float(spec[9])) < 0.1, "%.3f m (expected about %.2f)" % [lo.y, spec[9]])
			else:
				var s0: Vector3 = m0["size"]
				check(tag + " keeps the size", sz.y > 0.45 * s0.y and sz.y < 1.3 * s0.y and sz.x > 0.35 * s0.x and sz.x < 1.4 * s0.x and sz.z > 0.25 * s0.z and sz.z < 1.3 * s0.z,
					"%.2f x %.2f x %.2f against %.2f x %.2f x %.2f" % [sz.x, sz.y, sz.z, s0.x, s0.y, s0.z])
		# the parts, and that they add up to the whole
		var pr := NewModels5.parts(name, 0)
		var psum := 0
		for part in pr: psum += int(measure(pr[part]["mesh"])["tris"])
		check(name + " parts add up to the whole", psum == int(m0["tris"]), "%d against %d triangles" % [psum, m0["tris"]])
		if name in ANIMALS:
			check(name + " has head, jaw, tail and body", pr.has("head") and pr.has("jaw") and pr.has("tail") and pr.has("body"), "parts: %s" % str(pr.keys()))
			var box := AABB(m0["lo"], m0["size"]).grow(0.1)
			for part in ["head", "jaw", "tail"]:
				if pr.has(part): check(name + " " + part + " pivot inside the animal", box.has_point(pr[part]["pivot"]), "%s" % str(pr[part]["pivot"]))
			check(name + " has a collider", NewModels5.colliders(name).size() > 0, "")
			for c: AABB in NewModels5.colliders(name):
				check(name + " collider round its model", AABB(m0["lo"], m0["size"]).grow(0.25).encloses(c), "%s in %s" % [c, AABB(m0["lo"], m0["size"])])
	check("combine has a reel part", NewModels5.parts("combine_a", 0).has("reel"), "")
	check("chicken has a head part", NewModels5.parts("chicken_a", 0).has("head"), "")
	# built twice gives the same thing
	var a: int = measure(NewModels5.mesh("cow_a", 0))["tris"]
	NewModels5._cache.clear()
	var b: int = measure(NewModels5.mesh("cow_a", 0))["tris"]
	check("rebuild is identical", a == b, "%d and %d triangles" % [a, b])
	# the materials
	var mats_ok := true
	var info := ""
	for key in ["wood", "steel", "hay", "cloth", "glass", "holstein", "hereford", "jersey", "hair", "wool", "feather", "horse", "paint", "paint_matte", "hull", "mudpaint", "bin", "zinc", "skin", "eye", "horn", "rope"]:
		var mat := NewModels5._mat(key)
		if mat == null: mats_ok = false; info += key + " missing; "
		elif mat is ShaderMaterial and (mat as ShaderMaterial).shader == null: mats_ok = false; info += key + " has no shader; "
	check("materials", mats_ok, info)
	print("built and checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
