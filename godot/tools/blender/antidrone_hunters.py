# Pike's hunter drones (lane/antidrone). Game frame: +z is the nose, y up, the model's right is -x, origin on the ground
# under the middle (the lowest point of the skids or feet). No weapons: the heavy hexacopter carries a net launcher pod,
# closed and empty; nothing fires. The forward eye (node eye, ad_lamp_eye) is a red emissive lens readable from 100 m.
# Rotors are their own nodes, pivot on the motor shaft at the hub, spun about local y: rotor_1 front right (-x, +z),
# then round the airframe clockwise seen from above (rotor_2 rear right ... ). meta.spin gives each rotor's direction
# (+1 anticlockwise seen from above).
import math
from mathutils import Vector as V
import antidrone_lib as A
from antidrone_lib import AD, box, cyl, sphere, torus, sweep, loft, rotor, tube_path


def _dark(co, n, mat, node, tag):
    """a little scuffing on the dark plastics and carbon, nothing else"""
    if mat in ("ad_carbon", "ad_plastic_dark", "ad_steel_dark", "ad_battery"):
        v = 1.0 + 0.25 * A.fbm(co, 12.0, 2, 3.0)
        return (v, v, v)
    return (1.0, 1.0, 1.0)


def eye(a, c, r=0.028, hood=0.05, parent=None):
    """a recessed red lens in a short hood, facing +z: node eye"""
    e = a.node("eye", pivot=tuple(c))
    if parent:
        a.parents["eye"] = parent
    c = V(c)
    e.add(cyl(r + 0.012, r + 0.012, c - V((0, 0, hood * 0.6)), c + V((0, 0, hood * 0.4)), seg=14, caps=False), "ad_plastic_dark")
    e.add(cyl(r + 0.004, r + 0.004, c - V((0, 0, hood * 0.6)), c - V((0, 0, hood * 0.3)), seg=14), "ad_plastic_dark")
    e.add(sphere(r, c - V((0, 0, hood * 0.25)), scale=(1, 1, 0.65), seg=14, rings=6), "ad_lamp_eye", smooth=True)
    e.add(torus(r + 0.003, 0.003, c + V((0, 0, hood * 0.05)), seg=14, sides=4), "ad_lens")


def motor(n, c, r, h):
    c = V(c)
    n.add(cyl(r, r, c, c + V((0, h * 0.55, 0)), seg=14), "ad_motor", smooth=True)
    n.add(cyl(r * 1.02, r * 0.9, c + V((0, h * 0.55, 0)), c + V((0, h, 0)), seg=14), "ad_motor", smooth=True)
    n.add(cyl(r * 0.18, r * 0.18, c + V((0, h, 0)), c + V((0, h + 0.012, 0)), seg=8), "ad_chrome")


def arm(n, a, b, w, t):
    a, b = V(a), V(b)
    d = (b - a)
    ang = math.degrees(math.atan2(d.x, d.z))
    n.add(box((w, t, d.length), tuple((a + b) * 0.5), rot=(0, ang, 0), bevel=0.004), "ad_carbon", grain=tuple(d.normalized()))


def hunter_a():
    a = AD("hunter_drone_a", ground=False, ao_dist=0.06, ao_strength=0.6, colour=_dark, lod1=0.5,
           meta={"notes": "brutal little quadcopter 0.9 m across, dark frame, red forward eye, four exposed rotors; "
                          "origin on the ground under the middle (skids)",
                 "spin": {"rotor_1": -1, "rotor_2": 1, "rotor_3": -1, "rotor_4": 1}, "centre": [0.0, 0.16, 0.0],
                 "prop_radius": 0.21},
           probes=[{"node": "eye", "axis": "z", "side": 1}, {"node": "rotor_4", "axis": "x", "side": 1}], budget=5000)
    b = a.node("body")
    y0 = 0.13
    # hull: a chamfered box, a wedge nose cowl round the eye, a top deck plate, the battery strapped on top
    b.add(box((0.24, 0.1, 0.32), (0, y0 + 0.05, -0.02), bevel=0.02, seg=1), "ad_plastic_dark")
    nose = A.loft([[V((-0.11, y0 + 0.005, 0.13)), V((0.11, y0 + 0.005, 0.13)), V((0.11, y0 + 0.095, 0.13)), V((-0.11, y0 + 0.095, 0.13))],
                   [V((-0.07, y0 + 0.02, 0.2)), V((0.07, y0 + 0.02, 0.2)), V((0.06, y0 + 0.08, 0.19)), V((-0.06, y0 + 0.08, 0.19))]],
                  close_ring=True, cap0=True, cap1=True)
    b.add(nose, "ad_plastic_dark")
    b.add(box((0.3, 0.006, 0.36), (0, y0 + 0.103, -0.03), bevel=0.003), "ad_carbon")
    b.add(box((0.1, 0.06, 0.19), (0, y0 + 0.136, -0.05), bevel=0.008), "ad_battery")
    for z in (-0.1, 0.0):
        b.add(box((0.105, 0.065, 0.02), (0, y0 + 0.137, z)), "ad_strap")
    # rear whisker antennas and a small rear LED cluster
    for s in (-1, 1):
        b.add(cyl(0.004, 0.003, (s * 0.06, y0 + 0.1, -0.17), (s * 0.12, y0 + 0.16, -0.27), seg=5), "ad_plastic_dark")
    # arms and motors
    for (sx, sz) in ((-1, 1), (-1, -1), (1, -1), (1, 1)):
        m = V((sx * 0.235, y0 + 0.06, sz * 0.235))
        arm(b, (sx * 0.08, y0 + 0.06, sz * 0.08 - 0.02), m, 0.04, 0.03)
        motor(b, m + V((0, 0.015, 0)), 0.034, 0.045)
    # skids: two legs each side down to a bar on the ground
    for s in (-1, 1):
        for z in (-0.1, 0.09):
            b.add(cyl(0.008, 0.008, (s * 0.07, y0 + 0.01, z), (s * 0.13, 0.012, z), seg=6), "ad_steel_dark")
        b.add(cyl(0.011, 0.011, (s * 0.13, 0.011, -0.16), (s * 0.13, 0.011, 0.15), seg=8), "ad_steel_dark")
        b.add(sphere(0.011, (s * 0.13, 0.011, 0.15), seg=8, rings=4), "ad_steel_dark")
    eye(a, (0, y0 + 0.05, 0.215), r=0.026, parent=None)
    for i, (sx, sz) in enumerate(((-1, 1), (-1, -1), (1, -1), (1, 1))):
        hub = V((sx * 0.235, y0 + 0.06 + 0.015 + 0.057, sz * 0.235))
        r = a.node("rotor_%d" % (i + 1), pivot=tuple(hub))
        rotor(r, hub, 0.21, blades=2, chord=0.034, pitch=13.0, seed=i, hub_r=0.018)
    return a


def hunter_b():
    a = AD("hunter_drone_b", ground=False, ao_dist=0.07, ao_strength=0.6, colour=_dark, lod1=0.5,
           meta={"notes": "heavier six-rotor hunter, 1.1 m across, with a net launcher pod under the nose (node net_pod; "
                          "its front cap pod_door hinges up about x at its top edge; closed and empty, no projectile); "
                          "red forward eye; origin on the ground under the middle",
                 "spin": {"rotor_1": -1, "rotor_2": 1, "rotor_3": -1, "rotor_4": 1, "rotor_5": -1, "rotor_6": 1},
                 "centre": [0.0, 0.3, 0.0], "prop_radius": 0.19},
           probes=[{"node": "eye", "axis": "z", "side": 1}, {"node": "net_pod", "axis": "z", "side": 1}], budget=5000)
    b = a.node("body")
    y0 = 0.27
    b.add(box((0.3, 0.13, 0.38), (0, y0 + 0.065, -0.01), bevel=0.025, seg=1), "ad_plastic_dark")
    b.add(cyl(0.16, 0.16, (0, y0 + 0.13, -0.01), (0, y0 + 0.137, -0.01), seg=6), "ad_carbon")
    b.add(box((0.13, 0.075, 0.22), (0, y0 + 0.175, -0.04), bevel=0.01), "ad_battery")
    b.add(box((0.135, 0.08, 0.025), (0, y0 + 0.175, -0.04)), "ad_strap")
    hood = A.loft([[V((-0.12, y0 + 0.01, 0.17)), V((0.12, y0 + 0.01, 0.17)), V((0.12, y0 + 0.12, 0.17)), V((-0.12, y0 + 0.12, 0.17))],
                   [V((-0.08, y0 + 0.03, 0.24)), V((0.08, y0 + 0.03, 0.24)), V((0.07, y0 + 0.1, 0.23)), V((-0.07, y0 + 0.1, 0.23))]],
                  close_ring=True, cap0=True, cap1=True)
    b.add(hood, "ad_plastic_dark")
    R = 0.36
    # the six motors, clockwise from above starting at the front right
    pos = []
    for k in range(6):
        th = math.radians(30 + 60 * k)             # 30 deg = front right, measured clockwise from +z seen from above
        pos.append(V((-math.sin(th) * R, y0 + 0.07, math.cos(th) * R)))
    for p in pos:
        arm(b, V((p.x * 0.25, p.y, p.z * 0.25)), p, 0.036, 0.03)
        motor(b, p + V((0, 0.015, 0)), 0.03, 0.04)
    # four legs down to feet
    for (sx, sz) in ((-1, 1), (-1, -1), (1, -1), (1, 1)):
        top = V((sx * 0.11, y0 + 0.01, sz * 0.13))
        foot = V((sx * 0.2, 0.012, sz * 0.2))
        b.add(cyl(0.01, 0.009, top, foot, seg=6), "ad_carbon")
        b.add(sphere(0.014, foot, seg=8, rings=4), "ad_plastic_dark")
    # the net pod under the nose: a launcher tube in a cradle, its cap closed
    pc = V((0, y0 - 0.075, 0.06))
    pod = a.node("net_pod", pivot=tuple(pc))
    pod.add(cyl(0.065, 0.065, pc - V((0, 0, 0.17)), pc + V((0, 0, 0.15)), seg=14), "ad_plastic_grey", smooth=True, uv='cyl', grain=(0, 0, 1))
    for z in (-0.1, 0.06):
        pod.add(box((0.15, 0.08, 0.025), pc + V((0, 0.045, z))), "ad_steel_dark")
    pod.add(torus(0.066, 0.006, pc + V((0, 0, 0.12)), seg=14, sides=4), "ad_paint_red")      # a red band: not a weapon, a tell
    door = a.node("pod_door", pivot=tuple(pc + V((0, 0.066, 0.15))))
    a.parents["pod_door"] = "net_pod"
    door.add(cyl(0.068, 0.068, pc + V((0, 0, 0.15)), pc + V((0, 0, 0.165)), seg=14), "ad_plastic_dark")
    door.add(box((0.03, 0.012, 0.02), pc + V((0, 0.07, 0.158))), "ad_steel_dark")
    eye(a, (0, y0 + 0.065, 0.255), r=0.03)
    for i, p in enumerate(pos):
        hub = p + V((0, 0.015 + 0.052, 0))
        r = a.node("rotor_%d" % (i + 1), pivot=tuple(hub))
        rotor(r, hub, 0.19, blades=2, chord=0.032, pitch=13.0, seed=i, hub_r=0.016)
    return a


def hunter_c():
    a = AD("hunter_drone_c", ground=False, ao_dist=0.04, ao_strength=0.6, colour=_dark, lod1=0.5,
           meta={"notes": "a stripped racing frame, 0.5 m across, long and low: bare carbon plates, a battery strapped on "
                          "top, an FPV camera with a red eye ring at the nose (node eye) and a red strobe at the tail "
                          "(node strobe, ad_lamp_strobe: AntiDroneAssets.flash); origin under the middle (rubber feet)",
                 "spin": {"rotor_1": -1, "rotor_2": 1, "rotor_3": -1, "rotor_4": 1}, "centre": [0.0, 0.05, 0.0],
                 "prop_radius": 0.09},
           probes=[{"node": "eye", "axis": "z", "side": 1}, {"node": "strobe", "axis": "z", "side": -1}], budget=3500)
    b = a.node("body")
    y0 = 0.018
    # stretched-X unibody: arms forward and back are longer (the fast, long silhouette)
    mot = [V((-0.15, y0 + 0.005, 0.19)), V((-0.15, y0 + 0.005, -0.19)), V((0.15, y0 + 0.005, -0.19)), V((0.15, y0 + 0.005, 0.19))]
    for m in mot:
        arm(b, V((m.x * 0.2, y0, m.z * 0.25)), m, 0.03, 0.006)
        b.add(sphere(0.012, m - V((0, 0.011, 0)), scale=(1, 0.6, 1), seg=8, rings=3), "ad_plastic_dark")      # rubber feet
        motor(b, m + V((0, 0.003, 0)), 0.016, 0.022)
    b.add(box((0.07, 0.006, 0.2), (0, y0, 0.0), bevel=0.002), "ad_carbon")
    b.add(box((0.065, 0.004, 0.17), (0, y0 + 0.042, 0.0), bevel=0.002), "ad_carbon")
    for (x, z) in ((-0.025, 0.07), (0.025, 0.07), (-0.025, -0.07), (0.025, -0.07)):
        b.add(cyl(0.004, 0.004, (x, y0 + 0.003, z), (x, y0 + 0.04, z), seg=6), "ad_paint_red")
    b.add(box((0.045, 0.02, 0.05), (0, y0 + 0.02, 0.0)), "ad_plastic_grey")             # stack
    b.add(box((0.04, 0.032, 0.13), (0, y0 + 0.062, -0.01), bevel=0.004), "ad_battery")
    b.add(box((0.045, 0.035, 0.012), (0, y0 + 0.062, -0.01)), "ad_strap")
    for s in (-1, 1):
        b.add(cyl(0.003, 0.002, (s * 0.02, y0 + 0.03, -0.1), (s * 0.05, y0 + 0.07, -0.18), seg=4), "ad_plastic_dark")
    # camera cage at the nose, tilted up
    b.add(box((0.004, 0.032, 0.028), (-0.02, y0 + 0.022, 0.09)), "ad_carbon")
    b.add(box((0.004, 0.032, 0.028), (0.02, y0 + 0.022, 0.09)), "ad_carbon")
    eye(a, (0, y0 + 0.024, 0.1), r=0.011, hood=0.022)
    st = a.node("strobe", pivot=(0, y0 + 0.012, -0.112))
    st.add(box((0.022, 0.014, 0.012), (0, y0 + 0.012, -0.105)), "ad_plastic_dark")
    st.add(sphere(0.009, (0, y0 + 0.016, -0.114), seg=10, rings=5), "ad_lamp_strobe")
    for i, m in enumerate(mot):
        hub = m + V((0, 0.003 + 0.034, 0))
        r = a.node("rotor_%d" % (i + 1), pivot=tuple(hub))
        rotor(r, hub, 0.09, blades=3, chord=0.022, pitch=16.0, seed=i, hub_r=0.009, tip_up=0.002)
    return a


def hunter_rotor():
    a = AD("hunter_rotor", ground=False, ao_dist=0.04, ao_strength=0.5, colour=_dark, lod1=0.5,
           meta={"notes": "the shared hunter rotor and its guard: node rotor_1 (hub and blades, pivot on the shaft, spin "
                          "about y) over a motor, inside a guard ring (node guard) on two struts; origin under the motor",
                 "prop_radius": 0.21})
    g = a.node("guard")
    motor(g, (0, 0, 0), 0.034, 0.045)
    g.add(torus(0.235, 0.006, (0, 0.05, 0), rot=(90, 0, 0), seg=32, sides=5), "ad_plastic_dark")
    g.add(torus(0.235, 0.004, (0, 0.025, 0), rot=(90, 0, 0), seg=32, sides=4), "ad_plastic_dark")
    for k in range(4):
        ang = k / 4 * math.tau + 0.4
        d = V((math.cos(ang), 0, math.sin(ang)))
        g.add(cyl(0.005, 0.005, V((0, 0.012, 0)) + d * 0.03, V((0, 0.025, 0)) + d * 0.235, seg=5), "ad_plastic_dark")
        g.add(cyl(0.004, 0.004, V((0, 0.025, 0)) + d * 0.235, V((0, 0.05, 0)) + d * 0.235, seg=4), "ad_plastic_dark")
    hub = V((0, 0.057, 0))
    r = a.node("rotor_1", pivot=tuple(hub))
    rotor(r, hub, 0.21, blades=2, chord=0.034, pitch=13.0, seed=1, hub_r=0.018)
    return a


def net_pod():
    a = AD("hunter_net_pod", ground=False, ao_dist=0.05, ao_strength=0.5, colour=_dark, lod1=0.6,
           meta={"notes": "the net launcher pod alone, closed and empty, no projectile: node net_pod (tube and cradle, "
                          "its mounting face on top), pod_door (the front cap, hinges up about x at its top edge); origin "
                          "under the middle of the tube"})
    pc = V((0, 0.066, 0))
    pod = a.node("net_pod", pivot=tuple(pc))
    pod.add(cyl(0.065, 0.065, pc - V((0, 0, 0.17)), pc + V((0, 0, 0.15)), seg=16), "ad_plastic_grey", smooth=True, uv='cyl', grain=(0, 0, 1))
    pod.add(cyl(0.06, 0.06, pc - V((0, 0, 0.18)), pc - V((0, 0, 0.165)), seg=16), "ad_plastic_dark")
    for z in (-0.1, 0.06):
        pod.add(box((0.15, 0.06, 0.025), pc + V((0, 0.08, z))), "ad_steel_dark")
    pod.add(box((0.16, 0.008, 0.24), pc + V((0, 0.114, -0.02))), "ad_steel_dark")
    pod.add(torus(0.066, 0.006, pc + V((0, 0, 0.12)), seg=16, sides=4), "ad_paint_red")
    tube_path([pc + V((0.03, 0.06, -0.17)), pc + V((0.05, 0.1, -0.22)), pc + V((0.02, 0.118, -0.12))], 0.004, "ad_cable", pod, seg=4)
    door = a.node("pod_door", pivot=tuple(pc + V((0, 0.066, 0.15))))
    a.parents["pod_door"] = "net_pod"
    door.add(cyl(0.068, 0.068, pc + V((0, 0, 0.15)), pc + V((0, 0, 0.165)), seg=16), "ad_plastic_dark")
    door.add(box((0.03, 0.012, 0.02), pc + V((0, 0.07, 0.158))), "ad_steel_dark")
    return a


HUNTERS = [hunter_a, hunter_b, hunter_c, hunter_rotor, net_pod]
