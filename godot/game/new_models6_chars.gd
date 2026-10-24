class_name NewModels6Chars
extends RefCounted
## Story batch (models8), people and dogs: Ellis Voss (a retired mechanic in his seventies), Constable Rennick, and Biscuit the
## collie cross. Static posed figures, not rigs: each pose is its own export. Built from a small skeleton (joint angles to joint
## positions), then tapered limbs, a lofted torso, a plain stylised-realistic head, clothes as colour and thickness.
## Frame: metres, +Z is the way the figure faces, origin on the ground under the figure (a seated figure: under the seat).
## The figure's right-hand side is -x. Faces are deliberately minimal (nose, brow, eyes, a mouth line, ears): no uncanny detail.
## People and dogs carry no collision hulls (the brief).

const NAMES: Array[String] = [
	"ellis_standing_a", "ellis_standing_a_hips", "ellis_sitting_a", "ellis_sitting_a_mug", "ellis_under_bus_a", "ellis_waving_a",
	"ellis_toolbox_a", "ellis_toolbox_a_closed",
	"biscuit_sitting_a", "biscuit_standing_a", "biscuit_lying_a", "biscuit_running_a", "dog_bowl_a", "dog_bowl_a_full",
	"rennick_standing_a", "rennick_standing_a_clipboard", "rennick_walking_a", "rennick_knocking_a", "rennick_uniform_a", "rennick_uniform_a_writing",
	"police_clipboard_a",
]

const SKIN_E := Color(0.80, 0.60, 0.50)
const SKIN_R := Color(0.62, 0.45, 0.35)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"ellis_standing_a": _ellis(md, "stand", lod)
		"ellis_standing_a_hips": _ellis(md, "hips", lod)
		"ellis_sitting_a": _ellis(md, "sit", lod)
		"ellis_sitting_a_mug": _ellis(md, "sitmug", lod)
		"ellis_under_bus_a": _ellis_under(md, lod)
		"ellis_waving_a": _ellis(md, "wave", lod)
		"ellis_toolbox_a": _ellis(md, "tools", lod)
		"ellis_toolbox_a_closed": _ellis(md, "toolsclosed", lod)
		"biscuit_sitting_a": _biscuit(md, "sit", lod)
		"biscuit_standing_a": _biscuit(md, "stand", lod)
		"biscuit_lying_a": _biscuit(md, "lie", lod)
		"biscuit_running_a": _biscuit(md, "run", lod)
		"dog_bowl_a": _bowl(md, false)
		"dog_bowl_a_full": _bowl(md, true)
		"rennick_standing_a": _rennick(md, "stand", lod)
		"rennick_standing_a_clipboard": _rennick(md, "clip", lod)
		"rennick_walking_a": _rennick(md, "walk", lod)
		"rennick_knocking_a": _rennick(md, "knock", lod)
		"rennick_uniform_a": _rennick(md, "uniform", lod)
		"rennick_uniform_a_writing": _rennick(md, "uniformwrite", lod)
		"police_clipboard_a": _clipboard(md)
		_: return false
	return true

# ================================================================== the skeleton and the body
## A limb direction: flex swings it forward (+z), abd out to its own side (side is +1 for +x, -1 for -x). Straight down at 0, 0.
static func _dir(side: float, flex: float, abd: float) -> Vector3:
	return Vector3(side * sin(abd), -cos(abd) * cos(flex), cos(abd) * sin(flex)).normalized()

static func _bend(d: Vector3, ang: float, ref: Vector3) -> Vector3:
	var ax := d.cross(ref)
	if ax.length() < 1e-4: ax = Vector3.RIGHT
	return (Basis(ax.normalized(), ang) * d).normalized()

class Style:
	var jacket: Color
	var trousers: Color
	var boots: Color
	var skin: Color
	var hair: Color
	var height := 1.75
	var female := false
	var age := 0.0                     # greying and lines
	var jacket_k := 1.2                # arm and torso thickness over the bare limb
	var cap := ""                      # "flat", "peaked", ""
	var cap_col: Color
	var stubble := false

## Builds one person from a pose and returns the joints (for adding props to a hand).
## pose keys: pelvis (Vector3), lean, twist, head_pitch, head_yaw, hip_r/hip_l [flex, abd], knee_r/knee_l, foot_r/foot_l,
## arm_r/arm_l [flex, abd], elbow_r/elbow_l, hide_hand_r/hide_hand_l, expr
static func _person(md: NewModels6.Model, st: Style, pose: Dictionary, lod: int) -> Dictionary:
	var s := st.height / 1.75
	var seg: int = [10, 8, 6][lod]
	var jk := st.jacket_k
	var yaw: float = pose.get("twist", 0.0)
	var lean: float = pose.get("lean", 0.0)
	var pel: Vector3 = pose.get("pelvis", Vector3(0, 0.97 * s, 0))
	var by := Basis(Vector3.UP, yaw)
	var tb := by * Basis(Vector3.RIGHT, lean)
	var spine := tb * Vector3.UP
	var tright := tb * Vector3.RIGHT
	var neck := pel + spine * 0.55 * s
	var J := {}
	# ---- legs
	for side: float in [-1.0, 1.0]:
		var tag := "r" if side < 0.0 else "l"
		var hip := pel + by * Vector3(side * 0.09 * s, -0.02 * s, 0)
		var hp: Array = pose.get("hip_" + tag, [0.0, 0.03])
		var th := (by * _dir(side, float(hp[0]), float(hp[1]))).normalized()
		var knee := hip + th * 0.43 * s
		var sh := _bend(th, float(pose.get("knee_" + tag, 0.0)), by * Vector3(0, 0, -1))
		var ankle := knee + sh * 0.42 * s
		NewModels6.limb(md, "cloth", hip, knee, 0.088 * s, 0.062 * s, st.trousers, seg, 0.05)
		NewModels6.ball(md, "cloth", knee, Vector3(0.063, 0.063, 0.063) * s, st.trousers, 8)
		NewModels6.limb(md, "cloth", knee, ankle, 0.062 * s, 0.045 * s, st.trousers, seg, 0.05)
		NewModels6.ball(md, "cloth", hip, Vector3(0.09, 0.09, 0.09) * s, st.trousers, 8)
		# the boot: a rounded block lying on the ground (or tipped when the foot is not flat)
		var foot_pitch: float = pose.get("foot_" + tag, 0.0)
		var fb := by * Basis(Vector3.RIGHT, -foot_pitch)
		var boot_c := Vector3(ankle.x, ankle.y - 0.03 * s, ankle.z) + (fb * Vector3(0, 0, 0.06 * s))
		NewModels6.rbox(md, "leather", boot_c, Vector3(0.092, 0.092, 0.255) * s, st.boots, fb, 5.0, 8, 0.05)
		NewModels6.limb(md, "leather", ankle + Vector3(0, 0.1 * s, 0), ankle - Vector3(0, 0.03 * s, 0), 0.05 * s, 0.056 * s, st.boots, 8, 0.03)
		J["ankle_" + tag] = ankle
		J["knee_" + tag] = knee
	# ---- pelvis, torso, neck
	NewModels6.ball(md, "cloth", pel + Vector3(0, 0.02 * s, 0), Vector3(0.175, 0.105, 0.115) * s, st.trousers, 10, by)
	var k := jk * (0.9 if st.female else 0.92)
	var secs: Array = [[0.0, 0.165 * k, 0.112 * k], [0.25, 0.168 * k, 0.115 * k], [0.55, 0.178 * k, 0.12 * k], [0.85, 0.2 * k, 0.112 * k], [1.0, 0.16 * k, 0.085 * k]]
	if st.female:
		secs = [[0.0, 0.155 * k, 0.105 * k], [0.22, 0.148 * k, 0.098 * k], [0.5, 0.16 * k, 0.11 * k], [0.8, 0.185 * k, 0.105 * k], [1.0, 0.15 * k, 0.08 * k]]
	for sec in secs:
		sec[1] = float(sec[1]) * s; sec[2] = float(sec[2]) * s
	NewModels6.shell(md, "cloth", pel, neck, secs, st.jacket, tright, 2.6, seg + 2, 0.06)
	NewModels6.limb(md, "skin", neck - spine * 0.02 * s, neck + spine * 0.1 * s, 0.05 * s, 0.045 * s, st.skin, 8)
	NewModels6.ball(md, "cloth", neck, Vector3(0.1, 0.045, 0.085) * s, st.jacket, 8, tb)
	# ---- head
	var hb := by * Basis(Vector3.UP, pose.get("head_yaw", 0.0)) * Basis(Vector3.RIGHT, lean + float(pose.get("head_pitch", 0.0)))
	var head_c := neck + (hb * Vector3.UP) * 0.125 * s + (hb * Vector3(0, 0, 0.012 * s))
	_head(md, st, head_c, hb, s, lod, String(pose.get("expr", "neutral")))
	J["head"] = head_c
	# ---- arms
	var ak := 0.85 + 0.15 * jk
	for side: float in [-1.0, 1.0]:
		var tag := "r" if side < 0.0 else "l"
		var sh_j := neck - spine * 0.075 * s + tright * (side * 0.19 * s * (0.97 + 0.03 * jk))
		var ap: Array = pose.get("arm_" + tag, [0.0, 0.1])
		var ua := (tb * _dir(side, float(ap[0]), float(ap[1]))).normalized()
		var elbow := sh_j + ua * 0.30 * s
		var fa_dir := _bend(ua, float(pose.get("elbow_" + tag, 0.2)), tb * Vector3(0, 0, 1))
		var wrist := elbow + fa_dir * 0.265 * s
		NewModels6.limb(md, "cloth", sh_j, elbow, 0.058 * s * ak, 0.049 * s * ak, st.jacket, seg, 0.06)
		NewModels6.ball(md, "cloth", sh_j, Vector3(0.062, 0.062, 0.062) * s * ak, st.jacket, 8)
		NewModels6.ball(md, "cloth", elbow, Vector3(0.05, 0.05, 0.05) * s * ak, st.jacket, 8)
		NewModels6.limb(md, "cloth", elbow, wrist, 0.049 * s * ak, 0.04 * s * ak, st.jacket, seg, 0.06)
		NewModels6.limb(md, "cloth", wrist - fa_dir * 0.015, wrist + fa_dir * 0.025, 0.043 * s, 0.043 * s, st.jacket * 0.9, 8)
		var hand_c := wrist + fa_dir * 0.075 * s
		var hbas := DroneParts.along(wrist, wrist + fa_dir).basis
		if not bool(pose.get("hide_hand_" + tag, false)):
			NewModels6.ball(md, "skin", hand_c, Vector3(0.036, 0.022, 0.082) * s, st.skin, 8, hbas)
			NewModels6.ball(md, "skin", hand_c + hbas * Vector3(0.03 * side, 0.0, 0.0) * s, Vector3(0.012, 0.012, 0.04) * s, st.skin, 6, hbas)
		J["sh_" + tag] = sh_j; J["elbow_" + tag] = elbow; J["wrist_" + tag] = wrist; J["hand_" + tag] = hand_c
	J["pelvis"] = pel; J["neck"] = neck; J["s"] = s
	return J

## A plain head: an egg, a nose, brow, eyes, a mouth line, ears, hair or a cap. Faces +Z in its own frame.
static func _head(md: NewModels6.Model, st: Style, c: Vector3, hb: Basis, s: float, lod: int, expr: String) -> void:
	var skin := st.skin
	var seg: int = [12, 9, 7][lod]
	var grey := st.stubble
	var f := func(p: Vector3, _n: Vector3) -> Color:
		var col := skin
		if grey and p.y < -0.15 and p.z > 0.0: col = skin.lerp(Color(0.62, 0.60, 0.57), 0.55)
		var cheek := clampf(1.0 - absf(p.y + 0.1) * 3.0, 0.0, 1.0) * clampf(absf(p.x) * 2.0, 0.0, 1.0) * clampf(p.z + 0.2, 0.0, 1.0)
		return col.lerp(Color(skin.r * 1.08, skin.g * 0.85, skin.b * 0.82), cheek * 0.35)
	NewModels6.put_f(md, "skin", DroneParts.sphere(1.0, seg), Transform3D(hb * Basis.from_scale(Vector3(0.088, 0.108, 0.1) * s), c), f)
	NewModels6.ball(md, "skin", c + hb * Vector3(0, -0.06 * s, 0.02 * s), Vector3(0.07, 0.065, 0.08) * s, skin, 8, hb)
	var nose_col := skin.lerp(Color(0.8, 0.45, 0.4), 0.15)
	NewModels6.ball(md, "skin", c + hb * Vector3(0, -0.015 * s, 0.098 * s), Vector3(0.016, 0.03, 0.026) * s, nose_col, 6, hb)
	NewModels6.ball(md, "skin", c + hb * Vector3(0, 0.035 * s, 0.085 * s), Vector3(0.075, 0.014, 0.03) * s, skin * 0.97, 6, hb)
	for sx: float in [-1.0, 1.0]:
		NewModels6.ball(md, "enamel", c + hb * Vector3(sx * 0.034 * s, 0.018 * s, 0.092 * s), Vector3(0.011, 0.009, 0.006) * s, Color(0.05, 0.035, 0.03), 5, hb)
		NewModels6.ball(md, "skin", c + hb * Vector3(sx * 0.093 * s, -0.006 * s, -0.005 * s), Vector3(0.012, 0.032, 0.022) * s, skin * 0.96, 6, hb)
		if st.age > 0.3:
			NewModels6.ball(md, "skin", c + hb * Vector3(sx * 0.036 * s, 0.002 * s, 0.09 * s), Vector3(0.016, 0.006, 0.01) * s, skin * 0.88, 5, hb)
	var lip := skin.lerp(Color(0.5, 0.2, 0.18), 0.5)
	NewModels6.ball(md, "skin", c + hb * Vector3(0, -0.06 * s, 0.093 * s), Vector3(0.03, 0.005, 0.008) * s, lip, 5, hb)
	if expr != "neutral":
		for sx: float in [-1.0, 1.0]:
			NewModels6.ball(md, "skin", c + hb * Vector3(sx * 0.03 * s, -0.055 * s, 0.092 * s), Vector3(0.012, 0.005, 0.008) * s, lip, 5, hb * Basis(Vector3.BACK, sx * 0.5))
	var hair := st.hair
	if st.cap == "flat":
		NewModels6.ball(md, "cloth", c + hb * Vector3(0, 0.06 * s, -0.005 * s), Vector3(0.1, 0.045, 0.115) * s, st.cap_col, 10, hb * Basis(Vector3.RIGHT, -0.05), 0.07)
		NewModels6.box(md, "cloth", c + hb * Vector3(0, 0.045 * s, 0.1 * s), Vector3(0.15, 0.012, 0.075) * s, st.cap_col * 0.9, 0.0, Color(-1, 0, 0), hb * Basis(Vector3.RIGHT, 0.12))
		NewModels6.ball(md, "fur", c + hb * Vector3(0, 0.0, -0.045 * s), Vector3(0.085, 0.085, 0.075) * s, hair, 8, hb, 0.08)
	elif st.cap == "peaked":
		NewModels6.ball(md, "cloth", c + hb * Vector3(0, 0.075 * s, -0.005 * s), Vector3(0.106, 0.05, 0.108) * s, st.cap_col, 10, hb * Basis(Vector3.RIGHT, -0.08), 0.04)
		NewModels6.cyl(md, "cloth", c + hb * Vector3(0, 0.052 * s, 0), c + hb * Vector3(0, 0.074 * s, 0), 0.106 * s, 0.108 * s, 12, st.cap_col * 0.92, 3, 0.03)
		NewModels6.box(md, "leather", c + hb * Vector3(0, 0.05 * s, 0.108 * s), Vector3(0.17, 0.008, 0.08) * s, Color(0.04, 0.04, 0.05), 0.0, Color(-1, 0, 0), hb * Basis(Vector3.RIGHT, 0.2))
		NewModels6.box(md, "sheet", c + hb * Vector3(0, 0.08 * s, 0.104 * s), Vector3(0.026, 0.026, 0.006) * s, Color(0.66, 0.6, 0.45))
		NewModels6.ball(md, "fur", c + hb * Vector3(0, 0.0, -0.06 * s), Vector3(0.08, 0.08, 0.06) * s, hair, 8, hb, 0.08)
	else:
		NewModels6.ball(md, "fur", c + hb * Vector3(0, 0.025 * s, -0.025 * s), Vector3(0.093, 0.1, 0.1) * s, hair, 10, hb, 0.1)
		if st.female:
			NewModels6.ball(md, "fur", c + hb * Vector3(0, -0.03 * s, -0.115 * s), Vector3(0.036, 0.04, 0.05) * s, hair, 6, hb, 0.1)

# ================================================================== Ellis
static func _ellis_style() -> Style:
	var st := Style.new()
	st.jacket = Color(0.19, 0.20, 0.13)              # heavy olive work jacket
	st.trousers = Color(0.12, 0.13, 0.15)
	st.boots = Color(0.17, 0.12, 0.08)
	st.skin = SKIN_E
	st.hair = Color(0.74, 0.73, 0.70)
	st.height = 1.75
	st.age = 0.8
	st.jacket_k = 1.3
	st.cap = "flat"
	st.cap_col = Color(0.26, 0.24, 0.21)
	st.stubble = true
	return st

static func _ellis(md: NewModels6.Model, kind: String, lod: int) -> void:
	var st := _ellis_style()
	var pose := {"lean": 0.05, "head_pitch": -0.03, "hip_r": [0.0, 0.05], "hip_l": [0.0, 0.05], "knee_r": 0.02, "knee_l": 0.02}
	match kind:
		"stand":
			pose["arm_r"] = [0.05, 0.16]; pose["arm_l"] = [0.05, 0.16]; pose["elbow_r"] = 0.9; pose["elbow_l"] = 0.9
			pose["hide_hand_r"] = true; pose["hide_hand_l"] = true
		"hips":
			pose["arm_r"] = [-0.1, 0.55]; pose["arm_l"] = [-0.1, 0.55]; pose["elbow_r"] = 1.35; pose["elbow_l"] = 1.35
			pose["hip_r"] = [0.0, 0.1]; pose["hip_l"] = [0.0, 0.1]
		"wave":
			pose["arm_r"] = [0.1, 0.1]; pose["elbow_r"] = 0.2
			pose["arm_l"] = [0.2, 2.5]; pose["elbow_l"] = 0.55; pose["expr"] = "smile"; pose["head_yaw"] = 0.1
		"sit", "sitmug":
			pose["pelvis"] = Vector3(0, 0.50, 0)
			pose["hip_r"] = [1.5, 0.08]; pose["hip_l"] = [1.5, 0.08]; pose["knee_r"] = 1.5; pose["knee_l"] = 1.5
			pose["lean"] = 0.12
			pose["arm_r"] = [0.45, 0.12]; pose["arm_l"] = [0.5, 0.12]; pose["elbow_r"] = 1.5; pose["elbow_l"] = 1.45
			pose["head_pitch"] = 0.08
		"tools", "toolsclosed":
			pose["pelvis"] = Vector3(0, 0.50, 0)
			pose["hip_r"] = [1.35, 0.15]; pose["hip_l"] = [1.5, 0.2]; pose["knee_r"] = 2.1; pose["knee_l"] = 2.2
			pose["lean"] = 0.5; pose["head_pitch"] = 0.35
			pose["arm_r"] = [0.9, 0.15]; pose["elbow_r"] = 0.9; pose["arm_l"] = [0.5, 0.15]; pose["elbow_l"] = 1.1
	var j := _person(md, st, pose, lod)
	if kind == "sit" or kind == "sitmug":
		_camp_chair_under(md, Vector3(0, 0, -0.03))
	if kind == "sitmug":
		var hc: Vector3 = j["hand_r"]
		_mug(md, hc + Vector3(0, 0.03, 0.02))
	if kind == "tools" or kind == "toolsclosed":
		_toolbox(md, Vector3(-0.38, 0.0, 0.45), kind == "tools")

static func _camp_chair_under(md: NewModels6.Model, o: Vector3) -> void:
	var col := Color(0.16, 0.22, 0.16)
	NewModels6.box(md, "canvas", o + Vector3(0, 0.44, 0.02), Vector3(0.5, 0.025, 0.46), col)
	NewModels6.box(md, "canvas", o + Vector3(0, 0.72, -0.24), Vector3(0.5, 0.5, 0.025), col * 0.95, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.18))
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "sheet", o + Vector3(sx * 0.25, 0.0, 0.2), o + Vector3(sx * 0.25, 0.43, -0.2), 0.013, 0.013, Color(0.55, 0.57, 0.6), 6)
		NewModels6.limb(md, "sheet", o + Vector3(sx * 0.25, 0.0, -0.2), o + Vector3(sx * 0.25, 0.43, 0.2), 0.013, 0.013, Color(0.55, 0.57, 0.6), 6)
		NewModels6.limb(md, "sheet", o + Vector3(sx * 0.25, 0.43, -0.2), o + Vector3(sx * 0.25, 0.9, -0.28), 0.013, 0.013, Color(0.55, 0.57, 0.6), 6)

static func _mug(md: NewModels6.Model, c: Vector3) -> void:
	NewModels6.cyl(md, "enamel", c - Vector3(0, 0.045, 0), c + Vector3(0, 0.045, 0), 0.038, 0.04, 12, Color(0.78, 0.76, 0.68), 3, 0.0)
	NewModels6.cyl(md, "enamel", c + Vector3(0, 0.044, 0), c + Vector3(0, 0.046, 0), 0.034, 0.034, 12, Color(0.22, 0.14, 0.08), 3, 0.0)

static func _toolbox(md: NewModels6.Model, o: Vector3, open: bool) -> void:
	var red := Color(0.46, 0.12, 0.09)
	NewModels6.box(md, "rust", o + Vector3(0, 0.12, 0), Vector3(0.5, 0.22, 0.24), red)
	if open:
		NewModels6.box(md, "rust", o + Vector3(0, 0.33, -0.15), Vector3(0.5, 0.02, 0.2), red * 1.05, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 1.2))
		NewModels6.box(md, "paint", o + Vector3(0, 0.215, 0), Vector3(0.46, 0.015, 0.2), Color(0.1, 0.08, 0.07))
		for k in 6:
			var xx := -0.19 + k * 0.075
			NewModels6.box(md, "chrome", o + Vector3(xx, 0.235, (NewModels6.rnd(k, 1.0) - 0.5) * 0.05), Vector3(0.022, 0.012, 0.18 - 0.012 * k), Color(0.62, 0.63, 0.66), (NewModels6.rnd(k, 2.0) - 0.5) * 0.4)
		for k in 4:
			var p := o + Vector3(0.38 + 0.06 * k, 0.012, 0.15 - 0.11 * k)
			NewModels6.box(md, "chrome", p, Vector3(0.03, 0.012, 0.19), Color(0.58, 0.59, 0.62), (NewModels6.rnd(k, 4.0) - 0.5) * 1.2)
			NewModels6.cyl(md, "chrome", p + Vector3(0, 0, 0.1), p + Vector3(0, 0.0125, 0.1), 0.026, 0.026, 8, Color(0.56, 0.57, 0.6), 3, 0.0)
	else:
		NewModels6.box(md, "rust", o + Vector3(0, 0.255, 0), Vector3(0.5, 0.04, 0.24), red * 1.05)
	NewModels6.box(md, "leather", o + Vector3(0, 0.30, 0), Vector3(0.28, 0.02, 0.025), Color(0.1, 0.08, 0.06))

static func _ellis_under(md: NewModels6.Model, lod: int) -> void:
	# a man on a mechanic's creeper under a bus: only his legs and boots show, the rest is under the vehicle (at -z)
	var st := _ellis_style()
	var seg: int = [12, 8, 6][lod]
	NewModels6.box(md, "paint", Vector3(0, 0.07, -0.15), Vector3(0.4, 0.05, 1.0), Color(0.34, 0.12, 0.09))
	for sx: float in [-0.17, 0.17]:
		for zz: float in [-0.55, 0.25]:
			NewModels6.cyl(md, "rubber", Vector3(sx - 0.015, 0.028, zz), Vector3(sx + 0.015, 0.028, zz), 0.028, 0.028, 8, Color(0.05, 0.05, 0.05), 3, 0.0)
	for sx: float in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.1, 0.17, -0.15)
		var knee := hip + Vector3(sx * 0.02, 0.1, 0.38)
		var ankle := knee + Vector3(sx * 0.02, -0.08, 0.38)
		NewModels6.limb(md, "cloth", hip, knee, 0.088, 0.062, st.trousers, seg, 0.05)
		NewModels6.ball(md, "cloth", knee, Vector3(0.063, 0.063, 0.063), st.trousers, 8)
		NewModels6.limb(md, "cloth", knee, ankle, 0.062, 0.045, st.trousers, seg, 0.05)
		NewModels6.rbox(md, "leather", ankle + Vector3(0, 0.02, 0.1), Vector3(0.105, 0.115, 0.285), st.boots, Basis(Vector3.RIGHT, -0.9), 5.0, 10, 0.05)
	NewModels6.ball(md, "cloth", Vector3(0, 0.2, -0.17), Vector3(0.2, 0.11, 0.12), st.trousers, 10)

# ================================================================== Constable Rennick
static func _rennick(md: NewModels6.Model, kind: String, lod: int) -> void:
	var st := Style.new()
	st.height = 1.72
	st.female = true
	st.skin = SKIN_R
	st.hair = Color(0.19, 0.11, 0.07)
	st.boots = Color(0.07, 0.07, 0.08)
	st.trousers = Color(0.12, 0.13, 0.17)
	st.jacket = Color(0.12, 0.15, 0.22)          # a practical dark softshell
	st.jacket_k = 1.12
	if kind.begins_with("uniform"):
		st.jacket = Color(0.09, 0.12, 0.2)
		st.trousers = Color(0.07, 0.09, 0.14)
		st.cap = "peaked"; st.cap_col = Color(0.08, 0.1, 0.17)
	var pose := {"lean": 0.03, "arm_r": [0.05, 0.12], "arm_l": [0.05, 0.12], "elbow_r": 0.25, "elbow_l": 0.25, "hip_r": [0.0, 0.04], "hip_l": [0.0, 0.04],
		"knee_r": 0.0, "knee_l": 0.0}
	match kind:
		"clip":
			pose["arm_l"] = [0.55, 0.12]; pose["elbow_l"] = 1.5
		"walk":
			pose["hip_r"] = [0.5, 0.03]; pose["knee_r"] = 0.12; pose["hip_l"] = [-0.35, 0.03]; pose["knee_l"] = 0.4
			pose["arm_r"] = [-0.45, 0.1]; pose["elbow_r"] = 0.3; pose["arm_l"] = [0.5, 0.1]; pose["elbow_l"] = 0.4
			pose["lean"] = 0.1; pose["foot_l"] = 0.3
		"knock":
			pose["arm_r"] = [1.5, 0.15]; pose["elbow_r"] = 1.7; pose["arm_l"] = [0.5, 0.12]; pose["elbow_l"] = 1.6; pose["lean"] = 0.08
		"uniformwrite":
			pose["arm_r"] = [0.55, 0.1]; pose["elbow_r"] = 1.55; pose["arm_l"] = [0.5, 0.1]; pose["elbow_l"] = 1.6; pose["head_pitch"] = 0.35
	var j := _person(md, st, pose, lod)
	var s: float = j["s"]
	var neck: Vector3 = j["neck"]
	NewModels6.limb(md, "cloth", neck + Vector3(-0.07 * s, 0.0, 0.07 * s), neck + Vector3(0, -0.2 * s, 0.1 * s), 0.004, 0.004, Color(0.7, 0.2, 0.15), 4)
	NewModels6.limb(md, "cloth", neck + Vector3(0.07 * s, 0.0, 0.07 * s), neck + Vector3(0, -0.2 * s, 0.1 * s), 0.004, 0.004, Color(0.7, 0.2, 0.15), 4)
	NewModels6.box(md, "paper", neck + Vector3(0, -0.24 * s, 0.1 * s), Vector3(0.055, 0.075, 0.004) * s, Color(0.9, 0.9, 0.86))
	if kind.begins_with("uniform"):
		var shj: Vector3 = j["sh_l"]
		NewModels6.box(md, "rubber", shj + Vector3(0.0, -0.1 * s, 0.07 * s), Vector3(0.05, 0.1, 0.03) * s, Color(0.04, 0.04, 0.05))
		NewModels6.limb(md, "rubber", shj + Vector3(0.01, -0.05 * s, 0.07 * s), shj + Vector3(0.01, 0.02 * s, 0.07 * s), 0.004, 0.004, Color(0.03, 0.03, 0.03), 4)
	var hr: Vector3 = j["hand_r"]
	if kind == "knock":
		var hl: Vector3 = j["hand_l"]
		NewModels6.box(md, "paper", hl + Vector3(0, 0.0, 0.03), Vector3(0.1, 0.14, 0.015), Color(0.15, 0.15, 0.17), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.4))
	elif kind == "clip" or kind == "uniformwrite":
		var hl2: Vector3 = j["hand_l"]
		_clip_at(md, hl2 + Vector3(0.0, 0.05, 0.05), Basis(Vector3.RIGHT, -0.9))
		if kind == "uniformwrite":
			NewModels6.limb(md, "enamel", hr + Vector3(0, 0, 0.02), hr + Vector3(0.02, -0.14, 0.09), 0.006, 0.004, Color(0.1, 0.1, 0.12), 5)
	else:
		NewModels6.box(md, "paper", hr + Vector3(0, -0.04, 0.0), Vector3(0.09, 0.12, 0.012), Color(0.14, 0.14, 0.17), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.2))

static func _clip_at(md: NewModels6.Model, c: Vector3, bas: Basis) -> void:
	NewModels6.box(md, "wood", c, Vector3(0.23, 0.32, 0.012), Color(0.42, 0.29, 0.17), 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(md, "paper", c + bas * Vector3(0, -0.01, 0.009), Vector3(0.2, 0.28, 0.004), Color(0.92, 0.91, 0.85), 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(md, "chrome", c + bas * Vector3(0, 0.15, 0.012), Vector3(0.08, 0.03, 0.014), Color(0.65, 0.66, 0.68), 0.0, Color(-1, 0, 0), bas)

static func _clipboard(md: NewModels6.Model) -> void:
	_clip_at(md, Vector3(0, 0.012, 0), Basis(Vector3.RIGHT, -PI * 0.5))
	for k in 9:
		NewModels6.box(md, "paper", Vector3(-0.07, 0.0215, -0.11 + k * 0.026), Vector3(0.14 - NewModels6.rnd(k, 2.0) * 0.05, 0.001, 0.007), Color(0.3, 0.3, 0.34))
	NewModels6.box(md, "enamel", Vector3(0.12, 0.012, 0.02), Vector3(0.012, 0.012, 0.14), Color(0.1, 0.1, 0.12), 0.3)

# ================================================================== Biscuit (collie cross) and the bowl
const BROWN := Color(0.27, 0.15, 0.08)
const DARK := Color(0.12, 0.08, 0.06)
const WHITE := Color(0.9, 0.88, 0.82)

static func _biscuit(md: NewModels6.Model, kind: String, lod: int, coat_col := BROWN, white := WHITE) -> void:
	var seg: int = [12, 9, 6][lod]
	var chest := Vector3(0, 0.40, 0.18)
	var rump := Vector3(0, 0.40, -0.32)
	var head_dir := Vector3(0, 0.25, 1.0)
	var head_down := 0.0
	var tail_to := Vector3(0, 0.22, -0.78)
	var legs := {}          # name -> [hip, knee, ankle, paw]
	match kind:
		"stand":
			chest = Vector3(0, 0.40, 0.2); rump = Vector3(0, 0.40, -0.33)
			legs = {"fl": [Vector3(0.09, 0.40, 0.22), Vector3(0.1, 0.22, 0.24), Vector3(0.1, 0.09, 0.25), Vector3(0.1, 0.0, 0.29)],
				"fr": [Vector3(-0.09, 0.40, 0.22), Vector3(-0.1, 0.22, 0.24), Vector3(-0.1, 0.09, 0.25), Vector3(-0.1, 0.0, 0.29)],
				"bl": [Vector3(0.1, 0.4, -0.3), Vector3(0.11, 0.26, -0.18), Vector3(0.1, 0.12, -0.3), Vector3(0.1, 0.0, -0.28)],
				"br": [Vector3(-0.1, 0.4, -0.3), Vector3(-0.11, 0.26, -0.18), Vector3(-0.1, 0.12, -0.3), Vector3(-0.1, 0.0, -0.28)]}
			head_dir = Vector3(0, 0.3, 1.0)
			tail_to = Vector3(0, 0.3, -0.8)
		"sit":
			chest = Vector3(0, 0.62, 0.0); rump = Vector3(0, 0.2, -0.3)
			legs = {"fl": [Vector3(0.08, 0.6, 0.06), Vector3(0.09, 0.34, 0.1), Vector3(0.09, 0.13, 0.12), Vector3(0.09, 0.0, 0.17)],
				"fr": [Vector3(-0.08, 0.6, 0.06), Vector3(-0.09, 0.34, 0.1), Vector3(-0.09, 0.13, 0.12), Vector3(-0.09, 0.0, 0.17)],
				"bl": [Vector3(0.12, 0.22, -0.28), Vector3(0.14, 0.16, -0.02), Vector3(0.13, 0.04, -0.2), Vector3(0.13, 0.0, -0.05)],
				"br": [Vector3(-0.12, 0.22, -0.28), Vector3(-0.14, 0.16, -0.02), Vector3(-0.13, 0.04, -0.2), Vector3(-0.13, 0.0, -0.05)]}
			head_dir = Vector3(0, 0.75, 0.7)
			tail_to = Vector3(0.12, 0.03, -0.66)
		"lie":
			chest = Vector3(0, 0.16, 0.18); rump = Vector3(0, 0.16, -0.3)
			legs = {"fl": [Vector3(0.09, 0.15, 0.2), Vector3(0.1, 0.07, 0.34), Vector3(0.1, 0.04, 0.46), Vector3(0.1, 0.03, 0.55)],
				"fr": [Vector3(-0.09, 0.15, 0.2), Vector3(-0.1, 0.07, 0.34), Vector3(-0.1, 0.04, 0.46), Vector3(-0.1, 0.03, 0.55)],
				"bl": [Vector3(0.14, 0.16, -0.28), Vector3(0.2, 0.08, -0.12), Vector3(0.2, 0.04, -0.3), Vector3(0.17, 0.03, -0.18)],
				"br": [Vector3(-0.14, 0.16, -0.28), Vector3(-0.2, 0.08, -0.12), Vector3(-0.2, 0.04, -0.3), Vector3(-0.17, 0.03, -0.18)]}
			head_dir = Vector3(0.0, 0.05, 1.0)
			head_down = 0.1
			tail_to = Vector3(0.2, 0.04, -0.6)
		"run":
			chest = Vector3(0, 0.46, 0.24); rump = Vector3(0, 0.44, -0.3)
			legs = {"fl": [Vector3(0.09, 0.44, 0.26), Vector3(0.1, 0.34, 0.5), Vector3(0.1, 0.2, 0.62), Vector3(0.1, 0.14, 0.7)],
				"fr": [Vector3(-0.09, 0.44, 0.26), Vector3(-0.1, 0.4, 0.46), Vector3(-0.1, 0.3, 0.58), Vector3(-0.1, 0.26, 0.68)],
				"bl": [Vector3(0.1, 0.44, -0.3), Vector3(0.11, 0.34, -0.12), Vector3(0.1, 0.2, -0.5), Vector3(0.1, 0.08, -0.62)],
				"br": [Vector3(-0.1, 0.44, -0.3), Vector3(-0.11, 0.38, -0.5), Vector3(-0.1, 0.22, -0.64), Vector3(-0.1, 0.14, -0.74)]}
			head_dir = Vector3(0, 0.12, 1.0)
			tail_to = Vector3(0, 0.45, -0.92)
	var coat := coat_col
	# ---- body: a deep chest tapering to the waist and a rounded rump, lofted from the rump to the chest
	var secs := [[0.0, 0.1, 0.12], [0.18, 0.125, 0.15], [0.5, 0.135, 0.17], [0.78, 0.115, 0.14], [1.0, 0.075, 0.1]]
	var z := (chest - rump).normalized()
	var L := rump.distance_to(chest)
	var ss: Array = []
	for sc in secs: ss.append([float(sc[0]) * L, 0.0, 0.0, float(sc[1]), float(sc[2])])
	var data := DroneParts.loft(ss, 2.3, seg + 2, true)
	var xv := Vector3.RIGHT
	xv = (xv - z * xv.dot(z)).normalized()
	var yv := z.cross(xv)
	var xf := Transform3D(Basis(xv, yv, z), rump)
	var f2 := func(p: Vector3, n: Vector3) -> Color:
		var wn: Vector3 = xf.basis * n
		var wp: Vector3 = xf * p
		if wn.y < -0.3 or (wp.z > rump.z + L * 0.62 and wn.y < 0.4 and absf(wp.x) < 0.08): return white
		return coat
	NewModels6.put_f(md, "fur", data, xf, f2)
	# ---- neck and head
	var neck_base := chest + z * 0.03 + Vector3(0, 0.06, 0)
	var hdir := head_dir.normalized()
	var head_c := neck_base + hdir * 0.2 + Vector3(0, -head_down, 0)
	NewModels6.limb(md, "fur", neck_base, head_c - hdir * 0.04, 0.078, 0.052, coat, seg, 0.05)
	NewModels6.ball(md, "fur", neck_base, Vector3(0.1, 0.1, 0.1), coat, 8)
	var hb := DroneParts.along(head_c, head_c + hdir).basis
	NewModels6.ball(md, "fur", head_c, Vector3(0.062, 0.068, 0.088), coat, 10, hb, 0.05)
	NewModels6.shell(md, "fur", head_c + hb * Vector3(0, -0.015, 0.08), head_c + hb * Vector3(0, -0.028, 0.2), [[0.0, 0.045, 0.045], [0.5, 0.035, 0.035], [1.0, 0.026, 0.024]], coat.lerp(white, 0.25), hb * Vector3.RIGHT, 2.2, 8)
	NewModels6.ball(md, "rubber", head_c + hb * Vector3(0, -0.025, 0.205), Vector3(0.022, 0.017, 0.02), Color(0.03, 0.03, 0.03), 6, hb)
	NewModels6.ball(md, "fur", head_c + hb * Vector3(0, 0.035, 0.08), Vector3(0.016, 0.04, 0.09), white, 6, hb * Basis(Vector3.RIGHT, 0.2))
	for sx: float in [-1.0, 1.0]:
		NewModels6.ball(md, "enamel", head_c + hb * Vector3(sx * 0.044, 0.03, 0.085), Vector3(0.011, 0.012, 0.01), Color(0.1, 0.05, 0.02), 5, hb)
		var ear_base := head_c + hb * Vector3(sx * 0.05, 0.065, -0.01)
		var tip := ear_base + hb * Vector3(sx * 0.07, 0.07, -0.02) if kind != "run" else ear_base + hb * Vector3(sx * 0.07, 0.01, -0.09)
		NewModels6.limb(md, "fur", ear_base, tip, 0.036, 0.012, DARK.lerp(coat, 0.3), 6)
	# ---- legs: thick forelegs with white socks, paws on the ground
	for nm in legs:
		var lp: Array = legs[nm]
		var hip: Vector3 = lp[0]; var knee: Vector3 = lp[1]; var ank: Vector3 = lp[2]; var paw: Vector3 = lp[3]
		var front: bool = (nm as String).begins_with("f")
		NewModels6.limb(md, "fur", hip, knee, 0.052 if front else 0.065, 0.036, coat, seg, 0.04)
		NewModels6.limb(md, "fur", knee, ank, 0.036, 0.026, coat.lerp(white, 0.5), seg, 0.04)
		NewModels6.limb(md, "fur", ank, paw + Vector3(0, 0.015, 0), 0.026, 0.026, white, seg, 0.03)
		NewModels6.ball(md, "fur", paw + Vector3(0, 0.015, 0.03 if kind != "run" else 0.0), Vector3(0.036, 0.03, 0.05), white, 7)
		NewModels6.ball(md, "fur", hip, Vector3(0.062, 0.075, 0.075) if front else Vector3(0.07, 0.085, 0.085), coat, 7)
	# ---- the tail: a feathered plume with a white tip
	var tpos := rump + Vector3(0, 0.0, -0.03)
	var mid := tpos.lerp(tail_to, 0.5) + Vector3(0, 0.05 if kind != "run" else 0.0, 0)
	NewModels6.limb(md, "fur", tpos, mid, 0.034, 0.045, coat * 0.9, 7, 0.05)
	NewModels6.limb(md, "fur", mid, tail_to, 0.045, 0.02, coat.lerp(white, 0.35), 7, 0.05)

static func _bowl(md: NewModels6.Model, full: bool) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.1, 0.005), Vector2(0.125, 0.045), Vector2(0.13, 0.055), Vector2(0.124, 0.056), Vector2(0.118, 0.05),
		Vector2(0.095, 0.015), Vector2(0.0, 0.012)])
	NewModels6.put(md, "chrome", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, Color(0.74, 0.75, 0.78), 0.0)
	if full:
		NewModels6.cyl(md, "glass", Vector3(0, 0.03, 0), Vector3(0, 0.0305, 0), 0.108, 0.108, 18, Color.WHITE, 3, 0.0)
