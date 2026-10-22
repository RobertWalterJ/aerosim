class_name Osd
extends Control
## The drone's on-screen display, drawn over the video frame: top status bar (mode, GPS, link, battery, ISO and
## shutter), reticle, horizon and pitch ladder, flight-path marker, gimbal scale, bottom data bar (distance to home,
## height, altitude, speeds, wind), luma histogram and a compass radar. Ported from TelemetryOSD.ts.
## Fill `t` each frame (see main.gd) and set `frame` to the video frame's rectangle on screen.

var t := {}
var frame := Rect2(0, 0, 1280, 720)
var show_osd := true
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["SF Mono", "Menlo", "Consolas", "DejaVu Sans Mono", "monospace"])
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_font = f

func _process(_d: float) -> void:
	queue_redraw()

func _s(x) -> String:
	return str(x)

func _draw() -> void:
	if not show_osd or t.is_empty(): return
	var x0 := frame.position.x
	var y0 := frame.position.y
	var w := frame.size.x
	var h := frame.size.y
	var u := maxf(0.6, minf(w / 1280.0, h / 720.0))
	draw_set_transform(Vector2(x0, y0), 0.0, Vector2.ONE)
	var m := 18.0 * u
	var white := Color(1, 1, 1)
	# ---- top bar
	draw_rect(Rect2(0, 0, w, 36 * u), Color(0, 0, 0, 0.28))
	var mode: String = t["mode"]
	var mcol := Color("88ffff") if mode == "N" else (Color("ffcc66") if mode == "S" else (Color("ff88ff") if mode == "A" else Color("ff8888")))
	var ml := 54.0 * u   # clear of the back button
	draw_rect(Rect2(ml, 8 * u, 26 * u, 20 * u), mcol, false, 1.6 * u)
	_text(mode, Vector2(ml + 13 * u, 24 * u), 15 * u, mcol, 1, true)
	var armed: bool = t["armed"]
	var status := "DISARMED"
	if armed: status = {"A": "AEROBATIC", "M": "MANUAL", "S": "SPORT", "N": "NORMAL"}.get(mode, "NORMAL")
	elif str(t["crashed"]) != "": status = str(t["crashed"])
	_text(status, Vector2(ml + 36 * u, 24 * u), 13 * u, white if armed else Color("ff6666"))
	var gx := w * 0.30
	_text("GPS", Vector2(gx, 24 * u), 13 * u, white)
	_bars(Vector2(gx + 34 * u, 24 * u), u, int(round(float(t["sats"]) / 4.0)), Color("77ff77"))
	_text(_s(int(t["sats"])), Vector2(gx + 66 * u, 24 * u), 13 * u, white)
	var rx := w * 0.43
	var bars: int = t["rfBars"]
	_text("RF", Vector2(rx, 24 * u), 13 * u, white)
	_bars(Vector2(rx + 22 * u, 24 * u), u, bars, Color("ff6666") if bars <= 1 else Color("77ff77"))
	_text("%d dBm" % int(round(float(t["rfDbm"]))), Vector2(rx + 52 * u, 24 * u), 13 * u, white)
	var bx := w * 0.60
	var pct: float = t["battPct"]
	var bc := Color("ff6666") if pct < 20.0 else (Color("ffcc66") if pct < 40.0 else white)
	draw_rect(Rect2(bx, 12 * u, 28 * u, 14 * u), bc, false, 1.5 * u)
	draw_rect(Rect2(bx + 2 * u, 14 * u, 24 * u * pct / 100.0, 10 * u), bc)
	draw_rect(Rect2(bx + 28 * u, 15 * u, 2 * u, 8 * u), bc)
	_text("%d%%  %.2fV/c  %.1fA" % [int(round(pct)), float(t["cellV"]), float(t["battA"])], Vector2(bx + 38 * u, 24 * u), 13 * u, white)
	var ev: float = t["ev"]
	_text("ISO %d  1/%d  EV %s%.1f" % [int(t["iso"]), int(round(1.0 / float(t["shutter"]))), "+" if ev >= 0.0 else "", ev], Vector2(w - 54 * u, 24 * u), 13 * u, white, 2)
	# ---- reticle, horizon and pitch ladder
	var cx := w / 2.0
	var cy := h / 2.0
	var rc := Color(1, 1, 1, 0.9)
	for seg in [[Vector2(-14, 0), Vector2(-4, 0)], [Vector2(4, 0), Vector2(14, 0)], [Vector2(0, -14), Vector2(0, -4)], [Vector2(0, 4), Vector2(0, 14)]]:
		draw_line(Vector2(cx, cy) + seg[0] * u, Vector2(cx, cy) + seg[1] * u, rc, 1.5 * u)
	draw_set_transform(Vector2(x0 + cx, y0 + cy), -float(t["roll"]), Vector2.ONE)
	var ppd := 5.2 * u
	var cam_pitch := rad_to_deg(float(t["pitch"]))
	for a in range(-40, 41, 10):
		var yy := (cam_pitch - a) * ppd * -1.0
		if absf(yy) > 105.0 * u: continue
		var ln := 120.0 if a == 0 else 34.0
		var col := Color(1, 1, 1, 0.95 if a == 0 else 0.55)
		draw_line(Vector2(-ln * u, yy), Vector2(-10 * u, yy), col, 1.5 * u)
		draw_line(Vector2(10 * u, yy), Vector2(ln * u, yy), col, 1.5 * u)
		if a != 0: _text(_s(a), Vector2(-ln * u - 6 * u, yy + 3 * u), 10 * u, white, 2)
	draw_set_transform(Vector2(x0, y0), 0.0, Vector2.ONE)
	# flight-path marker
	var vb: Vector3 = t["velBody"]
	var sp := sqrt(vb.x * vb.x + vb.z * vb.z)
	if sp > 0.8:
		var fx := clampf((vb.x / maxf(sp, 1.0)) * minf(1.0, sp / 12.0) * 120.0, -140.0, 140.0) * u
		var fy := clampf((-vb.y / maxf(sp, 4.0)) * 90.0, -100.0, 100.0) * u
		var p := Vector2(cx + fx, cy + fy)
		var gc := Color("88ff88")
		draw_arc(p, 6 * u, 0, TAU, 20, gc, 1.5 * u)
		draw_line(p + Vector2(-12 * u, 0), p + Vector2(-6 * u, 0), gc, 1.5 * u)
		draw_line(p + Vector2(6 * u, 0), p + Vector2(12 * u, 0), gc, 1.5 * u)
		draw_line(p + Vector2(0, -6 * u), p + Vector2(0, -12 * u), gc, 1.5 * u)
	# ---- gimbal scale on the right edge
	var sx := w - 26 * u
	var sy0 := h * 0.28
	var sy1 := h * 0.72
	draw_line(Vector2(sx, sy0), Vector2(sx, sy1), white, 1.2 * u)
	for a in range(20, -91, -10):
		var yy := sy0 + (20.0 - a) / 110.0 * (sy1 - sy0)
		draw_line(Vector2(sx - (8 if a % 30 == 0 else 4) * u, yy), Vector2(sx, yy), white, 1.2 * u)
		if a % 30 == 0 or a == 20: _text(_s(a), Vector2(sx - 12 * u, yy + 3 * u), 10 * u, white, 2)
	var gdeg: float = t["gimbalDeg"]
	var gy := sy0 + (20.0 - gdeg) / 110.0 * (sy1 - sy0)
	var gcol := Color("ff6666") if float(t["stopHit"]) != 0.0 else Color("ffe14d")
	draw_colored_polygon(PackedVector2Array([Vector2(sx + 2 * u, gy), Vector2(sx + 11 * u, gy - 5 * u), Vector2(sx + 11 * u, gy + 5 * u)]), gcol)
	_text("%d°" % int(round(gdeg)), Vector2(sx + 6 * u, sy1 + 18 * u), 12 * u, Color("ffe14d"), 1, true)
	# ---- bottom bar
	draw_rect(Rect2(0, h - 56 * u, w, 56 * u), Color(0, 0, 0, 0.30))
	var items := [
		["H", "%d m" % int(round(float(t["homeDist"])))],
		["AGL", "%.1f m" % float(t["aglM"])],
		["MSL", "%d m" % int(round(float(t["mslM"])))],
		["H.S", "%.1f m/s  %d km/h" % [float(t["gs"]), int(round(float(t["gs"]) * 3.6))]],
		["V.S", "%s%.1f m/s" % ["+" if float(t["vs"]) >= 0.0 else "", float(t["vs"])]],
		["WIND", "%.1f m/s %s" % [float(t["windMs"]), str(t.get("windLevel", ""))]],
	]
	var bxp := m
	for it in items:
		_text(it[0], Vector2(bxp, h - 34 * u), 11 * u, Color("bbccdd"))
		_text(it[1], Vector2(bxp, h - 14 * u), 17 * u, white, 0, true)
		bxp += _font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * u)).x + 34 * u
	# ---- histogram and radar compass
	var hx := w - 214 * u
	var hy := h - 150 * u
	var hw := 180 * u
	var hh := 70 * u
	draw_rect(Rect2(hx, hy, hw, hh), Color(0, 0, 0, 0.38))
	var hist: PackedFloat32Array = t["histogram"]
	var hmax := 0.0001
	for v in hist: hmax = maxf(hmax, v)
	for i in hist.size():
		var bh := pow(hist[i] / hmax, 0.6) * (hh - 6 * u)
		draw_rect(Rect2(hx + 2 * u + i * (hw - 4 * u) / 64.0, hy + hh - 3 * u - bh, (hw - 4 * u) / 64.0 - 0.4 * u, bh), Color(1, 1, 1, 0.85))
	_text("LUMA", Vector2(hx + 4 * u, hy + 11 * u), 9 * u, Color("99ffbb"))
	var rcx := w - 78 * u
	var rcy := h - 232 * u
	var rr := 38 * u
	draw_arc(Vector2(rcx, rcy), rr, 0, TAU, 40, Color(1, 1, 1, 0.8), 1.3 * u)
	draw_arc(Vector2(rcx, rcy), rr * 0.5, 0, TAU, 32, Color(1, 1, 1, 0.4), 1.3 * u)
	var heading: float = t["heading"]
	var ncol := Color("ff8888")
	var np := Vector2(rcx, rcy) + Vector2(sin(-heading), -cos(-heading)) * (rr - 11 * u)
	_text("N", np + Vector2(0, 3 * u), 10 * u, ncol, 1)
	draw_set_transform(Vector2(x0 + rcx, y0 + rcy), 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -9 * u), Vector2(6 * u, 7 * u), Vector2(0, 3 * u), Vector2(-6 * u, 7 * u)]), Color("77eeff"))
	var hb := float(t["homeBearing"]) - heading
	draw_circle(Vector2(sin(hb), -cos(hb)) * rr * 0.72, 4 * u, Color("ffcc44"))
	draw_set_transform(Vector2(x0, y0), 0.0, Vector2.ONE)
	# ---- left info and warnings
	var info := [str(t["lensName"]), str(t["airframe"]), "AUDIO: %s" % str(t["audio"]), "%d fps sensor" % int(t["fps"])]
	for i in info.size(): _text(info[i], Vector2(m + 70 * u, 62 * u + i * 16 * u), 12 * u, Color(1, 1, 1, 0.85))
	var mission: Array = t.get("mission", [])
	for i in mission.size(): _text(str(mission[i]), Vector2(m + 70 * u, 62 * u + 84 * u + i * 17 * u), 13 * u, Color("ffe14d") if i == 0 else white, 0, true)
	if str(t.get("aero", "")) != "": _text(str(t["aero"]), Vector2(cx, 62 * u), 13 * u, Color("ff88ff"), 1, true)
	if str(t["crashed"]) != "":
		_text(str(t["crashed"]).to_upper(), Vector2(cx, cy - 60 * u), 30 * u, Color("ff5555"), 1, true)
		_text("TAP RESET" if bool(t.get("touch", false)) else "PRESS R TO RESET", Vector2(cx, cy - 34 * u), 15 * u, white, 1)
	if str(t.get("rec", "")) != "" and int(Time.get_ticks_msec() / 500) % 2 == 0:
		draw_circle(Vector2(w - 150 * u, 58 * u), 5 * u, Color("ff3333"))
		_text(str(t["rec"]), Vector2(w - 140 * u, 62 * u), 13 * u, Color("ff6666"))
	if float(t["rfDbm"]) < -85.0: _text("VIDEO LINK WEAK", Vector2(cx, 70 * u), 16 * u, Color("ff7766"), 1, true)
	if pct < 15.0: _text("LOW BATTERY - LAND NOW", Vector2(cx, 92 * u), 16 * u, Color("ff7766"), 1, true)

func _bars(origin: Vector2, u: float, on: int, col: Color) -> void:
	for i in 5:
		var bh := (4 + i * 3) * u
		draw_rect(Rect2(origin.x + i * 5 * u, origin.y - bh, 3 * u, bh), col if i < on else Color(1, 1, 1, 0.3))

## align: 0 left, 1 centre, 2 right
func _text(s: String, p: Vector2, size: float, col: Color, align := 0, bold := false) -> void:
	var fs := int(round(size))
	var wid := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := p
	if align == 1: pos.x -= wid * 0.5
	elif align == 2: pos.x -= wid
	draw_string(_font, pos + Vector2(1.2, 1.2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.55))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if bold: draw_string(_font, pos + Vector2(0.6, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
