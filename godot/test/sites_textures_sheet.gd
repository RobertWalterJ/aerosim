extends SceneTree
## The textures-used sheet for lane/sites: every material SiteAssets swaps in, as a lit swatch rendered with the game's own
## material (photographed sets as a 1.5 m square at their real scale, plain materials on a ball, decals over grey), with
## source, author, licence, repeat and where it is used. Needs a window:
## Godot --path <godot dir> --resolution 640x360 -s res://test/sites_textures_sheet.gd -- [out=<jpg>]

const CELL := Vector2i(400, 380)
const SW := 260
const COLS := 6

# [key, title, source, author, used on]
const ROWS := [
	["site_concrete", "Worn concrete", "Poly Haven concrete_floor_worn_001", "Dimitrios Savva, Rico Cilliers (CC0)", "ramp sides, curbs, cut-off walls"],
	["site_ramp", "Ramp concrete, waffle grooves", "concrete_floor_worn_001 + 25 mm V grooves at 45 deg, 200 mm apart (own work)", "Savva, Cilliers; grooves own (CC0)", "ramp slab"],
	["site_gravel", "Compacted gravel", "Poly Haven gravel_road (roughness rebuilt)", "Amal Kumar (CC0)", "parking apron, gravel patch"],
	["site_dirt", "Park dirt", "Poly Haven park_dirt", "Christopher Melani (CC0)", "cave apron, root plates"],
	["site_mud", "Wet mud", "park_dirt, darker and glossier", "Christopher Melani (CC0)", "ruts, puddle rim"],
	["site_soil", "Autumn leaf litter", "Poly Haven brown_mud_leaves_01, leaves turned autumn (own)", "Rob Tuytel (CC0)", "leaf drift, litter, root pit"],
	["site_track", "Cabin track (4.4 x 8 m)", "gravel_road, park_dirt, sparse_grass, brown_mud_leaves_01 composited (own)", "Kumar, Melani, Tuytel (CC0)", "track strip, track ribbons"],
	["site_deck", "Old planks", "Poly Haven old_planks_02", "Rob Tuytel (CC0)", "dock deck"],
	["site_timber", "Rough wood", "Poly Haven rough_wood", "Rob Tuytel (CC0)", "posts, piles, bollards, gates, sleeper"],
	["site_board", "Grey boards", "Poly Haven wood_planks_grey", "Rob Tuytel (CC0)", "sign backs, notice board, oar, fascia"],
	["site_paint_cream", "Cream paint", "Poly Haven plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "launch sign face"],
	["site_paint_red", "Red paint", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "sign border, life ring, lettering"],
	["site_paint_green", "Green paint", "plastered_wall_02 (tinted)", "Charlotte Baglioni (CC0)", "hull topsides (_b), bin"],
	["site_rock", "Grey rock (triplanar)", "Poly Haven rock_boulder_dry", "Dimitrios Savva, Rico Cilliers (CC0)", "boulders, outcrop, slab, scree"],
	["site_rock_moss", "Mossy rock (triplanar)", "Poly Haven mossy_rock", "Rob Tuytel (CC0)", "boulder and outcrop tops"],
	["site_moss", "Moss", "Poly Haven mossy_rock", "Rob Tuytel (CC0)", "old log"],
	["site_bark_oak", "Oak bark", "Poly Haven jolcham_oak_bark_01", "Charlotte Baglioni (CC0)", "fallen oak, stump, branches"],
	["site_bark_beech", "Smooth grey bark", "Poly Haven japanese_hackberry_bark", "Charlotte Baglioni (CC0)", "fallen beech"],
	["site_wood_end", "Sawn end grain", "own work (growth rings, checks, saw marks)", "AeroSim (CC0)", "cut trunk, log ends"],
	["site_alu", "Riveted aluminium", "own work (brushed grain, oxidation, lap seams, rivets)", "AeroSim (CC0)", "hull, outboard bracket"],
	["site_rust", "Coarse rust", "Poly Haven rust_coarse_01", "Dimitrios Savva, Rico Cilliers (CC0)", "lantern"],
	["site_galv", "Galvanised steel", "plain PBR (own)", "CC0", "trailer, caps, hoops, ladder"],
	["site_iron", "Cast iron", "plain PBR (own)", "CC0", "cleats, hinges"],
	["site_rubber", "Rubber", "plain + Poly Haven rubberized_track normal", "Charlotte Baglioni (CC0)", "tyres, rollers"],
	["site_plastic_white", "White polyethylene", "plain PBR (own)", "CC0", "dock floats, marker"],
	["site_plastic_red", "Red plastic", "plain PBR (own)", "CC0", "fuel tank"],
	["site_carpet", "Bunk carpet", "plain PBR (own)", "CC0", "trailer bunks"],
	["site_canvas_blue", "Faded canvas", "plain PBR (own)", "CC0", "tarp, winch strap"],
	["site_leaves", "Dry beech leaves", "assets/trees/leaves_beech.webp (tree lane atlas)", "AeroSim (CC0)", "leaves left on fallen crowns"],
	["site_cave_dark", "Cave mouth", "unshaded black (own)", "CC0", "cave_mouth"],
	["site_puddle", "Puddle water", "plain PBR (own)", "CC0", "track puddle"],
	["site_decal_rust", "Rust run decal", "own work", "CC0", "damage decals"],
	["site_decal_algae", "Algae decal", "own work", "CC0", "damage decals"],
	["site_decal_waterline", "Waterline decal", "own work", "CC0", "damage decals"],
	["site_decal_crack", "Concrete crack decal", "own work", "CC0", "damage decals"],
	["site_decal_oil", "Oil stain decal", "own work", "CC0", "oil stain, damage decals"],
	["site_decal_tyre", "Tyre print decal", "own work", "CC0", "tyre print"],
	["site_decal_damp", "Damp stain decal", "own work", "CC0", "cave damp stain"],
	["site_decal_chalk", "Chalk scrawl decal", "own work (unreadable)", "CC0", "cave chalk mark"],
]

var _out := "res://docs/realism/models/sites_final_textures.jpg"

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
		var mat := (SiteAssets.mat(key) as BaseMaterial3D).duplicate() as BaseMaterial3D
		mat.vertex_color_use_as_albedo = false
		var textured := SiteAssets.SETS.has(key) or key in SiteAssets.DECALS or key == "site_leaves"
		quad.visible = textured; ball.visible = not textured
		back.visible = key in SiteAssets.DECALS or key == "site_leaves"
		var rep := 1.0
		if SiteAssets.SETS.has(key):
			rep = float(SiteAssets.SETS[key][1])
			mat.uv1_triplanar = false
			if key == "site_track":
				mat.uv1_scale = Vector3(1.0, 0.55, 1.0)      # the full 4.4 m width by 4.4 m of the 8 m length
			elif key == "site_wood_end":
				mat.uv1_scale = Vector3(1, 1, 1)
			else:
				mat.uv1_scale = mat.uv1_scale * 1.5
		if textured: quad.material_override = mat
		else: ball.material_override = mat
		for f in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % COLS) * CELL.x + 10, (i / COLS) * CELL.y + 10)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, Vector2i(SW, SW)), at)
		var txt := "%s\n%s\n%s\n%s\nused: %s" % [e[1], e[2], e[3], ("one repeat %.2f m; swatch 1.5 m" % rep) if SiteAssets.SETS.has(key) else "", e[4]]
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
	var title := Label.new(); title.text = "lane/sites: textures used (SiteAssets materials). Licences: assets/textures/README.md"
	title.position = Vector2(sheet.get_width() - 620, sheet.get_height() - 30); title.add_theme_font_size_override("font_size", 14); v2.add_child(title)
	for f in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	var err := v2.get_texture().get_image().save_jpg(path, 0.9)
	print("textures sheet: %s (%s)" % [path, error_string(err)])
	quit()
