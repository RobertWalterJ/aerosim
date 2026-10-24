extends SceneTree
## Headless checks of the Blender animals (assets/models/animals/*.glb through game/animal_assets.gd):
##   Godot --headless --path <godot dir> -s res://test/animals_blender_test.gd [-- names=a,b]
## For every animal: the file loads; it has one Skeleton3D and an AnimationPlayer with the clips it should have, each with
## tracks and a sane length; the three levels of detail exist with falling triangle counts inside their budgets; standing
## height and length are in the real range for the species; no NaN or infinite vertex; and the orientation checks that
## catch upside-down, mirrored, back-to-front, inside-out or floating parts: feet on the ground (lowest point within 3 cm
## of y = 0), up is +y (the head and the top are above the middle), the head toward +Z, the left eye on +x, normals
## pointing out of the body (most of them away from the skeleton's middle), and every mesh's bounds overlapping the body.
## Prints a line per animal and ANIMALS PASS or ANIMALS FAIL.

const RANGE := {   # standing height (top of head or withers, m), length (m)
	"cow_a": [[1.35, 1.75], [2.1, 2.8]], "cow_b": [[1.3, 1.7], [2.0, 2.8]], "cow_c": [[1.1, 1.45], [1.8, 2.4]],
	"calf_a": [[0.75, 1.05], [1.1, 1.7]], "sheep_a": [[0.7, 1.0], [1.0, 1.45]], "sheep_b": [[0.7, 1.0], [1.0, 1.45]],
	"lamb_a": [[0.45, 0.7], [0.6, 0.95]], "horse_a": [[1.9, 2.3], [2.3, 2.9]], "horse_b": [[1.9, 2.3], [2.3, 2.9]],
	"chicken_a": [[0.33, 0.47], [0.3, 0.5]], "dog_a": [[0.6, 0.85], [0.8, 1.15]], "biscuit_a": [[0.6, 0.85], [0.8, 1.2]],
	"lost_dog_a": [[0.6, 0.9], [0.8, 1.2]], "wolf_a": [[0.85, 1.15], [1.1, 1.55]], "wolf_collar_a": [[0.85, 1.15], [1.1, 1.55]],
	"ram_a": [[0.8, 1.15], [1.15, 1.6]],
}
const BUDGET := {"cow_a": 20000, "cow_b": 20000, "cow_c": 20000, "horse_a": 20000, "horse_b": 20000, "chicken_a": 5000}

var _fail: Array[String] = []

func _initialize() -> void:
	var names: Array = AnimalAssets.NAMES.duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="): names = Array(a.substr(6).split(","))
	for nm in names:
		_check(nm)
	if _fail.is_empty():
		print("ANIMALS PASS (%d animals)" % names.size())
	else:
		print("ANIMALS FAIL: ", "; ".join(_fail))
	quit()

## The node's transform relative to `root`, from the local transforms (works before the node is in the tree).
func _rel(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != root:
		if c is Node3D: t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _bone_segments(sk: Skeleton3D, root: Node) -> Array:
	var out := []
	if sk == null: return out
	var xf := _rel(sk, root)
	for b in sk.get_bone_count():
		var par := sk.get_bone_parent(b)
		if par < 0: continue
		var nm := sk.get_bone_name(b)
		if nm.begins_with("eyelid") or nm.begins_with("ctrl"): continue
		out.append([xf * sk.get_bone_global_rest(par).origin, xf * sk.get_bone_global_rest(b).origin])
	return out

func _nearest_on(segs: Array, p: Vector3) -> Vector3:
	var best := Vector3.ZERO; var bd := 1e9
	for sg in segs:
		var a: Vector3 = sg[0]; var b: Vector3 = sg[1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_squared_to(q)
		if d < bd: bd = d; best = q
	return best

func _bad(nm: String, why: String) -> void:
	_fail.append("%s: %s" % [nm, why])
	print("  FAIL ", nm, ": ", why)

func _check(nm: String) -> void:
	if not AnimalAssets.has_file(nm):
		_bad(nm, "no file " + AnimalAssets.path_of(nm)); return
	var root := AnimalAssets.instance(nm, {"fur": false, "lod": -1})
	var sk := AnimalAssets.find_skeleton(root)
	var ap := AnimalAssets.find_player(root)
	if sk == null: _bad(nm, "no Skeleton3D")
	if ap == null: _bad(nm, "no AnimationPlayer")
	else:
		ap.stop()
		for c in AnimalAssets.clips(nm):
			if nm.begins_with("wolf") and c in ["sit", "lie", "tail_wag", "bark", "pant"]: continue
			if not ap.has_animation(c): _bad(nm, "missing clip " + c); continue
			var a := ap.get_animation(c)
			if a.get_track_count() < 10 or a.length < 0.2 or a.length > 12.0: _bad(nm, "clip %s has %d tracks, %.2f s" % [c, a.get_track_count(), a.length])
			for ti in a.get_track_count():
				for k in a.track_get_key_count(ti):
					var v = a.track_get_key_value(ti, k)
					if v is Quaternion and not (v as Quaternion).is_finite(): _bad(nm, "NaN in clip " + c); break
					if v is Vector3 and not (v as Vector3).is_finite(): _bad(nm, "NaN in clip " + c); break
	if nm.begins_with("wolf") and ap != null and not ap.has_animation("look"): _bad(nm, "missing clip look")
	# rest pose: measure in the model's own frame
	var tris := [0, 0, 0]
	var lo := Vector3(1e9, 1e9, 1e9); var hi := -lo
	var body_box := AABB()
	var outward := 0; var inward := 0
	var parts: Array = []
	var body_verts := PackedVector3Array()
	var centre := Vector3.ZERO
	var meshes: Array = AnimalAssets.meshes(root)
	for mi: MeshInstance3D in meshes:
		var nmi := String(mi.name)
		if mi.mesh == null: continue
		var xf := _rel(mi, root)
		var lod := -1
		for k in 3:
			if nmi.ends_with("_LOD%d" % k): lod = k
		var arr := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for v in verts:
			if not v.is_finite(): _bad(nm, "NaN vertex in " + nmi); break
		var n_tri := (idx.size() if idx.size() > 0 else verts.size()) / 3
		var box := AABB()
		for i in verts.size():
			var p := xf * verts[i]
			box = AABB(p, Vector3.ZERO) if i == 0 else box.expand(p)
		if lod >= 0:
			tris[lod] += n_tri
			if lod == 0:
				lo = box.position; hi = box.end; body_box = box
				for i in verts.size(): body_verts.append(xf * verts[i])
				centre = box.get_center()
				# outward means away from the nearest bone (the skeleton is the body's medial axis)
				var segs := _bone_segments(sk, root)
				for i in range(0, verts.size(), 7):
					var p := xf * verts[i]
					var q := _nearest_on(segs, p)
					var d := p - q
					if d.length() < 0.004: continue
					if (xf.basis * nrms[i]).dot(d) >= 0.0: outward += 1
					else: inward += 1
		else:
			parts.append([nmi, box])
	# floating parts: each part (eye, lid, collar) must touch the body: its centre within its own size (+1 cm) of the hide
	for pr in parts:
		var c: Vector3 = (pr[1] as AABB).get_center()
		var ext: float = (pr[1] as AABB).size.length() * 0.5 + 0.01
		var best := 1e9
		for i in body_verts.size():
			best = minf(best, c.distance_to(body_verts[i]))
		if best > ext: _bad(nm, "part %s floats %.3f m off the body" % [pr[0], best])
	var h := hi.y; var ln := hi.z - lo.z
	var r: Array = RANGE.get(nm, [[0.1, 3.0], [0.1, 4.0]])
	if absf(lo.y) > 0.03: _bad(nm, "lowest point at y=%.3f (feet not on the ground, or upside down)" % lo.y)
	if h < r[0][0] or h > r[0][1]: _bad(nm, "height %.2f m outside %s" % [h, str(r[0])])
	if ln < r[1][0] or ln > r[1][1]: _bad(nm, "length %.2f m outside %s" % [ln, str(r[1])])
	if tris[0] <= tris[1] or tris[1] <= tris[2] or tris[2] == 0: _bad(nm, "LOD triangles do not fall: %s" % str(tris))
	if tris[0] > BUDGET.get(nm, 14000): _bad(nm, "LOD0 %d triangles over budget %d" % [tris[0], BUDGET.get(nm, 14000)])
	if tris[1] > tris[0] * 0.45 or tris[2] > tris[0] * 0.16: _bad(nm, "LOD1/2 too heavy: %s" % str(tris))
	if outward < inward * 4: _bad(nm, "normals point inward (%d out, %d in): inside-out mesh?" % [outward, inward])
	if sk != null:
		var hb := sk.find_bone("head")
		if hb < 0: _bad(nm, "no head bone")
		else:
			var hp := _rel(sk, root) * sk.get_bone_global_rest(hb).origin
			if hp.z < centre.z: _bad(nm, "head is behind the middle (faces -Z, not +Z)")
			if hp.y < centre.y: _bad(nm, "head below the middle at rest (upside down?)")
		for bn in ["hips", "head", "jaw", "eyelid_L", "eyelid_R", "tail_01"]:
			if sk.find_bone(bn) < 0: _bad(nm, "missing bone " + bn)
		var legs := ["thigh_L", "shin_L", "thigh_R", "shin_R"]
		for bn in legs:
			if sk.find_bone(bn) < 0: _bad(nm, "missing bone " + bn)
	var eye_l := root.find_child("*eye_L*", true, false) as MeshInstance3D
	if eye_l != null and eye_l.mesh != null:
		var ec := _rel(eye_l, root) * eye_l.mesh.get_aabb().get_center()
		if ec.x <= 0.0: _bad(nm, "left eye on -x (mirrored)")
	else:
		_bad(nm, "no eye_L mesh")
	print("%-10s height %.2f m  length %.2f m  tris %s  clips %s  normals out %d%%" % [nm, h, ln, str(tris), str(ap.get_animation_list() if ap else []), int(100.0 * outward / maxf(outward + inward, 1))])
	root.free()
