class_name LaserBlind
extends CanvasLayer
## Pike's laser dazzler. It is a camera-feed effect only: a red-white burn over the video, below the HUD, so the
## instruments stay readable while the pilot loses the picture. It fades out after a short burn.

var _rect: ColorRect
var _t := 0.0
var _duration := 0.0
var _strength := 0.0
var _peak := 0.0

func _ready() -> void:
	layer = 9
	visible = false
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_rect)

func burn(duration := 2.0, strength := 1.0) -> void:
	_duration = maxf(duration, 0.2)
	_strength = clampf(strength, 0.2, 1.0)
	_peak = _strength
	_t = 0.0
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var k := clampf(_t / maxf(_duration * 0.08, 0.03), 0.0, 1.0)
	var fade := clampf(1.0 - (_t - _duration * 0.62) / maxf(_duration * 0.38, 0.05), 0.0, 1.0)
	var a := _peak * k * fade
	# A camera dazzler is not a red tint: at peak the whole feed is gone, white with only a warm afterimage.
	_rect.color = Color(1.0, 0.96, 0.88, a)
	if _t >= _duration:
		visible = false
		_rect.color = Color(0, 0, 0, 0)

func is_burning() -> bool:
	return visible
