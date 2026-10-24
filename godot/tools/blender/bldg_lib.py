"""Building kit for the Halloway buildings, the garage and the cabin (lane/buildings).

Everything is modelled in the GAME frame: metres, x right, y up, +z the street front, origin on the ground at the middle of
the footprint. Blender is Z-up, so points go through G() on the way in; the glTF exporter's +Y-up conversion turns them
back, so the .glb is in the game frame exactly.

Geometry is gathered in Acc objects (one per output node: body, door, window_light ...). Every face carries a material key
(the material name in the .glb, which StoryAssets swaps for the photographed set in the game), a tint (sRGB, written as the
vertex colour so one material serves many paints) and the coarsest level of detail it still appears in. Walls with openings
are made with Blender's exact boolean and read back into the Acc. Lettering is Blender text in an OFL font, converted to
mesh (real glyph outlines, extruded), read back the same way.

UVs are written in METRES (each material's repeat size is applied in the game's material), projected per face: walls get u
along the wall and v up; roof faces get u along the eaves and v up the slope; flat faces get x and z. So brick courses stay
level, slate courses run along the eaves and corrugations run down the slope.
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))


def G(p):
    """game (x, y up, z front) -> blender (x, -z, y)"""
    return Vector((p[0], -p[2], p[1]))


def ungame(b):
    return Vector((b[0], b[2], -b[1]))


def V(x, y, z):
    return Vector((x, y, z))


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


UP = V(0, 1, 0)

# materials whose UVs are given explicitly (0..1 per face) instead of projected in metres
EXPLICIT_UV = {"bld_grime", "bld_decal"}


class Acc:
    """Faces for one output node. pivot: the node's origin in the model frame."""

    def __init__(self, name, pivot=V(0, 0, 0)):
        self.name = name
        self.pivot = Vector(pivot)
        self.verts = []
        self.faces = []      # [indices], mat, tint(rgb srgb), smooth, uvs or None, alpha

    def _v(self, p):
        self.verts.append(Vector(p))
        return len(self.verts) - 1

    def poly(self, pts, mat, tint, smooth=False, uvs=None, alpha=1.0):
        ids = [self._v(p) for p in pts]
        self.faces.append([ids, mat, tint, smooth, uvs, alpha])

    def tris_count(self):
        return sum(len(f[0]) - 2 for f in self.faces)


class Kit:
    """The builder: an Acc per node, the current level of detail, materials and helpers."""

    def __init__(self, asset, lod, seed=1):
        self.asset = asset
        self.lod = lod
        self.nodes = {"body": Acc("body")}
        self.hulls = []
        self.rng = random.Random(seed)

    def node(self, name, pivot=None):
        if name not in self.nodes:
            self.nodes[name] = Acc(name, pivot if pivot is not None else V(0, 0, 0))
        return self.nodes[name]

    def jit(self, tint, amt=0.05):
        r = self.rng
        f = 1.0 + (r.random() - 0.5) * 2.0 * amt
        return tuple(max(0.0, min(1.0, c * f * (1.0 + (r.random() - 0.5) * amt * 0.5))) for c in tint)

    # ------------------------------------------------------------------ primitives
    def quad(self, a, b, c, d, mat, tint, node="body", double=False, uvs=None, alpha=1.0):
        acc = self.nodes[node] if isinstance(node, str) else node
        acc.poly([a, b, c, d], mat, tint, uvs=uvs, alpha=alpha)
        if double:
            acc.poly([d, c, b, a], mat, tint, uvs=None if uvs is None else [uvs[3], uvs[2], uvs[1], uvs[0]], alpha=alpha)

    def box(self, c, s, mat, tint, ax=None, node="body", skip=()):
        """A box centred on c, size s along the axes ax = (ex, ey, ez) (unit, right-handed). skip: faces to leave out
        ('+x', '-y' ...) where they would be hidden against a wall."""
        acc = self.nodes[node] if isinstance(node, str) else node
        ex, ey, ez = ax if ax else (V(1, 0, 0), V(0, 1, 0), V(0, 0, 1))
        c = Vector(c)
        hx, hy, hz = ex * (s[0] * 0.5), ey * (s[1] * 0.5), ez * (s[2] * 0.5)
        for key, n, u, v in (("+x", hx, hy, hz), ("-x", -hx, hz, hy), ("+y", hy, hz, hx), ("-y", -hy, hx, hz),
                             ("+z", hz, hx, hy), ("-z", -hz, hy, hx)):
            if key in skip:
                continue
            p = c + n
            acc.poly([p - u - v, p + u - v, p + u + v, p - u + v], mat, tint)

    def hexa(self, bot, top, mat, tint, node="body", skip=()):
        """A six-sided solid from 4 bottom and 4 top corners, both listed counter-clockwise seen from above."""
        acc = self.nodes[node] if isinstance(node, str) else node
        if "top" not in skip:
            acc.poly([top[0], top[1], top[2], top[3]], mat, tint)
        if "bot" not in skip:
            acc.poly([bot[3], bot[2], bot[1], bot[0]], mat, tint)
        for i in range(4):
            j = (i + 1) % 4
            if ("s%d" % i) in skip:
                continue
            acc.poly([bot[i], bot[j], top[j], top[i]], mat, tint)

    def cyl(self, a, b, r0, r1, seg, mat, tint, node="body", caps=3, smooth=True, ang0=0.0, ang1=None):
        acc = self.nodes[node] if isinstance(node, str) else node
        a = Vector(a); b = Vector(b)
        z = (b - a)
        L = z.length
        if L < 1e-6:
            return
        z /= L
        h = UP if abs(z.y) < 0.95 else V(1, 0, 0)
        x = h.cross(z).normalized()
        y = z.cross(x)
        full = ang1 is None
        if full:
            ang1 = ang0 + math.tau
        n = seg if full else seg + 1
        ra = [a + (x * math.cos(ang0 + (ang1 - ang0) * k / seg) + y * math.sin(ang0 + (ang1 - ang0) * k / seg)) * r0 for k in range(n)]
        rb = [b + (x * math.cos(ang0 + (ang1 - ang0) * k / seg) + y * math.sin(ang0 + (ang1 - ang0) * k / seg)) * r1 for k in range(n)]
        for k in range(seg):
            k2 = (k + 1) % n
            acc.poly([ra[k], ra[k2], rb[k2], rb[k]], mat, tint, smooth=smooth)
        if full and caps & 1:
            acc.poly(list(reversed(ra)), mat, tint)
        if full and caps & 2:
            acc.poly(rb, mat, tint)

    def lathe(self, c, prof, seg, mat, tint, node="body", smooth=True):
        """Profile [(r, y)] from bottom to top, swept round +y at c."""
        acc = self.nodes[node] if isinstance(node, str) else node
        c = Vector(c)
        rings = []
        for r, y in prof:
            rings.append([c + V(r * math.cos(math.tau * k / seg), y, -r * math.sin(math.tau * k / seg)) for k in range(seg)])
        for i in range(len(rings) - 1):
            A, B = rings[i], rings[i + 1]
            for k in range(seg):
                k2 = (k + 1) % seg
                if prof[i][0] < 1e-6 and prof[i + 1][0] < 1e-6:
                    continue
                if prof[i][0] < 1e-6:
                    acc.poly([A[k], B[k2], B[k]], mat, tint, smooth=smooth)
                elif prof[i + 1][0] < 1e-6:
                    acc.poly([A[k], A[k2], B[k]], mat, tint, smooth=smooth)
                else:
                    acc.poly([A[k], A[k2], B[k2], B[k]], mat, tint, smooth=smooth)

    def sweep(self, prof, a, b, up_hint, mat, tint, node="body", caps=True, smooth=False):
        """A closed CCW 2D profile [(s, t)] swept straight from a to b: t runs along up_hint (made square to the run) and
        s along up x run."""
        acc = self.nodes[node] if isinstance(node, str) else node
        a = Vector(a); b = Vector(b)
        d = (b - a).normalized()
        up = Vector(up_hint)
        up = (up - d * up.dot(d)).normalized()
        sd = up.cross(d).normalized()
        A = [a + sd * s + up * t for s, t in prof]
        B = [b + sd * s + up * t for s, t in prof]
        n = len(prof)
        for k in range(n):
            k2 = (k + 1) % n
            acc.poly([A[k], A[k2], B[k2], B[k]], mat, tint, smooth=smooth)
        if caps:
            acc.poly(list(reversed(A)), mat, tint)
            acc.poly(B, mat, tint)

    def slab_poly(self, pts2d, origin, ex, ey, thick, mat, tint, node="body"):
        """A flat polygon (2D points in the plane origin + ex*s + ey*t, CCW) extruded `thick` along ex x ey."""
        acc = self.nodes[node] if isinstance(node, str) else node
        n = ex.cross(ey).normalized()
        front = [origin + ex * s + ey * t for s, t in pts2d]
        back = [p - n * thick for p in front]
        acc.poly(front, mat, tint)
        acc.poly(list(reversed(back)), mat, tint)
        m = len(front)
        for k in range(m):
            k2 = (k + 1) % m
            acc.poly([front[k2], front[k], back[k], back[k2]], mat, tint)

    # ------------------------------------------------------------------ Blender-made parts read back into an Acc
    def take(self, obj, tints, node="body", default_tint=(1, 1, 1)):
        """Reads the evaluated mesh of a Blender object into the node: materials by slot name, tint by material."""
        acc = self.nodes[node] if isinstance(node, str) else node
        dg = bpy.context.evaluated_depsgraph_get()
        ev = obj.evaluated_get(dg)
        me = ev.to_mesh()
        mw = obj.matrix_world
        verts = [ungame(mw @ v.co) for v in me.vertices]
        for p in me.polygons:
            mname = ev.material_slots[p.material_index].material.name if ev.material_slots and ev.material_slots[p.material_index].material else "bld_paint"
            acc.poly([verts[i] for i in p.vertices], mname, tints.get(mname, default_tint), smooth=p.use_smooth)
        ev.to_mesh_clear()


# ====================================================================== Blender scene helpers
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _fonts.clear()          # the factory reset frees the loaded fonts


_mats = {}


def bmat(name):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    return m


def mesh_obj(name, verts_game, faces, mats):
    """faces: [(indices), mat_index]"""
    me = bpy.data.meshes.new(name)
    me.from_pydata([G(v) for v in verts_game], [], [f[0] for f in faces])
    for mn in mats:
        me.materials.append(bmat(mn))
    for p, f in zip(me.polygons, faces):
        p.material_index = f[1]
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def prism_obj(name, prof_xy, z0, z1, mat, axis="z"):
    """A prism of the 2D profile [(a, y)] (CCW) between z0 and z1 along the game axis `axis` ('z' or 'x')."""
    vs = []
    for a, y in prof_xy:
        vs.append(V(a, y, z0) if axis == "z" else V(z0, y, -a))
    for a, y in prof_xy:
        vs.append(V(a, y, z1) if axis == "z" else V(z1, y, -a))
    n = len(prof_xy)
    faces = [(list(range(n - 1, -1, -1)), 0), (list(range(n, 2 * n)), 0)]
    for k in range(n):
        k2 = (k + 1) % n
        faces.append(([k, k2, n + k2, n + k], 0))
    ob = mesh_obj(name, vs, faces, [mat])
    # make the normals point out whatever the winding of the profile
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    return ob


def box_obj(name, c, s, mat):
    c = Vector(c); h = Vector(s) * 0.5
    vs = [c + V(sx * h.x, sy * h.y, sz * h.z) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    F = [((0, 2, 3, 1), 0), ((4, 5, 7, 6), 0), ((0, 1, 5, 4), 0), ((2, 6, 7, 3), 0), ((0, 4, 6, 2), 0), ((1, 3, 7, 5), 0)]
    ob = mesh_obj(name, vs, F, [mat])
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    return ob


def bisect_y(ob, heights):
    """Cuts every face of the object at these heights (game y), so vertex colours can grade up a wall."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    for y in heights:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=G(V(0, y, 0)), plane_no=G(V(0, 1, 0)))
    bm.to_mesh(ob.data); bm.free()


def boolean_cut(target, cutters, name="cut"):
    if not cutters:
        return target
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    for c in cutters:
        for uc in list(c.users_collection):
            uc.objects.unlink(c)
        col.objects.link(c)
        c.hide_render = True
        c.display_type = "WIRE"
    md = target.modifiers.new("bool", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.operand_type = "COLLECTION"
    md.collection = col
    md.solver = "EXACT"
    try:
        md.material_mode = "TRANSFER"
    except Exception:
        pass
    return target


_fonts = {}


def font(name):
    if name not in _fonts:
        _fonts[name] = bpy.data.fonts.load(os.path.join(HERE, "fonts", name))
    return _fonts[name]


def text_obj(txt, fontfile, size, depth, mat, origin, n, up=V(0, 1, 0), align="CENTER", res=3, spacing=1.0, bevel=0.0):
    """Real glyph lettering: `origin` is the middle of the baseline on the surface, n the way it faces. It reads left to right
    for someone looking at that face (local x -> up x n)."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = txt
    cu.font = font(fontfile)
    cu.size = size
    cu.extrude = depth * 0.5
    cu.resolution_u = res
    cu.align_x = align
    cu.align_y = "BOTTOM_BASELINE"
    cu.space_character = spacing
    cu.bevel_depth = bevel
    cu.fill_mode = "BOTH"
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(bmat(mat))
    n = Vector(n).normalized(); up = Vector(up).normalized()
    r = up.cross(n).normalized()
    up = n.cross(r).normalized()
    o = Vector(origin) + n * (depth * 0.5)
    M = Matrix((
        (G(r)[0], G(up)[0], G(n)[0], G(o)[0]),
        (G(r)[1], G(up)[1], G(n)[1], G(o)[1]),
        (G(r)[2], G(up)[2], G(n)[2], G(o)[2]),
        (0, 0, 0, 1)))
    ob.matrix_world = M
    return ob


def text_width(txt, fontfile, size):
    cu = bpy.data.curves.new("tw", "FONT"); cu.body = txt; cu.font = font(fontfile); cu.size = size
    ob = bpy.data.objects.new("tw", cu); bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    w = ob.dimensions.x
    bpy.data.objects.remove(ob); bpy.data.curves.remove(cu)
    return w


# ====================================================================== writing the scene and the .glb
def uv_for(p, n):
    """Metres: walls u along, v up; slopes u along the contour, v up the slope; flat faces x and z."""
    if abs(n.y) > 0.97:
        return (p.x, -p.z) if n.y > 0 else (p.x, p.z)
    t = V(n.z, 0, -n.x).normalized()
    b = n.cross(t)
    return (p.dot(t), p.dot(b))


def grime(mat, p, n, wall_h):
    """Weathering written into the vertex colour: damp at the base of walls, dirt under the eaves, slates darker and
    greener at the eaves. Returns a multiplier (r, g, b)."""
    y = p.y
    if mat in ("bld_brick", "bld_brick2", "bld_render", "bld_stone", "bld_timber", "bld_weatherboard", "bld_ashlar"):
        damp = 1.0 - 0.28 * math.exp(-max(y, 0.0) / 0.32)
        eave = 1.0 - 0.10 * max(0.0, min(1.0, (y - (wall_h - 0.5)) / 0.5)) if wall_h > 0 else 1.0
        f = damp * eave
        return (f, f * 0.99, f * 0.97)
    if mat in ("bld_slate", "bld_slate2", "bld_corrugated", "bld_corrugated_rust"):
        return (1.0, 1.0, 1.0)
    return (1.0, 1.0, 1.0)


def write_node(kit, acc, wall_h, parent):
    if not acc.faces:
        ob = bpy.data.objects.new(acc.name, None)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = parent
        ob.location = G(acc.pivot)
        return ob
    mats = []
    mi = {}
    for f in acc.faces:
        if f[1] not in mi:
            mi[f[1]] = len(mats); mats.append(f[1])
    me = bpy.data.meshes.new(acc.name)
    verts = [G(v - acc.pivot) for v in acc.verts]
    me.from_pydata(verts, [], [f[0] for f in acc.faces])
    for m in mats:
        me.materials.append(bmat(m))
    me.uv_layers.new(name="UVMap")
    me.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    # fetch both after both exist: adding a layer reallocates the others, leaving earlier references stale
    uvl = me.uv_layers["UVMap"]
    col = me.color_attributes["Col"]
    for poly, f in zip(me.polygons, acc.faces):
        poly.material_index = mi[f[1]]
        poly.use_smooth = bool(f[3])
        pts = [acc.verts[i] for i in f[0]]
        # Newell normal in game coords
        n = V(0, 0, 0)
        for k in range(len(pts)):
            a, b = pts[k], pts[(k + 1) % len(pts)]
            n += V((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
        n = n.normalized() if n.length > 1e-12 else V(0, 1, 0)
        tint = f[2]
        for k, li in enumerate(poly.loop_indices):
            p = pts[k]
            if f[4] is not None:
                uvl.data[li].uv = f[4][k]
            else:
                u, v = uv_for(p, n)
                uvl.data[li].uv = (u, v)
            g = grime(f[1], p, n, wall_h)
            if f[1].startswith("bld_"):
                # the bld_* materials read the vertex colour as linear
                col.data[li].color = (srgb_to_lin(tint[0]) * g[0], srgb_to_lin(tint[1]) * g[1], srgb_to_lin(tint[2]) * g[2], f[5])
            else:
                # the story kit's materials (enamel, chrome, cloth ...) read it as sRGB, as the code-made files write it
                col.data[li].color = (tint[0], tint[1], tint[2], f[5])
    me.color_attributes.active_color = col
    try:
        me.color_attributes.render_color_index = 0
    except Exception:
        pass
    # weld coincident corners so smooth faces (cylinders, spheres, pots) share normals; flat faces stay flat (sharp)
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me); bm.free()
    me.validate(clean_customdata=False)
    me.update()
    ob = bpy.data.objects.new(acc.name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = G(acc.pivot)
    return ob


def export(kit, path, wall_h=0.0):
    """Writes the kit's nodes (as scene roots) plus hullN-colonly boxes as a .glb."""
    # remove the scratch objects (boolean shells, cutters, text) before writing
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    # no wrapping empty: the nodes are the scene's roots, so Godot's importer makes them direct children of the scene
    # root (StoryAssets names it after the asset), as the code-made files have them (get_node("door") works)
    root = None
    order = ["body"] + [k for k in kit.nodes if k != "body"]
    for k in order:
        write_node(kit, kit.nodes[k], wall_h, root)
    for i, (c, s) in enumerate(kit.hulls):
        c = Vector(c); h = Vector(s) * 0.5
        vs = [c + V(sx * h.x, sy * h.y, sz * h.z) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        F = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
        me = bpy.data.meshes.new("hull%d" % i)
        me.from_pydata([G(v) for v in vs], [], F)
        bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new("hull%d-colonly" % i, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
    bpy.ops.object.select_all(action="SELECT")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
                              export_image_format="NONE", export_vertex_color="ACTIVE", export_normals=True,
                              export_texcoords=True, export_materials="EXPORT", export_tangents=False)
    tris = sum(a.tris_count() for a in kit.nodes.values())
    return tris
