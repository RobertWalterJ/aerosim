class_name MarketplaceApp
extends Control
## Facade, the valley's classifieds board (session B). It is where the channel pot turns into the kit: two new drones,
## a night vision module, motor upgrades and a bigger battery. MugShot Motors is the seller for the drone gear; the
## favours and the honest parts come from the crew.
##
## Money is the same pot VidTube Studio shows. Purchases are saved by Inventory and applied to the airframes when they
## are built. The app is hosted by PhoneOS; flying a purchased drone emits fly_requested and puts the phone away.

signal fly_requested(id: String)

const KIND_LABEL := {"drone": "DRONE", "camera": "CAMERA", "motor": "MOTORS", "part": "PART"}

var jobs: Jobs
var inventory: Inventory
var hud: Hud
var _tab := "market"
var _kind := ""
var _query := ""
var _money: Label
var _search: LineEdit
var _list: VBoxContainer
var _tab_market: Button
var _tab_kit: Button
var _chips: HBoxContainer

func setup(j: Jobs, inv: Inventory, h: Hud) -> void:
	jobs = j
	inventory = inv
	hud = h
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
	# header
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 22.0, 14.0))
	col.add_child(head)
	var hm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 22)
	head.add_child(hm)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	hm.add_child(hrow)
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(58, 58)
	mark.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.30, 0.22, 0.14), 16, UniverseUI.AMBER, 1, 0.0, 0.0))
	var ml := UniverseUI.label("FC", 20, UniverseUI.CREAM)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(ml)
	hrow.add_child(mark)
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 0)
	hrow.add_child(title_col)
	title_col.add_child(UniverseUI.label("FACADE", 28, UniverseUI.CREAM))
	title_col.add_child(UniverseUI.label("The valley classifieds  ·  MugShot Motors and friends", 11, UniverseUI.MUTED))
	var pot := VBoxContainer.new()
	pot.add_theme_constant_override("separation", 0)
	hrow.add_child(pot)
	pot.add_child(UniverseUI.label("CHANNEL POT", 9, UniverseUI.MUTED))
	_money = UniverseUI.label("$0", 28, UniverseUI.AMBER)
	pot.add_child(_money)
	# tabs and search
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", 22)
	bar.add_theme_constant_override("margin_right", 22)
	bar.add_theme_constant_override("margin_top", 10)
	col.add_child(bar)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 8)
	bar.add_child(bcol)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	bcol.add_child(tab_row)
	_tab_market = Button.new(); _tab_market.text = "Market"; _tab_market.theme_type_variation = "Ghost"
	_tab_market.custom_minimum_size = Vector2(110, 34)
	_tab_market.pressed.connect(func(): _tab = "market"; refresh())
	tab_row.add_child(_tab_market)
	_tab_kit = Button.new(); _tab_kit.text = "Your kit"; _tab_kit.theme_type_variation = "Ghost"
	_tab_kit.custom_minimum_size = Vector2(110, 34)
	_tab_kit.pressed.connect(func(): _tab = "kit"; refresh())
	tab_row.add_child(_tab_kit)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(spacer)
	_search = LineEdit.new()
	_search.placeholder_text = "Search the board: drone, motor, night vision..."
	_search.custom_minimum_size = Vector2(330, 36)
	_search.text_changed.connect(func(t): _query = t.to_lower().strip_edges(); _refresh_list())
	tab_row.add_child(_search)
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 6)
	bcol.add_child(_chips)
	for pair in [["All", ""], ["Drones", "drone"], ["Camera", "camera"], ["Motors", "motor"], ["Parts", "part"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.theme_type_variation = "Chip"
		b.custom_minimum_size = Vector2(0, 26)
		var kind := str(pair[1])
		b.pressed.connect(func(): _kind = kind; refresh())
		_chips.add_child(b)
	# list
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + m, 22)
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	refresh()

func refresh() -> void:
	if _money != null and jobs != null:
		_money.text = "$" + str(jobs.money())
	if _tab_market != null:
		_tab_market.add_theme_color_override("font_color", UniverseUI.AMBER if _tab == "market" else UniverseUI.MUTED)
		_tab_kit.add_theme_color_override("font_color", UniverseUI.AMBER if _tab == "kit" else UniverseUI.MUTED)
	if _chips != null:
		_chips.visible = _tab == "market"
	if _search != null:
		_search.visible = _tab == "market"
	_refresh_list()

func _refresh_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	if _tab == "kit":
		_build_kit()
		return
	var shown := 0
	for item in FacadeCatalog.ITEMS:
		if _kind != "" and str(item.get("kind", "")) != _kind:
			continue
		var hay := (str(item.get("title", "")) + " " + str(item.get("seller", "")) + " " + str(item.get("desc", "")) + " " + str(item.get("condition", ""))).to_lower()
		if _query != "" and not hay.contains(_query):
			continue
		_list.add_child(_listing(item))
		shown += 1
	if shown == 0:
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", UniverseUI.card(14))
		_list.add_child(empty)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 18)
		empty.add_child(m)
		m.add_child(UniverseUI.label("Nothing on the board for that search. Try a drone, a motor or night vision.", 14, UniverseUI.MUTED))

func _listing(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := UniverseUI.card(14, UniverseUI.CARD)
	card.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	card.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	m.add_child(row)
	var kind := str(item.get("kind", "part"))
	var tint := _kind_colour(kind)
	var thumb := PanelContainer.new()
	thumb.custom_minimum_size = Vector2(76, 72)
	thumb.add_theme_stylebox_override("panel", UniverseUI.box(tint.darkened(0.55), 12, Color(tint.r, tint.g, tint.b, 0.5), 1, 0.0, 0.0))
	var tl := UniverseUI.label(str(KIND_LABEL.get(kind, "KIT")), 10, UniverseUI.CREAM)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb.add_child(tl)
	row.add_child(thumb)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	text.add_child(UniverseUI.label(str(item.get("title", "")), 18, UniverseUI.CREAM))
	var seller := "%s  ·  %s  ·  %s" % [str(item.get("seller", "")), str(item.get("place", "")), str(item.get("condition", ""))]
	text.add_child(UniverseUI.label(seller, 10, UniverseUI.MUTED))
	var desc := UniverseUI.label(str(item.get("desc", "")), 12, UniverseUI.CREAM_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	text.add_child(desc)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.custom_minimum_size = Vector2(132, 0)
	row.add_child(right)
	var price := UniverseUI.label("$" + str(int(item.get("price", 0))), 24, UniverseUI.AMBER)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(price)
	var owned := inventory != null and inventory.owns_item(item)
	var requires := str(item.get("requires", ""))
	var needs_drone := requires != "" and inventory != null and not inventory.owns_drone(requires)
	if owned:
		if kind == "drone":
			var fly := Button.new(); fly.text = "Fly it"; fly.theme_type_variation = "Primary"
			fly.custom_minimum_size = Vector2(0, 34)
			var drone_id := str(item.get("target", ""))
			fly.pressed.connect(func(): fly_requested.emit(drone_id))
			right.add_child(fly)
		else:
			var owned_l := UniverseUI.label("OWNED", 10, UniverseUI.MOSS)
			owned_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			right.add_child(owned_l)
			if kind == "camera" and str(item.get("id", "")) == "night_vision":
				var hint := UniverseUI.label("Press K in flight", 9, UniverseUI.MUTED)
				hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				right.add_child(hint)
	elif needs_drone:
		var need := UniverseUI.label("NEEDS " + requires.to_upper(), 9, UniverseUI.RUST)
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(need)
	else:
		var buy := Button.new()
		var affordable := jobs != null and jobs.money() >= int(item.get("price", 0))
		buy.text = "Buy" if affordable else "Need more"
		buy.theme_type_variation = "Primary" if affordable else "Ghost"
		buy.custom_minimum_size = Vector2(0, 34)
		buy.disabled = not affordable
		buy.pressed.connect(func(): _buy(item))
		right.add_child(buy)
	return card

func _buy(item: Dictionary) -> void:
	if jobs == null or inventory == null:
		return
	var price := int(item.get("price", 0))
	if not jobs.spend(price):
		if hud != null:
			hud.toast("Facade: not enough in the channel pot for " + str(item.get("title", "that")))
		return
	inventory.add_purchase(item)
	if hud != null:
		hud.toast("Facade: " + str(item.get("title", "purchase")) + " added to your kit")
	refresh()

func _build_kit() -> void:
	var intro := UniverseUI.label("YOUR KIT  ·  the drones, cameras and parts bought with the channel pot", 10, UniverseUI.AMBER)
	_list.add_child(intro)
	for id in inventory.available_drones():
		var af := Airframes.make(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UniverseUI.card(12))
		_list.add_child(card)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 10)
		card.add_child(m)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		m.add_child(row)
		var text := VBoxContainer.new(); text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(UniverseUI.label(str(af.get("name", id)), 16, UniverseUI.CREAM))
		var owned_new: bool = id in Inventory.BASE_DRONES
		text.add_child(UniverseUI.label("INCLUDED" if owned_new else "BOUGHT ON FACADE", 9, UniverseUI.MUTED if owned_new else UniverseUI.MOSS))
		var motor := inventory.motor_for(id)
		if motor != "":
			text.add_child(UniverseUI.label("MOTORS FITTED  ·  " + motor.replace("motor_", "").replace("_", " ").to_upper(), 9, UniverseUI.AMBER))
		var fly := Button.new(); fly.text = "Fly"; fly.theme_type_variation = "Primary"
		fly.custom_minimum_size = Vector2(86, 32)
		var drone_id := str(id)
		fly.pressed.connect(func(): fly_requested.emit(drone_id))
		row.add_child(fly)
	_list.add_child(UniverseUI.label("CAMERA AND PARTS", 10, UniverseUI.AMBER))
	var addons := 0
	if inventory.has_addon("night_vision"):
		_list.add_child(_owned_row("Night vision module", "Owned  ·  press K in flight to toggle"))
		addons += 1
	if inventory.has_battery():
		_list.add_child(_owned_row("High-capacity battery", "Fitted to every airframe"))
		addons += 1
	for id in inventory._motors.keys():
		var item := FacadeCatalog.item(str(inventory._motors[id]))
		if not item.is_empty():
			_list.add_child(_owned_row(str(item.get("title", "Motor upgrade")), "Fitted to " + str(Airframes.make(str(id)).get("name", id))))
	if addons == 0 and inventory._motors.is_empty():
		_list.add_child(UniverseUI.label("No camera or parts yet. MugShot Motors has a night vision module on the board.", 12, UniverseUI.MUTED))

func _owned_row(title: String, sub: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UniverseUI.card(10))
	_list.add_child(card)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 9)
	card.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	m.add_child(col)
	col.add_child(UniverseUI.label(title, 14, UniverseUI.CREAM))
	col.add_child(UniverseUI.label(sub, 9, UniverseUI.MOSS))
	return card

func _kind_colour(kind: String) -> Color:
	match kind:
		"drone": return UniverseUI.RUST
		"camera": return UniverseUI.LAKE
		"motor": return UniverseUI.AMBER
		"part": return UniverseUI.MOSS
	return UniverseUI.MUTED

func stats() -> Dictionary:
	return {"tab": _tab, "kind": _kind, "query": _query, "money": jobs.money() if jobs != null else 0, "kit": inventory.stats() if inventory != null else {}}

## Dev hooks for screenshots and the gate.
func debug_tab(name: String) -> void:
	_tab = name
	refresh()

func debug_query(q: String) -> void:
	_query = q.to_lower()
	if _search != null:
		_search.text = q
	refresh()

