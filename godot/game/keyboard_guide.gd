class_name KeyboardGuide
extends Control
## A picture of the keyboard with the keys AeroSim uses lit up and named, grouped by colour:
## blue flies the drone (the left thumb stick), amber moves it (the right thumb stick), green runs the camera,
## violet is everything else. Drawn in code, so it always matches what the keys really do.

const BLUE := Color(0.45, 0.82, 1.0)
const AMBER := Color(1.0, 0.78, 0.36)
const GREEN := Color(0.52, 0.9, 0.55)
const VIOLET := Color(0.78, 0.65, 1.0)
const KEY_BG := Color(0.13, 0.15, 0.19)
const KEY_EDGE := Color(0.30, 0.34, 0.42)

# rows of [label, width in key units, caption, colour (or null for an unused key)]
var _rows: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 470)
	resized.connect(func(): custom_minimum_size = Vector2(0, 7.7 * minf(maxf(size.x, 300.0) / 15.2, 62.0)))
	var n := func(t: String, w := 1.0) -> Array: return [t, w, "", null]
	var k := func(t: String, cap: String, c: Color, w := 1.0) -> Array: return [t, w, cap, c]
	_rows = [
		[k.call("Esc", "Menu", VIOLET, 1.5), n.call(" ", 12.0)],
		[n.call("`"), n.call("1"), n.call("2"), n.call("3"), n.call("4"), n.call("5"), n.call("6"), n.call("7"), n.call("8"), n.call("9"), n.call("0"),
			k.call("-", "Dark", GREEN), k.call("=", "Bright", GREEN), n.call("Bksp", 1.6)],
		[k.call("Tab", "Phone", VIOLET, 1.5), k.call("Q", "Cam up", GREEN), k.call("W", "Climb", BLUE), k.call("E", "Cam dn", GREEN), k.call("R", "Reset", VIOLET), k.call("T", "Thermal", GREEN), n.call("Y"), n.call("U"), n.call("I"), n.call("O"), n.call("P"), n.call("["), n.call("]"), n.call("\\", 1.1)],
		[n.call("Caps", 1.8), k.call("A", "Turn L", BLUE), k.call("S", "Descend", BLUE), k.call("D", "Turn R", BLUE), n.call("F"), k.call("G", "Gallery", VIOLET), k.call("H", "Overlay", VIOLET), k.call("J", "Jobs", VIOLET), k.call("K", "Night", GREEN), k.call("L", "Lens", GREEN), n.call(";"), n.call("'"), n.call("Enter", 1.7)],
		[n.call("Shift", 2.3), n.call("Z"), n.call("X"), k.call("C", "Camera", GREEN), k.call("V", "Sound", VIOLET), n.call("B"), k.call("N", "Alerts", VIOLET), k.call("M", "Mode", VIOLET), n.call(","), n.call("."), n.call("/"), n.call("Shift", 2.2)],
	]

func _draw() -> void:
	if size.x < 200.0: return
	var font := ThemeDB.fallback_font
	var unit := minf(size.x / 15.2, 62.0)
	var gap := unit * 0.07
	var left := (size.x - unit * 14.6) * 0.5
	var y := 4.0
	for row in _rows:
		var x := left
		for key in row:
			var w: float = key[1] * unit
			var col = key[3]
			if str(key[0]) == " ":
				x += w; continue
			var r := Rect2(x + gap, y + gap, w - gap * 2.0, unit - gap * 2.0)
			if col == null:
				draw_rect(r, Color(KEY_BG.r, KEY_BG.g, KEY_BG.b, 0.55))
				draw_rect(r, Color(KEY_EDGE.r, KEY_EDGE.g, KEY_EDGE.b, 0.35), false, 1.0)
				draw_string(font, r.position + Vector2(0, r.size.y * 0.62), str(key[0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(unit * 0.28), Color(0.55, 0.6, 0.68, 0.6))
			else:
				var c: Color = col
				draw_rect(r, Color(c.r * 0.28, c.g * 0.28, c.b * 0.28, 1.0))
				draw_rect(r, c, false, 2.0)
				draw_string(font, r.position + Vector2(0, r.size.y * 0.5), str(key[0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(unit * 0.36), Color.WHITE)
				draw_string(font, r.position + Vector2(0, r.size.y * 0.86), str(key[2]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(unit * 0.185), c)
			x += w
		y += unit
	# arrow keys, below the main block on the right
	var ax := left + unit * 11.4
	var ay := y + unit * 0.35
	var arrows := [["^", "Forward", Vector2(1, 0)], ["<", "Lean left", Vector2(0, 1)], ["v", "Back", Vector2(1, 1)], [">", "Lean right", Vector2(2, 1)]]
	for a in arrows:
		var p: Vector2 = a[2]
		var r := Rect2(ax + p.x * unit + gap, ay + p.y * unit + gap, unit - gap * 2.0, unit - gap * 2.0)
		draw_rect(r, Color(AMBER.r * 0.28, AMBER.g * 0.28, AMBER.b * 0.28, 1.0))
		draw_rect(r, AMBER, false, 2.0)
		draw_string(font, r.position + Vector2(0, r.size.y * 0.5), str(a[0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(unit * 0.4), Color.WHITE)
		draw_string(font, r.position + Vector2(0, r.size.y * 0.86), str(a[1]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(unit * 0.17), AMBER)
	# the legend, bottom left
	var lx := left
	var ly := ay + unit * 0.35
	var items := [[BLUE, "Fly: climb, descend, turn (left stick)"], [AMBER, "Move: forward, back, lean (right stick)"], [GREEN, "Camera: tilt, lens, brightness, view"], [VIOLET, "Menu, reset, sound, flight mode, overlay"]]
	for it in items:
		var c: Color = it[0]
		draw_rect(Rect2(lx, ly, unit * 0.34, unit * 0.34), c)
		draw_string(font, Vector2(lx + unit * 0.5, ly + unit * 0.3), str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, unit * 8.5, int(unit * 0.26), Color(0.9, 0.93, 0.97))
		ly += unit * 0.5
