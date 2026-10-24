# AeroSim vehicle kit: quick look renders in Blender (Cycles on the GPU) for iterating the shapes. The game's own look is
# checked in Godot (test/vehicles_blender_sheet.gd); these are the modeller's working views.
import bpy, math
from mathutils import Vector as V


def setup(res=(960, 600), samples=48, sun_el=25.0, sun_az=210.0, strength=1.0, overcast=False):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        for dt in ('OPTIX', 'CUDA'):
            try:
                prefs.compute_device_type = dt
                prefs.get_devices()
                ok = False
                for d in prefs.devices:
                    d.use = d.type == dt
                    ok = ok or d.use
                if ok:
                    sc.cycles.device = 'GPU'
                    break
            except Exception:
                continue
    except Exception:
        pass
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'AgX - Medium High Contrast' if not overcast else 'None'
    w = bpy.data.worlds.get("vkworld") or bpy.data.worlds.new("vkworld")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = 'NISHITA'
    sky.sun_elevation = math.radians(sun_el)
    sky.sun_rotation = math.radians(sun_az)
    sky.air_density = 1.0
    sky.dust_density = 1.5 if not overcast else 8.0
    sky.sun_intensity = 1.0 if not overcast else 0.05
    sky.sun_disc = not overcast
    nt.links.new(sky.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = strength * (0.35 if not overcast else 1.2)
    if overcast:
        mix = nt.nodes.new("ShaderNodeMixRGB")
        mix.inputs[0].default_value = 0.85
        mix.inputs[2].default_value = (0.55, 0.58, 0.62, 1)
        nt.links.new(sky.outputs[0], mix.inputs[1])
        nt.links.new(mix.outputs[0], bg.inputs[0])
    nt.links.new(bg.outputs[0], out.inputs[0])
    # ground
    if "vkground" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
        g = bpy.context.active_object
        g.name = "vkground"
        m = bpy.data.materials.new("vkground")
        m.use_nodes = True
        bs = m.node_tree.nodes["Principled BSDF"]
        bs.inputs["Base Color"].default_value = (0.09, 0.09, 0.085, 1)
        bs.inputs["Roughness"].default_value = 0.85
        g.data.materials.append(m)
    return sc


def wet(on=True):
    g = bpy.data.objects.get("vkground")
    if g:
        bs = g.data.materials[0].node_tree.nodes["Principled BSDF"]
        bs.inputs["Roughness"].default_value = 0.12 if on else 0.85
        bs.inputs["Base Color"].default_value = (0.03, 0.03, 0.03, 1) if on else (0.09, 0.09, 0.085, 1)


def camera(loc, target, lens=50.0, name="vkcam"):
    cam = bpy.data.objects.get(name)
    if cam is None:
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        bpy.context.scene.collection.objects.link(cam)
    cam.location = V(loc)
    d = V(target) - V(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    cam.data.clip_start = 0.02
    bpy.context.scene.camera = cam
    return cam


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


VIEWS = {
    # name: (camera offset from the vehicle's centre as multiples of length L, height in m, target height fraction, lens)
    "front34": ((0.95, 1.05), 1.4, 0.45, 50),
    "side": ((1.55, 0.0), 0.9, 0.45, 50),
    "rear34": ((-0.95, -1.05), 1.5, 0.45, 50),
    "top": ((0.0, 0.01), 7.0, 0.0, 35),
    "rearlow": ((-0.25, -1.3), 1.3, 0.55, 50),
}


def view(name, L, H, cx=0.0):
    off, h, tf, lens = VIEWS[name]
    if name == "side":
        loc = (L * off[0] + 1.0, 0.0, h)
    elif name == "top":
        loc = (0.0, 0.01, max(L * 1.6, 5.0))
    else:
        loc = (L * off[0], L * off[1], h)
    camera(loc, (0.0, 0.0, H * tf), lens)
