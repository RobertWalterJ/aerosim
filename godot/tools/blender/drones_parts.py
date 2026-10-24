# Shared drone sub-assemblies (lane/drones): frame outlines, brushless motors, propellers, stacks, cameras, connectors,
# the night-vision pod. Modelling frame: metres, +Y forward, +X right, +Z up (see drones_lib.py).
import math

from mathutils import Matrix, Vector

import drones_lib as L
from drones_lib import RX, RY, RZ, T, Vector as V

# motor order everywhere: FR, RR, RL, FL (the game's DroneView order 0..3). Spin seen from above: FR and RL clockwise,
# RR and FL anticlockwise (DroneView: i % 2 == 1 turns anticlockwise).
CORNERS = [("fr", 1, 1), ("rr", 1, -1), ("rl", -1, -1), ("fl", -1, 1)]
SPIN = {"fr": -1, "rr": 1, "rl": -1, "fl": 1}          # +1 anticlockwise from above


def motor_xy(d):
    return {c: (sx * d, sy * d) for (c, sx, sy) in CORNERS}


# ------------------------------------------------------------------------------------------------ frame outline
def unibody_outline(d, body, w0, w1, rp, pad_n=10, angular=False):
    """Outline (CCW) of a one-piece frame: `body` gives the four root points where the arms leave the centre plate
    {corner: (x, y)} plus extra nose/tail points; arms run to the motors at (+-d, +-d) and end in a pad of radius rp.
    Walks the outline round: out along each arm's right edge, round its pad, back along its left edge, then along the
    body to the next arm."""
    order = ["fr", "fl", "rl", "rr"]                    # anticlockwise from the front right
    mx = motor_xy(d)
    pts = []
    between = body.get("between", {})
    for k, c in enumerate(order):
        root = Vector(body[c] + (0.0,))
        m = Vector(mx[c] + (0.0,))
        u = (m - root).normalized()
        n = Vector((-u.y, u.x, 0.0))
        back = math.sqrt(max(rp * rp - w1 * w1, 0.0))
        pts.append(tuple((root - n * w0)[:2]))
        pts.append(tuple((m - u * back * 1.0 - n * w1 - u * (0.012 if angular else 0.0))[:2]))
        a_u = math.atan2(u.y, u.x)
        span = math.pi - math.asin(min(w1 / rp, 0.99))
        steps = pad_n
        for s in range(steps + 1):
            a = a_u - span + 2 * span * s / steps
            if angular and s not in (0, steps) and s % 2 == 1:
                rr = rp * 1.04
            else:
                rr = rp
            pts.append((m.x + rr * math.cos(a), m.y + rr * math.sin(a)))
        pts.append(tuple((m - u * back * 1.0 + n * w1 - u * (0.012 if angular else 0.0))[:2]))
        pts.append(tuple((root + n * w0)[:2]))
        for p in between.get(c, []):
            pts.append(p)
    # remove near duplicates
    out = []
    for p in pts:
        if not out or (abs(out[-1][0] - p[0]) + abs(out[-1][1] - p[1])) > 1e-6:
            out.append(p)
    return out


def holes(obj, kit, centres, r, depth=(-0.01, 0.02), seg=12):
    cut = [L.cyl(r, depth[1] - depth[0], seg, "carbon", T(x, y, depth[0]), name="cut") for (x, y) in centres]
    L.boolean(obj, cut)


def slot_cutters(slots, z0=-0.01, z1=0.05):
    """Rounded slots [(x, y, length, width, angle)] as cutter prisms."""
    out = []
    for (x, y, ln, w, a) in slots:
        poly = []
        for k in range(9):
            t = -math.pi / 2 + math.pi * k / 8
            poly.append((ln / 2 + w / 2 * math.cos(t), w / 2 * math.sin(t)))
        for k in range(9):
            t = math.pi / 2 + math.pi * k / 8
            poly.append((-ln / 2 + w / 2 * math.cos(t), w / 2 * math.sin(t)))
        out.append(L.plate(poly, z0, z1, "carbon", xf=T(x, y, 0) @ RZ(a), chamfer=0.0, name="slot"))
    return out


# ------------------------------------------------------------------------------------------------ brushless motor
def motor(kit, c, x, y, z, spec):
    """An outrunner on its mount at (x, y), base on z. spec: r (bell outer radius), h (bell height), base_r, bell, band,
    base (material keys), shaft_top (height of the shaft end above z). Returns the height of the bell top.
    The stator, windings, magnets and bearing are modelled, seen through the windows in the bell top and the gap under
    its rim."""
    q = kit.q
    s = kit.seg(18)
    ro = spec["r"]; h = spec["h"]; rb = spec["base_r"]
    ri = ro - 0.0014
    zb0 = z; zb1 = z + 0.0032                     # the base (stator mount)
    zr0 = zb1 + 0.0007                            # bell rim
    zt = zr0 + h                                  # bell top
    # base: a short drum with a chamfered top edge and a raised boss round the bearing
    base = L.lathe([(0, zb0), (rb, zb0), (rb, zb1 - 0.0005), (rb - 0.0005, zb1), (0.0055, zb1),
                    (0.0055, zb1 + 0.0005), (0, zb1 + 0.0005)], s, spec["base"], T(x, y, 0), name="mbase")
    kit.add(base, "body", "hull")
    # bell: outer wall with a chamfered rim and a fillet into the top, the top web, a hub boss round the shaft
    if q == 0:
        prof = [(ri, zr0), (ro, zr0), (ro, zt - 0.0013), (ro - 0.0013, zt), (0.0048, zt), (0.0044, zt + 0.0012), (0.0029, zt + 0.0012),
                (0.0029, zt - 0.0014), (ri, zt - 0.0014)]
    else:
        prof = [(0, zr0), (ro, zr0), (ro, zt - 0.0013), (ro - 0.0013, zt), (0.0044, zt + 0.0012), (0, zt + 0.0012)]
    bell = L.lathe(prof, s, spec["bell_side"], T(x, y, 0), name="bell", loop=(q == 0), axial_key=spec["bell"])
    if q == 0:
        # windows in the top between the spokes, so the copper windings show
        nwin = spec.get("windows", 6)
        cut = []
        for k in range(nwin):
            a = 2 * math.pi * (k + 0.5) / nwin
            r_in, r_out = 0.0058, ri - 0.0016
            half = math.pi / nwin * 0.62
            pts = [(r_in * math.cos(a - half * 0.8), r_in * math.sin(a - half * 0.8))]
            for t in range(5):
                aa = a - half + 2 * half * t / 4
                pts.append((r_out * math.cos(aa), r_out * math.sin(aa)))
            pts.append((r_in * math.cos(a + half * 0.8), r_in * math.sin(a + half * 0.8)))
            cut.append(L.plate(pts, zt - 0.004, zt + 0.004, spec["bell"], xf=T(x, y, 0), chamfer=0.0, name="win"))
        L.boolean(bell, cut)
    kit.add(bell, "body", "hull")
    if q == 0:
        # magnets: arc blocks on the inner wall (14 poles), nickel plated, seen in the gap under the rim and through the windows
        nm = 14
        for k in range(nm):
            a0 = 2 * math.pi * k / nm + 0.025
            a1 = 2 * math.pi * (k + 1) / nm - 0.025
            kit.add(L.arc_block(ri - 0.0011, ri - 0.00005, zr0 + 0.0004, zt - 0.0018, a0, a1, "magnet", T(x, y, 0), seg=1, name="mag"), "body", "none")
        # stator: the laminated tooth tips (a dark ring) and the copper windings inside them
        rs = ri - 0.0014
        kit.add(L.lathe([(rs - 0.0011, zr0 + 0.0009), (rs, zr0 + 0.0009), (rs, zt - 0.0024), (rs - 0.0011, zt - 0.0024)], 12, "lamination",
                        T(x, y, 0), name="stat", loop=True), "body", "none")
        kit.add(L.lathe([(0.0034, zr0 + 0.0005), (rs - 0.0012, zr0 + 0.0005), (rs - 0.0009, zr0 + 0.002), (rs - 0.0009, zt - 0.0032),
                         (rs - 0.0012, zt - 0.0018), (0.0034, zt - 0.0018)], 12, "copper", T(x, y, 0), name="wind", loop=True), "body", "none")
        # the top bearing in the hub: steel races and the black rubber seal between them
        kit.add(L.lathe([(0.0026, zt + 0.0011), (0.0044, zt + 0.0011), (0.0044, zt + 0.00125), (0.0026, zt + 0.00125)], 10, "steel", T(x, y, 0), name="brg", loop=True), "body", "none")
        kit.add(L.lathe([(0.0031, zt + 0.00126), (0.0037, zt + 0.00126), (0.0037, zt + 0.0013), (0.0031, zt + 0.0013)], 10, "rubber", T(x, y, 0), name="seal", loop=True), "body", "none")
    # the shaft (spins with the bell; its top is drawn with the prop)
    kit.add(L.lathe([(0, zb0 - 0.0008), (0.0025, zb0 - 0.0008), (0.0025, zt + 0.0013), (0, zt + 0.0013)], 8, "titanium", T(x, y, 0), name="shaft"), "body", "none")
    return zt


# ------------------------------------------------------------------------------------------------ propeller
def prop(kit, c, x, y, z, spec):
    """A propeller as its own node prop_<c> with the pivot on the shaft at the hub's middle. spec: the blade numbers
    (R, root, c_root, c_max, t_max, c_tip, sweep, pd, tc, n, phase), key, tip_key, hub (r, h), nut_key."""
    q = kit.q
    node = "prop_" + c
    hand = SPIN[c]
    hub_r = spec["hub_r"]; hub_h = spec["hub_h"]
    zc = z + hub_h * 0.5
    kit.pivots[node] = Vector((x, y, zc))
    nb = spec["n"]
    n_sec = (9, 6, 4)[q]; m_sec = (4, 3, 2)[q]
    rows = L.blade(spec, hand, n_sec, m_sec)
    rest = spec.get("rest", {}).get(c, 0.0)
    for b in range(nb):
        a = rest + 2 * math.pi * b / nb
        M = T(x, y, zc) @ RZ(a)
        ob = L.blade_mesh(rows, spec["key"], spec.get("tip_key"), name="blade")
        ob.data.transform(M)
        outline = [tuple((M @ V((px, py, 0.0)))[:2]) for (px, py) in L.blade_outline(rows)]
        kit.add(ob, node, "hull", plan_pts=outline, thin=True)
    s = kit.seg(16)
    hub = [(0, -hub_h * 0.5), (hub_r, -hub_h * 0.5), (hub_r, hub_h * 0.3), (hub_r * 0.8, hub_h * 0.5), (0, hub_h * 0.5)]
    kit.add(L.lathe(hub, s, spec["key"], T(x, y, zc), name="hub"), node, "none")
    # washer, the M5 lock nut and its domed cap
    zt = zc + hub_h * 0.5
    nk = spec.get("nut_key", "anod_orange")
    if q == 0:
        kit.add(L.lathe([(0, zt), (0.0052, zt), (0.0052, zt + 0.0006), (0, zt + 0.0006)], 12, "steel", T(x, y, 0), name="washer"), node, "none")
    kit.add(L.lathe([(0, zt + 0.0006), (0.0047, zt + 0.0006), (0.0047, zt + 0.0036), (0, zt + 0.0036)], 6, nk, T(x, y, 0), name="nut"), node, "none")
    if q < 2:
        dome = [(0, zt + 0.0036), (0.0041, zt + 0.0036), (0.0036, zt + 0.0052), (0.0021, zt + 0.006), (0, zt + 0.0062)]
        kit.add(L.lathe(dome, 12, nk, T(x, y, 0), name="dome"), node, "none")
    return node


# ------------------------------------------------------------------------------------------------ flight controller and ESC
def board(kit, cx, cy, z, size, kind):
    """A 30 x 30 stack board: black solder mask over copper with gold pads, the parts on it. kind 'esc' or 'fc'."""
    q = kit.q
    th = 0.0016
    b = L.rbox((size, size, th), "pcb", T(cx, cy, z + th / 2), bevel=0.0008, segs=1, name=kind)
    # the PCB image maps once over the board's top
    me = b.data
    uvl = me.uv_layers.active
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uvl.data[li].uv = ((co.x - cx) / size + 0.5, (co.y - cy) / size + 0.5)
    kit.add(b, "body", "hull")
    zt = z + th
    if q == 2:
        return zt
    if kind == "esc":
        for (sx, sy) in ((1, 1), (1, -1), (-1, -1), (-1, 1)):           # MOSFET pairs and a driver at each corner
            for k in range(2):
                kit.add(L.rbox((0.005, 0.006, 0.0011), "chip", T(cx + sx * (0.0085 + k * 0.0058), cy + sy * 0.0085, zt + 0.00055), bevel=0.0, name="fet"), "body", "none")
            if q == 0:
                kit.add(L.rbox((0.0035, 0.0035, 0.0008), "chip", T(cx + sx * 0.0045, cy + sy * 0.0042, zt + 0.0004), bevel=0.0, name="drv"), "body", "none")
        if q == 0:
            for k in range(6):                                          # small ceramic capacitors
                kit.add(L.rbox((0.0016, 0.0008, 0.0008), "smd", T(cx - 0.006 + k * 0.0024, cy, zt + 0.0004), bevel=0.0, name="mlcc"), "body", "none")
    else:
        kit.add(L.rbox((0.0072, 0.0072, 0.0011), "chip", T(cx, cy + 0.002, zt + 0.00055), bevel=0.0003, segs=1, name="mcu"), "body", "none")
        if q == 0:
            kit.add(L.rbox((0.003, 0.003, 0.0009), "chip", T(cx + 0.007, cy - 0.006, zt + 0.00045), bevel=0.0, name="gyro"), "body", "none")
            kit.add(L.rbox((0.002, 0.002, 0.0008), "chip", T(cx - 0.007, cy - 0.007, zt + 0.0004), bevel=0.0, name="baro"), "body", "none")
            for k in range(8):
                kit.add(L.rbox((0.0016, 0.0008, 0.0008), "smd", T(cx - 0.008 + k * 0.0022, cy - 0.0105, zt + 0.0004), bevel=0.0, name="mlcc"), "body", "none")
            # three small white JST-SH sockets and a USB-C port on the side
            for (px, py, w) in ((cx - 0.0105, cy + 0.006, 0.0062), (cx + 0.0105, cy + 0.006, 0.005), (cx, cy - 0.0125, 0.008)):
                kit.add(L.rbox((w if abs(px - cx) < 0.002 else 0.0042, 0.0042 if abs(px - cx) < 0.002 else w, 0.0029), "nylon_white", T(px, py, zt + 0.00145), bevel=0.0, name="jst"), "body", "none")
            kit.add(L.rbox((0.0034, 0.009, 0.0032), "steel", T(cx + size / 2 - 0.0016, cy - 0.002, zt + 0.0016), bevel=0.0012, segs=2, name="usb"), "body", "none")
            kit.add(L.rbox((0.0014, 0.007, 0.002), "chip", T(cx + size / 2 - 0.0002, cy - 0.002, zt + 0.0016), bevel=0.0006, segs=1, name="usbmouth"), "body", "none")
    return zt


# ------------------------------------------------------------------------------------------------ connectors and cables
def xt60(kit, p, axis, male, node="body"):
    """An XT60 housing: yellow nylon, 15.5 x 8 mm with the chamfered corners that key it, 16 mm long, along `axis`.
    male: the battery side (with the gold pins showing in its mouth)."""
    m = L.orient(Vector(p), axis)
    kit.add(L.rbox((0.0155, 0.0082, 0.016), "nylon_yellow", m @ RX(math.pi / 2), bevel=0.0012, segs=2, name="xt60"), node, "hull")
    if kit.q == 0:
        # the moulded grip ridges and (male) the two gold pins in the mouth
        for k in range(3):
            kit.add(L.rbox((0.0158, 0.0006, 0.0008), "nylon_yellow", m @ T(0, 0.0042, -0.004 + k * 0.0018), bevel=0.0, name="ridge"), node, "none")
        if male:
            for sx in (-1, 1):
                kit.add(L.cyl(0.0018, 0.004, 10, "gold", m @ T(sx * 0.0035, 0, 0.0075), name="pin"), node, "none")


def cap_lowesr(kit, p, axis, node="body"):
    """The low-ESR electrolytic capacitor on the battery leads: a sleeved can with a stripe and two legs."""
    m = L.orient(Vector(p), axis)
    s = kit.seg(18)
    kit.add(L.lathe([(0, 0), (0.0048, 0), (0.005, 0.0005), (0.005, 0.0195), (0.0046, 0.02), (0, 0.02)], s, "cap_sleeve", m, name="cap"), node, "hull")
    if kit.q == 0:
        kit.add(L.arc_block(0.00502, 0.00512, 0.0006, 0.0194, -0.5, 0.5, "cap_stripe", m, seg=3, name="stripe"), node, "none")
        kit.add(L.lathe([(0, 0.02), (0.0042, 0.02), (0.0042, 0.0203), (0, 0.0203)], s, "alu", m, name="captop"), node, "none")


# ------------------------------------------------------------------------------------------------ cameras
def lens(kit, p, axis, r, length, coat, node, glass_node=None, ring_key="lens_ring", focus_ring=True):
    """A lens barrel looking along `axis`: a matte ring (knurled focus ring when near), the front glass and, set back
    under it, the coloured anti-reflection coating that tints the reflection of the sky."""
    m = L.orient(Vector(p), axis)
    s = kit.seg(20)
    prof = [(0, 0), (r * 0.92, 0), (r * 0.92, length * 0.55), (r, length * 0.6), (r, length), (r * 0.82, length * 1.02), (r * 0.82, length * 0.97), (0, length * 0.97)]
    kit.add(L.lathe(prof, s, ring_key, m, name="barrel"), node, "hull")
    if focus_ring and kit.q == 0:
        kit.add(L.lathe([(r * 1.0, length * 0.62), (r * 1.06, length * 0.66), (r * 1.06, length * 0.86), (r * 1.0, length * 0.9)], 20, "plastic_black", m, name="focus", loop=True), node, "none")
    gnode = glass_node or node
    kit.add(L.lathe([(0, length * 0.985), (r * 0.8, length * 0.97), (r * 0.8, length * 0.955), (0, length * 0.955)], s, "glass", m, name="glass"), gnode, "none")
    if kit.q < 2:
        kit.add(L.lathe([(0, length * 0.94), (r * 0.62, length * 0.925), (r * 0.62, length * 0.91), (0, length * 0.91)], s, coat, m, name="coat"), gnode, "none")


def fpv_cam(kit, p, tilt, node, lens_node):
    """A micro FPV camera (19 mm): a black aluminium body, an M12 lens with a knurled ring, side screws."""
    m = T(*p) @ RX(tilt)
    kit.add(L.rbox((0.019, 0.017, 0.019), "anod_black", m, bevel=0.0018, segs=2, name="fpvcam"), node, "hull")
    if kit.q == 0:
        kit.add(L.rbox((0.0196, 0.0012, 0.0196), "anod_black", m @ T(0, 0.009, 0), bevel=0.0009, segs=1, name="bezel"), node, "none")
        kit.add(L.rbox((0.012, 0.004, 0.009), "plastic_black", m @ T(0, -0.0105, 0), bevel=0.0012, segs=1, name="camback"), node, "none")
    q = m @ V((0, 0.009, 0))
    ax = (m.to_3x3() @ V((0, 1, 0)))
    lens(kit, q, ax, 0.0072, 0.0095, "coat_violet", lens_node)
    kit.pivots[lens_node] = q
    for sx in (-1, 1):
        L.screw(kit, m @ V((sx * 0.0098, 0.0, 0.0)), m.to_3x3() @ V((sx, 0, 0)), r=0.0021, key=kit.screw_key)


def nv_pod(kit, xf, node, lens_node, led_node):
    """The night-vision pod: a clip-on low-light camera in a dark grey anodised case with cooling fins, a fast lens
    behind a knurled bezel with a green coating, two infrared illuminator LEDs, a status LED and a lead out of the back.
    Local frame: origin at the middle of the mounting face (the top), the body hangs below it, the lens looks +Y.
    40 x 34 x 46 mm (beside the 52 x 42 x 62 mm thermal pod)."""
    q = kit.q
    W, D, H = 0.034, 0.04, 0.03
    zc = -0.004 - H / 2
    kit.add(L.rbox((W, D, H), "anod_grey", xf @ T(0, -0.002, zc), bevel=0.0035, segs=3 if q == 0 else 2, name="podbody"), node, "hull")
    # the clip: a plate on top with a dovetail rail and a knurled thumbscrew on the side
    kit.add(L.rbox((0.022, 0.03, 0.0026), "anod_black", xf @ T(0, -0.002, -0.0013 - 0.0014), bevel=0.0008, segs=1, name="clip"), node, "hull")
    if q < 2:
        for sx in (-1, 1):
            kit.add(L.rbox((0.003, 0.03, 0.0016), "anod_black", xf @ T(sx * 0.0115, -0.002, -0.0011), bevel=0.0005, segs=1, name="rail"), node, "none")
        kit.add(L.lathe([(0, 0), (0.0042, 0), (0.0042, 0.004), (0, 0.004)], 24, "alu", xf @ T(0.017, -0.006, -0.0045) @ RY(math.pi / 2), name="thumb"), node, "none")
    if q == 0:
        # knurl grooves on the thumbscrew and cooling fins down both sides and across the back
        for k in range(12):
            a = 2 * math.pi * k / 12
            kit.add(L.rbox((0.0006, 0.0006, 0.004), "anod_black", xf @ T(0.019, -0.006 + 0.0042 * math.cos(a), -0.0045 + 0.0042 * math.sin(a)) @ RY(math.pi / 2), bevel=0.0, segs=1, name="kn"), node, "none")
        for sx in (-1, 1):
            for k in range(5):
                kit.add(L.rbox((0.0022, 0.022, 0.0012), "anod_grey", xf @ T(sx * (W / 2 + 0.0008), -0.008, zc - 0.009 + k * 0.0045), bevel=0.0, name="fin"), node, "none")
        for k in range(5):
            kit.add(L.rbox((0.026, 0.0022, 0.0012), "anod_grey", xf @ T(0, -0.002 - D / 2 - 0.0008, zc - 0.009 + k * 0.0045), bevel=0.0, name="fin"), node, "none")
    # front: knurled bezel, lens, coating
    fy = -0.002 + D / 2
    fp = xf @ V((0, fy, zc + 0.001))
    ax = xf.to_3x3() @ V((0, 1, 0))
    bez = [(0, 0), (0.0128, 0), (0.0128, 0.0042), (0.0118, 0.0052), (0.0104, 0.0052), (0.0104, 0.004), (0, 0.004)]
    kit.add(L.lathe(bez, kit.seg(24), "anod_black", L.orient(fp, ax), name="bezel"), node, "hull")
    if q == 0:
        for k in range(18):
            a = 2 * math.pi * k / 18
            kit.add(L.rbox((0.0007, 0.0007, 0.0032), "anod_grey", L.orient(fp, ax) @ T(0.0129 * math.cos(a), 0.0129 * math.sin(a), 0.0022), bevel=0.0, segs=1, name="knurl"), node, "none")
    lp = fp + ax * 0.0046
    kit.pivots[lens_node] = lp
    kit.add(L.lathe([(0, 0.0012), (0.0099, 0.0004), (0.0099, -0.0002), (0, -0.0002)], kit.seg(28), "glass", L.orient(lp, ax), name="podglass"), lens_node, "none")
    if q < 2:
        kit.add(L.lathe([(0, -0.0008), (0.0084, -0.0012), (0.0084, -0.0016), (0, -0.0016)], kit.seg(28), "coat_green", L.orient(lp, ax), name="podcoat"), lens_node, "none")
    # infrared illuminators at the top corners of the face, a status LED on the top at the back
    for sx in (-1, 1):
        ip = xf @ V((sx * 0.0128, fy + 0.0004, -0.0085))
        kit.add(L.lathe([(0, 0), (0.0024, 0), (0.0024, 0.0012), (0, 0.0012)], kit.seg(16), "anod_black", L.orient(ip, ax), name="irring"), node, "none")
        kit.add(L.lathe([(0, 0.0012), (0.0016, 0.0012), (0.0013, 0.0018), (0, 0.0019)], kit.seg(12), "lamp_ir", L.orient(ip, ax), name="ir"), led_node + "_ir" if q == 0 else node, "none")
    back = xf.to_3x3() @ V((0, -1, 0))
    sp = xf @ V((-0.0095, -0.002 - D / 2 - 0.0016, -0.0095))
    kit.add(L.lathe([(0, 0), (0.0018, 0), (0.0016, 0.0009), (0, 0.001)], kit.seg(12), "lamp_status", L.orient(sp, back), name="led"), led_node, "none")
    kit.pivots[led_node] = sp
    if q == 0:
        kit.pivots[led_node + "_ir"] = xf @ V((0, fy, -0.0085))
    # the lead: a short black cable from the back into a strain relief
    bp = xf @ V((0.006, -0.002 - D / 2, zc + 0.004))
    kit.add(L.rbox((0.009, 0.006, 0.0045), "plastic_black", T(*bp) @ T(0, -0.002, 0), bevel=0.0012, segs=1, name="plug"), node, "none")
    if q < 2:
        bdir = xf.to_3x3() @ V((0, -1, 0))
        p0 = bp + bdir * 0.005
        kit.add(L.tube([p0, p0 + bdir * 0.008 + V((0, 0, 0.004)), p0 + bdir * 0.012 + V((0, 0, 0.012))], 0.0014, "silicone_black", seg=kit.seg(8), name="lead"), node, "none")
