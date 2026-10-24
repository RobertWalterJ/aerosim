class_name WildlifeAssets
extends RefCounted
## The props of the wildlife brief (godot/docs/CLAUDE-WILDLIFE-ASSETS.md): the night pen and gates, trough, hay rack, salt lick,
## bell, wool on the wire, tracks, the advisory sign and the farm odds and ends. Made in Blender by tools/blender/build_props.py
## (photographed CC0 wood, straw, wool and galvanised steel from assets/textures, plain PBR metals), exported to
## assets/models/wildlife/<name>.glb. The animals of the brief (wolf_standing_a, sheep_grazing_a...) are in AnimalAssets.ALIASES:
## instance() here passes those names on, so one call serves the whole brief.
## Frame: metres, Y up, +Z is the front, origin at the base. Named nodes: night_pen_a has <name>_panel_back/_left/_right/
## _front_l/_front_r and <name>_gate (pivot on the hinge post, turn it about Y to open); pen_gate_a and pasture_gate_a
## have <name>_gate; collision comes from the "-colonly" boxes (pen panels, gates, trough, hay rack).

const NAMES: Array[String] = ["sheep_trough_a", "sheep_hay_rack_a", "sheep_salt_lick_a", "sheep_bell_a", "wool_on_wire_a", "wool_on_wire_b",
	"wolf_track_a", "wolf_track_b", "sheep_print_a", "sheep_print_b", "night_pen_a", "night_pen_a_open", "pen_gate_a",
	"farm_warning_sign_a", "hay_bale_small_a", "straw_patch_a", "sheep_feed_bucket_a", "wolf_ear_tuft_a", "pasture_gate_a",
	"farm_lantern_a", "wolf_collar_tracker_a", "sheep_shearing_kit_a"]
## Brief names served by other sets: the brief's farm_truck_a is the vehicles lane's older pickup.
const ELSEWHERE := {"farm_truck_a": "pickup_b", "field_gate_a": "pasture_gate_a"}
static var _scenes := {}

static func path_of(name: String) -> String:
	return "res://assets/models/wildlife/%s.glb" % name

static func instance(name: String, opts := {}) -> Node3D:
	if AnimalAssets.ALIASES.has(name) or name in AnimalAssets.NAMES:
		return AnimalAssets.instance(name, opts)
	if name == "farm_truck_a":
		var t := NewModels4.build_node("pickup_b", 0, Color(0, 0, 0, 0))
		t.name = name
		return t
	if name == "field_gate_a" and not ResourceLoader.exists(path_of(name)): name = "pasture_gate_a"
	var p := path_of(name)
	if not ResourceLoader.exists(p):
		push_warning("WildlifeAssets: no file " + p)
		var n := Node3D.new(); n.name = name
		return n
	var ps: PackedScene = _scenes.get(name)
	if ps == null:
		ps = load(p) as PackedScene
		_scenes[name] = ps
	var root := ps.instantiate() as Node3D
	root.name = name
	for mi: MeshInstance3D in AnimalAssets.meshes(root):
		var nm := String(mi.name)
		if nm.ends_with("_LOD0"):
			mi.visibility_range_end = 30.0; mi.visibility_range_end_margin = 1.0
		elif nm.ends_with("_LOD1"):
			mi.visibility_range_begin = 30.0; mi.visibility_range_begin_margin = 1.0
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if m == null: continue
			if m.resource_name.begins_with("wolf_track") or m.resource_name.begins_with("sheep_print"):
				var d := m.duplicate() as StandardMaterial3D
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; d.alpha_scissor_threshold = 0.3
				mi.set_surface_override_material(s, d)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif m.resource_name == "glass":
				var g := m.duplicate() as StandardMaterial3D
				g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; g.albedo_color.a = 0.35
				mi.set_surface_override_material(s, g)
			elif m.resource_name == "flame":
				var f := m.duplicate() as StandardMaterial3D
				f.emission_enabled = true; f.emission = Color(1.0, 0.62, 0.25); f.emission_energy_multiplier = 4.0
				mi.set_surface_override_material(s, f)
	if bool(opts.get("open", false)):
		var g := root.find_child("*_gate", true, false) as Node3D
		if g != null: g.rotation.y = deg_to_rad(100.0)
	return root

static func place(parent: Node, name: String, xf: Transform3D, opts := {}) -> Node3D:
	var n := instance(name, opts)
	n.transform = xf
	parent.add_child(n)
	return n
