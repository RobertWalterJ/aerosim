class_name ThermalHeat
extends RefCounted
## The heat shells for the thermal camera (session B realism pass). These are not visible to the normal camera. Each
## shell is an unshaded flat colour that the thermal post-process decodes:
##   magenta = a warm body, red = an engine or exhaust, pale magenta = a warm cabin or window.
## The shell shapes follow the thing they belong to, so a sheep reads as a sheep and a car reads as a car, not a blob.

const BODY := Color(0.75, 0.0, 1.0)
const ENGINE := Color(1.0, 0.0, 0.25)
const WARM := Color(1.0, 0.50, 1.0)
const ANIMAL := Color(0.58, 0.0, 1.0)
const COLD := Color(0.0, 0.62, 1.0)   # cyan = a negative/cold body, decoded by the shader as a radiant cold glow

static func material(code: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = code
	m.metallic = 0.0
	m.roughness = 1.0
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m

## A fading ground trace: a heat code that can blend with the grass or road. Shown only while the thermal camera is on.
static func trace_material(code: Color, alpha: float) -> StandardMaterial3D:
	var m := material(code)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(code.r, code.g, code.b, clampf(alpha, 0.05, 0.95))
	m.no_depth_test = false
	return m

static func shell(parent: Node3D, mesh: Mesh, xf: Transform3D, code: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(code)
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m

static func sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m

static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

## A person: a torso, a head and two hands. The head and hands are hotter than the coat.
static func person(parent: Node3D, pos: Vector3, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	# The coat insulates the torso; the head and hands are the warmer exposed parts.
	# These dimensions match CharacterActor (torso 0.205 x 1.06, head 0.108, hands at ~0.83 m).
	shell(root, capsule(0.24, 0.52), Transform3D(Basis(), Vector3(0.0, 1.16, 0.0)), WARM)
	shell(root, sphere(0.115), Transform3D(Basis(), Vector3(0.0, 1.58, 0.0)), BODY)
	for sx in [-1.0, 1.0]:
		shell(root, sphere(0.050), Transform3D(Basis(), Vector3(sx * 0.272, 0.83, -0.02)), BODY)
	return root

## A four-legged animal body, head and a small warm patch at the muzzle.
static func animal(parent: Node3D, pos: Vector3, length: float, height: float, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	shell(root, capsule(length * 0.20, length * 0.72), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, height * 0.58, 0.0)), ANIMAL)
	shell(root, sphere(length * 0.14), Transform3D(Basis(), Vector3(0.0, height * 0.66, -length * 0.42)), BODY)
	return root

## A road vehicle: a hot engine, a warm cabin and a hot exhaust. The body stays cool.
static func vehicle(parent: Node3D, body: Vector3, cab: Vector3, cab_y: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	shell(root, box(Vector3(body.x * 0.60, 0.34, 0.55)), Transform3D(Basis(), Vector3(0.0, 0.58, -body.z * 0.34)), ENGINE)
	shell(root, box(Vector3(cab.x * 0.76, cab.y * 0.52, cab.z * 0.66)), Transform3D(Basis(), Vector3(0.0, cab_y + 0.20, -0.25)), WARM)
	shell(root, box(Vector3(0.24, 0.16, 0.26)), Transform3D(Basis(), Vector3(body.x * 0.24, 0.36, body.z * 0.46)), ENGINE)
	return root

## A ghost: a completely cold figure with a radiant negative halo. The body reads colder than the valley around it,
## a strong cold contrast to every living warm body.
static func ghost(parent: Node3D, pos: Vector3, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	shell(root, capsule(0.24, 0.52), Transform3D(Basis(), Vector3(0.0, 1.16, 0.0)), COLD)
	shell(root, sphere(0.115), Transform3D(Basis(), Vector3(0.0, 1.58, 0.0)), COLD)
	for sx in [-1.0, 1.0]:
		shell(root, sphere(0.050), Transform3D(Basis(), Vector3(sx * 0.272, 0.83, -0.02)), COLD)
	var halo := MeshInstance3D.new()
	halo.mesh = capsule(0.68, 1.6)
	halo.material_override = trace_material(COLD, 0.30)
	halo.transform = Transform3D(Basis(), Vector3(0.0, 1.2, 0.0))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root

## A drone: a warm body and four hot motors.
static func drone(parent: Node3D, pos: Vector3, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	parent.add_child(root)
	shell(root, box(Vector3(0.34, 0.12, 0.42)), Transform3D(Basis(), Vector3(0.0, 0.10, 0.0)), WARM)
	for sx in [-0.28, 0.28]:
		for sz in [-0.28, 0.28]:
			shell(root, sphere(0.055), Transform3D(Basis(), Vector3(sx * 0.55, 0.15, sz * 0.55)), ENGINE)
	return root
