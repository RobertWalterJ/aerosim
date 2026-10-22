class_name World
extends Node3D
## Everything that stands on the valley, placed exactly as the web version places it (tools/export_world.ts wrote the
## layout): about 4,500 near trees and 60,000 far ones, tall meadow, hedges, shrubs, iron railings and gates, the stone
## boundary wall, the Victorian memorial section, the war memorial, obelisks, the chapel and shed, lamps and benches,
## fallen wood, rocks and parked cars. Props are grouped in 80 m cells, each with a detailed and a light model that
## Godot switches by distance. Also answers collision and line-of-sight questions about what it placed.

const CELL := 80.0
const FAR_CELL := 300.0
const TREE_NAMES := ["spruce_a", "spruce_b", "maple_red", "maple_gold", "oak"]
const TREE_NEAR_END := 110.0
const TREE_MID_END := 430.0
const CELL_PAD := 57.0           # half a cell's diagonal: a cell is shown while any of its props could be in range
const GRID := 24.0               # collision grid

var terrain: Terrain
var layout := {}
var tree_count := 0
var prop_count := 0
var exclusions: Array[Rect2] = []
var home := Vector2(-18.0, 36.0)

var _trunks := {}                # Vector2i -> Array of [x, y, z, radius, height]
var _cyls := {}                  # Vector2i -> Array of [x, z, r, y0, y1]
var _boxes := {}                 # Vector2i -> Array of [x0, z0, x1, z1, y0, y1]
var _hedge_cyls := []            # the hedgerows' own colliders [x, z, r, y0, y1] (game/hedgerow.gd)
var _hedge_pts := []             # where the layout's separate hedge pieces stood (their colliders are replaced)

func build(t: Terrain, touch_device: bool) -> void:
	terrain = t
	layout = t.layout
	home = Vector2(float(layout["home"]["x"]), float(layout["home"]["z"]))
	for r in layout["exclusions"]:
		exclusions.append(Rect2(Vector2(r[0], r[1]), Vector2(r[2] - r[0], r[3] - r[1])))
	_trees()
	_far_trees(touch_device)
	_props()
	_hedge_cyls = Hedgerow.build(self, touch_device)
	_park()
	_colliders()

# ------------------------------------------------------------------ trees
func _trees() -> void:
	var cells := {}    # Vector2i -> variant -> Array[Transform3D]
	for tr in layout["trees"]:
		var x: float = tr[0]; var y: float = tr[1]; var z: float = tr[2]
		var s: float = tr[4]
		var vi: int = int(tr[5])
		var xf := Transform3D(Basis(Vector3.UP, float(tr[3])).scaled(Vector3(s, s, s)), Vector3(x, y, z))
		var key := Vector2i(floori(x / CELL), floori(z / CELL))
		if not cells.has(key): cells[key] = {}
		if not cells[key].has(vi): cells[key][vi] = [] as Array[Transform3D]
		cells[key][vi].append(xf)
		var conifer := vi < 2
		var tk := Vector2i(floori(x / GRID), floori(z / GRID))
		if not _trunks.has(tk): _trunks[tk] = []
		_trunks[tk].append([x, y, z, (0.3 if conifer else 0.4) * s, (21.0 if conifer else 13.0) * s])
		tree_count += 1
	for key in cells:
		for vi in cells[key]:
			var xfs: Array[Transform3D] = cells[key][vi]
			var n: String = TREE_NAMES[vi]
			Assets.scatter(self, "trees/%s_l0" % n, xfs, true, 0.0, TREE_NEAR_END + CELL_PAD)
			Assets.scatter(self, "trees/%s_l1" % n, xfs, true, TREE_NEAR_END, TREE_MID_END + CELL_PAD)
			Assets.scatter(self, "trees/far_%s" % ("conifer" if vi < 2 else "broadleaf"), xfs, false, TREE_MID_END, 0.0)

func _far_trees(touch_device: bool) -> void:
	for kind in ["conifer", "broad"]:
		var arr: Array = layout["farTrees"][kind]
		var cells := {}   # Vector2i -> [xfs, colors]
		var step := 4 if touch_device else 1    # fewer far trees on a phone
		for i in range(0, arr.size() / 9, step):
			var o := i * 9
			var x: float = arr[o]; var z: float = arr[o + 2]
			var xf := Transform3D(Basis(Vector3.UP, float(arr[o + 3])).scaled(Vector3(arr[o + 4], arr[o + 5], arr[o + 4])), Vector3(x, arr[o + 1], z))
			var key := Vector2i(floori(x / FAR_CELL), floori(z / FAR_CELL))
			if not cells.has(key): cells[key] = [[] as Array[Transform3D], [] as Array[Color]]
			cells[key][0].append(xf); cells[key][1].append(Color(arr[o + 6], arr[o + 7], arr[o + 8]))
		for key in cells:
			Assets.scatter(self, "trees/far_%s" % ("conifer" if kind == "conifer" else "broadleaf"), cells[key][0], false, 0.0, 0.0, cells[key][1])

# ------------------------------------------------------------------ props (families from the web instancer)
func _props() -> void:
	for fam in layout["families"]:
		var items: Array = fam["items"]
		if items.is_empty(): continue
		var d: Array = fam["d"]
		var name: String = fam["name"]
		if Hedgerow.SPECIES.has(name):    # hedge pieces are joined into continuous rows by Hedgerow instead
			for it in items: _hedge_pts.append(Vector2(float(it[0]), float(it[2])))
			prop_count += items.size()
			continue
		var cells := {}   # Vector2i -> variant -> Array[Transform3D]
		for it in items:
			var s: float = it[6]
			var xf := Transform3D(Basis.from_euler(Vector3(it[4], it[3], it[5]), EULER_ORDER_YXZ).scaled(Vector3(s, s, s)), Vector3(it[0], it[1], it[2]))
			var key := Vector2i(floori(float(it[0]) / CELL), floori(float(it[2]) / CELL))
			var v: int = int(it[7])
			if not cells.has(key): cells[key] = {}
			if not cells[key].has(v): cells[key][v] = [] as Array[Transform3D]
			cells[key][v].append(xf)
			prop_count += 1
		var shadows: bool = fam["large"]
		for key in cells:
			for v in cells[key]:
				var xfs: Array[Transform3D] = cells[key][v]
				Assets.scatter(self, "world/%s__%d__0" % [name, v], xfs, shadows, 0.0, float(d[0]) + CELL_PAD)
				Assets.scatter(self, "world/%s__%d__1" % [name, v], xfs, shadows, float(d[0]), float(d[2]) + CELL_PAD)

# ------------------------------------------------------------------ park: one-off pieces, lamps, benches, headstones
func _park() -> void:
	var scene := load("res://assets/world/park.glb") as PackedScene
	if scene != null:
		var inst := scene.instantiate()
		_cast_shadows(inst)
		add_child(inst)
	for pi in layout["parkInstanced"]:
		var m: Array = pi["m"]
		var xfs: Array[Transform3D] = []
		for i in int(pi["count"]):
			var o := i * 9
			xfs.append(Transform3D(Basis.from_euler(Vector3(m[o + 3], m[o + 4], m[o + 5]), EULER_ORDER_YXZ).scaled(Vector3(m[o + 6], m[o + 7], m[o + 8])), Vector3(m[o], m[o + 1], m[o + 2])))
		Assets.scatter(self, "world/" + str(pi["name"]), xfs, true, 0.0, 0.0)

func _cast_shadows(n: Node) -> void:
	if n is GeometryInstance3D: (n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children(): _cast_shadows(c)

# ------------------------------------------------------------------ collisions
func _colliders() -> void:
	var cyl_list: Array = []
	var piece_keys := Hedgerow.piece_keys(_hedge_pts)
	for c in layout["colliders"]["cyl"]:
		if not Hedgerow.is_piece_collider(c, piece_keys): cyl_list.append(c)
	cyl_list.append_array(_hedge_cyls)
	for c in cyl_list:
		var k := Vector2i(floori(float(c[0]) / GRID), floori(float(c[1]) / GRID))
		if not _cyls.has(k): _cyls[k] = []
		_cyls[k].append([c[0], c[1], c[2], c[3], c[4]])
	for b in layout["colliders"]["box"]:
		var i0 := floori(float(b[0]) / GRID); var i1 := floori(float(b[2]) / GRID)
		var j0 := floori(float(b[1]) / GRID); var j1 := floori(float(b[3]) / GRID)
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var k := Vector2i(i, j)
				if not _boxes.has(k): _boxes[k] = []
				_boxes[k].append([b[0], b[1], b[2], b[3], b[4], b[5]])

## For the drone: returns the push-out vector when a sphere of radius r at (x, y, z) touches a trunk, monument or building.
func obstacle_hit(x: float, y: float, z: float, r: float) -> Vector3:
	var key := Vector2i(floori(x / GRID), floori(z / GRID))
	for a in range(-1, 2):
		for b in range(-1, 2):
			var k := Vector2i(key.x + a, key.y + b)
			if _trunks.has(k):
				for t in _trunks[k]:
					if y < t[1] - r or y > t[1] + t[4] + r: continue
					var dx: float = x - t[0]; var dz: float = z - t[2]
					var dd := sqrt(dx * dx + dz * dz)
					var rr: float = t[3] + r
					if dd < rr:
						var sc := (rr - dd) / maxf(dd, 1e-4)
						return Vector3(dx * sc, 0, dz * sc)
			if _cyls.has(k):
				for c in _cyls[k]:
					if y < c[3] - r or y > c[4] + r: continue
					var dx2: float = x - c[0]; var dz2: float = z - c[1]
					var d2 := sqrt(dx2 * dx2 + dz2 * dz2)
					var r2: float = c[2] + r
					if d2 < r2:
						var s2 := (r2 - d2) / maxf(d2, 1e-4)
						return Vector3(dx2 * s2, 0, dz2 * s2)
			if _boxes.has(k):
				for bx in _boxes[k]:
					if y < bx[4] - r or y > bx[5] + r: continue
					var cx := clampf(x, bx[0], bx[2]); var cz := clampf(z, bx[1], bx[3])
					var ddx := x - cx; var ddz := z - cz
					var d3 := sqrt(ddx * ddx + ddz * ddz)
					if d3 < r:
						var s3 := (r - d3) / d3 if d3 > 1e-4 else 1.0
						return Vector3(ddx * s3 + (r if d3 <= 1e-4 else 0.0), 0, ddz * s3)
	return Vector3.INF

## True if a ray from `origin` along `dir` passes through a tree crown within `reach` metres (used for sun glare).
func canopy_blocks(origin: Vector3, dir: Vector3, reach: float) -> bool:
	var t := 2.0
	while t < reach:
		var p := origin + dir * t
		var key := Vector2i(floori(p.x / GRID), floori(p.z / GRID))
		for a in range(-1, 2):
			for b in range(-1, 2):
				var k := Vector2i(key.x + a, key.y + b)
				if not _trunks.has(k): continue
				for tr in _trunks[k]:
					var h: float = tr[4]
					var base: float = tr[1] + 0.35 * h
					if p.y < base or p.y > tr[1] + h: continue
					var crown := 0.34 * h * (1.0 - (p.y - base) / (0.65 * h))
					var dx: float = p.x - tr[0]
					var dz: float = p.z - tr[2]
					if dx * dx + dz * dz < crown * crown: return true
		t += 3.0 if t < 30.0 else 8.0
	return false
