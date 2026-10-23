class_name Funnel
extends Node3D
## A tornado, waterspout or dust devil, rebuilt as a volumetric particle funnel (SPEC-VORTEX-LOOK, session B).
##
## The look is not a painted tube. Thousands of condensation wisps stream down and inward from the cloud base on spiral
## paths, a second layer of droplets glints inside and just outside them, and (for a tornado) a wide dust skirt with
## several hundred tumbling debris pieces orbiting and being lofted. Everything is grey-brown and soft edged, because
## the references show soft, layered, almost photographic funnels rather than hard graphics. A very faint dark shell is
## kept only to hold the dark interior, and a bright spray ring plus a ring on the water marks the foot of a waterspout.
##
## Stages (both): pendant lowering, cone, then wedge (tornado) or a steady tapering cone (waterspout), then a rope out.
## Tornado lives about 2.5 to 4.5 minutes, waterspout about 2 to 3. The wind field, the 22 m/s cap, the roar and the
## menu switches from SPEC-EXTREME-WEATHER stay exactly as they were. Particles live in world space so the funnel can
## move while the emitters sit still.
##
## Budgets (normal / low / high detail, computer): wisps 2500 / 1250 / 3000, droplets 800 / 400 / 950, dust 400 / 200
## / 480, debris 300 / 150 / 360. On a phone: 700, 200, 150 and 80.

const WSPOUT := 0
const TORNADO := 1
const DUST := 2
const MAX_WIND := 22.0

var kind := TORNADO
var detail := 1                  # 0 low, 1 normal, 2 high
var active := false
var anchor := Vector3.ZERO
var base_y := 0.0
var height := 500.0
var base_width := 60.0
var top_ratio := 2.2
var speed := 9.0
var strength := 0.0
var age := 0.0
var form_time := 35.0            # pendant lowering
var mature_time := 120.0         # cone / wedge
var rope_time := 30.0            # roping out
var fade_time := 10.0
var stage := 0.0                 # 0 cone, 1 wedge, 2 rope
var seed := 0.0
var drift := Vector3.ZERO

var _mobile := false
var _time := 0.0
var _mesh: MeshInstance3D
var _mesh_mat: ShaderMaterial
var _wisps: GPUParticles3D
var _wisps_mat: ShaderMaterial
var _drops: GPUParticles3D
var _drops_mat: ShaderMaterial
var _core: GPUParticles3D
var _core_mat: ShaderMaterial
var _dust: GPUParticles3D
var _dust_mat: ShaderMaterial
var _spray: GPUParticles3D
var _spray_mat: ShaderMaterial
var _plume: GPUParticles3D
var _plume_mat: ShaderMaterial
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
var _cloud: MeshInstance3D
var _cloud_mat: ShaderMaterial
var _debris: Array[MultiMeshInstance3D] = []
var _debris_state: Array[Dictionary] = []
var _debris_count := 0
var _sound: AudioStreamPlayer3D
var _terrain: Terrain
var _lake_level := Lake.LEVEL

## `roar` is the looped low roar stream made in game/weather_events.gd. Call start() after setup.
func setup(fkind: int, at: Vector3, terrain: Terrain, roar: AudioStream, detail_level := 1) -> void:
	kind = fkind
	detail = detail_level
	anchor = at
	_terrain = terrain
	_mobile = OS.has_feature("mobile")
	seed = randf() * 20.0
	base_y = at.y
	if kind == WSPOUT:
		height = randf_range(340.0, 640.0)
		base_width = randf_range(12.0, 40.0)
		top_ratio = 1.6
		speed = randf_range(3.0, 5.5)
		form_time = randf_range(35.0, 55.0)
		mature_time = randf_range(55.0, 95.0)
		rope_time = randf_range(18.0, 30.0)
		fade_time = 9.0
	elif kind == DUST:
		height = randf_range(60.0, 150.0)
		base_width = randf_range(3.0, 10.0)
		top_ratio = 1.25
		speed = randf_range(2.0, 4.5)
		form_time = randf_range(8.0, 14.0)
		mature_time = randf_range(18.0, 30.0)
		rope_time = randf_range(6.0, 10.0)
		fade_time = 5.0
	else:
		height = randf_range(380.0, 900.0)
		base_width = randf_range(35.0, 150.0)
		top_ratio = 2.3
		speed = randf_range(7.0, 15.0)
		form_time = randf_range(30.0, 45.0)
		mature_time = randf_range(100.0, 190.0)
		rope_time = randf_range(22.0, 40.0)
		fade_time = 10.0
	height *= 1.0
	_build_shell()
	_build_particles()
	_build_cloud()
	if kind == TORNADO:
		_build_debris()
	_build_sound(roar)
	visible = false
	active = false

# ------------------------------------------------------------------ the faint shell that keeps the interior dark
func _build_shell() -> void:
	var rings := 22 if _mobile else 30
	var segs := 18 if _mobile else 26
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in rings + 1:
		var t := float(r) / float(rings)
		var rad := _profile(t)
		var bow := 0.18 * sin(t * PI * 1.3) * (1.0 if kind == TORNADO else 0.7)
		for s in segs + 1:
			var a := TAU * float(s) / float(segs)
			var p := Vector3(cos(a) * rad + bow, t, sin(a) * rad)
			verts.append(p)
			norms.append(Vector3(cos(a), 0.0, sin(a)).normalized())
			uvs.append(Vector2(float(s) / float(segs), t))
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
	_mesh_mat = ShaderMaterial.new()
	_mesh_mat.shader = load("res://game/shaders/funnel_funnel.gdshader")
	_mesh_mat.set_shader_parameter("alpha", 0.12)
	_mesh_mat.set_shader_parameter("spin", 2.6 if kind != DUST else 4.0)
	_mesh_mat.set_shader_parameter("scroll", 1.2)
	_mesh_mat.set_shader_parameter("seed", seed)
	_mesh_mat.set_shader_parameter("dark_col", Vector3(0.10, 0.10, 0.10))
	_mesh_mat.set_shader_parameter("light_col", Vector3(0.30, 0.29, 0.27))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.material_override = _mesh_mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func _profile(t: float) -> float:
	# unit radius profile: narrow foot, wide top, a little flare under the cloud
	return lerpf(1.0, top_ratio, smoothstep(0.0, 1.0, t)) + 0.45 * top_ratio * smoothstep(0.84, 1.0, t)

# ------------------------------------------------------------------ particle layers
func _amount(normal: int) -> int:
	var k := 1.0
	if _mobile:
		k = 0.28
	else:
		k = [0.5, 1.0, 1.2][clampi(detail, 0, 2)]
	return maxi(8, int(normal * k))

func _emit(mode: int, normal: int, life: float, world_uniforms: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = _amount(normal)
	p.lifetime = life
	p.emitting = false
	p.local_coords = true
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-2000, -500, -2000), Vector3(4000, 3000, 4000))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := ShaderMaterial.new()
	dm.shader = load("res://game/shaders/vortex_wisp_draw.gdshader")
	dm.set_shader_parameter("px_per_m", 0.0016)
	dm.set_shader_parameter("opacity", 1.0)
	dm.set_shader_parameter("tint", Vector3(0.50, 0.51, 0.52) if mode == 0 else (Vector3(0.34, 0.35, 0.37) if mode == 2 else Vector3(0.80, 0.83, 0.86)))
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = dm
	p.draw_pass_1 = q
	var pm := ShaderMaterial.new()
	pm.shader = load("res://game/shaders/vortex_wisp.gdshader")
	pm.set_shader_parameter("mode", mode)
	pm.set_shader_parameter("seed_off", seed + float(mode) * 3.0)
	p.process_material = pm
	p.set_meta("draw_mat", dm)
	p.set_meta("proc_mat", pm)
	add_child(p)
	return p

func _build_particles() -> void:
	_wisps = _emit(0, 1800, 5.0, true)
	_wisps_mat = _wisps.get_meta("proc_mat")
	_drops = _emit(1, 800, 3.4, true)
	_drops_mat = _drops.get_meta("proc_mat")
	_core = _emit(2, 1200, 4.6, true)
	_core_mat = _core.get_meta("proc_mat")
	if kind == TORNADO:
		_dust = _spray_like(1, 400, 4.2, Color(0.55, 0.50, 0.44), 0.75)
		_dust_mat = _dust.get_meta("proc_mat")
	elif kind == WSPOUT:
		_spray = _spray_like(0, 320, 2.4, Color(0.85, 0.90, 0.95), 1.0)
		_spray_mat = _spray.get_meta("proc_mat")
		_plume = _spray_like(3, 260, 3.6, Color(0.88, 0.92, 0.95), 1.0)
		_plume_mat = _plume.get_meta("proc_mat")
		var disc := NewModels2.funnel_ring_disc(48, 0.42)
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = load("res://game/shaders/spout_ring.gdshader")
		_ring_mat.set_shader_parameter("seed", seed)
		_ring = MeshInstance3D.new()
		_ring.mesh = disc
		_ring.material_override = _ring_mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
	else:
		_dust = _spray_like(1, 200, 3.2, Color(0.60, 0.53, 0.44), 1.0)
		_dust_mat = _dust.get_meta("proc_mat")

	# the dust skirt and the spray/plume use the older funnel_spray shader, which already does rings and mist
func _spray_like(mode: int, normal: int, life: float, tint: Color, opacity: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = _amount(normal)
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-2000, -300, -2000), Vector3(4000, 2400, 4000))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := ShaderMaterial.new()
	dm.shader = load("res://game/shaders/funnel_spray_draw.gdshader")
	dm.set_shader_parameter("px_per_m", 0.0016)
	dm.set_shader_parameter("opacity", opacity)
	dm.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	dm.set_shader_parameter("tint_k", 1.0)
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = dm
	p.draw_pass_1 = q
	var pm := ShaderMaterial.new()
	pm.shader = load("res://game/shaders/funnel_spray.gdshader")
	pm.set_shader_parameter("mode", mode)
	pm.set_shader_parameter("seed_off", seed * 3.0 + float(mode))
	p.process_material = pm
	p.set_meta("proc_mat", pm)
	add_child(p)
	return p

# ------------------------------------------------------------------ the cloud base above it
func _build_cloud() -> void:
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = load("res://game/shaders/vortex_cloud.gdshader")
	_cloud_mat.set_shader_parameter("seed", seed)
	_cloud = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	_cloud.mesh = q
	_cloud.material_override = _cloud_mat
	_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud)

# ------------------------------------------------------------------ debris (tornado)
func _build_debris() -> void:
	var pieces := NewModels2.debris_pieces()
	var total := 300
	if _mobile:
		total = 80
	else:
		total = [150, 300, 360][clampi(detail, 0, 2)]
	_debris_count = total
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed * 1000.0) + 11
	var per := int(ceil(float(total) / 4.0))
	for k in 4:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pieces[k % pieces.size()]
		mm.instance_count = per
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_debris.append(mmi)
		for i in per:
			_debris_state.append({
				"mi": k, "i": i,
				"ang": rng.randf() * TAU, "ang_v": rng.randf_range(1.0, 2.6) * (1.0 if rng.randf() < 0.7 else -1.0),
				"rad": rng.randf_range(0.55, 1.5),
				"t0": rng.randf() * 0.75,
				"rise": rng.randf_range(0.25, 1.0),
				"size": rng.randf_range(0.6, 2.2),
				"tumble": Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU),
				"spin": rng.randf_range(1.0, 5.0),
			})

func _tick_debris(delta: float, radius_now: float) -> void:
	if _debris.is_empty():
		return
	for st in _debris_state:
		st["ang"] = float(st["ang"]) + float(st["ang_v"]) * delta
		st["tumble"] = (st["tumble"] as Vector3) + Vector3(0.7, 1.1, 0.5) * float(st["spin"]) * delta
		var t := fmod(float(st["t0"]) + _time * 0.07 * float(st["rise"]), 1.0)
		var h := height * (0.02 + 0.55 * t)
		var rad := radius_now * float(st["rad"]) * (1.0 + 0.6 * t)
		var ang := float(st["ang"])
		var p := Vector3(anchor.x + cos(ang) * rad, base_y + h, anchor.z + sin(ang) * rad)
		var sz := float(st["size"])
		var b := Basis.from_euler(st["tumble"] as Vector3).scaled(Vector3.ONE * sz)
		(_debris[int(st["mi"])].multimesh as MultiMesh).set_instance_transform(int(st["i"]), Transform3D(b, p))

func _build_sound(roar: AudioStream) -> void:
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = roar
	_sound.bus = "Weather" if AudioServer.get_bus_index("Weather") >= 0 else "Master"
	_sound.unit_size = 42.0
	_sound.max_distance = 5000.0
	_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_sound.volume_db = -8.0
	add_child(_sound)

# ------------------------------------------------------------------ life cycle
func start() -> void:
	age = 0.0
	active = true
	visible = true
	if _sound.stream != null and not _sound.playing:
		_sound.play()
	for p in [_wisps, _drops, _core, _dust, _spray, _plume]:
		if p != null:
			p.emitting = true

func stop() -> void:
	active = false
	visible = false
	for p in [_wisps, _drops, _core, _dust, _spray, _plume]:
		if p != null:
			p.emitting = false
	if _ring != null:
		_ring.visible = false
	if _sound.playing:
		_sound.stop()

func total_life() -> float:
	return form_time + mature_time + rope_time + fade_time

func update(delta: float, wind: Wind, terrain: Terrain) -> void:
	if not active:
		return
	_time += delta
	age += delta
	var t_form := form_time
	var t_mature := t_form + mature_time
	var t_rope := t_mature + rope_time
	var t_end := t_rope + fade_time
	# strength envelope
	if age < t_form:
		strength = smoothstep(0.0, 1.0, age / t_form)
	elif age < t_mature:
		strength = 1.0
	elif age < t_rope:
		strength = 1.0 - 0.55 * smoothstep(0.0, 1.0, (age - t_mature) / rope_time)
	else:
		strength = 0.45 * (1.0 - smoothstep(0.0, 1.0, (age - t_rope) / fade_time))
	if age >= t_end:
		stop()
		return
	# stages: pendant cone, then wedge for a tornado, then a rope
	var rope_k := 0.0
	if age > t_mature:
		rope_k = smoothstep(0.0, 1.0, (age - t_mature) / maxf(rope_time, 1.0))
	if age < t_form:
		stage = 0.0
	elif kind == TORNADO and rope_k < 0.15:
		stage = 1.0
	else:
		stage = 2.0 * rope_k
	# the funnel widens while it forms, then thins as it ropes out
	var wide := smoothstep(0.0, 1.0, clampf(age / maxf(t_form, 1.0), 0.0, 1.0))
	if rope_k > 0.0:
		wide *= 1.0 - 0.55 * rope_k
	var radius_now: float = 0.5 * base_width * (0.35 + 0.65 * wide)
	# movement: over the lake or across the meadow
	if age > t_form and age < t_rope and drift.length() < 1.0:
		drift = wind.toward().normalized() * speed
	elif age >= t_rope:
		drift *= 1.0 - 0.6 * delta
	var next := anchor + drift * delta
	if kind == WSPOUT:
		if Lake.is_wet(next.x, next.z):
			anchor.x = next.x; anchor.z = next.z
		else:
			drift = Vector3.ZERO
		base_y = _terrain.height(anchor.x, anchor.z) if _terrain else _lake_level
		if _lake_level > 0.0:
			base_y = _lake_level
		anchor.y = base_y
	elif kind == TORNADO:
		var home := Vector2(-18.0, 36.0)
		if Vector2(next.x, next.z).distance_to(home) > 150.0:
			anchor.x = next.x; anchor.z = next.z
		else:
			var away := (Vector2(anchor.x, anchor.z) - home).normalized()
			drift = Vector3(away.x, 0.0, away.y) * speed * 0.6
		base_y = _terrain.height(anchor.x, anchor.z) if _terrain else anchor.y
		anchor.y = base_y
	else:
		anchor.x = next.x; anchor.z = next.z
		if _terrain:
			base_y = _terrain.height(anchor.x, anchor.z)
		anchor.y = base_y
	global_position = Vector3(anchor.x, base_y, anchor.z)
	# the faint shell
	var squash := 1.0 - 0.35 * rope_k
	_mesh.scale = Vector3(radius_now * squash, height, radius_now * squash)
	_mesh.rotation.y = sin(_time * 0.4 + seed) * 0.35 + rope_k * sin(_time * 1.3) * 0.4
	_mesh_mat.set_shader_parameter("alpha", 0.05 + 0.09 * strength)
	# the particle uniforms, shared by the wisp and droplet layers
	var centre := Vector3(anchor.x, base_y, anchor.z)
	for m in [_wisps_mat, _drops_mat, _core_mat]:
		if m:
			m.set_shader_parameter("centre", centre)
			m.set_shader_parameter("height", height)
			m.set_shader_parameter("base_radius", radius_now)
			m.set_shader_parameter("top_ratio", top_ratio)
			m.set_shader_parameter("stage", stage)
			m.set_shader_parameter("strength", strength)
			m.set_shader_parameter("spin", 1.6 if kind == TORNADO else 1.15)
	# the dust skirt and the spray
	var dust_r := radius_now * (3.0 + 2.0 * stage)
	var dust_h := height * 0.35
	for pair in [[_dust, _dust_mat], [_spray, _spray_mat], [_plume, _plume_mat]]:
		var p: GPUParticles3D = pair[0]
		var m: ShaderMaterial = pair[1]
		if p == null or m == null:
			continue
		m.set_shader_parameter("centre", centre)
		m.set_shader_parameter("radius", dust_r if p == _dust else radius_now * 1.6)
		m.set_shader_parameter("height", dust_h if p == _dust else height * 0.25)
		m.set_shader_parameter("strength", strength)
		p.global_position = Vector3.ZERO
		var formed := age > t_form * 0.65
		p.emitting = formed and strength > 0.05
	# the waterspout spray ring on the water
	if _ring != null:
		_ring.visible = kind == WSPOUT and strength > 0.08
		_ring.global_position = Vector3(anchor.x, base_y + 0.35, anchor.z)
		_ring.scale = Vector3(radius_now * 1.7, 1.0, radius_now * 1.7)
		_ring_mat.set_shader_parameter("strength", strength)
	if _cloud != null:
		_cloud.global_position = Vector3(anchor.x, base_y + height, anchor.z)
		_cloud.scale = Vector3(radius_now * 9.0, radius_now * 9.0, 1.0)
		_cloud.rotation = Vector3(-PI * 0.5, 0.0, _time * 0.03 + seed)
		_cloud_mat.set_shader_parameter("strength", strength)
	_tick_debris(delta, radius_now)
	_sound.volume_db = -10.0 + 5.0 * strength
	_sound.global_position = Vector3(anchor.x, base_y + 8.0, anchor.z)

# ------------------------------------------------------------------ wind
func wind_at(pos: Vector3) -> Vector3:
	if not active or strength < 0.02:
		return Vector3.ZERO
	var inv_h := 1.0 / maxf(height, 1.0)
	var t := (pos.y - base_y) * inv_h
	if t < -0.05 or t > 1.05:
		return Vector3.ZERO
	t = clampf(t, 0.0, 1.0)
	var base_radius: float = 0.5 * base_width
	var profile := _profile(t) * (1.0 - 0.35 * clampf(stage / 2.0, 0.0, 1.0))
	var axis := Vector3(anchor.x, base_y + t * height, anchor.z)
	var d := pos - axis
	var r := maxf(Vector2(d.x, d.z).length(), 0.5)
	var core := base_radius * profile
	var falloff := clampf(core / r, 0.0, 1.0)
	var env := pow(sin(PI * clampf(t, 0.0, 1.0)), 0.35)
	var radial := Vector3(d.x, 0.0, d.z).normalized()
	var tang := Vector3(-radial.z, 0.0, radial.x)
	var v := tang * (18.0 * falloff) - radial * (7.0 * falloff) + Vector3(0.0, 9.0 * sin(PI * t) * falloff, 0.0)
	v *= strength * env
	if v.length() > MAX_WIND:
		v = v.normalized() * MAX_WIND
	return v

func alive() -> bool:
	return active and age < total_life()

func near(pos: Vector3, reach: float) -> bool:
	return active and Vector2(pos.x - anchor.x, pos.z - anchor.z).length() < reach

func info() -> Dictionary:
	return {"kind": kind, "age": snappedf(age, 0.1), "strength": snappedf(strength, 0.01),
		"anchor": [snappedf(anchor.x, 0.1), snappedf(anchor.y, 0.1), snappedf(anchor.z, 0.1)],
		"height": snappedf(height, 0.1), "width": snappedf(base_width, 0.1), "stage": snappedf(stage, 0.01),
		"particles": _wisps.amount + _drops.amount + (_dust.amount if _dust else 0), "debris": _debris_count}
