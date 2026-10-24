# AeroSim sites kit (lane/sites): the shared Blender machinery for the boat launch and the cabin track and cave.
# Everything is modelled in the GAME frame (metres, x right, y up, z forward = the asset's front) and turned to Blender's
# frame only when the objects are made, so the .glb comes out with +Z forward, Y up and the origin at the base.
#
# A site asset is a root node named after the asset, holding NAMED NODES (empties: boat_ramp_slab, tree_fall_a_trunk...)
# with one mesh per level of detail under each (<node>_LOD0, <node>_LOD1). The meshes carry plain materials named
# site_* (the game swaps in the photographed sets by name, see game/site_assets.gd), UVs in metres (box projection,
# grain-aware; the loader sets uv1_scale to 1 / the repeat), and a vertex colour that is (ambient occlusion x weathering)
# in linear RGB: ray-cast occlusion against the whole asset and the ground, times the asset's stains (waterline, algae,
# rust, damp, moss, tyre polish). Checks (floating parts, inside-out pieces, base height, front probes, triangle counts)
# go into the manifest that the Godot test reads back.
import bpy, bmesh, math, os, json, random
import numpy as np
from mathutils import Vector as V, Matrix, Euler, noise
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GODOT, "assets", "models", "sites")
FONT = os.path.join(HERE, "fonts", "PTSansNarrow-Bold.ttf")

G2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))   # game (x, y, z) -> Blender (x, -z, y)


def srgb_lin(c):
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


# ------------------------------------------------------------------------------------------------ materials
# key -> (fallback base colour sRGB, roughness, metallic). The game replaces each by name with the photographed set or the
# plain PBR material of the same key (game/site_assets.gd); these values are what a bare import of the .glb shows.
MATS = {
    "site_concrete": ((0.60, 0.60, 0.58), 0.88, 0.0),
    "site_ramp": ((0.62, 0.62, 0.60), 0.85, 0.0),
    "site_gravel": ((0.55, 0.51, 0.45), 0.95, 0.0),
    "site_dirt": ((0.42, 0.34, 0.26), 0.95, 0.0),
    "site_soil": ((0.30, 0.23, 0.17), 0.95, 0.0),
    "site_mud": ((0.22, 0.18, 0.14), 0.75, 0.0),
    "site_track": ((0.40, 0.34, 0.27), 0.95, 0.0),
    "site_deck": ((0.50, 0.47, 0.43), 0.85, 0.0),
    "site_timber": ((0.40, 0.34, 0.27), 0.9, 0.0),
    "site_board": ((0.52, 0.49, 0.45), 0.88, 0.0),
    "site_paint_cream": ((0.86, 0.82, 0.68), 0.75, 0.0),
    "site_paint_red": ((0.62, 0.10, 0.08), 0.6, 0.0),
    "site_paint_white": ((0.88, 0.88, 0.85), 0.6, 0.0),
    "site_paint_green": ((0.16, 0.27, 0.19), 0.55, 0.0),
    "site_paint_black": ((0.05, 0.05, 0.05), 0.6, 0.0),
    "site_galv": ((0.62, 0.63, 0.62), 0.5, 0.85),
    "site_iron": ((0.16, 0.15, 0.14), 0.7, 0.6),
    "site_rust": ((0.40, 0.20, 0.10), 0.85, 0.2),
    "site_alu": ((0.74, 0.75, 0.75), 0.42, 0.85),
    "site_rubber": ((0.04, 0.04, 0.04), 0.85, 0.0),
    "site_plastic_white": ((0.86, 0.86, 0.82), 0.55, 0.0),
    "site_plastic_red": ((0.70, 0.08, 0.06), 0.45, 0.0),
    "site_plastic_dark": ((0.10, 0.11, 0.12), 0.45, 0.0),
    "site_plastic_green": ((0.10, 0.32, 0.18), 0.45, 0.0),
    "site_rope": ((0.72, 0.66, 0.52), 0.9, 0.0),
    "site_carpet": ((0.32, 0.33, 0.34), 1.0, 0.0),
    "site_rock": ((0.55, 0.53, 0.50), 0.9, 0.0),
    "site_rock_moss": ((0.40, 0.44, 0.30), 0.92, 0.0),
    "site_moss": ((0.28, 0.36, 0.14), 0.95, 0.0),
    "site_bark_oak": ((0.36, 0.32, 0.27), 0.92, 0.0),
    "site_bark_beech": ((0.55, 0.55, 0.52), 0.85, 0.0),
    "site_wood_fresh": ((0.72, 0.60, 0.44), 0.85, 0.0),
    "site_wood_end": ((0.70, 0.58, 0.42), 0.85, 0.0),
    "site_leaves": ((0.62, 0.40, 0.16), 0.85, 0.0),
    "site_grass": ((0.40, 0.42, 0.22), 0.9, 0.0),
    "site_cave_dark": ((0.0, 0.0, 0.0), 1.0, 0.0),
    "site_puddle": ((0.10, 0.09, 0.07), 0.04, 0.0),
    "site_lamp_red": ((0.65, 0.04, 0.03), 0.25, 0.0),
    "site_lamp_amber": ((0.85, 0.45, 0.05), 0.25, 0.0),
    "site_reflector": ((0.85, 0.85, 0.85), 0.3, 0.0),
    "site_glass": ((0.70, 0.72, 0.68), 0.15, 0.0),
    "site_canvas_blue": ((0.20, 0.34, 0.52), 0.85, 0.0),
    "site_canvas_orange": ((0.90, 0.40, 0.10), 0.85, 0.0),
    "site_paper": ((0.86, 0.84, 0.76), 0.9, 0.0),
    "site_ply": ((0.55, 0.45, 0.32), 0.85, 0.0),
    "site_decal_rust": ((0.40, 0.20, 0.10), 0.9, 0.0),
    "site_decal_algae": ((0.20, 0.26, 0.12), 0.7, 0.0),
    "site_decal_waterline": ((0.25, 0.22, 0.17), 0.8, 0.0),
    "site_decal_crack": ((0.12, 0.12, 0.11), 0.9, 0.0),
    "site_decal_oil": ((0.05, 0.05, 0.05), 0.2, 0.0),
    "site_decal_tyre": ((0.20, 0.17, 0.13), 0.9, 0.0),
    "site_decal_damp": ((0.10, 0.10, 0.09), 0.6, 0.0),
    "site_decal_chalk": ((0.85, 0.85, 0.82), 0.9, 0.0),
}

_matcache = {}


def material(key):
    if key in _matcache and _matcache[key].name == key:
        return _matcache[key]
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        col, rough, metal = MATS[key]
        b.inputs["Base Color"].default_value = srgb_lin(col) + (1.0,)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        if key.startswith("site_lamp"):
            b.inputs["Emission Color"].default_value = srgb_lin(col) + (1.0,)
            b.inputs["Emission Strength"].default_value = 0.0
    _matcache[key] = m
    return m


# ------------------------------------------------------------------------------------------------ bmesh primitives
# All return a NEW bmesh in the game frame. Callers hand it to Mesh.add, which merges, textures and frees it.

def _xf(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def mrot(rot):
    """rotation (degrees about game x, y, z, applied x then y then z) as a 4x4 matrix"""
    return Euler([math.radians(a) for a in rot], 'XYZ').to_matrix().to_4x4()


def box(size, c=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, seg=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=V(size), verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=seg, affect='EDGES',
                        profile=0.5, clamp_overlap=True)
    return _xf(bm, Matrix.Translation(V(c)) @ mrot(rot))


def grid_box(size, c=(0, 0, 0), div=(1, 1, 1), rot=(0, 0, 0)):
    """a box whose faces are subdivided (for vertex colour gradients and draping)"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=V(size), verts=bm.verts)
    cuts = max(div) - 1
    if cuts > 0:
        bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=cuts, use_grid_fill=True)
    return _xf(bm, Matrix.Translation(V(c)) @ mrot(rot))


def frame_to(a, b):
    """matrix that takes +y to the direction a->b, positioned at a"""
    a, b = V(a), V(b)
    d = b - a
    L = d.length
    up = d.normalized()
    q = V((0, 1, 0)).rotation_difference(up)
    return Matrix.Translation(a) @ q.to_matrix().to_4x4(), L


def cyl(r0, r1, a, b, seg=10, caps=True):
    """a cone frustum from point a (radius r0) to point b (radius r1)"""
    M, L = frame_to(a, b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=L)
    # create_cone is along z centred: turn to +y and lift to start at 0
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, L * 0.5, 0)) @ Matrix.Rotation(-math.pi * 0.5, 4, 'X'), verts=bm.verts)
    return _xf(bm, M)


def sphere(r, c=(0, 0, 0), scale=(1, 1, 1), seg=10, rings=6):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for v in bm.verts:
        v.co = V((v.co.x * scale[0], v.co.z * scale[1], -v.co.y * scale[2]))
    return _xf(bm, Matrix.Translation(V(c)))


def torus(R, r, c=(0, 0, 0), rot=(0, 0, 0), seg=24, sides=8, a0=0.0, a1=math.tau):
    """a torus (or an arc of one) in the x-y plane, facing +z"""
    bm = bmesh.new()
    full = abs((a1 - a0) - math.tau) < 1e-6
    n = seg if full else seg + 1
    rings = []
    for i in range(n):
        t = a0 + (a1 - a0) * i / seg
        cen = V((math.cos(t) * R, math.sin(t) * R, 0))
        out = V((math.cos(t), math.sin(t), 0))
        ring = []
        for j in range(sides):
            p = j / sides * math.tau
            ring.append(bm.verts.new(cen + out * (math.cos(p) * r) + V((0, 0, math.sin(p) * r))))
        rings.append(ring)
    for i in range(seg if full else seg):
        A = rings[i]; B = rings[(i + 1) % n]
        for j in range(sides):
            bm.faces.new((A[j], A[(j + 1) % sides], B[(j + 1) % sides], B[j]))
    if not full:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _xf(bm, Matrix.Translation(V(c)) @ mrot(rot))


def sweep(path, radius, seg=8, caps=True, twist=0.0, rfn=None, section=None, close_path=False):
    """a tube along a polyline. radius a number or a list per point; rfn(i, j, angle) -> radius multiplier for bark
    noise; section: list of (u, v) points for a non-round section (scaled by radius)."""
    pts = [V(p) for p in path]
    n = len(pts)
    rad = radius if isinstance(radius, (list, tuple)) else [radius] * n
    bm = bmesh.new()
    rings = []
    prev_side = None
    for i, p in enumerate(pts):
        if close_path:
            t = (pts[(i + 1) % n] - pts[(i - 1) % n])
        elif i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        t.normalize()
        if prev_side is None:
            ref = V((0, 1, 0)) if abs(t.y) < 0.9 else V((1, 0, 0))
            side = t.cross(ref).normalized()
        else:
            side = (prev_side - t * prev_side.dot(t)).normalized()
        up = side.cross(t).normalized()
        prev_side = side
        ring = []
        sec = section or [(math.cos(j / seg * math.tau), math.sin(j / seg * math.tau)) for j in range(seg)]
        for j, (cu, cv) in enumerate(sec):
            ang = math.atan2(cv, cu) + twist * i
            rr = rad[i] * (rfn(i, j, ang) if rfn else 1.0)
            ring.append(bm.verts.new(p + (side * cu + up * cv) * rr))
        rings.append(ring)
    m = len(rings[0])
    for i in range(n - 1 + (1 if close_path else 0)):
        A = rings[i]; B = rings[(i + 1) % n]
        for j in range(m):
            bm.faces.new((A[j], A[(j + 1) % m], B[(j + 1) % m], B[j]))
    if caps and not close_path:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def loft(rings, close_ring=True, cap0=False, cap1=False):
    """skin a list of rings (each a list of points, same count)"""
    bm = bmesh.new()
    vr = [[bm.verts.new(V(p)) for p in r] for r in rings]
    m = len(vr[0])
    for i in range(len(vr) - 1):
        A, B = vr[i], vr[i + 1]
        for j in range(m if close_ring else m - 1):
            bm.faces.new((A[j], A[(j + 1) % m], B[(j + 1) % m], B[j]))
    if cap0:
        bm.faces.new(list(reversed(vr[0])))
    if cap1:
        bm.faces.new(vr[-1])
    return bm


def grid(xs, zs, yfn=lambda x, z: 0.0, keep=None):
    """a ground grid over the given x and z stations, height yfn(x, z); keep(x, z) drops cells outside a shape"""
    bm = bmesh.new()
    vv = {}
    for i, x in enumerate(xs):
        for k, z in enumerate(zs):
            vv[i, k] = bm.verts.new((x, yfn(x, z), z))
    for i in range(len(xs) - 1):
        for k in range(len(zs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) * 0.5, (zs[k] + zs[k + 1]) * 0.5
            if keep and not keep(cx, cz):
                continue
            bm.faces.new((vv[i, k], vv[i, k + 1], vv[i + 1, k + 1], vv[i + 1, k]))
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    for f in bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    bm.normal_update()
    return bm


def disc_patch(rx, rz, step, edge_sink=0.05, seed=0, wobble=0.12, top=0.03, yfn=None, rings=None):
    """an irregular ground patch (ellipse with a noisy outline) as concentric rings: flat top, outer ring sunk below the
    ground so the terrain cuts a ragged edge. yfn(x, z) adds relief."""
    rnd = random.Random(seed)
    nseg = max(16, int(2 * math.pi * max(rx, rz) / step))
    ph = [rnd.uniform(0, 6.28) for _ in range(4)]
    def edge_r(a):
        return 1.0 + wobble * (0.6 * math.sin(3 * a + ph[0]) + 0.3 * math.sin(7 * a + ph[1]) + 0.2 * math.sin(13 * a + ph[2]))
    nr = rings or max(3, int(max(rx, rz) / step))
    bm = bmesh.new()
    centre = bm.verts.new((0, top + (yfn(0, 0) if yfn else 0), 0))
    prev = None
    for ri in range(1, nr + 1):
        f = ri / nr
        ring = []
        for j in range(nseg):
            a = j / nseg * math.tau
            e = edge_r(a)
            x = math.cos(a) * rx * f * e
            z = math.sin(a) * rz * f * e
            y = top + (yfn(x, z) if yfn else 0.0)
            if ri == nr:
                y = -edge_sink
            elif ri == nr - 1:
                y = y * 0.5 - edge_sink * 0.2
            ring.append(bm.verts.new((x, y, z)))
        if prev is None:
            for j in range(nseg):
                bm.faces.new((centre, ring[(j + 1) % nseg], ring[j]))
        else:
            for j in range(nseg):
                bm.faces.new((prev[j], prev[(j + 1) % nseg], ring[(j + 1) % nseg], ring[j]))
        prev = ring
    bm.normal_update()
    for f in bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    return bm


def rock(size, c=(0, 0, 0), seed=0, subdiv=2, cuts=7, rough=0.12, embed=0.08, flat_base=True, rot_y=0.0, layered=0.0,
         blocky=0.0, depth=(0.5, 0.8)):
    """a fractured boulder: an icosphere scaled to size (x, y, z), pushed by fractal noise, then cut by random planes
    (vertices beyond a plane are projected onto it, which leaves the flat broken faces of real rock), base flattened
    and sunk `embed` metres into the ground. layered > 0 adds horizontal bedding steps (sedimentary breaks)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    if blocky > 0:
        # a subdivided cube, its corners rounded a little: joint-bounded blocks of an outcrop rather than river boulders
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=max(1, subdiv + 1), use_grid_fill=True)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        for v in bm.verts:
            v.co = v.co.lerp(v.co.normalized() * 0.55, 1.0 - blocky)
    else:
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=0.5)
    off = V((rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(-50, 50)))
    sx, sy, sz = size
    for v in bm.verts:
        p = v.co.copy()
        d = p.normalized()
        n1 = noise.fractal(p * 2.2 + off, 0.6, 2.0, 4)
        p = p * (1.0 + rough * n1)
        v.co = V((p.x * sx, p.z * sy, p.y * sz))
    # fracture planes
    for k in range(cuts):
        d = V((rnd.uniform(-1, 1), rnd.uniform(-0.6, 1.0), rnd.uniform(-1, 1))).normalized()
        ext = abs(d.x) * sx * 0.5 + abs(d.y) * sy * 0.5 + abs(d.z) * sz * 0.5
        h = ext * rnd.uniform(depth[0], depth[1])
        for v in bm.verts:
            s = v.co.dot(d)
            if s > h:
                v.co -= d * (s - h)
    if layered > 0:
        for v in bm.verts:
            q = (v.co.y + sy * 0.5) / layered
            fr = q - math.floor(q)
            if fr < 0.25:
                inset = (0.25 - fr) / 0.25 * 0.06
                v.co.x *= (1 - inset); v.co.z *= (1 - inset)
    lo = min(v.co.y for v in bm.verts)
    for v in bm.verts:
        v.co.y -= lo
    if flat_base:
        for v in bm.verts:
            if v.co.y < sy * 0.12:
                v.co.y = sy * 0.12 * (v.co.y / (sy * 0.12)) ** 2.0 if sy > 0 else 0
    for v in bm.verts:
        v.co.y -= embed
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _xf(bm, Matrix.Translation(V(c)) @ Matrix.Rotation(rot_y, 4, 'Y'))


def text_mesh(txt, size, extrude=0.002, align='CENTER', font=FONT, spacing=1.0):
    """lettering as a mesh in the game x-y plane facing +z (baseline at y=0), centred on x"""
    cu = bpy.data.curves.new("txt", 'FONT')
    cu.body = txt
    try:
        cu.font = bpy.data.fonts.load(font, check_existing=True)
    except Exception:
        pass
    cu.size = size
    cu.extrude = extrude
    cu.align_x = align
    cu.space_character = spacing
    cu.resolution_u = 3
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bm = bmesh.new(); bm.from_mesh(me)
    bpy.data.objects.remove(ob); bpy.data.curves.remove(cu); bpy.data.meshes.remove(me)
    # Blender text lies in its x-y plane with +z up out of the page: that is already the game's front (+z) facing x-y
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


# ------------------------------------------------------------------------------------------------ the mesh builder
class Mesh:
    """one node's geometry in the game frame, built from primitives. add() merges a bmesh with a material and UVs."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.mats = []
        self.smooth_faces = set()
        self.tags = {}            # face index range -> tag (for per-piece weathering)
        self._tag_faces = []      # (first, last, tag)

    def mi(self, key):
        if key not in self.mats:
            self.mats.append(key)
        return self.mats.index(key)

    def add(self, bm2, mat, tile=1.0, grain=None, smooth=False, uv=None, tag=None, keep_uv=False, mat_fn=None, recalc=True):
        """merge bm2 (freed). uv: None for box projection in metres (u along the grain where it lies in the face plane),
        'cyl' for a cylindrical wrap about the grain (bark: u round, v along), or a function f(co, normal) -> (u, v).
        mat_fn(face_centre, normal) -> material key per face (moss on top, etc.)"""
        if recalc:
            # closed pieces: consistent winding, outward (open surfaces that need a set side pass recalc=False)
            bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces[:])
            # safety for lumpy closed shapes: a closed piece must enclose a positive volume
            for grp in _components(bm2):
                if all(len(e.link_faces) == 2 for f in grp for e in f.edges):
                    vol = 0.0
                    for f in grp:
                        cs = [v.co for v in f.verts]
                        for k in range(1, len(cs) - 1):
                            vol += cs[0].dot(cs[k].cross(cs[k + 1])) / 6.0
                    if vol < 0:
                        for f in grp:
                            f.normal_flip()
        bm2.normal_update()
        me = bpy.data.meshes.new("tmp")
        if not keep_uv:
            for l in list(bm2.loops.layers.uv.values()):
                bm2.loops.layers.uv.remove(l)
        bm2.to_mesh(me)
        bm2.free()
        self.bm.faces.ensure_lookup_table()
        n0 = len(self.bm.faces)
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        self.bm.faces.ensure_lookup_table()
        new = self.bm.faces[n0:]
        idx = self.mi(mat)
        ga = V(grain).normalized() if grain is not None else None
        for f in new:
            n = f.normal
            if mat_fn:
                f.material_index = self.mi(mat_fn(f.calc_center_median(), n))
            else:
                f.material_index = idx
            if smooth:
                f.smooth = True
            if keep_uv:
                continue
            if callable(uv):
                for l in f.loops:
                    u, vv = uv(l.vert.co, n)
                    l[self.uv].uv = (u / tile, vv / tile)
                continue
            if uv == 'cyl' and ga is not None:
                # u round the axis (radians times a nominal radius of 0.25 m), v along it
                for l in f.loops:
                    p = l.vert.co
                    a = V((1, 0, 0)) if abs(ga.x) < 0.9 else V((0, 0, 1))
                    s = ga.cross(a).normalized(); t = ga.cross(s)
                    ang = math.atan2(p.dot(t), p.dot(s))
                    l[self.uv].uv = (ang * 0.25 / tile, p.dot(ga) / tile)
                # fix the seam: make u continuous within the face
                us = [l[self.uv].uv.x for l in f.loops]
                if max(us) - min(us) > math.pi * 0.25 / tile:
                    for l in f.loops:
                        if l[self.uv].uv.x < 0:
                            l[self.uv].uv.x += math.tau * 0.25 / tile
                continue
            ax = max(range(3), key=lambda i: abs(n[i]))
            if ga is not None and abs(ga[ax]) < 0.7:
                u_ax = ga
            else:
                u_ax = V((1, 0, 0)) if ax != 0 else V((0, 0, 1))
            v_ax = n.cross(u_ax)
            if v_ax.length < 1e-6:
                v_ax = V((0, 1, 0))
            v_ax.normalize()
            u_ax = v_ax.cross(n).normalized() if n.length > 0 else u_ax
            for l in f.loops:
                p = l.vert.co
                l[self.uv].uv = (p.dot(u_ax) / tile, p.dot(v_ax) / tile)
        if tag is not None:
            self._tag_faces.append((n0, len(self.bm.faces), tag))
        return new

    def face_tag(self, fi):
        for a, b, t in self._tag_faces:
            if a <= fi < b:
                return t
        return None

    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)


# ------------------------------------------------------------------------------------------------ the asset
class Asset:
    """nodes: name -> (Mesh, pivot (game), rot_y degrees). colour(co, n, mat, node, tag) -> (r, g, b) weathering.
    meta goes to the manifest (waterline, text rectangle, notes)."""

    def __init__(self, name, ground=True, ao_dist=0.6, ao_strength=0.75, lod1=0.45, lod_end=None, meta=None,
                 colour=None, buried_ok=0.0, float_ok=(), probes=(), budget=None):
        self.name = name
        self.nodes = {}
        self.order = []
        self.ground = ground
        self.ao_dist = ao_dist
        self.ao_strength = ao_strength
        self.lod1 = lod1
        self.lod_end = lod_end
        self.meta = meta or {}
        self.colour = colour
        self.buried_ok = buried_ok
        self.float_ok = set(float_ok)
        self.probes = list(probes)
        self.budget = budget

    def node(self, name, pivot=(0, 0, 0), rot=(0, 0, 0)):
        """a named node. Geometry is built in the asset frame in the node's REST pose; pivot is the node origin and rot
        (degrees about game x, y, z) is the pose the node is exported in (a gate swung open, an outboard tilted up)."""
        if name not in self.nodes:
            self.nodes[name] = [Mesh(name), V(pivot), tuple(rot)]
            self.order.append(name)
        return self.nodes[name][0]


def _components(bm):
    seen = set()
    out = []
    for f0 in bm.faces:
        if f0 in seen:
            continue
        st = [f0]; seen.add(f0); grp = []
        while st:
            f = st.pop(); grp.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g not in seen:
                        seen.add(g); st.append(g)
        out.append(grp)
    return out


def _hemi(n, k):
    """k fixed cosine-weighted directions about normal n"""
    a = V((1, 0, 0)) if abs(n.x) < 0.9 else V((0, 1, 0))
    s = n.cross(a).normalized(); t = n.cross(s)
    out = []
    ga = math.pi * (3 - math.sqrt(5))
    for i in range(k):
        r = math.sqrt((i + 0.5) / k)
        th = i * ga
        x, y = r * math.cos(th), r * math.sin(th)
        z = math.sqrt(max(0.0, 1 - r * r))
        out.append((s * x + t * y + n * z).normalized())
    return out


def checks(asset):
    """floating parts, inside-out pieces, the base, probes; all in the game frame on LOD0"""
    comps = []
    for nm in asset.order:
        mesh = asset.nodes[nm][0]
        mesh.bm.normal_update()
        for grp in _components(mesh.bm):
            vs = {v for f in grp for v in f.verts}
            lo = V((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
            hi = V((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
            closed = all(len(e.link_faces) == 2 for f in grp for e in f.edges) and len(grp) >= 4
            vol = 0.0
            if closed:
                for f in grp:
                    cs = [v.co for v in f.verts]
                    for k in range(1, len(cs) - 1):
                        vol += cs[0].dot(cs[k].cross(cs[k + 1])) / 6.0
            comps.append((nm, lo, hi, closed, vol))
    floating = []
    for i, (nm, lo, hi, c, vol) in enumerate(comps):
        if lo.y <= 0.03 or nm in asset.float_ok:
            continue
        best = 1e9
        for j, (n2, lo2, hi2, c2, v2) in enumerate(comps):
            if i == j:
                continue
            gap = max(0.0, lo2.x - hi.x, lo.x - hi2.x, lo2.y - hi.y, lo.y - hi2.y, lo2.z - hi.z, lo.z - hi2.z)
            best = min(best, gap)
        if best > 0.03:
            floating.append("%s@(%.2f,%.2f,%.2f)" % (nm, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2))
    inside_out = sorted({"%s@(%.2f,%.2f,%.2f)" % (nm, (lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
                         for (nm, lo, hi, c, vol) in comps if c and vol < -1e-7})
    alo = V((min(c[1].x for c in comps), min(c[1].y for c in comps), min(c[1].z for c in comps)))
    ahi = V((max(c[2].x for c in comps), max(c[2].y for c in comps), max(c[2].z for c in comps)))
    probes = []
    for p in asset.probes:
        ok = probe(asset, p, alo, ahi)
        probes.append({"probe": p, "ok": ok})
    return {"floating": floating, "inside_out": inside_out, "min_y": round(alo.y, 3), "aabb": [list(map(lambda x: round(x, 3), alo)),
            list(map(lambda x: round(x, 3), ahi))], "probes": probes, "components": len(comps)}


def node_box(asset, nm):
    vs = asset.nodes[nm][0].bm.verts
    lo = V((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
    hi = V((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
    return lo, hi


def probe(asset, p, alo, ahi):
    """{"node": n, "axis": "z", "side": 1}: the node's centre lies on that side of the asset centre.
    {"node": n, "mat": m, "dir": [0, 0, 1]}: the area-weighted normal of that material's faces points along dir."""
    if "side" in p:
        lo, hi = node_box(asset, p["node"])
        i = "xyz".index(p["axis"])
        return ((lo[i] + hi[i]) * 0.5 - (alo[i] + ahi[i]) * 0.5) * p["side"] > 0.0
    mesh = asset.nodes[p["node"]][0]
    if p["mat"] not in mesh.mats:
        return False
    mi = mesh.mats.index(p["mat"])
    acc = V((0, 0, 0))
    for f in mesh.bm.faces:
        if f.material_index == mi:
            acc += f.normal * f.calc_area()
    return acc.length > 0 and acc.normalized().dot(V(p["dir"]).normalized()) > 0.7


def bake_colours(asset):
    """vertex colour = ambient occlusion (rays against the whole asset and the ground) x the asset's weathering"""
    tris_all = []
    verts_all = []
    for nm in asset.order:
        bm = asset.nodes[nm][0].bm
        bm.verts.index_update()
        base = len(verts_all)
        verts_all.extend([v.co.copy() for v in bm.verts])
        for f in bm.faces:
            ids = [v.index + base for v in f.verts]
            for k in range(1, len(ids) - 1):
                tris_all.append((ids[0], ids[k], ids[k + 1]))
    if asset.ground:
        b = len(verts_all)
        S = 200.0
        verts_all += [V((-S, 0, -S)), V((S, 0, -S)), V((S, 0, S)), V((-S, 0, S))]
        tris_all += [(b, b + 1, b + 2), (b, b + 2, b + 3)]
    bvh = BVHTree.FromPolygons(verts_all, tris_all, all_triangles=True, epsilon=0.0)
    K = 14
    for nm in asset.order:
        mesh = asset.nodes[nm][0]
        bm = mesh.bm
        cl = bm.loops.layers.float_color.get("Col") or bm.loops.layers.float_color.new("Col")
        cache = {}
        bm.faces.ensure_lookup_table()
        for fi, f in enumerate(bm.faces):
            fn = f.normal.copy()
            mat = mesh.mats[f.material_index]
            tag = mesh.face_tag(fi)
            for l in f.loops:
                v = l.vert
                n = (v.normal if f.smooth else fn).normalized()
                key = (v.index, round(n.x, 1), round(n.y, 1), round(n.z, 1))
                if key not in cache:
                    occ = 0.0
                    if asset.ao_strength > 0:
                        o = v.co + n * 0.004
                        for d in _hemi(n, K):
                            hit = bvh.ray_cast(o, d, asset.ao_dist)
                            if hit[0] is not None:
                                occ += 1.0 - (hit[3] / asset.ao_dist) * 0.6
                        occ /= K
                    cache[key] = 1.0 - asset.ao_strength * occ
                ao = cache[key]
                w = asset.colour(v.co, n, mat, nm, tag) if asset.colour else (1.0, 1.0, 1.0)
                l[cl] = tuple(max(0.03, min(1.0, ao * x)) for x in w[:3]) + (1.0,)   # glTF stores 0..1: more wraps round


def node_matrix(pivot, rot):
    return Matrix.Translation(pivot) @ mrot(rot)


def _pose(asset):
    """move the geometry of rotated nodes into the pose they are exported in, so checks and occlusion see the final shape"""
    for nm in asset.order:
        mesh, pivot, rot = asset.nodes[nm]
        if any(abs(a) > 1e-9 for a in rot):
            M = node_matrix(pivot, rot) @ Matrix.Translation(-pivot)
            bmesh.ops.transform(mesh.bm, matrix=M, verts=mesh.bm.verts)
            mesh.bm.normal_update()


def _make_object(name, mesh, pivot, rot, coll):
    bm = mesh.bm.copy()
    bmesh.ops.transform(bm, matrix=node_matrix(pivot, rot).inverted(), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=G2B, verts=bm.verts)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for k in mesh.mats:
        me.materials.append(material(k))
    if "Col" in me.color_attributes:
        ca = me.color_attributes["Col"]
        me.color_attributes.active_color = ca
        try:
            me.color_attributes.render_color_index = me.color_attributes.find("Col")
        except Exception:
            pass
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def decimate(ob, ratio, name):
    c = ob.copy(); c.data = ob.data.copy(); c.name = name
    bpy.context.scene.collection.objects.link(c)
    m = c.modifiers.new("d", 'DECIMATE')
    m.decimate_type = 'COLLAPSE'
    m.ratio = ratio
    m.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    nme = bpy.data.meshes.new_from_object(c.evaluated_get(dg))
    c.modifiers.clear()
    old = c.data; c.data = nme
    bpy.data.meshes.remove(old)
    nme.name = name
    if "Col" in nme.color_attributes:
        nme.color_attributes.active_color = nme.color_attributes["Col"]
    return c


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _matcache.clear()


def build(asset, out_dir=OUT):
    """bake colours, make the objects (root > node empties > LOD meshes), export the .glb, return the manifest entry"""
    clear_scene()
    os.makedirs(out_dir, exist_ok=True)
    _pose(asset)
    chk = checks(asset)
    bake_colours(asset)
    coll = bpy.context.scene.collection
    # the named nodes are the top-level objects: Godot puts them straight under the imported scene's root
    objs = []
    tris0 = tris1 = 0
    nodes_info = {}
    for nm in asset.order:
        mesh, pivot, rot = asset.nodes[nm]
        if len(mesh.bm.faces) == 0:
            continue
        e = bpy.data.objects.new(nm, None)
        coll.objects.link(e)
        e.matrix_basis = G2B @ node_matrix(pivot, rot) @ G2B.inverted()
        objs.append(e)
        o0 = _make_object(nm + "_LOD0", mesh, pivot, rot, coll)
        o0.parent = e
        objs.append(o0)
        t0 = tri_count(o0)
        tris0 += t0
        info = {"pivot": [round(x, 3) for x in pivot], "rot": list(rot), "tris": [t0], "materials": list(mesh.mats)}
        if asset.lod1 and t0 > 150:
            o1 = decimate(o0, asset.lod1, nm + "_LOD1")
            o1.parent = e
            objs.append(o1)
            info["tris"].append(tri_count(o1))
            tris1 += tri_count(o1)
        else:
            tris1 += t0
        nodes_info[nm] = info
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(out_dir, asset.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                              export_texcoords=True, export_normals=True, export_tangents=True, export_materials='EXPORT',
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_active_vertex_color_when_no_material=True, export_image_format='NONE',
                              export_animations=False, export_extras=False)
    lo, hi = chk["aabb"]
    size = [round(hi[i] - lo[i], 3) for i in range(3)]
    span = max(size)
    lod_end = asset.lod_end or max(18.0, min(70.0, span * 9.0))
    man = {"file": asset.name + ".glb", "tris": [tris0, tris1], "size": size, "aabb_lo": lo, "aabb_hi": hi,
           "nodes": nodes_info, "lod_end": round(lod_end, 1), "checks": chk, "meta": asset.meta,
           "buried_ok": asset.buried_ok, "budget": asset.budget, "bytes": os.path.getsize(path)}
    print("SITE %-28s tris %6d/%6d  size %s  floating %s  inside_out %s  probes %s" % (
        asset.name, tris0, tris1, size, chk["floating"], chk["inside_out"], [p["ok"] for p in chk["probes"]]), flush=True)
    return man


# ------------------------------------------------------------------------------------------------ weathering helpers
def fbm(p, scale=1.0, oct=3, seed=0.0):
    """fractal noise squashed to -1..1 (the raw fractal can run well past 1, which would push colours negative)"""
    v = noise.fractal(V((p[0] * scale + seed, p[1] * scale + seed * 0.7, p[2] * scale - seed)), 0.55, 2.0, oct)
    return math.tanh(v * 0.7)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0))) if e1 != e0 else (1.0 if x >= e1 else 0.0)
    return t * t * (3 - 2 * t)
