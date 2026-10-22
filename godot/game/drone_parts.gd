class_name DroneParts
extends RefCounted
## Shaped parts for the drone models: a real propeller blade (narrow at the hub, widest about two thirds out, a rounded tip,
## twisted and slightly cambered like an aerofoil), and a tapered carbon arm. Built once as meshes; every drone reuses them.

## How wide the blade is, 0..1, at a point t of the way from hub to tip.
static func _chord(t: float) -> float:
	var root := 0.42 + 0.58 * smoothstep(0.0, 0.6, t)
	var round_tip := 1.0
	if t > 0.88:
		round_tip = sqrt(maxf(1.0 - pow((t - 0.88) / 0.12, 2.0), 0.0))
	return root * (1.0 - 0.15 * clampf((t - 0.65) / 0.35, 0.0, 1.0)) * round_tip

## One blade lying along +X from the hub. The tip end is coloured so spinning props show their tips.
static func blade(radius: float, hub: float, chord: float, base: Color, tip: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var n := 16
	var m := 6
	var top := []
	var bot := []
	for i in n + 1:
		var t := float(i) / n
		var cw := _chord(t) * chord
		var pitch := deg_to_rad(26.0) * (1.0 - 0.6 * t)
		var rt := []
		var rb := []
		for j in m + 1:
			var u := float(j) / m - 0.5
			var shape := 1.0 - 4.0 * u * u
			var x := hub + t * (radius - hub)
			var z := u * cw * cos(pitch) - 0.5 * chord * t * t * t * 0.25
			var y := u * cw * sin(pitch) + 0.10 * cw * shape
			var th := 0.045 * chord * shape + 0.0004
			rt.append(Vector3(x, y + th, z))
			rb.append(Vector3(x, y - th, z))
		top.append(rt)
		bot.append(rb)
	for i in n:
		var t0 := float(i) / n
		var c0 := tip if t0 > 0.9 else base
		for j in m:
			for face in [top, bot]:
				var a: Vector3 = face[i][j]
				var b: Vector3 = face[i + 1][j]
				var c: Vector3 = face[i + 1][j + 1]
				var d: Vector3 = face[i][j + 1]
				var flip: bool = face == bot
				var tri1: Array = [a, b, c] if not flip else [a, c, b]
				var tri2: Array = [a, c, d] if not flip else [a, d, c]
				for tri in [tri1, tri2]:
					for v in tri:
						st.set_color(c0)
						st.add_vertex(v)
	st.generate_normals()
	return st.commit()

## A carbon arm along +X from 0 to `length`, thinning from the body to the motor.
static func arm(length: float, w0: float, w1: float, h0: float, h1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []
	for k in 2:
		var x := float(k) * length
		var w := lerpf(w0, w1, float(k)) * 0.5
		var h := lerpf(h0, h1, float(k)) * 0.5
		pts.append([Vector3(x, h, -w), Vector3(x, h, w), Vector3(x, -h, w), Vector3(x, -h, -w)])
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v in [a, b, c, a, c, d]: st.add_vertex(v)
	quad.call(pts[0][0], pts[1][0], pts[1][1], pts[0][1])   # top
	quad.call(pts[0][3], pts[0][2], pts[1][2], pts[1][3])   # bottom
	quad.call(pts[0][1], pts[1][1], pts[1][2], pts[0][2])   # +z side
	quad.call(pts[0][0], pts[0][3], pts[1][3], pts[1][0])   # -z side
	quad.call(pts[1][0], pts[1][3], pts[1][2], pts[1][1])   # motor end
	quad.call(pts[0][0], pts[0][1], pts[0][2], pts[0][3])   # body end
	st.generate_normals()
	return st.commit()
