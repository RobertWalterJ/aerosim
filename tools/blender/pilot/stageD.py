import os
# Stage D: screen-type transmitter, holding pose (analytic two-bone IK), pose applied as rest, GLB export.
import bpy, bmesh, math, os
from mathutils import Vector, Matrix, Quaternion
W = os.environ.get('PILOT_WORK', os.getcwd())
rig = bpy.data.objects['Human.rig_x']
P = {k: float(v) for k, v in (kv.split('=') for kv in os.environ.get('POSE', '').split(',') if kv)}
def g(k, d): return P.get(k, d)

def link(o): bpy.context.scene.collection.objects.link(o)
def principled(name, color, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = color; b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m, b

# ------------------------------------------------------------ transmitter (built in its own frame, mm-ish detail)
# local frame: +X user's right, +Y up the face toward the antennas, +Z out of the screen toward the user
grey, gb = principled('rc_body_grey', (0.24, 0.255, 0.27, 1), 0.48)
gb.inputs['Coat Weight'].default_value = 0.15
dark, _ = principled('rc_dark_rubber', (0.025, 0.026, 0.028, 1), 0.7)
metal, _ = principled('rc_knurl_metal', (0.6, 0.6, 0.62, 1), 0.32, 1.0)
glass, glb = principled('rc_screen', (0.01, 0.01, 0.012, 1), 0.05)
led, ledb = principled('rc_led_green', (0.05, 1.0, 0.2, 1), 0.3)
ledb.inputs['Emission Color'].default_value = (0.1, 1.0, 0.25, 1); ledb.inputs['Emission Strength'].default_value = 6
# default screen image: a generic live-view style frame (replaced in game by the real camera feed)
scr = bpy.data.images.new('rc_screen_ui', 640, 360)
import numpy as np
h, w = 360, 640
yy, xx = np.mgrid[0:h, 0:w] / np.array([h, w])[:, None, None]
img = np.zeros((h, w, 4), np.float32); img[..., 3] = 1
sky = np.stack([0.45 + 0.25 * yy, 0.6 + 0.2 * yy, 0.85 + 0.1 * yy], -1)
hill = (yy < 0.42 + 0.06 * np.sin(xx * 9) + 0.04 * np.sin(xx * 23 + 1))
ground = np.stack([0.18 + 0.1 * yy, 0.32 + 0.1 * yy, 0.12 + 0.05 * yy], -1)
img[..., :3] = np.where(hill[..., None], ground, sky)
bar = (yy > 0.9) | (yy < 0.08); img[bar, :3] = img[bar, :3] * 0.35
for cx in (0.47, 0.5, 0.53):  # centre mark
    img[(abs(xx - cx) < 0.002) & (abs(yy - 0.5) < 0.02), :3] = 1
scr.pixels.foreach_set(img.ravel()); scr.pack()
nt = glass.node_tree; tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = scr
nt.links.new(tx.outputs['Color'], glb.inputs['Emission Color']); glb.inputs['Emission Strength'].default_value = 1.6
glb.inputs['Coat Weight'].default_value = 1.0; glb.inputs['Coat Roughness'].default_value = 0.03

parts = []
def add_obj(me, mat, name):
    o = bpy.data.objects.new(name, me); link(o); me.materials.append(mat); parts.append(o); return o
def rbox(name, size, loc, mat, bevel=0.004, seg=4):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts: v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(loc)
    if bevel > 0: bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=seg, affect='EDGES', profile=0.5, clamp_overlap=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    return add_obj(me, mat, name)
def cyl(name, r, h, loc, mat, seg=24, axis='Z', rot=None):
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h)
    M = Matrix.Translation(Vector(loc))
    if rot is not None: M = M @ rot
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    return add_obj(me, mat, name)
# main shell: 168 x 118 x 22 mm, plus rear grips
rbox('rc_shell', (0.168, 0.118, 0.022), (0, 0, 0), grey, bevel=0.009, seg=5)
for sx in (-1, 1):
    rbox('rc_grip', (0.034, 0.075, 0.03), (sx * 0.066, -0.012, -0.018), grey, bevel=0.013, seg=5)
    # stick well, stem and knurled cap
    cyl('rc_well', 0.0125, 0.003, (sx * 0.058, 0.036, 0.0105), dark, seg=28)
    cyl('rc_stem', 0.0025, 0.009, (sx * 0.058, 0.036, 0.0145), dark, seg=10)
    cyl('rc_cap', 0.0068, 0.004, (sx * 0.058, 0.036, 0.0205), metal, seg=18)
    # flat antennas, hinged at the top back, flipped up
    a = rbox('rc_antenna', (0.016, 0.07, 0.0055), (0, 0.035, 0), dark, bevel=0.0025, seg=3)
    a.matrix_world = Matrix.Translation((sx * 0.044, 0.056, -0.006)) @ Matrix.Rotation(math.radians(-12), 4, 'X')
    bpy.context.view_layer.update()
    a.data.transform(a.matrix_world); a.matrix_world = Matrix()
# screen: 5.5 in 16:9 (121 x 68 mm), slightly proud bezel
rbox('rc_bezel', (0.128, 0.074, 0.002), (0, -0.017, 0.0105), dark, bevel=0.0015, seg=2)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
for v in bm.verts: v.co = Vector((v.co.x * 0.1215, v.co.y * 0.0684 - 0.017, 0.0117))
me = bpy.data.meshes.new('rc_screen'); bm.to_mesh(me); bm.free()
uv = me.uv_layers.new(name='UVMap')
for loop in me.loops:
    co = me.vertices[loop.vertex_index].co; uv.data[loop.index].uv = ((co.x / 0.1215) + 0.5, ((co.y + 0.017) / 0.0684) + 0.5)
add_obj(me, glass, 'rc_screen')
for i in range(4):
    rbox('rc_led', (0.0022, 0.0012, 0.001), (-0.0057 + i * 0.0038, 0.047, 0.0112), led, bevel=0)
for x, y, mat in ((-0.022, 0.03, dark), (0.022, 0.03, dark), (0.0, 0.024, dark)):
    cyl('rc_button', 0.0034, 0.002, (x, y, 0.0115), mat, seg=14)
rbox('rc_switch', (0.011, 0.0045, 0.002), (0, 0.035, 0.0115), dark, bevel=0.0008, seg=1)
# join and place in front of the chest, screen tilted toward the face
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
rc = bpy.context.active_object; rc.name = 'Transmitter'
tilt = math.radians(g('tilt', 50))          # screen normal angle above horizontal-back
Yl = Vector((0, -math.sin(tilt), math.cos(tilt)))   # up the face: forward and up
Zl = Vector((0, math.cos(tilt), math.sin(tilt)))    # screen normal: up and back toward the face
Xl = Yl.cross(Zl)
RC_POS = Vector((0, g('rcy', -0.315), g('rcz', 1.11)))
rc.matrix_world = Matrix((
    (Xl.x, Yl.x, Zl.x, RC_POS.x), (Xl.y, Yl.y, Zl.y, RC_POS.y), (Xl.z, Yl.z, Zl.z, RC_POS.z), (0, 0, 0, 1)))
bpy.context.view_layer.update()
RCM = rc.matrix_world.copy()
def rcp(x, y, z): return RCM @ Vector((x, y, z))
def rcd(x, y, z): return (RCM.to_3x3() @ Vector((x, y, z))).normalized()

# ------------------------------------------------------------ pose
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
pb = rig.pose.bones
def world_mat(name): return rig.matrix_world @ pb[name].matrix
def set_world(name, M):
    pb[name].matrix = rig.matrix_world.inverted() @ M; bpy.context.view_layer.update()
def aim(name, target_dir, up_hint=None):
    """rotate bone (minimal rotation, keeps roll) so its Y axis points along target_dir"""
    M = world_mat(name); y = M.col[1].to_3d().normalized()
    q = y.rotation_difference(target_dir.normalized())
    R = q.to_matrix().to_4x4(); loc = M.translation.copy()
    N = R @ M; N.translation = loc; set_world(name, N)
def roll_to(name, want_z):
    """twist bone about its own Y so its Z axis lines up with want_z (projected)"""
    M = world_mat(name); y = M.col[1].to_3d().normalized(); z = M.col[2].to_3d().normalized()
    wz = (want_z - y * want_z.dot(y)).normalized()
    ang = z.angle(wz); s = 1 if y.dot(z.cross(wz)) > 0 else -1
    R = Matrix.Rotation(s * ang, 4, y); loc = M.translation.copy(); N = R @ M; N.translation = loc; set_world(name, N)
def two_bone(side, wrist, pole):
    up, lo = f'upperarm_{side}', f'lowerarm_{side}'
    S = world_mat(up).translation.copy()
    a = rig.data.bones[up].length; b = rig.data.bones[lo].length
    d = min((wrist - S).length, a + b - 1e-4); D = (wrist - S).normalized()
    cosA = (a * a + d * d - b * b) / (2 * a * d); ang = math.acos(max(-1, min(1, cosA)))
    pn = (pole - S); pn = (pn - D * pn.dot(D)).normalized()
    E = S + (D * math.cos(ang) + pn * math.sin(ang)) * a
    aim(up, E - S)
    aim(lo, wrist - world_mat(lo).translation)
    return E
for side, sx in (('l', 1), ('r', -1)):
    # controller frame: user's left hand is on the controller's -X side; world +X is the character's left
    cs = -sx
    wrist = rcp(cs * g('wx', 0.08), g('wy', -0.09), g('wz', -0.05))
    pole = Vector((sx * 0.45, 0.25, 0.9))
    two_bone(side, wrist, pole)
    print('WRIST', side, tuple(round(x,3) for x in wrist), 'got', tuple(round(x,3) for x in world_mat(f'hand_{side}').translation), 'rcbottom', tuple(round(x,3) for x in rcp(0,-0.059,0)))
    # hand: knuckles toward the top-back of the grip, palm facing the controller centre
    h = f'hand_{side}'
    aim(h, rcd(cs * g('hx', -0.6), 1.0, g('hz', 0.0)))
    roll_to(h, rcd(-cs * g('px', 0.3), 0.0, 1.0) * g('palm', 1.0))
    # fingers wrap round the back of the grip
    for fi, fname in enumerate(('index', 'middle', 'ring', 'pinky')):
        for j, amt in enumerate((g('f1', 30), g('f2', 35), g('f3', 25))):
            bn = f'{fname}_0{j + 1}_{side}'
            pb[bn].rotation_mode = 'XYZ'; pb[bn].rotation_euler = (math.radians(amt) * g('fs', 1.0), 0, 0)
    bpy.context.view_layer.update()
    # thumbs reach over the front of the shell to the stick caps
    cap = rcp(cs * 0.058, 0.036 + g('ty', -0.004), 0.021)
    for j, k in ((1, 1.0), (2, 1.0), (3, 1.0)):
        bn = f'thumb_0{j}_{side}'
        head = world_mat(bn).translation
        tgt = cap + rcd(0, 0, 1) * (g('tlift', 0.012) if j < 3 else 0.004) * (1 if j == 1 else 0.5)
        aim(bn, tgt - head)
    bpy.context.view_layer.update()
# head looks a little up (the game turns it toward the drone at runtime)
pb['neck_01'].rotation_mode = 'XYZ'; pb['neck_01'].rotation_euler = (math.radians(-g('neck', 6)), 0, 0)
bpy.context.view_layer.update()
bpy.ops.object.mode_set(mode='OBJECT')
# controller follows the upper body
rc.data.transform(rc.matrix_world); rc.matrix_world = Matrix()
vg = rc.vertex_groups.new(name='spine_03'); vg.add(list(range(len(rc.data.vertices))), 1.0, 'REPLACE')
rc.parent = rig; rc.matrix_parent_inverse = rig.matrix_world.inverted()
m = rc.modifiers.new('Armature', 'ARMATURE'); m.object = rig
for p in rc.data.polygons: p.use_smooth = True
bpy.ops.wm.save_as_mainfile(filepath=W + '/D_posed.blend')
print("POSED")
