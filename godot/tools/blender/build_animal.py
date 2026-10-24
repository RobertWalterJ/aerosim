# Builds one AeroSim animal from its species definition and writes godot/assets/models/animals/<name>.glb.
#   blender -b --python godot/tools/blender/build_animal.py -- name=cow_a [vox=0.005] [tex=2048] [lod0=16000] [keep=1]
# keep=1 also saves the working .blend next to the textures (for inspection). See README.md in this folder.
import sys, os, time, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import numpy as np
import sdf, blib, species, pipeline as pl, anim

args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
name = args["name"]
spec = species.get(name)
vox = float(args.get("vox", spec.vox))
tex = int(args.get("tex", spec.tex))
lod0 = int(args.get("lod0", spec.lod0))
godot = os.path.normpath(os.path.join(HERE, "..", ".."))
out_glb = args.get("out", os.path.join(godot, "assets", "models", "animals", name + ".glb"))
work = os.path.join(os.environ.get("TEMP", "."), "aerosim_animals", name)
os.makedirs(work, exist_ok=True); os.makedirs(os.path.dirname(out_glb), exist_ok=True)
t0 = time.time()

baked = os.path.join(work, name + "_baked.blend")
if args.get("from") == "rig" and os.path.exists(baked):
    # reuse the sculpt, game mesh and baked textures from the last full run (for rig and animation work)
    bpy.ops.wm.open_mainfile(filepath=baked)
    lo = bpy.data.objects[name + "_LOD0"]
    texs = {k: bpy.data.images[k] for k in ("albedo", "orm", "normal")}
    hi = bpy.data.objects.get(name + "_hi")
    spec._field = spec.field(spec.vox)    # refreshes the landmarks found on the sculpt (eye placement)
else:
    blib.clear_scene()
    hi = pl.build_sculpt(spec, vox)
    lo = pl.make_lowpoly(hi, name + "_LOD0", lod0, field=spec._field)
    pl.uv_unwrap(lo)
    pl.fur_to_vertex_colour(hi, lo)
    lo["uv_m"] = pl.uv_metres(lo)
    maps, _ = pl.bake_maps(spec, hi, lo, tex, work, cage=spec.cage)
    texs = pl.write_textures(spec, maps, work, tex)
    mat = pl.game_material(spec, texs)
    lo.data.materials.clear(); lo.data.materials.append(mat)
    for im in texs.values(): im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=baked)
scn = bpy.context.scene
extras = spec.extras(texs) if hasattr(spec, "extras") else []          # hair cards, feathers: (object, weight source)
eyes = pl.make_eyes(spec, None)
arm = pl.build_armature(spec)
spec.setup_controls(arm)
pl.skin(spec, arm, lo, eyes)
lod1 = pl.make_lod(lo, name + "_LOD1", spec.lod_ratio[0])
lod2 = pl.make_lod(lo, name + "_LOD2", spec.lod_ratio[1])
for o in (lod1, lod2):
    o.vertex_groups.clear()
    pl.transfer_weights(lo, o, arm)
for o, how in extras:
    pl.transfer_weights(lo, o, arm) if how == "transfer" else spec.weight_extra(o, arm, how)
update = bpy.context.view_layer.update
clips = spec.clips(arm, update)
actions = pl.bake_clips(spec, arm, clips)
# the hi-res sculpt is only for baking
if hi is not None: bpy.data.objects.remove(hi)
exported = [lo, lod1, lod2] + eyes + [o for o, _ in extras]
for o in exported: o.data.name = o.name
pl.export_glb(out_glb, exported, arm)
info = {"name": name, "tris": {o.name: blib.tri_count(o) for o in exported}, "clips": [a.name for a in actions],
        "clip_speeds": spec.clip_speeds(), "uv_m": round(float(lo.get("uv_m", 0.0)), 4),
        "height": round(max((arm.matrix_world @ v.co).z for v in lo.data.vertices), 3), "seconds": round(time.time() - t0, 1), "bytes": os.path.getsize(out_glb)}
ys = [(arm.matrix_world @ v.co).y for v in lo.data.vertices]
info["length"] = round(max(ys) - min(ys), 3)
json.dump(info, open(os.path.join(work, "info.json"), "w"), indent=1)
os.makedirs(os.path.join(HERE, "info"), exist_ok=True)
json.dump(info, open(os.path.join(HERE, "info", name + ".json"), "w"), indent=1, sort_keys=True)
import write_info
write_info.write(os.path.join(HERE, "info"), os.path.join(godot, "game", "animal_info.gd"))
print("INFO", json.dumps(info))
if args.get("keep") == "1":
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(work, name + ".blend"))
