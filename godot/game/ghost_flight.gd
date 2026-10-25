class_name GhostFlight
extends Node3D
## After the end card the tablet loses its feed, the HUD drops away, and the pilot drifts through the valley as a
## ghost. There is no damage, no battery and no collision. After a minute or two a warm glow appears over the body and
## the drone in the cemetery; a click draws the soul back in and hands control to the normal post-story walk.

signal finished

const GHOST_TIME := 90.0
const REVEAL_TIME := 6.0
const SPEED := 34.0
const BOOST := 2.6

var active := false
var _debug := false
var _t := 0.0
var _fade := 1.0
var _revealed := false
var _clicked := false
var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _yaw := 0.0
var _pitch := -0.08
var _main_cam: Camera3D
var _cam: Camera3D
var _vp: SubViewport
var _view: TextureRect
var _overlay: CanvasLayer
var _glitch: ColorRect
var _black: ColorRect
var _hud_text: Label
var _prompt: Label
var _body: Node3D
var _drone: Node3D
var _glow: OmniLight3D
var _glow_mesh: MeshInstance3D
var _beam: MeshInstance3D
var _terrain: Terrain

func setup(t: Terrain) -> void:
	_terrain = t
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.own_world_3d = false
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 88.0
	_cam.near = 0.03
	_cam.far = 26000.0
	_cam.current = true
	_vp.add_child(_cam)
	_build_body()
	_build_overlay()

func begin(main_cam: Camera3D, from_pos: Vector3, from_yaw: float, debug_fast := false) -> void:
	active = true
	_debug = debug_fast
	_t = 0.0
	_revealed = false
	_clicked = false
	_main_cam = main_cam
	_pos = from_pos + Vector3(0.0, 72.0, 118.0)
	_yaw = from_yaw
	_pitch = -0.24
	_vel = Vector3.ZERO
	_fade = 1.0
	_cam.current = true
	_cam.global_position = _pos
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	_body.visible = false
	_drone.visible = false
	_glow.visible = false
	_glow_mesh.visible = false
	_beam.visible = false
	_prompt.visible = false
	_hud_text.visible = true
	_overlay.visible = true
	if _black != null:
		_black.visible = true
		_black.color.a = 1.0
		var tw := create_tween()
		tw.tween_property(_black, "color:a", 0.0, 1.8)
		tw.tween_callback(func(): _black.visible = false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("ghost flight: begin cam=", (_cam != null), " current=", (_cam.current if _cam != null else false), " viewcam=", get_viewport().get_camera_3d(), " pos=", _pos)

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish += fwd
	if Input.is_key_pressed(KEY_S):
		wish -= fwd
	if Input.is_key_pressed(KEY_D):
		wish += right
	if Input.is_key_pressed(KEY_A):
		wish -= right
	if Input.is_key_pressed(KEY_SPACE):
		wish += Vector3.UP
	if Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL):
		wish -= Vector3.UP
	var speed := SPEED * (BOOST if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_vel = _vel.lerp(wish.normalized() * speed if wish.length_squared() > 0.0 else Vector3.ZERO, 1.0 - exp(-delta * 3.2))
	_pos += _vel * delta
	_cam.global_position = _pos
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	_cam.fov = lerpf(_cam.fov, 88.0 + clampf(_vel.length() * 0.22, 0.0, 12.0), 1.0 - exp(-delta * 2.0))
	if _revealed and _glow != null:
		_glow.light_energy = 6.5 + 1.2 * sin(_t * 2.2)
	_fade = minf(1.0, _fade + delta * 0.5)
	if _glitch != null and _glitch.material is ShaderMaterial:
		(_glitch.material as ShaderMaterial).set_shader_parameter("fade", _fade)
		(_glitch.material as ShaderMaterial).set_shader_parameter("intensity", 0.28 + 0.20 * sin(_t * 0.7))
	if _hud_text != null:
		_hud_text.modulate.a = clampf(1.0 - _t / 7.0, 0.0, 1.0)
	if not _revealed and _t >= (REVEAL_TIME if _debug else GHOST_TIME):
		_reveal()

func _reveal() -> void:
	_revealed = true
	_body.visible = true
	_drone.visible = true
	_glow.visible = true
	_glow.light_energy = 7.0
	_glow_mesh.visible = true
	_beam.visible = true
	_prompt.visible = true
	_prompt.text = "CLICK TO WAKE"
	# bring the ghost to a quiet overlook of the cemetery, so the body and its light are actually readable
	var bp := _body.global_position
	_pos = bp + Vector3(7.0, 4.5, 14.0)
	_vel = Vector3.ZERO
	var to_body := bp + Vector3(0.0, 1.2, 0.0) - _pos
	_yaw = atan2(-to_body.x, -to_body.z)
	_pitch = atan2(to_body.y, Vector2(to_body.x, to_body.z).length())
	if _hud_text != null:
		_hud_text.text = "A LIGHT IN THE CEMETERY"
		_hud_text.modulate.a = 1.0
	print("ghost flight: reveal at ", _body.position)

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * 0.0028
		_pitch = clampf(_pitch - event.relative.y * 0.0022, -1.35, 1.35)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _revealed:
		_finish()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _revealed:
		_finish()

func _finish() -> void:
	if _clicked:
		return
	_clicked = true
	active = false
	_overlay.visible = false
	_body.visible = false
	_drone.visible = false
	_glow.visible = false
	_glow_mesh.visible = false
	_beam.visible = false
	_cam.current = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit()

func debug_wake() -> void:
	_revealed = true
	_finish()

func debug_overlay_visible(on: bool) -> void:
	if _overlay != null:
		_overlay.visible = on

func wake_position() -> Vector3:
	return _body.global_position if _body != null else Vector3(-12.0, 0.0, 45.0)

func _build_body() -> void:
	var spot := Vector3(-12.0, 0.0, 45.0)
	# kept clear of planting by CaseObjects.near_evidence(GHOST_BODY_SPOT)
	if _terrain != null:
		spot.y = _terrain.height(spot.x, spot.z)
	_body = Node3D.new()
	_body.position = spot
	_body.rotation.y = 0.35
	add_child(_body)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.22, 0.24, 0.17)
	cloth.roughness = 0.95
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.48, 0.30, 0.20)
	skin.roughness = 0.8
	# A body lying on its side: simple, low-detail, seen from a respectful distance.
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.24
	tm.height = 1.12
	torso.mesh = tm
	torso.material_override = cloth
	torso.rotation.z = PI * 0.5
	torso.position = Vector3(0.0, 0.28, 0.0)
	_body.add_child(torso)
	var mat := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(2.3, 0.12, 1.0)
	mat.mesh = mm
	var mat_cloth := StandardMaterial3D.new()
	mat_cloth.albedo_color = Color(0.72, 0.28, 0.14)
	mat_cloth.roughness = 0.95
	mat.material_override = mat_cloth
	mat.position = Vector3(0.0, 0.07, 0.0)
	_body.add_child(mat)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0.62, 0.25, 0.02)
	_body.add_child(head)
	for sx in [-0.22, 0.22]:
		var leg := MeshInstance3D.new()
		var lm := CapsuleMesh.new()
		lm.radius = 0.08
		lm.height = 0.82
		leg.mesh = lm
		leg.material_override = cloth
		leg.rotation.z = PI * 0.5
		leg.position = Vector3(-0.78, 0.18, sx)
		_body.add_child(leg)
	# The little drone beside the body.
	_drone = Node3D.new()
	_drone.position = spot + Vector3(2.0, 0.0, 0.3)
	_drone.rotation.y = -0.3
	add_child(_drone)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.09, 0.10)
	dark.metallic = 0.4
	dark.roughness = 0.45
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.10, 0.42)
	body.mesh = bm
	body.material_override = dark
	body.position.y = 0.10
	_drone.add_child(body)
	for sx in [-0.28, 0.28]:
		for sz in [-0.28, 0.28]:
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(0.28, 0.03, 0.03)
			arm.mesh = am
			arm.material_override = dark
			arm.position = Vector3(sx * 0.55, 0.12, sz * 0.55)
			arm.rotation.y = atan2(sz, sx)
			_drone.add_child(arm)
			var rotor := MeshInstance3D.new()
			var rm := CylinderMesh.new()
			rm.top_radius = 0.11
			rm.bottom_radius = 0.11
			rm.height = 0.012
			rotor.mesh = rm
			rotor.material_override = dark
			rotor.position = Vector3(sx * 0.55, 0.15, sz * 0.55)
			_drone.add_child(rotor)
	# A warm beacon over the body: visible from the other side of the valley at the reveal.
	_glow = OmniLight3D.new()
	_glow.position = spot + Vector3(0.0, 2.1, 0.0)
	_glow.light_color = Color(1.0, 0.72, 0.38)
	_glow.light_energy = 0.0
	_glow.omni_range = 38.0
	_glow.visible = false
	add_child(_glow)
	_glow_mesh = MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.32
	gm.height = 0.64
	_glow_mesh.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.78, 0.42, 0.9)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.62, 0.22)
	gmat.emission_energy_multiplier = 6.0
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.no_depth_test = true
	_glow_mesh.material_override = gmat
	_glow_mesh.position = spot + Vector3(0.0, 2.1, 0.0)
	_glow_mesh.scale = Vector3(1.25, 1.25, 1.25)
	_glow_mesh.visible = false
	add_child(_glow_mesh)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.10
	beam_mesh.bottom_radius = 0.32
	beam_mesh.height = 20.0
	_beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.68, 0.28, 0.18)
	beam_mat.emission_enabled = true
	beam_mat.emission = Color(1.0, 0.60, 0.20)
	beam_mat.emission_energy_multiplier = 2.5
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.no_depth_test = true
	_beam.material_override = beam_mat
	_beam.position = spot + Vector3(0.0, 10.0, 0.0)
	_beam.visible = false
	add_child(_beam)

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 61
	_overlay.visible = false
	add_child(_overlay)
	_view = TextureRect.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.texture = _vp.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_view)
	_glitch = ColorRect.new()
	_glitch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/ghost_glitch.gdshader")
	_glitch.material = mat
	_overlay.add_child(_glitch)
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_black)
	_hud_text = Label.new()
	_hud_text.text = "SIGNAL LOST  ·  RECONNECTING"
	_hud_text.position = Vector2(34, 32)
	_hud_text.add_theme_font_size_override("font_size", 18)
	_hud_text.add_theme_color_override("font_color", Color(0.72, 0.92, 0.90, 0.9))
	_overlay.add_child(_hud_text)
	_prompt = Label.new()
	_prompt.text = "CLICK TO WAKE"
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-180, 220)
	_prompt.custom_minimum_size = Vector2(360, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.84, 0.48))
	_prompt.visible = false
	_overlay.add_child(_prompt)
