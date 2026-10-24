# Gear modelled in Blender for the people, fitted to each body: a hiking backpack with straps (Wren), a peaked uniform cap
# and a duty belt with radio pouch and torch holder (no weapons, no cuffs), and a knitted scarf for the crowd.
# build(name, person, spec) -> [(object, textures, node)]; weights are rigid to one or two bones (MPFB names; the
# pipeline renames them to Godot humanoid names afterwards).
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix
import people_lib as L

def bone_head(p, name):
    return p.rig.matrix_world @ p.rig.data.bones[name].head_local

def body_points(p, include_clothes=True):
    pts = [p.proxy.matrix_world @ v.co for v in p.proxy.data.vertices]
    if include_clothes:
        for o, g in p.clothes:
            pts.extend(o.matrix_world @ v.co for v in o.data.vertices)
    return np.array(pts)

def ring(p, z, cy=None, bins=32, band=0.02, include_clothes=True, xmax=0.21):
    """Outline of the body (and clothes) at height z: (centre, radii per angle). Angle 0 is the front (-Y), +a is the left."""
    P = body_points(p, include_clothes)
    sel = P[np.abs(P[:, 2] - z) < band]
    if xmax is not None:
        sel = sel[np.abs(sel[:, 0]) < xmax]
    cx = 0.0
    cy = float((sel[:, 1].min() + sel[:, 1].max()) / 2) if cy is None else cy
    ang = np.arctan2(sel[:, 0] - cx, -(sel[:, 1] - cy))
    r = np.hypot(sel[:, 0] - cx, sel[:, 1] - cy)
    radii = np.zeros(bins)
    for i in range(bins):
        a0 = -math.pi + i * math.tau / bins
        m = (ang >= a0) & (ang < a0 + math.tau / bins)
        radii[i] = r[m].max() if m.any() else 0
    for _ in range(3):
        for i in range(bins):
            if radii[i] == 0:
                radii[i] = max(radii[(i - 1) % bins], radii[(i + 1) % bins])
    return Vector((cx, cy, z)), radii

def ring_point(c, radii, a, extra=0.0):
    bins = len(radii)
    f = ((a + math.pi) / math.tau) * bins - 0.5
    i0 = int(math.floor(f)) % bins
    t = f - math.floor(f)
    r = radii[i0] * (1 - t) + radii[(i0 + 1) % bins] * t + extra
    return Vector((c.x + math.sin(a) * r, c.y - math.cos(a) * r, c.z))

def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    L.link(o)
    return o

def uv_box(o):
    L.select_only([o])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

def rigid(o, groups):
    """Weight every vertex to bones: groups = {bone: weight} or a function(co) -> {bone: weight}."""
    for v in o.data.vertices:
        w = groups(o.matrix_world @ v.co) if callable(groups) else groups
        for b, x in w.items():
            g = o.vertex_groups.get(b) or o.vertex_groups.new(name=b)
            g.add([v.index], x, "REPLACE")

def tex(key, tint, fabric_name, tile=4, detail=0.6, rough=None, size=512):
    """Diffuse/normal/ORM from a photographed fabric, tinted; cached like garment textures."""
    os.makedirs(L.TEXCACHE, exist_ok=True)
    out = {k: os.path.join(L.TEXCACHE, f"{key}_{k}.jpg") for k in ("diff", "nor", "orm")}
    if all(os.path.exists(v) for v in out.values()) and not os.environ.get("PEOPLE_RETEX"):
        return out
    fd, fn, fr = L.fabric(fabric_name, 512)
    fd = L.tile(fd, tile, size); fn = L.tile(fn, tile, size); fr = L.tile(fr, tile, size)
    fl = fd[..., :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    det = fl / max(float(fl.mean()), 1e-3)
    rgb = np.array(tint, np.float32)[None, None, :] * (1 - detail + detail * det[..., None])
    diff = np.concatenate([np.clip(rgb, 0, 1), np.ones_like(rgb[..., :1])], -1)
    r = fr[..., 0] if rough is None else np.full(fr.shape[:2], rough, np.float32)
    orm = np.stack([np.ones_like(r), r, np.zeros_like(r), np.ones_like(r)], -1)
    L.save_px(diff, out["diff"]); L.save_px(fn, out["nor"], quality=90); L.save_px(orm, out["orm"])
    return out

def flat_tex(key, color, rough=0.5, metal=0.0, size=64):
    os.makedirs(L.TEXCACHE, exist_ok=True)
    out = {k: os.path.join(L.TEXCACHE, f"{key}_{k}.jpg") for k in ("diff", "nor", "orm")}
    a = np.ones((size, size, 4), np.float32); a[..., :3] = color
    n = np.ones((size, size, 4), np.float32); n[..., :3] = (0.5, 0.5, 1.0)
    o = np.ones((size, size, 4), np.float32); o[..., 1] = rough; o[..., 2] = metal
    L.save_px(a, out["diff"]); L.save_px(n, out["nor"]); L.save_px(o, out["orm"])
    return out

def box(bm, centre, size, yaw=0.0):
    res = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=res["verts"])
    if yaw:
        bmesh.ops.rotate(bm, verts=res["verts"], cent=Vector(), matrix=Matrix.Rotation(yaw, 3, "Z"))
    bmesh.ops.translate(bm, vec=Vector(centre), verts=res["verts"])
    return res["verts"]

def bevelled(name, bm, width=0.008, segs=2):
    o = new_obj(name, bm)
    bv = o.modifiers.new("b", "BEVEL"); bv.width = width; bv.segments = segs; bv.limit_method = "ANGLE"
    L.apply_modifier(o, "b")
    return o

def strap(name, pts, width=0.05, thick=0.008):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, q in zip(sp.bezier_points, pts):
        bp.co = q
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    cu.resolution_u = 5
    rect = bpy.data.curves.new(name + "_rect", "CURVE"); rect.dimensions = "2D"
    rs = rect.splines.new("POLY"); rs.points.add(3)
    for pt, (a, b) in zip(rs.points, ((-width / 2, -thick / 2), (width / 2, -thick / 2), (width / 2, thick / 2), (-width / 2, thick / 2))):
        pt.co = (a, b, 0, 1)
    rs.use_cyclic_u = True
    ro = bpy.data.objects.new(name + "_rect", rect); L.link(ro)
    cu.bevel_mode = "OBJECT"; cu.bevel_object = ro; cu.use_fill_caps = True
    ob = bpy.data.objects.new(name, cu); L.link(ob)
    L.select_only([ob])
    bpy.ops.object.convert(target="MESH")
    st = bpy.context.view_layer.objects.active
    bpy.data.objects.remove(ro, do_unlink=True)
    return st

# ------------------------------------------------------------------------------------------------ backpack
def backpack(p, spec):
    col = spec.get("pack_color", (0.30, 0.13, 0.07))
    sh_l, sh_r = bone_head(p, "upperarm_l"), bone_head(p, "upperarm_r")
    top_z = sh_l.z - 0.03
    c_back, rad_back = ring(p, top_z - 0.2)
    back_y = ring_point(c_back, rad_back, math.pi).y
    w, h, d = 0.31, 0.48, 0.17
    centre = Vector((0, back_y + d / 2 + 0.012, top_z - h / 2 + 0.02))
    bm = bmesh.new()
    res = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((w, d, h)), verts=res["verts"])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        nx, ny, nz = x / (w / 2), y / (d / 2), z / (h / 2)
        v.co.x *= 1.0 - 0.10 * (abs(nz) ** 3) - 0.06 * (abs(ny) ** 3)
        v.co.z *= 1.0 - 0.04 * (abs(nx) ** 3)
        if y > 0:
            v.co.y *= 1.0 + 0.3 * (1 - nx * nx) * (1 - nz * nz)
        v.co += centre
    box(bm, centre + Vector((0, 0.012, h / 2 + 0.02)), (w * 0.95, d * 1.08, 0.06))                       # lid
    box(bm, centre + Vector((w / 2 + 0.025, 0.0, -h * 0.2)), (0.05, d * 0.62, h * 0.40))                  # side pocket
    box(bm, centre + Vector((0, d / 2 + 0.04, -h * 0.17)), (w * 0.68, 0.05, h * 0.36))                    # front pocket
    pack = bevelled("pack", bm, 0.012, 2)
    straps = []
    for side, sh, S in ((1, sh_l, "l"), (-1, sh_r, "r")):
        top = Vector((side * 0.075, back_y + 0.02, top_z - 0.01))
        c_sh, r_sh = ring(p, sh.z + 0.02, xmax=0.16)
        over = Vector((side * 0.10, c_sh.y - 0.005, sh.z + 0.075))
        c1, r1 = ring(p, sh.z - 0.07)
        front1 = ring_point(c1, r1, side * 0.40, 0.01)
        c2, r2 = ring(p, sh.z - 0.24)
        front2 = ring_point(c2, r2, side * 0.62, 0.01)
        side2 = ring_point(c2, r2, side * 1.50, 0.012)
        bottom = Vector((side * 0.12, back_y + 0.03, centre.z - h * 0.42))
        st = strap("strap_" + S, [top, over, front1, front2, side2, bottom])
        straps.append(st)
    c3, r3 = ring(p, sh_l.z - 0.17)
    chest_l, chest_r = ring_point(c3, r3, 0.48, 0.02), ring_point(c3, r3, -0.48, 0.02)
    straps.append(strap("sternum", [chest_r, (chest_l + chest_r) / 2 + Vector((0, -0.01, 0)), chest_l], 0.02, 0.005))
    obj = L.join([pack] + straps, "backpack")
    uv_box(obj)
    zs = sh_l.z
    rigid(obj, lambda co: ({"spine_03": 0.6, "clavicle_l": 0.4} if co.x > 0.05 else {"spine_03": 0.6, "clavicle_r": 0.4}) if co.z > zs - 0.06 else
          ({"spine_03": 0.8, "spine_02": 0.2} if co.z > zs - 0.3 else {"spine_02": 0.7, "spine_01": 0.3}))
    t = tex(spec["name"] + "_pack", col, "terlenka", tile=3, detail=0.5)
    return [(obj, t, "backpack")]

# ------------------------------------------------------------------------------------------------ peaked cap
def peaked_cap(p, spec):
    col = spec.get("cap_color", (0.05, 0.06, 0.1))
    ez = p.eyes.matrix_world.translation.z + float(L.coords(p.eyes)[:, 2].mean())
    zb = ez + 0.05
    pts = np.array([p.proxy.matrix_world @ v.co for v in p.proxy.data.vertices])
    sel = pts[(np.abs(pts[:, 2] - zb) < 0.012) & (np.abs(pts[:, 0]) < 0.12) & (pts[:, 1] < pts[:, 1].mean() + 0.2)]
    cy = float((sel[:, 1].min() + sel[:, 1].max()) / 2)
    rx = float(np.abs(sel[:, 0]).max()) + 0.014
    ry = float((sel[:, 1].max() - sel[:, 1].min()) / 2) + 0.014
    tilt = math.radians(-7)
    bm = bmesh.new()
    n = 28
    rings = []
    prof = [(0.0, 1.0), (0.045, 1.0), (0.05, 1.02), (0.085, 1.17), (0.097, 1.19), (0.104, 1.13)]
    for (dz, k) in prof:
        rings.append([bm.verts.new((math.sin(i / n * math.tau) * rx * k, cy - math.cos(i / n * math.tau) * ry * k, zb - 0.014 + dz)) for i in range(n)])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    ctr = bm.verts.new((0, cy, zb - 0.014 + 0.108))
    for i in range(n):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], ctr))
    m = 11
    inner, outer = [], []
    for i in range(m):
        a = -math.pi * 0.45 + i / (m - 1) * math.pi * 0.9
        inner.append(bm.verts.new((math.sin(a) * rx, cy - math.cos(a) * ry, zb - 0.014)))
        reach = 0.065 * max(math.cos(a), 0) ** 0.6
        outer.append(bm.verts.new((math.sin(a) * (rx + 0.008), cy - math.cos(a) * ry - reach, zb - 0.014 - 0.028 * max(math.cos(a), 0))))
    for i in range(m - 1):
        bm.faces.new((inner[i], inner[i + 1], outer[i + 1], outer[i]))
    bmesh.ops.rotate(bm, verts=list(bm.verts), cent=Vector((0, cy, zb)), matrix=Matrix.Rotation(tilt, 3, "X"))
    o = new_obj("peaked_cap", bm)
    sol = o.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.004; sol.offset = 1.0
    L.apply_modifier(o, "s")
    bm2 = bmesh.new()
    bmesh.ops.create_circle(bm2, cap_ends=True, segments=12, radius=0.013)
    for v in bm2.verts:
        v.co = Vector((v.co.x, 0, v.co.y * 1.3))
    bmesh.ops.translate(bm2, vec=Vector((0, cy - ry - 0.006, zb + 0.022)), verts=bm2.verts[:])
    bmesh.ops.rotate(bm2, verts=bm2.verts[:], cent=Vector((0, cy, zb)), matrix=Matrix.Rotation(tilt, 3, "X"))
    b = new_obj("badge", bm2)
    sol = b.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.003
    L.apply_modifier(b, "s")
    for ob in (o, b):
        uv_box(ob)
        rigid(ob, {"head": 1.0})
    t = tex(spec["name"] + "_peakcap", col, "poly_wool_herringbone", tile=2, detail=0.35)
    tb = flat_tex(spec["name"] + "_badge", (0.72, 0.73, 0.75), rough=0.3, metal=1.0)
    return [(o, t, "clothes"), (b, tb, "clothes")]

# ------------------------------------------------------------------------------------------------ duty belt
def belt_kit(p, spec):
    hips = bone_head(p, "pelvis")
    z = hips.z + spec.get("belt_dz", 0.04)
    c, radii = ring(p, z)
    n = len(radii) * 2
    bm = bmesh.new()
    rows = []
    for dz in (-0.024, 0.024):
        rows.append([bm.verts.new(ring_point(c, radii, -math.pi + i / n * math.tau, 0.006) + Vector((0, 0, dz))) for i in range(n)])
    for i in range(n):
        bm.faces.new((rows[0][i], rows[0][(i + 1) % n], rows[1][(i + 1) % n], rows[1][i]))
    belt = new_obj("belt", bm)
    sol = belt.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.006; sol.offset = 1.0
    L.apply_modifier(belt, "s")
    bm = bmesh.new()
    for a, size, dz in ((0.8, (0.07, 0.045, 0.11), -0.025), (-0.95, (0.045, 0.045, 0.15), -0.035),
                        (2.7, (0.11, 0.035, 0.08), -0.01), (0.0, (0.065, 0.014, 0.05), 0.0)):
        q = ring_point(c, radii, a, 0.012 + size[1] / 2)
        box(bm, (q.x, q.y, z + dz), size, yaw=-a)
    parts = bevelled("pouches", bm, 0.006, 2)
    obj = L.join([belt, parts], "belt_kit")
    uv_box(obj)
    rigid(obj, {"pelvis": 1.0})
    t = tex(spec["name"] + "_belt", (0.05, 0.05, 0.055), "brown_leather", tile=6, detail=0.4)
    return [(obj, t, "clothes")]

# ------------------------------------------------------------------------------------------------ scarf
def scarf(p, spec):
    col = spec.get("scarf_color", (0.55, 0.12, 0.1))
    nk = bone_head(p, "neck_01")
    z = nk.z - 0.01
    c, radii = ring(p, z, xmax=0.12)
    n = 24
    bm = bmesh.new()
    rows = []
    for dz, ex in ((-0.035, 0.02), (0.0, 0.034), (0.035, 0.016)):
        rows.append([bm.verts.new(ring_point(c, radii, -math.pi + i / n * math.tau, ex) + Vector((0, 0, dz))) for i in range(n)])
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    loop = new_obj("scarf_loop", bm)
    sol = loop.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.012; sol.offset = 0.0
    L.apply_modifier(loop, "s")
    c2, r2 = ring(p, z - 0.26)
    top = ring_point(c, radii, 0.35, 0.035)
    bot = ring_point(c2, r2, 0.3, 0.02)
    bm = bmesh.new()
    vs = []
    for i in range(7):
        t = i / 6
        q = top.lerp(bot, t)
        vs.append((bm.verts.new(q + Vector((-0.045, 0, 0))), bm.verts.new(q + Vector((0.045, 0, 0)))))
    for i in range(6):
        bm.faces.new((vs[i][0], vs[i][1], vs[i + 1][1], vs[i + 1][0]))
    tail = new_obj("scarf_tail", bm)
    sol = tail.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.01
    L.apply_modifier(tail, "s")
    obj = L.join([loop, tail], "scarf")
    uv_box(obj)
    rigid(obj, lambda co: {"neck_01": 0.5, "spine_03": 0.5} if co.z > z - 0.06 else {"spine_03": 1.0})
    t = tex(spec["name"] + "_scarf", col, "knitted_fleece", tile=3, detail=0.6)
    return [(obj, t, "clothes")]

BUILDERS = {"backpack": backpack, "peaked_cap": peaked_cap, "belt_kit": belt_kit, "scarf": scarf}

def build(extra, p, spec):
    out = BUILDERS[extra](p, spec)
    for o, t, node in out:
        for pl in o.data.polygons:
            pl.use_smooth = True
    return out
