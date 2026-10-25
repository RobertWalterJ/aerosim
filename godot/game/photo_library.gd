class_name PhotoLibrary
extends CanvasLayer
## The in-game photo library (session B): photos taken with the shutter stay inside the game, in a gallery the player can
## browse, keep, delete or explicitly export. No files are dropped into the player's Downloads or Pictures folders.
##
## Each photo is stored under user://gallery with a thumbnail and a metadata record: the in-game clock, the weather and its
## intensity, the drone, lens and exposure, the position and height, and which named places were in frame. That metadata is
## what story jobs and photo objectives will check later, so the sandbox stays untouched: photos are simply yours.
##
## The gallery is a full-screen page in the pause menu (Camera > Photo gallery) or the G key while the menu is open.
## Export copy is the only way a photo leaves the game, and it goes to user://exports.

const DIR := "user://gallery"
const INDEX := "user://gallery/index.json"
const MAX_PHOTOS := 120

## Emitted for every saved photo, with its metadata. The jobs layer listens to this to check photo objectives.
signal photo_saved(id: int, meta: Dictionary)

var hud: Hud
var jobs: Jobs                   # assigned by main: uploads to VidTube and the editor
var chat: ChatData
var _send_edit: Button
var world_life: WorldLife
var _index: Array = []
var _next_id := 1
var _root: Control
var _grid: GridContainer
var _count_label: Label
var _detail: Control
var _detail_tex: TextureRect
var _detail_info: Label
var _detail_index := -1
var _open := false

func setup(h: Hud, wl: WorldLife) -> void:
	hud = h
	world_life = wl
	layer = 30
	DirAccess.make_dir_recursive_absolute(DIR)
	_load_index()
	_build_ui()
	_open = false

# ------------------------------------------------------------------ capture
## Store a captured frame with its metadata. Returns the photo id.
func capture(img: Image, meta: Dictionary) -> int:
	if img == null:
		return -1
	DirAccess.make_dir_recursive_absolute(DIR)
	var id := _next_id
	_next_id += 1
	var full := "%s/p%05d.jpg" % [DIR, id]
	var thumb := "%s/t%05d.jpg" % [DIR, id]
	img.save_jpg(full, 0.92)
	var t := img.duplicate() as Image
	t.resize(320, maxi(1, int(round(320.0 * float(img.get_height()) / maxf(float(img.get_width()), 1.0)))), Image.INTERPOLATE_LANCZOS)
	t.save_jpg(thumb, 0.82)
	var rec := {"id": id, "full": full, "thumb": thumb, "meta": meta}
	_index.append(rec)
	# keep the library bounded, oldest first
	while _index.size() > MAX_PHOTOS:
		var old: Dictionary = _index.pop_front()
		_remove_files(old)
	_save_index()
	# places in frame count as discovered, so a photo of the farm is also finding the farm
	if world_life != null and meta.has("subjects"):
		var names: Array = []
		for s in meta["subjects"]:
			names.append(str(s.get("id", "")))
		world_life.mark_discovered(names)
	if hud != null:
		hud.toast("Saved to the photo gallery", false, "CAMERA")
	photo_saved.emit(id, meta)
	return id

## The thumbnail texture for a photo id, for the jobs page and any other in-game use.
func texture_for(photo_id: int) -> Texture2D:
	for rec in _index:
		if int(rec.get("id", -1)) == photo_id:
			return _thumb_texture(rec)
	return null

## The metadata for a photo id, for job scoring and the detail page.
func meta_for(photo_id: int) -> Dictionary:
	for rec in _index:
		if int(rec.get("id", -1)) == photo_id:
			return rec.get("meta", {})
	return {}

func _remove_files(rec: Dictionary) -> void:
	for key in ["full", "thumb"]:
		var p := str(rec.get(key, ""))
		if p != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ------------------------------------------------------------------ index
func _load_index() -> void:
	_index.clear()
	_next_id = 1
	if not FileAccess.file_exists(INDEX):
		return
	var f := FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for rec in data:
			if rec is Dictionary and FileAccess.file_exists(str(rec.get("full", ""))):
				_index.append(rec)
				_next_id = maxi(_next_id, int(rec.get("id", 1)) + 1)

func _save_index() -> void:
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_index))

func count() -> int:
	return _index.size()

func photos() -> Array:
	return _index.duplicate()

# ------------------------------------------------------------------ the gallery page
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UniverseUI.make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.03, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.090, 0.078, 0.99)
	sb.set_corner_radius_all(22)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.88, 0.74, 0.50, 0.22)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)
	panel.anchor_left = 0.04; panel.anchor_right = 0.96
	panel.anchor_top = 0.05; panel.anchor_bottom = 0.95
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Photo gallery"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.94, 0.912, 0.82))
	head.add_child(title)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 15)
	_count_label.add_theme_color_override("font_color", Color(0.60, 0.63, 0.555))
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_label)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var hint := Label.new()
	hint.text = "Photos stay in the camera roll. Export a copy when you want one outside it."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.60, 0.63, 0.555))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	var close := Button.new()
	close.text = "Close"
	close.flat = true
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(0.94, 0.912, 0.82))
	close.pressed.connect(close_gallery)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	_build_detail()
	_root.visible = false

func _build_detail() -> void:
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_detail)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent): if ev is InputEventMouseButton and ev.pressed: _close_detail())
	_detail.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.105, 0.12, 0.99)
	sb.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	_detail.add_child(panel)
	panel.anchor_left = 0.06; panel.anchor_right = 0.94
	panel.anchor_top = 0.08; panel.anchor_bottom = 0.92
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)
	_detail_tex = TextureRect.new()
	_detail_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_tex.custom_minimum_size = Vector2(560, 0)
	row.add_child(_detail_tex)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	var heading := Label.new()
	heading.text = "Photo"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	side.add_child(heading)
	_detail_info = Label.new()
	_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_info.add_theme_font_size_override("font_size", 14)
	_detail_info.add_theme_color_override("font_color", Color(0.74, 0.76, 0.80))
	_detail_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_detail_info)
	var export := Button.new(); export.text = "Export copy"; export.custom_minimum_size = Vector2(0, 42)
	export.pressed.connect(_export_current)
	side.add_child(export)
	var upload := Button.new(); upload.text = "Upload to VidTube Studio"; upload.custom_minimum_size = Vector2(0, 42)
	upload.pressed.connect(func(): _upload_current(false))
	side.add_child(upload)
	_send_edit = Button.new(); _send_edit.text = "Send to Maya to edit"; _send_edit.custom_minimum_size = Vector2(0, 42)
	_send_edit.disabled = jobs == null or not jobs.editor_friend()
	_send_edit.tooltip_text = "Uploaded to the DroneBudz #clips channel first, then Maya cuts and publishes it"
	_send_edit.pressed.connect(func(): _upload_current(true))
	side.add_child(_send_edit)
	var del := Button.new(); del.text = "Delete photo"; del.custom_minimum_size = Vector2(0, 42)
	del.add_theme_color_override("font_color", Color(0.95, 0.55, 0.50))
	del.pressed.connect(_delete_current)
	side.add_child(del)
	var back := Button.new(); back.text = "Back to gallery"; back.custom_minimum_size = Vector2(0, 42)
	back.pressed.connect(_close_detail)
	side.add_child(back)
	_detail.visible = false

func _refresh_grid() -> void:
	for ch in _grid.get_children():
		ch.queue_free()
	for i in _index.size():
		var rec: Dictionary = _index[i]
		var cell := Button.new()
		cell.flat = true
		cell.custom_minimum_size = Vector2(215, 128)
		cell.tooltip_text = "Photo %d" % int(rec.get("id", i + 1))
		var tex := TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.texture = _thumb_texture(rec)
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tex)
		var ix := i
		cell.pressed.connect(func(): _open_detail(ix))
		_grid.add_child(cell)
	if _index.is_empty():
		var empty := Label.new()
		empty.text = "No photos yet. Use the shutter in flight and they will appear here."
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
		_grid.add_child(empty)
	_count_label.text = "   %d photo%s" % [_index.size(), "" if _index.size() == 1 else "s"]

func _thumb_texture(rec: Dictionary) -> Texture2D:
	var path := ProjectSettings.globalize_path(str(rec.get("thumb", "")))
	var img := Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

func _open_detail(i: int) -> void:
	if i < 0 or i >= _index.size():
		return
	_detail_index = i
	var rec: Dictionary = _index[i]
	if _send_edit != null:
		_send_edit.disabled = jobs == null or not jobs.editor_friend()
	var path := ProjectSettings.globalize_path(str(rec.get("full", "")))
	var img := Image.load_from_file(path)
	if img != null:
		_detail_tex.texture = ImageTexture.create_from_image(img)
	_detail_info.text = _describe(rec) + ("\n\n" + jobs.photo_potential(rec.get("meta", {})) if jobs != null else "")
	_detail.visible = true

func _close_detail() -> void:
	_detail.visible = false
	_detail_tex.texture = null
	_detail_index = -1

func _describe(rec: Dictionary) -> String:
	var m: Dictionary = rec.get("meta", {})
	var lines: Array[String] = []
	lines.append("Taken at %s" % str(m.get("clock", "unknown time")))
	var weather := str(m.get("weather", ""))
	if weather != "":
		var inten := float(m.get("weather_i", 0.0))
		lines.append("Weather: %s, intensity %d%%" % [weather, int(round(inten * 100.0))])
	lines.append("Drone: %s" % str(m.get("drone", "drone")))
	lines.append("Lens: %s" % str(m.get("lens", "standard")))
	var expo := float(m.get("exposure", 1.0))
	var iso := int(m.get("iso", 100))
	var shutter := float(m.get("shutter", 0.01))
	lines.append("Exposure: EV %+.1f, ISO %d, 1/%d s" % [log(maxf(expo, 0.001)) / log(2.0), iso, int(round(maxf(1.0 / shutter, 1.0)))])
	var agl := float(m.get("agl", 0.0))
	lines.append("Height: %d m above the ground" % int(round(agl)))
	var subjects: Array = m.get("subjects", [])
	if not subjects.is_empty():
		var names: Array[String] = []
		for s in subjects:
			names.append(str(s.get("name", "something")))
		lines.append("In frame: " + ", ".join(names))
	var wl_near := ""
	if world_life != null:
		var p: Array = m.get("pos", [0.0, 0.0, 0.0])
		wl_near = world_life.nearest_place(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if wl_near != "":
		lines.append("Nearest place: " + wl_near)
	return "\n".join(lines)

func _export_current() -> void:
	if _detail_index < 0 or _detail_index >= _index.size():
		return
	var rec: Dictionary = _index[_detail_index]
	DirAccess.make_dir_recursive_absolute("user://exports")
	var name := "AeroSim_photo_%05d.jpg" % int(rec.get("id", 0))
	var dst := "user://exports/" + name
	var src := FileAccess.open(str(rec.get("full", "")), FileAccess.READ)
	if src == null:
		return
	var data := src.get_buffer(src.get_length())
	var out := FileAccess.open(dst, FileAccess.WRITE)
	if out != null:
		out.store_buffer(data)
		if hud != null:
			hud.toast("Exported a copy to the gallery folder.", false, "CAMERA")

func _upload_current(via_editor: bool) -> void:
	if _detail_index < 0 or _detail_index >= _index.size() or jobs == null:
		return
	var rec: Dictionary = _index[_detail_index]
	var rec_out := jobs.upload_photo(int(rec.get("id", -1)), rec.get("meta", {}), via_editor)
	if hud != null:
		if via_editor:
			hud.toast("Sent to Maya: edited cut published with %d views" % int(rec_out.get("views", 0)), false, "VIDTUBE")
		else:
			hud.toast("Uploaded to VidTube Studio: %d views, +%d followers" % [int(rec_out.get("views", 0)), int(rec_out.get("followers", 0))], false, "VIDTUBE")

func _delete_current() -> void:
	if _detail_index < 0 or _detail_index >= _index.size():
		return
	var rec: Dictionary = _index[_detail_index]
	_remove_files(rec)
	_index.remove_at(_detail_index)
	_save_index()
	_close_detail()
	_refresh_grid()

# ------------------------------------------------------------------ open and close
func open_gallery() -> void:
	_refresh_grid()
	_detail.visible = false
	_root.visible = true
	_open = true

func close_gallery() -> void:
	_root.visible = false
	_open = false
	_close_detail()

func toggle() -> void:
	if _open:
		close_gallery()
	else:
		open_gallery()

## Dev and menu helper: open the gallery and the newest photo's detail.
func open_detail_first() -> void:
	open_gallery()
	if not _index.is_empty():
		_open_detail(_index.size() - 1)

func is_open() -> bool:
	return _open

func stats() -> Dictionary:
	return {"photos": _index.size(), "open": _open}
