class_name NewModels4
extends RefCounted
## The fourth batch of models drawn by code (batch "models6"): road vehicles and roadside furniture for the country roads.
## Cars, pickups, vans, a tractor with its trailer, a milk tanker, a bus and a motorcycle, with real wheels that spin and
## steer; telegraph poles, power pylons, road signs, field gates, a bus shelter, a mailbox, road works, a milestone, a
## cattle grid, a bridge rail. Real metres. Forward is -z, up is +y, x is right. The origin is the ground, in the middle of
## the vehicle's length. Every model is one mesh with a surface per material, kept once made. The finish is the vertex
## colour (alpha = how worn it is) read by game/shaders/vehicle.gdshader. The contract is game/README-models.md.
## Entry points:
##   `NewModels4.mesh(name, lod, paint)`    the whole model as one still mesh (wheels in place); lod 0 near, 1 middle, 2 far.
##   `NewModels4.vehicle(name, lod, paint)` a Dictionary with the body and the wheels apart so the wheels can spin and steer.
##   `NewModels4.colliders(name)`           box strips (AABB, model frame) for what a drone can hit.
## The vehicle files: this one holds the shared parts, the wheels and the cars; new_models4_big.gd the farm and heavy
## vehicles; new_models4_props.gd the roadside furniture.

const CARS: Array[String] = ["car_hatch_a", "car_hatch_b", "car_estate_a", "pickup_a", "pickup_b", "van_a", "van_b"]
const BIG: Array[String] = ["tractor_a", "tractor_wheels_a", "tractor_trailer_a", "milk_tanker_a", "bus_a", "motorcycle_a"]
const PROPS: Array[String] = ["telegraph_pole_a", "telegraph_pole_b", "power_pylon_a", "power_pylon_b", "road_sign_bend_a", "road_sign_junction_a",
	"road_sign_speed_a", "road_marker_a", "cattle_grid_a", "field_gate_a", "field_gate_b", "bus_shelter_a", "post_box_a", "road_works_a",
	"milestone_a", "road_bridge_rail_a"]
const NAMES: Array[String] = ["car_hatch_a", "car_hatch_b", "car_estate_a", "pickup_a", "pickup_b", "van_a", "van_b", "tractor_a", "tractor_wheels_a",
	"tractor_trailer_a", "milk_tanker_a", "bus_a", "motorcycle_a", "telegraph_pole_a", "telegraph_pole_b", "power_pylon_a", "power_pylon_b",
	"road_sign_bend_a", "road_sign_junction_a", "road_sign_speed_a", "road_marker_a", "cattle_grid_a", "field_gate_a", "field_gate_b",
	"bus_shelter_a", "post_box_a", "road_works_a", "milestone_a", "road_bridge_rail_a"]

## Paints worth picking from (sRGB). Pass one as `paint` to get that colour; each colour is built once and kept.
const PAINTS: Array[Color] = [Color(0.62, 0.64, 0.66), Color(0.08, 0.09, 0.1), Color(0.55, 0.07, 0.06), Color(0.1, 0.2, 0.42), Color(0.9, 0.9, 0.88),
	Color(0.16, 0.3, 0.22), Color(0.36, 0.38, 0.4), Color(0.58, 0.46, 0.3), Color(0.7, 0.52, 0.12), Color(0.2, 0.42, 0.62)]

static var _cache := {}
static var _veh := {}
static var _mats := {}

# ================================================================== materials
## Shared materials, all game/shaders/vehicle.gdshader with a different `kind` (see the shader).
static func _mat(key: String) -> Material:
	if key == "wood" or key == "steel": return NewModels3._mat(key)
	if _mats.has(key): return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/vehicle.gdshader") as Shader
	var kinds := {"paint": 0, "rubber": 1, "metal": 2, "glass": 3, "trim": 4, "lens": 5, "sheet": 6, "concrete": 7}
	m.set_shader_parameter("kind", int(kinds[key]))
	_mats[key] = m
	return m

## The parts of one model by material.
class Parts:
	var m := {}
	func b(key: String) -> NewModels2.Buf:
		if not m.has(key): m[key] = NewModels2.Buf.new()
		return m[key]

# ================================================================== helpers
const I := Transform3D.IDENTITY

static func _rnd(i: float, salt := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

## Add a part (triangle lists [pos, nrm] or [pos, nrm, cols]) to a material of the model, moved by xf.
static func _put(p: Parts, key: String, data: Array, xf := I, col := Color.WHITE) -> void:
	var b := p.b(key)
	var pos: PackedVector3Array = data[0]
	var nrm: PackedVector3Array = data[1]
	b.pos.append_array(xf * pos)
	b.nrm.append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * nrm)
	if data.size() > 2:
		b.cols.append_array(data[2])
	else:
		var c := PackedColorArray(); c.resize(pos.size()); c.fill(col)
		b.cols.append_array(c)

## A box with flat faces, centred on c, turned by bas.
static func _bx(p: Parts, key: String, c: Vector3, size: Vector3, col: Color, bas := Basis.IDENTITY) -> void:
	_put(p, key, NewModels._box(size), Transform3D(bas, c), col)

## A softly rounded box.
static func _rbx(p: Parts, key: String, c: Vector3, size: Vector3, col: Color, bas := Basis.IDENTITY, seg := 12) -> void:
	_put(p, key, DroneParts.rbox(size, 6.0, seg), Transform3D(bas, c), col)

## A square bar from a to b (see NewModels2._beam).
static func _bm(p: Parts, key: String, a: Vector3, b: Vector3, w: float, h: float, col: Color, up := Vector3.UP, ext := 0.0) -> void:
	_put(p, key, NewModels2._beam(a, b, w, h, up, ext), I, col)

## A round tube from a to b.
static func _cyl(p: Parts, key: String, a: Vector3, b: Vector3, r0: float, r1: float, seg: int, col: Color) -> void:
	_put(p, key, DroneParts.tube(a, b, r0, r1, seg), I, col)

## A flat quad a-b-c-d (in order round its edge) facing n.
static func _qd(p: Parts, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	p.b(key).quad(a, b, c, d, col, n)

## A flat disc on a plane: centre c, facing n, radius r.
static func _disc(p: Parts, key: String, c: Vector3, n: Vector3, r: float, seg: int, col: Color) -> void:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := n.cross(u)
	var b := p.b(key)
	for k in seg:
		var a0 := TAU * k / seg; var a1 := TAU * (k + 1) / seg
		b.tri(c, c + (u * cos(a0) + v * sin(a0)) * r, c + (u * cos(a1) + v * sin(a1)) * r, col, n)

## A flat ring (annulus) on a plane.
static func _annulus(p: Parts, key: String, c: Vector3, n: Vector3, r0: float, r1: float, seg: int, col: Color) -> void:
	var u := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized()
	var v := n.cross(u)
	var b := p.b(key)
	for k in seg:
		var a0 := TAU * k / seg; var a1 := TAU * (k + 1) / seg
		var d0 := u * cos(a0) + v * sin(a0); var d1 := u * cos(a1) + v * sin(a1)
		b.quad(c + d0 * r0, c + d0 * r1, c + d1 * r1, c + d1 * r0, col, n)

static func _finish(p: Parts) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	for key in p.m: kit.add(_mat(key), (p.m[key] as NewModels2.Buf).data())
	return kit.commit()

## A colour a little lighter or darker per cell, alpha kept.
static func _vc(c: Color, k: float, amt := 0.05) -> Color:
	var o := NewModels._vary(c, Vector3(k * 1.7, k * 0.31, 5.1), amt)
	o.a = c.a
	return o

static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

# colours (sRGB; alpha is the condition: 1 clean)
const C_TRIM := Color(0.06, 0.06, 0.065, 0.95)
const C_TRIM2 := Color(0.16, 0.165, 0.17, 0.9)
const C_CHROME := Color(0.86, 0.87, 0.88, 1.0)
const C_ALU := Color(0.62, 0.63, 0.65, 0.8)
const C_GLASS := Color(0.5, 0.52, 0.55, 1.0)
const C_LENS := Color(0.82, 0.84, 0.86, 1.0)
const C_RED := Color(0.62, 0.03, 0.03, 1.0)
const C_AMBER := Color(0.85, 0.4, 0.04, 1.0)

# ================================================================== entry points
## The whole model as one still mesh. paint: the body colour (default is the model's own).
static func mesh(name: String, lod := 0, paint := Color(0, 0, 0, 0)) -> ArrayMesh:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d/%s" % [name, lod, paint.to_html()]
	if _cache.has(k): return _cache[k]
	var out: ArrayMesh
	if name in CARS or name in BIG and name != "tractor_wheels_a":
		var v := vehicle(name, lod, paint)
		out = _merge_vehicle(v)
	elif name == "tractor_wheels_a":
		out = NewModels4Big.tractor_wheels(lod)
	elif name in PROPS:
		out = NewModels4Props.mesh(name, lod)
	else:
		push_error("NewModels4: no model called " + name)
		out = ArrayMesh.new()
	_cache[k] = out
	return out

## A vehicle with its wheels apart. Keys: "body" (ArrayMesh), "wheels" (Array of {"mesh" made for its own side so it spins
## about local x with the same sign everywhere, "pos" the hub in the model frame, "radius", "steer" true on the front pair,
## "name"}), "size" (Vector3, metres), "wheel_radius", "track" (distance between the left and right hub centres), "wheelbase".
static func vehicle(name: String, lod := 0, paint := Color(0, 0, 0, 0)) -> Dictionary:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d/%s" % [name, lod, paint.to_html()]
	if _veh.has(k): return _veh[k]
	var v: Dictionary
	if name in CARS: v = _car(name, lod, paint)
	elif name in BIG: v = NewModels4Big.vehicle(name, lod, paint)
	else:
		push_error("NewModels4: not a vehicle: " + name)
		v = {"body": ArrayMesh.new(), "wheels": [], "size": Vector3.ZERO, "wheel_radius": 0.3, "track": 1.5, "wheelbase": 2.5}
	_veh[k] = v
	return v

## A ready-made Node3D for a vehicle: a "Body" MeshInstance3D and, for each wheel, a pivot Node3D named like the wheel
## ("wheel_fl", "wheel_fr", "wheel_rl", ...) at the hub (turn it about y to steer) holding a "Wheel" MeshInstance3D (roll it
## about x: rotation.x -= distance / radius when going forward). Other names give a MeshInstance3D of the still mesh.
static func build_node(name: String, lod := 0, paint := Color(0, 0, 0, 0)) -> Node3D:
	var root := Node3D.new()
	root.name = name
	if name in CARS or (name in BIG and name != "tractor_wheels_a"):
		var v := vehicle(name, lod, paint)
		var body := MeshInstance3D.new(); body.name = "Body"; body.mesh = v["body"]
		root.add_child(body)
		for w: Dictionary in v["wheels"]:
			var piv := Node3D.new(); piv.name = w["name"]; piv.position = w["pos"]
			var mi := MeshInstance3D.new(); mi.name = "Wheel"; mi.mesh = w["mesh"]
			piv.add_child(mi)
			root.add_child(piv)
	else:
		var mi := MeshInstance3D.new(); mi.name = "Mesh"; mi.mesh = mesh(name, lod, paint)
		root.add_child(mi)
	return root

## The body and every wheel merged into one mesh (wheels at rest).
static func _merge_vehicle(v: Dictionary) -> ArrayMesh:
	var out := ArrayMesh.new()
	var body: ArrayMesh = v["body"]
	_append_mesh(out, body, I)
	for w: Dictionary in v["wheels"]:
		_append_mesh(out, w["mesh"], Transform3D(Basis.IDENTITY, w["pos"]))
	return out

static func _append_mesh(out: ArrayMesh, m: ArrayMesh, xf: Transform3D) -> void:
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = xf * pos
		arrays[Mesh.ARRAY_NORMAL] = Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * nrm
		arrays[Mesh.ARRAY_COLOR] = arr[Mesh.ARRAY_COLOR]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, m.surface_get_material(s))

## The points a wire is hung from (telegraph poles and power pylons), in the model frame.
static func attachments(name: String) -> Array:
	return NewModels4Props.attachments(name)

## Box strips a drone can hit, in the model's frame.
static func colliders(name: String) -> Array:
	if name in PROPS: return NewModels4Props.colliders(name)
	if name == "tractor_wheels_a": return []
	if name in CARS or name in BIG:
		var v := vehicle(name, 2)
		return NewModels4Big.vehicle_colliders(name, v)
	return []

# ================================================================== wheels
## A wheel with its axis along x and its outer face toward +x, hub at the origin. R: overall radius, w: tyre width,
## style: "alloy" (five spokes), "steel" (a pressed steel disc with a cap), "heavy" (truck: ten-stud steel, bright nuts),
## "tractor" (big lugged rear), "tractor_f" (front), "moto". lod 0 near, 1 middle, 2 far (a plain turned wheel).
static func wheel(R: float, w: float, style: String, lod: int, paint := Color(0.6, 0.62, 0.64)) -> ArrayMesh:
	var key := "wheel/%.3f/%.3f/%s/%d/%s" % [R, w, style, lod, paint.to_html()]
	if _cache.has(key): return _cache[key]
	var p := Parts.new()
	var hw := w * 0.5
	var seg: int = [28, 16, 8][lod]
	var Rout := R
	var rimf := 0.62
	var side := 0.96
	match style:
		"steel": rimf = 0.6
		"heavy": rimf = 0.56; seg = [32, 18, 9][lod]
		"tractor": rimf = 0.56; seg = [40, 24, 10][lod]; R *= 0.948
		"tractor_f": rimf = 0.52; seg = [32, 20, 9][lod]; R *= 0.948
		"moto": rimf = 0.72; side = 0.9
	var rr := R * rimf
	var tw := hw * 0.8                       # half width of the running face
	var tyre_c := Color(0.02, 0.02, 0.022, 1.0)
	var rubber := tyre_c
	# ---- the tyre: sidewall bulge, shoulder, tread with grooves (lathe profile: x radius, y across, y toward +x after turning)
	var pr := PackedVector2Array()
	var pf := func(r: float, y: float) -> void: pr.append(Vector2(r, y))
	var rim_in := rr + 0.004
	if lod == 2:
		for q: Array in [[rim_in, hw * 0.8], [rr + (R - rr) * 0.6, hw], [R, tw], [R, tw], [R, -tw], [R, -tw], [rr + (R - rr) * 0.6, -hw], [rim_in, -hw * 0.8]]:
			pf.call(q[0], q[1])
	else:
		pf.call(rim_in, hw * 0.72)
		pf.call(rr + (R - rr) * 0.3, hw * side)
		pf.call(rr + (R - rr) * 0.68, hw * 1.0)
		pf.call(R - (R - rr) * 0.1, hw * 0.9)
		pf.call(R - 0.004, tw * 1.02); pf.call(R - 0.004, tw * 1.02)
		if style == "tractor" or style == "tractor_f":
			pass                                   # the lugs are real geometry added below
		elif lod == 0:
			pf.call(R, tw * 0.9); pf.call(R, tw * 0.9)
			for g: float in [0.45, -0.45]:
				var y: float = tw * g
				pf.call(R, y + 0.03 * tw); pf.call(R, y + 0.03 * tw)
				pf.call(R - 0.0075, y + 0.01 * tw); pf.call(R - 0.0075, y - 0.01 * tw)
				pf.call(R, y - 0.03 * tw); pf.call(R, y - 0.03 * tw)
			pf.call(R, -tw * 0.9); pf.call(R, -tw * 0.9)
		else:
			pf.call(R, tw * 0.9); pf.call(R, tw * 0.9); pf.call(R, -tw * 0.9); pf.call(R, -tw * 0.9)
		pf.call(R - 0.004, -tw * 1.02); pf.call(R - 0.004, -tw * 1.02)
		pf.call(R - (R - rr) * 0.1, -hw * 0.9)
		pf.call(rr + (R - rr) * 0.68, -hw * 1.0)
		pf.call(rr + (R - rr) * 0.3, -hw * side)
		pf.call(rim_in, -hw * 0.72)
	var on_x := Basis(Vector3(0, 0, 1), -PI * 0.5)                  # the lathe's +Y onto +X
	var tyre := DroneParts.lathe(pr, seg, true)
	_put(p, "rubber", tyre, Transform3D(on_x, Vector3.ZERO), rubber)
	# ---- lugs (farm tyres): chevron blocks standing on the running face
	if style == "tractor" or style == "tractor_f":
		var n_l: int = [24, 14, 0][lod] if style == "tractor" else [20, 12, 0][lod]
		var lug_len := tw * 0.62
		for i in n_l:
			var a := TAU * i / n_l
			var d := Vector3(0, cos(a), sin(a))
			var tang := Vector3(0, -sin(a), cos(a))
			for sgn: float in [-1.0, 1.0]:
				var c := Vector3(sgn * tw * 0.5, 0, 0) + d * R
				var axis := (Vector3(-sgn * 0.8, 0, 0) + tang * 0.9).normalized()
				_bm(p, "rubber", c - axis * lug_len * 0.5, c + axis * lug_len * 0.5, 0.07 * Rout, 0.1 * Rout, rubber, d)
	# ---- the rim
	var pc := Color(paint.r, paint.g, paint.b, 1.0)
	var rim_col := C_ALU if style == "alloy" else (Color(0.12, 0.12, 0.13, 0.9) if style != "moto" else C_ALU)
	if style == "steel": rim_col = Color(0.5, 0.5, 0.52, 0.85)
	if style == "heavy": rim_col = Color(0.62, 0.62, 0.64, 0.8)
	if style == "tractor" or style == "tractor_f": rim_col = Color(paint.r * 0.9, paint.g * 0.9, paint.b * 0.9, 0.8)
	var xo := hw * 0.78                                                 # the outer lip
	var barrel := PackedVector2Array([Vector2(rr + 0.004, xo), Vector2(rr + 0.004, xo), Vector2(rr - 0.006, xo - 0.012), Vector2(rr - 0.012, xo - 0.04),
		Vector2(rr - 0.012, -xo + 0.06), Vector2(rr - 0.006, -xo + 0.02), Vector2(rr + 0.004, -xo)])
	_put(p, "metal", DroneParts.lathe(barrel, maxi(seg / 2, 12)), Transform3D(on_x, Vector3.ZERO), rim_col)
	var hub_y := hw * 0.5
	match style:
		"alloy", "moto":
			var ns := 5 if style == "alloy" else 6
			if lod == 2: ns = 0
			_put(p, "metal", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, hub_y + 0.014), Vector2(rr * 0.2, hub_y + 0.012), Vector2(rr * 0.22, hub_y - 0.02),
				Vector2(0.0, hub_y - 0.02)])), 14 if lod < 2 else 8), Transform3D(on_x, Vector3.ZERO), rim_col)
			for i in ns:
				var a := TAU * (i + 0.5) / ns
				var d := Vector3(0, cos(a), sin(a))
				_bm(p, "metal", d * rr * 0.16 + Vector3(hub_y, 0, 0), d * rr * 0.92 + Vector3(xo - 0.03, 0, 0), rr * 0.2, 0.015 + 0.01 * rr, rim_col, Vector3(1, 0, 0))
			if lod < 2:
				_disc(p, "trim", Vector3(hub_y - 0.025, 0, 0), Vector3(1, 0, 0), rr * 0.9, 20, Color(0.03, 0.03, 0.035, 0.9))       # dark well behind the spokes
		"steel":
			_disc(p, "metal", Vector3(hub_y + 0.004, 0, 0), Vector3(1, 0, 0), rr * 0.97, 24 if lod < 2 else 10, rim_col)
			if lod < 2:
				for i in 5:
					var a := TAU * i / 5.0
					var d := Vector3(0, cos(a), sin(a))
					_disc(p, "trim", d * rr * 0.55 + Vector3(hub_y + 0.006, 0, 0), Vector3(1, 0, 0), rr * 0.13, 8, Color(0.04, 0.04, 0.045, 0.9))
				_put(p, "metal", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, hub_y + 0.03), Vector2(rr * 0.3, hub_y + 0.028), Vector2(rr * 0.33, hub_y + 0.004), Vector2(0.0, hub_y)])), 16),
					Transform3D(on_x, Vector3.ZERO), Color(0.55, 0.55, 0.57, 0.9))
		_:
			_disc(p, "metal", Vector3(hub_y + 0.004, 0, 0), Vector3(1, 0, 0), rr * 0.97, 24 if lod < 2 else 10, rim_col)
			if lod < 2:
				var n_s := 10 if style == "heavy" else 8
				for i in n_s:
					var a := TAU * (i + 0.5) / n_s
					var d := Vector3(0, cos(a), sin(a))
					_cyl(p, "metal", d * rr * 0.34 + Vector3(hub_y + 0.004, 0, 0), d * rr * 0.34 + Vector3(hub_y + 0.03, 0, 0), 0.016 * R / 0.5 + 0.008, 0.016 * R / 0.5 + 0.008, 6, Color(0.7, 0.7, 0.72, 0.75))
				_put(p, "metal", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, hub_y + 0.05), Vector2(rr * 0.24, hub_y + 0.045), Vector2(rr * 0.27, hub_y), Vector2(0.0, hub_y)])), 16),
					Transform3D(on_x, Vector3.ZERO), Color(paint.r * 0.7, paint.g * 0.7, paint.b * 0.7, 0.8) if style.begins_with("tractor") else Color(0.6, 0.6, 0.62, 0.7))
	var out := _finish(p)
	_cache[key] = out
	return out

## The same wheel for the left side (turned half a turn about y, so its outer face looks toward -x).
static func wheel_side(R: float, w: float, style: String, lod: int, paint: Color, left: bool) -> ArrayMesh:
	var right := wheel(R, w, style, lod, paint)
	if not left: return right
	var key := "wheelL/%.3f/%.3f/%s/%d/%s" % [R, w, style, lod, paint.to_html()]
	if _cache.has(key): return _cache[key]
	var out := ArrayMesh.new()
	_append_mesh(out, right, Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO))
	_cache[key] = out
	return out

# ================================================================== cars
## One car description: the body's stations and the cabin's, the windows and the details. See _car.
## Station: [z, half width, bottom y, top y, corner radius].
static func _spec(name: String) -> Dictionary:
	match name:
		"car_hatch_a":
			return {"kind": "hatch", "L": 4.0, "W": 1.72, "H": 1.46, "wb": 2.46, "fo": 0.82, "R": 0.30, "tw": 0.185, "style": "alloy", "paint": Color(0.5, 0.52, 0.55),
				"belt": 0.93, "nose": 0.7, "hood": 0.9, "deck": 0.96, "sill": 0.2, "zws": -0.78, "zrf": -0.02, "zrr": 1.0, "zrg": 1.88, "roof": 1.46, "cond": 0.9}
		"car_hatch_b":
			return {"kind": "hatch", "L": 4.3, "W": 1.8, "H": 1.45, "wb": 2.64, "fo": 0.88, "R": 0.32, "tw": 0.205, "style": "alloy", "paint": Color(0.5, 0.06, 0.05),
				"belt": 0.96, "nose": 0.72, "hood": 0.94, "deck": 1.0, "sill": 0.19, "zws": -0.85, "zrf": 0.0, "zrr": 1.1, "zrg": 2.0, "roof": 1.45, "cond": 0.82}
		"car_estate_a":
			return {"kind": "estate", "L": 4.7, "W": 1.82, "H": 1.5, "wb": 2.8, "fo": 0.92, "R": 0.325, "tw": 0.215, "style": "alloy", "paint": Color(0.16, 0.2, 0.22),
				"belt": 0.98, "nose": 0.74, "hood": 0.96, "deck": 1.04, "sill": 0.2, "zws": -0.95, "zrf": -0.05, "zrr": 1.85, "zrg": 2.25, "roof": 1.5, "cond": 0.93}
		"pickup_a":
			return {"kind": "pickup", "L": 5.3, "W": 1.98, "H": 1.82, "wb": 3.2, "fo": 0.95, "R": 0.385, "tw": 0.265, "style": "alloy", "paint": Color(0.12, 0.18, 0.34),
				"belt": 1.2, "nose": 1.0, "hood": 1.2, "deck": 1.15, "sill": 0.32, "zws": -1.15, "zrf": -0.5, "zrr": 0.2, "zrg": 0.52, "roof": 1.82, "cond": 0.88}
		"pickup_b":
			return {"kind": "pickup", "L": 4.9, "W": 1.82, "H": 1.7, "wb": 3.0, "fo": 0.82, "R": 0.345, "tw": 0.235, "style": "steel", "paint": Color(0.62, 0.55, 0.4),
				"belt": 1.12, "nose": 0.94, "hood": 1.12, "deck": 1.06, "sill": 0.3, "zws": -1.0, "zrf": -0.42, "zrr": 0.22, "zrg": 0.5, "roof": 1.7, "cond": 0.45}
		"van_a":
			return {"kind": "van", "L": 5.3, "W": 1.98, "H": 2.1, "wb": 3.3, "fo": 0.95, "R": 0.34, "tw": 0.215, "style": "steel", "paint": Color(0.88, 0.88, 0.86),
				"belt": 1.12, "nose": 0.92, "hood": 1.15, "deck": 1.0, "sill": 0.3, "zws": -1.4, "zrf": -0.75, "zrr": 2.5, "zrg": 2.62, "roof": 2.1, "cond": 0.85}
		"van_b":
			return {"kind": "van", "L": 4.4, "W": 1.8, "H": 1.9, "wb": 2.78, "fo": 0.8, "R": 0.31, "tw": 0.195, "style": "steel", "paint": Color(0.18, 0.28, 0.45),
				"belt": 1.04, "nose": 0.84, "hood": 1.04, "deck": 1.0, "sill": 0.26, "zws": -1.05, "zrf": -0.5, "zrr": 2.05, "zrg": 2.15, "roof": 1.9, "cond": 0.8}
	return {}

## The profile of a station list at z: [half width, bottom y, top y, radius] by linear blending between the stations.
static func _at(st: Array, z: float) -> Array:
	if z <= st[0][0]: return [st[0][1], st[0][2], st[0][3], st[0][4]]
	for k in st.size() - 1:
		var a: Array = st[k]; var b: Array = st[k + 1]
		if z <= b[0]:
			var t: float = 0.0 if absf(float(b[0]) - float(a[0])) < 1e-6 else (z - float(a[0])) / (float(b[0]) - float(a[0]))
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t)]
	var l: Array = st[st.size() - 1]
	return [l[1], l[2], l[3], l[4]]

## One section of a body: a rounded top, a vertical side that tucks in at the sill, a flat underside. Points go round once.
static func _ring(hw: float, ya: float, yb: float, rr: float, n: int, inset: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.append(Vector2(-hw + inset, ya)); p.append(Vector2(-hw + inset, ya))
	p.append(Vector2(-hw, ya + inset * 1.6))
	for k in n + 1:
		var a := PI - PI * 0.5 * k / n
		p.append(Vector2(-hw + rr + rr * cos(a), yb - rr + rr * sin(a)))
	for k in n + 1:
		var a2 := PI * 0.5 - PI * 0.5 * k / n
		p.append(Vector2(hw - rr + rr * cos(a2), yb - rr + rr * sin(a2)))
	p.append(Vector2(hw, ya + inset * 1.6))
	p.append(Vector2(hw - inset, ya)); p.append(Vector2(hw - inset, ya))
	return p

## A shell skinned through stations, each a rounded top section. n: rounding steps.
static func _shell(st: Array, n: int, inset := 0.05) -> Array:
	var rows: Array = []
	for s: Array in st:
		var hw: float = s[1]; var ya: float = s[2]; var yb: float = s[3]
		var rr := minf(float(s[4]), minf((yb - ya) * 0.499, hw * 0.98))
		var ins := minf(inset, (yb - ya) * 0.2)
		var row := PackedVector3Array()
		for q in _ring(hw, ya, yb, maxf(rr, 0.002), n, ins): row.append(Vector3(q.x, q.y, float(s[0])))
		rows.append(row)
	return NewModels2._skin(rows)

static func _car(name: String, lod: int, paint: Color) -> Dictionary:
	var s := _spec(name)
	var kind: String = s["kind"]
	var L: float = s["L"]; var W: float = s["W"]; var R: float = s["R"]; var tw: float = s["tw"]
	var wb: float = s["wb"]; var zf: float = -L * 0.5 + float(s["fo"]); var zr := zf + wb
	var belt: float = s["belt"]; var roof: float = s["roof"]; var sill: float = s["sill"]
	var nose: float = s["nose"]; var hood: float = s["hood"]; var deck: float = s["deck"]
	var zws: float = s["zws"]; var zrf: float = s["zrf"]; var zrr: float = s["zrr"]; var zrg: float = s["zrg"]
	var cond: float = s["cond"]
	var pc: Color = s["paint"] if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, cond)
	var P := Parts.new()
	var nn: int = [4, 2, 1][lod]
	var hw := W * 0.5 - 0.045                                          # the body's half width; the tyres stand a little proud
	var fwd := -1.0
	# ---- the lower body: nose, hood, doors, tail
	var rear_top := deck
	var body: Array = []
	if kind == "pickup":
		var zc := zrg                                                   # the cab's back wall
		body = [[-L * 0.5, hw - 0.16, sill + 0.14, nose - 0.2, 0.1], [-L * 0.5 + 0.06, hw - 0.06, sill + 0.06, nose - 0.04, 0.14], [-L * 0.5 + 0.35, hw, sill, nose + 0.04, 0.16],
			[-L * 0.5 + 1.1, hw, sill, hood - 0.02, 0.18], [zws, hw, sill, hood, 0.18], [zws + 0.1, hw, sill, belt, 0.1], [zc, hw, sill, belt, 0.08], [zc + 0.02, hw, sill, belt - 0.02, 0.06]]
	elif kind == "van":
		body = [[-L * 0.5, hw - 0.16, sill + 0.14, nose - 0.2, 0.1], [-L * 0.5 + 0.06, hw - 0.06, sill + 0.06, nose - 0.04, 0.14], [-L * 0.5 + 0.35, hw, sill, nose + 0.06, 0.16],
			[zws - 0.4, hw, sill, hood - 0.02, 0.18], [zws, hw, sill, belt + 0.04, 0.12], [zws + 0.5, hw, sill, belt + 0.04, 0.08], [L * 0.5 - 0.06, hw, sill, belt + 0.04, 0.08],
			[L * 0.5 - 0.0, hw - 0.04, sill + 0.06, belt, 0.06]]
	else:
		body = [[-L * 0.5, hw - 0.17, sill + 0.14, nose - 0.2, 0.1], [-L * 0.5 + 0.07, hw - 0.07, sill + 0.06, nose - 0.04, 0.14], [-L * 0.5 + 0.34, hw - 0.01, sill, nose + 0.03, 0.15],
			[-L * 0.5 + 0.9, hw, sill, lerpf(nose, hood, 0.55), 0.16], [zws + 0.2, hw, sill, hood, 0.17], [zws + 0.45, hw, sill, belt, 0.1],
			[zrg - 0.05, hw, sill, belt + 0.01, 0.1], [L * 0.5 - 0.18, hw - 0.02, sill + 0.03, rear_top, 0.12], [L * 0.5 - 0.04, hw - 0.12, sill + 0.1, rear_top - 0.05, 0.1],
			[L * 0.5, hw - 0.2, sill + 0.16, rear_top - 0.12, 0.08]]
	_put(P, "paint", _shell(body, nn), I, pc)
	# ---- the cabin: windscreen, roof, rear glass (a loft; glass panels sit on it)
	var cab: Array = []
	var gw := hw - 0.05
	var cab_top := roof
	if kind == "pickup":
		cab = [[zws, gw, belt - 0.05, belt + 0.03, 0.02], [zrf, gw - 0.02, belt - 0.05, roof, 0.15], [zrr, gw - 0.02, belt - 0.05, roof - 0.01, 0.15], [zrg, gw, belt - 0.05, roof - 0.05, 0.12]]
	elif kind == "van":
		cab = [[zws, gw, belt - 0.05, belt + 0.1, 0.02], [zrf, gw - 0.01, belt - 0.05, roof - 0.05, 0.16], [zrr, gw - 0.01, belt - 0.05, roof, 0.14], [zrg, gw - 0.04, belt - 0.05, roof - 0.04, 0.1]]
	elif kind == "estate":
		cab = [[zws, gw, belt - 0.05, belt + 0.03, 0.02], [zrf, gw - 0.05, belt - 0.05, roof, 0.17], [zrr, gw - 0.05, belt - 0.05, roof - 0.01, 0.17], [zrg, gw - 0.04, belt - 0.05, belt + 0.1, 0.05]]
	else:
		cab = [[zws, gw, belt - 0.05, belt + 0.03, 0.02], [zrf, gw - 0.05, belt - 0.05, roof, 0.17], [zrr, gw - 0.05, belt - 0.05, roof - 0.02, 0.17], [zrg, gw - 0.04, belt - 0.05, belt + 0.1, 0.05]]
	_put(P, "paint", _shell(cab, nn), I, pc)
	# ---- the glass on the cabin: windscreen, rear glass and side windows (flat panels a hair proud of the cabin)
	var gl := Color(C_GLASS.r, C_GLASS.g, C_GLASS.b, 1.0)
	_cabin_glass(P, kind, cab, s, gl, hw)
	# ---- the wheels' dark arches on the body sides, shut lines, handles, mirrors
	var wheels: Array = []
	var hub_x := W * 0.5 - tw * 0.5
	for ax: Array in [[zf, true], [zr, false]]:
		for sx: float in [-1.0, 1.0]:
			wheels.append({"name": "wheel_%s%s" % ["f" if ax[1] else "r", "l" if sx < 0.0 else "r"], "pos": Vector3(sx * hub_x, R, float(ax[0])), "radius": R,
				"steer": bool(ax[1]), "mesh": wheel_side(R, tw, s["style"], lod, pc, sx < 0.0)})
			if lod < 2:
				var an := Vector3(sx, 0, 0)
				_disc(P, "trim", Vector3(sx * (hw + 0.004), R, float(ax[0])), an, R * 1.12, [28, 16, 8][lod], Color(0.015, 0.015, 0.018, 0.9))
				if lod == 0 or kind != "hatch":
					_annulus(P, "trim", Vector3(sx * (hw + 0.007), R, float(ax[0])), an, R * 1.12, R * 1.22, 28 if lod == 0 else 14, Color(0.05, 0.05, 0.055, 0.9))
	_car_details(P, kind, s, lod, pc, hw, zf, zr, cab)
	var size := Vector3(W, H(s), L)
	var cols: Array = [AABB(Vector3(-W * 0.5, sill, -L * 0.5), Vector3(W, belt - sill, L))]
	if kind == "pickup": cols.append(AABB(Vector3(-hw, belt, zws), Vector3(hw * 2.0, roof - belt, zrg - zws)))
	elif kind == "van": cols.append(AABB(Vector3(-hw, belt, zws), Vector3(hw * 2.0, roof - belt, L * 0.5 - zws)))
	else: cols.append(AABB(Vector3(-hw + 0.1, belt, zws), Vector3(hw * 2.0 - 0.2, roof - belt, zrg - zws)))
	return {"body": _finish(P), "wheels": wheels, "size": size, "wheel_radius": R, "track": hub_x * 2.0, "wheelbase": wb, "colliders": cols}

static func H(s: Dictionary) -> float:
	return float(s["H"])

## Glass panels on the cabin loft: windscreen, rear glass, side windows; paint pillars between them.
static func _cabin_glass(P: Parts, kind: String, cab: Array, s: Dictionary, gl: Color, hw: float) -> void:
	var belt: float = s["belt"]; var roof: float = s["roof"]
	var zws: float = s["zws"]; var zrf: float = s["zrf"]; var zrr: float = s["zrr"]; var zrg: float = s["zrg"]
	var A: Array = cab[0]; var B: Array = cab[1]; var C: Array = cab[2]; var D: Array = cab[3]
	var off := 0.005
	var tr: float = float(B[4]) * 0.8 + 0.025
	# windscreen: a quad on the slope from A (z = zws) to B
	var ta := 0.07; var tb := 0.93
	var pa: Array = _at(cab, lerpf(zws, zrf, ta)); var pb: Array = _at(cab, lerpf(zws, zrf, tb))
	var ya := lerpf(float(A[3]), float(B[3]), ta) - 0.01; var yb := lerpf(float(A[3]), float(B[3]), tb) - 0.015
	var za := lerpf(zws, zrf, ta); var zb := lerpf(zws, zrf, tb)
	var wa: float = float(pa[0]) - 0.05; var wb_: float = float(pb[0]) - float(pb[3]) * 0.55
	var slope := Vector3(0, yb - ya, zb - za)
	var nrm := Vector3(0, zb - za, -(yb - ya)).normalized()
	if nrm.y < 0.0: nrm = -nrm
	var o := nrm * off
	_qd(P, "glass", Vector3(-wa, ya, za) + o, Vector3(wa, ya, za) + o, Vector3(wb_, yb, zb) + o, Vector3(-wb_, yb, zb) + o, gl, nrm)
	# rear glass
	if kind == "van" or kind == "pickup":
		pass
	var rear_open := kind == "hatch" or kind == "estate"
	if rear_open:
		var t0 := 0.06; var t1 := 0.9
		var z0 := lerpf(zrr, zrg, t0); var z1 := lerpf(zrr, zrg, t1)
		var q0: Array = _at(cab, z0); var q1: Array = _at(cab, z1)
		var y0 := lerpf(float(C[3]), float(D[3]), t0) - 0.01; var y1 := lerpf(float(C[3]), float(D[3]), t1) + 0.0
		var n2 := Vector3(0, z1 - z0, maxf(y0 - y1, 0.02)).normalized()
		var o2 := n2 * off
		var wr0: float = float(q0[0]) - float(q0[3]) * 0.55; var wr1: float = float(q1[0]) - 0.07
		_qd(P, "glass", Vector3(-wr0, y0, z0) + o2, Vector3(-wr1, y1, z1) + o2, Vector3(wr1, y1, z1) + o2, Vector3(wr0, y0, z0) + o2, gl, n2)
	elif kind == "van":
		# the cab's rear window is the bulkhead: no glass. Rear doors carry their glass in _car_details.
		pass
	# side windows: polygons in (z, y) on the cabin's side wall
	for sx: float in [-1.0, 1.0]:
		var polys: Array = []
		if kind == "hatch" or kind == "estate":
			var zb1 := lerpf(zrf, zrr, 0.42)                                   # the B pillar
			var zc_end := lerpf(zrr, zrg, 0.55) if kind == "hatch" else lerpf(zrr, zrg, 0.8)
			polys.append([[zws + 0.34, belt + 0.045], [zb1 - 0.04, belt + 0.045], [zb1 - 0.04, roof - tr], [zrf + 0.14, roof - tr], [lerpf(zws, zrf, 0.6), belt + 0.5 * (roof - belt) - 0.0]])
			polys.append([[zb1 + 0.05, belt + 0.045], [zc_end, belt + 0.045], [zc_end - 0.1 if kind == "hatch" else zc_end - 0.04, belt + 0.26 if kind == "hatch" else roof - tr], [zrr - 0.02, roof - tr], [zb1 + 0.05, roof - tr]])
		elif kind == "pickup":
			var zb1 := lerpf(zrf, zrr, 0.4)
			polys.append([[zws + 0.28, belt + 0.045], [zb1 - 0.04, belt + 0.045], [zb1 - 0.04, roof - tr], [zrf + 0.1, roof - tr], [lerpf(zws, zrf, 0.55), lerpf(belt, roof, 0.4)]])
			polys.append([[zb1 + 0.05, belt + 0.045], [zrg - 0.2, belt + 0.045], [zrg - 0.2, roof - tr - 0.08], [zrr, roof - tr], [zb1 + 0.05, roof - tr]])
		elif kind == "van":
			polys.append([[zws + 0.25, belt + 0.12], [zrf + 0.5, belt + 0.12], [zrf + 0.5, roof - tr - 0.05], [zrf + 0.12, roof - tr - 0.05], [lerpf(zws, zrf, 0.55), lerpf(belt, roof, 0.45)]])
		for poly: Array in polys:
			var pts: Array[Vector3] = []
			for q: Array in poly:
				var pr: Array = _at(cab, float(q[0]))
				pts.append(Vector3(sx * (float(pr[0]) + off), float(q[1]), float(q[0])))
			var nn := Vector3(sx, 0, 0)
			var c := Vector3.ZERO
			for v in pts: c += v
			c /= pts.size()
			for k in pts.size():
				P.b("glass").tri(c, pts[k], pts[(k + 1) % pts.size()], gl, nn)

## Everything small: shut lines, handles, mirrors, lamps, grille, bumpers, plates, wipers, exhaust and so on.
static func _car_details(P: Parts, kind: String, s: Dictionary, lod: int, pc: Color, hw: float, zf: float, zr: float, cab: Array) -> void:
	if lod == 2:
		# far: just the bumpers as dark strips and lamps as dots so the silhouette reads
		var L2: float = s["L"]; var W2: float = s["W"]
		_bx(P, "trim", Vector3(0, 0.34, -L2 * 0.5 + 0.02), Vector3(W2 * 0.82, 0.16, 0.12), C_TRIM)
		_bx(P, "trim", Vector3(0, 0.36, L2 * 0.5 - 0.02), Vector3(W2 * 0.82, 0.16, 0.12), C_TRIM)
		return
	var L: float = s["L"]; var W: float = s["W"]; var belt: float = s["belt"]; var roof: float = s["roof"]; var sill: float = s["sill"]
	var nose: float = s["nose"]; var zws: float = s["zws"]; var zrf: float = s["zrf"]; var zrr: float = s["zrr"]; var zrg: float = s["zrg"]
	var tall := kind == "pickup" or kind == "van"
	# ---- front end
	var zn := -L * 0.5
	var hl_y := nose - 0.12
	var bumper_h := 0.26 if not tall else 0.32
	_rbx(P, "trim", Vector3(0, sill + 0.17 if not tall else sill + 0.2, zn + 0.05), Vector3(W * 0.9, bumper_h, 0.22), C_TRIM2, Basis.IDENTITY, 10)      # bumper
	var gr_w := 0.5 if not tall else 0.62
	_rbx(P, "trim", Vector3(0, nose - 0.14, zn + 0.045), Vector3(gr_w, 0.13 if not tall else 0.2, 0.1), C_TRIM, Basis.IDENTITY, 8)                       # grille
	for k in 3:
		_bx(P, "metal", Vector3(0, nose - 0.2 + k * 0.05, zn - 0.0), Vector3(gr_w - 0.04, 0.012, 0.01), C_ALU)
	for sx: float in [-1.0, 1.0]:
		var hx := gr_w * 0.5 + 0.26
		_rbx(P, "trim", Vector3(sx * hx, hl_y, zn + 0.11), Vector3(0.4, 0.13, 0.2), C_TRIM2, Basis(Vector3.UP, sx * 0.0), 8)
		_bx(P, "lens", Vector3(sx * hx, hl_y, zn + 0.015), Vector3(0.37, 0.095, 0.03), C_LENS)
		_bx(P, "metal", Vector3(sx * (hx + 0.06), hl_y, zn + 0.0), Vector3(0.1, 0.07, 0.01), C_CHROME)          # reflector
		_bx(P, "lens", Vector3(sx * (hx + 0.12), hl_y - 0.1, zn + 0.045), Vector3(0.09, 0.04, 0.03), C_AMBER)      # indicator
		# fog lamp
		_disc(P, "lens", Vector3(sx * (hx - 0.05), sill + 0.16, zn - 0.065), Vector3(0, 0, -1), 0.04, 10, C_LENS)
	# plate (blank)
	_bx(P, "sheet", Vector3(0, sill + 0.2, zn - 0.062), Vector3(0.52, 0.11, 0.008), Color(0.9, 0.88, 0.8, 1.0))
	# hood shut line
	# ---- tail
	var zt := L * 0.5
	var tl_y := (s["deck"] as float) - 0.18 if not tall else belt - 0.15
	if kind == "van": tl_y = belt - 0.2
	_rbx(P, "trim", Vector3(0, sill + 0.19, zt - 0.05), Vector3(W * 0.9, bumper_h, 0.22), C_TRIM2, Basis.IDENTITY, 10)
	for sx: float in [-1.0, 1.0]:
		var tx := W * 0.5 - 0.2
		var tz := zt - 0.015
		_bx(P, "lens", Vector3(sx * tx, tl_y, tz), Vector3(0.26, 0.2 if kind != "pickup" else 0.3, 0.04), C_RED)
		_bx(P, "lens", Vector3(sx * tx, tl_y - 0.13 if kind != "pickup" else tl_y - 0.18, tz + 0.0), Vector3(0.12, 0.05, 0.04), Color(0.8, 0.8, 0.8, 1.0))   # reverse
	_bx(P, "sheet", Vector3(0, sill + 0.4 if not tall else sill + 0.5, zt + 0.003), Vector3(0.52, 0.11, 0.008), Color(0.9, 0.88, 0.8, 1.0))
	_cyl(P, "metal", Vector3(W * 0.5 - 0.35, sill + 0.06, zt - 0.5), Vector3(W * 0.5 - 0.35, sill + 0.06, zt + 0.1), 0.026, 0.026, 8, C_ALU)       # exhaust
	# ---- shut lines (doors) and handles, mirrors
	var zdoor0 := zws + 0.4
	for sx: float in [-1.0, 1.0]:
		var xs := sx * (hw + 0.004)
		var dz: Array = [zdoor0, lerpf(zrf, zrr, 0.42), lerpf(zrr, zrg, 0.6) if not tall else zrg - 0.2]
		if kind == "van": dz = [zdoor0, zrf + 0.55]
		for z: float in dz:
			_bx(P, "trim", Vector3(xs, (sill + belt) * 0.5 + 0.04, z), Vector3(0.006, belt - sill - 0.04, 0.012), Color(0.03, 0.03, 0.035, 0.9))
		_bx(P, "trim", Vector3(xs, sill + 0.04, (dz[0] + dz[dz.size() - 1]) * 0.5), Vector3(0.006, 0.014, absf(dz[dz.size() - 1] - dz[0])), Color(0.03, 0.03, 0.035, 0.9))
		for z: float in [dz[0] + 0.22, dz[1] + 0.22 if dz.size() > 2 else dz[0] + 0.22]:
			_rbx(P, "metal", Vector3(xs + sx * 0.008, belt - 0.12, z), Vector3(0.02, 0.025, 0.13), Color(pc.r * 0.7, pc.g * 0.7, pc.b * 0.7, 0.9), Basis.IDENTITY, 8)
		var mz := zws + 0.35
		var mr := 0.03 if not tall else 0.07
		_bm(P, "trim", Vector3(sx * (hw - 0.02), belt + 0.05, mz), Vector3(sx * (hw + 0.14 + mr), belt + 0.11, mz - 0.08), 0.03, 0.025, C_TRIM)
		_rbx(P, "paint", Vector3(sx * (hw + 0.19 + mr), belt + 0.13, mz - 0.11), Vector3(0.12 + mr, 0.1 + mr * 0.6, 0.17 + mr), pc, Basis.IDENTITY, 10)
		_bx(P, "glass", Vector3(sx * (hw + 0.12 + mr), belt + 0.13, mz - 0.11 + 0.088 + mr * 0.5), Vector3(0.1, 0.085, 0.003), C_GLASS)
		_bx(P, "lens", Vector3(sx * (hw + 0.008), belt - 0.34, zws - 0.1), Vector3(0.012, 0.035, 0.07), C_AMBER)       # side repeater
	# ---- wipers at the foot of the windscreen
	var a_hw := _at(cab, zws + 0.12)
	for sx: float in [-1.0, 1.0]:
		var y0: float = float(a_hw[2]) - 0.025
		_bm(P, "trim", Vector3(sx * 0.1, y0 + 0.003, zws + 0.09), Vector3(sx * 0.62, y0 + 0.12, zws + 0.2), 0.012, 0.008, C_TRIM)
	# ---- the roof: a rail or aerial
	if kind == "estate":
		for sx: float in [-1.0, 1.0]:
			_bm(P, "metal", Vector3(sx * 0.58, roof + 0.0, zrf + 0.1), Vector3(sx * 0.58, roof + 0.0, zrr - 0.1), 0.03, 0.025, C_ALU)
	if kind == "hatch" or kind == "estate":
		_cyl(P, "trim", Vector3(0.45, roof - 0.03, zrr - 0.45), Vector3(0.45, roof + 0.2, zrr - 0.45), 0.006, 0.003, 6, C_TRIM)
	# ---- the rest by body type
	if kind == "pickup": _pickup_bed(P, s, lod, pc, hw)
	if kind == "van": _van_rear(P, s, lod, pc, hw)

## The open load bed of a pickup: floor, sides, tailgate, inner arches and a bumper step.
static func _pickup_bed(P: Parts, s: Dictionary, lod: int, pc: Color, hw: float) -> void:
	var L: float = s["L"]; var sill: float = s["sill"]; var zrg: float = s["zrg"]; var R: float = s["R"]; var zr := -L * 0.5 + float(s["fo"]) + float(s["wb"])
	var z0 := zrg + 0.03                                              # the cab's back wall
	var z1 := L * 0.5 - 0.08
	var top: float = float(s["deck"]) + 0.02
	var th := 0.07
	var cc := pc
	var bedc := Color(0.05, 0.05, 0.055, 0.9)
	_bx(P, "paint", Vector3(0, sill + 0.25, (z0 + z1) * 0.5), Vector3(hw * 2.0 - 0.08, 0.3, z1 - z0), pc)       # the underside block
	_bx(P, "trim", Vector3(0, top - 0.3 + 0.0, (z0 + z1) * 0.5), Vector3((hw - th) * 2.0, 0.02, z1 - z0 - th), bedc)       # liner floor
	for sx: float in [-1.0, 1.0]:
		_rbx(P, "paint", Vector3(sx * (hw - th * 0.5), (sill + 0.25 + top) * 0.5 + 0.06, (z0 + z1) * 0.5), Vector3(th, top - sill - 0.25 + 0.15, z1 - z0), pc, Basis.IDENTITY, 8)
		_bx(P, "trim", Vector3(sx * (hw - th - 0.012), top - 0.14, (z0 + z1) * 0.5), Vector3(0.008, 0.26, z1 - z0 - th * 2.0), bedc)    # liner wall
		# inner wheel housing humps
		_rbx(P, "paint", Vector3(sx * (hw - th - 0.12), top - 0.3 + 0.12, zr), Vector3(0.26, 0.28, 0.9), pc, Basis.IDENTITY, 8)
	_rbx(P, "paint", Vector3(0, (sill + 0.25 + top) * 0.5 + 0.06, z1), Vector3(hw * 2.0, top - sill - 0.25 + 0.15, th), pc, Basis.IDENTITY, 8)      # tailgate
	_bx(P, "trim", Vector3(0, top - 0.14, z0 + 0.02), Vector3((hw - th) * 2.0, 0.26, 0.01), bedc)                                   # bulkhead
	if lod == 0:
		_bx(P, "metal", Vector3(0, top + 0.02, z1 + th * 0.5 + 0.004), Vector3(0.32, 0.03, 0.01), C_ALU)           # tailgate handle strip
		_bx(P, "trim", Vector3(0, sill + 0.24, L * 0.5 - 0.03), Vector3(hw * 1.5, 0.05, 0.1), C_TRIM2)

## The back of a van: two doors with a split line, small windows on one variant, a step and the roof's rear lip.
static func _van_rear(P: Parts, s: Dictionary, lod: int, pc: Color, hw: float) -> void:
	var L: float = s["L"]; var sill: float = s["sill"]; var belt: float = s["belt"]; var roof: float = s["roof"]
	var zt := L * 0.5 + 0.004
	var dk := Color(0.03, 0.03, 0.035, 0.9)
	_bx(P, "trim", Vector3(0, (sill + roof) * 0.5 - 0.1, zt), Vector3(0.008, roof - sill - 0.5, 0.01), dk)
	for sx: float in [-1.0, 1.0]:
		_bx(P, "trim", Vector3(sx * (hw - 0.08), (sill + roof) * 0.5 - 0.1, zt), Vector3(0.008, roof - sill - 0.5, 0.01), dk)
		_bx(P, "metal", Vector3(sx * 0.05, belt + 0.1, zt + 0.006), Vector3(0.05, 0.14, 0.015), C_ALU)
		if (s["paint"] as Color).r > 0.8:
			_bx(P, "glass", Vector3(sx * 0.47, roof - 0.55, zt + 0.003), Vector3(0.78, 0.55, 0.004), C_GLASS)
	_bx(P, "trim", Vector3(0, 0.34, L * 0.5 + 0.04), Vector3(hw * 1.6, 0.06, 0.14), dk)
