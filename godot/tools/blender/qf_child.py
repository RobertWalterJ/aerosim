# QuadriFlow in its own Blender process (it can crash Blender outright on some inputs: "wrong init"), so the build can
# survive and try again. blender -b --python qf_child.py -- <in.obj> <out.obj> <target_faces> <seed> <voxel 0|size>
import sys, bpy
a = sys.argv[sys.argv.index("--") + 1:]
src, dst, target, seed, vox = a[0], a[1], int(a[2]), int(a[3]), float(a[4])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src, forward_axis="Y", up_axis="Z")
ob = bpy.context.selected_objects[0]
bpy.context.view_layer.objects.active = ob
if vox > 0:
    ob.data.remesh_voxel_size = vox
    bpy.ops.object.voxel_remesh()
    import bmesh
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0004)
    bmesh.ops.dissolve_degenerate(bm, dist=0.0004, edges=bm.edges[:])
    bm.to_mesh(ob.data); bm.free()
n0 = len(ob.data.polygons)
bpy.ops.object.quadriflow_remesh(target_faces=target, use_mesh_symmetry=True, use_preserve_sharp=False, use_preserve_boundary=False,
                                 preserve_attributes=False, smooth_normals=True, mode="FACES", seed=seed)
n1 = len(ob.data.polygons)
if n1 != n0:
    bpy.ops.wm.obj_export(filepath=dst, export_selected_objects=False, export_materials=False, export_uv=False, export_normals=False,
                          forward_axis="Y", up_axis="Z")
print("QFCHILD", n0, n1)
