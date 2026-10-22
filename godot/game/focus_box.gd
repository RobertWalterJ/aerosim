extends Control
## Focus marks drawn on the video picture, like a drone app:
##  - the focus box, which comes up while the lens is acquiring: white while hunting, green with a short settle once
##    focus locks, then it fades away (autofocus carries on unseen at the centre);
##  - quiet corner marks that follow a subject the pilot tapped, for as long as it is held in focus;
##  - a small AF or MF chip at the top of the picture with the focus distance. Tapping it lets go of a held subject.
## It only draws; taps arrive through TouchSticks.tapped and SensorPipeline.focus_tap.

const HUNT := Color(1.0, 1.0, 1.0)
const LOCK := Color(0.42, 0.95, 0.5)

var pipe: Node                      # the SensorPipeline
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	queue_redraw()

func _at(r: Rect2, uv: Vector2) -> Vector2:
	return r.position + Vector2((uv.x * 0.5 + 0.5) * r.size.x, (0.5 - uv.y * 0.5) * r.size.y)

func _corners(c: Vector2, half: float, arm: float, col: Color, lw: float) -> void:
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var p := c + Vector2(sx * half, sy * half)
			draw_line(p, p - Vector2(sx * arm, 0), col, lw)
			draw_line(p, p - Vector2(0, sy * arm), col, lw)

func _draw() -> void:
	if pipe == null or not pipe.focus_shown: return
	var r: Rect2 = pipe.frame_rect()
	var lw := maxf(1.5, r.size.y * 0.0028)
	var half0 := 0.09 * r.size.y
	# a held subject: thin, faint corner marks that follow it
	if pipe.subject_held:
		var sc := _at(r, pipe.subject_uv)
		_corners(sc + Vector2(1, 1), half0 * 0.75, half0 * 0.28, Color(0, 0, 0, 0.25), lw)
		_corners(sc, half0 * 0.75, half0 * 0.28, Color(1, 1, 1, 0.42), lw)
	# the focus box while acquiring
	var alpha: float = pipe.box_alpha
	if alpha > 0.01:
		var c := _at(r, pipe.box_uv)
		var col := HUNT
		var scale := 1.0
		if pipe.focus_locked:
			var e := clampf(float(pipe.focus_lock_age) / 0.22, 0.0, 1.0)
			scale = lerpf(1.16, 1.0, 1.0 - (1.0 - e) * (1.0 - e))     # eases in to its locked size
			col = LOCK
		else:
			scale = 1.06 + 0.04 * sin(Time.get_ticks_msec() * 0.018)    # hunting: a slight restless pulse
		var half := half0 * scale
		var cc := Color(col.r, col.g, col.b, 0.95 * alpha)
		var tl := c - Vector2(half, half)
		draw_rect(Rect2(tl + Vector2(1, 1), Vector2(half, half) * 2.0), Color(0, 0, 0, 0.35 * alpha), false, lw)
		draw_rect(Rect2(tl, Vector2(half, half) * 2.0), Color(cc.r, cc.g, cc.b, 0.5 * alpha), false, lw)
		_corners(c, half, half * 0.32, cc, lw * 1.8)
		if not pipe.focus_locked: draw_circle(c, lw * 1.3, cc)
	# the chip: AF or MF and the distance
	var chip: Rect2 = pipe.chip_rect()
	var fs := int(clampf(r.size.y * 0.024, 11.0, 18.0))
	var manual: bool = pipe.manual_focus
	var label := "MF" if manual else "AF"
	var d: float = pipe.focus_m
	var dist := "∞" if d >= 300.0 else ("%.1f m" % d if d < 10.0 else "%d m" % int(round(d)))
	if pipe.subject_held: dist = "Subject " + dist
	var tag_w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.7
	var dist_w := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := tag_w + fs * 0.45 + dist_w + fs * 0.5
	var x0 := chip.position.x + chip.size.x * 0.5 - total * 0.5
	var y0 := chip.position.y
	var h := chip.size.y
	draw_rect(Rect2(Vector2(x0, y0), Vector2(total, h)), Color(0.02, 0.04, 0.05, 0.38), true)
	var tag_col := LOCK if (pipe.focus_locked and not manual) else Color(1, 1, 1)
	draw_rect(Rect2(Vector2(x0, y0), Vector2(tag_w, h)), Color(tag_col.r, tag_col.g, tag_col.b, 0.85), true)
	var base := y0 + h * 0.5 + fs * 0.36
	draw_string(_font, Vector2(x0 + fs * 0.35, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.07, 0.08))
	var tx := Vector2(x0 + tag_w + fs * 0.45, base)
	draw_string(_font, tx + Vector2(1, 1), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(_font, tx, dist, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
