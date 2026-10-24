class_name FarmDemo
extends RefCounted
## A patch of farmland built from the batch 5 models (NewModels3), to see them in the real scene: a corn field of rows, a block of
## barley and alfalfa, a field-margin strip, a fence run with a gate and a corner, round and square bales and a stack, and tilled
## ground. It is a development hook (screenshot token `farmdemo<x>_<z>` in game/main.gd), not part of the game: the game places the
## models itself. Each crop chunk uses the level of detail its distance from `eye` asks for, as the game will.

const ROW := 0.76

static func _mm(parent: Node3D, mesh: Mesh, xfs: Array) -> void:
	if xfs.is_empty(): return
	var m := MultiMesh.new()
	m.transform_format = MultiMesh.TRANSFORM_3D
	m.mesh = mesh
	m.instance_count = xfs.size()
	for i in xfs.size(): m.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = m
	mi.custom_aabb = AABB(Vector3(-400, -50, -400), Vector3(800, 400, 800))
	parent.add_child(mi)

static func _lod(d: float) -> int:
	return 0 if d < 22.0 else (1 if d < 70.0 else 2)

static func build(parent: Node3D, terrain: Object, c: Vector2, eye: Vector3) -> void:
	var root := Node3D.new()
	root.name = "FarmDemo"
	parent.add_child(root)
	var at := func(x: float, z: float, yaw := 0.0) -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, terrain.height(x, z), z))
	var dist := func(x: float, z: float) -> float: return Vector2(x - eye.x, z - eye.z).length()
	# the corn field: 24 rows by 24 chunks, rows along z
	var by_lod := [[], [], []]
	for r in 24:
		for k in 24:
			var x := c.x + ROW * r
			var z := c.y + 4.0 * k
			by_lod[_lod(dist.call(x, z + 2.0))].append(at.call(x + 0.1 * sin(k * 1.7 + r), z + 2.0))
	for l in 3: _mm(root, NewModels3.mesh("corn_row_chunk", l), by_lod[l])
	# barley and alfalfa blocks beside it, patches 0.45 m apart, a margin of weeds between
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var names := ["barley_patch_a", "barley_patch_b", "alfalfa_patch_a", "alfalfa_patch_b"]
	for bi in 2:
		var lods := [[], [], []]
		var bx := c.x - 12.0 - 12.0 * bi
		for i in 28:
			for j in 36:
				var x := bx + 0.45 * i + rng.randf_range(-0.12, 0.12)
				var z := c.y + 0.45 * j + rng.randf_range(-0.12, 0.12)
				lods[_lod(dist.call(x, z))].append(at.call(x, z, rng.randf() * TAU))
		for l in 3: _mm(root, NewModels3.mesh(names[bi * 2], l), lods[l])
	var wl := [[], [], []]
	for i in 12: wl[_lod(dist.call(c.x - 2.0, c.y + 1.2 * i))].append(at.call(c.x - 2.0, c.y + 1.2 * i + 0.6, PI * 0.5))
	for l in 3: _mm(root, NewModels3.mesh("crop_edge_weeds", l), wl[l])
	# a fence run along the field's far end with a corner and a gate, then bales in the yard
	var fx := c.x - 4.0
	var run := ["fence_post_rail_a", "fence_post_rail_b", "fence_wire_a", "fence_wire_b", "fence_gate_a", "fence_post_rail_c", "fence_post_rail_a"]
	for i in run.size():
		var mi := MeshInstance3D.new(); mi.mesh = NewModels3.mesh(run[i], _lod(dist.call(fx + 3.0 * i, c.y - 3.0)))
		mi.transform = at.call(fx + 3.0 * i, c.y - 3.0)
		root.add_child(mi)
	var cm := MeshInstance3D.new(); cm.mesh = NewModels3.mesh("fence_corner_a", 0); cm.transform = at.call(fx + 3.0 * run.size(), c.y - 3.0); root.add_child(cm)
	var bales := [["hay_round_a", 0.0, 0.0], ["hay_round_b", 2.2, 0.8], ["hay_roll_a", 4.4, -0.4], ["hay_square_a", 6.0, 1.2], ["hay_square_b", 7.2, 1.4], ["hay_stack_a", 9.5, 0.6]]
	for b in bales:
		var mi := MeshInstance3D.new(); mi.mesh = NewModels3.mesh(b[0], _lod(dist.call(fx + b[1], c.y - 8.0)))
		mi.transform = at.call(fx + float(b[1]), c.y - 8.0 + float(b[2]), 0.4 * float(b[1]))
		root.add_child(mi)
	# tilled soil and a headland beside the bales
	for i in 3:
		var mi := MeshInstance3D.new(); mi.mesh = NewModels3.mesh("field_furrow_a" if i != 1 else "field_furrow_b", 0)
		mi.transform = at.call(fx + 12.0 + 3.1 * i, c.y - 13.0)
		root.add_child(mi)
