class_name Birds
extends Node3D
## Birds over the valley: Canada geese crossing in a V, gulls working the lake shore, a starling murmuration at dusk
## and the two hawks that already circled the valley for their sound. Built by session B for SPEC-NEW-EXPERIENCES.md E4.
##
## The models are the four NewModels.bird() kinds with their eight baked wing poses. Each kind gets one MultiMesh per
## pose (32 meshes, one draw call each); every frame the flock code writes each bird's transform into the mesh of the
## pose it is in, so a goose flaps by moving between the eight meshes. Scales and sizes are real metres, so birds are
## dots from far away and show their wings and fingers within about 60 m.
##
## Behaviour: geese fly across the valley high up, gulls circle the lake shore, starlings flow as one shape over the
## lake at dusk, hawks soar in their thermals (the same circles the sound code uses). Within 25 m of the drone a flock
## scatters and veers away, and nothing is ever hurt: no collisions, no damage, no gore. Wind pushes every bird, rain,
## fog and snow thin them out, none fly at night, and geese only come in the spring and autumn months by date.
##
## Switch: Display > Graphics > "Birds" (hud.gd, default On). Budget: at most 1600 starlings plus the bigger birds on
## a computer, 320 on a phone (OS.has_feature("mobile")).

const KINDS := ["goose", "gull", "starling", "hawk"]
const POSE_N := 8
const GLIDE_POSE := 2                       # bird_info glide_flap 0.25 x 8 poses
const CAP_DESKTOP := {"goose": 26, "gull": 10, "starling": 1600, "hawk": 2}
const CAP_PHONE := {"goose": 26, "gull": 8, "starling": 320, "hawk": 2}
const SCATTER_M := 25.0                     # the drone this close scatters a flock
const VALLEY := 1900.0
const LAKE_SHORE := Vector2(-470.0, 100.0)  # the east shore of the lake, where the gulls work
const STARS_CRUISE := 15.0                  # geese crossing speed, m/s

var enabled := true

var _terrain: Terrain
var _audio: DroneAudio
var _mobile := false
var _t := 0.0
var _star_t := 0.0
var _star_acc := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _mm := {}                     # kind -> Array of MultiMeshInstance3D (one per pose)
var _caps := {}                   # kind -> int
var _birds := {}                  # kind -> Array of Dictionary states
var _last_flush := 0.0
var _last_honk := 0.0
var _last_gull := 0.0
var _force := false               # dev hook: ignore night, season and weather gates
var _debug_near := false          # dev hook: bring the flocks in front of the camera

# geese: one V flock led by a bird with a slowly turning heading
var _lead_p := Vector3.ZERO
var _lead_dir := Vector3(0.0, 0.0, -1.0)
var _lead_agl := 210.0
var _lead_t := 0.0
# starlings: one murmuration centre that drifts over the lake
var _star_c := Vector3.ZERO
var _star_v := Vector3.ZERO

func setup(terrain: Terrain, home: Vector2) -> void:
	_rng.seed = 7717
	_mobile = OS.has_feature("mobile")
	_caps = CAP_PHONE if _mobile else CAP_DESKTOP
	_terrain = terrain
	_noise.seed = 12
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.05
	_build_meshes()
	_build_geese(home)
	_build_gulls(home)
	_build_starlings()
	_build_hawks()

func set_audio(a: DroneAudio) -> void:
	_audio = a

func _build_meshes() -> void:
	for kind in KINDS:
		var list: Array = []
		var cap: int = int(_caps[kind])
		for pose in POSE_N:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = NewModels.bird(kind, float(pose) / float(POSE_N))
			mm.instance_count = cap
			mm.visible_instance_count = 0
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			mmi.custom_aabb = AABB(Vector3(-VALLEY, -300.0, -VALLEY), Vector3(VALLEY * 2.0, 1400.0, VALLEY * 2.0))
			add_child(mmi)
			list.append(mmi)
		_mm[kind] = list
		_birds[kind] = []

func _build_geese(home: Vector2) -> void:
	var count: int = int(_caps["goose"])
	_lead_p = Vector3(760.0, terrain_y(760.0, -1060.0) + _lead_agl, -1060.0)
	_lead_dir = Vector3(-0.55, 0.0, 0.84).normalized()
	_lead_agl = 210.0 + _rng.randf() * 70.0
	var birds: Array = _birds["goose"]
	for i in count:
		# the V: alternate sides, each pair a little further back and wider than the pair before
		var row := int(i / 2)
		var side := 1.0 if i % 2 == 0 else -1.0
		var off := Vector3(side * (1.6 + 1.15 * row), 0.0, 4.2 + 3.6 * row)
		birds.append({"p": _lead_p + off, "v": _lead_dir * STARS_CRUISE, "ph": _rng.randf(), "off": off,
			"pose": 0, "kind": "goose", "alive": true, "pp": _lead_p + off})

func _build_gulls(home: Vector2) -> void:
	var count: int = int(_caps["gull"])
	var birds: Array = _birds["gull"]
	for i in count:
		var c := LAKE_SHORE + Vector2(_rng.randf_range(-80.0, 120.0), _rng.randf_range(-420.0, 380.0))
		birds.append({"c": c, "r": _rng.randf_range(45.0, 150.0), "ang": _rng.randf() * TAU, "w": _rng.randf_range(0.10, 0.22) * (1.0 if i % 2 == 0 else -1.0),
			"alt": _rng.randf_range(35.0, 90.0), "ph": _rng.randf(), "p": Vector3.ZERO, "v": Vector3.ZERO,
			"pose": GLIDE_POSE, "kind": "gull", "alive": true, "pp": Vector3.ZERO})

func _build_starlings() -> void:
	var count: int = int(_caps["starling"])
	_star_c = Vector3(-760.0, Lake.LEVEL + 120.0, 120.0)
	var birds: Array = _birds["starling"]
	for i in count:
		var a := _rng.randf() * TAU
		var z := _rng.randf_range(-1.0, 1.0)
		var rr := sqrt(maxf(0.0, 1.0 - z * z))
		var off := Vector3(rr * cos(a), z * 0.45, rr * sin(a))
		birds.append({"off": off, "ph": _rng.randf() * TAU, "ang": a, "p": _star_c + off * 60.0,
			"pose": _rng.randi() % POSE_N, "kind": "starling", "alive": true, "pp": _star_c + off * 60.0})

func _build_hawks() -> void:
	var birds: Array = _birds["hawk"]
	for i in 2:
		birds.append({"p": Vector3.ZERO, "v": Vector3.ZERO, "pose": GLIDE_POSE, "kind": "hawk", "alive": true,
			"pp": Vector3.ZERO, "ph": _rng.randf(), "sc": 0.0})

func terrain_y(x: float, z: float) -> float:
	return _terrain.height(x, z) if _terrain != null else 0.0

# ------------------------------------------------------------------ per frame
## Called by main.gd every frame. wx is the weather system, `daylight` 0 at night, `doy` the day of the year.
func update(delta: float, cam: Camera3D, drone: Vector3, wind: Wind, wx: WeatherSystem, sun_el: float, daylight: float, doy: int, paused: bool) -> void:
	if not enabled:
		_hide_all()
		return
	if paused:
		return
	_t += delta
	if _debug_near:
		_drift_debug(cam, drone)
	var c: Dictionary = wx.cur
	var rain: float = float(c.get("rain", 0.0))
	var fog: float = float(c.get("fog", 0.0))
	var snow: float = float(c.get("snow", 0.0))
	var windv: Vector3 = wind.toward() * wind.speed * 0.55
	# how many birds the weather allows: fewer in rain and fog, none in a gale
	var weather_k: float = clampf((1.0 - 0.75 * rain) * (1.0 - 0.5 * fog) * (1.0 - 0.6 * snow) * (1.0 - smoothstep(9.0, 18.0, wind.speed)), 0.0, 1.0)
	var show_geese: bool = _force or ((doy >= 60 and doy <= 152) or (doy >= 244 and doy <= 335))
	show_geese = show_geese and (_force or daylight > 0.2) and weather_k > 0.25
	var show_gulls: bool = (_force or daylight > 0.15) and weather_k > 0.15
	var show_stars: bool = (_force or (sun_el < 6.0 and sun_el > -8.0)) and weather_k > 0.25
	var show_hawks: bool = (_force or daylight > 0.3) and weather_k > 0.2
	_update_geese(delta, drone, windv, weather_k, show_geese, cam)
	_update_gulls(delta, drone, windv, weather_k, show_gulls, cam)
	_update_hawks(delta, drone, windv, show_hawks)
	_star_acc += delta
	if _star_acc > 0.1:
		var sdt := _star_acc
		_star_acc = 0.0
		_update_starlings(sdt, drone, windv, weather_k, show_stars, cam)
	if not show_stars:
		_write_kind("starling", 0)

func _hide_all() -> void:
	for kind in KINDS:
		_write_kind(kind, 0)

func _drift_debug(cam: Camera3D, drone: Vector3) -> void:
	# screenshot hook: put the flock in front of the camera so a single frame shows what it looks like
	var fwd := -cam.global_transform.basis.z
	var fwd_h := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var right_h := fwd_h.cross(Vector3.UP).normalized()
	if _lead_p.distance_to(cam.global_position) > 900.0:
		_lead_p = cam.global_position + fwd_h * 72.0 + Vector3(0.0, 16.0, 0.0)
		_lead_dir = fwd_h
		for b in _birds["goose"]:
			b["p"] = _lead_p + b["off"]
			b["v"] = _lead_dir * STARS_CRUISE
	# the gulls circle in front of the camera too, so one demo frame shows all four kinds
	var gulls: Array = _birds["gull"]
	for i in gulls.size():
		var g: Dictionary = gulls[i]
		var side := float(i - gulls.size() / 2)
		g["c"] = Vector2(cam.global_position.x + fwd_h.x * 150.0 + right_h.x * side * 26.0, cam.global_position.z + fwd_h.z * 150.0 + right_h.z * side * 26.0)
		g["alt"] = 26.0 + 7.0 * float(i % 3)
		g["r"] = 22.0 + 6.0 * float(i % 4)
	_star_c = cam.global_position + fwd_h * 250.0 + Vector3(0.0, 55.0, 0.0)
	_star_v = fwd_h * 3.0

# ------------------------------------------------------------------ flocks
func _update_geese(delta: float, drone: Vector3, windv: Vector3, weather_k: float, show: bool, cam: Camera3D) -> void:
	var birds: Array = _birds["goose"]
	if not show:
		_write_kind("goose", 0)
		return
	# the leader: a slow turn, a steady 15 m/s, and an altitude above the ground that eases up and down
	_lead_t += delta
	var turn := _noise.get_noise_1d(_lead_t * 0.09) * 0.30
	_lead_dir = _lead_dir.rotated(Vector3.UP, turn * delta).normalized()
	_lead_p += _lead_dir * STARS_CRUISE * delta
	var gy := terrain_y(_lead_p.x, _lead_p.z)
	_lead_p.y = lerpf(_lead_p.y, gy + _lead_agl, clampf(delta * 0.3, 0.0, 1.0))
	if _lead_p.x > VALLEY or _lead_p.x < -VALLEY or _lead_p.z > VALLEY or _lead_p.z < -VALLEY:
		# off the map: come back in from the far side, heading across again
		var t := Vector3(-_lead_p.x, 0.0, -_lead_p.z).normalized()
		_lead_dir = (t + Vector3(_rng.randf_range(-0.3, 0.3), 0.0, _rng.randf_range(-0.3, 0.3))).normalized()
		_lead_p = -_lead_dir * VALLEY * 0.8
		_lead_p.y = terrain_y(_lead_p.x, _lead_p.z) + _lead_agl
	var thr := int(float(birds.size()) * clampf(weather_k * 1.4, 0.0, 1.0))
	for i in birds.size():
		var b: Dictionary = birds[i]
		var alive: bool = i < thr
		b["alive"] = alive
		if not alive:
			continue
		# in a V behind the leader, in the leader's own frame
		var right := _lead_dir.cross(Vector3.UP).normalized()
		var target: Vector3 = _lead_p + right * float(b["off"].x) - _lead_dir * float(b["off"].z)
		target += right * sin(_t * 0.9 + float(b["ph"]) * 9.0) * 0.5
		var p: Vector3 = b["p"]
		var v: Vector3 = b["v"]
		var want: Vector3 = (target - p) * 2.2 + _lead_dir * STARS_CRUISE + windv * 0.5
		# near the drone the flock splits and every bird veers away, then the V re-forms
		var away: Vector3 = p - drone
		var d := away.length()
		if d < SCATTER_M * 3.0:
			var push := clampf(1.0 - d / (SCATTER_M * 3.0), 0.0, 1.0)
			want += away / maxf(d, 0.1) * (14.0 * push) + Vector3(0.0, 3.0 * push, 0.0)
			if d < SCATTER_M + 12.0 and _t - _last_flush > 3.0:
				_last_flush = _t
				if _audio: _audio.flush_at(p)
		v = v.lerp(want, clampf(delta * 2.2, 0.0, 1.0))
		p += v * delta
		var flap: float = fposmod(float(b["ph"]) + delta * 2.8 * (1.0 + 0.25 * sin(_t * 0.7 + float(b["ph"]) * 6.0)), 1.0)
		b["ph"] = flap
		var pose := int(floor(flap * POSE_N)) % POSE_N
		if flap > 0.62 and flap < 0.78: pose = GLIDE_POSE   # a short glide at the top of the stroke
		b["p"] = p
		b["v"] = v
		b["pose"] = pose
		b["pp"] = p
		# honking: the flock talks now and then when it is near the camera
		var near := p.distance_to(cam.global_position)
		if near < 420.0 and near > 40.0 and _t - _last_honk > 2.5 + _rng.randf() * 4.0:
			_last_honk = _t
			if _audio: _audio.honk_at(p)
	_write_kind("goose", thr)

func _update_gulls(delta: float, drone: Vector3, windv: Vector3, weather_k: float, show: bool, cam: Camera3D) -> void:
	var birds: Array = _birds["gull"]
	if not show:
		_write_kind("gull", 0)
		return
	var thr := int(float(birds.size()) * clampf(weather_k * 1.6, 0.0, 1.0))
	for i in birds.size():
		var b: Dictionary = birds[i]
		var alive: bool = i < thr
		b["alive"] = alive
		if not alive:
			continue
		b["ang"] = float(b["ang"]) + float(b["w"]) * delta
		var ang: float = b["ang"]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var p := Vector3(c.x + cos(ang) * r, Lake.LEVEL + float(b["alt"]) + sin(ang * 2.0) * 3.0, c.y + sin(ang) * r)
		var tangent := Vector3(-sin(ang), 0.0, cos(ang)) * signf(float(b["w"])) * r * absf(float(b["w"]))
		var away: Vector3 = p - drone
		var v: Vector3 = tangent + windv * 0.35
		var d := away.length()
		if d < SCATTER_M * 2.5:
			v += away / maxf(d, 0.1) * 8.0 * clampf(1.0 - d / (SCATTER_M * 2.5), 0.0, 1.0)
			if d < SCATTER_M + 10.0 and _t - _last_gull > 2.0:
				_last_gull = _t
				if _audio: _audio.flush_at(p)
		b["p"] = p
		b["v"] = v
		b["pp"] = p
		b["pose"] = GLIDE_POSE if (int(_t * 2.0 + i) % 3 == 0) else int(fposmod(_t * 2.6 + float(b["ph"]), 1.0) * POSE_N) % POSE_N
		if p.distance_to(cam.global_position) < 260.0 and _t - _last_gull > 3.0 + _rng.randf() * 3.0 and _audio:
			_last_gull = _t
			_audio.gull_at(p)
	_write_kind("gull", thr)

## Circle centres of thermals (game/weather_events.gd B3). While this is not empty the hawks circle these instead of the
## old sound-only circles, so the birds and the rising air agree.
var thermal_centres: Array[Vector3] = []

func _update_hawks(delta: float, drone: Vector3, windv: Vector3, show: bool) -> void:
	var birds: Array = _birds["hawk"]
	if not show:
		_write_kind("hawk", 0)
		return
	if not thermal_centres.is_empty():
		# the hawks ride the thermals: one hawk per column (two columns, two hawks), a slow circle with a little bob
		for i in mini(birds.size(), thermal_centres.size()):
			var b: Dictionary = birds[i]
			var c: Vector3 = thermal_centres[i]
			var ang: float = _t * 0.16 + float(i) * 2.0
			var px := c.x + cos(ang) * 46.0
			var pz := c.z + sin(ang) * 46.0
			var p := Vector3(px, c.y - 60.0 + sin(_t * 0.5 + float(i)) * 14.0, pz)
			var v := Vector3(-sin(ang), 0.0, cos(ang)) * 46.0 * 0.16
			b["p"] = p; b["v"] = v; b["pp"] = p; b["pose"] = GLIDE_POSE; b["alive"] = true
		_write_kind("hawk", mini(birds.size(), thermal_centres.size()))
		return
	# otherwise the hawks soar on the same circles the sound code has always used (drone_audio "_soarers")
	var soar: Array = []
	if _audio != null:
		for s in _audio.soaring():
			if str(s["kind"]) == "hawk":
				soar.append(s)
	for i in mini(birds.size(), soar.size()):
		var b: Dictionary = birds[i]
		var s: Dictionary = soar[i]
		var c: Vector2 = s["c"]
		var ang: float = float(s["ang"])
		var r: float = float(s["r"])
		var px := c.x + cos(ang) * r
		var pz := c.y + sin(ang) * r
		var p := Vector3(px, terrain_y(px, pz) + absf(float(s["alt"])), pz)
		var v := Vector3(-sin(ang), 0.0, cos(ang)) * r * absf(float(s["w"]))
		b["p"] = p
		b["v"] = v
		b["pp"] = p
		b["pose"] = GLIDE_POSE
		b["alive"] = true
	_write_kind("hawk", mini(birds.size(), soar.size()))

func _update_starlings(dt: float, drone: Vector3, windv: Vector3, weather_k: float, show: bool, cam: Camera3D) -> void:
	var birds: Array = _birds["starling"]
	if not show:
		_write_kind("starling", 0)
		return
	_star_t += dt
	var thr := int(float(birds.size()) * clampf(weather_k * 1.3, 0.0, 1.0))
	# the cloud drifts slowly downwind, and every bird turns with it
	_star_v = _star_v.lerp(windv * 0.5, clampf(dt * 0.2, 0.0, 1.0))
	_star_c += _star_v * dt
	var gy := Lake.LEVEL + 120.0
	_star_c.y = lerpf(_star_c.y, gy, clampf(dt * 0.2, 0.0, 1.0))
	var right := Vector3.RIGHT
	for i in birds.size():
		var b: Dictionary = birds[i]
		var alive: bool = i < thr
		b["alive"] = alive
		if not alive:
			continue
		var off: Vector3 = b["off"]
		var ang: float = float(b["ang"]) + _star_t * 0.30
		var ox := cos(ang) * off.x - sin(ang) * off.z
		var oz := sin(ang) * off.x + cos(ang) * off.z
		var oy: float = off.y * 0.45
		var shape := _noise.get_noise_3d(ox * 9.0, oy * 9.0, _star_t * 0.20)
		var rr := 48.0 + 26.0 * shape
		var p: Vector3 = _star_c + Vector3(ox, oy, oz) * rr
		p += Vector3(sin(_star_t * 2.1 + float(b["ph"])), 0.6 * sin(_star_t * 1.7 + float(b["ph"]) * 2.0), cos(_star_t * 1.9 + float(b["ph"]))) * 1.4
		var away: Vector3 = p - drone
		var d := away.length()
		if d < SCATTER_M * 3.0:
			p += away / maxf(d, 0.1) * (SCATTER_M * 3.0 - d) * 0.55
			if d < SCATTER_M + 8.0 and _t - _last_flush > 2.0:
				_last_flush = _t
				if _audio: _audio.flush_at(p)
		var pp: Vector3 = b["pp"]
		b["pp"] = p
		b["p"] = p
		b["v"] = (p - pp) / maxf(dt, 1e-4)
		b["pose"] = GLIDE_POSE if int(_star_t * 3.0 + float(b["ph"])) % 2 == 0 else int(fposmod(float(b["ph"]) + _star_t * 3.0, 1.0) * POSE_N) % POSE_N
	_write_kind("starling", thr)

# ------------------------------------------------------------------ write the transforms into the pose meshes
func _write_kind(kind: String, active: int) -> void:
	var meshes: Array = _mm[kind]
	var birds: Array = _birds[kind]
	var used := PackedInt32Array()
	used.resize(POSE_N)
	var wrote := false
	for i in mini(active, birds.size()):
		var b: Dictionary = birds[i]
		if not bool(b.get("alive", true)):
			continue
		var pose: int = int(b["pose"]) % POSE_N
		if used[pose] >= int(_caps[kind]):
			continue
		var pos: Vector3 = b["p"]
		# face the way it is going; roll into the turn a little
		var v: Vector3 = b["v"]
		var fwd: Vector3 = v.normalized() if v.length_squared() > 0.01 else -_lead_dir
		if absf(fwd.y) > 0.98:
			fwd = Vector3(fwd.x, signf(fwd.y) * 0.98, fwd.z).normalized()
		var basis := Basis.looking_at(fwd, Vector3.UP)
		var bank: float = clampf(-(b.get("bank", 0.0)), -0.5, 0.5)
		if bank != 0.0:
			basis = basis * Basis(Vector3(0.0, 0.0, 1.0), bank)
		var xf := Transform3D(basis, pos)
		if kind == "starling":
			# a starling is 38 cm across: at a few hundred metres that is under a pixel, so draw it a little larger
			# (the "birds are dots far away, wings close up" rule). Taste question E4.2 in LOGIC-NOTES.md.
			xf = Transform3D(basis.scaled(Vector3.ONE * 1.6), pos)
		var mmi: MultiMeshInstance3D = meshes[pose]
		mmi.multimesh.set_instance_transform(used[pose], xf)
		used[pose] += 1
		wrote = true
	for pose in POSE_N:
		var mmi: MultiMeshInstance3D = meshes[pose]
		mmi.multimesh.visible_instance_count = used[pose]
		mmi.visible = used[pose] > 0
	if not wrote:
		for pose in POSE_N:
			(meshes[pose] as MultiMeshInstance3D).visible = false

# ------------------------------------------------------------------ image and test hooks
## Screenshot hook: ignore the night, the season and the weather, so a night shot can show the birds.
func force_visible(on: bool) -> void:
	_force = on

## Screenshot hook: keep the geese and the starling cloud in front of the camera.
func debug_near(on: bool) -> void:
	_debug_near = on

## A short read-out for a headless check.
func stats() -> Dictionary:
	var out := {}
	for kind in KINDS:
		var n := 0
		for b in _birds[kind]:
			if bool(b.get("alive", true)):
				n += 1
		out[kind] = n
	out["enabled"] = enabled
	out["force"] = _force
	return out
