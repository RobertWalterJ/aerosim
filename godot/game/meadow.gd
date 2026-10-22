class_name Meadow
extends Node3D
## Tall autumn meadow from the web version's clump models: foxtail, timothy, bluestem, goldenrod, Queen Anne's lace,
## asters and milkweed. Clumps are placed where the cover map says meadow (not mown lawn, not woodland), in patches of one
## kind of plant, with a detailed model near the camera and a lighter one in the middle distance. Beyond that the GPU
## blade layer carries the ground cover.

const CELL := 80.0
const NEAR_END := 55.0
const MID_END := 190.0
const VARIANTS := 10

var count := 0

## density: clumps per square metre (about 0.35 is rich). reach: how far from the start to plant.
func plant(terrain: Terrain, keep_clear: Callable, density := 0.3, reach := 330.0, seed_value := 23) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var patch := FastNoiseLite.new(); patch.seed = 77; patch.frequency = 0.012
	var clumpy := FastNoiseLite.new(); clumpy.seed = 78; clumpy.frequency = 0.05
	var step := 1.0 / sqrt(density)
	var cells := {}   # Vector2i -> variant -> Array[Transform3D]
	var x := -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var px := x + rng.randf() * step
			var pz := z + rng.randf() * step
			z += step
			if px * px + pz * pz > reach * reach: continue
			if keep_clear.call(px, pz): continue
			var cv := terrain.cover_at(px, pz)
			var wild := (1.0 - cv.y) * (1.0 - 0.6 * cv.x)       # meadow amount: not lawn, thinner in woods
			if wild < 0.25: continue
			var lump := clumpy.get_noise_2d(px, pz) * 0.5 + 0.5
			if rng.randf() > wild * (0.25 + 1.1 * lump): continue
			if terrain.normal_at(px, pz).y < 0.8: continue
			# one kind of plant per patch, with some mixing at the edges
			var pv := patch.get_noise_2d(px, pz) * 0.5 + 0.5
			var vi := clampi(int(pv * VARIANTS), 0, VARIANTS - 1)
			if rng.randf() < 0.22: vi = (vi + 1 + rng.randi() % 3) % VARIANTS
			var s := rng.randf_range(0.8, 1.25)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
			var key := Vector2i(floori(px / CELL), floori(pz / CELL))
			if not cells.has(key): cells[key] = {}
			if not cells[key].has(vi): cells[key][vi] = [] as Array[Transform3D]
			cells[key][vi].append(Transform3D(basis, Vector3(px, terrain.height(px, pz) - 0.03, pz)))
			count += 1
		x += step
	for key in cells:
		for vi in cells[key]:
			var xfs: Array[Transform3D] = cells[key][vi]
			Assets.scatter(self, "env/meadowClump_%d" % vi, xfs, false, 0.0, NEAR_END)
			Assets.scatter(self, "env/meadowClumpL1_%d" % vi, xfs, false, NEAR_END, MID_END)
