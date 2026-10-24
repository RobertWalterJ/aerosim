class_name AnimalAssets
extends RefCounted
## The Blender animals (lane/animals, "Blender 1: animals" in game/README-models.md): rigged, animated glTF files under assets/models/animals/, made by
## tools/blender/build_animal.py. Each file holds a Skeleton3D, an AnimationPlayer with named clips, three levels of detail
## (<name>_LOD0/1/2) and the eyes and eyelids. Here they are loaded, the levels of detail are switched by distance, the coat
## gets the shell-fur shader (game/shaders/fur.gdshader in its `maps` mode) and the idle clip starts at a random point so a
## herd does not move in step. If a file is missing the old code-built model (NewModels5) stands in, still and unrigged.
##
## Usage:  var cow := AnimalAssets.place(self, "cow_a", Transform3D(basis, pos))          # plays "idle"
##         AnimalAssets.play(cow, "walk")                                                 # any clip in CLIPS[name]
##         AnimalAssets.place(self, "biscuit_a", xf, {"clip": "sit"})
## Frame (the story brief's, as Batch 8): metres, Y up, +Z is the front, origin on the ground under the middle of the animal,
## its right-hand side is -x. Bones are listed in game/README-models.md, "Blender 1: animals (lane/animals)".

const NAMES: Array[String] = ["cow_a", "cow_b", "cow_c", "calf_a", "sheep_a", "sheep_b", "lamb_a", "ram_a", "horse_a", "horse_b", "chicken_a",
	"dog_a", "biscuit_a", "lost_dog_a", "wolf_a", "wolf_collar_a"]

## The wildlife brief's names (godot/docs/CLAUDE-WILDLIFE-ASSETS.md): each is one of the animals above playing a clip, at a scale,
## with a wool tint. instance("sheep_grazing_a", {"tint": "cream"}) works like any other name.
const ALIASES := {
	"wolf_standing_a": ["wolf_a", "idle", 1.0], "wolf_walking_a": ["wolf_a", "walk", 1.0], "wolf_looking_a": ["wolf_a", "look", 1.0],
	"wolf_trotting_a": ["wolf_a", "trot", 1.0],
	"sheep_grazing_a": ["sheep_b", "graze", 0.8], "sheep_standing_a": ["sheep_b", "idle", 0.8], "sheep_lamb_a": ["lamb_a", "idle", 1.0],
	"sheep_ram_a": ["ram_a", "idle", 0.85], "sheepdog_a": ["dog_a", "idle", 1.0],
}
## Wool tints for the flock (multiplies the fleece only): white, cream and a grey-brown.
const TINTS := {"white": Color(1.0, 1.0, 1.0), "cream": Color(1.0, 0.94, 0.82), "grey": Color(0.78, 0.73, 0.66)}

const QUAD_CLIPS: Array[String] = ["idle", "walk", "trot", "run", "graze"]
const DOG_CLIPS: Array[String] = ["idle", "walk", "trot", "run", "sit", "lie", "tail_wag", "bark", "pant"]
const HEN_CLIPS: Array[String] = ["idle", "walk", "run", "peck"]
const WOLF_CLIPS: Array[String] = ["idle", "walk", "trot", "run", "look"]

## Which shell-fur preset of NewModels5.FUR each animal wears ("" = none: the hen has feathers).
const FUR_KEY := {"cow_a": "holstein", "cow_b": "hereford", "cow_c": "jersey", "calf_a": "holstein", "sheep_a": "wool", "sheep_b": "wool",
	"lamb_a": "wool", "ram_a": "wool", "horse_a": "horse", "horse_b": "horse", "chicken_a": "", "dog_a": "hair", "biscuit_a": "hair", "lost_dog_a": "hair",
	"wolf_a": "hair", "wolf_collar_a": "hair"}

## Filled in from the build (tools/blender/build_animal.py prints them; game/animal_info.gd keeps them): metres of hide per UV unit,
## the clips' ground speeds (m/s) and the standing height.
const LOD_FAR := [8.0, 25.0, 80.0]        # shells near / fewer shells / LOD1 plain coat / LOD2 beyond
static var _scenes := {}
static var _mats := {}

static func clips(name: String) -> Array[String]:
	if name == "chicken_a": return HEN_CLIPS
	if name.begins_with("wolf"): return WOLF_CLIPS
	if name in ["dog_a", "biscuit_a", "lost_dog_a"]: return DOG_CLIPS
	return QUAD_CLIPS

static func path_of(name: String) -> String:
	return "res://assets/models/animals/%s.glb" % name

static func has_file(name: String) -> bool:
	return ResourceLoader.exists(path_of(name))

## A new animal, playing `opts.clip` (default "idle"). opts: clip, seed (int, for the start offset), fur (bool, default on),
## lod (-1 = by distance; 0, 1 or 2 to force one), speed_scale (animation speed).
static func instance(name: String, opts := {}) -> Node3D:
	if ALIASES.has(name):
		var al: Array = ALIASES[name]
		var o2 := opts.duplicate()
		if not o2.has("clip"): o2["clip"] = al[1]
		var n := instance(al[0], o2)
		n.name = name
		var sc: float = float(al[2]) * float(opts.get("scale", 1.0))
		if sc != 1.0:
			for c in n.get_children():
				if c is Node3D: (c as Node3D).scale *= sc
		return n
	if not has_file(name):
		return _fallback(name)
	var ps: PackedScene = _scenes.get(name)
	if ps == null:
		ps = load(path_of(name)) as PackedScene
		_scenes[name] = ps
	var root := ps.instantiate() as Node3D
	root.name = name
	var ap := find_player(root)
	if ap != null:
		for an in ap.get_animation_list():
			var a := ap.get_animation(an)
			if a != null: a.loop_mode = Animation.LOOP_LINEAR
	_setup_lods(root, name, int(opts.get("lod", -1)), bool(opts.get("fur", true)), opts.get("tint", "white"))
	if bool(opts.get("parts", false)): heat_parts(root)
	if ap != null:
		var clip: String = opts.get("clip", "idle")
		if not ap.has_animation(clip): clip = "idle"
		ap.play(clip)
		ap.speed_scale = float(opts.get("speed_scale", 1.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(opts.get("seed", hash(str(root.get_instance_id()))))
		ap.seek(rng.randf() * ap.current_animation_length, true)
	return root

static func place(parent: Node, name: String, xf: Transform3D, opts := {}) -> Node3D:
	var n := instance(name, opts)
	n.transform = xf
	parent.add_child(n)
	return n

## Switch an animal (made by instance/place) to another clip, blending over `blend` seconds.
static func play(animal: Node, clip: String, blend := 0.25) -> void:
	var ap := find_player(animal)
	if ap != null and ap.has_animation(clip):
		ap.play(clip, blend)

static func find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := find_player(c)
		if r != null: return r
	return null

static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := find_skeleton(c)
		if r != null: return r
	return null

static func meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): meshes(c, out)
	return out

# ------------------------------------------------------------------ levels of detail and fur
static func _setup_lods(root: Node3D, name: String, force: int, fur: bool, tint = "white") -> void:
	var tc: Color = TINTS.get(tint, Color.WHITE) if tint is String else tint
	var key: String = FUR_KEY.get(name, "")
	var info: Dictionary = AnimalInfo.INFO.get(name, {})
	var mobile := OS.has_feature("mobile") or RenderingServer.get_current_rendering_method() != "forward_plus"
	for mi: MeshInstance3D in meshes(root):
		var nm := String(mi.name)
		var lod := 0
		if nm.ends_with("_LOD1"): lod = 1
		elif nm.ends_with("_LOD2"): lod = 2
		elif nm.ends_with("_LOD0"): lod = 0
		else:
			# eyes, lids, hair cards and feathers: near and middle only
			_range(mi, 0.0, LOD_FAR[1] if force < 0 else (1e6 if force <= 1 else -1.0))
			_tune_part(mi)
			continue
		if force >= 0:
			mi.visible = lod == force
			if lod == force and fur and key != "": _fur(mi, name, key, info, 0 if force == 0 else 2, mobile, tc)
			continue
		match lod:
			0:
				_range(mi, 0.0, LOD_FAR[0] if (fur and key != "") else LOD_FAR[1])
				if fur and key != "":
					_fur(mi, name, key, info, 0, mobile, tc)
					# the same hide from 8 to 25 m with fewer shells: a second instance of the LOD0 mesh on the same skeleton
					var mid := mi.duplicate() as MeshInstance3D
					mid.name = name + "_LOD0_mid"
					mi.get_parent().add_child(mid)
					_range(mid, LOD_FAR[0], LOD_FAR[1])
					_fur(mid, name, key, info, 1, mobile, tc)
			1:
				_range(mi, LOD_FAR[1], LOD_FAR[2])
				if fur and key != "": _fur(mi, name, key, info, 2, mobile, tc)
			2:
				_range(mi, LOD_FAR[2], 0.0)

static func _range(mi: GeometryInstance3D, a: float, b: float) -> void:
	if b < 0.0:
		mi.visible = false
		return
	mi.visibility_range_begin = a
	mi.visibility_range_end = b
	mi.visibility_range_begin_margin = 1.0 if a > 0.0 else 0.0
	mi.visibility_range_end_margin = 1.0 if b > 0.0 else 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

## The imported coat material (albedo, normal, ORM) becomes the shell-fur chain: the skin pass and `shells` shells.
static func _fur(mi: MeshInstance3D, name: String, key: String, info: Dictionary, lod: int, mobile: bool, tint := Color.WHITE) -> void:
	if mi.mesh == null: return
	var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
	if src == null: return
	var ck := "%s/%d/%s/%s" % [name, lod, "m" if mobile else "d", tint.to_html()]
	var first: ShaderMaterial = _mats.get(ck)
	if first == null:
		var shader := load("res://game/shaders/fur.gdshader") as Shader
		var n: int = NewModels5.fur_shells(lod)
		var prm: Dictionary = NewModels5.FUR[key]
		var prev: ShaderMaterial = null
		for i in n + 1:
			var m := ShaderMaterial.new()
			m.shader = shader
			for k in prm: m.set_shader_parameter(k, prm[k])
			m.set_shader_parameter("maps", true)
			m.set_shader_parameter("maps_tint", Vector3(tint.r, tint.g, tint.b))
			# the baked maps already carry the coat's sheen in their roughness: soften the strand highlights so a black coat
			# does not read as glossy plastic
			m.set_shader_parameter("spec1", float(prm.get("spec1", 0.45)) * 0.6)
			m.set_shader_parameter("spec2", float(prm.get("spec2", 0.2)) * 0.6)
			m.set_shader_parameter("scatter", float(prm.get("scatter", 0.5)) * 0.5)
			# the baked albedo already holds the coat's light and dark: keep the strands close to it (less glitter)
			m.set_shader_parameter("root_dark", maxf(float(prm.get("root_dark", 0.5)), 0.82))
			m.set_shader_parameter("tip_light", 1.03)
			m.set_shader_parameter("patch_thr", 1.0)
			m.set_shader_parameter("albedo_map", src.albedo_texture)
			m.set_shader_parameter("normal_map", src.normal_texture)
			m.set_shader_parameter("orm_map", src.roughness_texture if src.roughness_texture != null else src.ao_texture)
			m.set_shader_parameter("uv_m", float(info.get("uv_m", 3.0)))
			m.set_shader_parameter("flow", Vector3(0.0, -0.25, -1.0))      # +Z is the front here: the hair lies back toward -z
			m.set_shader_parameter("coat_tex", load("res://assets/textures/wool_diff.jpg"))
			m.set_shader_parameter("coat_nor", load("res://assets/textures/wool_nor.jpg"))
			m.set_shader_parameter("shell_t", float(i) / maxf(n, 1.0))
			m.set_shader_parameter("flat_coat", 1.0 if n == 0 else 0.0)
			if prev != null: prev.next_pass = m
			else: first = m
			prev = m
		_mats[ck] = first
	mi.set_surface_override_material(0, first)

static func _tune_part(mi: MeshInstance3D) -> void:
	var nm := String(mi.name)
	if mi.mesh == null: return
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
		if m == null: continue
		if "_eye" in nm:
			var e := m.duplicate() as StandardMaterial3D
			e.roughness = 0.04; e.metallic_specular = 1.0
			e.clearcoat_enabled = true; e.clearcoat = 1.0; e.clearcoat_roughness = 0.02
			mi.set_surface_override_material(s, e)
		elif "_card" in nm or "_feather" in nm or "_hair" in nm:
			var c := m.duplicate() as StandardMaterial3D
			c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			c.backlight_enabled = true; c.backlight = Color(0.35, 0.3, 0.25)
			mi.set_surface_override_material(s, c)

# ------------------------------------------------------------------ fallback
## The code-built stand-in (NewModels5: still, no skeleton), turned to face +Z like the files.
static func _fallback(name: String) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var nm := "dog_a" if name in ["biscuit_a", "lost_dog_a", "wolf_a"] else name
	if nm in NewModels5.NAMES:
		var mi := MeshInstance3D.new()
		mi.name = name + "_fallback"
		mi.mesh = NewModels5.mesh(nm, 0)
		mi.rotation.y = PI
		root.add_child(mi)
	return root

# ------------------------------------------------------------------ dev hook
## main.gd `animals<distance>_<clip>_<name>+<name>...`: a row of animals on the ground ahead of the camera, side on to it.
static func dev_row(parent: Node, terrain: Object, cam: Camera3D, dist: float, clip: String, names: PackedStringArray, face := 90.0) -> void:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	f = f.normalized()
	var r := f.cross(Vector3.UP).normalized()
	var origin := cam.global_position + f * dist
	var widths: Array[float] = []
	var total := 0.0
	for nm in names:
		var w: float = float(AnimalInfo.INFO.get(nm, {}).get("length", 2.0)) * 0.75 + 0.6
		widths.append(w); total += w
	var x := -total * 0.5
	for i in names.size():
		var c := origin + r * (x + widths[i] * 0.5)
		c.y = terrain.height(c.x, c.z)
		var look := Basis.looking_at(f, Vector3.UP).rotated(Vector3.UP, deg_to_rad(face))
		var a := place(parent, names[i], Transform3D(look, c), {"clip": clip, "seed": i})
		print("animals: ", names[i], " at ", c, " playing ", clip, " file ", has_file(names[i]))
		x += widths[i]

# ------------------------------------------------------------------ heat mask parts
## Splits the near hide into named parts for the thermal heat mask (the wildlife brief): `body`, `head` (head, neck, ears),
## `legs` and, on sheep, `wool`. Each part is its own MeshInstance3D on the same skeleton and skin, named "<animal>_<part>",
## keeping the coat material, so it still animates; the whole LOD0 is hidden. Returns {part: MeshInstance3D}.
## Also reachable as instance(name, {"parts": true}).
static func heat_parts(root: Node) -> Dictionary:
	var out := {}
	var src: MeshInstance3D = null
	for mi: MeshInstance3D in meshes(root):
		if String(mi.name).ends_with("_LOD0"): src = mi
	var sk := find_skeleton(root)
	if src == null or src.mesh == null or src.skin == null or sk == null: return out
	var arr := src.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var nb := bones.size() / maxi(verts.size(), 1)
	var rn := String(root.name)
	var sheep := rn.begins_with("sheep") or rn.begins_with("lamb") or rn.begins_with("ram")
	var bind_names: Array[String] = []
	for b in src.skin.get_bind_count():
		var bn := String(src.skin.get_bind_name(b))
		if bn == "": bn = sk.get_bone_name(src.skin.get_bind_bone(b))
		bind_names.append(bn)
	var vpart := PackedStringArray()
	vpart.resize(verts.size())
	for v in verts.size():
		var best := 0; var bw := -1.0
		for k in nb:
			if wts[v * nb + k] > bw: bw = wts[v * nb + k]; best = bones[v * nb + k]
		var bn: String = bind_names[best] if best < bind_names.size() else ""
		var p := "body"
		for h in ["head", "jaw", "neck", "ear", "eyelid"]:
			if bn.begins_with(h): p = "head"
		for l in ["upperarm", "forearm", "cannon", "pastern", "foot", "thigh", "shin", "tarsus", "toe"]:
			if bn.begins_with(l): p = "legs"
		if sheep and p == "body" and cols.size() > v and cols[v].a > 0.5: p = "wool"
		vpart[v] = p
	var tris := {}
	for t in idx.size() / 3:
		var p := vpart[idx[t * 3]]
		if not tris.has(p): tris[p] = PackedInt32Array()
		(tris[p] as PackedInt32Array).append_array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
	var mat := src.get_surface_override_material(0)
	if mat == null: mat = src.mesh.surface_get_material(0)
	for p in tris:
		var a2 := arr.duplicate()
		a2[Mesh.ARRAY_INDEX] = tris[p]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, src.mesh.surface_get_format(0))
		am.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = rn + "_" + p
		mi.mesh = am; mi.skin = src.skin
		mi.transform = src.transform
		src.get_parent().add_child(mi)
		mi.skeleton = mi.get_path_to(sk)
		_range(mi, 0.0, LOD_FAR[1])
		out[p] = mi
	src.visible = false
	var mid := src.get_parent().get_node_or_null(String(src.name) + "_mid")
	if mid != null: (mid as Node3D).visible = false
	return out
