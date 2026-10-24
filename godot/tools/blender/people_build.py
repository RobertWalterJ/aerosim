# Build and export people: blender.exe -b --python people_build.py -- <name> [<name>...] | all  [--blend]
# Needs the private Blender user folder with MPFB (see people_setup.py; run_people.sh sets BLENDER_USER_RESOURCES).
import bpy, os, sys, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import people_lib as L
from people_roster import ROSTER

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
save_blend = "--blend" in argv
names = [a for a in argv if not a.startswith("--")]
if not names or names == ["all"]:
    names = list(ROSTER)
report = {}
for nm in names:
    L.reset_scene()
    spec = ROSTER[nm]
    rig, lods, mats = L.build_character(spec)
    st = L.stats(rig, lods)
    report[nm] = st
    L.log(nm, json.dumps(st))
    objs = [o for l in lods.values() for o in l]
    path = os.path.join(L.OUT_DIR, nm + ".glb")
    L.export_glb(path, rig, objs)
    L.log("wrote", path, os.path.getsize(path))
    if spec.get("ghost_file"):
        # lane/rennick: the same build with drained, pale materials baked in (people_rennick.ghostify)
        import people_rennick
        people_rennick.ghostify(objs, nm)
        gpath = os.path.join(L.OUT_DIR, spec["ghost_file"] + ".glb")
        L.export_glb(gpath, rig, objs)
        L.log("wrote", gpath, os.path.getsize(gpath))
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.TOOLS, "blend", nm + ".blend"))
rp = os.path.join(L.TOOLS, "build_report.json")
old = json.load(open(rp)) if os.path.exists(rp) else {}
old.update(report)
json.dump(old, open(rp, "w"), indent=1)
