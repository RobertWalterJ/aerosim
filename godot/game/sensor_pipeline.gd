class_name SensorPipeline
extends Node
## The seven-stage small-sensor camera model from the web version (SensorPipeline.ts), built from SubViewports.
##   1 rolling shutter + motor jello | 2 centre-weighted auto-exposure with lag | 3 sun streak, cyan ghost, veiling glare
##   4 Brown-Conrady distortion + lateral chromatic aberration | 5 10-stop S-curve | 6 ISP unsharp mask + ISO noise
##   7 RF-link H.264 macroblocking, plus a bloom chain.
## The 3D world is drawn by `camera` into an HDR overscan viewport (linear, unclamped); every later stage is a
## full-screen shader pass into its own small viewport; the last one is letterboxed onto the screen.

const LENSES := {
	"standard": {"diag": 84.0, "k1": 0.035, "k2": 0.0, "name": "84° Standard (24 mm)", "ca": 0.0018},
	"wide": {"diag": 150.0, "k1": 0.30, "k2": 0.16, "name": "150° Wide (SuperView)", "ca": 0.004},
}
const SHADER_DIR := "res://game/shaders/"

var lens := "standard"
var ev_comp := 0.0
## 0 = normal exposure, 1 = a moonless night where the camera must not simply lift the world into daylight.
var night_dark := 0.0
var _over := 0.0
var _log_e := 0.0                    # log2 exposure the camera has adapted to
var _mean_log := -2.9                # latest metered mean log luminance of the scene
var wb_kelvin := 5600.0              # the white balance the camera has settled on
var _sun_amt := 0.0                  # how much sun is in the picture, 0..1, eased
var bloom_on := true
var rain_lens := 0.0                # water on the lens, 0..1
var lens_wash := 0.0                # rotor wash over the lens, 0..1
var lens_air := Vector3.ZERO        # air moving over the lens in camera axes: sideways, up, head-on (m/s)
var noise_scale := 1.0              # sensor noise amount, 1 = as designed
var link_effects := true            # video-link macroblocking on or off
var out_w := 1280
var out_h := 720
var msaa := Viewport.MSAA_2X
var s_over := 1.2

# readouts for the on-screen display (refreshed a few times a second)
var exposure := 1.0
var iso_shown := 100
var shutter_shown := 1.0 / 200.0
var histogram := PackedFloat32Array()
var sun_vis := 1.0                 # 0..1, set by the caller (line of sight to the sun)
var drone_speed := 0.0             # m/s, set by the caller (forward-motion blur)
var look := 0                      # colour look: 0 Natural, 1 Flat (D-Cinelike), 2 Vivid

# session B (fireworks): up to four recent bursts in the lens. game/fireworks.gd calls burst_glare() for each burst;
# the lens gets a flash, an anamorphic streak, a ghost ring, a short exposure dip and a little veiling light.
const BURST_N := 4
var _burst_p: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _burst_c: Array[Color] = [Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0)]
var _burst_k: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _burst_wash := 0.0

# session A (camera): storm/funnel exposure dip. Session B's storm and funnel call event_dim() to darken the scene.
var _event_dim := 0.0
var _event_dim_target := 0.0

## A storm or funnel darkening the scene: an exposure dip. `strength` 0..1, where 1.0 is about 1.2 stops darker.
## It fades over about 1.5 s. Called from session B's storm and funnel runtime.
func event_dim(strength: float) -> void:
	_event_dim_target = clampf(strength, 0.0, 1.0)

## A firework burst seen by this camera: a short lens flash, a streak and a ghost, and it nudges the auto exposure.
## `strength` 0..1.6 (a big shell is about 1.0). The effect fades over about 1.2 s. Called from game/fireworks.gd.
## The active firework bursts as screen-space flash sources, for the night-vision intensifier. Each entry is
## {uv: Vector2, k: strength, c: Colour}; off-screen bursts are omitted.
func burst_uvs() -> Array:
	var out: Array = []
	if camera == null:
		return out
	for i in BURST_N:
		if _burst_k[i] <= 0.001:
			continue
		var p: Vector2 = _project(_burst_p[i])
		if p.x < -1.8 or p.x > 1.8 or p.y < -1.8 or p.y > 1.8:
			continue
		out.append({"uv": p * 0.5 + Vector2(0.5, 0.5), "k": _burst_k[i], "c": _burst_c[i]})
	return out

func burst_wash() -> float:
	return _burst_wash

func burst_glare(world_pos: Vector3, colour: Color, strength: float) -> void:
	var slot := 0
	var weakest := 1e9
	for i in BURST_N:
		if _burst_k[i] < weakest:
			weakest = _burst_k[i]
			slot = i
	_burst_p[slot] = world_pos
	_burst_c[slot] = colour
	_burst_k[slot] = clampf(strength, 0.0, 1.6)


var camera: Camera3D
var scene_vp: SubViewport
var simple := false               # phone-safe mode: the 3D picture goes straight to the screen, none of the sensor passes
var screen: ColorRect              # letterboxed output, add it to a CanvasLayer

var _holder: Node
var _hist_vp: SubViewport
var _passes := {}
var _exp: Array[SubViewport] = []
var _exp_idx := 0
var _codec: Array[SubViewport] = []
var _codec_idx := 0
var _down: Array[SubViewport] = []
var _up: Array[SubViewport] = []
var _frame := 0
var _sun_world := Vector3(0, 1, 0)

func setup(cam: Camera3D, height: int, msaa_mode: int) -> void:
	camera = cam
	msaa = msaa_mode
	out_h = height
	for a in OS.get_cmdline_user_args():     # test hook: dof0 / dof1 / dof2 picks the depth of field mode, dofdebug prints the focus
		if a.begins_with("dof") and a.length() == 4: dof_mode = int(a.substr(3))
		if a == "dofdebug": _dof_debug = true
		if a.begins_with("dofcal"): _dof_cal = float(a.substr(6))
		if a == "nonoise": noise_scale = 0.0
		if a.begins_with("mf"): manual_focus = true; mf_distance = float(a.substr(2))     # mf2.5: manual focus at 2.5 m
		if a.begins_with("fp"):                                                             # fp0.4_-0.3: autofocus point
			var v := a.substr(2).split("_")
			if v.size() == 2: _test_tap = Vector2(float(v[0]), float(v[1]))
	_build()
	_setup_dof()

## Switch between the full sensor camera and the phone-safe plain picture.
func set_simple(on: bool) -> void:
	if on == simple: return
	simple = on
	_build()

func lens_info() -> Dictionary:
	return LENSES[lens]

func set_lens(name: String) -> void:
	if name == lens: return
	lens = name
	_build()

func set_sun_direction(to_sun: Vector3) -> void:
	_sun_world = to_sun.normalized()

func _tan_half() -> Vector2:
	var l: Dictionary = LENSES[lens]
	var aspect := float(out_w) / float(out_h)
	var half_diag := tan(deg_to_rad(float(l["diag"])) / 2.0)
	var ty := half_diag / sqrt(1.0 + aspect * aspect)
	return Vector2(ty * aspect, ty)

func hfov_deg() -> float:
	return rad_to_deg(2.0 * atan(_tan_half().x))

# ------------------------------------------------------------------ construction
func _vp(size: Vector2i, hdr := true) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.use_hdr_2d = hdr
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	return vp

func _pass(key: String, shader: String, size: Vector2i) -> SubViewport:
	var vp := _vp(size)
	var rect := ColorRect.new()
	rect.size = Vector2(size)
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_DIR + shader + ".gdshader")
	rect.material = mat
	vp.add_child(rect)
	_holder.add_child(vp)
	_passes[key] = mat
	mat.set_meta("vp", vp)
	return vp

func _build() -> void:
	if _holder != null:
		_holder.queue_free()
	_holder = Node.new()
	_holder.name = "SensorPasses"
	add_child(_holder)
	_passes.clear(); _exp.clear(); _codec.clear(); _down.clear(); _up.clear()
	var l: Dictionary = LENSES[lens]
	out_w = int(round(out_h * 16.0 / 9.0))
	s_over = maxf(1.2, (1.0 + float(l["k1"]) + float(l["k2"])) * 1.06)
	var k := minf(s_over, 1.45)
	var sw := int(round(out_w * k))
	var sh := int(round(out_h * k))
	var tan_half := _tan_half()
	# the scene: HDR overscan so distortion and rolling-shutter shifts never run out of picture
	scene_vp = SubViewport.new()
	scene_vp.size = Vector2i(sw, sh)
	scene_vp.use_hdr_2d = true
	scene_vp.msaa_3d = msaa
	scene_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene_vp.name = "SensorScene"
	_holder.add_child(scene_vp)
	if camera.get_parent() != scene_vp:
		if camera.get_parent() != null: camera.reparent(scene_vp, false)
		else: scene_vp.add_child(camera)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = rad_to_deg(2.0 * atan(tan_half.y * s_over))
	camera.current = true
	if simple:
		# no HDR, no post passes: the scene viewport is the picture (the game sets a normal tone map on the environment)
		scene_vp.size = Vector2i(out_w, out_h)
		scene_vp.use_hdr_2d = false
		camera.fov = 52.0
		if screen == null:
			screen = ColorRect.new()
			screen.set_anchors_preset(Control.PRESET_FULL_RECT)
			screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
			screen.material = ShaderMaterial.new()
			(screen.material as ShaderMaterial).shader = load(SHADER_DIR + "blit.gdshader")
		var sbm: ShaderMaterial = screen.material
		sbm.set_shader_parameter("uSrc", scene_vp.get_texture())
		var ssz := screen.get_viewport_rect().size
		sbm.set_shader_parameter("uAspectScreen", ssz.x / maxf(ssz.y, 1.0))
		sbm.set_shader_parameter("uAspectSrc", float(out_w) / float(out_h))
		return
	# exposure
	var meter := _pass("meter", "meter", Vector2i(32, 32))
	var reduce := _pass("reduce", "reduce", Vector2i(1, 1))
	for i in 2: _exp.append(_pass("exp%d" % i, "adapt", Vector2i(1, 1)))
	(_passes["meter"] as ShaderMaterial).set_shader_parameter("uScene", scene_vp.get_texture())
	(_passes["meter"] as ShaderMaterial).set_shader_parameter("uS", s_over)
	(_passes["reduce"] as ShaderMaterial).set_shader_parameter("uSrc", meter.get_texture())
	for i in 2:
		var m: ShaderMaterial = _passes["exp%d" % i]
		m.set_shader_parameter("uMeter", reduce.get_texture())
		m.set_shader_parameter("uPrev", _exp[1 - i].get_texture())
		m.set_shader_parameter("uEvComp", ev_comp)
	# bloom chain: bright pass at half resolution, four downsamples, then the matching upsamples
	var w := int(round(out_w / 2.0))
	var h := int(round(out_h / 2.0))
	var sizes: Array[Vector2i] = []
	for i in 5:
		sizes.append(Vector2i(maxi(2, w), maxi(2, h)))
		w = maxi(2, w >> 1); h = maxi(2, h >> 1)
	_down.append(_pass("down0", "bloom_pre", sizes[0]))
	var pre: ShaderMaterial = _passes["down0"]
	pre.set_shader_parameter("uScene", scene_vp.get_texture())
	pre.set_shader_parameter("uTexel", Vector2(1.0 / sw, 1.0 / sh))
	for i in range(1, 5):
		_down.append(_pass("down%d" % i, "bloom_down", sizes[i]))
		var dm: ShaderMaterial = _passes["down%d" % i]
		dm.set_shader_parameter("uSrc", _down[i - 1].get_texture())
		dm.set_shader_parameter("uTexel", Vector2(1.0 / sizes[i - 1].x, 1.0 / sizes[i - 1].y))
	_up.resize(5)
	_up[4] = _pass("up4", "bloom_up", sizes[4])
	var u4: ShaderMaterial = _passes["up4"]
	u4.set_shader_parameter("uLow", _down[4].get_texture()); u4.set_shader_parameter("uHigh", _down[4].get_texture()); u4.set_shader_parameter("uWeight", 0.0)
	u4.set_shader_parameter("uTexel", Vector2(1.0 / sizes[4].x, 1.0 / sizes[4].y))
	for i in range(3, -1, -1):
		_up[i] = _pass("up%d" % i, "bloom_up", sizes[i])
		var um: ShaderMaterial = _passes["up%d" % i]
		um.set_shader_parameter("uLow", _up[i + 1].get_texture()); um.set_shader_parameter("uHigh", _down[i].get_texture()); um.set_shader_parameter("uWeight", 1.0)
		um.set_shader_parameter("uTexel", Vector2(1.0 / sizes[i + 1].x, 1.0 / sizes[i + 1].y))
	# sensor, ISP, codec
	var out := Vector2i(out_w, out_h)
	var sensor := _pass("sensor", "sensor", out)
	var sm: ShaderMaterial = _passes["sensor"]
	sm.set_shader_parameter("uScene", scene_vp.get_texture())
	sm.set_shader_parameter("uBloom", _up[0].get_texture())
	sm.set_shader_parameter("uS", s_over)
	sm.set_shader_parameter("uAspect", float(out_w) / float(out_h))
	sm.set_shader_parameter("uTan", tan_half)
	sm.set_shader_parameter("uK", Vector2(float(l["k1"]), float(l["k2"])))
	sm.set_shader_parameter("uCA", float(l["ca"]))
	var isp := _pass("isp", "isp", out)
	var im: ShaderMaterial = _passes["isp"]
	im.set_shader_parameter("uSrc", sensor.get_texture())
	im.set_shader_parameter("uTexel", Vector2(1.0 / out_w, 1.0 / out_h))
	for i in 2: _codec.append(_pass("codec%d" % i, "codec", out))
	for i in 2:
		var cm: ShaderMaterial = _passes["codec%d" % i]
		cm.set_shader_parameter("uSrc", isp.get_texture())
		cm.set_shader_parameter("uPrev", _codec[1 - i].get_texture())
		cm.set_shader_parameter("uRes", Vector2(out_w, out_h))
	var hist := _pass("hist", "hist", Vector2i(64, 36))
	(_passes["hist"] as ShaderMaterial).set_shader_parameter("uTexel", Vector2(1.0 / out_w, 1.0 / out_h))
	hist.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hist_vp = hist
	# the screen: the latest codec frame, letterboxed
	if screen == null:
		screen = ColorRect.new()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen.material = ShaderMaterial.new()
		(screen.material as ShaderMaterial).shader = load(SHADER_DIR + "blit.gdshader")
	histogram.resize(64)
	_exp_idx = 0

# ------------------------------------------------------------------ per frame
## Inputs: dt and time in seconds; the camera's angular velocity in its own frame (x pitch up, y yaw left, z roll),
## vibration 0..1, blade-pass frequency in Hz, and the video-link quality (rf_bad 0 good .. 1 lost).
func process_frame(dt: float, time: float, ang_vel_cam: Vector3, vibration: float, motor_hz: float, rf_bad: float) -> void:
	if simple:
		_frame += 1
		var sz0 := screen.get_viewport_rect().size
		var sbm2: ShaderMaterial = screen.material
		sbm2.set_shader_parameter("uAspectScreen", sz0.x / maxf(sz0.y, 1.0))
		return
	_frame += 1
	var tan_half := _tan_half()
	# session B: firework bursts on the lens (fade, project, and a small metering bias so the exposure flashes)
	var bpos := PackedVector2Array()
	var bcol := PackedVector3Array()
	var bk := PackedFloat32Array()
	var bwash := 0.0
	for i in BURST_N:
		_burst_k[i] = maxf(0.0, _burst_k[i] - dt * (0.55 + 0.35 * _burst_k[i]))
		var buv := _project(_burst_p[i])
		var kv: float = _burst_k[i]
		if buv.x < -1.7 or buv.x > 1.7 or buv.y < -1.7 or buv.y > 1.7:
			kv = 0.0
		# _project gives -1..1 with +y up; the sensor shader wants 0..1 screen uv with +y up (T() flips it itself)
		bpos.append(buv * 0.5 + Vector2(0.5, 0.5))
		bcol.append(Vector3(_burst_c[i].r, _burst_c[i].g, _burst_c[i].b))
		bk.append(kv)
		bwash += kv
	_burst_wash += (minf(bwash, 2.5) * 0.30 - _burst_wash) * clampf(dt * 5.0, 0.0, 1.0)
	# stage 2: metering and adaptation. Two 1x1 viewports take turns, each reading the other's result.
	# the sun in the picture: it washes the frame out, then the camera stops down and its auto white balance swings cooler
	var cb0 := camera.global_transform.basis
	var sun_target := smoothstep(0.86, 0.99, (-cb0.z).dot(_sun_world)) * sun_vis
	_sun_amt += (sun_target - _sun_amt) * (1.0 - exp(-minf(dt, 0.1) / (0.12 if sun_target > _sun_amt else 0.7)))
	var wb_target := 5600.0 - 2300.0 * _sun_amt
	wb_kelvin += (wb_target - wb_kelvin) * (1.0 - exp(-minf(dt, 0.1) / (0.9 if wb_target < wb_kelvin else 2.0)))
	# the camera's exposure follows the metered scene, slowly: it opens up quickly in the dark, and is slow to stop down
	# when bright light arrives, so the picture stays washed out for a moment before it settles. Worked out here, not in a shader.
	_event_dim += (_event_dim_target - _event_dim) * (1.0 - exp(-minf(dt, 0.1) / 1.5))
	var tgt := clampf(log(0.13) / log(2.0) - _mean_log + ev_comp - 0.8 * _sun_amt - 0.35 * minf(bwash, 1.2) - 1.2 * _event_dim - 1.55 * night_dark, log(0.1) / log(2.0), log(1.6) / log(2.0))
	var tau := 0.9 if tgt < _log_e else 0.45
	_log_e += (tgt - _log_e) * (1.0 - exp(-minf(dt, 0.1) / tau))
	_over = clampf((_log_e - tgt) / 1.5, 0.0, 1.0)     # how far the picture is still over-exposed: the haze lasts only while it is
	exposure = pow(2.0, _log_e)
	var next := 1 - _exp_idx
	var m: ShaderMaterial = _passes["exp%d" % next]
	m.set_shader_parameter("uDt", minf(dt, 0.1)); m.set_shader_parameter("uEvComp", ev_comp); m.set_shader_parameter("uBias", -2.4 * _sun_amt)
	_exp[next].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_exp[_exp_idx].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_exp_idx = next
	var exp_tex := _exp[next].get_texture()
	# bloom
	(_passes["down0"] as ShaderMaterial).set_shader_parameter("uExpV", _log_e)
	# sun position in the scene viewport's uv (y up) and its visibility
	var cb := camera.global_transform.basis
	var v := cb.inverse() * _sun_world
	var behind := v.z >= 0.0
	# the sun's place in the picture follows the field of view the 3D camera really has (the game sets it each frame)
	var ty_cam := tan(deg_to_rad(camera.fov * 0.5))
	var ts := Vector2(ty_cam * float(out_w) / float(out_h), ty_cam)
	var sun_uv := Vector2(2.0, 2.0)
	if not behind:
		sun_uv = Vector2(v.x / (-v.z) / ts.x * 0.5 + 0.5, v.y / (-v.z) / ts.y * 0.5 + 0.5)
	var in_view := (not behind) and sun_uv.x > -0.3 and sun_uv.x < 1.3 and sun_uv.y > -0.3 and sun_uv.y < 1.3
	var fwd_dot := (-cb.z).dot(_sun_world)
	# stages 1, 3, 4: sensor and lens
	var sm: ShaderMaterial = _passes["sensor"]
	sm.set_shader_parameter("uExpV", _log_e)
	sm.set_shader_parameter("uTime", time)
	sm.set_shader_parameter("uSunS", sun_uv)
	sm.set_shader_parameter("uWRS", Vector2(ang_vel_cam.y, ang_vel_cam.x))
	sm.set_shader_parameter("uWRoll", ang_vel_cam.z)
	sm.set_shader_parameter("uVibAmp", 0.00035 + 0.0016 * vibration)
	sm.set_shader_parameter("uVibFreq", TAU * (motor_hz * 0.071 + 17.0))
	sm.set_shader_parameter("uFrame", float(_frame))
	var glare := smoothstep(0.8, 0.98, fwd_dot) * (1.0 if in_view else 0.5)
	var wash := maxf(maxf(glare * 0.6, _sun_amt), _burst_wash * 0.8) * lerpf(0.3, 1.0, _over)
	sm.set_shader_parameter("uGlare", wash)
	var wbt := clampf((wb_kelvin - 5600.0) / 5600.0, -0.6, 0.6) * 0.62
	sm.set_shader_parameter("uWB", Vector3(1.0 + wbt, 1.0, 1.0 - wbt))
	sm.set_shader_parameter("uIso", pow(clampf(exposure / 3.5, 1.0, 16.0), 0.8) * noise_scale)
	sm.set_shader_parameter("uBloomK", (0.1 + 0.3 * _sun_amt) if bloom_on else 0.0)
	sm.set_shader_parameter("uSunVis", sun_vis)
	sm.set_shader_parameter("uRain", rain_lens)
	sm.set_shader_parameter("uAir", lens_air)
	sm.set_shader_parameter("uWash", lens_wash)
	sm.set_shader_parameter("uInView", 1.0 if in_view else 0.0)
	# session B: the firework bursts in the lens (see burst_glare)
	sm.set_shader_parameter("uBurstS", bpos)
	sm.set_shader_parameter("uBurstC", bcol)
	sm.set_shader_parameter("uBurstK", bk)
	sm.set_shader_parameter("uBurstWash", _burst_wash)
	sm.set_shader_parameter("uShutter", shutter_shown)
	sm.set_shader_parameter("uSpeed", drone_speed)
	sm.set_shader_parameter("uMotionBlur", 0.0 if simple else 1.0)
	# stages 5 and 6
	var ip: ShaderMaterial = _passes["isp"]
	ip.set_shader_parameter("uGlare", wash)
	ip.set_shader_parameter("uLook", look)
	# stage 7: two codec viewports take turns so the previous frame is available for stale macroblocks
	var cn := 1 - _codec_idx
	var cm: ShaderMaterial = _passes["codec%d" % cn]
	cm.set_shader_parameter("uBad", rf_bad if link_effects else 0.0); cm.set_shader_parameter("uFrame", float(_frame))
	cm.set_shader_parameter("uLink", 1.0 if link_effects else 0.0)
	_codec[cn].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_codec[_codec_idx].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_codec_idx = cn
	var out_tex := _codec[cn].get_texture()
	var bm: ShaderMaterial = screen.material
	bm.set_shader_parameter("uSrc", out_tex)
	var sz := screen.get_viewport_rect().size
	bm.set_shader_parameter("uAspectScreen", sz.x / maxf(sz.y, 1.0))
	bm.set_shader_parameter("uAspectSrc", float(out_w) / float(out_h))
	(_passes["hist"] as ShaderMaterial).set_shader_parameter("uSrc", out_tex)
	if _frame % 6 == 0: _readback()

## The rectangle of the screen the video frame occupies (for placing the on-screen display).
func frame_rect() -> Rect2:
	var sz := screen.get_viewport_rect().size
	var a := float(out_w) / float(out_h)
	var w := sz.x
	var h := sz.x / a
	if h > sz.y:
		h = sz.y; w = sz.y * a
	return Rect2((sz.x - w) * 0.5, (sz.y - h) * 0.5, w, h)

func _readback() -> void:
	if simple: return
	if DisplayServer.get_name() == "headless": return   # no real textures to read
	# metering: the weighted mean log luminance of the scene is in the red channel of the 1x1 reduce viewport
	var img: Image = null
	var rm: ShaderMaterial = _passes["reduce"]
	if rm.has_meta("vp"): img = (rm.get_meta("vp") as SubViewport).get_texture().get_image()
	if img != null and not img.is_empty():
		var ml: float = img.get_pixel(0, 0).r
		if is_finite(ml) and ml > -17.0 and ml < 8.0: _mean_log = ml      # a phone GPU that cannot hold the value gives nonsense: keep the last good reading
		var shutter := exposure / 200.0
		var iso := 100.0
		if shutter > 1.0 / 50.0:
			iso = clampf(100.0 * shutter * 50.0, 100.0, 1600.0); shutter = 1.0 / 50.0
		if shutter < 1.0 / 4000.0: shutter = 1.0 / 4000.0
		shutter_shown = shutter
		iso_shown = int(round(iso / 50.0)) * 50
	# luma histogram
	_hist_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var himg := _hist_vp.get_texture().get_image()
	if himg != null and not himg.is_empty():
		histogram.fill(0.0)
		for y in 36:
			for x in 64:
				var c := himg.get_pixel(x, y)
				var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				histogram[mini(63, int(lum * 64.0))] += 1.0
		for i in 64: histogram[i] /= 64.0 * 36.0

## The finished video frame as an image (what a photo saves), or null when there is nothing to read.
func capture() -> Image:
	if simple: return scene_vp.get_texture().get_image()
	if DisplayServer.get_name() == "headless" or _codec.is_empty(): return null
	return _codec[_codec_idx].get_texture().get_image()

# ------------------------------------------------------------------ depth of field and autofocus
## How much of the picture is in focus. The blur itself is the engine's depth-of-field pass on the 3D camera
## (CameraAttributesPractical: works on Forward+ and Mobile, reads the depth buffer itself, and runs on the HDR scene
## before exposure, so bright highlights spread into soft round discs). This code decides where the lens is focused and
## how big the blur circle is, from thin-lens optics:
##   circle of confusion on the sensor  c(d) = A * f / (S - f) * |d - S| / d,  aperture A = f / N
## for focus distance S, subject distance d, focal length f and f-number N, as a share of the sensor width. The focal
## length comes from the sensor width and the lens's horizontal field of view, f = w / (2 tan(hfov / 2)), so the wide
## lens has a much shorter focal length and far deeper focus. Behind the subject the blur levels off at A f / (S - f);
## at the hyperfocal distance H = f^2 / (N c_max) + f everything from H/2 to the horizon is sharp. So the far landscape
## only softens when the lens is focused close, and near things (grass under the lens, a branch) are what blur most.
## Blur depends only on depth, never on where a pixel is on the screen.
## Gimbal cameras autofocus on a point in the picture (the centre, or where the pilot tapped): probe rays against the
## terrain, trees and buildings, and a lightly damped spring in dioptres, so the focus overshoots a little and settles,
## slower in poor light. FPV action cameras have no autofocus: they are fixed at their hyperfocal distance, so almost
## everything is sharp. Manual focus sets the distance from a slider.
const OPTICS := {
	# w: sensor width in mm (the 16:9 video crop), c: largest acceptable blur circle in mm (sensor diagonal / 1500),
	# n: f-number, cap: largest blur radius as a share of the frame height,
	# af_hz / af_damp: autofocus speed and damping (lower damping hunts more); af_hz 0 = fixed focus
	"mini": {"w": 9.6, "c": 0.008, "n": 1.7, "cap": 0.008, "af_hz": 1.5, "af_damp": 0.5},       # 1/1.3-inch sensor, f/1.7
	"cinema": {"w": 36.0, "c": 0.03, "n": 2.8, "cap": 0.025, "af_hz": 1.9, "af_damp": 0.62},    # full frame, 24 mm f/2.8 prime
	"cinewhoop": {"w": 7.4, "c": 0.006, "n": 2.5, "cap": 0.006, "af_hz": 0.0, "af_damp": 1.0},  # 1/1.9-inch action camera, fixed focus
	"freestyle": {"w": 6.17, "c": 0.005, "n": 2.8, "cap": 0.006, "af_hz": 0.0, "af_damp": 1.0}, # 1/2.3-inch action camera, fixed focus
	"race": {"w": 4.8, "c": 0.004, "n": 2.0, "cap": 0.006, "af_hz": 0.0, "af_damp": 1.0},       # 1/3-inch FPV camera, fixed focus
}
## Cinematic: still real optics, just a full-frame sensor and a fast f/1.4 lens on every drone, with autofocus.
const OPTICS_CINEMATIC := {"w": 36.0, "c": 0.03, "n": 1.4, "cap": 0.03, "af_hz": 1.7, "af_damp": 0.55}
const DOF_PX_PER_AMOUNT := 100.0    # the engine's blur radius in scene pixels for an amount of 1 (measured; floor about 2 px)
const DOF_SHARP_PX := 0.6           # below this blur radius (scene pixels) leave it sharp (the engine adds about 1 px of its own)
const DOF_NEAR_REF := 0.35          # when focused far, the near blur is sized for things this close (m): grass, a branch
const AF_MIN := 0.3
const AF_MAX := 400.0
const AF_OBJ_REACH := 160.0         # trees and buildings further than this are focused as the far landscape anyway

var dof_mode := 1:                  # 0 off, 1 natural (from the airframe), 2 cinematic
	set(v):
		if v != dof_mode and v != 0: _reacquire()
		dof_mode = v
var manual_focus := false:          # MF: the distance comes from mf_distance
	set(v):
		if manual_focus and not v: _reacquire()
		if v: _release_subject("")
		manual_focus = v
var mf_distance := 10.0             # metres; AF_MAX or more means infinity
var focus_m := 30.0                 # where the lens is focused now, in metres (readout)
var focus_locked := false           # autofocus has settled on its subject
var focus_lock_age := 0.0           # seconds since it locked (for the box animation)
var focus_shown := false            # this camera has focus to show (autofocus or manual, depth of field on, first person)
var box_alpha := 0.0                # the focus box: shown while acquiring, then it fades away once locked
var box_uv := Vector2.ZERO          # where the box is, in the video frame: -1..1, +y up
var subject_held := false           # a tapped subject is being kept in focus
var subject_uv := Vector2.ZERO      # where that subject is in the frame now
var dof_blur_px := 0.0              # blur radius at infinity in scene pixels (readout)
var cinematic_blur := 0.0            # the ending pushes the lens past subtle and into a wash of blur
signal focus_message(text: String)  # short notes for the pilot ("Focus returned to centre")
var _subject_world := Vector3.ZERO
var _acquiring := true              # the box is up: hunting, or locked and about to fade
var _dof_attr: CameraAttributesPractical
var _dof_debug := false
var _dof_cal := 0.0
var _test_tap := Vector2(9, 9)      # test hook fp<x>_<y>: tap that frame point once the world is up
var _af_d := 1.0 / 30.0             # focus in dioptres (1/m) and its rate
var _af_v := 0.0
var _af_target := 1.0 / 30.0
var _af_t := 0.0
var _af_hits := PackedFloat32Array([30.0, 30.0, 30.0, 30.0, 30.0])
var _af_probe := 0
var _af_settle := 0.0
var _af_us := 0                     # time the last probe took, microseconds (debug)
var _last_airframe := ""
var _box: Control
var _terrain: Object
var _world: Object

## The ending deliberately overdoes the focus. Normal flight never touches this.
func set_cinematic_blur(amount: float) -> void:
	cinematic_blur = clampf(amount, 0.0, 1.0)

## The free walk after the story does not want an autofocus box and a readout floating over the valley.
func set_focus_overlay(on: bool) -> void:
	if _box != null:
		_box.visible = on
	if not on:
		focus_shown = false
		box_alpha = 0.0

func _setup_dof() -> void:
	_dof_attr = CameraAttributesPractical.new()
	_dof_attr.auto_exposure_enabled = false
	_dof_attr.dof_blur_far_enabled = false
	_dof_attr.dof_blur_near_enabled = false
	camera.attributes = _dof_attr
	# round bokeh like a real iris; the cheapest quality on phones
	RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)
	var mobile := RenderingServer.get_current_rendering_method() != "forward_plus"
	RenderingServer.camera_attributes_set_dof_blur_quality(RenderingServer.DOF_BLUR_QUALITY_LOW if mobile else RenderingServer.DOF_BLUR_QUALITY_MEDIUM, false)
	_box = preload("res://game/focus_box.gd").new()
	_box.pipe = self
	screen.add_child(_box)

## The AF or MF chip on the picture, in screen pixels (top middle, below the status bar). Tapping it releases a held
## subject, or makes the camera focus again at the centre.
func chip_rect() -> Rect2:
	var r := frame_rect()
	var fs := clampf(r.size.y * 0.024, 11.0, 18.0)
	var w := fs * 7.5
	var h := fs * 1.6
	var vp := screen.get_viewport_rect().size
	return Rect2(r.position.x + r.size.x * 0.5 - w * 0.5, maxf(r.position.y, vp.y * 0.175), w, h)

func _to_uv(pos: Vector2) -> Vector2:
	var r := frame_rect()
	return Vector2((pos.x - r.position.x) / r.size.x * 2.0 - 1.0, 1.0 - (pos.y - r.position.y) / r.size.y * 2.0)

## Where a world point is in the video frame (-1..1, +y up), or far outside when it is behind the camera.
func _project(p: Vector3) -> Vector2:
	var v := camera.global_transform.basis.inverse() * (p - camera.global_position)
	if v.z > -0.05: return Vector2(9.0, 9.0)
	var ty := tan(deg_to_rad(camera.fov * 0.5)) / s_over
	var tx := ty * float(out_w) / float(out_h)
	return Vector2(v.x / -v.z / tx, v.y / -v.z / ty)

## The box comes up and the lens hunts again (autofocus switched on, a tap, or the scene changed a lot).
func _reacquire() -> void:
	_acquiring = true
	focus_locked = false; _af_settle = 0.0
	_af_t = 0.0

func _release_subject(msg: String) -> void:
	if not subject_held: return
	subject_held = false
	_af_hits.fill(1.0 / maxf(_af_d, 1e-4))
	_reacquire()
	if msg != "": focus_message.emit(msg)

## A short tap or click on the picture (screen position in pixels). On the chip: let go of a held subject, or focus
## again. On the held subject's marker: let go of it. Anywhere else: find what is there and keep it in focus.
func focus_tap(pos: Vector2) -> void:
	if not focus_shown or manual_focus: return
	if chip_rect().grow(6.0).has_point(pos):
		if subject_held: _release_subject("Focus returned to centre")
		else: _reacquire()
		return
	var r := frame_rect()
	if not r.has_point(pos): return
	var uv := _to_uv(pos)
	if subject_held:
		var px := Vector2((uv.x - subject_uv.x) * r.size.x, (uv.y - subject_uv.y) * r.size.y) * 0.5
		if px.length() < 0.11 * r.size.y:
			_release_subject("Focus returned to centre")
			return
	if _terrain == null: return
	var d := _probe(_terrain, _world, uv)
	if d >= AF_MAX * 0.99:
		# nothing solid there (sky): focus on the far distance, still centred on that spot
		d = AF_MAX
	var b := camera.global_transform.basis
	var ty := tan(deg_to_rad(camera.fov * 0.5)) / s_over
	var tx := ty * float(out_w) / float(out_h)
	var dir := (-b.z + b.x * (uv.x * tx) + b.y * (uv.y * ty)).normalized()
	_subject_world = camera.global_position + dir * d
	subject_held = true
	subject_uv = uv
	_reacquire()

## Call once a frame before process_frame. `terrain` needs height(x, z); `world` its obstacle grids (_trunks, _cyls,
## _boxes, GRID). In the chase view the camera is not the drone's: it focuses on the drone itself.
func update_focus(dt: float, terrain: Object, world: Object, airframe_id: String, chase_view: bool, drone_pos: Vector3) -> void:
	if _dof_attr == null: return
	_terrain = terrain; _world = world
	if _test_tap.x < 5.0 and _frame == 150:
		var r0 := frame_rect()
		focus_tap(r0.position + Vector2((_test_tap.x * 0.5 + 0.5) * r0.size.x, (0.5 - _test_tap.y * 0.5) * r0.size.y))
	var dt_c := minf(dt, 0.1)
	if airframe_id != _last_airframe:
		_last_airframe = airframe_id; _release_subject(""); _reacquire()
	var o: Dictionary = OPTICS_CINEMATIC if dof_mode == 2 else OPTICS.get(airframe_id, OPTICS["mini"])
	if chase_view and dof_mode == 1: o = OPTICS["mini"]
	var fixed: bool = float(o["af_hz"]) <= 0.0 and not chase_view and not manual_focus
	var was_shown := focus_shown
	focus_shown = dof_mode != 0 and not chase_view and not fixed
	if focus_shown and not was_shown: _reacquire()
	if chase_view: _release_subject("")
	# focal length from the sensor width and the lens's horizontal field of view: the wide lens is far shorter
	var w_mm: float = o["w"]
	var tan_hx := _tan_half().x
	if chase_view: tan_hx = tan(deg_to_rad(camera.fov * 0.5)) / s_over * float(out_w) / float(out_h)
	var f_mm := w_mm / (2.0 * tan_hx)
	var n: float = o["n"]
	var c_max: float = o["c"]
	var hyper_m := (f_mm * f_mm / (n * c_max) + f_mm) / 1000.0
	# poor light makes contrast autofocus slow and hesitant: from the metered scene level
	var light := smoothstep(-6.4, -4.4, _mean_log)        # 1 bright day .. 0 dusk and night
	var af_hz: float = float(o["af_hz"]) * lerpf(0.4, 1.25, light)
	var damp: float = float(o["af_damp"]) * lerpf(0.75, 1.0, light)
	if chase_view:
		_af_target = 1.0 / clampf(camera.global_position.distance_to(drone_pos), AF_MIN, AF_MAX)
		af_hz = 2.0; damp = 0.8
	elif manual_focus:
		_af_target = 1.0 / clampf(mf_distance, AF_MIN, AF_MAX) if mf_distance < AF_MAX else 1.0 / AF_MAX
		af_hz = 4.0; damp = 1.0          # the focus ring follows the slider directly
	elif fixed:
		# fixed focus at the hyperfocal distance: everything from half of it to the horizon is acceptably sharp
		_af_target = 1.0 / clampf(hyper_m, AF_MIN, AF_MAX)
		_af_d = _af_target; _af_v = 0.0
	elif dof_mode != 0 and subject_held:
		# keep the tapped subject in focus: its distance as the drone moves, until it leaves the picture
		subject_uv = _project(_subject_world)
		if absf(subject_uv.x) > 1.0 or absf(subject_uv.y) > 1.0:
			_release_subject("Focus returned to centre")
		else:
			_af_target = 1.0 / clampf(camera.global_position.distance_to(_subject_world), AF_MIN, AF_MAX)
	elif dof_mode != 0:
		_af_t -= dt_c
		if _af_t <= 0.0:
			_af_t = 1.0 / 15.0       # the lens measures fifteen times a second, one probe ray at a time
			var t0 := Time.get_ticks_usec()
			# the middle of the focus area every other time, then each of its four corners in turn
			_af_probe = (_af_probe + 1) % 8
			var corner := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
			var slot := 0 if _af_probe % 2 == 0 else 1 + (_af_probe >> 1)
			var off := Vector2.ZERO
			if slot > 0: off += Vector2(0.05 * 9.0 / 16.0, 0.05) * 2.0 * corner[slot - 1]
			_af_hits[slot] = _probe(terrain, world, off)
			_af_us = Time.get_ticks_usec() - t0
			# centre-weighted: the middle counts twice, then the median, so a thin twig at a corner does not grab focus
			var arr: Array[float] = [_af_hits[0], _af_hits[0], _af_hits[1], _af_hits[2], _af_hits[3], _af_hits[4]]
			arr.sort()
			_af_target = 1.0 / (0.5 * (arr[2] + arr[3]))
	if not fixed:
		# a lightly damped spring in dioptres: it settles in a fraction of a second, overshooting a little (hunting)
		var wn := TAU * af_hz
		_af_v += (wn * wn * (_af_target - _af_d) - 2.0 * damp * wn * _af_v) * dt_c
		_af_d = clampf(_af_d + _af_v * dt_c, 1.0 / AF_MAX, 1.0 / AF_MIN)
	var s := 1.0 / _af_d
	focus_m = s
	# focus state: a big jump in subject distance (a new scene) means hunting again, with the box up
	var rel_err := absf(log(_af_d / _af_target))
	if focus_locked and rel_err > 0.45 and not manual_focus: _reacquire()
	if rel_err < 0.05 and absf(_af_v) < 0.25 * _af_d + 0.002: _af_settle += dt_c
	else: _af_settle = 0.0; focus_locked = false
	if not focus_locked and _af_settle > 0.12:
		focus_locked = true; focus_lock_age = 0.0
	focus_lock_age += dt_c
	# the box: up while acquiring, green once locked, then it fades out after about a second and a half
	box_uv = subject_uv if subject_held else Vector2.ZERO
	var want := 0.0
	if focus_shown and not manual_focus and _acquiring:
		want = 1.0
		if focus_locked and focus_lock_age > 1.5:
			want = 0.0
			if box_alpha < 0.02: _acquiring = false
	box_alpha = move_toward(box_alpha, want, dt_c * (6.0 if want > box_alpha else 2.2))
	# blur circle radius for a subject at infinity, A f / (S - f), in pixels of the scene viewport
	var k := minf(s_over, 1.45)
	var frame_w_px := float(out_w) * k / s_over          # the video frame's width, measured in scene pixels
	var coc_inf_mm := f_mm * f_mm / (n * maxf(s * 1000.0 - f_mm, 1.0))
	var a_px := 0.5 * coc_inf_mm / w_mm * frame_w_px
	dof_blur_px = a_px
	var cap_px: float = float(o["cap"]) * float(out_h) * k / s_over
	# the engine takes one blur size for near and far. Behind the subject the true blur levels off at a_px, so when the
	# far field blurs at all the size is a_px (it can never grow past it). When it does not (focused far, past about
	# H/2) the far field stays sharp and the size is set by how soft very near things get.
	var far_on := a_px >= DOF_SHARP_PX
	if _dof_cal > 0.0:     # test hook dofcal<amount>: everything past 1 m blurred by that engine amount, to measure it
		_dof_attr.dof_blur_amount = _dof_cal; _dof_attr.dof_blur_far_enabled = true; _dof_attr.dof_blur_near_enabled = false
		_dof_attr.dof_blur_far_distance = 0.5; _dof_attr.dof_blur_far_transition = 0.01
		return
	var kk := minf(a_px, cap_px) if far_on else minf(a_px * maxf(s / DOF_NEAR_REF - 1.0, 0.0), cap_px)
	var far_b := 0.0; var far_e := 0.0; var near_b := 0.0; var near_e := 0.0
	if dof_mode == 0 or kk < DOF_SHARP_PX:
		_dof_attr.dof_blur_far_enabled = false; _dof_attr.dof_blur_near_enabled = false
	else:
		_dof_attr.dof_blur_amount = kk / DOF_PX_PER_AMOUNT
		_dof_attr.dof_blur_far_enabled = far_on
		if far_on:
			# sharp until the blur passes the threshold; the engine's ramp is centred where the true blur is half of it
			far_b = s / maxf(1.0 - DOF_SHARP_PX / a_px, 0.02)
			var d_half := s / maxf(1.0 - 0.5 * kk / a_px, 0.02)
			far_e = maxf(2.0 * d_half - far_b, far_b * 1.6)
			_dof_attr.dof_blur_far_distance = far_b
			_dof_attr.dof_blur_far_transition = far_e - far_b
		# in front of the subject the blur grows as a_px (S/d - 1): sharp down to near_b, full size at near_e
		near_b = s / (1.0 + DOF_SHARP_PX / a_px)
		near_e = s / (1.0 + kk / a_px)
		_dof_attr.dof_blur_near_enabled = true
		_dof_attr.dof_blur_near_distance = near_b
		_dof_attr.dof_blur_near_transition = maxf(near_b - near_e, 0.01)
	if cinematic_blur > 0.001:
		# Everything outside a narrow strip is soft, and the strip itself is soft too. This is not a correct lens.
		_dof_attr.dof_blur_amount = 0.16 * cinematic_blur
		_dof_attr.dof_blur_far_enabled = true
		_dof_attr.dof_blur_far_distance = 0.35
		_dof_attr.dof_blur_far_transition = 0.6
		_dof_attr.dof_blur_near_enabled = true
		_dof_attr.dof_blur_near_distance = 0.12
		_dof_attr.dof_blur_near_transition = 0.2
	if _dof_debug and _frame % 30 == 0:
		print("dof: mode %d %s focus %.2f m (target %.2f) %s, f %.1f mm f/%.1f c %.3f mm, H %.2f m, light %.2f, blur at infinity %.2f px, size %.2f px (cap %.1f), far %s %.1f..%.1f, near %.2f..%.2f, probe %d us" % [dof_mode, "MF" if manual_focus else "AF", s, 1.0 / _af_target, "locked" if focus_locked else "hunting", f_mm, n, c_max, hyper_m, light, a_px, kk, cap_px, "on" if far_on else "off", far_b, far_e, near_e, near_b, _af_us])

## Distance along a ray through the video frame at `off` (-1..1, +y up) to the first solid thing: the ground, a tree
## trunk or crown, a monument or a building. The terrain is marched out in growing steps and halved in on the hit;
## objects are gathered once from the cells the ray crosses, so each step only tests the few that are near it.
func _probe(terrain: Object, world: Object, off: Vector2) -> float:
	var b := camera.global_transform.basis
	var ty := tan(deg_to_rad(camera.fov * 0.5)) / s_over
	var tx := ty * float(out_w) / float(out_h)
	var dir := (-b.z + b.x * (off.x * tx) + b.y * (off.y * ty)).normalized()
	var org := camera.global_position
	# 1: the ground
	var t_hit := AF_MAX
	var prev := AF_MIN
	var t := AF_MIN
	while t < AF_MAX:
		var p := org + dir * t
		if terrain.height(p.x, p.z) > p.y:
			var lo := prev; var hi := t
			for i in 6:
				var m := (lo + hi) * 0.5
				var pm := org + dir * m
				if terrain.height(pm.x, pm.z) > pm.y: hi = m
				else: lo = m
			t_hit = hi
			break
		prev = t
		t = t * 1.07 + 0.04
	if world == null: return clampf(t_hit, AF_MIN, AF_MAX)
	# 2: objects in front of that
	var reach := minf(t_hit, AF_OBJ_REACH)
	var trunks = world.get("_trunks")
	var cyls = world.get("_cyls")
	var boxes = world.get("_boxes")
	if trunks == null: return clampf(t_hit, AF_MIN, AF_MAX)
	var g: float = world.GRID
	var keys := {}
	var step := g * 0.5
	var u := 0.0
	while true:
		var q := org + dir * minf(u, reach)
		var kq := Vector2i(floori(q.x / g), floori(q.z / g))
		for a in range(-1, 2):
			for c in range(-1, 2):
				keys[Vector2i(kq.x + a, kq.y + c)] = true
		if u >= reach: break
		u += step
	var o2 := Vector2(org.x, org.z)
	var d2 := Vector2(dir.x, dir.z)
	var cand: Array = []           # [kind, data, t_in, t_out]: 0 tree, 1 cylinder, 2 box; the stretch of ray over it in plan
	var seen := {}
	for kk in keys:
		if trunks.has(kk):
			for tr in trunks[kk]:
				var span := _ray_circle(o2, d2, Vector2(float(tr[0]), float(tr[2])), maxf(0.34 * float(tr[4]), float(tr[3])), reach)
				if span.y > span.x: cand.append([0, tr, span.x, span.y])
		if cyls != null and cyls.has(kk):
			for cy in cyls[kk]:
				var span2 := _ray_circle(o2, d2, Vector2(float(cy[0]), float(cy[1])), float(cy[2]), reach)
				if span2.y > span2.x: cand.append([1, cy, span2.x, span2.y])
		if boxes != null and boxes.has(kk):
			for bx in boxes[kk]:
				var id: int = bx.hash()
				if seen.has(id): continue        # a big building sits in several cells
				seen[id] = true
				var span3 := _ray_box(o2, d2, Vector2(float(bx[0]), float(bx[1])), Vector2(float(bx[2]), float(bx[3])), reach)
				if span3.y > span3.x: cand.append([2, bx, span3.x, span3.y])
	if cand.is_empty(): return clampf(t_hit, AF_MIN, AF_MAX)
	cand.sort_custom(func(a, b): return a[2] < b[2])
	# march only through the stretches where the ray is over something, nearest first
	for e in cand:
		var one := [e]
		var t0: float = maxf(float(e[2]), AF_MIN)
		var t1: float = minf(float(e[3]), reach)
		if t0 >= t_hit: break
		var pv := t0
		var tt := t0
		while tt <= t1:
			if _obj_solid(one, org + dir * tt):
				var lo2 := pv; var hi2 := tt
				for i in 5:
					var m2 := (lo2 + hi2) * 0.5
					if _obj_solid(one, org + dir * m2): hi2 = m2
					else: lo2 = m2
				t_hit = minf(t_hit, hi2)
				break
			pv = tt
			tt += maxf(0.15, tt * 0.04)
	return clampf(t_hit, AF_MIN, AF_MAX)

## The stretch of a ray (plan view, parameter = distance along the 3D ray) that lies within a circle; empty when y <= x.
static func _ray_circle(o: Vector2, d: Vector2, c: Vector2, r: float, reach: float) -> Vector2:
	var rel := o - c
	var a := d.dot(d)
	if a < 1e-8:
		return Vector2(0.0, reach) if rel.length_squared() < r * r else Vector2(1.0, 0.0)
	var bh := rel.dot(d)
	var disc := bh * bh - a * (rel.length_squared() - r * r)
	if disc < 0.0: return Vector2(1.0, 0.0)
	var sq := sqrt(disc)
	return Vector2(maxf((-bh - sq) / a, 0.0), minf((-bh + sq) / a, reach))

static func _ray_box(o: Vector2, d: Vector2, lo: Vector2, hi: Vector2, reach: float) -> Vector2:
	var t0 := 0.0
	var t1 := reach
	for ax in 2:
		if absf(d[ax]) < 1e-8:
			if o[ax] < lo[ax] or o[ax] > hi[ax]: return Vector2(1.0, 0.0)
		else:
			var ta := (lo[ax] - o[ax]) / d[ax]
			var tb := (hi[ax] - o[ax]) / d[ax]
			t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
	return Vector2(t0, t1)

func _obj_solid(cand: Array, p: Vector3) -> bool:
	for e in cand:
		var v: Array = e[1]
		match int(e[0]):
			0:   # tree: [x, y, z, radius, height]; trunk, then the crown cone the sun test also uses
				var h: float = v[4]
				var dx: float = p.x - float(v[0]); var dz: float = p.z - float(v[2])
				var r2 := dx * dx + dz * dz
				if p.y < float(v[1]) or p.y > float(v[1]) + h: continue
				var tr: float = v[3]
				if r2 < tr * tr: return true
				var base: float = float(v[1]) + 0.35 * h
				if p.y < base: continue
				var crown := 0.34 * h * (1.0 - (p.y - base) / (0.65 * h))
				if r2 < crown * crown: return true
			1:   # cylinder: [x, z, r, y0, y1]
				if p.y < float(v[3]) or p.y > float(v[4]): continue
				var cx: float = p.x - float(v[0]); var cz: float = p.z - float(v[1])
				if cx * cx + cz * cz < float(v[2]) * float(v[2]): return true
			2:   # box: [x0, z0, x1, z1, y0, y1]
				if p.y >= float(v[4]) and p.y <= float(v[5]) and p.x >= float(v[0]) and p.x <= float(v[2]) and p.z >= float(v[1]) and p.z <= float(v[3]): return true
	return false
