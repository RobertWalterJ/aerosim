class_name WildlifeObjects
extends Node3D
## Code placeholders for the night pasture (session B): the sheep flock, the wolf at the field edge, and their heat
## signatures for the thermal camera. Claude's wolf and sheep models will replace these. No collisions and no gore.

var _wolf: Node3D
var _wolf_heat: MeshInstance3D
var _sheep_heat: Array[MeshInstance3D] = []
var _wolf_pos := Vector3.ZERO

func setup(t: Terrain) -> void:
	var s := CaseObjects.SHEEP_SPOT
	var base := Vector3(s.x, t.height(s.x, s.y), s.y)
	for i in 7:
		var off := Vector3(-2.4 + float(i % 3) * 2.4, 0.0, -2.0 + float(i / 3) * 3.0)
		_build_sheep(base + off)
	var w := CaseObjects.WOLF_SPOT
	_wolf_pos = Vector3(w.x, t.height(w.x, w.y), w.y)
	_build_wolf(_wolf_pos)
	_wolf.visible = false
	_wolf_heat.visible = false
	for m in _sheep_heat:
		m.visible = false
	print("wildlife objects: sheep=7 wolf=", _wolf_pos)

func wolf_position() -> Vector3:
	return _wolf_pos

func show_wolf() -> void:
	if _wolf != null:
		_wolf.visible = true

func set_thermal_markers(on: bool) -> void:
	if _wolf_heat != null:
		_wolf_heat.visible = on and _wolf != null and _wolf.visible
	for m in _sheep_heat:
		m.visible = on

func _build_sheep(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = randf_range(0.0, TAU)
	add_child(root)
	var wool := StandardMaterial3D.new()
	wool.albedo_color = Color(0.80, 0.78, 0.68)
	wool.roughness = 0.95
	var face := StandardMaterial3D.new()
	face.albedo_color = Color(0.28, 0.24, 0.20)
	face.roughness = 0.9
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 0.86
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = wool
	bmi.position.y = 0.55
	bmi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	root.add_child(bmi)
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.26
	var hmi := MeshInstance3D.new()
	hmi.mesh = head
	hmi.material_override = face
	hmi.position = Vector3(0.0, 0.62, -0.52)
	root.add_child(hmi)
	for p in [Vector3(-0.22, 0.25, -0.3), Vector3(0.22, 0.25, -0.3), Vector3(-0.22, 0.25, 0.3), Vector3(0.22, 0.25, 0.3)]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.09, 0.5, 0.09)
		var lmi := MeshInstance3D.new()
		lmi.mesh = leg
		lmi.material_override = face
		lmi.position = p
		root.add_child(lmi)
	var heat := _heat_mesh(0.55, 1.1)
	heat.position.y = 0.6
	root.add_child(heat)
	_sheep_heat.append(heat)

func _build_wolf(pos: Vector3) -> void:
	_wolf = Node3D.new()
	_wolf.position = pos
	_wolf.rotation.y = -0.9
	add_child(_wolf)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.30, 0.28, 0.24)
	fur.roughness = 0.92
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.15, 0.13)
	dark.roughness = 0.95
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 1.18
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = fur
	bmi.position.y = 0.52
	bmi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_wolf.add_child(bmi)
	var head := BoxMesh.new()
	head.size = Vector3(0.34, 0.28, 0.44)
	var hmi := MeshInstance3D.new()
	hmi.mesh = head
	hmi.material_override = fur
	hmi.position = Vector3(0.0, 0.62, -0.72)
	_wolf.add_child(hmi)
	var snout := BoxMesh.new()
	snout.size = Vector3(0.18, 0.15, 0.25)
	var smi := MeshInstance3D.new()
	smi.mesh = snout
	smi.material_override = dark
	smi.position = Vector3(0.0, 0.56, -0.96)
	_wolf.add_child(smi)
	for sx in [-1.0, 1.0]:
		var ear := BoxMesh.new()
		ear.size = Vector3(0.10, 0.20, 0.06)
		var emi := MeshInstance3D.new()
		emi.mesh = ear
		emi.material_override = dark
		emi.position = Vector3(sx * 0.11, 0.82, -0.66)
		_wolf.add_child(emi)
	for p in [Vector3(-0.20, 0.25, -0.38), Vector3(0.20, 0.25, -0.38), Vector3(-0.20, 0.25, 0.38), Vector3(0.20, 0.25, 0.38)]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.12, 0.52, 0.12)
		var lmi := MeshInstance3D.new()
		lmi.mesh = leg
		lmi.material_override = fur
		lmi.position = p
		_wolf.add_child(lmi)
	var tail := BoxMesh.new()
	tail.size = Vector3(0.12, 0.12, 0.62)
	var tmi := MeshInstance3D.new()
	tmi.mesh = tail
	tmi.material_override = fur
	tmi.position = Vector3(0.0, 0.62, 0.82)
	tmi.rotation.x = -0.25
	_wolf.add_child(tmi)
	_wolf_heat = _heat_mesh(0.9, 2.0)
	_wolf_heat.position.y = 0.75
	_wolf.add_child(_wolf_heat)

func _heat_mesh(radius: float, height: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	m.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.35, 0.90)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.12)
	mat.emission_energy_multiplier = 8.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.78, 0.35, 0.90)
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	return m
