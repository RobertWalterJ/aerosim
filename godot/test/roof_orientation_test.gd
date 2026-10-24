extends SceneTree
## Headless geometry test for every roofed model in the game: is the roof the right way up, facing up, and sitting on its walls?
## Godot --headless --path <godot dir> -s res://test/roof_orientation_test.gd [-- only=<name prefix>] [-- fixtures] [-- verbose]
##
## For each model the triangles are read from the shipped file (a .glb is parsed with GLTFDocument, so it is the file the game
## loads, not the code that wrote it) or, for the in-code farm buildings, from the mesh the game builds. Then:
##  1. RIDGE ABOVE EAVES. A height field of the top surface (the highest non-vertical triangle over each 0.1 m cell) is taken
##     across the ridge (the axis along which the roof height changes most) as a median profile. A roof that is upside down
##     (the two pitches meeting in a V, ridge lower than the eaves) has a profile whose middle is lower than both its ends; that
##     fails. A gable, hip, cone, tent or single-pitch roof does not.
##  2. ROOF FACES UP. Over the roof cells, the top triangle's stored normal must point up (n.y > 0) and its winding must agree
##     with that normal (so it is not back-face culled from above).
##  3. ROOF SITS ON THE WALLS. Under the roof, at every cell a wall passes through, the gap from the top of the wall up to the
##     nearest roof surface above it is measured (the smallest within 0.35 m, as a pitched roof bears on the outer edge of a
##     thick wall). The sloped roof triangles are split into connected pieces (shared corners); every piece of more than
##     0.4 m2 must rest on its walls (a gap under 0.15 m in at least three cells: the eaves line or a gable top in contact)
##     or stand on the flat top of another part (a spire on a tower), or, if small or narrow (gutter, ridge tiles, a cap),
##     touch other geometry within 6 cm. A roof hovering over its walls, or a loose piece in the air, fails.
## `fixtures` also runs the three files in test/fixtures/roof_broken/ (made from the models8 code with the pitch sign flipped,
## and with the roof lifted 0.6 m), which must FAIL; the run fails if any of them passes. That is the proof the test catches
## the bug Robert saw.

const CELL := 0.1
const GAP_TOL := 0.15
const VALLEY_TOL := 0.25

## [name, source, note]. source: "story" (assets/models/story/<group>/<name>.glb), "res://...glb", or "code:<what>".
const MODELS := [
	["town_police_house_a", "story", ""], ["town_police_house_a_open", "story", ""], ["town_pub_a", "story", ""],
	["town_village_hall_a", "story", ""], ["town_shop_a", "story", ""], ["town_shop_b", "story", ""],
	["town_bakery_a", "story", ""], ["town_chip_shop_a", "story", ""], ["town_church_a", "story", ""],
	["town_school_a", "story", ""], ["garage_shell_a", "story", ""], ["town_bus_shelter_a", "story", "mono"],
	["cabin_abandoned_a", "story", ""], ["cabin_abandoned_a_broken_roof", "story", "holed"], ["cabin_lean_to_a", "story", "mono"],
	["storm_rail_hut_a", "story", ""], ["festival_marquee_a", "story", "tent"], ["festival_stage_a", "story", "canopy"],
	["festival_stall_a", "story", "canopy"], ["festival_stall_a_b", "story", "canopy"], ["festival_toilet_a", "story", "mono"],
	["camp_tent_a", "story", "tent"], ["camp_tent_a_open", "story", "tent"], ["camp_tent_b", "story", "tent"],
	["wren_tent_a", "story", "tent"],
	["barn", "code:barn", ""], ["silo", "code:silo", "skirted"],
	["chicken_coop_a", "code:nm5", ""], ["dog_kennel_a", "code:nm5", ""], ["grain_silo_a", "code:nm5", "cone"],
	["bus_shelter_a", "code:nm4", "mono"],
	["park_chapel", "code:park_chapel", ""],
]
## Variants and levels of detail checked too (same rules).
const LOD_NAMES := ["town_police_house_a", "town_pub_a", "town_village_hall_a", "town_shop_a", "town_shop_b", "town_bakery_a",
	"town_chip_shop_a", "town_church_a", "town_school_a", "garage_shell_a", "cabin_abandoned_a", "cabin_abandoned_a_broken_roof"]

const FIXTURES := ["res://test/fixtures/roof_broken/town_police_house_a_v.glb", "res://test/fixtures/roof_broken/town_village_hall_a_v.glb",
	"res://test/fixtures/roof_broken/garage_shell_a_v.glb", "res://test/fixtures/roof_broken/town_shop_a_float.glb"]

var _verbose := false
var _wind_sign := 1.0

func _initialize() -> void:
	var only := ""
	var fixtures := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = a.substr(5)
		if a == "fixtures": fixtures = true
		if a == "verbose": _verbose = true
	Grass.add_globals()
	_wind_sign = _reference_winding()
	var fails := 0
	var n := 0
	for e in MODELS:
		var nm: String = e[0]
		if only != "" and not nm.begins_with(only): continue
		var srcs: Array = [[nm, _source(nm, e[1], 0)]]
		if nm in LOD_NAMES:
			for lod in [1, 2]:
				var p := _source(nm, e[1], lod)
				if p != "" and FileAccess.file_exists(ProjectSettings.globalize_path(p)): srcs.append(["%s_lod%d" % [nm, lod], p])
		for s in srcs:
			var tris := _load(s[1], nm)
			if tris.is_empty():
				print("FAIL %-34s no geometry (%s)" % [s[0], s[1]])
				fails += 1
				continue
			var r := check(tris, e[2])
			n += 1
			if not r["ok"]: fails += 1
			print("%s %-34s %s" % ["ok  " if r["ok"] else "FAIL", s[0], r["msg"]])
	var fx_bad := 0
	if fixtures:
		print("-- broken fixtures (each must FAIL) --")
		for f in FIXTURES:
			var tris2 := _load(f, "")
			if tris2.is_empty():
				print("MISSING ", f); fx_bad += 1; continue
			var r2 := check(tris2, "")
			print("%s %-34s %s" % ["caught" if not r2["ok"] else "MISSED", f.get_file(), r2["msg"]])
			if r2["ok"]: fx_bad += 1
	print("roof orientation test: %d models, %d failures%s" % [n, fails, ("" if not fixtures else ", %d broken fixtures not caught" % fx_bad)])
	var pass_ok := fails == 0 and fx_bad == 0
	print("RESULT: PASS" if pass_ok else "RESULT: FAIL")
	quit(0 if pass_ok else 1)

func _source(nm: String, src: String, lod: int) -> String:
	if src == "story": return StoryAssets.path_of(nm, lod)
	if src.begins_with("res://"): return src
	return src if lod == 0 else ""

# ------------------------------------------------------------------ loading triangles: Array of [a, b, c, n_stored]
func _load(src: String, nm: String) -> Array:
	var out: Array = []
	if src.begins_with("code:"):
		var what := src.substr(5)
		match what:
			"barn": _add_mesh(out, NewModels2.barn(), Transform3D.IDENTITY)
			"silo": _add_mesh(out, NewModels2.silo(), Transform3D.IDENTITY)
			"nm5": _add_mesh(out, NewModels5.mesh(nm, 0), Transform3D.IDENTITY)
			"nm4": _add_mesh(out, NewModels4.mesh(nm, 0), Transform3D.IDENTITY)
			"park_chapel": _park_chapel(out)
		return out
	var abs := ProjectSettings.globalize_path(src)
	if not FileAccess.file_exists(abs): return out
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(abs, st) != OK: return out
	var root := doc.generate_scene(st)
	if root == null: return out
	_walk(root, Transform3D.IDENTITY, out)
	root.free()
	return out

func _walk(n: Node, xf: Transform3D, out: Array) -> void:
	var x2 := xf
	if n is Node3D: x2 = xf * (n as Node3D).transform
	var nm := String(n.name)
	if nm.ends_with("-colonly") or nm.begins_with("hull"): return
	if n is ImporterMeshInstance3D and (n as ImporterMeshInstance3D).mesh != null:
		_add_mesh(out, (n as ImporterMeshInstance3D).mesh.get_mesh(), x2)
	elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		_add_mesh(out, (n as MeshInstance3D).mesh, x2)
	for c in n.get_children(): _walk(c, x2, out)

func _add_mesh(out: Array, m: Mesh, xf: Transform3D) -> void:
	if m == null: return
	var nb := xf.basis.inverse().transposed()
	for s in m.get_surface_count():
		if m.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var has_n: bool = nr != null and (nr as PackedVector3Array).size() == v.size()
		var count: int = (idx as PackedInt32Array).size() if idx != null else v.size()
		# a two-sided material (canvas, tarp, cloth) is lit from whichever side faces the eye, so its facing is not checked
		var mat := m.surface_get_material(s)
		var dbl := mat is BaseMaterial3D and (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
		for t in range(0, count, 3):
			var i0: int = idx[t] if idx != null else t
			var i1: int = idx[t + 1] if idx != null else t + 1
			var i2: int = idx[t + 2] if idx != null else t + 2
			var a := xf * v[i0]; var b := xf * v[i1]; var c := xf * v[i2]
			var ns := Vector3.ZERO
			if has_n: ns = (nb * ((nr[i0] + nr[i1] + nr[i2]) as Vector3)).normalized()
			out.append([a, b, c, ns, dbl])

## The park chapel (park.glb, from src/world/MemorialParkAssets.ts) cut out of the park around the layout's chapel position.
func _park_chapel(out: Array) -> void:
	var lay = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/layout.json"))
	if lay == null or not lay.has("chapel"): return
	var cp: Array = lay["chapel"]
	var c := Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
	var all: Array = []
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://assets/world/park.glb"), st) != OK: return
	var root := doc.generate_scene(st)
	_walk(root, Transform3D.IDENTITY, all)
	root.free()
	for t in all:
		var m: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		if Vector2(m.x - c.x, m.z - c.z).length() < 9.0 and m.y > c.y - 2.0 and m.y < c.y + 20.0:
			out.append([t[0] - c, t[1] - c, t[2] - c, t[3], t[4]])

## The sign of dot(cross(b - a, c - a), n) for a Godot BoxMesh: the winding the renderer treats as front.
func _reference_winding() -> float:
	var bm := BoxMesh.new()
	var arr := bm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]; var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var s := 0.0
	for t in range(0, idx.size(), 3):
		s += signf((v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).dot(nr[idx[t]]))
	return signf(s)

# ------------------------------------------------------------------ the checks
func check(tris: Array, note: String) -> Dictionary:
	var lo := Vector3(INF, INF, INF); var hi := -lo
	for t in tris:
		for k in 3:
			lo = lo.min(t[k]); hi = hi.max(t[k])
	var H := hi.y - maxf(lo.y, 0.0)
	var nx := clampi(int(ceil((hi.x - lo.x) / CELL)), 1, 400)
	var nz := clampi(int(ceil((hi.z - lo.z) / CELL)), 1, 400)
	var cx := (hi.x - lo.x) / nx; var cz := (hi.z - lo.z) / nz
	var N := nx * nz
	var top := PackedFloat32Array(); top.resize(N); top.fill(-INF)
	var top_ok := PackedByteArray(); top_ok.resize(N)        # 1: top triangle faces up and winds the right way
	var top_sl := PackedByteArray(); top_sl.resize(N)        # 1: top triangle is sloped (a roof face)
	var wall := PackedFloat32Array(); wall.resize(N); wall.fill(-INF)
	var hits: Array = []; hits.resize(N)                     # sloped surface heights over each cell: [y, piece]
	var key_of := {}
	var parent: Array[int] = []
	var tri_piece := PackedInt32Array(); tri_piece.resize(tris.size()); tri_piece.fill(-1)
	var areas := {}
	var wall_tris: Array[int] = []
	var flats: Array[int] = []
	var top_piece := PackedInt32Array(); top_piece.resize(N); top_piece.fill(-1)
	var slope_x := 0.0; var slope_z := 0.0
	# connected parts of the whole model, by shared corners (rounded to 2 mm): a roof slab with its end faces is one part,
	# a wall shell with its bevelled top another
	var comp := PackedInt32Array(); comp.resize(tris.size()); comp.fill(-1)
	for i in tris.size():
		var t0: Array = tris[i]
		var ids0: Array[int] = []
		for p3: Vector3 in [t0[0], t0[1], t0[2]]:
			var kk := Vector3i(roundi(p3.x * 500.0), roundi(p3.y * 500.0), roundi(p3.z * 500.0))
			if not key_of.has(kk):
				key_of[kk] = parent.size(); parent.append(parent.size())
			ids0.append(key_of[kk])
		_union(parent, ids0[0], ids0[1]); _union(parent, ids0[0], ids0[2])
		comp[i] = ids0[0]
	for i in tris.size():
		var t: Array = tris[i]
		var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
		var gn := (b - a).cross(c - a)
		var ar := gn.length() * 0.5
		if ar < 1e-7: continue
		gn = gn.normalized()
		var ns: Vector3 = t[3]
		if ns == Vector3.ZERO: ns = gn * _wind_sign
		var cy := (a.y + b.y + c.y) / 3.0
		if absf(gn.y) < 0.12:
			if ar < 0.015: continue      # ropes, rods and trim are not walls
			if maxf(a.y, maxf(b.y, c.y)) - minf(a.y, minf(b.y, c.y)) < 0.3: continue    # nor are fascias, ridge caps, sills
			wall_tris.append(i)          # walls are marked after the roof pieces are known (below)
			continue
		var sloped := absf(gn.y) < 0.985
		if not sloped and gn.y * _wind_sign > 0.0: flats.append(i)
		var up_face := (gn * _wind_sign).y > 0.0
		var face_ok: bool = (ns.y > 0.0 and gn.dot(ns) * _wind_sign > 0.0) or (t.size() > 4 and t[4])
		var piece := _find(parent, comp[i])
		if sloped and cy > lo.y + 0.3 * H:
			tri_piece[i] = piece
		# rasterise over the cells it covers
		var mnx := clampi(int((minf(a.x, minf(b.x, c.x)) - lo.x) / cx), 0, nx - 1)
		var mxx := clampi(int((maxf(a.x, maxf(b.x, c.x)) - lo.x) / cx), 0, nx - 1)
		var mnz := clampi(int((minf(a.z, minf(b.z, c.z)) - lo.z) / cz), 0, nz - 1)
		var mxz := clampi(int((maxf(a.z, maxf(b.z, c.z)) - lo.z) / cz), 0, nz - 1)
		var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(d) < 1e-9: continue
		for j in range(mnz, mxz + 1):
			for ii in range(mnx, mxx + 1):
				var px := lo.x + (ii + 0.5) * cx; var pz := lo.z + (j + 0.5) * cz
				var u := ((px - a.x) * (c.z - a.z) - (c.x - a.x) * (pz - a.z)) / d
				var v := ((b.x - a.x) * (pz - a.z) - (px - a.x) * (b.z - a.z)) / d
				if u < -1e-4 or v < -1e-4 or u + v > 1.0001: continue
				var y := a.y + u * (b.y - a.y) + v * (c.y - a.y)
				var k := j * nx + ii
				if y > top[k] + 0.002:
					top[k] = y
					top_ok[k] = 1 if face_ok else 0
					top_sl[k] = 1 if sloped else 0
					top_piece[k] = piece if y > lo.y + 0.3 * H else -1
				elif y > top[k] - 0.002:
					# a double-sided sheet (canvas, tarp): the cell is right if either face at the top faces up
					if face_ok: top_ok[k] = 1
					if sloped: top_sl[k] = 1
				if sloped:
					if hits[k] == null: hits[k] = []
					(hits[k] as Array).append([y, piece])
		if tri_piece[i] >= 0:
			areas[i] = ar
			if gn.y * _wind_sign > 0.12 or (t.size() > 4 and t[4]):
				slope_x += absf(gn.x) * ar; slope_z += absf(gn.z) * ar
	for i in tri_piece.size():
		if tri_piece[i] >= 0: tri_piece[i] = _find(parent, tri_piece[i])
	# the roof pieces are those seen from above somewhere; a slab's end faces belong to one, a wall's bevelled top (under
	# the roof, never on top) does not
	var top_set := {}
	for k in N:
		if top_piece[k] >= 0: top_set[_find(parent, top_piece[k])] = true
	for i in wall_tris:
		var t: Array = tris[i]
		var a: Vector3 = t[0]; var b: Vector3 = t[1]; var c: Vector3 = t[2]
		if top_set.has(_find(parent, comp[i])): continue      # part of a roof (a slab's end face, a chimney)
		for e in [[a, b], [b, c], [c, a]]:
			var p: Vector3 = e[0]; var q: Vector3 = e[1]
			var steps := int(ceil(Vector2(q.x - p.x, q.z - p.z).length() / (CELL * 0.5))) + 1
			for s in steps + 1:
				var w := p.lerp(q, float(s) / steps)
				var ci := clampi(int((w.x - lo.x) / cx), 0, nx - 1); var cj := clampi(int((w.z - lo.z) / cz), 0, nz - 1)
				var k2 := cj * nx + ci
				if w.y > wall[k2]: wall[k2] = w.y
	var msgs: Array = []
	var ok := true
	# ---- 1. ridge above eaves: median top-height profile across the ridge
	var roof_min := lo.y + 0.3 * H
	var prof_x := _profile(top, nx, nz, roof_min, true)
	var prof_z := _profile(top, nx, nz, roof_min, false)
	# across the ridge: the way the roof faces lean (area-weighted), else the axis along which the height changes most
	var rx := _range(prof_x); var rz := _range(prof_z)
	var prof := prof_x if rx >= rz else prof_z
	if slope_x + slope_z > 0.5:
		prof = prof_x if slope_x >= slope_z else prof_z
	var valley := _valley(prof)
	if valley > VALLEY_TOL:
		ok = false
		msgs.append("UPSIDE DOWN: the middle of the roof is %.2f m lower than both eaves (V roof)" % valley)
	# ---- 2. roof faces up
	var roof_cells := 0; var good := 0
	for k in N:
		if top[k] > roof_min and top_sl[k] == 1:
			roof_cells += 1
			good += top_ok[k]
	var frac := float(good) / maxf(roof_cells, 1)
	if roof_cells > 20 and frac < 0.9:
		ok = false
		msgs.append("ROOF FACES DOWN: only %d%% of the top roof surface faces up" % int(frac * 100.0))
	# ---- 3 and 4. support: gap from each wall top up to the nearest sloped surface above it, per piece
	# per cell first; then each wall cell takes the smallest gap within 0.35 m, because a pitched roof bears on the outer edge
	# of a thick wall (the wall plate) and rises away from it across the wall's thickness
	var gapg := PackedFloat32Array(); gapg.resize(N); gapg.fill(INF)
	var gapp := PackedInt32Array(); gapp.resize(N); gapp.fill(-1)
	for k in N:
		if wall[k] == -INF or hits[k] == null or wall[k] < roof_min - 0.5 * H: continue
		var best := INF; var bp := -1
		for h in hits[k]:
			var y: float = h[0]
			if int(h[1]) < 0 or not top_set.has(_find(parent, int(h[1]))): continue      # only roof surfaces
			if y >= wall[k] - 0.15 and y - wall[k] < best:
				best = maxf(y - wall[k], 0.0); bp = h[1]
		if bp < 0 or best == INF: continue
		gapg[k] = best; gapp[k] = _find(parent, bp)
	var R := int(ceil(0.35 / minf(cx, cz)))
	var piece_gaps := {}
	var all_gaps: Array = []
	for k in N:
		if gapg[k] == INF: continue
		var i0 := k % nx; var j0 := k / nx
		var g := gapg[k]
		for dj in range(-R, R + 1):
			for di in range(-R, R + 1):
				var ii := i0 + di; var jj := j0 + dj
				if ii < 0 or jj < 0 or ii >= nx or jj >= nz: continue
				var k2 := jj * nx + ii
				if gapp[k2] == gapp[k] and gapg[k2] < g: g = gapg[k2]
		all_gaps.append(g)
		if not piece_gaps.has(gapp[k]): piece_gaps[gapp[k]] = []
		piece_gaps[gapp[k]].append(g)
	var med_gap := _pct(all_gaps, 0.1)
	# pieces: area, and whether they rest on walls or touch other geometry
	var piece_area := {}
	for i in areas:
		var p := tri_piece[i]
		piece_area[p] = float(piece_area.get(p, 0.0)) + float(areas[i])
	var floating: Array = []
	if _verbose:
		for p in piece_gaps: print("   gaps piece ", p, " area ", piece_area.get(p, -1.0), " cells ", (piece_gaps[p] as Array).size(), " top ", top_set.has(p))
	for p in piece_area:
		if not top_set.has(p): continue      # under the roof (a wall's bevelled top): not a roof piece
		if float(piece_area[p]) < 0.4 or note == "tent" or note == "skirted": continue
		# resting: somewhere along its wall cells (the eaves line, a gable top) the gap is under 0.15 m, in at least three
		# cells; buttresses, posts and the inner half of a thick wall under a steep pitch may all stand well clear below it.
		# Small pieces (gutters, ridge tiles, a cupola cap) may instead hang on other geometry within 6 cm.
		var contact := 0
		if piece_gaps.has(p):
			for g in piece_gaps[p]:
				if float(g) <= GAP_TOL: contact += 1
		if contact >= 3: continue
		var pb := _piece_box(tris, tri_piece, p)
		# a spire or cap standing on the flat top of a tower or belfry rests there
		if _rests_on_flat(tris, flats, comp, parent, p, pb): continue
		# a gutter, a run of ridge tiles or a capping (small, or narrow) may hang on other geometry within 6 cm
		if (float(piece_area[p]) < 12.0 or minf(pb.size.x, pb.size.z) < 0.8) and _touches(tris, tri_piece, p, 0.06): continue
		floating.append(p)
		if _verbose:
			print("   floating piece %.1f m2 at %s, wall cells under it %d, gap 30%% %s" % [piece_area[p], _piece_box(tris, tri_piece, p), (piece_gaps[p] as Array).size() if piece_gaps.has(p) else 0, str(_pct(piece_gaps[p], 0.3)) if piece_gaps.has(p) else "-"])
	if not floating.is_empty():
		ok = false
		msgs.append("ROOF NOT ON WALLS: %d roof pieces float clear of their walls (largest %.1f m2)" % [floating.size(), _max_area(piece_area, floating)])
	var summary := "H %.1f m, ridge profile %s, roof up %d%%, wall gap (10th pct) %.2f m, %d pieces" % [H, _fmt_prof(prof), int(frac * 100.0), med_gap if all_gaps.size() > 0 else -1.0, piece_area.size()]
	return {"ok": ok, "msg": summary + ("" if msgs.is_empty() else "  <<< " + "; ".join(msgs))}

func _profile(top: PackedFloat32Array, nx: int, nz: int, ymin: float, along_x: bool) -> Array:
	var n_out := nx if along_x else nz
	var n_in := nz if along_x else nx
	var out: Array = []
	for i in n_out:
		var vals: Array = []
		for j in n_in:
			var k := (j * nx + i) if along_x else (i * nx + j)
			if top[k] > ymin: vals.append(top[k])
		out.append(_median(vals) if vals.size() >= 3 else NAN)
	# keep the span covered by the roof
	var first := 0; var last := out.size() - 1
	while first < out.size() and is_nan(out[first]): first += 1
	while last >= 0 and is_nan(out[last]): last -= 1
	if last <= first: return []
	return out.slice(first, last + 1)

func _range(p: Array) -> float:
	var mn := INF; var mx := -INF
	for v in p:
		if is_nan(v): continue
		mn = minf(mn, v); mx = maxf(mx, v)
	return mx - mn if mx > mn else 0.0

## How far the middle (35-65 %) dips below the lower of the two ends (the 0-15 % and 85-100 % stretches): an upside-down
## pitched roof is lowest in the middle; a porch or lean-to tucked under one eave is not.
func _valley(p: Array) -> float:
	var n := p.size()
	if n < 8: return 0.0
	var e0 := -INF; var e1 := -INF; var mid := INF
	for i in n:
		var v: float = p[i]
		if is_nan(v): continue
		var f := float(i) / (n - 1)
		if f <= 0.15: e0 = maxf(e0, v)
		elif f >= 0.85: e1 = maxf(e1, v)
		elif f >= 0.35 and f <= 0.65: mid = minf(mid, v)
	if e0 == -INF or e1 == -INF or mid == INF: return 0.0
	return minf(e0, e1) - mid

func _touches(tris: Array, tri_piece: PackedInt32Array, p: int, tol: float) -> bool:
	var pts := {}
	var bb := AABB(); var first := true
	for i in tris.size():
		if tri_piece[i] != p: continue
		for k in 3:
			var q: Vector3 = tris[i][k]
			pts[Vector3i(floori(q.x / tol), floori(q.y / tol), floori(q.z / tol))] = true
			if first: bb = AABB(q, Vector3.ZERO); first = false
			else: bb = bb.expand(q)
	bb = bb.grow(tol)
	for i in tris.size():
		if tri_piece[i] == p: continue
		var t: Array = tris[i]
		for k in 3:
			var q: Vector3 = t[k]
			if not bb.has_point(q): continue
			var c := Vector3i(floori(q.x / tol), floori(q.y / tol), floori(q.z / tol))
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if pts.has(c + Vector3i(dx, dy, dz)): return true
		# a long edge of another part passing through the piece (a wall top under a slab): test its midpoint too
		var m: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		if bb.has_point(m):
			var cm := Vector3i(floori(m.x / tol), floori(m.y / tol), floori(m.z / tol))
			if pts.has(cm): return true
	return false

func _piece_box(tris: Array, tri_piece: PackedInt32Array, p: int) -> AABB:
	var bb := AABB(); var first := true
	for i in tris.size():
		if tri_piece[i] != p: continue
		for k in 3:
			if first: bb = AABB(tris[i][k], Vector3.ZERO); first = false
			else: bb = bb.expand(tris[i][k])
	return bb

func _rests_on_flat(tris: Array, flats: Array[int], comp: PackedInt32Array, parent: Array[int], p: int, pb: AABB) -> bool:
	var y0 := pb.position.y
	for i in flats:
		if _find(parent, comp[i]) == p: continue
		var t: Array = tris[i]
		var y: float = (t[0].y + t[1].y + t[2].y) / 3.0
		if absf(y - y0) > 0.05: continue
		var m: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		if m.x > pb.position.x and m.x < pb.end.x and m.z > pb.position.z and m.z < pb.end.z: return true
	return false

func _max_area(areas: Dictionary, ids: Array) -> float:
	var m := 0.0
	for p in ids: m = maxf(m, float(areas[p]))
	return m

func _fmt_prof(p: Array) -> String:
	if p.size() < 3: return "-"
	var n := p.size()
	return "%.1f/%.1f/%.1f" % [p[int(n * 0.05)], p[n / 2], p[int(n * 0.95)]]

static func _pct(a: Array, q: float) -> float:
	if a.is_empty(): return NAN
	var b := a.duplicate(); b.sort()
	return b[clampi(int(b.size() * q), 0, b.size() - 1)]

static func _median(a: Array) -> float:
	if a.is_empty(): return NAN
	var b := a.duplicate(); b.sort()
	return b[b.size() / 2]

static func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

static func _union(parent: Array[int], a: int, b: int) -> void:
	var ra := _find(parent, a); var rb := _find(parent, b)
	if ra != rb: parent[ra] = rb
