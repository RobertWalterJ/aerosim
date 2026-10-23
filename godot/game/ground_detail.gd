class_name GroundDetail
extends RefCounted
## The small-scale life of the ground, shared by the ground and grass shaders:
##   - a canopy map: how much tree crown stands over each 2.3 m of the park (leaf litter, moss, damp shade, thin grass)
##   - desire lines: the short cuts people have worn across the lawn between paths
##   - the photographed sets for the path edges (cobble kerb, gravel verge) and the leaf litter under trees
## FarHills.build calls dress() once the terrain exists, so terrain.gd needs no change.

const CANOPY_SPAN := 1200.0       # metres covered by the canopy map, centred on the park
const CANOPY_PX := 512
## Worn short cuts: [x0, z0, x1, z1] in metres, each about a metre wide. Picked from the park plan where a path
## bends away from where people want to go (pad to plaza, avenue to the chapel walk, into the grave blocks).
const DESIRE := [
	Vector4(-14.0, 27.0, -4.0, 16.5),      # start pad to the plaza
	Vector4(92.0, 10.0, 126.0, -21.0),     # east avenue to the chapel walk
	Vector4(2.5, -45.0, 26.0, -60.0),      # north avenue into the north-east graves
	Vector4(-125.0, 8.0, -104.0, 43.0),    # corner cut across the west lawn
	Vector4(128.0, -4.0, 150.0, -35.0),    # loop to the chapel walk
	Vector4(-36.0, 20.0, -55.0, 52.0),     # spur into the south-west graves
]

static var _canopy: ImageTexture
static var _tex := {}

## How much crown stands over each point, 0..1, from the near trees in the layout.
static func canopy_tex(terrain: Terrain) -> ImageTexture:
	if _canopy != null: return _canopy
	var t0 := Time.get_ticks_msec()
	var n := CANOPY_PX
	var px := float(n) / CANOPY_SPAN
	var buf := PackedByteArray()
	buf.resize(n * n)
	buf.fill(0)
	for tr in terrain.layout["trees"]:
		var s: float = tr[4]
		var conifer := int(tr[5]) < 2
		var r := (2.6 if conifer else 4.8) * s * px          # crown radius in pixels
		var cx := (float(tr[0]) + CANOPY_SPAN * 0.5) * px
		var cz := (float(tr[2]) + CANOPY_SPAN * 0.5) * px
		var ro := r * 1.35                                 # litter and shade spill a little past the crown
		var i0 := maxi(0, floori(cx - ro)); var i1 := mini(n - 1, ceili(cx + ro))
		var j0 := maxi(0, floori(cz - ro)); var j1 := mini(n - 1, ceili(cz + ro))
		for j in range(j0, j1 + 1):
			var dz := (float(j) + 0.5 - cz)
			for i in range(i0, i1 + 1):
				var dx := (float(i) + 0.5 - cx)
				var d := sqrt(dx * dx + dz * dz) / ro
				if d >= 1.0: continue
				var v := int(255.0 * (1.0 - d * d) * (0.75 if conifer else 1.0))
				var k := j * n + i
				buf[k] = mini(255, maxi(buf[k], v) + mini(buf[k], v) / 3)     # overlapping crowns: denser shade
	var img := Image.create_from_data(n, n, false, Image.FORMAT_L8, buf)
	_canopy = ImageTexture.create_from_image(img)
	print("ground detail: canopy map %d ms" % (Time.get_ticks_msec() - t0))
	return _canopy

static func desire_array() -> PackedVector4Array:
	var a := PackedVector4Array()
	for d in DESIRE: a.append(d)
	a.resize(8)
	return a

static func _tex_set(name: String) -> Array:
	if not _tex.has(name):
		var t := []
		for map in ["diff", "nor", "arm"]: t.append(load("res://assets/textures/%s_%s.jpg" % [name, map]))
		_tex[name] = t
	return _tex[name]

## Hand the ground shader its extra maps (canopy, desire lines, cobble, gravel, leaf litter).
static func dress(terrain: Terrain) -> void:
	var m: ShaderMaterial = terrain._mat
	if m == null: return
	m.set_shader_parameter("uCanopy", canopy_tex(terrain))
	m.set_shader_parameter("uCanopySpan", CANOPY_SPAN)
	m.set_shader_parameter("uDesire", desire_array())
	m.set_shader_parameter("uDesireN", DESIRE.size())
	var c := _tex_set("cobble"); var g := _tex_set("gravel"); var l := _tex_set("soil_leaves")
	m.set_shader_parameter("uCobble", c[0]); m.set_shader_parameter("uCobbleN", c[1]); m.set_shader_parameter("uCobbleARM", c[2])
	m.set_shader_parameter("uGravel", g[0]); m.set_shader_parameter("uGravelN", g[1])
	m.set_shader_parameter("uLitterT", l[0]); m.set_shader_parameter("uLitterN", l[1])
