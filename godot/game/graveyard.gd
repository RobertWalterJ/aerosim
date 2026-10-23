class_name Graveyard
extends RefCounted
## More kinds of grave and the chapel's small details, all modelled in code from simple shapes.
##   Graves: a Celtic cross, an angel on a plinth, an obelisk, a pointed Gothic headstone, and kerbed plots (a stone kerb
##   round a bed of chippings, with a headstone or a cross at the head). They fill the gaps in the grave blocks'
##   2.8 m rows, kept clear of paths, the start pad, hedges, tree trunks and every other collider. One mesh per shape,
##   placed with a MultiMesh, all sharing one weathered-stone material (shaders/stone.gdshader).
##   Chapel: entrance steps, a stone door surround, window sills, a round window in each gable, a ridge cap, eaves
##   gutters and louvred openings in the bell stage of the tower.
## Hedgerow.build calls build() and adds the returned collision cylinders [x, z, r, y0, y1] to the world's.

const ROW := 2.8                 # spacing of the existing headstone rows
const COUNT := 230               # new graves wanted

static var _stone: ShaderMaterial

static func build(world: World, hedge_cyls: Array) -> Array:
	var t0 := Time.get_ticks_msec()
	var cyls := []
	_chapel(world, cyls)
	var n := _graves(world, hedge_cyls, cyls)
	print("graveyard: %d new graves, chapel details, %d ms" % [n, Time.get_ticks_msec() - t0])
	return cyls

# ------------------------------------------------------------------ materials
static func _white() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

static func stone_material() -> ShaderMaterial:
	if _stone != null: return _stone
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/stone.gdshader") as Shader
	m.set_shader_parameter("albedo_tex", _white())
	Assets._stone_set(m, "limestone", 1)
	m.set_shader_parameter("polish_override", 0.12)
	m.set_shader_parameter("set_tint", Vector3(0.76, 0.75, 0.72))
	m.set_shader_parameter("set_jitter", 1.0)
	m.set_shader_parameter("set_normal_amt", 0.8)
	_stone = m
	return m

static func _plain(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

# ------------------------------------------------------------------ shapes (local frame: y up from the ground, faces +-z)
static func _xf(p: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), p)

## A flat outline in the (x, y) plane, `thick` deep along z, centred on z = 0.
static func _slab(outline: PackedVector2Array, thick: float) -> Array:
	var data := DroneParts.extrude(outline, -thick * 0.5, thick * 0.5)
	# extrude builds in (x, z); turn it upright so the outline's second coordinate is height
	return DroneParts._apply(data, Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO))

## A headstone outline: straight sides to h0, then a pointed (Gothic) or round top reaching h1.
static func _tablet_outline(w: float, h0: float, h1: float, pointed: bool) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-w, 0.0), Vector2(w, 0.0)])
	if h0 > 0.001: pts.append(Vector2(w, h0))
	var n := 10
	for i in range(1, n):
		var t := float(i) / n           # right side up to the top, then down the left
		var a := t * PI
		var x := w * cos(a)
		var y: float
		if pointed:
			var u := 1.0 - absf(1.0 - 2.0 * t)              # 0 at the shoulders, 1 at the apex
			y = h0 + (h1 - h0) * sin(u * PI * 0.5)
			x = w * (1.0 - 2.0 * t) * (1.0 - 0.25 * sin(u * PI))
		else:
			y = h0 + (h1 - h0) * sin(a)
		pts.append(Vector2(x, y))
	if h0 > 0.001: pts.append(Vector2(-w, h0))
	return pts

static func _torus(R: float, r: float, seg := 28) -> Array:
	var prof := PackedVector2Array()
	for k in 10: prof.append(Vector2(R + r * cos(TAU * k / 10.0), r * sin(TAU * k / 10.0)))
	return DroneParts.lathe(prof, seg, true)

static func _box(kit: DroneParts.Kit, m: Material, size: Vector3, c: Vector3, col := Color.WHITE, e := 9.0) -> void:
	kit.add(m, DroneParts.rbox(size, e, 12), _xf(c), col, "none")

## Each shape: {mesh, foot: [[x, z, r], ...] in its own frame, h: height, w: weight}.
static func _shapes() -> Array:
	var m := stone_material()
	var out := []
	# Celtic cross on a base
	var k := DroneParts.Kit.new()
	_box(k, m, Vector3(0.62, 0.32, 0.36), Vector3(0, 0.16, 0))
	_box(k, m, Vector3(0.17, 1.25, 0.12), Vector3(0, 0.32 + 0.625, 0))
	_box(k, m, Vector3(0.6, 0.16, 0.12), Vector3(0, 1.3, 0))
	k.add(m, _torus(0.21, 0.035), _xf(Vector3(0, 1.3, 0), Vector3(PI * 0.5, 0, 0)), Color.WHITE, "none")
	out.append({"mesh": k.commit(), "foot": [[0.0, 0.0, 0.4]], "h": 1.6, "w": 0.18})
	# angel on a plinth
	k = DroneParts.Kit.new()
	_box(k, m, Vector3(0.78, 0.18, 0.78), Vector3(0, 0.09, 0))
	_box(k, m, Vector3(0.6, 0.72, 0.6), Vector3(0, 0.54, 0))
	_box(k, m, Vector3(0.7, 0.08, 0.7), Vector3(0, 0.94, 0))
	k.add(m, DroneParts.lathe(PackedVector2Array([Vector2(0, 0.98), Vector2(0.22, 0.98), Vector2(0.2, 1.12), Vector2(0.16, 1.4), Vector2(0.12, 1.58), Vector2(0.135, 1.64), Vector2(0.06, 1.69), Vector2(0, 1.69)]), 18), _xf(Vector3.ZERO), Color.WHITE, "none")
	k.add(m, DroneParts.sphere(0.085, 14), _xf(Vector3(0, 1.78, 0.01)), Color.WHITE, "none")
	var wing := PackedVector2Array([Vector2(0, 0), Vector2(0.08, 0.2), Vector2(0.17, 0.38), Vector2(0.26, 0.5), Vector2(0.24, 0.3), Vector2(0.2, 0.1), Vector2(0.15, -0.15), Vector2(0.08, -0.38), Vector2(0.02, -0.42)])
	var wdata := DroneParts.extrude(wing, -0.015, 0.015)
	for sx in [-1.0, 1.0]:
		var wb := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
		k.add(m, wdata, Transform3D(Basis(Vector3.UP, sx * 0.45) * wb, Vector3(sx * 0.08, 1.52, -0.09)), Color.WHITE, "none")
		k.add(m, DroneParts.tube(Vector3(sx * 0.13, 1.58, 0.0), Vector3(sx * 0.03, 1.4, 0.13), 0.035, 0.03, 8), Transform3D.IDENTITY, Color.WHITE, "none")
	out.append({"mesh": k.commit(), "foot": [[0.0, 0.0, 0.5]], "h": 1.9, "w": 0.07})
	# obelisk on two steps and a die
	k = DroneParts.Kit.new()
	_box(k, m, Vector3(0.82, 0.22, 0.82), Vector3(0, 0.11, 0))
	_box(k, m, Vector3(0.62, 0.3, 0.62), Vector3(0, 0.37, 0))
	_box(k, m, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.77, 0))
	var up := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 1.02, 0))
	k.add(m, DroneParts.loft([[0.0, 0.0, 0.0, 0.19, 0.19], [1.9, 0.0, 0.0, 0.125, 0.125]], 12.0, 16, true), up, Color.WHITE, "none")
	k.add(m, DroneParts.loft([[1.9, 0.0, 0.0, 0.125, 0.125], [2.08, 0.0, 0.0, 0.004, 0.004]], 12.0, 16, false), up, Color.WHITE, "none")
	out.append({"mesh": k.commit(), "foot": [[0.0, 0.0, 0.5]], "h": 3.1, "w": 0.1})
	# pointed Gothic headstone on a base
	k = DroneParts.Kit.new()
	_box(k, m, Vector3(0.78, 0.14, 0.3), Vector3(0, 0.07, 0))
	k.add(m, _slab(_tablet_outline(0.3, 0.72, 1.02, true), 0.1), _xf(Vector3(0, 0.13, 0)), Color.WHITE, "none")
	out.append({"mesh": k.commit(), "foot": [[0.0, 0.0, 0.42]], "h": 1.15, "w": 0.27})
	# kerbed plots: a kerb round a bed of grey chippings, a round-topped headstone or a cross at the head (-z)
	for head in ["stone", "cross"]:
		k = DroneParts.Kit.new()
		for sx in [-1.0, 1.0]:
			_box(k, m, Vector3(0.12, 0.17, 2.0), Vector3(sx * 0.44, 0.085, 0.0))
			_box(k, m, Vector3(1.0, 0.17, 0.12), Vector3(0, 0.085, sx * 0.98))
		_box(k, m, Vector3(0.78, 0.07, 1.86), Vector3(0, 0.05, 0), Color(0.62, 0.62, 0.64), 4.0)
		if head == "stone":
			k.add(m, _slab(_tablet_outline(0.34, 0.55, 0.8, false), 0.09), _xf(Vector3(0, 0.1, -0.92)), Color.WHITE, "none")
		else:
			_box(k, m, Vector3(0.12, 1.05, 0.1), Vector3(0, 0.1 + 0.525, -0.92))
			_box(k, m, Vector3(0.5, 0.11, 0.1), Vector3(0, 0.88, -0.92))
		out.append({"mesh": k.commit(), "foot": [[0.0, -0.6, 0.6], [0.0, 0.6, 0.6]], "h": 1.15 if head == "cross" else 0.9, "w": 0.2 if head == "stone" else 0.1})
	return out

# ------------------------------------------------------------------ placement
static func _graves(world: World, hedge_cyls: Array, cyls: Array) -> int:
	var t: Terrain = world.terrain
	var layout: Dictionary = world.layout
	var G := 4.0
	var obs := {}                      # Vector2i -> Array of [x, z, r]
	var add := func(x: float, z: float, r: float) -> void:
		var key := Vector2i(floori(x / G), floori(z / G))
		if not obs.has(key): obs[key] = []
		obs[key].append([x, z, r])
	for c in layout["colliders"]["cyl"]: add.call(float(c[0]), float(c[1]), float(c[2]))
	for c in hedge_cyls: add.call(float(c[0]), float(c[1]), float(c[2]))
	for c in cyls: add.call(float(c[0]), float(c[1]), float(c[2]))
	for key in world._trunks:
		for tr in world._trunks[key]: add.call(float(tr[0]), float(tr[2]), float(tr[3]) + 0.4)
	var boxes: Array = []
	for b in layout["colliders"]["box"]: boxes.append(Rect2(Vector2(b[0], b[1]) - Vector2(1.5, 1.5), Vector2(b[2] - b[0], b[3] - b[1]) + Vector2(3, 3)))
	for r in world.exclusions: boxes.append(r.grow(1.0))
	var home := world.home
	var free := func(x: float, z: float, r: float) -> bool:
		if Vector2(x, z).distance_to(home) < 15.0 + r: return false
		if Hedgerow._path_dist(t, x, z) < 2.3 + r: return false
		for b in boxes:
			var rb: Rect2 = b
			if rb.grow(r).has_point(Vector2(x, z)): return false
		var key := Vector2i(floori(x / G), floori(z / G))
		for a in range(-1, 2):
			for bb in range(-1, 2):
				var k2 := Vector2i(key.x + a, key.y + bb)
				if not obs.has(k2): continue
				for o in obs[k2]:
					var dx: float = x - o[0]; var dz: float = z - o[1]
					var need: float = r + float(o[2]) + 0.35
					if dx * dx + dz * dz < need * need: return false
		return true
	# where the existing headstones stand (their rows are the lattice new graves fill)
	var heads: Array = []
	for k in 4:
		var pi: Dictionary = layout["parkInstanced"][k]
		var mm: Array = pi["m"]
		for i in int(pi["count"]): heads.append(Vector3(mm[i * 9], mm[i * 9 + 4], mm[i * 9 + 2]))
	var shapes := _shapes()
	var wsum := 0.0
	for s in shapes: wsum += float(s["w"])
	var rng := RandomNumberGenerator.new(); rng.seed = 90210
	var xfs: Array = []; var cols: Array = []
	for s in shapes:
		xfs.append([] as Array[Transform3D]); cols.append([] as Array[Color])
	var steps := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(2, 0), Vector2(0, 2)]
	var placed := 0
	var tries := 0
	var tints := [Color(0.95, 0.95, 0.93), Color(0.8, 0.8, 0.82), Color(0.58, 0.59, 0.61), Color(0.98, 0.88, 0.74), Color(1.04, 1.04, 1.02), Color(0.42, 0.43, 0.45)]
	while placed < COUNT and tries < COUNT * 40:
		tries += 1
		var h: Vector3 = heads[rng.randi() % heads.size()]
		var st: Vector2 = steps[rng.randi() % steps.size()]
		var yaw := h.y + rng.randf_range(-0.04, 0.04)
		var off := Vector2(st.x * ROW, st.y * ROW).rotated(-yaw) + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
		var x := h.x + off.x; var z := h.z + off.y
		# pick a shape by weight
		var pick := rng.randf() * wsum
		var si := 0
		for q in shapes.size():
			pick -= float(shapes[q]["w"])
			if pick <= 0.0: si = q; break
		var sh: Dictionary = shapes[si]
		var basis := Basis(Vector3.UP, yaw)
		var ok := true
		var feet: Array = []
		for f in sh["foot"]:
			var fp := basis * Vector3(f[0], 0, f[1])
			feet.append([x + fp.x, z + fp.z, float(f[2])])
			if not free.call(x + fp.x, z + fp.z, float(f[2])): ok = false; break
		if not ok: continue
		var y := t.height(x, z) - 0.04
		var lean := Basis(Vector3.RIGHT, rng.randf_range(-0.035, 0.035)) * Basis(Vector3.FORWARD, rng.randf_range(-0.025, 0.025))
		xfs[si].append(Transform3D(basis * lean, Vector3(x, y, z)))
		cols[si].append(tints[rng.randi() % tints.size()])
		for f in feet:
			add.call(f[0], f[1], f[2])
			cyls.append([f[0], f[1], f[2], y - 0.1, y + float(sh["h"])])
		placed += 1
	for si in shapes.size():
		var list: Array[Transform3D] = xfs[si]
		if list.is_empty(): continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = shapes[si]["mesh"]
		mm.instance_count = list.size()
		for q in list.size():
			mm.set_instance_transform(q, list[q]); mm.set_instance_color(q, cols[si][q])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visibility_range_end = 420.0
		world.add_child(mi)
		if OS.is_debug_build() and "gravedebug" in OS.get_cmdline_user_args(): print("graveyard shape %d: %d, first at %s" % [si, list.size(), list[0].origin])
	return placed

# ------------------------------------------------------------------ the chapel
## The chapel in park.glb: an 11 x 7 m nave on a brick plinth (floor 0.9 m up), long axis turned about 31.5 degrees,
## door and bell tower at the +axis end. Measured from the model; only built if the layout's chapel is where it was.
const CHAPEL_C := Vector2(188.0, -74.0)
const CHAPEL_AXIS := Vector2(0.5224, 0.8527)
const CH_GROUND := 126.19
const CH_FLOOR := 127.09
const CH_EAVES := 130.49
const CH_RIDGE := 133.72
const CH_HALF_L := 5.51
const CH_HALF_W := 3.485

static func _chapel(world: World, cyls: Array) -> void:
	var ch: Array = world.layout.get("chapel", [])
	if ch.size() < 3 or Vector2(float(ch[0]), float(ch[2])).distance_to(CHAPEL_C) > 0.5: return
	var ax := Vector3(CHAPEL_AXIS.x, 0, CHAPEL_AXIS.y)
	var lat := Vector3(CHAPEL_AXIS.y, 0, -CHAPEL_AXIS.x)
	# frame: x = across the nave (lat), y up, z = along the nave towards the door (ax)
	var F := Transform3D(Basis(lat, Vector3.UP, ax), Vector3(CHAPEL_C.x, 0, CHAPEL_C.y))
	var k := DroneParts.Kit.new()
	var stone := Graveyard.stone_material()
	var ashlar := ShaderMaterial.new()
	ashlar.shader = load("res://game/shaders/stone.gdshader") as Shader
	ashlar.set_shader_parameter("albedo_tex", _white())
	Assets._stone_set(ashlar, "ashlar", 1)
	ashlar.set_shader_parameter("polish_override", 0.05)
	ashlar.set_shader_parameter("set_metres", 2.2)
	var lead := _plain(Color(0.16, 0.17, 0.19), 0.45, 0.4)
	var glass := _plain(Color(0.03, 0.04, 0.06), 0.08, 0.6)
	var wood := _plain(Color(0.30, 0.27, 0.23), 0.8)
	var dark := _plain(Color(0.02, 0.02, 0.025), 1.0)
	var face := CH_HALF_L + 0.25           # the plinth's end face
	# entrance steps up to the door
	for s in 3:
		var top := CH_FLOOR - 0.3 * s
		var depth := 0.36 * (s + 1)
		_box(k, ashlar, Vector3(2.5 + 0.3 * s, top - CH_GROUND + 0.3, depth), Vector3(0, (top + CH_GROUND - 0.3) * 0.5, face + depth * 0.5), Color.WHITE, 10.0)
	# stone door surround: jambs and a pointed hood over the door
	var wall := CH_HALF_L + 0.06
	for sx in [-1.0, 1.0]:
		_box(k, stone, Vector3(0.2, 2.55, 0.14), Vector3(sx * 0.86, CH_FLOOR + 1.275, wall), Color.WHITE, 10.0)
	k.add(stone, _slab(_tablet_outline(0.98, 0.0, 0.62, true), 0.14), _xf(Vector3(0, CH_FLOOR + 2.5, wall)), Color.WHITE, "none")
	k.add(dark, _slab(_tablet_outline(0.72, 0.0, 0.42, true), 0.16), _xf(Vector3(0, CH_FLOOR + 2.52, wall + 0.005)), Color.WHITE, "none")
	# round windows high in both gables: a stone ring and dark glass
	for end in [-1.0, 1.0]:
		var gz: float = end * (CH_HALF_L + 0.04)
		var gy := 131.55 if end > 0.0 else 131.7
		k.add(stone, _torus(0.5, 0.075, 28), _xf(Vector3(0, gy, gz), Vector3(PI * 0.5, 0, 0)), Color.WHITE, "none")
		k.add(glass, DroneParts.lathe(PackedVector2Array([Vector2(0, 0.0), Vector2(0.48, 0.0)]), 24), _xf(Vector3(0, gy, gz - end * 0.02), Vector3(PI * 0.5 * end, 0, 0)), Color.WHITE, "none")
		k.add(glass, DroneParts.lathe(PackedVector2Array([Vector2(0.48, 0.0), Vector2(0, 0.0)]), 24), _xf(Vector3(0, gy, gz - end * 0.02), Vector3(PI * 0.5 * end, 0, 0)), Color.WHITE, "none")
	# window sills under the eight tall windows (four a side, measured from the model)
	for side in [-1.0, 1.0]:
		for i in 4:
			var along := -3.9 + 2.6 * i
			_box(k, stone, Vector3(0.16, 0.1, 0.95), Vector3(side * (CH_HALF_W + 0.08), 127.74, along), Color.WHITE, 10.0)
	# ridge cap and eaves gutters
	k.add(lead, DroneParts.tube(Vector3(0, CH_RIDGE, -CH_HALF_L - 0.3), Vector3(0, CH_RIDGE, CH_HALF_L + 0.3), 0.11, 0.11, 10), Transform3D.IDENTITY, Color.WHITE, "none")
	for side in [-1.0, 1.0]:
		var gx: float = side * (CH_HALF_W + 0.42)
		k.add(lead, DroneParts.tube(Vector3(gx, CH_EAVES - 0.12, -CH_HALF_L - 0.3), Vector3(gx, CH_EAVES - 0.12, CH_HALF_L + 0.3), 0.07, 0.07, 8), Transform3D.IDENTITY, Color.WHITE, "none")
		for end in [-1.0, 1.0]:      # downpipes at the four corners
			k.add(lead, DroneParts.tube(Vector3(gx, CH_EAVES - 0.12, end * (CH_HALF_L + 0.2)), Vector3(gx, CH_FLOOR, end * (CH_HALF_L + 0.2)), 0.045, 0.045, 8), Transform3D.IDENTITY, Color.WHITE, "none")
	# bell stage: louvred openings on all four faces of the tower's upper block (2.2 m square, 135.5 to 137.3 m)
	var tc := Vector3(0, 0, 3.906)
	for f in 4:
		var rot := Basis(Vector3.UP, f * PI * 0.5)
		var n := rot * Vector3(0, 0, 1)
		var c := tc + n * 1.105 + Vector3(0, 136.4, 0)
		var fx := Transform3D(rot, c)
		k.add(dark, DroneParts.rbox(Vector3(0.95, 1.25, 0.04), 10.0, 8), fx, Color.WHITE, "none")
		for s in 5:
			k.add(wood, DroneParts.rbox(Vector3(0.95, 0.06, 0.12), 8.0, 8), fx * _xf(Vector3(0, -0.5 + 0.25 * s, 0.04), Vector3(-0.6, 0, 0)), Color.WHITE, "none")
		k.add(stone, DroneParts.rbox(Vector3(1.15, 0.09, 0.14), 10.0, 8), fx * _xf(Vector3(0, -0.68, 0.05)), Color.WHITE, "none")
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.transform = F
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	world.add_child(mi)
	# the steps are solid
	for s in [-0.8, 0.0, 0.8]:
		var p := F * Vector3(s, 0, face + 0.5)
		cyls.append([p.x, p.z, 0.55, CH_GROUND - 0.1, CH_FLOOR])
