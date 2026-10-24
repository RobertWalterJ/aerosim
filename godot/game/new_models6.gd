class_name NewModels6
extends RefCounted
## The story batch (models8): the assets for "The Lake Car" and Halloway (docs/story/CLAUDE-NARRATIVE-ASSETS.md in lane/notify),
## drawn by code with the DroneParts kit and written out as glTF binaries under assets/models/story/ by tools/export_story.gd.
## This file is the framework: materials, the little shape helpers every group uses, the model container, the scene builder
## (a root node with named children for wheels, doors and lamp glass, plus collision hulls) and the entry points. The assets
## themselves live in the group files: NewModels6Chars (people and dogs), NewModels6Camp (camp, evidence), NewModels6Bus (the
## festival bus and the garage), NewModels6Town (festival field and Halloway high street).
## The story brief's frame, not the older models': real metres, Y up, +Z forward, origin at the base (a seated person: the
## ground under them), x is the model's right-hand side when looking along +Z... which is -x on screen; see the contract.
## The contract is game/README-models.md ("Batch 8").

const LOD_SEG := [16, 10, 6]

## Models that also get a middle and a far version written (<name>_lod1.glb, <name>_lod2.glb).
const LODS := {"festival_bus_restored": true, "festival_bus_restored_open": true, "festival_bus_garage": true}

## Where each name is written: assets/models/story/<dir>/<name>.glb (lod 1 and 2 as <name>_lod1.glb where the model has them).
static func group_of(name: String) -> String:
	var g7 := NewModels7.group_of(name)
	if g7 != "": return g7
	if name.begins_with("ellis_") or name.begins_with("biscuit_") or name.begins_with("rennick_") or name == "dog_bowl_a" or name == "police_clipboard_a":
		return "characters"
	if name.begins_with("camp_"): return "camp"
	if name.begins_with("festival_"): return "festival"
	if name.begins_with("garage_") or name.begins_with("town_"): return "halloway"
	if name.begins_with("crowd_") or name.begins_with("parade_"): return "festival"
	if name.begins_with("lost_dog") or name.begins_with("crop_circle") or name == "milk_churn_a" or name.begins_with("railway_signal"): return "cases"
	if name.begins_with("livery_") or name.begins_with("drone_badge") or name.begins_with("casebook_") : return "reward"
	if name.begins_with("police_") or name.begins_with("evidence_") or name.begins_with("car_") or name.begins_with("committee_"): return "evidence"
	return "reward"

static func names() -> Array[String]:
	var out: Array[String] = []
	out.append_array(NewModels6Chars.NAMES)
	out.append_array(NewModels6Camp.NAMES)
	out.append_array(NewModels6Bus.NAMES)
	out.append_array(NewModels6Town.NAMES)
	out.append_array(NewModels6Hall.NAMES)
	out.append_array(NewModels6Evid.NAMES)
	out.append_array(NewModels6Later.NAMES)
	out.append_array(NewModels7.names())
	return out

# ================================================================== materials
static var _mats := {}
static var _xmats := {}

## Material keys. Textured (shader) keys carry a photographed set in the game; the exported glTF gets a plain vertex-colour
## stand-in with the same resource name, so a loader can swap the kit material in by name.
const SHADER_KEYS := ["wood", "steel", "paintwood", "brick", "roof", "stone", "concrete", "soil", "mud", "hay"]

static func _brick_material() -> ShaderMaterial:
	if _mats.has("brick"): return _mats["brick"]
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/farm.gdshader") as Shader
	m.set_shader_parameter("set_albedo", load("res://assets/textures/brick_diff.jpg"))
	m.set_shader_parameter("set_normal", load("res://assets/textures/brick_nor.jpg"))
	m.set_shader_parameter("set_arm", load("res://assets/textures/brick_arm.jpg"))
	m.set_shader_parameter("kind", 2)
	m.set_shader_parameter("proj", 0)
	m.set_shader_parameter("set_metres", Vector2(1.0, 1.0))
	m.set_shader_parameter("tint_gain", 1.35)
	m.set_shader_parameter("metal_amt", 0.0)
	m.set_shader_parameter("normal_amt", 1.0)
	_mats["brick"] = m
	return m

static func _std(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match key:
		"paint": m.roughness = 0.82; m.metallic_specular = 0.4
		"gloss": m.roughness = 0.32; m.metallic_specular = 0.6; m.clearcoat_enabled = true; m.clearcoat = 0.35; m.clearcoat_roughness = 0.25
		"sheet": m.roughness = 0.5; m.metallic = 0.4
		"rust": m.roughness = 0.9; m.metallic = 0.15
		"chrome": m.roughness = 0.18; m.metallic = 1.0
		"cloth": m.roughness = 0.95; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.metallic_specular = 0.2
		"canvas": m.roughness = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.metallic_specular = 0.25
		"tarp": m.roughness = 0.55; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"rubber": m.roughness = 0.88; m.metallic_specular = 0.3
		"skin": m.roughness = 0.62; m.metallic_specular = 0.45; m.subsurf_scatter_enabled = true; m.subsurf_scatter_strength = 0.35
		"fur": m.roughness = 0.95; m.metallic_specular = 0.2
		"leather": m.roughness = 0.6; m.metallic_specular = 0.5
		"enamel": m.roughness = 0.28; m.metallic_specular = 0.6
		"paper": m.roughness = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glass":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.05, 0.07, 0.08, 0.5); m.roughness = 0.04; m.metallic = 0.7
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"water":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.24, 0.2, 0.12, 0.82); m.roughness = 0.04; m.metallic_specular = 0.7
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"lamp":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(1.0, 0.93, 0.78); m.emission_enabled = true; m.emission = Color(1.0, 0.86, 0.6); m.emission_energy_multiplier = 2.4
		"steam":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.8, 0.8, 0.84, 0.07); m.roughness = 1.0
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"warm":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(1.0, 0.85, 0.6); m.emission_enabled = true; m.emission = Color(1.0, 0.72, 0.4); m.emission_energy_multiplier = 1.1
		"flame":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(1.0, 0.5, 0.15); m.emission_enabled = true; m.emission = Color(1.0, 0.42, 0.08); m.emission_energy_multiplier = 3.2
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"flame_blue":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.5, 0.65, 1.0); m.emission_enabled = true; m.emission = Color(0.2, 0.4, 1.0); m.emission_energy_multiplier = 2.4
		"lamp_red":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(1.0, 0.3, 0.25); m.emission_enabled = true; m.emission = Color(1.0, 0.1, 0.08); m.emission_energy_multiplier = 2.6
		"lamp_blue":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.5, 0.65, 1.0); m.emission_enabled = true; m.emission = Color(0.25, 0.45, 1.0); m.emission_energy_multiplier = 2.2
		"lamp_off":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.78, 0.76, 0.68); m.roughness = 0.2
		_: m.roughness = 0.85
	return m

## The in-game material for a key (shader-textured where the farm kit has a set).
static func mat(key: String) -> Material:
	if _mats.has(key): return _mats[key]
	var m: Material
	match key:
		"wood": m = NewModels3._mat("wood")
		"steel": m = NewModels3._mat("steel")
		"soil", "mud", "hay": m = NewModels3._mat(key)
		"paintwood": m = NewModels2.farm_material("wood")
		"roof": m = NewModels2.farm_material("roof")
		"stone": m = NewModels2.farm_material("stone")
		"concrete": m = NewModels2.farm_material("concrete")
		"brick": m = _brick_material()
		_: m = _std(key)
	_mats[key] = m
	return m

## The plain stand-in written to glTF files: vertex colour as albedo, the key as the material name.
static func export_mat(key: String) -> Material:
	if _xmats.has(key): return _xmats[key]
	var m: StandardMaterial3D
	if key in SHADER_KEYS:
		m = StandardMaterial3D.new()
		m.resource_name = key
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		match key:
			"roof", "steel": m.roughness = 0.5; m.metallic = 0.4
			_: m.roughness = 0.85
	else:
		m = _std(key)
	_xmats[key] = m
	return m

# ================================================================== the model container
## One drawn thing: triangle buffers per material for the main node, plus named sub-nodes (wheels, doors, lamp glass) with a
## pivot, plus collision hulls.
class Model:
	var m := {}                       # material key -> NewModels2.Buf
	var subs := {}                    # node name -> Model (its own buffers, positions given in the model's frame)
	var pivots := {}                  # node name -> Vector3
	var hulls: Array = []             # AABB in the model's frame
	func b(key: String) -> NewModels2.Buf:
		if not m.has(key): m[key] = NewModels2.Buf.new()
		return m[key]
	func sub(node: String, pivot := Vector3.ZERO) -> Model:
		if not subs.has(node):
			subs[node] = Model.new()
			pivots[node] = pivot
		return subs[node]

static var _cache := {}

static func build(name: String, lod := 0) -> Model:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d" % [name, lod]
	if _cache.has(k): return _cache[k]
	var md := Model.new()
	var ok := NewModels6Chars.build(name, md, lod) or NewModels6Camp.build(name, md, lod) or NewModels6Bus.build(name, md, lod) \
		or NewModels6Town.build(name, md, lod) or NewModels6Hall.build(name, md, lod) or NewModels6Evid.build(name, md, lod) or NewModels6Later.build(name, md, lod) \
			or NewModels7.build(name, md, lod)
	if not ok:
		push_error("NewModels6: no model called " + name)
	_cache[k] = md
	return md

static func _commit(md: Model, offset: Vector3, export: bool) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	for key in md.m:
		var buf: NewModels2.Buf = md.m[key]
		if buf.pos.is_empty(): continue
		var d := buf.data()
		if offset != Vector3.ZERO:
			var p2 := PackedVector3Array(); p2.resize(buf.pos.size())
			for i in buf.pos.size(): p2[i] = buf.pos[i] - offset
			d = [p2, buf.nrm, buf.cols]
		kit.add(export_mat(key) if export else mat(key), d)
	var out := kit.commit()
	return out

## All of it as one mesh (sub-nodes in place): for budgets and contact sheets.
static func mesh(name: String, lod := 0) -> ArrayMesh:
	var md := build(name, lod)
	var kit := DroneParts.Kit.new()
	var merged := {}
	for key in md.m: merged[key] = md.m[key]
	var extra := {}
	for sn in md.subs:
		var sm: Model = md.subs[sn]
		for key in sm.m:
			if not extra.has(key): extra[key] = []
			extra[key].append(sm.m[key])
	for key in merged:
		kit.add(mat(key), (merged[key] as NewModels2.Buf).data())
	for key in extra:
		for buf: NewModels2.Buf in extra[key]:
			kit.add(mat(key), buf.data())
	return kit.commit()

## A root node (named after the asset) with a "body" mesh, one child per sub-node at its pivot, and collision hulls as
## `hullN-colonly` boxes (Godot's importer turns those into a static body). export true: plain glTF-friendly materials.
static func scene(name: String, lod := 0, export := false) -> Node3D:
	var md := build(name, lod)
	var root := Node3D.new()
	root.name = name
	var body := MeshInstance3D.new()
	body.name = "body"
	body.mesh = _commit(md, Vector3.ZERO, export)
	root.add_child(body)
	for sn in md.subs:
		var sm: Model = md.subs[sn]
		var mi := MeshInstance3D.new()
		mi.name = sn
		var piv: Vector3 = md.pivots[sn]
		mi.position = piv
		mi.mesh = _commit(sm, piv, export)
		root.add_child(mi)
	var i := 0
	for h in (md.hulls if export else []):
		var bb: AABB = h
		var hi := MeshInstance3D.new()
		hi.name = "hull%d-colonly" % i
		var bm := BoxMesh.new(); bm.size = bb.size
		hi.mesh = bm
		hi.position = bb.get_center()
		root.add_child(hi)
		i += 1
	return root

static func colliders(name: String) -> Array:
	return build(name, 0).hulls

# ================================================================== shape helpers (shared by every group)
static func rnd(i: float, salt := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

## A colour nudged by position, so flat parts do not look printed.
static func vc(c: Color, k: float, amt := 0.06) -> Color:
	var o := NewModels._vary(c, Vector3(k * 1.7, k * 0.31, 5.1), amt)
	o.a = c.a
	return o

static func _fix_alpha(b: NewModels2.Buf, from: int, key: String, a: float) -> void:
	if key == "wood" or key == "steel": return
	for i in range(from, b.cols.size()):
		var c := b.cols[i]; c.a = a; b.cols[i] = c

## A box centred on c, size s, turned by yaw about +Y (or by a full basis).
static func box(md: Model, key: String, c: Vector3, s: Vector3, col: Color, yaw := 0.0, top := Color(-1, 0, 0), bas := Basis.IDENTITY) -> void:
	var b := md.b(key)
	var n0 := b.cols.size()
	var bb := Basis(Vector3.UP, yaw) * bas
	NewModels3._boxb(b, c, bb, s, col, top)
	_fix_alpha(b, n0, key, 1.0)

static func cyl(md: Model, key: String, a: Vector3, c: Vector3, r0: float, r1: float, seg: int, col: Color, caps := 3, vary := 0.05) -> void:
	var b := md.b(key)
	var n0 := b.cols.size()
	NewModels3._prism(b, a, c, r0, r1, seg, col, caps, vary)
	_fix_alpha(b, n0, key, 1.0)

## Add a DroneParts shape ([pos, nrm] or with colours) with a transform and one colour.
static func put(md: Model, key: String, data: Array, xf: Transform3D, col: Color, vary := 0.0) -> void:
	var b := md.b(key)
	var pos: PackedVector3Array = xf * (data[0] as PackedVector3Array)
	var nrm: PackedVector3Array = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (data[1] as PackedVector3Array)
	for i in nrm.size(): nrm[i] = nrm[i].normalized()
	b.pos.append_array(pos); b.nrm.append_array(nrm)
	var n := pos.size()
	for i in n:
		var c := col
		if vary > 0.0 and i % 3 == 0:
			var f := (pos[i] + pos[mini(i + 1, n - 1)] + pos[mini(i + 2, n - 1)]) / 3.0
			c = vc(col, f.x * 7.0 + f.y * 3.0 + f.z * 5.0, vary)
		elif vary > 0.0 and b.cols.size() > 0:
			c = b.cols[b.cols.size() - 1]
		b.cols.append(c)

## Like put, but the colour of each triangle is asked of f(local centre of the triangle, its normal) before the transform.
static func put_f(md: Model, key: String, data: Array, xf: Transform3D, f: Callable) -> void:
	var b := md.b(key)
	var lp: PackedVector3Array = data[0]
	var pos: PackedVector3Array = xf * lp
	var nrm: PackedVector3Array = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (data[1] as PackedVector3Array)
	for i in nrm.size(): nrm[i] = nrm[i].normalized()
	b.pos.append_array(pos); b.nrm.append_array(nrm)
	var n := lp.size()
	var c := Color.WHITE
	for i in n:
		if i % 3 == 0:
			var cen := (lp[i] + lp[mini(i + 1, n - 1)] + lp[mini(i + 2, n - 1)]) / 3.0
			c = f.call(cen, nrm[i])
		b.cols.append(c)

## An ellipsoid centred on c with radii r (x, y, z), optionally turned.
static func ball(md: Model, key: String, c: Vector3, r: Vector3, col: Color, seg := 12, bas := Basis.IDENTITY, vary := 0.0) -> void:
	put(md, key, DroneParts.sphere(1.0, seg), Transform3D(bas * Basis.from_scale(r), c), col, vary)

## A tapered round bar from a to b (flat ends).
static func limb(md: Model, key: String, a: Vector3, c: Vector3, r0: float, r1: float, col: Color, seg := 10, vary := 0.0) -> void:
	put(md, key, DroneParts.tube(a, c, r0, r1, seg), Transform3D.IDENTITY, col, vary)

## A softly rounded box, centred on c.
static func rbox(md: Model, key: String, c: Vector3, s: Vector3, col: Color, bas := Basis.IDENTITY, e := 6.0, seg := 14, vary := 0.0) -> void:
	put(md, key, DroneParts.rbox(s, e, seg), Transform3D(bas, c), col, vary)

## A lofted shell along the line a to b: sections are [t (0..1), half width across (x), half depth (front to back)], and the
## shell is oval-ish with squareness e. across is the world direction the width runs in.
static func shell(md: Model, key: String, a: Vector3, c: Vector3, secs: Array, col: Color, across := Vector3.RIGHT, e := 2.4, seg := 14, vary := 0.0) -> void:
	var L := a.distance_to(c)
	var z := (c - a).normalized()
	var x := across.normalized()
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x)
	var ss: Array = []
	for s in secs: ss.append([float(s[0]) * L, 0.0, 0.0, float(s[1]), float(s[2])])
	var data := DroneParts.loft(ss, e, seg, true)
	# loft's width is local x, its height local y; with basis (x, y, z) the width runs along `across`
	put(md, key, data, Transform3D(Basis(x, y, z), a), col, vary)

## A flat polygon (points in order, convex or a simple fan) double-sided, facing n.
static func sheet(md: Model, key: String, pts: Array, col: Color, n: Vector3, double := true) -> void:
	var b := md.b(key)
	var n0 := b.cols.size()
	NewModels2._fan(b, pts, n, col)
	if double:
		var rev := pts.duplicate(); rev.reverse()
		NewModels2._fan(b, rev, -n, col)
	_fix_alpha(b, n0, key, 1.0)

## A flat quad a b c d, double-sided.
static func quad2(md: Model, key: String, a: Vector3, b2: Vector3, c: Vector3, d: Vector3, col: Color, double := true) -> void:
	var n := (b2 - a).cross(d - a).normalized()
	sheet(md, key, [a, b2, c, d], col, n, double)

## An extruded outline in the XZ plane (x, z points) from y0 to y1.
static func prism_poly(md: Model, key: String, poly: PackedVector2Array, y0: float, y1: float, col: Color, xf := Transform3D.IDENTITY, vary := 0.0) -> void:
	put(md, key, DroneParts.extrude(poly, y0, y1), xf, col, vary)

static func hull(md: Model, c: Vector3, s: Vector3) -> void:
	md.hulls.append(AABB(c - s * 0.5, s))

## ---------------------------------------------------------------- lettering
## A 5 x 7 block alphabet, so signs carry real, readable (fictional) words as thin raised quads rather than a texture.
const FONT := {
	"A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"B": ["XXXX.", "X...X", "X...X", "XXXX.", "X...X", "X...X", "XXXX."],
	"C": [".XXX.", "X...X", "X....", "X....", "X....", "X...X", ".XXX."],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
	"E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
	"F": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
	"G": [".XXX.", "X...X", "X....", "X.XXX", "X...X", "X...X", ".XXX."],
	"H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
	"J": ["..XXX", "...X.", "...X.", "...X.", "...X.", "X..X.", ".XX.."],
	"K": ["X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X"],
	"L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
	"M": ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"],
	"N": ["X...X", "XX..X", "X.X.X", "X..XX", "X...X", "X...X", "X...X"],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
	"Q": [".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..X.", ".XX.X"],
	"R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
	"S": [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
	"U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"V": ["X...X", "X...X", "X...X", "X...X", "X...X", ".X.X.", "..X.."],
	"W": ["X...X", "X...X", "X...X", "X.X.X", "X.X.X", "XX.XX", "X...X"],
	"X": ["X...X", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "X...X"],
	"Y": ["X...X", "X...X", ".X.X.", "..X..", "..X..", "..X..", "..X.."],
	"Z": ["XXXXX", "....X", "...X.", "..X..", ".X...", "X....", "XXXXX"],
	"&": [".XX..", "X..X.", "X.X..", ".X...", "X.X.X", "X..X.", ".XX.X"],
	".": [".....", ".....", ".....", ".....", ".....", ".....", "..X.."],
	"0": [".XXX.", "X...X", "X..XX", "X.X.X", "XX..X", "X...X", ".XXX."],
	"1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", ".XXX."],
	"2": [".XXX.", "X...X", "....X", "...X.", "..X..", ".X...", "XXXXX"],
	"3": ["XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX."],
	"4": ["...X.", "..XX.", ".X.X.", "X..X.", "XXXXX", "...X.", "...X."],
	"5": ["XXXXX", "X....", "XXXX.", "....X", "....X", "X...X", ".XXX."],
	"6": [".XXX.", "X....", "X....", "XXXX.", "X...X", "X...X", ".XXX."],
	"7": ["XXXXX", "....X", "...X.", "..X..", ".X...", ".X...", ".X..."],
	"8": [".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX."],
	"9": [".XXX.", "X...X", "X...X", ".XXXX", "....X", "....X", ".XXX."],
}

## The width of a string at text height h.
static func text_width(s: String, h: float) -> float:
	var u := h / 7.0
	var w := 0.0
	for ch in s: w += (3.0 if ch == " " else 6.0) * u
	return maxf(w - u, 0.0)

## Lettering as thin quads standing off a surface. `anchor` is the middle of the baseline, `face` the way the letters face (they
## read left to right for someone looking at that face), h the cap height.
static func text(md: Model, key: String, s: String, anchor: Vector3, face: Vector3, h: float, col: Color, up := Vector3.UP, off := 0.004) -> void:
	var n := face.normalized()
	var right := up.cross(n).normalized()
	var u := h / 7.0
	var x := -text_width(s, h) * 0.5
	var b := md.b(key)
	var n0 := b.cols.size()
	for ch in s:
		if ch == " ": x += 3.0 * u; continue
		var g: Array = FONT.get(ch, FONT["."])
		for r in 7:
			var row: String = g[r]
			var c := 0
			while c < 5:
				if row[c] == "X":
					var c1 := c
					while c1 + 1 < 5 and row[c1 + 1] == "X": c1 += 1
					var y0 := h - (r + 1) * u
					var p0 := anchor + n * off + right * (x + c * u) + up * y0
					var p1 := p0 + right * ((c1 - c + 1) * u)
					b.quad(p0, p1, p1 + up * u, p0 + up * u, col, n)
					c = c1 + 1
				else:
					c += 1
		x += 6.0 * u
	_fix_alpha(b, n0, key, 1.0)

## A slab seen side-on: the polygon is in (z, y) and stands at x = x_out with the given thickness, facing sign (+1 or -1).
static func slab_zy(md: Model, key: String, poly: PackedVector2Array, x_out: float, thick: float, sign: float, col: Color, vary := 0.0) -> void:
	var b := md.b(key)
	var n0 := b.cols.size()
	var idx := Geometry2D.triangulate_polygon(poly)
	var xin := x_out - sign * thick
	for k in range(0, idx.size(), 3):
		var pa := poly[idx[k]]; var pb := poly[idx[k + 1]]; var pc := poly[idx[k + 2]]
		var c := vc(col, (pa.x + pb.x + pc.x) * 3.1 + (pa.y + pb.y + pc.y) * 5.3, vary) if vary > 0.0 else col
		b.tri(Vector3(x_out, pa.y, pa.x), Vector3(x_out, pb.y, pb.x), Vector3(x_out, pc.y, pc.x), c, Vector3(sign, 0, 0))
		b.tri(Vector3(xin, pa.y, pa.x), Vector3(xin, pb.y, pb.x), Vector3(xin, pc.y, pc.x), c, Vector3(-sign, 0, 0))
	var m := poly.size()
	var cw := Geometry2D.is_polygon_clockwise(poly)
	for k in m:
		var p := poly[k]; var q := poly[(k + 1) % m]
		var e := q - p
		if e.length() < 1e-6: continue
		var nz := Vector2(e.y, -e.x).normalized()
		if cw: nz = -nz
		var nn := Vector3(0, nz.y, nz.x)
		b.quad(Vector3(x_out, p.y, p.x), Vector3(x_out, q.y, q.x), Vector3(xin, q.y, q.x), Vector3(xin, p.y, p.x), col, nn)
	_fix_alpha(b, n0, key, 1.0)

## A smooth surface from a grid of rows of points (DroneParts.grid), one colour, optionally flipped to face the other way.
static func gridsurf(md: Model, key: String, rows: Array, col: Color, hint: Callable, vary := 0.0) -> void:
	put(md, key, DroneParts.grid(rows, false, false, hint), Transform3D.IDENTITY, col, vary)
