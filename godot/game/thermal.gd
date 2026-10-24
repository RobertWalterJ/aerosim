class_name ThermalCamera
extends CanvasLayer
## The thermal camera that Alex fits to the drone for the last search (session B finale).
##
## A screen-space false-colour pass over the world, plus a thermal signature on Wren that only becomes visible while
## the camera is on. The HUD stays above it, so the pilot keeps the normal instruments while the world below turns into
## a heat image. Installed by the finale, toggled with T.

var installed := false
var _on := false
var _rect: ColorRect
var _badge: Label

func _ready() -> void:
	layer = 9
	visible = false
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.size = get_viewport().get_visible_rect().size
	_rect.position = Vector2.ZERO
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/thermal.gdshader")
	_rect.material = mat
	add_child(_rect)
	_badge = Label.new()
	_badge.text = "  THERMAL CAMERA  "
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	_badge.position = Vector2(18, 16)
	add_child(_badge)

func install() -> void:
	installed = true

func is_installed() -> bool:
	return installed

func is_on() -> bool:
	return _on

func set_on(on: bool) -> void:
	if not installed:
		return
	_on = on
	visible = on

func toggle() -> void:
	if installed:
		set_on(not _on)
