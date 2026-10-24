# Blender 4.2 helpers for the drone models (lane/drones). Pure bmesh, no operators that need a window, so it runs with
# `blender -b -P build_drones.py`.
#
# Modelling frame (the whole file works in it): metres, +Y forward, +X right, +Z up. The exporter turns the finished model
# round 180 degrees about Z so the .glb has its nose at Blender -Y, which the glTF converter writes as +Z (the story
# frame: +Z front, the model's right is -x, origin at the base).
#
# Every part is its own object until assemble() joins the parts of one node (body, battery, prop_fr ...) into a mesh.
# Each part also records its outline for the drone chooser's technical drawing (see manifest()).
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

TEX = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "drones"))

# ------------------------------------------------------------------------------------------------ materials
# base: sRGB colour. tex: a prepared set in assets/textures/drones (drone_<tex>_nor/_orm, and _diff when diff=True).
# tile: metres covered by one repeat of the texture. emit: emission strength (the colour is the base colour).
MATS = {
    "carbon":        dict(base=(0.05, 0.05, 0.055), tex="carbon", diff=True, tile=0.014, metal=0.0),
    "carbon_edge":   dict(base=(0.16, 0.16, 0.165), rough=0.72, metal=0.0),
    "anod_orange":   dict(base=(0.95, 0.33, 0.05), tex="brushed", tile=0.02, metal=1.0),
    "anod_orange_spun": dict(base=(0.95, 0.33, 0.05), tex="spun", tile=0.03, metal=1.0, spin=True),
    "anod_navy":     dict(base=(0.10, 0.16, 0.36), tex="brushed", tile=0.02, metal=1.0),
    "anod_navy_spun": dict(base=(0.10, 0.16, 0.36), tex="spun", tile=0.026, metal=1.0, spin=True),
    "anod_black":    dict(base=(0.05, 0.05, 0.055), tex="brushed", tile=0.02, metal=1.0),
    "anod_grey":     dict(base=(0.22, 0.23, 0.25), tex="brushed", tile=0.02, metal=1.0),
    "alu":           dict(base=(0.86, 0.87, 0.88), tex="brushed", tile=0.02, metal=1.0),
    "steel":         dict(base=(0.78, 0.78, 0.8), rough=0.22, metal=1.0),
    "titanium":      dict(base=(0.6, 0.58, 0.55), rough=0.3, metal=1.0),
    "steel_dark":    dict(base=(0.2, 0.2, 0.22), rough=0.32, metal=1.0),
    "copper":        dict(base=(0.93, 0.52, 0.32), rough=0.34, metal=1.0),
    "magnet":        dict(base=(0.66, 0.66, 0.68), rough=0.28, metal=1.0),
    "lamination":    dict(base=(0.3, 0.31, 0.33), rough=0.45, metal=1.0),
    "gold":          dict(base=(0.95, 0.76, 0.42), rough=0.22, metal=1.0),
    "pcb":           dict(base=(1.0, 1.0, 1.0), img="drone_pcb_diff.jpg", rough=0.42, metal=0.0),
    "chip":          dict(base=(0.04, 0.04, 0.045), rough=0.35, metal=0.0),
    "smd":           dict(base=(0.38, 0.33, 0.25), rough=0.45, metal=0.0),
    "plastic_black": dict(base=(0.025, 0.025, 0.028), tex="plastic", tile=0.05, metal=0.0),
    "plastic_grey":  dict(base=(0.07, 0.072, 0.078), tex="plastic", tile=0.05, metal=0.0),
    "shell_navy":    dict(base=(0.07, 0.11, 0.24), tex="plastic", tile=0.04, metal=0.0),
    "shell_navy_dark": dict(base=(0.035, 0.05, 0.1), tex="plastic", tile=0.04, metal=0.0),
    "tpu_orange":    dict(base=(0.95, 0.38, 0.06), tex="rubber", tile=0.012, metal=0.0),
    "tpu_black":     dict(base=(0.04, 0.04, 0.045), tex="rubber", tile=0.012, metal=0.0),
    "tpu_blue":      dict(base=(0.12, 0.2, 0.42), tex="rubber", tile=0.012, metal=0.0),
    "rubber":        dict(base=(0.03, 0.03, 0.032), tex="rubber", tile=0.01, metal=0.0),
    "silicone_black": dict(base=(0.03, 0.03, 0.033), rough=0.42, metal=0.0),
    "silicone_red":  dict(base=(0.62, 0.05, 0.04), rough=0.42, metal=0.0),
    "heatshrink":    dict(base=(0.02, 0.02, 0.022), rough=0.36, metal=0.0),
    "heatshrink_clear": dict(base=(0.5, 0.52, 0.55), rough=0.2, metal=0.0),
    "nylon_yellow":  dict(base=(0.95, 0.75, 0.12), rough=0.42, metal=0.0),
    "nylon_white":   dict(base=(0.86, 0.85, 0.8), rough=0.45, metal=0.0),
    "nylon_black":   dict(base=(0.03, 0.03, 0.035), rough=0.5, metal=0.0),
    "cap_sleeve":    dict(base=(0.06, 0.06, 0.07), rough=0.3, metal=0.0),
    "cap_stripe":    dict(base=(0.55, 0.56, 0.6), rough=0.3, metal=0.0),
    "strap":         dict(base=(1.0, 1.0, 1.0), tex="strap", diff=True, tile=0.02, metal=0.0),
    "wrap_raptor":   dict(base=(1.0, 1.0, 1.0), img="drone_wrap_raptor.jpg", rough=0.28, metal=0.0, uv="own"),
    "wrap_nightowl": dict(base=(1.0, 1.0, 1.0), img="drone_wrap_nightowl.jpg", rough=0.28, metal=0.0, uv="own"),
    "prop_orange":   dict(base=(0.93, 0.28, 0.02), rough=0.16, metal=0.0),
    "prop_black":    dict(base=(0.03, 0.033, 0.04), rough=0.42, metal=0.0),
    "prop_tip_blue": dict(base=(0.18, 0.36, 0.78), rough=0.4, metal=0.0),
    "glass":         dict(base=(0.004, 0.004, 0.006), rough=0.02, metal=0.0, spec=1.0),
    "coat_violet":   dict(base=(0.32, 0.12, 0.55), rough=0.06, metal=1.0),
    "coat_green":    dict(base=(0.14, 0.5, 0.26), rough=0.06, metal=1.0),
    "coat_amber":    dict(base=(0.62, 0.38, 0.08), rough=0.06, metal=1.0),
    "lens_ring":     dict(base=(0.02, 0.02, 0.022), rough=0.6, metal=0.0),
    "lamp_green":    dict(base=(0.2, 1.0, 0.35), emit=6.0),
    "lamp_red":      dict(base=(1.0, 0.12, 0.08), emit=6.0),
    "lamp_white":    dict(base=(1.0, 0.97, 0.92), emit=6.0),
    "lamp_blue":     dict(base=(0.2, 0.45, 1.0), emit=5.0),
    "lamp_landing":  dict(base=(1.0, 0.96, 0.88), emit=12.0),
    "lamp_ir":       dict(base=(0.5, 0.03, 0.03), emit=1.2),
    "lamp_status":   dict(base=(0.25, 1.0, 0.4), emit=6.0),
    "reflector":     dict(base=(0.92, 0.92, 0.94), rough=0.08, metal=1.0),
    "lens_clear":    dict(base=(0.85, 0.86, 0.88), rough=0.03, metal=0.0, alpha=0.25),
}

_mat_cache = {}


def _img(name, srgb):
    key = name + ("" if srgb else "#lin")
    im = bpy.data.images.get(key)
    if im is None:
        im = bpy.data.images.load(os.path.join(TEX, name), check_existing=False)
        im.name = key
        im.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    return im


def srgb_to_lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(key):
    if key in _mat_cache:
        return _mat_cache[key]
    s = MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = srgb_to_lin(s.get("base", (0.5, 0.5, 0.5)))
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Metallic"].default_value = s.get("metal", 0.0)
    bsdf.inputs["Roughness"].default_value = s.get("rough", 0.5)
    if "spec" in s:
        bsdf.inputs["Specular IOR Level"].default_value = 0.5 * s["spec"] + 0.25
    tex = s.get("tex")
    if tex:
        if s.get("diff"):
            n = nt.nodes.new("ShaderNodeTexImage"); n.image = _img("drone_%s_diff.jpg" % tex, True)
            nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
        orm = nt.nodes.new("ShaderNodeTexImage"); orm.image = _img("drone_%s_orm.jpg" % tex, False)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nor = nt.nodes.new("ShaderNodeTexImage"); nor.image = _img("drone_%s_nor.jpg" % tex, False)
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nor.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if s.get("img"):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = _img(s["img"], True)
        nt.links.new(n.outputs["Color"], bsdf.inputs["Base Color"])
    if "emit" in s:
        bsdf.inputs["Emission Color"].default_value = (*base, 1.0)
        bsdf.inputs["Emission Strength"].default_value = s["emit"]
        bsdf.inputs["Roughness"].default_value = 0.3
    if "alpha" in s:
        bsdf.inputs["Alpha"].default_value = s["alpha"]
        m.blend_method = "BLEND"
    _mat_cache[key] = m
    return m


def tile_of(key):
    return MATS[key].get("tile", 0.02)


# ------------------------------------------------------------------------------------------------ the kit
class Part:
    __slots__ = ("obj", "node", "outline", "plan_pts", "thin")

    def __init__(self, obj, node, outline, plan_pts=None, thin=False):
        self.obj = obj; self.node = node; self.outline = outline; self.plan_pts = plan_pts; self.thin = thin


class Kit:
    """Parts of one model at one level of detail."""

    def __init__(self, name, q):
        self.name = name
        self.q = q                 # 0 near, 1 middle, 2 far
        self.parts = []
        self.pivots = {}           # node -> Vector (modelling frame)
        self.parents = {}          # node -> parent node ("" is the root)
        self.marks = {}            # empties: name -> Vector

    def seg(self, n0):
        """Segment count for round things at this level of detail."""
        return max(6, int(round(n0 * (1.0, 0.5, 0.34)[self.q])))

    # small parts left out of the lighter levels of detail (by part name): from the middle level, and from the far one
    SKIP1 = {"grommet", "bolt", "jst", "usbmouth", "coax", "rxcoax", "sma", "hinge", "bal", "captop", "knob", "prong", "mlcc", "drv",
             "gyro", "baro", "kn", "knurl", "vent", "sd", "gflex", "stripe", "ridge", "pin"}
    SKIP2 = SKIP1 | {"nut", "shaft", "lead", "pig", "sleeve", "wire", "jstxh", "washer", "dome", "fin", "fet", "usb", "cap", "buckle",
                     "rec", "door", "acface", "irring", "plug", "thumb", "hingeblk", "damper", "riser", "socket", "focus",
                     "pagodacap", "stem", "rxtube", "camback", "seal", "brg", "mag", "stat", "wind", "grip", "latch", "antmount"}

    def add(self, obj, node="body", outline="hull", plan_pts=None, thin=False):
        base = obj.name.split(".")[0]
        if (self.q >= 1 and base in Kit.SKIP1) or (self.q >= 2 and base in Kit.SKIP2):
            me = obj.data
            bpy.data.objects.remove(obj)
            if me.users == 0:
                bpy.data.meshes.remove(me)
            return None
        self.parts.append(Part(obj, node, outline, plan_pts, thin))
        return obj


def _new_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def _uv_box(bm, tile, center=None):
    """Box projection: each face takes the plane its normal faces most. Done in the part's own frame."""
    uv = bm.loops.layers.uv.verify()
    c = center or Vector((0, 0, 0))
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        for lp in f.loops:
            p = lp.vert.co - c
            if ax == 0: u, v = p.y, p.z
            elif ax == 1: u, v = p.x, p.z
            else: u, v = p.x, p.y
            lp[uv].uv = (u / tile, v / tile)


def finish(bm, key, xf=None, uv="box", name="part", keys=None):
    """Turn a bmesh into an object: UVs in the part's own frame, then the transform, one material (or per face index)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:]) if uv != "keep_normals" else None
    if uv in ("box", "keep_normals"):
        _uv_box(bm, tile_of(key))
    if xf is not None:
        bm.transform(xf)
    mats = [mat(k) for k in (keys or [key])]
    return _new_obj(name, bm, mats)


# ------------------------------------------------------------------------------------------------ primitives
def lathe(profile, seg, key, xf=None, name="lathe", spin=None, cap=True, loop=False, axial_key=None):
    """A turned part: profile [(r, z)] spun round local Z. r == 0 makes a pole. loop=True joins the last profile point
    back to the first (a closed section, such as a ring or a bell with a wall). UVs: round faces cylindrical (u round, v
    along the profile), faces looking along the axis planar and centred (so spun-metal texture rings the axis)."""
    if loop:
        profile = list(profile) + [profile[0]]
        cap = False
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    rings = []
    for (r, z) in profile:
        if r < 1e-7:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * j / seg), r * math.sin(2 * math.pi * j / seg), z)) for j in range(seg)])
    faces = []
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        if len(A) == 1 and len(B) == 1:
            continue
        for j in range(seg):
            j2 = (j + 1) % seg
            if len(A) == 1:
                vs = [A[0], B[j], B[j2]]
            elif len(B) == 1:
                vs = [A[j], A[j2], B[0]]
            else:
                if (A[j].co - B[j].co).length < 1e-9 and (A[j2].co - B[j2].co).length < 1e-9:
                    continue
                vs = [A[j], A[j2], B[j2], B[j]]
            try:
                faces.append(bm.faces.new(vs))
            except ValueError:
                pass
    if cap:
        for ring in (rings[0], rings[-1]):
            if len(ring) > 2:
                try:
                    faces.append(bm.faces.new(ring))
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-8)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tile = tile_of(key)
    spin_mat = MATS[axial_key or key].get("spin", False) if spin is None else spin
    rmax = max(p[0] for p in profile) or 1.0
    for f in bm.faces:
        n = f.normal
        axial = abs(n.z) > 0.75
        if axial_key:
            f.material_index = 1 if (axial and n.z > 0) else 0
        for lp in f.loops:
            p = lp.vert.co
            if axial:
                if spin_mat:
                    lp[uvl].uv = (0.5 + p.x / (2.2 * rmax), 0.5 + p.y / (2.2 * rmax))
                else:
                    lp[uvl].uv = (p.x / tile, p.y / tile)
            else:
                a = math.atan2(p.y, p.x)
                fc = f.calc_center_median()
                ac = math.atan2(fc.y, fc.x)
                if a - ac > math.pi: a -= 2 * math.pi
                if ac - a > math.pi: a += 2 * math.pi
                r = math.hypot(p.x, p.y)
                lp[uvl].uv = (a * max(r, rmax * 0.5) / tile, p.z / tile)
    if xf is not None:
        bm.transform(xf)
    return _new_obj(name, bm, [mat(key)] + ([mat(axial_key)] if axial_key else []))


def rbox(size, key, xf=None, bevel=None, segs=2, name="box"):
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((sx, sy, sz, 1.0)))
    b = min(sx, sy, sz) * 0.18 if bevel is None else bevel
    if b > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=b, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    return finish(bm, key, xf, name=name)


def plate(poly, z0, z1, key, edge_key=None, xf=None, chamfer=0.0003, name="plate"):
    """A flat part cut from an outline [(x, y)] in the XY plane, from z0 to z1. Top and bottom take `key`, the cut edge
    `edge_key` (raw carbon edges are a matte grey), with a small chamfer so the edge catches the light."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, z0)) for (x, y) in poly]
    f = bm.faces.new(vs)
    ret = bmesh.ops.extrude_face_region(bm, geom=[f], use_keep_orig=True)
    top = [e for e in ret["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in top:
        v.co.z = z1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    if chamfer > 0:
        rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-9]
        bmesh.ops.bevel(bm, geom=rim, offset=chamfer, segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    ek = edge_key or key
    for fc in bm.faces:
        fc.material_index = 0 if abs(fc.normal.z) > 0.95 else 1
    _uv_box(bm, tile_of(key))
    if xf is not None:
        bm.transform(xf)
    return _new_obj(name, bm, [mat(key), mat(ek)])


def boolean(obj, cutters, op="DIFFERENCE"):
    """Cut (or join) with exact booleans, then bake the result into obj's mesh and delete the cutters."""
    for c in cutters:
        md = obj.modifiers.new("b", "BOOLEAN")
        md.operation = op
        md.solver = "EXACT"
        md.object = c
        c.hide_render = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = obj.data
    obj.modifiers.clear()
    obj.data = me
    bpy.data.meshes.remove(old)
    for c in cutters:
        cm = c.data
        bpy.data.objects.remove(c)
        if cm.users == 0:
            bpy.data.meshes.remove(cm)
    return obj


def cyl(r, h, seg, key, xf=None, name="cyl", z0=0.0, chamfer=0.0):
    c = chamfer
    if c > 0:
        prof = [(0, z0), (r - c, z0), (r, z0 + c), (r, z0 + h - c), (r - c, z0 + h), (0, z0 + h)]
    else:
        prof = [(0, z0), (r, z0), (r, z0 + h), (0, z0 + h)]
    return lathe(prof, seg, key, xf, name=name)


def _catmull(pts, sub):
    if len(pts) < 3 or sub <= 1:
        return [Vector(p) for p in pts]
    P = [Vector(p) for p in pts]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(sub):
            t = k / sub
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return out


def tube(points, r, key, seg=8, sub=4, caps=True, name="tube", r1=None):
    """A round tube along a smooth path through `points` (cables, wires, antennas). r1 tapers it to the end."""
    path = _catmull(points, sub)
    n = len(path)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    tangents = []
    for i in range(n):
        a = path[max(i - 1, 0)]; b = path[min(i + 1, n - 1)]
        t = (b - a)
        tangents.append(t.normalized() if t.length > 1e-12 else Vector((0, 0, 1)))
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = tangents[0].cross(ref).normalized()
    rings = []
    s = 0.0
    lengths = [0.0]
    for i in range(1, n):
        lengths.append(lengths[-1] + (path[i] - path[i - 1]).length)
    for i in range(n):
        if i > 0:                                  # parallel transport of the frame
            t0, t1 = tangents[i - 1], tangents[i]
            ax = t0.cross(t1)
            if ax.length > 1e-9:
                ang = t0.angle(t1)
                nrm = Matrix.Rotation(ang, 3, ax.normalized()) @ nrm
        bin_ = tangents[i].cross(nrm).normalized()
        rr = r if r1 is None else r + (r1 - r) * (lengths[i] / max(lengths[-1], 1e-9))
        rings.append([bm.verts.new(path[i] + (nrm * math.cos(2 * math.pi * j / seg) + bin_ * math.sin(2 * math.pi * j / seg)) * rr) for j in range(seg)])
    tile = tile_of(key)
    for i in range(n - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            f = bm.faces.new([rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]])
            for lp, (jj, ii) in zip(f.loops, [(j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1)]):
                lp[uvl].uv = (jj / seg * 2 * math.pi * r / tile, lengths[ii] / tile)
    if caps:
        for ring in (rings[0], rings[-1]):
            bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _new_obj(name, bm, [mat(key)])


def quad(corners, key, name="decal", uvs=((0, 0), (1, 0), (1, 1), (0, 1))):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    f = bm.faces.new([bm.verts.new(c) for c in corners])
    for lp, uv in zip(f.loops, uvs):
        lp[uvl].uv = uv
    return _new_obj(name, bm, [mat(key)])


def wrapped_box(size, key, xf=None, bevel=0.003, segs=3, name="pack"):
    """A battery pack: a soft box whose UVs wrap round it (u along its length = Y, v round the section), for the printed
    shrink wrap."""
    sx, sy, sz = size
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bm.transform(Matrix.Diagonal((sx, sy, sz, 1.0)))
    bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=segs, profile=0.5, affect="EDGES", clamp_overlap=True)
    uvl = bm.loops.layers.uv.verify()
    perim = 2 * (sx + sz)
    for f in bm.faces:
        for lp in f.loops:
            p = lp.vert.co
            a = math.atan2(p.z / sz, p.x / sx)          # angle round the section, 0 at +x
            u = 0.5 + p.y / sy * 0.98
            v = ((a / (2 * math.pi)) + 0.25) % 1.0        # top face (+z, a = 90 degrees) maps to v ~ 0.5
            lp[uvl].uv = (u, v)
    # fix the seam: a face whose loops straddle v 0/1 gets its small values lifted
    for f in bm.faces:
        vs = [lp[uvl].uv.y for lp in f.loops]
        if max(vs) - min(vs) > 0.5:
            for lp in f.loops:
                if lp[uvl].uv.y < 0.5:
                    lp[uvl].uv.y += 1.0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if xf is not None:
        bm.transform(xf)
    return _new_obj(name, bm, [mat(key)])


def loft(sections, key, e=2.6, seg=24, name="loft", caps=True):
    """A smooth shell lofted along Y through sections (y, cx, cz, half_width, half_height); e is the squareness
    (2 round, 4 soft box, 8 nearly square). Ends are closed with a fan."""
    bm = bmesh.new()
    ex = 2.0 / e
    rings = []
    for (y, cx, cz, hw, hh) in sections:
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            ca, sa = math.cos(a), math.sin(a)
            ring.append(bm.verts.new((cx + hw * math.copysign(abs(ca) ** ex, ca), y, cz + hh * math.copysign(abs(sa) ** ex, sa))))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            try:
                bm.faces.new([rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]])
            except ValueError:
                pass
    if caps:
        for k, ring in ((0, rings[0]), (-1, rings[-1])):
            y, cx, cz = sections[k][0], sections[k][1], sections[k][2]
            c = bm.verts.new((cx, y, cz))
            for j in range(seg):
                try:
                    bm.faces.new([ring[j], ring[(j + 1) % seg], c])
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-8)
    return finish(bm, key, None, name=name)


def arc_block(r0, r1, z0, z1, a0, a1, key, xf=None, seg=3, name="arc"):
    """A curved block: the part of a thick ring between angles a0 and a1 (magnets on a bell's inner wall)."""
    bm = bmesh.new()
    rows = []
    for k in range(seg + 1):
        a = a0 + (a1 - a0) * k / seg
        c, s = math.cos(a), math.sin(a)
        rows.append([bm.verts.new((r * c, r * s, z)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))])
    for k in range(seg):
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new([rows[k][j], rows[k][j2], rows[k + 1][j2], rows[k + 1][j]])
    bm.faces.new(rows[0]); bm.faces.new(rows[-1][::-1])
    return finish(bm, key, xf, name=name)


def poly_round(cx, cy, r, n, a0=0.0, a1=2 * math.pi):
    return [(cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]


# ------------------------------------------------------------------------------------------------ transforms
def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))


def RX(a):
    return Matrix.Rotation(a, 4, "X")


def RY(a):
    return Matrix.Rotation(a, 4, "Y")


def RZ(a):
    return Matrix.Rotation(a, 4, "Z")


def orient(p, up):
    """A frame at p with its local +Z along `up`."""
    up = Vector(up).normalized()
    q = Vector((0, 0, 1)).rotation_difference(up)
    return Matrix.Translation(p) @ q.to_matrix().to_4x4()


def along(a, b):
    """Local +Z from a towards b, origin at a."""
    return orient(Vector(a), Vector(b) - Vector(a))


# ------------------------------------------------------------------------------------------------ small parts
def screw(kit, p, up=(0, 0, 1), r=0.0028, key="anod_orange", node="body", hexsocket=True, simple=False):
    """An M3 (or M2) button-head cap screw seen from its head: a dome with a socket recess (near), a plain dome (simple,
    for screws seen only from underneath). Not drawn at the far level of detail."""
    if kit.q == 2 or (simple and kit.q > 0):
        return
    h = r * 0.55
    if hexsocket and kit.q == 0 and not simple:
        prof = [(0, 0), (r, 0), (r, h * 0.4), (r * 0.7, h), (r * 0.38, h), (r * 0.38, h * 0.45), (0, h * 0.45)]
        s = 8
    else:
        prof = [(0, 0), (r, 0), (r * 0.75, h), (0, h)]
        s = 6
    kit.add(lathe(prof, s, key, orient(Vector(p), up), name="screw"), node, "none")


def nut(kit, p, up=(0, 0, 1), r=0.0032, h=0.0025, key="anod_orange", node="body", nylock=False):
    prof = [(r * 0.45, 0), (r, 0), (r, h), (r * 0.45, h)]
    kit.add(lathe(prof, 6, key, orient(Vector(p), up), name="nut"), node, "none")
    if nylock and kit.q == 0:
        kit.add(lathe([(r * 0.45, h), (r * 0.82, h), (r * 0.82, h * 1.5), (r * 0.6, h * 1.65), (r * 0.45, h * 1.65)], kit.seg(12), key, orient(Vector(p), up), name="nyl"), node, "none")


def zip_tie(kit, centre, axis, radius, key="nylon_black", width=0.0025, node="body", head_dir=(0, 0, 1)):
    """A cable tie pulled tight round a bundle or a standoff: a thin band, a square head and a short cut tail."""
    if kit.q > 0:
        return
    axis = Vector(axis).normalized()
    m = orient(Vector(centre), axis)
    th = 0.0007
    prof = [(radius, -width / 2), (radius + th, -width / 2), (radius + th, width / 2), (radius, width / 2)]
    kit.add(lathe(prof, kit.seg(12), key, m, name="tie", cap=False), node, "none")
    hd = Vector(head_dir).normalized()
    hd = (hd - axis * hd.dot(axis)).normalized()
    hp = Vector(centre) + hd * (radius + th + 0.0012)
    hb = Matrix.Translation(hp) @ Vector((0, 0, 1)).rotation_difference(hd).to_matrix().to_4x4()
    kit.add(rbox((width * 1.5, 0.0034, 0.0026), key, hb, bevel=0.0003, segs=1, name="tiehead"), node, "none")
    side = hd.cross(axis).normalized()
    kit.add(tube([hp + hd * 0.0012, hp + hd * 0.003 + side * 0.0012, hp + hd * 0.0055 + side * 0.0018], 0.0007, key, seg=4, sub=2, name="tietail"), node, "none")


# ------------------------------------------------------------------------------------------------ propellers
def _naca(u, tc):
    return 5.0 * tc * (0.2969 * math.sqrt(max(u, 0.0)) - 0.126 * u - 0.3516 * u * u + 0.2843 * u ** 3 - 0.1036 * u ** 4)


def chord_at(s, t):
    R = s["R"]; tm = s["t_max"]
    cr, cm, ct = s["c_root"] * R, s["c_max"] * R, s["c_tip"] * R
    tr = s.get("t_round", 0.86)
    if t <= tm:
        u = t / tm
        return cr + (cm - cr) * (1.0 - (1.0 - u) ** 2)
    if t <= tr:
        u2 = (t - tm) / (tr - tm)
        return cm + (ct - cm) * u2 ** 1.15
    u3 = min(max((t - tr) / (1.0 - tr), 0.0), 1.0)
    return ct * math.sqrt(max(1.0 - u3 * u3, 0.0))


def blade(s, hand, n=14, m=6):
    """One propeller blade along +X, the same aerofoil maths as game/drone_parts.gd. hand = 1 turns anticlockwise seen
    from above (moving towards +Y), -1 clockwise. The leading edge is the raised one, so the blade pushes air down."""
    R = s["R"]; P = s["pd"] * 2.0 * R
    rows = []
    for i in range(n + 1):
        t = 1.0 - (1.0 - i / n) ** 1.5
        r = s["root"] + (R - s["root"]) * t
        c = chord_at(s, t)
        sw = s["sweep"] * R * t * t
        le_frac = 0.30 + 0.12 * t
        lex = -le_frac * c + sw
        beta = min(math.atan(P / (2 * math.pi * max(r, 0.002))), math.radians(42.0))
        tc = s["tc"] + (0.06 - s["tc"]) * t
        camber = 0.035
        pts = []
        for k in range(m + 1):
            u = 0.5 - 0.5 * math.cos(math.pi * k / m)
            pts.append((u, camber * 4 * u * (1 - u) + 0.5 * _naca(u, tc)))
        for k in range(m, 0, -1):
            u = 0.5 - 0.5 * math.cos(math.pi * k / m)
            pts.append((u, camber * 4 * u * (1 - u) * 0.4 - 0.5 * _naca(u, tc)))
        ring = []
        for (qx, qy) in pts:
            zc = lex + qx * c
            yc = qy * c
            zz = zc * math.cos(beta) + yc * math.sin(beta)
            yy = -zc * math.sin(beta) + yc * math.cos(beta)
            # game frame (r, yy, zz*hand) with forward -z  ->  modelling frame (x, y = -z, z = up)
            ring.append(Vector((r, -zz * hand, yy)))
        rows.append(ring)
    return rows


def blade_mesh(rows, key, tip_key=None, tip_from=0.9, name="blade"):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    V = [[bm.verts.new(p) for p in ring] for ring in rows]
    nr = len(V); nj = len(V[0])
    tipi = int(round(tip_from * (nr - 1)))
    for i in range(nr - 1):
        for j in range(nj):
            j2 = (j + 1) % nj
            vs = [V[i][j], V[i][j2], V[i + 1][j2], V[i + 1][j]]
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.material_index = 1 if (tip_key and i >= tipi) else 0
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.x / 0.03, lp.vert.co.y / 0.03)
    try:
        bm.faces.new(V[0])
    except ValueError:
        pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _new_obj(name, bm, [mat(key), mat(tip_key or key)])


def blade_outline(rows):
    """Plan outline of a blade (x, y) for the drawing: the leading and trailing edge of every section."""
    le = [(ring[0].x, ring[0].y) for ring in rows]
    m = (len(rows[0]) - 1) // 2
    te = [(ring[m].x, ring[m].y) for ring in rows]
    return le + te[::-1]


# ------------------------------------------------------------------------------------------------ assembly and export
def join(objs, name):
    """Join part objects (their mesh data is already in world space) into one mesh with a merged material list."""
    mats = []
    bm = bmesh.new()
    for o in objs:
        me = o.data
        idx = []
        for m in me.materials:
            if m not in mats:
                mats.append(m)
            idx.append(mats.index(m))
        tmp = me.copy()
        mi = [0] * len(tmp.polygons)
        tmp.polygons.foreach_get("material_index", mi)
        tmp.polygons.foreach_set("material_index", [idx[k] if k < len(idx) else 0 for k in mi])
        if o.matrix_world != Matrix.Identity(4):
            tmp.transform(o.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(38.0))
    return ob


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def _hull(pts):
    pts = sorted(set((round(x, 6), round(y, 6)) for x, y in pts))
    if len(pts) < 3:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def assemble(kit, base_z, com_body):
    """Join the parts node by node, turn the model round (nose to -Y, so +Z in glTF), lift it so its base is at z 0,
    set each node's origin to its pivot and parent the nodes. Returns (root, info) where info has triangle counts and
    the drawing outlines in the game's body frame (forward -z, right +x, origin at the centre of mass)."""
    # outlines first, from the parts, in the body frame: body = (x, z - base_z, -y) - com
    plan, side = [], []
    cb = Vector(com_body)
    for p in kit.parts:
        if p.outline == "none":
            continue
        me = p.obj.data
        vs = [v.co for v in me.vertices]
        step = max(1, len(vs) // 600)
        body = [Vector((v.x, v.z - base_z, -v.y)) - cb for v in vs[::step]]
        top = max(b.y for b in body); near = min(b.x for b in body)
        if p.outline in ("hull", "plate"):
            if p.plan_pts:
                pts = [(x - cb.x, -y - cb.z) for (x, y) in p.plan_pts]
            else:
                pts = _hull([(b.x, b.z) for b in body])
            plan.append({"pts": pts, "key": top, "thin": p.thin})
        side.append({"pts": _hull([(b.z, b.y) for b in body]), "key": -near})
    turn = RZ(math.pi)
    lift = T(0, 0, -base_z)
    M = lift @ turn
    nodes = {}
    for p in kit.parts:
        nodes.setdefault(p.node, []).append(p.obj)
    root = bpy.data.objects.new(kit.name, None)
    bpy.context.scene.collection.objects.link(root)
    made = {"": root}
    counts = {}
    order = sorted(nodes.keys(), key=lambda n: (n.count("/"), n))
    for node in nodes:
        ob = join(nodes[node], node)
        for o in nodes[node]:
            me = o.data
            bpy.data.objects.remove(o)
            if me.users == 0:
                bpy.data.meshes.remove(me)
        ob.data.transform(M)
        piv = M @ Vector(kit.pivots.get(node, (0.0, 0.0, base_z)))
        ob.data.transform(T(-piv.x, -piv.y, -piv.z))
        ob.location = piv
        made[node] = ob
        counts[node] = tris(ob)
    # empty pivots that carry no mesh of their own (gimbal axes with all parts on children)
    for node, pv in kit.pivots.items():
        if node not in made:
            e = bpy.data.objects.new(node, None)
            bpy.context.scene.collection.objects.link(e)
            e.location = M @ Vector(pv)
            made[node] = e
    # every node keeps an identity rotation, so its local position is its world pivot less its parent's
    W = {n: ob.location.copy() for n, ob in made.items() if n != ""}
    W[""] = Vector((0, 0, 0))
    for node, ob in made.items():
        if node == "":
            continue
        pn = kit.parents.get(node, "")
        ob.parent = made.get(pn, root)
        ob.location = W[node] - W[pn if pn in made else ""]
    for m_name, pos in kit.marks.items():
        e = bpy.data.objects.new(m_name, None)
        bpy.context.scene.collection.objects.link(e)
        e.location = M @ Vector(pos)
        e.parent = root
    return root, made, {"plan": plan, "side": side, "tris": counts}


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    _mat_cache.clear()
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def export_glb(root, path):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    def sel(o):
        o.select_set(True)
        for c in o.children:
            sel(c)
    sel(root)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                              export_extras=True, export_image_format="JPEG", export_jpeg_quality=88, export_tangents=False,
                              export_animations=False, export_lights=False, export_cameras=False)
