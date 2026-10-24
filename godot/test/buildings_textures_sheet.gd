extends SceneTree
## The textures-used sheet for the buildings pass (lane/buildings): each photographed set the Blender buildings use, as a lit
## swatch (a 1.5 m square of wall rendered with the game's material at its real scale, so a brick course is 75 mm), with
## the Poly Haven source, author, licence, the size of one repeat and where it is used; then the plain materials.
## Needs a window: Godot --path <godot dir> --resolution 640x360 -s res://test/buildings_textures_sheet.gd -- [out=<jpg>]

const CELL := Vector2i(470, 400)
const SW := 300
const COLS := 4

# [key, title, source, author, used on]
const PHOTO := [
	["bld_brick", "Red brick (stretcher bond)", "Poly Haven red_brick, 1k", "Rob Tuytel", "police house, shop A, school, chimneys"],
	["bld_brick2", "Old red brick", "Poly Haven medieval_red_brick, 1k", "Rob Tuytel", "shop B, bakery, garage"],
	["bld_render", "Painted render", "Poly Haven painted_plaster_wall, 1k", "Amal Kumar", "pub, chip shop; pots and ridge tiles"],
	["bld_stone", "Dressed stone (render set, buff)", "Poly Haven painted_plaster_wall, 1k", "Amal Kumar", "sills, lintels, quoins, string courses"],
	["bld_ashlar", "Sandstone blocks", "Poly Haven large_sandstone_blocks, 1k", "Rob Tuytel", "church and tower walls"],
	["bld_slate", "Slate roof", "Poly Haven roof_slates_03, 1k", "Rob Tuytel", "police house, pub, hall, shops, school"],
	["bld_slate2", "Weathered slate", "Poly Haven roof_slates_02, 1k", "Rob Tuytel", "church roof and broach spire"],
	["bld_corrugated", "Corrugated iron", "Poly Haven corrugated_iron_02, 1k", "Jenelle van Heerden, Sergej Majboroda", "garage roof, roller door"],
	["bld_corrugated_rust", "Worn corrugated iron", "Poly Haven worn_corrugated_iron, 1k", "Jenelle van Heerden, Dimitrios Savva", "cabin roofs"],
	["bld_weatherboard", "Painted weatherboard (turned level, colour from paint)", "Poly Haven distressed_painted_planks, 1k", "Rob Tuytel", "village hall"],
	["bld_timber", "Weathered plank siding", "Poly Haven weathered_plank_siding, 1k", "Dimitrios Savva", "cabin walls"],
	["bld_paint", "Painted joinery", "Poly Haven plastered_wall_02, 512 px", "Charlotte Baglioni", "frames, sashes, doors, fascias, signs"],
	["bld_wood", "Old planks", "Poly Haven old_planks_02, 1k", "Rob Tuytel", "cabin deck, door, shutters, shelves"],
	["bld_floor", "Worn floorboards", "Poly Haven wood_floor_worn, 512 px", "Dimitrios Savva", "floors seen through windows"],
	["bld_concrete", "Painted concrete floor", "Poly Haven concrete_floor_painted, 1k", "Rob Tuytel", "garage floor, steps, flaunching"],
]
const PLAIN := [
	["bld_glass", "Window glass", "clear, sky reflection (own work, CC0)"],
	["bld_iron", "Cast iron (painted)", "gutters, downpipes, brackets (own work, CC0)"],
	["bld_lead", "Lead flashing", "aprons, cornice tops (own work, CC0)"],
	["bld_brass", "Brass ironmongery", "knobs, letter plates, knockers (own work, CC0)"],
	["bld_canvas", "Awning canvas", "striped by vertex colour (own work, CC0)"],
	["bld_grime", "Run-off streak decal", "drawn by make_building_textures.py (own work, CC0)"],
]

var _out := "res://docs/realism/models/buildings_final_textures.jpg"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	_run.call_deferred()

func _run() -> void:
	var n := PHOTO.size() + PLAIN.size()
	var rows := int(ceil(float(n) / COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.14))
	var vp := SubViewport.new(); vp.size = Vector2i(SW, SW); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.5, 0.55, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.55, 0.57, 0.6); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, -30, 0); sun.light_energy = 1.6; vp.add_child(sun)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.5; cam.position = Vector3(0, 0, 3); vp.add_child(cam)
	var quad := MeshInstance3D.new(); var pm := QuadMesh.new(); pm.size = Vector2(1.5, 1.5); quad.mesh = pm; vp.add_child(quad)
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 1.1; ball.mesh = sm; vp.add_child(ball)
	var labels: Array = []
	var i := 0
	for e in PHOTO + PLAIN:
		var key: String = e[0]
		var mat := BuildingMats.get_mat(key).duplicate() as BaseMaterial3D
		mat.vertex_color_use_as_albedo = false
		if key == "bld_weatherboard": mat.albedo_color = Color(0.92, 0.89, 0.8)
		elif key == "bld_stone": mat.albedo_color = Color(0.86, 0.82, 0.72)
		elif key == "bld_canvas": mat.albedo_color = Color(0.15, 0.32, 0.22)
		elif key == "bld_iron": mat.albedo_color = Color(0.08, 0.085, 0.09)
		elif key == "bld_lead": mat.albedo_color = Color(0.42, 0.44, 0.45)
		elif key == "bld_brass": mat.albedo_color = Color(0.78, 0.62, 0.3)
		var photo := i < PHOTO.size()
		quad.visible = photo; ball.visible = not photo
		if photo:
			# the swatch quad's UVs run 0..1 over 1.5 m; the material repeats every 1/uv1_scale m, so scale to match
			var m2 := mat as BaseMaterial3D
			m2.uv1_scale = m2.uv1_scale * 1.5
			quad.material_override = m2
		else:
			ball.material_override = mat
		for f in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 10)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(SW, SW)), at)
		var txt := ""
		if photo:
			var rep: float = BuildingMats.SETS[key][1]
			txt = "%s\n%s\n%s, CC0\none repeat %.2f m; swatch 1.5 m\n%s" % [e[1], e[2], e[3], rep, e[4]]
		else:
			txt = "%s\n%s" % [e[1], e[2]]
		labels.append([at, key, txt])
		i += 1
	vp.queue_free()
	var v2 := SubViewport.new(); v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var k := Label.new(); k.text = l[1]; k.position = Vector2(at2.x + SW + 8, at2.y); k.add_theme_font_size_override("font_size", 14)
		k.add_theme_color_override("font_color", Color(1, 0.85, 0.5)); v2.add_child(k)
		var lab := Label.new(); lab.text = l[2]; lab.position = Vector2(at2.x, at2.y + SW + 2); lab.size = Vector2(CELL.x - 20, 60)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD; lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92)); v2.add_child(lab)
	for f in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	var err := final.save_jpg(path, 0.9)
	print("textures sheet: %s (%s)" % [path, error_string(err)])
	quit()
