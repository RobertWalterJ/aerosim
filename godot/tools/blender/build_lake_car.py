# Lake Car, the 1980s estate at the north shore.
# Run:
#   blender.exe -b --python tools/blender/build_lake_car.py
#
# This is the first real modelling slice from the vehicle backlog, not the full fleet. It is a deliberately
# low-poly hero prop: the story object needs to read as an abandoned 1980s estate from 5 m and from 60 m.
# Frame follows the project contract after glTF export: origin on the ground under the centre, forward local -Z,
# right local +X. In Blender the car is modelled with +Y as the front, which exports as glTF -Z forward.
import bpy
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "story", "lake_car.glb")
PREVIEW = os.path.join(ROOT, "docs", "realism", "models", "lake_car_preview.png")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
os.makedirs(os.path.dirname(PREVIEW), exist_ok=True)

# ------------------------------------------------------------------ scene helpers
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    for item in list(block):
        if item.users == 0:
            block.remove(item)

def mat(name, color, rough=0.7, metal=0.0, alpha=1.0, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, alpha)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if alpha < 1.0:
        m.blend_method = 'BLEND'
        m.show_transparent_back = False
    return m

NAVY = mat("body_navy", (0.055, 0.10, 0.18), 0.72, 0.18)
NAVY_DARK = mat("body_navy_dark", (0.035, 0.065, 0.115), 0.78, 0.12)
ROOF = mat("roof_bleached", (0.29, 0.32, 0.34), 0.88, 0.05)
GLASS = mat("glass", (0.05, 0.08, 0.10), 0.18, 0.25, 0.46)
GLASS_CRACKED = mat("glass_cracked", (0.09, 0.12, 0.13), 0.42, 0.10, 0.55)
RUBBER = mat("wheel_rubber", (0.018, 0.018, 0.020), 0.95, 0.0)
STEEL = mat("wheel_steel", (0.25, 0.25, 0.24), 0.55, 0.65)
RUST = mat("rust", (0.26, 0.105, 0.055), 0.98, 0.0)
ALGAE = mat("algae_sill", (0.15, 0.18, 0.105), 1.0, 0.0)
CHROME = mat("chrome", (0.45, 0.45, 0.43), 0.35, 0.9)
HEAD = mat("headlamp", (0.82, 0.78, 0.60), 0.25, 0.0, emission=(0.7, 0.62, 0.4))
TAIL = mat("taillamp", (0.55, 0.06, 0.04), 0.35, 0.0, emission=(0.5, 0.02, 0.01))
INTERIOR = mat("interior_dark", (0.055, 0.06, 0.055), 0.95, 0.0)
SEAT = mat("seat_worn", (0.19, 0.16, 0.13), 0.95, 0.0)
PLATE = mat("plate", (0.78, 0.76, 0.62), 0.7, 0.0)
TAG = mat("evidence_tag", (0.95, 0.55, 0.08), 0.55, 0.0)

def empty(name, parent=None, loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    e.location = loc
    if parent:
        e.parent = parent
    return e

def box(name, size, loc, material, parent, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = rot
    if bevel > 0.0:
        b = o.modifiers.new("bevel", 'BEVEL')
        b.width = bevel
        b.segments = 2
        b.limit_method = 'ANGLE'
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
    o.data.materials.append(material)
    o.parent = parent
    return o

def cyl(name, radius, depth, loc, material, parent, axis='X', verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.name = name
    if axis == 'X':
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == 'Y':
        o.rotation_euler = (math.pi / 2, 0, 0)
    o.data.materials.append(material)
    o.parent = parent
    return o

def text(name, body, loc, material, parent, size=0.11, rot=(math.pi / 2, 0, 0)):
    bpy.ops.object.text_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.data.body = body
    o.data.align_x = 'CENTER'
    o.data.align_y = 'CENTER'
    o.data.size = size
    o.data.extrude = 0.0015
    o.rotation_euler = rot
    o.data.materials.append(material)
    o.parent = parent
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.convert(target='MESH')
    return o

# ------------------------------------------------------------------ the car
root = empty("lake_car")
root.location = (0, 0, 0)

# body: an 1980s five-door estate, long roof and a boxy rear
box("body_lower", (1.80, 4.58, 0.48), (0, 0, 0.62), NAVY, root, bevel=0.055)
box("body_sill_l", (0.08, 4.22, 0.22), (-0.88, 0, 0.40), NAVY_DARK, root, bevel=0.025)
box("body_sill_r", (0.08, 4.22, 0.22), (0.88, 0, 0.40), NAVY_DARK, root, bevel=0.025)
box("hood", (1.72, 1.42, 0.20), (0, 1.55, 0.87), NAVY, root, bevel=0.045)
box("cabin", (1.64, 2.55, 0.62), (0, -0.18, 1.05), NAVY, root, bevel=0.06)
box("roof", (1.55, 2.10, 0.10), (0, -0.28, 1.40), ROOF, root, bevel=0.035)
box("tailgate", (1.59, 0.12, 0.66), (0, -1.45, 0.98), NAVY, root, bevel=0.03)
box("bonnet_lip", (1.58, 0.10, 0.10), (0, 2.24, 0.90), CHROME, root, bevel=0.02)
box("front_bumper", (1.82, 0.18, 0.20), (0, 2.30, 0.46), CHROME, root, bevel=0.03)
box("rear_bumper", (1.82, 0.16, 0.20), (0, -2.31, 0.48), CHROME, root, bevel=0.03)
box("front_valance", (1.68, 0.06, 0.22), (0, 2.29, 0.68), NAVY_DARK, root, bevel=0.015)
box("grille", (0.92, 0.055, 0.20), (0, 2.265, 0.82), CHROME, root, bevel=0.015)
for sx in (-1, 1):
    box("lamp_head_" + ("l" if sx < 0 else "r"), (0.36, 0.07, 0.20), (sx * 0.58, 2.28, 0.84), HEAD, root, bevel=0.015)
    box("lamp_tail_" + ("l" if sx < 0 else "r"), (0.30, 0.07, 0.30), (sx * 0.66, -2.27, 0.84), TAIL, root, bevel=0.015)
    box("mirror_" + ("l" if sx < 0 else "r"), (0.16, 0.20, 0.08), (sx * 0.93, 0.68, 1.22), NAVY_DARK, root, bevel=0.02)
    # rust at the rear arch and the front wing
    box("rust_arch_" + ("l" if sx < 0 else "r"), (0.03, 0.62, 0.20), (sx * 0.905, -1.35, 0.60), RUST, root)
    box("rust_wing_" + ("l" if sx < 0 else "r"), (0.03, 0.34, 0.12), (sx * 0.905, 1.62, 0.62), RUST, root)
    box("algae_" + ("l" if sx < 0 else "r"), (0.02, 3.20, 0.07), (sx * 0.906, -0.05, 0.31), ALGAE, root)

# glazing. Side windows are inset panels; the windscreen and rear screen are separate cracked pieces.
box("windscreen", (1.44, 0.055, 0.42), (0, 1.08, 1.22), GLASS, root, bevel=0.012, rot=(math.radians(-25), 0, 0))
box("rear_screen", (1.40, 0.055, 0.40), (0, -1.38, 1.20), GLASS_CRACKED, root, bevel=0.012, rot=(math.radians(20), 0, 0))
for sx in (-1, 1):
    box("side_glass_front_" + ("l" if sx < 0 else "r"), (0.035, 0.76, 0.38), (sx * 0.846, 0.30, 1.20), GLASS, root)
    box("side_glass_rear_" + ("l" if sx < 0 else "r"), (0.035, 0.86, 0.36), (sx * 0.846, -0.62, 1.18), GLASS_CRACKED if sx > 0 else GLASS, root)
box("roof_rack_l", (0.045, 2.00, 0.035), (-0.56, -0.25, 1.46), CHROME, root)
box("roof_rack_r", (0.045, 2.00, 0.035), (0.56, -0.25, 1.46), CHROME, root)
for sy in (-0.95, 0.25):
    box("roof_rack_cross_%s" % sy, (1.12, 0.035, 0.03), (0, sy, 1.46), CHROME, root)

# the wheels: separate named pivots, axle along local X, tyres resting at Z 0.33
for key, sx, sy in (("fl", -0.84, 1.46), ("fr", 0.84, 1.46), ("rl", -0.84, -1.46), ("rr", 0.84, -1.46)):
    pivot = empty("wheel_" + key, root, (sx, sy, 0.34))
    cyl("tyre_" + key, 0.325, 0.22, (0, 0, 0), RUBBER, pivot, axis='X', verts=24)
    cyl("rim_" + key, 0.185, 0.225, (0, 0, 0), STEEL, pivot, axis='X', verts=16)
    # a missing hubcap on the rear left, as the brief asks for a shabby abandoned car
    if key != "rl":
        cyl("hub_" + key, 0.11, 0.235, (0, 0, 0), CHROME, pivot, axis='X', verts=12)

# interior visible through the glass: dash, right-hand-drive wheel, two worn seats
box("dash", (1.46, 0.24, 0.20), (0, 1.02, 0.98), INTERIOR, root, bevel=0.02)
box("seat_driver", (0.46, 0.48, 0.48), (0.36, 0.12, 0.92), SEAT, root, bevel=0.03)
box("seat_passenger", (0.46, 0.48, 0.48), (-0.36, 0.12, 0.92), SEAT, root, bevel=0.03)
box("seat_rear", (1.30, 0.40, 0.20), (0, -0.88, 0.80), SEAT, root, bevel=0.03)
bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.022, major_segments=16, minor_segments=6, location=(0.36, 0.84, 1.02))
wheel_o = bpy.context.object
wheel_o.name = "steering_wheel"
wheel_o.rotation_euler = (math.radians(90), 0, 0)
wheel_o.data.materials.append(INTERIOR)
wheel_o.parent = root

# evidence tag on the rear and a clean empty plate, front and rear
box("evidence_tag", (0.17, 0.015, 0.08), (0.68, -2.36, 0.72), TAG, root)
box("plate_front", (0.42, 0.018, 0.11), (0, 2.375, 0.55), PLATE, root)
box("plate_rear", (0.42, 0.018, 0.11), (0, -2.36, 0.55), PLATE, root)
text("plate_front_text", "HY 84 AV", (0, 2.392, 0.55), INTERIOR, root, 0.085, rot=(math.pi / 2, 0, 0))
text("plate_rear_text", "HY 84 AV", (0, -2.377, 0.55), INTERIOR, root, 0.085, rot=(math.pi / 2, 0, math.pi))
# a small broken mirror and a loose trim strip
box("mirror_glass_l", (0.12, 0.03, 0.06), (-0.94, 0.68, 1.22), GLASS_CRACKED, root)
box("rear_trim", (0.46, 0.035, 0.06), (0.48, -2.34, 0.74), RUST, root)

# clean transform: all parts parented to the root, root at origin on the ground
# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
for o in root.children_recursive:
    o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    use_selection=True,
    export_apply=True,
    export_yup=True,
    export_materials='EXPORT',
    export_cameras=False,
    export_lights=False,
)
print("WROTE", OUT, os.path.getsize(OUT))

# ------------------------------------------------------------------ preview
world = bpy.data.worlds.new("PreviewWorld")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.10, 0.12, 0.13, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
bpy.context.scene.world = world

bpy.ops.object.camera_add(location=(5.7, -6.4, 3.3))
cam = bpy.context.object
cam.data.lens = 58
cam.rotation_euler = (math.radians(70), 0, math.radians(42))
bpy.context.scene.camera = cam

bpy.ops.object.light_add(type='AREA', location=(3.0, -3.0, 6.0))
key = bpy.context.object
key.data.energy = 900
key.data.size = 5.0
key.rotation_euler = (math.radians(30), 0, math.radians(-35))
bpy.ops.object.light_add(type='AREA', location=(-4.0, 2.0, 3.0))
fill = bpy.context.object
fill.data.energy = 450
fill.data.size = 4.0
fill.rotation_euler = (math.radians(70), 0, math.radians(145))

bpy.ops.mesh.primitive_plane_add(size=16, location=(0, 0, 0))
ground = bpy.context.object
ground.data.materials.append(mat("preview_ground", (0.25, 0.27, 0.24), 1.0, 0.0))
bpy.context.scene.render.engine = 'BLENDER_EEVEE_NEXT'
bpy.context.scene.render.resolution_x = 900
bpy.context.scene.render.resolution_y = 600
bpy.context.scene.render.resolution_percentage = 100
bpy.context.scene.render.image_settings.file_format = 'PNG'
bpy.context.scene.render.filepath = PREVIEW
bpy.ops.render.render(write_still=True)
print("PREVIEW", PREVIEW)
