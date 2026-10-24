extends SceneTree
## The textures and materials the Blender vehicles use (game/vehicle_assets.gd): every material slot drawn on a sphere with
## the game's own vehicle shaders (paint, glass, chrome, rubber...), labelled with what it is, where it is used and where it
## came from, and the three photographed CC0 maps shown as tiles with their source, author and licence.
## Needs a window: Godot --path <godot dir> --resolution 480x270 -s res://test/vehicles_textures_sheet.gd -- [out=<jpg>]

const COLS := 6
const CELL := Vector2i(330, 360)
const BALL := 200

# [slot, label, colour (sRGB; null = the shader's own), finish, used on]
const SLOTS := [
	["paint", "Car paint, clear coat", Color(0.50, 0.05, 0.04), "procedural flake, scratches, fade; rust photo where worn", "every body; per-vehicle colour"],
	["paint", "Car paint, worn", Color(0.24, 0.36, 0.55), "the same shader at condition 0.4: faded, rusted through (rust photo)", "Lake Car, 1984 cruiser sills, old pickup"],
	["paint2", "Second colour", Color(0.07, 0.09, 0.14), "clear coat; livery panels", "cruiser doors and roof, bus bands, van stripes"],
	["glass", "Glass", null, "see-through, Fresnel reflection, road film, raindrops in rain", "all windows"],
	["lamp_front", "Clear headlamp lens", null, "see-through lens over a chrome reflector; glows when lit", "headlamps"],
	["lamp_reflector", "Reflector and bulb", Color(0.78, 0.78, 0.8), "glossy; the headlamp glow", "inside every headlamp, work lamps"],
	["lamp_tail", "Tail lamp lens", Color(0.62, 0.05, 0.05), "glossy coloured lens; glows", "tail lamps"],
	["lamp_brake", "Brake lamp lens", Color(0.72, 0.04, 0.04), "glossy; bright glow when braking", "brake lamps"],
	["lamp_ind_r", "Indicator lens", Color(0.95, 0.5, 0.06), "glossy amber; glows", "indicators, side repeaters"],
	["lightbar_blue", "Lightbar lens", Color(0.05, 0.14, 0.8), "glossy; beacon glow", "police lightbars"],
	["lamp_beacon", "Amber beacon", Color(0.95, 0.5, 0.05), "glossy; beacon glow", "tractor roof beacon, SMV sign"],
	["chrome", "Chrome", Color(0.86, 0.87, 0.88), "mirror metal, dulls with wear", "bumpers, trims, handles, nuts"],
	["rim", "Alloy wheel", Color(0.62, 0.63, 0.65), "satin aluminium", "alloy wheels"],
	["rim_steel", "Painted steel wheel", Color(0.55, 0.56, 0.58), "satin paint, chips with wear", "steel wheels, wheel trims"],
	["rubber", "Tyre rubber", null, "tyre black, dust; fine grain photo normal", "every tyre"],
	["metal", "Bare metal", Color(0.35, 0.35, 0.36), "dull steel, rust spots", "brake discs, chassis, exhaust"],
	["caliper", "Brake caliper", Color(0.55, 0.06, 0.05), "painted", "calipers, the tanker valve wheel"],
	["trim", "Black trim", Color(0.04, 0.04, 0.045), "plastic, sheen drops with wear", "seals, pillars, grilles, wheel wells"],
	["trim_grey", "Grey trim", Color(0.14, 0.14, 0.15), "plastic", "underbody, grille bars"],
	["seat", "Seat cloth", Color(0.07, 0.068, 0.065), "woven cloth photo normal", "every seat"],
	["interior", "Cabin lining", Color(0.05, 0.05, 0.05), "matte, both sides", "door cards, headliners, floors"],
	["dash", "Dashboard", Color(0.035, 0.035, 0.037), "matte plastic", "dashboards, consoles"],
	["plate", "Number plate (blank)", Color(0.92, 0.92, 0.86), "painted sheet; fictional, no registration", "number plates"],
	["lettering", "Lettering", Color(0.9, 0.86, 0.75), "painted sheet; real glyph geometry", "HALLOWAY, MARSH & DAUGHTERS..."],
	["sheet_white", "White sheet", Color(0.82, 0.82, 0.8), "painted sheet", "tractor roof, ice cream sign"],
	["primer", "Grey primer", Color(0.42, 0.42, 0.41), "flat, chalky", "the unrestored bus panel"],
	["canvas", "Canvas / tarp", Color(0.12, 0.25, 0.5), "matte cloth, both sides", "bus tarpaulin, awning"],
	["straw", "Straw bale", Color(0.62, 0.5, 0.25), "matte", "parade trailer bales"],
	["wood", "Painted timber / wafer", Color(0.42, 0.28, 0.16), "satin", "trailer boards, the cone"],
	["mirror", "Mirror glass", Color(0.9, 0.9, 0.92), "polished metal", "door mirrors"],
]

# [file stem, what it is, source, author, licence, used on]
const PHOTO := [
	["rust_diff", "Coarse rust (albedo)", "Poly Haven rust_coarse_01 (polyhaven.com/a/rust_coarse_01), 1k re-saved at 512", "Dimitrios Savva, Rico Cilliers",
		"CC0", "rust where the paint has rusted through"],
	["fabric_nor", "Woven fabric (normal)", "Poly Haven fabric_pattern_07 (polyhaven.com/a/fabric_pattern_07), 1k re-saved at 512", "Rob Tuytel", "CC0",
		"seat cloth weave"],
	["rubber_nor", "Rubberised surface (normal)", "Poly Haven rubberized_track (polyhaven.com/a/rubberized_track), 1k re-saved at 512",
		"Charlotte Baglioni", "CC0", "tyre sidewall and tread grain"],
	["mudtrack_diff", "Wet mud (albedo)", "Poly Haven aerial_mud_1 (polyhaven.com/a/aerial_mud_1), already in the project", "Rob Tuytel", "CC0",
		"road dirt thrown up the lower panels"],
]

var _out := "res://docs/realism/models/vehicles_final_textures.jpg"

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

func _ball(slot: String, col, worn := false) -> Image:
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
	var mat := VehicleAssets._mat(slot, c, 0.0)
	if worn:
		mat = mat.duplicate()
		(mat as ShaderMaterial).set_shader_parameter("cond_scale", 0.4)
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
		balls.append(await _ball(String(e[0]), e[2], String(e[1]).contains("worn")))
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL.x * COLS, CELL.y * rows + 96)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new(); bg.color = Color(0.1, 0.1, 0.11); bg.size = Vector2(vp.size); vp.add_child(bg)
	_label(vp, "Blender vehicles: every material and texture used (lane/vehicles)", Vector2(20, 12), 26, Color.WHITE, 1900)
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
