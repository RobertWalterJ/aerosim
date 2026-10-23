extends SceneTree
## Headless check of the fixed-wing plane physics and controller. Prints PASS/FAIL and the measured numbers.
## Run: Godot_console.exe --headless --path godot -s test/plane_test.gd

const DT := 0.002
const SUB := 4
var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

func _ground_h(_x: float, _z: float) -> float: return 0.0
func _ground_n(_x: float, _z: float) -> Vector3: return Vector3.UP

## Build a hand-launched plane: 3 m up, 10 m/s along the heading, nose up 10 degrees.
func make_plane(heading: float, x := 0.0, z := 0.0) -> Array:
	var af := Airframes.make("wing")
	var p := FPVPlane.new(af)
	var fc := PlaneController.new(af, p)
	fc.set_step(DT); fc.mode = "N"
	p.ground_h = _ground_h; p.ground_n = _ground_n
	p.obstacle_hit = func(_a: float, _b: float, _c: float, _d: float) -> Vector3: return Vector3.INF
	var q := Quaternion(Vector3.UP, heading)
	p.reset(x, 40.0, z, heading)
	p.s[6] = q.x; p.s[7] = q.y; p.s[8] = q.z; p.s[9] = q.w
	var fwd := q * Vector3(0, 0, -1)
	p.s[3] = fwd.x * 18.0; p.s[4] = fwd.y * 18.0; p.s[5] = fwd.z * 18.0
	p.s[13] = float(af["omegaMax"]) * 0.5
	fc.heading = heading
	return [p, fc]

func tick(p: FPVPlane, fc: PlaneController, t: float, st: Vector4) -> void:
	p.wind = Vector3.ZERO
	var agl := p.position().y
	fc.on_ground = agl < 0.15
	for i in SUB:
		fc.update(DT, st.x, st.y, st.z, st.w)
		p.step(DT)
		t += DT

func _init() -> void:
	# 1. level trim at cruise: hold altitude within 3 m for 60 s in calm
	var a := make_plane(0.0)
	var p: FPVPlane = a[0]; var fc: PlaneController = a[1]
	fc.cruise_assist = true
	var t := 0.0
	var alt0 := p.position().y
	var max_dev := 0.0
	for k in int(60.0 / (DT * SUB)):
		tick(p, fc, t, Vector4(0.0, 0.0, 0.0, 0.0)); t += DT * SUB
		max_dev = maxf(max_dev, absf(p.position().y - alt0))
		if p.crashed: break
	check("level trim at cruise (60 s)", not p.crashed and max_dev < 3.0 and p.airspeed > 8.0, "alt dev %.1f m, airspeed %.1f m/s, crashed=%s" % [max_dev, p.airspeed, p.crashed])

	# 2. stall recovery: a nose-down command recovers airspeed in under 3 s with under 40 m lost
	var b := make_plane(0.0)
	var p2: FPVPlane = b[0]; var fc2: PlaneController = b[1]
	var t2 := 0.0
	for k in int(10.0 / (DT * SUB)):
		tick(p2, fc2, t2, Vector4(-0.8, 0.0, -1.0, 0.0)); t2 += DT * SUB   # cut throttle and pull up (pitch -1 = nose up) to stall
		if p2.crashed: break
	var alt_stall := p2.position().y
	var t_rec := 0.0
	var lost := 0.0
	while t_rec < 3.0 and p2.airspeed < 12.0 and not p2.crashed:
		tick(p2, fc2, t2, Vector4(0.6, 0.0, 0.5, 0.0)); t2 += DT * SUB; t_rec += DT * SUB   # throttle + nose down (pitch +0.5) to recover
		lost = maxf(lost, alt_stall - p2.position().y)
	check("stall recovery under 3 s", t_rec < 3.0 and lost < 40.0 and not p2.crashed, "recover %.2f s, lost %.1f m, crashed=%s" % [t_rec, lost, p2.crashed])

	# 3. bank turn: hold a 30 degree bank and finish a 360 turn with the right radius
	var c := make_plane(0.0)
	var p3: FPVPlane = c[0]; var fc3: PlaneController = c[1]
	fc3.cruise_assist = true
	var t3 := 0.0
	for k in int(8.0 / (DT * SUB)):
		tick(p3, fc3, t3, Vector4(0.0, 0.0, 0.0, 0.0)); t3 += DT * SUB   # settle level
	var v := p3.airspeed
	var r_pred := v * v / (9.80665 * tan(deg_to_rad(30.0)))
	var turned := 0.0
	var hdg0 := 0.0
	var hdg := 0.0
	var first := true
	var t_turn := 0.0
	while turned < TAU * 0.98:
		tick(p3, fc3, t3, Vector4(0.0, 0.0, 0.0, 0.667)); t3 += DT * SUB   # roll stick to a 30 degree bank
		var vel := p3.velocity()
		hdg = atan2(-vel.x, -vel.z)   # measure the velocity turn, not the nose (which oscillates in a slip)
		if first: hdg0 = hdg; first = false
		else: turned += absf(wrapf(hdg - hdg0, -PI, PI)); hdg0 = hdg
		t_turn += DT * SUB
		if t3 > 120.0 or p3.crashed: break
	var radius := v * t_turn / (2.0 * PI) if (turned > TAU * 0.98 and not p3.crashed) else 999.0
	check("360 bank turn radius", not p3.crashed and turned > TAU * 0.98 and absf(radius - r_pred) < 0.2 * r_pred, "r %.1f m (pred %.1f m), crashed=%s" % [radius, r_pred, p3.crashed])

	# 4. RTH from 3 km lands within 25 m of home
	var d := make_plane(0.0, 3000.0, 0.0)
	var p4: FPVPlane = d[0]; var fc4: PlaneController = d[1]
	var t4 := 0.0
	fc4.start_rth(Vector2.ZERO, 80.0)
	while t4 < 600.0 and (p4.armed or p4.position().y > 0.5):
		tick(p4, fc4, t4, Vector4(0.0, 0.0, 0.0, 0.0)); t4 += DT * SUB
	var dist4 := Vector2(p4.position().x, p4.position().z).length()
	check("RTH lands within 25 m", dist4 < 25.0 and t4 < 600.0, "%.1f m from home in %.1f s, crashed=%s" % [dist4, t4, p4.crashed])

	# 5. no NaN over a 5 minute random-stick run
	var e := make_plane(0.0)
	var p5: FPVPlane = e[0]; var fc5: PlaneController = e[1]
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var nan := false
	var t5 := 0.0
	for k in int(300.0 / (DT * SUB)):
		var st := Vector4(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		tick(p5, fc5, t5, st); t5 += DT * SUB
		for i in p5.s.size():
			if is_nan(p5.s[i]): nan = true
		if nan: break
	check("no NaN over 5 min random sticks", not nan, "nan=%s" % nan)

	if fails == 0: print("ALL PASS")
	else: print("%d FAIL" % fails)
	quit()
