import os
# Stage A: base character (macros, face shaping, skin, rig, assets), baked to plain meshes.
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *
clear()
T = LocationService.get_mpfb_data("targets")
macro = TargetService.get_default_macro_info_dict()
macro.update({"gender": 1.0, "age": 0.592, "muscle": 0.6, "weight": 0.6, "proportions": 0.62, "height": 0.5,
              "race": {"african": 1.0, "asian": 0.0, "caucasian": 0.0}})
human = HumanService.create_human(macro_detail_dict=macro)
face = {"head/head-round": 0.35, "head/head-fat-incr": 0.25,
        "cheek/l-cheek-volume-incr": 0.35, "cheek/r-cheek-volume-incr": 0.35,
        "nose/nose-scale-horiz-incr": 0.35, "nose/nose-flaring-incr": 0.35, "nose/nose-volume-incr": 0.2, "nose/nose-point-width-incr": 0.3,
        "mouth/mouth-upperlip-volume-incr": 0.3, "mouth/mouth-lowerlip-volume-incr": 0.35, "mouth/mouth-scale-horiz-incr": 0.15,
        "chin/chin-width-incr": 0.2, "neck/measure-neck-circ-incr": 0.25}
for k, w in face.items():
    TargetService.load_target(human, os.path.join(T, k + ".target.gz"), weight=w)
skin = AssetService.find_asset_absolute_path("middleage_african_male.mhmat", asset_subdir="skins")
HumanService.set_character_skin(skin, human, skin_type="GAMEENGINE")
HumanService.add_builtin_rig(human, "game_engine")
assets = [("eyes", "high-poly.mhclo", "Eyes"), ("eyebrows", "eyebrow010.mhclo", "Eyebrows"), ("eyelashes", "eyelashes02.mhclo", "Eyelashes"),
          ("clothes", "male_casualsuit02.mhclo", "Clothes"), ("clothes", "shoes05.mhclo", "Clothes")]
for sub, f, t in assets:
    HumanService.add_mhclo_asset(AssetService.find_asset_absolute_path(f, asset_subdir=sub), human, asset_type=t, material_type="GAMEENGINE", subdiv_levels=0)
root = ExportService.create_character_copy(human, name_suffix="_x")
bm = ObjectService.find_object_of_type_amongst_nearest_relatives(root, "Basemesh")
ExportService.bake_modifiers_remove_helpers(bm, bake_masks=True, bake_subdiv=True, remove_helpers=True, also_proxy=True)
# remove the original character
keep = set([root] + ObjectService.get_list_of_children(root))
for c in list(keep):
    keep |= set(ObjectService.get_list_of_children(c))
for o in list(bpy.data.objects):
    if o not in keep: bpy.data.objects.remove(o, do_unlink=True)
# apply remaining shape keys
for o in bpy.data.objects:
    if o.type == 'MESH' and o.data.shape_keys:
        bpy.context.view_layer.objects.active = o
        for s in bpy.context.selected_objects: s.select_set(False)
        o.select_set(True)
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, (len(o.data.polygons), [m.type for m in o.modifiers]) if o.type == 'MESH' else '', o.parent.name if o.parent else '')
import mathutils
zs = [ (o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == 'MESH' and 'Basemesh' in str(o.get('mpfb_type','')) or o == bm for v in o.data.vertices] if False else [(bm.matrix_world @ v.co).z for v in bm.data.vertices]
print("HEIGHT", max(zs), min(zs))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.environ.get('PILOT_WORK', os.getcwd()), 'A.blend'))
