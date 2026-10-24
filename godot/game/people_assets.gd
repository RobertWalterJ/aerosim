class_name PeopleAssets
extends RefCounted
## Blender 2 (lane people): rigged, animated people made in Blender (godot/tools/blender/, MakeHuman CC0 bodies via MPFB).
## Each person is assets/models/people/<person>.glb: Armature/Skeleton3D with Godot humanoid bone names (plus LeftEye and
## RightEye), meshes head_LOD0..2 (face, eyes, brows, lashes, hair; LOD0 has the blend shapes blink, smile, mouth_open,
## mouth_o, mouth_e, mouth_mbp, brow_up), body_LOD0..2 (the skin that shows), clothes_LOD0..2, and on some people
## coat_LODn / backpack_LODn. The clips live in three shared libraries, anim_male.glb, anim_female.glb and anim_child.glb,
## and are copied onto each person (rotations for every bone, the Hips position scaled to the person's hip height).
## Hand-held and ground props are in people_props.glb.
## Usage:  PeopleAssets.place(parent, "ellis_sitting_a_mug", Transform3D(...))  or  PeopleAssets.instance("crowd_walk_a_b")
##         PeopleAssets.person("ellis", "wave")   (any person, any clip)
## Story names (ellis_*, rennick_*, wren_*, crowd_*) resolve to a person, a clip and props through STORY below, so
## StoryAssets keeps working with the old names. Returns null if the person's file is missing (the caller falls back).
## Frame: metres, +Z is the front, origin on the ground at the feet (seated people: the ground under the seat).

const DIR := "res://assets/models/people/"
const LOD_END := [14.0, 45.0, 400.0]

## Which library each person uses.
const BODY := {
	"ellis": "male", "rennick": "female", "rennick_uniform": "female", "rennick_1984": "female", "wren": "female",
	"crowd_m1": "male", "crowd_m2": "male", "crowd_m3": "male", "crowd_f1": "female", "crowd_f2": "female", "crowd_f3": "female",
	"child_boy": "child", "child_girl": "child", "band_singer": "female", "band_guitar": "male", "band_fiddle": "male",
	"band_drummer": "male", "pilot": "male", "bystander": "female",
	# lane/antidrone: the village cast of the character brief, the DroneBudz crew and the other people the story names
	"ifeoma_okafor": "female", "mei_lin": "female", "ravi_patel": "male", "grace_adeyemi": "female", "hana_sato": "female",
	"priya_nair": "female", "daniel_whitlock": "male", "arthur_bell": "male",
	"maya": "female", "jo": "female", "riley": "male", "tom": "male", "alex": "male", "sam": "female", "kit": "male",
	"harlan_pike": "male", "farmer": "male", "nora_pike": "female", "councillor_bain": "male",
}

## Display names and village ids (village.gd, character_data) -> person file, so code can ask by the name it already uses.
const ALIASES := {
	"Ifeoma Okafor": "ifeoma_okafor", "Ada Okafor": "ifeoma_okafor", "Mei Lin": "mei_lin", "Ravi Patel": "ravi_patel",
	"Grace Adeyemi": "grace_adeyemi", "Hana Sato": "hana_sato", "Priya Nair": "priya_nair",
	"Daniel Whitlock": "daniel_whitlock", "Arthur Bell": "arthur_bell", "Wren": "wren", "Maya": "maya", "Jo": "jo",
	"Riley": "riley", "Tom": "tom", "Alex": "alex", "Sam": "sam", "Kit": "kit", "Harlan Pike": "harlan_pike",
	"Nora Pike": "nora_pike", "Councillor Bain": "councillor_bain", "Ellis Voss": "ellis", "Ellis": "ellis",
	"Rennick": "rennick", "Constable Ada Rennick": "rennick_1984",
}

## The person file for a display name, id or file name ("" if none).
static func resolve(name: String) -> String:
	if BODY.has(name): return name
	if ALIASES.has(name): return ALIASES[name]
	var k := name.to_lower().replace(" ", "_")
	return k if BODY.has(k) else ""

## Story asset name -> person, clip, props ("name:L" / "name:R" in a hand, "name:C" on the chest, "name" on the ground,
## "name@x,y,z,yaw" on the ground with an offset in the person's frame), optional cloth tint and ghost.
const STORY := {
	"ellis_standing_a": {"p": "ellis", "a": "pockets"},
	"ellis_standing_a_hips": {"p": "ellis", "a": "hands_hips"},
	"ellis_sitting_a": {"p": "ellis", "a": "sit_idle", "props": ["camp_chair"]},
	"ellis_sitting_a_mug": {"p": "ellis", "a": "sit_mug", "props": ["camp_chair", "mug:R"]},
	"ellis_under_bus_a": {"p": "ellis", "a": "lie_creeper", "props": ["creeper@0,0,-0.32,0"]},
	"ellis_waving_a": {"p": "ellis", "a": "wave"},
	"ellis_toolbox_a": {"p": "ellis", "a": "toolbox_kneel", "props": ["toolbox_open@-0.32,0,0.5,0.4"]},
	"ellis_toolbox_a_closed": {"p": "ellis", "a": "toolbox_kneel", "props": ["toolbox_closed@-0.32,0,0.5,0.4"]},
	"ellis_talking_a": {"p": "ellis", "a": "talk"},
	"ellis_walking_a": {"p": "ellis", "a": "walk"},
	"rennick_standing_a": {"p": "rennick", "a": "idle"},
	"rennick_standing_a_clipboard": {"p": "rennick", "a": "clipboard_hold", "props": ["clipboard:L"]},
	"rennick_walking_a": {"p": "rennick", "a": "walk"},
	"rennick_knocking_a": {"p": "rennick", "a": "knock", "props": ["notebook:L"]},
	"rennick_uniform_a": {"p": "rennick_uniform", "a": "idle"},
	"rennick_uniform_a_writing": {"p": "rennick_uniform", "a": "clipboard_write", "props": ["clipboard:L", "pen:R"]},
	"rennick_1984_standing_a": {"p": "rennick_1984", "a": "idle"},
	"rennick_1984_standing_a_notebook": {"p": "rennick_1984", "a": "notebook_hold", "props": ["notebook:L"]},
	"rennick_1984_ghost_a": {"p": "rennick_1984", "a": "idle", "ghost": true},
	"wren_standing_phone_a": {"p": "wren", "a": "phone_hold", "props": ["phone:R"]},
	"wren_sitting_porch_a": {"p": "wren", "a": "sit_hug_knees"},
	"wren_walking_torch_a": {"p": "wren", "a": "walk_torch", "props": ["torch:R"]},
	"wren_waving_a": {"p": "wren", "a": "wave_up"},
	"wren_crouched_a": {"p": "wren", "a": "crouch"},
	"crowd_stand_a": {"p": "crowd_m1", "a": "idle"},
	"crowd_stand_a_b": {"p": "crowd_f1", "a": "idle_shift"},
	"crowd_stand_a_c": {"p": "crowd_m3", "a": "talk"},
	"crowd_stand_a_d": {"p": "crowd_f2", "a": "look_around"},
	"crowd_walk_a": {"p": "crowd_m2", "a": "walk"},
	"crowd_walk_a_b": {"p": "crowd_f3", "a": "walk"},
	"crowd_walk_a_c": {"p": "bystander", "a": "walk"},
	"crowd_child_a": {"p": "child_girl", "a": "flag_wave", "props": ["flag:R"]},
	"crowd_child_a_b": {"p": "child_boy", "a": "cheer"},
	"crowd_child_a_c": {"p": "child_boy", "a": "clap", "tint": Color(0.6, 0.75, 1.0)},
	"crowd_point_a": {"p": "crowd_m3", "a": "point", "tint": Color(0.75, 0.85, 1.0)},
	"crowd_point_a_b": {"p": "crowd_f1", "a": "point", "tint": Color(1.0, 0.8, 0.75)},
	"crowd_cheer_a": {"p": "crowd_f3", "a": "clap"},
	"crowd_cheer_a_b": {"p": "crowd_m2", "a": "cheer", "tint": Color(0.7, 0.9, 0.8)},
	"crowd_seated_a": {"p": "crowd_m1", "a": "sit_idle", "props": ["camp_chair"], "tint": Color(0.85, 0.85, 1.0)},
	"crowd_seated_a_b": {"p": "crowd_f2", "a": "sit_idle", "props": ["camp_chair"]},
	"crowd_sway_a": {"p": "crowd_f1", "a": "sway"},
	"pilot_standing_a": {"p": "pilot", "a": "look_up"},
	"bystander_standing_a": {"p": "bystander", "a": "idle"},
}

## The band (crowd_band_a): singer with a mic stand, guitarist, fiddler and a drummer behind a small kit (no weapons).
const BAND := [
	{"p": "band_singer", "a": "sing", "props": ["mic:R", "mic_stand"], "at": Vector3(-1.4, 0, 0.4)},
	{"p": "band_guitar", "a": "play_guitar", "props": ["guitar:C"], "at": Vector3(-0.2, 0, 0.5), "yaw": 0.25},
	{"p": "band_fiddle", "a": "play_fiddle", "props": ["fiddle:F", "bow:R"], "at": Vector3(1.0, 0, 0.45), "yaw": -0.3},
	{"p": "band_drummer", "a": "play_drum", "props": ["drum_kit", "stick_l:L", "stick_r:R"], "at": Vector3(0.0, 0, -1.3)},
]

static var _scenes := {}
static var _libs := {}
static var _props: Node3D = null
static var _mats := {}
static var _ghost: ShaderMaterial = null

static func handles(name: String) -> bool:
	return STORY.has(name) or name == "crowd_band_a" or BODY.has(name) or ALIASES.has(name)

static func available(person_name: String) -> bool:
	return ResourceLoader.exists(DIR + person_name + ".glb")

## A story asset by name (see STORY), or null if its person file is missing.
static func instance(name: String) -> Node3D:
	if name == "crowd_band_a":
		return band()
	if BODY.has(name) or ALIASES.has(name):
		return person(resolve(name), "idle")
	if not STORY.has(name):
		return null
	var s: Dictionary = STORY[name]
	var n := person(s["p"], s["a"], s.get("props", []), s.get("tint", Color(1, 1, 1)), s.get("ghost", false), hash(name))
	if n != null:
		n.name = name
	return n

static func place(parent: Node, name: String, xf: Transform3D) -> Node3D:
	var n := instance(name)
	if n == null:
		return null
	n.transform = xf
	parent.add_child(n)
	return n

static func band() -> Node3D:
	var root := Node3D.new()
	root.name = "crowd_band_a"
	for m: Dictionary in BAND:
		var n := person(m["p"], m["a"], m.get("props", []), Color(1, 1, 1), false, hash(m["p"]))
		if n == null:
			root.free()
			return null
		n.position = m["at"]
		n.rotation.y = m.get("yaw", 0.0)
		root.add_child(n)
	return root

## Any person playing any clip (looping), with props. seed picks the start time in the loop so a crowd is not in step.
static func person(person_name: String, clip := "idle", props: Array = [], tint := Color(1, 1, 1), ghost := false, seed := 0) -> Node3D:
	var path := DIR + person_name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var ps := _scenes[path] as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate() as Node3D
	root.name = person_name
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	_setup_meshes(root, tint, ghost)
	if skel != null:
		var ap := AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		root.add_child(ap)
		var lib := library(BODY.get(person_name, "male"), skel, person_name)
		if lib != null:
			ap.add_animation_library("", lib)
			var c := clip if lib.has_animation(clip) else "idle"
			ap.play(c)
			var length := lib.get_animation(c).length
			ap.seek(fposmod(float(seed % 997) * 0.618, 1.0) * length, true)
			ap.speed_scale = 0.94 + float(seed % 13) * 0.01
		for pr in props:
			_attach_prop(root, skel, String(pr))
		var face := PeopleFace.new()
		face.name = "Face"
		face.setup(root, clip, seed)
		root.add_child(face)
	return root

# ------------------------------------------------------------------------------------------------ animation libraries
## The shared clips, retargeted onto one person's skeleton. The library's rotations are absolute (its own rest times the
## pose), so each key becomes this skeleton's rest times the library's change from its rest: the same pose on a body with
## slightly different bone rolls. Only the Hips keep a position track (the change from rest, scaled to this person's hip
## height), so one set of clips fits adults and children. Cached per person file.
static func library(body: String, skel: Skeleton3D, person_key := "") -> AnimationLibrary:
	var src := _source_library(body)
	if src == null:
		return null
	var key := "%s_%s" % [body, person_key if person_key != "" else str(skel.get_bone_count())]
	if _libs.has(key):
		return _libs[key]
	var lrest: Dictionary = src.get_meta("rests", {})
	var hips := skel.find_bone("Hips")
	var ratio := 1.0
	if hips >= 0 and src.has_meta("hips_y"):
		ratio = skel.get_bone_global_rest(hips).origin.y / float(src.get_meta("hips_y"))
	var lib := AnimationLibrary.new()
	for an in src.get_animation_list():
		var a := (src.get_animation(an) as Animation).duplicate(true) as Animation
		for t in range(a.get_track_count() - 1, -1, -1):
			var tp := a.track_get_type(t)
			var p := str(a.track_get_path(t))
			var bone := p.get_slice(":", 1)
			var bi := skel.find_bone(bone)
			if tp == Animation.TYPE_SCALE_3D or tp == Animation.TYPE_BLEND_SHAPE or (bi < 0 and bone != ""):
				a.remove_track(t)
			elif tp == Animation.TYPE_POSITION_3D:
				if bone != "Hips":
					a.remove_track(t)
				else:
					var r0: Vector3 = (lrest[bone] as Transform3D).origin if lrest.has(bone) else Vector3.ZERO
					var c0 := skel.get_bone_rest(bi).origin
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, c0 + ((a.track_get_key_value(t, k) as Vector3) - r0) * ratio)
			elif tp == Animation.TYPE_ROTATION_3D and lrest.has(bone):
				var lq := (lrest[bone] as Transform3D).basis.get_rotation_quaternion()
				var cq := skel.get_bone_rest(bi).basis.get_rotation_quaternion()
				var fix := cq * lq.inverse()
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, (fix * (a.track_get_key_value(t, k) as Quaternion)).normalized())
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(an, a)
	_libs[key] = lib
	return lib

static func _source_library(body: String) -> AnimationLibrary:
	var key := "src_" + body
	if _libs.has(key):
		return _libs[key]
	var path := DIR + "anim_" + body + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate()
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := n.find_child("Skeleton3D", true, false) as Skeleton3D
	var lib: AnimationLibrary = null
	if ap != null and ap.has_animation_library(""):
		lib = ap.get_animation_library("")
		if skel != null and skel.find_bone("Hips") >= 0:
			lib.set_meta("hips_y", skel.get_bone_global_rest(skel.find_bone("Hips")).origin.y)
			var rests := {}
			for i in skel.get_bone_count():
				rests[skel.get_bone_name(i)] = skel.get_bone_rest(i)
			lib.set_meta("rests", rests)
	n.free()
	_libs[key] = lib
	return lib

static func clip_names() -> PackedStringArray:
	var lib := _source_library("male")
	return lib.get_animation_list() if lib != null else PackedStringArray()

# ------------------------------------------------------------------------------------------------ materials and LODs
static func _setup_meshes(root: Node, tint: Color, ghost: bool) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		var lod := 0
		if nm.ends_with("_LOD1"): lod = 1
		elif nm.ends_with("_LOD2"): lod = 2
		mi.visibility_range_begin = 0.0 if lod == 0 else LOD_END[lod - 1]
		mi.visibility_range_end = LOD_END[lod]
		mi.visibility_range_begin_margin = 0.0 if lod == 0 else 1.0
		mi.visibility_range_end_margin = 1.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if ghost:
				mi.set_surface_override_material(s, ghost_material())
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			if m == null:
				continue
			var fixed := _fix_material(m)
			if tint != Color(1, 1, 1) and fixed.resource_name.begins_with("cloth"):
				fixed = _tinted(fixed, tint)
			if fixed != m:
				mi.set_surface_override_material(s, fixed)

## The imported glTF materials, adjusted once each: skin gets subsurface scattering, a soft rim and back light (ears and
## fingers glow a little against the sun; Forward+ only, the mobile renderer ignores it), hair uses alpha-to-coverage cut-out.
static func _fix_material(m: Material) -> Material:
	if not (m is StandardMaterial3D):
		return m
	if _mats.has(m):
		return _mats[m]
	var sm := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
	var k := sm.resource_name
	if k.begins_with("skin"):
		sm.subsurf_scatter_enabled = true
		sm.subsurf_scatter_strength = 0.35
		sm.subsurf_scatter_skin_mode = true
		sm.subsurf_scatter_transmittance_enabled = true
		sm.subsurf_scatter_transmittance_color = Color(0.9, 0.35, 0.25)
		sm.subsurf_scatter_transmittance_depth = 0.08
		sm.subsurf_scatter_transmittance_boost = 0.15
		sm.rim_enabled = true
		sm.rim = 0.25
		sm.rim_tint = 0.6
		sm.roughness = 0.55
		sm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	elif k.begins_with("hair"):
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		sm.alpha_scissor_threshold = 0.4
		sm.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.rim_enabled = true
		sm.rim = 0.3
		sm.rim_tint = 0.8
		sm.roughness = 0.62
	elif k.begins_with("brow") or k.begins_with("lash"):
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif k.begins_with("eye"):
		sm.roughness = 0.08
		sm.metallic_specular = 0.6
	elif k.begins_with("cloth"):
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.rim_enabled = true
		sm.rim = 0.12
		sm.rim_tint = 0.7
	_mats[m] = sm
	return sm

static func _tinted(m: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key := [m, tint]
	if _mats.has(key):
		return _mats[key]
	var t := m.duplicate() as StandardMaterial3D
	t.albedo_color = m.albedo_color * tint
	_mats[key] = t
	return t

## Rennick's ghost: pale, translucent, a soft rim, no hard edges (game/shaders/people_ghost.gdshader).
static func ghost_material() -> ShaderMaterial:
	if _ghost == null:
		_ghost = ShaderMaterial.new()
		_ghost.shader = load("res://game/shaders/people_ghost.gdshader")
	return _ghost

# ------------------------------------------------------------------------------------------------ props
static func _prop_mesh(pname: String) -> Node3D:
	if _props == null:
		var path := DIR + "people_props.glb"
		if not ResourceLoader.exists(path):
			return null
		_props = (load(path) as PackedScene).instantiate() as Node3D
	var src := _props.find_child("prop_" + pname, true, false) as Node3D
	if src == null:
		return null
	var n := src.duplicate() as Node3D
	n.transform = Transform3D.IDENTITY
	n.name = "prop_" + pname
	return n

static func _attach_prop(root: Node3D, skel: Skeleton3D, spec: String) -> void:
	var where := ""
	var off := Transform3D.IDENTITY
	var pname := spec
	if spec.contains(":"):
		pname = spec.get_slice(":", 0)
		where = spec.get_slice(":", 1)
	elif spec.contains("@"):
		pname = spec.get_slice("@", 0)
		var v := spec.get_slice("@", 1).split(",")
		off = Transform3D(Basis(Vector3.UP, float(v[3])), Vector3(float(v[0]), float(v[1]), float(v[2])))
	var n := _prop_mesh(pname)
	if n == null:
		return
	if where == "":
		n.transform = off
		root.add_child(n)
		return
	var bone := "RightHand" if where == "R" else ("LeftHand" if where == "L" else ("Head" if where == "F" else "UpperChest"))
	var bi := skel.find_bone(bone)
	if bi < 0:
		return
	var att := BoneAttachment3D.new()
	att.name = "hold_" + pname
	att.bone_name = bone
	skel.add_child(att)
	var rest := skel.get_bone_global_rest(bi)
	var model: Transform3D
	if where == "C":
		model = _chest_frame(skel)
	elif where == "F":
		model = _fiddle_frame(skel)
	else:
		model = grip_frame(skel, where == "L") * _GRIP_FIX
	n.transform = rest.affine_inverse() * model
	att.add_child(n)

## A prop modelled in Blender with its handle along x, the fingers along y and the palm normal along z arrives in Godot
## with Blender y as -z and Blender z as +y; this turns it back into the grip frame.
const _GRIP_FIX := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0)), Vector3.ZERO)

## The grip frame of a hand at rest, in skeleton space: origin in the middle of the palm (where a fist holds a handle),
## y along the fingers, z out of the palm, x across the knuckles.
static func grip_frame(skel: Skeleton3D, left: bool) -> Transform3D:
	var S := "Left" if left else "Right"
	var p := func(b: String) -> Vector3: return skel.get_bone_global_rest(skel.find_bone(S + b)).origin
	var hand: Vector3 = p.call("Hand")
	var idx: Vector3 = p.call("IndexProximal")
	var lit: Vector3 = p.call("LittleProximal")
	var mid: Vector3 = p.call("MiddleProximal")
	var thumb: Vector3 = p.call("ThumbDistal")
	var y := (mid - hand).normalized()
	var lat := (lit - idx)
	lat = (lat - y * lat.dot(y)).normalized()
	var z := lat.cross(y).normalized()
	var knuck := (idx + lit) * 0.5
	if z.dot(thumb - knuck) < 0.0:
		z = -z
	var x := y.cross(z).normalized()
	var o := hand.lerp(mid, 0.75) + z * 0.03
	return Transform3D(Basis(x, y, z), o)

## Fiddle under the chin: the body tucked against the left collarbone, the neck pointing forward and to the player's
## left, soundboard up. Rides on the head bone (the chin holds it).
static func _fiddle_frame(skel: Skeleton3D) -> Transform3D:
	var sh := skel.get_bone_global_rest(skel.find_bone("LeftShoulder")).origin
	var nk := skel.get_bone_global_rest(skel.find_bone("Neck")).origin
	var chin := nk.lerp(sh, 0.6) + Vector3(0, 0.02, 0.06)
	var fwd := Vector3(0.55, 0.12, 1.0).normalized()          # toward the scroll
	var x := -fwd
	var up := Vector3(-0.25, 1, 0).normalized()
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), chin + fwd * 0.42)

## Chest frame for a strapped instrument: soundboard to the front, neck to the player's left and tilted up, the body in
## front of the belly a little to the player's right.
static func _chest_frame(skel: Skeleton3D) -> Transform3D:
	var h := skel.get_bone_global_rest(skel.find_bone("Hips")).origin
	var b := Basis(Vector3(0, 0, 1), 0.42) * Basis(Vector3(1, 0, 0), PI * 0.5)
	return Transform3D(b, h + Vector3(-0.1, 0.14, 0.16))
