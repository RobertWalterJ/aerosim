# The Halloway Lake boat launch (godot/docs/CLAUDE-BOAT-LAUNCH-ASSETS.md on lane/notify), modelled to real proportions.
# References studied (proportions only, nothing copied): the Western Australian "Guidelines for the design of boat launching
# facilities" (DoT WA, MAC P RBFS R22: 4 m between kerbs per lane, 1:8 preferred grade, a waffle of 25 mm V grooves at
# 45 degrees), the NSW Boat Ramp Facility Guidelines (2023), a southeast US fisheries paper on ramp slabs (6 in slabs,
# 6 in curbs, cut-off walls at head and toe), the Lund WC-12 spec sheet (12 ft 1 in riveted V hull, 61 in beam, 15 in
# transom) for the boat, and the common 4.80-12 single-axle galvanised boat trailer with carpeted bunks for the trailer.
# Game frame throughout: metres, x right, y up, z = the asset's front; origin at the base.
import math, random
from mathutils import Vector as V, Matrix
import bmesh
import sites_lib as L
from sites_lib import box, cyl, sweep, loft, grid, disc_patch, rock, torus, sphere, text_mesh, Asset, mix, smooth, fbm

WL = 24.0          # the ramp's waterline mark, metres from the head


# ======================================================================================================== the ramp
def ramp_colour(co, n, mat, node, tag):
    z, x = co.z, co.x
    m = 0.96 + 0.08 * fbm(co, 0.6, 3, 2.0)
    c = (m, m, m * 0.98)
    # tyre polish and dirt in the two wheel paths on the dry part
    for s in (-1, 1):
        w = math.exp(-((x - s * 0.95) / 0.32) ** 2) * (1 - smooth(WL - 4, WL - 1, z))
        c = mix(c, (c[0] * 0.80, c[1] * 0.77, c[2] * 0.72), w * 0.8)
    # dust and leaves along the curbs
    c = mix(c, (c[0] * 0.8, c[1] * 0.72, c[2] * 0.6), smooth(3.05, 3.5, abs(x)) * 0.6)
    # the joints every 5 m (sealant, dirt)
    for k in range(1, 6):
        if abs(z - k * 5.0) < 0.035 and mat != "site_concrete":
            c = (c[0] * 0.45, c[1] * 0.43, c[2] * 0.4)
    # wet band, scum line at the waterline, algae below it
    wet = smooth(WL - 3.2, WL - 0.2, z)
    c = mix(c, (c[0] * 0.62, c[1] * 0.62, c[2] * 0.6), wet)
    scum = math.exp(-((z - (WL - 0.35)) / 0.18) ** 2)
    c = mix(c, (0.82, 0.78, 0.66), scum * 0.6)
    alg = smooth(WL - 0.3, WL + 0.6, z)
    g = 0.5 + 0.25 * fbm(co, 1.3, 2, 7.0)
    c = mix(c, (0.40 * g + 0.1, 0.48 * g + 0.1, 0.30 * g + 0.05), alg * 0.9)
    if mat == "site_concrete" and n.y < -0.5:
        c = (c[0] * 0.5, c[1] * 0.5, c[2] * 0.5)
    return c


def boat_ramp():
    a = Asset("boat_ramp", ao_dist=0.5, lod1=0.5, colour=ramp_colour, buried_ok=0.7,
              meta={"waterline_z": WL, "width": 7.0, "length": 30.0, "curbs": "x = +-3.5 to +-3.8",
                    "note": "built level; SiteAssets.fit_ramp(node, head_y, water_y) shears it so the waterline mark (z = 24) "
                            "meets the water; the slab runs on 6 m past the mark under water as real ramps do"},
              probes=[{"node": "boat_ramp_slab", "mat": "site_ramp", "dir": [0, 1, 0]}])
    slab = a.node("boat_ramp_slab")
    xs = [-3.5, -3.1, -2.2, -1.35, -0.95, -0.55, 0.0, 0.55, 0.95, 1.35, 2.2, 3.1, 3.5]
    zs = sorted(set([round(1.0 * i, 3) for i in range(31)] + [k * 5.0 + d for k in range(1, 6) for d in (-0.03, 0.03)] +
                    [WL - 0.6, WL - 0.45, WL - 0.3, WL - 0.15, WL + 0.15]))
    top = lambda x, z: 0.05 + 0.03 * (1 - (x / 3.5) ** 2)
    slab.add(grid(xs, zs, top), "site_ramp", recalc=False)
    # sides, bottom and the end walls (cut-off walls at head and toe, 0.6 m deep)
    ring_pts = lambda z: [(x, top(x, z), z) for x in xs] + [(3.5, -0.2, z), (-3.5, -0.2, z)]
    for x0 in (-3.5, 3.5):
        pts = [(x0, top(x0, z), z) for z in zs]
        bm = bmesh.new()
        vs_top = [bm.verts.new(p) for p in pts]
        vs_bot = [bm.verts.new((p[0], -0.2, p[2])) for p in pts]
        for i in range(len(pts) - 1):
            f = bm.faces.new((vs_top[i], vs_top[i + 1], vs_bot[i + 1], vs_bot[i]))
            if (f.normal.x > 0) != (x0 > 0):
                f.normal_flip()
        slab.add(bm, "site_concrete", recalc=False)
    slab.add(box((7.0, 0.02, 30.0), (0, -0.21, 15.0)), "site_concrete")
    slab.add(box((7.0, 0.65, 0.3), (0, -0.25 + 0.0, 0.15)), "site_concrete")     # head cut-off wall
    slab.add(box((7.0, 0.65, 0.4), (0, -0.25, 29.8)), "site_concrete")           # toe cut-off wall
    # the curbs: 0.3 m wide, 0.2 m proud of the slab, chamfered top edge, chipped at random by vertex colour
    for s, nm in ((-1, "boat_ramp_curb_l"), (1, "boat_ramp_curb_r")):
        c = a.node(nm)
        x0 = s * 3.65
        sec = [(-0.15, -0.2), (0.15, -0.2), (0.15, 0.22), (0.12, 0.25), (-0.12, 0.25), (-0.15, 0.22)]
        rings = []
        for z in [0.0] + [1.0 * i + 0.5 for i in range(30)] + [30.0]:
            rings.append([(x0 + u * (1 if s > 0 else -1), v, z) for (u, v) in sec])
        bm = loft(rings, True, True, True)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        c.add(bm, "site_concrete", grain=(0, 0, 1))
    return a


# ======================================================================================================== the apron
def apron_colour(co, n, mat, node, tag):
    x, z = co.x, co.z
    m = 0.95 + 0.1 * fbm(co, 0.35, 3, 4.0)
    c = (m, m * 0.98, m * 0.95)
    # two pairs of wheel tracks where trailers back down to the ramp: compacted, darker, a little polished
    for zc in (2.4, -2.4):
        zp = zc - 0.012 * x * x * (1 if zc > 0 else -1)
        for s in (-0.8, 0.8):
            w = math.exp(-((z - zp - s) / 0.28) ** 2) * smooth(-10, -6, x) * (1 - smooth(8.5, 10.5, x))
            c = mix(c, (c[0] * 0.70, c[1] * 0.66, c[2] * 0.60), w * 0.85)
    # the edge grades into grassy soil
    f = ((abs(x) / 10.0) ** 4 + (abs(z) / 6.5) ** 4) ** 0.25
    c = mix(c, (0.62, 0.66, 0.46), smooth(0.86, 1.02, f) * 0.75)
    # two damp dips
    for (px, pz, r) in ((-6.5, 3.6, 1.1), (3.0, -4.6, 0.8)):
        d = math.hypot(x - px, z - pz)
        c = mix(c, (c[0] * 0.6, c[1] * 0.58, c[2] * 0.55), max(0.0, 1 - d / r) * 0.8)
    return c


def boat_parking_gravel():
    a = Asset("boat_parking_gravel", ao_strength=0.0, lod1=0.5, colour=apron_colour, buried_ok=0.1,
              meta={"size": [20, 13], "note": "gravel apron, edge sunk 5 cm so the terrain cuts a ragged edge; "
                                              "drape with SiteAssets.drape(node, height_fn) on sloping ground"})
    g = a.node("boat_parking_gravel")
    rnd = random.Random(3)
    ph = [rnd.uniform(0, 6.28) for _ in range(3)]
    def f_of(x, z):
        return ((abs(x) / 10.0) ** 4 + (abs(z) / 6.5) ** 4) ** 0.25
    def edge(x, z):
        a_ = math.atan2(z, x)
        return 1.0 + 0.04 * math.sin(5 * a_ + ph[0]) + 0.025 * math.sin(11 * a_ + ph[1])
    def yfn(x, z):
        f = f_of(x, z) / edge(x, z)
        y = 0.03 + 0.012 * L.fbm((x, 0, z), 0.3, 2, 1.0)
        for zc in (2.4, -2.4):
            zp = zc - 0.012 * x * x * (1 if zc > 0 else -1)
            for s in (-0.8, 0.8):
                y -= 0.02 * math.exp(-((z - zp - s) / 0.22) ** 2) * smooth(-10, -6, x)
        for (px, pz, r) in ((-6.5, 3.6, 1.1), (3.0, -4.6, 0.8)):
            y -= 0.03 * max(0.0, 1 - math.hypot(x - px, z - pz) / r)
        return y * (1 - smooth(0.9, 1.0, f)) - 0.06 * smooth(0.93, 1.03, f)
    xs = [-10.8 + 0.6 * i for i in range(37)]
    zs = [-7.2 + 0.6 * i for i in range(25)]
    g.add(grid(xs, zs, yfn, keep=lambda x, z: f_of(x, z) / edge(x, z) < 1.04), "site_gravel", recalc=False)
    return a


def boat_launch_gravel_patch():
    a = Asset("boat_launch_gravel_patch", ao_strength=0.0, lod1=0.5, buried_ok=0.1,
              colour=lambda co, n, m, nd, t: mix((1, 0.98, 0.95), (0.62, 0.57, 0.5), sum(
                  math.exp(-((co.x - s) / 0.25) ** 2) for s in (-0.8, 0.8)) * 0.8))
    g = a.node("boat_launch_gravel_patch")
    def yfn(x, z):
        return 0.02 * L.fbm((x, 0, z), 1.2, 2, 3.0) - sum(0.035 * math.exp(-((x - s) / 0.2) ** 2) for s in (-0.8, 0.8))
    g.add(disc_patch(2.2, 3.0, 0.4, seed=5, yfn=yfn, top=0.04), "site_gravel", recalc=False)
    # loose stones kicked up beside the ruts
    rnd = random.Random(8)
    for k in range(14):
        x = rnd.choice((-1, 1)) * rnd.uniform(1.0, 1.9); z = rnd.uniform(-2.5, 2.5); s = rnd.uniform(0.04, 0.09)
        g.add(rock((s * 1.3, s, s * 1.1), (x, 0.0, z), seed=k + 30, subdiv=0, cuts=3, embed=s * 0.3), "site_rock")
    return a


# ======================================================================================================== the dock
def dock_colour(co, n, mat, node, tag):
    c = (1.0, 1.0, 1.0)
    y = co.y
    if mat in ("site_deck", "site_board"):
        r = random.Random(tag or 0)
        k = 0.82 + 0.3 * r.random()
        c = (k, k * (0.97 + 0.04 * r.random()), k * 0.95)
        c = mix(c, (c[0] * 1.1, c[1] * 1.08, c[2] * 1.0), max(0.0, fbm(co, 0.8, 2, 1.0)) * 0.5)
    if mat == "site_timber":
        c = mix(c, (0.55, 0.52, 0.46), smooth(0.4, -0.2, y))
    if mat == "site_plastic_white":
        c = (0.95, 0.95, 0.92)
    # algae and a tide line round the waterline, wet and dark below it
    alg = smooth(0.12, -0.05, y)
    c = mix(c, (0.38, 0.44, 0.30), alg * 0.85)
    line = math.exp(-((y - 0.1) / 0.03) ** 2)
    c = mix(c, (0.55, 0.5, 0.4), line * 0.6)
    if mat in ("site_galv", "site_iron"):
        c = mix(c, (0.75, 0.55, 0.42), max(0.0, fbm(co, 4.0, 2, 3.0)) * 0.7)
    return c


def cleat(mesh, x, y, z, along=(0, 0, 1)):
    """a cast horn cleat 0.3 m long on the deck"""
    mesh.add(box((0.07, 0.03, 0.16), (x, y + 0.015, z), bevel=0.01), "site_iron")
    for s in (-1, 1):
        mesh.add(cyl(0.022, 0.018, (x, y + 0.02, z + s * 0.04), (x, y + 0.075, z + s * 0.05), 8), "site_iron")
    mesh.add(sweep([(x, y + 0.07, z - 0.15), (x, y + 0.085, z - 0.06), (x, y + 0.09, z), (x, y + 0.085, z + 0.06),
                    (x, y + 0.07, z + 0.15)], [0.012, 0.018, 0.02, 0.018, 0.012], 8), "site_iron")
    for s in (-1, 1):
        mesh.add(cyl(0.012, 0.012, (x, y, z + s * 0.11), (x, y + 0.012, z + s * 0.11), 6), "site_galv")


def boat_dock():
    a = Asset("boat_dock", ao_dist=0.45, colour=dock_colour, buried_ok=3.0, lod1=0.45,
              meta={"length": 14.0, "width": 2.4, "deck_top": 0.39, "origin": "shore end, centre, at the waterline",
                    "note": "floating dock on six piles; place the origin at the ramp side at Lake.LEVEL"},
              probes=[{"node": "boat_dock_ladder", "axis": "z", "side": 1}])
    deck = a.node("boat_dock_deck")
    posts = a.node("boat_dock_posts")
    floats = a.node("boat_dock_floats")
    cleats = a.node("boat_dock_cleats")
    ladder = a.node("boat_dock_ladder")
    Lz = 14.0
    # stringers, fascia and joists
    for s in (-1, 1):
        deck.add(box((0.1, 0.2, Lz), (s * 1.12, 0.25, Lz / 2)), "site_timber", grain=(0, 0, 1), tag=900 + s)
        deck.add(box((0.035, 0.22, Lz), (s * 1.1925, 0.24, Lz / 2), bevel=0.004), "site_board", grain=(0, 0, 1), tag=910 + s)
    for k in range(12):
        z = 0.6 + k * 1.15
        deck.add(box((2.24, 0.15, 0.05), (0, 0.225, z)), "site_timber", grain=(1, 0, 0), tag=950 + k)
    # deck boards along the dock: 16 x 140 mm with 10 mm gaps, butt joints staggered
    rnd = random.Random(21)
    for i in range(16):
        x = -1.2 + 0.075 + i * 0.15
        j = rnd.uniform(4.0, 10.0)
        for (z0, z1, t) in ((0.0, j, i * 2), (j + 0.006, Lz, i * 2 + 1)):
            deck.add(box((0.14, 0.04, z1 - z0), (x, 0.37, (z0 + z1) / 2)), "site_deck", grain=(0, 0, 1), tag=t)
    deck.add(box((2.6, 0.25, 0.25), (0, 0.02, -0.1), bevel=0.02), "site_timber", grain=(1, 0, 0), tag=990)   # shore sill
    # white floats with moulded ribs, half submerged
    for zc in (1.75, 5.25, 8.75, 12.25):
        floats.add(box((2.2, 0.4, 1.5), (0, -0.05, zc), bevel=0.05), "site_plastic_white")
        for k in (-0.45, 0.45):
            floats.add(box((2.22, 0.06, 0.08), (0, 0.0, zc + k)), "site_plastic_white")
    # six piles outside the deck, caps, hoops and brackets
    for z in (0.8, 7.0, 13.2):
        for s in (-1, 1):
            x = s * 1.36
            posts.add(cyl(0.125, 0.115, (x, -2.8, z), (x, 1.05, z), 10), "site_timber", grain=(0, 1, 0), uv='cyl')
            posts.add(cyl(0.13, 0.03, (x, 1.04, z), (x, 1.13, z), 10), "site_galv")
            posts.add(torus(0.155, 0.014, (x, 0.26, z), rot=(90, 0, 0), seg=10, sides=4), "site_galv")
            posts.add(box((0.2, 0.06, 0.08), (s * 1.27, 0.26, z)), "site_galv")
    # cleats
    cleat(cleats, 0.95, 0.39, 6.2)
    cleat(cleats, -0.95, 0.39, 13.0)
    # boarding ladder at the outer end
    for s in (-1, 1):
        ladder.add(sweep([(s * 0.22, 0.39, 13.75), (s * 0.22, 0.9, 13.8), (s * 0.22, 0.95, 14.05), (s * 0.22, 0.6, 14.15),
                          (s * 0.22, -1.1, 14.15)], 0.02, 8), "site_galv")
    for y in (0.15, -0.25, -0.65):
        ladder.add(box((0.46, 0.03, 0.08), (0, y, 14.15), bevel=0.008), "site_galv")
    ladder.add(box((0.5, 0.05, 0.12), (0, 0.37, 13.95)), "site_galv")
    return a


# ======================================================================================================== the sign
def post(mesh, x, z, h, w=0.14, buried=0.4, mat="site_timber", tag=0, cap=True):
    mesh.add(box((w, h + buried - 0.03, w), (x, (h - buried - 0.03) / 2, z), bevel=0.006), mat, grain=(0, 1, 0), tag=tag)
    if cap:
        b = bmesh.new()
        hw = w / 2
        vs = [b.verts.new(p) for p in ((x - hw, h - 0.03, z - hw), (x + hw, h - 0.03, z - hw), (x + hw, h - 0.03, z + hw), (x - hw, h - 0.03, z + hw))]
        tip = b.verts.new((x, h + 0.02, z))
        for i in range(4):
            b.faces.new((vs[i], vs[(i + 1) % 4], tip))
        b.faces.new(list(reversed(vs)))
        bmesh.ops.recalc_face_normals(b, faces=b.faces[:])
        mesh.add(b, mat, tag=tag)


def sign_colour(co, n, mat, node, tag):
    m = 0.95 + 0.08 * fbm(co, 2.0, 3, 5.0)
    c = (m, m, m)
    if mat == "site_paint_cream":
        # grime gathering at the bottom edge, a little green at the top, fading in the middle
        c = mix(c, (0.80, 0.76, 0.66), smooth(2.0, 1.78, co.y) * 0.7)
        c = mix(c, (0.80, 0.86, 0.72), smooth(2.6, 2.73, co.y) * 0.5)
        if fbm(co, 6.0, 2, 9.0) > 0.42:
            c = (0.62, 0.58, 0.52)          # chipped to the timber
    if mat == "site_timber":
        c = mix(c, (0.62, 0.58, 0.5), smooth(0.35, -0.05, co.y))
        c = mix(c, (0.85, 0.92, 0.75), max(0.0, fbm(co, 3.0, 2, 2.0) - 0.2))
    if mat == "site_paint_red":
        c = mix(c, (0.85, 0.8, 0.78), max(0.0, fbm(co, 5.0, 2, 4.0)) * 0.6)
    return c


def boat_launch_sign():
    a = Asset("boat_launch_sign", colour=sign_colour, buried_ok=0.45, ao_dist=0.4,
              meta={"text_rect": {"centre": [0.0, 2.25, 0.114], "size": [2.86, 0.76], "facing": "+z"},
                    "ring_hook": [-1.35, 1.62, 0.075],
                    "note": "no lettering in the model: put a Label3D or a painted face at text_rect"},
              probes=[{"node": "boat_launch_sign_board", "mat": "site_paint_cream", "dir": [0, 0, 1]}])
    posts = a.node("boat_launch_sign_posts")
    board = a.node("boat_launch_sign_board")
    for s in (-1, 1):
        post(posts, s * 1.35, 0.0, 2.95, tag=s)
    # the board: timber with a cream painted face; a simple red border, 8 mm proud; four coach bolts
    board.add(box((3.1, 1.0, 0.04), (0, 2.25, 0.09), bevel=0.006), "site_board", grain=(1, 0, 0),
              mat_fn=lambda c, n: "site_paint_cream" if n.z > 0.9 else "site_board")
    bw, inset, z = 0.06, 0.05, 0.112
    for (w, h, x, y) in ((3.1 - 2 * inset, bw, 0, 2.25 + 0.5 - inset - bw / 2), (3.1 - 2 * inset, bw, 0, 2.25 - 0.5 + inset + bw / 2),
                         (bw, 1.0 - 2 * inset, -1.55 + inset + bw / 2, 2.25), (bw, 1.0 - 2 * inset, 1.55 - inset - bw / 2, 2.25)):
        board.add(box((w, h, 0.006), (x, y, z)), "site_paint_red")
    for s in (-1, 1):
        for y in (1.95, 2.55):
            board.add(cyl(0.016, 0.012, (s * 1.35, y, 0.108), (s * 1.35, y, 0.12), 8), "site_galv")
    # a hook for the life ring on the left post, below the board
    posts.add(box((0.08, 0.1, 0.012), (-1.35, 1.62, 0.076)), "site_galv")
    posts.add(sweep([(-1.35, 1.62, 0.08), (-1.35, 1.62, 0.15), (-1.35, 1.66, 0.17)], 0.008, 6), "site_galv")
    return a


def boat_life_ring():
    R, r = 0.30, 0.08
    def ring_colour(co, n, mat, node, tag):
        m = 0.92 + 0.1 * fbm(co, 5.0, 2, 1.0)
        c = (m, m, m)
        if mat == "site_paint_white":
            c = mix(c, (0.82, 0.8, 0.72), smooth(0.5, 0.05, co.y) * 0.6)
        return c
    a = Asset("boat_life_ring", colour=ring_colour, ao_dist=0.15, ground=False, lod1=0.5,
              meta={"outer_diameter": 0.76, "note": "30 in (0.76 m) ring, the standard size; origin at the bottom of the "
                                                    "ring, hook bracket at the top (y 0.76 to 0.86) fits the sign's ring_hook"},
              probes=[{"node": "boat_life_ring_bracket", "axis": "y", "side": 1}])
    ring = a.node("boat_life_ring")
    cy = R + r + 0.05          # room below the ring for the grab line's festoons
    def seg_mat(c, n):
        ang = math.atan2(c.y - cy, c.x) % math.tau
        return "site_paint_red" if int((ang + math.pi / 4) / (math.pi / 2)) % 2 == 0 else "site_paint_white"
    ring.add(torus(R, r, (0, cy, 0), seg=24, sides=7), "site_paint_white", mat_fn=seg_mat, smooth=True)
    for k in range(4):
        t = math.pi / 4 + k * math.pi / 2
        ring.add(torus(R, r + 0.004, (0, cy, 0), seg=3, sides=10, a0=t - 0.08, a1=t + 0.08), "site_reflector", smooth=True)
    # the grab line in four festoons, seized to the ring at eight points
    pts = []
    for k in range(4):
        for j in range(9):
            t = k * math.pi / 2 + math.pi / 4 + j / 8 * math.pi / 2
            sag = 0.035 * math.sin(j / 8 * math.pi)
            rr = R + r + 0.004 + sag
            pts.append((math.cos(t) * rr, cy + math.sin(t) * rr, 0.012 * math.sin(j / 8 * math.pi)))
    ring.add(sweep(pts + [pts[0]], 0.006, 3), "site_rope")
    br = a.node("boat_life_ring_bracket")
    br.add(box((0.06, 0.14, 0.012), (0, cy + R + r + 0.06, -0.09)), "site_galv")
    br.add(sweep([(0, cy + R + r + 0.1, -0.084), (0, cy + R + r + 0.1, 0.0), (0, cy + R + r - 0.0, 0.0)], 0.007, 6), "site_galv")
    return a


# ======================================================================================================== the boat
# Hull: 3.6 m long, 1.4 m beam, riveted modified-V, transom 0.50 m, bow 0.70 m. Origin: keel bottom, middle of the length.
HL = 3.6


def hull_station(t):
    """t 0 (transom) .. 1 (bow): (keel y, chine half-breadth, chine y, gunwale half-breadth, sheer y)"""
    ys = 0.50 + 0.04 * t + 0.16 * t ** 3
    if t <= 0.42:
        bg = 0.58 + 0.12 * math.sin(t / 0.42 * math.pi / 2)
    else:
        bg = 0.70 * max(0.0, 1 - ((t - 0.42) / 0.58) ** 2) ** 0.55
    bg = max(bg, 0.004)
    yk = 0.0 if t < 0.55 else 0.40 * ((t - 0.55) / 0.45) ** 2.2
    dr = math.radians(12 + 22 * t ** 2)
    bc = bg * (0.86 - 0.2 * max(0.0, t - 0.7))
    yc = yk + math.tan(dr) * bc
    yc = min(yc, ys - 0.05)
    return yk, bc, yc, bg, ys


def hull_section(t):
    """one side's section from the keel up to the gunwale: list of (x, y)"""
    yk, bc, yc, bg, ys = hull_station(t)
    pts = [(0.0, yk), (bc * 0.30, yk + (yc - yk) * 0.28), (bc * 0.55, yk + (yc - yk) * 0.53 - 0.004),
           (bc * 0.56, yk + (yc - yk) * 0.555), (bc * 0.80, yk + (yc - yk) * 0.79), (bc, yc), (bc + 0.012, yc + 0.006)]
    for k in (0.3, 0.6, 1.0):
        x = bc + 0.012 + (bg - bc - 0.012) * (k ** 0.8)
        y = yc + 0.006 + (ys - yc - 0.006) * k
        pts.append((x, y))
    return pts


def hull_bottom_y(x, z):
    """outer bottom height at half-breadth |x| and position z (for sitting the hull on bunks)"""
    t = (z + HL / 2) / HL
    sec = hull_section(min(0.995, max(0.0, t)))
    ax = abs(x)
    for (x0, y0), (x1, y1) in zip(sec[:-1], sec[1:]):
        if x0 <= ax <= x1 and x1 > x0:
            return y0 + (y1 - y0) * (ax - x0) / (x1 - x0)
    return sec[-1][1]


def hull_colour(paint):
    def f(co, n, mat, node, tag):
        m = 0.94 + 0.1 * fbm(co, 1.5, 3, 3.0)
        c = (m, m, m)
        if node == "boat_outboard":
            return mix(c, (0.8, 0.78, 0.74), max(0.0, fbm(co, 4.0, 2, 1.0)) * 0.5)
        y = co.y
        outside = tag == "out"
        if outside:
            c = mix(c, (0.70, 0.68, 0.62), smooth(0.16, 0.10, y) * 0.8)            # below the waterline: dull, stained
            c = mix(c, (0.62, 0.55, 0.42), math.exp(-((y - 0.14) / 0.015) ** 2) * 0.6)   # the tide line
            c = mix(c, (0.85, 0.85, 0.82), max(0.0, fbm(co, 8.0, 2, 6.0) - 0.3) * 0.8)   # scrapes on the keel and chines
        if tag == "in" and n.y > 0.4:
            c = mix(c, (0.70, 0.62, 0.50), smooth(0.12, 0.03, y) * 0.8)             # silt and leaf bits in the bilge
        if mat == "site_paint_green":
            c = mix(c, (1.2, 1.18, 1.1), max(0.0, fbm(co, 2.0, 2, 8.0)) * 0.4)        # chalky fading
            c = mix(c, (1.6, 1.6, 1.55), max(0.0, fbm(co, 9.0, 2, 2.0) - 0.35))        # chips to bare metal
        return c
    return f


def build_hull(a, prefix="boat_aluminium_hull", painted=False, offset=V((0, 0, 0)), outboard=True, tilt=0.0):
    hull = a.node(prefix, pivot=offset)
    off = offset
    nst = 20
    ts = [i / (nst - 1) * 0.995 for i in range(nst)]
    rings_out = []
    for t in ts:
        z = -HL / 2 + t * HL
        sec = hull_section(t)
        ring = [(-x, y, z) for (x, y) in reversed(sec[1:])] + [(x, y, z) for (x, y) in sec]
        rings_out.append([V(p) + off for p in ring])
    yc_at = {}
    def mat_out(c, n):
        if not painted:
            return "site_alu"
        t = (c.z - off.z + HL / 2) / HL
        _, bc, yc, bg, ys = hull_station(min(0.995, max(0.0, t)))
        return "site_paint_green" if c.y - off.y > yc + 0.02 else "site_alu"
    def uvf(co, n):
        return (co.z, abs(co.x - off.x) + max(0.0, co.y - off.y - 0.08) * 0.9)
    bm = loft(rings_out, close_ring=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    # make sure the outer skin faces outward (away from the centre line)
    bm.normal_update()
    acc = sum((f.normal.x * (f.calc_center_median().x - off.x) for f in bm.faces), 0.0)
    if acc < 0:
        for f in bm.faces:
            f.normal_flip()
    hull.add(bm, "site_alu", uv=uvf, mat_fn=mat_out, tag="out", recalc=False)
    # the inner skin, 3 mm inside, facing in
    rings_in = []
    for t in ts:
        z = -HL / 2 + t * HL
        sec = hull_section(t)
        sec_in = [(max(0.0, x - 0.004), y + 0.003) for (x, y) in sec]
        ring = [(-x, y, z) for (x, y) in reversed(sec_in[1:])] + [(x, y, z) for (x, y) in sec_in]
        rings_in.append([V(p) + off for p in ring])
    bm = loft(rings_in, close_ring=False)
    bm.normal_update()
    acc = sum((f.normal.x * (f.calc_center_median().x - off.x) for f in bm.faces), 0.0)
    if acc > 0:
        for f in bm.faces:
            f.normal_flip()
    hull.add(bm, "site_alu", uv=uvf, tag="in", recalc=False)
    # transom: an aluminium plate with a plywood motor pad on top inside
    sec = hull_section(0.0)
    poly = [(-x, y) for (x, y) in reversed(sec[1:])] + sec
    for zz, flip in ((-HL / 2 - 0.002, True), (-HL / 2 + 0.018, False)):
        b = bmesh.new()
        vs = [b.verts.new(V((x, y, zz)) + off) for (x, y) in poly]
        f = b.faces.new(vs)
        b.normal_update()
        if (f.normal.z > 0) == flip:
            f.normal_flip()
        hull.add(b, "site_alu", tag="out" if flip else "in", recalc=False)
    ys0 = hull_station(0.0)[4]
    hull.add(box((0.62, 0.26, 0.045), V((0, ys0 - 0.13, -HL / 2 + 0.04)) + off, bevel=0.005), "site_ply", grain=(1, 0, 0))
    # gunwale rails (a capped extrusion) along both sheers, meeting at the stem
    for s in (-1, 1):
        path = []
        for t in ts:
            yk, bc, yc, bg, ys = hull_station(t)
            path.append(V((s * bg, ys + 0.008, -HL / 2 + t * HL)) + off)
        hull.add(sweep(path, 0.016, 4), "site_alu", grain=(0, 0, 1), tag="rail")
    # keel strip and stem band
    kp = []
    for t in ts:
        yk = hull_station(t)[0]
        kp.append(V((0, yk - 0.006, -HL / 2 + t * HL)) + off)
    yk1, _, _, _, ys1 = hull_station(0.995)
    for k in range(1, 5):
        kp.append(V((0, yk1 + (ys1 - yk1) * k / 4, -HL / 2 + 0.995 * HL + 0.004 * k)) + off)
    hull.add(sweep(kp, 0.014, 4), "site_alu", tag="out")
    # ribs inside every 0.45 m
    for zr in (-0.9, -0.45, 0.45, 0.9):
        t = (zr + HL / 2) / HL
        sec = hull_section(t)
        yk, bc, yc, bg, ys = hull_station(t)
        side = [(x, y) for (x, y) in sec if x <= bc + 0.02]
        path = [V((-x, y + 0.012, zr)) + off for (x, y) in reversed(side[1:])] + [V((x, y + 0.012, zr)) + off for (x, y) in side]
        hull.add(sweep(path, 0.012, 3), "site_alu", tag="in")
    # bench seats (with buoyancy boxes under the stern and bow seats)
    def half_at(t, y):
        sec = hull_section(t)
        for (x0, y0), (x1, y1) in zip(sec[:-1], sec[1:]):
            if y0 <= y <= y1 and y1 > y0:
                return x0 + (x1 - x0) * (y - y0) / (y1 - y0)
        return sec[-1][0]
    for (zs_, yseat, depth, boxed) in ((-1.42, 0.34, 0.32, True), (-0.1, 0.36, 0.26, False), (0.95, 0.42, 0.28, True)):
        t = (zs_ + HL / 2) / HL
        hw = half_at(t, yseat) - 0.002
        hull.add(box((hw * 2, 0.03, depth), V((0, yseat, zs_)) + off, bevel=0.006), "site_alu", grain=(1, 0, 0), tag="seat")
        if boxed:
            hb = half_at(t, yseat - 0.16)
            hull.add(box((hb * 2 - 0.02, 0.17, depth - 0.03), V((0, yseat - 0.1, zs_)) + off, bevel=0.004), "site_alu", tag="seat")
        else:
            for s in (-1, 1):
                hull.add(box((0.03, 0.12, depth * 0.8), V((s * (hw - 0.03), yseat - 0.07, zs_)) + off), "site_alu", tag="seat")
    # bow deck plate, bow eye, transom handles, drain plug, oarlocks
    bp = []
    for t in [0.86 + 0.0135 * i for i in range(11)]:
        yk, bc, yc, bg, ys = hull_station(t)
        bp.append((bg, ys - 0.004, -HL / 2 + t * HL))
    b = bmesh.new()
    vs = [b.verts.new(V((x, y, z)) + off) for (x, y, z) in bp] + [b.verts.new(V((-x, y, z)) + off) for (x, y, z) in reversed(bp)]
    f = b.faces.new(vs)
    b.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    hull.add(b, "site_alu", tag="deck", recalc=False)
    hull.add(box((0.14, 0.02, 0.04), V((0, hull_station(0.9)[4] + 0.005, -HL / 2 + 0.9 * HL)) + off, bevel=0.006), "site_alu")
    tb = 0.985
    ykb = hull_station(tb)[0]
    eye_y = ykb + 0.10
    hull.add(torus(0.025, 0.006, V((0, eye_y, -HL / 2 + tb * HL + 0.03)) + off, rot=(0, 90, 0), seg=10, sides=5), "site_galv")
    a.meta["bow_eye"] = [round(off.x, 3), round(eye_y + off.y, 3), round(-HL / 2 + tb * HL + 0.03 + off.z, 3)]
    for s in (-1, 1):
        hb = hull_station(0.0)[3]
        hull.add(sweep([V((s * (hb - 0.06), ys0 - 0.02, -HL / 2 - 0.002)) + off, V((s * (hb - 0.06), ys0 - 0.02, -HL / 2 - 0.06)) + off,
                        V((s * (hb - 0.16), ys0 - 0.02, -HL / 2 - 0.06)) + off, V((s * (hb - 0.16), ys0 - 0.02, -HL / 2 - 0.002)) + off],
                       0.01, 6), "site_alu")
        x_ol = s * (half_at((-0.1 + HL / 2) / HL, hull_station((-0.1 + HL / 2) / HL)[4]) + 0.0)
        ys_m = hull_station((0.15 + HL / 2) / HL)[4]
        hull.add(cyl(0.018, 0.018, V((x_ol, ys_m - 0.02, 0.15)) + off, V((x_ol, ys_m + 0.03, 0.15)) + off, 8), "site_galv")
        hull.add(sweep([V((x_ol, ys_m + 0.03, 0.15)) + off, V((x_ol, ys_m + 0.07, 0.12)) + off, V((x_ol, ys_m + 0.1, 0.15)) + off,
                        V((x_ol, ys_m + 0.07, 0.18)) + off, V((x_ol, ys_m + 0.03, 0.15)) + off], 0.007, 5), "site_galv")
    hull.add(cyl(0.02, 0.02, V((0.2, 0.04, -HL / 2 - 0.0)) + off, V((0.2, 0.04, -HL / 2 - 0.02)) + off, 8), "site_galv")
    if outboard:
        build_outboard(a, V((0, ys0, -HL / 2 - 0.05)) + off, tilt=tilt)
    return hull


def build_outboard(a, clamp, tilt=0.0, name="boat_outboard"):
    """a 9.9 hp class tiller outboard (15 in shaft) hung on the transom; clamp = top of the transom at the clamp. The node
    pivots on the tilt tube, so rot x tilts it (the boat on the trailer has it tilted up)."""
    p = V(clamp)
    o = a.node(name, pivot=p, rot=(tilt, 0, 0))
    def P(x, y, z):
        return p + V((x, y, z))
    # clamp bracket over the transom top, screw handles
    o.add(box((0.16, 0.22, 0.05), P(0, -0.07, 0.03), bevel=0.01), "site_alu")
    o.add(box((0.16, 0.05, 0.12), P(0, 0.02, -0.01), bevel=0.01), "site_alu")
    for s in (-1, 1):
        o.add(cyl(0.012, 0.012, P(s * 0.05, -0.1, 0.06), P(s * 0.05, -0.1, 0.13), 6), "site_galv")
        o.add(box((0.06, 0.012, 0.012), P(s * 0.05, -0.1, 0.135)), "site_plastic_dark")
    # swivel and midsection, leg, cavitation plate, gearcase, skeg and propeller
    o.add(box((0.12, 0.16, 0.12), P(0, 0.0, -0.1), bevel=0.02, seg=2), "site_paint_black")
    leg_top, leg_bot = 0.04, -0.47
    sec = [(0.0, 0.085), (0.03, 0.05), (0.035, 0.0), (0.03, -0.06), (0.0, -0.085), (-0.03, -0.06), (-0.035, 0.0), (-0.03, 0.05)]
    rings = []
    for y in (leg_top, -0.15, -0.3, leg_bot):
        rings.append([P(u, y, -0.12 + v) for (u, v) in sec])
    o.add(loft(rings, True, True, True), "site_paint_black")
    o.add(box((0.2, 0.012, 0.26), P(0, leg_bot + 0.02, -0.14), bevel=0.004), "site_paint_black")
    o.add(sweep([P(0, leg_bot - 0.06, -0.01), P(0, leg_bot - 0.065, -0.1), P(0, leg_bot - 0.065, -0.2), P(0, leg_bot - 0.06, -0.27)],
                [0.03, 0.046, 0.046, 0.036], 10), "site_paint_black")
    b = bmesh.new()
    vs = [b.verts.new(P(0, leg_bot - 0.08, -0.06)), b.verts.new(P(0, leg_bot - 0.2, -0.12)), b.verts.new(P(0, leg_bot - 0.19, -0.2)),
          b.verts.new(P(0, leg_bot - 0.08, -0.22))]
    b.faces.new(vs)
    bmesh.ops.solidify(b, geom=b.faces[:], thickness=0.012)
    o.add(b, "site_paint_black")
    hub = P(0, leg_bot - 0.065, -0.28)
    o.add(cyl(0.03, 0.022, hub, hub + V((0, 0, -0.08)), 10), "site_paint_black")
    for k in range(3):
        ang = k * math.tau / 3
        d = V((math.cos(ang), math.sin(ang), 0))
        t = V((-math.sin(ang), math.cos(ang), 0))
        b = bmesh.new()
        c0 = hub + V((0, 0, -0.03)) + d * 0.025
        vs = [b.verts.new(c0 + t * 0.02 + V((0, 0, 0.02))), b.verts.new(c0 + d * 0.1 + t * 0.03 + V((0, 0, 0.0))),
              b.verts.new(c0 + d * 0.105 - t * 0.02 + V((0, 0, -0.03))), b.verts.new(c0 - t * 0.02 + V((0, 0, -0.03)))]
        b.faces.new(vs)
        bmesh.ops.solidify(b, geom=b.faces[:], thickness=0.005)
        o.add(b, "site_alu")
    # powerhead cowling (rounded) and lower cowl, latch, tiller handle with a rubber grip
    o.add(box((0.30, 0.16, 0.40), P(0, 0.14, -0.2), bevel=0.04, seg=2), "site_plastic_dark")
    o.add(box((0.31, 0.24, 0.44), P(0, 0.33, -0.21), bevel=0.08, seg=3), "site_plastic_dark")
    o.add(box((0.02, 0.06, 0.004), P(0, 0.26, 0.012)), "site_paint_white")
    o.add(cyl(0.014, 0.014, P(0, 0.15, 0.0), P(0.02, 0.22, 0.42), 8), "site_paint_black")
    o.add(cyl(0.022, 0.022, P(0.017, 0.2, 0.33), P(0.024, 0.225, 0.5), 10), "site_rubber")
    return o


def boat_aluminium_hull(variant="a"):
    painted = variant == "b"
    name = "boat_aluminium_hull" + ("_b" if painted else "")
    a = Asset(name, colour=hull_colour(painted), ao_dist=0.35, lod1=0.5, buried_ok=0.25,
              meta={"length": HL, "beam": 1.4, "draft": 0.12, "waterline_y": 0.12, "origin": "keel bottom, mid-length (the outboard's skeg reaches 0.17 m below it)",
                    "front": "+z is the bow", "variant": "bare aluminium" if not painted else "dark green topsides"},
              probes=[{"node": "boat_outboard", "axis": "z", "side": -1}], ground=False)
    build_hull(a, name, painted)
    # rename the hull node to the brief's name when this is the plain hull
    return a


def boat_outboard_alone():
    a = Asset("boat_outboard", colour=hull_colour(False), ao_dist=0.2, ground=False, buried_ok=0.75,
              meta={"origin": "the clamp, on the transom top", "front": "+z (tiller forward, into the boat)",
                    "tilt": "rotate the node about x by up to 70 degrees to tilt the leg up"})
    build_outboard(a, V((0, 0, 0)))
    return a


# ======================================================================================================== the trailer
TR_AX = -0.7          # axle z
TR_WX = 0.84          # wheel centre x


def trailer_colour(co, n, mat, node, tag):
    m = 0.92 + 0.12 * fbm(co, 2.0, 3, 6.0)
    c = (m, m, m)
    if mat == "site_galv":
        c = mix(c, (1.12, 1.12, 1.1), max(0.0, fbm(co, 7.0, 2, 3.0) - 0.15) * 0.7)       # white zinc bloom
        c = mix(c, (0.62, 0.42, 0.28), max(0.0, fbm(co, 5.0, 2, 9.0) - 0.45) * 1.2)      # rust at welds and scrapes
        c = mix(c, (0.62, 0.55, 0.45), smooth(0.35, 0.05, co.y) * 0.6)                 # road dirt low down
    if mat == "site_carpet":
        c = mix(c, (0.75, 0.7, 0.6), max(0.0, fbm(co, 3.0, 2, 2.0)) * 0.6)
    if mat == "site_rubber":
        c = mix(c, (2.4, 2.1, 1.7), smooth(0.08, 0.0, co.y) * 0.5)
    return c


def wheel(mesh, hub, side, R=0.265, w=0.12, rim=0.15):
    """a 4.80-12 trailer wheel: tyre turned from a section, galvanised rim, five nuts, hub cap. hub = centre."""
    hx, hy, hz = hub
    prof = [(rim, -w * 0.42), (rim + 0.02, -w * 0.5), (R - 0.04, -w * 0.52), (R - 0.01, -w * 0.45), (R, -w * 0.3), (R, w * 0.3),
            (R - 0.01, w * 0.45), (R - 0.04, w * 0.52), (rim + 0.02, w * 0.5), (rim, w * 0.42)]
    seg = 16
    rings = []
    for (r_, x_) in prof:
        rings.append([(hx + x_, hy + math.cos(k / seg * math.tau) * r_, hz + math.sin(k / seg * math.tau) * r_) for k in range(seg)])
    bm = loft(rings, True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    if sum(f.normal.dot(f.calc_center_median() - V(hub)) for f in bm.faces) < 0:
        for f in bm.faces:
            f.normal_flip()
    mesh.add(bm, "site_rubber", smooth=True, uv=lambda co, n: (math.atan2(co.z - hz, co.y - hy) * R, co.x - hx))
    # rim: a dished disc
    rp = [(rim, -w * 0.42), (rim - 0.01, -w * 0.3), (rim * 0.7, -w * 0.3 * side * 0 - 0.02 * side), (0.06, -0.035 * side),
          (0.06, 0.035 * side), (rim * 0.7, 0.02 * side), (rim - 0.01, w * 0.3), (rim, w * 0.42)]
    rings = [[(hx + x_, hy + math.cos(k / seg * math.tau) * r_, hz + math.sin(k / seg * math.tau) * r_) for k in range(seg)] for (r_, x_) in rp]
    bm = loft(rings, True)
    bm.normal_update()
    mesh.add(bm, "site_galv", smooth=True)
    cap_x = hx + side * 0.06
    mesh.add(cyl(0.045, 0.035, (hx, hy, hz), (cap_x, hy, hz), 12), "site_galv")
    mesh.add(cyl(0.02, 0.018, (cap_x, hy, hz), (cap_x + side * 0.02, hy, hz), 10), "site_galv")
    for k in range(5):
        ang = k / 5 * math.tau
        c = (hx + side * 0.03, hy + math.cos(ang) * 0.055, hz + math.sin(ang) * 0.055)
        mesh.add(cyl(0.011, 0.011, c, (c[0] + side * 0.025, c[1], c[2]), 6), "site_galv")


def build_trailer(a, with_strap_to=None):
    frame = a.node("boat_trailer_frame")
    bunks = a.node("boat_trailer_bunks")
    winch = a.node("boat_trailer_winch")
    hitch = a.node("boat_trailer_hitch")
    lights = a.node("boat_trailer_lights")
    y0, y1 = 0.40, 0.475
    ym = (y0 + y1) / 2
    # main rails (C-channel), A-frame, tongue
    for s in (-1, 1):
        frame.add(box((0.05, 0.075, 2.7), (s * 0.52, ym, -0.7)), "site_galv", grain=(0, 0, 1))
        a_ = V((s * 0.52, ym, 0.62)); b_ = V((s * 0.05, ym, 1.45))
        frame.add(box((0.05, 0.075, (b_ - a_).length + 0.06), (a_ + b_) / 2,
                      rot=(0, math.degrees(math.atan2(b_.x - a_.x, b_.z - a_.z)), 0)), "site_galv")
    frame.add(box((0.075, 0.075, 0.75), (0, ym, 1.62)), "site_galv", grain=(0, 0, 1))
    for z in (-2.03, -1.25, -0.25, 0.58):
        frame.add(box((1.09, 0.06, 0.06), (0, y0 + 0.03, z)), "site_galv")
    # springs and hangers on the axle, axle tube, hubs
    for s in (-1, 1):
        for k in range(3):
            frame.add(box((0.045, 0.012, 0.72 - k * 0.16), (s * 0.52, 0.315 + k * 0.013, TR_AX)), "site_galv")
        for dz in (-0.36, 0.36):
            frame.add(box((0.05, 0.08, 0.03), (s * 0.52, 0.355, TR_AX + dz)), "site_galv")
        frame.add(box((0.06, 0.05, 0.08), (s * 0.52, 0.29, TR_AX)), "site_galv")
    frame.add(cyl(0.03, 0.03, (-TR_WX + 0.07, 0.265, TR_AX), (TR_WX - 0.07, 0.265, TR_AX), 10), "site_galv")
    # fenders over the wheels with their brackets, amber side markers
    for s in (-1, 1):
        arc = []
        for k in range(13):
            t = math.radians(15 + 150 * k / 12)
            arc.append((s * TR_WX, 0.265 + math.sin(t) * 0.33, TR_AX + math.cos(t) * 0.33))
        frame.add(sweep(arc, 1.0, 4, section=[(-0.003, -0.1), (0.003, -0.1), (0.003, 0.1), (-0.003, 0.1)]), "site_galv")
        for dz in (-0.22, 0.22):
            frame.add(box((0.3, 0.03, 0.04), (s * 0.69, 0.51, TR_AX + dz)), "site_galv")
        frame.add(box((0.012, 0.035, 0.07), (s * (TR_WX + 0.102), 0.5, TR_AX + 0.31)), "site_lamp_amber")
    # bunks: carpeted timber, tilted in, on galvanised brackets
    for s in (-1, 1):
        for z in (-1.6, -0.2):
            frame.add(box((0.05, 0.12, 0.05), (s * 0.36, 0.535, z)), "site_galv")
        bunks.add(box((0.14, 0.04, 2.6), (s * 0.36, 0.615, -0.85), rot=(0, 0, s * -16), bevel=0.01), "site_carpet",
                  grain=(0, 0, 1))
    # the winch post, brace, bow stop roller, winch and strap
    winch.add(box((0.06, 0.6, 0.06), (0, 0.475 + 0.3, 1.55)), "site_galv")
    winch.add(box((0.05, 0.05, 0.62), (0, 0.66, 1.33), rot=(-32, 0, 0)), "site_galv")
    winch.add(box((0.18, 0.04, 0.05), (0, 1.06, 1.53)), "site_galv")
    for s in (-1, 1):
        winch.add(cyl(0.035, 0.03, (s * 0.01, 1.05, 1.49), (s * 0.08, 1.05, 1.49), 10), "site_rubber")
    winch.add(box((0.1, 0.12, 0.12), (0, 0.86, 1.47), bevel=0.01), "site_galv")
    winch.add(cyl(0.04, 0.04, (-0.06, 0.86, 1.44), (0.06, 0.86, 1.44), 12), "site_galv")
    winch.add(cyl(0.05, 0.05, (0.07, 0.86, 1.44), (0.085, 0.86, 1.44), 14), "site_galv")
    winch.add(box((0.012, 0.22, 0.025), (0.11, 0.78, 1.44)), "site_galv")
    winch.add(cyl(0.012, 0.012, (0.11, 0.68, 1.44), (0.18, 0.68, 1.44), 6), "site_plastic_dark")
    if with_strap_to is not None:
        e = V(with_strap_to)
        st = V((0, 0.86, 1.40))
        winch.add(sweep([st, st.lerp(e, 0.5) + V((0, -0.01, 0)), e + V((0, 0, 0.04))], 1.0, 4,
                        section=[(-0.025, -0.002), (0.025, -0.002), (0.025, 0.002), (-0.025, 0.002)]), "site_canvas_blue")
        winch.add(torus(0.02, 0.005, e + V((0, 0, 0.03)), rot=(90, 0, 0), seg=8, sides=4), "site_galv")
    else:
        winch.add(sweep([V((0, 0.86, 1.40)), V((0, 0.66, 1.38)), V((0, 0.5, 1.36))], 1.0, 4,
                        section=[(-0.025, -0.002), (0.025, -0.002), (0.025, 0.002), (-0.025, 0.002)]), "site_canvas_blue")
        winch.add(sweep([V((0, 0.5, 1.36)), V((0, 0.47, 1.35)), V((0, 0.47, 1.31))], 0.006, 5), "site_galv")
    # coupler, latch, safety chains, jack with caster
    hitch.add(box((0.1, 0.1, 0.32), (0, 0.45, 2.0), bevel=0.015), "site_galv")
    hitch.add(sphere(0.06, (0, 0.44, 2.12), (1.0, 0.8, 1.0), 12, 6), "site_galv")
    hitch.add(box((0.03, 0.03, 0.2), (0, 0.52, 1.98), rot=(-12, 0, 0)), "site_galv")
    for s in (-1, 1):
        pts = []
        for k in range(15):
            t = k / 14
            pts.append(V((s * (0.05 + 0.04 * t), 0.43 - 0.22 * math.sin(t * math.pi), 1.78 + 0.32 * t)))
        for k in range(14):
            c = (pts[k] + pts[k + 1]) / 2
            d = pts[k + 1] - pts[k]
            ang = math.degrees(math.atan2(d.y, d.z))
            hitch.add(torus(0.022, 0.0045, c, rot=(-ang, 90 if k % 2 else 0, 0), seg=6, sides=3), "site_galv")
    hitch.add(cyl(0.03, 0.03, (0.12, 0.1, 1.6), (0.12, 0.8, 1.6), 10), "site_galv")
    hitch.add(box((0.04, 0.06, 0.08), (0.08, 0.44, 1.6)), "site_galv")
    hitch.add(cyl(0.008, 0.008, (0.12, 0.8, 1.6), (0.12, 0.84, 1.6), 6), "site_galv")
    hitch.add(sweep([(0.12, 0.84, 1.6), (0.22, 0.84, 1.6), (0.22, 0.84, 1.66)], 0.008, 5), "site_galv")
    hitch.add(box((0.05, 0.05, 0.1), (0.12, 0.1, 1.6)), "site_galv")
    wheel_c = a.node("boat_trailer_jack_caster")
    wheel_c.add(cyl(0.07, 0.07, (0.1, 0.07, 1.6), (0.14, 0.07, 1.6), 12), "site_rubber")
    # rear light bar with the two tail lamps (lens material site_lamp_red), a blank plate, red reflectors
    lights.add(box((1.5, 0.05, 0.05), (0, 0.43, -2.07)), "site_galv")
    for s in (-1, 1):
        lights.add(box((0.14, 0.1, 0.05), (s * 0.68, 0.43, -2.09), bevel=0.01), "site_plastic_dark")
        lights.add(box((0.12, 0.08, 0.008), (s * 0.68, 0.43, -2.117)), "site_lamp_red")
    lights.add(box((0.32, 0.16, 0.006), (-0.3, 0.32, -2.1)), "site_paint_white")
    lights.add(box((0.04, 0.12, 0.02), (-0.3, 0.38, -2.09)), "site_galv")
    for wn, side in (("boat_trailer_wheel_l", -1), ("boat_trailer_wheel_r", 1)):
        w = a.node(wn, pivot=(side * TR_WX, 0.265, TR_AX))
        wheel(w, (side * TR_WX, 0.265, TR_AX), side)


def boat_trailer():
    a = Asset("boat_trailer", colour=trailer_colour, ao_dist=0.35, lod1=0.5,
              meta={"length": 4.2, "axle_z": TR_AX, "wheel_radius": 0.265, "origin": "ground, middle of the length",
                    "front": "+z (the hitch)", "bunk_top_y": 0.635,
                    "wheels": "boat_trailer_wheel_l / _r pivot on the hub, axle along x"},
              probes=[{"node": "boat_trailer_hitch", "axis": "z", "side": 1}, {"node": "boat_trailer_lights", "axis": "z", "side": -1}])
    build_trailer(a)
    return a


def boat_trailer_hull(covered=False):
    name = "boat_trailer_hull" + ("_covered" if covered else "")
    col_h = hull_colour(True)
    def colour(co, n, mat, node, tag):
        if node.startswith("boat_trailer"):
            return trailer_colour(co, n, mat, node, tag)
        if node == "boat_cover_tarp":
            return tarp_colour(co, n, mat, node, tag)
        return col_h(co, n, mat, node, tag)
    a = Asset(name, colour=colour, ao_dist=0.35, lod1=0.5,
              meta={"origin": "ground, middle of the trailer", "front": "+z (the hitch, the bow)",
                    "note": "the green-topsided hull on the bunks, outboard tilted up, strap to the bow eye"},
              probes=[{"node": "boat_trailer_hitch", "axis": "z", "side": 1}])
    # sit the hull on the bunks: find the lift that brings the hull bottom onto the bunk tops (y 0.635 at |x| 0.36)
    zc = 1.47 - HL / 2
    lift = 0.0
    for k in range(25):
        z = -2.1 + k * 0.1
        if -2.15 <= z <= 0.45 and abs(z - zc) < HL / 2 - 0.05:
            lift = max(lift, 0.637 - hull_bottom_y(0.36, z - zc))
    off = V((0, lift, zc))
    hull = build_hull(a, "boat_aluminium_hull_b", True, off, outboard=True, tilt=62.0)
    build_trailer(a, with_strap_to=a.meta["bow_eye"])
    if covered:
        build_tarp(a, off)
    return a


# ======================================================================================================== working detail (P1)
def wood_colour(co, n, mat, node, tag):
    m = 0.9 + 0.15 * fbm(co, 2.5, 3, 4.0)
    c = (m, m, m)
    c = mix(c, (0.6, 0.56, 0.5), smooth(0.25, -0.05, co.y))
    c = mix(c, (0.86, 0.95, 0.72), max(0.0, fbm(co, 3.0, 2, 1.0) - 0.3))
    if mat in ("site_galv", "site_iron"):
        c = mix(c, (0.7, 0.5, 0.36), max(0.0, fbm(co, 5.0, 2, 3.0) - 0.2))
    return c


def boat_launch_bollard():
    a = Asset("boat_launch_bollard", colour=wood_colour, buried_ok=0.35, ao_dist=0.3,
              meta={"note": "one 220 mm timber bollard, 1.0 m out of the ground"})
    b = a.node("boat_launch_bollard")
    b.add(cyl(0.11, 0.105, (0, -0.3, 0), (0, 0.92, 0), 12), "site_timber", grain=(0, 1, 0), uv='cyl')
    b.add(cyl(0.105, 0.06, (0, 0.92, 0), (0, 1.0, 0), 12), "site_timber", grain=(0, 1, 0), uv='cyl')
    b.add(cyl(0.113, 0.113, (0, 0.72, 0), (0, 0.76, 0), 12), "site_galv")
    return a


def boat_launch_bollards():
    a = Asset("boat_launch_bollards", colour=wood_colour, buried_ok=0.35, ao_dist=0.3,
              meta={"note": "the pair at the ramp head, 7.8 m apart (either side of the curbs)"})
    for s, nm in ((-1, "boat_launch_bollard_l"), (1, "boat_launch_bollard_r")):
        b = a.node(nm)
        x = s * 3.9
        b.add(cyl(0.11, 0.105, (x, -0.3, 0), (x, 0.92, 0), 12), "site_timber", grain=(0, 1, 0), uv='cyl')
        b.add(cyl(0.105, 0.06, (x, 0.92, 0), (x, 1.0, 0), 12), "site_timber", grain=(0, 1, 0), uv='cyl')
        b.add(cyl(0.113, 0.113, (x, 0.72, 0), (x, 0.76, 0), 12), "site_galv")
    return a


def boat_launch_wheel_stop():
    a = Asset("boat_launch_wheel_stop", colour=wood_colour, buried_ok=0.05, ao_dist=0.25,
              meta={"note": "an old railway sleeper pinned at the apron edge, 2.0 m"})
    b = a.node("boat_launch_wheel_stop")
    b.add(box((2.0, 0.13, 0.24), (0, 0.055, 0), bevel=0.02), "site_timber", grain=(1, 0, 0))
    for x in (-0.8, 0.8):
        b.add(cyl(0.018, 0.018, (x, 0.1, 0), (x, 0.13, 0), 8), "site_iron")
    return a


def boat_mooring_rope():
    a = Asset("boat_mooring_rope", ao_dist=0.08, colour=lambda co, n, m, nd, t: (0.95 + 0.1 * fbm(co, 8, 2, 1), 0.95, 0.9))
    r = a.node("boat_mooring_rope")
    pts = []
    turns = 4.2
    for k in range(int(turns * 16)):
        t = k / 16 * math.tau
        rr = 0.12 + 0.028 * t / math.tau
        pts.append((math.cos(t) * rr, 0.009 + 0.004 * math.sin(t * 3.0) + 0.002 * (k % 2), math.sin(t) * rr))
    t_end = pts[-1]
    for k in range(1, 12):
        pts.append((t_end[0] + 0.05 * k, 0.009, t_end[2] + 0.02 * math.sin(k * 0.8)))
    r.add(sweep(pts, 0.009, 5), "site_rope", smooth=True)
    return a


def boat_fuel_tank():
    def col(co, n, m, nd, t):
        c = (1.0, 1.0, 1.0)
        if m == "site_plastic_red":
            c = mix(c, (0.75, 0.7, 0.65), smooth(0.05, 0.0, co.y) * 0.6)
            c = mix(c, (1.15, 1.1, 1.05), max(0.0, fbm(co, 4, 2, 2)) * 0.4)
        return c
    a = Asset("boat_fuel_tank", colour=col, ao_dist=0.12,
              meta={"note": "25 L portable outboard tank with gauge, cap and a fuel line with primer bulb"})
    t = a.node("boat_fuel_tank")
    t.add(box((0.33, 0.24, 0.52), (0, 0.12, 0), bevel=0.04, seg=2), "site_plastic_red")
    for x in (-0.06, 0.06):
        t.add(box((0.02, 0.07, 0.2), (x, 0.27, -0.05), bevel=0.008), "site_plastic_red")
    t.add(box((0.14, 0.02, 0.2), (0, 0.305, -0.05), bevel=0.008), "site_plastic_red")
    t.add(cyl(0.035, 0.035, (0.08, 0.24, 0.17), (0.08, 0.27, 0.17), 12), "site_plastic_dark")
    t.add(cyl(0.03, 0.03, (-0.08, 0.24, 0.17), (-0.08, 0.255, 0.17), 12), "site_paint_white")
    t.add(cyl(0.015, 0.015, (0.0, 0.2, 0.26), (0.0, 0.2, 0.29), 8), "site_plastic_dark")
    hose = [(0.0, 0.2, 0.29), (0.05, 0.16, 0.35), (0.15, 0.04, 0.36), (0.25, 0.012, 0.3), (0.3, 0.012, 0.12), (0.26, 0.012, -0.1),
            (0.15, 0.012, -0.3), (0.0, 0.012, -0.34)]
    t.add(sweep(hose, 0.007, 6), "site_plastic_dark", smooth=True)
    t.add(sweep([(0.29, 0.03, 0.18), (0.295, 0.03, 0.12), (0.29, 0.03, 0.06)], [0.012, 0.024, 0.012], 8), "site_plastic_dark", smooth=True)
    return a


def boat_paddle():
    a = Asset("boat_paddle", colour=lambda co, n, m, nd, t: mix((1.0, 0.98, 0.95), (0.62, 0.6, 0.55), smooth(0.25, 0.0, co.y)),
              ao_dist=0.05, ground=True,
              meta={"length": 2.1, "origin": "the blade tip", "note": "a 7 ft wooden oar standing on its blade tip; tilt it "
                                                                       "about x to lean it against the sign post"})
    o = a.node("boat_paddle")
    # blade (a flat, slightly dished spoon), loom and handle along +y
    sec_blade = [(-0.075, 0.0), (-0.07, 0.008), (0.0, 0.012), (0.07, 0.008), (0.075, 0.0), (0.07, -0.006), (0.0, -0.009), (-0.07, -0.006)]
    rings = []
    for (y, w) in ((0.0, 0.55), (0.04, 0.85), (0.15, 1.0), (0.4, 1.0), (0.52, 0.7), (0.62, 0.3)):
        rings.append([(u * w, y, v * (0.6 + 0.4 * w)) for (u, v) in sec_blade])
    o.add(loft(rings, True, True, True), "site_board", grain=(0, 1, 0))
    o.add(cyl(0.021, 0.019, (0, 0.6, 0), (0, 1.9, 0), 10), "site_board", grain=(0, 1, 0))
    o.add(cyl(0.024, 0.024, (0, 1.3, 0), (0, 1.55, 0), 10), "site_rope")                    # leather / cord leather wrap
    o.add(cyl(0.017, 0.016, (0, 1.9, 0), (0, 2.1, 0), 10), "site_board", grain=(0, 1, 0))
    return a


def boat_launch_marker():
    a = Asset("boat_launch_marker", buried_ok=1.6, ao_dist=0.2,
              colour=lambda co, n, m, nd, t: mix(mix((1, 1, 1), (0.45, 0.5, 0.36), smooth(0.25, -0.1, co.y)),
                                                 (0.7, 0.66, 0.6), max(0.0, fbm(co, 4, 2, 3)) * 0.4),
              meta={"origin": "the water surface (or the shore); 1.5 m stands in the water below",
                    "note": "white PVC marker post with a red reflective top band"})
    m = a.node("boat_launch_marker")
    m.add(cyl(0.08, 0.08, (0, -1.5, 0), (0, 1.5, 0), 12), "site_plastic_white", grain=(0, 1, 0), uv='cyl')
    m.add(cyl(0.083, 0.083, (0, 1.2, 0), (0, 1.45, 0), 12), "site_paint_red")
    m.add(cyl(0.083, 0.083, (0, 1.05, 0), (0, 1.12, 0), 12), "site_reflector")
    m.add(cyl(0.085, 0.085, (0, 1.5, 0), (0, 1.53, 0), 12), "site_plastic_white")
    return a


def boat_launch_bin():
    def col(co, n, m, nd, t):
        c = wood_colour(co, n, m, nd, t)
        if m == "site_paint_green":
            c = mix((1, 1, 1), (0.72, 0.5, 0.36), max(0.0, fbm(co, 5, 2, 7) - 0.25) * 1.2)
        return c
    a = Asset("boat_launch_bin", colour=col, buried_ok=0.35, ao_dist=0.3,
              meta={"note": "green steel drum bin with a lid in a two-post timber frame"})
    b = a.node("boat_launch_bin")
    b.add(cyl(0.29, 0.29, (0, 0.12, 0), (0, 0.98, 0), 18), "site_paint_green", uv='cyl', grain=(0, 1, 0))
    for y in (0.35, 0.75):
        b.add(cyl(0.298, 0.298, (0, y, 0), (0, y + 0.025, 0), 18), "site_paint_green")
    b.add(cyl(0.31, 0.24, (0, 0.98, 0), (0, 1.06, 0), 18), "site_paint_green")
    b.add(cyl(0.05, 0.05, (0, 1.06, 0), (0, 1.09, 0), 8), "site_paint_green")
    for s in (-1, 1):
        b.add(box((0.1, 1.35, 0.1), (s * 0.42, 0.5, 0), bevel=0.006), "site_timber", grain=(0, 1, 0))
        b.add(box((0.14, 0.04, 0.05), (s * 0.355, 0.85, 0)), "site_galv")
    return a


def boat_launch_notice_board():
    def col(co, n, m, nd, t):
        c = wood_colour(co, n, m, nd, t)
        if m == "site_paper":
            c = mix((1, 1, 1), (0.85, 0.8, 0.6), max(0.0, fbm(co, 3, 2, t or 1)) * 0.8)
        return c
    a = Asset("boat_launch_notice_board", colour=col, buried_ok=0.45, ao_dist=0.3,
              meta={"note": "a roofed timber notice board, blank pinned sheets (no text)"},
              probes=[{"node": "boat_launch_notice_board", "mat": "site_paper", "dir": [0, 0, 1]}])
    b = a.node("boat_launch_notice_board")
    for s in (-1, 1):
        post(b, s * 0.7, 0.0, 2.15, w=0.1, tag=s, cap=False)
    b.add(box((1.32, 0.95, 0.03), (0, 1.55, 0.065), bevel=0.004), "site_board", grain=(1, 0, 0))
    for (w, h, x, y) in ((1.4, 0.05, 0, 2.03), (1.4, 0.05, 0, 1.07), (0.05, 1.0, -0.68, 1.55), (0.05, 1.0, 0.68, 1.55)):
        b.add(box((w, h, 0.05), (x, y, 0.09), bevel=0.004), "site_timber", grain=(1, 0, 0) if w > h else (0, 1, 0))
    b.add(box((1.6, 0.025, 0.42), (0, 2.18, 0.06), rot=(14, 0, 0), bevel=0.004), "site_board", grain=(1, 0, 0))
    b.add(box((1.6, 0.025, 0.42), (0, 2.18, -0.3), rot=(-14, 0, 0), bevel=0.004), "site_board", grain=(1, 0, 0))
    rnd = random.Random(4)
    for k, (x, y, w, h) in enumerate(((-0.35, 1.75, 0.3, 0.42), (0.05, 1.8, 0.21, 0.3), (0.38, 1.7, 0.3, 0.21), (-0.2, 1.3, 0.21, 0.3),
                                      (0.3, 1.35, 0.3, 0.42))):
        b.add(box((w, h, 0.002), (x, y, 0.082), rot=(0, 0, rnd.uniform(-4, 4))), "site_paper", tag=k + 1,
              mat_fn=lambda c, n: "site_paper" if n.z > 0.5 else "site_board")
        b.add(cyl(0.006, 0.006, (x, y + h / 2 - 0.02, 0.082), (x, y + h / 2 - 0.02, 0.088), 6), "site_paint_red")
    return a


# ======================================================================================================== atmosphere (P2)
def tarp_colour(co, n, mat, node, tag):
    f = max(0.0, fbm(co, 1.2, 3, 2.0))
    c = mix((1.0, 1.0, 1.0), (1.35, 1.3, 1.2), f * 0.6)         # sun-faded patches
    c = mix(c, (0.7, 0.68, 0.6), smooth(0.2, -0.2, n.y) * 0.3)
    return c


def build_tarp(a, off):
    """a faded blue cover over the hull: hugs the topsides down to just below the gunwale, sags between the seats, tied
    down with rope to the hull rails"""
    t = a.node("boat_cover_tarp", pivot=off)
    nst = 20
    rings = []
    for i in range(nst):
        tt = 0.02 + i / (nst - 1) * 0.955
        yk, bc, yc, bg, ys = hull_station(tt)
        z = -HL / 2 + tt * HL
        sag = 0.06 * math.sin(tt * math.pi * 3.0) ** 2 + 0.03
        across = 9
        ring = []
        ring.append((-(bg + 0.03), ys - 0.1, z))
        ring.append((-(bg + 0.035), ys + 0.02, z))
        for j in range(across):
            u = -1 + 2 * j / (across - 1)
            ring.append((u * bg * 0.92, ys + 0.03 + (0.1 - sag) * (1 - u * u) + 0.02, z))
        ring.append(((bg + 0.035), ys + 0.02, z))
        ring.append(((bg + 0.03), ys - 0.1, z))
        rings.append([V(p) + off for p in ring])
    bm = loft(rings, close_ring=False)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
    bm.normal_update()
    t.add(bm, "site_canvas_blue", smooth=True)
    for i in range(4):
        tt = 0.15 + i * 0.22
        yk, bc, yc, bg, ys = hull_station(tt)
        z = -HL / 2 + tt * HL
        path = [V((-(bg + 0.04), ys - 0.06, z)), V((-(bg + 0.04), ys + 0.04, z))]
        for j in range(7):
            u = -1 + 2 * j / 6
            path.append(V((u * bg * 0.92, ys + 0.03 + 0.1 * (1 - u * u) + 0.03, z)))
        path += [V((bg + 0.04, ys + 0.04, z)), V((bg + 0.04, ys - 0.06, z))]
        t.add(sweep([p + off for p in path], 0.006, 5), "site_rope")


def boat_cover_tarp():
    a = Asset("boat_cover_tarp", colour=tarp_colour, ground=False, ao_dist=0.2,
              meta={"origin": "the hull's origin (keel bottom, mid-length): add it as a child of the hull",
                    "note": "fits boat_aluminium_hull and _b"})
    build_tarp(a, V((0, 0, 0)))
    return a


def boat_fishing_box():
    def col(co, n, m, nd, t):
        return mix((1, 1, 1), (0.8, 0.76, 0.7), max(0.0, fbm(co, 6, 2, 2)) * 0.5)
    a = Asset("boat_fishing_box", colour=col, ao_dist=0.1,
              meta={"note": "a green tackle box (closed) and a two-piece spinning rod with reel; no hooks shown"})
    b = a.node("boat_fishing_box")
    b.add(box((0.42, 0.16, 0.22), (0, 0.08, 0), bevel=0.012), "site_plastic_green")
    b.add(box((0.43, 0.05, 0.23), (0, 0.185, 0), bevel=0.015), "site_plastic_green")
    b.add(sweep([(-0.08, 0.21, 0), (-0.06, 0.25, 0), (0.06, 0.25, 0), (0.08, 0.21, 0)], 0.01, 6), "site_plastic_dark")
    for x in (-0.15, 0.15):
        b.add(box((0.04, 0.03, 0.012), (x, 0.16, 0.118)), "site_galv")
    r = a.node("boat_fishing_rod")
    r.add(cyl(0.012, 0.003, (0.35, 0.012, -0.5), (0.4, 0.012, 1.6), 6), "site_plastic_dark")
    r.add(cyl(0.016, 0.014, (0.35, 0.016, -0.5), (0.355, 0.016, -0.2), 8), "site_carpet")
    r.add(box((0.05, 0.06, 0.05), (0.35, 0.05, -0.12)), "site_plastic_dark")
    r.add(cyl(0.03, 0.03, (0.32, 0.06, -0.12), (0.38, 0.06, -0.12), 12), "site_galv")
    return a


def boat_launch_gate(open_deg=96.0):
    a = Asset("boat_launch_gate", colour=wood_colour, buried_ok=0.6, ao_dist=0.35,
              meta={"width": 3.6, "origin": "middle of the opening, on the ground", "front": "+z (the lane outside)",
                    "note": "boat_launch_gate_leaf pivots on the hanging post (x = -1.9); exported open %.0f degrees, set its "
                            "rotation.y to 0 to close" % open_deg})
    p = a.node("boat_launch_gate_posts")
    for s in (-1, 1):
        post(p, s * 1.95, 0.0, 1.45, w=0.18, tag=s)
    leaf = a.node("boat_launch_gate_leaf", pivot=(-1.85, 0, 0), rot=(0, -open_deg, 0))
    x0, x1 = -1.83, 1.83
    for y in (0.25, 0.48, 0.71, 0.94, 1.17):
        leaf.add(box((x1 - x0, 0.09, 0.04), ((x0 + x1) / 2, y, 0), bevel=0.004), "site_timber", grain=(1, 0, 0), tag=int(y * 10))
    for x in (x0 + 0.05, -0.2, x1 - 0.05):
        leaf.add(box((0.09, 1.05, 0.045), (x, 0.71, 0.04 if x > x0 + 0.1 else -0.04), bevel=0.004), "site_timber", grain=(0, 1, 0))
    d0, d1 = V((x0 + 0.1, 0.27, 0.042)), V((x1 - 0.15, 1.15, 0.042))
    leaf.add(box((0.08, 0.035, (d1 - d0).length), (d0 + d1) / 2, rot=(0, 90, math.degrees(math.atan2(d1.y - d0.y, d1.x - d0.x))),
                 bevel=0.003), "site_timber")
    for y in (0.3, 1.1):
        leaf.add(box((0.5, 0.04, 0.008), (x0 + 0.25, y, 0.026)), "site_iron")
        p.add(cyl(0.014, 0.014, (-1.95 + 0.09, y - 0.08, 0.0), (-1.95 + 0.09, y + 0.05, 0.0), 6), "site_iron")
        p.add(box((0.06, 0.03, 0.03), (-1.95 + 0.06, y - 0.06, 0.0)), "site_iron")
    leaf.add(box((0.12, 0.05, 0.03), (x1 - 0.05, 0.94, 0.03)), "site_galv")
    return a


def boat_launch_weather_post():
    def col(co, n, m, nd, t):
        c = (1, 1, 1)
        if m == "site_canvas_orange":
            c = mix(c, (1.2, 1.15, 1.1), max(0.0, fbm(co, 3, 2, 2)) * 0.5)
        return c
    a = Asset("boat_launch_weather_post", colour=col, ao_dist=0.15, buried_ok=0.0,
              meta={"origin": "the foot of the mast where it is clamped to a post (bolt it to the sign post at about 2.2 m)",
                    "note": "1.4 m galvanised mast, a wind sock on a swivel (node boat_launch_windsock: turn it about y to the "
                            "wind), a rain gauge on a bracket"})
    m = a.node("boat_launch_weather_post")
    m.add(cyl(0.022, 0.02, (0, 0, 0), (0, 1.4, 0), 10), "site_galv")
    for y in (0.08, 0.5):
        m.add(box((0.08, 0.05, 0.06), (0, y, -0.04)), "site_galv")
    m.add(box((0.3, 0.02, 0.04), (0.15, 0.62, 0)), "site_galv")
    m.add(cyl(0.05, 0.05, (0.28, 0.6, 0), (0.28, 0.85, 0), 14), "site_glass")
    m.add(cyl(0.065, 0.05, (0.28, 0.85, 0), (0.28, 0.9, 0), 14), "site_plastic_dark")
    s = a.node("boat_launch_windsock", pivot=(0, 1.4, 0))
    s.add(cyl(0.03, 0.03, (0, 1.38, 0), (0, 1.46, 0), 8), "site_galv")
    s.add(torus(0.15, 0.008, (0.0, 1.42, 0.17), rot=(0, 0, 0), seg=14, sides=4), "site_galv")
    s.add(box((0.02, 0.02, 0.18), (0, 1.42, 0.085)), "site_galv")
    rings = []
    for k in range(9):
        t = k / 8
        r = 0.15 * (1 - 0.6 * t)
        droop = -0.35 * t ** 2
        rings.append([(math.cos(j / 12 * math.tau) * r, 1.42 + math.sin(j / 12 * math.tau) * r + droop, 0.17 + t * 0.9)
                      for j in range(12)])
    bm = loft(rings, True)
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.003)
    s.add(bm, "site_canvas_orange", smooth=True,
          mat_fn=lambda c, n: "site_canvas_orange" if int((c.z - 0.17) / 0.18) % 2 == 0 else "site_paint_white")
    return a


def boat_launch_damage_decals():
    a = Asset("boat_launch_damage_decals", ao_strength=0.0, ground=False,
              float_ok=["decal_rust_run", "decal_algae", "decal_waterline", "decal_crack_flat", "decal_oil_flat"],
              meta={"note": "alpha decals as separate nodes, each a quad facing +z (stand them on walls) or lying flat "
                            "(names ending _flat): rust run 0.3 x 0.6, algae 1.0 x 0.5, waterline 1.5 x 0.5, concrete crack "
                            "1.2 x 1.2 (flat), oil stain 0.9 x 0.9 (flat). Place 5 mm proud of the surface."})
    def quad(node, w, h, flat, mat):
        b = bmesh.new()
        if flat:
            pts = [(-w / 2, 0.005, h / 2), (w / 2, 0.005, h / 2), (w / 2, 0.005, -h / 2), (-w / 2, 0.005, -h / 2)]
            uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        else:
            pts = [(-w / 2, h, 0), (w / 2, h, 0), (w / 2, 0, 0), (-w / 2, 0, 0)]
            uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        vs = [b.verts.new(p) for p in pts]
        f = b.faces.new(vs)
        b.normal_update()
        if flat and f.normal.y < 0:
            f.normal_flip(); uvs = list(reversed(uvs))
        if not flat and f.normal.z < 0:
            f.normal_flip(); uvs = list(reversed(uvs))
        uvl = b.loops.layers.uv.new("UVMap")
        for l, uv in zip(f.loops, uvs):
            l[uvl].uv = (uv[0], 1 - uv[1])
        a.node(node).add(b, mat, keep_uv=True, recalc=False)
    quad("decal_rust_run", 0.3, 0.6, False, "site_decal_rust")
    quad("decal_algae", 1.0, 0.5, False, "site_decal_algae")
    quad("decal_waterline", 1.5, 0.5, False, "site_decal_waterline")
    quad("decal_crack_flat", 1.2, 1.2, True, "site_decal_crack")
    quad("decal_oil_flat", 0.9, 0.9, True, "site_decal_oil")
    return a


LAUNCH = [boat_ramp, boat_parking_gravel, boat_dock, boat_launch_sign, boat_life_ring, lambda: boat_aluminium_hull("a"),
          lambda: boat_aluminium_hull("b"), boat_outboard_alone, boat_trailer, lambda: boat_trailer_hull(False),
          lambda: boat_trailer_hull(True), boat_launch_bollard, boat_launch_bollards, boat_launch_wheel_stop, boat_mooring_rope,
          boat_fuel_tank, boat_paddle, boat_launch_marker, boat_launch_bin, boat_launch_notice_board, boat_launch_gravel_patch,
          boat_cover_tarp, boat_fishing_box, boat_launch_gate, boat_launch_weather_post, boat_launch_damage_decals]
