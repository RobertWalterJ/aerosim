extends SceneTree
## Contact sheet of every flight-screen icon, for checking the icon set by eye. Not part of the game (test/ is left out
## of exports). Run: Godot --path <godot dir> --resolution 1500x1000 -s res://test/icon_sheet.gd -- out=<png> [scale=3]

var _out := "user://icon_sheet.png"
var _scale := 1.0

class Sheet extends Control:
	func _draw() -> void:
		# left half a dark scene, right half a bright sky, so icons are judged on both
		draw_rect(Rect2(0, 0, size.x * 0.5, size.y), Color(0.16, 0.19, 0.17))
		draw_rect(Rect2(size.x * 0.5, 0, size.x * 0.5, size.y), Color(0.70, 0.78, 0.86))
		var f := HudIcons.label_font()
		var rows := ["normal 52", "small 40", "active", "pressed", "disabled"]
		for i in rows.size():
			draw_string(f, Vector2(8, 70 + i * 92), rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))
		# status bar strip
		draw_rect(Rect2(0, 560, size.x, 36), Color(0, 0, 0, 0.28))
		var x := 20.0
		HudIcons.mode_chip(self, "N", Vector2(x + 11, 578), 27, HudIcons.mode_tint("N")); x += 36
		HudIcons.mode_chip(self, "S", Vector2(x + 11, 578), 27, HudIcons.mode_tint("S")); x += 36
		HudIcons.mode_chip(self, "M", Vector2(x + 11, 578), 27, HudIcons.mode_tint("M")); x += 50
		HudIcons.icon(self, "gps", Vector2(x + 9, 578), 23, Color.WHITE, 2.0, 1.2)
		HudIcons.bars(self, Vector2(x + 22, 584), 12, 4, Color.WHITE)
		draw_string(f, Vector2(x + 26 + HudIcons.bars_width(12), 584), "17", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE); x += 80
		HudIcons.icon(self, "rc", Vector2(x + 9, 578), 20, Color.WHITE, 2.0, 1.3)
		HudIcons.bars(self, Vector2(x + 21, 584), 12, 2, HudIcons.signal_colour(2)); x += 50
		HudIcons.icon(self, "hd", Vector2(x + 10, 578), 25, Color.WHITE)
		HudIcons.bars(self, Vector2(x + 23, 584), 12, 1, HudIcons.signal_colour(1)); x += 70
		for p in [100.0, 55.0, 30.0, 10.0]:
			var col := Color("ff6666") if p < 20.0 else (Color("ffcc66") if p < 40.0 else Color.WHITE)
			x += HudIcons.battery(self, Vector2(x, 578), 13, p, col) + 18
		# map markers
		draw_rect(Rect2(20, 620, 160, 90), Color(0.36, 0.45, 0.28))
		HudIcons.home_marker(self, Vector2(60, 665), 7.5)
		HudIcons.drone_marker(self, Vector2(120, 665), 11.0, 0.0, Color(0.22, 0.58, 1.0))
		HudIcons.drone_marker(self, Vector2(150, 665), 11.0, 0.6, Color(0.22, 0.58, 1.0))

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("scale="): _scale = float(a.substr(6))
	# drawn into an off-screen viewport scaled up, so a 3x sheet is a true 3x vector render, not an enlarged picture
	var vp := SubViewport.new()
	vp.size = Vector2i(int(1500 * _scale), int(1000 * _scale))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_transform = Transform2D().scaled(Vector2(_scale, _scale))
	root.add_child(vp)
	var sheet := Sheet.new()
	sheet.size = Vector2(1500, 1000)
	vp.add_child(sheet)
	var kinds := ["back", "gear", "N", "S", "M", "takeoff", "land", "home", "eye", "chase", "camera", "video", "drone", "rc"]
	for row in 5:
		var d := 40.0 if row == 1 else 52.0
		for i in kinds.size():
			var b := RoundButton.new(kinds[i], d)
			b.label = ["Back", "More", "Mode", "Mode", "Mode", "Takeoff", "Land", "Return", "View", "View", "Photo", "Video", "Drone", "RC"][i] if row != 1 else ""
			b.position = Vector2(90 + i * 72, 40 + row * 92)
			if row == 2: b.active = true
			if row == 3: b._down = true
			if row == 4: b.disabled = true
			sheet.add_child(b)
	var states := [[false, false, false, false], [true, false, false, false], [true, true, false, false], [false, false, true, false], [false, false, false, true]]
	for i in states.size():
		var s := ShutterButton.new(80)
		s.video_mode = states[i][0]; s.recording = states[i][1]; s._down = states[i][2]; s.disabled = states[i][3]
		s.position = Vector2(240 + i * 110, 620)
		sheet.add_child(s)
	await process_frame
	for i in 8: await process_frame
	var img := vp.get_texture().get_image()
	img.save_png(_out)
	print("saved ", _out)
	quit()
