extends SceneTree
## lane/wreckvan: the textures and materials of anne_car_wreck_a and police_dive_van_a (copied from vehicles_textures_sheet.gd).
## The textures and materials the Blender vehicles use (game/vehicle_assets.gd): every material slot drawn on a sphere with
## the game's own vehicle shaders (paint, glass, chrome, rubber...), labelled with what it is, where it is used and where it
## came from, and the three photographed CC0 maps shown as tiles with their source, author and licence.
## Needs a window: Godot --path <godot dir> --resolution 480x270 -s res://test/wreckvan_textures_sheet.gd -- [out=<jpg>]

const COLS := 6
const CELL := Vector2i(330, 360)
const BALL := 200

# [slot, label, colour (sRGB; null = the shader's own), finish, used on, wreck (true = with the wreck's silt line and paint photo)]
const SLOTS := [
	["paint", "Wreck paint, pale blue", Color(0.60, 0.71, 0.78), "no clear coat; paint photo spots it with rust", "Anne's car", true],
	["paint", "Wreck paint at the water line", Color(0.60, 0.71, 0.78), "water line through the middle: silt, algae below", "Anne's car, lower body", "line"],
	["glass", "Wreck glass", null, "silted below the line, grimed above", "Anne's car windows", true],
	["silt", "Lake silt bed", Color(0.5, 0.5, 0.5), "silt photo + its normal map, wet glossy hollows", "the bed round the wreck", false],
	["weed", "Lake weed, green", Color(0.10, 0.13, 0.045), "matte, both sides", "sedge tufts, pondweed, shoots in the cabin", false],
	["weed_dry", "Lake weed, dried", Color(0.20, 0.17, 0.10), "matte, both sides", "weed draped over the roof and bonnet", false],
	["crack", "Glass crack", Color(0.62, 0.64, 0.62), "thin pale strips on the screen", "crazed windscreen", false],
	["chrome", "Chrome, rusted", Color(0.86, 0.87, 0.88), "the wreck's bumpers and trims at low condition", "Anne's car", true],
	["paint", "Van paint, white", Color(0.93, 0.93, 0.91), "clear coat, light wear", "the dive van", false],
	["lettering2", "Livery blue", Color(0.05, 0.12, 0.38), "painted sheet", "van band, DIVE UNIT lettering", false],
	["lettering", "Livery yellow", Color(0.95, 0.76, 0.1), "painted sheet", "van band edges", false],
	["sheet_white", "White lettering / flag stripe", Color(0.92, 0.92, 0.9), "painted sheet", "HALLOWAY PROVINCIAL POLICE, diver-down stripe", false],
	["flag_a", "Diver-down flag red", Color(0.78, 0.06, 0.05), "cloth, both sides", "the dive flag", false],
	["kit_yellow", "Dive kit yellow", Color(0.88, 0.62, 0.05), "painted, chips with wear", "cylinders, rescue board, crate", false],
	["lightbar_blue", "Beacon lens", Color(0.05, 0.14, 0.8), "glossy; beacon glow", "lightbar, rear beacons, grille flashers", false],
	["lamp_beacon", "Amber traffic bar", Color(0.95, 0.5, 0.05), "glossy; beacon glow", "rear amber bar", false],
	["metal", "Rack aluminium", Color(0.35, 0.35, 0.36), "dull metal", "roof rack, ladder, flag staff", false],
	["wood", "Cargo floor ply", Color(0.5, 0.38, 0.24), "satin", "the cargo floor", false],
]

# [file stem, what it is, source, author, licence, used on]
const PHOTO := [
	["wreck_paint_diff", "Rusting white paint (albedo)", "Poly Haven rusty_metal_02 (polyhaven.com/a/rusty_metal_02), 1k", "Rob Tuytel", "CC0",
		"multiplies the wreck's paint: rust spotting"],
	["wreck_paint_nor", "Rusting paint (normal)", "Poly Haven rusty_metal_02 (polyhaven.com/a/rusty_metal_02), 1k", "Rob Tuytel", "CC0",
		"blistered paint relief on the wreck"],
	["wreck_silt_diff", "Wet brown mud (albedo)", "Poly Haven brown_mud_02 (polyhaven.com/a/brown_mud_02), 1k", "Rob Tuytel", "CC0",
		"the silt bed and the silt coat below the water line"],
	["wreck_silt_nor", "Wet brown mud (normal)", "Poly Haven brown_mud_02 (polyhaven.com/a/brown_mud_02), 1k", "Rob Tuytel", "CC0",
		"silt bed relief"],
	["rust_diff", "Coarse rust (albedo)", "Poly Haven rust_coarse_01 (polyhaven.com/a/rust_coarse_01), already in the project", "Dimitrios Savva, Rico Cilliers",
		"CC0", "rust where the paint has rusted through"],
	["mudtrack_diff", "Wet mud (albedo)", "Poly Haven aerial_mud_1 (polyhaven.com/a/aerial_mud_1), already in the project", "Rob Tuytel", "CC0",
		"road dirt on the van's lower panels"],
]

const WRECK := {"silt_line": 0.38, "paint_tex": "wreck_paint_diff", "paint_nor": "wreck_paint_nor", "paint_scale": 1.1, "paint_amount": 1.0,
	"silt_tex": "wreck_silt_diff", "silt_scale": 0.77}

var _out := "res://docs/realism/models/wreckvan_final_textures.jpg"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wet", 0.0)
	RenderingServer.global_shader_parameter_set("g_snow", 0.0)
	_run.call_deferred()

func _label(parent: Node, txt: String, pos: Vector2, size: int, col: Color, w := 310.0) -> void:
	var l := Label.new()
	l.text = txt; l.position = pos; l.custom_minimum_size = Vector2(w, 10); l.size = Vector2(w, 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	parent.add_child(l)

func _ball(slot: String, col, wreck = false) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(BALL, BALL); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.35, 0.48, 0.7); sky.sky_horizon_color = Color(0.9, 0.8, 0.7)
	sky.ground_horizon_color = Color(0.4, 0.36, 0.32); sky.ground_bottom_color = Color(0.15, 0.13, 0.12)
	var s := Sky.new(); s.sky_material = sky
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.32, 0.33, 0.35)
	env.sky = s; env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var key := DirectionalLight3D.new(); key.light_energy = 2.2; key.rotation_degrees = Vector3(-35, -40, 0); vp.add_child(key)
	# a checker card behind it so the see-through materials read
	var card := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(3, 3); card.mesh = qm
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.85, 0.85, 0.85)
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color(0.9, 0.9, 0.9) if (x + y) % 2 == 0 else Color(0.2, 0.2, 0.22))
	cm.albedo_texture = ImageTexture.create_from_image(img); cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	card.material_override = cm; card.position = Vector3(0, 0, -1.4); vp.add_child(card)
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.75; sm.height = 1.5; sm.radial_segments = 64; sm.rings = 32
	ball.mesh = sm
	var c: Color = col if col != null else Color(0.5, 0.5, 0.5)
	var wk := {}
	if wreck is bool and wreck:      # all above the water line: the paint photo, dried silt on top
		wk = WRECK.duplicate(); wk["silt_line"] = -0.9
	if wreck is String:          # the sphere straddles the water line: put the line through its middle (ball centre at y 0)
		wk = WRECK.duplicate(); wk["silt_line"] = 0.0
	var mat := VehicleAssets._mat(slot, c, 0.0, wk)
	if not wk.is_empty() and slot != "glass":
		mat = mat.duplicate()
		(mat as ShaderMaterial).set_shader_parameter("cond_scale", 0.45)
	ball.material_override = mat
	ball.position = Vector3(0, 0.0, 0)
	vp.add_child(ball)
	var cam := Camera3D.new(); cam.fov = 40; vp.add_child(cam); cam.look_at_from_position(Vector3(0, 0.15, 2.4), Vector3.ZERO)
	for k in 5: await process_frame
	await RenderingServer.frame_post_draw
	var out := vp.get_texture().get_image()
	vp.queue_free()
	return out

func _run() -> void:
	var total := SLOTS.size() + PHOTO.size()
	var rows := int(ceil(total / float(COLS)))
	var balls: Array = []
	for e in SLOTS:
		balls.append(await _ball(String(e[0]), e[2], e[5]))
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * COLS, CELL.y * rows + 96)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.1, 0.11); bg.size = Vector2(vp.size); vp.add_child(bg)
	_label(vp, "Wreck and dive van: every material and texture used (lane/wreckvan)", Vector2(20, 12), 26, Color.WHITE, 1900)
	_label(vp, "Spheres are drawn with the game's own vehicle shaders (vehicle_pbr, vehicle_glass) in front of a checker card, so the see-through ones read. Photographed maps are Poly Haven, CC0. All other finishes are procedural, own work, CC0. No real brands, badges or registrations.", Vector2(20, 50), 14, Color(0.8, 0.8, 0.82), 1900)
	var i := 0
	for k in SLOTS.size():
		var e: Array = SLOTS[k]
		var at := Vector2((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 96)
		var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(balls[k]); tr.position = at + Vector2(0, 22)
		tr.size = Vector2(BALL, BALL); vp.add_child(tr)
		_label(vp, "%s  (slot \"%s\")" % [e[1], e[0]], at, 14, Color.WHITE, 320)
		_label(vp, String(e[3]), at + Vector2(0, BALL + 26), 11, Color(0.78, 0.8, 0.85), 310)
		_label(vp, "Used on: " + String(e[4]), at + Vector2(0, BALL + 58), 11, Color(0.7, 0.85, 0.7), 310)
		i += 1
	for e in PHOTO:
		var at2 := Vector2((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 96)
		var p := "res://assets/textures/%s.jpg" % e[0]
		var tr2 := TextureRect.new(); tr2.position = at2 + Vector2(0, 22); tr2.size = Vector2(BALL, BALL)
		tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr2.stretch_mode = TextureRect.STRETCH_SCALE
		if ResourceLoader.exists(p):
			var img: Image = (load(p) as Texture2D).get_image()
			if img.is_compressed(): img.decompress()
			tr2.texture = ImageTexture.create_from_image(img)
		vp.add_child(tr2)
		_label(vp, "%s  (%s.jpg)" % [e[1], e[0]], at2, 14, Color.WHITE, 320)
		_label(vp, "%s\n%s, %s" % [String(e[2]).replace(" (", "\n("), e[3], e[4]], at2 + Vector2(0, BALL + 26), 11, Color(0.78, 0.8, 0.85), 310)
		_label(vp, "Used for: " + String(e[5]), at2 + Vector2(0, BALL + 90), 11, Color(0.7, 0.85, 0.7), 310)
		i += 1
	for k in 6: await process_frame
	await RenderingServer.frame_post_draw
	var final := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("WROTE textures sheet: %s (%s)" % [path, error_string(final.save_jpg(path, 0.9))])
	quit()
