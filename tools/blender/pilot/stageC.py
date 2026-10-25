import os
# Stage C: new textures, beard volume shells, cap, clear acetate glasses.
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, numpy as np, math, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
TEX = os.path.join(os.environ.get('PILOT_WORK', os.getcwd()), 'tex')
rig = bpy.data.objects['Human.rig_x']
body = bpy.data.objects['Human_x']

def link(o):
    bpy.context.scene.collection.objects.link(o)

def bind_to_head(o):
    """parent to the rig, fully weighted to the head bone"""
    o.parent = rig; o.matrix_parent_inverse = rig.matrix_world.inverted()
    vg = o.vertex_groups.new(name='head'); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    m = o.modifiers.new('Armature', 'ARMATURE'); m.object = rig

def principled(name, color=(0.8, 0.8, 0.8, 1), rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = color; b.inputs['Roughness'].default_value = rough; b.inputs['Metallic'].default_value = metal
    return m, b

def swap_image(obj, contains, path):
    img = bpy.data.images.load(path)
    for n in obj.data.materials[0].node_tree.nodes:
        if n.type == 'TEX_IMAGE' and contains in n.image.name: n.image = img
    return img

# ---------------------------------------------------------------- textures
swap_image(body, 'diffuse', TEX + '/skin_diffuse.png')
skinmat = body.data.materials[0]; sb = [n for n in skinmat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'][0]
sb.inputs['Roughness'].default_value = 0.55
sb.inputs['Subsurface Weight'].default_value = 0.08; sb.inputs['Subsurface Radius'].default_value = (1.0, 0.35, 0.2); sb.inputs['Subsurface Scale'].default_value = 0.01
cloth = bpy.data.objects['Human.male_casualsuit02_x']
swap_image(cloth, 'diffuse', TEX + '/top_jeans_diffuse.png')

# ---------------------------------------------------------------- beard volume shells
dens = np.load(TEX + '/beard_vertex_density.npy')
beard_img = bpy.data.images.load(TEX + '/beard_rgba.png')
SH = [(0.0010, 0.22), (0.0020, 0.34), (0.0031, 0.45), (0.0043, 0.56), (0.0056, 0.67)]  # fur shells: (max offset, alpha threshold)
for k, (off, thr) in enumerate(SH):
    o = body.copy(); o.data = body.data.copy(); o.name = f'BeardShell{k}'; link(o)
    o.data.materials.clear()
    m, b = principled(f'beard_shell_{k}', rough=0.62)
    b.inputs['Sheen Weight'].default_value = 0.12; b.inputs['Sheen Tint'].default_value = (0.45, 0.4, 0.36, 1)
    nt = m.node_tree; tx = nt.nodes.new('ShaderNodeTexImage'); tx.image = beard_img
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = thr
    nt.links.new(tx.outputs['Color'], b.inputs['Base Color']); nt.links.new(tx.outputs['Alpha'], gt.inputs[0]); nt.links.new(gt.outputs[0], b.inputs['Alpha'])
    m.blend_method = 'CLIP' if hasattr(m, 'blend_method') else None
    o.data.materials.append(m)
    bmo = bmesh.new(); bmo.from_mesh(o.data); bmo.verts.ensure_lookup_table()
    kill = [f for f in bmo.faces if max(dens[v.index] for v in f.verts) < 0.04]
    bmesh.ops.delete(bmo, geom=kill, context='FACES')
    loose = [v for v in bmo.verts if not v.link_faces]; bmesh.ops.delete(bmo, geom=loose, context='VERTS')
    bmo.normal_update()
    # need the original indices for density: store via a layer before delete is simpler; recompute from position
    bmo.to_mesh(o.data); bmo.free()
    # displace along normals by density
    body_co = np.array([v.co[:] for v in body.data.vertices])
    tree = BVHTree.FromPolygons([v.co for v in body.data.vertices], [p.vertices for p in body.data.polygons])
    from mathutils.kdtree import KDTree
    kd = KDTree(len(body_co))
    for i, c in enumerate(body_co): kd.insert(c, i)
    kd.balance()
    for v in o.data.vertices:
        _, idx, _ = kd.find(v.co)
        d = float(dens[idx])
        v.co = v.co + v.normal * off * min(1.0, d * 1.3) ** 0.7
    print('SHELL', k, len(o.data.polygons))

# ---------------------------------------------------------------- cap
co = np.array([body.matrix_world @ v.co for v in body.data.vertices])
bvh = BVHTree.FromPolygons([Vector(c) for c in co], [p.vertices for p in body.data.polygons])
cx, cy = 0.0, -0.044
def zcut(y):  # lower edge of the crown: forehead high, nape low
    return 1.758 + (1.692 - 1.758) * (y - (-0.14)) / (0.05 - (-0.14))
bmc = bmesh.new()
bmesh.ops.create_uvsphere(bmc, u_segments=72, v_segments=36, radius=1.0)
for v in bmc.verts:
    v.co = Vector((v.co.x * 0.088, cy + v.co.y * 0.104, 1.715 + v.co.z * 0.105))
# clean cut along the tilted plane through the forehead and nape points
p0 = Vector((0, -0.14, 1.758)); p1 = Vector((0, 0.05, 1.692))
nrm = Vector((0, -(p1.z - p0.z), (p1.y - p0.y))).normalized()
if nrm.z < 0: nrm = -nrm
bmesh.ops.bisect_plane(bmc, geom=bmc.verts[:] + bmc.edges[:] + bmc.faces[:], plane_co=p0, plane_no=nrm, clear_inner=True)
# project every vertex onto the head (hair + fabric thickness) along the ray from the head centre
ctr = Vector((0, cy, 1.70))
for v in bmc.verts:
    d = (v.co - ctr).normalized()
    hit = bvh.ray_cast(v.co + d * 0.05, -d, 0.2)
    if hit[0] is not None:
        # dome the crown a little above the skull (structured front panels)
        lift = 0.0055 + 0.005 * max(0.0, d.z) ** 2 + 0.004 * max(0.0, -d.y) * max(0.0, d.z)
        v.co = hit[0] + d * lift
# seams along 6 meridians and a top button
for v in bmc.verts:
    a = math.atan2(v.co.x - cx, -(v.co.y - cy))
    s = min(abs(((a / (math.pi / 3)) % 1.0) - 0.0), abs(((a / (math.pi / 3)) % 1.0) - 1.0))
    if s < 0.035 and v.co.z > zcut(v.co.y) + 0.01:
        v.co = v.co - (v.co - ctr).normalized() * 0.0008
capme = bpy.data.meshes.new('cap'); bmc.to_mesh(capme); bmc.free()
cap = bpy.data.objects.new('Cap', capme); link(cap)
for p in capme.polygons: p.use_smooth = True
sol = cap.modifiers.new('sol', 'SOLIDIFY'); sol.thickness = 0.0022; sol.offset = 1
capmat, cb = principled('cap_cotton', color=(0.028, 0.036, 0.026, 1), rough=0.9)
capme.materials.append(capmat)
# button
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1)
btn = bpy.context.active_object; btn.name = 'CapButton'
top = max((Vector(v.co) for v in capme.vertices), key=lambda p: p.z)
btn.scale = (0.0075, 0.0075, 0.003); btn.location = top + Vector((0, 0, 0.0025)); btn.data.materials.append(capmat)
# brim: follows the front of the crown edge, flares out and curves down
edge = []
bme = bmesh.new(); bme.from_mesh(capme)
for v in bme.verts:
    if v.is_boundary:
        p = Vector(v.co); a = math.atan2(p.x - cx, -(p.y - cy))
        if abs(a) < 1.5: edge.append((a, p))
bme.free()
edge.sort(key=lambda e: e[0])
nu, nv = 40, 10
amax = 1.32
def edge_at(a):
    best = min(edge, key=lambda e: abs(e[0] - a)); return best[1]
verts, faces = [], []
for i in range(nu + 1):
    a = -amax + 2 * amax * i / nu
    base = edge_at(a).copy() + Vector((0, 0, 0.001))
    u = a / amax
    L = 0.074 * math.sqrt(max(0.0, 1 - u ** 4))  # rounded tip outline
    out = Vector((math.sin(a), -math.cos(a), 0))
    for j in range(nv + 1):
        t = j / nv
        p = base + out * (L * t) + Vector((0, 0, -math.tan(math.radians(14)) * L * t))
        p.z -= 0.012 * (u ** 2) * t ** 1.5  # pre-curved: sides bend down
        verts.append(p)
for i in range(nu):
    for j in range(nv):
        q = i * (nv + 1) + j
        faces.append((q, q + nv + 1, q + nv + 2, q + 1))
brme = bpy.data.meshes.new('brim'); brme.from_pydata([v[:] for v in verts], [], faces)
brim = bpy.data.objects.new('CapBrim', brme); link(brim)
for p in brme.polygons: p.use_smooth = True
bs = brim.modifiers.new('sol', 'SOLIDIFY'); bs.thickness = 0.0045; bs.offset = -1
brme.materials.append(capmat)

# ---------------------------------------------------------------- glasses (clear acetate, round panto)
eyeobj = bpy.data.objects['Human.high-poly_x']
ev = np.array([eyeobj.matrix_world @ v.co for v in eyeobj.data.vertices])
eL = ev[ev[:, 0] > 0].mean(0); eR = ev[ev[:, 0] < 0].mean(0)
front_y = ev[:, 1].min() - 0.013
ez = (eL[2] + eR[2]) / 2 + 0.002
def ring(cxp, R, w, depth, seg=56, flat=0.12):
    vs, fs = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        r = R * (1 - flat * max(0.0, math.sin(a)) ** 6)  # slightly flattened top (panto)
        for (rr, yy) in ((r, -depth / 2), (r + w, -depth / 2), (r + w, depth / 2), (r, depth / 2)):
            vs.append((cxp + rr * math.cos(a), front_y + yy, ez + rr * math.sin(a) * 0.93))
    for i in range(seg):
        for k in range(4):
            a0 = i * 4 + k; a1 = i * 4 + (k + 1) % 4; b0 = ((i + 1) % seg) * 4 + k; b1 = ((i + 1) % seg) * 4 + (k + 1) % 4
            fs.append((a0, b0, b1, a1))
    return vs, fs
allv, allf = [], []
def add(vs, fs):
    o = len(allv); allv.extend(vs); allf.extend([tuple(i + o for i in f) for f in fs])
R = 0.0222
for sx, e in ((1, eL), (-1, eR)):
    add(*ring(e[0], R, 0.0042, 0.0046))
# bridge (keyhole arch) and end pieces
def bar(p0, p1, w=0.0038, h=0.0046, seg=10, sag=0.0):
    vs, fs = [], []
    p0, p1 = Vector(p0), Vector(p1)
    for i in range(seg + 1):
        t = i / seg; c = p0.lerp(p1, t); c.z += sag * math.sin(math.pi * t)
        for (dx, dz) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            vs.append((c.x, c.y + dx, c.z + dz))
    for i in range(seg):
        for k in range(4):
            a0 = i * 4 + k; a1 = i * 4 + (k + 1) % 4; fs.append((a0, a0 + 4, a1 + 4, a1))
    return vs, fs
inner = R + 0.001
add(*bar((eR[0] + inner * 0.85, front_y, ez + 0.009), (eL[0] - inner * 0.85, front_y, ez + 0.009), sag=0.004))
temples = []
for sx, e in ((1, eL), (-1, eR)):
    hinge = Vector((e[0] + sx * (R + 0.004), front_y + 0.004, ez + 0.006))
    # follow the side of the head back to the ear, staying 3 mm off the skin
    pts = []
    for i in range(17):
        t = i / 16
        p = Vector((hinge.x, hinge.y + t * 0.135, hinge.z + 0.004 * t))
        if t > 0.86: p.z -= (t - 0.86) * 0.22  # bend down behind the ear
        # push out of the head
        hit = bvh.ray_cast(Vector((sx * 0.2, p.y, p.z)), Vector((-sx, 0, 0)), 0.4)
        if hit[0] is not None: p.x = sx * max(abs(p.x), abs(hit[0].x) + 0.003)
        pts.append(p)
    vs, fs = [], []
    for i, c in enumerate(pts):
        for (dx, dz) in ((-0.0014, -0.0021), (0.0014, -0.0021), (0.0014, 0.0021), (-0.0014, 0.0021)):
            vs.append((c.x + dx, c.y, c.z + dz))
    for i in range(len(pts) - 1):
        for k in range(4):
            a0 = i * 4 + k; a1 = i * 4 + (k + 1) % 4; fs.append((a0, a0 + 4, a1 + 4, a1))
    add(vs, fs)
gm = bpy.data.meshes.new('glasses_frame'); gm.from_pydata(allv, [], allf)
frame = bpy.data.objects.new('GlassesFrame', gm); link(frame)
fm, fb = principled('glasses_acetate_clear', color=(0.97, 0.94, 0.9, 1), rough=0.04)
fb.inputs['Transmission Weight'].default_value = 0.92; fb.inputs['IOR'].default_value = 1.49
gm.materials.append(fm)
# lenses: slightly curved discs
lv, lf = [], []
for e in (eL, eR):
    o = len(lv); seg = 40
    lv.append((e[0], front_y - 0.0012, ez))
    for i in range(seg):
        a = 2 * math.pi * i / seg; r = (R + 0.0008) * (1 - 0.12 * max(0.0, math.sin(a)) ** 6)
        lv.append((e[0] + r * math.cos(a), front_y + 0.0006, ez + r * math.sin(a) * 0.93))
    for i in range(seg): lf.append((o, o + 1 + i, o + 1 + (i + 1) % seg))
lm = bpy.data.meshes.new('glasses_lens'); lm.from_pydata(lv, [], lf)
lens = bpy.data.objects.new('GlassesLens', lm); link(lens)
lmat, lb = principled('glasses_lens', color=(1, 1, 1, 1), rough=0.02)
lb.inputs['Transmission Weight'].default_value = 1.0; lb.inputs['IOR'].default_value = 1.6

lm.materials.append(lmat)
for o in (frame, lens):
    for p in o.data.polygons: p.use_smooth = True

for o in (cap, btn, brim, frame, lens):
    bind_to_head(o)
for k in range(len(SH)):
    o = bpy.data.objects[f'BeardShell{k}']
    o.parent = rig  # keeps the body's vertex groups and armature modifier
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ.get('PILOT_WORK', os.getcwd()), 'C.blend'))
