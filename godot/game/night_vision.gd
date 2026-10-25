class_name NightVision
extends CanvasLayer
## The night vision camera add-on bought on Facade (session B). A green low-light pass over the world, under the HUD,
## toggled with K when the module is owned. It is an image intensifier, not true thermal.

var _on := false
var _rect: ColorRect
var _mat: ShaderMaterial
var _gain := 1.0

func _ready() -> void:
	layer = 8
	visible = false
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.size = get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/night_vision.gdshader")
	_mat = mat
	_rect.material = mat
	add_child(_rect)
	set_gain(1.0)

func is_on() -> bool:
	return _on

func set_on(on: bool) -> void:
	_on = on
	visible = on

func set_gain(g: float) -> void:
	_gain = clampf(g, 0.6, 5.0)
	if _mat != null:
		_mat.set_shader_parameter("gain", _gain)

func set_scene(sensor: Object, moon_light: float, night_dark: float) -> void:
	if _mat == null:
		return
	var uvs := PackedVector2Array()
	var ks := PackedFloat32Array()
	var cs := PackedVector3Array()
	if sensor != null and sensor.has_method("burst_uvs"):
		for b in sensor.burst_uvs():
			uvs.append(b["uv"])
			ks.append(float(b["k"]))
			var c: Color = b["c"]
			cs.append(Vector3(c.r, c.g, c.b))
	while uvs.size() < 4:
		uvs.append(Vector2(0.5, 0.5))
		ks.append(0.0)
		cs.append(Vector3.ZERO)
	_mat.set_shader_parameter("burst_uv", uvs)
	_mat.set_shader_parameter("burst_k", ks)
	_mat.set_shader_parameter("burst_c", cs)
	_mat.set_shader_parameter("burst_wash", sensor.burst_wash() if sensor != null and sensor.has_method("burst_wash") else 0.0)
	_mat.set_shader_parameter("moon_light", clampf(moon_light, 0.0, 1.0))
	_mat.set_shader_parameter("night_dark", clampf(night_dark, 0.0, 1.0))

func get_gain() -> float:
	return _gain

func toggle() -> void:
	set_on(not _on)
