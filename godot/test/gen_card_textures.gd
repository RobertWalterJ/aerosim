extends SceneTree
## Draws the leaf-card textures of the crop models (game/new_models3.gd, farm_plant.gdshader kind 2) and saves them as PNGs in
## assets/textures/cards/. Run once after changing a drawing (headless is fine):
## Godot --headless --path <godot dir> -s res://test/gen_card_textures.gd
## The files are data, not colour: r is the light and shade of the leaf (0 dark, 1 bright), g is 1 where the part is a stem, husk
## or head (it takes the stem colour), b is 0.5 for the first accent (tassel, umbel) and 1.0 for the second (silk, flower), and a
## is the cut-out. Everything drawn here is original (blades are curves painted with a width profile, veins and a midrib).

var img: Image
var W := 256
var H := 256
var wrap_x := true
var wrap_y := false
var rs := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/cards"))
	_corn(); _corn_top(); _barley(false); _barley(true); _alfalfa(false); _alfalfa(true); _weeds()
	print("cards done")
	quit()

# ------------------------------------------------------------------ canvas
func _begin(w: int, h: int, tile_x := true, tile_y := false) -> void:
	W = w; H = h; wrap_x = tile_x; wrap_y = tile_y
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.0, 0.0, 0.0))

func _save(nm: String) -> void:
	var path := ProjectSettings.globalize_path("res://assets/textures/cards/%s.png" % nm)
	var e := img.save_png(path)
	print("%s: %s" % [path, error_string(e)])

## Paint one pixel with coverage cov ("over" blending of the data channels).
func _px(x: int, y: int, cov: float, shade: float, stem: float, acc: float) -> void:
	if cov <= 0.0: return
	if wrap_x: x = posmod(x, W)
	elif x < 0 or x >= W: return
	if wrap_y: y = posmod(y, H)
	elif y < 0 or y >= H: return
	var o := img.get_pixel(x, y)
	var a := cov + o.a * (1.0 - cov)
	if a <= 0.0001: return
	var k := cov / a
	img.set_pixel(x, y, Color(lerpf(o.r, shade, k), lerpf(o.g, stem, k), lerpf(o.b, acc, k), a))

func _disc(c: Vector2, r: float, shade: float, stem: float, acc: float, flat := 1.0) -> void:
	var x0 := int(floor(c.x - r - 1.0)); var x1 := int(ceil(c.x + r + 1.0))
	var y0 := int(floor(c.y - r - 1.0)); var y1 := int(ceil(c.y + r + 1.0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length()
			var cov := clampf(r - d + 0.5, 0.0, 1.0)
			if cov > 0.0:
				_px(x, y, cov, shade * (1.0 - 0.18 * (1.0 - flat) * (d / maxf(r, 0.5))), stem, acc)

func _bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)

## A leaf blade along a cubic curve. prof: 0 corn (widest a third along, pointed), 1 grass (narrow, slow taper), 2 round leaflet.
## shade is the brightness of the leaf, edge the wavy margin amount, rib the midrib brightness added.
func _blade(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, wmax: float, shade: float, stem := 0.0, acc := 0.0,
		prof := 0, edge := 0.0, rib := 0.14, seed := 0.0, tip_shade := 0.0) -> void:
	var len_est := (p1 - p0).length() + (p2 - p1).length() + (p3 - p2).length()
	var steps := int(maxf(8.0, len_est / 0.6))
	for i in steps + 1:
		var t := float(i) / steps
		var c := _bez(p0, p1, p2, p3, t)
		var c2 := _bez(p0, p1, p2, p3, minf(t + 0.01, 1.0))
		var c1 := _bez(p0, p1, p2, p3, maxf(t - 0.01, 0.0))
		var tg := (c2 - c1).normalized()
		var nm := Vector2(-tg.y, tg.x)
		var pr: float
		match prof:
			0: pr = clampf(sin(PI * pow(t, 0.62)), 0.0, 1.0) * (1.0 - 0.25 * t)
			1: pr = clampf(minf(t * 7.0, 1.0) * (1.0 - pow(t, 2.2)), 0.0, 1.0)
			_: pr = sin(PI * t) ** 0.7
		var w := wmax * pr * (1.0 + edge * sin(t * 38.0 + seed * 7.0) * 0.5)
		if w < 0.35: continue
		var base_s := shade * (1.0 + tip_shade * t)
		var o := -w - 1.0
		while o <= w + 1.0:
			var cov := clampf(w - absf(o) + 0.5, 0.0, 1.0)
			if cov > 0.0:
				var q := c + nm * o
				var across := absf(o) / w
				var s := base_s * (0.74 + 0.26 * (1.0 - across * across))
				if absf(o) < maxf(0.7, w * 0.08): s += rib
				else: s *= 1.0 + 0.045 * sin(o / w * 22.0 + seed)
				s *= 1.0 + 0.05 * sin(t * 61.0 + seed * 3.0)
				_px(int(floor(q.x)), int(floor(q.y)), cov, clampf(s, 0.0, 1.2), stem, acc)
			o += 0.6

## A thin straight-ish line (stem, awn, spoke) of constant width.
func _line(a: Vector2, b: Vector2, w: float, shade: float, stem: float, acc: float, w1 := -1.0) -> void:
	var n := int(maxf(2.0, a.distance_to(b) / 0.7))
	if w1 < 0.0: w1 = w
	for i in n + 1:
		var t := float(i) / n
		_disc(a.lerp(b, t), lerpf(w, w1, t), shade * (0.9 + 0.2 * t), stem, acc)

# ------------------------------------------------------------------ corn, side view
## One corn plant with its foot at (x, y_base), H_p pixels tall.
func _corn_plant(x: float, yb: float, hp: float, depth: float, seed: float) -> void:
	rs.seed = int(seed * 1000.0)
	# the stalk, thicker at the foot
	_line(Vector2(x, yb), Vector2(x + rs.randf_range(-3.0, 3.0), yb - hp * 0.92), 4.2, 0.62 * depth, 1.0, 0.0, 2.2)
	var nl := 11
	for i in nl:
		var f := 0.07 + 0.74 * float(i) / (nl - 1)
		var side := 1.0 if i % 2 == 0 else -1.0
		var node := Vector2(x + rs.randf_range(-1.5, 1.5), yb - hp * f)
		var L := hp * lerpf(0.4, 0.21, f) * rs.randf_range(0.86, 1.1)
		var drop := lerpf(0.5, 0.06, f)
		var rise := lerpf(0.55, 0.9, f)
		var sg := Vector2(side, 0.0)
		var p1 := node + Vector2(side * L * 0.34, -L * rise * 0.55)
		var p2 := node + Vector2(side * L * 0.78, -L * rise * 0.6 + L * drop * 0.55)
		var p3 := node + Vector2(side * L * 1.02, -L * rise * 0.28 + L * drop)
		var wm := L * 0.075 * rs.randf_range(0.85, 1.15)
		var shade := depth * rs.randf_range(0.78, 0.98) * lerpf(0.88, 1.06, f)
		_blade(node, p1, p2, p3, wm, shade, 0.0, 0.0, 0, 0.35, 0.16, seed + i, 0.1)
	# the ear, wrapped in husk leaves, with a few threads of silk
	var ey := yb - hp * 0.56
	var es := 1.0 if int(seed) % 2 == 0 else -1.0
	var ear0 := Vector2(x + es * 4.0, ey)
	var ear1 := Vector2(x + es * 23.0, ey - 30.0)
	_line(ear0, ear1, 6.5, 0.88 * depth, 1.0, 0.0, 3.0)
	for k in 3:
		var a := Vector2(es * (6.0 + k * 3.0), -4.0 - k * 3.0)
		_blade(ear0 + Vector2(es * 2.0, 0.0), ear0 + a * 2.0, ear1 + Vector2(-es * (3.0 - k), 8.0), ear1 + Vector2(es * (k * 2.0 - 2.0), -8.0), 5.0, depth * 0.95, 0.0, 0.0, 1, 0.1, 0.1, seed + k)
	for k in 5:
		_line(ear1, ear1 + Vector2(es * rs.randf_range(1.0, 7.0), rs.randf_range(-8.0, -3.0)), 0.6, 0.8, 1.0, 1.0)
	# the tassel: a spike with branches
	var top := Vector2(x, yb - hp * 0.94)
	_line(top, top + Vector2(0, -hp * 0.07), 1.7, 0.95 * depth, 1.0, 0.5)
	for k in 8:
		var s2 := -1.0 if k % 2 == 0 else 1.0
		var a2 := top + Vector2(0, -hp * (0.02 + 0.004 * k))
		var e2 := a2 + Vector2(s2 * rs.randf_range(14.0, 26.0), rs.randf_range(-16.0, 4.0) * 1.0)
		_blade(a2, a2 + Vector2(s2 * 6.0, -9.0), e2 - Vector2(s2 * 5.0, 8.0), e2, 1.8, 0.95 * depth, 1.0, 0.5, 1, 0.0, 0.0, seed + k)

func _corn() -> void:
	_begin(256, 600, true, false)
	# three plants, the far ones darker (a bake of the shade inside the canopy), foot at the bottom edge
	_corn_plant(58.0, 596.0, 520.0, 0.66, 3.0)
	_corn_plant(196.0, 596.0, 505.0, 0.72, 5.0)
	_corn_plant(128.0, 598.0, 560.0, 1.0, 2.0)
	# the ground end of the card is in shadow: fade the foot to darker
	for y in range(380, H):
		var k := float(y - 380) / (H - 380)
		for x in W:
			var c := img.get_pixel(x, y)
			if c.a > 0.0: img.set_pixel(x, y, Color(c.r * (1.0 - 0.38 * k * k), c.g, c.b, c.a))
	_save("corn_card")

# ------------------------------------------------------------------ corn, from above
func _corn_top() -> void:
	_begin(256, 256, true, true)
	rs.seed = 11
	for c: Vector2 in [Vector2(70.0, 64.0), Vector2(198.0, 192.0), Vector2(70.0, 192.0), Vector2(198.0, 64.0)]:
		var n := 9
		for i in n:
			var a := TAU * i / n + rs.randf_range(-0.2, 0.2) + c.x * 0.01
			var L := rs.randf_range(88.0, 118.0)
			var d := Vector2(cos(a), sin(a))
			var nrm := Vector2(-d.y, d.x) * rs.randf_range(-0.2, 0.2)
			var p0 := c + d * 6.0
			var p1 := c + d * L * 0.3 + nrm * L * 0.2
			var p2 := c + d * L * 0.7 + nrm * L * 0.4
			var p3 := c + d * L + nrm * L * 0.5
			_blade(p0, p1, p2, p3, 13.0, rs.randf_range(0.62, 0.92), 0.0, 0.0, 0, 0.25, 0.16, float(i) + c.x, 0.3)
		_disc(c, 6.0, 0.5, 1.0, 0.0)
	_save("corn_top")

# ------------------------------------------------------------------ barley
func _barley(ripe: bool) -> void:
	_begin(256, 372, true, false)
	rs.seed = 7 if not ripe else 8
	var depth_order := []
	for i in 30:
		var x := rs.randf_range(18.0, 238.0)
		var h := rs.randf_range(110.0, 300.0)
		var lean := rs.randf_range(-0.45, 0.45)
		var base := Vector2(x, 370.0)
		var p1 := base + Vector2(lean * 30.0, -h * 0.35)
		var p2 := base + Vector2(lean * 70.0, -h * 0.7)
		var p3 := base + Vector2(lean * 120.0 + rs.randf_range(-10.0, 10.0), -h)
		depth_order.append([rs.randf_range(0.55, 1.0), base, p1, p2, p3, i])
	depth_order.sort_custom(func(a, b): return a[0] < b[0])
	for d in depth_order:
		_blade(d[1], d[2], d[3], d[4], rs.randf_range(7.0, 10.0), d[0], 0.0, 0.0, 1, 0.2, 0.08, float(d[5]), 0.2)
	# stems and heads
	var heads := []
	for i in 16:
		var x := rs.randf_range(28.0, 228.0)
		var h := rs.randf_range(250.0, 350.0)
		var lean := rs.randf_range(-0.5, 0.5)
		var base := Vector2(x, 372.0)
		var droop := 0.55 if ripe else 0.28
		var p1 := base + Vector2(lean * 24.0, -h * 0.4)
		var p2 := base + Vector2(lean * 60.0, -h * 0.8)
		var p3 := base + Vector2(lean * 70.0 + droop * 90.0 * signf(lean + 0.01), -h * 0.92 + droop * 40.0)
		heads.append([rs.randf_range(0.7, 1.0), base, p1, p2, p3, i])
	heads.sort_custom(func(a, b): return a[0] < b[0])
	for hd in heads:
		var sh: float = hd[0]
		var b: Vector2 = hd[1]
		_blade(b, hd[2], hd[3], hd[4], 2.6, sh * 0.85, 1.0, 0.0, 1, 0.0, 0.0, float(hd[5]))
		var tip: Vector2 = hd[4]
		var td: Vector2 = ((hd[4] as Vector2) - (hd[3] as Vector2)).normalized()
		# the head: an ellipse of grain, rows of dark and light, with awns fanning out of its end
		var hl := 36.0
		for k in 22:
			var t := float(k) / 21.0
			var pc: Vector2 = tip + td * (t * hl)
			var wd := 6.4 * (0.5 + 0.9 * sin(PI * (0.12 + 0.8 * t)))
			var nrm: Vector2 = Vector2(-td.y, td.x)
			for s in range(-int(wd), int(wd) + 1):
				var q: Vector2 = pc + nrm * s
				var cov := clampf(wd - absf(s) + 0.5, 0.0, 1.0)
				_px(int(floor(q.x)), int(floor(q.y)), cov, sh * (0.82 + 0.22 * ((k % 2) * 0.5 + (1.0 - absf(s) / wd) * 0.5)), 1.0, 0.0)
		for ka in 14:
			var spread := (float(ka) - 6.5) * 0.045
			var dir: Vector2 = td.rotated(spread + rs.randf_range(-0.03, 0.03))
			var lenw := rs.randf_range(52.0, 80.0)
			var st: Vector2 = tip + td * rs.randf_range(10.0, hl)
			_line(st, st + dir * lenw, 0.75, sh * 1.05, 1.0, 0.0, 0.3)
	_save("barley_card_b" if ripe else "barley_card_a")

# ------------------------------------------------------------------ alfalfa
func _leaflet(c: Vector2, d: Vector2, L: float, sh: float) -> void:
	var n := Vector2(-d.y, d.x)
	_blade(c, c + d * L * 0.33 + n * L * 0.04, c + d * L * 0.66 - n * L * 0.04, c + d * L, L * 0.3, sh, 0.0, 0.0, 2, 0.0, 0.1, c.x)

func _alfalfa(flower: bool) -> void:
	_begin(256, 256, true, false)
	rs.seed = 21 if not flower else 22
	var stems := []
	for i in 17:
		var x := rs.randf_range(30.0, 226.0)
		var h := rs.randf_range(120.0, 235.0)
		var lean := rs.randf_range(-0.5, 0.5)
		stems.append([rs.randf_range(0.55, 1.0), Vector2(x, 254.0), h, lean, i])
	stems.sort_custom(func(a, b): return a[0] < b[0])
	for s in stems:
		var sh: float = s[0]
		var b: Vector2 = s[1]; var h: float = s[2]; var lean: float = s[3]
		var p1 := b + Vector2(lean * 14.0, -h * 0.35)
		var p2 := b + Vector2(lean * 36.0, -h * 0.7)
		var p3 := b + Vector2(lean * 48.0, -h)
		var pts: Array = []
		for k in 21: pts.append(_bez(b, p1, p2, p3, float(k) / 20.0))
		for k in 20: _line(pts[k], pts[k + 1], 1.6 - 0.6 * k / 20.0, sh * 0.9, 1.0, 0.0)
		var nodes := 6
		for q in nodes:
			var t := 0.28 + 0.72 * float(q) / (nodes - 1)
			var c: Vector2 = pts[int(t * 20.0)]
			var ang := (-PI * 0.5) + (0.9 + 0.12 * q) * (1.0 if (q + int(s[4])) % 2 == 0 else -1.0)
			var d := Vector2(cos(ang), sin(ang))
			var L := 25.0 * lerpf(1.0, 0.7, t)
			_leaflet(c, d, L, sh * rs.randf_range(0.85, 1.0))
			_leaflet(c, d.rotated(0.55), L * 0.9, sh * rs.randf_range(0.75, 0.95))
			_leaflet(c, d.rotated(-0.55), L * 0.9, sh * rs.randf_range(0.75, 0.95))
		if flower:
			var tp: Vector2 = pts[20]
			for k in 9:
				var o := Vector2(rs.randf_range(-5.0, 5.0), 3.0 * k - 12.0 + rs.randf_range(-2.0, 2.0))
				_disc(tp + o, rs.randf_range(2.3, 3.3), sh * rs.randf_range(0.8, 1.05), 0.0, 1.0)
	_save("alfalfa_card_b" if flower else "alfalfa_card_a")

# ------------------------------------------------------------------ field-margin weeds
func _weeds() -> void:
	_begin(256, 228, true, false)
	rs.seed = 31
	var bl := []
	for i in 46:
		var x := rs.randf_range(6.0, 250.0)
		var h := rs.randf_range(70.0, 205.0)
		var lean := rs.randf_range(-0.8, 0.8)
		var b := Vector2(x, 227.0)
		bl.append([rs.randf_range(0.5, 1.0), b, b + Vector2(lean * 14.0, -h * 0.4), b + Vector2(lean * 40.0, -h * 0.75), b + Vector2(lean * 70.0, -h * 0.97 + 18.0 * absf(lean)), i])
	bl.sort_custom(func(a, c): return a[0] < c[0])
	for d in bl:
		_blade(d[1], d[2], d[3], d[4], rs.randf_range(3.2, 5.2), d[0], 0.0, 0.0, 1, 0.18, 0.08, float(d[5]), 0.2)
	# wild carrot umbels (the first accent) and goldenrod plumes (the second)
	for i in 4:
		var x := 36.0 + i * 62.0 + rs.randf_range(-14.0, 14.0)
		var h := rs.randf_range(150.0, 205.0)
		var b := Vector2(x, 227.0)
		var tip := b + Vector2(rs.randf_range(-12.0, 12.0), -h)
		_line(b, tip, 1.6, 0.8, 1.0, 0.0, 1.0)
		for k in 9:
			var a := PI * (k + 0.5) / 9.0 + PI
			var e := tip + Vector2(cos(a), sin(a)) * 22.0 + Vector2(0, 6.0)
			_line(tip, e, 0.6, 0.9, 1.0, 0.0)
			_disc(e, 3.6, 1.0, 0.0, 0.5, 0.6)
			_disc(e + Vector2(-2.0, 1.0), 2.4, 0.95, 0.0, 0.5, 0.6)
	for i in 3:
		var x := 52.0 + i * 78.0 + rs.randf_range(-10.0, 10.0)
		var h := rs.randf_range(130.0, 180.0)
		var b := Vector2(x, 227.0)
		var tip := b + Vector2(rs.randf_range(-6.0, 10.0), -h)
		_line(b, tip, 1.5, 0.75, 1.0, 0.0, 1.0)
		for k in 22:
			var t := float(k) / 21.0
			var c := tip + Vector2(rs.randf_range(-6.0, 6.0) * (1.0 - t * 0.5), 28.0 * t - 6.0)
			_disc(c, rs.randf_range(2.5, 4.2), rs.randf_range(0.85, 1.05), 0.0, 1.0)
	_save("weeds_card")
