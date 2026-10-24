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
var _scale_panel: PanelContainer

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
	_badge.text = "  THERMAL CAMERA  ·  T  "
	_badge.add_theme_font_size_override("font_size", 16)
	_badge.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	_badge.position = Vector2(18, 16)
	add_child(_badge)
	_build_scale()

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
	if _scale_panel != null:
		_scale_panel.visible = on

func _build_scale() -> void:
	_scale_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.025, 0.04, 0.82)
	sb.border_color = Color(0.86, 0.70, 0.42, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	_scale_panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_scale_panel.add_child(col)
	var title := Label.new()
	title.text = "WHITE-HOT  ·  RELATIVE SCALE"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.62))
	col.add_child(title)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	col.add_child(bar)
	var swatches := [
		["AIR 8", Color(0.06, 0.02, 0.18)],
		["GROUND 12", Color(0.36, 0.04, 0.20)],
		["BODY 37", Color(1.0, 0.82, 0.22)],
		["ENGINE 90+", Color(1.0, 0.96, 0.72)],
	]
	for s in swatches:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(74, 0)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(70, 7)
		var sc: Color = s[1]
		sw.color = sc
		cell.add_child(sw)
		var lab := Label.new()
		lab.text = str(s[0])
		lab.add_theme_font_size_override("font_size", 9)
		lab.add_theme_color_override("font_color", Color(0.90, 0.88, 0.78))
		cell.add_child(lab)
		bar.add_child(cell)
	_scale_panel.visible = false
	add_child(_scale_panel)
	var vp := get_viewport().get_visible_rect().size
	_scale_panel.position = Vector2(vp.x * 0.5 - 160.0, vp.y - 220.0)
func toggle() -> void:
	if installed:
		set_on(not _on)
