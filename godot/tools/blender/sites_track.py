# The old way to the cabin (godot/docs/CLAUDE-CABIN-TRACK-ASSETS.md on lane/notify): a worn 3.4 m dirt and gravel track,
# fallen trees and rockfalls across it, and the cave in the outcrop west of the cabin. Real proportions: a car-width
# two-rut forest track (wheel gauge about 1.55 m), a mature broadleaf windthrow with its root plate torn up (root plates of
# shallow-rooted broadleaves on thin soil are typically 2-3 m across and 0.4-0.6 m deep), a smaller beech fall, boulder
# rockfalls of the kind that come off a weathered outcrop, and a low cave mouth about a person and a half high.
# Game frame: metres, x right, y up, z forward (the track runs along z; the trees lie across it along x); origin at the base.
import math, random
from mathutils import Vector as V, Matrix
import bmesh
import sites_lib as L
from sites_lib import box, cyl, sweep, loft, grid, disc_patch, rock, torus, sphere, text_mesh, Asset, mix, smooth, fbm

GAUGE = 0.78


# ======================================================================================================== the track
def track_y(x, z):
    """the track's cross section: two ruts 50 mm down, a slight hump in the middle, the edges sunk into the ground"""
    y = 0.03 + 0.012 * math.exp(-(x / 0.3) ** 2)
    for s in (-1, 1):
        y -= 0.05 * math.exp(-((x - s * GAUGE) / 0.13) ** 2)
    y += 0.008 * fbm((x, 0, z), 1.3, 2, 2.0)
    y -= 0.09 * smooth(1.9, 2.2, abs(x))
    return y


def track_dirt_strip():
    a = Asset("track_dirt_strip", ao_strength=0.0, lod1=0.5, buried_ok=0.1,
              colour=lambda co, n, m, nd, t: (1.0, 1.0, 1.0),
              meta={"width": 4.4, "core_width": 3.4, "length": 12.0, "uv": "u 0..1 across 4.4 m (ruts at u 0.32 and 0.68), "
                    "v = metres along / 8 (the texture tiles every 8 m)", "material": "site_track (SiteAssets.track_material())",
                    "note": "a straight 12 m segment that chains end to end; for the real route build a ribbon with the same "
                            "UVs and section (track_y in sites_track.py), edges sunk 6 cm so the ground cuts a ragged edge"})
    s = a.node("track_dirt_strip")
    xs = [-2.2 + 0.2 * i for i in range(23)]
    zs = [0.5 * i for i in range(25)]
    s.add(grid(xs, zs, track_y), "site_track", uv=lambda co, n: ((co.x + 2.2) / 4.4, co.z / 8.0), recalc=False)
    return a


def track_rut_pair():
    a = Asset("track_rut_pair", ao_strength=0.0, lod1=0.0, buried_ok=0.1,
              colour=lambda co, n, m, nd, t: mix((1, 1, 1), (0.72, 0.7, 0.66), max(0.0, fbm(co, 0.8, 2, 4.0)) * 0.8),
              meta={"width": 0.34, "gauge": 2 * GAUGE, "length": 12.0,
                    "note": "two wet ruts to lay over the strip (same frame as track_dirt_strip); their edges dip below the "
                            "strip so the join is ragged; material site_mud (darker, glossier dirt)"})
    for s, nm in ((-1, "track_rut_l"), (1, "track_rut_r")):
        m = a.node(nm)
        rnd = random.Random(7 + s)
        jit = [rnd.uniform(-0.03, 0.03) for _ in range(25)]
        b = bmesh.new()
        rows = []
        for k in range(25):
            z = 0.5 * k
            row = []
            for j, u in enumerate((-0.17, -0.08, 0.0, 0.08, 0.17)):
                x = s * GAUGE + u + (jit[k] if abs(u) > 0.1 else 0.0)
                y = track_y(x, z) + (0.006 if abs(u) < 0.1 else -0.012)
                row.append(b.verts.new((x, y, z)))
            rows.append(row)
        for k in range(24):
            for j in range(4):
                f = b.faces.new((rows[k][j], rows[k + 1][j], rows[k + 1][j + 1], rows[k][j + 1]))
                if f.normal.y < 0:
                    f.normal_flip()
        m.add(b, "site_mud", grain=(0, 0, 1), recalc=False)
    return a


# ======================================================================================================== trees
def bark_rfn(seed, depth=0.06, flare=None):
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 6.28) for _ in range(4)]
    def f(i, j, ang):
        r = 1.0 + depth * (math.sin(ang * 7 + ph[0] + i * 0.3) * 0.6 + math.sin(ang * 13 + ph[1]) * 0.4)
        if flare:
            r *= flare(i, ang)
        return r
    return f


def splinter_end(mesh, centre, axis, radius, seed, mat="site_wood_fresh", n=9, length=0.35):
    """a snapped end: a ring of jagged splinters of pale fresh wood (instead of a clean cap)"""
    rnd = random.Random(seed)
    ax = V(axis).normalized()
    a = V((1, 0, 0)) if abs(ax.x) < 0.9 else V((0, 1, 0))
    s = ax.cross(a).normalized(); t = ax.cross(s)
    b = bmesh.new()
    c = V(centre)
    ring = []
    for k in range(n):
        ang = k / n * math.tau
        ring.append(b.verts.new(c + (s * math.cos(ang) + t * math.sin(ang)) * radius * 0.98))
    tips = []
    for k in range(n):
        ang = (k + 0.5) / n * math.tau
        L_ = rnd.uniform(0.15, 1.0) * length
        rr = radius * rnd.uniform(0.2, 0.75)
        tips.append(b.verts.new(c + ax * L_ + (s * math.cos(ang) + t * math.sin(ang)) * rr))
    mid = b.verts.new(c + ax * length * 0.25)
    for k in range(n):
        b.faces.new((ring[k], ring[(k + 1) % n], tips[k]))
        b.faces.new((ring[(k + 1) % n], mid, tips[k]))
        b.faces.new((ring[k], tips[k], mid))
    bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
    mesh.add(b, mat)


def limb(mesh, pts, r0, r1, seed, mat="site_bark_oak", seg=7, end="snap", tile=1.0):
    n = len(pts)
    rad = [r0 + (r1 - r0) * (i / (n - 1)) for i in range(n)]
    mesh.add(sweep(pts, rad, seg, caps=(end != "snap"), rfn=bark_rfn(seed, 0.05)), mat, grain=V(pts[-1]) - V(pts[0]), uv='cyl',
             tile=tile, smooth=True)
    if end == "snap":
        splinter_end(mesh, pts[-1], V(pts[-1]) - V(pts[-2]), rad[-1], seed + 5, n=6, length=rad[-1] * 3.0)
    return rad


def leaf_cards(mesh, centres, size, seed, n_per=2):
    """crossed leaf cards (the beech twig atlas, one quarter per card): the dry leaves still on the fallen crown"""
    rnd = random.Random(seed)
    for c in centres:
        for k in range(n_per):
            q = rnd.randrange(4)
            u0, v0 = (q % 2) * 0.5, (q // 2) * 0.5
            yaw = rnd.uniform(0, math.pi)
            tilt = rnd.uniform(-0.6, 0.6)
            d = V((math.cos(yaw), 0, math.sin(yaw)))
            up = V((0, math.cos(tilt), 0)) + V((-math.sin(yaw), 0, math.cos(yaw))) * math.sin(tilt)
            s = size * rnd.uniform(0.75, 1.2)
            b = bmesh.new()
            cc = V(c)
            ps = [cc - d * s / 2, cc + d * s / 2, cc + d * s / 2 + up * s, cc - d * s / 2 + up * s]
            vs = [b.verts.new(p) for p in ps]
            f = b.faces.new(vs)
            uvl = b.loops.layers.uv.new("UVMap")
            for l, (uu, vv) in zip(f.loops, ((0, 1), (1, 1), (1, 0), (0, 0))):
                l[uvl].uv = (u0 + uu * 0.5, 1 - (v0 + vv * 0.5))
            mesh.add(b, "site_leaves", keep_uv=True, recalc=False)


def tree_colour(co, n, mat, node, tag):
    m = 0.92 + 0.12 * fbm(co, 1.2, 3, 3.0)
    c = (m, m, m)
    if mat in ("site_bark_oak", "site_bark_beech"):
        c = mix(c, (0.7, 0.85, 0.55), max(0.0, n.y) * max(0.0, fbm(co, 1.6, 2, 5.0) + 0.1) * 0.8)    # moss and algae on top
        c = mix(c, (0.62, 0.55, 0.45), smooth(0.25, 0.0, co.y) * 0.5)                               # soil splash low down
    if mat == "site_wood_fresh":
        c = (0.95, 0.9, 0.85)
    if mat == "site_dirt":
        c = mix(c, (0.42, 0.37, 0.32), 0.85)
    if mat == "site_leaves":
        c = (1.0, 1.0, 1.0)
    if mat == "site_soil" and node.endswith("_roots") and co.y > 0.2:
        c = mix(c, (0.55, 0.5, 0.45), 0.7)         # the torn underside of the root plate: dark wet earth
    return c


def root_plate(a, nm, centre, radius, thick, facing, seed, n_roots=14, bark="site_bark_oak"):
    """a torn-up root plate: a lumpy disc of soil and stones standing near upright, roots radiating and snapped at the rim"""
    rp = a.node(nm)
    rnd = random.Random(seed)
    c = V(centre)
    f = V(facing).normalized()
    b = bmesh.new()
    bmesh.ops.create_icosphere(b, subdivisions=3, radius=1.0)
    s1 = f.cross(V((0, 1, 0))).normalized()
    up = s1.cross(f).normalized()
    off = rnd.uniform(0, 50)
    for v in b.verts:
        p = v.co.copy()
        nrm = 1.0 + 0.3 * L.noise.fractal(p * 1.6 + V((off, 0, 0)), 0.6, 2.0, 3)
        v.co = c + (f * p.x * thick * 0.5 + s1 * p.y * radius + up * p.z * radius) * nrm
    rp.add(b, "site_soil", smooth=True)
    # stones caught in the soil of the exposed underside
    for k in range(7):
        ang = rnd.uniform(0, math.tau); rr = rnd.uniform(0.2, 0.85) * radius
        p = c + (s1 * math.cos(ang) + up * math.sin(ang)) * rr - f * thick * 0.45
        sz = rnd.uniform(0.08, 0.2)
        rp.add(rock((sz * 1.2, sz, sz), p - V((0, sz * 0.5, 0)), seed=seed * 10 + k, subdiv=1, cuts=4, embed=0.0, flat_base=False),
               "site_rock")
    # roots: tapering tubes from the plate, out past the rim, broken, some drooping
    for k in range(n_roots):
        ang = k / n_roots * math.tau + rnd.uniform(-0.2, 0.2)
        d = s1 * math.cos(ang) + up * math.sin(ang)
        start = c - f * thick * 0.3 + d * radius * rnd.uniform(0.15, 0.45)
        L_ = radius * rnd.uniform(0.75, 1.25)
        pts = []
        for i in range(5):
            t = i / 4
            p = start + d * L_ * t - f * (0.25 * t + rnd.uniform(-0.06, 0.06)) + V((0, -0.35 * t * t, 0))
            p.y = max(p.y, -0.12 - 0.02 * i)      # roots that reach the ground bury their tips a little, no deeper
            pts.append(p)
        r0 = rnd.uniform(0.035, 0.075)
        rp.add(sweep(pts, [r0 * (1 - 0.8 * i / 4) + 0.006 for i in range(5)], 5, caps=True, rfn=bark_rfn(seed + k, 0.15)), bark,
               grain=d, uv='cyl', smooth=True)
    return rp


def _end_cap(mesh, pp, rr, sgn, seg=12):
    """a sawn face across the trunk (x axis) at point pp, radius rr, facing sgn * x"""
    b = bmesh.new()
    ring = [b.verts.new(pp + V((0, math.cos(k / seg * math.tau) * rr, math.sin(k / seg * math.tau) * rr))) for k in range(seg)]
    f_ = b.faces.new(ring)
    b.normal_update()
    if f_.normal.x * sgn < 0:
        f_.normal_flip()
    mesh.add(b, "site_wood_end", uv=lambda co, n, pp=pp, rr=rr: ((co.z - pp.z) / (rr * 2.4) + 0.5, (co.y - pp.y) / (rr * 2.4) + 0.5),
             recalc=False)


def tree_fall_a(cut=False):
    name = "tree_fall_cut" if cut else "tree_fall_a"
    a = Asset(name, colour=tree_colour, ao_dist=0.6, lod1=0.45, buried_ok=0.3,
              meta={"length": 8.4, "lies": "across the track along x, roots at -x", "note":
                    ("the same oak sawn through either side of the track and the middle log rolled off the way: "
                     "someone cleared it once") if cut else "a mature oak blown down across the track: lifted root plate, "
                                                             "snapped crown, a few dry leaves still on the twigs"},
              probes=[{"node": name + "_roots", "axis": "x", "side": -1}])
    trunk = a.node(name + "_trunk")
    branches = a.node(name + "_branches")
    rnd = random.Random(11)
    def ry(x):
        return 0.31 - 0.08 * (x + 3.55) / 6.45
    def hy(x):
        return max(ry(x), 0.5 - 0.27 * smooth(-3.5, 0.8, x) + 0.12 * smooth(1.6, 2.9, x))
    path = [V((x, hy(x), 0.08 * math.sin((x + 3.55) / 6.45 * 2.5))) for x in [-3.55 + 6.45 * i / 11 for i in range(12)]]
    radii = [ry(p.x) * (1.0 + 0.32 * math.exp(-((p.x + 3.55) / 0.5) ** 2)) for p in path]
    def flare(i, ang):
        return 1.0 + 0.12 * math.exp(-i / 1.2) * abs(math.sin(ang * 2.5))
    if not cut:
        trunk.add(sweep(path, radii, 12, caps=True, rfn=bark_rfn(3, 0.06, flare)), "site_bark_oak", grain=(1, 0, 0), uv='cyl', smooth=True)
    else:
        # sawn at x -1.15 and +1.25; the middle log lies off the track at z +2.7
        for (x0, x1) in ((-4.0, -1.15), (1.25, 3.0)):
            idx = [i for i, p in enumerate(path) if x0 <= p.x <= x1]
            pts = [path[i] for i in idx]
            rs = [radii[i] for i in idx]
            if x0 > -4:
                pts.insert(0, V((x0, hy(x0), 0.08 * math.sin((x0 + 3.55) / 6.45 * 2.5)))); rs.insert(0, ry(x0))
            if x1 < 3:
                pts.append(V((x1, hy(x1), 0.08 * math.sin((x1 + 3.55) / 6.45 * 2.5)))); rs.append(ry(x1))
            trunk.add(sweep(pts, rs, 12, caps=False, rfn=bark_rfn(3, 0.06, flare if x0 < -3 else None)), "site_bark_oak",
                      grain=(1, 0, 0), uv='cyl', smooth=True)
            _end_cap(trunk, pts[0], rs[0], -1)
            _end_cap(trunk, pts[-1], rs[-1], 1)
        r = ry(0.0)
        lp = [V((-0.95 + 0.4 * i, r, 2.7 + 0.05 * i)) for i in range(6)]
        trunk.add(sweep(lp, r, 12, caps=False, rfn=bark_rfn(5, 0.06)), "site_bark_oak", grain=(1, 0, 0), uv='cyl', smooth=True)
        _end_cap(trunk, lp[0], r, -1)
        _end_cap(trunk, lp[-1], r, 1)
        for xc in (-1.15, 1.25):
            pat = disc_patch(0.45, 0.35, 0.1, edge_sink=0.01, seed=int(xc * 10) + 50, top=0.012, wobble=0.25)
            bmesh.ops.translate(pat, vec=V((xc, 0, 0.1)), verts=pat.verts)
            branches.add(pat, "site_wood_fresh", recalc=False)
    # the crown: three limbs off the fork; one snapped short, one runs on and down into the ground, one up to the side
    fork = path[-1]
    rf = radii[-1]
    limb(branches, [fork, fork + V((0.35, 0.18, -0.12)), fork + V((0.7, 0.35, -0.28))], rf * 0.8, rf * 0.62, 21)
    limb(branches, [fork, fork + V((0.6, -0.05, 0.25)), fork + V((1.2, -0.2, 0.5)), fork + V((1.75, -0.48, 0.65))],
         rf * 0.75, rf * 0.35, 22, end="snap")
    side = [fork, fork + V((0.3, 0.3, -0.5)), fork + V((0.5, 0.7, -1.0)), fork + V((0.55, 1.1, -1.5))]
    limb(branches, side, rf * 0.65, rf * 0.3, 23)
    twig_tips = []
    for k in range(9):
        base = side[1 + k % 3] if k < 5 else fork + V((0.4 + 0.2 * k, 0.1, 0.3 - 0.1 * k))
        d = V((rnd.uniform(0.2, 1.0), rnd.uniform(-0.6, 0.9), rnd.uniform(-1.0, 1.0))).normalized()
        L1 = rnd.uniform(0.7, 1.4)
        pts = [base, base + d * L1 * 0.5 + V((0, 0.08, 0)), base + d * L1]
        if pts[-1].y < -0.05:
            pts[-1].y = -0.05
        branches.add(sweep(pts, [0.05, 0.035, 0.012], 5, caps=True), "site_bark_oak", grain=d, uv='cyl', smooth=True)
        twig_tips.append(pts[-1])
        for j in range(2):
            d2 = (d + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.3, 0.6), rnd.uniform(-0.6, 0.6)))).normalized()
            q = pts[1] + d2 * rnd.uniform(0.3, 0.6)
            q.y = max(q.y, -0.03)
            branches.add(sweep([pts[1], (pts[1] + q) / 2, q], [0.022, 0.014, 0.006], 4, caps=True), "site_bark_oak", grain=d2, uv='cyl')
            twig_tips.append(q)
    leaf_cards(branches, [t + V((0, -0.15, 0)) for t in twig_tips if t.y > 0.25][:9], 0.55, 31, n_per=1)
    # the root plate stands at the -x end, the torn pit behind it
    root_plate(a, name + "_roots", (-3.8, 1.1, 0.0), 1.2, 0.75, (1, 0.05, 0), 41, n_roots=22)
    pit = disc_patch(1.3, 1.25, 0.25, edge_sink=0.04, seed=4, top=0.05,
                     yfn=lambda x, z: 0.12 * math.exp(-((math.hypot(x, z) - 0.9) / 0.3) ** 2) - 0.05 * math.exp(-(math.hypot(x, z) / 0.6) ** 2))
    bmesh.ops.translate(pit, vec=V((-4.55, 0, 0)), verts=pit.verts)
    a.nodes[name + "_roots"][0].add(pit, "site_soil", recalc=False)
    return a


def tree_fall_b():
    a = Asset("tree_fall_b", colour=tree_colour, ao_dist=0.5, lod1=0.45, buried_ok=0.25,
              meta={"length": 7.0, "lies": "diagonally across the track (about 22 degrees off x), roots at -x",
                    "note": "a smaller beech, smooth grey bark, shallow root plate, branches across the ruts"},
              probes=[{"node": "tree_fall_b_roots", "axis": "x", "side": -1}])
    trunk = a.node("tree_fall_b_trunk")
    br = a.node("tree_fall_b_branches")
    rnd = random.Random(17)
    d = V((math.cos(math.radians(22)), 0, math.sin(math.radians(22))))
    start = V((-3.0, 0, -1.2))
    path, radii = [], []
    for i in range(10):
        t = i / 9
        p = start + d * (6.2 * t)
        r = 0.16 - 0.09 * t
        p.y = max(r, 0.34 - 0.2 * smooth(0.0, 0.5, t) + 0.1 * smooth(0.75, 1.0, t))
        path.append(p)
        radii.append(r * (1.0 + 0.25 * math.exp(-(t / 0.06))))
    trunk.add(sweep(path, radii, 10, caps=False, rfn=bark_rfn(8, 0.02)), "site_bark_beech", grain=d, uv='cyl', smooth=True)
    splinter_end(trunk, path[-1], path[-1] - path[-2], radii[-1], 9, length=0.25)
    b = bmesh.new()
    sd = d.cross(V((0, 1, 0))).normalized()
    ring = [b.verts.new(path[0] + (V((0, math.cos(k / 10 * math.tau), 0)) + sd * math.sin(k / 10 * math.tau)) * radii[0]) for k in range(10)]
    b.faces.new(ring)
    trunk.add(b, "site_bark_beech")
    tips = []
    for k in range(10):
        t = 0.35 + 0.065 * k
        base = start + d * (6.2 * t)
        base.y = path[min(9, int(t * 9))].y
        sgn = 1 if k % 2 else -1
        up = rnd.uniform(-0.2, 1.0)
        dd = (d * rnd.uniform(0.3, 0.9) + sd * sgn * rnd.uniform(0.4, 1.0) + V((0, up, 0))).normalized()
        L1 = rnd.uniform(0.9, 1.8)
        p2 = base + dd * L1
        p2.y = max(p2.y, -0.04)
        pts = [base, base + dd * L1 * 0.5 + V((0, 0.06, 0)), p2]
        br.add(sweep(pts, [0.045, 0.03, 0.01], 5), "site_bark_beech", grain=dd, uv='cyl', smooth=True)
        tips.append(p2)
        q = pts[1] + (dd + V((0, 0.4, 0))).normalized() * 0.5
        br.add(sweep([pts[1], q], [0.015, 0.006], 4), "site_bark_beech", grain=dd, uv='cyl')
        tips.append(q)
    leaf_cards(br, [t for t in tips if t.y > 0.3][:10], 0.5, 32, n_per=1)
    root_plate(a, "tree_fall_b_roots", start + V((0, 0.62, 0.0)) - d * 0.14, 0.68, 0.3, d, 51, n_roots=10, bark="site_bark_beech")
    return a


# ======================================================================================================== rocks
def rock_colour(co, n, mat, node, tag):
    m = 0.9 + 0.14 * fbm(co, 0.9, 3, 1.0)
    c = (m * 0.97, m * 0.98, m)
    c = mix(c, (0.72, 0.8, 0.6), max(0.0, fbm(co, 2.5, 2, 4.0) - 0.25) * 0.9)          # lichen
    c = mix(c, (0.6, 0.58, 0.52), smooth(0.25, -0.05, co.y) * 0.6)                    # damp and soil at the base
    if mat == "site_soil":
        c = (1, 1, 1)
    if mat == "site_dirt":
        c = mix((1, 1, 1), (0.7, 0.66, 0.6), smooth(2.0, 0.6, co.z) * 0.6)
    return c


def moss_fn(seed, amount=0.55):
    def f(c, n):
        return "site_rock_moss" if (n.y > amount and fbm(c, 1.2, 2, seed) > -0.15) else "site_rock"
    return f


def rockfall(name, stones, litter, seed, moss=0.6):
    a = Asset(name, colour=rock_colour, ao_dist=0.5, lod1=0.4, buried_ok=0.2,
              meta={"note": "boulders over the track; separate named boulder nodes and a leaf-litter patch with chips"})
    for i, (size, c, layered) in enumerate(stones):
        b = a.node("%s_boulder_%d" % (name, i))
        b.add(rock(size, c, seed=seed + i, subdiv=3, cuts=13, rough=0.07, depth=(0.42, 0.75), blocky=0.35 if i % 2 else 0.0, embed=0.1, layered=layered, rot_y=seed * 0.37 + i),
              "site_rock", mat_fn=moss_fn(seed + i, moss))
    lt = a.node(name + "_litter")
    rx, rz, cx, cz = litter
    pat = disc_patch(rx, rz, 0.3, edge_sink=0.04, seed=seed, top=0.03, wobble=0.25,
                     yfn=lambda x, z: 0.03 * fbm((x, 0, z), 1.5, 2, 2.0))
    bmesh.ops.translate(pat, vec=V((cx, 0, cz)), verts=pat.verts)
    lt.add(pat, "site_soil", recalc=False)
    rnd = random.Random(seed + 99)
    for k in range(12):
        x = cx + rnd.uniform(-rx, rx) * 0.9; z = cz + rnd.uniform(-rz, rz) * 0.9; s = rnd.uniform(0.05, 0.16)
        lt.add(rock((s * 1.3, s, s * 1.1), (x, 0, z), seed=seed * 7 + k, subdiv=1, cuts=4, embed=s * 0.25), "site_rock")
    return a


def rockfall_a():
    return rockfall("rockfall_a", [((1.55, 1.15, 1.35), (0.0, 0, 0.0), 0.35), ((0.9, 0.7, 0.8), (-1.25, 0, 0.55), 0.0),
                                   ((0.75, 0.55, 0.85), (1.15, 0, -0.45), 0.0), ((0.6, 0.45, 0.55), (0.7, 0, 0.95), 0.0),
                                   ((0.55, 0.5, 0.6), (-0.8, 0, -0.9), 0.0), ((0.45, 0.35, 0.4), (1.7, 0, 0.5), 0.0),
                                   ((0.4, 0.3, 0.45), (-1.75, 0, -0.3), 0.0)], (2.2, 1.7, 0.0, 0.0), 300)


def rockfall_b():
    return rockfall("rockfall_b", [((0.95, 0.75, 0.85), (0.0, 0, 0.0), 0.0), ((0.6, 0.45, 0.55), (-0.85, 0, 0.35), 0.0),
                                   ((0.5, 0.4, 0.45), (0.75, 0, -0.35), 0.0), ((0.4, 0.3, 0.35), (0.4, 0, 0.7), 0.0)],
                    (1.5, 1.2, 0.0, 0.1), 400, moss=0.35)


def dead_branch_scatter():
    a = Asset("dead_branch_scatter", colour=tree_colour, ao_dist=0.25, lod1=0.5,
              meta={"spread": [3.0, 2.0], "note": "snapped branches and twigs lying on the ground"})
    b = a.node("dead_branch_scatter")
    rnd = random.Random(61)
    for k in range(11):
        c = V((rnd.uniform(-1.4, 1.4), 0.0, rnd.uniform(-0.9, 0.9)))
        ang = rnd.uniform(0, math.pi)
        d = V((math.cos(ang), 0, math.sin(ang)))
        L1 = rnd.uniform(0.6, 1.7)
        r = rnd.uniform(0.015, 0.045)
        pts = [c - d * L1 / 2 + V((0, r * 0.8, 0)), c + V((0, r * 0.9 + 0.01, 0)), c + d * L1 / 2 + V((0, r * 0.6, 0))]
        b.add(sweep(pts, [r, r * 0.8, r * 0.5], 5), "site_bark_oak", grain=d, uv='cyl', smooth=True)
        if rnd.random() < 0.7:
            d2 = (d + V((0, rnd.uniform(0.2, 0.6), 0)) + V((-d.z, 0, d.x)) * rnd.choice((-1, 1)) * 0.8).normalized()
            q = pts[1] + d2 * L1 * 0.35
            b.add(sweep([pts[1], q], [r * 0.6, r * 0.25], 4), "site_bark_oak", grain=d2, uv='cyl')
    return a


# ======================================================================================================== the cave
# The outcrop faces +z (toward the cabin). Origin: the middle of the cave mouth, on the ground at the face line.
OUTCROP_BLOCKS = [  # size, centre (base), layered
    ((2.9, 2.2, 3.1), (-2.4, 0.0, -0.2), 0.45), ((2.5, 1.9, 2.7), (-2.15, 1.75, -0.8), 0.45), ((1.7, 1.1, 1.9), (-2.7, 3.2, -1.1), 0.4),
    ((2.8, 2.4, 3.0), (2.35, 0.0, -0.3), 0.45), ((2.3, 1.7, 2.5), (2.45, 2.0, -0.9), 0.45),
    ((3.8, 1.4, 2.7), (0.05, 2.6, -0.85), 0.4),
    ((7.6, 3.6, 2.6), (0.0, 0.0, -2.9), 0.5),
    ((2.6, 0.9, 2.1), (-0.9, 3.6, -1.9), 0.0), ((2.2, 0.8, 1.9), (1.5, 3.3, -2.0), 0.0),
]


def outcrop_mesh(mesh):
    for i, (size, c, lay) in enumerate(OUTCROP_BLOCKS):
        mesh.add(rock(size, c, seed=700 + i, subdiv=3, cuts=11, rough=0.05, depth=(0.45, 0.8), blocky=0.75, embed=0.12 if c[1] == 0 else 0.0, layered=lay,
                      flat_base=c[1] == 0, rot_y=0.15 * (i % 3 - 1)), "site_rock", mat_fn=moss_fn(700 + i, 0.7), tag=i)


def cave_tunnel(mesh):
    """the black mouth: an irregular arch 2.2 m wide and 2.8 m tall, run 3 m into the rock and closed at the back.
    Faces point inward (seen from the front)."""
    rnd = random.Random(9)
    prof = []
    n = 16
    for k in range(1, n):
        t = k / n
        ang = math.pi * t
        x = -math.cos(ang) * 1.1
        y = 0.05 + math.sin(ang) ** 0.75 * 2.75
        prof.append((x + rnd.uniform(-0.05, 0.05), y + rnd.uniform(-0.06, 0.06)))
    prof = [(-1.08, -0.08)] + prof + [(1.08, -0.08)]
    rings = []
    for j, z in enumerate((0.55, 0.1, -0.6, -1.4, -2.3)):
        sh = 1.0 - 0.18 * j
        rings.append([(x * sh + 0.05 * j, y * sh - 0.08 * (1 - sh), z) for (x, y) in prof])
    b = loft(rings, close_ring=False)
    for j in range(len(rings) - 1):
        r0, r1 = rings[j], rings[j + 1]
        vs = [b.verts.new(r0[0]), b.verts.new(r0[-1]), b.verts.new(r1[-1]), b.verts.new(r1[0])]
        b.faces.new(vs)
    back = [b.verts.new(p) for p in rings[-1]]
    b.faces.new(back)
    b.normal_update()
    for f in b.faces:
        c = f.calc_center_median()
        if abs(f.normal.z) > 0.7:
            if f.normal.z < 0:
                f.normal_flip()
        elif f.normal.dot(V((0 - c.x, 1.2 - c.y, 0))) < 0:
            f.normal_flip()
    mesh.add(b, "site_cave_dark", recalc=False)


def cave_colour(co, n, mat, node, tag):
    c = rock_colour(co, n, mat, node, tag)
    d = math.hypot(co.x / 1.6, (co.y - 1.4) / 2.0)
    c = mix(c, (c[0] * 0.55, c[1] * 0.56, c[2] * 0.55), max(0.0, 1.0 - d) * 0.7 * smooth(-1.5, 0.5, co.z))
    return c


def cave_outcrop():
    a = Asset("cave_outcrop", colour=cave_colour, ao_dist=0.9, lod1=0.45, buried_ok=0.2,
              meta={"width": 7.6, "height": 4.4, "mouth": {"width": 2.2, "height": 2.8, "centre": [0.0, 1.4, 0.3]},
                    "origin": "the middle of the cave mouth, on the ground at the face", "front": "+z (toward the cabin)",
                    "note": "cave_mouth is its own node with material site_cave_dark (unshaded black). Place cave_boulder_arch, "
                            "cave_apron, cave_fallen_slab, cave_scree, cave_damp_stain and cave_chalk_mark with the SAME transform"},
              probes=[{"node": "cave_mouth", "mat": "site_cave_dark", "dir": [0, 0, 1]}])
    outcrop_mesh(a.node("cave_outcrop"))
    cave_tunnel(a.node("cave_mouth"))
    return a


def cave_boulder_arch():
    a = Asset("cave_boulder_arch", colour=cave_colour, ao_dist=0.6, lod1=0.45, buried_ok=0.2,
              meta={"note": "four boulders framing the mouth: two jambs, a lintel stone and a chock stone; same origin as "
                            "cave_outcrop"})
    for i, (size, c, lay) in enumerate((((1.0, 2.3, 1.1), (-1.55, 0.0, 0.55), 0.5), ((1.1, 2.5, 1.15), (1.6, 0.0, 0.45), 0.5),
                                        ((3.3, 0.85, 1.2), (0.05, 2.08, 0.45), 0.0), ((0.75, 0.6, 0.7), (-1.15, 0.0, 1.1), 0.0))):
        b = a.node("cave_boulder_%d" % i)
        b.add(rock(size, c, seed=800 + i, subdiv=3, cuts=12, rough=0.06, depth=(0.45, 0.78), blocky=0.5, embed=0.1 if c[1] == 0 else 0.0, layered=lay,
                   flat_base=c[1] == 0), "site_rock", mat_fn=moss_fn(800 + i, 0.6))
    return a


def cave_apron():
    a = Asset("cave_apron", colour=rock_colour, ao_strength=0.4, ao_dist=0.3, lod1=0.5, buried_ok=0.1,
              meta={"size": [8.0, 7.0], "note": "bare dirt and stone in front of the mouth (same origin as cave_outcrop; it "
                                                "reaches 7 m toward +z); no grass"})
    g = a.node("cave_apron")
    pat = disc_patch(4.0, 3.5, 0.35, edge_sink=0.05, seed=12, top=0.03, wobble=0.18,
                     yfn=lambda x, z: 0.04 * fbm((x, 0, z), 0.8, 2, 3.0))
    bmesh.ops.translate(pat, vec=V((0, 0, 3.2)), verts=pat.verts)
    g.add(pat, "site_dirt", recalc=False)
    rnd = random.Random(13)
    for k in range(22):
        x = rnd.uniform(-3.4, 3.4); z = rnd.uniform(0.3, 6.2); s = rnd.uniform(0.05, 0.22)
        g.add(rock((s * 1.3, s * 0.7, s * 1.1), (x, 0, z), seed=900 + k, subdiv=1, cuts=4, embed=s * 0.3), "site_rock")
    return a


def cave_warning_board(blank=False):
    name = "cave_warning_board" + ("_blank" if blank else "")
    def col(co, n, mat, node, tag):
        m = 0.9 + 0.12 * fbm(co, 3, 3, 2)
        c = (m, m, m)
        if mat == "site_paint_white":
            c = mix(c, (0.8, 0.76, 0.66), smooth(1.0, 0.75, co.y) * 0.6)
            if fbm(co, 7.0, 2, 3.0) > 0.35:
                c = (0.55, 0.5, 0.44)
        if mat == "site_timber":
            c = mix(c, (0.6, 0.58, 0.5), smooth(0.3, 0.0, co.y))
        return c
    a = Asset(name, colour=col, ao_dist=0.25, buried_ok=0.4,
              meta={"note": "a small weathered board on two short posts, leaning back a little" +
                    ("" if blank else "; hand-painted CAVE / KEEP OUT in red")},
              probes=[{"node": name, "mat": "site_paint_white", "dir": [0, 0.1, 1]}])
    b = a.node(name, rot=(-6, 0, 2.5))
    for s in (-1, 1):
        b.add(box((0.08, 1.55, 0.08), (s * 0.36, 0.42, 0.0), bevel=0.004), "site_timber", grain=(0, 1, 0))
    b.add(box((0.9, 0.48, 0.025), (0, 0.98, 0.055), bevel=0.003), "site_board", grain=(1, 0, 0),
          mat_fn=lambda c, n: "site_paint_white" if n.z > 0.9 else "site_board")
    if not blank:
        for txt, y, size in (("CAVE", 1.04, 0.17), ("KEEP OUT", 0.84, 0.13)):
            t = text_mesh(txt, size, extrude=0.0, spacing=1.05)
            bmesh.ops.transform(t, matrix=Matrix.Translation((0, y, 0.0685)) @ Matrix.Rotation(0.03, 4, 'Z'), verts=t.verts)
            b.add(t, "site_paint_red", recalc=False, uv=lambda co, n: (co.x, co.y))
    for x in (-0.36, 0.36):
        for y in (0.88, 1.1):
            b.add(cyl(0.008, 0.006, (x, y, 0.068), (x, y, 0.075), 6), "site_iron")
    return a


def cave_fallen_slab():
    a = Asset("cave_fallen_slab", colour=rock_colour, ao_dist=0.4, buried_ok=0.3,
              meta={"note": "a flat slab half buried at the entrance (same origin as cave_outcrop; it lies at x -0.6, z 1.6)"})
    b = a.node("cave_fallen_slab")
    s = rock((1.9, 0.38, 1.3), (0, 0, 0), seed=950, subdiv=2, cuts=10, rough=0.04, blocky=0.85, embed=0.0, flat_base=False)
    bmesh.ops.transform(s, matrix=Matrix.Translation((-0.6, -0.12, 1.6)) @ Matrix.Rotation(math.radians(12), 4, 'Z') @
                        Matrix.Rotation(math.radians(25), 4, 'Y'), verts=s.verts)
    b.add(s, "site_rock", mat_fn=moss_fn(951, 0.6))
    return a


def project_patch(a_target, origin, du, dv, ray, nu=10, nv=10, offset=0.012, back=3.0):
    """a decal that follows a rock face: a grid laid out from origin along du and dv, each point shot along `ray` onto the
    target asset's surface and lifted `offset` off it"""
    from mathutils.bvhtree import BVHTree
    verts, tris = [], []
    for nm in a_target.order:
        bm = a_target.nodes[nm][0].bm
        if nm == "cave_mouth":
            continue
        bm.verts.index_update()
        b0 = len(verts)
        verts += [v.co.copy() for v in bm.verts]
        for f in bm.faces:
            ids = [v.index + b0 for v in f.verts]
            for k in range(1, len(ids) - 1):
                tris.append((ids[0], ids[k], ids[k + 1]))
    bvh = BVHTree.FromPolygons(verts, tris, all_triangles=True)
    b = bmesh.new()
    uvl = b.loops.layers.uv.new("UVMap")
    grid_v = {}
    O, U, Vv, R = V(origin), V(du), V(dv), V(ray).normalized()
    for i in range(nu + 1):
        for j in range(nv + 1):
            p = O + U * (i / nu) + Vv * (j / nv)
            hit = bvh.ray_cast(p - R * back, R, 8.0)
            if hit[0] is None:
                continue
            grid_v[i, j] = (b.verts.new(hit[0] + hit[1] * offset), (i / nu, 1 - j / nv))
    for i in range(nu):
        for j in range(nv):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(k in grid_v for k in q):
                f = b.faces.new([grid_v[k][0] for k in q])
                for l, k in zip(f.loops, q):
                    l[uvl].uv = grid_v[k][1]
    b.normal_update()
    for f in b.faces:
        if f.normal.dot(-R) < 0:
            f.normal_flip()
    return b


def cave_damp_stain():
    src = cave_outcrop()
    a = Asset("cave_damp_stain", ao_strength=0.0, ground=False, float_ok=["cave_damp_stain"], meta={"note": "a dark damp stain on the rock round the mouth, "
              "projected onto cave_outcrop (same origin)"})
    b = project_patch(src, (-1.9, 4.3, 3.0), (3.8, 0, 0), (0, -4.3, 0), (0, 0, -1), 14, 14)
    a.node("cave_damp_stain").add(b, "site_decal_damp", keep_uv=True, recalc=False)
    return a


def cave_chalk_mark():
    src = cave_outcrop()
    a = Asset("cave_chalk_mark", ao_strength=0.0, ground=False, float_ok=["cave_chalk_mark"], meta={"note": "a faint, unreadable chalk scrawl on the right-hand "
              "rock just inside the mouth (same origin as cave_outcrop)"})
    b = project_patch(src, (0.0, 1.6, 0.6), (0, 0, -0.55), (0, -0.45, 0), (1, 0, 0), 6, 6, offset=0.01, back=0.0)
    a.node("cave_chalk_mark").add(b, "site_decal_chalk", keep_uv=True, recalc=False)
    return a


def cave_scree():
    a = Asset("cave_scree", colour=rock_colour, ao_dist=0.25, lod1=0.5, buried_ok=0.1,
              meta={"note": "loose stones fanned out below the outcrop's right side (same origin as cave_outcrop)"})
    g = a.node("cave_scree")
    rnd = random.Random(23)
    for k in range(26):
        x = 2.4 + rnd.gauss(0, 0.8); z = 1.0 + abs(rnd.gauss(0, 0.7)); s = rnd.uniform(0.04, 0.25) * max(0.5, 1.3 - 0.3 * (z - 1.0))
        g.add(rock((s * 1.3, s * 0.8, s * 1.1), (x, 0, z), seed=1000 + k, subdiv=2 if s > 0.14 else 1, cuts=4, embed=s * 0.3),
              "site_rock", mat_fn=moss_fn(1000 + k, 0.8))
    return a


# ======================================================================================================== woodland detail (P1)
def track_puddle():
    a = Asset("track_puddle", ao_strength=0.0, lod1=0.0, buried_ok=0.06,
              colour=lambda co, n, m, nd, t: (1, 1, 1),
              meta={"size": [0.6, 1.8], "note": "a muddy puddle that fits in a rut (long axis along z)"})
    p = a.node("track_puddle")
    p.add(disc_patch(0.32, 0.95, 0.16, edge_sink=0.03, seed=31, top=0.012, wobble=0.15), "site_mud", recalc=False)
    p.add(disc_patch(0.24, 0.78, 0.18, edge_sink=-0.016, seed=32, top=0.018, wobble=0.12), "site_puddle", recalc=False)
    return a


def track_leaf_drift():
    a = Asset("track_leaf_drift", ao_strength=0.0, lod1=0.5, buried_ok=0.06, colour=lambda co, n, m, nd, t: (1.05, 0.98, 0.9),
              meta={"size": [0.9, 3.0], "note": "a drift of fallen leaves along the track edge (long axis along z)"})
    p = a.node("track_leaf_drift")
    p.add(disc_patch(0.45, 1.5, 0.2, edge_sink=0.03, seed=33, top=0.02, wobble=0.2,
                     yfn=lambda x, z: 0.1 * max(0.0, 1 - (x / 0.45) ** 2 - (z / 1.5) ** 2) + 0.02 * fbm((x, 0, z), 3.0, 2, 1.0)),
          "site_soil", recalc=False)
    return a


def track_grass_tuft():
    a = Asset("track_grass_tuft", ao_strength=0.0, lod1=0.0, ground=False,
              colour=lambda co, n, m, nd, t: mix((0.30, 0.38, 0.14), (0.72, 0.64, 0.38), smooth(0.05, 0.4, co.y)),
              meta={"size": [0.5, 0.45, 0.4], "note": "a clump of grass and dry stems for the centre strip; double-sided blades"})
    g = a.node("track_grass_tuft")
    rnd = random.Random(35)
    b = bmesh.new()
    for k in range(60):
        r = abs(rnd.gauss(0, 0.08)); ang = rnd.uniform(0, math.tau)
        base = V((math.cos(ang) * r, 0.0, math.sin(ang) * r))
        lean = V((math.cos(ang), 0, math.sin(ang))) * rnd.uniform(0.05, 0.35) + V((rnd.uniform(-0.1, 0.1), 0, rnd.uniform(-0.1, 0.1)))
        h = rnd.uniform(0.18, 0.45)
        w = rnd.uniform(0.006, 0.012)
        side = V((-math.sin(ang + 1.0), 0, math.cos(ang + 1.0)))
        pts = [base + V((0, -0.01, 0)), base + lean * 0.3 + V((0, h * 0.45, 0)), base + lean * 0.75 + V((0, h * 0.8, 0)), base + lean + V((0, h * 0.95, 0))]
        prev = None
        for i, p in enumerate(pts):
            ww = w * (1 - i / 3) + 0.0005
            pair = (b.verts.new(p - side * ww), b.verts.new(p + side * ww))
            if prev:
                b.faces.new((prev[0], prev[1], pair[1], pair[0]))
            prev = pair
    g.add(b, "site_grass", recalc=False, uv=lambda co, n: (co.x, co.y))
    return a


def tree_stump_a():
    a = Asset("tree_stump_a", colour=tree_colour, ao_dist=0.35, lod1=0.5, buried_ok=0.15,
              meta={"note": "a broken oak stump 0.75 m high with buttress roots and a splintered top"})
    s = a.node("tree_stump_a")
    path = [V((0, -0.1, 0)), V((0, 0.2, 0)), V((0.02, 0.45, 0.01)), V((0.03, 0.62, 0.01))]
    def flare(i, ang):
        return 1.0 + 0.35 * math.exp(-i / 0.7) * abs(math.sin(ang * 2.0))
    s.add(sweep(path, [0.42, 0.33, 0.3, 0.29], 12, caps=False, rfn=bark_rfn(71, 0.06, flare)), "site_bark_oak", grain=(0, 1, 0), uv='cyl',
          smooth=True)
    splinter_end(s, path[-1], (0.05, 1, 0.02), 0.29, 72, mat="site_timber", n=10, length=0.28)
    for k in range(4):
        ang = k * math.pi / 2 + 0.4
        d = V((math.cos(ang), 0, math.sin(ang)))
        s.add(sweep([d * 0.25 + V((0, 0.12, 0)), d * 0.6 + V((0, 0.04, 0)), d * 0.95 + V((0, -0.04, 0))], [0.09, 0.05, 0.02], 6),
              "site_bark_oak", grain=d, uv='cyl', smooth=True)
    return a


def fallen_log_old():
    def col(co, n, mat, node, tag):
        c = tree_colour(co, n, mat, node, tag)
        if mat == "site_moss":
            c = (0.9 + 0.2 * fbm(co, 2, 2, 1), 1.0, 0.85)
        return c
    a = Asset("fallen_log_old", colour=col, ao_dist=0.35, lod1=0.5, buried_ok=0.15,
              meta={"length": 4.2, "note": "an old log long collapsed at the track side: half sunk, bark gone in places, moss "
                                           "on top, rotten ends"})
    g = a.node("fallen_log_old")
    path = [V((-2.1 + 4.2 * t, 0.12 - 0.04 * math.sin(t * math.pi), 0.05 * math.sin(t * 3.0))) for t in [i / 8 for i in range(9)]]
    def matf(c, n):
        if n.y > 0.45 and fbm(c, 1.5, 2, 3.0) > -0.25:
            return "site_moss"
        return "site_timber" if fbm(c, 1.1, 2, 7.0) > 0.25 else "site_bark_oak"
    g.add(sweep(path, [0.2 - 0.03 * (i / 8) for i in range(9)], 10, caps=False, rfn=bark_rfn(81, 0.08)), "site_bark_oak", grain=(1, 0, 0),
          uv='cyl', mat_fn=matf, smooth=True)
    for (pp, r, sgn) in ((path[0], 0.2, -1), (path[-1], 0.17, 1)):
        splinter_end(g, pp, (sgn, 0, 0), r, 82 + sgn, mat="site_wood_end", n=8, length=0.12)
    return a


# ======================================================================================================== small signs of use (P2)
def track_old_gate():
    def col(co, n, mat, node, tag):
        m = 0.88 + 0.14 * fbm(co, 2, 3, 6)
        c = mix((m, m, m), (0.82, 0.92, 0.7), max(0.0, fbm(co, 2.5, 2, 2.0) - 0.15))
        if mat == "site_iron":
            c = (0.85, 0.6, 0.45)
        return c
    a = Asset("track_old_gate", colour=col, ao_dist=0.35, buried_ok=0.5, lod1=0.5,
              meta={"width": 3.2, "origin": "middle of the old gateway on the ground", "front": "+z (the ridge road side)",
                    "note": "a leaning, sagging timber field gate left half open at the ridge pull-off; the latch post has "
                            "rotted off. track_old_gate_leaf pivots on the hanging post"})
    p = a.node("track_old_gate_posts")
    p.add(box((0.18, 1.95, 0.18), (-1.7, 0.53, 0.0), rot=(0, 0, -5), bevel=0.01), "site_timber", grain=(0, 1, 0))
    p.add(box((0.17, 1.0, 0.17), (1.7, 0.05, 0.0), rot=(0, 0, -3), bevel=0.01), "site_timber", grain=(0, 1, 0))
    splinter_end(p, (1.72, 0.54, 0.0), (0.05, 1, 0), 0.085, 91, n=7, length=0.18)
    leaf = a.node("track_old_gate_leaf", pivot=(-1.6, 0, 0), rot=(0, -38, -5))
    x0, x1 = -1.58, 1.45
    for y in (0.35, 0.62, 0.89, 1.16):
        leaf.add(box((x1 - x0, 0.09, 0.04), ((x0 + x1) / 2, y, 0.0), bevel=0.004), "site_timber", grain=(1, 0, 0))
    for x in (x0 + 0.05, x1 - 0.05):
        leaf.add(box((0.09, 0.95, 0.045), (x, 0.76, 0.04), bevel=0.004), "site_timber", grain=(0, 1, 0))
    d0, d1 = V((x0 + 0.1, 0.36, 0.045)), V((x1 - 0.12, 1.15, 0.045))
    leaf.add(box((0.08, 0.035, (d1 - d0).length), (d0 + d1) / 2, rot=(0, 90, math.degrees(math.atan2(d1.y - d0.y, d1.x - d0.x)))),
             "site_timber")
    for y in (0.4, 1.1):
        leaf.add(box((0.45, 0.035, 0.008), (x0 + 0.22, y, -0.026)), "site_iron")
    return a


def flat_decal(name, mat, w, h, note):
    a = Asset(name, ao_strength=0.0, ground=False, meta={"size": [w, h], "note": note})
    b = bmesh.new()
    uvl = b.loops.layers.uv.new("UVMap")
    vs = [b.verts.new(p) for p in ((-w / 2, 0.006, -h / 2), (-w / 2, 0.006, h / 2), (w / 2, 0.006, h / 2), (w / 2, 0.006, -h / 2))]
    f = b.faces.new(vs)
    b.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    for l in f.loops:
        l[uvl].uv = (l.vert.co.x / w + 0.5, 1 - (l.vert.co.z / h + 0.5))
    a.node(name).add(b, mat, keep_uv=True, recalc=False)
    return a


def track_oil_stain():
    return flat_decal("track_oil_stain", "site_decal_oil", 0.9, 0.9, "an old dark oil stain, flat alpha decal lying 6 mm up")


def track_tyre_print():
    return flat_decal("track_tyre_print", "site_decal_tyre", 0.2, 1.6, "a faded tyre print in the dirt along z, flat alpha decal")


def cave_old_lantern():
    a = Asset("cave_old_lantern", ao_dist=0.08, colour=lambda co, n, m, nd, t: mix((1, 1, 1), (0.7, 0.6, 0.5), max(0.0, fbm(co, 12, 2, 1)) * 0.6),
              meta={"height": 0.3, "note": "a rusted hurricane lantern, unlit, glass globe clouded; stands on the rocks"})
    l = a.node("cave_old_lantern")
    l.add(cyl(0.075, 0.07, (0, 0, 0), (0, 0.06, 0), 14), "site_rust")
    l.add(cyl(0.07, 0.04, (0, 0.06, 0), (0, 0.08, 0), 14), "site_rust")
    globe = [V((0, 0.08 + 0.13 * t, 0)) for t in [i / 5 for i in range(6)]]
    l.add(sweep(globe, [0.04, 0.055, 0.062, 0.06, 0.05, 0.035], 14), "site_glass", smooth=True)
    for k in range(4):
        ang = k * math.pi / 2 + 0.4
        x, z = math.cos(ang), math.sin(ang)
        l.add(sweep([(x * 0.068, 0.06, z * 0.068), (x * 0.075, 0.15, z * 0.075), (x * 0.05, 0.22, z * 0.05)], 0.004, 4), "site_rust")
    l.add(cyl(0.06, 0.025, (0, 0.21, 0), (0, 0.26, 0), 12), "site_rust")
    l.add(torus(0.075, 0.004, (0, 0.24, 0), rot=(0, 0, 0), seg=10, sides=4, a0=0.0, a1=math.pi), "site_rust")
    return a


TRACK = [track_dirt_strip, track_rut_pair, tree_fall_a, tree_fall_b, rockfall_a, rockfall_b, dead_branch_scatter, cave_outcrop,
         cave_boulder_arch, cave_apron, cave_warning_board, lambda: cave_warning_board(True), cave_fallen_slab, track_puddle,
         track_leaf_drift, track_grass_tuft, tree_stump_a, fallen_log_old, cave_damp_stain, cave_scree, track_old_gate,
         track_oil_stain, track_tyre_print, cave_old_lantern, cave_chalk_mark, lambda: tree_fall_a(True)]
