# Quick shape check: build one animal's sculpt from species.py and render clay views.
# blender -b --python try_shape.py -- name=cow_a out=<dir> [vox=0.008]
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import sdf, blib, species
args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
name = args.get("name", "cow_a")
out = args.get("out", os.path.join(os.environ.get("TEMP", "."), "animals"))
os.makedirs(out, exist_ok=True)
t = time.time()
spec = species.get(name)
vox = float(args.get("vox", spec.preview_vox))
F = spec.field(vox)
print("field", F.n, "%.1fs" % (time.time() - t))
pts, tris, quads = F.mesh()
print("mesh", len(pts), len(tris), len(quads), "%.1fs" % (time.time() - t))
blib.clear_scene()
ob = blib.mesh_from_arrays(name, pts, tris, quads)
imgs = blib.render_views([ob], os.path.join(out, name + ".png"))
print("IMGS", imgs, "%.1fs" % (time.time() - t))
