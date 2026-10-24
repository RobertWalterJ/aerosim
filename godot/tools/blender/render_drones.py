# Render the exported drone .glb files in Blender (Cycles) for checking by eye, the marketplace thumbnails and the
# parts sheet. It imports the files back, so it also proves the export opens.
#   blender -b -P godot/tools/blender/render_drones.py -- job=<views|thumbs|parts> [names=a,b] [out=<dir>] [light=golden|overcast|studio] [res=640]
# views: one PNG per (model, view) into out/: front, side, three-quarter, top, under, and close-ups (motor, camera,
#        gimbal, pod). The contact sheets are put together from them by tools/blender/drones_sheets.py.
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(__file__)
MODELS = os.path.abspath(os.path.join(HERE, "..", "..", "assets", "models", "drones"))

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = {"job": "views", "names": "raptor_race_a,nightowl_a,night_vision_pod_a", "out": os.path.join(HERE, "_renders"), "light": "golden", "res": "640", "samples": "96"}
for a in args:
    if "=" in a:
        k, v = a.split("=", 1)
        opt[k] = v
OUT = opt["out"]
os.makedirs(OUT, exist_ok=True)
RES = int(opt["res"])


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for dev in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = dev
            prefs.get_devices()
            for d in prefs.devices:
                d.use = True
            sc.cycles.device = "GPU"
            break
        except Exception:
            continue
    sc.cycles.samples = int(opt["samples"])
    sc.cycles.use_denoising = True
    sc.render.resolution_x = RES
    sc.render.resolution_y = int(RES * 0.75)
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    return sc


def light(kind):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    sc.view_settings.exposure = {"golden": -0.9, "overcast": -0.3}.get(kind, 0.0)
    if kind == "golden":
        sky = nt.nodes.new("ShaderNodeTexSky")
        sky.sky_type = "NISHITA"
        sky.sun_elevation = math.radians(9.0)
        sky.sun_rotation = math.radians(215.0)
        sky.sun_size = math.radians(1.2)
        sky.air_density = 1.4
        sky.dust_density = 2.5
        nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 0.55
        sun = bpy.data.lights.new("sun", "SUN")
        sun.energy = 2.2
        sun.color = (1.0, 0.8, 0.6)
        sun.angle = math.radians(1.0)
        o = bpy.data.objects.new("sun", sun)
        o.rotation_euler = Euler((math.radians(81.0), 0.0, math.radians(215.0 - 180.0)))
        sc.collection.objects.link(o)
    elif kind == "overcast":
        bg.inputs["Color"].default_value = (0.62, 0.66, 0.72, 1.0)
        bg.inputs["Strength"].default_value = 1.15
        sun = bpy.data.lights.new("soft", "SUN")
        sun.energy = 0.6
        sun.angle = math.radians(35.0)
        o = bpy.data.objects.new("soft", sun)
        o.rotation_euler = Euler((math.radians(20.0), 0.0, math.radians(30.0)))
        sc.collection.objects.link(o)
    else:  # studio: a product shot on a pale sweep
        bg.inputs["Color"].default_value = (0.86, 0.87, 0.9, 1.0)
        bg.inputs["Strength"].default_value = 0.55
        for (rx, rz, e, sz) in ((55, 35, 260, 0.6), (65, 200, 90, 0.9), (20, 120, 60, 0.5)):
            L = bpy.data.lights.new("area", "AREA")
            L.energy = e * 0.012
            L.size = sz
            o = bpy.data.objects.new("area", L)
            d = Vector((math.sin(math.radians(rx)) * math.sin(math.radians(rz)), -math.sin(math.radians(rx)) * math.cos(math.radians(rz)), math.cos(math.radians(rx))))
            o.location = d * 0.6
            o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
            sc.collection.objects.link(o)


def ground(kind):
    me = bpy.data.meshes.new("g")
    s = 3.0
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("ground", me)
    bpy.context.scene.collection.objects.link(o)
    m = bpy.data.materials.new("gm")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    if kind == "studio":
        b.inputs["Base Color"].default_value = (0.75, 0.76, 0.78, 1)
        b.inputs["Roughness"].default_value = 0.6
    else:
        # a weathered concrete launch pad
        tex = m.node_tree.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 60.0
        tex.inputs["Detail"].default_value = 8.0
        ramp = m.node_tree.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].color = (0.09, 0.09, 0.09, 1)
        ramp.color_ramp.elements[1].color = (0.2, 0.2, 0.19, 1)
        m.node_tree.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        m.node_tree.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.85
    me.materials.append(m)


def load(name, at=(0, 0, 0), lift=0.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in objs if o.parent is None]
    for r in roots:
        r.location = Vector(at) + Vector((0, 0, lift))
    bpy.context.view_layer.update()
    return objs


def bbox(objs):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for o in objs:
        if o.type != "MESH":
            continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi


def camera(target, direction, dist, lens=60.0):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cd.clip_start = 0.002
    cd.dof.use_dof = False
    o = bpy.data.objects.new("cam", cd)
    bpy.context.scene.collection.objects.link(o)
    d = Vector(direction).normalized()
    o.location = Vector(target) + d * dist
    o.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = o
    return o


def shoot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def node(objs, name):
    for o in objs:
        if o.name.split(".")[0] == name:
            return o
    return None


# nose is -Y after import (the file's +Z front); right-hand side of the drone is -X
VIEWS = {
    "front": (Vector((0.0, -1.0, 0.18)), 1.0),
    "side": (Vector((-1.0, 0.0, 0.14)), 1.0),
    "three_quarter": (Vector((-0.75, -0.8, 0.55)), 1.0),
    "top": (Vector((0.0, -0.02, 1.0)), 1.0),
    "rear": (Vector((0.45, 1.0, 0.4)), 1.0),
    "under": (Vector((0.3, -0.5, -0.25)), 1.0),
}


def job_views():
    for name in opt["names"].split(","):
        for kind in opt["light"].split(","):
            reset(); light(kind); ground(kind)
            objs = load(name, lift=0.0 if name != "night_vision_pod_a" else 0.05)
            lo, hi = bbox(objs)
            c = (lo + hi) * 0.5
            size = (hi - lo).length
            want = list(VIEWS.keys())
            if opt.get("views"):
                want = opt["views"].split(",")
            gnd = bpy.data.objects.get("ground")
            for v in want:
                if v in VIEWS:
                    d, f = VIEWS[v]
                    camera(c, d, size * 1.45 * f, 60.0)
                    if gnd is not None:
                        gnd.hide_render = v == "under"       # seen from below the ground would hide it
                    shoot(os.path.join(OUT, "%s_%s_%s.png" % (name, v, kind)))
            if gnd is not None:
                gnd.hide_render = False
            # close-ups
            close = []
            if name == "raptor_race_a":
                p = node(objs, "prop_fr"); close.append(("motor", p.matrix_world.translation + Vector((0, 0, -0.008)), Vector((-0.7, -0.9, 0.55)), 0.075))
                p = node(objs, "camera_lens"); close.append(("camera", p.matrix_world.translation, Vector((0.35, -1.0, 0.25)), 0.09))
                p = node(objs, "action_cam_lens"); close.append(("action_cam", p.matrix_world.translation, Vector((-0.6, -1.0, 0.45)), 0.11))
                close.append(("stack", c + Vector((0, 0.0, -0.01)), Vector((-1.0, 0.25, 0.32)), 0.12))
                close.append(("battery", c + Vector((0, 0.01, 0.01)), Vector((0.55, 0.9, 0.6)), 0.15))
            elif name == "nightowl_a":
                p = node(objs, "gimbal_pitch"); close.append(("gimbal", p.matrix_world.translation, Vector((-0.75, -1.0, 0.05)), 0.11))
                p = node(objs, "prop_fl"); close.append(("motor", p.matrix_world.translation + Vector((0, 0, -0.008)), Vector((0.7, -0.9, 0.55)), 0.075))
                p = node(objs, "nv_pod"); close.append(("pod", p.matrix_world.translation + Vector((0, 0, -0.02)), Vector((0.5, -1.0, -0.15)), 0.11))
                p = node(objs, "landing_light"); close.append(("landing_light", p.matrix_world.translation, Vector((-0.25, -1.0, -0.22)), 0.1))
            elif name == "night_vision_pod_a":
                close.append(("lens", c, Vector((-0.4, -1.0, 0.1)), 0.11))
                close.append(("back", c, Vector((0.6, 1.0, 0.3)), 0.12))
            for (tag, tgt, d, dist) in close:
                camera(tgt, d, dist, 50.0)
                shoot(os.path.join(OUT, "%s_close_%s_%s.png" % (name, tag, kind)))


def job_thumbs():
    """512 px marketplace listing photos: the drone on a pale sweep, three-quarter from the front."""
    sc = None
    for name in ("raptor_race_a", "nightowl_a"):
        sc = reset(); light("studio"); ground("studio")
        sc.render.resolution_x = 512; sc.render.resolution_y = 512
        objs = load(name)
        lo, hi = bbox(objs)
        c = (lo + hi) * 0.5
        camera(c + Vector((0, 0, -0.004)), Vector((-0.8, -0.85, 0.5)), (hi - lo).length * 1.42, 60.0)
        shoot(os.path.join(OUT, "thumb_%s.png" % name))


def job_parts():
    """The generic parts listing photo: the night-vision pod, a battery, a prop, a motor (cut from the Raptor's file)."""
    sc = reset(); light("studio"); ground("studio")
    sc.render.resolution_x = 512; sc.render.resolution_y = 512
    pod = load("night_vision_pod_a", at=(0.045, 0.02, 0.034))
    rap = load("raptor_race_a", at=(0, 0, 0))
    keep = {"battery", "prop_fr", "prop_rl"}
    for o in rap:
        base = o.name.split(".")[0]
        if base not in keep and o.parent is not None and o.parent.parent is None and base not in ("raptor_race_a",):
            o.hide_render = True
        if base in ("camera_lens", "action_cam_lens", "action_cam_led", "status_led"):
            o.hide_render = True
    bat = node(rap, "battery"); bat.location += Vector((-0.06, 0.03, -0.035))
    p1 = node(rap, "prop_fr"); p1.location = Vector((0.0, -0.075, 0.004)) - (p1.parent.location if p1.parent else Vector())
    p2 = node(rap, "prop_rl"); p2.location = Vector((-0.06, -0.08, 0.004)) - (p2.parent.location if p2.parent else Vector())
    bpy.context.view_layer.update()
    camera(Vector((-0.005, -0.02, 0.02)), Vector((-0.2, -1.0, 0.95)), 0.33, 50.0)
    shoot(os.path.join(OUT, "thumb_parts.png"))


{"views": job_views, "thumbs": job_thumbs, "parts": job_parts}[opt["job"]]()
