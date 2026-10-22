class_name Cemetery
extends Node3D
## A Victorian memorial section laid out from the web version's models: rows of headstones with the occasional
## cross, angel, urn, willow marker and kerbed plot, bouquets, an iron fence and hedges around it, and dead wood and
## clutter nearby. The ground under it is levelled by the terrain (see Terrain.add_flat_rect).

const CENTRE := Vector2(62.0, -48.0)
const HALF := Vector2(15.0, 10.0)        # half size of the fenced section in metres
const ROWS := 5
const PER_ROW := 9

func contains(x: float, z: float, margin := 0.0) -> bool:
	return absf(x - CENTRE.x) < HALF.x + margin and absf(z - CENTRE.y) < HALF.y + margin

func build(terrain: Terrain) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var base_y := terrain.height(CENTRE.x, CENTRE.y)
	var at := func(x: float, z: float, yaw: float = 0.0, s: float = 1.0) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x, terrain.height(x, z), z))
	# headstones: rows facing the same way, spaced like a Victorian section, each leaning a little
	var groups := {}   # model -> Array[Transform3D]
	var add := func(model: String, xf: Transform3D):
		if not groups.has(model): groups[model] = [] as Array[Transform3D]
		groups[model].append(xf)
	var x0 := CENTRE.x - HALF.x + 4.0
	var z0 := CENTRE.y - HALF.y + 3.5
	for r in ROWS:
		for c in PER_ROW:
			if rng.randf() < 0.07: continue          # a gap in the row
			var x := x0 + c * ((HALF.x * 2.0 - 8.0) / (PER_ROW - 1)) + rng.randf_range(-0.2, 0.2)
			var z := z0 + r * 3.8 + rng.randf_range(-0.2, 0.2)
			var yaw := rng.randf_range(-0.05, 0.05) + PI   # face south
			var roll := rng.randf()
			if roll < 0.62: add.call("env/headstone_%d" % rng.randi_range(0, 7), at.call(x, z, yaw))
			elif roll < 0.72: add.call("env/crossMonument_%d" % rng.randi_range(0, 2), at.call(x, z, yaw))
			elif roll < 0.80: add.call("env/urnMonument_%d" % rng.randi_range(0, 3), at.call(x, z, yaw))
			elif roll < 0.88: add.call("env/willowMarker_%d" % rng.randi_range(0, 3), at.call(x, z, yaw))
			elif roll < 0.94: add.call("env/kerbedPlot_%d" % rng.randi_range(0, 3), at.call(x, z, yaw))
			else: add.call("env/angelMonument_%d" % rng.randi_range(0, 2), at.call(x, z, yaw))
			if rng.randf() < 0.3: add.call("env/bouquet_%d" % rng.randi_range(0, 3), at.call(x + rng.randf_range(-0.3, 0.3), z + 0.5, rng.randf() * TAU))
	for m in groups: Assets.scatter(self, m, groups[m], true, 0.0, 260.0)
	# iron fence around the section, tiled from the model's length; a gate in the middle of the south side
	var fence := "env/ironFence_0"
	var fb: Array = Assets.info(fence).get("bbox", [[0, 0, 0], [3, 1.4, 0.1]])
	var seg_len: float = float(fb[1][0]) - float(fb[0][0])
	var fence_xfs: Array[Transform3D] = []
	var n_x := int(ceil(HALF.x * 2.0 / seg_len))
	var n_z := int(ceil(HALF.y * 2.0 / seg_len))
	for i in n_x:
		var px := CENTRE.x - HALF.x + seg_len * i
		fence_xfs.append(at.call(px, CENTRE.y - HALF.y, 0.0))
		if i != n_x / 2: fence_xfs.append(at.call(px, CENTRE.y + HALF.y, 0.0))
	for i in n_z:
		var pz := CENTRE.y - HALF.y + seg_len * i
		fence_xfs.append(at.call(CENTRE.x - HALF.x, pz + seg_len, -PI / 2.0))
		fence_xfs.append(at.call(CENTRE.x + HALF.x, pz, PI / 2.0))
	Assets.scatter(self, fence, fence_xfs, true, 0.0, 300.0)
	Assets.place(self, "env/ironGate_0", at.call(CENTRE.x - 1.5 + (n_x / 2 - 0.0) * 0.0, CENTRE.y + HALF.y, 0.0))
	# hedges outside the north and east sides, shrubs at the corners
	var hedge_xfs: Array[Transform3D] = []
	for i in 6:
		hedge_xfs.append(at.call(CENTRE.x - HALF.x + 3.0 + i * 5.2, CENTRE.y - HALF.y - 2.0, 0.0))
	Assets.scatter(self, "env/hedge_0", hedge_xfs, true, 0.0, 300.0)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		Assets.place(self, "env/shrub_%d" % rng.randi_range(0, 3), at.call(CENTRE.x + c.x * (HALF.x + 2.0), CENTRE.y + c.y * (HALF.y + 2.0), rng.randf() * TAU))
	# a few dead trees, stumps, rocks and fallen branches around the edge for variety
	var scatter_around := func(model_base: String, count: int, variants: int, radius_min: float, radius_max: float):
		var xfs := {}
		for i in count:
			var a := rng.randf() * TAU
			var rad := rng.randf_range(radius_min, radius_max)
			var px: float = CENTRE.x + cos(a) * rad * 1.6
			var pz: float = CENTRE.y + sin(a) * rad
			var k := "env/%s_%d" % [model_base, rng.randi_range(0, variants - 1)]
			if not xfs.has(k): xfs[k] = [] as Array[Transform3D]
			xfs[k].append(at.call(px, pz, rng.randf() * TAU, rng.randf_range(0.8, 1.2)))
		for k in xfs: Assets.scatter(self, k, xfs[k], true, 0.0, 220.0)
	scatter_around.call("deadTree", 3, 4, 14.0, 26.0)
	scatter_around.call("hollowStump", 4, 4, 14.0, 30.0)
	scatter_around.call("rockOutcrop", 3, 4, 20.0, 34.0)
	scatter_around.call("fallenBranch", 8, 4, 12.0, 30.0)
	scatter_around.call("leafDrift", 10, 4, 6.0, 22.0)
	# shift the whole section so it sits on the levelled ground
	position = Vector3.ZERO
	var _unused := base_y
