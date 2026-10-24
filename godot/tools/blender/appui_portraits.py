# Phone app portraits (lane appui2): build each cast member with the people pipeline, pose them, add a few modelled props,
# and render a head-and-shoulders still in Cycles with a transparent film. The 2D grade, backdrop and sizes are done by
# godot/tools/ui_art/gen_portraits.py (system Python + Pillow).
#   sh run_people.sh appui_portraits.py -- --out <dir> [--names maya,jo] [--samples 160] [--res 1024]
# Framing is identical for everyone: 85 mm lens, frame height 0.50 m, eye line 40 percent from the top, camera at eye level.
import bpy, bmesh, os, sys, math, json, time
import numpy as np
from mathutils import Vector, Matrix, Quaternion
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import people_lib as L
import people_clips as C
from people_pose import Poser
from appui_roster import CAST, PORTRAIT_CAST

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(k, d=None):
    return argv[argv.index(k) + 1] if k in argv else d
OUT = arg("--out")
NAMES = arg("--names", ",".join(PORTRAIT_CAST)).split(",")
SAMPLES = int(arg("--samples", "160"))
RES = int(arg("--res", "1024"))
FRAME_H = 0.44
EYE_FROM_TOP = 0.42
LENS = 85.0
os.makedirs(OUT, exist_ok=True)


# ------------------------------------------------------------------------------------------------ small helpers
def mat(name, col, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_k=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if coat:
        b.inputs["Coat Weight"].default_value = coat
    if emit:
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1)
        b.inputs["Emission Strength"].default_value = emit_k
    return m


def obj_from_bm(bm, name, m):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(name, centre, size, m, rot=None, bevel=0.004):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    o = obj_from_bm(bm, name, m)
    o.location = centre
    if rot is not None:
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = rot
    if bevel:
        bv = o.modifiers.new("bv", "BEVEL")
        bv.width = bevel
        bv.segments = 3
    return o


def cylinder(name, centre, r, depth, m, rot=None, verts=24):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=depth)
    o = obj_from_bm(bm, name, m)
    o.location = centre
    if rot is not None:
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = rot
    bv = o.modifiers.new("bv", "BEVEL")
    bv.width = min(r, depth) * 0.25
    bv.segments = 2
    return o


def tube(name, pts, r, m, closed=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 4
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1)
    sp.order_u = 4
    sp.use_endpoint_u = not closed
    sp.use_cyclic_u = closed
    sp.resolution_u = 8
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o


def ray(origin, direction, dist=3.0):
    dg = bpy.context.evaluated_depsgraph_get()
    hit, loc, nor, idx, ob, mw = bpy.context.scene.ray_cast(dg, Vector(origin), Vector(direction).normalized(), distance=dist)
    return (loc, nor) if hit else (None, None)


def front(x, z, y0=-1.5):
    return ray((x, y0, z), (0, 1, 0))


def ring_points(cx, cy, z, n=28, out=0.004, rmax=0.4):
    pts = []
    for i in range(n):
        a = i / n * math.tau
        d = Vector((math.sin(a), -math.cos(a), 0))      # a = 0 is the front (-Y)
        loc, nor = ray(Vector((cx, cy, z)) + d * rmax, -d, rmax)
        if loc is None:
            continue
        pts.append(loc + d * out)
    return pts


def ribbon(name, samples, width, m, lift=0.004, thick=0.003):
    """A flat strap lying on the body: samples are (point, normal) along its path."""
    bm = bmesh.new()
    rows = []
    for i, (p, n) in enumerate(samples):
        t = (samples[min(i + 1, len(samples) - 1)][0] - samples[max(i - 1, 0)][0]).normalized()
        b = n.cross(t).normalized()
        c = p + n * lift
        rows.append((bm.verts.new(c - b * width / 2), bm.verts.new(c + b * width / 2)))
    for r0, r1 in zip(rows, rows[1:]):
        bm.faces.new((r0[0], r0[1], r1[1], r1[0]))
    o = obj_from_bm(bm, name, m)
    so = o.modifiers.new("so", "SOLIDIFY")
    so.thickness = thick
    so.offset = 1.0
    return o


def bone_world(rig, name, tail=False):
    pb = rig.pose.bones[name]
    return rig.matrix_world @ (pb.tail if tail else pb.head)


def look_quat(fwd, up=Vector((0, 0, 1))):
    """Rotation that maps local -Y to fwd and +Z towards up."""
    f = fwd.normalized()
    r = f.cross(up).normalized()
    u = r.cross(f).normalized()
    M = Matrix((r, -f, u)).transposed()
    return M.to_quaternion()


# ------------------------------------------------------------------------------------------------ props
BLACK_PLASTIC = None

def props(spec, rig, E):
    m_black = mat("black_plastic", (0.025, 0.025, 0.027), 0.42)
    neck = bone_world(rig, "Neck")
    head = bone_world(rig, "Head")
    for pr in spec.get("props", []):
        if pr == "headphones":
            cushion = mat("cushion", (0.05, 0.045, 0.04), 0.7)
            shell = mat("hp_shell", (0.05, 0.05, 0.055), 0.35, coat=0.4)
            z = neck.z - 0.005
            for s in (-1, 1):
                c = Vector((s * 0.078, neck.y - 0.012, z))
                q = Quaternion((0, 1, 0), s * math.radians(90)) @ Quaternion((1, 0, 0), math.radians(-12))
                cylinder("hp_cup", c, 0.040, 0.026, shell, rot=Quaternion((0, 0, 1), s * math.radians(-18)) @ Quaternion((0, 1, 0), math.radians(90)))
                cylinder("hp_pad", c + Vector((-s * 0.016, 0, 0)), 0.036, 0.012, cushion, rot=Quaternion((0, 0, 1), s * math.radians(-18)) @ Quaternion((0, 1, 0), math.radians(90)))
            arc = []
            for i in range(13):
                a = math.radians(-8 + i * (196 / 12))
                arc.append(Vector((math.cos(a) * 0.082, neck.y + math.sin(a) * 0.075 - 0.01, z - 0.012 * math.sin(a))))
            tube("hp_band", arc, 0.007, m_black)
        elif pr == "lanyard":
            web = mat("lanyard", (0.70, 0.46, 0.14), 0.75)
            card_m = mat("card", (0.86, 0.83, 0.74), 0.35, coat=0.6)
            band_m = mat("card_band", (0.30, 0.45, 0.33), 0.4)
            zc = E.z - 0.255
            for s in (-1, 1):
                pts = []
                for i in range(9):
                    t = i / 8
                    x = s * (0.052 * (1 - t) + 0.006 * t)
                    zz = (neck.z + 0.01) * (1 - t) + (zc + 0.05) * t
                    loc, nor = front(x, zz)
                    if loc is not None:
                        pts.append(loc + nor * 0.005)
                if len(pts) >= 4:
                    tube("lanyard_cord", pts, 0.0045, web)
            loc, nor = front(0.0, zc)
            if loc is not None:
                q = look_quat(-nor)
                box("lanyard_card", loc + nor * 0.006, (0.056, 0.0025, 0.082), card_m, rot=q, bevel=0.003)
                box("lanyard_band", loc + nor * 0.0075 + Vector((0, 0, 0.026)), (0.057, 0.0012, 0.02), band_m, rot=q, bevel=0.0)
                box("lanyard_clip", loc + nor * 0.008 + Vector((0, 0, 0.046)), (0.012, 0.004, 0.016), mat("clip", (0.6, 0.6, 0.58), 0.3, 1.0), rot=q, bevel=0.002)
        elif pr == "radio":
            led = mat("led", (0.9, 0.55, 0.1), 0.3, emit=(1.0, 0.55, 0.12), emit_k=6.0)
            loc, nor = front(0.105, E.z - 0.205)
            if loc is not None:
                q = look_quat(-nor)
                c = loc + nor * 0.016
                box("radio_body", c, (0.046, 0.026, 0.078), m_black, rot=q, bevel=0.006)
                up = q @ Vector((0, 0, 1))
                cylinder("radio_aerial", c + up * 0.065 + (q @ Vector((0.012, 0, 0))), 0.0055, 0.06, m_black, rot=q)
                box("radio_led", c + up * 0.03 + (q @ Vector((-0.013, -0.0135, 0))), (0.006, 0.002, 0.004), led, rot=q, bevel=0.0)
                box("radio_grille", c - up * 0.01 + (q @ Vector((0, -0.0132, 0))), (0.032, 0.0015, 0.03), mat("grille", (0.08, 0.08, 0.085), 0.6), rot=q, bevel=0.001)
        elif pr == "camera_strap":
            strap = mat("strap", (0.05, 0.05, 0.055), 0.65)
            samples = []
            top, tn = ray((0.115, neck.y + 0.01, neck.z + 0.4), (0, 0, -1))
            if top is not None:
                samples.append((top, tn))
            for i in range(12):
                t = i / 11
                x = 0.105 * (1 - t) - 0.17 * t
                z = (neck.z - 0.03) * (1 - t) + (E.z - 0.58) * t
                loc, nor = front(x, z)
                if loc is not None:
                    samples.append((loc, nor))
            if len(samples) > 4:
                ribbon("camera_strap", samples, 0.032, strap, lift=0.006, thick=0.003)
        elif pr == "magnifier":
            z = E.z + 0.052
            pts = ring_points(head.x, head.y - 0.01, z, out=0.004)
            if len(pts) > 12:
                tube("mag_band", pts + pts[:3], 0.0065, m_black, closed=True)
                fr = min(pts, key=lambda p: p.y)
                q = Quaternion((1, 0, 0), math.radians(-38))
                c = fr + Vector((0, -0.022, 0.024))
                box("mag_visor", c, (0.105, 0.03, 0.036), m_black, rot=q, bevel=0.008)
                glass = mat("lens", (0.75, 0.82, 0.85), 0.02, coat=1.0)
                for s in (-1, 1):
                    cylinder("mag_lens", c + q @ Vector((s * 0.027, -0.016, 0)), 0.0125, 0.006, glass, rot=q @ Quaternion((1, 0, 0), math.radians(90)))
                for s in (-1, 1):
                    cylinder("mag_hinge", fr + Vector((s * 0.055, 0.0, 0.004)), 0.007, 0.012, mat("brass", (0.75, 0.55, 0.25), 0.3, 1.0), rot=Quaternion((0, 1, 0), math.radians(90)))
        elif pr == "pocket_tools":
            loc, nor = front(0.075, E.z - 0.245)
            if loc is not None:
                for i, (dx, col, r, h) in enumerate(((-0.012, (0.75, 0.2, 0.12), 0.0045, 0.065), (0.004, (0.9, 0.7, 0.2), 0.004, 0.058), (0.016, (0.12, 0.12, 0.12), 0.006, 0.05))):
                    cylinder(f"tool{i}", loc + nor * 0.008 + Vector((dx, 0, h * 0.25)), r, h, mat(f"tool{i}", col, 0.4), rot=Quaternion((0, 1, 0), math.radians(6 * (i - 1))))
        elif pr == "gaiter":
            gm = mat("gaiter", (0.03, 0.032, 0.03), 0.85)
            rows = []
            for i, z in enumerate(np.linspace(neck.z - 0.06, E.z - 0.028, 7)):
                pts = ring_points(neck.x, neck.y + 0.01, z, n=32, out=0.012 + 0.004 * i, rmax=0.3)
                if len(pts) == 32:
                    rows.append(pts)
            bm = bmesh.new()
            vrows = [[bm.verts.new(p) for p in r] for r in rows]
            for r0, r1 in zip(vrows, vrows[1:]):
                for k in range(32):
                    bm.faces.new((r0[k], r0[(k + 1) % 32], r1[(k + 1) % 32], r1[k]))
            g = obj_from_bm(bm, "gaiter", gm)
            so = g.modifiers.new("so", "SOLIDIFY"); so.thickness = 0.006
            g.modifiers.new("ss", "SUBSURF").levels = 1
        elif pr == "goggles":
            z = E.z + 0.004
            loc, nor = front(E.x, z)
            yf = loc.y if loc is not None else E.y - 0.09
            shell = mat("gog_shell", (0.035, 0.038, 0.04), 0.4)
            foam = mat("gog_foam", (0.03, 0.03, 0.03), 0.9)
            visor = mat("gog_visor", (0.55, 0.62, 0.70), 0.06, metal=1.0)
            c = Vector((E.x, yf - 0.03, z))
            box("gog_body", c, (0.17, 0.058, 0.074), shell, bevel=0.018)
            box("gog_foam", c + Vector((0, 0.03, 0)), (0.162, 0.016, 0.068), foam, bevel=0.012)
            box("gog_visor", c + Vector((0, -0.03, 0.002)), (0.15, 0.004, 0.056), visor, bevel=0.012)
            cylinder("gog_ant", c + Vector((0.07, -0.012, 0.05)), 0.004, 0.05, m_black)
            box("gog_led", c + Vector((-0.06, -0.031, -0.026)), (0.008, 0.002, 0.004), mat("gled", (0.2, 0.9, 0.4), 0.3, emit=(0.3, 1.0, 0.45), emit_k=5.0), bevel=0.0)
            pts = ring_points(head.x, head.y - 0.01, z + 0.006, out=0.006)
            back = [p for p in pts if p.y > c.y + 0.03]
            if len(back) > 6:
                back.sort(key=lambda p: math.atan2(p.x, p.y - head.y))
                tube("gog_strap", [c + Vector((0.083, 0.02, 0))] + back + [c + Vector((-0.083, 0.02, 0))], 0.011, mat("gog_strap", (0.12, 0.13, 0.12), 0.8))


# ------------------------------------------------------------------------------------------------ scene
def world_env(sc, backlit):
    w = bpy.data.worlds.new("portrait_world")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mth = nt.nodes.new("ShaderNodeMath")
    mth.operation = "MULTIPLY_ADD"
    mth.inputs[1].default_value = 0.5
    mth.inputs[2].default_value = 0.5
    nt.links.new(sep.outputs["Z"], mth.inputs[0])
    nt.links.new(mth.outputs[0], ramp.inputs["Fac"])
    cr = ramp.color_ramp
    cr.elements[0].position = 0.40
    cr.elements[0].color = (0.10, 0.12, 0.07, 1)          # valley floor
    cr.elements[1].position = 0.62
    cr.elements[1].color = (0.30, 0.42, 0.55, 1)          # sky
    e = cr.elements.new(0.505)
    e.color = (0.95, 0.66, 0.36, 1)                       # warm horizon
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.10 if backlit else 0.32
    nt.links.new(bg.outputs[0], out.inputs[0])


def area(name, loc, target, size, energy, col):
    ld = bpy.data.lights.new(name, "AREA")
    ld.shape = "DISK"
    ld.size = size
    ld.energy = energy
    ld.color = col
    o = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    d = (Vector(target) - Vector(loc)).normalized()
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.to_track_quat("-Z", "Y")
    return o


def lights(E, backlit):
    if backlit:
        area("rim_l", E + Vector((-0.45, 0.95, 0.30)), E, 0.4, 120, (1.0, 0.78, 0.55))
        area("rim_r", E + Vector((0.45, 0.95, 0.20)), E, 0.4, 110, (0.95, 0.80, 0.62))
        return
    area("key", E + Vector((-0.80, -0.95, 0.55)), E + Vector((0, 0, -0.04)), 0.9, 46, (1.0, 0.86, 0.70))
    area("fill", E + Vector((0.95, -0.85, -0.05)), E, 1.5, 10, (0.78, 0.86, 1.0))
    area("rim", E + Vector((0.65, 0.85, 0.45)), E, 0.6, 48, (1.0, 0.84, 0.62))
    area("hair", E + Vector((-0.3, 0.6, 0.9)), E, 0.7, 30, (1.0, 0.9, 0.78))


def camera(E):
    d = LENS / 36.0 * FRAME_H
    cd = bpy.data.cameras.new("cam")
    cd.lens = LENS
    cd.sensor_fit = "HORIZONTAL"
    cd.sensor_width = 36.0
    cd.shift_y = -(0.5 - EYE_FROM_TOP)
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = 4.0
    cd.dof.focus_distance = d
    co = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(co)
    co.location = E + Vector((0, -d, 0))
    co.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = co
    return co


def render_setup(sc):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    sc.cycles.transparent_max_bounces = 16
    sc.render.film_transparent = True
    sc.render.resolution_x = RES
    sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.image_settings.color_depth = "16"
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except Exception:
        pass


def set_smile(objs, v):
    for o in objs:
        if o.type == "MESH" and o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks:
                if kb.name == "smile":
                    kb.value = v


report = {}
for name in NAMES:
    t0 = time.time()
    L.reset_scene()
    spec = CAST[name]
    rig, lods, mats = L.build_character(spec)
    for lod in (1, 2):
        for o in lods.get(lod, []):
            bpy.data.objects.remove(o, do_unlink=True)
    objs = lods[0]
    P = C.idle(0.0)
    turn = spec.get("turn", 0)
    P["neck"] = (2, turn * 0.45, 0)
    P["head"] = (-3, turn * 0.55, 0)
    P["spine"] = (1.5, turn * 0.15, 0)
    Poser(rig).apply(P)
    set_smile(objs, spec.get("smile", 0.2))
    bpy.context.view_layer.update()
    E = (bone_world(rig, "LeftEye") + bone_world(rig, "RightEye")) / 2
    props(spec, rig, E)
    sc = bpy.context.scene
    render_setup(sc)
    world_env(sc, spec.get("backlit"))
    lights(E, spec.get("backlit"))
    camera(E)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    report[name] = {"seconds": round(time.time() - t0, 1), "eye": [round(v, 4) for v in E]}
    L.log("portrait", name, json.dumps(report[name]))
json.dump(report, open(os.path.join(OUT, "portraits_report.json"), "w"), indent=1)
