class_name NewModels6Evid
extends RefCounted
## Story batch (models8), priority 1: the festival crowd and band (low-poly posed people for the field, in the same figure builder as
## Ellis and Rennick but without close-up faces), the evidence and police close-up props, and the reward pieces (the drone badge,
## the festival rosette, and two 2D pieces drawn into PNGs by `decal()`). Metres, +Z front, origin on the ground (props: their base).
## Fictional throughout: no real force, badge, brand or person.

const NAMES: Array[String] = [
	"crowd_stand_a", "crowd_stand_a_b", "crowd_stand_a_c", "crowd_stand_a_d", "crowd_walk_a", "crowd_walk_a_b", "crowd_walk_a_c",
	"crowd_child_a", "crowd_child_a_b", "crowd_child_a_c", "crowd_point_a", "crowd_point_a_b", "crowd_cheer_a", "crowd_cheer_a_b", "crowd_band_a",
	"crowd_seated_a", "crowd_seated_a_b",
	"police_tape_roll_a", "police_tape_strip_a", "police_cone_a", "evidence_marker_a", "evidence_bag_a", "police_radio_a", "police_torch_a",
	"police_torch_a_off", "police_notebook_a", "police_camera_a", "car_vin_plate_a", "car_tow_sticker_a", "car_keys_a", "car_glovebox_programme_a",
	"committee_photo_a",
	"drone_badge_voss", "festival_rosette_a",
]

## The 2D pieces, written as PNGs by tools/export_story.gd.
const DECALS: Array[String] = ["livery_voss_son_decal", "casebook_badge_voss"]

const GREEN := Color(0.12, 0.3, 0.2)
const CREAM := Color(0.88, 0.84, 0.68)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	if name.begins_with("crowd_"):
		_crowd(md, name, maxi(lod, 1))
		return true
	match name:
		"police_tape_roll_a": _tape_roll(md)
		"police_tape_strip_a": _tape_strip(md)
		"police_cone_a": _cone(md)
		"evidence_marker_a": _marker(md)
		"evidence_bag_a": _bag(md)
		"police_radio_a": _radio(md)
		"police_torch_a": _torch(md, true)
		"police_torch_a_off": _torch(md, false)
		"police_notebook_a": _notebook(md)
		"police_camera_a": _camera(md)
		"car_vin_plate_a": _vin(md)
		"car_tow_sticker_a": _sticker(md)
		"car_keys_a": _keys(md)
		"car_glovebox_programme_a": _glove_programme(md)
		"committee_photo_a": _committee(md)
		"drone_badge_voss": _drone_badge(md)
		"festival_rosette_a": _rosette(md)
		_: return false
	return true

# ================================================================== crowd and band
const COATS := [Color(0.34, 0.22, 0.14), Color(0.16, 0.2, 0.26), Color(0.4, 0.14, 0.12), Color(0.22, 0.3, 0.22), Color(0.5, 0.42, 0.28), Color(0.28, 0.28, 0.3), Color(0.55, 0.33, 0.2), Color(0.14, 0.24, 0.34)]
const SCARVES := [Color(0.7, 0.55, 0.15), Color(0.6, 0.15, 0.15), Color(0.2, 0.4, 0.5), Color(0.85, 0.8, 0.65), Color(0.25, 0.4, 0.25), Color(0.5, 0.2, 0.4)]
const SKINS := [Color(0.8, 0.6, 0.5), Color(0.66, 0.47, 0.36), Color(0.88, 0.7, 0.6), Color(0.5, 0.35, 0.26), Color(0.74, 0.55, 0.43)]
const HAIRS := [Color(0.16, 0.1, 0.07), Color(0.45, 0.3, 0.15), Color(0.7, 0.68, 0.64), Color(0.08, 0.07, 0.06), Color(0.55, 0.25, 0.1)]

static func _style(i: int, child: bool) -> NewModels6Chars.Style:
	var st := NewModels6Chars.Style.new()
	st.jacket = COATS[i % COATS.size()]
	st.trousers = Color(0.14, 0.15, 0.18).lerp(Color(0.3, 0.28, 0.22), NewModels6.rnd(i, 1.0))
	st.boots = Color(0.12, 0.09, 0.07)
	st.skin = SKINS[(i * 3) % SKINS.size()]
	st.hair = HAIRS[(i * 2 + 1) % HAIRS.size()]
	st.height = 1.14 if child else 1.58 + NewModels6.rnd(i, 4.0) * 0.28
	st.female = i % 2 == 0
	st.jacket_k = 1.18
	st.cap = "flat" if (i % 4 == 1 and not child) else ""
	st.cap_col = COATS[(i + 3) % COATS.size()] * 0.8
	return st

static func _scarf(md: NewModels6.Model, j: Dictionary, col: Color) -> void:
	var s: float = j["s"]
	var neck: Vector3 = j["neck"]
	NewModels6.ball(md, "cloth", neck + Vector3(0, 0.0, 0.01), Vector3(0.11, 0.06, 0.1) * s, col, 8)
	NewModels6.limb(md, "cloth", neck + Vector3(0.05, -0.02, 0.09) * s, neck + Vector3(0.06, -0.3, 0.1) * s, 0.03 * s, 0.025 * s, col, 6)

static func _crowd(md: NewModels6.Model, name: String, lod: int) -> void:
	var variant := 0
	if name.ends_with("_b"): variant = 1
	elif name.ends_with("_c"): variant = 2
	elif name.ends_with("_d"): variant = 3
	var base := name.substr(0, name.length() - (2 if variant > 0 else 0))
	var i := variant * 5 + base.length()
	if base == "crowd_band_a":
		_band(md, lod)
		return
	var st := _style(i, base == "crowd_child_a")
	var pose := {"lean": 0.03, "arm_r": [0.05, 0.12], "arm_l": [0.05, 0.12], "elbow_r": 0.3, "elbow_l": 0.3, "hip_r": [0.0, 0.04], "hip_l": [0.0, 0.04], "knee_r": 0.0, "knee_l": 0.0,
		"head_yaw": (NewModels6.rnd(i, 2.0) - 0.5) * 0.5, "twist": (NewModels6.rnd(i, 3.0) - 0.5) * 0.8}
	match base:
		"crowd_stand_a":
			pose["arm_r"] = [0.05, 0.16]; pose["arm_l"] = [0.05, 0.16]; pose["elbow_r"] = 0.9; pose["elbow_l"] = 0.9
			pose["hide_hand_r"] = true; pose["hide_hand_l"] = true
			if variant == 2: pose["hide_hand_r"] = false; pose["hide_hand_l"] = false; pose["elbow_r"] = 1.4; pose["elbow_l"] = 1.4; pose["arm_r"] = [0.5, 0.2]; pose["arm_l"] = [0.5, 0.2]
			if variant == 3: pose["hip_r"] = [0.0, 0.18]; pose["hip_l"] = [0.0, 0.02]; pose["knee_l"] = 0.1
		"crowd_walk_a":
			var sw := 0.45 + variant * 0.08
			pose["hip_r"] = [sw, 0.03]; pose["knee_r"] = 0.12; pose["hip_l"] = [-sw * 0.8, 0.03]; pose["knee_l"] = 0.5
			pose["arm_r"] = [-0.4, 0.1]; pose["elbow_r"] = 0.3; pose["arm_l"] = [0.45, 0.1]; pose["elbow_l"] = 0.4; pose["lean"] = 0.08; pose["foot_l"] = 0.3
		"crowd_child_a":
			pose["arm_r"] = [1.0, 0.45]; pose["elbow_r"] = 0.5; pose["lean"] = 0.0; pose["hip_r"] = [0.0, 0.08]; pose["hip_l"] = [0.0, 0.08]
			if variant == 1: pose["hip_r"] = [0.4, 0.05]; pose["knee_r"] = 0.2; pose["hip_l"] = [-0.3, 0.05]; pose["knee_l"] = 0.4
			if variant == 2: pose["arm_r"] = [2.4, 0.3]; pose["elbow_r"] = 0.3; pose["arm_l"] = [0.6, 0.5]
		"crowd_point_a":
			pose["arm_r"] = [1.45, 0.15 if variant == 0 else 0.5]; pose["elbow_r"] = 0.12; pose["lean"] = 0.06; pose["head_yaw"] = -0.2
			pose["hip_r"] = [0.12, 0.08]
		"crowd_cheer_a":
			if variant == 0:
				pose["arm_r"] = [0.9, 0.2]; pose["arm_l"] = [0.9, 0.2]; pose["elbow_r"] = 1.5; pose["elbow_l"] = 1.5      # clapping
			else:
				pose["arm_r"] = [0.2, 2.6]; pose["arm_l"] = [0.2, 2.6]; pose["elbow_r"] = 0.3; pose["elbow_l"] = 0.3; pose["lean"] = -0.05     # arms up
		"crowd_seated_a":
			pose["pelvis"] = Vector3(0, 0.50 * st.height / 1.75, 0)
			pose["hip_r"] = [1.5, 0.08]; pose["hip_l"] = [1.5, 0.08]; pose["knee_r"] = 1.5; pose["knee_l"] = 1.5; pose["lean"] = 0.06
			pose["arm_r"] = [0.5, 0.1]; pose["arm_l"] = [0.5, 0.1]; pose["elbow_r"] = 1.2; pose["elbow_l"] = 1.2
			if variant == 1:
				pose["arm_r"] = [0.2, 0.5]; pose["arm_l"] = [0.9, 0.1]; pose["elbow_r"] = 0.8; pose["lean"] = 0.2; pose["knee_l"] = 1.0
	var j := NewModels6Chars._person(md, st, pose, lod)
	if i % 3 != 2: _scarf(md, j, SCARVES[i % SCARVES.size()])
	if base == "crowd_child_a":
		# a little paper flag on a stick in the raised hand
		var hr: Vector3 = j["hand_r"]
		NewModels6.limb(md, "wood", hr + Vector3(0, -0.12, 0), hr + Vector3(0, 0.5, 0), 0.006, 0.005, Color(0.7, 0.62, 0.45), 4)
		NewModels6.sheet(md, "cloth", [hr + Vector3(0, 0.5, 0), hr + Vector3(0.22, 0.45, 0), hr + Vector3(0.0, 0.34, 0)], GREEN if variant != 1 else Color(0.7, 0.2, 0.15), Vector3(0, 0, 1))

static func _band(md: NewModels6.Model, lod: int) -> void:
	var wood := Color(0.5, 0.3, 0.14)
	# a singer on the left with a mic stand, a guitarist, a bass player and a drummer behind a small kit; no weapons, only instruments
	var offsets := [Vector3(-1.4, 0, 0.4), Vector3(-0.2, 0, 0.5), Vector3(1.0, 0, 0.45), Vector3(0.0, 0, -1.3)]
	for k in 4:
		var st := _style(20 + k, false)
		st.height = 1.7
		var pose := {"lean": 0.05, "arm_r": [0.1, 0.15], "arm_l": [0.1, 0.15], "elbow_r": 0.3, "elbow_l": 0.3, "hip_r": [0.0, 0.05], "hip_l": [0.0, 0.05], "knee_r": 0.0, "knee_l": 0.0}
		if k == 0: pose["arm_r"] = [1.2, 0.2]; pose["elbow_r"] = 1.3; pose["head_pitch"] = -0.1
		if k == 1: pose["arm_r"] = [0.6, 0.25]; pose["elbow_r"] = 1.3; pose["arm_l"] = [0.9, 0.35]; pose["elbow_l"] = 0.7; pose["twist"] = -0.4
		if k == 2: pose["arm_r"] = [0.6, 0.25]; pose["elbow_r"] = 1.2; pose["arm_l"] = [0.9, 0.35]; pose["elbow_l"] = 0.8; pose["twist"] = 0.4; pose["hip_r"] = [0.2, 0.15]
		if k == 3:
			pose["pelvis"] = Vector3(0, 0.50, 0)
			pose["hip_r"] = [1.45, 0.1]; pose["hip_l"] = [1.45, 0.1]; pose["knee_r"] = 1.4; pose["knee_l"] = 1.4
			pose["arm_r"] = [0.6, 0.35]; pose["arm_l"] = [0.6, 0.35]; pose["elbow_r"] = 1.4; pose["elbow_l"] = 1.4
		var sub := NewModels6.Model.new()
		var j := NewModels6Chars._person(sub, st, pose, lod)
		for key in sub.m:
			var buf: NewModels2.Buf = sub.m[key]
			var dst := md.b(key)
			for q in buf.pos.size():
				dst.pos.append(buf.pos[q] + offsets[k]); dst.nrm.append(buf.nrm[q]); dst.cols.append(buf.cols[q])
		var o: Vector3 = offsets[k]
		if k == 0:
			NewModels6.limb(md, "steel", o + Vector3(0.05, 0.0, 0.35), o + Vector3(0.05, 1.5, 0.35), 0.012, 0.012, Color(0.1, 0.1, 0.11), 6)
			NewModels6.ball(md, "paint", o + Vector3(0.05, 1.55, 0.37), Vector3(0.03, 0.04, 0.03), Color(0.1, 0.1, 0.11), 6)
		elif k == 1 or k == 2:
			var gc := o + Vector3(0.0, 1.0, 0.18)
			NewModels6.ball(md, "gloss", gc, Vector3(0.17, 0.2, 0.05), wood if k == 1 else Color(0.5, 0.1, 0.08), 10)
			NewModels6.limb(md, "wood", gc + Vector3(0.0, 0.1, 0.0), gc + Vector3(0.45 * (1.0 if k == 1 else -1.0), 0.35, 0.0), 0.016, 0.014, Color(0.18, 0.1, 0.06), 5)
		else:
			NewModels6.cyl(md, "gloss", o + Vector3(0, 0.0, 0.7), o + Vector3(0, 0.45, 0.7), 0.24, 0.24, 14, Color(0.55, 0.15, 0.1), 3, 0.04)
			NewModels6.cyl(md, "gloss", o + Vector3(-0.4, 0.5, 0.55), o + Vector3(-0.4, 0.62, 0.55), 0.17, 0.17, 12, Color(0.75, 0.75, 0.72), 3, 0.04)
			NewModels6.cyl(md, "gloss", o + Vector3(0.45, 0.6, 0.5), o + Vector3(0.45, 0.62, 0.5), 0.18, 0.18, 12, Color(0.75, 0.62, 0.3), 3, 0.0)
			NewModels6.limb(md, "steel", o + Vector3(0.45, 0.0, 0.5), o + Vector3(0.45, 0.6, 0.5), 0.01, 0.01, Color(0.2, 0.2, 0.22), 5)
			NewModels6.cyl(md, "rubber", o + Vector3(0, 0.0, 0.0), o + Vector3(0, 0.42, 0.0), 0.2, 0.2, 10, Color(0.08, 0.08, 0.08), 3, 0.0)

# ================================================================== evidence and police close-ups
static func _tape_roll(md: NewModels6.Model) -> void:
	var f := func(p: Vector3, _n: Vector3) -> Color:
		return Color(0.1, 0.25, 0.7) if fposmod(p.x * 90.0 + p.z * 90.0 + p.y * 40.0, 2.0) < 1.0 else Color(0.94, 0.94, 0.9)
	var prof := PackedVector2Array([Vector2(0.03, -0.04), Vector2(0.075, -0.04), Vector2(0.075, 0.04), Vector2(0.03, 0.04), Vector2(0.03, -0.04)])
	NewModels6.put_f(md, "paper", DroneParts.lathe(prof, 20), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)), f)
	NewModels6.cyl(md, "paper", Vector3(0, 0.0, 0), Vector3(0, 0.002, 0), 0.075, 0.075, 18, Color(0.1, 0.25, 0.7), 3, 0.0)
	for k in 6:
		var x := 0.08 + k * 0.045
		NewModels6.box(md, "paper", Vector3(x, 0.002, 0.012 * k), Vector3(0.045, 0.001, 0.07), Color(0.1, 0.25, 0.7) if k % 2 == 0 else Color(0.94, 0.94, 0.9), 0.06 * k)

static func _tape_strip(md: NewModels6.Model) -> void:
	for sx: float in [-1.5, 1.5]:
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, 0.0), Vector3(sx, 1.1, 0.0), 0.025, 0.02, Color(0.5, 0.4, 0.28), 6, 0.1)
		NewModels6.cyl(md, "paint", Vector3(sx, 0.0, 0.0), Vector3(sx, 0.03, 0.0), 0.12, 0.12, 8, Color(0.1, 0.1, 0.11), 3, 0.0)
	var n := 24
	for k in n:
		var x0 := -1.5 + 3.0 * k / n; var x1 := -1.5 + 3.0 * (k + 1) / n
		var t0 := float(k) / n; var t1 := float(k + 1) / n
		var y0 := 0.95 - 0.07 * 4.0 * t0 * (1.0 - t0); var y1 := 0.95 - 0.07 * 4.0 * t1 * (1.0 - t1)
		var c := Color(0.1, 0.25, 0.7) if k % 2 == 0 else Color(0.94, 0.94, 0.9)
		NewModels6.sheet(md, "paper", [Vector3(x0, y0 - 0.035, 0), Vector3(x1, y1 - 0.035, 0), Vector3(x1, y1 + 0.035, 0), Vector3(x0, y0 + 0.035, 0)], c, Vector3(0, 0, 1))
	NewModels6.hull(md, Vector3(0, 0.55, 0), Vector3(3.1, 1.1, 0.3))
	md.hulls.clear()

static func _cone(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.15, 0.02), Vector2(0.09, 0.03), Vector2(0.075, 0.45), Vector2(0.055, 0.45), Vector2(0.0, 0.45)])
	var f := func(p: Vector3, _n: Vector3) -> Color:
		if p.y < 0.03: return Color(0.04, 0.04, 0.04)
		if p.y > 0.2 and p.y < 0.28 or p.y > 0.34 and p.y < 0.4: return Color(0.9, 0.9, 0.85)
		return Color(0.92, 0.34, 0.07)
	NewModels6.put_f(md, "rubber", DroneParts.lathe(prof, 14), Transform3D.IDENTITY, f)
	NewModels6.hull(md, Vector3(0, 0.22, 0), Vector3(0.3, 0.45, 0.3))

static func _marker(md: NewModels6.Model) -> void:
	var y := Color(0.95, 0.8, 0.1)
	NewModels6.box(md, "paper", Vector3(0, 0.05, 0.03), Vector3(0.1, 0.1, 0.004), y, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.25))
	NewModels6.box(md, "paper", Vector3(0, 0.05, -0.03), Vector3(0.1, 0.1, 0.004), y * 0.95, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.25))
	NewModels6.text(md, "paper", "1", Vector3(0, 0.025, 0.0545), Vector3(0, 0.25, 1).normalized(), 0.05, Color(0.05, 0.05, 0.05), Vector3.UP, 0.0)

static func _bag(md: NewModels6.Model) -> void:
	var kraft := Color(0.62, 0.48, 0.3)
	NewModels6.rbox(md, "paper", Vector3(0, 0.15, 0), Vector3(0.2, 0.3, 0.07), kraft, Basis.IDENTITY, 5.0, 8, 0.05)
	NewModels6.box(md, "paper", Vector3(0, 0.3, 0), Vector3(0.2, 0.04, 0.09), kraft * 0.92)
	NewModels6.box(md, "paper", Vector3(0, 0.285, 0.036), Vector3(0.21, 0.03, 0.004), Color(0.75, 0.12, 0.1))
	NewModels6.box(md, "paper", Vector3(0, 0.19, 0.036), Vector3(0.12, 0.06, 0.002), Color(0.9, 0.88, 0.8))

static func _radio(md: NewModels6.Model) -> void:
	NewModels6.rbox(md, "rubber", Vector3(0, 0.07, 0), Vector3(0.062, 0.14, 0.034), Color(0.05, 0.05, 0.06), Basis.IDENTITY, 6.0, 8, 0.02)
	NewModels6.limb(md, "rubber", Vector3(0.02, 0.14, 0.0), Vector3(0.025, 0.25, 0.0), 0.006, 0.004, Color(0.04, 0.04, 0.05), 5)
	NewModels6.box(md, "glass", Vector3(0, 0.1, 0.0175), Vector3(0.04, 0.025, 0.002), Color(0.2, 0.3, 0.2))
	NewModels6.ball(md, "rubber", Vector3(-0.036, 0.1, 0.0), Vector3(0.008, 0.01, 0.01), Color(0.9, 0.5, 0.1), 5)
	NewModels6.box(md, "rubber", Vector3(0, 0.04, 0.0177), Vector3(0.04, 0.05, 0.002), Color(0.02, 0.02, 0.02))

static func _torch(md: NewModels6.Model, on: bool) -> void:
	NewModels6.cyl(md, "rubber", Vector3(0, 0.0, 0), Vector3(0, 0.15, 0), 0.016, 0.02, 10, Color(0.08, 0.08, 0.09), 3, 0.0)
	NewModels6.cyl(md, "rubber", Vector3(0, 0.15, 0), Vector3(0, 0.2, 0), 0.02, 0.032, 10, Color(0.08, 0.08, 0.09), 3, 0.0)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.2, 0), Vector3(0, 0.205, 0), 0.032, 0.032, 10, Color(0.6, 0.6, 0.62), 3, 0.0)
	var lg := md.sub("lamp_glass", Vector3(0, 0.205, 0))
	NewModels6.cyl(lg, "lamp" if on else "lamp_off", Vector3(0, 0.205, 0), Vector3(0, 0.208, 0), 0.027, 0.027, 10, Color.WHITE, 3, 0.0)
	NewModels6.box(md, "chrome", Vector3(0, 0.1, 0.019), Vector3(0.012, 0.025, 0.006), Color(0.5, 0.5, 0.52))

static func _notebook(md: NewModels6.Model) -> void:
	NewModels6.box(md, "leather", Vector3(0, 0.006, 0), Vector3(0.2, 0.012, 0.13), Color(0.1, 0.12, 0.2))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paper", Vector3(sx * 0.049, 0.015, 0.0), Vector3(0.095, 0.008, 0.12), Color(0.9, 0.88, 0.8), 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, -sx * 0.04))
		for k in 9:
			NewModels6.box(md, "paper", Vector3(sx * 0.049, 0.0195, -0.05 + k * 0.012), Vector3(0.075 - NewModels6.rnd(k + sx, 2.0) * 0.03, 0.0006, 0.0025), Color(0.15, 0.15, 0.3))
	NewModels6.cyl(md, "enamel", Vector3(0.11, 0.012, 0.05), Vector3(0.11, 0.012, -0.06), 0.004, 0.004, 6, Color(0.1, 0.1, 0.12), 3, 0.0)

static func _camera(md: NewModels6.Model) -> void:
	NewModels6.rbox(md, "paint", Vector3(0, 0.045, 0), Vector3(0.12, 0.08, 0.06), Color(0.08, 0.08, 0.09), Basis.IDENTITY, 6.0, 10, 0.02)
	NewModels6.cyl(md, "chrome", Vector3(0.0, 0.045, 0.03), Vector3(0.0, 0.045, 0.085), 0.034, 0.03, 14, Color(0.12, 0.12, 0.13), 3, 0.0)
	NewModels6.cyl(md, "glass", Vector3(0.0, 0.045, 0.085), Vector3(0.0, 0.045, 0.087), 0.026, 0.026, 12, Color.WHITE, 3, 0.0)
	NewModels6.box(md, "paint", Vector3(-0.03, 0.095, 0.0), Vector3(0.04, 0.015, 0.03), Color(0.05, 0.05, 0.06))
	NewModels6.ball(md, "chrome", Vector3(0.04, 0.09, 0.01), Vector3(0.012, 0.008, 0.012), Color(0.6, 0.6, 0.62), 6)
	for sx: float in [-1.0, 1.0]:
		var prev := Vector3(sx * 0.06, 0.06, 0.0)
		for k in 8:
			var t := (k + 1) / 8.0
			var p := Vector3(sx * (0.06 + 0.04 * t), 0.06 - 0.05 * t, -0.01 * sin(t * 3.0) + 0.1 * t * 0.0)
			NewModels6.limb(md, "leather", prev, p, 0.006, 0.006, Color(0.1, 0.07, 0.05), 3)
			prev = p

static func _vin(md: NewModels6.Model) -> void:
	NewModels6.box(md, "chrome", Vector3(0, 0.015, 0), Vector3(0.14, 0.03, 0.002), Color(0.62, 0.62, 0.64))
	NewModels6.text(md, "chrome", "HW1F4B0X1KD123456", Vector3(0, 0.008, 0), Vector3(0, 0, 1), 0.012, Color(0.1, 0.1, 0.12), Vector3.UP, 0.0015)
	for sx: float in [-1.0, 1.0]:
		NewModels6.ball(md, "chrome", Vector3(sx * 0.063, 0.015, 0.002), Vector3(0.003, 0.003, 0.002), Color(0.45, 0.45, 0.48), 4)

static func _sticker(md: NewModels6.Model) -> void:
	NewModels6.box(md, "paper", Vector3(0, 0.05, 0), Vector3(0.1, 0.1, 0.0015), GREEN)
	NewModels6.box(md, "paper", Vector3(0, 0.05, 0.001), Vector3(0.09, 0.09, 0.0008), CREAM)
	NewModels6.box(md, "paper", Vector3(0, 0.05, 0.0016), Vector3(0.082, 0.082, 0.0008), GREEN)
	NewModels6.text(md, "paper", "VOSS", Vector3(0, 0.058, 0.0016), Vector3(0, 0, 1), 0.02, CREAM, Vector3.UP, 0.0006)
	NewModels6.text(md, "paper", "& SON", Vector3(0, 0.034, 0.0016), Vector3(0, 0, 1), 0.02, CREAM, Vector3.UP, 0.0006)
	NewModels6.text(md, "paper", "TOWING", Vector3(0, 0.014, 0.0016), Vector3(0, 0, 1), 0.01, CREAM, Vector3.UP, 0.0006)

static func _keys(md: NewModels6.Model) -> void:
	var n := 14
	for k in n:
		var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
		NewModels6.limb(md, "chrome", Vector3(cos(a0) * 0.016, 0.003, sin(a0) * 0.016), Vector3(cos(a1) * 0.016, 0.003, sin(a1) * 0.016), 0.0014, 0.0014, Color(0.62, 0.62, 0.64), 3)
	for k in 2:
		var ang := -0.5 + k * 0.9
		var d := Vector3(sin(ang), 0, cos(ang))
		NewModels6.box(md, "chrome", d * 0.05, Vector3(0.012, 0.003, 0.07), Color(0.7, 0.62, 0.3) if k == 0 else Color(0.6, 0.6, 0.62), ang)
		NewModels6.box(md, "chrome", d * 0.09 + Vector3(0, 0, 0), Vector3(0.012, 0.003, 0.004), Color(0.6, 0.6, 0.62), ang)
		NewModels6.ball(md, "chrome", d * 0.015, Vector3(0.012, 0.0025, 0.012), Color(0.7, 0.62, 0.3), 6)
	NewModels6.box(md, "leather", Vector3(0.03, 0.003, -0.05), Vector3(0.035, 0.004, 0.025), Color(0.5, 0.35, 0.18), 0.4)
	NewModels6.box(md, "paper", Vector3(0.03, 0.0055, -0.05), Vector3(0.028, 0.001, 0.014), Color(0.88, 0.84, 0.68), 0.4)

static func _glove_programme(md: NewModels6.Model) -> void:
	NewModels6Camp._programme(md, false)
	# a small photograph tucked into the fold, showing a few people in front of a bus
	NewModels6.box(md, "paper", Vector3(0.02, 0.0105, 0.0), Vector3(0.09, 0.0015, 0.06), Color(0.82, 0.78, 0.66), 0.15)
	NewModels6.box(md, "paper", Vector3(0.02, 0.0122, 0.0), Vector3(0.082, 0.0006, 0.052), Color(0.55, 0.5, 0.4), 0.15)
	for k in 5:
		NewModels6.box(md, "paper", Vector3(-0.015 + k * 0.016, 0.0132, 0.005), Vector3(0.007, 0.0004, 0.02), Color(0.2, 0.18, 0.15) * (0.7 + 0.3 * NewModels6.rnd(k, 1.0)), 0.15)

static func _committee(md: NewModels6.Model) -> void:
	# a framed 1970s photograph of the festival committee: rows of small figures in brown and orange, a green bus behind
	NewModels6.box(md, "wood", Vector3(0, 0.08, 0), Vector3(0.22, 0.17, 0.014), Color(0.34, 0.24, 0.15))
	NewModels6.box(md, "paper", Vector3(0, 0.08, 0.008), Vector3(0.19, 0.14, 0.002), Color(0.72, 0.66, 0.5))
	NewModels6.box(md, "paper", Vector3(0, 0.12, 0.0095), Vector3(0.19, 0.06, 0.0008), Color(0.3, 0.4, 0.3))      # the bus
	for row in 2:
		for k in 7:
			var x := -0.075 + k * 0.025 + row * 0.0125
			var y := 0.06 + row * 0.03
			var coat: Color = [Color(0.55, 0.3, 0.12), Color(0.4, 0.22, 0.12), Color(0.7, 0.45, 0.15), Color(0.3, 0.2, 0.14)][(k + row) % 4]
			NewModels6.box(md, "paper", Vector3(x, y - 0.012, 0.0105), Vector3(0.016, 0.026, 0.0008), coat)
			NewModels6.ball(md, "paper", Vector3(x, y + 0.012, 0.0105), Vector3(0.007, 0.008, 0.0006), Color(0.8, 0.6, 0.48), 6)
	NewModels6.box(md, "wood", Vector3(0, 0.0, -0.06), Vector3(0.05, 0.002, 0.002), Color(0.3, 0.2, 0.12))
	NewModels6.limb(md, "wood", Vector3(0.0, 0.01, -0.012), Vector3(0.0, 0.14, -0.06), 0.004, 0.004, Color(0.3, 0.22, 0.14), 4)

# ================================================================== reward pieces
static func _drone_badge(md: NewModels6.Model) -> void:
	# a 3 cm enamel plate, green with a cream rim and a small bus mark: attaches to a drone with a magnet on the back
	NewModels6.cyl(md, "chrome", Vector3(0, 0, 0), Vector3(0, 0.003, 0), 0.016, 0.016, 20, Color(0.72, 0.62, 0.3), 3, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.003, 0), Vector3(0, 0.0045, 0), 0.0145, 0.0145, 20, CREAM, 3, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.0045, 0), Vector3(0, 0.006, 0), 0.0125, 0.0125, 20, GREEN, 3, 0.0)
	NewModels6.box(md, "enamel", Vector3(0, 0.0065, 0), Vector3(0.016, 0.0006, 0.008), CREAM)
	for sx: float in [-0.005, 0.005]:
		NewModels6.cyl(md, "enamel", Vector3(sx, 0.0065, 0.0045), Vector3(sx, 0.0069, 0.0045), 0.0018, 0.0018, 8, Color(0.05, 0.05, 0.05), 3, 0.0)
	NewModels6.cyl(md, "rubber", Vector3(0, -0.002, 0), Vector3(0, 0.0, 0), 0.012, 0.012, 14, Color(0.15, 0.15, 0.16), 3, 0.0)

static func _rosette(md: NewModels6.Model) -> void:
	# pleated cream fan round a green centre, two ribbon tails
	var n := 24
	for k in n:
		var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
		var rh := 0.012 if k % 2 == 0 else 0.006
		var c := CREAM if k % 2 == 0 else CREAM * 0.88
		NewModels6.sheet(md, "cloth", [Vector3(0, 0.0, 0), Vector3(cos(a0) * 0.045, rh, sin(a0) * 0.045), Vector3(cos(a1) * 0.045, rh * 0.8, sin(a1) * 0.045)], c, Vector3(0, 1, 0))
	NewModels6.cyl(md, "enamel", Vector3(0, 0.012, 0), Vector3(0, 0.016, 0), 0.02, 0.018, 14, GREEN, 3, 0.0)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.016, 0), Vector3(0, 0.0175, 0), 0.012, 0.012, 12, Color(0.72, 0.62, 0.3), 3, 0.0)
	for sx: float in [-1.0, 1.0]:
		NewModels6.sheet(md, "cloth", [Vector3(sx * 0.008, 0.003, 0.02), Vector3(sx * 0.02, 0.003, 0.02), Vector3(sx * 0.05, 0.003, 0.11), Vector3(sx * 0.03, 0.003, 0.12)], GREEN if sx < 0.0 else CREAM, Vector3(0, 1, 0))

# ================================================================== the two 2D pieces (PNG)
static func _txt(img: Image, s: String, cx: int, y: int, px: int, col: Color) -> void:
	var w := 0
	for ch in s: w += (3 if ch == " " else 6) * px
	var x := cx - (w - px) / 2
	for ch in s:
		if ch == " ": x += 3 * px; continue
		var g: Array = NewModels6.FONT.get(ch, NewModels6.FONT["."])
		for r in 7:
			for c in 5:
				if (g[r] as String)[c] == "X":
					img.fill_rect(Rect2i(x + c * px, y + r * px, px, px), col)
		x += 6 * px

static func decal(name: String) -> Image:
	if name == "livery_voss_son_decal":
		# a 512 x 160 sticker for the Gimbal Mini's shell: green plate, cream border, the name, and a small bus
		var img := Image.create(512, 160, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		img.fill_rect(Rect2i(4, 4, 504, 152), Color(0.88, 0.84, 0.68))
		img.fill_rect(Rect2i(14, 14, 484, 132), GREEN)
		_txt(img, "VOSS & SON", 256, 32, 8, Color(0.88, 0.84, 0.68))
		_txt(img, "MOTOR WORKS", 256, 108, 4, Color(0.88, 0.84, 0.68))
		img.fill_rect(Rect2i(30, 50, 56, 34), Color(0.88, 0.84, 0.68))
		img.fill_rect(Rect2i(34, 56, 12, 12), GREEN); img.fill_rect(Rect2i(50, 56, 12, 12), GREEN); img.fill_rect(Rect2i(66, 56, 12, 12), GREEN)
		img.fill_rect(Rect2i(38, 80, 10, 10), Color(0.1, 0.1, 0.1)); img.fill_rect(Rect2i(66, 80, 10, 10), Color(0.1, 0.1, 0.1))
		return img
	# the Casebook badge: a cream and green rosette disc with a bus and a plain title
	var im := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for y in 256:
		for x in 256:
			var d := Vector2(x - 128.0, y - 128.0).length()
			var a := atan2(y - 128.0, x - 128.0)
			var scallop := 118.0 + 7.0 * sin(a * 24.0)
			if d < scallop: im.set_pixel(x, y, Color(0.88, 0.84, 0.68))
			if d < 98.0: im.set_pixel(x, y, GREEN)
			if d < 90.0 and d > 86.0: im.set_pixel(x, y, Color(0.88, 0.84, 0.68))
	_txt(im, "HALLOWAY", 128, 66, 4, Color(0.88, 0.84, 0.68))
	_txt(im, "CASEBOOK", 128, 170, 4, Color(0.88, 0.84, 0.68))
	im.fill_rect(Rect2i(78, 108, 100, 40), Color(0.88, 0.84, 0.68))
	for k in 4: im.fill_rect(Rect2i(84 + k * 22, 114, 16, 14), GREEN)
	im.fill_rect(Rect2i(92, 140, 14, 14), Color(0.1, 0.1, 0.1)); im.fill_rect(Rect2i(150, 140, 14, 14), Color(0.1, 0.1, 0.1))
	return im
