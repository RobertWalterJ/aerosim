class_name AntiDroneAssets
extends RefCounted
## lane/antidrone: Harlan Pike's ridge and his hunter drones (brief godot/docs/CLAUDE-ANTI-DRONE-ASSETS.md on lane/notify).
## Modelled in Blender by tools/blender/build_antidrone.py (antidrone_lib.py on the sites kit, antidrone_pike.py,
## antidrone_hunters.py), exported to assets/models/antidrone/<name>.glb; AntiDroneManifest (generated) lists each file's
## nested named nodes (parent, pivot, rot), sizes, triangle counts, LOD distance, metadata and the Blender-side checks.
##
## Frame: metres, Y up, +Z is the asset's front (the trailer's hitch, the shack's door, the boards' faces, the hunters'
## noses; a hunter's right is -x), origin at the base (the hunters: the ground under the skids; meta.centre is the middle).
## Moving parts are their own nodes with a clean pivot: the trailer's `mast` (hinge pin at the deck; rotate about local x
## by meta.lower_deg to lay it forward), `mast_stage_2` / `mast_stage_3` (slide down local y to telescope), `dish` (turn
## about y), `beacon`, `guy_wires`, `trailer_wheel_l/_r`, the shack's `door` (about y), `rotor_1..4` (`..6` on the hex)
## spun about local y in the direction meta.spin gives, `eye`, `strobe`, `net_pod` > `pod_door` (about x), the axe.
## Lamps are emissive materials, not lights: ad_lamp_red (beacon, antenna), ad_lamp_eye (hunter eyes), ad_lamp_strobe,
## ad_lamp_amber (generator warning lamp), ad_lamp_white (floodlight), ad_lamp_green (radio LED).
##
## Calls:
##   AntiDroneAssets.place(parent, "pike_jammer_trailer", Transform3D, opts := {}) -> Node3D
##   AntiDroneAssets.instance(name, opts := {}) -> Node3D        opts: "lod_scale" float, "lamps" bool (default true)
##   AntiDroneAssets.set_beacon(node, on)                         the red beacon (and the antenna lamp) on or off
##   AntiDroneAssets.set_lamp(node, key, energy)                  any ad_lamp_* material on this instance (0 = off)
##   AntiDroneAssets.lower_mast(node, t)                          t 0 standing .. 1 laid down; hides guy wires and the
##                                                                beacon once it starts to fall (the jammer is down)
##   AntiDroneAssets.spin_rotors(node, delta, rev_per_s := 60.0)  turn every rotor_N by its meta.spin direction
##   AntiDroneAssets.flash(node, time)                            a strobe pattern on ad_lamp_strobe / the strobe card
##   AntiDroneAssets.drape(node, height_fn)                       ground pieces onto the terrain (SiteAssets.drape)
##   AntiDroneAssets.text_rect(name) -> Dictionary                 the blank face for Label3D (manifesto, warning sign)
##   AntiDroneAssets.has(name), names(), info(name), meta(name)
## If a file is missing, instance() returns a stand-in: a plain box of the manifest size, or for a hunter a small code-built
## quad with the same node names (body, eye, rotor_1..N), so placement and animation code never breaks.

const DIR := "res://assets/models/antidrone/"
const TEX := "res://assets/textures/"
const DTEX := "res://assets/textures/drones/"

## photographed or drawn sets: key -> [albedo file, normal file or "", ORM/ARM file or "", metres per repeat (0 = UVs are
## already 0..1), albedo tint, normal scale]
const SETS := {
	"ad_trailer_paint": ["bld_paint_diff.jpg", "bld_paint_nor.jpg", "bld_paint_arm.jpg", 1.6, Color(0.36, 0.42, 0.31), 0.6],
	"ad_paint_white": ["bld_paint_diff.jpg", "bld_paint_nor.jpg", "bld_paint_arm.jpg", 1.4, Color(0.93, 0.91, 0.85), 0.5],
	"ad_paint_red": ["bld_paint_diff.jpg", "bld_paint_nor.jpg", "bld_paint_arm.jpg", 1.2, Color(0.66, 0.15, 0.1), 0.5],
	"ad_jerrycan": ["bld_paint_diff.jpg", "bld_paint_nor.jpg", "bld_paint_arm.jpg", 0.8, Color(0.33, 0.38, 0.23), 0.4],
	"ad_toolbox_red": ["bld_paint_diff.jpg", "bld_paint_nor.jpg", "bld_paint_arm.jpg", 0.8, Color(0.62, 0.1, 0.07), 0.4],
	"ad_rust": ["rust_diff.jpg", "", "", 0.6, Color(1, 1, 1), 1.0],
	"ad_planks": ["bld_timber_diff.jpg", "bld_timber_nor.jpg", "bld_timber_arm.jpg", 1.57, Color(0.9, 0.88, 0.84), 1.0],
	"ad_ply": ["postwood_diff.jpg", "postwood_nor.jpg", "postwood_arm.jpg", 1.2, Color(1.08, 1.0, 0.9), 0.6],
	"ad_corrugated": ["bld_corrugated_rust_diff.jpg", "bld_corrugated_rust_nor.jpg", "bld_corrugated_rust_arm.jpg", 1.8, Color(1, 1, 1), 1.0],
	"ad_ground": ["pike_ridge_clearing.jpg", "pike_ridge_clearing_nor.jpg", "pike_ridge_clearing_arm.jpg", 0.0, Color(1, 1, 1), 1.0],
	"ad_carbon": ["drones/drone_carbon_diff.jpg", "drones/drone_carbon_nor.jpg", "drones/drone_carbon_orm.jpg", 0.12, Color(0.8, 0.8, 0.8), 0.8],
	"ad_plastic_dark": ["", "drones/drone_plastic_nor.jpg", "drones/drone_plastic_orm.jpg", 0.2, Color(0.075, 0.08, 0.085), 0.5],
	"ad_plastic_grey": ["", "drones/drone_plastic_nor.jpg", "drones/drone_plastic_orm.jpg", 0.3, Color(0.33, 0.34, 0.34), 0.5],
	"ad_motor": ["", "drones/drone_spun_nor.jpg", "drones/drone_spun_orm.jpg", 0.05, Color(0.16, 0.16, 0.17), 0.6],
	"ad_strap": ["drones/drone_strap_diff.jpg", "drones/drone_strap_nor.jpg", "drones/drone_strap_orm.jpg", 0.1, Color(1, 1, 1), 0.8],
	"ad_tarp": ["", "fabric_nor.jpg", "", 0.11, Color(0.29, 0.32, 0.21), 0.6],
	"ad_canvas": ["", "fabric_nor.jpg", "", 0.11, Color(0.19, 0.26, 0.17), 0.6],
}

## plain PBR: key -> [albedo sRGB, roughness, metallic]
const PLAIN := {
	"ad_galv": [Color(0.64, 0.65, 0.64), 0.46, 0.85],
	"ad_steel_dark": [Color(0.14, 0.14, 0.14), 0.55, 0.65],
	"ad_cable": [Color(0.05, 0.05, 0.05), 0.55, 0.0],
	"ad_cable_orange": [Color(0.82, 0.34, 0.07), 0.5, 0.0],
	"ad_prop": [Color(0.045, 0.045, 0.05), 0.4, 0.0],
	"ad_battery": [Color(0.11, 0.12, 0.11), 0.5, 0.0],
	"ad_bone": [Color(0.84, 0.80, 0.70), 0.75, 0.0],
	"ad_ribbon": [Color(0.6, 0.08, 0.07), 0.8, 0.0],
	"ad_engine": [Color(0.3, 0.31, 0.3), 0.55, 0.5],
	"ad_thermos": [Color(0.2, 0.32, 0.24), 0.38, 0.3],
	"ad_chrome": [Color(0.78, 0.78, 0.8), 0.18, 1.0],
	"ad_tape": [Color(0.82, 0.76, 0.56), 0.45, 0.0],
	"ad_lens": [Color(0.03, 0.03, 0.035), 0.05, 0.0],
	"ad_water": [Color(0.06, 0.07, 0.06), 0.05, 0.0],
	"ad_tarp_blue": [Color(0.17, 0.28, 0.43), 0.75, 0.0],
}

## emissive lamps: key -> [colour, default energy]. The threat reads (beacon, eyes, strobe) start lit.
const LAMPS := {
	"ad_lamp_red": [Color(0.95, 0.06, 0.03), 4.0],
	"ad_lamp_eye": [Color(1.0, 0.05, 0.03), 5.0],
	"ad_lamp_strobe": [Color(1.0, 0.12, 0.06), 4.0],
	"ad_lamp_amber": [Color(1.0, 0.55, 0.08), 1.5],
	"ad_lamp_white": [Color(1.0, 0.95, 0.82), 0.0],
	"ad_lamp_green": [Color(0.15, 1.0, 0.25), 1.2],
}

## drawn cards and decals: key -> [file, mode]  (mode: "decal" alpha no depth write, "card" alpha scissor double sided,
## "smoke" unshaded alpha, "add" additive unshaded billboard)
const CARDS := {
	"ad_paper": ["pike_paper_blank.png", "card"],
	"ad_paper_lined": ["pike_manifesto_paper.png", "card"],
	"ad_notices": ["pike_notice_stack.png", "card"],
	"ad_decal_stencil": ["pike_no_drone_stencil.png", "decal"],
	"ad_decal_tyre": ["pike_tyre_marks.png", "decal"],
	"ad_smoke": ["pike_smoke_card.png", "smoke"],
	"ad_strobe": ["pike_strobe_card.png", "add"],
}

const HUNTERS := ["hunter_drone_a", "hunter_drone_b", "hunter_drone_c"]

static var _scenes := {}
static var _mats := {}

static func has(name: String) -> bool:
	return AntiDroneManifest.DATA.has(name)

static func names() -> Array:
	return AntiDroneManifest.DATA.keys()

static func info(name: String) -> Dictionary:
	return AntiDroneManifest.DATA.get(name, {})

static func meta(name: String) -> Dictionary:
	return info(name).get("meta", {})

static func path_of(name: String) -> String:
	return DIR + name + ".glb"

static func text_rect(name: String) -> Dictionary:
	return meta(name).get("text_rect", {})

static func _tex(file: String) -> Texture2D:
	var p := TEX + file
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## the materials: site_* from SiteAssets (shared photographed sets), ad_* built here; all multiply the vertex colour
## (occlusion and weathering, linear) except the cards, decals and lamps' lenses keep it too (it is 1 there)
static func mat(key: String) -> Material:
	if key.begins_with("site_"):
		return SiteAssets.mat(key)
	if _mats.has(key): return _mats[key]
	var m: BaseMaterial3D
	if SETS.has(key):
		var s: Array = SETS[key]
		var o: BaseMaterial3D = ORMMaterial3D.new() if String(s[2]) != "" else StandardMaterial3D.new()
		if String(s[0]) != "": o.albedo_texture = _tex(s[0])
		o.albedo_color = s[4]
		if String(s[1]) != "":
			o.normal_enabled = true
			o.normal_texture = _tex(s[1])
			o.normal_scale = float(s[5])
		if o is ORMMaterial3D:
			(o as ORMMaterial3D).orm_texture = _tex(s[2])
		else:
			o.roughness = 0.82 if key in ["ad_tarp", "ad_canvas"] else 0.8
		if float(s[3]) > 0.0:
			var rep := 1.0 / float(s[3])
			o.uv1_scale = Vector3(rep, rep, rep)
		if key == "ad_corrugated":
			o.metallic = 0.25
		if key == "ad_ground":
			o.metallic_specular = 0.3
		if key in ["ad_tarp", "ad_canvas"]:
			o.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = o
	elif LAMPS.has(key):
		var l := StandardMaterial3D.new()
		var c: Color = LAMPS[key][0]
		l.albedo_color = c * 0.6
		l.roughness = 0.15
		l.emission_enabled = true
		l.emission = c
		l.emission_energy_multiplier = float(LAMPS[key][1])
		m = l
	elif CARDS.has(key):
		var cd := StandardMaterial3D.new()
		var e: Array = CARDS[key]
		cd.albedo_texture = _tex(e[0])
		cd.cull_mode = BaseMaterial3D.CULL_DISABLED
		cd.roughness = 0.9
		match String(e[1]):
			"card":
				cd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				cd.alpha_scissor_threshold = 0.4
			"decal":
				cd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				cd.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				cd.render_priority = 1
			"smoke":
				cd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				cd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cd.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				cd.albedo_color = Color(0.8, 0.8, 0.8, 0.85)
			"add":
				cd.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				cd.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				cd.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				cd.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
				cd.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				cd.no_depth_test = false
		m = cd
	else:
		var p := StandardMaterial3D.new()
		var pe: Array = PLAIN.get(key, [Color(0.5, 0.5, 0.5), 0.8, 0.0])
		p.albedo_color = pe[0]
		p.roughness = float(pe[1])
		p.metallic = float(pe[2])
		if key == "ad_glass":
			p.albedo_color = Color(0.3, 0.32, 0.32, 0.4)
			p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			p.roughness = 0.1
			p.cull_mode = BaseMaterial3D.CULL_DISABLED
		if key == "ad_ribbon":
			p.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = p
	m.resource_name = key
	if not (CARDS.has(key) or LAMPS.has(key) or key == "ad_glass"):
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

static func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _meshes(c, out)

static func _dress(root: Node3D, lod_end: float) -> void:
	var ms: Array = []
	_meshes(root, ms)
	for mi: MeshInstance3D in ms:
		var nm := String(mi.name)
		if nm.ends_with("_LOD0"):
			var has1 := false
			for c in mi.get_parent().get_children(): if String(c.name).ends_with("_LOD1"): has1 = true
			if has1:
				mi.visibility_range_end = lod_end; mi.visibility_range_end_margin = 2.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		elif nm.ends_with("_LOD1"):
			mi.visibility_range_begin = lod_end; mi.visibility_range_begin_margin = 2.0
		if mi.mesh == null: continue
		var cards_only := true
		for s in mi.mesh.get_surface_count():
			var m0 := mi.mesh.surface_get_material(s)
			if m0 == null: continue
			var key := m0.resource_name
			if key.begins_with("site_") or key.begins_with("ad_"):
				mi.set_surface_override_material(s, mat(key))
			if not (CARDS.has(key) and String(CARDS[key][1]) != "card"): cards_only = false
		if cards_only:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## a plain box of the manifest size, or a code-built hunter with the same node names
static func _stand_in(name: String) -> Node3D:
	var r := Node3D.new()
	r.name = name
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.08, 0.08, 0.09); dark.roughness = 0.5
	if name in HUNTERS:
		var n_rot := 6 if name == "hunter_drone_b" else 4
		var span := 0.45 if name == "hunter_drone_c" else (0.55 if name == "hunter_drone_b" else 0.45)
		var y := 0.06 if name == "hunter_drone_c" else 0.2
		var body := MeshInstance3D.new(); body.name = "body"
		var bm := BoxMesh.new(); bm.size = Vector3(span * 0.5, 0.1, span * 0.7); body.mesh = bm
		body.position = Vector3(0, y, 0); body.material_override = dark; r.add_child(body)
		var eye := MeshInstance3D.new(); eye.name = "eye"
		var sm := SphereMesh.new(); sm.radius = 0.03; sm.height = 0.06; eye.mesh = sm
		eye.position = Vector3(0, y, span * 0.37); eye.material_override = mat("ad_lamp_eye"); r.add_child(eye)
		for i in n_rot:
			var th := deg_to_rad(45.0 + 90.0 * i) if n_rot == 4 else deg_to_rad(30.0 + 60.0 * i)
			var rn := MeshInstance3D.new(); rn.name = "rotor_%d" % (i + 1)
			var cm := CylinderMesh.new(); cm.top_radius = span * 0.42; cm.bottom_radius = span * 0.42; cm.height = 0.006
			rn.mesh = cm; rn.material_override = dark
			rn.position = Vector3(-sin(th) * span * 0.75, y + 0.06, cos(th) * span * 0.75)
			r.add_child(rn)
		return r
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var e: Dictionary = info(name)
	var sz := Vector3.ONE
	var lo := Vector3(-0.5, 0.0, -0.5)
	if e.has("size"):
		sz = e["size"]; lo = e["aabb_lo"]
	box.size = sz
	mi.mesh = box
	mi.position = lo + sz * 0.5
	var sm2 := StandardMaterial3D.new(); sm2.albedo_color = Color(0.45, 0.42, 0.38)
	mi.material_override = sm2
	r.add_child(mi)
	return r

static func instance(name: String, opts := {}) -> Node3D:
	var p := path_of(name)
	if not ResourceLoader.exists(p):
		push_warning("AntiDroneAssets: no file " + p + ", using a stand-in")
		return _stand_in(name)
	var ps: PackedScene = _scenes.get(name)
	if ps == null:
		ps = load(p) as PackedScene
		_scenes[name] = ps
	if ps == null:
		return _stand_in(name)
	var root := ps.instantiate() as Node3D
	root.name = name
	var lod_end := float(info(name).get("lod_end", 40.0)) * float(opts.get("lod_scale", 1.0))
	_dress(root, lod_end)
	if not bool(opts.get("lamps", true)):
		for k in LAMPS: set_lamp(root, k, 0.0)
	return root

static func place(parent: Node, name: String, xf: Transform3D, opts := {}) -> Node3D:
	var n := instance(name, opts)
	n.transform = xf
	parent.add_child(n)
	return n

## any lamp material on this instance: energy 0 is off (a per-instance copy, so other instances keep their state)
static func set_lamp(node: Node3D, key: String, energy: float) -> void:
	var ms: Array = []
	_meshes(node, ms)
	for mi: MeshInstance3D in ms:
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m == null or m.resource_name != key: continue
			var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.emission_energy_multiplier = energy
			mi.set_surface_override_material(s, d)
		if mi.material_override != null and mi.material_override.resource_name == key:
			var d2 := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			d2.emission_energy_multiplier = energy
			mi.material_override = d2

static func set_beacon(node: Node3D, on: bool) -> void:
	set_lamp(node, "ad_lamp_red", float(LAMPS["ad_lamp_red"][1]) if on else 0.0)

## the jammer coming down: t 0 standing .. 1 laid forward over the drawbar (meta.lower_deg about the mast's local x)
static func lower_mast(node: Node3D, t: float) -> void:
	var mast := node.find_child("mast", true, false) as Node3D
	if mast == null: return
	if not mast.has_meta("rest"): mast.set_meta("rest", mast.transform)
	var deg := float(meta(String(node.name)).get("lower_deg", 88.0))
	var rest: Transform3D = mast.get_meta("rest")
	mast.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, deg_to_rad(deg) * clampf(t, 0.0, 1.0)), rest.origin)
	var guys := node.find_child("guy_wires", true, false) as Node3D
	if guys != null: guys.visible = t <= 0.0
	set_beacon(node, t <= 0.0)

## spin every rotor_N about its local y; meta.spin gives +1 anticlockwise seen from above
static func spin_rotors(node: Node3D, delta: float, rev_per_s := 60.0) -> void:
	var spin: Dictionary = meta(String(node.name)).get("spin", {})
	for i in range(1, 7):
		var r := node.find_child("rotor_%d" % i, true, false) as Node3D
		if r == null: continue
		var dir := float(spin.get("rotor_%d" % i, 1 if i % 2 == 0 else -1))
		r.rotate_object_local(Vector3.UP, dir * rev_per_s * TAU * delta)

## a double-blink strobe (two 60 ms flashes a second) on the racing hunter's strobe and any strobe card
static func flash(node: Node3D, time: float) -> void:
	var ph := fposmod(time, 1.0)
	var on := ph < 0.06 or (ph > 0.18 and ph < 0.24)
	set_lamp(node, "ad_lamp_strobe", float(LAMPS["ad_lamp_strobe"][1]) if on else 0.0)
	var ms: Array = []
	_meshes(node, ms)
	for mi: MeshInstance3D in ms:
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m != null and m.resource_name == "ad_strobe":
				mi.visible = on

static func drape(node: Node3D, height_fn: Callable) -> void:
	SiteAssets.drape(node, height_fn)
