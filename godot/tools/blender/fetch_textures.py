"""Downloads the CC0 Poly Haven sets the Blender buildings use (1k JPEG: diff, nor_gl, arm) into tools/blender/tex_src/.
Run with python -I. The building script packs them into the .glb files; the sources are recorded in assets/textures/README.md."""
import json, os, sys, urllib.request
UA = {"User-Agent": "AeroSim-buildings/1.0 (texture fetch)"}
def get(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=UA))
SETS = ["red_brick", "brick_wall_02", "medieval_red_brick", "roof_slates_02", "roof_slates_03", "corrugated_iron_02",
        "worn_corrugated_iron", "weathered_plank_siding", "distressed_painted_planks", "painted_plaster_wall",
        "plastered_wall_02", "old_planks_02", "concrete_floor_painted", "wood_floor_worn", "rusty_metal_sheet", "old_sandstone_02", "white_sandstone_blocks_02"]
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for s in SETS:
    info = json.load(get("https://api.polyhaven.com/files/" + s))
    for key, mp in (("diff", "Diffuse"), ("nor", "nor_gl"), ("arm", "arm"), ("disp", "Displacement")):
        if mp not in info: print("missing", s, mp); continue
        url = info[mp]["1k"]["jpg"]["url"]
        dst = os.path.join(out, "%s_%s.jpg" % (s, key))
        if not os.path.exists(dst):
            open(dst, "wb").write(get(url).read())
        print(dst)
    a = json.load(get("https://api.polyhaven.com/info/" + s))
    print(s, "dims_mm", a.get("dimensions"), "authors", list(a.get("authors", {}).keys()))
