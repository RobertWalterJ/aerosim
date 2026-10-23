class_name Funnel
extends Node3D
## A tornado, waterspout or dust devil: one shared funnel system for SPEC-EXTREME-WEATHER B1/B4 (session B).
##
## The visible funnel is a procedural tapered tube built here (rings of vertices with a bowed axis), drawn with
## shaders/funnel_funnel.gdshader: dark core, torn lighter edges and bands that scroll up while they spin faster near
## the base. Around its foot live GPU particles: a spray ring and a mist cone for a waterspout, a dust skirt with
## orbiting leaves and twigs for a tornado, a small dust ring for a dust devil.
##
## Life: it forms (widening out of the cloud), tracks along the wind, rops out (thins and wobbles) and dissipates.
## Waterspouts stay over the lake (Lake.is_wet); tornadoes cross the open meadow and keep away from the cemetery park.
## `wind_at(pos)` is the rotating plus inflow plus updraft field that game/wind.gd adds to the wind the drone feels,
## capped at MAX_WIND so every drone stays flyable. The drone is never damaged and lightning never strikes it.
##
## Cost: one mesh under 1300 triangles and at most 1000 particles on a computer (250 on a phone).

const WSPOUT := 0
const TORNADO := 1
const DUST := 2
const MAX_WIND := 22.0

var kind := TORNADO
var active := false
var anchor := Vector3.ZERO
var base_y := 0.0
var height := 500.0
var base_width := 60.0          # metres across at the foot
var top_ratio := 2.2            # top radius over base radius
var speed := 9.0                # track speed, m/s
var strength := 0.0             # 0..1 envelope
var age := 0.0
var form_time := 45.0
var track_time := 60.0
var rope_time := 22.0
var fade_time := 8.0
var seed := 0.0
var drift := Vector3.ZERO
var _mobile := false
var _time := 0.0
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _spray: GPUParticles3D
var _debris: GPUParticles3D
var _mist: GPUParticles3D
var _mats: Array[ShaderMaterial] = []
var _draw_mats: Array[ShaderMaterial] = []
var _sound: AudioStreamPlayer3D
var _wobble := 0.0
var _terrain: Terrain
var _lake_level := Lake.LEVEL

## `roar` is the looped low roar stream made in game/weather_events.gd. Use `start()` after setup.
func setup(fkind: int, at: Vector3, terrain: Terrain, roar: AudioStream) -> void:
	kind = fkind
	anchor = at
	_terrain = terrain
	_mobile = OS.has_feature("mobile")
	seed = randf() * 20.0
	base_y = at.y
	if kind == WSPOUT:
		height = randf_range(320.0, 620.0)
		base_width = randf_range(10.0, 40.0)
		top_ratio = 1.5
		speed = randf_range(3.5, 6.0)
		form_time = randf_range(45.0, 75.0)
		track_time = randf_range(45.0, 80.0)
	elif kind == DUST:
		height = randf_range(60.0, 150.0)
		base_width = randf_range(3.0, 10.0)
		top_ratio = 1.25
		speed = randf_range(2.0, 4.5)
		form_time = randf_range(8.0, 15.0)
		track_time = randf_range(18.0, 30.0)
		rope_time = randf_range(6.0, 10.0)
		fade_time = 5.0
	else:
		height = randf_range(300.0, 900.0)
		base_width = randf_range(20.0, 150.0)
		top_ratio = 2.3
		speed = randf_range(7.0, 15.0)
		form_time = randf_range(40.0, 70.0)
		track_time = randf_range(50.0, 100.0)
		rope_time = randf_range(15.0, 25.0)
	_build_mesh()
	_build_particles()
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = roar
	_sound.bus = "Weather"
	_sound.unit_size = 42.0
	_sound.max_distance = 4000.0
	_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_sound.volume_db = -8.0
	add_child(_sound)
	if roar != null:
		_sound.play()
	active = true
	visible = false

func _ring_radius(t: float) -> float:
	# a narrow foot, widening up the funnel, with a flare where it joins the wall cloud
	return lerpf(1.0, top_ratio, smoothstep(0.0, 1.0, t)) + 0.5 * top_ratio * smoothstep(0.82, 1.0, t)

func _build_mesh() -> void:
	var rings := 26 if not _mobile else 18
	var segs := 24 if not _mobile else 18
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rings + 1:
		var t := float(r) / float(rings)
		var rad := _ring_radius(t)
		var bow := 0.16 * sin(t * PI * 1.25) * (1.0 if kind == TORNADO else 0.7)
		for s in segs + 1:
			var a := TAU * float(s) / float(segs)
			var p := Vector3(cos(a) * rad + bow, t, sin(a) * rad)
			var n := Vector3(cos(a), 0.0, sin(a)).normalized()
			verts.append(p); norms.append(n); uvs.append(Vector2(float(s) / float(segs), t))
	for r in rings:
		for s in segs:
			var i0 := r * (segs + 1) + s
			var i1 := i0 + segs + 1
			idx.append_array([i0, i1, i0 + 1, i0 + 1, i1, i1 + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://game/shaders/funnel_funnel.gdshader")
	_mat.set_shader_parameter("alpha", 0.5)
	_mat.set_shader_parameter("spin", 4.5 if kind == DUST else (3.2 if kind == TORNADO else 2.4))
	_mat.set_shader_parameter("scroll", 2.0 if kind == DUST else 1.5)
	_mat.set_shader_parameter("seed", seed)
	_mat.set_shader_parameter("dark_col", Vector3(0.18, 0.17, 0.16) if kind != WSPOUT else Vector3(0.22, 0.23, 0.24))
	_mat.set_shader_parameter("light_col", Vector3(0.60, 0.57, 0.52) if kind != WSPOUT else Vector3(0.72, 0.75, 0.78))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func _particles(mode: int, amount: int, life: float, opacity: float, tint: Color, stretch := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(8, int(amount * (0.25 if _mobile else 1.0)))
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.fixed_fps = 0
	p.explosiveness = 0.0
	p.visibility_aabb = AABB(Vector3(-1200, -200, -1200), Vector3(2400, 1600, 2400))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := ShaderMaterial.new()
	dm.shader = load("res://game/shaders/funnel_spray_draw.gdshader")
	dm.set_shader_parameter("px_per_m", 0.0016)
	dm.set_shader_parameter("opacity", opacity)
	dm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	dm.set_shader_parameter("tint_k", 1.0)
	dm.set_shader_parameter("stretch", stretch)
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = dm
	p.draw_pass_1 = q
	_draw_mats.append(dm)
	var pm := ShaderMaterial.new()
	pm.shader = load("res://game/shaders/funnel_spray.gdshader")
	pm.set_shader_parameter("mode", mode)
	pm.set_shader_parameter("seed_off", seed * 3.0 + float(mode))
	_mats.append(pm)
	p.process_material = pm
	add_child(p)
	return p

func _build_particles() -> void:
	if kind == WSPOUT:
		_spray = _particles(0, 420, 2.6, 0.55, Color(0.85, 0.90, 0.95), 1.0)
		_mist = _particles(3, 380, 4.0, 0.30, Color(0.88, 0.92, 0.95), 1.0)
	else:
		_spray = _particles(1, 700 if kind == TORNADO else 260, 4.5, 0.42, Color(0.62, 0.55, 0.45), 1.0)
		_debris = _particles(2, 280 if kind == TORNADO else 90, 3.2, 0.75, Color(0.45, 0.35, 0.25), 1.0)

## Start it now (after setup), or restart it.
func start() -> void:
	age = 0.0
	active = true
	visible = true
	if _sound.stream != null and not _sound.playing:
		_sound.play()
	for p in [_spray, _debris, _mist]:
		if p != null:
			p.emitting = true

func stop() -> void:
	active = false
	visible = false
	for p in [_spray, _debris, _mist]:
		if p != null:
			p.emitting = false
	if _sound.playing:
		_sound.stop()

func total_life() -> float:
	return form_time + track_time + rope_time + fade_time

## Forms, widens, moves along the wind, rops out and fades. `wind` is the global wind direction source.
func update(delta: float, wind: Wind, terrain: Terrain) -> void:
	if not active:
		return
	_time += delta
	age += delta
	var t_form := form_time
	var t_track := t_form + track_time
	var t_rope := t_track + rope_time
	var t_end := t_rope + fade_time
	# the strength envelope
	if age < t_form:
		strength = smoothstep(0.0, 1.0, age / t_form)
	elif age < t_track:
		strength = 1.0
	elif age < t_rope:
		strength = 1.0 - 0.45 * smoothstep(0.0, 1.0, (age - t_track) / rope_time)
	else:
		strength = 0.55 * (1.0 - smoothstep(0.0, 1.0, (age - t_rope) / fade_time))
	if age >= t_end:
		stop()
		return
	# the width: widens while forming, thins and wobbles while roping out
	var wide := smoothstep(0.0, 1.0, clampf(age / maxf(t_form, 1.0), 0.0, 1.0))
	if age > t_track:
		wide *= 1.0 - 0.55 * smoothstep(0.0, 1.0, (age - t_track) / maxf(rope_time, 1.0))
	var base_radius: float = 0.5 * base_width * (0.35 + 0.65 * wide)
	var wob := 0.0
	if age > t_track:
		wob = sin(_time * 2.7 + seed) * 0.25 * smoothstep(0.0, 1.0, (age - t_track) / maxf(rope_time, 1.0))
	# the funnel drifts and tracks along the wind while it is established
	if age > t_form and age < t_rope and drift.length() < 1.0:
		drift = wind.toward().normalized() * speed
	elif age >= t_rope:
		drift *= 1.0 - 0.6 * delta
	var next := anchor + drift * delta
	if kind == WSPOUT:
		# a waterspout stays over the lake
		if Lake.is_wet(next.x, next.z):
			anchor.x = next.x; anchor.z = next.z
		else:
			drift = Vector3.ZERO
		base_y = _lake_level
	elif kind == TORNADO:
		# a tornado crosses the open meadow and never goes through the cemetery park at home
		var home := Vector2(-18.0, 36.0)
		if next.distance_to(Vector3(anchor.x, 0.0, anchor.z)) >= 0.0:
			if Vector2(next.x, next.z).distance_to(home) > 150.0:
				anchor.x = next.x; anchor.z = next.z
			else:
				# slide round the park instead of through it
				var away := (Vector2(anchor.x, anchor.z) - home).normalized()
				drift = Vector3(away.x, 0.0, away.y) * speed * 0.6
		base_y = terrain.height(anchor.x, anchor.z)
	else:
		anchor.x = next.x; anchor.z = next.z
		base_y = terrain.height(anchor.x, anchor.z)
	anchor.y = base_y
	# place the mesh and the particle fields
	global_position = Vector3(anchor.x, base_y, anchor.z)
	scale = Vector3(base_radius, height, base_radius)
	rotation.y = sin(_time * 0.4 + seed) * 0.35 + wob
	_mat.set_shader_parameter("alpha", 0.25 + 0.70 * strength)
	var centre := Vector3(anchor.x, base_y, anchor.z)
	for m in _mats:
		m.set_shader_parameter("centre", centre)
		m.set_shader_parameter("radius", base_radius)
		m.set_shader_parameter("height", height)
		m.set_shader_parameter("strength", strength)
	for p in [_spray, _debris, _mist]:
		if p != null:
			p.global_position = Vector3.ZERO
			p.emitting = strength > 0.05
	_sound.volume_db = -10.0 + 5.0 * strength
	_sound.global_position = Vector3(anchor.x, base_y + 8.0, anchor.z)

## The wind field: rotation plus inflow plus updraft, strongest at the core, falling off as 1/r, capped so every drone
## stays flyable. Summed into Wind.sample by game/wind.gd.
func wind_at(pos: Vector3) -> Vector3:
	if not active or strength < 0.02:
		return Vector3.ZERO
	var inv_h := 1.0 / maxf(height, 1.0)
	var t := (pos.y - base_y) * inv_h
	if t < -0.05 or t > 1.05:
		return Vector3.ZERO
	t = clampf(t, 0.0, 1.0)
	var base_radius: float = 0.5 * base_width
	var bow := 0.16 * base_radius * sin(t * PI * 1.25) * (1.0 if kind == TORNADO else 0.7)
	var axis := Vector3(anchor.x + bow, base_y + t * height, anchor.z)
	var d := pos - axis
	var r := maxf(Vector2(d.x, d.z).length(), 0.5)
	var core := base_radius * (1.0 + 0.8 * t)
	var falloff := clampf(core / r, 0.0, 1.0)          # 1 inside the core, 1/r outside
	var env := pow(sin(PI * clampf(t, 0.0, 1.0)), 0.35)
	var radial := Vector3(d.x, 0.0, d.z).normalized()
	var tang := Vector3(-radial.z, 0.0, radial.x)
	var v := tang * (18.0 * falloff) - radial * (7.0 * falloff) + Vector3(0.0, 9.0 * sin(PI * t) * falloff, 0.0)
	v *= strength * env
	if v.length() > MAX_WIND:
		v = v.normalized() * MAX_WIND
	return v

## True while the funnel is worth drawing and simulating.
func alive() -> bool:
	return active and age < total_life()

func near(pos: Vector3, reach: float) -> bool:
	return active and Vector2(pos.x - anchor.x, pos.z - anchor.z).length() < reach

func info() -> Dictionary:
	return {"kind": kind, "age": snappedf(age, 0.1), "strength": snappedf(strength, 0.01),
		"anchor": [snappedf(anchor.x, 0.1), snappedf(anchor.y, 0.1), snappedf(anchor.z, 0.1)],
		"height": snappedf(height, 0.1), "width": snappedf(base_width, 0.1)}
