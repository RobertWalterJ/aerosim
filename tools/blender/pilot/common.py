import bpy, sys, importlib, os, math
bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")
def imp(path, key):
    for m in list(sys.modules):
        if m.endswith(path):
            return getattr(importlib.import_module(m), key)
    raise ValueError(path)
HumanService = imp("mpfb.services.humanservice", "HumanService")
AssetService = imp("mpfb.services.assetservice", "AssetService")
TargetService = imp("mpfb.services.targetservice", "TargetService")
LocationService = imp("mpfb.services.locationservice", "LocationService")
ObjectService = imp("mpfb.services.objectservice", "ObjectService")
ExportService = imp("mpfb.services.exportservice", "ExportService")

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.preferences.addon_enable(module="bl_ext.user_default.mpfb")

def render_setup(res=(720, 960), samples=24):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.transparent_max_bounces = 48; sc.cycles.max_bounces = 16; sc.cycles.device = 'CPU'; sc.cycles.samples = samples; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.resolution_percentage = 100
    sc.view_settings.view_transform = 'AgX'
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.55, 0.65, 0.8, 1); bg.inputs[1].default_value = 0.6
    sun = bpy.data.lights.new('sun', 'SUN'); sun.energy = 3.5; sun.angle = 0.05
    so = bpy.data.objects.new('sun', sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(50), 0, math.radians(-35))

def shoot(path, loc, target, lens=50):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new('cam'); cam.lens = lens
    co = bpy.data.objects.new('cam', cam); sc.collection.objects.link(co); co.location = loc
    tgt = bpy.data.objects.new('tgt', None); sc.collection.objects.link(tgt); tgt.location = target
    c = co.constraints.new('TRACK_TO'); c.target = tgt; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
    sc.camera = co; sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co); bpy.data.objects.remove(tgt)
