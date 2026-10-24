extends SceneTree
## The textures-used sheet for lane/antidrone (adapted from sites_textures_sheet.gd): every material AntiDroneAssets swaps in, as a lit swatch rendered with the game's own
## material (photographed sets as a 1.5 m square at their real scale, plain materials on a ball, decals over grey), with
## source, author, licence, repeat and where it is used. Needs a window:
## Godot --path <godot dir> --resolution 640x360 -s res://test/antidrone_textures_sheet.gd -- [out=<jpg>]

const CELL := Vector2i(400, 380)
const SW := 260
const COLS := 6

# [key, title, source, author, used on]
const ROWS := [
	["ad_ground", "Pike's clearing (12 x 12 m, not tiling)", "dry grass + park_dirt (rwj_procgen set, Poly Haven) + drawn ruts, oil, paths (own)", "Poly Haven authors (CC0); masks own", "pike_clearing_patch"],
	["ad_trailer_paint", "Faded olive enamel", "Poly Haven plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "trailer box, mudguards"],
	["ad_paint_white", "Weathered white paint", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "dish, warning sign face, rain barrel"],
	["ad_paint_red", "Red paint", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "generator frame and tank, clamp levers"],
	["ad_toolbox_red", "Toolbox red", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "toolbox"],
	["ad_jerrycan", "Jerry can green", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "fuel can"],
	["ad_rust", "Coarse rust", "Poly Haven rust_coarse_01", "Dimitrios Savva, Rico Cilliers (CC0)", "chassis, drawbar, hinge, stove pipe"],
	["ad_planks", "Weathered plank siding", "Poly Haven weathered_plank_siding", "Dimitrios Savva (CC0)", "shack walls, door, crate"],
	["ad_ply", "Weathered ply", "Poly Haven rough_wood (lightened)", "Rob Tuytel (CC0)", "manifesto board, sign board"],
	["ad_corrugated", "Worn corrugated iron", "Poly Haven worn_corrugated_iron", "Jenelle van Heerden, Dimitrios Savva (CC0)", "shack and lean-to roofs"],
	["ad_carbon", "Carbon fibre", "ambientCG carbon set (drones lane)", "ambientCG (CC0)", "hunter arms, plates"],
	["ad_plastic_dark", "Dark moulded plastic", "drones lane plastic normal/ORM", "ambientCG (CC0)", "hunter hulls, eye hoods, battery box"],
	["ad_motor", "Spun motor bells", "drones lane spun normal/ORM", "ambientCG (CC0)", "motors, rotor hubs"],
	["ad_strap", "Woven strap", "drones lane strap set", "ambientCG (CC0)", "battery straps"],
	["ad_tarp", "Olive tarpaulin", "plain + Poly Haven fabric_pattern_07 normal", "Rob Tuytel (CC0)", "tarp, lean-to lump"],
	["ad_canvas", "Chair canvas", "plain + fabric_pattern_07 normal", "Rob Tuytel (CC0)", "camp chair, rag"],
	["ad_galv", "Galvanised steel", "plain PBR (own)", "CC0", "mast, guy wires, fence wire"],
	["ad_steel_dark", "Dark steel", "plain PBR (own)", "CC0", "plates, cage, skids"],
	["ad_cable", "Black cable", "plain PBR (own)", "CC0", "power cable, leads"],
	["ad_bone", "Bleached bone", "plain PBR (own)", "CC0", "deer skull on the folk fence"],
	["ad_ribbon", "Red rag ribbon", "plain PBR (own)", "CC0", "ribbons on the fence"],
	["ad_lamp_red", "Beacon (emissive)", "plain emissive (own)", "CC0", "beacon, antenna lamp"],
	["ad_lamp_eye", "Hunter eye (emissive)", "plain emissive (own)", "CC0", "hunter eyes"],
	["ad_lamp_amber", "Warning lamp (emissive)", "plain emissive (own)", "CC0", "generator lamp"],
	["ad_paper", "Blank taped sheet", "pike_paper_blank.png (own)", "AeroSim (CC0)", "manifesto face (Label3D)"],
	["ad_paper_lined", "Manifesto page", "pike_manifesto_paper.png (own, unreadable lines)", "AeroSim (CC0)", "pages on the board"],
	["ad_notices", "Damp notice stack", "pike_notice_stack.png (own, unreadable)", "AeroSim (CC0)", "story prop texture"],
	["ad_decal_stencil", "NO DRONE stencil", "pike_no_drone_stencil.png (own)", "AeroSim (CC0)", "trailer side"],
	["ad_decal_tyre", "Tyre marks", "pike_tyre_marks.png (own)", "AeroSim (CC0)", "pike_tyre_tracks"],
	["ad_smoke", "Smoke card", "pike_smoke_card.png (own)", "AeroSim (CC0)", "pike_smoke"],
	["ad_strobe", "Strobe card", "pike_strobe_card.png (own)", "AeroSim (CC0)", "pike_strobe_card"],
]

var _out := "res://docs/realism/models/antidrone_final_textures.jpg"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	_run.call_deferred()

func _run() -> void:
	var n := ROWS.size()
	var rows := int(ceil(float(n) / COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.13, 0.13, 0.14))
	var vp := SubViewport.new(); vp.size = Vector2i(SW, SW); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.45, 0.47, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.55, 0.57, 0.6); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, -30, 0); sun.light_energy = 1.6; vp.add_child(sun)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 1.5; cam.position = Vector3(0, 0, 3); vp.add_child(cam)
	var back := MeshInstance3D.new(); var bq := QuadMesh.new(); bq.size = Vector2(1.5, 1.5); back.mesh = bq; back.position.z = -0.01
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.55, 0.55, 0.53); back.material_override = bm; vp.add_child(back)
	var quad := MeshInstance3D.new(); var pm := QuadMesh.new(); pm.size = Vector2(1.5, 1.5); quad.mesh = pm; vp.add_child(quad)
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 1.1; ball.mesh = sm; vp.add_child(ball)
	var labels: Array = []
	for i in n:
		var e: Array = ROWS[i]
		var key: String = e[0]
		var mat := (AntiDroneAssets.mat(key) as BaseMaterial3D).duplicate() as BaseMaterial3D
		mat.vertex_color_use_as_albedo = false
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		var textured := AntiDroneAssets.SETS.has(key) or AntiDroneAssets.CARDS.has(key)
		quad.visible = textured; ball.visible = not textured
		back.visible = AntiDroneAssets.CARDS.has(key)
		var rep := 1.0
		if AntiDroneAssets.SETS.has(key):
			rep = float(AntiDroneAssets.SETS[key][3])
			if rep > 0.0: mat.uv1_scale = mat.uv1_scale * 1.5
			else: mat.uv1_scale = Vector3(1, 1, 1)
		if textured: quad.material_override = mat
		else: ball.material_override = mat
		for f in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 10)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(SW, SW)), at)
		var txt := "%s\n%s\n%s\n%s\nused: %s" % [e[1], e[2], e[3], ("one repeat %.2f m; swatch 1.5 m" % rep) if rep > 0.0 and AntiDroneAssets.SETS.has(key) else "", e[4]]
		labels.append([at, key, txt])
	vp.queue_free()
	var v2 := SubViewport.new(); v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var k := Label.new(); k.text = l[1]; k.position = Vector2(at2.x + SW + 6, at2.y); k.size = Vector2(CELL.x - SW - 16, 80)
		k.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		k.add_theme_font_size_override("font_size", 12); k.add_theme_color_override("font_color", Color(1, 0.85, 0.5)); v2.add_child(k)
		var lab := Label.new(); lab.text = l[2]; lab.position = Vector2(at2.x, at2.y + SW + 2); lab.size = Vector2(CELL.x - 20, 100)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD; lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92)); v2.add_child(lab)
	var title := Label.new(); title.text = "lane/antidrone: textures used (AntiDroneAssets materials). Licences: assets/textures/README.md"
	title.position = Vector2(sheet.get_width() - 620, sheet.get_height() - 30); title.add_theme_font_size_override("font_size", 14); v2.add_child(title)
	for f in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	var err := v2.get_texture().get_image().save_jpg(path, 0.9)
	print("textures sheet: %s (%s)" % [path, error_string(err)])
	quit()
