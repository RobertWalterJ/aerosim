class_name SiteAssets
extends RefCounted
## The site assets of lane/sites (godot/docs/CLAUDE-BOAT-LAUNCH-ASSETS.md and CLAUDE-CABIN-TRACK-ASSETS.md on lane/notify):
## the Halloway Lake boat launch and the old cabin track and cave. Modelled in Blender by tools/blender/build_sites.py
## (sites_launch.py, sites_track.py) and exported to assets/models/sites/<name>.glb; SiteManifest (generated) lists every
## file's named nodes, pivots, sizes, LOD distance, metadata and the Blender-side checks.
##
## Frame: metres, Y up, +Z is the asset's front, origin at the base (the dock and marker: the water surface; the hull: its
## keel). Each .glb holds NAMED NODES (boat_ramp_slab, boat_dock_floats, tree_fall_a_roots, cave_mouth...) with <node>_LOD0
## and <node>_LOD1 meshes under them. The meshes carry plain materials named site_* and a vertex colour (occlusion times
## weathering, linear); this script swaps in the photographed PBR sets by name (sources in assets/textures/README.md) and
## sets the LOD visibility ranges, so always go through instance() / place().
##
## Calls:
##   SiteAssets.place(parent, "boat_trailer_hull", Transform3D) -> Node3D      (any asset name, or a brief part name below)
##   SiteAssets.instance(name, opts := {}) -> Node3D                           (opts: "lod_scale": float, "lights": bool)
##   SiteAssets.fit_ramp(ramp_node, head_y, water_y)   shears the level ramp so its waterline mark (z 24) meets water_y
##   SiteAssets.drape(node, height_fn: Callable)        moves every vertex of a ground piece (apron, track, aprons, puddle,
##                                                      leaf drift) onto height_fn.call(x, z) in world space, keeping relief
##   SiteAssets.track_material() -> Material             the cabin-track surface for a code-built ribbon: u 0..1 across
##                                                      4.4 m (ruts at u 0.32 and 0.68), v = metres along / 8
##   SiteAssets.set_lamps(node, on)                      trailer tail lamps on or off (emissive, no light nodes)
##   SiteAssets.has(name), names(), info(name) (the manifest entry), meta(name)
## If a file is missing, instance() returns a plain stand-in box of the manifest size (or a 1 m marker) so placement code
## never breaks.

const DIR := "res://assets/models/sites/"

## brief part names that live as a node inside another file: name -> [file, node(s)]
const PARTS := {
	"boat_ramp_slab": ["boat_ramp", ["boat_ramp_slab"]],
	"boat_ramp_curb": ["boat_ramp", ["boat_ramp_curb_l", "boat_ramp_curb_r"]],
	"boat_ramp_grooves": ["boat_ramp", ["boat_ramp_slab"]],
	"boat_dock_deck": ["boat_dock", ["boat_dock_deck"]],
	"boat_dock_posts": ["boat_dock", ["boat_dock_posts"]],
	"boat_dock_floats": ["boat_dock", ["boat_dock_floats"]],
	"boat_dock_cleats": ["boat_dock", ["boat_dock_cleats"]],
	"boat_trailer_winch": ["boat_trailer", ["boat_trailer_winch"]],
	"cave_mouth": ["cave_outcrop", ["cave_mouth"]],
}

## key -> [texture prefix, metres per repeat, triplanar, normal scale]. Prefixes are files in assets/textures.
const SETS := {
	"site_concrete": ["site_concrete", 3.0, false, 1.0],
	"site_ramp": ["site_ramp", 2.0, false, 1.0],
	"site_gravel": ["site_gravel", 2.0, false, 1.0],
	"site_dirt": ["site_dirt", 3.0, false, 1.0],
	"site_mud": ["site_dirt", 2.0, false, 0.6],
	"site_soil": ["site_leaflitter", 2.5, false, 1.0],
	"site_track": ["site_track", 1.0, false, 1.0],
	"site_deck": ["bld_wood", 2.0, false, 1.0],
	"site_timber": ["postwood", 1.0, false, 1.0],
	"site_board": ["barnwood", 1.5, false, 1.0],
	"site_paint_cream": ["bld_paint", 1.2, false, 0.6],
	"site_paint_red": ["bld_paint", 1.2, false, 0.6],
	"site_paint_white": ["bld_paint", 1.2, false, 0.5],
	"site_paint_green": ["bld_paint", 1.2, false, 0.5],
	"site_rock": ["limestone", 2.2, true, 1.0],
	"site_rock_moss": ["mossrock", 2.4, true, 1.0],
	"site_moss": ["mossrock", 1.2, false, 0.8],
	"site_bark_oak": ["bark_oak", 1.0, false, 1.0],
	"site_bark_beech": ["site_bark_beech", 1.2, false, 1.0],
	"site_wood_end": ["site_wood_end", 1.0, false, 1.0],
	"site_alu": ["site_alu", 1.0, false, 1.0],
	"site_rust": ["rust", 0.6, false, 1.0],
}

## plain PBR: key -> [albedo sRGB, roughness, metallic]
const PLAIN := {
	"site_paint_black": [Color(0.06, 0.06, 0.06), 0.55, 0.0],
	"site_galv": [Color(0.66, 0.67, 0.66), 0.48, 0.85],
	"site_iron": [Color(0.17, 0.16, 0.15), 0.72, 0.55],
	"site_rubber": [Color(0.045, 0.045, 0.045), 0.88, 0.0],
	"site_plastic_white": [Color(0.86, 0.86, 0.82), 0.5, 0.0],
	"site_plastic_red": [Color(0.66, 0.07, 0.05), 0.42, 0.0],
	"site_plastic_dark": [Color(0.10, 0.11, 0.12), 0.42, 0.0],
	"site_plastic_green": [Color(0.12, 0.32, 0.18), 0.45, 0.0],
	"site_rope": [Color(0.70, 0.64, 0.50), 0.92, 0.0],
	"site_carpet": [Color(0.30, 0.31, 0.32), 1.0, 0.0],
	"site_wood_fresh": [Color(0.70, 0.58, 0.42), 0.85, 0.0],
	"site_grass": [Color(1, 1, 1), 0.9, 0.0],
	"site_ply": [Color(0.55, 0.45, 0.32), 0.85, 0.0],
	"site_canvas_blue": [Color(0.19, 0.33, 0.50), 0.85, 0.0],
	"site_canvas_orange": [Color(0.88, 0.38, 0.08), 0.85, 0.0],
	"site_paper": [Color(0.86, 0.84, 0.76), 0.92, 0.0],
	"site_reflector": [Color(0.85, 0.85, 0.85), 0.25, 0.3],
}

const DECALS := ["site_decal_rust", "site_decal_algae", "site_decal_waterline", "site_decal_crack", "site_decal_oil",
	"site_decal_tyre", "site_decal_damp", "site_decal_chalk"]

## stand-in sizes (metres) when neither the file nor its manifest entry is there
const FALLBACK_SIZE := Vector3(1.0, 1.0, 1.0)

static var _scenes := {}
static var _mats := {}

static func has(name: String) -> bool:
	return SiteManifest.DATA.has(name) or PARTS.has(name)

static func names() -> Array:
	return SiteManifest.DATA.keys()

static func info(name: String) -> Dictionary:
	if PARTS.has(name): name = PARTS[name][0]
	return SiteManifest.DATA.get(name, {})

static func meta(name: String) -> Dictionary:
	return info(name).get("meta", {})

static func path_of(name: String) -> String:
	return DIR + name + ".glb"

## the materials: photographed ORM sets or plain PBR, all multiplied by the vertex colour (occlusion and weathering)
static func mat(key: String) -> Material:
	if _mats.has(key): return _mats[key]
	var m: BaseMaterial3D
	if SETS.has(key):
		var s: Array = SETS[key]
		var pre: String = s[0]
		var o: BaseMaterial3D
		if ResourceLoader.exists("res://assets/textures/%s_arm.jpg" % pre): o = ORMMaterial3D.new()
		else: o = StandardMaterial3D.new()
		o.albedo_texture = load("res://assets/textures/%s_diff.jpg" % pre)
		if ResourceLoader.exists("res://assets/textures/%s_nor.jpg" % pre):
			o.normal_enabled = true
			o.normal_texture = load("res://assets/textures/%s_nor.jpg" % pre)
			o.normal_scale = float(s[3])
		if o is ORMMaterial3D:
			(o as ORMMaterial3D).orm_texture = load("res://assets/textures/%s_arm.jpg" % pre)
		else:
			o.roughness = 0.85
		var rep := 1.0 / float(s[1])
		o.uv1_scale = Vector3(rep, rep, rep)
		if key == "site_bark_oak": o.uv1_scale = Vector3(1.0, 0.5, 1.0)       # the photograph is 1 m round by 2 m up the trunk
		if key in ["site_concrete", "site_ramp", "site_gravel", "site_dirt", "site_track", "site_soil", "site_mud"]:
			o.metallic_specular = 0.3      # ground: no sky sheen from the shiny patches of the photographed roughness
		if bool(s[2]):
			o.uv1_triplanar = true
			o.uv1_triplanar_sharpness = 4.0
		match key:
			"site_paint_cream": o.albedo_color = Color(0.93, 0.89, 0.74)
			"site_paint_red": o.albedo_color = Color(0.70, 0.12, 0.09)
			"site_paint_white": o.albedo_color = Color(0.98, 0.98, 0.95)
			"site_paint_green": o.albedo_color = Color(0.22, 0.36, 0.26)
			"site_mud": o.albedo_color = Color(0.55, 0.5, 0.45)
			"site_rock": o.albedo_color = Color(0.6, 0.6, 0.62)
			"site_rock_moss": o.albedo_color = Color(0.74, 0.8, 0.7)
			"site_gravel": o.albedo_color = Color(0.9, 0.93, 0.98)
			"site_bark_oak": o.albedo_color = Color(0.72, 0.7, 0.66)
			"site_bark_beech": o.albedo_color = Color(0.78, 0.8, 0.86)
			"site_moss": o.albedo_color = Color(0.8, 0.9, 0.62)
			"site_alu": o.metallic = 0.32      # dull, oxidised: a bright metallic hull mirrors the whole sky
			"site_concrete", "site_ramp": o.albedo_color = Color(1.32, 1.3, 1.26)
		if key == "site_mud" and o is ORMMaterial3D:
			# wet: darker and glossier than the dirt it is made from (an ORM cannot scale roughness; use a standard one)
			var w := StandardMaterial3D.new()
			w.albedo_texture = o.albedo_texture; w.albedo_color = o.albedo_color
			w.normal_enabled = true; w.normal_texture = o.normal_texture; w.normal_scale = 0.6
			w.roughness = 0.6; w.metallic_specular = 0.4; w.uv1_scale = o.uv1_scale
			o = w
		m = o
	elif key in DECALS:
		var d := StandardMaterial3D.new()
		d.albedo_texture = load("res://assets/textures/%s.png" % key)
		d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d.roughness = 0.35 if key == "site_decal_oil" else 0.9
		d.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		d.cull_mode = BaseMaterial3D.CULL_DISABLED
		d.render_priority = 1
		m = d
	else:
		var p := StandardMaterial3D.new()
		match key:
			"site_cave_dark":
				# the cave mouth stays black in any light: unshaded, no reflections, no fog lift
				p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				p.albedo_color = Color(0.0, 0.0, 0.0)
				p.disable_fog = true
			"site_puddle":
				p.albedo_color = Color(0.11, 0.09, 0.065)
				p.roughness = 0.18
				p.metallic_specular = 0.35
			"site_glass":
				p.albedo_color = Color(0.32, 0.33, 0.30, 0.38)
				p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				p.roughness = 0.25
				p.cull_mode = BaseMaterial3D.CULL_DISABLED
			"site_leaves":
				p.albedo_texture = load("res://assets/trees/leaves_beech.webp")
				p.albedo_color = Color(0.62, 0.45, 0.32)
				p.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				p.alpha_scissor_threshold = 0.45
				p.cull_mode = BaseMaterial3D.CULL_DISABLED
				p.roughness = 0.85
			"site_lamp_red", "site_lamp_amber":
				var c := Color(0.75, 0.05, 0.03) if key == "site_lamp_red" else Color(0.95, 0.5, 0.05)
				p.albedo_color = c
				p.roughness = 0.2
				p.emission_enabled = true
				p.emission = c
				p.emission_energy_multiplier = 0.0
			_:
				var e: Array = PLAIN.get(key, [Color(0.6, 0.6, 0.6), 0.8, 0.0])
				p.albedo_color = e[0]
				p.roughness = float(e[1])
				p.metallic = float(e[2])
				if key == "site_rubber":
					p.normal_enabled = true
					p.normal_texture = load("res://assets/textures/rubber_nor.jpg")
					p.uv1_scale = Vector3(6.0, 6.0, 6.0)
				if key in ["site_grass", "site_canvas_blue", "site_canvas_orange", "site_paper", "site_rope"]:
					p.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = p
	m.resource_name = key
	if key != "site_cave_dark" and not key in DECALS and key != "site_glass":
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = false
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m

## the cabin-track surface for a code-built ribbon (u 0..1 across 4.4 m, v = metres / 8)
static func track_material() -> Material:
	return mat("site_track")

static func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _meshes(c, out)

static func _dress(root: Node3D, lod_end: float) -> void:
	var ms: Array = []
	_meshes(root, ms)
	for mi: MeshInstance3D in ms:
		var nm := String(mi.name)
		if nm.ends_with("_LOD0"):
			mi.visibility_range_end = lod_end; mi.visibility_range_end_margin = 2.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		elif nm.ends_with("_LOD1"):
			mi.visibility_range_begin = lod_end; mi.visibility_range_begin_margin = 2.0
		if mi.mesh == null: continue
		var decal_only := true
		for s in mi.mesh.get_surface_count():
			var m0 := mi.mesh.surface_get_material(s)
			if m0 == null: continue
			var key := m0.resource_name
			if key.begins_with("site_"):
				mi.set_surface_override_material(s, mat(key))
			if not (key in DECALS or key == "site_cave_dark"): decal_only = false
		if decal_only:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _stand_in(name: String) -> Node3D:
	var r := Node3D.new()
	r.name = name
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var e: Dictionary = info(name)
	var sz: Vector3 = FALLBACK_SIZE
	var lo := Vector3(-0.5, 0.0, -0.5)
	if e.has("size"):
		sz = e["size"]; lo = e["aabb_lo"]
	bm.size = sz
	mi.mesh = bm
	mi.position = lo + sz * 0.5
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.5, 0.48, 0.44)
	mi.material_override = sm
	r.add_child(mi)
	return r

static func instance(name: String, opts := {}) -> Node3D:
	var file := name
	var keep: Array = []
	if PARTS.has(name):
		file = PARTS[name][0]
		keep = PARTS[name][1]
	var p := path_of(file)
	if not ResourceLoader.exists(p):
		push_warning("SiteAssets: no file " + p + ", using a stand-in")
		return _stand_in(name)
	var ps: PackedScene = _scenes.get(file)
	if ps == null:
		ps = load(p) as PackedScene
		_scenes[file] = ps
	var root := ps.instantiate() as Node3D
	root.name = name
	if not keep.is_empty():
		for c in root.get_children():
			if not String(c.name) in keep:
				root.remove_child(c)
				c.free()
	var lod_end := float(info(file).get("lod_end", 40.0)) * float(opts.get("lod_scale", 1.0))
	_dress(root, lod_end)
	if bool(opts.get("lights", false)):
		set_lamps(root, true)
	return root

static func place(parent: Node, name: String, xf: Transform3D, opts := {}) -> Node3D:
	var n := instance(name, opts)
	n.transform = xf
	parent.add_child(n)
	return n

## the ramp is built level (head at z 0, toe at z 30, waterline mark at z = meta.waterline_z); this shears it so the top
## falls from head_y at the head to water_y at the mark (and carries on under water), keeping the node's yaw and position.
## Call after placing it with its origin at the head.
static func fit_ramp(ramp: Node3D, head_y: float, water_y: float) -> void:
	var wl := float(meta("boat_ramp").get("waterline_z", 24.0))
	var k := (water_y - head_y) / wl
	var shear := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, k, 1))
	var yaw := Basis(Vector3.UP, ramp.transform.basis.get_euler().y)
	ramp.transform = Transform3D(yaw * shear, Vector3(ramp.position.x, head_y, ramp.position.z))

## drape ground pieces onto the terrain: every vertex moves to height_fn.call(world_x, world_z) plus its own height above
## the asset's base, so the apron, track segment, cave apron and puddles follow sloping ground.
static func drape(node: Node3D, height_fn: Callable) -> void:
	var ms: Array = []
	_meshes(node, ms)
	for mi: MeshInstance3D in ms:
		var am := mi.mesh as ArrayMesh
		if am == null: continue
		var gx := mi.global_transform
		var inv := gx.affine_inverse()
		var out := ArrayMesh.new()
		for s in am.get_surface_count():
			var arr := am.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for i in vs.size():
				var w := gx * vs[i]
				var base_local_y: float = vs[i].y
				var h: float = height_fn.call(w.x, w.z)
				vs[i] = inv * Vector3(w.x, h + base_local_y, w.z)
			arr[Mesh.ARRAY_VERTEX] = vs
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(s, am.surface_get_material(s))
			var ov := mi.get_surface_override_material(s)
			if ov != null: mi.set_surface_override_material(s, ov)
		mi.mesh = out

## the boat trailer's tail lamps and side markers (emissive only)
static func set_lamps(node: Node3D, on: bool) -> void:
	var ms: Array = []
	_meshes(node, ms)
	for mi: MeshInstance3D in ms:
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m == null or not m.resource_name.begins_with("site_lamp"): continue
			var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
			d.emission_energy_multiplier = 3.0 if on else 0.0
			mi.set_surface_override_material(s, d)
