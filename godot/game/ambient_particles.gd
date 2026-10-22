class_name AmbientParticles
extends Node3D
## Atmospheric particles that make the air feel alive, all on the GPU (see shaders/ambient_particles.gdshader):
##   leaves  autumn leaves drifting on the wind around the camera, more in the woods and in a breeze
##   motes   dust and pollen (and the odd seed or insect) that only show when light falls on them: brightest
##           against a low sun, gone in shade and at night except in the drone's light
##   wash    leaves and dust blown out of the ground in a ring when the drone hovers low
## Rain, snow and fog thin them out; wet leaves fall straighter. About 800 particles on a computer, half on a phone.
## main.gd builds it once with setup() and calls update() every frame.

const DESKTOP_COUNTS := {"leaves": 300, "motes": 220, "wash_leaves": 160, "wash_dust": 120}
const REF_ARM := 0.0795          # the Gimbal Mini's arm length; wash scales from it

var enabled := true
var leaves: GPUParticles3D
var motes: GPUParticles3D
var wash_leaves: GPUParticles3D
var wash_dust: GPUParticles3D
var _terrain: Terrain
var _mats: Array[ShaderMaterial] = []
var _leaf_mat: ShaderMaterial
var _mote_mat: ShaderMaterial
var _dust_mat: ShaderMaterial
var _cover_t := 0.0
var _woods := 0.5                # woodland around the camera, 0..1
var _under := Vector2.ZERO       # land cover under the drone: x woodland, y mown lawn

func setup(terrain: Terrain, touch: bool) -> void:
	_terrain = terrain
	var k := 0.5 if touch else 1.0
	var shader := load("res://game/shaders/ambient_particles.gdshader") as Shader
	var leaf_mesh := _leaf_mesh()
	leaves = _system(shader, 0, int(DESKTOP_COUNTS["leaves"] * k), 7.0, leaf_mesh, AABB(Vector3(-16, -70, -16), Vector3(32, 90, 32)))
	leaves.preprocess = 6.0
	_params(leaves, {"box": Vector3(7.5, 7.0, 7.5), "size_range": Vector2(0.05, 0.09)})
	motes = _system(shader, 1, int(DESKTOP_COUNTS["motes"] * k), 8.0, _mote_mesh(), AABB(Vector3(-7, -5, -7), Vector3(14, 10, 14)))
	motes.preprocess = 4.0
	_params(motes, {"box": Vector3(5.0, 3.0, 5.0), "size_range": Vector2(0.008, 0.018)})
	wash_leaves = _system(shader, 2, int(DESKTOP_COUNTS["wash_leaves"] * k), 4.5, leaf_mesh, AABB(Vector3(-14, -4, -14), Vector3(28, 16, 28)))
	_params(wash_leaves, {"size_range": Vector2(0.05, 0.09)})
	wash_dust = _system(shader, 3, int(DESKTOP_COUNTS["wash_dust"] * k), 2.2, _dust_mesh(), AABB(Vector3(-14, -4, -14), Vector3(28, 14, 28)))
	_params(wash_dust, {"size_range": Vector2(0.35, 0.8)})
	for p in [wash_leaves, wash_dust]:
		p.emitting = false
	if OS.get_cmdline_user_args().has("noamb"): set_enabled(false)     # test hook: compare a screenshot without them

func _system(shader: Shader, mode: int, amount: int, life: float, mesh: Mesh, aabb: AABB) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 8)
	p.lifetime = life
	p.randomness = 0.3
	p.local_coords = false
	p.fixed_fps = 0                 # every frame, no interpolation: wrapped particles must not smear across the box
	p.interpolate = false
	p.visibility_aabb = aabb
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_pass_1 = mesh
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("height_tex", _terrain.height_tex)
	p.process_material = m
	_mats.append(m)
	add_child(p)
	return p

func _params(p: GPUParticles3D, values: Dictionary) -> void:
	var m := p.process_material as ShaderMaterial
	for key in values: m.set_shader_parameter(key, values[key])

func set_enabled(on: bool) -> void:
	enabled = on
	for p in [leaves, motes, wash_leaves, wash_dust]:
		p.visible = on
		if not on: p.emitting = false

## Every frame. wind_ref: the wind 30 m up (wind.toward() * wind.speed); wash 0..1 as main.gd's _wash_now (it peaks
## near 0.55); arm_d: the airframe's arm length in metres.
func update(delta: float, cam: Camera3D, wind_ref: Vector3, gust: float, sun_el: float, sun_dir: Vector3, daylight: float, wx: WeatherSystem,
		drone_pos: Vector3, armed: bool, wash: float, arm_d: float) -> void:
	if not enabled or _terrain == null: return
	var cam_pos := cam.global_position
	# the size of one pixel 1 m from the camera, so small leaves and motes are never drawn smaller than a few pixels
	var vp_h := float(cam.get_viewport().get_visible_rect().size.y) if cam.get_viewport() else 720.0
	var ppm := 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(vp_h, 1.0)
	_leaf_mat.set_shader_parameter("px_per_m", ppm)
	_mote_mat.set_shader_parameter("px_per_m", ppm)
	var c := wx.cur
	var rain := float(c.get("rain", 0.0))
	var snow := float(c.get("snow", 0.0))
	var fog := float(c.get("fog", 0.0))
	var sunk := float(c.get("sun", 1.0))
	var wet := wx.wet
	var wind6 := wind_ref * 0.75          # log profile: about three quarters of the 30 m wind at 6 m
	var ws := wind6.length()
	var gy := _terrain.height(cam_pos.x, cam_pos.z)
	var cam_agl := cam_pos.y - gy

	_cover_t -= delta
	if _cover_t <= 0.0:
		_cover_t = 0.3
		# woodland around the camera, weighted upwind where the leaves come from
		var up := -wind_ref.normalized() * 14.0 if wind_ref.length() > 0.1 else Vector3.ZERO
		var w := 0.0
		for o in [Vector3.ZERO, up, up + Vector3(12, 0, 0), up + Vector3(-12, 0, 0), up + Vector3(0, 0, 12), up + Vector3(0, 0, -12)]:
			w += _terrain.cover_at(cam_pos.x + o.x, cam_pos.z + o.z).x
		_woods = clampf(w / 6.0 * 1.6, 0.0, 1.0)
		_under = _terrain.cover_at(drone_pos.x, drone_pos.z)

	var drone_v := Vector4(drone_pos.x, drone_pos.y, drone_pos.z, 0.0)
	var size_k := clampf(arm_d / REF_ARM, 0.6, 1.8)
	var radius := 1.0 + 1.3 * size_k
	var wash_speed := 3.0 + 2.6 * size_k
	drone_v.w = radius
	var wk := clampf(wash / 0.55, 0.0, 1.0) if armed else 0.0
	for m in _mats:
		m.set_shader_parameter("wind", wind6)
		m.set_shader_parameter("gust", gust)
		m.set_shader_parameter("wet", wet)
		m.set_shader_parameter("drone", drone_v)
		m.set_shader_parameter("wash", wk)
		m.set_shader_parameter("wash_speed", wash_speed)

	# drifting leaves: more in the woods and in a breeze, fewer in rain and fog, none in snow, few high up
	var lk := (0.6 + 0.4 * _woods) * (0.5 + 0.5 * smoothstep(0.4, 5.0, ws))     # the whole park is full of maples and oaks
	lk *= (1.0 - 0.65 * rain) * (1.0 - snow) * (1.0 - 0.6 * fog) * (1.0 - wx.snow_cover)
	lk *= 1.0 - smoothstep(22.0, 45.0, cam_agl)
	_drive(leaves, lk)
	leaves.global_position = Vector3(cam_pos.x, cam_pos.y, cam_pos.z)
	(leaves.process_material as ShaderMaterial).set_shader_parameter("center", cam_pos)
	_leaf_mat.set_shader_parameter("wet", wet)

	# motes: rain washes the dust out of the air; cloud dims them through the light itself
	var mk := pow(1.0 - rain, 2.0) * (1.0 - snow) * (1.0 - 0.5 * fog) * (0.3 + 0.7 * sunk) * (1.0 - smoothstep(30.0, 60.0, cam_agl))
	_drive(motes, mk)
	motes.global_position = cam_pos
	(motes.process_material as ShaderMaterial).set_shader_parameter("center", cam_pos)
	var golden := 1.0 - smoothstep(4.0, 25.0, sun_el)
	# glints need direct sun: under an overcast sky the motes are only faint (the drone light still shows them)
	_mote_mat.set_shader_parameter("strength", (1.0 + 1.6 * golden * daylight) * lerpf(0.06, 1.0, smoothstep(0.25, 0.75, sunk)))

	# rotor wash: the drone low over the ground blows up litter and dust; little on mown lawn, nothing on snow
	var ground_d := Vector3(drone_pos.x, _terrain.height(drone_pos.x, drone_pos.z), drone_pos.z)
	var woodland := _under.x
	var lawn := _under.y
	var bare := 1.0 - lawn
	var wl := wk * (0.12 + 0.88 * maxf(woodland, bare * 0.45)) * (1.0 - wx.snow_cover) * (1.0 - 0.4 * wet)
	var wdk := wk * (0.15 + 0.85 * bare * (1.0 - 0.6 * woodland)) * (1.0 - 0.9 * wet)
	wdk = maxf(wdk * (1.0 - wx.snow_cover), wk * wx.snow_cover)    # powder snow instead of dust
	wl *= size_k; wdk *= size_k
	_drive(wash_leaves, wl)
	_drive(wash_dust, wdk)
	for p in [wash_leaves, wash_dust]:
		p.global_position = ground_d
		(p.process_material as ShaderMaterial).set_shader_parameter("center", ground_d)
	var dust_c := Color(0.46, 0.39, 0.29).lerp(Color(0.95, 0.96, 1.0), wx.snow_cover)
	dust_c = dust_c.lerp(Color(0.33, 0.27, 0.2), clampf(woodland, 0.0, 1.0) * 0.5)
	if wdk > 0.03:
		_dust_mat.set_shader_parameter("light", daylight * (0.35 + 0.55 * sunk) + 0.03)
		_dust_mat.set_shader_parameter("sun_view", (cam.global_transform.basis.inverse() * sun_dir).normalized())
		_dust_mat.set_shader_parameter("sun_k", sunk * smoothstep(0.0, 6.0, sun_el))
	(wash_dust.process_material as ShaderMaterial).set_shader_parameter("tint",Color(dust_c.r, dust_c.g, dust_c.b, 0.22 + 0.2 * wx.snow_cover))

func _drive(p: GPUParticles3D, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	var on := k > 0.03
	if p.emitting != on: p.emitting = on
	var r := maxf(k, 0.03)
	if absf(p.amount_ratio - r) > 0.02: p.amount_ratio = r

# ------------------------------------------------------------------ meshes and textures
## A leaf: a 1 m quad folded along the midrib (scaled down by the particle), textured with a leaf outline.
func _leaf_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-0.5, 0.0, 0.5]
	var lift := [0.0, 0.1, 0.0]
	var verts := []
	for zi in 2:
		for xi in 3:
			verts.append([Vector3(xs[xi], lift[xi], -0.5 + zi), Vector2(xs[xi] + 0.5, float(zi))])
	for q in [[0, 1, 3, 4], [1, 2, 4, 5]]:
		for i in [q[0], q[2], q[1], q[1], q[2], q[3]]:
			st.set_uv(verts[i][1]); st.add_vertex(verts[i][0])
	st.generate_normals()
	var mesh := st.commit()
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = load("res://game/shaders/ambient_leaf.gdshader")
	_leaf_mat.set_shader_parameter("leaf_tex", _leaf_texture())
	mesh.surface_set_material(0, _leaf_mat)
	return mesh

## Two leaves side by side (64 x 64 each): a five-lobed maple and a wavy oak. r = shading and veins, g = browned edge, a = outline.
func _leaf_texture() -> ImageTexture:
	var S := 64
	var img := Image.create(S * 2, S, false, Image.FORMAT_RGBA8)
	for kind in 2:
		for y in S:
			for x in S:
				var u := (x + 0.5) / S * 2.0 - 1.0
				var v := (y + 0.5) / S * 2.0 - 1.0          # v = -1 at the tip
				var inside := false
				var edge := 0.0
				var vein := 0.0
				if kind == 0:
					var d := Vector2(u, v - 0.12)
					var r := d.length()
					var th := atan2(d.x, -d.y)
					var R := 0.86 * (0.42 + 0.58 * pow(absf(cos(th * 2.5)), 1.4)) * (1.0 + 0.05 * cos(th * 22.0))
					inside = r < R
					edge = smoothstep(0.7, 1.0, r / maxf(R, 0.01))
					for a in [0.0, 1.2566, -1.2566, 2.5133, -2.5133]:
						if cos(th - a) > 0.0 and r * absf(sin(th - a)) < 0.03: vein = 1.0
				else:
					var d2 := Vector2(u, v - 0.05)
					var e := sqrt(pow(d2.x / 0.46, 2.0) + pow(d2.y / 0.86, 2.0))
					var R2 := 1.0 - 0.16 * absf(sin(d2.y * 9.0))
					inside = e < R2
					edge = smoothstep(0.7, 1.0, e / R2)
					if absf(d2.x) < 0.035: vein = 1.0
				# the stalk
				if absf(u) < 0.045 and v > 0.1 and v < 0.97: inside = true; vein = 1.0
				var lum := 0.85 - 0.35 * vein - 0.15 * edge + 0.1 * sin(u * 9.0 + v * 7.0)
				img.set_pixel(x + kind * S, y, Color(clampf(lum, 0.0, 1.0), edge, 0.0, 1.0 if inside else 0.0))

	return ImageTexture.create_from_image(img)

func _mote_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_mote_mat = ShaderMaterial.new()
	_mote_mat.shader = load("res://game/shaders/ambient_mote.gdshader")
	_mote_mat.set_shader_parameter("warm", Vector3(1.0, 0.93, 0.8))
	q.material = _mote_mat
	return q

func _dust_mesh() -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = load("res://game/shaders/ambient_dust.gdshader")
	q.material = _dust_mat
	return q
