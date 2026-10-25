import os
# Stage E: bake the holding pose into the rest pose (so the game only animates head/neck), shrink textures, export GLB.
import bpy, os
W = os.environ.get('PILOT_WORK', os.getcwd())
OUT = os.environ.get('OUT', W + '/pilot.glb')
rig = bpy.data.objects['Human.rig_x']
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in meshes:
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception as e: print('MODFAIL', o.name, m.name, e)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='POSE'); bpy.ops.pose.select_all(action='SELECT')
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
    m = o.modifiers.new('Armature', 'ARMATURE'); m.object = rig
    if o.parent != rig: o.parent = rig
# texture budget for the web
limits = {'skin_diffuse': 2048, 'male_casualsuit02_normal': 1024, 'top_jeans_diffuse': 1024, 'beard_rgba': 1024,
          'shoes05': 512, 'brown_eye': 256, 'eyebrow': 256, 'eyelashes': 256, 'rc_screen_ui': 640}
for img in bpy.data.images:
    for k, lim in limits.items():
        if k in img.name and img.size[0] > lim:
            img.scale(lim, lim); print('SCALED', img.name, lim)
# names the game looks for
names = {'Human_x': 'body', 'Human.male_casualsuit02_x': 'clothes', 'Human.shoes05_x': 'shoes', 'Human.high-poly_x': 'eyes',
         'Human.eyebrow010_x': 'eyebrows', 'Human.eyelashes02_x': 'eyelashes'}
for o in meshes:
    if o.name in names: o.name = names[o.name]
rig.name = 'pilot_rig'
tris = 0
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.calc_loop_triangles(); n = len(o.data.loop_triangles); tris += n; print('MESH', o.name, n)
print('TRIS', tris)
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=False, export_apply=True, export_skins=True,
                          export_animations=False, export_morph=False, export_yup=True, export_image_format='WEBP',
                          export_image_quality=88, export_def_bones=True, export_extras=False, export_cameras=False, export_lights=False)
print('EXPORTED', OUT, os.path.getsize(OUT))
bpy.ops.wm.save_as_mainfile(filepath=W + '/E_rest.blend')
