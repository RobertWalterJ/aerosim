extends SceneTree
## Headless: every phone-app art file the code and the briefs name exists at its exact path, imports, and has the expected size.
## Covers the UniverseUI hooks (app_icon -> assets/ui/icon_<key>.png, avatar -> assets/ui/avatar_<key>.png,
## case_art -> assets/ui/<key>.png) plus every file in CLAUDE-PHONE-APP-UI-PASS.md and CLAUDE-APP-ASSETS.md.
## Godot --headless --path <godot dir> -s res://test/appui_paths_test.gd -- [group=p0|p1|p2|all]
## Prints APPUI PATHS PASS (n files) or APPUI PATHS FAIL with the missing files.

const APP_KEYS := ["chat", "studio", "photos", "jobs", "casebook", "market", "map", "settings", "recents", "home", "search"]
const AVATARS := ["maya", "jo", "riley", "tom", "alex", "sam", "rennick", "unknown", "you", "wren", "kit"]
const ITEMS := ["raptor", "nightowl", "thermal_camera", "night_vision", "battery", "motors", "props", "controller", "repair_kit"]

static func groups() -> Dictionary:
	var p0: Array = []
	for k in APP_KEYS: p0.append(["icon_%s.png" % k, 256])
	for k in AVATARS:
		p0.append(["avatar_%s.png" % k, 512])
		p0.append(["sizes/96/avatar_%s.png" % k, 96])      # lane avatars: native small sizes and the emblem cutout
		p0.append(["sizes/48/avatar_%s.png" % k, 48])
		p0.append(["avatars/cutout/%s.png" % k, 512])
		for s in ["eclectic", "emblem"]:                          # both sets kept for --switch
			p0.append(["avatars_alt/%s_%s.png" % [k, s], 512])
			p0.append(["avatars_alt/cutout/%s_%s.png" % [k, s], 512])
			p0.append(["avatars_alt/sizes/96/%s_%s.png" % [k, s], 96])
			p0.append(["avatars_alt/sizes/48/%s_%s.png" % [k, s], 48])
	for k in ITEMS: p0.append(["item_%s.png" % k, 512])
	for n in ["status_signal", "status_wifi", "status_battery", "status_battery_low", "status_notification", "status_search",
			"nav_home", "nav_back", "nav_recents", "nav_close", "nav_more"]:
		p0.append([n + ".png", 36])
		p0.append(["sizes/18/%s.png" % n, 18])
	p0.append(["badge_dot.png", 32]); p0.append(["badge_unread.png", 0])
	p0.append(["badge_work.png", 36]); p0.append(["badge_guide.png", 36])
	p0.append(["page_dot_on.png", 0]); p0.append(["page_dot_off.png", 0])
	p0.append(["casebook_paper.jpg", 2048]); p0.append(["casebook_folder.png", 256])
	for n in ["overview", "evidence", "chapters", "contacts"]: p0.append(["casebook_tab_%s.png" % n, 64])
	for n in ["casebook_stamp_open", "casebook_stamp_closed", "stamp_case_closed", "stamp_evidence"]: p0.append([n + ".png", 384])
	p0.append(["casebook_stamp_evidence.png", 512]); p0.append(["casebook_photo_frame.png", 192])
	for n in ["open", "done", "waiting"]: p0.append(["casebook_timeline_node_%s.png" % n, 64])
	p0.append(["casebook_empty_folder.png", 512]); p0.append(["casebook_pin_red.png", 64])
	var p1: Array = []
	for n in ["act_1_waiting", "act_2_lake_car", "act_3_last_flight", "act_4_cabin", "act_5_end"]: p1.append([n + ".png", 384])
	for n in ["badge_rush", "badge_dm", "badge_job", "badge_story", "badge_edited"]: p1.append([n + ".png", 64])
	for n in ["notify_clip", "notify_video", "notify_photo", "notify_job"]: p1.append([n + ".png", 128])
	for n in ["channel_clips", "channel_town", "channel_weather", "channel_jobs"]: p1.append([n + ".png", 96])
	for n in ["chat_compose", "chat_attach", "chat_mic", "chat_send", "studio_metric_followers", "studio_metric_money",
			"studio_metric_videos", "studio_metric_views", "metric_followers", "metric_money", "metric_videos", "metric_views",
			"studio_play", "studio_upload", "studio_cut", "job_badge_distance", "job_badge_range", "job_badge_frame",
			"job_badge_retake", "job_badge_pulled", "job_badge_excellent"]:
		p1.append([n + ".png", 64])
	for n in ["chat_channel_hash", "chat_channel_voice", "chat_channel_jobs", "photos_album", "photos_grid", "photos_detail",
			"photos_delete", "photos_share", "job_category_photo", "job_category_farm", "job_category_lake", "job_category_civic",
			"facade_drones", "facade_cameras", "facade_power", "facade_parts"]:
		p1.append([n + ".png", 48])
	for n in ["chat_reply_arrow", "chat_pinned", "chat_edited"]: p1.append([n + ".png", 40])
	p1.append(["job_stamp_pulled.png", 192]); p1.append(["job_stamp_excellent.png", 192])
	p1.append(["studio_banner.jpg", 0]); p1.append(["chat_server_banner.png", 0])
	p1.append(["photos_empty.png", 512]); p1.append(["photos_frame_clean.png", 0])
	p1.append(["facade_seller_strip.png", 0]); p1.append(["facade_sold.png", 128])
	p1.append(["map_paper.jpg", 2048])
	for n in ["current", "suggested", "locked", "open"]: p1.append(["map_pin_%s.png" % n, 64])
	p1.append(["map_route_line.png", 0]); p1.append(["map_compass.png", 256]); p1.append(["map_beacon.png", 128])
	var fonts: Array = []
	for n in ["ui_sans.ttf", "ui_sans_bold.ttf", "ui_serif.ttf", "ui_serif_bold.ttf", "ui_mono.ttf", "ui_sans_medium.tres",
			"ui_sans_semibold.tres", "LICENSES.md"]:
		fonts.append(n)
	var p2: Array = []
	for n in ["thumb_frame_clean", "thumb_frame_rust", "thumb_duration_mask", "thumb_play_plate"]:
		p2.append([n + ".png", 1280]); p2.append(["thumbs/480/%s.png" % n, 480])
	p2.append(["paper_grain.png", 512])
	return {"p0": p0, "p1": p1, "fonts": fonts, "p2": p2}

func _initialize() -> void:
	var want := "all"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("group="): want = a.substr(6)
	var g := groups()
	var fails: Array = []
	var n := 0
	for gname in g:
		if want != "all" and gname != want and not (want == "p1" and gname == "fonts"): continue
		for entry in g[gname]:
			if gname == "fonts":
				var fp := "res://assets/fonts/" + str(entry)
				n += 1
				if not FileAccess.file_exists(fp): fails.append(fp)
				elif fp.ends_with(".ttf") or fp.ends_with(".tres"):
					var f = load(fp)
					if f == null: fails.append(fp + " (does not load)")
				continue
			var path := "res://assets/ui/" + str(entry[0])
			var px := int(entry[1])
			n += 1
			if not FileAccess.file_exists(path):
				fails.append(path)
				continue
			if not ResourceLoader.exists(path):
				fails.append(path + " (not imported)")
				continue
			var tex := load(path) as Texture2D
			if tex == null:
				fails.append(path + " (not a texture)")
			elif px > 0 and tex.get_width() != px:
				fails.append("%s (width %d, expected %d)" % [path, tex.get_width(), px])
	for f in fails: print("MISSING ", f)
	if fails.is_empty(): print("APPUI PATHS PASS (%d files, group %s)" % [n, want])
	else: print("APPUI PATHS FAIL (%d of %d, group %s)" % [fails.size(), n, want])
	quit(0 if fails.is_empty() else 1)
