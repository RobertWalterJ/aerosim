# AeroSim vehicle kit: the rig and the export. Every moving part is rigidly bound (weight 1) to one bone of one armature;
# the three levels of detail are three meshes on the same armature, named <name>_LOD0, _LOD1, _LOD2. Every pivot bone
# POINTS ALONG ITS TURNING AXIS, so a part turns by rotating its bone about the bone's own +Y (wheels spin, doors swing,
# wheels steer, wipers sweep, the steering wheel turns). The baked actions become AnimationPlayer animations in Godot.
import bpy, bmesh, math
from mathutils import Vector as V, Matrix, Quaternion
from vk_core import material, box_uv, tri_count


def merge_parts(name, parts, bone_names, coll=None):
    """One mesh from many parts, each part's vertices weighted 1 to its bone."""
    bm = bmesh.new()
    dl = bm.verts.layers.deform.verify()
    mats = []
    gidx = {b: i for i, b in enumerate(bone_names)}
    for p in parts:
        if len(p.bm.faces) == 0:
            continue
        if p.bone not in gidx:
            raise ValueError("part %s on unknown bone %s" % (p.name, p.bone))
        gi = gidx[p.bone]
        p.bm.verts.index_update()
        vm = {}
        for v in p.bm.verts:
            nv = bm.verts.new(v.co)
            nv[dl][gi] = 1.0
            vm[v.index] = nv
        for f in p.bm.faces:
            mname = p.mats[f.material_index] if f.material_index < len(p.mats) else p.mats[0]
            if mname not in mats:
                mats.append(mname)
            try:
                nf = bm.faces.new([vm[v.index] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mats.index(mname)
            nf.smooth = f.smooth
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)   # only welds within the same coordinates
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(material(m))
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    for b in bone_names:
        ob.vertex_groups.new(name=b)
    try:
        me.set_sharp_from_angle(angle=math.radians(38.0))
    except Exception:
        pass
    box_uv(ob, 1.0)
    return ob


def armature(name, bones):
    """bones: list of dicts {name, head, tail, parent}. Returns the armature object (at the origin)."""
    ad = bpy.data.armatures.new(name + "_rig")
    ob = bpy.data.objects.new(name, ad)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for b in bones:
        e = ad.edit_bones.new(b["name"])
        e.head = V(b["head"])
        e.tail = V(b["tail"])
        e.roll = b.get("roll", 0.0)
        e.use_deform = True
        eb[b["name"]] = e
    for b in bones:
        if b.get("parent"):
            eb[b["name"]].parent = eb[b["parent"]]
            eb[b["name"]].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in ob.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return ob


def bind(mesh_ob, arm_ob):
    mesh_ob.parent = arm_ob
    m = mesh_ob.modifiers.new("Armature", 'ARMATURE')
    m.object = arm_ob


def add_action(arm, name, keys, fps=24):
    """keys: {bone: [(frame, angle_radians_about_bone_Y or ('loc', (x, y, z) world metres))...]}"""
    act = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for bname, ks in keys.items():
        pb = arm.pose.bones.get(bname)
        if pb is None:
            continue
        rest = pb.bone.matrix_local.to_3x3()
        for (fr, val) in ks:
            if isinstance(val, tuple) and val[0] == 'loc':
                pb.location = rest.inverted() @ V(val[1])
                pb.keyframe_insert("location", frame=fr, group=bname)
            else:
                pb.rotation_quaternion = Quaternion(V((0, 1, 0)), val)
                pb.keyframe_insert("rotation_quaternion", frame=fr, group=bname)
        # reset
        pb.rotation_quaternion = Quaternion()
        pb.location = V((0, 0, 0))
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.easing = 'AUTO'
    trk = arm.animation_data.nla_tracks.new()
    trk.name = name
    st = trk.strips.new(name, int(act.frame_range[0]), act)
    trk.mute = True
    arm.animation_data.action = None
    act.use_fake_user = True
    return act


def bake_ao(obs, distance=0.5, samples=48):
    """Ambient occlusion into the colour attribute 'Col' (rgb), keeping alpha (the finish condition)."""
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
    if sc.world is None:
        sc.world = bpy.data.worlds.new("bakeworld")
    sc.world.light_settings.distance = distance
    for ob in obs:
        me = ob.data
        alpha = None
        if "Col" in me.color_attributes:
            ca = me.color_attributes["Col"]
            alpha = [c.color[3] for c in ca.data]
        else:
            ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
            for c in ca.data:
                c.color = (1, 1, 1, 1)
        me.color_attributes.active_color = ca
        try:
            me.attributes.default_color_name = "Col"
        except Exception:
            pass
        for o in list(bpy.context.view_layer.objects):
            if o is not None:
                o.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        # disable the armature modifier while baking so the rest pose is used
        try:
            bpy.ops.object.bake(type='AO', target='VERTEX_COLORS', margin=0, use_clear=True)
        except Exception as e:
            print("AO bake failed", ob.name, e)
            continue
        ca = me.color_attributes["Col"]
        for i, c in enumerate(ca.data):
            col = c.color
            a = 1.0 if alpha is None else alpha[i]
            # soften: full black AO is too strong for open panels
            g = 0.25 + 0.75 * col[0]
            c.color = (g, g, g, a)


def set_condition(ob, fn):
    """Write the finish condition (vertex alpha; 1 clean .. 0 rusted through) from fn(co, normal)."""
    me = ob.data
    if "Col" not in me.color_attributes:
        ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
        for c in ca.data:
            c.color = (1, 1, 1, 1)
    ca = me.color_attributes["Col"]
    for i, v in enumerate(me.vertices):
        c = ca.data[i].color
        ca.data[i].color = (c[0], c[1], c[2], max(0.0, min(1.0, fn(v.co, v.normal))))


def export_glb(path, arm, meshes):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    arm.select_set(True)
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True, export_apply=False,
        export_texcoords=True, export_normals=True, export_tangents=True, export_materials='EXPORT',
        export_vertex_color='ACTIVE', export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
        export_skins=True, export_def_bones=False, export_animations=True, export_animation_mode='NLA_TRACKS',
        export_force_sampling=True, export_optimize_animation_size=True, export_yup=True, export_image_format='NONE',
        export_rest_position_armature=True, export_anim_slide_to_zero=True)
