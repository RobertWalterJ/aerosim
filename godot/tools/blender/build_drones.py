# Build the Facade kit drones in Blender 4.2 and export them as glTF 2.0 (lane/drones).
#   blender -b -P godot/tools/blender/build_drones.py -- [only=raptor_race_a,nightowl_a,night_vision_pod_a] [preview=<dir>]
# Writes godot/assets/models/drones/<name>.glb, <name>_lod1.glb, <name>_lod2.glb and <name>.json (the manifest the game's
# DroneAssets reads: centre of mass, camera eye, prop pivots and radius, blur colours, triangle counts, and the plan and
# side outlines of every part for the drone chooser's drawing).
# Frame in the files: metres, +Y up, +Z forward (nose), the model's right is -x, origin on the ground under the middle
# (the lowest point of the feet). The night-vision pod's origin is the middle of its mounting face (its top).
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import drones_lib as L  # noqa: E402
import drones_parts as P  # noqa: E402
from drones_lib import RX, RY, RZ, T  # noqa: E402

V = Vector
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "drones"))


def band_tie(kit, centre, along, w, h, node="body", key="nylon_black"):
    """A cable tie pulled round a flat bundle (an arm and the cable on it): a rounded rectangle band, square head, cut tail."""
    if kit.q > 0:
        return
    m = L.orient(V(centre), along)
    th = 0.0007
    outer = L.rbox((w + 2 * th, h + 2 * th, 0.0024), key, m, bevel=min(w, h) * 0.3, segs=1, name="tie")
    inner = L.rbox((w, h, 0.004), key, m, bevel=min(w, h) * 0.28, segs=1, name="tiecut")
    L.boolean(outer, [inner])
    kit.add(outer, node, "none")
    hp = m @ V((w / 2 + th + 0.0012, 0, 0))
    kit.add(L.rbox((0.0026, 0.0034, 0.0028), key, T(*hp) @ m.to_3x3().to_4x4(), bevel=0.0, name="tiehead"), node, "none")
    d = m.to_3x3() @ V((1, 0, 0))
    kit.add(L.tube([hp + d * 0.0012, hp + d * 0.004 + m.to_3x3() @ V((0, 0.001, 0)), hp + d * 0.0068 + m.to_3x3() @ V((0, 0.0016, 0))], 0.0006, key, seg=4, sub=2, name="tail"), node, "none")


def wires3(kit, a, b, r=0.0007, sag=0.0008, keys=("silicone_black",) * 3, spread=0.0016, node="body"):
    a = V(a); b = V(b)
    d = (b - a).normalized()
    side = d.cross(V((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else V((1, 0, 0))
    for k, s in enumerate((-1, 0, 1)):
        o = side * spread * s
        mid = (a + b) * 0.5 + o + V((0, 0, -sag))
        kit.add(L.tube([a + o, mid, b + o], r, keys[k], seg=4, sub=2, name="wire"), node, "none")


# ================================================================================================ the Raptor
def raptor(kit):
    q = kit.q
    kit.screw_key = "anod_orange"
    d = 0.08
    # --- the frame: a 5 mm carbon unibody with angular motor pads, a 2 mm top plate on orange standoffs
    body = {"fr": (0.02, 0.03), "fl": (-0.02, 0.03), "rl": (-0.02, -0.034), "rr": (0.02, -0.034),
            "between": {"fr": [(0.0165, 0.045), (0.0165, 0.061), (0.011, 0.07), (-0.011, 0.07), (-0.0165, 0.061), (-0.0165, 0.045)],
                        "fl": [(-0.021, 0.012), (-0.021, -0.016)],
                        "rl": [(-0.013, -0.056), (0.013, -0.056)],
                        "rr": [(0.021, -0.016), (0.021, 0.012)]}}
    outline = P.unibody_outline(d, body, 0.0085, 0.0062, 0.0135, pad_n=10 if q < 2 else 6, angular=True)
    uni = L.plate(outline, 0.0, 0.005, "carbon", "carbon_edge", name="unibody", chamfer=0.0004 if q < 2 else 0.0)
    mx = P.motor_xy(d)
    if q == 0:
        cut = []
        for c, (x, y) in mx.items():
            # a lightening slot along each arm
            u = V((x, y, 0)).normalized()
            mid = V((x, y, 0)) * 0.56
            cut += P.slot_cutters([(mid.x, mid.y, 0.024, 0.0042, math.atan2(u.y, u.x))])
        L.boolean(uni, cut)
    kit.add(uni, "body", "plate", plan_pts=outline)
    top = [(-0.0175, -0.05), (0.0175, -0.05), (0.0175, -0.044), (0.0175, 0.036), (0.012, 0.044), (-0.012, 0.044), (-0.0175, 0.036)]
    tp = L.plate(top, 0.030, 0.032, "carbon", "carbon_edge", name="topplate")
    if q < 2:
        L.boolean(tp, P.slot_cutters([(0.0, 0.026, 0.014, 0.005, 0.0), (0.0, -0.032, 0.012, 0.005, 0.0)]))
    kit.add(tp, "body", "plate", plan_pts=top)
    so = [(sx * 0.0145, sy) for sx in (-1, 1) for sy in (0.036, -0.042)]
    for (x, y) in so:
        kit.add(L.lathe([(0, 0.005), (0.0029, 0.005), (0.0029, 0.030), (0, 0.030)], 6, "anod_orange", T(x, y, 0) @ RZ(math.pi / 6), name="standoff"), "body", "side")
        L.screw(kit, (x, y, 0.032), (0, 0, 1), key="anod_orange")
        L.screw(kit, (x, y, 0.0), (0, 0, -1), key="anod_orange", simple=True)
    # camera side plates
    side = [(0.03, 0.005), (0.064, 0.005), (0.0705, 0.011), (0.0705, 0.023), (0.063, 0.0298), (0.03, 0.0298)]
    perm = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    for sx in (-1, 1):
        x0 = sx * 0.0115 + (0 if sx > 0 else -0.002)
        kit.add(L.plate(side, 0.0, 0.002, "carbon", "carbon_edge", xf=T(x0, 0, 0) @ perm, name="sideplate"), "body", "side")
    # --- the stack: 4-in-1 ESC on soft grommets, the flight controller above it, M3 bolts and nylon nuts
    for (sx, sy) in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
        x, y = sx * 0.01525, sy * 0.01525
        kit.add(L.lathe([(0, 0.005), (0.0034, 0.005), (0.0036, 0.0068), (0.0034, 0.0085), (0, 0.0085)], kit.seg(10), "tpu_orange", T(x, y, 0), name="grommet"), "body", "none")
        kit.add(L.lathe([(0, 0.0101), (0.0032, 0.0101), (0.0034, 0.0133), (0.0032, 0.0165), (0, 0.0165)], kit.seg(10), "tpu_orange", T(x, y, 0), name="grommet"), "body", "none")
        kit.add(L.lathe([(0, 0.0), (0.0015, 0.0), (0.0015, 0.0215), (0, 0.0215)], 8, "steel_dark", T(x, y, 0), name="bolt"), "body", "none")
        P_nut = (x, y, 0.0181)
        L.nut(kit, P_nut, key="nylon_black", r=0.003, h=0.0024)
    P.board(kit, 0.0, 0.0, 0.0085, 0.036, "esc")
    P.board(kit, 0.0, 0.0, 0.0165, 0.034, "fc")
    kit.add(L.rbox((0.0016, 0.0012, 0.0006), "lamp_blue", T(0.0075, 0.0105, 0.0184), bevel=0.0001, segs=1, name="sled"), "status_led", "none")
    kit.pivots["status_led"] = V((0.0075, 0.0105, 0.0184))
    # a digital video transmitter behind the stack: finned aluminium heatsink on a board
    kit.add(L.rbox((0.024, 0.022, 0.0016), "pcb", T(0.0, -0.034, 0.0105), bevel=0.0006, segs=1, name="vtxpcb"), "body", "side")
    kit.add(L.rbox((0.022, 0.02, 0.0045), "anod_grey", T(0.0, -0.034, 0.0137), bevel=0.0008, segs=1, name="vtxsink"), "body", "side")
    if q < 2:
        for k in range(6):
            kit.add(L.rbox((0.0011, 0.019, 0.006), "anod_grey", T(-0.009 + k * 0.0036, -0.034, 0.0185), bevel=0.0, name="fin"), "body", "none")
    # --- motors, props, arm LEDs, landing pads and wires
    mspec = {"r": 0.0139, "h": 0.0125, "base_r": 0.0128, "bell": "anod_orange_spun", "bell_side": "anod_orange", "base": "anod_black", "windows": 6}
    pspec = {"R": 0.0635, "n": 3, "root": 0.0062, "c_root": 0.15, "c_max": 0.245, "t_max": 0.45, "c_tip": 0.14, "sweep": 0.07, "pd": 0.85,
             "tc": 0.14, "key": "prop_orange", "hub_r": 0.0066, "hub_h": 0.0065, "nut_key": "anod_orange",
             "rest": {"fr": 0.5, "rr": 1.8, "rl": 3.1, "fl": 4.4}}
    led_mat = {"fr": "lamp_green", "fl": "lamp_red", "rr": "lamp_white", "rl": "lamp_white"}
    for c, (x, y) in mx.items():
        zt = P.motor(kit, c, x, y, 0.005, mspec)
        P.prop(kit, c, x, y, zt + 0.0013, pspec)
        u = V((x, y, 0)).normalized()
        # TPU landing pad under each motor mount
        kit.add(L.lathe([(0, -0.0045), (0.0058, -0.0045), (0.0075, -0.003), (0.0084, 0.0), (0, 0.0)], kit.seg(14), "tpu_orange", T(x, y, 0), name="pad"), "body", "side")
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            L.screw(kit, (x + 0.0113 * math.cos(a), y + 0.0113 * math.sin(a), 0.0), (0, 0, -1), r=0.0026, key="steel_dark", simple=True)
        lp = V((x, y, -0.0008)) - u * 0.024
        kit.add(L.rbox((0.0052, 0.0052, 0.0016), led_mat[c], T(lp.x, lp.y, lp.z) @ RZ(math.atan2(u.y, u.x)), bevel=0.0004, segs=1, name="led"), "led_" + c, "none")
        kit.pivots["led_" + c] = lp
        # motor leads: three wires off the base into a heat-shrink sleeve along the arm, out again to the ESC pads
        side = V((-u.y, u.x, 0))
        m0 = V((x, y, 0.0062)) - u * 0.0128
        s0 = V((x, y, 0.0062)) - u * 0.02
        s1 = V((0, 0, 0.0062)) + u * 0.034
        if q < 2:
            kit.add(L.tube([s0, s0 * 0.5 + s1 * 0.5 + V((0, 0, 0.0004)), s1], 0.0026, "heatshrink", seg=kit.seg(10), sub=2, name="sleeve"), "body", "none")
        if q == 0:
            P_wires = wires3(kit, m0, s0, sag=0.0004)
            band_tie(kit, (s0 * 0.4 + s1 * 0.6) - V((0, 0, 0.0012)), u, 0.0165, 0.0087)
    # --- FPV camera between the side plates, 40 degrees up
    P.fpv_cam(kit, (0.0, 0.058, 0.0175), math.radians(40.0), "camera_fpv", "camera_lens")
    kit.pivots["camera_fpv"] = V((0.0, 0.058, 0.0175))
    # --- the battery: 6S 1100 pack on a rubber pad, one strap with a buckle, leads to the XT60, balance lead on top
    kit.add(L.rbox((0.03, 0.062, 0.0016), "rubber", T(0, -0.002, 0.0328), bevel=0.0005, segs=1, name="grip"), "body", "none")
    bc = V((0.0, -0.002, 0.0336 + 0.019))
    kit.add(L.wrapped_box((0.035, 0.074, 0.038), "wrap_raptor", T(*bc), bevel=0.0042, segs=3 if q == 0 else 2, name="pack"), "battery", "hull")
    kit.pivots["battery"] = bc
    sz = (0.0384, 0.0, 0.0438)
    outer = L.rbox((0.0386, 0.02, 0.0438), "strap", T(0, -0.002, 0.0293 + 0.0438 / 2), bevel=0.004, segs=2, name="strap")
    if q < 2:
        inner = L.rbox((0.0362, 0.03, 0.0414), "strap", T(0, -0.002, 0.0293 + 0.0438 / 2), bevel=0.003, segs=2, name="strapcut")
        L.boolean(outer, [inner])
    kit.add(outer, "body", "none")
    kit.add(L.rbox((0.012, 0.023, 0.0016), "anod_orange", T(0.007, -0.002, 0.0738), bevel=0.0005, segs=1, name="buckle"), "body", "none")
    if q == 0:
        kit.add(L.rbox((0.0016, 0.024, 0.0018), "anod_black", T(0.0045, -0.002, 0.0742), bevel=0.0003, segs=1, name="buckleslot"), "body", "none")
    # battery leads out of the back to the male XT60, mated to the frame's pigtail
    xp_m = V((0.008, -0.056, 0.042))
    xp_f = V((0.008, -0.072, 0.042))
    P.xt60(kit, xp_m, (0, -1, 0), True, node="battery")
    for (sx, key) in ((-1, "silicone_black"), (1, "silicone_red")):
        a = V((0.006 + sx * 0.0045, -0.039, 0.048))
        b = xp_m + V((sx * 0.0035, 0.008, 0.0))
        kit.add(L.tube([a, a + V((0, -0.004, -0.001)), b + V((0, 0.003, 0)), b], 0.0017, key, seg=kit.seg(8), sub=3, name="lead"), "battery", "none")
    if q < 2:
        bl = [V((-0.012, -0.039, 0.064)), V((-0.012, -0.044, 0.068)), V((-0.012, -0.036, 0.0735)), V((-0.01, -0.024, 0.073))]
        if q == 0:
            for k in range(7):
                o = V((-0.0028 + k * 0.00095, 0, 0))
                kit.add(L.tube([p + o for p in bl], 0.00045, "silicone_red" if k == 6 else "silicone_black", seg=4, sub=3, name="bal"), "battery", "none")
        kit.add(L.rbox((0.0095, 0.0055, 0.0046), "nylon_white", T(-0.009, -0.021, 0.0735), bevel=0.0006, segs=1, name="jstxh"), "battery", "none")
    P.xt60(kit, xp_f, (0, -1, 0), False, node="body")
    if q < 2:
        for (sx, key) in ((-1, "silicone_black"), (1, "silicone_red")):
            a = xp_f + V((sx * 0.0035, -0.008, 0.0))
            b = V((sx * 0.006, -0.017, 0.0108))
            kit.add(L.tube([a, a + V((0, -0.008, -0.006)), V((sx * 0.006, -0.07, 0.016)), V((sx * 0.006, -0.05, 0.0125)), b], 0.0017, key, seg=kit.seg(8), sub=3, name="pig"), "body", "none")
        P.cap_lowesr(kit, V((0.0, -0.079, 0.019)), (0, -1, 0.2))
        if q == 0:
            L.zip_tie(kit, V((0.0, -0.069, 0.0185)), (0, -1, 0.2), 0.0058)
    # --- VTX antenna on a printed mount at the back left, RX whiskers in orange tubes on the rear arms
    am = V((-0.011, -0.047, 0.036))
    kit.add(L.rbox((0.012, 0.012, 0.009), "tpu_orange", T(*am) @ RX(-0.5), bevel=0.002, segs=2, name="antmount"), "body", "side")
    adir = V((0.0, -0.55, 0.83)).normalized()
    a0 = am + adir * 0.004
    kit.add(L.tube([a0, a0 + adir * 0.03], 0.0016, "plastic_black", seg=kit.seg(10), sub=1, name="stem"), "body", "side")
    head = a0 + adir * 0.03
    kit.add(L.lathe([(0, 0), (0.0062, 0.0008), (0.0072, 0.004), (0.0072, 0.0095), (0.0055, 0.0125), (0, 0.013)], kit.seg(18), "tpu_black", L.orient(head, adir), name="pagoda"), "body", "side")
    kit.add(L.lathe([(0, 0.013), (0.0046, 0.0128), (0.0028, 0.0155), (0, 0.016)], kit.seg(14), "tpu_orange", L.orient(head, adir), name="pagodacap"), "body", "none")
    if q < 2:
        kit.add(L.lathe([(0.0016, 0), (0.0034, 0), (0.0034, 0.0045), (0.0016, 0.0045)], 6, "gold", L.orient(a0 - adir * 0.001, adir), name="sma", loop=True), "body", "none")
        kit.add(L.tube([V((-0.006, -0.042, 0.021)), V((-0.009, -0.05, 0.026)), a0 - adir * 0.002], 0.0011, "silicone_black", seg=6, sub=3, name="coax"), "body", "none")
    for sx in (-1, 1):
        c = "rr" if sx > 0 else "rl"
        x, y = mx[c]
        u = V((x, y, 0)).normalized()
        base = u * 0.05 + V((0, 0, 0.0064))
        tip = base + V((sx * 0.012, -0.022, 0.026))
        kit.add(L.tube([base, base + V((sx * 0.003, -0.006, 0.006)), tip], 0.0013, "tpu_orange", seg=kit.seg(8), sub=3, name="rxtube"), "body", "side")
        if q < 2:
            kit.add(L.tube([V((sx * 0.012, -0.012, 0.0175)), V((sx * 0.02, -0.024, 0.009)), base], 0.0006, "silicone_black", seg=4, sub=3, name="rxcoax"), "body", "none")
        band_tie(kit, base - V((0, 0, 0.0018)), u, 0.0145, 0.0085)
    # --- the action camera, fixed on a printed mount at the front of the top plate, 25 degrees up
    kit.add(L.rbox((0.03, 0.014, 0.0055), "tpu_orange", T(0, 0.039, 0.0348), bevel=0.0015, segs=2, name="acmount"), "body", "hull")
    for sx in (-1, 1):
        kit.add(L.rbox((0.003, 0.009, 0.01), "tpu_orange", T(sx * 0.0045, 0.042, 0.04), bevel=0.0008, segs=1, name="prong"), "body", "none")
    kit.add(L.lathe([(0, 0), (0.0042, 0), (0.0042, 0.0026), (0.0034, 0.0032), (0, 0.0032)], kit.seg(16), "tpu_orange", T(0.0076, 0.042, 0.042) @ RY(math.pi / 2), name="knob"), "body", "none")
    acx = T(0.0, 0.05, 0.057) @ RX(math.radians(25.0))
    kit.add(L.rbox((0.042, 0.024, 0.03), "plastic_black", acx, bevel=0.0035, segs=3 if q == 0 else 2, name="acbody"), "action_cam", "hull")
    kit.pivots["action_cam"] = acx @ V((0, 0, 0))
    if q < 2:
        kit.add(L.rbox((0.04, 0.0012, 0.028), "plastic_grey", acx @ T(0, 0.0122, 0), bevel=0.0012, segs=1, name="acface"), "action_cam", "none")
        kit.add(L.rbox((0.0065, 0.0065, 0.0016), "silicone_red", acx @ T(0.012, 0.002, 0.0152), bevel=0.0007, segs=1, name="rec"), "action_cam", "none")
        kit.add(L.rbox((0.0016, 0.012, 0.022), "plastic_grey", acx @ T(-0.0212, -0.001, 0.0), bevel=0.0005, segs=1, name="door"), "action_cam", "none")
    lp = acx @ V((-0.0085, 0.0128, 0.002))
    P.lens(kit, lp, acx.to_3x3() @ V((0, 1, 0)), 0.0082, 0.0058, "coat_violet", "action_cam", glass_node="action_cam_lens")
    kit.pivots["action_cam_lens"] = lp
    ledp = acx @ V((0.0135, 0.0131, 0.0095))
    kit.add(L.lathe([(0, 0), (0.0011, 0), (0.001, 0.0006), (0, 0.0007)], 10, "lamp_red", L.orient(ledp, acx.to_3x3() @ V((0, 1, 0))), name="acled"), "action_cam_led", "none")
    kit.pivots["action_cam_led"] = ledp
    kit.parents.update({"camera_lens": "camera_fpv", "action_cam_lens": "action_cam", "action_cam_led": "action_cam"})
    # centre of mass (from the parts' rough masses: pack 180 g on top, motors, frame and stack, cameras) and the FPV eye
    kit.marks["com"] = V((0.0, 0.002, 0.03))
    kit.marks["fpv_eye"] = kit.pivots["camera_lens"]
    return {"prop": pspec, "blur_body": (0.55, 0.2, 0.03), "blur_tip": (0.85, 0.35, 0.08), "camOffset_physics": (0, 0.01, -0.06)}


# ================================================================================================ the Night Owl
def nightowl(kit):
    q = kit.q
    kit.screw_key = "anod_navy"
    d = 0.08
    body = {"fr": (0.018, 0.028), "fl": (-0.018, 0.028), "rl": (-0.018, -0.034), "rr": (0.018, -0.034),
            "between": {"fr": [(0.0158, 0.04), (0.0158, 0.074), (0.011, 0.081), (-0.011, 0.081), (-0.0158, 0.074), (-0.0158, 0.04)],
                        "fl": [(-0.02, 0.012), (-0.02, -0.018)],
                        "rl": [(-0.012, -0.058), (0.012, -0.058)],
                        "rr": [(0.02, -0.018), (0.02, 0.012)]}}
    outline = P.unibody_outline(d, body, 0.0075, 0.0055, 0.0115, pad_n=14 if q < 2 else 7, angular=False)
    uni = L.plate(outline, 0.0, 0.004, "carbon", "carbon_edge", name="unibody", chamfer=0.0004 if q < 2 else 0.0)
    mx = P.motor_xy(d)
    if q == 0:
        cut = []
        for c, (x, y) in mx.items():
            u = V((x, y, 0)).normalized()
            mid = V((x, y, 0)) * 0.55
            cut += P.slot_cutters([(mid.x, mid.y, 0.026, 0.0036, math.atan2(u.y, u.x))])
        L.boolean(uni, cut)
    kit.add(uni, "body", "plate", plan_pts=outline)
    # --- the stack inside a navy moulded canopy with vents in its sides
    for (sx, sy) in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
        x, y = sx * 0.01525, sy * 0.01525
        kit.add(L.lathe([(0, 0.004), (0.0032, 0.004), (0.0034, 0.0048), (0.0032, 0.0055), (0, 0.0055)], kit.seg(10), "rubber", T(x, y, 0), name="grommet"), "body", "none")
        kit.add(L.lathe([(0, 0.0071), (0.003, 0.0071), (0.0032, 0.0098), (0.003, 0.0125), (0, 0.0125)], kit.seg(10), "rubber", T(x, y, 0), name="grommet"), "body", "none")
        kit.add(L.lathe([(0, -0.0006), (0.0015, -0.0006), (0.0015, 0.016), (0, 0.016)], 8, "steel_dark", T(x, y, 0), name="bolt"), "body", "none")
        L.nut(kit, (x, y, 0.0141), key="nylon_black", r=0.0029, h=0.0022)
    P.board(kit, 0.0, 0.0, 0.0055, 0.036, "esc")
    P.board(kit, 0.0, 0.0, 0.0125, 0.034, "fc")
    secs = [(-0.052, 0, 0.0125, 0.015, 0.0055), (-0.044, 0, 0.0135, 0.0205, 0.0095), (-0.022, 0, 0.014, 0.0225, 0.01), (0.03, 0, 0.014, 0.0225, 0.01),
            (0.055, 0, 0.0128, 0.018, 0.0088), (0.069, 0, 0.0115, 0.011, 0.0062)]
    shell = L.loft(secs, "shell_navy", e=3.4, seg=kit.seg(32), name="canopy")
    if q < 2:
        th = 0.0014
        inner = L.loft([(y + (th if k == 0 else (-th if k == len(secs) - 1 else 0)), cx, cz, hw - th, hh - th) for k, (y, cx, cz, hw, hh) in enumerate(secs)],
                       "shell_navy", e=3.4, seg=kit.seg(32), name="canopyin")
        cuts = [inner, L.rbox((0.08, 0.2, 0.02), "shell_navy", T(0, 0, -0.0045), bevel=0.0, name="floorcut")]
        for sx in (-1, 1):
            for k in range(3):
                cuts.append(L.rbox((0.012, 0.009, 0.0042), "shell_navy", T(sx * 0.022, -0.016 + k * 0.014, 0.0125), bevel=0.0018, segs=2, name="vent"))
        L.boolean(shell, cuts)
    kit.add(shell, "body", "hull")
    kit.add(L.rbox((0.0015, 0.0012, 0.0005), "lamp_blue", T(0.0072, 0.0098, 0.0145), bevel=0.0001, segs=1, name="fcled"), "body", "none")
    # --- the battery bay on the canopy: a carbon tray, navy side rails with slots, a hinged latch at the back
    kit.add(L.plate([(-0.02, -0.062), (0.02, -0.062), (0.02, 0.042), (0.016, 0.046), (-0.016, 0.046), (-0.02, 0.042)], 0.0238, 0.0258, "carbon", "carbon_edge", name="tray"), "body", "plate",
            plan_pts=[(-0.02, -0.062), (0.02, -0.062), (0.02, 0.042), (0.016, 0.046), (-0.016, 0.046), (-0.02, 0.042)])
    for sx in (-1, 1):
        rail = L.rbox((0.0026, 0.1, 0.0125), "anod_navy", T(sx * 0.0207, -0.009, 0.0258 + 0.00625), bevel=0.0008, segs=1, name="rail")
        if q < 2:
            L.boolean(rail, [L.rbox((0.01, 0.022, 0.0052), "anod_navy", T(sx * 0.0207, -0.035 + k * 0.026, 0.032), bevel=0.0022, segs=2, name="rslot") for k in range(3)])
        kit.add(rail, "body", "side")
        for yy in (-0.05, 0.03):
            kit.add(L.rbox((0.004, 0.006, 0.0215), "anod_navy", T(sx * 0.0185, yy, 0.004 + 0.0105), bevel=0.0008, segs=1, name="riser"), "body", "side")
    kit.add(L.rbox((0.044, 0.004, 0.012), "anod_navy", T(0, -0.0615, 0.0315), bevel=0.0012, segs=2, name="latch"), "body", "side")
    if q < 2:
        kit.add(L.lathe([(0, -0.024), (0.0017, -0.024), (0.0017, 0.024), (0, 0.024)], 10, "steel", T(0, -0.0615, 0.026) @ RY(math.pi / 2), name="hinge"), "body", "none")
    bc = V((0.0, -0.01, 0.0258 + 0.0152))
    kit.add(L.wrapped_box((0.035, 0.1, 0.0304), "wrap_nightowl", T(*bc), bevel=0.0038, segs=3 if q == 0 else 2, name="pack"), "battery", "hull")
    kit.pivots["battery"] = bc
    outer = L.rbox((0.0466, 0.02, 0.036), "strap", T(0, -0.012, 0.0236 + 0.018), bevel=0.0035, segs=2, name="strap")
    if q < 2:
        L.boolean(outer, [L.rbox((0.0442, 0.03, 0.0336), "strap", T(0, -0.012, 0.0236 + 0.018), bevel=0.003, segs=2, name="strapcut")])
    kit.add(outer, "body", "none")
    kit.add(L.rbox((0.012, 0.023, 0.0016), "anod_navy", T(-0.008, -0.012, 0.0603), bevel=0.0005, segs=1, name="buckle"), "body", "none")
    # leads to the XT60 behind the latch, a balance lead tucked on top
    xp_m = V((0.009, -0.07, 0.039))
    xp_f = V((0.009, -0.086, 0.039))
    P.xt60(kit, xp_m, (0, -1, 0), True, node="battery")
    for (sx, key) in ((-1, "silicone_black"), (1, "silicone_red")):
        a = V((0.006 + sx * 0.0045, -0.06, 0.044))
        b = xp_m + V((sx * 0.0035, 0.008, 0.0))
        kit.add(L.tube([a, a + V((0, -0.003, 0.0)), b + V((0, 0.003, 0)), b], 0.0015, key, seg=kit.seg(10), sub=3, name="lead"), "battery", "none")
    if q < 2:
        bl = [V((-0.011, -0.06, 0.05)), V((-0.011, -0.064, 0.055)), V((-0.011, -0.055, 0.0565)), V((-0.009, -0.045, 0.0562))]
        if q == 0:
            for k in range(5):
                o = V((-0.0019 + k * 0.00095, 0, 0))
                kit.add(L.tube([p + o for p in bl], 0.00045, "silicone_red" if k == 4 else "silicone_black", seg=4, sub=3, name="bal"), "battery", "none")
        kit.add(L.rbox((0.0075, 0.0055, 0.0046), "nylon_white", T(-0.008, -0.042, 0.0565), bevel=0.0006, segs=1, name="jstxh"), "battery", "none")
    P.xt60(kit, xp_f, (0, -1, 0), False, node="body")
    if q < 2:
        for (sx, key) in ((-1, "silicone_black"), (1, "silicone_red")):
            a = xp_f + V((sx * 0.0035, -0.008, 0.0))
            kit.add(L.tube([a, a + V((0, -0.006, -0.008)), V((sx * 0.006, -0.08, 0.012)), V((sx * 0.006, -0.054, 0.008)), V((sx * 0.006, -0.017, 0.0078))],
                           0.0015, key, seg=kit.seg(8), sub=3, name="pig"), "body", "none")
        P.cap_lowesr(kit, V((-0.004, -0.092, 0.012)), (0, -1, 0.1))
    # --- motors, low-noise props, arm LEDs, landing legs
    mspec = {"r": 0.0122, "h": 0.0105, "base_r": 0.0112, "bell": "anod_navy_spun", "bell_side": "anod_navy", "base": "anod_black", "windows": 5}
    pspec = {"R": 0.0508, "n": 2, "root": 0.0056, "c_root": 0.17, "c_max": 0.29, "t_max": 0.36, "c_tip": 0.17, "sweep": 0.24, "pd": 0.62,
             "tc": 0.12, "t_round": 0.8, "key": "prop_black", "tip_key": "prop_tip_blue", "hub_r": 0.0062, "hub_h": 0.006, "nut_key": "anod_navy",
             "rest": {"fr": 0.5, "rr": 1.8, "rl": 3.1, "fl": 4.4}}
    led_mat = {"fr": "lamp_green", "fl": "lamp_red", "rr": "lamp_white", "rl": "lamp_white"}
    for c, (x, y) in mx.items():
        zt = P.motor(kit, c, x, y, 0.004, mspec)
        P.prop(kit, c, x, y, zt + 0.0013, pspec)
        u = V((x, y, 0)).normalized()
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            L.screw(kit, (x + 0.0085 * math.cos(a), y + 0.0085 * math.sin(a), 0.0), (0, 0, -1), r=0.0021, key="steel_dark", simple=True)
        lp = V((x, y, -0.0008)) - u * 0.02
        kit.add(L.rbox((0.0046, 0.0046, 0.0015), led_mat[c], T(*lp) @ RZ(math.atan2(u.y, u.x)), bevel=0.0004, segs=1, name="led"), "led_" + c, "none")
        kit.pivots["led_" + c] = lp
        s0 = V((x, y, 0.005)) - u * 0.017
        s1 = u * 0.036 + V((0, 0, 0.005))
        if q < 2:
            kit.add(L.tube([s0, (s0 + s1) * 0.5 + V((0, 0, 0.0003)), s1], 0.0022, "heatshrink", seg=kit.seg(10), sub=2, name="sleeve"), "body", "none")
        if q == 0:
            wires3(kit, V((x, y, 0.0052)) - u * 0.011, s0, r=0.0006, sag=0.0003, spread=0.0013)
            band_tie(kit, (s0 * 0.45 + s1 * 0.55) - V((0, 0, 0.001)), u, 0.0142, 0.0068)
        # landing leg: a carbon tube from a navy socket under the arm, splayed out, a soft rubber foot
        top = V((x, y, 0.0)) - u * 0.03
        foot = top + u * 0.012 + V((0, 0, -0.056))
        kit.add(L.rbox((0.009, 0.009, 0.006), "anod_navy", T(top.x, top.y, -0.003) @ RZ(math.atan2(u.y, u.x)), bevel=0.0015, segs=1, name="socket"), "body", "side")
        kit.add(L.tube([top + V((0, 0, -0.004)), foot + V((0, 0, 0.004))], 0.0022, "carbon", seg=kit.seg(12), sub=1, name="leg"), "body", "side")
        kit.add(L.lathe([(0, -0.0045), (0.0024, -0.0045), (0.004, -0.0032), (0.0044, -0.0005), (0.0034, 0.0025), (0.0024, 0.004), (0, 0.004)], kit.seg(10),
                        "rubber", T(*foot), name="foot"), "body", "side")
    # --- gimbal: damped mount plate under the nose, yaw motor, yaw arm, roll motor behind the camera, roll arm, pitch motor
    kit.add(L.plate([(-0.014, 0.052), (0.014, 0.052), (0.014, 0.078), (-0.014, 0.078)], -0.0085, -0.007, "carbon", "carbon_edge", name="gplate"), "body", "plate",
            plan_pts=[(-0.014, 0.052), (0.014, 0.052), (0.014, 0.078), (-0.014, 0.078)])
    for (gx, gy) in ((-0.0105, 0.055), (0.0105, 0.055), (-0.0105, 0.075), (0.0105, 0.075)):
        kit.add(L.lathe([(0, -0.007), (0.0022, -0.007), (0.0036, -0.0052), (0.0036, -0.0018), (0.0022, 0.0), (0, 0.0)], kit.seg(10), "rubber", T(gx, gy, 0), name="damper"), "body", "none")
    yaw_c = V((0.0, 0.065, -0.0115))
    kit.add(L.lathe([(0, -0.0085), (0.0092, -0.0085), (0.0094, -0.0092), (0.0094, -0.0148), (0, -0.0148)], kit.seg(28), "anod_navy", T(0, 0.065, 0), name="yawstator"), "body", "hull")
    kit.pivots["gimbal_yaw"] = yaw_c
    kit.add(L.lathe([(0, -0.0149), (0.0094, -0.0149), (0.0094, -0.0172), (0.0086, -0.0178), (0, -0.0178)], kit.seg(28), "anod_navy_spun", T(0, 0.065, 0), name="yawrotor"), "gimbal_yaw", "hull")
    kit.add(L.rbox((0.0085, 0.019, 0.0026), "anod_navy", T(0, 0.0585, -0.0188), bevel=0.0009, segs=2, name="yawarm"), "gimbal_yaw", "hull")
    kit.add(L.rbox((0.0085, 0.0026, 0.02), "anod_navy", T(0, 0.0495, -0.0285), bevel=0.0009, segs=2, name="yawarm2"), "gimbal_yaw", "hull")
    C = V((0.0, 0.074, -0.036))
    roll_c = V((0.0, 0.054, -0.036))
    kit.add(L.lathe([(0, 0), (0.0085, 0), (0.0085, 0.0042), (0.008, 0.0048), (0, 0.0048)], kit.seg(28), "anod_navy", L.orient(V((0, 0.0508, -0.036)), (0, 1, 0)), name="rollstator"), "gimbal_yaw", "hull")
    kit.pivots["gimbal_roll"] = roll_c
    kit.add(L.lathe([(0, 0.0049), (0.0085, 0.0049), (0.0085, 0.0072), (0.0078, 0.0078), (0, 0.0078)], kit.seg(28), "anod_navy_spun", L.orient(V((0, 0.0508, -0.036)), (0, 1, 0)), name="rollrotor"), "gimbal_roll", "hull")
    kit.add(L.rbox((0.0225, 0.0026, 0.0085), "anod_navy", T(0.0102, 0.0598, -0.036), bevel=0.0009, segs=2, name="rollarm"), "gimbal_roll", "hull")
    kit.add(L.rbox((0.0026, 0.0175, 0.0085), "anod_navy", T(0.0215, 0.0668, -0.036), bevel=0.0009, segs=2, name="rollarm2"), "gimbal_roll", "hull")
    kit.add(L.lathe([(0, 0), (0.0078, 0), (0.0078, 0.0038), (0.0073, 0.0044), (0, 0.0044)], kit.seg(28), "anod_navy", L.orient(V((0.0202, 0.074, -0.036)), (-1, 0, 0)), name="pitchstator"), "gimbal_roll", "hull")
    kit.pivots["gimbal_pitch"] = C
    kit.add(L.lathe([(0, 0.0045), (0.0075, 0.0045), (0.0075, 0.006), (0, 0.006)], kit.seg(28), "anod_navy_spun", L.orient(V((0.0202, 0.074, -0.036)), (-1, 0, 0)), name="pitchrotor"), "gimbal_pitch", "hull")
    kit.add(L.rbox((0.028, 0.025, 0.024), "shell_navy_dark", T(*C), bevel=0.004, segs=3 if q == 0 else 2, name="camhead"), "gimbal_pitch", "hull")
    if q == 0:
        for k in range(4):
            kit.add(L.rbox((0.016, 0.0006, 0.0012), "shell_navy_dark", T(0, C.y - 0.0127, C.z - 0.0055 + k * 0.0032), bevel=0.0002, segs=1, name="vent"), "gimbal_pitch", "none")
        kit.add(L.rbox((0.0006, 0.012, 0.0016), "shell_navy_dark", T(-0.0141, C.y - 0.002, C.z + 0.006), bevel=0.0002, segs=1, name="sd"), "gimbal_pitch", "none")
        kit.add(L.tube([V((0.0, 0.05, 0.0)), V((0.003, 0.056, -0.006)), V((0.006, 0.06, -0.013))], 0.0009, "silicone_black", seg=6, sub=3, name="gflex"), "body", "none")
    lp = C + V((0, 0.0125, 0.0))
    P.lens(kit, lp, (0, 1, 0), 0.0074, 0.0072, "coat_violet", "gimbal_pitch", glass_node="camera_lens")
    kit.pivots["camera_lens"] = lp + V((0, 0.007, 0))
    kit.parents.update({"gimbal_yaw": "", "gimbal_roll": "gimbal_yaw", "gimbal_pitch": "gimbal_roll", "camera_lens": "gimbal_pitch"})
    # --- the night-vision pod clipped under the front left, the landing light under the nose
    P.nv_pod(kit, T(-0.031, 0.04, 0.0), "nv_pod", "nv_lens", "nv_led")
    kit.pivots["nv_pod"] = V((-0.031, 0.04, 0.0))
    kit.parents.update({"nv_lens": "nv_pod", "nv_led": "nv_pod", "nv_led_ir": "nv_pod"})
    llp = V((0.009, 0.035, -0.0005))
    ldir = V((0.0, 0.55, -0.83)).normalized()
    m = L.orient(llp, ldir)
    kit.add(L.lathe([(0, 0), (0.0068, 0), (0.0074, 0.0016), (0.0074, 0.006), (0.0064, 0.0068), (0, 0.0068)], kit.seg(24), "anod_navy", L.orient(llp + V((0, 0, 0.003)), (0, 0, -1)), name="llhousing"), "body", "hull")
    lc = llp + V((0, 0, -0.0068)) + ldir * 0.0004
    kit.add(L.lathe([(0.0012, 0), (0.0058, 0.0035), (0.0058, 0.0037), (0.0012, 0.0006)], kit.seg(24), "reflector", L.orient(lc + ldir * -0.0035, ldir), name="refl"), "landing_light", "none")
    kit.add(L.lathe([(0, 0), (0.0026, 0), (0.0022, 0.0012), (0, 0.0014)], kit.seg(12), "lamp_landing", L.orient(lc - ldir * 0.0034, ldir), name="emitter"), "landing_light", "none")
    kit.add(L.lathe([(0, 0.0003), (0.006, 0), (0.006, -0.0006), (0, -0.0003)], kit.seg(24), "lens_clear", L.orient(lc, ldir), name="lllens"), "landing_light", "none")
    kit.pivots["landing_light"] = lc
    # --- antennas: two paddle aerials at the back of the bay, receiver whiskers on the rear arms, a status LED bar
    for sx in (-1, 1):
        hp = V((sx * 0.013, -0.064, 0.036))
        kit.add(L.lathe([(0, -0.003), (0.0026, -0.003), (0.0026, 0.003), (0, 0.003)], kit.seg(12), "plastic_black", T(*hp) @ RY(math.pi / 2), name="hingeblk"), "body", "none")
        pm = T(*hp) @ RZ(sx * 0.35) @ RX(-0.55)
        kit.add(L.rbox((0.0085, 0.0022, 0.052), "plastic_black", pm @ T(0, 0, 0.027), bevel=0.001, segs=2, name="paddle"), "body", "side")
        c = "rr" if sx > 0 else "rl"
        x, y = mx[c]
        u = V((x, y, 0)).normalized()
        base = u * 0.05 + V((0, 0, 0.0055))
        tip = base + V((sx * 0.012, -0.02, 0.024))
        kit.add(L.tube([base, base + V((sx * 0.003, -0.006, 0.006)), tip], 0.0012, "tpu_blue", seg=kit.seg(8), sub=3, name="rxtube"), "body", "side")
        band_tie(kit, base - V((0, 0, 0.0016)), u, 0.0135, 0.0069)
    sl = V((0.0, -0.0638, 0.0275))
    kit.add(L.rbox((0.014, 0.0012, 0.0024), "lamp_status", T(*sl), bevel=0.0004, segs=1, name="statusbar"), "status_led", "none")
    kit.pivots["status_led"] = sl
    kit.marks["com"] = V((0.0, 0.002, 0.022))
    kit.marks["fpv_eye"] = kit.pivots["camera_lens"]
    return {"prop": pspec, "blur_body": (0.03, 0.035, 0.045), "blur_tip": (0.16, 0.3, 0.6), "camOffset_physics": (0, -0.012, -0.07)}


# ================================================================================================ the night-vision pod
def pod(kit):
    kit.screw_key = "anod_black"
    P.nv_pod(kit, Matrix.Identity(4), "body", "camera_lens", "status_led")
    kit.marks["mount"] = V((0, 0, 0))
    return {}


MODELS = {"raptor_race_a": raptor, "nightowl_a": nightowl, "night_vision_pod_a": pod}


def build(name, q):
    L.clear_scene()
    kit = L.Kit(name, q)
    meta = MODELS[name](kit)
    if "stats" in sys.argv:
        tally = {}
        for p in kit.parts:
            k = p.obj.name.split(".")[0]
            tally[k] = tally.get(k, 0) + L.tris(p.obj)
        print("STATS", name, q, sorted(tally.items(), key=lambda kv: -kv[1])[:25])
    zs = [v.co.z for p in kit.parts for v in p.obj.data.vertices]
    base_z = 0.0 if name == "night_vision_pod_a" else min(zs)
    com = kit.marks.get("com", V((0, 0, base_z)))
    com_body = V((com.x, com.z - base_z, -com.y))
    root, made, info = L.assemble(kit, base_z, com_body)
    return kit, root, made, info, meta, base_z, com_body


def body_frame(v, base_z, com_body):
    v = V(v)
    return [round(v.x - com_body.x, 6), round(v.z - base_z - com_body.y, 6), round(-v.y - com_body.z, 6)]


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    for a in args:
        if a.startswith("only="):
            only = a[5:].split(",")
    os.makedirs(OUT, exist_ok=True)
    for name in MODELS:
        if only and name not in only:
            continue
        manifest = {"name": name, "lods": {}}
        for q in (0, 1, 2):
            kit, root, made, info, meta, base_z, com_body = build(name, q)
            fn = name + ("" if q == 0 else "_lod%d" % q) + ".glb"
            L.export_glb(root, os.path.join(OUT, fn))
            total = sum(info["tris"].values())
            manifest["lods"][str(q)] = {"file": fn, "tris": total, "nodes": info["tris"]}
            print("BUILT %s lod%d: %d triangles, %d nodes" % (name, q, total, len(info["tris"])))
            if q == 0:
                manifest["plan"] = info["plan"]
                manifest["side"] = info["side"]
                manifest["com_model"] = [round(com_body.x, 6), round(com_body.y, 6), round(com_body.z, 6)]
                manifest["frame"] = "story frame in the file (+Z front, right -x, origin at the base); body frame here (forward -z, right +x, origin at com)"
                props = {}
                for c in ("fr", "rr", "rl", "fl"):
                    nm = "prop_" + c
                    if nm in kit.pivots:
                        props[c] = body_frame(kit.pivots[nm], base_z, com_body)
                if props:
                    ps = meta["prop"]
                    manifest["props"] = props
                    manifest["prop_radius"] = ps["R"]
                    manifest["prop_blades"] = ps["n"]
                    manifest["prop_chord"] = round(L.chord_at(ps, 0.7), 5)
                    manifest["blur_body"] = meta["blur_body"]
                    manifest["blur_tip"] = meta["blur_tip"]
                    manifest["spin"] = {c: ("ccw" if P.SPIN[c] > 0 else "cw") for c in P.SPIN}
                if "fpv_eye" in kit.marks:
                    manifest["fpv_eye"] = body_frame(kit.marks["fpv_eye"], base_z, com_body)
                    manifest["camOffset_physics"] = meta.get("camOffset_physics")
                used = sorted({m.name for ob in made.values() if ob.type == "MESH" for m in ob.data.materials})
                manifest["materials"] = {}
                for mn in used:
                    sp = L.MATS[mn.split(".")[0]]
                    e = {}
                    if sp.get("tex"):
                        e["orm"] = "drone_%s_orm.jpg" % sp["tex"]
                        e["nor"] = "drone_%s_nor.jpg" % sp["tex"]
                        if sp.get("diff"):
                            e["albedo"] = "drone_%s_diff.jpg" % sp["tex"]
                    if sp.get("img"):
                        e["albedo"] = sp["img"]
                    if "emit" in sp:
                        e["emit"] = sp["emit"]
                    if "alpha" in sp:
                        e["alpha"] = sp["alpha"]
                    manifest["materials"][mn] = e
                manifest["parents"] = {n: (ob.parent.name if ob.parent else "") for n, ob in made.items() if n}
        with open(os.path.join(OUT, name + ".json"), "w") as f:
            json.dump(manifest, f, indent=1)


if __name__ == "__main__":
    main()
