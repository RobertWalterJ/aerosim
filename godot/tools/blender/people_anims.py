# Bake the shared animation libraries: assets/models/people/anim_<male|female|child>.glb
# blender.exe -b --python people_anims.py -- [male female child] [--only clip,clip]
# Each library is a plain reference body with the same rig as the people, carrying every clip in people_clips.py as a
# glTF animation (rotations for every bone, position for Hips only). PeopleAssets copies the clips onto each person.
import bpy, os, sys, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import people_lib as L
from people_pose import Poser
from people_clips import CLIPS

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
only = None
if "--only" in argv:
    only = argv[argv.index("--only") + 1].split(",")
    argv = argv[:argv.index("--only")]
kinds = [a for a in argv if not a.startswith("--")] or ["male", "female", "child"]

REF = {
    "male": {"macro": {"gender": 1.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "height": 0.5}},
    "female": {"macro": {"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "height": 0.5}},
    "child": {"macro": {"gender": 0.5, "age": 0.16, "muscle": 0.5, "weight": 0.5, "height": 0.5}, "proxy": "male1591"},
}
FPS = 30

for kind in kinds:
    L.reset_scene()
    spec = {"name": "anim_" + kind, "race": {"caucasian": 1.0, "african": 0.0, "asian": 0.0}, "skin": "young_caucasian_male",
            "clothes": [], "trim_skin": False, "skin_tex": 256}
    spec.update(REF[kind])
    rig, lods, mats = L.build_character(spec)
    sc = bpy.context.scene
    sc.render.fps = FPS
    poser = Poser(rig)
    rig.animation_data_create()
    made = []
    for name, (dur, fn) in CLIPS.items():
        if only and name not in only:
            continue
        act = bpy.data.actions.new(name)
        rig.animation_data.action = act
        n = max(2, round(dur * FPS))
        step = 2 if n > 24 else 1
        frames = list(range(0, n + 1, step))
        if frames[-1] != n:
            frames.append(n)
        for f in frames:
            poser.apply(fn((f % n) / n if f < n else 0.0))
            for pb in rig.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=f + 1, group=pb.name)
            rig.pose.bones["Hips"].keyframe_insert("location", frame=f + 1, group="Hips")
        for fc in act.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        act.use_fake_user = True
        tr = rig.animation_data.nla_tracks.new()
        tr.name = name
        tr.strips.new(name, 1, act)
        tr.mute = True
        rig.animation_data.action = None
        made.append(name)
    poser.reset()
    path = os.path.join(L.OUT_DIR, "anim_" + kind + ".glb")
    objs = lods[2]
    L.select_only([rig] + objs, rig)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_skins=True, export_morph=False, export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=False,
                              export_optimize_animation_size=True, export_materials="NONE",
                              export_def_bones=False, export_rest_position_armature=True,
                              export_anim_single_armature=True, export_reset_pose_bones=True)
    L.log("wrote", path, os.path.getsize(path), made)
    if "--blend" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(L.TOOLS, "blend", "anim_" + kind + ".blend"))
