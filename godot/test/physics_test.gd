extends SceneTree
## Headless physics check, the same tests as tests/physics.test.ts in the web version.
## Run: Godot_console.exe --headless --path godot --script res://test/physics_test.gd [-- dt=0.001 ids=mini,race]

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

func hspeed(q: Quad) -> float:
	return sqrt(q.s[3] * q.s[3] + q.s[5] * q.s[5])

func _init() -> void:
	var dt := 0.001
	var ids: Array = Airframes.IDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("dt="): dt = float(a.substr(3))
		if a.begins_with("ids="): ids = a.substr(4).split(",")
	var scale := 0.001 / dt   # step counts scale so each phase lasts the same real time
	var t0 := Time.get_ticks_msec()
	var total_steps := 0
	for id in ids:
		if id == "wing": continue   # plane lane: the fixed wing is checked by test/plane_test.gd, not the quad battery
		var af := Airframes.make(id)
		print("--- ", af["name"], "  dt=", dt)
		var rm := Rotor.new(af)
		rm.compute(af["omegaMax"], 0, 0, 10, 1.225, 0)
		check("static Tmax", absf(rm.T - rm.Tmax) / rm.Tmax < 0.03, "T=%.3f N vs %.3f N" % [rm.T, rm.Tmax])
		var q := Quad.new(af)
		var fc := FlightController.new(af, q)
		fc.set_step(dt)
		var wh: float = af["omegaMax"] * sqrt(1.0 / float(af["twr"]))
		q.reset(0, 20, 0, 0)
		for i in 4:
			q.s[13 + i] = wh; q.cmd[i] = wh
		# hover in N mode
		var steps := int(6.0 / dt)
		for i in steps:
			fc.update(dt, 0, 0, 0, 0); q.step(dt)
		total_steps += steps
		check("N-mode hover holds alt", absf(q.s[1] - 20.0) < 0.3 and hspeed(q) < 0.1, "y=%.3f v=%.3f P=%.1f W" % [q.s[1], q.velocity().length(), q.p_elec])
		# forward stick
		steps = int(16.0 / dt)
		for i in steps:
			fc.update(dt, 0, 0, 1, 0); q.step(dt)
		total_steps += steps
		var vf := hspeed(q)
		check("forward flight reaches vmax", vf > float(af["limits"]["N"]["vH"]) * 0.8, "v=%.2f m/s, alt=%.2f, tilt=%.1f deg" % [vf, q.s[1], rad_to_deg(fc.tilt)])
		steps = int(6.0 / dt)
		for i in steps:
			fc.update(dt, 0, 0, 0, 0); q.step(dt)
		total_steps += steps
		check("brakes to hover", hspeed(q) < 0.4, "v=%.2f" % hspeed(q))
		# wind hold
		q.wind = Vector3(6, 0, 0)
		steps = int(8.0 / dt)
		for i in steps:
			fc.update(dt, 0, 0, 0, 0); q.step(dt)
		total_steps += steps
		check("GPS hold in 6 m/s wind", hspeed(q) < 0.5, "v=%.2f alt=%.2f" % [hspeed(q), q.s[1]])
		q.wind = Vector3.ZERO
		# manual mode roll rate step
		fc.mode = "M"; fc.reset_state()
		var max_w := 0.0
		steps = int(0.7 / dt)
		for i in steps:
			fc.update(dt, 0.1, 0, 0, 1); q.step(dt)
			max_w = maxf(max_w, absf(q.s[12]))
		total_steps += steps
		check("M-mode roll rate achieved", max_w > 2.5, "peak roll rate %.0f deg/s" % rad_to_deg(max_w))
		check("M-mode stays armed", not q.crashed, q.crash_reason)
		print("battery: soc=%.3f V=%.2f (%.2f/cell) I=%.1fA" % [q.battery.soc, q.battery.v_term, q.battery.cell_v(), q.battery.current])
	var ms := Time.get_ticks_msec() - t0
	print("steps %d in %d ms = %.1f us per step" % [total_steps, ms, 1000.0 * ms / maxf(total_steps, 1)])
	print("ALL PASS" if fails == 0 else str(fails) + " FAILURES")
	quit(1 if fails else 0)
