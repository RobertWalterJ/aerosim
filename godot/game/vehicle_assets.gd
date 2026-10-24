class_name VehicleAssets
extends RefCounted
## Blender 3 (lane/vehicles): the vehicles modelled in Blender (tools/blender/build_vehicles.py) as rigged glTF files in
## assets/models/vehicles/<name>.glb. Each file holds one armature with three meshes on it (<name>_LOD0, _LOD1, _LOD2) and
## baked animations. This class loads one, swaps in the vehicle shaders by material slot name (paint per instance), sets the
## level-of-detail distances, and drives the rig: wheels roll and steer through their bones, doors, bonnet, tailgate,
## wipers and the steering wheel through the AnimationPlayer, lamps through their materials. If a file is missing the
## code-built batch 6 model (NewModels4) stands in, with the same calls working on its wheel pivots.
##
## Frame (batch 6): metres, forward -z, up +y, right +x, origin on the ground in the middle of the length.
## The story frame (+z forward) is available with `front_plus_z` (StoryAssets uses it).
##
##   var car := VehicleAssets.place(self, "car_hatch_b", Transform3D(basis, pos), Color(0.1, 0.2, 0.4))
##   VehicleAssets.roll(car, metres_travelled)       # wheels turn by -distance / radius about their axles
##   VehicleAssets.steer(car, deg_to_rad(20))         # + turns left
##   VehicleAssets.play(car, "doors_open")            # or pose(car, "doors_open") to jump to the end
##   VehicleAssets.set_lights(car, {"head": 1.0, "tail": 1.0, "brake": 0.0, "ind_l": 0.0})
## The bone and animation names of every vehicle are in game/vehicle_manifest.gd and README-models.md (Blender 3 (lane/vehicles)).

const DIR := "res://assets/models/vehicles/"
const LOD_END := [25.0, 80.0]              # LOD0 to 25 m, LOD1 to 80 m, LOD2 beyond
const LOD_MARGIN := 2.0

## What stands in when a .glb is missing (a batch 6 code model).
const FALLBACK := {
	"lake_car_estate_a": "car_estate_a", "lake_car_estate_b": "car_estate_a", "police_suv_a": "pickup_a",
	"police_saloon_a": "car_estate_a", "cruiser_1984_a": "car_estate_a", "festival_bus_restored": "bus_a",
	"festival_bus_garage": "bus_a", "festival_ice_cream_van_a": "van_a", "parade_tractor_a": "tractor_a",
	"parade_trailer_a": "tractor_trailer_a", "lorry_a": "milk_tanker_a", "bus_b": "bus_a", "farm_quad_a": "motorcycle_a",
}

## How each material slot is drawn: [shader, kind, extra parameters]. Colours come from the file's own material unless the
## slot is paint (the instance's paint) or listed with a "tint" here.
const SLOTS := {
	"paint": ["pbr", 0, {}],
	"paint2": ["pbr", 0, {}],
	"rust": ["pbr", 0, {"cond_scale": 0.15}],
	"glass": ["glass", -1, {"tint": Color(0.16, 0.19, 0.2), "opacity": 0.16}],
	"glass_tint": ["glass", -1, {"tint": Color(0.06, 0.07, 0.08), "opacity": 0.6}],
	"lamp_front": ["glass", -1, {"tint": Color(0.85, 0.87, 0.9), "opacity": 0.1, "grime": 0.05}],
	"chrome": ["pbr", 2, {"cond_scale": 1.0}],
	"mirror": ["pbr", 2, {"cond_scale": 1.0}],
	"rim": ["pbr", 2, {"cond_scale": 0.9}],
	"rim_steel": ["pbr", 6, {"cond_scale": 0.9}],
	"metal": ["pbr", 2, {"cond_scale": 0.55}],
	"rubber": ["pbr", 1, {"tint": Color(1, 1, 1)}],
	"trim": ["pbr", 4, {}],
	"trim_grey": ["pbr", 4, {}],
	"caliper": ["pbr", 6, {}],
	"interior": ["ds", 4, {}],
	"seat": ["ds", 4, {"detail": "seat"}],
	"dash": ["pbr", 4, {}],
	"plate": ["pbr", 6, {}],
	"plate_text": ["pbr", 6, {}],
	"lettering": ["pbr", 6, {}],
	"lettering2": ["pbr", 6, {}],
	"canvas": ["ds", 4, {}],
	"wood": ["pbr", 6, {}],
	"lamp_reflector": ["pbr", 5, {"tint": Color(0.78, 0.78, 0.8)}],
	"lamp_tail": ["pbr", 5, {}],
	"lamp_brake": ["pbr", 5, {}],
	"lamp_ind_l": ["pbr", 5, {}],
	"lamp_ind_r": ["pbr", 5, {}],
	"lamp_reverse": ["pbr", 5, {}],
	"lightbar_red": ["pbr", 5, {}],
	"lightbar_blue": ["pbr", 5, {}],
	"lamp_beacon": ["pbr", 5, {}],
	"primer": ["pbr", 0, {"cond_scale": 0.55}],
	"sheet_white": ["pbr", 6, {}],
	"straw": ["ds", 4, {}],
	"flag_a": ["ds", 4, {}],
	"flag_b": ["ds", 4, {}],
	"flag_c": ["ds", 4, {}],
	# lane/wreckvan: the lake silt bed (photo), lake weed (both sides), cracks in glass, the dive team's yellow kit
	"silt": ["pbr", 8, {}],
	"weed": ["ds", 4, {}],
	"weed_dry": ["ds", 4, {}],
	"crack": ["pbr", 4, {}],
	"kit_yellow": ["pbr", 6, {}],
}
## Lamp groups for set_lights (material slots each one lights) and how bright "1" is.
const LAMPS := {
	"head": [["lamp_front", 1.6], ["lamp_reflector", 4.0]],
	"tail": [["lamp_tail", 2.5]],
	"brake": [["lamp_brake", 6.0], ["lamp_tail", 2.0]],
	"ind_l": [["lamp_ind_l", 6.0]],
	"ind_r": [["lamp_ind_r", 6.0]],
	"reverse": [["lamp_reverse", 4.0]],
	"beacon_red": [["lightbar_red", 7.0]],
	"beacon_blue": [["lightbar_blue", 7.0]],
	"beacon_amber": [["lamp_beacon", 7.0]],
}

## Posed variants under their own names (the story briefs ask for them): [vehicle, animation(s) jumped to the end, joined by +].
const ALIASES := {
	"cruiser_1984_a_driver_open": ["cruiser_1984_a", "door_driver_open"],
	"cruiser_1984_a_open": ["cruiser_1984_a", "doors_open"],
	"festival_bus_restored_open": ["festival_bus_restored", "bus_door_open"],
	"lake_car_estate_a_closed": ["lake_car_estate_a", "tailgate_close"],
	"festival_ice_cream_van_a_open": ["festival_ice_cream_van_a", "serving_hatch_open"],
	# lane/wreckvan: the dive van with its barn doors, its sliding door, or both open
	"police_dive_van_a_rear_open": ["police_dive_van_a", "rear_doors_open"],
	"police_dive_van_a_side_open": ["police_dive_van_a", "slide_door_open"],
	"police_dive_van_a_open": ["police_dive_van_a", "rear_doors_open+slide_door_open"],
}

static var _mats := {}
static var _shaders := {}
static var _tex := {}

static func names() -> Array:
	return VehicleManifest.DATA.keys()

## True when the vehicle has a Blender .glb (otherwise instance() builds the code stand-in).
static func has(name: String) -> bool:
	if ALIASES.has(name): name = String(ALIASES[name][0])
	return VehicleManifest.DATA.has(name) and ResourceLoader.exists(DIR + String(VehicleManifest.DATA[name]["file"]))

## True for any name this class can place (a .glb or a stand-in).
static func handles(name: String) -> bool:
	return VehicleManifest.DATA.has(name) or FALLBACK.has(name) or name in NewModels4.CARS or name in NewModels4.BIG

static func info(name: String) -> Dictionary:
	return VehicleManifest.DATA.get(name, {})

static func place(parent: Node, name: String, xf: Transform3D, paint := Color(0, 0, 0, 0), front_plus_z := false) -> Node3D:
	var n := instance(name, paint, front_plus_z)
	n.transform = xf
	parent.add_child(n)
	return n

## A ready vehicle: a Node3D named after it holding "rig" (the imported scene: Skeleton3D with the three LOD meshes, and
## the AnimationPlayer). paint: the body colour in sRGB (transparent black = the vehicle's own colour).
static func instance(name: String, paint := Color(0, 0, 0, 0), front_plus_z := false) -> Node3D:
	if ALIASES.has(name):
		var a: Array = ALIASES[name]
		var vv := instance(String(a[0]), paint, front_plus_z)
		vv.name = name
		var ap := vv.get_meta("anim", null) as AnimationPlayer
		if ap != null: ap.stop()
		var steps := String(a[1]).split("+")
		if ap != null and steps.size() > 1:
			# several poses at once (lane/wreckvan: barn doors and sliding door): one animation holding the end of each
			var key := "+".join(steps)
			var lib := ap.get_animation_library("")
			if lib != null and not lib.has_animation(key):
				var comb := Animation.new()
				comb.length = 0.05
				for st in steps:
					if not ap.has_animation(st): continue
					var src := ap.get_animation(st)
					for t in src.get_track_count():
						var kc := src.track_get_key_count(t)
						if kc == 0: continue
						var nt := comb.add_track(src.track_get_type(t))
						comb.track_set_path(nt, src.track_get_path(t))
						comb.track_insert_key(nt, 0.0, src.track_get_key_value(t, kc - 1))
				lib.add_animation(key, comb)
			steps = PackedStringArray([key])
		for p in steps:
			pose(vv, p)
		_repose_when_ready(vv, steps)
		return vv
	var root := Node3D.new()
	root.name = name
	root.set_meta("vehicle", name)
	if not has(name):
		return _fallback(root, name, paint, front_plus_z)
	var ps := load(DIR + String(VehicleManifest.DATA[name]["file"])) as PackedScene
	var rig := ps.instantiate() as Node3D
	rig.name = "rig"
	if front_plus_z:
		rig.rotation.y = PI
	root.add_child(rig)
	_setup(root, rig, name, paint)
	var pose_name: String = String(VehicleManifest.DATA[name].get("pose", ""))
	if pose_name != "":
		for p in pose_name.split("+"):
			pose(root, p)
		_repose_when_ready(root, pose_name.split("+"))
	return root

## A pose set before the vehicle is in the tree does not reach the drawn skin (the bones read posed, the mesh shows rest):
## apply it again once the vehicle is ready in the tree (lane/wreckvan; also fixes the existing posed variants).
static func _repose_when_ready(v: Node3D, steps: PackedStringArray) -> void:
	v.ready.connect(_pose_all.bind(v, steps), CONNECT_ONE_SHOT)

static func _pose_all(v: Node3D, steps: PackedStringArray) -> void:
	for p in steps:
		pose(v, p)

# ------------------------------------------------------------------ setup
static func _setup(root: Node3D, rig: Node3D, name: String, paint: Color) -> void:
	var d: Dictionary = VehicleManifest.DATA[name]
	var p1 := _srgb(d.get("paint", [0.5, 0.5, 0.5]))
	if paint.a > 0.0: p1 = paint
	var p2v = d.get("paint2", null)
	var p2 := _srgb(p2v) if p2v != null else Color(0.85, 0.85, 0.82)
	var lamps := {}
	var dirt := float(d.get("dirt", 0.35))
	var wreck: Dictionary = d.get("wreck", {})     # lane/wreckvan: silt line and paint photo of a lake wreck
	var skel: Skeleton3D = null
	for n in rig.find_children("*", "", true, false):
		if n is Skeleton3D and skel == null: skel = n
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var lod := 0
			if mi.name.ends_with("_LOD1"): lod = 1
			elif mi.name.ends_with("_LOD2"): lod = 2
			mi.visibility_range_begin = 0.0 if lod == 0 else LOD_END[lod - 1]
			mi.visibility_range_end = LOD_END[lod] if lod < 2 else 0.0
			mi.visibility_range_begin_margin = LOD_MARGIN if lod > 0 else 0.0
			mi.visibility_range_end_margin = LOD_MARGIN if lod < 2 else 0.0
			mi.set_meta("lod", lod)
			if mi.mesh == null: continue
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				var key := m.resource_name if m != null else "paint"
				var base := Color(0.5, 0.5, 0.5)
				if m is BaseMaterial3D: base = (m as BaseMaterial3D).albedo_color
				var mat: Material
				if key == "paint": mat = _mat(key, p1, dirt, wreck)
				elif key == "paint2": mat = _mat(key, p2, dirt, wreck)
				else: mat = _mat(key, base, dirt, wreck)
				if key.begins_with("lamp_") or key.begins_with("lightbar_"):
					mat = mat.duplicate()
					if not lamps.has(key): lamps[key] = []
					(lamps[key] as Array).append(mat)
				mi.set_surface_override_material(s, mat)
	root.set_meta("lamps", lamps)
	root.set_meta("skeleton", skel)
	var ap := rig.find_children("*", "AnimationPlayer", true, false)
	root.set_meta("anim", ap[0] if ap.size() > 0 else null)
	# the wheels: bone index, rest rotation, the axle in the bone's own frame, radius
	var wheels: Array = []
	var steers: Array = []
	if skel != null:
		for w: Dictionary in d.get("wheels", []):
			var bi := skel.find_bone(String(w["bone"]))
			if bi < 0: continue
			var gr := skel.get_bone_global_rest(bi)
			wheels.append({"i": bi, "rest": skel.get_bone_rest(bi).basis.get_rotation_quaternion(),
				"axis": (gr.basis.inverse() * Vector3.RIGHT).normalized(), "r": float(w["radius"])})
		for bn in d.get("bones", []):
			if String(bn).begins_with("steer_"):
				var bi := skel.find_bone(String(bn))
				var gr := skel.get_bone_global_rest(bi)
				steers.append({"i": bi, "rest": skel.get_bone_rest(bi).basis.get_rotation_quaternion(),
					"axis": (gr.basis.inverse() * Vector3.UP).normalized()})
		var bb := skel.find_bone("body")
		root.set_meta("body_bone", bb)
	root.set_meta("wheels", wheels)
	root.set_meta("steers", steers)
	root.set_meta("roll", 0.0)

static func _srgb(v) -> Color:
	if v is Color: return v
	if v is Vector3: return Color(v.x, v.y, v.z)
	return Color(float(v[0]), float(v[1]), float(v[2]))

static func _shader(kind: String) -> Shader:
	if not _shaders.has(kind):
		var p: String = {"pbr": "res://game/shaders/vehicle_pbr.gdshader", "ds": "res://game/shaders/vehicle_pbr_ds.gdshader",
			"glass": "res://game/shaders/vehicle_glass.gdshader"}[kind]
		_shaders[kind] = load(p)
	return _shaders[kind]

static func _texture(key: String) -> Texture2D:
	if not _tex.has(key):
		var p := "res://assets/textures/%s.jpg" % key
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]

## The shared material for a slot and colour (kept, so a handful of paints share them).
static func _mat(key: String, col: Color, dirt := 0.35, wreck := {}) -> Material:
	var k := "%s/%s/%.2f" % [key, col.to_html(), dirt]
	if not wreck.is_empty(): k += "/w%d" % wreck.hash()
	if _mats.has(k): return _mats[k]
	var spec: Array = SLOTS.get(key, ["pbr", 4, {}])
	var ex: Dictionary = spec[2]
	var m := ShaderMaterial.new()
	m.shader = _shader(String(spec[0]))
	if spec[0] == "glass":
		m.set_shader_parameter("tint", ex.get("tint", col))
		m.set_shader_parameter("opacity", float(ex.get("opacity", 0.16)))
		m.set_shader_parameter("grime", float(ex.get("grime", 0.35)))
	else:
		m.set_shader_parameter("kind", int(spec[1]))
		m.set_shader_parameter("tint", ex.get("tint", col))
		m.set_shader_parameter("cond_scale", float(ex.get("cond_scale", 1.0)))
		m.set_shader_parameter("dirt", dirt if key != "interior" and key != "seat" and key != "dash" else 0.0)
		if key == "paint" or key == "paint2" or key == "rust":
			var rt := _texture("rust_diff")
			if rt != null:
				m.set_shader_parameter("rust_tex", rt)
				m.set_shader_parameter("rust_scale", 1.6)
			var dt := _texture("mudtrack_diff")
			if dt != null:
				m.set_shader_parameter("dirt_tex", dt)
				m.set_shader_parameter("dirt_scale", 0.9)
		if ex.get("detail", "") == "seat":
			var st := _texture("fabric_nor")
			if st != null:
				m.set_shader_parameter("detail_nor", st)
				m.set_shader_parameter("detail_scale", 9.0)
				m.set_shader_parameter("detail_depth", 0.6)
		if key == "rubber":
			var rb := _texture("rubber_nor")
			if rb != null:
				m.set_shader_parameter("detail_nor", rb)
				m.set_shader_parameter("detail_scale", 6.0)
				m.set_shader_parameter("detail_depth", 0.35)
	_wreck_params(m, key, spec, wreck)
	m.resource_name = key
	_mats[k] = m
	return m

## lane/wreckvan: the silt bed always takes the photographed lake mud; a vehicle whose manifest has a "wreck" entry
## (silt_line, paint_tex, paint_scale, paint_nor, silt_tex, silt_scale) gets its silt line on every slot and the
## photographed paint on its paint.
static func _wreck_params(m: ShaderMaterial, key: String, spec: Array, wreck: Dictionary) -> void:
	var silt_name := String(wreck.get("silt_tex", "wreck_silt_diff"))
	var silt_s := float(wreck.get("silt_scale", 0.77))
	if key == "silt":
		var st := _texture(silt_name)
		if st != null:
			m.set_shader_parameter("silt_tex", st)
			m.set_shader_parameter("silt_scale", silt_s)
		var sn := _texture(silt_name.replace("_diff", "_nor"))
		if sn != null:
			m.set_shader_parameter("detail_nor", sn)
			m.set_shader_parameter("detail_scale", silt_s)
			m.set_shader_parameter("detail_depth", 0.8)
		m.set_shader_parameter("dirt", 0.0)
	if wreck.is_empty(): return
	var line := float(wreck.get("silt_line", -100.0))
	m.set_shader_parameter("silt_line", line)
	if spec[0] == "glass": return
	var st2 := _texture(silt_name)
	if st2 != null:
		m.set_shader_parameter("silt_tex", st2)
		m.set_shader_parameter("silt_scale", silt_s)
	if (key == "paint" or key == "paint2") and wreck.has("paint_tex"):
		var pt := _texture(String(wreck["paint_tex"]))
		if pt != null:
			m.set_shader_parameter("paint_tex", pt)
			m.set_shader_parameter("paint_scale", float(wreck.get("paint_scale", 1.0)))
			m.set_shader_parameter("paint_amount", float(wreck.get("paint_amount", 1.0)))
		var pn := _texture(String(wreck.get("paint_nor", "")))
		if pn != null:
			m.set_shader_parameter("detail_nor", pn)
			m.set_shader_parameter("detail_scale", float(wreck.get("paint_scale", 1.0)))
			m.set_shader_parameter("detail_depth", 0.6)

# ------------------------------------------------------------------ driving the rig
## Roll the wheels on by `distance` metres (forward positive): each wheel turns -distance / radius about its axle.
static func roll(v: Node3D, distance: float) -> void:
	var total: float = float(v.get_meta("roll", 0.0)) + distance
	v.set_meta("roll", total)
	if v.has_meta("fallback"):
		for c in v.find_children("wheel_*", "Node3D", true, false):
			var w := c.get_node_or_null("Wheel") as Node3D
			if w: w.rotation.x = -total / float(c.get_meta("r", 0.32))
		return
	var skel := v.get_meta("skeleton") as Skeleton3D
	if skel == null: return
	for w: Dictionary in v.get_meta("wheels"):
		var q := (w["rest"] as Quaternion) * Quaternion(w["axis"], -total / float(w["r"]))
		skel.set_bone_pose_rotation(int(w["i"]), q)

## Turn the steering wheels by `angle` radians (+ = left) about their own vertical axes.
static func steer(v: Node3D, angle: float) -> void:
	if v.has_meta("fallback"):
		for c in v.find_children("wheel_f*", "Node3D", true, false):
			c.rotation.y = angle
		return
	var skel := v.get_meta("skeleton") as Skeleton3D
	if skel == null: return
	for s: Dictionary in v.get_meta("steers"):
		skel.set_bone_pose_rotation(int(s["i"]), (s["rest"] as Quaternion) * Quaternion(s["axis"], angle))

## Bounce the body on its springs: lift (m), pitch (radians, nose up +) and roll (radians).
static func bounce(v: Node3D, lift: float, pitch := 0.0, side_roll := 0.0) -> void:
	var skel := v.get_meta("skeleton", null) as Skeleton3D
	if skel == null: return
	var bi := int(v.get_meta("body_bone", -1))
	if bi < 0: return
	var rest := skel.get_bone_rest(bi)
	var gr := skel.get_bone_global_rest(bi)
	var up := (gr.basis.inverse() * Vector3.UP).normalized()
	var right := (gr.basis.inverse() * Vector3.RIGHT).normalized()
	var fwd := (gr.basis.inverse() * Vector3.FORWARD).normalized()
	skel.set_bone_pose_position(bi, rest.origin + rest.basis * (up * lift))
	skel.set_bone_pose_rotation(bi, rest.basis.get_rotation_quaternion() * Quaternion(right, pitch) * Quaternion(fwd, side_roll))

## Play a baked animation ("doors_open", "doors_close", "door_driver_open", "bonnet_open", "tailgate_open", "wipers",
## "steer_left", "steer_right", and per vehicle extras: see the manifest's "actions").
static func play(v: Node3D, anim: String, speed := 1.0) -> bool:
	var ap := v.get_meta("anim", null) as AnimationPlayer
	if ap == null or not ap.has_animation(anim): return false
	ap.play(anim, -1, speed)
	return true

## Jump straight to the end of an animation (a parked pose: doors open, tailgate up...).
static func pose(v: Node3D, anim: String, at := 1.0) -> bool:
	var ap := v.get_meta("anim", null) as AnimationPlayer
	if ap == null or not ap.has_animation(anim): return false
	var a := ap.get_animation(anim)
	ap.play(anim)
	ap.seek(a.length * at, true)
	ap.pause()
	return true

## Light the lamps: keys head, tail, brake, ind_l, ind_r, reverse, beacon_red, beacon_blue; values 0 (off) to 1.
static func set_lights(v: Node3D, on: Dictionary) -> void:
	var lamps: Dictionary = v.get_meta("lamps", {})
	var glow := {}
	for g in on:
		if not LAMPS.has(g): continue
		for pair in LAMPS[g]:
			glow[pair[0]] = maxf(float(glow.get(pair[0], 0.0)), float(on[g]) * float(pair[1]))
	for key in lamps:
		var gv: float = float(glow.get(key, 0.0))
		for m: ShaderMaterial in lamps[key]:
			m.set_shader_parameter("glow", gv)

## Box colliders (AABB in the vehicle's frame) as a StaticBody3D child, for parked vehicles a drone can hit.
static func add_colliders(v: Node3D) -> StaticBody3D:
	var name := String(v.get_meta("vehicle", ""))
	var sb := StaticBody3D.new()
	sb.name = "collision"
	var flip := false
	var rig := v.get_node_or_null("rig") as Node3D
	if rig != null and absf(rig.rotation.y) > 1.0: flip = true
	for box in colliders(name):
		var lo: Vector3 = box[0]; var hi: Vector3 = box[1]
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = hi - lo
		cs.shape = sh
		var c := (lo + hi) * 0.5
		if flip: c = Vector3(-c.x, c.y, -c.z)
		cs.position = c
		sb.add_child(cs)
	v.add_child(sb)
	return sb

static func colliders(name: String) -> Array:
	var out: Array = []
	var d: Dictionary = VehicleManifest.DATA.get(name, {})
	for b in d.get("colliders", []):
		out.append([_v3(b[0]), _v3(b[1])])
	if out.is_empty() and FALLBACK.has(name):
		for a: AABB in NewModels4.colliders(FALLBACK[name]):
			out.append([a.position, a.end])
	return out

static func _v3(v) -> Vector3:
	if v is Vector3: return v
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

# ------------------------------------------------------------------ the code stand-in
static func _fallback(root: Node3D, name: String, paint: Color, front_plus_z: bool) -> Node3D:
	var src := String(FALLBACK.get(name, name))
	var node := NewModels4.build_node(src, 0, paint)
	node.name = "rig"
	if front_plus_z: node.rotation.y = PI
	for c in node.get_children():
		if String(c.name).begins_with("wheel_"):
			var R := 0.32
			for w: Dictionary in NewModels4.vehicle(src, 0, paint).get("wheels", []):
				if w["name"] == c.name: R = float(w["radius"])
			c.set_meta("r", R)
	root.add_child(node)
	root.set_meta("fallback", src)
	root.set_meta("lamps", {})
	root.set_meta("wheels", [])
	root.set_meta("steers", [])
	return root
