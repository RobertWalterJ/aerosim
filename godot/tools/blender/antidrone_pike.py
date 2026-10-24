# Harlan Pike's ridge: the jammer site, the shack and the land (lane/antidrone). Game frame: x right, y up, +z the front.
# Homemade and slightly broken, not military hardware. No weapons (the brief's shotgun prop is deliberately left out), no
# readable text, no insignia. Text faces (manifesto, warning sign) are blank and their rectangles are in meta.text_rect.
import math, random
from mathutils import Vector as V
import antidrone_lib as A
from antidrone_lib import (AD, box, grid_box, cyl, sphere, torus, sweep, loft, grid, disc_patch, rock, quad, uv01, wheel,
                           tube_path, sag, rust_colour, fbm, mix, smooth)

MAST_TOP = 14.0


# ============================================================================================ the mast (shared)
def mast_parts(a, y0, z0, parent=None, guys=True, beacon=True):
    """telescopic galvanised mast standing at (0, y0, z0), top at MAST_TOP above the ground: nodes mast (hinge at the
    foot, lowers about x), mast_stage_2, mast_stage_3 (telescope along y from their feet), dish (turns about y on the
    mast axis), beacon (caged red lamp), guy_wires (top level: hide them when the mast comes down)."""
    top = MAST_TOP
    L = top - y0
    s1a, s1b = y0, y0 + L * 0.40
    s2a, s2b = s1b - 0.3, y0 + L * 0.72
    s3a, s3b = s2b - 0.3, top - 0.22
    c = V((0, 0, z0))
    m1 = a.node("mast", pivot=(0, y0, z0))
    if parent:
        a.parents["mast"] = parent
    # hinge foot: two cheek plates, a pin and the base socket
    m1.add(box((0.24, 0.02, 0.2), (0, y0 + 0.01, z0)), "ad_steel_dark")
    for s in (-1, 1):
        m1.add(box((0.012, 0.16, 0.16), (s * 0.095, y0 + 0.09, z0)), "ad_rust")
    m1.add(cyl(0.012, 0.012, (-0.12, y0 + 0.1, z0), (0.12, y0 + 0.1, z0), seg=8), "ad_galv")
    m1.add(cyl(0.085, 0.085, c + V((0, y0 + 0.04, 0)), c + V((0, y0 + 0.22, 0)), seg=12), "ad_steel_dark")
    m1.add(cyl(0.075, 0.075, c + V((0, s1a + 0.2, 0)), c + V((0, s1b, 0)), seg=12), "ad_galv", smooth=True, uv='cyl', grain=(0, 1, 0))
    m1.add(cyl(0.095, 0.095, c + V((0, s1b - 0.14, 0)), c + V((0, s1b, 0)), seg=12), "ad_steel_dark")
    # clamp lever on the collar, a winch box and the cable down the mast to a junction box at the foot
    m1.add(box((0.03, 0.03, 0.16), (0.1, s1b - 0.07, z0 + 0.06), rot=(0, 25, 0)), "ad_paint_red")
    m1.add(box((0.14, 0.16, 0.1), (0, y0 + 0.9, z0 + 0.12), bevel=0.01), "ad_trailer_paint")
    m1.add(cyl(0.045, 0.045, (-0.08, y0 + 0.9, z0 + 0.2), (0.08, y0 + 0.9, z0 + 0.2), seg=10), "ad_galv")
    pts = [V((0.11, y0 + 0.35, z0 + 0.02))]
    for i in range(1, 9):
        pts.append(V((0.105 + 0.006 * math.sin(i * 1.7), y0 + 0.35 + (s1b - 0.6 - y0) * i / 8, z0 + 0.03 * math.cos(i * 1.3))))
    tube_path(pts, 0.008, "ad_cable", m1)
    for i in range(1, 8):
        y = y0 + 0.35 + (s1b - 0.6 - y0) * i / 8
        m1.add(torus(0.082, 0.004, (0, y, z0), rot=(90, 0, 0), seg=14, sides=4), "ad_cable")      # cable ties
    m2 = a.node("mast_stage_2", pivot=(0, s2a, z0))
    a.parents["mast_stage_2"] = "mast"
    m2.add(cyl(0.058, 0.058, c + V((0, s2a, 0)), c + V((0, s2b, 0)), seg=12), "ad_galv", smooth=True, uv='cyl', grain=(0, 1, 0))
    m2.add(cyl(0.076, 0.076, c + V((0, s2b - 0.12, 0)), c + V((0, s2b, 0)), seg=12), "ad_steel_dark")
    m2.add(box((0.026, 0.026, 0.13), (0.085, s2b - 0.06, z0 + 0.05), rot=(0, 30, 0)), "ad_paint_red")
    if guys:
        m2.add(torus(0.08, 0.012, (0, s2b - 0.3, z0), rot=(90, 0, 0), seg=14, sides=5), "ad_galv")     # guy ring
    m3 = a.node("mast_stage_3", pivot=(0, s3a, z0))
    a.parents["mast_stage_3"] = "mast_stage_2"
    m3.add(cyl(0.042, 0.042, c + V((0, s3a, 0)), c + V((0, s3b, 0)), seg=10), "ad_galv", smooth=True, uv='cyl', grain=(0, 1, 0))
    m3.add(box((0.3, 0.02, 0.3), (0, s3b + 0.01, z0)), "ad_steel_dark")                   # head plate
    # three homemade panel antennas round the upper mast and two whips: the jammer itself
    for k in range(3):
        ang = math.radians(90 + k * 120)
        d = V((math.cos(ang), 0, math.sin(ang)))
        pc = c + V((0, s3b - 1.75, 0)) + d * 0.2
        m3.add(box((0.05, 0.42, 0.13), pc, rot=(0, -math.degrees(ang), 0), bevel=0.01), "ad_plastic_grey")
        m3.add(box((0.15, 0.03, 0.03), c + V((0, s3b - 1.6, 0)) + d * 0.09, rot=(0, -math.degrees(ang), 0)), "ad_steel_dark")
        m3.add(box((0.15, 0.03, 0.03), c + V((0, s3b - 1.9, 0)) + d * 0.09, rot=(0, -math.degrees(ang), 0)), "ad_steel_dark")
    for s in (-1, 1):
        b0 = V((s * 0.12, s3b + 0.02, z0 - 0.1))
        m3.add(cyl(0.012, 0.012, b0, b0 + V((0, 0.06, 0)), seg=6), "ad_steel_dark")
        m3.add(cyl(0.005, 0.0025, b0 + V((0, 0.06, 0)), b0 + V((s * 0.05, 1.1, 0)), seg=5), "ad_plastic_dark")
    # the dish: 1.1 m, a shallow paraboloid on an arm, facing +z, feed on three struts; turns about the mast axis
    dy = s3b - 0.95
    dsh = a.node("dish", pivot=(0, dy, z0))
    a.parents["dish"] = "mast_stage_3"
    R, depth = 0.55, 0.16
    zc = z0 + 0.32
    rings = []
    nr, ns = 6, 20
    for i in range(nr + 1):
        rr = R * i / nr
        zz = zc - depth * (1 - (rr / R) ** 2) + depth            # rim at zc + ... ; vertex (centre) deepest
        zz = zc + depth * (rr / R) ** 2
        rings.append([V((math.cos(j / ns * math.tau) * max(rr, 1e-4), dy + math.sin(j / ns * math.tau) * max(rr, 1e-4), zz)) for j in range(ns)])
    front = loft(rings, close_ring=True)
    dsh.add(front, "ad_paint_white", smooth=True, recalc=False)
    back = [[p + V((0, 0, -0.012)) for p in r] for r in rings]
    bk = loft(back, close_ring=True)
    for f in bk.faces:
        f.normal_flip()
    dsh.add(bk, "ad_paint_white", smooth=True, recalc=False)
    dsh.add(torus(R, 0.012, (0, dy, zc + depth - 0.006), seg=24, sides=5), "ad_paint_white")       # rolled rim
    dsh.add(cyl(0.03, 0.03, (0, dy, z0 + 0.04), (0, dy, zc - 0.005), seg=8), "ad_steel_dark")      # arm
    dsh.add(box((0.16, 0.16, 0.03), (0, dy, zc - 0.02)), "ad_steel_dark")
    focus = V((0, dy, zc + R * R / (4 * depth)))
    for k in range(3):
        ang = math.radians(90 + k * 120)
        rimp = V((math.cos(ang) * R * 0.95, dy + math.sin(ang) * R * 0.95, zc + depth * 0.9))
        dsh.add(cyl(0.007, 0.007, rimp, focus, seg=5), "ad_galv")
    dsh.add(cyl(0.04, 0.03, focus - V((0, 0, 0.02)), focus + V((0, 0, 0.1)), seg=8), "ad_plastic_dark")
    if beacon:
        beacon_parts(a, V((0, s3b + 0.02, z0)), parent="mast_stage_3")
    if guys:
        g = a.node("guy_wires", pivot=(0, 0, z0))
        gy = s2b - 0.3
        for k in range(3):
            ang = math.radians(30 + k * 120)
            st = V((math.cos(ang) * 6.5, 0.0, z0 + math.sin(ang) * 6.5))
            top_p = V((math.cos(ang) * 0.08, gy, z0 + math.sin(ang) * 0.08))
            g.add(cyl(0.004, 0.004, top_p, st + V((0, 0.42, 0)), seg=4, caps=False), "ad_galv")
            g.add(cyl(0.012, 0.012, st + V((0, 0.24, 0)), st + V((0, 0.42, 0)), seg=6), "ad_rust")      # turnbuckle
            g.add(cyl(0.02, 0.012, st + V((0, -0.25, 0)), st + V((0, 0.26, 0)), seg=6), "ad_steel_dark")  # ground stake
    return s3b


def beacon_parts(a, base, parent=None, name="beacon"):
    """a caged red beacon standing on base: plate, red glass dome (ad_lamp_red, emissive), six bars, two rings, a cap"""
    b = a.node(name, pivot=tuple(base))
    if parent:
        a.parents[name] = parent
    base = V(base)
    b.add(cyl(0.075, 0.07, base, base + V((0, 0.035, 0)), seg=14), "ad_steel_dark")
    b.add(cyl(0.058, 0.058, base + V((0, 0.035, 0)), base + V((0, 0.13, 0)), seg=14), "ad_lamp_red", smooth=True)
    b.add(sphere(0.058, base + V((0, 0.13, 0)), scale=(1, 0.75, 1), seg=14, rings=6), "ad_lamp_red", smooth=True)
    for k in range(6):
        ang = k / 6 * math.tau
        p = V((math.cos(ang) * 0.072, 0, math.sin(ang) * 0.072))
        b.add(cyl(0.005, 0.005, base + p + V((0, 0.03, 0)), base + p * 0.4 + V((0, 0.2, 0)), seg=4), "ad_steel_dark")
    b.add(torus(0.072, 0.005, base + V((0, 0.09, 0)), rot=(90, 0, 0), seg=14, sides=4), "ad_steel_dark")
    b.add(torus(0.05, 0.005, base + V((0, 0.17, 0)), rot=(90, 0, 0), seg=12, sides=4), "ad_steel_dark")
    b.add(cyl(0.035, 0.03, base + V((0, 0.195, 0)), base + V((0, 0.215, 0)), seg=10), "ad_steel_dark")


# ============================================================================================ the jammer trailer
def jammer_trailer():
    a = AD("pike_jammer_trailer", ao_dist=0.25, ao_strength=0.55, colour=rust_colour(1.0, 0.55),
           meta={"notes": "rusty box trailer, hitch toward +z; the mast hinges at the deck (node mast, pivot on the hinge "
                          "pin): rotate mast about local x by +88 deg to lay it forward over the drawbar; mast_stage_2 and "
                          "mast_stage_3 slide down their local y to telescope; dish turns about y; beacon is the caged lamp "
                          "(material ad_lamp_red, emissive: AntiDroneAssets.set_beacon); hide guy_wires when the mast is down",
                 "mast_top": MAST_TOP, "mast_hinge_axis": "x", "lower_deg": 88.0, "deck_y": 0.62},
           probes=[{"node": "trailer_hitch", "axis": "z", "side": 1}], budget=8000, buried_ok=0.26)
    t = a.node("trailer_body")
    dy = 0.62                 # deck top
    L, W = 2.4, 1.4
    # chassis rails and cross members (rust), deck (paint), box sides with a top rail and corner posts
    for s in (-1, 1):
        t.add(box((0.06, 0.1, L + 0.1), (s * 0.5, dy - 0.11, -0.1)), "ad_rust")
    for z in (-1.2, -0.4, 0.4, 0.95):
        t.add(box((1.06, 0.06, 0.05), (0, dy - 0.11, z)), "ad_rust")
    t.add(box((W, 0.035, L), (0, dy - 0.018, -0.1)), "ad_trailer_paint")
    for s in (-1, 1):
        side = grid_box((0.025, 0.42, L), (s * (W / 2 - 0.0125), dy + 0.21, -0.1), div=(1, 2, 6))
        t.add(side, "ad_trailer_paint", tag="side")
        t.add(box((0.05, 0.04, L + 0.02), (s * (W / 2 - 0.02), dy + 0.43, -0.1)), "ad_trailer_paint")
        for z in (-1.3, 1.1):
            t.add(box((0.05, 0.46, 0.05), (s * (W / 2 - 0.02), dy + 0.2, z)), "ad_rust")
        for zr in (-0.75, -0.1, 0.55):
            t.add(box((0.012, 0.36, 0.03), (s * (W / 2 + 0.002), dy + 0.2, zr)), "ad_trailer_paint")         # pressed ribs
    t.add(box((W, 0.42, 0.025), (0, dy + 0.21, 1.1)), "ad_trailer_paint")                  # front board
    t.add(box((W, 0.42, 0.03), (0, dy + 0.21, -1.31)), "ad_trailer_paint")                 # tailgate
    for s in (-1, 1):
        t.add(cyl(0.012, 0.012, (s * 0.6, dy + 0.38, -1.34), (s * 0.45, dy + 0.38, -1.34), seg=6), "ad_galv")    # latches
    # axle, leaf springs, mudguards; rear lamp clusters (dead, no emission) and a reflector
    t.add(box((1.5, 0.06, 0.06), (0, 0.3, -0.1)), "ad_rust")
    for s in (-1, 1):
        t.add(box((0.05, 0.04, 0.7), (s * 0.5, 0.42, -0.1)), "ad_rust")
        mg = []
        for i in range(9):
            ang = math.pi * i / 8
            mg.append(V((s * 0.82, 0.3 + math.sin(ang) * 0.4, -0.1 + math.cos(ang) * 0.42)))
        tube_path(mg, 0.02, "ad_trailer_paint", t, seg=6)
        t.add(box((0.24, 0.012, 0.86), (s * 0.82, 0.71, -0.1)), "ad_trailer_paint")
        t.add(box((0.16, 0.08, 0.04), (s * 0.55, dy - 0.06, -1.35)), "site_plastic_red")
    # rear corner steadies, wound down to the ground (the trailer is parked)
    for s in (-1, 1):
        t.add(cyl(0.02, 0.02, (s * 0.5, dy - 0.15, -1.15), (s * 0.5, 0.06, -1.15), seg=6), "ad_rust")
        t.add(box((0.12, 0.02, 0.12), (s * 0.5, 0.01, -1.15)), "ad_rust")
    # contents: a battery box and a junction box with the cable coming in, a lump of tarp, a bucket
    t.add(box((0.42, 0.26, 0.3), (-0.35, dy + 0.13, 0.55), bevel=0.01), "ad_plastic_dark")
    t.add(box((0.3, 0.22, 0.14), (0.25, dy + 0.11, -0.95), bevel=0.01), "ad_plastic_grey")
    t.add(cyl(0.13, 0.15, (0.4, dy, 0.6), (0.4, dy + 0.3, 0.6), seg=12, caps=True), "ad_plastic_grey")
    tube_path([V((0.25, dy + 0.12, -0.88)), V((0.4, dy + 0.06, -0.6)), V((0.6, dy + 0.02, -0.3)), V((0.69, dy + 0.4, -0.2)),
               V((0.74, dy + 0.38, -0.2)), V((0.8, 0.3, -0.25)), V((0.9, 0.006, -0.3))], 0.009, "ad_cable", t)
    # wheels (on the ground)
    w = a.node("trailer_wheel_l", pivot=(0.82, 0.3, -0.1))
    wheel(w, (0.82, 0.3, -0.1), 0.3, 0.17)
    w = a.node("trailer_wheel_r", pivot=(-0.82, 0.3, -0.1))
    wheel(w, (-0.82, 0.3, -0.1), 0.3, 0.17)
    # the A-frame drawbar, coupling, jockey wheel down on the ground, a safety chain
    h = a.node("trailer_hitch", pivot=(0, 0.45, 2.1))
    for s in (-1, 1):
        h.add(cyl(0.035, 0.035, (s * 0.5, dy - 0.11, 1.1), (0, 0.46, 2.0), seg=6), "ad_rust")
    h.add(box((0.12, 0.1, 0.32), (0, 0.46, 2.1)), "ad_rust")
    h.add(sphere(0.05, (0, 0.47, 2.27), seg=10, rings=6), "ad_steel_dark")
    h.add(cyl(0.03, 0.03, (0.12, 0.62, 1.75), (0.12, 0.12, 1.75), seg=8), "ad_galv")
    h.add(cyl(0.035, 0.035, (0.12, 0.62, 1.75), (0.12, 0.78, 1.75), seg=8), "ad_galv")
    h.add(box((0.1, 0.02, 0.02), (0.12, 0.79, 1.8)), "ad_galv")
    wheel(h, (0.12, 0.1, 1.75), 0.1, 0.06, rim_mat="ad_galv")
    h.add(box((0.05, 0.05, 0.12), (0.12, 0.14, 1.75)), "ad_galv")
    tube_path(sag((-0.06, 0.44, 2.0), (0.02, 0.4, 2.3), 6, 0.08), 0.007, "ad_galv", h, seg=4)
    # the NO DRONES stencil sprayed on the left side (x +) and a scrap of tarp
    st = a.node("stencil")
    sc = (W / 2 + 0.004, dy + 0.21, -0.1)
    st.add(A.quad(0.38, 0.38, sc, rot=(0, 90, 0)), "ad_decal_stencil", uv=uv01(0.38, 0.38, sc, (0, 90, 0)), recalc=False)
    mast_parts(a, dy, -0.75)
    return a


def jammer_mast():
    a = AD("pike_jammer_mast", ao_dist=0.4, colour=rust_colour(2.0, 0.45),
           meta={"notes": "the mast alone on a ground plate (origin at its foot); same nodes as on the trailer",
                 "mast_top": MAST_TOP, "mast_hinge_axis": "x", "lower_deg": 88.0},
           probes=[{"node": "dish", "axis": "z", "side": 1}], budget=5000, buried_ok=0.26)
    base = a.node("mast_base")
    base.add(box((0.7, 0.03, 0.7), (0, 0.015, 0)), "ad_rust")
    for s in (-1, 1):
        base.add(box((0.7, 0.06, 0.05), (0, 0.06, s * 0.32)), "ad_rust")
    mast_parts(a, 0.03, 0.0)
    return a


def beacon_only():
    a = AD("pike_beacon", ao_dist=0.05, ground=False, colour=rust_colour(3.0, 0.3), lod1=0.6,
           meta={"notes": "the caged red beacon; origin at its base plate; ad_lamp_red is emissive (set_beacon)"})
    beacon_parts(a, V((0, 0, 0)))
    return a


# ============================================================================================ boards and signs
def manifesto_board():
    a = AD("pike_manifesto_board", colour=rust_colour(4.0, 0.3),
           meta={"text_rect": {"centre": [0.0, 1.53, 0.05], "size": [0.96, 0.88], "normal": [0, 0, 1], "tilt_deg": -2.5,
                               "notes": "the blank taped sheet in the middle of the ply face"},
                 "notes": "lopsided ply board 2.4 x 1.4 m on two posts, the right post sunk lower; face +z; the paper is blank"},
           probes=[{"node": "manifesto_paper", "mat": "ad_paper", "dir": [0, 0, 1]}], buried_ok=0.35)
    tilt = -2.5      # degrees about z: the right post sank
    p = a.node("manifesto_posts")
    for x, top in ((-1.0, 2.38), (1.0, 2.3)):
        p.add(box((0.095, top + 0.35, 0.095), (x, (top - 0.35) / 2, -0.06), rot=(0, 0, tilt * 0.6)), "site_timber", grain=(0, 1, 0))
    b = a.node("manifesto_board")
    rot = (0, 0, tilt)
    b.add(box((2.4, 1.4, 0.018), (0, 1.6, 0.0), rot=rot), "ad_ply", grain=(1, 0, 0))
    # screws, a split corner and a batten along the top as a drip edge
    b.add(box((2.44, 0.05, 0.05), (0.0, 2.32, -0.005), rot=rot), "site_timber", grain=(1, 0, 0))
    pp = a.node("manifesto_paper")
    sc = (0.0, 1.53, 0.012)
    pp.add(A.quad(0.96, 0.88, sc, rot=rot), "ad_paper", uv=uv01(0.96, 0.88, sc, rot), recalc=False)
    for (x, y, w, h, r) in ((-0.8, 1.72, 0.3, 0.42, 4), (0.78, 1.38, 0.3, 0.42, -6), (0.82, 1.82, 0.28, 0.36, 3)):
        c2 = (x, y, 0.011)
        pp.add(A.quad(w, h, c2, rot=(0, 0, tilt + r)), "ad_paper_lined", uv=uv01(w, h, c2, (0, 0, tilt + r)), recalc=False)
    for (x, y) in ((-0.48, 1.97), (0.48, 1.97), (-0.48, 1.09), (0.48, 1.09)):
        c3 = (x, y, 0.014)
        pp.add(A.quad(0.12, 0.04, c3, rot=(0, 0, tilt + 40 * (1 if x * y > 0 else -1))), "ad_tape", recalc=False)
    return a


def warning_sign():
    a = AD("pike_warning_sign", colour=rust_colour(5.0, 0.35),
           meta={"text_rect": {"centre": [0.0, 1.3, 0.04], "size": [0.84, 0.54], "normal": [0, 0, 1],
                               "notes": "blank painted face for NO DRONES / PRIVATE LAND (Label3D)"}},
           probes=[{"node": "warning_sign_board", "mat": "ad_paint_white", "dir": [0, 0, 1]}], buried_ok=0.42)
    p = a.node("warning_sign_post")
    p.add(box((0.08, 2.0, 0.08), (0, 0.6, -0.05), rot=(2, 0, 1.5)), "site_timber", grain=(0, 1, 0))
    b = a.node("warning_sign_board")
    b.add(box((0.9, 0.6, 0.02), (0, 1.3, 0.0), rot=(0, 0, 1.5)), "ad_ply", grain=(1, 0, 0))
    b.add(A.quad(0.86, 0.56, (0, 1.3, 0.0105), rot=(0, 0, 1.5)), "ad_paint_white", recalc=False)
    for (x, y) in ((-0.38, 1.52), (0.38, 1.52), (-0.38, 1.08), (0.38, 1.08)):
        b.add(cyl(0.008, 0.008, (x, y, 0.012), (x, y, 0.016), seg=6), "ad_rust")
    return a


# ============================================================================================ the shack
def generator_parts(n, c, rot_y=0.0, lamp=None):
    """a small open-frame generator at c (base), facing +z: frame, tank, engine, alternator, panel, muffler"""
    import antidrone_lib as AA
    cx, cy, cz = c
    def P(x, y, z):
        ca, sa = math.cos(rot_y), math.sin(rot_y)
        return V((cx + x * ca + z * sa, cy + y, cz - x * sa + z * ca))
    fr = []
    for (x0, z0) in ((-0.3, -0.22), (0.3, -0.22), (0.3, 0.22), (-0.3, 0.22)):
        fr.append(P(x0, 0.02, z0))
    for i in range(4):
        tube_path([fr[i], fr[(i + 1) % 4]], 0.016, "ad_paint_red", n, seg=6)
        tube_path([fr[i] , fr[i] + V((0, 0.44, 0))], 0.016, "ad_paint_red", n, seg=6)
    top = [f + V((0, 0.44, 0)) for f in fr]
    for i in range(4):
        tube_path([top[i], top[(i + 1) % 4]], 0.016, "ad_paint_red", n, seg=6)
    n.add(box((0.4, 0.15, 0.3), P(0.0, 0.52, 0.0), rot=(0, math.degrees(rot_y), 0), bevel=0.04, seg=2), "ad_paint_red", tag="tank")
    n.add(cyl(0.03, 0.03, P(0.1, 0.59, 0.05), P(0.1, 0.62, 0.05), seg=8), "ad_steel_dark")
    n.add(box((0.24, 0.24, 0.26), P(-0.1, 0.18, 0.0), rot=(0, math.degrees(rot_y), 0), bevel=0.02), "ad_engine")
    n.add(cyl(0.11, 0.11, P(0.06, 0.2, 0.0), P(0.26, 0.2, 0.0), seg=12), "ad_paint_red")
    n.add(box((0.02, 0.14, 0.2), P(0.29, 0.25, 0.0), rot=(0, math.degrees(rot_y), 0)), "ad_plastic_dark")
    n.add(cyl(0.035, 0.035, P(-0.22, 0.32, -0.15), P(0.0, 0.32, -0.15), seg=8), "ad_rust")       # muffler
    n.add(box((0.08, 0.06, 0.02), P(-0.12, 0.12, 0.14), rot=(0, math.degrees(rot_y), 0)), "ad_plastic_dark")   # recoil
    if lamp is not None:
        lamp.add(sphere(0.022, P(0.29, 0.36, 0.05), seg=8, rings=4), "ad_lamp_amber")
        lamp.add(cyl(0.024, 0.024, P(0.285, 0.34, 0.05), P(0.3, 0.34, 0.05), seg=8), "ad_steel_dark")


def shack():
    a = AD("pike_shack", ao_dist=0.7, colour=rust_colour(6.0, 0.5),
           meta={"notes": "plank shack 3.0 x 2.4 m on blocks, mono-pitch corrugated roof falling to the back, door on the "
                          "front (+z, node door hinged on its right edge seen from outside, +x; rotation.y +80 swings it open outward), a lean-to on the right (-x) with "
                          "the generator (node shack_generator_lamp is its amber warning lamp) and a tarp lump, a rain "
                          "barrel at the front left; lived-in, not a fortress", "door_hinge_axis": "y"},
           probes=[{"node": "door", "axis": "z", "side": 1}], budget=7000, buried_ok=0.05)
    W, D = 3.0, 2.4
    fy = 0.25          # floor
    hf, hb = 2.3, 1.95  # wall tops front / back
    w = a.node("shack_walls")
    for (x, z) in ((-1.4, -1.1), (1.4, -1.1), (-1.4, 1.1), (1.4, 1.1), (0, -1.1), (0, 1.1)):
        w.add(box((0.2, fy + 0.04, 0.2), (x, (fy + 0.04) / 2 - 0.04, z)), "site_concrete")
    w.add(box((W, 0.05, D), (0, fy - 0.025, 0)), "ad_planks", grain=(1, 0, 0))
    # walls: boards with the grain upright, slight unevenness; front wall with a door hole
    def wall_h(z):
        return hf + (hb - hf) * (D / 2 - z) / D
    # back
    w.add(box((W, hb - fy, 0.04), (0, (hb + fy) / 2, -D / 2 + 0.02)), "ad_planks", grain=(0, 1, 0))
    # sides: sloped tops, made as lofts
    for s in (-1, 1):
        x = s * (W / 2 - 0.02)
        rings = [[V((x - 0.02, fy, -D / 2)), V((x + 0.02, fy, -D / 2)), V((x + 0.02, hb, -D / 2)), V((x - 0.02, hb, -D / 2))],
                 [V((x - 0.02, fy, D / 2)), V((x + 0.02, fy, D / 2)), V((x + 0.02, hf, D / 2)), V((x - 0.02, hf, D / 2))]]
        w.add(loft(rings, close_ring=True, cap0=True, cap1=True), "ad_planks", grain=(0, 1, 0))
    # front: left of the door, above the door, right of the door (door 0.8 m wide at x 0.25..1.05 minus)
    dx0, dx1, dh = -0.15, 0.65, 2.0
    w.add(box((dx0 + W / 2, hf - fy, 0.04), ((-W / 2 + dx0) / 2, (hf + fy) / 2, D / 2 - 0.02)), "ad_planks", grain=(0, 1, 0))
    w.add(box((W / 2 - dx1, hf - fy, 0.04), ((W / 2 + dx1) / 2, (hf + fy) / 2, D / 2 - 0.02)), "ad_planks", grain=(0, 1, 0))
    w.add(box((dx1 - dx0, hf - fy - dh, 0.04), ((dx0 + dx1) / 2, (hf + fy + dh) / 2, D / 2 - 0.02)), "ad_planks", grain=(0, 1, 0))
    # door frame, a step (two blocks) and a side window (left wall, +x) with plastic glazing and a batten cross
    for x in (dx0 - 0.03, dx1 + 0.03):
        w.add(box((0.05, dh, 0.07), (x, fy + dh / 2, D / 2)), "site_timber", grain=(0, 1, 0))
    w.add(box((dx1 - dx0 + 0.11, 0.05, 0.07), ((dx0 + dx1) / 2, fy + dh + 0.025, D / 2)), "site_timber", grain=(1, 0, 0))
    w.add(box((0.5, 0.1, 0.3), ((dx0 + dx1) / 2, 0.08, D / 2 + 0.2)), "site_concrete")
    w.add(box((0.4, 0.1, 0.25), ((dx0 + dx1) / 2 + 0.05, 0.18, D / 2 + 0.16)), "site_concrete")
    wx = W / 2 + 0.002
    w.add(box((0.004, 0.5, 0.6), (wx, 1.45, 0.2)), "ad_glass")
    w.add(box((0.04, 0.6, 0.06), (wx + 0.01, 1.45, 0.53)), "site_timber")
    w.add(box((0.04, 0.6, 0.06), (wx + 0.01, 1.45, -0.13)), "site_timber")
    w.add(box((0.04, 0.06, 0.72), (wx + 0.01, 1.73, 0.2)), "site_timber")
    w.add(box((0.04, 0.06, 0.72), (wx + 0.01, 1.17, 0.2)), "site_timber")
    w.add(box((0.03, 0.04, 0.6), (wx + 0.02, 1.45, 0.2)), "site_timber")
    # the door (hinged at its left edge seen from outside: x = dx0), ledged and braced boards, a hasp
    door = a.node("door", pivot=(dx1, fy + 0.02, D / 2 + 0.01))
    door.add(box((dx1 - dx0 - 0.02, dh - 0.03, 0.035), ((dx0 + dx1) / 2, fy + 0.02 + (dh - 0.03) / 2, D / 2 + 0.01)), "ad_planks", grain=(0, 1, 0))
    for y in (0.35, 1.0, 1.65):
        door.add(box((dx1 - dx0 - 0.08, 0.1, 0.025), ((dx0 + dx1) / 2, fy + y, D / 2 + 0.04)), "ad_planks", grain=(1, 0, 0))
    door.add(box((0.05, 0.04, 0.02), (dx0 + 0.08, fy + 1.05, D / 2 + 0.06)), "ad_rust")
    for y in (0.35, 1.65):
        door.add(box((0.3, 0.03, 0.01), (dx1 - 0.15, fy + y, D / 2 + 0.058)), "ad_steel_dark")
    # roof: corrugated sheets falling to the back with an overhang, purlins under it, a stove pipe through it
    r = a.node("shack_roof")
    ov = 0.3
    rfz, rbz = D / 2 + ov, -D / 2 - 0.25
    def ry(z):
        return wall_h(z) + 0.06
    xs = [-W / 2 - 0.2 + i * (W + 0.4) / 30 for i in range(31)]
    zs = [rbz + i * (rfz - rbz) / 4 for i in range(5)]
    def corr(x, z):
        return ry(z) + 0.018 * math.sin(x / 0.076 * math.pi)
    top = A.grid(xs, zs, corr)
    r.add(top, "ad_corrugated", grain=(0, 0, 1), recalc=False)
    under = A.grid(xs, zs, lambda x, z: corr(x, z) - 0.004)
    for f in under.faces:
        f.normal_flip()
    r.add(under, "ad_corrugated", grain=(0, 0, 1), recalc=False)
    for z in (-1.0, 0.0, 1.0):
        r.add(box((W + 0.3, 0.06, 0.08), (0, ry(z) - 0.05, z)), "site_timber", grain=(1, 0, 0))
    r.add(cyl(0.065, 0.065, (0.8, ry(-0.5) - 0.3, -0.5), (0.8, ry(-0.5) + 0.75, -0.5), seg=10), "ad_rust")
    r.add(cyl(0.1, 0.07, (0.8, ry(-0.5) + 0.75, -0.5), (0.8, ry(-0.5) + 0.85, -0.5), seg=10), "ad_rust")
    r.add(cyl(0.03, 0.03, (-W / 2 - 0.05, ry(-D / 2) - 0.05, -D / 2 - 0.2), (W / 2 + 0.05, ry(-D / 2) - 0.05, -D / 2 - 0.2), seg=6), "ad_galv")   # gutter
    # rain barrel at the back left corner with a downpipe from the gutter
    rb = a.node("shack_barrel")
    rb.add(cyl(0.29, 0.29, (1.25, 0.0, -1.62), (1.25, 0.88, -1.62), seg=16), "ad_paint_white", smooth=True, uv='cyl', grain=(0, 1, 0))
    for y in (0.2, 0.68):
        rb.add(torus(0.295, 0.015, (1.25, y, -1.62), rot=(90, 0, 0), seg=16, sides=4), "ad_paint_white")
    rb.add(cyl(0.26, 0.26, (1.25, 0.82, -1.62), (1.25, 0.845, -1.62), seg=16), "ad_water")
    rb.add(cyl(0.025, 0.025, (1.35, ry(-D / 2) - 0.06, -D / 2 - 0.2), (1.3, 0.95, -1.55), seg=6), "ad_galv")
    # the lean-to on the right (-x): two posts, a sloping corrugated sheet, the generator and a tarp lump under it
    lt = a.node("shack_lean_to")
    lx0, lx1 = -W / 2, -W / 2 - 1.5
    for z in (-0.95, 0.95):
        lt.add(box((0.08, 1.7, 0.08), (lx1 + 0.05, 0.85, z)), "site_timber", grain=(0, 1, 0))
    lt.add(box((0.07, 0.08, 2.1), (lx1 + 0.05, 1.72, 0)), "site_timber", grain=(0, 0, 1))
    xs2 = [lx1 - 0.15 + i * (lx0 - lx1 + 0.15) / 12 for i in range(13)]
    zs2 = [-1.15 + i * 2.3 / 18 for i in range(19)]
    def ly(x, z):
        t = (x - (lx1 - 0.15)) / (lx0 - lx1 + 0.15)
        return 1.74 + t * 0.35 + 0.016 * math.sin(z / 0.076 * math.pi)
    lt.add(A.grid(xs2, zs2, ly), "ad_corrugated", grain=(1, 0, 0), recalc=False)
    lu = A.grid(xs2, zs2, lambda x, z: ly(x, z) - 0.004)
    for f in lu.faces:
        f.normal_flip()
    lt.add(lu, "ad_corrugated", grain=(1, 0, 0), recalc=False)
    gen = a.node("shack_generator")
    lamp = a.node("shack_generator_lamp")
    generator_parts(gen, (-W / 2 - 0.65, 0.0, 0.45), rot_y=math.radians(90), lamp=lamp)
    tp = a.node("shack_tarp")
    tarp_lump(tp, (-W / 2 - 0.7, 0.0, -0.55), (0.9, 0.55, 0.7), seed=3)
    return a


def tarp_lump(n, c, size, seed=0, mat="ad_tarp"):
    """a tarpaulin thrown over a boxy load: a heightfield draped over a rounded box, folds, edges on the ground"""
    cx, cy, cz = c
    sx, sy, sz = size
    rnd = random.Random(seed)
    nx, nz = 22, 18
    ex, ez = sx * 0.5 + 0.28, sz * 0.5 + 0.28
    xs = [cx - ex + 2 * ex * i / nx for i in range(nx + 1)]
    zs = [cz - ez + 2 * ez * k / nz for k in range(nz + 1)]
    def h(x, z):
        u = abs(x - cx) / (sx * 0.5); v = abs(z - cz) / (sz * 0.5)
        m = max(u, v)
        lump = 1.0 + 0.18 * fbm((x * 1.7, 0, z * 1.7), 1.0, 2, seed + 5.0) - 0.15 * smooth(0.0, 1.0, u * v)
        body = sy * lump * (1.0 - smooth(0.55, 1.5, m + 0.08 * fbm((x, 1, z), 4.0, 2, seed))) + 0.012
        fold = 0.025 * math.sin((x - cx) * 9.0 + 2 * math.sin((z - cz) * 4.0)) * smooth(0.6, 1.2, m)
        n0 = 0.02 * fbm((x, 0, z), 3.0, 2, seed)
        return cy + max(0.008, body + fold + n0 * (1 - smooth(1.3, 1.6, m)))
    top = A.grid(xs, zs, h)
    n.add(top, mat, recalc=False, grain=(1, 0, 0), smooth=True)      # one sheet; the material is double-sided
    # a rope over it and two bricks holding the windward edge
    rp = [V((cx - ex * 0.9 + 1.8 * ex * t, h(cx - ex * 0.9 + 1.8 * ex * t, cz) + 0.012, cz)) for t in [i / 10 for i in range(11)]]
    tube_path(rp, 0.008, "site_rope", n, seg=5)
    for k in range(2):
        bx = cx - ex * 0.6 + k * ex * 1.1
        n.add(box((0.22, 0.07, 0.1), (bx, 0.035, cz + ez - 0.12), rot=(0, rnd.uniform(-30, 30), 0)), "site_concrete")


def generator():
    a = AD("pike_generator", ao_dist=0.25, colour=rust_colour(7.0, 0.6),
           meta={"notes": "small open-frame generator (front +z), fuel can and cable reel; warning lamp node "
                          "generator_lamp (ad_lamp_amber, emissive: AntiDroneAssets.set_lamp)"},
           probes=[{"node": "generator_reel", "axis": "x", "side": 1}])
    g = a.node("generator")
    lamp = a.node("generator_lamp")
    generator_parts(g, (0, 0, 0), lamp=lamp)
    # jerry can (left of it, -x), reel (right, +x)
    j = a.node("generator_fuel_can")
    j.add(box((0.17, 0.46, 0.34), (-0.55, 0.23, 0.05), bevel=0.02), "ad_jerrycan")
    for y in (0.16, 0.3):
        j.add(box((0.175, 0.012, 0.3), (-0.55, y, 0.05)), "ad_jerrycan")
    for z in (-0.04, 0.02, 0.08):
        j.add(box((0.02, 0.04, 0.03), (-0.55, 0.48, z)), "ad_jerrycan")
    j.add(cyl(0.022, 0.022, (-0.55, 0.42, 0.18), (-0.55, 0.5, 0.24), seg=8), "ad_steel_dark")
    r = a.node("generator_reel")
    rc = V((0.7, 0.24, 0.05))
    for s in (-1, 1):
        r.add(cyl(0.23, 0.23, rc + V((s * 0.13, 0, 0)), rc + V((s * 0.145, 0, 0)), seg=16), "ad_plastic_grey")
    r.add(cyl(0.19, 0.19, rc - V((0.13, 0, 0)), rc + V((0.13, 0, 0)), seg=16), "ad_cable_orange", smooth=True, uv='cyl', grain=(1, 0, 0))
    for s in (-1, 1):
        r.add(box((0.03, 0.26, 0.04), rc + V((s * 0.16, -0.12, 0.12)), rot=(-25, 0, 0)), "ad_steel_dark")
        r.add(box((0.03, 0.26, 0.04), rc + V((s * 0.16, -0.12, -0.12)), rot=(25, 0, 0)), "ad_steel_dark")
    tube_path([rc + V((0, -0.19, 0.03)), V((0.55, 0.008, 0.35)), V((0.2, 0.008, 0.3)), V((0.3, 0.12, 0.22))], 0.008, "ad_cable_orange", r)
    return a


def fence(name, length, folk=False, seed=0):
    a = AD(name, ao_dist=0.3, colour=rust_colour(8.0 + seed, 0.5), buried_ok=0.45,
           meta={"notes": "broken post-and-wire fence along x from 0 to %.0f m (origin at the first post), one strand "
                          "snapped and trailing, one post leaning%s" % (length, "; a deer skull on the middle post and red "
                          "rag ribbons tied to the wire (folk detail)" if folk else "")})
    rnd = random.Random(seed + 11)
    posts = a.node(name + "_posts")
    n = int(round(length / 2.0)) + 1
    tops = []
    for i in range(n):
        x = i * length / (n - 1)
        lean = (rnd.uniform(-4, 4), 0, rnd.uniform(-5, 5))
        if i == n // 2 + (0 if folk else 1) and n > 2:
            lean = (14, 0, -6)
        h = rnd.uniform(1.15, 1.3)
        cen = V((x, (h - 0.45) / 2, 0))
        posts.add(box((0.09, h + 0.45, 0.09), tuple(cen), rot=lean), "site_timber", grain=(0, 1, 0))
        M = A.mrot(lean).to_3x3()
        tops.append([cen + M @ (V((x, y, 0.05)) - cen) for y in (0.4, 0.75, 1.08)])
    wires = a.node(name + "_wire")
    for k in range(3):
        for i in range(n - 1):
            p0, p1 = tops[i][k], tops[i + 1][k]
            if k == 1 and i == (n - 1) // 2:
                # the snapped strand: two ends hanging to the ground and curling
                mid = p0.lerp(p1, 0.45)
                tube_path(sag(p0, V((mid.x - 0.1, 0.02, 0.12)), 8, 0.25, 0.02, seed + i), 0.004, "ad_galv", wires, seg=4)
                tube_path(sag(p1, V((mid.x + 0.3, 0.02, -0.08)), 8, 0.25, 0.02, seed + i + 7), 0.004, "ad_galv", wires, seg=4)
                continue
            tube_path(sag(p0, p1, 10, 0.05 + 0.03 * k, 0.004, seed + i * 3 + k), 0.004, "ad_galv", wires, seg=4)
    if folk:
        f = a.node(name + "_folk")
        mp = tops[n // 2][2] + V((0, 0.06, 0.0))
        skull(f, mp + V((0, 0.02, 0.06)))
        for k in range(3):
            i = k * (n - 2) // 2
            p = tops[i][1].lerp(tops[i + 1][1], 0.5)
            p.y -= 0.03
            f.add(torus(0.012, 0.005, p, rot=(0, 90, 0), seg=8, sides=4), "ad_ribbon")
            for t in (-1, 1):
                tail = [p + V((t * 0.008, -0.01, 0)), p + V((t * 0.02, -0.12, 0.01)), p + V((t * 0.03 + 0.02, -0.26, 0.02))]
                f.add(sweep(tail, 0.006, seg=4, section=[(1, 0), (0.2, 0.3), (-1, 0), (0.2, -0.3)]), "ad_ribbon")
    return a


def skull(n, c):
    """a weathered deer skull nailed facing out (+z): cranium, long tapering muzzle, eye sockets, two short antler stubs"""
    c = V(c)
    n.add(sphere(0.06, c + V((0, 0.03, 0)), scale=(1.0, 0.9, 1.05), seg=12, rings=8), "ad_bone", smooth=True)
    rings = []
    for i in range(6):
        t = i / 5
        w = 0.05 * (1 - 0.62 * t); hh = 0.04 * (1 - 0.55 * t)
        y = c.y + 0.0 - 0.06 * t
        z = c.z + 0.04 + 0.16 * t
        rings.append([V((c.x + math.cos(j / 8 * math.tau) * w, y + math.sin(j / 8 * math.tau) * hh, z)) for j in range(8)])
    n.add(loft(rings, cap0=False, cap1=True), "ad_bone", smooth=True)
    for s in (-1, 1):
        n.add(sphere(0.016, c + V((s * 0.045, 0.03, 0.06)), seg=8, rings=4), "ad_steel_dark")
        n.add(cyl(0.012, 0.007, c + V((s * 0.03, 0.08, 0.0)), c + V((s * 0.07, 0.17, -0.02)), seg=6), "ad_bone")
        n.add(cyl(0.007, 0.004, c + V((s * 0.07, 0.17, -0.02)), c + V((s * 0.06, 0.24, 0.03)), seg=5), "ad_bone")
    n.add(cyl(0.004, 0.004, c + V((0, 0.05, 0.06)), c + V((0, 0.05, -0.08)), seg=4), "ad_rust")       # the nail


def cable_run():
    a = AD("pike_cable_run", ao_dist=0.05, colour=rust_colour(9.0, 0.2), lod1=0.5,
           meta={"notes": "an 8 m power cable lying in the grass from the generator (z 0) to the mast (z 8), plugs at "
                          "both ends; drape it with AntiDroneAssets.drape"})
    c = a.node("cable")
    rnd = random.Random(5)
    pts = []
    for i in range(41):
        t = i / 40
        x = 0.25 * math.sin(t * 7.0) + 0.12 * math.sin(t * 19.0 + 1)
        pts.append(V((x, 0.009, t * 8.0)))
    pts[0] = V((0.0, 0.14, -0.02)); pts[1].y = 0.05
    pts[-1] = V((pts[-1].x, 0.15, 8.05)); pts[-2].y = 0.05
    tube_path(pts, 0.009, "ad_cable", c, seg=6)
    for p in (pts[0], pts[-1]):
        c.add(cyl(0.022, 0.022, p - V((0, 0.0, 0.04)), p + V((0, 0, 0.04)), seg=8), "ad_plastic_grey")
    # two cable stakes (bent wire hoops)
    for t in (0.3, 0.7):
        p = pts[int(t * 40)]
        c.add(torus(0.03, 0.004, p + V((0, 0.0, 0)), rot=(0, 90, 0), seg=10, sides=4, a0=0, a1=math.pi), "ad_galv")
    return a


# ============================================================================================ priority 1 props
def tarp():
    a = AD("pike_tarp", ao_dist=0.3, colour=rust_colour(10.0, 0.2),
           meta={"notes": "a tarpaulin lump over something boxy under the lean-to; nothing under it is modelled"})
    t = a.node("tarp")
    tarp_lump(t, (0, 0, 0), (1.0, 0.48, 0.75), seed=9)
    return a


def toolbox():
    a = AD("pike_toolbox", ao_dist=0.12, colour=rust_colour(11.0, 0.45),
           meta={"notes": "an open cantilever toolbox (lid open toward -z), spanners, a screwdriver, an oil can and a "
                          "rag; the brief's shotgun cleaning kit is left out on purpose (no weapons or weapon kit)"})
    b = a.node("toolbox")
    L, W, H = 0.5, 0.22, 0.2
    b.add(box((L, 0.01, W), (0, 0.005, 0)), "ad_toolbox_red")
    for s in (-1, 1):
        b.add(box((L, H, 0.008), (0, H / 2, s * (W / 2 - 0.004))), "ad_toolbox_red", tag="side")
        b.add(box((0.008, H, W), (s * (L / 2 - 0.004), H / 2, 0)), "ad_toolbox_red")
    # trays swung out on their arms
    for s in (-1, 1):
        b.add(box((L * 0.9, 0.06, 0.1), (0, H + 0.07, s * 0.16), bevel=0.004), "ad_toolbox_red")
        b.add(box((L * 0.86, 0.004, 0.09), (0, H + 0.098, s * 0.16)), "ad_steel_dark")
        for x in (-0.18, 0.18):
            b.add(box((0.008, 0.11, 0.015), (x, H + 0.02, s * 0.12), rot=(s * 40, 0, 0)), "ad_galv")
    b.add(cyl(0.008, 0.008, (-0.12, H + 0.16, 0), (0.12, H + 0.16, 0), seg=6), "ad_galv")
    for x in (-0.12, 0.12):
        b.add(box((0.012, 0.06, 0.012), (x, H + 0.13, 0)), "ad_galv")
    # tools on the ground beside it
    tl = a.node("toolbox_tools")
    for k, (x, z, ang, ln) in enumerate(((0.45, 0.15, 20, 0.2), (0.5, 0.0, -10, 0.24), (0.42, -0.14, 55, 0.17))):
        tl.add(box((ln, 0.006, 0.018), (x, 0.003, z), rot=(0, ang, 0)), "ad_chrome")
        for e in (-1, 1):
            d = V((math.cos(math.radians(ang)), 0, -math.sin(math.radians(ang)))) * (ln / 2) * e
            tl.add(cyl(0.017, 0.017, V((x, 0.0, z)) + d, V((x, 0.007, z)) + d, seg=8), "ad_chrome")
    tl.add(cyl(0.012, 0.012, (-0.42, 0.012, 0.1), (-0.3, 0.012, 0.16), seg=8), "site_plastic_red")
    tl.add(cyl(0.003, 0.003, (-0.3, 0.012, 0.16), (-0.2, 0.012, 0.21), seg=5), "ad_chrome")
    tl.add(cyl(0.045, 0.04, (-0.45, 0.0, -0.12), (-0.45, 0.12, -0.12), seg=12), "ad_galv")
    tl.add(cyl(0.006, 0.004, (-0.45, 0.12, -0.12), (-0.38, 0.22, -0.08), seg=5), "ad_galv")
    tl.add(sphere(0.07, (-0.25, 0.015, -0.2), scale=(1.2, 0.25, 0.9), seg=10, rings=4), "ad_canvas")
    return a


def chair():
    a = AD("pike_chair", ao_dist=0.25, colour=rust_colour(12.0, 0.25),
           meta={"notes": "a folding camp chair facing +z, a thermos on the ground to its right (-x) with its cup"})
    c = a.node("chair")
    # X-legs each side, seat and back slung between
    for s in (-1, 1):
        x = s * 0.27
        tube_path([V((x, 0.0, 0.25)), V((x, 0.46, -0.2))], 0.011, "ad_steel_dark", c, seg=6)
        tube_path([V((x, 0.0, -0.25)), V((x, 0.46, 0.22))], 0.011, "ad_steel_dark", c, seg=6)
        tube_path([V((x, 0.44, -0.24)), V((x - s * 0.02, 0.92, -0.33))], 0.011, "ad_steel_dark", c, seg=6)
        tube_path([V((x, 0.6, -0.25)), V((x, 0.62, 0.2)), V((x, 0.46, 0.22))], 0.012, "ad_steel_dark", c, seg=6)    # arm
    seat = A.grid([-0.27 + 0.54 * i / 8 for i in range(9)], [-0.22 + 0.44 * k / 6 for k in range(7)],
                  lambda x, z: 0.42 - 0.05 * (1 - (x / 0.27) ** 2) * (1 - (z / 0.22) ** 2))
    c.add(seat, "ad_canvas", recalc=False)
    sb = A.grid([-0.27 + 0.54 * i / 8 for i in range(9)], [-0.22 + 0.44 * k / 6 for k in range(7)],
                lambda x, z: 0.416 - 0.05 * (1 - (x / 0.27) ** 2) * (1 - (z / 0.22) ** 2))
    for f in sb.faces:
        f.normal_flip()
    c.add(sb, "ad_canvas", recalc=False)
    c.add(box((0.52, 0.42, 0.012), (0, 0.7, -0.29), rot=(-12, 0, 0)), "ad_canvas")
    th = a.node("thermos")
    th.add(cyl(0.045, 0.045, (-0.45, 0.0, 0.1), (-0.45, 0.3, 0.1), seg=14), "ad_thermos", smooth=True, uv='cyl', grain=(0, 1, 0))
    th.add(cyl(0.048, 0.044, (-0.45, 0.3, 0.1), (-0.45, 0.37, 0.1), seg=14), "ad_plastic_dark")
    th.add(cyl(0.042, 0.035, (-0.33, 0.0, 0.16), (-0.33, 0.06, 0.16), seg=12, caps=True), "ad_plastic_dark")
    return a


def floodlight():
    a = AD("pike_floodlight", ao_dist=0.2, colour=rust_colour(13.0, 0.3),
           meta={"notes": "a battery work floodlight on a short stand, the lamp head (node floodlight_head, tilts about x) "
                          "aimed up toward the mast behind it (-z); lens material ad_lamp_white (emissive: set_lamp)",
                 "aim": [0, 0.57, -0.82]})
    b = a.node("floodlight_stand")
    b.add(box((0.3, 0.22, 0.2), (0, 0.11, 0.05), bevel=0.012), "ad_plastic_dark")       # battery box
    b.add(box((0.2, 0.03, 0.04), (0, 0.24, 0.05)), "ad_plastic_grey")                    # handle
    tube_path([V((0, 0.22, -0.02)), V((0, 0.62, -0.02))], 0.014, "ad_steel_dark", b, seg=6)
    for s in (-1, 1):
        b.add(box((0.012, 0.12, 0.03), (s * 0.13, 0.66, -0.02)), "ad_steel_dark")
    tube_path([V((0.02, 0.2, 0.15)), V((0.15, 0.1, 0.35)), V((0.4, 0.008, 0.5))], 0.007, "ad_cable", b)
    h = a.node("floodlight_head", pivot=(0, 0.68, -0.02), rot=(35, 0, 0))
    h.add(box((0.24, 0.18, 0.08), (0, 0.68, -0.04), bevel=0.01), "ad_plastic_grey")
    for i in range(5):
        h.add(box((0.24, 0.01, 0.03), (0, 0.6 + i * 0.04, -0.095)), "ad_plastic_grey")    # fins at the back
    h.add(box((0.2, 0.14, 0.01), (0, 0.68, 0.0)), "ad_lamp_white")
    return a


def radio():
    a = AD("pike_radio", ao_dist=0.2, colour=rust_colour(14.0, 0.35), buried_ok=0.32,
           meta={"notes": "a battered CB radio on an upturned crate with a coiled handset, its whip aerial on a 3 m pole "
                          "lashed to a stake beside it; node radio_led is a small green emissive LED (set_lamp)"})
    c = a.node("radio_crate")
    c.add(box((0.5, 0.32, 0.36), (0, 0.16, 0)), "ad_planks", grain=(1, 0, 0))
    r = a.node("radio")
    r.add(box((0.2, 0.06, 0.22), (0, 0.35, 0.0), bevel=0.006), "ad_steel_dark")
    r.add(box((0.17, 0.035, 0.005), (0, 0.35, 0.112)), "ad_plastic_dark")
    for x in (-0.06, 0.0, 0.06):
        r.add(cyl(0.008, 0.008, (x, 0.35, 0.112), (x, 0.35, 0.125), seg=8), "ad_plastic_grey")
    r.add(box((0.07, 0.11, 0.035), (0.17, 0.33, 0.08), rot=(0, 0, 15), bevel=0.01), "ad_plastic_dark")       # handset
    coil = [V((0.1 + 0.012 * math.cos(t), 0.37 - 0.004 * t + 0.012 * math.sin(t), 0.05 + t * 0.004)) for t in
            [i * 0.6 for i in range(26)]]
    tube_path(coil, 0.003, "ad_cable", r, seg=4)
    led = a.node("radio_led")
    led.add(sphere(0.005, (0.075, 0.37, 0.113), seg=6, rings=3), "ad_lamp_green")
    p = a.node("radio_aerial")
    p.add(box((0.06, 3.1, 0.06), (0.45, 1.25, -0.2), rot=(0, 0, -2)), "site_timber", grain=(0, 1, 0))
    p.add(cyl(0.01, 0.003, (0.42, 2.8, -0.2), (0.4, 4.1, -0.2), seg=5), "ad_galv")
    for y in (1.2, 2.2):
        p.add(torus(0.04, 0.006, (0.45, y, -0.2), rot=(90, 0, 0), seg=8, sides=4), "site_rope")
    tube_path([V((0.0, 0.35, -0.11)), V((0.1, 0.3, -0.25)), V((0.4, 0.4, -0.25)), V((0.43, 2.8, -0.22))], 0.004, "ad_cable", p)
    return a


def log_pile():
    a = AD("pike_log_pile", ao_dist=0.3, colour=rust_colour(15.0, 0.3),
           meta={"notes": "a pile of cut logs (ends toward +z) and a chopping stump with an axe in it (node axe)"})
    rnd = random.Random(21)
    p = a.node("log_pile")
    rows = [(5, 0.13), (4, 0.39), (3, 0.62)]
    for ri, (n, y) in enumerate(rows):
        for i in range(n):
            r = rnd.uniform(0.1, 0.14)
            x = (i - (n - 1) / 2) * 0.27 + rnd.uniform(-0.02, 0.02)
            z0, z1 = -0.45 + rnd.uniform(-0.04, 0.04), 0.45 + rnd.uniform(-0.04, 0.04)
            yy = y if ri == 0 else y
            p.add(cyl(r, r * 0.97, (x, yy, z0), (x, yy, z1), seg=10, caps=False), "site_bark_oak", smooth=True, uv='cyl', grain=(0, 0, 1))
            for (zz, s) in ((z0, -1), (z1, 1)):
                p.add(cyl(r * 0.96, r * 0.96, (x, yy, zz - s * 0.004), (x, yy, zz + s * 0.002), seg=10), "site_wood_end")
    s = a.node("chopping_stump")
    s.add(cyl(0.24, 0.22, (1.0, 0.0, 0.3), (1.0, 0.45, 0.3), seg=12, caps=False), "site_bark_oak", smooth=True, uv='cyl', grain=(0, 1, 0))
    s.add(cyl(0.225, 0.225, (1.0, 0.44, 0.3), (1.0, 0.452, 0.3), seg=12), "site_wood_end")
    for k in range(5):
        ang = rnd.uniform(0, math.tau)
        s.add(box((0.05, 0.03, 0.2), (1.0 + math.cos(ang) * 0.4, 0.015, 0.3 + math.sin(ang) * 0.4), rot=(0, rnd.uniform(0, 180), 0)), "site_wood_fresh")
    ax = a.node("axe", pivot=(1.0, 0.45, 0.3))
    ax.add(box((0.14, 0.09, 0.012), (1.0, 0.47, 0.3), rot=(0, 0, 0)), "ad_steel_dark")
    ax.add(box((0.03, 0.05, 0.03), (0.93, 0.5, 0.3)), "ad_steel_dark")
    ax.add(cyl(0.016, 0.014, (0.93, 0.48, 0.3), (0.55, 0.92, 0.3), seg=8), "site_wood_fresh")
    return a


# ============================================================================================ story props and atmosphere
def mast_wreck():
    a = AD("pike_mast_wreck", ao_dist=0.4, colour=rust_colour(16.0, 0.75), buried_ok=0.05,
           meta={"notes": "the mast after the storm: lying along +z from its foot (origin), bent at the stage-2 collar, the "
                          "dish crumpled, no beacon (the cage is torn off), a snapped guy wire coiled beside it; dark, "
                          "rust-streaked, no emission"})
    m = a.node("mast_wreck")
    pts = [V((0, 0.08, 0)), V((0.0, 0.08, 4.0)), V((0.05, 0.075, 5.2)), V((0.4, 0.07, 6.1)), V((1.2, 0.06, 8.8)),
           V((1.6, 0.05, 10.2))]
    m.add(sweep(pts[:3], 0.075, seg=10), "ad_galv", smooth=True)
    m.add(sweep(pts[2:5], 0.058, seg=10), "ad_galv", smooth=True)
    m.add(sweep(pts[4:], 0.042, seg=8), "ad_galv", smooth=True)
    m.add(sweep([pts[5], V((1.8, 0.045, 12.4)), V((1.7, 0.08, 13.2))], 0.042, seg=8), "ad_rust", smooth=True)
    for p, r in ((pts[2], 0.095), (pts[4], 0.076)):
        m.add(cyl(r, r, p - V((0, 0, 0.06)), p + V((0, 0, 0.06)), seg=10), "ad_steel_dark")
    # the crumpled dish lying face down beside the top
    d = a.node("mast_wreck_dish")
    dc = V((2.4, 0.0, 12.4))
    rings = []
    for i in range(6):
        rr = 0.55 * i / 5
        rings.append([V((dc.x + math.cos(j / 16 * math.tau) * max(rr, 1e-3) * (1 + 0.15 * math.sin(j * 1.9)),
                         0.02 + 0.16 * (1 - (rr / 0.55) ** 2) + 0.05 * math.sin(j * 2.3) * (rr / 0.55),
                         dc.z + math.sin(j / 16 * math.tau) * max(rr, 1e-3) * (1 + 0.1 * math.cos(j * 1.3)))) for j in range(16)])
    top = loft(rings)
    d.add(top, "ad_paint_white", smooth=True, recalc=False)
    bot = loft([[p - V((0, 0.012, 0)) for p in r] for r in rings])
    for f in bot.faces:
        f.normal_flip()
    d.add(bot, "ad_paint_white", smooth=True, recalc=False)
    # snapped guy wire, coiled in the grass, and the torn beacon cage
    g = a.node("mast_wreck_guy")
    coil = [V((-0.8 + 0.5 * math.cos(t) + t * 0.05, 0.006 + 0.004 * math.sin(t * 3), 6.0 + 0.4 * math.sin(t))) for t in
            [i * 0.35 for i in range(40)]]
    tube_path(coil, 0.004, "ad_galv", g, seg=4)
    tube_path([V((0.1, 0.06, 7.0)), V((-0.4, 0.01, 6.5)), coil[0]], 0.004, "ad_galv", g, seg=4)
    cg = a.node("mast_wreck_cage")
    cc = V((1.2, 0.0, 13.6))
    for k in range(4):
        ang = k / 4 * math.tau
        cg.add(cyl(0.005, 0.005, cc + V((math.cos(ang) * 0.07, 0.01, math.sin(ang) * 0.07)),
                   cc + V((math.cos(ang) * 0.03 + 0.15, 0.02, math.sin(ang) * 0.03)), seg=4), "ad_steel_dark")
    cg.add(torus(0.07, 0.005, cc + V((0, 0.012, 0)), rot=(90, 0, 0), seg=12, sides=4), "ad_steel_dark")
    return a


def smoke():
    a = AD("pike_smoke", ao_strength=0.0, ground=True, lod1=0.0,
           meta={"notes": "three crossed smoke cards 1.2 x 4.5 m rising from the origin (pike_smoke_card.png, alpha, "
                          "unshaded, no shadow): reads as a wisp from any side"})
    s = a.node("smoke")
    for k in range(3):
        rot = (0, k * 60, 0)
        c = (0, 2.25, 0)
        s.add(A.quad(1.2, 4.5, c, rot=rot), "ad_smoke", uv=uv01(1.2, 4.5, c, rot), recalc=False)
    return a


def strobe_card():
    a = AD("pike_strobe_card", ao_strength=0.0, ground=False, lod1=0.0,
           meta={"notes": "a 0.8 m red strobe flare card centred on the origin (pike_strobe_card.png, additive, "
                          "billboard); put it on the beacon and flash it (AntiDroneAssets.flash)"})
    s = a.node("strobe_card")
    s.add(A.quad(0.8, 0.8, (0, 0, 0)), "ad_strobe", uv=uv01(0.8, 0.8), recalc=False)
    return a


def tyre_tracks():
    a = AD("pike_tyre_tracks", ao_strength=0.0, lod1=0.0,
           meta={"notes": "decals on the ground (y 0.01): the trailer's two wheel tracks curving in along +z and the jerked "
                          "side-drag where it was pulled round; drape with AntiDroneAssets.drape"})
    t = a.node("tyre_tracks")
    for (x0, bend) in ((-0.82, -0.35), (0.82, -0.25)):
        pts = []
        for i in range(13):
            z = i * 0.5
            pts.append(V((x0 + bend * (z / 6) ** 2, 0.01, z)))
        for i in range(12):
            p0, p1 = pts[i], pts[i + 1]
            d = (p1 - p0).normalized(); sd = V((d.z, 0, -d.x)) * 0.11
            bm = A.loft([[p0 - sd, p0 + sd], [p1 - sd, p1 + sd]], close_ring=False)
            v0 = i * 0.5 / 3.0
            t.add(bm, "ad_decal_tyre", recalc=False,
                  uv=(lambda P0, D, V0: (lambda co, n: (0.25 + (co - P0).dot(V((D.z, 0, -D.x))) / 0.88,
                                                         V0 + (co - P0).dot(D) / 3.0)))(p0, d, v0))
    for f in t.bm.faces:
        if f.normal.y < 0:
            f.normal_flip()
    return a


def ridge_antenna():
    a = AD("pike_ridge_antenna", ao_dist=0.5, colour=rust_colour(17.0, 0.5), lod_end=120.0,
           meta={"notes": "a distant homemade lattice antenna on the ridge line, 18 m, three-legged, a small dish and a "
                          "red top lamp (node antenna_lamp, ad_lamp_red, emissive); a silhouette for the skyline"})
    t = a.node("antenna_tower")
    H = 18.0
    legs = []
    for k in range(3):
        ang = k / 3 * math.tau
        legs.append((V((math.cos(ang) * 0.9, 0, math.sin(ang) * 0.9)), V((math.cos(ang) * 0.22, H, math.sin(ang) * 0.22))))
    for (b0, b1) in legs:
        t.add(cyl(0.035, 0.025, b0, b1, seg=6), "ad_galv")
    nseg = 12
    for i in range(nseg):
        y0, y1 = H * i / nseg, H * (i + 1) / nseg
        for k in range(3):
            pa = legs[k][0].lerp(legs[k][1], i / nseg); pb = legs[(k + 1) % 3][0].lerp(legs[(k + 1) % 3][1], (i + 1) / nseg)
            pc = legs[(k + 1) % 3][0].lerp(legs[(k + 1) % 3][1], i / nseg)
            t.add(cyl(0.012, 0.012, pa, pb, seg=4), "ad_galv")
            t.add(cyl(0.012, 0.012, pa, pc, seg=4), "ad_galv")
    t.add(cyl(0.02, 0.008, V((0, H, 0)), V((0, H + 3.0, 0)), seg=5), "ad_galv")
    dc = V((0.0, H - 2.0, 0.35))
    rings = []
    for i in range(5):
        rr = 0.45 * i / 4
        rings.append([V((math.cos(j / 14 * math.tau) * max(rr, 1e-3), dc.y + math.sin(j / 14 * math.tau) * max(rr, 1e-3),
                         dc.z + 0.12 * (rr / 0.45) ** 2)) for j in range(14)])
    t.add(loft(rings), "ad_paint_white", smooth=True, recalc=False)
    bk = loft([[p - V((0, 0, 0.01)) for p in r] for r in rings])
    for f in bk.faces:
        f.normal_flip()
    t.add(bk, "ad_paint_white", smooth=True, recalc=False)
    l = a.node("antenna_lamp")
    l.add(sphere(0.07, (0, H + 0.08, 0), seg=10, rings=5), "ad_lamp_red")
    return a


def clearing_patch():
    a = AD("pike_clearing_patch", ao_strength=0.0, lod1=0.5, buried_ok=0.08,
           meta={"notes": "the 12 x 12 m clearing ground (pike_ridge_clearing textures, u, v 0..1 across it): the trailer "
                          "stands at the middle, hitch toward +z; outer ring sunk 6 cm so the terrain cuts a ragged edge; "
                          "drape with AntiDroneAssets.drape", "texture_size_m": 12.0})
    g = a.node("clearing_ground")
    bm = disc_patch(5.9, 5.9, 0.5, edge_sink=0.06, seed=4, wobble=0.06, top=0.02,
                    yfn=lambda x, z: 0.01 * fbm((x, 0, z), 0.8, 2, 4.0))
    g.add(bm, "ad_ground", recalc=False, uv=lambda co, n: (co.x / 12.0 + 0.5, 0.5 - co.z / 12.0))
    return a


PIKE = [jammer_trailer, jammer_mast, beacon_only, manifesto_board, warning_sign, shack, generator,
        lambda: fence("pike_fence", 4.0, seed=1), lambda: fence("pike_fence_8m", 8.0, seed=2),
        lambda: fence("pike_fence_folk", 4.0, folk=True, seed=3), cable_run,
        tarp, toolbox, chair, floodlight, radio, log_pile, mast_wreck, smoke, strobe_card, tyre_tracks, ridge_antenna,
        clearing_patch]
