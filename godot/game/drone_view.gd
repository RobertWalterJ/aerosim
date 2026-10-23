class_name DroneView
extends Node3D
## The visible drone, drawn by code to match the airframe: each of the five is modelled on a kind of real drone
## (a folding camera Mini, a 5-inch freestyle quad, a race quad, a ducted cinewhoop, a large cinema drone).
## Body frame: +x right, +y up, forward is -z, the origin is the centre of mass. armD and R set the size.
## Static parts are merged into one mesh per material, so a drone costs only a handful of draw calls.

var _props: Array[Node3D] = []
var _discs: Array[MeshInstance3D] = []
var _gimbal: Node3D
var _af: Dictionary
var _omega_max := 1.0
var _fpv := false
var _phase := PackedFloat64Array([0.0, 1.1, 2.3, 3.7])
var _last_t := 0.0

# Each airframe is modelled once and kept: its meshes, where its props and lights go, and the outlines of every part
# (for the technical drawing in the drone chooser). Building the same drone again only places nodes.
static var _cache := {}

const DUCT_GAP := 0.0025          # cinewhoop: clearance from prop tip to duct wall, m
const DUCT_WALL := 0.0086         # cinewhoop: duct wall and lip, m

var _kit: DroneParts.Kit
var _gkit: DroneParts.Kit
var _m := {}

## How far the widest part round each motor reaches from the motor (the prop, or the duct round it), m.
static func reach(af: Dictionary) -> float:
	return float(af["R"]) + (DUCT_GAP + DUCT_WALL if af["id"] == "cinewhoop" else 0.0)

## The finished model data for an airframe (made on first use).
static func model(af: Dictionary) -> Dictionary:
	var id: String = af["id"]
	if not _cache.has(id):
		var v := DroneView.new()
		_cache[id] = v._make(af)
		v.free()
	return _cache[id]

func build(af: Dictionary, _record := false) -> void:
	for c in get_children(): c.queue_free()
	_props.clear(); _discs.clear()
	_af = af
	_omega_max = af["omegaMax"]
	var md := model(af)
	var body := MeshInstance3D.new(); body.mesh = md["body"]; add_child(body)
	_gimbal = Node3D.new()
	_gimbal.transform = md["gimbal_xf"]
	var gm := MeshInstance3D.new(); gm.mesh = md["gimbal"]; _gimbal.add_child(gm)
	add_child(_gimbal)
	var r: float = af["R"]
	var blades: int = af["nBlades"]
	var dshader: Shader = load("res://game/shaders/prop_blur.gdshader")
	for i in 4:
		var prop := Node3D.new(); prop.position = md["prop_pos"][i]
		prop.rotation.y = 0.5 + i * 1.3
		var pm := MeshInstance3D.new(); pm.mesh = md["prop_ccw"] if i % 2 == 1 else md["prop_cw"]
		prop.add_child(pm)
		add_child(prop); _props.append(prop)
		# the blur disc: what a camera records of a fast prop
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new(); dm.top_radius = r; dm.bottom_radius = r; dm.height = 0.001; dm.radial_segments = 32
		var dmat := ShaderMaterial.new()
		dmat.shader = dshader
		dmat.set_shader_parameter("radius", r); dmat.set_shader_parameter("n_blades", float(blades))
		dmat.set_shader_parameter("chord", md["chord"])
		dmat.set_shader_parameter("body_col", md["blur_body"]); dmat.set_shader_parameter("tip_col", md["blur_tip"])
		disc.mesh = dm; disc.material_override = dmat; disc.position = (md["prop_pos"][i] as Vector3) + Vector3(0, 0.001, 0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; disc.visible = false
		add_child(disc); _discs.append(disc)
		# navigation lights: green front right, red front left, white behind
		var led := MeshInstance3D.new(); var lsm := SphereMesh.new()
		var lr := 0.0032 * clampf(float(af["armD"]) / 0.0795, 0.8, 1.5)
		lsm.radius = lr; lsm.height = lr * 2.0; lsm.radial_segments = 10; lsm.rings = 6
		var lc := Color(0.2, 1.0, 0.3) if i == 0 else (Color(1.0, 0.15, 0.1) if i == 3 else Color(1.0, 1.0, 1.0))
		var lm := StandardMaterial3D.new(); lm.albedo_color = lc; lm.emission_enabled = true; lm.emission = lc; lm.emission_energy_multiplier = 3.0
		led.mesh = lsm; led.material_override = lm; led.position = md["led"][i]
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(led)
	set_fpv(_fpv)

## Model the airframe: everything that does not change from one build to the next.
func _make(af: Dictionary) -> Dictionary:
	var id: String = af["id"]
	_kit = DroneParts.Kit.new(); _kit.record = true
	_gkit = DroneParts.Kit.new(); _gkit.record = true
	_make_materials(id)
	var design: Dictionary
	match id:
		"freestyle": design = _freestyle(af)
		"race": design = _race(af)
		"cinewhoop": design = _cinewhoop(af)
		"cinema": design = _cinema(af)
		_: design = _mini(af)
	var out := _prop_data(af, design)
	out["body"] = _kit.commit()
	out["gimbal"] = _gkit.commit()
	var co: Vector3 = af["camOffset"]
	var gxf := Transform3D(Basis(Vector3.RIGHT, 0.0 if af["hasGimbal"] else float(af["camTilt"])), co + Vector3(0, 0.005, 0))
	out["gimbal_xf"] = gxf
	# the outlines for the drawing, the gimbal's carried into the body frame
	var plan: Array = _kit.plan.duplicate()
	var side: Array = _kit.side.duplicate()
	for s in _gkit.plan:
		var s2: Dictionary = s.duplicate()
		if s2.has("pts"):
			var pts := PackedVector2Array()
			for q in s2["pts"]:
				var w := gxf * Vector3(q.x, 0.0, q.y)
				pts.append(Vector2(w.x, w.z))
			s2["pts"] = pts
		s2["key"] = float(s2["key"]) + gxf.origin.y
		plan.append(s2)
	for s in _gkit.side:
		var pts2 := PackedVector2Array()
		for q in s["pts"]:
			var w2 := gxf * Vector3(0.0, q.y, q.x)
			pts2.append(Vector2(w2.z, w2.y))
		side.append({"pts": pts2, "key": s["key"]})
	out["plan"] = plan; out["side"] = side
	_kit = null; _gkit = null; _m = {}
	return out

## Through the drone's own camera: the camera pod would fill the picture, so it is hidden, and fast props show as a blur.
func set_fpv(on: bool) -> void:
	_fpv = on
	if _gimbal: _gimbal.visible = not on

func update_props(motor_omega: PackedFloat64Array, t: float, armed: bool) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for i in _props.size():
		var w := motor_omega[13 + i]
		var spin := 1.0 if i % 2 == 1 else -1.0
		var blur: bool = armed and w > 45.0       # above about 7 turns a second the blades are only ever seen smeared
		_props[i].visible = not blur
		_discs[i].visible = blur
		if not blur:
			if armed: _props[i].rotation.y = fmod(t * w * 0.05 * spin, TAU)
			continue
		_phase[i] = fmod(_phase[i] + spin * w * dt, TAU)
		var m := _discs[i].material_override as ShaderMaterial
		m.set_shader_parameter("phase", _phase[i])
		m.set_shader_parameter("omega", spin * w)

# ------------------------------------------------------------------ materials
func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

static var _wear: ImageTexture

## Roughness wear map: 0.8 almost everywhere (so the material keeps its own roughness), with faint mottling, fine
## straight scratches and a few scuffs that are rougher, so they catch the light as dull lines on glossy parts.
static func _wear_tex() -> ImageTexture:
	if _wear != null: return _wear
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new(); rng.seed = 515
	var fn := FastNoiseLite.new(); fn.frequency = 0.035; fn.seed = 3
	for y in n:
		for x in n:
			img.set_pixel(x, y, Color(0.8 + 0.05 * fn.get_noise_2d(x, y), 0, 0))
	for s in 70:
		var p := Vector2(rng.randf() * n, rng.randf() * n)
		var a := rng.randf() * TAU if s % 3 != 0 else rng.randf_range(-0.3, 0.3)     # many run roughly the same way, as wiping does
		var L := rng.randf_range(8.0, 60.0)
		var v := rng.randf_range(0.9, 1.0)
		for t in int(L):
			var q := p + Vector2(cos(a), sin(a)) * t
			img.set_pixel(posmod(int(q.x), n), posmod(int(q.y), n), Color(v, 0, 0))
	for s in 12:
		var c := Vector2(rng.randf() * n, rng.randf() * n)
		var r := rng.randf_range(2.0, 6.0)
		for y in range(int(c.y - r), int(c.y + r) + 1):
			for x in range(int(c.x - r), int(c.x + r) + 1):
				if Vector2(x, y).distance_to(c) < r and rng.randf() < 0.6: img.set_pixel(posmod(x, n), posmod(y, n), Color(0.95, 0, 0))
	img.generate_mipmaps()
	_wear = ImageTexture.create_from_image(img)
	return _wear

func _make_materials(id: String) -> void:
	var accent_col: Color = {"freestyle": Color(1.0, 0.42, 0.08), "race": Color(0.25, 0.95, 0.45), "cinewhoop": Color(0.2, 0.6, 1.0),
		"mini": Color(0.55, 0.57, 0.6), "cinema": Color(0.9, 0.22, 0.16)}.get(id, Color(1.0, 0.5, 0.1))
	_m = {
		"carbon": _mat(Color(0.05, 0.053, 0.06), 0.32, 0.35),
		"carbon_edge": _mat(Color(0.12, 0.125, 0.135), 0.55, 0.1),
		"metal": _mat(Color(0.62, 0.64, 0.68), 0.28, 0.9),
		"dark_metal": _mat(Color(0.16, 0.17, 0.19), 0.35, 0.8),
		"accent": _mat(accent_col, 0.38, 0.35),
		"tpu": _mat(accent_col.darkened(0.1), 0.75, 0.0),
		"rubber": _mat(Color(0.06, 0.06, 0.065), 0.85, 0.0),
		"plastic": _mat(Color(0.09, 0.095, 0.105), 0.55, 0.0),
		"shell": _mat(Color(0.86, 0.87, 0.88) if id == "mini" else Color(0.78, 0.79, 0.8), 0.32, 0.0),
		"shell_dark": _mat(Color(0.2, 0.21, 0.23), 0.4, 0.05),
		"glass": _mat(Color(0.02, 0.03, 0.06), 0.05, 0.9),
		"pcb": _mat(Color(0.05, 0.12, 0.08), 0.5, 0.2),
		"battery": _mat(Color(0.11, 0.115, 0.13), 0.45, 0.05),
		"label": _mat(Color(0.3, 0.32, 0.36), 0.5, 0.0),
		"yellow": _mat(Color(0.95, 0.75, 0.1), 0.5, 0.0),
		"red": _mat(Color(0.75, 0.08, 0.06), 0.5, 0.0),
		"black": _mat(Color(0.03, 0.03, 0.035), 0.5, 0.0),
		"accent_col": accent_col,
	}
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true; bm.vertex_color_is_srgb = true; bm.roughness = 0.38; bm.metallic = 0.05
	_m["blade"] = bm
	_m["gold"] = _mat(Color(0.83, 0.66, 0.32), 0.3, 0.95)
	var dm := StandardMaterial3D.new()        # stickers and printed marks, coloured per vertex
	dm.vertex_color_use_as_albedo = true; dm.vertex_color_is_srgb = true; dm.roughness = 0.55
	_m["decal"] = dm
	# light wear: fine scratches and scuffs vary the roughness, projected from three sides (the parts have no UVs)
	for key in ["carbon", "carbon_edge", "metal", "dark_metal", "shell", "shell_dark", "plastic", "battery", "accent", "black"]:
		var sm: StandardMaterial3D = _m[key]
		sm.roughness_texture = _wear_tex()
		sm.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		sm.uv1_triplanar = true
		sm.uv1_world_triplanar = false
		sm.uv1_scale = Vector3(14.0, 14.0, 14.0)
		sm.roughness = minf(1.0, sm.roughness * 1.25)

func _xf(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)

# ------------------------------------------------------------------ small details: screws, bolts, cables, labels, fittings
# All go into the body kit with outline "none", so the chooser drawings are unchanged, and they reuse the drone's own
# materials (one extra surface at most: the vertex-coloured "decal" material for stickers and printed marks).

## A frame turned so its +y points along `up`.
func _orient(p: Vector3, up: Vector3) -> Transform3D:
	var y := up.normalized()
	if y.dot(Vector3.UP) > 0.9999: return Transform3D(Basis.IDENTITY, p)
	if y.dot(Vector3.UP) < -0.9999: return Transform3D(Basis(Vector3.RIGHT, PI), p)
	return Transform3D(Basis(Quaternion(Vector3.UP, y)), p)

## A button-head screw (or a hex bolt head when hex is true) standing on a surface with normal `up`.
func _screw(p: Vector3, r := 0.0014, up := Vector3.UP, mat_key := "dark_metal", hex := false) -> void:
	var prof := DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r, r * 0.4), Vector2(r * 0.75, r * 0.72), Vector2(0, r * 0.72)])) if not hex \
		else DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r, r * 0.7), Vector2(0, r * 0.7)]))
	_kit.add(_m[mat_key], DroneParts.lathe(prof, 6 if hex else 8), _orient(p, up), Color.WHITE, "none")

## A cable from a to b that sags a little in the middle (motor leads, camera and antenna leads).
func _cable(a: Vector3, b: Vector3, r: float, sag: float, mat_key := "black") -> void:
	var m := (a + b) * 0.5 + Vector3(0, -sag, 0)
	_kit.add(_m[mat_key], DroneParts.tube(a, m, r, r, 6), Transform3D.IDENTITY, Color.WHITE, "none")
	_kit.add(_m[mat_key], DroneParts.tube(m, b, r, r, 6), Transform3D.IDENTITY, Color.WHITE, "none")

## A flat rectangle (w along the frame's x, l along its z) lying on a surface: stickers and printed marks.
func _rect(xf: Transform3D, w: float, l: float, col: Color) -> void:
	var a := Vector3(-w * 0.5, 0, -l * 0.5); var b := Vector3(w * 0.5, 0, -l * 0.5)
	var c := Vector3(w * 0.5, 0, l * 0.5); var d := Vector3(-w * 0.5, 0, l * 0.5)
	var pos := PackedVector3Array([a, c, b, a, d, c])
	var nrm := PackedVector3Array(); nrm.resize(6); nrm.fill(Vector3.UP)
	var cols := PackedColorArray(); cols.resize(6); cols.fill(col)
	_kit.add(_m["decal"], [pos, nrm, cols], xf, col, "none")

## A plain sticker: a pale label with lines of tiny dark "print" and a short bar-code, no words and no brand marks.
func _sticker(xf: Transform3D, w: float, l: float, bg := Color(0.86, 0.86, 0.84), ink := Color(0.08, 0.08, 0.09)) -> void:
	_rect(xf, w, l, bg)
	var lift := Transform3D(Basis.IDENTITY, Vector3(0, 0.00012, 0))
	var rows := 3
	for i in rows:
		var lw := w * (0.75 - 0.18 * i)
		_rect(xf * lift * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + 0.08 * w + lw * 0.5, 0, -l * 0.5 + l * (0.18 + 0.16 * i))), lw, l * 0.07, ink)
	var bars := 9
	for j in bars:
		var bw := w * (0.012 if j % 3 == 0 else 0.022)
		_rect(xf * lift * Transform3D(Basis.IDENTITY, Vector3(-w * 0.38 + w * 0.085 * j, 0, l * 0.3)), bw, l * 0.26, ink)

## Motor leads along the top of an arm: from the motor's foot back towards the body.
func _motor_leads(p: Vector3, y: float, motor_r: float, inner: float) -> void:
	var dir := Vector3(p.x, 0, p.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var start := Vector3(p.x, y, p.z) - dir * (motor_r * 1.05)
	var end := Vector3(dir.x * inner, y, dir.z * inner)
	for s in [-1.0, 0.0, 1.0]:
		_cable(start + side * (0.0016 * s), end + side * (0.0016 * s), 0.0007, 0.0004, "black")
	_kit.add(_m["black"], DroneParts.tube(start.lerp(end, 0.35), start.lerp(end, 0.55), 0.0027, 0.0027, 8), _xf(Vector3(0, 0.0005, 0)), Color.WHITE, "none")   # heat-shrink sleeve

## Two arm bolts where an arm leaves the body, and screws on the motor mount round the motor.
func _arm_bolts(p: Vector3, y: float, near: float, motor_r: float) -> void:
	var dir := Vector3(p.x, 0, p.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	for s in [-1.0, 1.0]:
		_screw(Vector3(dir.x * near, y, dir.z * near) + side * (0.0045 * s), 0.0019, Vector3.UP, "metal", true)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var q := Vector3(p.x, y, p.z) + (dir * cos(a) + side * sin(a)) * (motor_r * 1.18)
		_screw(q, 0.0011, Vector3.UP, "dark_metal")

## The coaxial fitting at the foot of an antenna: a gold hex nut and a short black sleeve.
func _sma(p: Vector3, axis: Vector3) -> void:
	var xf := _orient(p, axis)
	_kit.add(_m["gold"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0034, 0), Vector2(0.0034, 0.0035), Vector2(0, 0.0035)])), 6), xf, Color.WHITE, "none")
	_kit.add(_m["gold"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0.0035), Vector2(0.0022, 0.0035), Vector2(0.0022, 0.007), Vector2(0, 0.007)])), 10), xf, Color.WHITE, "none")

## A motor sitting on `base` (the top of its mount): a stator base, the bell with a coloured band, a shaft.
## Returns the height of the top of the bell.
func _motor(kit: DroneParts.Kit, base: Vector3, r: float, h: float, bell: Material, band: Material) -> float:
	var hb := h * 0.16
	kit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.9, 0), Vector2(r * 0.9, hb), Vector2(0, hb)])), 20), _xf(base))
	var bp := PackedVector2Array([Vector2(r * 0.96, hb), Vector2(r, hb + h * 0.06), Vector2(r, h * 0.84), Vector2(r * 0.9, h * 0.97), Vector2(r * 0.55, h), Vector2(r * 0.18, h), Vector2(r * 0.18, h * 1.1), Vector2(0, h * 1.1)])
	kit.add(bell, DroneParts.lathe(DroneParts.crisp(bp), 24), _xf(base))
	kit.add(band, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(r * 0.99, h * 0.5), Vector2(r * 1.012, h * 0.5), Vector2(r * 1.012, h * 0.66), Vector2(r * 0.99, h * 0.66)])), 24), _xf(base), Color.WHITE, "none")
	return base.y + h

## A carbon frame cut as one piece: a centre plate and four arms ending in motor pads.
func _unibody(centre: PackedVector2Array, positions: Array[Vector3], w0: float, w1: float, pad_r: float, y0: float, y1: float, pad_sides := 18) -> void:
	var shape := centre
	for p in positions:
		var arm := DroneParts.arm_outline(Vector2.ZERO, Vector2(p.x, p.z), w0, w1, pad_r, pad_sides)
		var merged := Geometry2D.merge_polygons(shape, arm)
		for poly in merged:
			if not Geometry2D.is_polygon_clockwise(poly) or merged.size() == 1:
				shape = poly; break
	_kit.add(_m["carbon"], DroneParts.extrude(shape, y0, y1), Transform3D.IDENTITY, Color.WHITE, "hull", shape)

## A flat carbon plate standing on its edge (camera side plates): the outline is given as (height, z).
func _side_plate(outline: PackedVector2Array, x: float, thick: float) -> void:
	var poly := PackedVector2Array()
	for q in outline: poly.append(Vector2(-q.x, q.y))
	var xf := Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3(x - thick * 0.5, 0, 0))
	_kit.add(_m["carbon"], DroneParts.extrude(poly, 0.0, thick), xf)

func _motor_positions(af: Dictionary) -> Array[Vector3]:
	var d: float = af["armD"]
	return [Vector3(d, 0, -d), Vector3(d, 0, d), Vector3(-d, 0, d), Vector3(-d, 0, -d)]

## An FPV camera: a square body with a lens barrel looking along -z (built into the gimbal node).
func _fpv_cam(size: float, lens_col: Material) -> void:
	_gkit.add(_m["black"], DroneParts.rbox(Vector3(size, size, size * 0.9)), _xf(Vector3.ZERO))
	var lr := size * 0.34
	var barrel := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(lr, 0), Vector2(lr, size * 0.45), Vector2(lr * 0.8, size * 0.5), Vector2(0, size * 0.5)])), 20)
	_gkit.add(lens_col, barrel, _xf(Vector3(0, 0, -size * 0.42), Vector3(-PI * 0.5, 0, 0)))
	_gkit.add(_m["glass"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.0015), Vector2(lr * 0.62, 0.0)]), 16), _xf(Vector3(0, 0, -size * 0.92), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")

## A battery: a rounded pack, a printed wrap, a strap or two, and the power lead at the back.
func _battery(c: Vector3, size: Vector3, straps: Array, strap_mat: Material, lead := true) -> void:
	_kit.add(_m["battery"], DroneParts.rbox(size, 7.0), _xf(c))
	_kit.add(_m["label"], DroneParts.rbox(Vector3(size.x * 1.015, size.y * 1.015, size.z * 0.42), 9.0), _xf(c + Vector3(0, 0, -size.z * 0.05)), Color.WHITE, "none")
	for sz in straps:
		_kit.add(strap_mat, DroneParts.rbox(Vector3(size.x * 1.04, size.y * 1.05, 0.011), 9.0), _xf(c + Vector3(0, -size.y * 0.02, float(sz))), Color.WHITE, "none")
		# the strap's metal buckle on top
		_kit.add(_m["dark_metal"], DroneParts.rbox(Vector3(0.009, 0.0022, 0.0135), 6.0, 8), _xf(c + Vector3(size.x * 0.18, size.y * 0.5 + 0.0016, float(sz))), Color.WHITE, "none")
	# a black grip pad under the pack, and a plain cell label on its side
	_kit.add(_m["rubber"], DroneParts.rbox(Vector3(size.x * 0.9, 0.0016, size.z * 0.8), 8.0, 8), _xf(c + Vector3(0, -size.y * 0.5 - 0.0008, 0)), Color.WHITE, "none")
	_sticker(Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)).orthonormalized(), c + Vector3(size.x * 0.5 + 0.0004, size.y * 0.05, size.z * 0.12)), size.z * 0.42, size.y * 0.6)
	if lead:
		var back := c + Vector3(0, -size.y * 0.25, size.z * 0.5)
		_kit.add(_m["red"], DroneParts.tube(back + Vector3(0.004, 0, -0.002), back + Vector3(0.006, 0.004, 0.014), 0.0016, 0.0016, 8), Transform3D.IDENTITY, Color.WHITE, "none")
		_kit.add(_m["black"], DroneParts.tube(back + Vector3(-0.004, 0, -0.002), back + Vector3(-0.006, 0.004, 0.014), 0.0016, 0.0016, 8), Transform3D.IDENTITY, Color.WHITE, "none")
		_kit.add(_m["yellow"], DroneParts.rbox(Vector3(0.016, 0.008, 0.011), 8.0), _xf(back + Vector3(0, 0.005, 0.02)), Color.WHITE, "none")

# ------------------------------------------------------------------ 5-inch freestyle
func _freestyle(af: Dictionary) -> Dictionary:
	var pos := _motor_positions(af)
	var ya := -0.013; var yb := -0.008                     # the arms: 5 mm carbon
	var centre := PackedVector2Array([Vector2(-0.014, -0.064), Vector2(0.014, -0.064), Vector2(0.021, -0.05), Vector2(0.021, 0.046), Vector2(0.013, 0.058), Vector2(-0.013, 0.058), Vector2(-0.021, 0.046), Vector2(-0.021, -0.05)])
	_unibody(centre, pos, 0.018, 0.0145, 0.0148, ya, yb)
	# top plate on aluminium standoffs, the flight controller stack between
	var top := PackedVector2Array([Vector2(-0.011, -0.064), Vector2(0.011, -0.064), Vector2(0.019, -0.047), Vector2(0.019, 0.042), Vector2(0.012, 0.055), Vector2(-0.012, 0.055), Vector2(-0.019, 0.042), Vector2(-0.019, -0.047)])
	_kit.add(_m["carbon"], DroneParts.extrude(top, 0.026, 0.028), Transform3D.IDENTITY, Color.WHITE, "hull", top)
	for sx in [-1.0, 1.0]:
		for sz in [-0.042, 0.04]:
			_kit.add(_m["accent"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, yb), Vector2(0.0026, yb), Vector2(0.0026, 0.026), Vector2(0, 0.026)])), 6), _xf(Vector3(sx * 0.0165, 0, sz)), Color.WHITE, "side")
	_kit.add(_m["pcb"], DroneParts.rbox(Vector3(0.036, 0.0035, 0.036), 10.0), _xf(Vector3(0, -0.003, 0.004)), Color.WHITE, "side")
	_kit.add(_m["pcb"], DroneParts.rbox(Vector3(0.032, 0.0035, 0.032), 10.0), _xf(Vector3(0, 0.006, 0.004)), Color.WHITE, "side")
	_kit.add(_m["black"], DroneParts.tube(Vector3(-0.012, 0.0, 0.05), Vector3(0.012, 0.0, 0.05), 0.005, 0.005, 12), Transform3D.IDENTITY, Color.WHITE, "side")
	# camera cage side plates, the FPV camera between them
	for sx in [-1.0, 1.0]:
		_side_plate(PackedVector2Array([Vector2(yb, -0.06), Vector2(yb, -0.04), Vector2(0.026, -0.04), Vector2(0.026, -0.062), Vector2(0.012, -0.071)]), sx * 0.0128, 0.002)
	_fpv_cam(0.019, _m["dark_metal"])
	# a strapped 4S pack on top, an HD action camera in a printed mount in front of it
	_battery(Vector3(0, 0.0445, 0.007), Vector3(0.035, 0.033, 0.074), [-0.016, 0.026], _m["accent"])
	_kit.add(_m["tpu"], DroneParts.rbox(Vector3(0.03, 0.007, 0.024), 5.0), _xf(Vector3(0, 0.0315, -0.049)))
	var hd := _xf(Vector3(0, 0.046, -0.05), Vector3(deg_to_rad(15.0), 0, 0))
	_kit.add(_m["plastic"], DroneParts.rbox(Vector3(0.04, 0.026, 0.022), 6.0), hd)
	_kit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0075, 0), Vector2(0.0075, 0.005), Vector2(0, 0.005)])), 18), hd * _xf(Vector3(-0.007, 0.0, -0.011), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	_kit.add(_m["glass"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.001), Vector2(0.0055, 0.0)]), 16), hd * _xf(Vector3(-0.007, 0.0, -0.0162), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	# video antenna on a printed mount at the back, receiver whiskers either side
	_kit.add(_m["tpu"], DroneParts.rbox(Vector3(0.016, 0.01, 0.012), 5.0), _xf(Vector3(0, 0.032, 0.052)))
	_kit.add(_m["black"], DroneParts.tube(Vector3(0, 0.034, 0.054), Vector3(0, 0.066, 0.084), 0.0022, 0.0018, 10))
	_kit.add(_m["black"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.0022), Vector2(0.0085, -0.0022), Vector2(0.0085, 0.0022), Vector2(0, 0.0022)])), 18), _xf(Vector3(0, 0.07, 0.088), Vector3(-PI * 0.25, 0, 0)))
	for sx in [-1.0, 1.0]:
		_kit.add(_m["black"], DroneParts.tube(Vector3(sx * 0.01, 0.027, 0.05), Vector3(sx * 0.03, 0.036, 0.085), 0.0011, 0.0009, 6), Transform3D.IDENTITY, Color.WHITE, "none")
	# motors, and printed landing pads under the motor mounts
	var top_y := 0.0
	for p in pos:
		top_y = _motor(_kit, p + Vector3(0, yb, 0), 0.0142, 0.0185, _m["metal"], _m["accent"])
		_kit.add(_m["rubber"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.03), Vector2(0.0052, -0.03), Vector2(0.0058, -0.0285), Vector2(0.0068, ya), Vector2(0, ya)])), 14), _xf(p))
	# small details: arm bolts, motor screws and leads, top-plate screws, the antenna's fitting and a frame sticker
	for p in pos:
		_arm_bolts(p, yb, 0.034, 0.0142)
		_motor_leads(p, yb + 0.0008, 0.0142, 0.03)
	for sx in [-1.0, 1.0]:
		for sz in [-0.042, 0.04]:
			_screw(Vector3(sx * 0.0165, 0.028, sz), 0.0018, Vector3.UP, "dark_metal", true)
	_sma(Vector3(0, 0.034, 0.054), Vector3(0, 0.032, 0.03))
	for sx in [-1.0, 1.0]:
		_kit.add(_m["tpu"], DroneParts.tube(Vector3(sx * 0.0285, 0.0353, 0.081), Vector3(sx * 0.0302, 0.0362, 0.0855), 0.0014, 0.0014, 6), Transform3D.IDENTITY, Color.WHITE, "none")   # receiver aerial tips
	_cable(Vector3(0.006, 0.0, 0.02), Vector3(0.004, 0.025, 0.05), 0.0011, 0.002, "black")         # video lead up to the transmitter
	_sticker(_xf(Vector3(0.0, 0.0281, 0.012)), 0.014, 0.024, Color(0.82, 0.82, 0.8))
	return {
		"yp": top_y + 0.0038, "led": func(p: Vector3) -> Vector3: return p + Vector3(0, yb - 0.003, 0) + Vector3(signf(p.x), 0, signf(p.z)) * 0.0118,
		"spec": {"R": af["R"], "n": af["nBlades"], "root": 0.0045, "c_root": 0.15, "c_max": 0.245, "t_max": 0.42, "c_tip": 0.15, "sweep": 0.06, "pd": 0.8, "tc": 0.15,
			"col": Color(0.95, 0.42, 0.1), "tip_col": Color(0.98, 0.62, 0.3)},
		"hub": {"r": 0.0066, "h": 0.0074, "cap_r": 0.0046, "cap_h": 0.006, "hex": true, "cap_col": Color(0.12, 0.12, 0.13)},
	}

# ------------------------------------------------------------------ race quad: thin, narrow, low and angular
func _race(af: Dictionary) -> Dictionary:
	var pos := _motor_positions(af)
	var ya := -0.012; var yb := -0.008
	var centre := PackedVector2Array([Vector2(0.0, -0.066), Vector2(0.015, -0.05), Vector2(0.015, 0.044), Vector2(0.0, 0.058), Vector2(-0.015, 0.044), Vector2(-0.015, -0.05)])
	_unibody(centre, pos, 0.0145, 0.0112, 0.0138, ya, yb, 6)
	var top := PackedVector2Array([Vector2(0.0, -0.05), Vector2(0.0125, -0.038), Vector2(0.0125, 0.04), Vector2(0.0, 0.052), Vector2(-0.0125, 0.04), Vector2(-0.0125, -0.038)])
	_kit.add(_m["carbon"], DroneParts.extrude(top, 0.0225, 0.024), Transform3D.IDENTITY, Color.WHITE, "hull", top)
	for sx in [-1.0, 1.0]:
		for sz in [-0.03, 0.032]:
			_kit.add(_m["metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, yb), Vector2(0.0022, yb), Vector2(0.0022, 0.0225), Vector2(0, 0.0225)])), 6), _xf(Vector3(sx * 0.011, 0, sz)), Color.WHITE, "side")
	_kit.add(_m["pcb"], DroneParts.rbox(Vector3(0.026, 0.0035, 0.026), 10.0), _xf(Vector3(0, -0.002, 0.004)), Color.WHITE, "side")
	_kit.add(_m["pcb"], DroneParts.rbox(Vector3(0.024, 0.0035, 0.024), 10.0), _xf(Vector3(0, 0.006, 0.004)), Color.WHITE, "side")
	# a small aluminium camera bracket either side of a nano camera
	for sx in [-1.0, 1.0]:
		_side_plate(PackedVector2Array([Vector2(yb, -0.052), Vector2(yb, -0.04), Vector2(0.0225, -0.042), Vector2(0.0225, -0.05), Vector2(0.01, -0.064)]), sx * 0.0095, 0.0016)
	_fpv_cam(0.0145, _m["accent"])
	# a flat 6S pack, one strap, a short stubby antenna
	_battery(Vector3(0, 0.0368, 0.008), Vector3(0.033, 0.026, 0.07), [0.008], _m["accent"])
	_kit.add(_m["black"], DroneParts.tube(Vector3(0, 0.024, 0.05), Vector3(0, 0.046, 0.064), 0.0028, 0.0024, 10))
	_kit.add(_m["accent"], DroneParts.sphere(0.003, 10), _xf(Vector3(0, 0.0465, 0.0645)))
	var top_y := 0.0
	for p in pos:
		top_y = _motor(_kit, p + Vector3(0, yb, 0), 0.0145, 0.0175, _m["black"], _m["accent"])
		_kit.add(_m["rubber"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.03), Vector2(0.0048, -0.03), Vector2(0.006, ya), Vector2(0, ya)])), 12), _xf(p))
	for p in pos:
		_arm_bolts(p, yb, 0.03, 0.0145)
		_motor_leads(p, yb + 0.0008, 0.0145, 0.026)
	for sx in [-1.0, 1.0]:
		for sz in [-0.03, 0.032]:
			_screw(Vector3(sx * 0.011, 0.024, sz), 0.0016, Vector3.UP, "metal", true)
	_sma(Vector3(0, 0.024, 0.05), Vector3(0, 0.022, 0.014))
	_sticker(_xf(Vector3(0.0, 0.0242, -0.022)), 0.012, 0.02, Color(0.15, 0.16, 0.17), Color(0.75, 0.95, 0.8))
	return {
		"yp": top_y + 0.0036, "led": func(p: Vector3) -> Vector3: return p + Vector3(0, yb - 0.003, 0) + Vector3(signf(p.x), 0, signf(p.z)) * 0.011,
		"spec": {"R": af["R"], "n": af["nBlades"], "root": 0.0045, "c_root": 0.13, "c_max": 0.205, "t_max": 0.5, "c_tip": 0.12, "sweep": 0.09, "pd": 0.92, "tc": 0.13,
			"col": Color(0.3, 0.92, 0.45), "tip_col": Color(0.6, 1.0, 0.7)},
		"hub": {"r": 0.0062, "h": 0.007, "cap_r": 0.0044, "cap_h": 0.0055, "hex": true, "cap_col": Color(0.1, 0.1, 0.11)},
	}

# ------------------------------------------------------------------ cinewhoop: guarded 3-inch, an action camera on top
func _cinewhoop(af: Dictionary) -> Dictionary:
	var pos := _motor_positions(af)
	var r: float = af["R"]
	var ya := -0.03; var yb := -0.0275
	var centre := PackedVector2Array([Vector2(-0.016, -0.06), Vector2(0.016, -0.06), Vector2(0.019, -0.045), Vector2(0.019, 0.045), Vector2(0.014, 0.056), Vector2(-0.014, 0.056), Vector2(-0.019, 0.045), Vector2(-0.019, -0.045)])
	_unibody(centre, pos, 0.012, 0.01, 0.0105, ya, yb)
	# the ducts: a smooth ring around each prop with a rounded intake lip, joined to each other by bridges
	var ri := r + DUCT_GAP
	# a closed (radius, height) section; corners are repeated to keep them crisp, the intake lip stays smooth
	var duct := PackedVector2Array([Vector2(ri, -0.0295), Vector2(ri, -0.0295), Vector2(ri, -0.011), Vector2(ri + 0.0009, -0.0068), Vector2(ri + 0.003, -0.0042), Vector2(ri + 0.0062, -0.0032),
		Vector2(ri + 0.0082, -0.0042), Vector2(ri + 0.0086, -0.0065), Vector2(ri + 0.0058, -0.0295), Vector2(ri + 0.0058, -0.0295)])
	for p in pos:
		_kit.add(_m["plastic"], DroneParts.lathe(duct, 32, true), _xf(p + Vector3(0, 0, 0)), Color.WHITE, "ring")
		for sa in [2.0 * PI / 3.0, -2.0 * PI / 3.0]:
			var ang: float = atan2(-p.z, -p.x) + sa
			var dir := Vector3(cos(ang), 0, sin(ang))
			_kit.add(_m["plastic"], DroneParts.tube(p + dir * 0.008 + Vector3(0, -0.0285, 0), p + dir * (ri + 0.002) + Vector3(0, -0.0285, 0), 0.0016, 0.0016, 6), Transform3D.IDENTITY, Color.WHITE, "none")
	var d: float = af["armD"]
	for c in [Vector3(0, -0.016, -d), Vector3(0, -0.016, d), Vector3(d, -0.016, 0), Vector3(-d, -0.016, 0)]:
		var along_x: bool = absf(c.z) > 0.01
		var gap := 2.0 * d - 2.0 * (ri + 0.0086) + 0.006
		_kit.add(_m["plastic"], DroneParts.rbox(Vector3(gap if along_x else 0.012, 0.024, 0.012 if along_x else gap), 6.0), _xf(c), Color.WHITE, "hull")
	# stack, top plate, camera cage
	for sx in [-1.0, 1.0]:
		for sz in [-0.03, 0.03]:
			_kit.add(_m["metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, yb), Vector2(0.002, yb), Vector2(0.002, 0.0), Vector2(0, 0.0)])), 6), _xf(Vector3(sx * 0.0115, 0, sz)), Color.WHITE, "side")
	_kit.add(_m["pcb"], DroneParts.rbox(Vector3(0.026, 0.0035, 0.026), 10.0), _xf(Vector3(0, -0.016, 0.0)), Color.WHITE, "side")
	var top := PackedVector2Array([Vector2(-0.014, -0.046), Vector2(0.014, -0.046), Vector2(0.016, -0.036), Vector2(0.016, 0.045), Vector2(-0.016, 0.045), Vector2(-0.016, -0.036)])
	_kit.add(_m["carbon"], DroneParts.extrude(top, 0.0, 0.002), Transform3D.IDENTITY, Color.WHITE, "hull", top)
	for sx in [-1.0, 1.0]:
		_side_plate(PackedVector2Array([Vector2(yb, -0.06), Vector2(yb, -0.045), Vector2(0.002, -0.042), Vector2(0.012, -0.05), Vector2(0.012, -0.062), Vector2(-0.01, -0.07)]), sx * 0.0122, 0.002)
	_fpv_cam(0.019, _m["dark_metal"])
	# battery at the back, the action camera on a printed wedge at the front
	_battery(Vector3(0, 0.0132, 0.024), Vector3(0.03, 0.022, 0.054), [0.026], _m["accent"])
	_kit.add(_m["tpu"], DroneParts.rbox(Vector3(0.034, 0.007, 0.03), 5.0), _xf(Vector3(0, 0.0055, -0.029)))
	var ac := _xf(Vector3(0, 0.0285, -0.031), Vector3(deg_to_rad(8.0), 0, 0))
	_kit.add(_m["plastic"], DroneParts.rbox(Vector3(0.058, 0.04, 0.028), 7.0), ac)
	_kit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.02, 0.02, 0.006), 6.0), ac * _xf(Vector3(-0.014, 0.004, -0.0145)), Color.WHITE, "none")
	_kit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0072, 0), Vector2(0.0072, 0.004), Vector2(0, 0.004)])), 18), ac * _xf(Vector3(-0.014, 0.004, -0.017), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	_kit.add(_m["glass"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.001), Vector2(0.0052, 0.0)]), 16), ac * _xf(Vector3(-0.014, 0.004, -0.0212), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	_kit.add(_m["glass"], DroneParts.rbox(Vector3(0.018, 0.016, 0.002), 8.0), ac * _xf(Vector3(0.013, 0.003, -0.0142)), Color.WHITE, "none")
	_kit.add(_m["black"], DroneParts.tube(Vector3(0, 0.002, 0.045), Vector3(0, 0.024, 0.062), 0.0018, 0.0016, 8))
	var top_y := 0.0
	for p in pos:
		top_y = _motor(_kit, p + Vector3(0, yb, 0), 0.0098, 0.0118, _m["black"], _m["accent"])
		_motor_leads(p, yb + 0.0007, 0.0098, 0.022)
		for sa in [0.6, -0.6]:      # screws holding each duct to the frame
			var dd := Vector3(-p.x, 0, -p.z).normalized().rotated(Vector3.UP, float(sa))
			_screw(p + dd * 0.0125 + Vector3(0, yb, 0), 0.0012, Vector3.UP, "dark_metal")
	for sx in [-1.0, 1.0]:
		for sz in [-0.03, 0.03]:
			_screw(Vector3(sx * 0.0115, 0.002, sz), 0.0015, Vector3.UP, "dark_metal", true)
	_sma(Vector3(0, 0.002, 0.045), Vector3(0, 0.022, 0.017))
	_sticker(ac * Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), Vector3(0.0292, 0.0, 0.0)), 0.016, 0.012)     # the action camera's side label
	_cable(Vector3(-0.012, 0.004, -0.03), Vector3(-0.014, 0.012, -0.024), 0.0009, 0.001, "black")
	return {
		"yp": top_y + 0.003, "led": func(p: Vector3) -> Vector3: return p + Vector3(0, -0.018, 0) + Vector3(signf(p.x), 0, signf(p.z)).normalized() * (ri + 0.0072),
		"spec": {"R": r, "n": af["nBlades"], "root": 0.004, "c_root": 0.2, "c_max": 0.34, "t_max": 0.45, "c_tip": 0.27, "sweep": 0.05, "pd": 1.0, "tc": 0.14,
			"col": Color(0.62, 0.68, 0.74), "tip_col": Color(0.82, 0.86, 0.9)},
		"hub": {"r": 0.0052, "h": 0.0062, "cap_r": 0.0036, "cap_h": 0.0048, "hex": true, "cap_col": Color(0.2, 0.55, 0.95)},
		"duct": ri,
	}

# ------------------------------------------------------------------ Gimbal Mini: a smooth folding camera drone
func _mini(af: Dictionary) -> Dictionary:
	var pos := _motor_positions(af)
	var shell: Material = _m["shell"]
	var body := [[-0.069, 0.0, 0.012, 0.011, 0.006], [-0.064, 0.0, 0.010, 0.02, 0.013], [-0.052, 0.0, 0.006, 0.026, 0.021], [-0.032, 0.0, 0.004, 0.029, 0.024],
		[0.012, 0.0, 0.004, 0.029, 0.024], [0.042, 0.0, 0.005, 0.027, 0.022], [0.062, 0.0, 0.007, 0.022, 0.018], [0.073, 0.0, 0.009, 0.013, 0.011], [0.077, 0.0, 0.009, 0.005, 0.004]]
	_kit.add(shell, DroneParts.loft(body, 2.7, 28))
	# a dark face at the nose, a vent at the tail where the battery slides in
	var face := [[-0.0705, 0.0, 0.012, 0.0105, 0.0062], [-0.066, 0.0, 0.0105, 0.0185, 0.0125], [-0.058, 0.0, 0.0085, 0.0235, 0.0172]]
	for s in face: s[3] += 0.0007; s[4] += 0.0007
	_kit.add(_m["shell_dark"], DroneParts.loft(face, 2.7, 28, true), Transform3D.IDENTITY, Color.WHITE, "none")
	_kit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.026, 0.012, 0.006), 6.0), _xf(Vector3(0, 0.01, 0.073)), Color.WHITE, "none")
	# arms: the front pair fold out high from the shoulders, the back pair low from the hips (as a folding drone does)
	var yp := 0.0
	for i in 4:
		var p := pos[i]
		var front := p.z < 0.0
		var sx := signf(p.x)
		var root := Vector3(sx * 0.024, 0.017, -0.036) if front else Vector3(sx * 0.022, -0.012, 0.046)
		var pod_top := 0.018 if front else -0.011
		var pod_bot := -0.004 if front else -0.03
		var pod := Vector3(p.x, (pod_top + pod_bot) * 0.5, p.z)
		var axf := DroneParts.along(root, pod - Vector3(signf(p.x), 0, signf(p.z)).normalized() * 0.006)
		var L := root.distance_to(pod)
		_kit.add(shell, DroneParts.loft([[0.0, 0.0, 0.0, 0.0065, 0.0052], [L * 0.5, 0.0, 0.0, 0.0056, 0.0042], [L - 0.004, 0.0, 0.0, 0.0058, 0.0046], [L, 0.0, 0.0, 0.004, 0.0035]], 2.4, 16), axf)
		_kit.add(_m["shell_dark"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.0055), Vector2(0.0048, -0.0055), Vector2(0.0048, 0.0055), Vector2(0, 0.0055)])), 14), _xf(root), Color.WHITE, "none")
		var pod_prof := PackedVector2Array([Vector2(0, pod_bot), Vector2(0.0085, pod_bot), Vector2(0.0105, pod_bot + 0.004), Vector2(0.0108, pod_top - 0.002), Vector2(0.0098, pod_top), Vector2(0, pod_top)])
		_kit.add(shell, DroneParts.lathe(pod_prof, 22), _xf(Vector3(p.x, 0, p.z)))
		var top_y := _motor(_kit, Vector3(p.x, pod_top, p.z), 0.0094, 0.0062, _m["shell_dark"], _m["shell_dark"])
		if front:
			yp = top_y + 0.0028
			# a slim landing foot under each front motor
			_kit.add(shell, DroneParts.tube(Vector3(p.x, pod_bot + 0.002, p.z), Vector3(p.x * 1.03, -0.027, p.z * 1.03), 0.0042, 0.0028, 10))
			_kit.add(_m["rubber"], DroneParts.sphere(0.003, 10), _xf(Vector3(p.x * 1.03, -0.027, p.z * 1.03)))
	# small details: hinge pins at the arm roots, cooling vents on top, a status light strip, plain printed marks
	for i in 4:
		var p2 := pos[i]
		var front2 := p2.z < 0.0
		var root2 := Vector3(signf(p2.x) * 0.024, 0.017, -0.036) if front2 else Vector3(signf(p2.x) * 0.022, -0.012, 0.046)
		_screw(root2 + Vector3(0, 0.0055, 0), 0.0021, Vector3.UP, "metal")
	for k in 5:
		_kit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.014, 0.0012, 0.0016), 6.0, 6), _xf(Vector3(0, 0.0278, 0.026 + 0.0034 * k)), Color.WHITE, "none")
	_kit.add(_m["glass"], DroneParts.rbox(Vector3(0.012, 0.0022, 0.0012), 6.0, 6), _xf(Vector3(0, 0.0175, 0.0742)), Color.WHITE, "none")
	_rect(_xf(Vector3(-0.012, 0.02815, -0.012)), 0.006, 0.0012, Color(0.45, 0.46, 0.48))
	_rect(_xf(Vector3(-0.012, 0.02815, -0.0095)), 0.009, 0.0012, Color(0.45, 0.46, 0.48))
	_sticker(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.0202, 0.01)), 0.016, 0.022)       # a plain rating label underneath
	# the gimbal: a small camera head hung from the nose on a side arm, with its lens looking forward
	_gkit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.022, 0.019, 0.019), 5.0), _xf(Vector3(0, 0, 0.001)))
	_gkit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0078, 0), Vector2(0.0078, 0.003), Vector2(0.0066, 0.0038), Vector2(0, 0.0038)])), 20), _xf(Vector3(0, 0, -0.0085), Vector3(-PI * 0.5, 0, 0)))
	_gkit.add(_m["glass"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.0012), Vector2(0.0058, 0.0)]), 18), _xf(Vector3(0, 0, -0.0124), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	_gkit.add(shell, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0062, 0), Vector2(0.0062, 0.004), Vector2(0, 0.004)])), 16), _xf(Vector3(0.011, 0, 0.0), Vector3(0, 0, -PI * 0.5)))
	_gkit.add(shell, DroneParts.tube(Vector3(0.0135, 0.0, 0.002), Vector3(0.0105, 0.012, 0.011), 0.0028, 0.0026, 10), Transform3D.IDENTITY, Color.WHITE, "none")
	_gkit.add(shell, DroneParts.rbox(Vector3(0.026, 0.005, 0.014), 5.0), _xf(Vector3(0.0, 0.0135, 0.013)), Color.WHITE, "none")
	return {
		"yp": yp, "yp_rear": -0.011 + 0.0062 + 0.0028,
		"led": func(p: Vector3) -> Vector3: return Vector3(p.x, (-0.006 if p.z < 0.0 else -0.026), p.z) + Vector3(signf(p.x), 0, signf(p.z)).normalized() * 0.0098,
		"spec": {"R": af["R"], "n": af["nBlades"], "root": 0.006, "c_root": 0.15, "c_max": 0.215, "t_max": 0.3, "c_tip": 0.1, "sweep": 0.17, "pd": 0.55, "tc": 0.12,
			"col": Color(0.36, 0.375, 0.4), "tip_col": Color(0.36, 0.375, 0.4)},
		"hub": {"r": 0.0082, "h": 0.0045, "cap_r": 0.0052, "cap_h": 0.003, "cap_col": Color(0.85, 0.86, 0.87), "col": Color(0.3, 0.31, 0.33)},
	}

# ------------------------------------------------------------------ cinema drone: big body, raised arms, landing skids
func _cinema(af: Dictionary) -> Dictionary:
	var pos := _motor_positions(af)
	var shell: Material = _m["shell"]
	var body := [[-0.152, 0.0, 0.023, 0.007, 0.005], [-0.142, 0.0, 0.022, 0.024, 0.012], [-0.118, 0.0, 0.02, 0.036, 0.018], [-0.085, 0.0, 0.016, 0.046, 0.025],
		[-0.03, 0.0, 0.014, 0.05, 0.029], [0.06, 0.0, 0.014, 0.05, 0.029], [0.108, 0.0, 0.017, 0.042, 0.024], [0.138, 0.0, 0.02, 0.028, 0.016], [0.151, 0.0, 0.021, 0.012, 0.008]]
	_kit.add(shell, DroneParts.loft(body, 3.4, 32))
	# dark sensor visor on the nose, battery doors on the flanks, a satellite dome on top, a red line along the spine
	var visor := [[-0.1535, 0.0, 0.023, 0.0075, 0.0055], [-0.144, 0.0, 0.0222, 0.0245, 0.0125], [-0.13, 0.0, 0.021, 0.031, 0.0155]]
	for s in visor: s[3] += 0.0008; s[4] += 0.0008
	_kit.add(_m["shell_dark"], DroneParts.loft(visor, 3.4, 32, true), Transform3D.IDENTITY, Color.WHITE, "none")
	for sx in [-1.0, 1.0]:
		_kit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.004, 0.032, 0.11), 8.0), _xf(Vector3(sx * 0.0492, 0.012, 0.012)), Color.WHITE, "none")
	_kit.add(_m["shell_dark"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.007), Vector2(0.012, 0.0055), Vector2(0.02, 0.002), Vector2(0.022, 0.0)]), 24), _xf(Vector3(0, 0.0425, 0.07)))
	_kit.add(_m["accent"], DroneParts.rbox(Vector3(0.006, 0.0025, 0.1), 8.0), _xf(Vector3(0, 0.0432, -0.02)), Color.WHITE, "none")
	# arms: from each flank a thick tube rises to a shoulder, two arms run out to the motors, a leg drops to a skid
	var yp := 0.0
	for sx in [-1.0, 1.0]:
		var sh := Vector3(sx * 0.084, 0.034, 0.0)
		_kit.add(_m["carbon"], DroneParts.tube(Vector3(sx * 0.035, 0.018, 0.0), sh, 0.0105, 0.0095, 16))
		_kit.add(shell, DroneParts.sphere(0.0135, 18), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.35)), sh))
		var foot := Vector3(sx * 0.118, -0.025, 0.0)
		_kit.add(_m["carbon"], DroneParts.tube(sh, foot + Vector3(0, 0.004, 0), 0.0072, 0.0062, 14))
		_kit.add(_m["carbon"], DroneParts.tube(foot + Vector3(0, 0, -0.105), foot + Vector3(0, 0, 0.105), 0.0052, 0.0052, 12))
		for ez in [-0.105, 0.105]:
			_kit.add(_m["accent"], DroneParts.sphere(0.0058, 12), _xf(foot + Vector3(0, 0, ez)), Color.WHITE, "none")
		for sz in [-1.0, 1.0]:
			var mpos := Vector3(sx * float(af["armD"]), 0.0, sz * float(af["armD"]))
			_kit.add(_m["carbon"], DroneParts.tube(sh, Vector3(mpos.x, 0.036, mpos.z), 0.0082, 0.0072, 14))
	# tube clamps where each arm leaves the shoulder, a bolt on each
	for sx in [-1.0, 1.0]:
		var sh2 := Vector3(sx * 0.084, 0.034, 0.0)
		for sz in [-1.0, 1.0]:
			var mpos2 := Vector3(sx * float(af["armD"]), 0.036, sz * float(af["armD"]))
			var dir2 := (mpos2 - sh2).normalized()
			var cpos := sh2 + dir2 * 0.022
			_kit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0084, -0.005), Vector2(0.0098, -0.005), Vector2(0.0098, 0.005), Vector2(0.0084, 0.005)])), 16), _orient(cpos, dir2), Color.WHITE, "none")
			_screw(cpos + Vector3(0, 0.0098, 0), 0.0016, Vector3.UP, "metal", true)
		# a fin antenna on each rear leg, a plain service label on each battery door, a yellow and black lift mark
		var side_b := Basis(Vector3(0, 0, sx), Vector3(sx, 0, 0), Vector3(0, -1, 0)).orthonormalized()
		_kit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.003, 0.03, 0.014), 6.0, 8), _xf(Vector3(sx * 0.11, 0.0, 0.07), Vector3(0, 0, sx * 0.25)), Color.WHITE, "none")
		_sticker(Transform3D(side_b, Vector3(sx * 0.0513, 0.012, 0.04)), 0.026, 0.014, Color(0.78, 0.79, 0.8), Color(0.12, 0.12, 0.13))
		for k in 4:
			_rect(Transform3D(side_b, Vector3(sx * 0.0514, 0.022, -0.03 + 0.0032 * k)), 0.0016, 0.004, Color(0.95, 0.75, 0.1) if k % 2 == 0 else Color(0.05, 0.05, 0.05))
	for k in 4:
		_screw(Vector3((-1.0 if k < 2 else 1.0) * 0.03, 0.0428, (-1.0 if k % 2 == 0 else 1.0) * 0.045), 0.0017, Vector3.UP, "dark_metal")
	_cable(Vector3(0.01, 0.0, -0.11), Vector3(0.026, -0.012, -0.12), 0.0016, 0.002, "black")      # gimbal lead from the nose
	for p in pos:
		_kit.add(shell, DroneParts.lathe(PackedVector2Array([Vector2(0, 0.022), Vector2(0.008, 0.0225), Vector2(0.0145, 0.028), Vector2(0.0175, 0.036), Vector2(0.0178, 0.042), Vector2(0, 0.042)]), 24), _xf(Vector3(p.x, 0, p.z)))
		var top_y := _motor(_kit, Vector3(p.x, 0.042, p.z), 0.0172, 0.0155, _m["dark_metal"], _m["accent"])
		yp = top_y + 0.0042
	# the gimbal: a yaw motor under the nose, a yoke, and a cinema camera with a big lens
	var gy := 0.022
	_gkit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, gy), Vector2(0.016, gy), Vector2(0.016, gy + 0.008), Vector2(0, gy + 0.008)])), 22), _xf(Vector3.ZERO))
	_gkit.add(_m["shell_dark"], DroneParts.tube(Vector3(-0.004, gy - 0.001, 0.0), Vector3(0.027, gy - 0.004, 0.0), 0.0042, 0.0042, 10), Transform3D.IDENTITY, Color.WHITE, "none")
	_gkit.add(_m["shell_dark"], DroneParts.tube(Vector3(0.027, gy - 0.004, 0.0), Vector3(0.027, 0.0, 0.0), 0.0042, 0.0042, 10), Transform3D.IDENTITY, Color.WHITE, "none")
	_gkit.add(_m["dark_metal"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0105, 0), Vector2(0.0105, 0.006), Vector2(0, 0.006)])), 18), _xf(Vector3(0.0265, 0, 0), Vector3(0, 0, PI * 0.5)))
	_gkit.add(_m["shell"], DroneParts.rbox(Vector3(0.042, 0.036, 0.036), 6.0), _xf(Vector3(0, 0.002, 0.006)))
	_gkit.add(_m["shell_dark"], DroneParts.rbox(Vector3(0.03, 0.022, 0.004), 6.0), _xf(Vector3(0, 0.003, 0.0245)), Color.WHITE, "none")
	var lens := DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0135, 0), Vector2(0.0135, 0.018), Vector2(0.0145, 0.019), Vector2(0.0145, 0.026), Vector2(0.0125, 0.028), Vector2(0, 0.028)]))
	_gkit.add(_m["black"], DroneParts.lathe(lens, 24), _xf(Vector3(0, 0, -0.011), Vector3(-PI * 0.5, 0, 0)))
	_gkit.add(_m["accent"], DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0136, 0.012), Vector2(0.0141, 0.012), Vector2(0.0141, 0.0145), Vector2(0.0136, 0.0145)])), 24), _xf(Vector3(0, 0, -0.011), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	_gkit.add(_m["glass"], DroneParts.lathe(PackedVector2Array([Vector2(0, 0.0018), Vector2(0.0105, 0.0)]), 22), _xf(Vector3(0, 0, -0.0392), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	return {
		"yp": yp, "led": func(p: Vector3) -> Vector3: return Vector3(p.x, 0.025, p.z) + Vector3(signf(p.x), 0, signf(p.z)).normalized() * 0.0115,
		"spec": {"R": af["R"], "n": af["nBlades"], "root": 0.009, "c_root": 0.11, "c_max": 0.175, "t_max": 0.28, "c_tip": 0.085, "sweep": 0.13, "pd": 0.5, "tc": 0.12,
			"col": Color(0.07, 0.075, 0.08), "tip_col": Color(0.07, 0.075, 0.08)},
		"hub": {"r": 0.0122, "h": 0.0062, "cap_r": 0.0088, "cap_h": 0.0055, "cap_col": Color(0.7, 0.72, 0.75), "col": Color(0.1, 0.105, 0.11)},
	}

# ------------------------------------------------------------------ propellers and lights: where they go, and the prop meshes
func _prop_data(af: Dictionary, design: Dictionary) -> Dictionary:
	var positions := _motor_positions(af)
	var r: float = af["R"]
	var blades: int = af["nBlades"]
	var spec: Dictionary = design["spec"]
	var hub: Dictionary = design["hub"]
	var bcol: Color = spec["col"]; var tcol: Color = spec["tip_col"]
	var out := {
		"prop_ccw": DroneParts.prop(spec, 1, hub, _m["blade"]), "prop_cw": DroneParts.prop(spec, -1, hub, _m["blade"]),
		"prop_pos": [], "led": [], "discs": [], "spec": spec,
		"chord": DroneParts.chord_at(spec, 0.7),
		"blur_body": Color(bcol.r * 0.55, bcol.g * 0.55, bcol.b * 0.55), "blur_tip": Color(tcol.r * 0.85, tcol.g * 0.85, tcol.b * 0.85),
	}
	for i in 4:
		var p := positions[i]
		var hand := 1 if i % 2 == 1 else -1
		var yp: float = design["yp"]
		if design.has("yp_rear") and p.z > 0.0: yp = design["yp_rear"]
		out["prop_pos"].append(Vector3(p.x, yp, p.z))
		out["led"].append((design["led"] as Callable).call(p))
		out["discs"].append([Vector3(p.x, yp, p.z), r])
		# the blades at rest, for the drawing (build() turns each prop to the same angle)
		var bo := DroneParts.blade_outline(spec, hand)
		for b in blades:
			var bas := Basis(Vector3.UP, 0.5 + i * 1.3 + TAU * b / blades)
			var pts := PackedVector2Array()
			for q in bo:
				var w := bas * Vector3(q.x, 0.0, q.y)
				pts.append(Vector2(p.x + w.x, p.z + w.z))
			_kit.plan_poly(pts, yp)
		_kit.plan.append({"ring": [Vector2(p.x, p.z), 0.0, float(hub["r"])], "key": yp + 0.004})
	return out
