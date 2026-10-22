class_name MiniMap
extends Control
## The map thumbnail in the corner of a drone app: a hill-shaded top-down view of the valley, the home point, the
## drone as an arrow with its recent track, and the cemetery. It turns with the drone's heading (heading up) and the
## ring shows north. The map picture is painted once from the terrain and the cover map.

const VIEW_M := 420.0            # metres across the map thumbnail

var drone := Vector3.ZERO
var heading := 0.0              # compass bearing in radians, 0 = north, clockwise
var home := Vector2.ZERO
var features: Array[Rect2] = [] # rectangles to outline, in world x,z
var paths: Array[PackedVector2Array] = []   # park paths as lines, in world x,z
var _tex: ImageTexture
var _size_m := 1600.0
var _trail := PackedVector2Array()
var _trail_t := 0.0

func _init(d := 150.0) -> void:
	custom_minimum_size = Vector2(d, d)
	size = Vector2(d, d)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Paint the map from the terrain: hill-shading times a land colour from the cover map.
func bake(terrain: Terrain) -> void:
	_size_m = Terrain.SIZE
	var n := 512
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sun := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in n:
		for i in n:
			var x := ((i + 0.5) / n - 0.5) * _size_m
			var z := ((j + 0.5) / n - 0.5) * _size_m
			var nrm := terrain.normal_at(x, z)
			var shade := clampf(0.55 + 0.9 * (nrm.dot(sun) - sun.y * 0.9), 0.25, 1.1)
			var cv := terrain.cover_at(x, z)
			var land := Color(0.52, 0.56, 0.34).lerp(Color(0.42, 0.55, 0.27), cv.y).lerp(Color(0.22, 0.34, 0.20), cv.x)
			img.set_pixel(i, j, Color(land.r * shade, land.g * shade, land.b * shade))
	_tex = ImageTexture.create_from_image(img)

func update_state(pos: Vector3, head: float, delta: float) -> void:
	drone = pos; heading = head
	_trail_t += delta
	if _trail_t > 0.4:
		_trail_t = 0.0
		_trail.append(Vector2(pos.x, pos.z))
		if _trail.size() > 240: _trail.remove_at(0)
	queue_redraw()

func clear_trail() -> void:
	_trail.clear()

func _w2m(p: Vector2) -> Vector2:
	# world (x, z) to map pixels, with the drone at the centre and the view turned so the heading points up
	var k := size.x / VIEW_M
	var d := (p - Vector2(drone.x, drone.z)) * k
	return size * 0.5 + d.rotated(-heading)

func _draw() -> void:
	var c := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.12))
	if _tex != null:
		var k := size.x / VIEW_M
		draw_set_transform(c, -heading, Vector2(k, k))
		draw_texture_rect(_tex, Rect2(Vector2(-drone.x, -drone.z) - Vector2(_size_m, _size_m) * 0.5, Vector2(_size_m, _size_m)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pl in paths:
		if pl.size() < 2: continue
		var pts := PackedVector2Array()
		for p in pl: pts.append(_w2m(p))
		draw_polyline(pts, Color(0.9, 0.88, 0.8, 0.8), 1.4, true)
	for r in features:
		var a := _w2m(r.position); var b := _w2m(Vector2(r.end.x, r.position.y)); var d := _w2m(r.end); var e := _w2m(Vector2(r.position.x, r.end.y))
		draw_polyline(PackedVector2Array([a, b, d, e, a]), Color(1, 1, 1, 0.55), 1.2, true)
	if _trail.size() > 1:
		var pts := PackedVector2Array()
		for p in _trail: pts.append(_w2m(p))
		draw_polyline(pts, Color(0.35, 0.7, 1.0, 0.9), 1.8, true)
	# home marker and the drone, always pointing up (the map turns, not the arrow)
	HudIcons.home_marker(self, _w2m(home), 8.5)
	HudIcons.drone_marker(self, c, 11.0, 0.0, Color(0.22, 0.58, 1.0))
	# north marker on the rim
	var nd := Vector2(sin(-heading), -cos(-heading)) * (size.x * 0.5 - 12.0)
	draw_circle(c + nd, 8.5, Color(0, 0, 0, 0.55), true, -1.0, true)
	var nf := HudIcons.bold_font()
	var nw := nf.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(nf, c + nd + Vector2(-nw * 0.5, 4.3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.5, 0.45))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.9), false, 2.0)
