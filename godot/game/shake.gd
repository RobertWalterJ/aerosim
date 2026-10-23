class_name CamShake
extends RefCounted
## Camera buffeting in rough air, applied to the first-person camera after main.gd has placed it.
## A gimbal camera (Mini, Cinema) is stabilised: it keeps only a tiny residual (the gimbal lags the frame by a few
## milliseconds) and a faint jitter. A fixed FPV camera already shows the whole frame wobble, because it is bolted to
## the frame; it gets a little extra vibration on top. Smooth noise in time, so it does not depend on the frame rate.
## Rotation is capped (1.5 degrees on a gimbal, 4 on FPV) so it never makes anyone feel sick.
## "Camera shake": Off / Natural.

var enabled := true
var vibration := 0.0          # 0..1 extra vibration for the sensor (jello, rolling shutter)
var amount_deg := 0.0         # the rotation applied this frame, for logs and tests
var _noise := FastNoiseLite.new()
var _t := 0.0
var _level := 0.0
var _log := OS.get_cmdline_user_args().has("windlog")
var _log_t := 0.0
var _log_pk := 0.0

const GIMBAL_CAP := 1.5
const FPV_CAP := 4.0
const GIMBAL_LAG := 0.004     # seconds the gimbal motors lag the frame

func _init() -> void:
	_noise.seed = 77
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0

## turb, burst: 0..1 from Wind. rates: the drone's body rates (rad/s, body frame). gimbal: true for a stabilised camera.
func apply(cam: Camera3D, dt: float, turb: float, burst: float, rates: Vector3, gimbal: bool) -> void:
	_t += dt
	if not enabled:
		vibration = 0.0; amount_deg = 0.0
		return
	# ease the level so a gust spell swells and fades rather than switching on
	var target := turb * (0.45 + 0.55 * burst)
	_level += (target - _level) * (1.0 - exp(-dt / 0.3))
	var lv := _level
	# jitter: two bands of smooth noise, a quick buzz (about 9 per second) and a slower knock (about 2.5 per second)
	var jx := 0.6 * _noise.get_noise_2d(_t * 9.0, 1.0) + 0.4 * _noise.get_noise_2d(_t * 2.5, 11.0)
	var jy := 0.6 * _noise.get_noise_2d(_t * 9.0, 21.0) + 0.4 * _noise.get_noise_2d(_t * 2.5, 31.0)
	var jz := 0.6 * _noise.get_noise_2d(_t * 9.0, 41.0) + 0.4 * _noise.get_noise_2d(_t * 2.5, 51.0)
	var rot := Vector3.ZERO
	var cap := FPV_CAP
	if gimbal:
		cap = GIMBAL_CAP
		rot = Vector3(jx, 0.5 * jy, jz) * deg_to_rad(0.6) * lv
		rot += Vector3(rates.x, 0.0, rates.z) * GIMBAL_LAG     # residual: the gimbal is a few milliseconds behind the frame
		vibration = 0.10 * lv
	else:
		rot = Vector3(jx, 0.5 * jy, jz) * deg_to_rad(1.6) * lv
		vibration = 0.35 * lv
	var c := deg_to_rad(cap)
	rot = rot.clamp(Vector3(-c, -c, -c), Vector3(c, c, c))
	amount_deg = rad_to_deg(rot.length())
	if _log:
		_log_t += dt; _log_pk = maxf(_log_pk, amount_deg)
		if _log_t >= 1.0:
			print("shakelog level %.2f peak %.2f deg vibration %.2f" % [_level, _log_pk, vibration]); _log_t = 0.0; _log_pk = 0.0
	if amount_deg < 0.001: return
	var off := Vector3(jy, jx, 0.0) * (0.003 if gimbal else 0.006) * lv
	var xf := cam.global_transform
	xf.origin += xf.basis * off
	xf.basis = xf.basis * Basis.from_euler(rot)
	cam.global_transform = xf
