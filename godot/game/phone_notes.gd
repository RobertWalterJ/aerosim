class_name PhoneNotes
extends CanvasLayer
## Phone-style notification bundle for world events (session B, from Robert's notes).
##
## The player's drone app is a made-up phone app called "DroneBudz": a group of drone friends who text when something
## is about to happen. When a show is about to start, a storm is building, a tornado touches down or the fog rolls in,
## a notification drops in at the top right of the screen, in the look of an iOS or Android notification bundle: the
## newest card in front with the app icon, the app name, the sender, the message and a "now" stamp, and older cards
## stacked behind it, with "N more notifications" when there is a pile. The cards slide in, fade after a few seconds
## and never use the white warning line the drone itself uses for flight warnings.
##
## It is UI only: it reads state and listens to the event runtime (game/weather_events.gd) and the fireworks runtime
## (game/fireworks.gd through main.gd), draws everything itself (no image assets are required), and is switched off from
## Display > Overlay and sound > Phone messages. Fonts are the project defaults, so it works on a phone and in the
## Simple camera.

const APP := "DroneBudz"
const MAX_CARDS := 4
const CARD_LIFE := 9.5            # seconds a card stays before it fades
const SENDERS := ["Maya", "Tom", "Riley", "Jo", "Sam", "Alex"]

## Messages by event kind: [sender, title, body, urgency]. Urgency 0 is chat, 1 amber, 2 red.
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
var _root: Control
var _cards: Array[Dictionary] = []     # newest first: {holder, foot, body, t, fade, msg, idx}
var _rng := RandomNumberGenerator.new()
var _demo_queue: Array[String] = []
var _demo_t := 0.0
var _w := 400.0

## A little drawn app icon: a green chat square with a white quadcopter and an urgency dot. No image asset needed.
class AppIcon extends Control:
	var urgency := 0
	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.55, 0.36)          # DroneBudz green
		sb.set_corner_radius_all(11)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var c := size * 0.5
		var s := size.x
		var white := Color(0.96, 0.99, 0.97)
		draw_line(c + Vector2(-0.30, -0.30) * s, c + Vector2(0.30, 0.30) * s, white, 2.2)
		draw_line(c + Vector2(0.30, -0.30) * s, c + Vector2(-0.30, 0.30) * s, white, 2.2)
		draw_circle(c + Vector2(-0.30, -0.30) * s, 0.11 * s, white)
		draw_circle(c + Vector2(0.30, -0.30) * s, 0.11 * s, white)
		draw_circle(c + Vector2(-0.30, 0.30) * s, 0.11 * s, white)
		draw_circle(c + Vector2(0.30, 0.30) * s, 0.11 * s, white)
		var body := StyleBoxFlat.new()
		body.bg_color = white
		body.set_corner_radius_all(3)
		draw_style_box(body, Rect2(c + Vector2(-0.09, -0.13) * s, Vector2(0.18, 0.26) * s))
		if urgency > 0:
			draw_circle(Vector2(size.x - 6, 6), 5.5, Color(0.95, 0.72, 0.18) if urgency == 1 else Color(0.92, 0.22, 0.20))

func setup(h: Hud) -> void:
	hud = h
	layer = 20
	_rng.seed = 424242
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

func update(delta: float, paused: bool) -> void:
	enabled = true if hud == null else bool(hud.phone_notes)
	_root.visible = enabled and not paused and (not _cards.is_empty() or not _demo_queue.is_empty())
	if not _root.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	_w = clampf(vp.x * 0.36, 340.0, 480.0)
	# the demo queue (a test hook) drips its messages in so they bundle like a phone would
	if not _demo_queue.is_empty():
		_demo_t += delta
		if _demo_t >= 0.55:
			_demo_t = 0.0
			_post_kind(_demo_queue.pop_front())
	# age the cards: each card has its own clock and fades out after a while
	var remove: Array = []
	for c in _cards:
		c["t"] = float(c["t"]) + delta
		var life := CARD_LIFE + 3.0 * float(c.get("idx", 0))
		c["fade"] = clampf(1.0 - (float(c["t"]) - life) / 0.6, 0.0, 1.0)
		if float(c["fade"]) <= 0.0:
			remove.append(c)
	# layout the stack: newest in front, older behind and slightly down, like an iOS or Android bundle
	var n := _cards.size()
	for i in n:
		var c: Dictionary = _cards[i]
		c["idx"] = i
		var holder: PanelContainer = c["holder"]
		var target_x := vp.x - _w - 26.0 - 10.0 * float(i)
		var target_y := 26.0 + 12.0 * float(i)
		var enter := clampf(float(c["t"]) / 0.24, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - enter, 3.0)
		holder.position = Vector2(target_x - (1.0 - ease) * 30.0, lerpf(-70.0, target_y, ease))
		var sc := 1.0 - 0.035 * float(i)
		holder.scale = Vector2(sc, sc)
		holder.modulate.a = float(c["fade"]) * (0.62 if i > 0 else 1.0)
		var foot: Label = c["foot"]
		if i == 0 and n > 1:
			foot.visible = true
			foot.text = "%d more notification%s" % [n - 1, "" if n == 2 else "s"]
		else:
			foot.visible = false
	for c in remove:
		(c["holder"] as PanelContainer).queue_free()
		_cards.erase(c)
	while _cards.size() > MAX_CARDS:
		var dead: Dictionary = _cards.pop_back()
		(dead["holder"] as PanelContainer).queue_free()

## Post an event notification by kind: show_soon, show_start, show_over, storm, tornado, waterspout, dustdevil,
## thermals, fogbank, snowsquall, surprise. Safe to call repeatedly; it does not de-duplicate.
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
	# work out the phone width now: the card must be laid out at its final width, or the wrapped body text leaves
	# empty space when the width changes later
	var vp := get_viewport().get_visible_rect().size
	_w = clampf(vp.x * 0.36, 340.0, 480.0)
	while _cards.size() >= MAX_CARDS:
		var old: Dictionary = _cards.pop_back()
		(old["holder"] as PanelContainer).queue_free()
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(_w, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.135, 0.145, 0.95)
	sb.set_corner_radius_all(20)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.09)
	sb.shadow_color = Color(0, 0, 0, 0.40)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 7)
	card.add_theme_stylebox_override("panel", sb)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	# a little drawing of the app icon: no image asset is needed, so it works in every language and on every phone
	var icon := AppIcon.new()
	icon.custom_minimum_size = Vector2(44, 44)
	icon.size = Vector2(44, 44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon.urgency = int(msg.get("urgency", 0))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var app := Label.new()
	app.text = APP
	app.add_theme_font_size_override("font_size", 15)
	app.add_theme_color_override("font_color", Color(0.78, 0.80, 0.82))
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(app)
	var stamp := Label.new()
	stamp.text = "now"
	stamp.add_theme_font_size_override("font_size", 13)
	stamp.add_theme_color_override("font_color", Color(0.62, 0.64, 0.66))
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(stamp)
	var title := Label.new()
	title.text = str(msg["sender"])
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.97, 0.97, 0.98))
	# names are short: no wrap, or the label's minimum height explodes while it is being laid out
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	col.add_child(title)
	var body := Label.new()
	body.text = str(msg["body"])
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.80, 0.81, 0.83))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(_w - 28.0 - 44.0 - 12.0, 0)
	col.add_child(body)
	var foot := Label.new()
	foot.text = ""
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.60, 0.62, 0.65))
	foot.visible = false
	col.add_child(foot)
	_root.add_child(card)
	# now let the card size itself to its content, then keep that height for the stack layout
	var h := card.get_combined_minimum_size().y
	card.size = Vector2(_w, h)
	_cards.insert(0, {"holder": card, "foot": foot, "body": body, "t": 0.0, "fade": 1.0, "idx": 0, "msg": msg})

## A test hook: three messages arriving close together, so the bundle stacks like a phone would.
func debug_demo() -> void:
	_demo_queue = ["show_soon", "storm", "tornado"]

## A single event message, for the event screenshots.
func debug_one(kind: String) -> void:
	_post_kind(kind)

func stats() -> Dictionary:
	return {"cards": _cards.size(), "queued": _demo_queue.size(), "enabled": enabled}
