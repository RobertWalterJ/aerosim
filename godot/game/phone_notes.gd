class_name PhoneNotes
extends CanvasLayer
## Real phone notification look for the DroneBudz group chat (session B, rework after Robert's note).
##
## Two styles, chosen in Display > Overlay and sound > Phone style:
##   iPhone  a frosted glass card at the top of the screen: a blurred backdrop taken from the FPV feed, a real rounded
##           glass rim, the app icon, "DRONEBUDZ" in small caps, a "now" stamp, a sender avatar, the sender name in
##           semibold, the message and "N more notifications" when several arrive together. Older cards sit behind it
##           and peek out at the bottom, scaled and dimmed, like an iOS notification group.
##   Android a Material style surface: a nearly opaque rounded card with a little elevation, the app icon and app name
##           with the timestamp, a small expand chevron, the sender in bold and the message.
##
## Both slide in from the top, settle with a spring, stay about ten seconds and fade out. Everything is drawn in code
## (the icon and the avatars are drawn, no PNGs), so there is nothing to load and nothing to conflict.
##
## The bundle is fed by the fireworks runtime and the weather event runtime through a few guarded post() calls, and is
## switched off with Phone messages (or when the game is paused). Drone flight warnings keep the white warning line.

const APP := "DroneBudz"
const MAX_CARDS := 4
const CARD_LIFE := 10.0
const SENDERS := ["Maya", "Tom", "Riley", "Jo", "Sam", "Alex"]
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

## Style constants: 0 iPhone, 1 Android. hud.phone_style carries the choice.
var enabled := true
var hud: Hud
var _root: Control
var _cards: Array[Dictionary] = []     # newest first
var _rng := RandomNumberGenerator.new()
var _demo_queue: Array[String] = []
var _demo_t := 0.0
var _style := 0
var _card_w := 420.0
var _f_regular: FontVariation
var _f_semibold: FontVariation
var _f_spaced: FontVariation
var _glass_cache := {}

# ------------------------------------------------------------------ drawn icons (no image assets)
class AppIcon extends Control:
	var urgency := 0
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.52, 0.34)
		sb.set_corner_radius_all(int(size.x * 0.26))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		var s := size.x
		var white := Color(0.97, 0.99, 0.98)
		draw_line(c + Vector2(-0.31, -0.31) * s, c + Vector2(0.31, 0.31) * s, white, maxf(1.4, s * 0.055))
		draw_line(c + Vector2(0.31, -0.31) * s, c + Vector2(-0.31, 0.31) * s, white, maxf(1.4, s * 0.055))
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
		draw_arc(c, size.x * 0.5 - 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.16), 1.0, true)
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
		draw_polyline(PackedVector2Array([c + Vector2(-w * 0.22, -h * 0.14), c + Vector2(0, h * 0.16), c + Vector2(w * 0.22, -h * 0.14)]), Color(0.72, 0.74, 0.78, 0.9), 1.8, true)

# ------------------------------------------------------------------ setup
func setup(h: Hud) -> void:
	hud = h
	layer = 20
	_rng.seed = 424242
	_f_regular = FontVariation.new()
	_f_regular.base_font = ThemeDB.fallback_font
	_f_semibold = FontVariation.new()
	_f_semibold.base_font = ThemeDB.fallback_font
	_f_semibold.variation_embolden = 0.5
	_f_spaced = FontVariation.new()
	_f_spaced.base_font = ThemeDB.fallback_font
	_f_spaced.variation_embolden = 0.25
	_f_spaced.spacing_glyph = 1
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	# a back buffer copy so the glass shader can sample and blur the FPV feed behind the cards
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(bbc)

func _process(_delta: float) -> void:
	pass   # main.gd calls update once a frame

# ------------------------------------------------------------------ per frame
func update(delta: float, paused: bool) -> void:
	enabled = true if hud == null else bool(hud.phone_notes)
	var style := 0 if hud == null else int(hud.phone_style)
	if style != _style:
		# rebuild the same messages in the new style instead of dropping them
		var msgs: Array = []
		for c in _cards:
			msgs.append(c["msg"])
		for c in _cards:
			(c["holder"] as Control).queue_free()
		_cards.clear()
		_style = style
		for m in msgs:
			_add(m)
	_root.visible = enabled and not paused and (not _cards.is_empty() or not _demo_queue.is_empty())
	if not _root.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	_card_w = clampf(vp.x * (0.335 if _style == 0 else 0.35), 360.0, 470.0)
	if not _demo_queue.is_empty():
		_demo_t += delta
		if _demo_t >= 0.55:
			_demo_t = 0.0
			_post_kind(_demo_queue.pop_front())
	# age and expire
	var remove: Array = []
	for c in _cards:
		c["t"] = float(c["t"]) + delta
		var life := CARD_LIFE + 3.0 * float(c.get("idx", 0))
		c["fade"] = clampf(1.0 - (float(c["t"]) - life) / 0.6, 0.0, 1.0)
		if float(c["fade"]) <= 0.0:
			remove.append(c)
	# layout: newest front and highest, older cards behind and lower, the way a phone groups notifications
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
		var sc := 1.0 - 0.022 * float(i)
		holder.scale = Vector2(sc, sc)
		holder.modulate.a = float(c["fade"]) * (0.62 if i > 0 else 1.0)
		var foot: Label = c["foot"]
		if i == 0 and n > 1:
			foot.visible = true
			foot.text = "%d more notification%s" % [n - 1, "" if n == 2 else "s"]
		else:
			foot.visible = false
		_size_card(c, float(c["fade"]))
	for c in remove:
		(c["holder"] as Control).queue_free()
		_cards.erase(c)
	while _cards.size() > MAX_CARDS:
		var dead: Dictionary = _cards.pop_back()
		(dead["holder"] as Control).queue_free()

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
	var vp := get_viewport().get_visible_rect().size
	_card_w = clampf(vp.x * (0.335 if _style == 0 else 0.35), 360.0, 470.0)
	while _cards.size() >= MAX_CARDS:
		var old: Dictionary = _cards.pop_back()
		(old["holder"] as Control).queue_free()
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(_card_w, 10)
	_root.add_child(holder)
	# the soft shadow under the card (a transparent panel style only draws its shadow)
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
	# the glass or surface fill
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
		gm.set_shader_parameter("tint", Vector3(0.13, 0.135, 0.15))
		gm.set_shader_parameter("tint_amount", 0.94)
		gm.set_shader_parameter("blur_px", 3.0)
		gm.set_shader_parameter("edge_light", 0.35)
		gm.set_shader_parameter("grain", 0.5)
	glass.material = gm
	holder.add_child(glass)
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# the content
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
	var sender := str(msg["sender"])
	var urgency := int(msg.get("urgency", 0))
	# header: app icon, app name, time, and on Android a little expand chevron
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 7)
	col.add_child(head)
	var icon_size := 28.0 if _style == 0 else 24.0
	var icon := AppIcon.new()
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.urgency = urgency if _style == 0 else 0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(icon)
	var app := Label.new()
	app.text = "DRONEBUDZ" if _style == 0 else "DroneBudz"
	app.add_theme_font_override("font", _f_spaced if _style == 0 else _f_regular)
	app.add_theme_font_size_override("font_size", 12 if _style == 0 else 13)
	app.add_theme_color_override("font_color", Color(0.70, 0.72, 0.76) if _style == 0 else Color(0.78, 0.80, 0.83))
	app.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(app)
	if urgency > 0 or _style == 1:
		var dot := Color(0.98, 0.73, 0.16) if urgency == 1 else Color(0.95, 0.24, 0.21)
		if urgency == 0:
			dot = Color(0.33, 0.75, 0.45)
		var bullet := Label.new()
		bullet.text = "  •"
		bullet.add_theme_font_size_override("font_size", 12)
		bullet.add_theme_color_override("font_color", dot)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(bullet)
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
	if _style == 1:
		var ch := Chevron.new()
		ch.custom_minimum_size = Vector2(16, 16)
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(ch)
	# the message body: iPhone shows the sender avatar and the name next to it, Android keeps it flatter
	var body_row := HBoxContainer.new()
	body_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_theme_constant_override("separation", 10)
	col.add_child(body_row)
	var avatar_w := 0.0
	if _style == 0:
		var av := Avatar.new()
		av.letter = sender.substr(0, 1).to_upper()
		av.col = SENDER_COL.get(sender, Color(0.4, 0.5, 0.6))
		av.custom_minimum_size = Vector2(34, 34)
		av.size = Vector2(34, 34)
		av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body_row.add_child(av)
		avatar_w = 34.0 + 10.0
	var vcol := VBoxContainer.new()
	vcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vcol.add_theme_constant_override("separation", 1)
	vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(vcol)
	var title := Label.new()
	title.text = sender
	title.add_theme_font_override("font", _f_semibold)
	title.add_theme_font_size_override("font_size", 16 if _style == 0 else 17)
	title.add_theme_color_override("font_color", Color(0.97, 0.97, 0.98))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	vcol.add_child(title)
	var body := Label.new()
	body.text = str(msg["body"])
	body.add_theme_font_override("font", _f_regular)
	body.add_theme_font_size_override("font_size", 14 if _style == 0 else 14)
	body.add_theme_color_override("font_color", Color(0.80, 0.82, 0.85) if _style == 0 else Color(0.72, 0.74, 0.78))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(_card_w - pad * 2 - avatar_w - 2, 0)
	vcol.add_child(body)
	var foot := Label.new()
	foot.text = ""
	foot.add_theme_font_override("font", _f_regular)
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(0.60, 0.62, 0.66))
	foot.visible = false
	col.add_child(foot)
	_cards.insert(0, {"holder": holder, "foot": foot, "glass": glass, "margin": margin, "t": 0.0, "fade": 1.0, "idx": 0, "msg": msg})
	_size_card(_cards[0], 1.0)

## Size the holder and the shader to the content height. Runs every frame because the footer can appear or go away.
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

# ------------------------------------------------------------------ test hooks
func debug_demo() -> void:
	_demo_queue = ["show_soon", "storm", "tornado"]

func debug_one(kind: String) -> void:
	_post_kind(kind)

func stats() -> Dictionary:
	return {"cards": _cards.size(), "queued": _demo_queue.size(), "enabled": enabled, "style": _style}
