# Facade product tiles (lane appui2): the real game drones and pods are imported from assets/models; the battery,
# motor set, props, controller and repair kit are modelled here. One object per tile, three-quarter view, soft top-left
# light, a shadow-catcher floor for the contact shadow, transparent film. The 2D tile treatment (category accent) is in
# tools/ui_art/gen_products.py.
#   blender.exe -b --factory-startup --python appui_products.py -- --out <dir> [--names raptor,battery] [--samples 128]
import bpy, bmesh, os, sys, math, json
from mathutils import Vector, Matrix, Quaternion, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
MODELS = os.path.join(GODOT, "assets", "models")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(k, d=None):
    return argv[argv.index(k) + 1] if k in argv else d
OUT = arg("--out")
ALL = ["raptor", "nightowl", "thermal_camera", "night_vision", "battery", "motors", "props", "controller", "repair_kit"]
NAMES = arg("--names", ",".join(ALL)).split(",")
SAMPLES = int(arg("--samples", "128"))
RES = int(arg("--res", "1024"))
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, col, rough=0.5, metal=0.0, coat=0.0, emit=None, emit_k=0.0, bump=0.0, scale=60.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Specular IOR Level"].default_value = 0.35
    if emit:
        b.inputs["Emission Color"].default_value = (emit[0], emit[1], emit[2], 1)
        b.inputs["Emission Strength"].default_value = emit_k
    if bump:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Detail"].default_value = 8
        bn = nt.nodes.new("ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.00015
        nt.links.new(tex.outputs["Fac"], bn.inputs["Height"])
        nt.links.new(bn.outputs["Normal"], b.inputs["Normal"])
    return m


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def from_bm(bm, name, m, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def bevel(o, w, seg=3):
    b = o.modifiers.new("bv", "BEVEL")
    b.width = w
    b.segments = seg
    b.limit_method = "ANGLE"
    o.modifiers.new("wn", "WEIGHTED_NORMAL")
    return o


def box(name, size, loc, m, rot=(0, 0, 0), bv=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    o = from_bm(bm, name, m, smooth=False)
    o.location = loc
    o.rotation_euler = rot
    if bv:
        bevel(o, bv)
    return o


def cyl(name, r, h, loc, m, rot=(0, 0, 0), seg=40, bv=0.0, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = from_bm(bm, name, m, smooth=False)
    o.location = loc
    o.rotation_euler = rot
    if bv:
        bevel(o, bv, 2)
    else:
        o.modifiers.new("wn", "WEIGHTED_NORMAL")
    return o


def torus(name, R, r, loc, m, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=48, minor_segments=16, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o


def curve(name, pts, r, m):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 4
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1)
    sp.order_u = 4
    sp.use_endpoint_u = True
    o = link(bpy.data.objects.new(name, cu))
    o.data.materials.append(m)
    return o


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


# ------------------------------------------------------------------------------------------------ modelled products
def m_battery():
    shell = mat("bat_shell", (0.055, 0.06, 0.065), 0.45, bump=0.3)
    rubber = mat("bat_rubber", (0.025, 0.025, 0.025), 0.85, bump=0.5, scale=120)
    label = mat("bat_band", (0.33, 0.55, 0.60), 0.4)
    amber = mat("amber", (1.0, 0.6, 0.15), 0.3, emit=(1.0, 0.55, 0.12), emit_k=12)
    off = mat("led_off", (0.12, 0.1, 0.06), 0.3)
    box("pack", (0.13, 0.045, 0.042), (0, 0, 0.021), shell, bv=0.006)
    for s in (-1, 1):
        box("bumper", (0.016, 0.05, 0.047), (s * 0.062, 0, 0.0235), rubber, bv=0.007)
    box("band", (0.06, 0.0462, 0.03), (0.0, 0, 0.021), label, bv=0.003)
    for i in range(4):
        box("led", (0.006, 0.003, 0.004), (-0.012 + i * 0.008, -0.0236, 0.034), amber if i < 3 else off, bv=0.0008)
    strap = mat("strap", (0.12, 0.10, 0.07), 0.8, bump=0.4, scale=200)
    box("strap", (0.022, 0.049, 0.045), (0.03, 0, 0.0225), strap, bv=0.002)
    yel = mat("xt60", (0.85, 0.65, 0.12), 0.4)
    red = mat("wire_r", (0.6, 0.07, 0.05), 0.35)
    blk = mat("wire_b", (0.03, 0.03, 0.03), 0.35)
    curve("wire_r", [(0.07, -0.006, 0.03), (0.09, -0.012, 0.035), (0.105, -0.03, 0.01), (0.09, -0.05, 0.006)], 0.0028, red)
    curve("wire_b", [(0.07, 0.004, 0.03), (0.093, -0.004, 0.035), (0.11, -0.025, 0.012), (0.096, -0.048, 0.006)], 0.0028, blk)
    box("plug", (0.016, 0.012, 0.009), (0.092, -0.056, 0.006), yel, rot=(0, 0, 0.6), bv=0.0015)


def motor(loc, m_bell, m_base, m_cu, cut=False):
    x, y, z = loc
    cyl("base", 0.0155, 0.004, (x, y, z + 0.002), m_base, bv=0.0008)
    cyl("stator", 0.0125, 0.012, (x, y, z + 0.010), m_cu)
    if cut:
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=48, radius1=0.0145, radius2=0.0145, depth=0.016)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(-1, -1, 0), clear_inner=True)
        bmesh.ops.contextual_create(bm, geom=[e for e in bm.edges if e.is_boundary])
        o = from_bm(bm, "bell_cut", m_bell, smooth=False)
        o.location = (x, y, z + 0.013)
        o.modifiers.new("so", "SOLIDIFY").thickness = -0.0015
        for k in range(9):
            a = math.radians(-135 + k * 10 - 90)
            cyl("winding", 0.0035, 0.011, (x + 0.009 * math.cos(a + math.pi / 2), y + 0.009 * math.sin(a + math.pi / 2), z + 0.011), m_cu, seg=12)
    else:
        cyl("bell", 0.0145, 0.016, (x, y, z + 0.013), m_bell, bv=0.001)
        for k in range(6):
            a = k * math.tau / 6
            box("slot", (0.006, 0.0015, 0.0015), (x + 0.0085 * math.cos(a), y + 0.0085 * math.sin(a), z + 0.0212), m_base, rot=(0, 0, a))
    cyl("shaft", 0.0025, 0.012, (x, y, z + 0.025), mat("steel", (0.75, 0.75, 0.74), 0.25, 1.0), seg=16)
    cyl("nut", 0.0042, 0.003, (x, y, z + 0.0225), m_base, seg=6)
    wires = [mat("w1", (0.03, 0.03, 0.03), 0.4)] * 3
    for i in range(3):
        curve("wire", [(x - 0.012, y + (i - 1) * 0.0025, z + 0.003), (x - 0.025, y + (i - 1) * 0.003, z + 0.003), (x - 0.04, y - 0.01 + (i - 1) * 0.004, z + 0.002)], 0.001, wires[i])


def m_motors():
    bell = mat("bell", (0.55, 0.12, 0.07), 0.3, 1.0)
    base = mat("mbase", (0.06, 0.06, 0.065), 0.4, 0.8)
    cu = mat("copper", (0.85, 0.42, 0.18), 0.32, 1.0)
    for i, (x, y) in enumerate(((-0.022, -0.022), (0.022, -0.022), (-0.022, 0.022), (0.022, 0.022))):
        motor((x, y, 0), bell, base, cu, cut=(i == 1))


def blade(name, m, length, root_w, tip_w, side):
    bm = bmesh.new()
    n = 10
    rows = []
    for i in range(n + 1):
        t = i / n
        r = 0.006 + t * length
        w = root_w + (tip_w - root_w) * t ** 0.8
        w *= 1.0 - 0.6 * max(0, t - 0.85) / 0.15
        tw = math.radians(28 - 18 * t)
        cx = r * side
        lead = Vector((0, w * 0.55, 0))
        trail = Vector((0, -w * 0.45, 0))
        R = Matrix.Rotation(tw * side, 3, "X")
        th = 0.0016 * (1 - t * 0.6)
        pts = [R @ (lead), R @ Vector((0, 0.05 * w, th)), R @ trail, R @ Vector((0, 0.05 * w, -th * 0.4))]
        rows.append([bm.verts.new(Vector((cx, 0, 0.006)) + p) for p in pts])
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(4):
            bm.faces.new((r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]))
    bm.faces.new(rows[-1][::-1])
    return from_bm(bm, name, m)


def m_props():
    matte = mat("prop", (0.09, 0.095, 0.10), 0.62, bump=0.15)
    hub_m = mat("hub", (0.05, 0.05, 0.05), 0.5)
    for k, (dx, dy, rz, tilt) in enumerate(((-0.018, -0.008, 0.25, 0.0), (0.02, 0.016, -0.55, 0.08))):
        objs = [blade("b1", matte, 0.055, 0.010, 0.016, 1), blade("b2", matte, 0.055, 0.010, 0.016, -1),
                cyl("hub", 0.0065, 0.008, (0, 0, 0.006), hub_m, bv=0.001)]
        for o in objs:
            o.rotation_euler = (tilt, 0, rz)
            o.location = Vector((dx, dy, 0.002 + k * 0.012))


def m_controller():
    body_m = mat("ctl", (0.10, 0.105, 0.11), 0.48, bump=0.2)
    grip = mat("grip", (0.04, 0.04, 0.042), 0.8, bump=0.6, scale=150)
    stick = mat("stick", (0.03, 0.03, 0.03), 0.55)
    metal = mat("alu", (0.55, 0.55, 0.56), 0.3, 1.0)
    screen = mat("screen", (0.02, 0.025, 0.03), 0.08, coat=1.0)
    accent = mat("accent", (0.88, 0.62, 0.25), 0.35)
    body = box("body", (0.16, 0.075, 0.03), (0, 0, 0.022), body_m, bv=0.012)
    for s in (-1, 1):
        box("grip", (0.045, 0.07, 0.034), (s * 0.068, 0.006, 0.019), grip, rot=(0, 0, s * 0.12), bv=0.014)
        cyl("gimbal", 0.013, 0.004, (s * 0.045, -0.006, 0.038), stick, seg=32, bv=0.001)
        cyl("stick", 0.0028, 0.022, (s * 0.045, -0.006, 0.05), metal, seg=16)
        cyl("cap", 0.0065, 0.006, (s * 0.045, -0.006, 0.062), stick, seg=24, bv=0.002)
        box("ant", (0.008, 0.005, 0.055), (s * 0.055, 0.035, 0.05), body_m, rot=(0.35, 0, 0), bv=0.003)
    for i in range(3):
        cyl("btn", 0.0035, 0.003, (-0.01 + i * 0.01, -0.025, 0.037), accent if i == 1 else stick, seg=20)
    # phone cradle and phone
    box("arm", (0.012, 0.012, 0.03), (0, 0.03, 0.045), metal, bv=0.003)
    box("clamp", (0.15, 0.012, 0.012), (0, 0.035, 0.064), body_m, rot=(0.3, 0, 0), bv=0.004)
    ph = box("phone", (0.14, 0.008, 0.068), (0, 0.04, 0.095), mat("phone", (0.05, 0.05, 0.055), 0.3, 0.6), rot=(-0.3, 0, 0), bv=0.006)
    box("screen", (0.132, 0.002, 0.062), (0, 0.0355, 0.0965), screen, rot=(-0.3, 0, 0), bv=0.004)


def m_repair_kit():
    case = mat("case", (0.40, 0.42, 0.24), 0.55, bump=0.35, scale=90)
    latch = mat("latch", (0.6, 0.6, 0.6), 0.3, 1.0)
    box("case", (0.12, 0.085, 0.035), (-0.02, 0.025, 0.0175), case, bv=0.008)
    box("lid_rim", (0.122, 0.087, 0.004), (-0.02, 0.025, 0.026), case, bv=0.002)
    for s in (-1, 1):
        box("latch", (0.012, 0.004, 0.012), (-0.02 + s * 0.03, -0.0185, 0.025), latch, bv=0.001)
    box("handle", (0.04, 0.008, 0.008), (-0.02, -0.02, 0.006), mat("hdl", (0.05, 0.05, 0.05), 0.6), bv=0.003)
    # tape roll
    tape = mat("tape", (0.62, 0.62, 0.6), 0.5, bump=0.2)
    t = cyl("tape", 0.024, 0.018, (0.06, -0.03, 0.009), tape, seg=48)
    cyl("core", 0.015, 0.0185, (0.06, -0.03, 0.009), mat("core", (0.75, 0.62, 0.42), 0.8), seg=48)
    cyl("hole", 0.0135, 0.019, (0.06, -0.03, 0.009), mat("void", (0.02, 0.02, 0.02), 0.9), seg=48)
    # spare arm (carbon bar with holes)
    carbon = mat("carbon", (0.025, 0.025, 0.028), 0.32, coat=0.5, bump=0.25, scale=400)
    arm = box("arm", (0.11, 0.016, 0.004), (-0.015, -0.055, 0.002), carbon, rot=(0, 0, 0.18), bv=0.0015)
    for k in range(3):
        a = 0.18
        x = -0.015 + (k - 1) * 0.04 * math.cos(a)
        y = -0.055 + (k - 1) * 0.04 * math.sin(a)
        cyl("hole", 0.0025, 0.005, (x, y, 0.002), mat("void2", (0.01, 0.01, 0.01), 0.9), seg=16)
    # hex keys
    steel = mat("hex", (0.25, 0.26, 0.28), 0.3, 1.0)
    for k, (x, y, r) in enumerate(((0.035, 0.03, 0.4), (0.045, 0.045, 0.6))):
        curve("key", [(x, y, 0.002), (x + 0.03 * math.cos(r), y + 0.03 * math.sin(r), 0.002), (x + 0.032 * math.cos(r), y + 0.032 * math.sin(r), 0.004),
                      (x + 0.032 * math.cos(r) - 0.012 * math.sin(r), y + 0.032 * math.sin(r) + 0.012 * math.cos(r), 0.004)], 0.0016 + k * 0.0004, steel)


MODELLED = {"battery": m_battery, "motors": m_motors, "props": m_props, "controller": m_controller, "repair_kit": m_repair_kit}
IMPORTED = {"raptor": "drones/raptor_race_a.glb", "nightowl": "drones/nightowl_a.glb",
            "night_vision": "drones/night_vision_pod_a.glb", "thermal_camera": "story/gear/thermal_pod_a.glb"}
VIEW = {  # azimuth (deg, camera position around the object, 0 = from -Y front), elevation, yaw of object
    "raptor": (35, 26, 0), "nightowl": (35, 26, 0), "night_vision": (-35, 18, 0), "thermal_camera": (-35, 18, 0),
    "battery": (-30, 28, 0), "motors": (30, 38, 0), "props": (25, 45, 0), "controller": (-20, 32, 0), "repair_kit": (25, 38, 0),
}


# ------------------------------------------------------------------------------------------------ scene
def bounds():
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in bpy.data.objects:
        if o.type not in ("MESH", "CURVE") or o.hide_render:
            continue
        ev = o.evaluated_get(dg)
        try:
            me = ev.to_mesh()
        except Exception:
            continue
        for v in me.vertices:
            w = ev.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return lo, hi


def stage(name):
    sc = bpy.context.scene
    lo, hi = bounds()
    c = (lo + hi) / 2
    size = max(hi - lo)
    # floor shadow catcher at the lowest point
    bpy.ops.mesh.primitive_plane_add(size=size * 12, location=(c.x, c.y, lo.z))
    fl = bpy.context.active_object
    fl.is_shadow_catcher = True
    az, el, _ = VIEW[name]
    rad = (hi - lo).length / 2
    lens = 70.0
    fov = 2 * math.atan(18.0 / lens)
    d = rad / math.sin(fov / 2) * FIT.get(name, 1.0)
    dirv = Vector((math.sin(math.radians(az)) * math.cos(math.radians(el)), -math.cos(math.radians(az)) * math.cos(math.radians(el)), math.sin(math.radians(el))))
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cam = link(bpy.data.objects.new("cam", cd))
    cam.location = c + dirv * d
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (-dirv).to_track_quat("-Z", "Y")
    sc.camera = cam
    cd.clip_start = d * 0.05
    cd.clip_end = d * 10

    def area(nm, offset, sz, en, col):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.shape = "DISK"
        ld.size = sz * size
        ld.energy = en * (size / 0.2) ** 2
        ld.color = col
        o = link(bpy.data.objects.new(nm, ld))
        o.location = c + Vector(offset) * size
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = (c - o.location).normalized().to_track_quat("-Z", "Y")
    # soft top-left key relative to the camera, a cool fill and a warm rim
    right = dirv.cross(Vector((0, 0, 1))).normalized()
    key = (-right * 1.4 + dirv * 0.9 + Vector((0, 0, 2.0)))
    area("key", key, 1.4, 2.2, (1.0, 0.92, 0.8))
    area("fill", right * 1.8 + dirv * 0.8 + Vector((0, 0, 0.5)), 2.0, 0.6, (0.8, 0.88, 1.0))
    area("rim", -dirv * 1.8 + right * 0.6 + Vector((0, 0, 1.3)), 1.0, 1.6, (1.0, 0.86, 0.66))
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.40, 0.36, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"


FIT = {"raptor": 0.86, "nightowl": 0.84, "props": 0.95, "motors": 0.92}
report = {}
for name in NAMES:
    reset()
    if name in IMPORTED:
        objs = import_glb(os.path.join(MODELS, IMPORTED[name]))
        # the game models carry LOD-free single files; hide helper empties' children that are colliders if any
        for o in objs:
            if o.type == "MESH" and ("collider" in o.name.lower() or "col_" in o.name.lower()):
                o.hide_render = True
            # stray authoring leftovers inside some glb files (camera, light, default cube)
            if o.type in ("CAMERA", "LIGHT") or (o.type == "MESH" and o.name.startswith("Cube") and [m.name for m in o.data.materials if m] == ["Material"]):
                o.hide_render = True
                print("[products] hid stray", o.name, flush=True)
        glow = {"thermal_camera": ((1.0, 0.42, 0.16), 7.0), "night_vision": ((0.35, 1.0, 0.45), 1.4)}.get(name)
        if glow:
            for o in objs:
                if o.type == "MESH":
                    for i, slot in enumerate(o.material_slots):
                        if slot.material is None:
                            continue
                        if "lens" not in o.name.lower() and "glass" not in slot.material.name.lower():
                            continue
                        m2 = slot.material.copy()
                        b = m2.node_tree.nodes.get("Principled BSDF")
                        if b:
                            b.inputs["Emission Color"].default_value = (*glow[0], 1)
                            b.inputs["Emission Strength"].default_value = glow[1]
                        o.material_slots[i].material = m2
                    print("[products] glow on", o.name, flush=True)
    else:
        MODELLED[name]()
    stage(name)
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    lo, hi = bounds()
    report[name] = {"size_m": [round(v, 4) for v in (hi - lo)]}
    print("[products]", name, report[name], flush=True)
json.dump(report, open(os.path.join(OUT, "products_report.json"), "w"), indent=1)
