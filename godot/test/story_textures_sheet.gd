extends SceneTree
## A sheet of labelled swatches of every texture and material the storm and endgame assets (models9) use: the photographed CC0 sets (a crop of the
## albedo, the Poly Haven source, the author and the licence, where it is used) and the plain materials that are only colour and PBR numbers.
## Needs a window (not headless): Godot --path <godot dir> --resolution 480x270 -s res://test/story_textures_sheet.gd -- [out=<jpg>]

const SWATCH := 200
const CELL := Vector2i(430, 330)
const COLS := 4

# [material key in the story files, texture file stem, what it is, source, author, licence, used on]
const PHOTO := [
	["wood", "postwood", "Rough weathered timber", "Poly Haven rough_wood (polyhaven.com/a/rough_wood), 1k", "Rob Tuytel", "CC0", "cabin boards, planks, posts, doors, furniture, shelter beams"],
	["paintwood", "barnwood", "Painted and bare grey boards", "Poly Haven wood_planks_grey (polyhaven.com/a/wood_planks_grey), 1k", "Rob Tuytel", "CC0", "cabin weatherboards, barn panel, chapel walls, weather screen"],
	["roof", "roofsteel", "Corrugated galvanised iron", "Poly Haven corrugated_iron (polyhaven.com/a/corrugated_iron), 1k", "Dimitrios Savva, Jenelle van Heerden", "CC0", "cabin and rail hut roofs"],
	["stone", "rubble", "Fieldstone wall", "Poly Haven stone_wall (polyhaven.com/a/stone_wall), 1k", "Charlotte Baglioni, Dario Barresi", "CC0", "shelter, retaining wall, chimney, piers"],
	["concrete", "silocrete", "Concrete staves", "Poly Haven concrete_wall_004 (polyhaven.com/a/concrete_wall_004), 1k", "Charlotte Baglioni, Dario Barresi", "CC0", "hatch surround, footings, aerial base"],
	["brick", "brick", "Red brick", "Poly Haven red_brick_03 (polyhaven.com/a/red_brick_03), 1k", "Rob Tuytel", "CC0", "chimney cap, tarp weights"],
	["soil", "plough", "Ploughed farm soil", "Poly Haven farm_soil (polyhaven.com/a/farm_soil), 1k", "Amal Kumar", "CC0", "scoured patch, root plate, sandbag spill"],
	["mud", "mudtrack", "Wet mud track", "Poly Haven aerial_mud_1 (polyhaven.com/a/aerial_mud_1), 1k", "Rob Tuytel", "CC0", "tyre ruts, flooded ditch, sign mud"],
	["hay", "straw", "Straw and reed chaff", "Poly Haven riet_01 (polyhaven.com/a/riet_01), 1k", "Rob Tuytel", "CC0", "ditch reeds, torn grass"],
]

# [material key, label, colour, what it is, used on]
const PLAIN := [
	["steel", "Galvanised steel (zinc bloom)", Color(0.5, 0.52, 0.54), "procedural, farm_props kind 1; no photograph", "roof sheets, tin, wire, hinges"],
	["cloth / canvas / tarp", "Woven cloth", Color(0.3, 0.34, 0.27), "colour and roughness only (own work, CC0)", "tents, sandbags, coat, blankets"],
	["rubber / leather", "Rubber and leather", Color(0.16, 0.1, 0.07), "colour and roughness only (own work, CC0)", "boots, cords, shingles, belts"],
	["enamel / chrome", "Enamel, chrome, sheet metal", Color(0.78, 0.74, 0.6), "colour, clear-coat and metal numbers (own work, CC0)", "kettle, bell, gauges, radio, pod"],
	["glass / water", "Glass and water", Color(0.2, 0.22, 0.28), "translucent PBR (own work, CC0)", "windows, ampoule, bottle, flood water"],
	["lamp / warm / flame", "Lit panes and flame", Color(1.0, 0.82, 0.5), "emissive PBR (own work, CC0)", "cabin windows, lanterns, torch, stove"],
	["paper", "Paper and card", Color(0.88, 0.84, 0.7), "colour only; lettering is real geometry from our own 5 x 7 block alphabet", "maps, diaries, newspaper, signs"],
	["steam", "Steam and smoke", Color(0.9, 0.9, 0.92), "translucent, soft discs and cones (own work, CC0)", "kettle steam, chimney smoke, torch beam"],
]

var _out := "res://docs/realism/models/storm_endgame_final_textures.jpg"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	_run.call_deferred()

func _label(parent: Node, txt: String, pos: Vector2, size: int, col: Color, w := 410.0) -> void:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.custom_minimum_size = Vector2(w, 10)
	l.size = Vector2(w, 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)

func _run() -> void:
	var total := PHOTO.size() + PLAIN.size()
	var rows := int(ceil(total / float(COLS)))
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * COLS, CELL.y * rows + 90)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.1, 0.11); bg.size = Vector2(vp.size); vp.add_child(bg)
	_label(vp, "Textures and materials used by the storm and endgame assets (models9)", Vector2(20, 14), 26, Color.WHITE, 1600)
	_label(vp, "Every photographed set is Poly Haven, CC0, shown as its albedo tile. The rest are plain colour and PBR numbers, own work, CC0. No imagery from aerial or street photography.", Vector2(20, 52), 15, Color(0.8, 0.8, 0.82), 1650)
	var i := 0
	for e in PHOTO:
		var at := Vector2((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 90)
		var path := "res://assets/textures/%s_diff.jpg" % e[1]
		var sw := TextureRect.new()
		sw.position = at + Vector2(0, 22)
		sw.size = Vector2(SWATCH, SWATCH)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_SCALE
		if ResourceLoader.exists(path):
			var img: Image = (load(path) as Texture2D).get_image()
			if img.is_compressed(): img.decompress()
			sw.texture = ImageTexture.create_from_image(img)
		vp.add_child(sw)
		_label(vp, "%s  (key \"%s\")" % [e[2], e[0]], at, 15, Color(1, 1, 1), 410)
		_label(vp, "%s\n%s\n%s" % [e[3], e[4], e[5]], at + Vector2(0, SWATCH + 26), 12, Color(0.78, 0.8, 0.85), 410)
		_label(vp, _wrap("Used on: " + String(e[6]), 26), at + Vector2(SWATCH + 8, 24), 12, Color(0.7, 0.85, 0.7), 200)
		i += 1
	for e in PLAIN:
		var at2 := Vector2((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 90)
		var cr := ColorRect.new(); cr.color = e[2]; cr.position = at2 + Vector2(0, 22); cr.size = Vector2(SWATCH, SWATCH); vp.add_child(cr)
		var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.18); shade.position = at2 + Vector2(SWATCH * 0.5, 22); shade.size = Vector2(SWATCH * 0.5, SWATCH); vp.add_child(shade)
		_label(vp, "%s  (key \"%s\")" % [e[1], e[0]], at2, 15, Color(1, 1, 1), 410)
		_label(vp, _wrap("No photograph: " + String(e[3]), 62), at2 + Vector2(0, SWATCH + 26), 12, Color(0.78, 0.8, 0.85), 410)
		_label(vp, _wrap("Used on: " + String(e[4]), 26), at2 + Vector2(SWATCH + 8, 24), 12, Color(0.7, 0.85, 0.7), 200)
		i += 1
	for k in 6: await process_frame
	await RenderingServer.frame_post_draw
	var img2 := vp.get_texture().get_image()
	var p := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	print("textures sheet: %s (%s)" % [p, error_string(img2.save_jpg(p, 0.9))])
	quit()

## Breaks a line into lines of about n characters at spaces.
func _wrap(s: String, n: int) -> String:
	var out := ""
	var line := ""
	for w in s.split(" "):
		if line.length() + w.length() + 1 > n and line != "":
			out += line + "\n"
			line = w
		else:
			line = w if line == "" else line + " " + w
	return out + line
