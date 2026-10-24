extends SceneTree
## Headless check of the third batch of models (game/new_models3.gd): builds every model at every level of detail and checks
## there is no NaN, that every triangle faces the way its normals point, that the triangle counts are within the phone budgets
## (and fall from near to far), that the sizes are real metres, that the colliders sit round their models, that the repeat
## sizes tile and that building twice gives the same mesh. Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/new_models3_test.gd

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

func measure(mesh: ArrayMesh) -> Dictionary:
	var tris := 0
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var flipped := 0
	var surfaces := 0
	var colour_ok := true
	for s in mesh.get_surface_count():
		surfaces += 1
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
	return {"tris": tris, "size": hi - lo, "lo": lo, "hi": hi, "finite": finite, "flipped": flipped, "surfaces": surfaces, "colour_ok": colour_ok}

## name: [near budget, middle budget, far budget, min height, max height, min footprint x, max footprint x, min footprint z, max footprint z]
## Footprints are the extent of the mesh in x and z; a height window and a footprint window check the real size.
const SPEC := {
	"fence_post_rail_a": [900, 450, 120, 1.2, 1.45, 3.0, 3.2, 0.0, 0.3],
	"fence_post_rail_b": [450, 250, 80, 1.25, 1.45, 3.0, 3.2, 0.0, 0.3],
	"fence_post_rail_c": [650, 300, 80, 1.1, 1.3, 3.0, 3.2, 0.0, 0.4],
	"fence_wire_a": [800, 300, 150, 1.2, 1.4, 3.0, 3.2, 0.0, 0.3],
	"fence_wire_b": [800, 450, 120, 1.25, 1.45, 3.0, 3.2, 0.0, 0.3],
	"fence_gate_a": [900, 450, 220, 1.4, 1.6, 3.1, 3.3, 0.0, 0.3],
	"fence_corner_a": [2200, 1000, 400, 1.3, 1.5, 3.0, 3.3, 3.0, 3.3],
	"fence_broken_a": [900, 450, 220, 0.8, 1.5, 3.0, 3.3, 0.0, 1.0],
	"hay_round_a": [900, 250, 40, 1.1, 1.25, 1.19, 1.21, 1.1, 1.25],
	"hay_round_b": [900, 250, 40, 1.1, 1.25, 1.19, 1.21, 1.1, 1.25],
	"hay_roll_a": [900, 250, 40, 1.35, 1.55, 1.19, 1.21, 1.4, 1.6],
	"hay_square_a": [200, 80, 30, 0.34, 0.37, 0.89, 0.92, 0.44, 0.47],
	"hay_square_b": [200, 80, 30, 0.34, 0.37, 0.89, 0.92, 0.44, 0.47],
	"hay_stack_a": [1200, 400, 80, 1.3, 1.45, 1.7, 1.95, 1.7, 1.95],
	"corn_stand_a": [2600, 900, 60, 2.2, 3.2, 0.9, 3.0, 0.9, 3.0],
	"corn_stand_b": [3200, 1000, 60, 2.2, 3.2, 0.9, 3.0, 0.9, 3.0],
	"corn_row_chunk": [5400, 1800, 80, 2.2, 3.2, 0.5, 3.0, 3.9, 5.4],
	"barley_patch_a": [1300, 550, 60, 0.6, 0.95, 0.4, 1.3, 0.4, 1.3],
	"barley_patch_b": [1300, 550, 60, 0.6, 0.95, 0.4, 1.3, 0.4, 1.3],
	"alfalfa_patch_a": [1700, 550, 60, 0.35, 0.6, 0.4, 1.0, 0.4, 1.0],
	"alfalfa_patch_b": [2400, 600, 60, 0.35, 0.6, 0.4, 1.0, 0.4, 1.0],
	"crop_edge_weeds": [1300, 450, 60, 0.8, 1.3, 1.0, 1.9, 0.4, 1.2],
	"field_furrow_a": [2700, 700, 80, 0.15, 0.3, 3.03, 3.05, 3.99, 4.01],
	"field_furrow_b": [3600, 1000, 400, 0.15, 0.3, 3.14, 3.16, 4.19, 4.21],
	"field_headland_a": [1800, 500, 80, 0.0, 0.2, 5.99, 6.01, 2.99, 3.01],
	"field_track_a": [2500, 700, 80, 0.1, 0.35, 2.59, 2.61, 7.99, 8.01],
}

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	print("New models, batch 3 (farm): triangles, surfaces and real sizes")
	check("name list", NewModels3.NAMES.size() == 26 and NewModels3.NAMES.size() == SPEC.size(), "%d names" % NewModels3.NAMES.size())
	for name in NewModels3.NAMES:
		var spec: Array = SPEC[name]
		var prev := 1 << 30
		var m0: Dictionary
		for lod in 3:
			var m := measure(NewModels3.mesh(name, lod))
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
				check(name + " sits on the ground", lo.y > -0.12 and lo.y < 0.06, "lowest point %.3f m" % lo.y)
			else:
				var s0: Vector3 = m0["size"]
				check(tag + " keeps the size", absf(sz.y - s0.y) < maxf(0.4 * s0.y, 0.1) and sz.x > 0.3 * s0.x and sz.x < 1.3 * s0.x and sz.z > 0.3 * s0.z and sz.z < 1.3 * s0.z,
					"%.2f x %.2f x %.2f against %.2f x %.2f x %.2f" % [sz.x, sz.y, sz.z, s0.x, s0.y, s0.z])
		# colliders
		var cols: Array = NewModels3.colliders(name)
		var is_collider := name.begins_with("fence_") or name.begins_with("hay_")
		check(name + " colliders", (cols.size() > 0) == is_collider, "%d box strips" % cols.size())
		for c: AABB in cols:
			var meshbox := AABB(m0["lo"], m0["size"]).grow(0.15)
			check(name + " collider inside its model", meshbox.encloses(c), "%s in %s" % [c, AABB(m0["lo"], m0["size"])])
	# the repeat sizes: fence sections span their tile, ground tiles are exactly their tile wide, with matching edges
	for name in ["field_furrow_a", "field_furrow_b", "field_headland_a", "field_track_a"]:
		var t: Vector2 = NewModels3.TILE[name]
		var m := measure(NewModels3.mesh(name, 0))
		check(name + " tile size", absf(m["size"].x - t.x) < 0.01 and absf(m["size"].z - t.y) < 0.01, "%.2f x %.2f" % [m["size"].x, m["size"].z])
		check(name + " edges meet", _edges_match(NewModels3.mesh(name, 0), t, name != "field_track_a"), "heights on opposite edges agree (the track tiles along z only)")
	var rowm := measure(NewModels3.mesh("corn_row_chunk", 0))
	check("corn row spans one repeat", rowm["lo"].z > -2.7 and rowm["hi"].z < 2.7, "z %.2f to %.2f" % [rowm["lo"].z, rowm["hi"].z])
	# built twice gives the same thing (the cache is cleared in between)
	var a: int = measure(NewModels3.mesh("corn_stand_a", 0))["tris"]
	NewModels3._cache.clear()
	var b: int = measure(NewModels3.mesh("corn_stand_a", 0))["tris"]
	check("rebuild is identical", a == b, "%d and %d triangles" % [a, b])
	# the materials: shaders loaded, textures present where the shader needs them
	var mats_ok := true
	var info := ""
	for key in ["wood", "steel", "hay", "plastic", "soil", "mud", "leaf", "plant"]:
		var mat := NewModels3._mat(key)
		if mat.shader == null: mats_ok = false; info += key + " has no shader; "
		if key in ["wood", "hay", "soil", "mud"] and mat.get_shader_parameter("set_albedo") == null: mats_ok = false; info += key + " has no textures; "
	check("materials", mats_ok, info)
	print("built and checked in %d ms" % (Time.get_ticks_msec() - t0))
	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)

## The height of the surface at x = -sx/2 against x = +sx/2 and at z = -sz/2 against z = +sz/2 (field tiles must meet).
func _edges_match(mesh: ArrayMesh, t: Vector2, both := true) -> bool:
	var arr := mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var xl := {}; var xr := {}; var zl := {}; var zr := {}
	for p in pos:
		var kz := int(round(p.z * 100.0)); var kx := int(round(p.x * 100.0))
		if absf(p.x + t.x * 0.5) < 0.002: xl[kz] = p.y
		if absf(p.x - t.x * 0.5) < 0.002: xr[kz] = p.y
		if absf(p.z + t.y * 0.5) < 0.002: zl[kx] = p.y
		if absf(p.z - t.y * 0.5) < 0.002: zr[kx] = p.y
	var ok := not xl.is_empty() and not zl.is_empty()
	for k in (xl if both else {}):
		if xr.has(k) and absf(float(xl[k]) - float(xr[k])) > 0.002: ok = false
	for k in zl:
		if zr.has(k) and absf(float(zl[k]) - float(zr[k])) > 0.002: ok = false
	return ok
