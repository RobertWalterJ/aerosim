extends SceneTree
## Blender 2 people check (headless):  Godot --headless --path godot -s res://test/people_blender_test.gd
## Loads every person, checks the skeleton (Godot humanoid names), the LOD meshes and their triangle budgets, the height in
## metres, that no vertex is NaN, that the three animation libraries carry every clip, that the face blend shapes are
## there, and that every story name resolves to a person that animates. Prints PEOPLE TEST PASS or PEOPLE TEST FAIL.

const BONES := ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftEye", "RightEye",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftThumbMetacarpal", "LeftIndexProximal", "LeftLittleDistal",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightMiddleIntermediate",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]
const CLIPS := ["idle", "idle_shift", "walk", "sit_idle", "talk", "wave", "look_around", "clap", "sway", "cheer", "point",
	"play_guitar", "play_fiddle", "play_drum", "sing", "crouch", "kneel", "sit_hug_knees", "walk_torch", "phone_hold",
	"pockets", "hands_hips", "sit_mug", "toolbox_kneel", "lie_creeper", "clipboard_hold", "clipboard_write", "knock", "flag_wave", "wave_up"]
const SHAPES := ["blink", "smile", "mouth_open", "mouth_o", "mouth_e", "mouth_mbp", "brow_up"]
const BUDGET := [9600, 4400, 1700]

var fails: Array[String] = []

func fail(s: String) -> void:
	fails.append(s)
	print("  FAIL ", s)

func tris_and_nan(mi: MeshInstance3D) -> Array:
	var t := 0
	var bad := false
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		t += (idx.size() if idx.size() > 0 else pos.size()) / 3
		for p in pos:
			if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): bad = true
			lo = lo.min(p); hi = hi.max(p)
	return [t, bad, lo, hi]

func _initialize() -> void:
	print("== Blender 2 people")
	for body in ["male", "female", "child"]:
		var p := "res://assets/models/people/anim_%s.glb" % body
		if not ResourceLoader.exists(p):
			fail("missing library " + p)
			continue
		var n := (load(p) as PackedScene).instantiate()
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null:
			fail(body + ": no AnimationPlayer")
		else:
			for c in CLIPS:
				if not ap.has_animation(c): fail("%s library: no clip %s" % [body, c])
			print("  library %-7s %d clips" % [body, ap.get_animation_list().size()])
		n.free()
	for person in PeopleAssets.BODY:
		var path := "res://assets/models/people/%s.glb" % person
		if not ResourceLoader.exists(path):
			fail("missing " + path)
			continue
		var root := (load(path) as PackedScene).instantiate() as Node3D
		var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel == null:
			fail(person + ": no Skeleton3D")
			root.free()
			continue
		for b in BONES:
			if skel.find_bone(b) < 0: fail("%s: no bone %s" % [person, b])
		var lods := [0, 0, 0]
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var shapes_ok := false
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			var l := 0 if nm.ends_with("_LOD0") else (1 if nm.ends_with("_LOD1") else (2 if nm.ends_with("_LOD2") else -1))
			if l < 0:
				fail("%s: mesh %s is not named _LODn" % [person, nm]); continue
			if mi.skin == null and mi.skeleton == NodePath(""):
				fail("%s: %s not skinned" % [person, nm])
			var r := tris_and_nan(mi)
			lods[l] += r[0]
			if r[1]: fail("%s: NaN in %s" % [person, nm])
			if l == 0:
				lo = lo.min(r[2]); hi = hi.max(r[3])
			if nm == "head_LOD0":
				var am := mi.mesh as ArrayMesh
				var have := []
				for i in am.get_blend_shape_count(): have.append(String(am.get_blend_shape_name(i)))
				shapes_ok = true
				for s in SHAPES:
					if not s in have:
						fail("%s: no blend shape %s" % [person, s]); shapes_ok = false
		for l in 3:
			if lods[l] == 0: fail("%s: no LOD%d" % [person, l])
			elif lods[l] > BUDGET[l]: fail("%s: LOD%d %d triangles > %d" % [person, l, lods[l], BUDGET[l]])
		var h := hi.y - lo.y
		var child: bool = PeopleAssets.BODY[person] == "child"
		if (child and (h < 1.0 or h > 1.5)) or (not child and (h < 1.5 or h > 1.95)):
			fail("%s: height %.2f m" % [person, h])
		if absf(lo.y) > 0.03: fail("%s: feet at y %.3f, not on the ground" % [person, lo.y])
		print("  %-16s tris %5d / %4d / %4d  height %.2f m  bones %d  shapes %s" % [person, lods[0], lods[1], lods[2], h, skel.get_bone_count(), "ok" if shapes_ok else "MISSING"])
		root.free()
	# every story name gives a person that animates, with its props
	var holder := Node3D.new()
	root.add_child(holder)
	var names: Array = PeopleAssets.STORY.keys()
	names.append("crowd_band_a")
	for nm in names:
		var n := PeopleAssets.instance(nm)
		if n == null:
			fail("story name %s gave nothing" % nm); continue
		holder.add_child(n)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null or not ap.is_playing():
			fail("%s: not animating" % nm)
		var s: Dictionary = PeopleAssets.STORY.get(nm, {})
		for pr in s.get("props", []):
			var pn := "prop_" + String(pr).get_slice(":", 0).get_slice("@", 0)
			if n.find_child(pn, true, false) == null: fail("%s: prop %s missing" % [nm, pn])
	print("  %d story names resolved" % names.size())
	if StoryAssets.instance("ellis_sitting_a_mug").find_child("Skeleton3D", true, false) == null:
		fail("StoryAssets does not route ellis_sitting_a_mug to the people")
	await process_frame
	await process_frame
	holder.queue_free()
	print("PEOPLE TEST PASS" if fails.is_empty() else "PEOPLE TEST FAIL (%d)" % fails.size())
	quit()
