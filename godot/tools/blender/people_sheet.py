# Render views of exported people for contact sheets (the exported .glb files are what is rendered, so this checks the export).
# blender.exe -b --python people_sheet.py -- --out <dir> --names ellis,rennick [--views front,side,threeq,back,face]
#   [--lights golden,overcast,backlit] [--anim <library.glb> --clip idle --frame 20] [--walk N] [--res 640]
# Writes <dir>/<name>_<view>_<light>.png; compose them with people_compose.py (system Python with PIL).
import bpy, os, sys, math
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

argv = sys.argv[sys.argv.index("--") + 1:]
def arg(k, d=None):
    return argv[argv.index(k) + 1] if k in argv else d
OUT = arg("--out")
NAMES = arg("--names").split(",")
VIEWS = arg("--views", "front,side,threeq,back,face").split(",")
LIGHTS = arg("--lights", "golden").split(",")
RES = int(arg("--res", "640"))
ANIM = arg("--anim")
CLIP = arg("--clip", "idle")
FRAME = float(arg("--frame", "0.25"))
POSES = arg("--poses")
WALK = int(arg("--walk", "0"))
LOD = arg("--lod", "0")
DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "models", "people"))
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE_NEXT"
sc.eevee.use_shadows = True
sc.eevee.use_raytracing = True
sc.eevee.taa_render_samples = 48
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Base Contrast"
sc.render.resolution_x = RES
sc.render.resolution_y = int(RES * 1.25)

def ground():
    bpy.ops.mesh.primitive_plane_add(size=40)
    g = bpy.context.object
    m = bpy.data.materials.new("ground")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.16, 0.17, 0.12, 1)
    b.inputs["Roughness"].default_value = 0.95
    g.data.materials.append(m)
ground()

world = bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
wn = world.node_tree
sky = wn.nodes.new("ShaderNodeTexSky")
sky.sky_type = "NISHITA"
bg = wn.nodes["Background"]
wn.links.new(sky.outputs["Color"], bg.inputs["Color"])
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sc.collection.objects.link(sun)
sun.data.angle = math.radians(1.5)

def set_light(kind, facing_yaw):
    """facing_yaw: the yaw (radians) of the camera around the figure, so 'backlit' puts the sun behind the figure."""
    if kind == "golden":
        elev, az, energy, col, skys = 9, facing_yaw + math.radians(35), 4.0, (1.0, 0.78, 0.55), 0.35
        sun.hide_render = False
    elif kind == "overcast":
        elev, az, energy, col, skys = 50, facing_yaw + 0.5, 0.0, (1, 1, 1), 1.0
        sun.hide_render = True
    else:  # backlit
        elev, az, energy, col, skys = 14, facing_yaw + math.pi + 0.25, 4.5, (1.0, 0.86, 0.68), 0.45
        sun.hide_render = False
    sky.sun_elevation = math.radians(max(elev, 2))
    sky.sun_rotation = az
    sky.sun_intensity = 0.0 if kind == "overcast" else 0.25
    sky.air_density = 1.0
    sky.dust_density = 3.0 if kind != "overcast" else 6.0
    bg.inputs["Strength"].default_value = skys if kind != "overcast" else 0.0
    if kind == "overcast":
        # flat grey cloud light
        wn.links.clear() if False else None
        for l in list(wn.links):
            if l.to_node == bg:
                wn.links.remove(l)
        bg.inputs["Color"].default_value = (0.62, 0.65, 0.7, 1)
        bg.inputs["Strength"].default_value = 1.1
    else:
        if not any(l.to_node == bg for l in wn.links):
            wn.links.new(sky.outputs["Color"], bg.inputs["Color"])
    sun.data.energy = energy
    sun.data.color = col
    # sun direction: light travels from azimuth az at elevation elev toward the figure
    d = Vector((math.sin(az) * math.cos(math.radians(elev)), -math.cos(az) * math.cos(math.radians(elev)), math.sin(math.radians(elev))))
    sun.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam

def aim(loc, tgt, lens):
    cam.location = loc
    cam.data.lens = lens
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()

def load(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(DIR, name + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        if o.type == "MESH":
            keep = o.name.split(".")[0].endswith("_LOD" + LOD)
            o.hide_render = not keep
            o.hide_viewport = not keep
    arm = [o for o in objs if o.type == "ARMATURE"]
    return objs, (arm[0] if arm else None)

LIB_ACTS = {}
def library_actions(lib):
    if lib in LIB_ACTS:
        return LIB_ACTS[lib]
    before = set(bpy.data.objects)
    acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=lib)
    new = [o for o in bpy.data.objects if o not in before]
    acts = {}
    for a in bpy.data.actions:
        if a in acts_before:
            continue
        a.use_fake_user = True
        acts[a.name.split("_Armature")[0]] = a
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    LIB_ACTS[lib] = acts
    return acts

def pose_from_library(arm, lib, clip, frame):
    acts = library_actions(lib)
    act = acts.get(clip)
    if act is None:
        print("clip not found", clip, list(acts))
        return None
    act = act.copy()
    for fc in list(act.fcurves):
        if fc.data_path.endswith("location") and '"Hips"' not in fc.data_path:
            act.fcurves.remove(fc)
        elif fc.data_path.endswith("scale"):
            act.fcurves.remove(fc)
    arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    sc.frame_set(int(f0 + (f1 - f0) * frame) if isinstance(frame, float) else frame)
    return act

VIEWDEF = {
    "front": (0.0, 3.3, 0.95, 0.9, 50),
    "threeq": (math.radians(40), 3.3, 0.95, 0.9, 50),
    "side": (math.radians(90), 3.3, 0.95, 0.9, 50),
    "back": (math.radians(180), 3.3, 0.95, 0.9, 50),
    "face": (math.radians(22), 0.75, None, None, 85),
}

for nm in NAMES:
    objs, arm = load(nm)
    if ANIM and arm:
        pose_from_library(arm, ANIM, CLIP, FRAME)
    bpy.context.view_layer.update()
    # head height from the Head bone
    hz = 1.6
    if arm and "Head" in arm.pose.bones:
        hz = (arm.matrix_world @ arm.pose.bones["Head"].head).z + 0.07
        hx = (arm.matrix_world @ arm.pose.bones["Head"].head)
    top = max((o.matrix_world @ Vector(c)).z for o in objs if o.type == "MESH" and not o.hide_render for c in o.bound_box)
    if POSES and arm:
        set_light(LIGHTS[0], math.radians(35))
        for clip in POSES.split(","):
            pose_from_library(arm, ANIM, clip, FRAME)
            bpy.context.view_layer.update()
            for v in VIEWS:
                yaw = VIEWDEF[v][0]
                aim(Vector((-math.sin(yaw) * 3.6, -math.cos(yaw) * 3.6, 1.0)), Vector((0, 0, 0.8)), 45)
                sc.render.filepath = os.path.join(OUT, f"{nm}_{clip}_{v}.png")
                bpy.ops.render.render(write_still=True)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
        continue
    if WALK:
        act = arm.animation_data.action if arm and arm.animation_data else None
        f0, f1 = (int(act.frame_range[0]), int(act.frame_range[1])) if act else (1, 30)
        for i in range(WALK):
            f = f0 + int((f1 - f0) * i / WALK)
            sc.frame_set(f)
            set_light(LIGHTS[0], math.radians(90))
            aim((3.6, 0, 0.9), (0, 0, 0.85), 45)
            sc.render.filepath = os.path.join(OUT, f"{nm}_walk_{i:02d}.png")
            bpy.ops.render.render(write_still=True)
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
        continue
    for li in LIGHTS:
        for v in VIEWS:
            yaw, dist, tz, cz, lens = VIEWDEF[v]
            if v == "face":
                hp = hx if arm else Vector((0, 0, hz))
                tgt = Vector((hp.x, hp.y - 0.02, hz - 0.0))
                loc = tgt + Vector((-math.sin(yaw) * dist, -math.cos(yaw) * dist, 0.02))
            else:
                h = max(top, 0.5)
                tgt = Vector((0, 0, h * 0.52))
                dist = 1.75 * h + 0.6
                loc = Vector((-math.sin(yaw) * dist, -math.cos(yaw) * dist, h * 0.55))
            set_light(li, yaw)
            aim(loc, tgt, lens)
            sc.render.filepath = os.path.join(OUT, f"{nm}_{v}_{li}.png")
            bpy.ops.render.render(write_still=True)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
