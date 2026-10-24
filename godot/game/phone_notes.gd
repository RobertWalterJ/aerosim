class_name PhoneNotes
extends CanvasLayer

## Emitted when the player asks to open the DroneBudz app from the notification shade.
signal app_requested(app: String)
## Android style notifications for the DroneBudz group chat (session B).
##
## The drone view stays full screen. When something happens, an Android heads-up notification drops from the top of the
## screen: a Material surface card with the app icon, "DroneBudz" and a timestamp, the sender and the message. If more
## messages arrive while one is showing, they group into the same card ("DroneBudz · 3 notifications", latest message
## on top, with an expand chevron), the way Android groups notifications from one app. Tapping the card (or pressing N)
## opens the notification centre: an Android shade style panel with the recent DroneBudz notifications, an in-game clock
## time on each, a "Clear all" action and nothing else phone related, so the screen still feels like a real drone being
## flown with the phone's notifications on top.
##
## The iPhone glass style is still in the code and can be selected from the menu, but Android is the default and the
## look Robert picked. The rest of the phone (status bar, home indicator, device frame) is deliberately not drawn: only
## the notifications and the shade, so it reads as a phone notification layer without turning the screen into a phone.
##
## Everything is drawn in code, no image assets. Messages are fed by the fireworks and weather event runtimes, and the
## whole layer is switched off with Phone messages.

const APP := "DroneBudz"
const MAX_HISTORY := 24
const HEADS_UP_LIFE := 9.5
const SENDER_COL := {
	"Maya": Color(0.72, 0.36, 0.48), "Tom": Color(0.28, 0.46, 0.72), "Riley": Color(0.72, 0.33, 0.26),
	"Jo": Color(0.47, 0.35, 0.72), "Sam": Color(0.22, 0.55, 0.52), "Alex": Color(0.68, 0.52, 0.24),
}
const MESSAGES := {
	"show_soon": ["Maya", "Fireworks tonight", "The show over the lake starts at half past nine. Bring the drone down before it gets loud.", 0],
	"show_start": ["Tom", "The show is starting", "Fireworks over the lake, right now. Loud bangs coming.", 1],
	"show_over": ["Jo", "That is the show done", "Nice flying. Same time next week?", 0],
	"storm": ["Sam", "Storm warning", "Storm cells are building over the valley. Lightning already in the area, winds picking up.", 1],
	"tornado": ["Riley", "TORNADO ON THE GROUND", "Tornado on the ground in the meadow. Keep well clear of it.", 2],
	"waterspout": ["Maya", "Waterspout over the lake", "A waterspout is forming out over the water. Big one, great shot if you keep your distance.", 1],
	"dustdevil": ["Alex", "Dust devil", "Small dust devil spinning up on the dry ground. Nothing to worry about.", 0],
	"thermals": ["Alex", "Hawks are up", "Thermals rising over the meadow and the hawks are circling them. Good air if you want to climb.", 0],
	"fogbank": ["Sam", "Fog rolling in", "A bank of mist is drifting over the lake. Visibility is dropping.", 1],
	"snowsquall": ["Tom", "Snow squall", "A whiteout cell is moving across the valley. Watch your link.", 1],
	"surprise": ["Jo", "Something is kicking off", "Weather is turning over the valley. Look up.", 0],
}

var enabled := true
var hud: Hud
var _root: Control              # the heads-up notification stack
var _cards: Array[Dictionary] = []
var _history: Array[Dictionary] = []      # for the notification centre: {msg, clock, id}
var _group_n := 0                          # messages in the current Android group
var _rng := RandomNumberGenerator.new()
var _demo_queue: Array[String] = []
var _demo_t := 0.0
var _style := 1                            # 0 iPhone glass, 1 Android (default)
var _card_w := 430.0
var _f_regular: FontVariation
var _f_medium: FontVariation
var _f_bold: FontVariation
var _f_spaced: FontVariation

# ------------------------------------------------------------------ drawn icons and avatars
class AppIcon extends Control:
	var urgency := 0
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.42, 0.27)
		sb.set_corner_radius_all(int(size.x * 0.28))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		var s := size.x
		var white := Color(0.97, 0.99, 0.98)
		draw_line(c + Vector2(-0.31, -0.31) * s, c + Vector2(0.31, 0.31) * s, white, maxf(1.3, s * 0.055))
		draw_line(c + Vector2(0.31, -0.31) * s, c + Vector2(-0.31, 0.31) * s, white, maxf(1.3, s * 0.055))
		draw_circle(c + Vector2(-0.31, -0.31) * s, 0.115 * s, white)
		draw_circle(c + Vector2(0.31, -0.31) * s, 0.115 * s, white)
		draw_circle(c + Vector2(-0.31, 0.31) * s, 0.115 * s, white)
		draw_circle(c + Vector2(0.31, 0.31) * s, 0.115 * s, white)
		var body := StyleBoxFlat.new()
		body.bg_color = white
		body.set_corner_radius_all(maxi(2, int(s * 0.05)))
		draw_style_box(body, Rect2(c + Vector2(-0.085, -0.12) * s, Vector2(0.17, 0.24) * s))
		if urgency > 0:
			var dot := Color(0.98, 0.73, 0.16) if urgency == 1 else Color(0.95, 0.24, 0.21)
			draw_circle(Vector2(size.x - s * 0.10, s * 0.10), s * 0.13, dot)

class Avatar extends Control:
	var letter := "M"
	var col := Color.WHITE
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.5, col)
		var font := ThemeDB.fallback_font
		if font == null:
			return
		var fs := int(size.x * 0.42)
		var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var asc := font.get_ascent(fs)
		var desc := font.get_descent(fs)
		draw_string(font, c + Vector2(-tw * 0.5, (asc - desc) * 0.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))

class Chevron extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := size * 0.5
		draw_polyline(PackedVector2Array([c + Vector2(-w * 0.22, -h * 0.10), c + Vector2(0, h * 0.18), c + Vector2(w * 0.22, -h * 0.10)]), Color(0.74, 0.76, 0.80, 0.9), 1.8, true)

# ------------------------------------------------------------------ setup
func setup(h: Hud) -> void:
	hud = h
	layer = 20
	_rng.seed = 424242
	_style = 1 if h == null else int(h.phone_style)
	_f_regular = FontVariation.new()
	_f_regular.base_font = ThemeDB.fallback_font
	_f_medium = FontVariation.new()
	_f_medium.base_font = ThemeDB.fallback_font
	_f_medium.variation_embolden = 0.32
	_f_bold = FontVariation.new()
	_f_bold.base_font = ThemeDB.fallback_font
	_f_bold.variation_embolden = 0.62
	_f_spaced = FontVariation.new()
	_f_spaced.base_font = ThemeDB.fallback_font
	_f_spaced.variation_embolden = 0.25
	_f_spaced.spacing_glyph = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	# a back buffer copy so the iPhone glass style can sample and blur the FPV feed behind a card
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(bbc)
	_build_shade()
	_build_pill()

func _process(_delta: float) -> void:
	pass   # main.gd calls update once a frame

# ------------------------------------------------------------------ per frame
func update(delta: float, paused: bool) -> void:
	enabled = true if hud == null else bool(hud.phone_notes)
	var style := 1 if hud == null else int(hud.phone_style)
	if style != _style:
		_style = style
		_clear_heads_up()
		if not _history.is_empty():
			_show_latest()
	if _shade_open and (not enabled or paused):
		close_shade()
	_animate_shade(delta)
	var vp0 := get_viewport().get_visible_rect().size
	_update_pill(vp0)
	_root.visible = enabled and not _shade_open and (not _cards.is_empty() or not _demo_queue.is_empty())
	if not _root.visible:
		return
	var vp := vp0
	_card_w = clampf(vp.x * (0.335 if _style == 0 else 0.35), 360.0, 470.0)
	if not _demo_queue.is_empty():
		_demo_t += delta
		if _demo_t >= 0.55:
			_demo_t = 0.0
			_post_kind(_demo_queue.pop_front())
	var remove: Array = []
	for c in _cards:
		c["t"] = float(c["t"]) + delta
		c["fade"] = clampf(1.0 - (float(c["t"]) - HEADS_UP_LIFE) / 0.6, 0.0, 1.0)
		if float(c["fade"]) <= 0.0:
			remove.append(c)
	var n := _cards.size()
	for i in n:
		var c: Dictionary = _cards[i]
		c["idx"] = i
		var holder: Control = c["holder"]
		var target_x := (vp.x - _card_w) * 0.5
		var target_y := 30.0 + 11.0 * float(i)
		var enter := clampf(float(c["t"]) / 0.34, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - enter, 3.0)
		holder.position = Vector2(target_x, lerpf(-90.0, target_y, e))
		holder.scale = Vector2.ONE * (1.0 - 0.022 * float(i))
		holder.modulate.a = float(c["fade"]) * (0.62 if i > 0 else 1.0)
		_size_card(c, float(c["fade"]))
	for c in remove:
		(c["holder"] as Control).queue_free()
		_cards.erase(c)
		if _style == 1:
			_group_n = 0

# ------------------------------------------------------------------ posting
func post(kind: String, force := false) -> void:
	if not enabled and not force:
		return
	_post_kind(kind)

func post_text(sender: String, title: String, body: String, urgency := 0) -> void:
	_add({"sender": sender, "title": title, "body": body, "urgency": urgency})

func _post_kind(kind: String) -> void:
	if not MESSAGES.has(kind):
		return
	var m: Array = MESSAGES[kind]
	_add({"sender": m[0], "title": m[1], "body": m[2], "urgency": int(m[3])})

func _add(msg: Dictionary) -> void:
	var rec := {"msg": msg, "clock": _clock_str(), "hour": _clock_hour(), "id": _history.size()}
	_history.append(rec)
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	_group_n = mini(_history.size(), 9)
	_clear_heads_up()
	if _style == 1:
		# Android: one grouped heads-up card showing the latest message and the group count
		_build_android_card(msg, _group_n)
	else:
		# iPhone: a stack, newest in front, older behind
		_build_ios_card(msg)
		for i in _cards.size():
			_cards[i]["idx"] = i
	if _shade_open:
		_rebuild_shade()
	if not _cards.is_empty():
		_size_card(_cards[0], 1.0)

func _clear_heads_up() -> void:
	for c in _cards:
		(c["holder"] as Control).queue_free()
	_cards.clear()

## Re-show the latest stored message (used when the style changes or the card was dismissed).
func _show_latest() -> void:
	if _history.is_empty():
		return
	var m: Dictionary = _history.back()["msg"]
	_group_n = mini(_history.size(), 9)
	if _style == 1:
		_build_android_card(m, _group_n)
	else:
		_build_ios_card(m)
	if not _cards.is_empty():
		_size_card(_cards[0], 1.0)

# ------------------------------------------------------------------ card construction
func _base_card() -> Dictionary:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(_card_w, 10)
	_root.add_child(holder)
	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbs := StyleBoxFlat.new()
	sbs.bg_color = Color(0, 0, 0, 0)
	sbs.set_corner_radius_all(24 if _style == 0 else 28)
	sbs.shadow_color = Color(0, 0, 0, 0.42)
	sbs.shadow_size = 22
	sbs.shadow_offset = Vector2(0, 9)
	shadow.add_theme_stylebox_override("panel", sbs)
	holder.add_child(shadow)
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var glass := ColorRect.new()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://game/shaders/phone_glass.gdshader")
	if _style == 0:
		gm.set_shader_parameter("radius", 22.0)
		gm.set_shader_parameter("tint", Vector3(0.085, 0.09, 0.105))
		gm.set_shader_parameter("tint_amount", 0.74)
		gm.set_shader_parameter("blur_px", 15.0)
		gm.set_shader_parameter("edge_light", 1.0)
		gm.set_shader_parameter("grain", 1.0)
	else:
		gm.set_shader_parameter("radius", 28.0)
		gm.set_shader_parameter("tint", Vector3(0.115, 0.115, 0.125))
		gm.set_shader_parameter("tint_amount", 0.965)
		gm.set_shader_parameter("blur_px", 2.0)
		gm.set_shader_parameter("edge_light", 0.30)
		gm.set_shader_parameter("grain", 0.45)
	glass.material = gm
	holder.add_child(glass)
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := 15 if _style == 0 else 16
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, pad + 1)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if _style == 0 else 14)
	holder.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4 if _style == 0 else 5)
	margin.add_child(col)
	return {"holder": holder, "glass": glass, "margin": margin, "col": col, "t": 0.0, "fade": 1.0, "idx": 0}

func _header(col: VBoxContainer, urgency: int, trailing: String, chevron := false) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 7)
	col.add_child(head)
	var icon_size := 28.0 if _style == 0 else 22.0
	var icon := AppIcon.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.urgency = urgency if _style == 0 else 0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var app := Label.new()
	app.text = "DRONEBUDZ" if _style == 0 else "DroneBudz"
	app.add_theme_font_override("font", _f_spaced if _style == 0 else _f_medium)
	app.add_theme_font_size_override("font_size", 12 if _style == 0 else 13)
	app.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76) if _style == 0 else Color(0.80, 0.82, 0.85))
	app.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(app)
	if trailing != "":
		var extra := Label.new()
		extra.text = trailing
		extra.add_theme_font_override("font", _f_regular)
		extra.add_theme_font_size_override("font_size", 12)
		extra.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(extra)
	var stretch := Control.new()
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var stamp := Label.new()
	stamp.text = "now"
	stamp.add_theme_font_size_override("font_size", 12)
	stamp.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(stamp)
	if _style == 1 and chevron:
		var ch := Chevron.new()
		ch.custom_minimum_size = Vector2(16, 16)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(ch)
	return head

func _build_android_card(msg: Dictionary, group_n: int) -> void:
	var c := _base_card()
	var col: VBoxContainer = c["col"]
	var sender := str(msg["sender"])
	var urgency := int(msg.get("urgency", 0))
	_header(col, urgency, "" if group_n <= 1 else "·  %d notifications" % group_n, group_n > 1)
	# Android messaging style: the text on the left and the sender's picture as the large icon on the right
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var title := Label.new()
	title.text = "%s: %s" % [sender, str(msg["title"])]
	title.add_theme_font_override("font", _f_bold)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	v.add_child(title)
	var body := Label.new()
	body.text = str(msg["body"])
	body.add_theme_font_override("font", _f_regular)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(_card_w - 34 - 56, 0)
	v.add_child(body)
	var av := Avatar.new()
	av.letter = sender.substr(0, 1).to_upper()
	av.col = SENDER_COL.get(sender, Color(0.4, 0.5, 0.6))
	av.custom_minimum_size = Vector2(48, 48)
	av.size = Vector2(48, 48)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(av)
	# tapping the card opens the notification centre, like tapping a notification on Android
	_make_clickable(c)
	_cards.insert(0, c)

func _build_ios_card(msg: Dictionary) -> void:
	var c := _base_card()
	var col: VBoxContainer = c["col"]
	var sender := str(msg["sender"])
	var urgency := int(msg.get("urgency", 0))
	_header(col, urgency, "")
	var body_row := HBoxContainer.new()
	body_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_theme_constant_override("separation", 10)
	col.add_child(body_row)
	var av := Avatar.new()
	av.letter = sender.substr(0, 1).to_upper()
	av.col = SENDER_COL.get(sender, Color(0.4, 0.5, 0.6))
	av.custom_minimum_size = Vector2(34, 34)
	av.size = Vector2(34, 34)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_child(av)
	var vcol := VBoxContainer.new()
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_theme_constant_override("separation", 1)
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(vcol)
	var title := Label.new()
	title.text = "%s  ·  %s" % [sender, str(msg["title"])]
	title.add_theme_font_override("font", _f_bold)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.97, 0.97, 0.98))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	vcol.add_child(title)
	var body := Label.new()
	body.text = str(msg["body"])
	body.add_theme_font_override("font", _f_regular)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.80, 0.82, 0.85))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(_card_w - 34 - 44 - 2, 0)
	vcol.add_child(body)
	_make_clickable(c)
	_cards.insert(0, c)

func _make_clickable(c: Dictionary) -> void:
	var holder: Control = c["holder"]
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				open_shade()
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				# dismissing the heads-up is like swiping it away: it leaves the screen but the notification stays in
				# the notification centre, exactly like a real phone
				_clear_heads_up()
	)

## Size the holder and the shader to the content height (the group count changes it).
func _size_card(c: Dictionary, fade: float) -> void:
	var holder: Control = c["holder"]
	var margin: MarginContainer = c["margin"]
	var h := maxf(margin.get_combined_minimum_size().y, 60.0)
	holder.size = Vector2(_card_w, h)
	var glass: ColorRect = c["glass"]
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gm := glass.material as ShaderMaterial
	if gm:
		gm.set_shader_parameter("card_size", Vector2(_card_w, h))
		gm.set_shader_parameter("alpha", fade)

# ------------------------------------------------------------------ notification centre (Android shade style)
var _shade_root: Control
var _shade_dim: ColorRect
var _shade_panel: PanelContainer
var _shade_list: VBoxContainer
var _shade_scroll: ScrollContainer
var _shade_open := false
var _shade_h := 420.0
var _shade_total: Label
var _shade_expanded := true
var _pill: PanelContainer
var _pill_count: Label

func _build_shade() -> void:
	_shade_root = Control.new()
	_shade_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade_root.visible = false
	add_child(_shade_root)
	_shade_dim = ColorRect.new()
	_shade_dim.color = Color(0, 0, 0, 0.42)
	_shade_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close_shade()
	)
	_shade_root.add_child(_shade_dim)
	_shade_panel = PanelContainer.new()
	_shade_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.088, 0.078, 0.98)
	sb.set_corner_radius_all(0)
	sb.corner_radius_bottom_left = 28
	sb.corner_radius_bottom_right = 28
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 8)
	_shade_panel.add_theme_stylebox_override("panel", sb)
	_shade_root.add_child(_shade_panel)
	_shade_panel.anchor_left = 0.0
	_shade_panel.anchor_right = 1.0
	_shade_panel.anchor_top = 0.0
	_shade_panel.anchor_bottom = 0.0
	_shade_panel.offset_left = 0
	_shade_panel.offset_right = 0
	_shade_panel.offset_top = -320
	_shade_panel.offset_bottom = 0
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_shade_panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Notifications"
	title.add_theme_font_override("font", _f_bold)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	head.add_child(title)
	_shade_total = Label.new()
	_shade_total.add_theme_font_override("font", _f_regular)
	_shade_total.add_theme_font_size_override("font_size", 13)
	_shade_total.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	_shade_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_shade_total)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var open_btn := Button.new()
	open_btn.text = "Open DroneBudz"
	open_btn.flat = true
	open_btn.add_theme_font_size_override("font_size", 14)
	open_btn.add_theme_color_override("font_color", Color(0.55, 0.80, 0.95))
	open_btn.pressed.connect(func(): app_requested.emit("chat"); close_shade())
	head.add_child(open_btn)
	var clear_btn := Button.new()
	clear_btn.text = "Clear all"
	clear_btn.flat = true
	clear_btn.add_theme_font_size_override("font_size", 14)
	clear_btn.add_theme_color_override("font_color", Color(0.55, 0.80, 0.95))
	clear_btn.pressed.connect(func(): _history.clear(); _group_n = 0; _rebuild_shade())
	head.add_child(clear_btn)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.80, 0.82, 0.85))
	close_btn.pressed.connect(close_shade)
	head.add_child(close_btn)
	var group := Label.new()
	group.text = "DroneBudz"
	group.add_theme_font_override("font", _f_medium)
	group.add_theme_font_size_override("font_size", 14)
	group.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	col.add_child(group)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 60)
	_shade_scroll = scroll
	col.add_child(scroll)
	_shade_list = VBoxContainer.new()
	_shade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shade_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_shade_list)
	_build_click_through_shade()

func _build_click_through_shade() -> void:
	pass

## The notification centre, built the way Android presents a grouped conversation: one DroneBudz group summary that
## can be expanded into the individual messages. The summary shows the latest message while collapsed; expanding lists
## every message with its time and a dismiss control, and the group can be cleared as a whole.
func _rebuild_shade() -> void:
	if _shade_list == null:
		return
	for ch in _shade_list.get_children():
		ch.queue_free()
	if _shade_total:
		_shade_total.text = "  %d notifications" % _history.size() if not _history.is_empty() else ""
	if _history.is_empty():
		var empty := Label.new()
		empty.text = "No notifications"
		empty.add_theme_font_override("font", _f_regular)
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.60, 0.62, 0.66))
		_shade_list.add_child(empty)
		return
	# the group summary card
	var group := PanelContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_STOP
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.12, 0.14, 0.122, 0.97)
	gsb.set_corner_radius_all(20)
	group.add_theme_stylebox_override("panel", gsb)
	var gpad := MarginContainer.new()
	for side in ["left", "right"]:
		gpad.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		gpad.add_theme_constant_override("margin_" + side, 12)
	group.add_child(gpad)
	var gcol := VBoxContainer.new()
	gcol.add_theme_constant_override("separation", 6)
	gpad.add_child(gcol)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	gcol.add_child(head)
	var icon := AppIcon.new()
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var name_l := Label.new()
	name_l.text = "DroneBudz"
	name_l.add_theme_font_override("font", _f_bold)
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96))
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_l)
	var count_l := Label.new()
	count_l.text = "· %d" % _history.size()
	count_l.add_theme_font_override("font", _f_regular)
	count_l.add_theme_font_size_override("font_size", 13)
	count_l.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	count_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count_l)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var chev := Chevron.new()
	chev.custom_minimum_size = Vector2(18, 18)
	chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _shade_expanded:
		chev.rotation = PI
	head.add_child(chev)
	group.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_shade_expanded = not _shade_expanded
			_rebuild_shade()
	)
	var latest: Dictionary = _history.back()
	if not _shade_expanded:
		var msg: Dictionary = latest["msg"]
		var prev := Label.new()
		prev.text = "%s: %s" % [str(msg["sender"]), str(msg["body"])]
		prev.add_theme_font_override("font", _f_regular)
		prev.add_theme_font_size_override("font_size", 13)
		prev.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76))
		prev.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		prev.autowrap_mode = TextServer.AUTOWRAP_OFF
		prev.custom_minimum_size = Vector2(200, 0)
		gcol.add_child(prev)
	_shade_list.add_child(group)
	if not _shade_expanded:
		return
	# the individual messages inside the group, newest first, each dismissible like a real notification
	var items := _history.duplicate()
	for i in range(items.size() - 1, -1, -1):
		_shade_list.add_child(_shade_child(items[i]))
	if _shade_scroll:
		# the centre grows with the content, and only scrolls when the group is long
		var rows := _history.size() if _shade_expanded else 0
		_shade_scroll.custom_minimum_size = Vector2(0, clampf(8.0 + 88.0 * float(mini(rows, 4)), 24.0, 330.0))

func _shade_child(rec: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.14, 0.97)
	sb.set_corner_radius_all(16)
	card.add_theme_stylebox_override("panel", sb)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	card.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pad.add_child(row)
	var msg: Dictionary = rec["msg"]
	var sender := str(msg["sender"])
	var av := Avatar.new()
	av.letter = sender.substr(0, 1).to_upper()
	av.col = SENDER_COL.get(sender, Color(0.4, 0.5, 0.6))
	av.custom_minimum_size = Vector2(32, 32)
	av.size = Vector2(32, 32)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name_l := Label.new()
	name_l.text = "%s: %s" % [sender, str(msg["title"])]
	name_l.add_theme_font_override("font", _f_bold)
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(name_l)
	var clock := Label.new()
	clock.text = str(rec.get("clock", "now"))
	clock.add_theme_font_size_override("font_size", 12)
	clock.add_theme_color_override("font_color", Color(0.62, 0.64, 0.68))
	top.add_child(clock)
	var body_l := Label.new()
	body_l.text = str(msg["body"])
	body_l.add_theme_font_override("font", _f_regular)
	body_l.add_theme_font_size_override("font_size", 13)
	body_l.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body_l)
	var dismiss := Button.new()
	dismiss.text = "×"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(28, 28)
	dismiss.add_theme_font_size_override("font_size", 18)
	dismiss.add_theme_color_override("font_color", Color(0.66, 0.68, 0.72))
	dismiss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var gid := int(rec.get("id", -1))
	dismiss.pressed.connect(func(): _dismiss_id(gid))
	row.add_child(dismiss)
	return card

func _dismiss_id(id: int) -> void:
	for i in _history.size():
		if int(_history[i].get("id", -1)) == id:
			_history.remove_at(i)
			break
	_group_n = mini(_history.size(), 9)
	if _history.is_empty():
		_clear_heads_up()
	_rebuild_shade()

## A small persistent DroneBudz icon with the unread count, like the status bar icon a phone keeps after the heads-up
## banner has gone: it stays until the notifications are dismissed or cleared, and tapping it opens the centre.
func _build_pill() -> void:
	_pill = PanelContainer.new()
	_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.088, 0.078, 0.93)
	sb.set_corner_radius_all(15)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 10
	_pill.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 9)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	_pill.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)
	var icon := AppIcon.new()
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size = Vector2(18, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_pill_count = Label.new()
	_pill_count.add_theme_font_override("font", _f_bold)
	_pill_count.add_theme_font_size_override("font_size", 12)
	_pill_count.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	_pill_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pill_count)
	_pill.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			open_shade()
	)
	_pill.visible = false
	add_child(_pill)

func _update_pill(vp: Vector2) -> void:
	if _pill == null:
		return
	var show := enabled and not _shade_open and _cards.is_empty() and not _history.is_empty()
	_pill.visible = show
	if not show:
		return
	_pill_count.text = str(_history.size())
	_pill.reset_size()
	_pill.position = Vector2(vp.x - _pill.size.x - 18.0, 30.0)

func open_shade() -> void:
	_shade_open = true
	_rebuild_shade()
	_shade_h = _shade_content_h()
	_shade_panel.offset_top = -_shade_h
	_shade_panel.offset_bottom = 0.0
	_shade_root.visible = true

func _shade_content_h() -> float:
	var vp := get_viewport().get_visible_rect().size
	return clampf(_shade_panel.get_combined_minimum_size().y + 18.0, 150.0, vp.y * 0.72)

func close_shade() -> void:
	_shade_open = false
	_shade_root.visible = false

func toggle_shade() -> void:
	if _shade_open:
		close_shade()
	else:
		open_shade()

func _animate_shade(delta: float) -> void:
	if _shade_root == null or not _shade_open:
		return
	_shade_h = _shade_content_h()
	_shade_panel.offset_top = lerpf(_shade_panel.offset_top, 0.0, clampf(delta * 12.0, 0.0, 1.0))
	if _shade_panel.offset_top > -1.0:
		_shade_panel.offset_top = 0.0
	_shade_panel.offset_bottom = _shade_panel.offset_top + _shade_h
func _clock_hour() -> float:
	return float(hud.weather.get("hour", 21.0)) if hud != null else 21.0

func _clock_str() -> String:
	var hour := _clock_hour()
	var h := int(hour) % 24
	var m := int((hour - floorf(hour)) * 60.0) % 60
	return "%02d:%02d" % [h, m]

# ------------------------------------------------------------------ test hooks
func debug_demo() -> void:
	_demo_queue = ["show_soon", "storm", "tornado"]

func debug_one(kind: String) -> void:
	_post_kind(kind)

## Fill the history and open the notification centre, for a shot. `folded` shows the collapsed group summary.
func debug_shade(folded := false) -> void:
	for k in ["show_start", "storm", "waterspout", "fogbank", "thermals", "show_over"]:
		_post_kind(k)
	_shade_expanded = not folded
	open_shade()

func debug_clear() -> void:
	_history.clear()
	_clear_heads_up()
	_group_n = 0
	close_shade()

func stats() -> Dictionary:
	return {"cards": _cards.size(), "history": _history.size(), "queued": _demo_queue.size(),
		"enabled": enabled, "style": _style, "shade": _shade_open}
