class_name Forest
extends Node3D
## The trees: the web version's spruce, maple and oak models (godot/assets/trees), planted in a jittered grid with
## forest density from noise. Each 100 m cell gets its own MultiMeshes so Godot can switch detail by distance:
## full model near the camera, a lighter model in the middle, a ~100-triangle silhouette far away.

const CELL := 100.0
const NEAR_END := 110.0
const MID_END := 430.0
const TREE_CELL := 24.0            # trunk-collision grid (separate from the render cells)

# variant: name, conifer, height, trunk radius
const VARIANTS := [
	{"n": "spruce_a", "conifer": true, "h": 20.8, "r": 0.30},
	{"n": "spruce_b", "conifer": true, "h": 20.3, "r": 0.30},
	{"n": "maple_red", "conifer": false, "h": 12.9, "r": 0.40},
	{"n": "maple_gold", "conifer": false, "h": 12.0, "r": 0.40},
	{"n": "oak", "conifer": false, "h": 14.3, "r": 0.46},
]

var _trunks := {}       # Vector2i -> Array of [x, y, z, radius, height]
var tree_count := 0

## keep_clear(x, z) -> bool: return true for places where no tree may stand (cemetery, take-off pad).
func plant(terrain: Terrain, keep_clear: Callable, span := 700.0, step := 9.5, seed_value := 11) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var forest := FastNoiseLite.new(); forest.seed = 31; forest.frequency = 0.004
	var park := FastNoiseLite.new(); park.seed = 8; park.frequency = 0.012
	var cells := {}   # Vector2i -> variant index -> Array[Transform3D]
	var x := -span
	while x < span:
		var z := -span
		while z < span:
			var px := x + rng.randf() * step
			var pz := z + rng.randf() * step
			z += step
			var d := sqrt(px * px + pz * pz)
			if d < 30.0 or keep_clear.call(px, pz): continue
			var dens := forest.get_noise_2d(px, pz) * 0.5 + 0.5
			# open parkland near the start, denser woodland further out
			var want := smoothstep(0.32, 0.7, dens) * (0.35 + 0.65 * smoothstep(60.0, 320.0, d))
			if rng.randf() > want: continue
			if terrain.normal_at(px, pz).y < 0.86: continue
			var y := terrain.height(px, pz)
			if y > 120.0: continue
			# species: broadleaf in the park-like middle, spruce in the woods
			var broad_p := clampf(0.15 + 0.55 * (1.0 - smoothstep(150.0, 450.0, d)) + 0.25 * (park.get_noise_2d(px, pz) * 0.5 + 0.5), 0.05, 0.85)
			var vi: int
			if rng.randf() < broad_p: vi = 2 + int(rng.randf() * 3.0) % 3
			else: vi = int(rng.randf() * 2.0) % 2
			var s := 0.8 + rng.randf() * 0.5
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			var key := Vector2i(floori(px / CELL), floori(pz / CELL))
			if not cells.has(key): cells[key] = {}
			if not cells[key].has(vi): cells[key][vi] = [] as Array[Transform3D]
			cells[key][vi].append(Transform3D(basis, Vector3(px, y - 0.1, pz)))
			var tk := Vector2i(floori(px / TREE_CELL), floori(pz / TREE_CELL))
			if not _trunks.has(tk): _trunks[tk] = []
			_trunks[tk].append([px, y, pz, float(VARIANTS[vi]["r"]) * s, float(VARIANTS[vi]["h"]) * s])
			tree_count += 1
		x += step
	for key in cells:
		for vi in cells[key]:
			var xfs: Array[Transform3D] = cells[key][vi]
			var v: Dictionary = VARIANTS[vi]
			Assets.scatter(self, "trees/%s_l0" % v["n"], xfs, true, 0.0, NEAR_END)
			Assets.scatter(self, "trees/%s_l1" % v["n"], xfs, true, NEAR_END, MID_END)
			Assets.scatter(self, "trees/far_%s" % ("conifer" if v["conifer"] else "broadleaf"), xfs, false, MID_END, 0.0)

## Trunk collision for the drone: returns the push-out vector, or Vector3.INF when clear.
func trunk_hit(x: float, y: float, z: float, r: float) -> Vector3:
	var key := Vector2i(floori(x / TREE_CELL), floori(z / TREE_CELL))
	for a in range(-1, 2):
		for b in range(-1, 2):
			var k := Vector2i(key.x + a, key.y + b)
			if not _trunks.has(k): continue
			for t in _trunks[k]:
				if y < t[1] - r or y > t[1] + t[4] + r: continue
				var dx: float = x - t[0]
				var dz: float = z - t[2]
				var dd := sqrt(dx * dx + dz * dz)
				var rr: float = t[3] + r
				if dd < rr:
					var sc := (rr - dd) / maxf(dd, 1e-4)
					return Vector3(dx * sc, 0, dz * sc)
	return Vector3.INF
