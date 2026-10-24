class_name DroneAssets
extends RefCounted
## Blender 4 (lane/drones): the Facade kit drones modelled in Blender (tools/blender/build_drones.py) as glTF files in
## assets/models/drones/: `raptor_race_a` (5-inch 6S race quad), `nightowl_a` (quiet 4-inch gimbal ship) and
## `night_vision_pod_a` (the clip-on low-light camera). Each has three levels of detail (<name>.glb, _lod1, _lod2) and a
## manifest <name>.json (centre of mass, prop pivots and radius, blur colours, triangle counts, the outlines for the drone
## chooser's drawing). The files carry their PBR textures embedded (so they stand on their own); the game discards those
## on import and puts the one shared set from assets/textures/drones back by material name (_dress).
##
## Frame in the files (the story frame): metres, +Y up, +Z is the nose, the model's right is -x, origin on the ground under
## the middle (the pod: the middle of its mounting face, the top). DroneView turns a drone into its own body frame
## (forward -z, right +x, origin at the centre of mass) with body_xf().
##
##   DroneAssets.place(parent, "nightowl_a", Transform3D(basis, pos))     # a still model in the world (story frame)
##   DroneAssets.place(parent, "night_vision_pod_a", xf, 1)                 # level of detail 1
## Named nodes: prop_fr prop_rr prop_rl prop_fl (pivot on the shaft; fr and rl turn clockwise seen from above, rr and fl
## anticlockwise), battery, camera_lens, status_led, led_fr led_rr led_rl led_fl (navigation lamps), and per model:
## Raptor camera_fpv (FPV camera, child camera_lens), action_cam (fixed, children action_cam_lens, action_cam_led);
## Night Owl gimbal_yaw > gimbal_roll > gimbal_pitch > camera_lens (each pivot on its axis: yaw about y, roll about z,
## pitch about x), nv_pod (children nv_lens, nv_led, nv_led_ir), landing_light; the pod: body, camera_lens, status_led.
## If a file is missing, the code-built placeholder stands in (DroneView's Race and Mini, the story thermal pod).

const DIR := "res://assets/models/drones/"
const TEX := "res://assets/textures/drones/"
const NAMES: Array[String] = ["raptor_race_a", "nightowl_a", "night_vision_pod_a"]
## Which airframe (physics/airframes.gd id) flies which model. The Facade kit ids; race and mini keep their own models.
const MODEL_FOR := {"raptor": "raptor_race_a", "nightowl": "nightowl_a"}
## What stands in when a file is missing: an airframe id for DroneView, or a story asset.
const FALLBACK := {"raptor_race_a": "race", "nightowl_a": "mini", "night_vision_pod_a": "thermal_pod_a"}
const PROPS: Array[String] = ["prop_fr", "prop_rr", "prop_rl", "prop_fl"]     # DroneView's motor order 0..3
const SPIN := {"prop_fr": -1, "prop_rr": 1, "prop_rl": -1, "prop_fl": 1}         # +1 anticlockwise seen from above
## Nodes hidden when looking through the drone's own camera (they would fill the picture).
const FPV_HIDE := {"raptor_race_a": ["camera_fpv"], "nightowl_a": ["gimbal_yaw"]}

static var _manifest := {}
static var _data := {}
static var _mats := {}

static func model_for(airframe_id: String) -> String:
	return MODEL_FOR.get(airframe_id, "")

static func path_of(name: String, lod := 0) -> String:
	return DIR + name + ("" if lod <= 0 else "_lod%d" % lod) + ".glb"

static func has_file(name: String, lod := 0) -> bool:
	return ResourceLoader.exists(path_of(name, lod))

## The manifest written by the Blender build (empty if missing).
static func manifest(name: String) -> Dictionary:
	if _manifest.has(name): return _manifest[name]
	var out := {}
	var p := DIR + name + ".json"
	if FileAccess.file_exists(p):
		var j = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary: out = j
	_manifest[name] = out
	return out

## A model as a Node3D in the file's frame (or the placeholder when the file is missing).
static func instance(name: String, lod := 0) -> Node3D:
	var p := path_of(name, lod)
	if lod > 0 and not ResourceLoader.exists(p): p = path_of(name, 0)
	var ps := load(p) as PackedScene if ResourceLoader.exists(p) else null
	if ps == null:
		return fallback(name)
	var root := ps.instantiate() as Node3D
	root.name = name
	_dress(root, name)
	return root

static func place(parent: Node, name: String, xf := Transform3D.IDENTITY, lod := 0) -> Node3D:
	var n := instance(name, lod)
	n.transform = xf
	parent.add_child(n)
	return n

## The placeholder: the code-built drone (turned into the file's frame) or the thermal pod from the story set.
static func fallback(name: String) -> Node3D:
	var fb: String = FALLBACK.get(name, "")
	var root := Node3D.new()
	root.name = name
	if fb == "thermal_pod_a":
		root.add_child(StoryAssets.instance("thermal_pod_a", 0))
		return root
	var af := Airframes.make(fb)
	var v := DroneView.new()
	v.build(af)
	var md := DroneView.model(af)
	var low := 0.0
	for s in md["side"]:
		for q in s["pts"]: low = minf(low, q.y)
	v.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, -low, 0))
	root.add_child(v)
	return root

## The files' own textures are discarded on import; the shared set in assets/textures/drones goes back on by material name
## (one material per name for every drone and level of detail). Lamps (lamp_*) glow; the landing light's lens is see-through.
static func _dress(n: Node, name: String) -> void:
	var specs: Dictionary = manifest(name).get("materials", {})
	_dress_node(n, specs)

static func _dress_node(n: Node, specs: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m == null: continue
				var key := m.resource_name
				if not _mats.has(key):
					_mats[key] = _material(m, key, specs.get(key, {}))
				mi.set_surface_override_material(s, _mats[key])
	for c in n.get_children(): _dress_node(c, specs)

static func _material(src: BaseMaterial3D, key: String, spec: Dictionary) -> BaseMaterial3D:
	var m := src.duplicate() as BaseMaterial3D
	if spec.has("albedo"):
		m.albedo_texture = load(TEX + String(spec["albedo"]))
	if spec.has("orm"):
		var t: Texture2D = load(TEX + String(spec["orm"]))
		m.roughness_texture = t
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = t
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	if spec.has("nor"):
		m.normal_enabled = true
		m.normal_texture = load(TEX + String(spec["nor"]))
	if key.begins_with("lamp_"):
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 8.0 if key == "lamp_landing" else (1.5 if key == "lamp_ir" else 4.0)
		if key != "lamp_ir": m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if spec.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(spec["alpha"])
	return m

## From the file's frame to DroneView's body frame: turn half round about y, then put the centre of mass at the origin.
static func body_xf(name: String) -> Transform3D:
	var m := manifest(name)
	var com := Vector3.ZERO
	if m.has("com_model"):
		var c: Array = m["com_model"]
		com = Vector3(float(c[0]), float(c[1]), float(c[2]))
	return Transform3D(Basis(Vector3.UP, PI), -com)

## What DroneView.model() needs for a glTF drone: the drawing outlines, prop discs and blur colours, in the body frame.
## Empty if this airframe has no file.
static func model_data(airframe_id: String) -> Dictionary:
	var name := model_for(airframe_id)
	if name == "" or not has_file(name): return {}
	if _data.has(name): return _data[name]
	var m := manifest(name)
	if m.is_empty() or not m.has("props"): return {}
	var plan: Array = []
	for s in m["plan"]:
		var pts := PackedVector2Array()
		for q in s["pts"]: pts.append(Vector2(float(q[0]), float(q[1])))
		var e := {"pts": pts, "key": float(s["key"])}
		if s.get("thin", false): e["thin"] = true
		plan.append(e)
	var side: Array = []
	for s in m["side"]:
		var pts2 := PackedVector2Array()
		for q in s["pts"]: pts2.append(Vector2(float(q[0]), float(q[1])))
		side.append({"pts": pts2, "key": float(s["key"])})
	var r := float(m["prop_radius"])
	var prop_pos: Array = []
	var discs: Array = []
	for nm in PROPS:
		var c: Array = m["props"][nm.substr(5)]
		var p := Vector3(float(c[0]), float(c[1]), float(c[2]))
		prop_pos.append(p)
		discs.append([p, r])
	var bb: Array = m["blur_body"]; var bt: Array = m["blur_tip"]
	var out := {
		"glb": name, "plan": plan, "side": side, "discs": discs, "prop_pos": prop_pos, "prop_radius": r,
		"chord": float(m["prop_chord"]), "blades": int(m["prop_blades"]),
		"blur_body": Color(float(bb[0]), float(bb[1]), float(bb[2])), "blur_tip": Color(float(bt[0]), float(bt[1]), float(bt[2])),
		"fpv_hide": FPV_HIDE.get(name, []),
	}
	_data[name] = out
	return out

## Triangle count of a loaded model (all meshes under it), for the tests.
static func triangles(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mesh := (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	for c in n.get_children(): t += triangles(c)
	return t
