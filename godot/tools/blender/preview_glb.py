# Quick look at an exported animal in Blender (Eevee): imports the .glb and renders views and an animation strip.
#   blender -b --python preview_glb.py -- name=cow_a [clip=walk] [frames=6] [out=<dir>] [lod=0]
import sys, os, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from mathutils import Vector
import blib

args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
name = args["name"]
godot = os.path.normpath(os.path.join(HERE, "..", ".."))
glb = args.get("glb", os.path.join(godot, "assets", "models", "animals", name + ".glb"))
out = args.get("out", os.path.join(os.environ.get("TEMP", "."), "aerosim_animals", "preview"))
os.makedirs(out, exist_ok=True)
lod = int(args.get("lod", 0))
blib.clear_scene()
bpy.ops.import_scene.gltf(filepath=glb)
scn = bpy.context.scene
scn.render.fps = 30
arm = next(o for o in scn.objects if o.type == "ARMATURE")
for o in scn.objects:
    if o.type == "MESH":
        keep = ("LOD%d" % lod) in o.name or ("eye" in o.name or "lid" in o.name or "fur" in o.name or "card" in o.name) and lod == 0
        if "LOD" in o.name and ("LOD%d" % lod) not in o.name: keep = False
        o.hide_render = not keep
# ground
bpy.ops.mesh.primitive_plane_add(size=40)
g = bpy.context.active_object
gm = bpy.data.materials.new("ground"); gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.07, 0.025, 1)
g.data.materials.append(gm)
scn.render.engine = "BLENDER_EEVEE_NEXT"
scn.eevee.taa_render_samples = 32
try:
    scn.eevee.use_shadows = True
except Exception:
    pass
scn.render.resolution_x, scn.render.resolution_y = int(args.get("w", 640)), int(args.get("h", 480))
scn.world = bpy.data.worlds.new("w"); scn.world.use_nodes = True
bg = scn.world.node_tree.nodes["Background"]; bg.inputs["Color"].default_value = (0.55, 0.65, 0.8, 1); bg.inputs["Strength"].default_value = 0.8
ld = bpy.data.lights.new("sun", "SUN"); ld.energy = float(args.get("sun", 3.5)); ld.angle = math.radians(2)
sun = bpy.data.objects.new("sun", ld); scn.collection.objects.link(sun)
sun.rotation_euler = (math.radians(55), 0, math.radians(float(args.get("sunaz", 140))))
cd = bpy.data.cameras.new("cam"); cd.lens = float(args.get("lens", 50))
cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
clip = args.get("clip", "idle")
act = bpy.data.actions.get(clip) or next((a for a in bpy.data.actions if a.name.split("_")[0] == clip), None)
if act:
    arm.animation_data_create(); arm.animation_data.action = act
frame = int(args.get("frame", 0))
scn.frame_set(frame)
# frame the body
lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for o in scn.objects:
    if o.type == "MESH" and not o.hide_render and o != g:
        dg = bpy.context.evaluated_depsgraph_get()
        oe = o.evaluated_get(dg)
        for v in oe.to_mesh().vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        oe.to_mesh_clear()
ctr = (lo + hi) / 2; rad = (hi - lo).length / 2
views = args.get("views", "side,34front,front,34rear,head").split(",")
dirs = {"side": (1, 0, 0.1), "34front": (0.75, -1.0, 0.3), "front": (0, -1, 0.12), "34rear": (-0.8, 1.0, 0.35), "rear": (0, 1, 0.15),
        "top": (0.01, 0.0, 1.0), "lside": (-1, 0, 0.1)}
imgs = []
def shoot(tag, dv, c, r):
    dv = Vector(dv).normalized()
    d = r / math.sin(cd.angle / 2) * 0.9
    cam.location = c + dv * d
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    cd.clip_start = d * 0.01; cd.clip_end = d * 20
    p = os.path.join(out, "%s_%s.png" % (name, tag))
    scn.render.filepath = p
    bpy.ops.render.render(write_still=True)
    imgs.append(p)
for v in views:
    if v == "head":
        hb = arm.pose.bones.get("head")
        hp = arm.matrix_world @ ((hb.head + hb.tail) / 2)
        shoot("head", (0.8, -0.8, 0.25), hp, rad * 0.28)
    else:
        shoot(v, dirs[v], ctr, rad)
if "strip" in args and act:
    n = int(args.get("frames", 6))
    f0, f1 = act.frame_range
    for i in range(n):
        scn.frame_set(int(f0 + (f1 - f0) * i / n))
        shoot("%s%02d" % (clip, i), (1, 0, 0.08), ctr, rad)
print("PREVIEW", imgs)
