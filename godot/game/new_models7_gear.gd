class_name NewModels7Gear
extends RefCounted
## Story batch 9 (models9), part B3: the small endgame things. The thermal camera pod for the Gimbal Mini (pod, LED, mount), the police
## dive buoy and marker and Anne's photograph, the cruiser's accessories (plate, lightbar, aerial, door lettering, roadside kits),
## what belongs to Wren (pack, phone, torch, foil blanket, bottle, poles and gear, a tent), Constable Rennick's cap, case folder and
## portrait, an old thermos and a 1984 newspaper. The people and the vehicles themselves are made separately; these are the props
## that go with them. No colliders (the brief). Metres, +Z front, origin at the base. Fictional signage and insignia only.

const NAMES: Array[String] = [
	"thermal_pod_a", "thermal_pod_led_a", "thermal_pod_led_a_off", "thermal_pod_mount_a",
	"lake_buoy_a", "dive_marker_a", "anne_photo_a",
	"cruiser_plate_a", "cruiser_lightbar_a", "cruiser_aerial_a", "cruiser_door_lettering_a", "cruiser_boot_kit_a", "cruiser_old_kit_a",
	"wren_backpack_a", "wren_phone_a", "wren_torch_a", "wren_torch_a_off", "wren_space_blanket_a", "wren_space_blanket_a_b", "wren_water_bottle_a",
	"wren_hiking_gear_a", "wren_tent_a",
	"rennick_hat_a", "rennick_case_file_a", "rennick_portrait_a", "cabin_thermos_a", "cabin_newspaper_a",
]

const INK := Color(0.1, 0.08, 0.06)
const PAPER := Color(0.88, 0.84, 0.7)
const FOIL := Color(0.74, 0.76, 0.78)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"thermal_pod_a": _pod(md, lod)
		"thermal_pod_led_a": _led(md, true)
		"thermal_pod_led_a_off": _led(md, false)
		"thermal_pod_mount_a": _mount(md)
		"lake_buoy_a": _buoy(md, lod)
		"dive_marker_a": _marker(md)
		"anne_photo_a": _photo(md, "anne")
		"cruiser_plate_a": _plate(md)
		"cruiser_lightbar_a": _lightbar(md)
		"cruiser_aerial_a": _aerial(md)
		"cruiser_door_lettering_a": _lettering(md)
		"cruiser_boot_kit_a": _boot_kit(md)
		"cruiser_old_kit_a": _old_kit(md)
		"wren_backpack_a": _backpack(md, lod)
		"wren_phone_a": _phone(md)
		"wren_torch_a": _torch(md, true)
		"wren_torch_a_off": _torch(md, false)
		"wren_space_blanket_a": _blanket(md, false)
		"wren_space_blanket_a_b": _blanket(md, true)
		"wren_water_bottle_a": _bottle(md)
		"wren_hiking_gear_a": _hiking_gear(md)
		"wren_tent_a": _tent(md, lod)
		"rennick_hat_a": _hat(md)
		"rennick_case_file_a": _folder(md)
		"rennick_portrait_a": _photo(md, "rennick")
		"cabin_thermos_a": _thermos(md)
		"cabin_newspaper_a": _newspaper(md)
		_: return false
	return true

# ================================================================== the thermal pod
static func _pod(md: NewModels6.Model, lod: int) -> void:
	# a small thermal camera pod, 52 x 42 x 62 mm, black anodised aluminium: heat-sink fins across the top, a germanium lens in a knurled ring at the front,
	# a status LED (its own node) and a USB-C lead; the plate on top bolts under the gimbal camera, which is why the top is flat and the origin is the mounting face
	var black := Color(0.06, 0.065, 0.07)
	NewModels6.rbox(md, "sheet", Vector3(0, -0.021, 0.0), Vector3(0.052, 0.042, 0.062), Color(0.17, 0.18, 0.2), Basis.IDENTITY, 6.0, 12, 0.02)
	NewModels6.box(md, "sheet", Vector3(0, -0.0015, 0.0), Vector3(0.056, 0.003, 0.066), Color(0.45, 0.46, 0.48))
	for k in 7:
		NewModels6.box(md, "chrome", Vector3(0, -0.012 - k * 0.0, -0.026 + k * 0.0), Vector3(0.001, 0.0, 0.0), black)
	for k in 6:
		NewModels6.box(md, "sheet", Vector3(0.0, -0.032, -0.022 + k * 0.0085), Vector3(0.05, 0.007, 0.003), Color(0.22, 0.23, 0.25))
	NewModels6.cyl(md, "chrome", Vector3(0, -0.019, 0.031), Vector3(0, -0.019, 0.047), 0.0185, 0.0185, 24 if lod == 0 else 12, black * 1.2, 3, 0.0)
	if lod == 0:
		for k in 24:
			var a := TAU * k / 24.0
			NewModels6.limb(md, "chrome", Vector3(cos(a) * 0.0188, -0.019 + sin(a) * 0.0188, 0.036), Vector3(cos(a) * 0.0188, -0.019 + sin(a) * 0.0188, 0.045), 0.0006, 0.0006, black * 1.8, 3)
	NewModels6.cyl(md, "glass", Vector3(0, -0.019, 0.047), Vector3(0, -0.019, 0.0475), 0.0145, 0.0145, 24, Color.WHITE, 3, 0.0)
	NewModels6.ball(md, "enamel", Vector3(0, -0.019, 0.0475), Vector3(0.012, 0.012, 0.0008), Color(0.12, 0.08, 0.16), 14)
	NewModels6.cyl(md, "chrome", Vector3(0, -0.019, 0.0472), Vector3(0, -0.019, 0.0476), 0.0145, 0.0145, 24, Color(0.2, 0.15, 0.3), 1, 0.0)
	var led := md.sub("led", Vector3(0.016, -0.0075, 0.0315))
	NewModels6.ball(led, "lamp_blue", Vector3(0.016, -0.0075, 0.0315), Vector3(0.0022, 0.0022, 0.0012), Color.WHITE, 8)
	NewModels6.box(md, "paper", Vector3(-0.016, -0.0075, 0.0316), Vector3(0.013, 0.0035, 0.0002), Color(0.7, 0.7, 0.7))
	var prev := Vector3(-0.012, -0.03, -0.031)
	for k in range(1, 15):
		var t := float(k) / 14.0
		var p := Vector3(-0.012 - 0.03 * t, -0.03 - 0.02 * sin(t * PI), -0.031 - 0.06 * t)
		NewModels6.limb(md, "rubber", prev, p, 0.0018, 0.0018, Color(0.05, 0.05, 0.06), 4)
		prev = p
	NewModels6.cyl(md, "chrome", prev, prev + Vector3(0.0, 0.0, -0.014), 0.004, 0.004, 8, Color(0.5, 0.5, 0.52), 3, 0.0)
	NewModels6.box(md, "paper", Vector3(0.0, -0.008, -0.0305), Vector3(0.03, 0.01, 0.0003), Color(0.2, 0.2, 0.2))

static func _led(md: NewModels6.Model, on: bool) -> void:
	# the status LED on its own, a 3 mm dome in a bezel: blue-white when on, dark glass when off
	NewModels6.cyl(md, "chrome", Vector3(0, 0, 0), Vector3(0, 0, 0.0015), 0.0034, 0.0034, 12, Color(0.06, 0.065, 0.07), 3, 0.0)
	NewModels6.ball(md, "lamp_blue" if on else "lamp_off", Vector3(0, 0, 0.0016), Vector3(0.0022, 0.0022, 0.0014), Color.WHITE if on else Color(0.1, 0.1, 0.12), 10)

static func _mount(md: NewModels6.Model) -> void:
	# the bracket that holds the pod under the Gimbal Mini's camera: a bent aluminium plate with two screws and a cable clip, plus a loop of lead
	var al := Color(0.58, 0.6, 0.62)
	NewModels6.box(md, "chrome", Vector3(0, 0.0015, 0.0), Vector3(0.05, 0.003, 0.06), al)
	NewModels6.box(md, "chrome", Vector3(0, -0.011, -0.0285), Vector3(0.05, 0.022, 0.003), al * 0.95)
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(md, "steel", Vector3(sx * 0.018, 0.003, 0.016), Vector3(sx * 0.018, 0.006, 0.016), 0.003, 0.003, 8, Color(0.5, 0.5, 0.52), 3, 0.0)
		NewModels6.limb(md, "steel", Vector3(sx * 0.0185, 0.0048, 0.016), Vector3(sx * 0.0175, 0.0048, 0.016), 0.001, 0.001, Color(0.1, 0.1, 0.1), 3)
	NewModels6.box(md, "rubber", Vector3(0.0, 0.0045, -0.02), Vector3(0.012, 0.003, 0.01), Color(0.08, 0.08, 0.08))
	var prev := Vector3(0.0, 0.005, -0.02)
	for k in range(1, 13):
		var a := TAU * k / 12.0
		var p := Vector3(0.015 * sin(a), 0.005 + 0.012 * (1.0 - cos(a)) * 0.5, -0.02 - 0.015 * (1.0 - cos(a)))
		NewModels6.limb(md, "rubber", prev, p, 0.0017, 0.0017, Color(0.05, 0.05, 0.06), 4)
		prev = p

# ================================================================== the lake
static func _buoy(md: NewModels6.Model, lod: int) -> void:
	# a police dive buoy: a 0.4 m white sphere with a blue band, a stainless eye on top and a cut of anchor line; the waterline is y = 0 (floating)
	var seg := 20 if lod == 0 else 10
	NewModels6.ball(md, "enamel", Vector3(0, 0.06, 0), Vector3(0.2, 0.2, 0.2), Color(0.88, 0.88, 0.86), seg, Basis.IDENTITY, 0.02)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.04, 0), Vector3(0, 0.1, 0), 0.2, 0.2, seg, Color(0.1, 0.25, 0.6), 1, 0.01)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.26, 0), Vector3(0, 0.32, 0), 0.03, 0.025, 10, Color(0.65, 0.66, 0.68), 3, 0.0)
	NewModels6.limb(md, "chrome", Vector3(0, 0.32, 0), Vector3(0.0, 0.38, 0.02), 0.008, 0.008, Color(0.65, 0.66, 0.68), 6)
	NewModels6.text(md, "paint", "DIVE", Vector3(0, 0.01, 0.2), Vector3(0, 0, 1), 0.07, Color(0.88, 0.88, 0.86), Vector3.UP, 0.0)
	NewModels6.limb(md, "cloth", Vector3(0, 0.38, 0.02), Vector3(0.1, 0.1, 0.25), 0.011, 0.011, Color(0.85, 0.85, 0.8), 5)
	

static func _marker(md: NewModels6.Model) -> void:
	# a dive marker: an orange float with a small blue-white flag, a weighted line (shown 2 m) and a lead weight; the waterline is y = 0
	NewModels6.cyl(md, "enamel", Vector3(0, -0.02, 0), Vector3(0, 0.08, 0), 0.07, 0.06, 14, Color(0.95, 0.4, 0.06), 3, 0.02)
	NewModels6.limb(md, "wood", Vector3(0, 0.08, 0), Vector3(0, 0.5, 0), 0.007, 0.006, NewModels7.W(Color(0.6, 0.5, 0.3), 1.0), 5)
	NewModels6.sheet(md, "cloth", [Vector3(0, 0.5, 0), Vector3(0.0, 0.5, 0.22), Vector3(0.0, 0.34, 0.22), Vector3(0.0, 0.34, 0)], Color(0.9, 0.9, 0.92), Vector3.RIGHT)
	NewModels6.box(md, "cloth", Vector3(0.002, 0.42, 0.11), Vector3(0.002, 0.16, 0.08), Color(0.12, 0.28, 0.7))
	var prev := Vector3(0, -0.02, 0)
	for k in range(1, 11):
		var p := Vector3(0.01 * sin(k), -0.02 - k * 0.2, 0.012 * cos(k))
		NewModels6.limb(md, "cloth", prev, p, 0.004, 0.004, Color(0.7, 0.68, 0.55), 4)
		prev = p
	NewModels6.cyl(md, "rust", prev, prev + Vector3(0, -0.12, 0), 0.04, 0.05, 10, Color(0.35, 0.36, 0.4), 3, 0.03)
	

static func _photo(md: NewModels6.Model, who: String) -> void:
	# a small 1980s black-and-white portrait, 0.09 x 0.12 m, white border, a generic head and shoulders (nobody real), a pencilled date on the back edge
	NewModels6.box(md, "paper", Vector3(0, 0.0008, 0), Vector3(0.09, 0.0016, 0.12), Color(0.9, 0.89, 0.85))
	NewModels6.box(md, "paper", Vector3(0, 0.0019, 0.003), Vector3(0.074, 0.0006, 0.1), Color(0.44, 0.45, 0.46))
	NewModels6.ball(md, "paper", Vector3(0, 0.0024, 0.018), Vector3(0.017, 0.0008, 0.021), Color(0.72, 0.72, 0.72), 12)
	NewModels6.ball(md, "paper", Vector3(0, 0.0024, -0.03), Vector3(0.032, 0.0008, 0.02), Color(0.22, 0.24, 0.3), 12)
	if who == "rennick":
		NewModels6.box(md, "paper", Vector3(0, 0.0026, 0.038), Vector3(0.036, 0.0008, 0.011), Color(0.12, 0.13, 0.18))
		NewModels6.box(md, "paper", Vector3(0, 0.0026, 0.048), Vector3(0.05, 0.0008, 0.004), Color(0.08, 0.09, 0.12))
	else:
		NewModels6.ball(md, "paper", Vector3(0, 0.0026, 0.026), Vector3(0.022, 0.0008, 0.014), Color(0.28, 0.2, 0.15), 10)
	NewModels6.text(md, "paper", "1984", Vector3(0.0, 0.0017, -0.056), Vector3.UP, 0.005, Color(0.3, 0.3, 0.34), Vector3(0, 0, -1), 0.0)

# ================================================================== the cruiser's things
static func _plate(md: NewModels6.Model) -> void:
	# a fictional provincial number plate, 0.3 x 0.15 m, embossed letters, bolted on; and a round 1984 tax disc beside it
	NewModels6.rbox(md, "sheet", Vector3(0, 0.075, 0.0), Vector3(0.3, 0.15, 0.004), Color(0.86, 0.84, 0.74), Basis.IDENTITY, 3.0, 6, 0.02)
	NewModels6.box(md, "paint", Vector3(0, 0.075, 0.0025), Vector3(0.285, 0.135, 0.0006), Color(0.1, 0.18, 0.4))
	NewModels6.box(md, "paint", Vector3(0, 0.075, 0.0032), Vector3(0.275, 0.125, 0.0006), Color(0.86, 0.84, 0.74))
	NewModels6.text(md, "paint", "HALLOWAY", Vector3(0, 0.125, 0.004), Vector3(0, 0, 1), 0.02, Color(0.1, 0.18, 0.4), Vector3.UP, 0.0)
	NewModels6.text(md, "paint", "PX 4417", Vector3(0, 0.05, 0.004), Vector3(0, 0, 1), 0.062, Color(0.1, 0.18, 0.4), Vector3.UP, 0.0)
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(md, "steel", Vector3(sx * 0.13, 0.075, 0.003), Vector3(sx * 0.13, 0.075, 0.007), 0.006, 0.005, 6, Color(0.5, 0.5, 0.52), 3, 0.0)
	NewModels6.cyl(md, "paper", Vector3(0.0, 0.19, 0.0), Vector3(0.0, 0.19, 0.0015), 0.03, 0.03, 16, Color(0.78, 0.2, 0.15), 3, 0.0)
	NewModels6.text(md, "paper", "1984", Vector3(0.0, 0.184, 0.0018), Vector3(0, 0, 1), 0.016, Color(0.96, 0.96, 0.94), Vector3.UP, 0.0)

static func _lightbar(md: NewModels6.Model) -> void:
	# a low 1980s lightbar, 1.2 m long: a black rail with two end caps, a red dome and a blue dome (each its own node), a centre speaker
	NewModels6.rbox(md, "rubber", Vector3(0, 0.03, 0), Vector3(1.2, 0.06, 0.28), Color(0.07, 0.07, 0.08), Basis.IDENTITY, 4.0, 10, 0.02)
	NewModels6.rbox(md, "rubber", Vector3(0, 0.07, 0), Vector3(0.24, 0.05, 0.22), Color(0.12, 0.12, 0.13), Basis.IDENTITY, 4.0, 8, 0.02)
	for k in 5:
		NewModels6.box(md, "rust", Vector3(-0.08 + k * 0.04, 0.0975, 0.0), Vector3(0.006, 0.002, 0.16), Color(0.03, 0.03, 0.03))
	var rd := md.sub("lightbar_red", Vector3(-0.35, 0.06, 0.0))
	var bl := md.sub("lightbar_blue", Vector3(0.35, 0.06, 0.0))
	var dome := PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.07, 0.095), Vector2(0.11, 0.07), Vector2(0.12, 0.03), Vector2(0.125, 0.0), Vector2(0.0, 0.0)])
	for pr in [[rd, -1.0, Color(0.35, 0.05, 0.05)], [bl, 1.0, Color(0.05, 0.1, 0.35)]]:
		var tgt: NewModels6.Model = pr[0]
		var sx: float = pr[1]
		var c: Vector3 = Vector3(sx * 0.35, 0.06, 0.0)
		NewModels6.put(tgt, "enamel", DroneParts.lathe(dome, 18), Transform3D(Basis.IDENTITY, c), pr[2], 0.0)
		NewModels6.box(tgt, "chrome", c + Vector3(0, 0.03, 0), Vector3(0.14, 0.05, 0.02), Color(0.6, 0.6, 0.62))
	NewModels6.rbox(md, "rubber", Vector3(0, 0.03, 0.0), Vector3(0.22, 0.07, 0.2), Color(0.07, 0.07, 0.08), Basis.IDENTITY, 4.0, 6, 0.02)
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(md, "steel", Vector3(sx * 0.5, 0.0, 0.0), Vector3(sx * 0.5, -0.04, 0.0), 0.02, 0.02, 8, Color(0.5, 0.5, 0.52), 3, 0.0)

static func _aerial(md: NewModels6.Model) -> void:
	# a 1.5 m whip aerial on a spring base, slightly bent after forty years
	NewModels6.cyl(md, "rust", Vector3(0, 0, 0), Vector3(0, 0.04, 0), 0.025, 0.02, 12, Color(0.1, 0.1, 0.1), 3, 0.0)
	for k in 8:
		NewModels6.limb(md, "steel", Vector3(0, 0.04 + k * 0.0125, 0), Vector3(0, 0.0525 + k * 0.0125, 0), 0.0075, 0.0075, Color(0.6, 0.6, 0.62), 6)
	var prev := Vector3(0, 0.14, 0)
	for k in range(1, 13):
		var t := float(k) / 12.0
		var p := Vector3(0.08 * t * t, 0.14 + 1.36 * t - 0.04 * t * t, 0.02 * t * t)
		NewModels6.limb(md, "steel", prev, p, 0.0035 * (1.0 - 0.6 * t), 0.0035 * (1.0 - 0.6 * (t + 1.0 / 12.0)), Color(0.55, 0.57, 0.6), 4)
		prev = p
	NewModels6.ball(md, "chrome", prev, Vector3(0.006, 0.006, 0.006), Color(0.6, 0.6, 0.62), 6)

static func _lettering(md: NewModels6.Model) -> void:
	# the door lettering as raised, faded letters (no backing, to stick on a door panel): HALLOWAY over PROVINCIAL POLICE, and a round crest with a blue bar (fictional)
	var faded := Color(0.7, 0.2, 0.18)
	NewModels6.text(md, "paint", "HALLOWAY", Vector3(0.0, 0.34, 0.0), Vector3(0, 0, 1), 0.1, Color(0.14, 0.2, 0.42), Vector3.UP, 0.0)
	NewModels6.text(md, "paint", "PROVINCIAL POLICE", Vector3(0.0, 0.19, 0.0), Vector3(0, 0, 1), 0.06, Color(0.14, 0.2, 0.42), Vector3.UP, 0.0)
	NewModels6.cyl(md, "paint", Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.5, 0.0008), 0.08, 0.08, 24, faded, 3, 0.03)
	NewModels6.cyl(md, "paint", Vector3(0.0, 0.5, 0.0008), Vector3(0.0, 0.5, 0.0016), 0.065, 0.065, 24, Color(0.9, 0.88, 0.8), 3, 0.02)
	NewModels6.box(md, "paint", Vector3(0.0, 0.5, 0.0024), Vector3(0.1, 0.02, 0.0008), Color(0.14, 0.2, 0.42))
	NewModels6.box(md, "paint", Vector3(0.0, 0.5, 0.0024), Vector3(0.02, 0.1, 0.0008), Color(0.14, 0.2, 0.42))

static func _boot_kit(md: NewModels6.Model) -> void:
	# the roadside kit that lived in the boot: a scissor jack, a folded red warning triangle, a grey wool blanket and a tin first-aid box with a white cross
	NewModels6.box(md, "rust", Vector3(0.0, 0.025, 0.0), Vector3(0.28, 0.012, 0.1), Color(0.3, 0.2, 0.15))
	NewModels6.limb(md, "rust", Vector3(-0.12, 0.03, 0.0), Vector3(0.0, 0.1, 0.0), 0.012, 0.012, Color(0.3, 0.2, 0.15), 6)
	NewModels6.limb(md, "rust", Vector3(0.12, 0.03, 0.0), Vector3(0.0, 0.1, 0.0), 0.012, 0.012, Color(0.3, 0.2, 0.15), 6)
	NewModels6.cyl(md, "rust", Vector3(0.0, 0.1, 0.0), Vector3(0.0, 0.13, 0.0), 0.03, 0.025, 10, Color(0.3, 0.2, 0.15), 3, 0.03)
	NewModels6.limb(md, "rust", Vector3(-0.12, 0.03, 0.0), Vector3(0.12, 0.03, 0.0), 0.006, 0.006, Color(0.35, 0.3, 0.28), 5)
	NewModels6.box(md, "rubber", Vector3(0.45, 0.012, 0.0), Vector3(0.45, 0.024, 0.07), Color(0.75, 0.15, 0.1))
	NewModels6.box(md, "rubber", Vector3(0.45, 0.026, 0.0), Vector3(0.38, 0.004, 0.04), Color(0.9, 0.9, 0.9))
	NewModels6.rbox(md, "cloth", Vector3(-0.1, 0.055, 0.28), Vector3(0.5, 0.11, 0.34), Color(0.42, 0.42, 0.4), Basis(Vector3.UP, 0.1), 3.2, 12, 0.04)
	for k in 3:
		NewModels6.box(md, "cloth", Vector3(-0.1, 0.112, 0.2 + k * 0.08), Vector3(0.5, 0.003, 0.012), Color(0.55, 0.14, 0.12), 0.1)
	NewModels6.rbox(md, "sheet", Vector3(0.4, 0.075, 0.3), Vector3(0.22, 0.15, 0.1), Color(0.62, 0.15, 0.12), Basis(Vector3.UP, -0.3), 4.0, 8, 0.03)
	NewModels6.box(md, "paint", Vector3(0.4, 0.152, 0.3), Vector3(0.012, 0.0, 0.06), Color(0.95, 0.95, 0.95))
	NewModels6.box(md, "paint", Vector3(0.4, 0.153, 0.3), Vector3(0.06, 0.001, 0.012), Color(0.95, 0.95, 0.95))

static func _old_kit(md: NewModels6.Model) -> void:
	# a smaller roadside kit from the glovebox: a torch, a tin of plasters, a folded road map and a wool glove
	NewModels6.cyl(md, "rubber", Vector3(0.0, 0.03, 0.0), Vector3(0.2, 0.03, 0.0), 0.025, 0.03, 12, Color(0.15, 0.15, 0.17), 3, 0.03)
	NewModels6.cyl(md, "chrome", Vector3(0.2, 0.03, 0.0), Vector3(0.22, 0.03, 0.0), 0.04, 0.04, 14, Color(0.6, 0.6, 0.62), 3, 0.0)
	NewModels6.rbox(md, "sheet", Vector3(0.0, 0.01, 0.2), Vector3(0.11, 0.02, 0.07), Color(0.7, 0.62, 0.2), Basis.IDENTITY, 4.0, 6, 0.03)
	NewModels6.box(md, "paper", Vector3(0.35, 0.01, 0.15), Vector3(0.24, 0.02, 0.17), Color(0.55, 0.6, 0.48), 0.2)
	NewModels6.text(md, "paper", "ROAD MAP", Vector3(0.35, 0.021, 0.15), Vector3.UP, 0.02, INK, Vector3(0, 0, -1), 0.0)
	NewModels6.ball(md, "cloth", Vector3(-0.15, 0.02, 0.15), Vector3(0.06, 0.02, 0.08), Color(0.3, 0.3, 0.34), 8, Basis(Vector3.UP, 0.5))

# ================================================================== Wren's things
static func _backpack(md: NewModels6.Model, lod: int) -> void:
	# a 40 litre hiking pack, 0.62 m tall: teal body, a lid, a side pocket, compression straps, shoulder straps and a hip belt, a yellow rain cover half pulled over, wet and dark at the base
	var teal := Color(0.13, 0.26, 0.26)
	var secs := [[0.0, 0.16, 0.11], [0.2, 0.18, 0.13], [0.6, 0.19, 0.14], [1.0, 0.16, 0.12]]
	NewModels6.shell(md, "cloth", Vector3(0, 0.05, 0.0), Vector3(0, 0.6, 0.0), secs, teal, Vector3.RIGHT, 2.6, 24 if lod == 0 else 10, 0.015)
	NewModels6.rbox(md, "cloth", Vector3(0, 0.62, -0.01), Vector3(0.34, 0.08, 0.27), teal * 1.1, Basis.IDENTITY, 4.0, 8, 0.04)
	NewModels6.rbox(md, "cloth", Vector3(0.21, 0.22, 0.0), Vector3(0.09, 0.24, 0.17), teal * 0.9, Basis.IDENTITY, 4.0, 8, 0.04)
	for y in [0.2, 0.38, 0.52]:
		NewModels6.box(md, "cloth", Vector3(0, y, 0.145), Vector3(0.3, 0.025, 0.006), Color(0.12, 0.12, 0.13))
		NewModels6.box(md, "chrome", Vector3(0.08, y, 0.149), Vector3(0.025, 0.03, 0.006), Color(0.1, 0.1, 0.1))
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "cloth", Vector3(sx * 0.1, 0.56, -0.12), Vector3(sx * 0.12, 0.1, -0.14), 0.026, 0.024, Color(0.1, 0.1, 0.11), 6)
		NewModels6.limb(md, "cloth", Vector3(sx * 0.18, 0.1, -0.1), Vector3(sx * 0.3, 0.12, 0.05), 0.02, 0.02, Color(0.1, 0.1, 0.11), 5)
	NewModels6.box(md, "cloth", Vector3(0, 0.12, -0.14), Vector3(0.3, 0.16, 0.03), Color(0.14, 0.14, 0.15))
	var cover := NewModels6.Model.new()
	var secs2 := [[0.0, 0.17, 0.12], [0.5, 0.18, 0.14], [1.0, 0.16, 0.12]]
	NewModels6.shell(md, "tarp", Vector3(0, 0.34, 0.0), Vector3(0, 0.62, 0.0), secs2, Color(0.7, 0.6, 0.14), Vector3.RIGHT, 2.6, 24 if lod == 0 else 10, 0.015)
	NewModels6.ball(md, "tarp", Vector3(0.0, 0.12, 0.0), Vector3(0.17, 0.13, 0.13), Color(0.05, 0.1, 0.12), 8, Basis.IDENTITY, 0.04)

static func _phone(md: NewModels6.Model) -> void:
	# a smartphone, 0.07 x 0.15 x 0.008 m, screen glowing, one corner scuffed: lies face up
	NewModels6.rbox(md, "enamel", Vector3(0, 0.004, 0), Vector3(0.07, 0.008, 0.15), Color(0.06, 0.06, 0.07), Basis.IDENTITY, 5.0, 8, 0.01)
	NewModels6.box(md, "lamp", Vector3(0, 0.0083, 0.0), Vector3(0.063, 0.0004, 0.138), Color(0.85, 0.92, 1.0))
	NewModels6.box(md, "paper", Vector3(0, 0.0087, 0.045), Vector3(0.05, 0.0003, 0.012), Color(0.4, 0.5, 0.65))
	NewModels6.box(md, "paper", Vector3(0, 0.0087, 0.01), Vector3(0.05, 0.0003, 0.025), Color(0.45, 0.55, 0.7))
	NewModels6.ball(md, "enamel", Vector3(0.0, 0.0084, 0.073), Vector3(0.004, 0.0004, 0.002), Color(0.02, 0.02, 0.02), 4)
	NewModels6.box(md, "paper", Vector3(0.03, 0.0088, -0.068), Vector3(0.012, 0.0002, 0.008), Color(0.7, 0.7, 0.72))

static func _torch(md: NewModels6.Model, on: bool) -> void:
	# a 0.17 m LED torch, yellow and black rubber body, a ribbed head, a lanyard; on it has a glowing lens, a cone of beam is the `beam` node
	var yel := Color(0.9, 0.7, 0.05)
	NewModels6.cyl(md, "rubber", Vector3(0, 0.025, 0.0), Vector3(0, 0.025, 0.1), 0.021, 0.022, 14, yel, 3, 0.03)
	NewModels6.cyl(md, "rubber", Vector3(0, 0.025, 0.1), Vector3(0, 0.025, 0.17), 0.022, 0.032, 16, Color(0.08, 0.08, 0.08), 3, 0.02)
	for k in 6:
		NewModels6.cyl(md, "rubber", Vector3(0, 0.025, 0.005 + k * 0.012), Vector3(0, 0.025, 0.009 + k * 0.012), 0.0225, 0.0225, 14, Color(0.1, 0.1, 0.1), 3, 0.0)
	NewModels6.cyl(md, "rubber", Vector3(0.0, 0.047, 0.05), Vector3(0.0, 0.053, 0.05), 0.008, 0.008, 8, Color(0.08, 0.08, 0.08), 3, 0.0)
	NewModels6.cyl(md, "lamp" if on else "glass", Vector3(0, 0.025, 0.169), Vector3(0, 0.025, 0.172), 0.027, 0.027, 16, Color.WHITE, 3, 0.0)
	var prev := Vector3(0.0, 0.03, 0.0)
	for k in range(1, 9):
		var p := Vector3(0.02 * sin(k), 0.0 + 0.01 * k * 0.0, -0.01 * k)
		NewModels6.limb(md, "cloth", prev, p, 0.0025, 0.0025, Color(0.7, 0.2, 0.15), 3)
		prev = p
	if on:
		var bm := md.sub("beam", Vector3(0, 0.025, 0.172))
		NewModels6.put(bm, "steam", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.25, 1.4), Vector2(0.0, 1.4)]), 14), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.025, 0.172)), Color(1, 1, 0.9), 0.0)

static func _blanket(md: NewModels6.Model, spread: bool) -> void:
	# a silver emergency foil blanket, 1.6 x 2.1 m: folded into a crinkled pad (a) or half spread out in sharp creases (b)
	if not spread:
		for k in 4:
			NewModels6.rbox(md, "chrome", Vector3(0, 0.02 + k * 0.032, 0.0), Vector3(0.24 - k * 0.01, 0.035, 0.17), FOIL * (0.9 + 0.06 * k), Basis(Vector3.UP, 0.05 * k), 3.0, 8, 0.12)
		return
	var f := func(x: float, z: float) -> float:
		return 0.04 + 0.05 * sin(x * 7.0 + z * 3.0) * sin(z * 5.0 + 1.0) + 0.03 * absf(sin(x * 11.0 - z * 4.0)) + 0.12 * exp(-(x * x / 0.3 + z * z / 0.4))
	NewModels7.sheet_grid(md, "chrome", 1.6, 1.0, 40, 24, FOIL, f, Transform3D.IDENTITY, 0.12)

static func _bottle(md: NewModels6.Model) -> void:
	# a 0.5 litre PET water bottle, half empty, blue cap, a label band; the water inside is its own surface
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.008), Vector2(0.034, 0.1), Vector2(0.036, 0.12), Vector2(0.034, 0.14), Vector2(0.034, 0.17), Vector2(0.026, 0.19), Vector2(0.012, 0.2), Vector2(0.011, 0.215)])
	NewModels6.put(md, "glass", DroneParts.lathe(prof, 20), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.034, 0.0)), Color.WHITE, 0.0)
	NewModels6.put(md, "water", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.006), Vector2(0.027, 0.006), Vector2(0.03, 0.01), Vector2(0.03, 0.095), Vector2(0.0, 0.095)]), 16), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.034, 0.0)), Color.WHITE, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0.213, 0.034, 0.0), Vector3(0.232, 0.034, 0.0), 0.014, 0.014, 12, Color(0.1, 0.3, 0.7), 3, 0.0)
	NewModels6.cyl(md, "paper", Vector3(0.05, 0.034, 0.0), Vector3(0.1, 0.034, 0.0), 0.0345, 0.0345, 20, Color(0.8, 0.85, 0.9), 3, 0.0)

static func _hiking_gear(md: NewModels6.Model) -> void:
	# a pair of folding trekking poles with cork grips and wrist straps leant together, a pair of wet gaiters and a headlamp on its strap
	for k in 2:
		var o := Vector3(-0.1 + k * 0.1, 0.0, 0.0)
		NewModels6.limb(md, "chrome", o, o + Vector3(0.08 - k * 0.1, 1.2, 0.0), 0.009, 0.007, Color(0.15, 0.17, 0.2), 6)
		NewModels6.limb(md, "leather", o + Vector3(0.08 - k * 0.1, 1.2, 0.0), o + Vector3(0.09 - k * 0.1, 1.38, 0.0), 0.017, 0.016, Color(0.62, 0.5, 0.32), 8, 0.05)
		NewModels6.cyl(md, "rubber", o, o + Vector3(0, 0.07, 0), 0.016, 0.01, 10, Color(0.3, 0.3, 0.32), 3, 0.0)
		NewModels6.limb(md, "cloth", o + Vector3(0.09 - k * 0.1, 1.3, 0.0), o + Vector3(0.04 - k * 0.1, 1.12, 0.03), 0.004, 0.004, Color(0.7, 0.2, 0.15), 3)
	for k in 2:
		NewModels6.limb(md, "cloth", Vector3(0.5 + k * 0.15, 0.04, 0.3), Vector3(0.5 + k * 0.15, 0.04, 0.0), 0.05, 0.06, Color(0.25, 0.3, 0.2), 10, 0.05)
		NewModels6.ball(md, "cloth", Vector3(0.5 + k * 0.15, 0.04, 0.3), Vector3(0.05, 0.03, 0.02), Color(0.12, 0.14, 0.1), 6)
	NewModels6.rbox(md, "rubber", Vector3(-0.45, 0.025, 0.35), Vector3(0.07, 0.04, 0.045), Color(0.1, 0.1, 0.11), Basis.IDENTITY, 4.0, 6, 0.02)
	NewModels6.cyl(md, "lamp_off", Vector3(-0.45, 0.025, 0.375), Vector3(-0.45, 0.025, 0.38), 0.015, 0.015, 12, Color(0.8, 0.8, 0.8), 3, 0.0)
	var prev := Vector3(-0.485, 0.03, 0.35)
	for k in range(1, 17):
		var a := PI * float(k) / 16.0
		var p := Vector3(-0.45 - cos(a) * 0.085, 0.01, 0.35 - sin(a) * 0.08)
		NewModels6.limb(md, "cloth", prev, p, 0.008, 0.008, Color(0.1, 0.1, 0.12), 4)
		prev = p

static func _tent(md: NewModels6.Model, lod: int) -> void:
	# a two-person dome tent, 2.1 x 1.4 m on the ground and 1.05 m high: a grey-green flysheet over two crossing arched poles, a porch with a half-open door, guy lines and pegs
	var nu := 14 if lod == 0 else 7
	var nv := 12 if lod == 0 else 6
	var rows: Array = []
	for j in nv + 1:
		var t := float(j) / nv
		var r := PackedVector3Array(); r.resize(nu + 1)
		for i in nu + 1:
			var u := float(i) / nu
			var a := PI * u
			var h := sin(t * PI * 0.5)
			var x := cos(a) * 0.7 * (1.0 - 0.0 * t)
			var z := (t * 2.0 - 1.0) * 1.05 * (1.0 - 0.0)
			var rad := sqrt(maxf(0.0, 1.0 - z * z / (1.05 * 1.05)))
			r[i] = Vector3(cos(a) * 0.7 * rad, sin(a) * 1.05 * rad * (0.9 + 0.1 * sin(u * 9.0 + t * 5.0) * 0.1), z)
		rows.append(r)
	NewModels6.gridsurf(md, "canvas", rows, Color(0.28, 0.34, 0.27), func(_i: int, _j: int, p: Vector3) -> Vector3: return Vector3(p.x, p.y, p.z * 0.5), 0.03)
	var pole := Color(0.2, 0.22, 0.2)
	for pc in [0, 1]:
		var pr := Vector3(0.7, 0.0, 0.0) if pc == 0 else Vector3(0.0, 0.0, 1.05)
		for k in range(1, 17):
			var a := PI * float(k) / 16.0
			var a0 := PI * float(k - 1) / 16.0
			var p0 := Vector3(cos(a0) * 0.7, sin(a0) * 1.05, 0.0) if pc == 0 else Vector3(0.0, sin(a0) * 1.05, cos(a0) * 1.05)
			var p1 := Vector3(cos(a) * 0.7, sin(a) * 1.05, 0.0) if pc == 0 else Vector3(0.0, sin(a) * 1.05, cos(a) * 1.05)
			NewModels6.limb(md, "chrome", p0 * 1.002, p1 * 1.002, 0.006, 0.006, pole, 4)
	NewModels6.quad2(md, "canvas", Vector3(-0.28, 0.0, 1.0), Vector3(0.28, 0.0, 1.0), Vector3(0.22, 0.62, 0.9), Vector3(-0.22, 0.62, 0.9), Color(0.1, 0.12, 0.1))
	NewModels6.sheet(md, "canvas", [Vector3(-0.28, 0.0, 1.0), Vector3(-0.02, 0.0, 1.02), Vector3(-0.02, 0.62, 0.92), Vector3(-0.22, 0.62, 0.9)], Color(0.28, 0.34, 0.27), Vector3(0, 0, 1))
	for k in 6:
		var a1 := TAU * k / 6.0 + 0.3
		var g0 := Vector3(cos(a1) * 0.55, 0.65, sin(a1) * 0.85)
		var g1 := Vector3(cos(a1) * 1.5, 0.0, sin(a1) * 1.7)
		NewModels7.rope(md, "cloth", g0, g1, 0.0, 0.0035, Color(0.85, 0.5, 0.1), 3)
		NewModels6.limb(md, "chrome", g1 + Vector3(0, 0.12, 0), g1 + Vector3(0.0, -0.02, 0.0), 0.004, 0.003, Color(0.7, 0.35, 0.1), 4)

# ================================================================== Rennick's things
static func _hat(md: NewModels6.Model) -> void:
	# a 1980s peaked uniform cap, 0.3 m across: a dark blue crown, a black band and patent peak and a brass badge with a plain crest and no lettering that matches any real force
	var blue := Color(0.08, 0.1, 0.19)
	NewModels6.cyl(md, "cloth", Vector3(0, 0.02, 0), Vector3(0, 0.095, 0), 0.1, 0.108, 22, blue * 0.95, 3, 0.04)
	NewModels6.ball(md, "cloth", Vector3(0, 0.095, 0.0), Vector3(0.118, 0.034, 0.118), blue, 18, Basis(Vector3.RIGHT, -0.06), 0.04)
	NewModels6.cyl(md, "cloth", Vector3(0, 0.02, 0), Vector3(0, 0.04, 0), 0.1, 0.1, 22, Color(0.03, 0.03, 0.04), 3, 0.0)
	NewModels6.box(md, "leather", Vector3(0, 0.025, 0.115), Vector3(0.18, 0.007, 0.09), Color(0.03, 0.03, 0.04), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.2))
	NewModels6.cyl(md, "chrome", Vector3(0, 0.07, 0.106), Vector3(0, 0.07, 0.111), 0.022, 0.022, 14, Color(0.72, 0.58, 0.26), 3, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.07, 0.111), Vector3(0, 0.07, 0.113), 0.014, 0.014, 14, Color(0.1, 0.18, 0.4), 3, 0.0)
	NewModels6.limb(md, "cloth", Vector3(-0.1, 0.03, 0.04), Vector3(0.1, 0.03, 0.04), 0.002, 0.002, Color(0.7, 0.58, 0.25), 3)

static func _folder(md: NewModels6.Model) -> void:
	# a closed manila case folder, 0.24 x 0.31 m, with a photograph clipped to the front, a typed tab label and a rubber band
	var manila := Color(0.7, 0.58, 0.36)
	NewModels6.box(md, "paper", Vector3(0, 0.004, 0), Vector3(0.24, 0.008, 0.31), manila)
	NewModels6.box(md, "paper", Vector3(-0.07, 0.008, 0.17), Vector3(0.09, 0.008, 0.02), manila * 0.95)
	NewModels6.text(md, "paper", "RENNICK A.", Vector3(-0.07, 0.0125, 0.162), Vector3.UP, 0.009, INK, Vector3(0, 0, -1), 0.0)
	NewModels6.text(md, "paper", "CASE 84 / 117", Vector3(0.0, 0.0085, -0.1), Vector3.UP, 0.014, Color(0.5, 0.1, 0.1), Vector3(0, 0, -1), 0.0)
	NewModels6.box(md, "paper", Vector3(0.0, 0.0105, 0.04), Vector3(0.08, 0.002, 0.1), Color(0.9, 0.89, 0.85), 0.1)
	NewModels6.box(md, "paper", Vector3(0.0, 0.0118, 0.04), Vector3(0.066, 0.0008, 0.084), Color(0.4, 0.41, 0.42), 0.1)
	NewModels6.limb(md, "steel", Vector3(0.0, 0.0125, 0.082), Vector3(0.0, 0.0125, 0.052), 0.0012, 0.0012, Color(0.6, 0.6, 0.62), 3)
	NewModels6.limb(md, "cloth", Vector3(-0.12, 0.009, -0.05), Vector3(0.12, 0.009, -0.05), 0.003, 0.003, Color(0.5, 0.32, 0.2), 4)

static func _thermos(md: NewModels6.Model) -> void:
	# an old green steel vacuum flask, 0.35 m, with a screw cup, and two enamel mugs beside it
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.046, 0.01), Vector2(0.048, 0.1), Vector2(0.046, 0.26), Vector2(0.042, 0.29), Vector2(0.0, 0.29)])
	NewModels6.put(md, "enamel", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, Color(0.15, 0.3, 0.2), 0.03)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.29, 0), Vector3(0, 0.345, 0), 0.048, 0.044, 20, Color(0.7, 0.68, 0.6), 3, 0.03)
	NewModels6.cyl(md, "rubber", Vector3(0, 0.0, 0), Vector3(0, 0.015, 0), 0.044, 0.044, 16, Color(0.1, 0.1, 0.1), 3, 0.0)
	NewModels6.limb(md, "rubber", Vector3(0.05, 0.15, 0.0), Vector3(0.09, 0.22, 0.0), 0.006, 0.006, Color(0.1, 0.1, 0.1), 5)
	NewModels6.limb(md, "rubber", Vector3(0.09, 0.22, 0.0), Vector3(0.05, 0.28, 0.0), 0.006, 0.006, Color(0.1, 0.1, 0.1), 5)
	for k in 2:
		var c := Vector3(0.14 + k * 0.1, 0.0, 0.0 + k * 0.08)
		NewModels6.cyl(md, "enamel", c, c + Vector3(0, 0.08, 0), 0.04, 0.043, 16, Color(0.82, 0.8, 0.7) if k == 0 else Color(0.15, 0.3, 0.45), 3, 0.03)
		NewModels6.cyl(md, "enamel", c + Vector3(0, 0.08, 0), c + Vector3(0, 0.083, 0), 0.043, 0.043, 16, Color(0.1, 0.1, 0.12), 3, 0.0)
		NewModels6.limb(md, "enamel", c + Vector3(0.04, 0.06, 0), c + Vector3(0.07, 0.04, 0), 0.006, 0.006, Color(0.5, 0.5, 0.5), 5)

static func _newspaper(md: NewModels6.Model) -> void:
	# the front page of a 1984 local paper, folded once: a fictional masthead, the headline STORM TAKES THE VALLEY, a grainy photo and columns of grey type
	NewModels6.box(md, "paper", Vector3(0, 0.002, 0), Vector3(0.3, 0.003, 0.4), Color(0.8, 0.78, 0.68))
	NewModels6.box(md, "paper", Vector3(0, 0.0045, 0.0), Vector3(0.001, 0.002, 0.4), Color(0.6, 0.58, 0.5))
	NewModels6.text(md, "paper", "THE HALLOWAY HERALD", Vector3(0.0, 0.0042, 0.158), Vector3.UP, 0.026, INK, Vector3(0, 0, -1), 0.0)
	NewModels6.text(md, "paper", "NOVEMBER 1984", Vector3(0.0, 0.0042, 0.13), Vector3.UP, 0.01, Color(0.3, 0.3, 0.32), Vector3(0, 0, -1), 0.0)
	NewModels6.text(md, "paper", "STORM TAKES", Vector3(0.0, 0.0042, 0.075), Vector3.UP, 0.04, INK, Vector3(0, 0, -1), 0.0)
	NewModels6.text(md, "paper", "THE VALLEY", Vector3(0.0, 0.0042, 0.03), Vector3.UP, 0.04, INK, Vector3(0, 0, -1), 0.0)
	NewModels6.box(md, "paper", Vector3(-0.055, 0.0045, -0.07), Vector3(0.13, 0.0006, 0.1), Color(0.42, 0.43, 0.44))
	NewModels6.sheet(md, "paper", [Vector3(-0.1, 0.0052, -0.05), Vector3(-0.02, 0.0052, -0.1), Vector3(-0.05, 0.0052, -0.11), Vector3(-0.11, 0.0052, -0.08)], Color(0.3, 0.3, 0.32), Vector3.UP, false)
	for c in 3:
		for l in 10:
			NewModels6.box(md, "paper", Vector3(0.06 + (c - 1) * 0.0 + 0.0, 0.0044, -0.02 - l * 0.016 - 0.0), Vector3(0.08 - 0.02 * NewModels6.rnd(l * 3 + c, 61.0), 0.0004, 0.0035), Color(0.4, 0.4, 0.42))
	for l in 5:
		NewModels6.box(md, "paper", Vector3(-0.055, 0.0044, -0.14 + l * 0.0 - l * 0.0 - l * 0.0), Vector3(0.12, 0.0004, 0.0035), Color(0.4, 0.4, 0.42))
