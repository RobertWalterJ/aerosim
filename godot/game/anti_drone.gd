class_name AntiDrone
extends Node3D
## Harlan Pike's anti-drone ridge (session B, story hazard). Pike is a freeman-on-the-land who does not appear in the
## chat himself: Rennick, Riley and Alex know of him. His jammer mast and its hunter drones keep the player away from
## the abandoned cabin until the last flight. When the jammer mast goes down, the hunters are still up and the player has
## to fly fast enough to outrun them.
##
## This is scenery and pressure, not a gun game. Nothing here hurts the player or ends the story; a hit puts the drone
## back at the launch site so the flight can be tried again.

signal forced_return(reason: String)

const SAVE := "user://anti_drone.cfg"
const JAMMER_SPOT := Vector2(-260.0, -807.0)
const JAMMER_RADIUS := 235.0
const SHOTGUN_RADIUS := 92.0
const SHOTGUN_AGL := 15.0
const HUNTER_SPEED := 13.2
const HUNTER_RANGE := 280.0
const LASER_RANGE := 118.0
const LASER_HOLD := 58.0

var hud: Hud
var chat: ChatData
var notes: PhoneNotes
var story: StoryArc
var director: StoryDirector
var finale: Finale
var quad
var terrain: Terrain
var jammer_down := false
var intro_done := false
var _return_cd := 0.0
var _jammer_grace := 0.0
var _shot_grace := 0.0
var _warn_t := 0.0
var _warn_next := -99.0
var _t := 0.0
var _beacon: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _hunters: Array = []
var _warn_layer: CanvasLayer
var _warn_label: Label
var _warn_panel: PanelContainer
var _laser_line: MeshInstance3D
var _laser_mat: StandardMaterial3D
var _blind: LaserBlind
var _laser_charge := 0.0
var _blind_cd := 0.0
var _laser_warned := false

func setup(h: Hud, c: ChatData, n: PhoneNotes, st: StoryArc, d: StoryDirector, f: Finale, q, t: Terrain) -> void:
	hud = h
	chat = c
	notes = n
	story = st
	director = d
	finale = f
	quad = q
	terrain = t
	_load()
	_build_site()
	_build_warning()
	_build_laser()
	if jammer_down:
		_set_beacon(false)

func update(delta: float) -> void:
	_t += delta
	_return_cd = maxf(_return_cd - delta, 0.0)
	_jammer_grace = maxf(_jammer_grace - delta, 0.0)
	_shot_grace = maxf(_shot_grace - delta, 0.0)
	_warn_t = maxf(_warn_t - delta, 0.0)
	if _warn_t <= 0.0 and _warn_panel != null:
		_warn_panel.visible = false
	if _beacon != null and not jammer_down:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		if _beacon_mat != null:
			_beacon_mat.emission_energy_multiplier = 1.2 + pulse * 2.0
	_maybe_introduce()
	if quad == null or not quad.armed:
		_jammer_grace = 0.0
		_shot_grace = 0.0
		return
	var p: Vector3 = quad.position()
	var flat := Vector2(p.x, p.z)
	var dist := flat.distance_to(JAMMER_SPOT)
	_update_laser(delta, p, flat, dist)
	if not jammer_down and dist < JAMMER_RADIUS:
		if _t - _warn_next > 3.0:
			_warn("HARLAN PIKE JAMMER   ·   LINK FAILING", 2.8)
			_warn_next = _t
		_jammer_grace += delta
		if _jammer_grace > 2.6:
			_force_return("jammer")
			return
	else:
		_jammer_grace = 0.0
	if finale != null and finale.started and not finale.ended:
		_update_hunters(delta)
		var agl: float = p.y - terrain.height(p.x, p.z)
		if agl < SHOTGUN_AGL and flat.distance_to(JAMMER_SPOT) < SHOTGUN_RADIUS:
			if _t - _warn_next > 2.5:
				_warn("PIKE ON THE RIDGE   ·   GET UP", 2.4)
				_warn_next = _t
			_shot_grace += delta
			if _shot_grace > 2.2:
				_force_return("shotgun")
				return
		else:
			_shot_grace = 0.0
	_update_hunter_idle(delta)

func jammer_down_now() -> void:
	if jammer_down:
		return
	jammer_down = true
	_set_beacon(false)
	if _laser_line != null:
		_laser_line.visible = false
	_laser_charge = 0.0
	if _blind != null:
		_blind.visible = false
	_save()
	if hud != null and hud.story_mode:
		chat.post("town", "Rennick", "Pike's jammer mast came down in the storm last night. The north frequency is clear. His hunter drones are still flying. Keep high and keep moving.", false)
		chat.post("town", "Riley", "If you go north, go fast. The hunters are slow to turn but they are patient.", false)
		chat.post("tech", "Alex", "The jammer is off. You will have a signal. Do not stop to look at the cabin.", false)
		notes.post_text("Rennick", "The north is open", "Pike's jammer is down. The hunter drones are still up. Keep high and fast, and do not stop.", 1)
		hud.toast("Rennick: Pike jammer is down. Keep high and fast.", true, "DRONEBUDZ")

func debug_laser_burn() -> void:
	if _blind != null:
		_blind.burn(2.2, 1.0)

func _build_laser() -> void:
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.albedo_color = Color(1.0, 0.04, 0.02)
	_laser_mat.emission_enabled = true
	_laser_mat.emission = Color(1.0, 0.02, 0.01)
	_laser_mat.emission_energy_multiplier = 5.0
	_laser_mat.no_depth_test = true
	_laser_line = MeshInstance3D.new()
	_laser_line.mesh = ImmediateMesh.new()
	_laser_line.material_override = _laser_mat
	_laser_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_line.visible = false
	add_child(_laser_line)
	_blind = LaserBlind.new()
	add_child(_blind)

func _update_laser(delta: float, drone_p: Vector3, flat: Vector2, dist: float) -> void:
	_blind_cd = maxf(_blind_cd - delta, 0.0)
	if _laser_line == null:
		return
	if jammer_down or quad == null or not quad.armed or dist > LASER_RANGE:
		_laser_charge = 0.0
		_laser_line.visible = false
		return
	_laser_charge += delta
	_laser_line.visible = true
	var from := Vector3(JAMMER_SPOT.x, terrain.height(JAMMER_SPOT.x, JAMMER_SPOT.y) + 22.0, JAMMER_SPOT.y)
	var to := drone_p
	var im := _laser_line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES, _laser_mat)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	if _laser_charge > 0.30 and _blind_cd <= 0.0:
		_blind_cd = 3.2
		if _blind != null:
			_blind.burn(2.2, 1.0)
		if not _laser_warned:
			_laser_warned = true
			_warn("PIKE LASER   Â·   CAMERA BURN", 2.8)
		if hud != null:
			hud.toast("Pike laser is on the camera. Break line of sight.", true, "LINK")
	if dist < LASER_HOLD and _laser_charge > 2.2:
		_force_return("laser")

func _maybe_introduce() -> void:
	if intro_done or hud == null or not hud.story_mode or story == null:
		return
	if director == null or director.act_number() < 2:
		return
	intro_done = true
	_save()
	chat.post("town", "Rennick", "Before you go north: the ridge past the camp belongs to Harlan Pike. He calls himself a freeman on the land. He has written a manifesto about the county having no jurisdiction over his ridge, and he has been warned off three investigations.", false)
	chat.post("town", "Riley", "He is not a monster. He is a man with a bad fence and a worse pamphlet. He also has a jammer mast, a shotgun and at least two drone hunters. Do not buzz his place.", false)
	chat.post("tech", "Alex", "I read the manifesto. It is mostly about fences, fees and the county. The jammer is real. If your link drops up there, turn back.", false)
	notes.post_text("Rennick", "Harlan Pike", "The north ridge belongs to Harlan Pike. He has a jammer mast, a shotgun and hunter drones. Do not cross the north line until I say.", 1)
	_warn("NORTH RIDGE   ·   PIKE JAMMER ACTIVE", 4.0)

func _update_hunters(delta: float) -> void:
	var p: Vector3 = quad.position()
	for h in _hunters:
		var node: Node3D = h["node"]
		var vel: Vector3 = h["vel"]
		var d := node.global_position.distance_to(p)
		if d < HUNTER_RANGE:
			var want := (p - node.global_position).normalized() * HUNTER_SPEED
			vel = vel.lerp(want, clampf(delta * 0.85, 0.0, 1.0))
			node.look_at(p, Vector3.UP)
			if d < 2.9 and _return_cd <= 0.0:
				_force_return("hunter")
				return
		else:
			var home: Vector3 = h["home"]
			vel = vel.lerp((home - node.global_position).normalized() * 4.0, clampf(delta * 0.5, 0.0, 1.0))
		node.global_position += vel * delta
		var gy := terrain.height(node.global_position.x, node.global_position.z) + 9.0 + sin(_t * 1.7 + float(h["phase"])) * 1.1
		node.global_position.y = maxf(node.global_position.y, gy)
		h["vel"] = vel
		if node.global_position.distance_to(Vector3(JAMMER_SPOT.x, terrain.height(JAMMER_SPOT.x, JAMMER_SPOT.y) + 20.0, JAMMER_SPOT.y)) > 360.0:
			node.global_position = h["home"]

func _update_hunter_idle(_delta: float) -> void:
	if finale != null and finale.started:
		return
	for h in _hunters:
		var node: Node3D = h["node"]
		if node != null:
			node.rotate_y(0.25 * _delta)

func _force_return(reason: String) -> void:
	if _return_cd > 0.0:
		return
	_return_cd = 5.0
	forced_return.emit(reason)

func _warn(text: String, seconds: float) -> void:
	if _warn_panel == null:
		return
	_warn_label.text = text
	_warn_panel.visible = true
	_warn_t = seconds

func _build_warning() -> void:
	_warn_layer = CanvasLayer.new()
	_warn_layer.layer = 29
	add_child(_warn_layer)
	_warn_panel = PanelContainer.new()
	_warn_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warn_panel.offset_left = -260.0
	_warn_panel.offset_right = 260.0
	_warn_panel.offset_top = 58.0
	_warn_panel.offset_bottom = 100.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.04, 0.03, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.86, 0.28, 0.22, 0.9)
	_warn_panel.add_theme_stylebox_override("panel", sb)
	_warn_label = UniverseUI.label("", 12, Color(0.98, 0.76, 0.62))
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warn_panel.add_child(_warn_label)
	_warn_panel.visible = false
	_warn_layer.add_child(_warn_panel)

func _build_site() -> void:
	var root := Node3D.new()
	root.position = Vector3(JAMMER_SPOT.x, terrain.height(JAMMER_SPOT.x, JAMMER_SPOT.y), JAMMER_SPOT.y)
	add_child(root)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.11)
	dark.roughness = 0.9
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.34, 0.18, 0.11)
	rust.roughness = 0.85
	# the trailer
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 0.7, 5.0)
	base.mesh = bm
	base.material_override = rust
	base.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(base)
	var wheel := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.38; wm.bottom_radius = 0.38; wm.height = 0.28
	wheel.mesh = wm
	wheel.material_override = dark
	wheel.rotation.z = PI * 0.5
	wheel.position = Vector3(-1.75, 0.38, 1.3)
	root.add_child(wheel)
	var wheel2 := wheel.duplicate() as MeshInstance3D
	wheel2.position = Vector3(1.75, 0.38, 1.3)
	root.add_child(wheel2)
	# mast
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.07; mm.bottom_radius = 0.18; mm.height = 24.0
	mast.mesh = mm
	mast.material_override = dark
	mast.position = Vector3(0.0, 12.5, -0.7)
	root.add_child(mast)
	var dish := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 1.05; dm.height = 1.1
	dish.mesh = dm
	dish.material_override = rust
	dish.scale = Vector3(1.0, 0.45, 1.0)
	dish.position = Vector3(0.0, 24.5, -0.7)
	root.add_child(dish)
	_beacon = MeshInstance3D.new()
	var bm2 := SphereMesh.new()
	bm2.radius = 0.30; bm2.height = 0.60
	_beacon.mesh = bm2
	_beacon_mat = StandardMaterial3D.new()
	_beacon_mat.albedo_color = Color(0.9, 0.18, 0.12)
	_beacon_mat.emission_enabled = true
	_beacon_mat.emission = Color(0.95, 0.12, 0.08)
	_beacon_mat.emission_energy_multiplier = 2.5
	_beacon.material_override = _beacon_mat
	_beacon.position = Vector3(0.0, 24.5, -0.7)
	root.add_child(_beacon)
	# notice board
	var board := MeshInstance3D.new()
	var bbm := BoxMesh.new()
	bbm.size = Vector3(2.4, 1.4, 0.12)
	board.mesh = bbm
	board.material_override = rust
	board.position = Vector3(3.2, 1.2, 1.4)
	root.add_child(board)
	var plate := Label3D.new()
	plate.text = "THE UNBOUND VALLEY\nNO COUNTY. NO DRONES."
	plate.font_size = 48
	plate.modulate = Color(0.94, 0.88, 0.70)
	plate.outline_size = 0
	plate.position = Vector3(3.2, 1.25, 1.47)
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	root.add_child(plate)
	# the hunter drones
	for i in 3:
		var a := TAU * float(i) / 3.0
		var home := Vector3(JAMMER_SPOT.x + cos(a) * 58.0, terrain.height(JAMMER_SPOT.x, JAMMER_SPOT.y) + 22.0, JAMMER_SPOT.y + sin(a) * 58.0)
		_make_hunter(home, i)

func _make_hunter(home: Vector3, i: int) -> void:
	var node := Node3D.new()
	node.position = home
	add_child(node)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.11, 0.10)
	dark.metallic = 0.3
	dark.roughness = 0.5
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.16, 0.78)
	body.mesh = bm
	body.material_override = dark
	node.add_child(body)
	for j in 4:
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.035; am.bottom_radius = 0.035; am.height = 0.95
		arm.mesh = am
		arm.material_override = dark
		arm.rotation = Vector3(0.0, TAU * float(j) / 4.0 + PI * 0.25, PI * 0.5)
		arm.position = Vector3(cos(TAU * float(j) / 4.0 + PI * 0.25) * 0.42, 0.05, sin(TAU * float(j) / 4.0 + PI * 0.25) * 0.42)
		node.add_child(arm)
		var rotor := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.24; rm.bottom_radius = 0.24; rm.height = 0.025
		rotor.mesh = rm
		rotor.material_override = dark
		rotor.position = Vector3(cos(TAU * float(j) / 4.0 + PI * 0.25) * 0.86, 0.12, sin(TAU * float(j) / 4.0 + PI * 0.25) * 0.86)
		node.add_child(rotor)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.09; em.height = 0.18
	eye.mesh = em
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.85, 0.12, 0.08)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.95, 0.10, 0.06)
	eye_mat.emission_energy_multiplier = 2.0
	eye.material_override = eye_mat
	eye.position = Vector3(0.0, 0.02, 0.42)
	node.add_child(eye)
	_hunters.append({"node": node, "vel": Vector3.ZERO, "home": home, "phase": float(i) * 2.1})

func _set_beacon(on: bool) -> void:
	if _beacon_mat == null:
		return
	_beacon_mat.albedo_color = Color(0.9, 0.18, 0.12) if on else Color(0.14, 0.14, 0.13)
	_beacon_mat.emission_energy_multiplier = 2.5 if on else 0.0

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	intro_done = bool(cf.get_value("pike", "intro", false))
	jammer_down = bool(cf.get_value("pike", "jammer_down", false))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pike", "intro", intro_done)
	cf.set_value("pike", "jammer_down", jammer_down)
	cf.save(SAVE)

func stats() -> Dictionary:
	return {"intro": intro_done, "jammer_down": jammer_down, "hunters": _hunters.size()}
