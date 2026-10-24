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

# ------------------------------------------------------------------------------------------------ lane/rennick
## Mean colour of a material's albedo texture (0..1), sampled on a coarse grid of opaque texels.
func albedo_mean(m: Material) -> Color:
	if not (m is StandardMaterial3D) or (m as StandardMaterial3D).albedo_texture == null:
		return Color(-1, -1, -1)
	var img := (m as StandardMaterial3D).albedo_texture.get_image()
	if img == null:
		return Color(-1, -1, -1)
	if img.is_compressed():
		img.decompress()
	var acc := Vector3.ZERO
	var n := 0
	var step := maxi(1, img.get_width() / 48)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.r + c.g + c.b > 0.06:
				acc += Vector3(c.r, c.g, c.b); n += 1
	if n == 0:
		return Color(-1, -1, -1)
	acc /= n
	return Color(acc.x, acc.y, acc.z)

func material_named(r: Node, prefix: String) -> Material:
	for mi: MeshInstance3D in r.find_children("*_LOD0", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and String(m.resource_name).begins_with(prefix):
				return m
	return null

func rennick_checks(holder: Node3D) -> void:
	# Constable Ada Rennick, remade to docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md: a Black woman in her early thirties,
	# warm brown skin (tone 2), 1.68 m; the same body in every variant; the ghost a pale build of the 1984 figure.
	var bones := -1
	for nm in ["rennick", "rennick_uniform", "rennick_1984", "rennick_1984_ghost"]:
		var path := "res://assets/models/people/%s.glb" % nm
		if not ResourceLoader.exists(path):
			fail("rennick: missing " + path); continue
		var r := (load(path) as PackedScene).instantiate() as Node3D
		var sk := r.find_child("Skeleton3D", true, false) as Skeleton3D
		if bones < 0: bones = sk.get_bone_count()
		elif sk.get_bone_count() != bones: fail("rennick: %s has %d bones, not %d" % [nm, sk.get_bone_count(), bones])
		var skin := albedo_mean(material_named(r, "skin"))
		var lum := skin.r * 0.2126 + skin.g * 0.7152 + skin.b * 0.0722
		var sat := (maxf(skin.r, maxf(skin.g, skin.b)) - minf(skin.r, minf(skin.g, skin.b))) / maxf(maxf(skin.r, skin.b), 0.001)
		if nm == "rennick_1984_ghost":
			if lum < 0.55 or sat > 0.12: fail("rennick ghost: skin not pale and drained (lum %.2f, sat %.2f)" % [lum, sat])
			var cloth := albedo_mean(material_named(r, "cloth"))
			if cloth.r * 0.2126 + cloth.g * 0.7152 + cloth.b * 0.0722 < 0.5: fail("rennick ghost: uniform not pale")
			if cloth.b < cloth.r: fail("rennick ghost: no cool tint")
		else:
			# warm brown: dark-to-mid luminance, clearly warm (red well over blue)
			if lum < 0.12 or lum > 0.42 or skin.r < skin.b * 1.4: fail("rennick %s: skin is not warm brown (%s)" % [nm, skin])
		if material_named(r, "hair") == null: fail("rennick %s: no hair material" % nm)
		print("  rennick %-20s skin %.2f %.2f %.2f  lum %.2f" % [nm, skin.r, skin.g, skin.b, lum])
		r.free()
	# plain-clothes height without a cap: the brief's 1.68 m (with a close crop)
	var plain := (load("res://assets/models/people/rennick.glb") as PackedScene).instantiate() as Node3D
	var top := -INF
	for mi: MeshInstance3D in plain.find_children("*_LOD0", "MeshInstance3D", true, false):
		top = maxf(top, mi.get_aabb().end.y)
	if top < 1.64 or top > 1.72: fail("rennick: plain-clothes height %.3f m, the brief says 1.68" % top)
	print("  rennick plain-clothes height %.3f m" % top)
	plain.free()
	# the ghost in the game: every surface on the ghost shader, opaque (no blending, so inner layers cannot show through),
	# alpha-cut hair, brows and lashes, no shadow, no glowing eyes, and the fade parameter works
	var g := PeopleAssets.instance("rennick_1984_ghost_a")
	if g == null:
		fail("rennick_1984_ghost_a gave nothing"); return
	holder.add_child(g)
	var sh := load("res://game/shaders/people_ghost.gdshader") as Shader
	if sh.code.contains("blend_") or sh.code.contains("ALPHA ="): fail("ghost shader blends: inner layers would show through")
	var surfaces := 0
	for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null: continue
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: fail("ghost %s casts a shadow" % mi.name)
		for s in mi.mesh.get_surface_count():
			surfaces += 1
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			var src := mi.mesh.surface_get_material(s)
			var k := String(src.resource_name) if src != null else ""
			if m == null or m.shader != sh:
				fail("ghost %s surface %d (%s) not on the ghost shader" % [mi.name, s, k]); continue
			if m.get_shader_parameter("albedo_tex") == null: fail("ghost %s: %s has no baked texture" % [mi.name, k])
			var cut: bool = m.get_shader_parameter("alpha_cut")
			if (k.begins_with("hair") or k.begins_with("brow") or k.begins_with("lash")) != cut:
				fail("ghost %s: %s alpha cut %s" % [mi.name, k, cut])
			if k.begins_with("eye") and float(m.get_shader_parameter("rim_strength")) > 0.0: fail("ghost eyes glow")
	PeopleAssets.set_ghost_fade(g, 0.4, 0.3)
	var body := g.find_child("body_LOD0", true, false) as MeshInstance3D
	var probe := body.get_surface_override_material(0) as ShaderMaterial
	if absf(float(probe.get_shader_parameter("fade")) - 0.4) > 0.001: fail("set_ghost_fade did not set fade")
	PeopleAssets.set_ghost_fade(g, 0.0)
	if body.visible: fail("ghost at fade 0 still visible")
	PeopleAssets.set_ghost_fade(g, 1.0, 0.0)
	print("  rennick ghost: %d surfaces on the opaque ghost shader, fade ok" % surfaces)
	# her props and the old names still resolve
	for nm in ["rennick_hat_a", "rennick_case_file_a", "rennick_portrait_a"]:
		if StoryAssets.instance(nm) == null: fail("story prop %s missing" % nm)
	for pr in ["clipboard", "notebook", "pen"]:
		if PeopleAssets._prop_mesh(pr) == null: fail("people prop %s missing" % pr)
	for f in ["res://assets/ui/avatar_rennick.png", "res://assets/ui/sizes/48/avatar_rennick.png", "res://assets/ui/sizes/96/avatar_rennick.png"]:
		if not ResourceLoader.exists(f): fail("avatar %s missing" % f)

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
	rennick_checks(holder)
	await process_frame
	await process_frame
	holder.queue_free()
	print("PEOPLE TEST PASS" if fails.is_empty() else "PEOPLE TEST FAIL (%d)" % fails.size())
	quit()
