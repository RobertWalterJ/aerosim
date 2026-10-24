class_name NewModels7
extends RefCounted
## Story batch 9 (models9): the storm and tornado assets (what the storm leaves behind and the weather archive) and the endgame
## props and buildings (the cabin and its yard, the cabin interior set, the thermal pod, Anne's lake markers, the small things
## that belong to Wren, Constable Rennick and the 1984 cruiser). The characters (Wren, Rennick) and the vehicles (the cruiser,
## Anne's car, the dive van and boat) are being rebuilt separately; their asset names are listed in README-models.md so their files
## drop straight in. This is the dispatcher and the shared helpers; the models live in NewModels7Storm, NewModels7Archive,
## NewModels7Cabin, NewModels7Interior and NewModels7Gear. It plugs into NewModels6 (names, group_of, build) so StoryAssets, the
## exporter and the contact sheets treat these like every other story asset. Same frame as batch 8: metres, Y up, +Z is the
## front, origin at the base (debris pieces: centred on their own origin, for MultiMesh). Contract: game/README-models.md ("Batch 9").

const LODS := {"cabin_abandoned_a": true, "cabin_abandoned_a_broken_roof": true}

static func names() -> Array[String]:
	var out: Array[String] = []
	out.append_array(NewModels7Storm.NAMES)
	out.append_array(NewModels7Archive.NAMES)
	out.append_array(NewModels7Cabin.NAMES)
	out.append_array(NewModels7Interior.NAMES)
	out.append_array(NewModels7Gear.NAMES)
	return out

static func group_of(name: String) -> String:
	if name in NewModels7Storm.NAMES or name in NewModels7Archive.NAMES: return "storm"
	if name in NewModels7Cabin.NAMES or name in NewModels7Interior.NAMES: return "cabin"
	if name in NewModels7Gear.NAMES: return "gear"
	return ""

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	return NewModels7Storm.build(name, md, lod) or NewModels7Archive.build(name, md, lod) or NewModels7Cabin.build(name, md, lod) \
		or NewModels7Interior.build(name, md, lod) or NewModels7Gear.build(name, md, lod)

## A timber colour with the grain direction in alpha (1 up, 0.75 along x, 0.5 along z; see farm_props.gdshader kind 0).
static func W(c: Color, grain := 1.0) -> Color:
	return Color(c.r, c.g, c.b, grain)

## Copies another drawn model into this one, moved by xf (positions and normals; hulls are carried as boxes, sub-nodes are not).
static func merge(dst: NewModels6.Model, src: NewModels6.Model, xf: Transform3D, with_hulls := false) -> void:
	for key in src.m:
		var sb: NewModels2.Buf = src.m[key]
		if sb.pos.is_empty(): continue
		var db := dst.b(key)
		var nb := Basis(xf.basis.inverse().transposed())
		for i in sb.pos.size():
			db.pos.append(xf * sb.pos[i])
			db.nrm.append((nb * sb.nrm[i]).normalized())
			db.cols.append(sb.cols[i])
	if with_hulls:
		for h in src.hulls:
			var bb: AABB = h
			var c := xf * bb.get_center()
			var sz := (xf.basis * bb.size).abs()
			dst.hulls.append(AABB(c - sz * 0.5, sz))

## A freshly built model of another asset, for composing (a set of props on a table, debris around a hatch).
static func sample(name: String, lod := 2) -> NewModels6.Model:
	return NewModels6.build(name, lod)

## A rectangular sheet of surface (w across x, d along z) as a grid in the XZ plane at y = f(x, z); `up` faces +Y.
static func sheet_grid(md: NewModels6.Model, key: String, w: float, d: float, nu: int, nv: int, col: Color, f: Callable, xf := Transform3D.IDENTITY, vary := 0.05) -> void:
	var rows: Array = []
	for j in nv + 1:
		var r := PackedVector3Array(); r.resize(nu + 1)
		for i in nu + 1:
			var x := (float(i) / nu - 0.5) * w
			var z := (float(j) / nv - 0.5) * d
			r[i] = xf * Vector3(x, float(f.call(x, z)), z)
		rows.append(r)
	var up := (xf.basis * Vector3.UP).normalized()
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return up
	NewModels6.gridsurf(md, key, rows, col, hint, vary)

## A circular patch (radius r, centre origin) as a grid in the XZ plane, heights from f(x, z), a ragged edge from edge(angle).
static func disc_grid(md: NewModels6.Model, key: String, r: float, rings: int, spokes: int, col: Color, f: Callable, edge: Callable, vary := 0.06) -> void:
	var rows: Array = []
	for j in rings + 1:
		var row := PackedVector3Array(); row.resize(spokes + 1)
		for i in spokes + 1:
			var a := TAU * float(i % spokes) / spokes
			var rr := r * float(j) / rings * float(edge.call(a))
			var x := cos(a) * rr
			var z := sin(a) * rr
			row[i] = Vector3(x, float(f.call(x, z)), z)
		rows.append(row)
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP
	NewModels6.gridsurf(md, key, rows, col, hint, vary)

## A bundle of thin crossed leaf-shaped cards (autumn colours) inside a radius: debris leaves, a bush, a heap.
static func leaves(md: NewModels6.Model, c: Vector3, rad: float, n: int, size: float, seed_i: float, cols: Array) -> void:
	for k in n:
		var a := NewModels6.rnd(k, seed_i) * TAU
		var rr := rad * sqrt(NewModels6.rnd(k, seed_i + 1.0))
		var p := c + Vector3(cos(a) * rr, (NewModels6.rnd(k, seed_i + 2.0) - 0.5) * rad * 0.6, sin(a) * rr)
		var yaw := NewModels6.rnd(k, seed_i + 3.0) * TAU
		var tilt := (NewModels6.rnd(k, seed_i + 4.0) - 0.5) * 1.6
		var bas := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var s := size * (0.7 + 0.6 * NewModels6.rnd(k, seed_i + 5.0))
		var col: Color = cols[int(NewModels6.rnd(k, seed_i + 6.0) * cols.size()) % cols.size()]
		var h := s * 0.5
		var pts := [bas * Vector3(0, 0, -h) + p, bas * Vector3(s * 0.28, 0, -h * 0.1) + p, bas * Vector3(s * 0.2, 0, h * 0.6) + p, bas * Vector3(0, 0, h) + p,
			bas * Vector3(-s * 0.2, 0, h * 0.6) + p, bas * Vector3(-s * 0.28, 0, -h * 0.1) + p]
		NewModels6.sheet(md, "cloth", pts, NewModels6.vc(col, k * 1.3, 0.12), bas * Vector3.UP)

## Autumn leaf colours used by debris and the felled tree.
const AUTUMN := [Color(0.55, 0.3, 0.1), Color(0.62, 0.42, 0.12), Color(0.4, 0.28, 0.1), Color(0.5, 0.2, 0.08), Color(0.32, 0.3, 0.1)]

## A straight board between two points with a rectangular section (w across, t thick), `up` the broad face's direction.
static func board(md: NewModels6.Model, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, up := Vector3.UP) -> void:
	var bd := NewModels2._beam(a, b, w, t, up)
	NewModels6.put(md, key, bd, Transform3D.IDENTITY, col, 0.0)

## A rope or wire as a chain of short tubes along a drooping curve between a and b.
static func rope(md: NewModels6.Model, key: String, a: Vector3, b: Vector3, sag: float, r: float, col: Color, n := 8) -> void:
	var prev := a
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		NewModels6.limb(md, key, prev, p, r, r, col, 4)
		prev = p
