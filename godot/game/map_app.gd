class_name MapApp
extends Control
## The valley map app (session B): the pilot's road map and launch-site selector. It shows the roads, the cemetery,
## the lake and the unlocked launch sites, suggests a site for the current story beat, and lets the player drive the
## kit to another site while the drone is on the ground. The move is implied: the map shows the distance and drive
## time, the game repositions the launch pad and says where the kit was unpacked.

signal travel_requested(site_id: String)

var hud: Hud
var roads: Roads
var sites: LaunchSites
var story: StoryArc
var wildlife: WildlifeCase
var finale: Finale
var _map: MapCanvas
var _current: Label
var _suggestion: Label
var _status: Label
var _list: VBoxContainer

func setup(h: Hud, r: Roads, s: LaunchSites, st: StoryArc, w: WildlifeCase, f: Finale) -> void:
	hud = h
	roads = r
	sites = s
	story = st
	wildlife = w
	finale = f
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UniverseUI.make_theme()
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.045, 0.055, 0.048, 1.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UniverseUI.DEEP
	hsb.border_width_bottom = 3
	hsb.border_color = UniverseUI.AMBER
	head.add_theme_stylebox_override("panel", hsb)
	col.add_child(head)
	var hm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 20)
	head.add_child(hm)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 14)
	hm.add_child(hrow)
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(54, 54)
	mark.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.MOSS.darkened(0.25), 14, UniverseUI.MOSS, 1, 0.0, 0.0))
	var ml := UniverseUI.label("MAP", 15, UniverseUI.CREAM)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(ml)
	hrow.add_child(mark)
	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_theme_constant_override("separation", 1)
	hrow.add_child(tcol)
	tcol.add_child(UniverseUI.label("HALLOWAY  ·  FLIGHT MAP", 10, UniverseUI.AMBER))
	tcol.add_child(UniverseUI.label("Where the kit is parked", 22, UniverseUI.CREAM))
	_current = UniverseUI.label("", 12, UniverseUI.CREAM_DIM)
	tcol.add_child(_current)
	_suggestion = UniverseUI.label("", 11, UniverseUI.MOSS)
	tcol.add_child(_suggestion)
	_status = UniverseUI.label("", 11, UniverseUI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tcol.add_child(_status)
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + m, 18)
	col.add_child(body)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	body.add_child(hb)
	var map_panel := PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.NIGHT, 16, UniverseUI.LINE, 1, 0.0, 0.0))
	hb.add_child(map_panel)
	_map = MapCanvas.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(480, 360)
	map_panel.add_child(_map)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(330, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	hb.add_child(side)
	side.add_child(UniverseUI.label("LAUNCH SITES", 10, UniverseUI.AMBER))
	side.add_child(UniverseUI.label("Drive the kit, then unpack", 16, UniverseUI.CREAM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

func set_status(text: String, error := false) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", UniverseUI.RUST if error else UniverseUI.MUTED)

func refresh() -> void:
	if sites == null:
		return
	var active := sites.current()
	var suggested := _suggested_id()
	_current.text = "KIT PARKED AT  ·  " + str(active["name"]).to_upper()
	_suggestion.text = ("SUGGESTED FOR THE CASE  ·  " + sites.name(suggested).to_upper()) if suggested != "" and suggested != sites.active_id else "The valley is yours. Pick a place to unpack."
	_map.set_data(roads, sites, sites.active_id, suggested)
	for c in _list.get_children():
		c.queue_free()
	var ordered: Array = []
	ordered.append(active)
	for s in sites.list():
		var sid := str(s["id"])
		if sid == str(active["id"]):
			continue
		if sid == suggested:
			ordered.append(s)
	for s in sites.list():
		var sid2 := str(s["id"])
		if sid2 == str(active["id"]) or sid2 == suggested:
			continue
		ordered.append(s)
	for s in ordered:
		var id := str(s["id"])
		var card := PanelContainer.new()
		var accent := UniverseUI.AMBER if id == sites.active_id else (UniverseUI.MOSS if id == suggested else UniverseUI.LINE)
		card.add_theme_stylebox_override("panel", UniverseUI.card(12, UniverseUI.CARD, accent, 1))
		_list.add_child(card)
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 9)
		card.add_child(m)
		var cc := VBoxContainer.new()
		cc.add_theme_constant_override("separation", 2)
		m.add_child(cc)
		var top := HBoxContainer.new()
		cc.add_child(top)
		var nm := UniverseUI.label(str(s["name"]), 14, UniverseUI.CREAM)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		if id == sites.active_id:
			top.add_child(UniverseUI.label("CURRENT", 9, UniverseUI.AMBER))
		elif id == suggested:
			top.add_child(UniverseUI.label("SUGGESTED", 9, UniverseUI.MOSS))
		var note := UniverseUI.label(str(s["note"]), 10, UniverseUI.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cc.add_child(note)
		var ap: Vector2 = active["pos"]
		var sp: Vector2 = s["pos"]
		var dist := sites.distance_m(ap, sp)
		var meta := UniverseUI.label("%.1f km  ·  about %d min by road" % [dist / 1000.0, sites.drive_minutes(ap, sp)], 10, UniverseUI.CREAM_DIM)
		cc.add_child(meta)
		var btn := Button.new()
		btn.text = "You are here" if id == sites.active_id else "Drive here"
		btn.theme_type_variation = "Ghost" if id == sites.active_id else "Primary"
		btn.custom_minimum_size = Vector2(0, 30)
		btn.disabled = id == sites.active_id
		btn.pressed.connect(func(): travel_requested.emit(id))
		cc.add_child(btn)

func _suggested_id() -> String:
	if sites == null:
		return ""
	if finale != null and story != null and story.case_closed():
		return "cabin_track"
	if wildlife != null and wildlife.started and not wildlife.completed():
		return "farm"
	if story != null and story.started:
		match story.chapter:
			0: return "lake"
			1: return "garage"
			2: return "camp"
			3: return "camp"
			4: return "festival"
			5: return "festival"
	return "home"

## A schematic map drawn from the actual road paths, the cemetery outline and the site pins. It is not the live camera
## map; it is the road atlas the pilot uses to decide where to leave the car.
class MapCanvas extends Control:
	var roads: Roads
	var sites: LaunchSites
	var active_id := "home"
	var suggested_id := ""
	var _bounds := Rect2(-540, -1180, 1100, 1560)

	func set_data(r: Roads, s: LaunchSites, a: String, sug: String) -> void:
		roads = r
		sites = s
		active_id = a
		suggested_id = sug
		queue_redraw()

	func _w2m(p: Vector2) -> Vector2:
		var pad := 20.0
		var avail := size - Vector2(pad * 2.0, pad * 2.0)
		var sx := avail.x / _bounds.size.x
		var sy := avail.y / _bounds.size.y
		var k := minf(sx, sy)
		var ox := (size.x - _bounds.size.x * k) * 0.5
		var oy := (size.y - _bounds.size.y * k) * 0.5
		return Vector2(ox + (p.x - _bounds.position.x) * k, oy + (p.y - _bounds.position.y) * k)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.09, 0.072))
		# faint 100 m grid
		var gx := -500.0
		while gx <= 400.0:
			draw_line(_w2m(Vector2(gx, -1180)), _w2m(Vector2(gx, 560)), Color(0.15, 0.17, 0.13, 0.35), 1.0)
			gx += 100.0
		var gz := -1100.0
		while gz <= 300.0:
			draw_line(_w2m(Vector2(-540, gz)), _w2m(Vector2(560, gz)), Color(0.15, 0.17, 0.13, 0.35), 1.0)
			gz += 100.0
		# lake shape: the western basin, approximated for the road atlas
		var lake_pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			lake_pts.append(_w2m(Vector2(-650.0 + cos(a) * 230.0, 20.0 + sin(a) * 460.0)))
		draw_colored_polygon(lake_pts, Color(0.16, 0.28, 0.32, 0.75))
		var lake_closed := lake_pts.duplicate()
		lake_closed.append(lake_pts[0])
		draw_polyline(lake_closed, Color(0.36, 0.52, 0.56, 0.5), 1.2)
		# cemetery boundary
		var c0 := _w2m(Vector2(-238, -238))
		var c1 := _w2m(Vector2(238, 238))
		draw_rect(Rect2(c0, c1 - c0), Color(0.25, 0.32, 0.22, 0.35), true)
		draw_rect(Rect2(c0, c1 - c0), Color(0.58, 0.66, 0.48, 0.7), false, 1.2)
		# the village, east of the park and separate from the cemetery
		var v0 := _w2m(Vector2(330.0, 226.0))
		var v1 := _w2m(Vector2(512.0, 318.0))
		draw_rect(Rect2(v0, v1 - v0), Color(0.40, 0.36, 0.25, 0.35), true)
		draw_rect(Rect2(v0, v1 - v0), Color(0.70, 0.62, 0.44, 0.55), false, 1.0)
		draw_string(HudIcons.bold_font(), v0 + Vector2(4.0, -4.0), "HALLOWAY VILLAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.86, 0.80, 0.62, 0.9))
		# roads
		if roads != null:
			for id in roads.paths:
				var path: Array = roads.paths[id]
				if path.size() < 2:
					continue
				var pts := PackedVector2Array()
				for p in path:
					pts.append(_w2m(p))
				draw_polyline(pts, Color(0.06, 0.055, 0.045, 0.9), 4.0)
				draw_polyline(pts, Color(0.62, 0.56, 0.42, 0.75), 1.0)
		# site pins; labels are placed greedily so the sites around the village and the gate car parks do not
		# cover each other on a small map.
		if sites != null:
			var font := HudIcons.bold_font()
			var placed: Array[Rect2] = []
			var candidates := [Vector2(10, -14), Vector2(10, 6), Vector2(-10, -14), Vector2(-10, 6), Vector2(10, 22), Vector2(10, -30), Vector2(-10, 22), Vector2(-10, -30)]
			for s in sites.list():
				var id := str(s["id"])
				var p := _w2m(s["pos"])
				var col := UniverseUI.AMBER if id == active_id else (UniverseUI.MOSS if id == suggested_id else UniverseUI.CREAM_DIM)
				draw_circle(p, 7.0, Color(0.02, 0.02, 0.02, 0.8))
				draw_circle(p, 5.0, col)
				draw_circle(p, 1.8, UniverseUI.NIGHT)
				var txt := str(s["name"])
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				var best := Vector2(10, -14)
				var best_rect := Rect2(p + Vector2(10, -16), Vector2(tw, 14))
				var found := false
				for off in candidates:
					var cand := Vector2(off.x, off.y)
					if cand.x < 0:
						cand.x = -tw - 10
					var r := Rect2(p + cand + Vector2(0, -2), Vector2(tw, 14))
					var clear := true
					for other in placed:
						if r.intersects(other.grow(2)):
							clear = false
							break
					if clear:
						best = cand
						best_rect = r
						found = true
						break
				if not found:
					best = Vector2(10, -30)
					best_rect = Rect2(p + best + Vector2(0, -2), Vector2(tw, 14))
				placed.append(best_rect)
				var label_p := p + best
				if absf(best.x) > 12.0 or absf(best.y) > 20.0:
					draw_line(p, label_p + Vector2(0, 4), Color(0.72, 0.68, 0.52, 0.55), 1.0)
				draw_string(font, label_p + Vector2(0, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.92, 0.89, 0.78, 0.9))
			# a soft line from the current site to the suggested one
			if suggested_id != "" and suggested_id != active_id:
				var a2 := _w2m(sites.pos(active_id))
				var b2 := _w2m(sites.pos(suggested_id))
				draw_line(a2, b2, Color(0.44, 0.64, 0.36, 0.55), 1.4)
		# frame
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08), false, 1.0)
