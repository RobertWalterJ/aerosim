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
var _over := 0.0
var _log_e := 0.0                    # log2 exposure the camera has adapted to
var _mean_log := -2.9                # latest metered mean log luminance of the scene
var wb_kelvin := 5600.0              # the white balance the camera has settled on
var _sun_amt := 0.0                  # how much sun is in the picture, 0..1, eased
var bloom_on := true
var rain_lens := 0.0                # water on the lens, 0..1
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

var camera: Camera3D
var scene_vp: SubViewport
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
	_frame += 1
	var tan_half := _tan_half()
	# stage 2: metering and adaptation. Two 1x1 viewports take turns, each reading the other's result.
	# the sun in the picture: it washes the frame out, then the camera stops down and its auto white balance swings cooler
	var cb0 := camera.global_transform.basis
	var sun_target := smoothstep(0.86, 0.99, (-cb0.z).dot(_sun_world)) * sun_vis
	_sun_amt += (sun_target - _sun_amt) * (1.0 - exp(-minf(dt, 0.1) / (0.12 if sun_target > _sun_amt else 0.7)))
	var wb_target := 5600.0 - 2300.0 * _sun_amt
	wb_kelvin += (wb_target - wb_kelvin) * (1.0 - exp(-minf(dt, 0.1) / (0.9 if wb_target < wb_kelvin else 2.0)))
	# the camera's exposure follows the metered scene, slowly: it opens up quickly in the dark, and is slow to stop down
	# when bright light arrives, so the picture stays washed out for a moment before it settles. Worked out here, not in a shader.
	var tgt := clampf(log(0.13) / log(2.0) - _mean_log + ev_comp - 0.8 * _sun_amt, log(0.1) / log(2.0), log(3.0) / log(2.0))
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
	var wash := maxf(glare * 0.6, _sun_amt) * lerpf(0.3, 1.0, _over)
	sm.set_shader_parameter("uGlare", wash)
	var wbt := clampf((wb_kelvin - 5600.0) / 5600.0, -0.6, 0.6) * 0.62
	sm.set_shader_parameter("uWB", Vector3(1.0 + wbt, 1.0, 1.0 - wbt))
	sm.set_shader_parameter("uIso", pow(clampf(exposure / 3.5, 1.0, 16.0), 0.8) * noise_scale)
	sm.set_shader_parameter("uBloomK", (0.1 + 0.3 * _sun_amt) if bloom_on else 0.0)
	sm.set_shader_parameter("uSunVis", sun_vis)
	sm.set_shader_parameter("uRain", rain_lens)
	sm.set_shader_parameter("uInView", 1.0 if in_view else 0.0)
	# stages 5 and 6
	var ip: ShaderMaterial = _passes["isp"]
	ip.set_shader_parameter("uGlare", wash)
	# stage 7: two codec viewports take turns so the previous frame is available for stale macroblocks
	var cn := 1 - _codec_idx
	var cm: ShaderMaterial = _passes["codec%d" % cn]
	cm.set_shader_parameter("uBad", rf_bad if link_effects else 0.0); cm.set_shader_parameter("uFrame", float(_frame))
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
	if DisplayServer.get_name() == "headless": return   # no real textures to read
	# metering: the weighted mean log luminance of the scene is in the red channel of the 1x1 reduce viewport
	var img: Image = null
	var rm: ShaderMaterial = _passes["reduce"]
	if rm.has_meta("vp"): img = (rm.get_meta("vp") as SubViewport).get_texture().get_image()
	if img != null and not img.is_empty():
		_mean_log = img.get_pixel(0, 0).r
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
	if DisplayServer.get_name() == "headless" or _codec.is_empty(): return null
	return _codec[_codec_idx].get_texture().get_image()
