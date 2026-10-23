class_name FlightController
extends RefCounted
## Cascaded controller ported from FlightControllerPID.ts:
## velocity (100 Hz) -> attitude (250 Hz) -> rate PID (every step) -> motor mixer.
## N (Normal) and S (Sport): velocity and altitude hold with a bank limit. M (Manual): acro rates with airmode.
## Sticks are -1..1: pitch +1 = forward, roll +1 = right, throttle +1 = climb, yaw +1 = turn right.

const G := 9.80665

var mode := "N"
var af: Dictionary
var quad: Quad
var hover_throttle := 0.0
var heading := 0.0
var tilt := 0.0
var on_ground := false
var stick_throttle := 0.0

var _tick := 0
var _gyro := Vector3.ZERO
var _rate_sp := Vector3.ZERO
var _i_term := Vector3.ZERO
var _prev_gyro := Vector3.ZERO
var _d_filt := Vector3.ZERO
var _vel_i := Vector2.ZERO          # (forward, right)
var _thrust_cmd := 0.0
var _tilt_sp := Vector2.ZERO        # (pitch, roll)
var _yaw_rate_sp := 0.0
var _alt_i := 0.0
var _a_z := 0.0
var _rng := RandomNumberGenerator.new()
# GPS position hold (Normal and Sport, sticks centred): a gust pushes the drone off its spot, then it flies back
var pos_hold := true
var holding := false
var saturated := false               # the velocity loop asked for more bank than the mode allows (wind too strong)
var _hold := Vector2.ZERO            # (x, z) of the held spot
var _last_xz := Vector2.ZERO
# steps between loop updates; set from the physics step so the loops keep their real-time rates
var vel_every := 10
var att_every := 4

func _init(airframe: Dictionary, q: Quad) -> void:
	af = airframe; quad = q
	hover_throttle = sqrt(1.0 / float(af["twr"]))
	_rng.seed = 99

func set_airframe(airframe: Dictionary) -> void:
	af = airframe
	hover_throttle = sqrt(1.0 / float(af["twr"]))

func reset_state() -> void:
	_i_term = Vector3.ZERO; _vel_i = Vector2.ZERO; _alt_i = 0.0; _tilt_sp = Vector2.ZERO
	holding = false; saturated = false

## Set the loop rates from the physics step length (the web version runs 1 ms steps: 100 Hz and 250 Hz loops).
func set_step(dt: float) -> void:
	vel_every = maxi(1, roundi(0.01 / dt))
	att_every = maxi(1, roundi(0.004 / dt))

func _lim() -> Dictionary:
	return af["limits"]["S" if mode == "S" else "N"]

static func _sh(x: float) -> float:
	var dz := 0.04
	return 0.0 if absf(x) < dz else (x - signf(x) * dz) / (1.0 - dz)

## Betaflight-like rate curve (rad/s)
func _acro_rate(x: float) -> float:
	var rc: float = af["ratesRc"]; var sr: float = af["ratesSuper"]; var ex: float = af["ratesExpo"]
	var xr := 0.0 if absf(x) < 1e-6 else signf(x) * (pow(absf(x), 3.0) * ex + absf(x) * (1.0 - ex))
	var base := 200.0 * rc * xr
	var f := 1.0 / clampf(1.0 - absf(xr) * sr, 0.01, 1.0)
	return deg_to_rad(base * f)

func update(dt: float, throttle: float, yaw: float, pitch: float, roll: float) -> void:
	var s := quad.s
	if not quad.armed:
		quad.cmd.fill(0.0)
		return
	_tick += 1
	# gyro measurement: true rate + noise through a ~180 Hz low-pass
	var gn := 0.002
	var a := dt / (dt + 1.0 / (TAU * 180.0))
	_gyro.x += a * (s[10] + gn * _gauss() - _gyro.x)
	_gyro.y += a * (s[11] + gn * _gauss() - _gyro.y)
	_gyro.z += a * (s[12] + gn * _gauss() - _gyro.z)
	var q := Quaternion(s[6], s[7], s[8], s[9])
	var f := q * Vector3(0, 0, -1)
	var up := q * Vector3(0, 1, 0)
	tilt = acos(clampf(up.y, -1.0, 1.0))
	heading = atan2(-f.x, -f.z)
	if mode != "M":
		if _tick % vel_every == 0: _velocity_loop(dt * vel_every, throttle, yaw, pitch, roll)
		if _tick % att_every == 0: _attitude_loop()
	else:
		_acro_setpoint(throttle, yaw, pitch, roll)
	_rate_loop(dt)

func _velocity_loop(dt: float, throttle: float, yaw: float, pitch: float, roll: float) -> void:
	var s := quad.s
	var lim := _lim()
	var cos_h := cos(heading)
	var sin_h := sin(heading)
	# heading-frame velocities. forward = (-sinH, -cosH) in (x, z); right = (cosH, -sinH)
	var v_f: float = s[3] * -sin_h + s[5] * -cos_h
	var v_r: float = s[3] * cos_h + s[5] * -sin_h
	var sp_f := _sh(pitch) * float(lim["vH"])
	var sp_r := _sh(roll) * float(lim["vH"])
	# position hold: capture the spot once the drone has stopped with the sticks centred; fly back to it
	var xz := Vector2(s[0], s[2])
	var centred := absf(pitch) < 0.05 and absf(roll) < 0.05
	if not pos_hold or not centred or on_ground or xz.distance_to(_last_xz) > 2.0:
		holding = false       # a stick moved, the drone is landed, or it was moved by a reset
	elif not holding and sqrt(s[3] * s[3] + s[5] * s[5]) < 0.6:
		holding = true; _hold = xz
	_last_xz = xz
	if holding:
		var e := _hold - xz
		if e.length() > 20.0:     # blown far away: keep trying from 20 m, do not race back from further
			_hold = xz + e.normalized() * 20.0; e = _hold - xz
		var kp := 0.9 if mode == "N" else 0.6
		var v_back := (e * kp).limit_length(2.5)
		sp_f += v_back.x * -sin_h + v_back.y * -cos_h
		sp_r += v_back.x * cos_h + v_back.y * -sin_h
	var kv: float = lim["kv"]
	var a_f := kv * (sp_f - v_f)
	var a_r := kv * (sp_r - v_r)
	# integral for wind rejection when the sticks are centred
	if absf(pitch) < 0.05 and absf(roll) < 0.05 and sqrt(v_f * v_f + v_r * v_r) < 2.0:
		_vel_i.x = clampf(_vel_i.x + 0.5 * (sp_f - v_f) * dt, -2.0, 2.0)
		_vel_i.y = clampf(_vel_i.y + 0.5 * (sp_r - v_r) * dt, -2.0, 2.0)
	else:
		_vel_i *= pow(0.97, dt / 0.01)
	a_f += clampf(_vel_i.x, -2.0, 2.0); a_r += clampf(_vel_i.y, -2.0, 2.0)
	var a_max := G * tan(float(lim["bank"]))
	var mag := sqrt(a_f * a_f + a_r * a_r)
	saturated = mag > a_max * 0.98
	if mag > a_max:
		a_f *= a_max / mag; a_r *= a_max / mag
	_tilt_sp.x = -atan2(a_f, G)    # nose down for forward acceleration
	_tilt_sp.y = -atan2(a_r, G)    # negative = right side down
	# vertical
	var vz_sp := _sh(throttle) * (float(lim["vUp"]) if throttle > 0.0 else float(lim["vDown"]))
	var a_z := 3.2 * (vz_sp - s[4])
	_alt_i = clampf(_alt_i + 2.6 * (vz_sp - s[4]) * dt, -3.0, 3.0)
	_a_z = a_z + _alt_i
	var cos_t := clampf(cos(tilt), 0.55, 1.0)
	_thrust_cmd = (float(af["mass"]) * (G + _a_z)) / cos_t
	if on_ground and throttle < 0.08 and vz_sp <= 0.01:
		_thrust_cmd = float(af["mass"]) * G * 0.78
		_tilt_sp = Vector2.ZERO; _alt_i = 0.0; _vel_i = Vector2.ZERO
	_yaw_rate_sp = -_sh(yaw) * float(lim["yawRate"])   # stick right = clockwise from above = negative about +Y

func _attitude_loop() -> void:
	var s := quad.s
	var qd := Quaternion(Vector3.UP, heading) * Quaternion(Vector3.RIGHT, _tilt_sp.x) * Quaternion(Vector3(0, 0, 1), _tilt_sp.y)
	var qc := Quaternion(-s[6], -s[7], -s[8], s[9])
	var qe := qc * qd   # error in the body frame
	var sg := -1.0 if qe.w < 0.0 else 1.0
	var p: float = af["gain"]["attP"]
	_rate_sp.x = 2.0 * sg * qe.x * p
	_rate_sp.z = 2.0 * sg * qe.z * p
	_rate_sp.y = _yaw_rate_sp

func _acro_setpoint(throttle: float, yaw: float, pitch: float, roll: float) -> void:
	_rate_sp.x = -_acro_rate(pitch)    # stick forward = nose down
	_rate_sp.z = -_acro_rate(roll)     # stick right = right side down
	_rate_sp.y = -_acro_rate(yaw) * 0.8
	var u := _throttle_curve(throttle)
	_thrust_cmd = 4.0 * quad.rotor.Tmax * u * u
	stick_throttle = u

func _throttle_curve(x: float) -> float:
	var uh := hover_throttle
	var n := uh * (0.08 + 0.92 * (1.0 + x)) if x < 0.0 else uh + x * (1.0 - uh)
	return clampf(n, 0.06, 1.0)

func _rate_loop(dt: float) -> void:
	var g: Dictionary = af["gain"]
	var p := [float(g["rateP"]), float(g["yawP"]), float(g["rateP"])]
	var ki := [float(g["rateI"]), float(g["rateI"]) * 0.6, float(g["rateI"])]
	var inertia: Vector3 = af["I"]
	var gyro := [_gyro.x, _gyro.y, _gyro.z]
	var sp := [_rate_sp.x, _rate_sp.y, _rate_sp.z]
	var it := [_i_term.x, _i_term.y, _i_term.z]
	var pg := [_prev_gyro.x, _prev_gyro.y, _prev_gyro.z]
	var df := [_d_filt.x, _d_filt.y, _d_filt.z]
	var ii := [inertia.x, inertia.y, inertia.z]
	var tau := [0.0, 0.0, 0.0]
	for i in 3:
		var e: float = sp[i] - gyro[i]
		it[i] = clampf(it[i] + e * ki[i] * dt, -40.0, 40.0)
		var d_meas: float = (gyro[i] - pg[i]) / dt
		df[i] += 0.12 * (d_meas - df[i])
		pg[i] = gyro[i]
		var acc: float = p[i] * e + it[i] - float(g["rateD"]) * df[i]
		tau[i] = acc * ii[i]
	_i_term = Vector3(it[0], it[1], it[2]); _prev_gyro = Vector3(pg[0], pg[1], pg[2]); _d_filt = Vector3(df[0], df[1], df[2])
	_mix(_thrust_cmd, tau)

func _mix(tc: float, tau: Array) -> void:
	var d: float = af["armD"]
	var kq := quad.rotor.kq
	var t_max := quad.rotor.Tmax
	var cap := quad.omega_cap() / float(af["omegaMax"])   # battery-limited fraction of omegaMax
	var t_max_eff := t_max * cap * cap
	var ti := [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		var r := quad.rpos[i]
		ti[i] = tc / 4.0 + (r.x * tau[2]) / (4.0 * d * d) + (-r.z * tau[0]) / (4.0 * d * d) + (-Quad.SPIN[i] * tau[1]) / (4.0 * kq)
	# airmode-style desaturation: shift to keep differential authority
	var mn := minf(minf(ti[0], ti[1]), minf(ti[2], ti[3]))
	var mx := maxf(maxf(ti[0], ti[1]), maxf(ti[2], ti[3]))
	var idle := 0.0036 * t_max
	if mn < idle:
		var sh := idle - mn
		for i in 4: ti[i] += sh
		mx += sh
	if mx > t_max_eff:
		var sh2 := mx - t_max_eff
		for i in 4: ti[i] -= sh2
	for i in 4:
		var t := clampf(ti[i], idle, t_max_eff)
		quad.cmd[i] = sqrt(t / quad.rotor.kT)

## True when position hold is at the bank limit and still being pushed more than 3 m off its spot.
func losing_hold() -> bool:
	return holding and saturated and _hold.distance_to(_last_xz) > 3.0

## Angle (rad) between where the controller wants the drone's top to point and where it points: the uncommanded wobble.
func tilt_error() -> float:
	var qd := Quaternion(Vector3.RIGHT, _tilt_sp.x) * Quaternion(Vector3(0, 0, 1), _tilt_sp.y)
	var want := Quaternion(Vector3.UP, heading) * qd * Vector3.UP
	var up := quad.attitude() * Vector3.UP
	return acos(clampf(want.dot(up), -1.0, 1.0))

func thrust_fraction() -> float:
	return _thrust_cmd / (4.0 * quad.rotor.Tmax)

func _gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0: u = _rng.randf()
	while v == 0.0: v = _rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)
