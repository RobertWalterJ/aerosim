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

func get_gain() -> float:
	return _gain

func toggle() -> void:
	set_on(not _on)
