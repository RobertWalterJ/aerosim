# lane/rennick: Constable Ada Rennick's uniform gear and her ghost, for the Blender people pipeline (people_lib.py).
#
# Gear (registered into people_gear.BUILDERS, used from people_roster.py "extras"):
#   uniform_cap     a peaked uniform cap: crown, band, patent peak, chinstrap and a badge carrying the fictional Halloway
#                   constabulary emblem (a lit lantern in a ring; no lettering, no crown, nothing of a real force)
#   duty_belt       a duty belt with buckle, radio (1984: a big handset with a long whip aerial in a leather holster;
#                   modern: a compact radio), a torch in a ring holder and pouches. No weapon, no cuffs, no baton.
#   shoulder_radio  the modern speaker-mic on the left chest with its cord to the belt radio
# Fictional emblem painter for fabric patches (emblem_patch) and the cap badge.
# Ghost: ghostify() turns every material of a built character into a drained, pale, faintly cool version with a soft
#   self-glow, for the separate file rennick_1984_ghost.glb (same body, face, uniform and rig).
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector, Matrix
import people_lib as L
import people_gear as G

NAVY = (0.10, 0.12, 0.22)
SILVER = (0.80, 0.81, 0.83)
GOLD = (0.78, 0.62, 0.28)

# ------------------------------------------------------------------------------------------------ the fictional emblem
def emblem(h, w, field=NAVY, ring=SILVER, lamp=GOLD, outer=None):
    """The Halloway constabulary mark, drawn in code: a ring around a lit lantern on a plain field. RGB h x w (top row
    first). outer: the colour outside the disc (defaults to the field)."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u = (xs + 0.5) / w * 2 - 1
    v = 1 - (ys + 0.5) / h * 2               # +1 at the top
    s = min(h, w) / max(h, w)
    if w > h: u = u / s
    else: v = v / s
    r = np.hypot(u, v)
    out = np.empty((h, w, 3), np.float32)
    out[:] = outer if outer is not None else field
    out[r < 0.92] = field
    out[(r > 0.74) & (r < 0.86)] = ring
    out[(r > 0.66) & (r < 0.70)] = ring
    # small studs on the ring (eight, no lettering)
    for k in range(8):
        a = k / 8 * math.tau + math.pi / 8
        out[np.hypot(u - math.cos(a) * 0.80, v - math.sin(a) * 0.80) < 0.035] = field
    # the lantern: cap, glass, base, handle loop
    body = (np.abs(u) < 0.20 - (v - 0.1) * 0.08) & (v > -0.28) & (v < 0.24)
    glass = (np.abs(u) < 0.12 - (v - 0.1) * 0.05) & (v > -0.18) & (v < 0.16)
    capt = (v >= 0.24) & (v < 0.40) & (np.abs(u) < (0.40 - v) * 1.4)
    base = (v <= -0.28) & (v > -0.38) & (np.abs(u) < 0.25)
    loop = (np.abs(np.hypot(u, v - 0.45) - 0.08) < 0.025) & (v > 0.40)
    out[body | capt | base | loop] = lamp
    out[glass] = (1.0, 0.92, 0.62)
    out[glass & (np.abs(u) < 0.025)] = lamp                # the glazing bar
    # rays
    for a in (0.0, 0.5, -0.5, 1.0, -1.0):
        d = np.array([math.sin(a), math.cos(a)])
        t = u * d[0] + (v - 0.0) * d[1]
        perp = np.abs(u * d[1] - (v - 0.0) * d[0])
        if abs(a) < 0.1:
            continue
        out[(perp < 0.022) & (t > 0.30) & (t < 0.52) & (v > 0.0)] = lamp
    return np.clip(out, 0, 1)

def emblem_patch(field=NAVY, outer=NAVY):
    return lambda h, w: emblem(h, w, field=field, outer=outer)

# UV rectangles (0..1 from the top-left of the source image) painted over on a garment's texture: the EMT jacket's
# logo panel (a real organisation's name and red cross) becomes the fictional lantern emblem on the jacket's navy.
def solid(col):
    return lambda h, w: np.broadcast_to(np.array(col, np.float32), (h, w, 3)).copy()

PATCHES = {
    "emblem_jacket": [(0.565, 0.58, 0.985, 0.99, emblem_patch(field=(0.07, 0.09, 0.18), outer=(0.06, 0.075, 0.14)))],
    # toigo_female_suit_2: the floral tie and pocket square become a plain dark uniform tie and a plain pocket
    "suit2_tie": [(0.835, 0.02, 0.935, 0.275, solid((0.035, 0.035, 0.05))),
                  (0.82, 0.43, 0.91, 0.48, solid((0.065, 0.075, 0.14)))],
}

def emblem_tex(key, metal_col, field, size=256, metallic=True, outer=None):
    """Badge texture: the emblem in enamel and metal. ORM marks the metal parts metallic."""
    os.makedirs(L.TEXCACHE, exist_ok=True)
    out = {k: os.path.join(L.TEXCACHE, f"{key}_{k}.jpg") for k in ("diff", "nor", "orm")}
    img = emblem(size, size, field=field, ring=metal_col, lamp=metal_col, outer=metal_col if outer is None else outer)[::-1]
    metal = (np.abs(img - np.array(field, np.float32)).sum(-1) > 0.08).astype(np.float32)
    diff = np.concatenate([img, np.ones((size, size, 1), np.float32)], -1)
    n = np.ones((size, size, 4), np.float32); n[..., :3] = (0.5, 0.5, 1.0)
    orm = np.ones((size, size, 4), np.float32); orm[..., 1] = (0.45 - 0.2 * metal) if metallic else 0.75; orm[..., 2] = 0.95 * metal if metallic else 0.0
    L.save_px(diff, out["diff"], quality=92); L.save_px(n, out["nor"]); L.save_px(orm, out["orm"])
    return out

# ------------------------------------------------------------------------------------------------ helpers
def _head_frame(p):
    ez = p.eyes.matrix_world.translation.z + float(L.coords(p.eyes)[:, 2].mean())
    zb = ez + 0.05
    pts = np.array([p.proxy.matrix_world @ v.co for v in p.proxy.data.vertices])
    sel = pts[(np.abs(pts[:, 2] - zb) < 0.012) & (np.abs(pts[:, 0]) < 0.12) & (pts[:, 1] < pts[:, 1].mean() + 0.2)]
    cy = float((sel[:, 1].min() + sel[:, 1].max()) / 2)
    rx = float(np.abs(sel[:, 0]).max()) + 0.016
    ry = float((sel[:, 1].max() - sel[:, 1].min()) / 2) + 0.016
    return zb, cy, rx, ry

def _solid(o, t, offset=1.0):
    s = o.modifiers.new("s", "SOLIDIFY"); s.thickness = t; s.offset = offset
    L.apply_modifier(o, "s")

def _cyl(bm, a, b, r, segs=12, r2=None):
    """A capped cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=d.length)
    q = d.normalized().to_track_quat("Z", "Y")
    bmesh.ops.rotate(bm, verts=res["verts"], cent=Vector(), matrix=q.to_matrix())
    bmesh.ops.translate(bm, vec=(a + b) / 2, verts=res["verts"])
    return res["verts"]

def _planar_uv(o, axis_u=0, axis_v=2):
    """UVs from two world axes over the object's bounding box (badges: the emblem faces forward)."""
    me = o.data
    if not me.uv_layers:
        me.uv_layers.new()
    co = np.array([o.matrix_world @ v.co for v in me.vertices])
    lo, hi = co.min(0), co.max(0)
    uvl = me.uv_layers.active.data
    for pl in me.polygons:
        for li in pl.loop_indices:
            c = co[me.loops[li].vertex_index]
            uvl[li].uv = ((c[axis_u] - lo[axis_u]) / max(hi[axis_u] - lo[axis_u], 1e-6),
                          (c[axis_v] - lo[axis_v]) / max(hi[axis_v] - lo[axis_v], 1e-6))

# ------------------------------------------------------------------------------------------------ peaked uniform cap
def uniform_cap(p, spec):
    style = spec.get("cap_style", "1984")
    col = spec.get("cap_color", NAVY)
    band_col = spec.get("cap_band", (0.03, 0.03, 0.035))
    zb, cy, rx, ry = _head_frame(p)
    z0 = zb - 0.018
    tilt = Matrix.Rotation(math.radians(-6), 3, "X")
    piv = Vector((0, cy, zb))
    n = 22
    def pt(a, k, dz, raise_=0.0):
        r = raise_ * max(math.cos(a), 0.0) ** 1.5
        return Vector((math.sin(a) * rx * k, cy - math.cos(a) * ry * k, z0 + dz + r))
    def finish(bm, name):
        bmesh.ops.rotate(bm, verts=list(bm.verts), cent=piv, matrix=tilt)
        return G.new_obj(name, bm)
    # crown: from inside the band up to a broad top, raised at the front
    prof = [(0.036, 1.0, 0.0), (0.046, 1.035, 0.0), (0.064, 1.14, 0.006), (0.080, 1.22, 0.014),
            (0.090, 1.245, 0.018), (0.097, 1.23, 0.02), (0.1015, 1.17, 0.02)]
    bm = bmesh.new()
    rings = [[bm.verts.new(pt(i / n * math.tau, k, dz, ra)) for i in range(n)] for dz, k, ra in prof]
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    top = bm.verts.new((0, cy - ry * 0.12, z0 + 0.105))
    for i in range(n):
        bm.faces.new((rings[-1][i], rings[-1][(i + 1) % n], top))
    crown = finish(bm, "cap_crown")
    # band
    bm = bmesh.new()
    rings = [[bm.verts.new(pt(i / n * math.tau, 1.012, dz)) for i in range(n)] for dz in (0.0, 0.022, 0.044)]
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    band = finish(bm, "cap_band")
    # peak: three rows, drooping toward the tip
    m = 11
    bm = bmesh.new()
    rows = []
    for t in (0.0, 0.5, 1.0):
        row = []
        for i in range(m):
            a = -math.pi * 0.43 + i / (m - 1) * math.pi * 0.86
            c = max(math.cos(a), 0.0)
            reach = 0.064 * c ** 0.6 * t
            drop = (0.012 * t + 0.016 * t * t) * c
            base = pt(a, 1.02, 0.001)
            row.append(bm.verts.new(base + Vector((math.sin(a) * reach * 0.25, -reach, -drop))))
        rows.append(row)
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(m - 1):
            bm.faces.new((r0[i], r0[i + 1], r1[i + 1], r1[i]))
    peak = finish(bm, "cap_peak")
    _solid(peak, 0.0035, 0.0)
    # chinstrap across the front of the band, with a small button at each end
    bm = bmesh.new()
    rows = [[bm.verts.new(pt(-math.pi * 0.42 + i / 9 * math.pi * 0.84, 1.03, dz)) for i in range(10)] for dz in (0.006, 0.016)]
    for i in range(9):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    for s in (-1, 1):
        a = s * math.pi * 0.43
        c = pt(a, 1.03, 0.011)
        nrm = Vector((math.sin(a), -math.cos(a), 0))
        _cyl(bm, c, c + nrm * 0.004, 0.0055, 6)
    strap = finish(bm, "cap_strap")
    _solid(strap, 0.0015)
    # badge on the crown front: a shield-shaped plate following the crown's curve
    k_at = 1.11
    bw, bh = 0.036, 0.042
    zc = z0 + 0.060 + 0.006
    bm = bmesh.new()
    gx, gz = 7, 8
    grid = {}
    for j in range(gz):
        for i in range(gx):
            u = (i / (gx - 1)) * 2 - 1
            vv = (j / (gz - 1)) * 2 - 1
            # shield outline: straight top, rounded to a point at the bottom
            half = 1.0 if vv > -0.2 else max(0.0, math.sqrt(max(0.0, 1 - ((vv + 0.2) / 0.8) ** 2)))
            x = u * half * bw / 2
            z = zc + vv * bh / 2
            ell = max(0.0, 1 - (x / (rx * k_at)) ** 2)
            y = cy - ry * k_at * math.sqrt(ell) - 0.003 - 0.016 * max(0.0, (z - (z0 + 0.05)) / 0.04)
            grid[i, j] = bm.verts.new((x, y, z))
    for j in range(gz - 1):
        for i in range(gx - 1):
            q = (grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1])
            if len({tuple(round(c, 6) for c in v.co) for v in q}) >= 3:
                try:
                    bm.faces.new(q)
                except ValueError:
                    pass
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    badge = finish(bm, "cap_badge")
    _planar_uv(badge, 0, 2)
    for ob in (crown, band, peak, strap):
        G.uv_box(ob)
    for ob in (crown, band, peak, strap, badge):
        G.rigid(ob, {"head": 1.0})
    nm = spec["name"]
    metal = GOLD if style == "1984" else SILVER
    out = [(crown, G.tex(nm + "_capcrown", col, "caban", tile=2, detail=0.45), "clothes"),
           (band, G.tex(nm + "_capband", band_col, "stretch_poplin", tile=3, detail=0.5, rough=0.7), "clothes"),
           (peak, G.flat_tex(nm + "_cappeak", (0.015, 0.015, 0.018), rough=0.16), "clothes"),
           (strap, G.flat_tex(nm + "_capstrap", metal if style == "1984" else (0.02, 0.02, 0.022), rough=0.3 if style == "1984" else 0.35,
                              metal=0.9 if style == "1984" else 0.0), "clothes"),
           (badge, emblem_tex(nm + "_capbadge", metal, (0.08, 0.12, 0.30)), "clothes")]
    return out

# ------------------------------------------------------------------------------------------------ duty belt
def duty_belt(p, spec):
    style = spec.get("cap_style", "1984")
    hips = G.bone_head(p, "pelvis")
    z = hips.z + spec.get("belt_dz", 0.04)
    c, radii = G.ring(p, z)
    n = len(radii)
    hh = 0.026 if style == "1984" else 0.028
    bm = bmesh.new()
    rows = [[bm.verts.new(G.ring_point(c, radii, -math.pi + i / n * math.tau, 0.008) + Vector((0, 0, dz))) for i in range(n)] for dz in (-hh, hh)]
    for i in range(n):
        bm.faces.new((rows[0][i], rows[0][(i + 1) % n], rows[1][(i + 1) % n], rows[1][i]))
    belt = G.new_obj("belt", bm)
    _solid(belt, 0.006)
    def on(a, depth, extra=0.0):
        return G.ring_point(c, radii, a, 0.014 + depth / 2 + extra)
    # pouches and holders (leather 1984 / ballistic nylon modern)
    bm = bmesh.new()
    pouches = [(2.75, (0.11, 0.035, 0.075), -0.012), (-2.55, (0.06, 0.03, 0.07), -0.018), (2.2, (0.055, 0.03, 0.08), -0.02)]
    rad_a = -0.95 if style == "1984" else 0.95
    torch_a = 1.75 if style == "1984" else -1.75
    if style == "1984":
        pouches.append((rad_a, (0.085, 0.055, 0.12), -0.045))                       # radio holster
    else:
        pouches.append((rad_a, (0.066, 0.042, 0.085), -0.03))
    for a, size, dz in pouches:
        q = on(a, size[1])
        G.box(bm, (q.x, q.y, z + dz), size, yaw=-a)
    # torch ring holder
    q = on(torch_a, 0.03)
    G.box(bm, (q.x, q.y, z - 0.005), (0.03, 0.03, 0.03), yaw=-torch_a)
    kit = G.bevelled("belt_pouches", bm, 0.005, 1)
    leather = L.join([belt, kit], "belt_leather")
    # buckle
    bm = bmesh.new()
    q = on(0.0, 0.01)
    G.box(bm, (q.x, q.y, z), (0.072 if style == "1984" else 0.06, 0.012, 0.058 if style == "1984" else 0.05))
    buckle = G.bevelled("buckle", bm, 0.004, 1)
    # radio
    bm = bmesh.new()
    if style == "1984":
        q = on(rad_a, 0.05, 0.004)
        G.box(bm, (q.x, q.y, z + 0.02), (0.072, 0.045, 0.17), yaw=-rad_a)            # the handset, higher than the holster
        top = Vector((q.x, q.y, z + 0.105))
        _cyl(bm, top + Vector((0.018, 0, 0)), top + Vector((0.018, 0, 0.19)), 0.004, 6, 0.0025)   # whip aerial
        _cyl(bm, top + Vector((-0.02, 0, 0)), top + Vector((-0.02, 0, 0.018)), 0.008, 6)        # channel knob
    else:
        q = on(rad_a, 0.038, 0.004)
        G.box(bm, (q.x, q.y, z + 0.02), (0.056, 0.034, 0.11), yaw=-rad_a)
        top = Vector((q.x, q.y, z + 0.075))
        _cyl(bm, top + Vector((0.012, 0, 0)), top + Vector((0.012, 0, 0.075)), 0.006, 6, 0.005)
        _cyl(bm, top + Vector((-0.014, 0, 0)), top + Vector((-0.014, 0, 0.014)), 0.007, 6)
    radio = G.bevelled("radio", bm, 0.004, 1)
    # torch (hangs head-up through the ring)
    bm = bmesh.new()
    q = on(torch_a, 0.03, 0.002)
    if style == "1984":
        _cyl(bm, (q.x, q.y, z - 0.17), (q.x, q.y, z + 0.04), 0.017, 10)
        _cyl(bm, (q.x, q.y, z + 0.04), (q.x, q.y, z + 0.10), 0.019, 10, 0.026)
    else:
        _cyl(bm, (q.x, q.y, z - 0.10), (q.x, q.y, z + 0.03), 0.0135, 12)
        _cyl(bm, (q.x, q.y, z + 0.03), (q.x, q.y, z + 0.065), 0.015, 12, 0.018)
    torch = G.new_obj("torch", bm)
    for ob in (leather, buckle, radio, torch):
        G.uv_box(ob)
        G.rigid(ob, {"pelvis": 1.0})
    nm = spec["name"]
    if style == "1984":
        tl = G.tex(nm + "_dutybelt", (0.035, 0.032, 0.03), "brown_leather", tile=6, detail=0.35, rough=0.32)
        tb = G.flat_tex(nm + "_buckle", GOLD, rough=0.3, metal=1.0)
        tt = G.flat_tex(nm + "_torch", (0.05, 0.05, 0.055), rough=0.35, metal=0.8)
    else:
        tl = G.tex(nm + "_dutybelt", (0.03, 0.03, 0.032), "terlenka", tile=8, detail=0.5, rough=0.8)
        tb = G.flat_tex(nm + "_buckle", (0.04, 0.04, 0.045), rough=0.45, metal=0.2)
        tt = G.flat_tex(nm + "_torch", (0.06, 0.06, 0.065), rough=0.4, metal=0.7)
    tr = G.flat_tex(nm + "_radio", (0.03, 0.03, 0.033), rough=0.55)
    return [(leather, tl, "clothes"), (buckle, tb, "clothes"), (radio, tr, "clothes"), (torch, tt, "clothes")]

# ------------------------------------------------------------------------------------------------ modern speaker-mic
def shoulder_radio(p, spec):
    sh = G.bone_head(p, "upperarm_l")
    zc = sh.z - 0.10
    c, radii = G.ring(p, zc)
    q = G.ring_point(c, radii, 0.55, 0.016)
    bm = bmesh.new()
    G.box(bm, (q.x, q.y, zc), (0.048, 0.022, 0.064), yaw=-0.55)
    mic = G.bevelled("speaker_mic", bm, 0.006, 1)
    hips = G.bone_head(p, "pelvis")
    zb = hips.z + spec.get("belt_dz", 0.04)
    c2, r2 = G.ring(p, zb + 0.08)
    c3, r3 = G.ring(p, zb + 0.25)
    cord = G.strap("mic_cord", [q + Vector((0.006, 0.004, -0.03)), G.ring_point(c3, r3, 0.75, 0.012),
                                G.ring_point(c2, r2, 0.9, 0.02)], 0.007, 0.007)
    obj = L.join([mic, cord], "shoulder_radio")
    G.uv_box(obj)
    zs = sh.z - 0.2
    G.rigid(obj, lambda co: {"spine_03": 1.0} if co.z > zs else ({"spine_02": 0.6, "spine_03": 0.4} if co.z > zb + 0.15 else {"spine_01": 0.5, "pelvis": 0.5}))
    return [(obj, G.flat_tex(spec["name"] + "_mic", (0.03, 0.03, 0.033), rough=0.5), "clothes")]

# ------------------------------------------------------------------------------------------------ shoulder flashes
def shoulder_flash(p, spec):
    """The embroidered constabulary flash on each upper sleeve: a curved patch following the sleeve, the lantern emblem."""
    from mathutils.bvhtree import BVHTree
    verts, polys = [], []
    for o, g in p.clothes:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        polys.extend(tuple(base + i for i in pl.vertices) for pl in o.data.polygons)
    bvh = BVHTree.FromPolygons(verts, polys)
    out = []
    for side in ("l", "r"):
        sh = G.bone_head(p, "upperarm_" + side)
        el = G.bone_head(p, "lowerarm_" + side)
        ax = (el - sh).normalized()
        lat = Vector((1 if side == "l" else -1, 0, 0))
        o = (lat - ax * lat.dot(ax)).normalized()
        c = sh + ax * 0.085
        hit = bvh.ray_cast(c + o * 0.25, -o, 0.3)
        R = ((hit[0] - c).dot(o) if hit[0] is not None else 0.055) + 0.0025
        bm = bmesh.new()
        nu, nv, w, h = 6, 6, 0.075, 0.085
        grid = {}
        for j in range(nv):
            for i in range(nu):
                ang = ((i / (nu - 1)) - 0.5) * w / R
                d = Matrix.Rotation(ang * (1 if side == "l" else -1), 3, ax) @ o
                grid[i, j] = bm.verts.new(c + ax * (((j / (nv - 1)) - 0.5) * -h) + d * R)
        for j in range(nv - 1):
            for i in range(nu - 1):
                bm.faces.new((grid[i, j], grid[i + 1, j], grid[i + 1, j + 1], grid[i, j + 1]))
        ob = G.new_obj("flash_" + side, bm)
        me = ob.data
        me.uv_layers.new()
        uvl = me.uv_layers.active.data
        idx = {j * nu + i: (i, j) for j in range(nv) for i in range(nu)}   # creation order
        for pl in me.polygons:
            for li in pl.loop_indices:
                i, j = idx[me.loops[li].vertex_index]
                uvl[li].uv = (i / (nu - 1) if side == "l" else 1 - i / (nu - 1), 1 - j / (nv - 1))
        G.rigid(ob, {"upperarm_" + side: 1.0})
        out.append((ob, emblem_tex(spec["name"] + "_flash", (0.82, 0.83, 0.85), (0.06, 0.08, 0.17), metallic=False, outer=(0.055, 0.07, 0.13)), "clothes"))
    return out

G.BUILDERS.update({"uniform_cap": uniform_cap, "duty_belt": duty_belt, "shoulder_radio": shoulder_radio,
                   "shoulder_flash": shoulder_flash})

# ------------------------------------------------------------------------------------------------ the ghost
COOL = np.array((0.915, 0.95, 1.0), np.float32)

def ghost_pixels(px, kind):
    """Drain a texture to a pale, faintly cool grey-white that keeps its own tonal structure (features, folds, seams):
    the face still reads as hers, the uniform still reads as a uniform."""
    rgb = px[..., :3]
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    if kind == "eye":
        v = 0.36 + 0.52 * np.sqrt(np.clip(lum, 0, 1))        # irises stay mid grey: no blank or glowing eyes
    else:
        v = 0.55 + 0.37 * np.sqrt(np.clip(lum, 0, 1))
        if kind == "skin":
            ok = px[..., 3] > 0.5 if px.shape[-1] > 3 else np.ones(lum.shape, bool)
            med = float(np.median(lum[ok])) if ok.any() else 0.3
            v = v * (1 + np.clip(lum / max(med, 1e-3) - 1, -0.6, 0.6) * 0.16)   # keep lips, brows and lids legible
    out = px.copy()
    out[..., :3] = np.clip(v[..., None] * COOL[None, None, :], 0, 1)
    return out

def ghostify(objs, key, glow=0.22):
    """Swap every base-colour image on these objects' materials for its ghost version (cached in texcache as
    <key>_ghost_<image>), and feed the same image to emission at a low strength: a soft self-light, not a glow."""
    done = set()
    for o in objs:
        for slot in o.material_slots:
            m = slot.material
            if m is None or m.name in done:
                continue
            done.add(m.name)
            nt = m.node_tree
            bsdf = nt.nodes.get("Principled BSDF")
            if bsdf is None:
                continue
            kind = m.name.split(".")[0]
            src = None
            for l in nt.links:
                if l.to_node == bsdf and l.to_socket.name == "Base Color" and l.from_node.type == "TEX_IMAGE":
                    src = l.from_node
            if src is None:
                col = bsdf.inputs["Base Color"].default_value
                arr = np.array([[[col[0], col[1], col[2], 1.0]]], np.float32)
                g = ghost_pixels(arr, kind)[0, 0]
                bsdf.inputs["Base Color"].default_value = (*g[:3], 1)
                continue
            img = src.image
            w, h = img.size
            a = np.empty(w * h * 4, np.float32)
            img.pixels.foreach_get(a)
            a = ghost_pixels(a.reshape(h, w, 4), kind)
            fmt = "PNG" if img.filepath_raw.lower().endswith(".png") else "JPEG"
            path = os.path.join(L.TEXCACHE, f"{key}_ghost_{os.path.basename(img.filepath_raw)}")
            L.save_px(a, path, fmt=fmt, quality=90)
            src.image = bpy.data.images.load(path, check_existing=False)
            nt.links.new(src.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = glow
