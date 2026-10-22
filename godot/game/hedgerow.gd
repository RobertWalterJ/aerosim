class_name Hedgerow
extends RefCounted
## Clipped hedges as continuous hedgerows. The web layout places hedges as short separate pieces (2 m boxwood blocks
## lining the spur walks, 3 m yew blocks in a ring round the chapel). Here the pieces that form a row are found
## (close together and facing the same way), joined into one smooth centre line, and each row is rebuilt as a single
## leafy hedge that follows the ground: a dark inner body with a softly rounded, clipped top and a slightly wider base,
## covered in leaf-spray cards from the props atlas. Rows open up where they would run over a path or into a
## headstone, tree or building, and finish with trimmed, rounded ends. Rows are merged per 80 m cell into one mesh with
## a near and a far version, and the same wind and rotor-wash shader as the trees.

const CELL := 80.0
const OBST_CELL := 4.0          # obstacle lookup grid (largest obstacle radius is well under this)
const LOD0_END := 50.0           # near (full) version up to this distance beyond the group's own radius
const LOD1_END := 480.0
const ATLAS := "res://assets/world/props_0.png"
const SOLID_UV := Vector2(0.8, 0.875)      # plain cell of the atlas, used for the inner body

## Per species: piece length in the layout, largest gap that still joins two pieces, hedge size and shape, leaf colour.
const SPECIES := {
	"hedge-boxwood": {
		"len": 2.0, "join": 1.4, "h": 0.8, "w": 0.64, "cap": 0.3, "e": 2.6, "batter": 0.07,
		"cell": Rect2(0.0, 0.5, 0.25, 0.25), "card": 0.29, "density": 48.0,
		"tint": Vector3(0.13, 0.2, 0.06), "bronze": 0.55, "fresh": 0.0,
	},
	"hedge-yew": {
		"len": 3.0, "join": 9.5, "h": 1.75, "w": 1.05, "cap": 0.22, "e": 4.0, "batter": 0.09,
		"cell": Rect2(0.25, 0.5, 0.25, 0.25), "card": 0.37, "density": 32.0,
		"tint": Vector3(0.078, 0.13, 0.055), "bronze": 0.0, "fresh": 0.35,
	},
}

static var stats := {}

## Builds the hedgerows into `world` and returns their collision cylinders as [x, z, r, y0, y1].
static func build(world: World, touch_device: bool) -> Array:
	var t0 := Time.get_ticks_msec()
	var t: Terrain = world.terrain
	var layout: Dictionary = world.layout
	var cyls := []
	var groups := {}       # String key -> {origin, lod0: {verts...}, lod1: {...}, sp}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	stats = {"rows": 0, "segments": 0, "tris0": 0, "tris1": 0, "meshes": 0}
	var hedge_pts := []     # every piece position, so the old per-piece colliders can be dropped
	var fams := {}
	for fam in layout["families"]:
		if SPECIES.has(str(fam["name"])): fams[str(fam["name"])] = fam["items"]
	for name in fams:
		for it in fams[name]: hedge_pts.append(Vector2(float(it[0]), float(it[2])))
	var obstacles := _obstacles(world, hedge_pts)
	for name in fams:
		var sp: Dictionary = SPECIES[name]
		var items: Array = fams[name]
		for chain in _chains(items, sp):
			stats["rows"] += 1
			var line := _centre_line(chain, sp, t)
			for seg in _open_runs(line, sp, t, obstacles):
				stats["segments"] += 1
				var mid: Vector2 = _at(line, (seg[0] + seg[1]) * 0.5)["p"]
				var key := "%s|%d|%d" % [name, floori(mid.x / CELL), floori(mid.y / CELL)]
				if not groups.has(key):
					groups[key] = {"sp": sp, "origin": Vector3(mid.x, t.height(mid.x, mid.y), mid.y), "lod": [_new_buf(), _new_buf()]}
				var g: Dictionary = groups[key]
				var density := 0.6 if touch_device else 1.0
				_hedge(line, seg, sp, g["lod"][0], g["origin"], rng, 0, density)
				_hedge(line, seg, sp, g["lod"][1], g["origin"], rng, 1, density)
				# collision: a run of overlapping cylinders along the hedge's centre line
				var s: float = seg[0]
				while s <= seg[1]:
					var a := _at(line, s)
					var p: Vector2 = a["p"]
					var r: float = float(sp["w"]) * 0.5
					cyls.append([p.x, p.y, r, float(a["g"]) - 0.1, float(a["g"]) + float(sp["h"])])
					s += 0.55
	var mat_cache := {}
	for key in groups:
		var g: Dictionary = groups[key]
		var sp: Dictionary = g["sp"]
		if not mat_cache.has(sp["tint"]): mat_cache[sp["tint"]] = _material(sp)
		var radius := 0.0
		for v in (g["lod"][0]["v"] as PackedVector3Array): radius = maxf(radius, Vector2(v.x, v.z).length())
		for lod in 2:
			var b: Dictionary = g["lod"][lod]
			if (b["v"] as PackedVector3Array).is_empty(): continue
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh(b, mat_cache[sp["tint"]])
			mi.position = g["origin"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if lod == 0:
				mi.visibility_range_end = LOD0_END + radius; mi.visibility_range_end_margin = 6.0
			else:
				mi.visibility_range_begin = LOD0_END + radius; mi.visibility_range_begin_margin = 6.0
				mi.visibility_range_end = LOD1_END + radius; mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			world.add_child(mi)
			stats["meshes"] += 1
			stats["tris%d" % lod] += (b["i"] as PackedInt32Array).size() / 3
	print("hedgerow: %d rows, %d runs, %d meshes, %d near tris, %d far tris, %d colliders, %d ms" % [stats["rows"], stats["segments"], stats["meshes"], stats["tris0"], stats["tris1"], cyls.size(), Time.get_ticks_msec() - t0])
	return cyls

## Lookup of where the old hedge pieces stood, for is_piece_collider().
static func piece_keys(hedge_pts: Array) -> Dictionary:
	var keys := {}
	for p in hedge_pts: keys[Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))] = true
	return keys

## True for a layout collider that belongs to one of the old hedge pieces (they are replaced by the row colliders).
static func is_piece_collider(c: Array, keys: Dictionary) -> bool:
	return keys.has(Vector2i(roundi(float(c[0]) * 100.0), roundi(float(c[1]) * 100.0)))

# ------------------------------------------------------------------ rows from pieces
## Groups the pieces into chains: neighbours that are close and lined up along each other's long axis.
static func _chains(items: Array, sp: Dictionary) -> Array:
	var n := items.size()
	var c: Array[Vector2] = []
	var d: Array[Vector2] = []
	for it in items:
		c.append(Vector2(float(it[0]), float(it[2])))
		var ry := float(it[3])
		d.append(Vector2(cos(ry), -sin(ry)))     # the piece runs along its local X axis
	var reach: float = float(sp["len"]) + float(sp["join"])
	# best neighbour ahead of and behind each piece
	var fwd: Array[int] = []; var back: Array[int] = []
	fwd.resize(n); back.resize(n); fwd.fill(-1); back.fill(-1)
	for i in n:
		var bf := 1e9; var bb := 1e9
		for j in n:
			if i == j: continue
			var off := c[j] - c[i]
			var dist := off.length()
			if dist > reach or dist < 0.3: continue
			var u := off / dist
			if absf(u.dot(d[i])) < 0.88 or absf(u.dot(d[j])) < 0.88: continue
			if u.dot(d[i]) > 0.0:
				if dist < bf: bf = dist; fwd[i] = j
			else:
				if dist < bb: bb = dist; back[i] = j
	var adj := []
	for i in n: adj.append([])
	for i in n:
		for j in [fwd[i], back[i]]:
			if j < 0: continue
			if fwd[j] == i or back[j] == i:
				if not (j in adj[i]): adj[i].append(j)
				if not (i in adj[j]): adj[j].append(i)
	var used := {}
	var out := []
	# open chains first (start at an end), then whatever is left is a closed loop
	for pass_i in 2:
		for i in n:
			if used.has(i): continue
			if pass_i == 0 and (adj[i] as Array).size() == 2: continue
			var chain := [i]
			used[i] = true
			var cur := i
			while true:
				var nxt := -1
				for j in adj[cur]:
					if not used.has(j): nxt = j; break
				if nxt < 0: break
				chain.append(nxt); used[nxt] = true; cur = nxt
			var closed: bool = pass_i == 1 and chain.size() > 2 and (chain[0] in adj[cur])
			var pts: Array[Vector2] = []
			var dirs: Array[Vector2] = []
			for k in chain:
				pts.append(c[k]); dirs.append(d[k])
			out.append({"pts": pts, "dirs": dirs, "closed": closed})
	return out

## A dense centre line (every ~0.1 m) through the piece centres, with ground height and arc length.
static func _centre_line(chain: Dictionary, sp: Dictionary, t: Terrain) -> Dictionary:
	var pts: Array[Vector2] = chain["pts"]
	var dirs: Array[Vector2] = chain["dirs"]
	var closed: bool = chain["closed"]
	var half: float = float(sp["len"]) * 0.5
	var q: Array[Vector2] = []
	if closed:
		q = pts.duplicate()
	elif pts.size() == 1:
		q.append(pts[0] - dirs[0] * half); q.append(pts[0] + dirs[0] * half)
	else:
		var d0 := dirs[0] * signf(dirs[0].dot(pts[1] - pts[0]))
		var dn := dirs[-1] * signf(dirs[-1].dot(pts[-1] - pts[-2]))
		q.append(pts[0] - d0 * half)
		q.append_array(pts)
		q.append(pts[-1] + dn * half)
	var n := q.size()
	var dense := PackedVector2Array()
	var spans := n if closed else n - 1
	for i in spans:
		var p1 := q[i]
		var p2 := q[(i + 1) % n]
		var p0: Vector2
		var p3: Vector2
		if closed:
			p0 = q[(i - 1 + n) % n]; p3 = q[(i + 2) % n]
		else:
			p0 = q[i - 1] if i > 0 else p1 * 2.0 - p2
			p3 = q[i + 2] if i + 2 < n else p2 * 2.0 - p1
		var steps := maxi(2, ceili(p1.distance_to(p2) / 0.1))
		for k in steps:
			var u := float(k) / steps
			var u2 := u * u; var u3 := u2 * u
			dense.append(0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3))
	dense.append(q[0] if closed else q[-1])
	var arc := PackedFloat32Array()
	var gnd := PackedFloat32Array()
	var acc := 0.0
	for i in dense.size():
		if i > 0: acc += dense[i].distance_to(dense[i - 1])
		arc.append(acc)
		gnd.append(t.height(dense[i].x, dense[i].y))
	return {"p": dense, "arc": arc, "g": gnd, "len": acc, "closed": closed}

## Point, unit tangent and ground height at arc length s.
static func _at(line: Dictionary, s: float) -> Dictionary:
	var arc: PackedFloat32Array = line["arc"]
	var pts: PackedVector2Array = line["p"]
	var gnd: PackedFloat32Array = line["g"]
	var L: float = line["len"]
	if line["closed"]: s = fposmod(s, L)
	else: s = clampf(s, 0.0, L)
	var i := clampi(arc.bsearch(s) - 1, 0, arc.size() - 2)
	var span := maxf(arc[i + 1] - arc[i], 1e-5)
	var f := clampf((s - arc[i]) / span, 0.0, 1.0)
	var tdir := (pts[i + 1] - pts[i]) / span
	return {"p": pts[i].lerp(pts[i + 1], f), "t": tdir.normalized(), "g": lerpf(gnd[i], gnd[i + 1], f)}

# ------------------------------------------------------------------ keeping clear of paths, graves, trees, buildings
## Colliders near the hedges (not the hedges' own): [x, z, r] circles and [x0, z0, x1, z1] boxes.
static func _obstacles(world: World, hedge_pts: Array) -> Dictionary:
	var lo := Vector2(1e9, 1e9); var hi := Vector2(-1e9, -1e9)
	for p in hedge_pts: lo = lo.min(p); hi = hi.max(p)
	lo -= Vector2(25, 25); hi += Vector2(25, 25)
	var keys := piece_keys(hedge_pts)
	var circles := {}     # Vector2i (4 m cell) -> Array of [x, z, r]
	var add := func(x: float, z: float, r: float) -> void:
		if x < lo.x or x > hi.x or z < lo.y or z > hi.y: return
		var k := Vector2i(floori(x / OBST_CELL), floori(z / OBST_CELL))
		if not circles.has(k): circles[k] = []
		circles[k].append([x, z, r])
	for c in world.layout["colliders"]["cyl"]:
		if not is_piece_collider(c, keys): add.call(float(c[0]), float(c[1]), float(c[2]))
	for k in world._trunks:
		for tr in world._trunks[k]: add.call(float(tr[0]), float(tr[2]), float(tr[3]))
	var boxes := []
	for b in world.layout["colliders"]["box"]: boxes.append([float(b[0]), float(b[1]), float(b[2]), float(b[3])])
	return {"c": circles, "b": boxes}

## Distance to the nearest path centre line, bilinear between the path map's half-metre samples.
static func _path_dist(t: Terrain, x: float, z: float) -> float:
	var step := Terrain.PATH_SPAN / float(t._path.get_width())
	var fx := (x + Terrain.PATH_SPAN / 2.0) / step - 0.5
	var fz := (z + Terrain.PATH_SPAN / 2.0) / step - 0.5
	var i := floorf(fx); var j := floorf(fz)
	var tx := fx - i; var tz := fz - j
	var o := -Terrain.PATH_SPAN / 2.0
	var a := t.dist_to_path(o + (i + 0.5) * step, o + (j + 0.5) * step)
	var b := t.dist_to_path(o + (i + 1.5) * step, o + (j + 0.5) * step)
	var c := t.dist_to_path(o + (i + 0.5) * step, o + (j + 1.5) * step)
	var d := t.dist_to_path(o + (i + 1.5) * step, o + (j + 1.5) * step)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

## The stretches of the centre line [s0, s1] where the hedge can stand.
static func _open_runs(line: Dictionary, sp: Dictionary, t: Terrain, obs: Dictionary) -> Array:
	var L: float = line["len"]
	var hw: float = float(sp["w"]) * 0.5
	var closed: bool = line["closed"]
	var n := maxi(2, int(ceil(L / 0.2)))
	var step := L / n
	var samples := n if closed else n + 1       # a ring's last sample would repeat its first
	var blocked: Array[bool] = []
	var any := false
	for k in samples:
		var p: Vector2 = _at(line, minf(k * step, L))["p"]
		var bad := _path_dist(t, p.x, p.y) < hw + 1.75     # the asphalt is about 1.55 m either side of the centre line
		if not bad:
			var ck := Vector2i(floori(p.x / OBST_CELL), floori(p.y / OBST_CELL))
			for a in range(-1, 2):
				for bb in range(-1, 2):
					for c in obs["c"].get(ck + Vector2i(a, bb), []):
						var dx: float = p.x - c[0]; var dz: float = p.y - c[1]
						var rr: float = hw * 0.85 + float(c[2]) + 0.05
						if dx * dx + dz * dz < rr * rr: bad = true
		if not bad:
			for b in obs["b"]:
				var cx := clampf(p.x, b[0], b[2]); var cz := clampf(p.y, b[1], b[3])
				if Vector2(p.x - cx, p.y - cz).length() < hw + 0.3: bad = true; break
		blocked.append(bad)
		any = any or bad
	if closed and not any: return [[0.0, L]]    # an unbroken ring
	var runs := []
	var start := -1.0
	var first := 0
	if closed:
		while not blocked[first]: first += 1     # start the walk at a blocked sample so no run wraps around
	for kk in n + 1:      # a ring walks once round, back to the blocked sample it started at
		var k := (first + kk) % n if closed else kk
		var s := float(first + kk) * step if closed else minf(kk * step, L)
		if not blocked[k]:
			if start < 0.0: start = s
		elif start >= 0.0:
			runs.append([start, s - step]); start = -1.0
	if start >= 0.0: runs.append([start, L])
	var out := []
	var pad := 0.12
	for r in runs:
		var a: float = r[0]; var b: float = r[1]
		if a > 0.01: a += pad
		if b < L - 0.01 or closed: b -= pad
		if b - a >= 0.9: out.append([a, b])
	return out

# ------------------------------------------------------------------ the hedge mesh
static func _new_buf() -> Dictionary:
	return {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "uv2": PackedVector2Array(), "i": PackedInt32Array()}

static var _noise: FastNoiseLite

static func _nz(x: float, y: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = 4242
		_noise.frequency = 1.0
	return _noise.get_noise_3d(x, y, z)

## The cross-section's frame at arc length s: centre, sideways direction, ground, size, and how far into a trimmed end.
static func _frame(line: Dictionary, seg: Array, sp: Dictionary, s: float) -> Array:
	var a := _at(line, s)
	var tg: Vector2 = a["t"]
	var H: float = float(sp["h"]) * (1.0 + 0.035 * _nz(s * 0.13, 3.1, 0.0) + 0.012 * _nz(s * 0.9, 7.7, 0.0))
	var W: float = float(sp["w"]) * (1.0 + 0.05 * _nz(s * 0.17, 11.3, 0.0))
	# trimmed ends: k runs from 0 at the cut to 1 a short way in (rounded vertical corners)
	var R := minf(0.32, W * 0.45)
	var k := 1.0
	var ds := s - float(seg[0]); var de := float(seg[1]) - s
	if seg[2] and ds < R: k = sqrt(maxf(0.0, 1.0 - pow((R - ds) / R, 2.0)))
	if seg[3] and de < R: k = minf(k, sqrt(maxf(0.0, 1.0 - pow((R - de) / R, 2.0))))
	var end_dir := Vector3(tg.x, 0.0, tg.y) * (-1.0 if ds < de else 1.0)
	return [a["p"], Vector2(-tg.y, tg.x), float(a["g"]), H, W, k, end_dir]

## A point on the hedge for frame f and section parameter u (0 = foot of one side, over the top, 1 = foot of the
## other side). Returns [world position, outward normal (world), height above ground of the point].
static func _surf(f: Array, sp: Dictionary, u: float, inset: float, wobble: bool) -> Array:
	var p2: Vector2 = f[0]
	var nrm: Vector2 = f[1]
	var g: float = f[2]
	var H: float = f[3]
	var W: float = f[4]
	var k: float = f[5]
	var capH: float = float(sp["cap"]) * W
	var e: float = sp["e"]
	var y0 := H - capH
	var per := 2.0 * y0 + PI * (W * 0.5 + capH) * 0.5
	var fa := y0 / per
	var y := 0.0; var z := 0.0
	if u < fa:
		y = (u / fa) * y0; z = W * 0.5
	elif u > 1.0 - fa:
		y = ((1.0 - u) / fa) * y0; z = -W * 0.5
	else:
		var phi := PI * (u - fa) / (1.0 - 2.0 * fa)
		var c := cos(phi); var sn := sin(phi)
		z = W * 0.5 * signf(c) * pow(absf(c), 2.0 / e)
		y = y0 + capH * pow(absf(sn), 2.0 / e)
	# a little wider at the foot (batter) and a soft flare where it meets the ground
	z *= 1.0 + float(sp["batter"]) * (1.0 - y / H) + 0.06 * (1.0 - smoothstep(0.0, 0.22 * H, y))
	z *= 0.62 + 0.38 * k
	y *= 0.93 + 0.07 * k
	# a soft "volume" normal: out from a line low in the hedge, turning to face along the row at a trimmed end
	var out := Vector2(z, y - y0 * 0.45).normalized()
	z -= out.x * inset; y -= out.y * inset
	var wp := Vector3(p2.x + nrm.x * z, g + y, p2.y + nrm.y * z)
	var n3 := Vector3(nrm.x * out.x, out.y, nrm.y * out.x)
	if wobble:
		var w := _nz(wp.x * 1.7, wp.y * 1.7, wp.z * 1.7) * 0.03 + _nz(wp.x * 4.6, wp.y * 4.6, wp.z * 4.6) * 0.012
		wp += n3 * w
	if k < 1.0: n3 = n3.lerp(f[6], (1.0 - k) * 0.85).normalized()
	if u <= 0.0001 or u >= 0.9999:
		wp.y = minf(g, wp.y) - 0.12     # tuck the foot into the ground on either side of a slope
	return [wp, n3, y]

## Appends one stretch of hedge to buffer `b` (vertices relative to `origin`). lod 0: dense leaf cards; lod 1: light.
static func _hedge(line: Dictionary, run: Array, sp: Dictionary, b: Dictionary, origin: Vector3, rng: RandomNumberGenerator, lod: int, density: float) -> void:
	var L: float = line["len"]
	var closed_ring: bool = line["closed"] and run[0] <= 0.0 and run[1] >= L
	var seg := [float(run[0]), float(run[1]), not closed_ring, not closed_ring]
	var len_s: float = seg[1] - seg[0]
	var vs: PackedVector3Array = b["v"]; var ns: PackedVector3Array = b["n"]; var cs: PackedColorArray = b["c"]
	var uvs: PackedVector2Array = b["uv"]; var uv2s: PackedVector2Array = b["uv2"]; var idx: PackedInt32Array = b["i"]
	var H: float = sp["h"]
	# ---- inner body: a dark tube of the section swept along the run, closed at the trimmed ends
	var nu := maxi(2, ceili(len_s / (0.35 if lod == 0 else 0.8)))
	var nsec := 12 if lod == 0 else 7
	var inset := 0.06 if lod == 0 else 0.015
	var base := vs.size()
	for i in nu + 1:
		var s: float = seg[0] + len_s * float(i) / nu
		var f := _frame(line, seg, sp, s)
		for j in nsec + 1:
			var u := float(j) / nsec
			var r := _surf(f, sp, u, inset, true)
			var wp: Vector3 = r[0]
			vs.append(wp - origin)
			ns.append(r[1])
			var ao := 0.35 + 0.65 * smoothstep(-0.05, 0.8 * H, float(r[2]))
			var shade := (0.18 if lod == 0 else 0.55) * ao
			cs.append(Color(shade, shade, shade * 0.9))
			uvs.append(SOLID_UV)
			uv2s.append(Vector2(0.0, 0.0))
	for i in nu:
		for j in nsec:
			var q := base + i * (nsec + 1) + j
			idx.append_array([q, q + nsec + 1, q + nsec + 2, q, q + nsec + 2, q + 1])
	if not closed_ring:
		for end in 2:
			var s: float = seg[0] if end == 0 else seg[1]
			var a := _at(line, s)
			var tg: Vector2 = a["t"]
			var sgn := -1.0 if end == 0 else 1.0
			var cpos := Vector3((a["p"] as Vector2).x, float(a["g"]) + H * 0.42, (a["p"] as Vector2).y)
			var ci := vs.size()
			vs.append(cpos - origin); ns.append(Vector3(tg.x, 0.0, tg.y) * sgn); cs.append(Color(0.16, 0.16, 0.15))
			uvs.append(SOLID_UV); uv2s.append(Vector2.ZERO)
			var row := base + (0 if end == 0 else nu) * (nsec + 1)
			for j in nsec:
				if end == 0: idx.append_array([ci, row + j + 1, row + j])
				else: idx.append_array([ci, row + j, row + j + 1])
	# ---- leaf-spray cards over the whole surface, facing out with the volume so the mass shades as one form
	var W: float = sp["w"]
	var per: float = 2.0 * H + W * 1.2
	var cap_area := 0.0 if closed_ring else 2.0 * W * H * 0.85
	var area := per * len_s + cap_area
	var card: float = sp["card"]
	var count := int(area * float(sp["density"]) * density * (1.0 if lod == 0 else 0.22))
	var size_k := 1.0 if lod == 0 else 1.75
	var cell: Rect2 = sp["cell"]
	var end_share := cap_area / area
	for i in count:
		var s: float; var u: float
		var p: Vector3; var n: Vector3; var yh: float
		if rng.randf() < end_share:
			# the trimmed end faces: a disc of cards inside the end outline
			var end := rng.randi() % 2
			s = seg[0] + 0.02 if end == 0 else seg[1] - 0.02
			u = rng.randf()
			var rim := _surf(_frame(line, seg, sp, s), sp, u, 0.0, true)
			var a := _at(line, s)
			var tg: Vector2 = a["t"]
			var sgn := -1.0 if end == 0 else 1.0
			var cpos := Vector3((a["p"] as Vector2).x, float(a["g"]) + H * 0.42, (a["p"] as Vector2).y)
			var rr := sqrt(rng.randf()) * 0.95
			p = cpos.lerp(rim[0], rr)
			n = (Vector3(tg.x, 0.0, tg.y) * sgn).lerp(rim[1], rr * rr * 0.6).normalized()
			yh = p.y - float(a["g"])
		else:
			s = rng.randf_range(seg[0], seg[1])
			u = rng.randf()
			var r := _surf(_frame(line, seg, sp, s), sp, u, 0.0, true)
			p = r[0]; n = r[1]; yh = r[2]
		var off := rng.randf_range(-0.04, 0.018)
		p += n * off
		var size := card * size_k * rng.randf_range(0.8, 1.2)
		var gnd := p.y - yh
		p.y = maxf(p.y, gnd + size * 0.3)
		# card axes: a random spin about the outward normal, tilted out of the surface so sprays stick out
		var t0 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		t0 = t0.rotated(n, rng.randf() * TAU)
		var v0 := n.cross(t0).normalized()
		v0 = v0.rotated(t0, clampf(rng.randfn(0.0, 0.45), -0.9, 0.9))
		var vn := n.lerp(Vector3.UP, 0.2).normalized()
		var depth := clampf(-off, 0.0, 1.0)
		# light: darker towards the foot and inside, brightest on the sunny clipped top
		var ao := (0.42 + 0.58 * smoothstep(-0.05, 0.9 * H, yh)) * (1.0 - depth * 6.0) * (0.82 + 0.18 * maxf(n.y, 0.0))
		var col := _leaf_colour(sp, p, yh / H, rng) * ao
		var phase := rng.randf()
		var flex := 0.07 * clampf(yh / H, 0.0, 1.0)
		var h := size * 0.5
		var q0 := vs.size()
		var corners := [p - t0 * h - v0 * h, p + t0 * h - v0 * h, p + t0 * h + v0 * h, p - t0 * h + v0 * h]
		var cuv := [Vector2(cell.position.x, cell.end.y), Vector2(cell.end.x, cell.end.y), Vector2(cell.end.x, cell.position.y), cell.position]
		for k in 4:
			vs.append((corners[k] as Vector3) - origin); ns.append(vn); cs.append(col)
			uvs.append(cuv[k]); uv2s.append(Vector2(phase, flex))
		idx.append_array([q0, q0 + 1, q0 + 2, q0, q0 + 2, q0 + 3])
	b["v"] = vs; b["n"] = ns; b["c"] = cs; b["uv"] = uvs; b["uv2"] = uv2s; b["i"] = idx

## Leaf colour as a multiplier on the species tint: brightness variation, bronzed patches on boxwood, paler new
## growth on the yew's sunny top.
static func _leaf_colour(sp: Dictionary, p: Vector3, hrel: float, rng: RandomNumberGenerator) -> Color:
	# broad lighter and darker stretches along the row, then leaf-to-leaf variation
	var k := (rng.randf_range(0.72, 1.0) if rng.randf() < 0.85 else rng.randf_range(0.45, 0.7)) * (0.9 + 0.1 * _nz(p.x * 0.12 - 5.0, 0.0, p.z * 0.12))
	var c := Color(0.92 * k, k, 0.9 * k)
	var patch := _nz(p.x * 0.45 + 11.0, p.y * 0.45, p.z * 0.45)
	var br: float = sp["bronze"]
	if br > 0.0 and patch > 0.2:
		var m := smoothstep(0.2, 0.6, patch) * br
		c = c.lerp(Color(1.0, 0.78, 0.42) * k, m)
	var fr: float = sp["fresh"]
	if fr > 0.0 and hrel > 0.8 and rng.randf() < fr:
		c = c.lerp(Color(1.0, 1.0, 0.62), 0.6)
	return c

static func _mesh(b: Dictionary, mat: Material) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = b["v"]
	arr[Mesh.ARRAY_NORMAL] = b["n"]
	arr[Mesh.ARRAY_COLOR] = b["c"]
	arr[Mesh.ARRAY_TEX_UV] = b["uv"]
	arr[Mesh.ARRAY_TEX_UV2] = b["uv2"]
	arr[Mesh.ARRAY_INDEX] = b["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m

static func _material(sp: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/foliage.gdshader") as Shader
	m.set_shader_parameter("albedo_tex", load(ATLAS) as Texture2D)
	m.set_shader_parameter("use_alpha", true)
	m.set_shader_parameter("alpha_cut", 0.45)
	m.set_shader_parameter("roughness", 0.82)
	m.set_shader_parameter("translucency", 0.22)
	m.set_shader_parameter("sway", 0.25)        # clipped hedges barely bend; the leaves still shiver
	m.set_shader_parameter("flutter", 0.45)
	var tn: Vector3 = sp["tint"]
	m.set_shader_parameter("tint", tn)
	return m
