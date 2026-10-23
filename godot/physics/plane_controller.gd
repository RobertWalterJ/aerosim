class_name PlaneController
extends RefCounted
## Flight controller for the fixed-wing plane. Sticks: throttle (left up/down), rudder (left left/right),
## elevator (right up/down), aileron (right left/right). Normal = stabilised (self-levelling, bank limit 45
## degrees, pitch 30); Sport and Manual = acro (rate control). A cruise assist holds altitude. RTH climbs to a
## safe height, flies to home, circles down and belly-lands. Writes plane.cmd = [throttle, elev, ail, rud].

const G := 9.80665

var af: Dictionary
var plane: FPVPlane
var mode := "N"
var heading := 0.0
var on_ground := false
var stick_throttle := 0.0

var cruise_assist := false
var _cruise_alt := 0.0
var _cruise_i := 0.0

# RTH state machine: 0 off, 1 climb, 2 cruise home, 3 circle down, 4 land
var rth := 0
var _home := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _i_pitch := 0.0
var _i_bank := 0.0
var _launch_t := 0.0

func _init(airframe: Dictionary, p: FPVPlane) -> void:
	af = airframe; plane = p
	_rng.seed = 77

func set_airframe(airframe: Dictionary) -> void:
	af = airframe

func reset_state() -> void:
	_i_pitch = 0.0; _i_bank = 0.0; _cruise_i = 0.0
	_launch_t = 3.0   # hold a gentle climb after a hand launch until the sticks take over

func set_step(_dt: float) -> void:
	pass

func thrust_fraction() -> float:
	return clampf(plane.cmd[0], 0.0, 1.0)

## Start return-to-home: remember the home point and climb.
func start_rth(home: Vector2, alt: float) -> void:
	_home = home
	_cruise_alt = alt
	rth = 1

func cancel_rth() -> void:
	rth = 0

## The plane's pitch angle (rad, nose up positive) and bank angle (rad, right wing down positive).
func _angles() -> Vector2:
	var q := plane.attitude()
	var fwd := q * Vector3(0, 0, -1)
	var right := q * Vector3(1, 0, 0)
	return Vector2(asin(clampf(fwd.y, -1.0, 1.0)), asin(clampf(-right.y, -1.0, 1.0)))

func update(dt: float, throttle: float, yaw: float, pitch: float, roll: float) -> void:
	if not plane.armed:
		plane.cmd.fill(0.0)
		return
	stick_throttle = (throttle + 1.0) * 0.5
	# just after a hand launch: hold a gentle climb for three seconds, then hand control to the sticks
	if _launch_t > 0.0:
		_launch_t -= dt
		plane.cmd[0] = 0.6
		plane.cmd[1] = clampf(0.14 - plane.rates().x * 0.2, -1.0, 1.0)
		plane.cmd[2] = clampf(-_angles().y * 1.2, -1.0, 1.0)
		plane.cmd[3] = 0.0
		return
	# RTH overrides the sticks
	if rth > 0:
		_rth_step(dt)
		return
	var a := _angles()
	var pt := a.x
	var bk := a.y
	var w := plane.rates()
	var elev := 0.0
	var ail := 0.0
	var rud := -yaw
	if mode == "N":
		# stabilised: self-levelling to a stick-commanded pitch and bank, with limits
		var pitch_sp := -pitch * 0.52              # +pitch stick = nose down; about 30 degrees
		var bank_sp := roll * 0.785                # about 45 degrees
		if cruise_assist:
			pitch_sp += _cruise_hold(dt)
		var ep := pitch_sp - pt
		_i_pitch = clampf(_i_pitch + ep * dt * 0.6, -0.4, 0.4)
		elev = 1.8 * ep + _i_pitch - 0.25 * w.x
		var eb := bank_sp - bk
		_i_bank = clampf(_i_bank + eb * dt * 0.6, -0.4, 0.4)
		ail = 1.4 * eb + _i_bank - 0.15 * w.z
		# a little rudder to coordinate the turn into the bank
		rud = 0.5 * bk
	else:
		# acro: rate control
		var p_rate := -pitch * 2.4                # rad/s, +stick = nose down
		var r_rate := -roll * 3.6                 # rad/s, +stick = roll right
		elev = 0.9 * (p_rate - w.x)
		ail = 0.7 * (r_rate - w.z)
		rud = -yaw * 1.6
	plane.cmd[0] = stick_throttle
	plane.cmd[1] = clampf(elev, -1.0, 1.0)
	plane.cmd[2] = clampf(ail, -1.0, 1.0)
	plane.cmd[3] = clampf(rud, -1.0, 1.0)

func _cruise_hold(dt: float) -> float:
	# hold altitude with a pitch correction and a slow throttle trim
	var p := plane.position()
	var alt := p.y
	_cruise_i = clampf(_cruise_i + (_cruise_alt - alt) * dt * 0.15, -0.2, 0.2)
	stick_throttle = clampf(0.42 + _cruise_i, 0.25, 0.75)
	return clampf((_cruise_alt - alt) * 0.03 - plane.s[4] * 0.08, -0.25, 0.25)

## RTH: climb to a safe height, fly to home, circle down, belly-land. Called from update() when rth > 0.
func _rth_step(dt: float) -> void:
	var p := plane.position()
	var alt := p.y - plane._gh0
	var to_home := _home - Vector2(p.x, p.z)
	var dist := to_home.length()
	var w := plane.rates()
	var a := _angles()
	match rth:
		1:  # climb to a safe height (about 80 m)
			plane.cmd[0] = 0.7
			plane.cmd[1] = clampf(-(a.x - 0.25) * 1.5 - 0.25 * w.x, -1.0, 1.0)
			plane.cmd[2] = clampf(-a.y * 1.4 - 0.15 * w.z, -1.0, 1.0)
			plane.cmd[3] = 0.0
			if alt > 80.0: rth = 2
		2:  # fly to home, then circle down
			var target := atan2(to_home.x, to_home.y)   # world heading toward home (home heading convention)
			var fwd := plane.attitude() * Vector3(0, 0, -1)
			var hdg := atan2(-fwd.x, -fwd.z)
			var err := wrapf(target - hdg, -PI, PI)
			plane.cmd[0] = 0.55
			plane.cmd[1] = clampf(-(a.x - 0.08) * 1.5 - 0.25 * w.x, -1.0, 1.0)
			plane.cmd[2] = clampf(-err * 0.9 - 0.15 * w.z, -1.0, 1.0)
			plane.cmd[3] = clampf(err * 0.8, -1.0, 1.0)
			if dist < 90.0: rth = 3
		3:  # circle down over home
			plane.cmd[0] = 0.35
			plane.cmd[1] = clampf(-(a.x - 0.06) * 1.5 - 0.25 * w.x, -1.0, 1.0)
			plane.cmd[2] = clampf(-0.55 - a.y * 1.2 - 0.15 * w.z, -1.0, 1.0)   # hold a steady left bank to circle
			plane.cmd[3] = 0.3
			if alt < 4.0: rth = 4
		_:  # final belly landing
			plane.cmd[0] = 0.0
			plane.cmd[1] = clampf(-(a.x - 0.12) * 1.6 - 0.3 * w.x, -1.0, 1.0)
			plane.cmd[2] = clampf(-a.y * 1.6 - 0.2 * w.z, -1.0, 1.0)
			plane.cmd[3] = 0.0
			if plane.on_ground and plane.s[4] > -0.3:
				plane.cmd[1] = 0.6   # flare and hold
				plane.armed = false
				rth = 0

func tilt_error() -> float:
	var a := _angles()
	return absf(a.x) + absf(a.y)

func _gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0: u = _rng.randf()
	while v == 0.0: v = _rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)
