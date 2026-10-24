# tools/blender: the Blender animals and wildlife props (lane/animals)

Headless Blender 4.2.3 (`RWJ Coding Projects/_tools/blender-4.2.3-windows-x64/blender.exe`). One heavy process at a time.

    blender -b --python build_animal.py -- name=cow_a          # one animal -> assets/models/animals/cow_a.glb
    blender -b --python build_animal.py -- name=cow_a from=rig # reuse the last sculpt and bake: rig and clips only (seconds)
    blender -b --python build_props.py [-- only=night_pen]     # the wildlife props -> assets/models/animals/../wildlife/
    blender -b --python try_shape.py -- name=horse_a           # clay renders of the sculpt only, for anatomy work
    blender -b --python preview_glb.py -- name=cow_a clip=walk strip=1   # Eevee look at an exported file

What happens in `build_animal.py` (`pipeline.py`):
1. **Sculpt.** `species.py` (cattle, the shared four-legged rig), `sp_more.py` (sheep, ram), `sp_horse.py`, `sp_dog.py`
   (dogs, wolf), `sp_hen.py` place joints from real proportions and build the body from ellipsoids, round cones and
   rounded boxes on that skeleton, blended with smooth minimum (`sdf.py`), with noise relief for wool, hair locks and
   feathers. OpenVDB (bundled with Blender) turns the field into a watertight surface at 1.6 to 5 mm.
2. **Paint.** Each species paints colour, roughness and fur amount per vertex on the sculpt (its markings live on the
   body's own rest-pose axes).
3. **Game mesh.** QuadriFlow remesh (all quads, symmetric) of a coarser meshing of the same field, projected back on the
   sculpt; smart UV unwrap. If QuadriFlow refuses a mesh the build falls back to a decimate and says so in the log.
4. **Bake** (Cycles, CPU): albedo, roughness, tangent normal and occlusion from the sculpt to the game mesh, with
   photographed CC0 detail (Poly Haven velour, curly fleece, leather; see `assets/textures/README.md`) projected on the
   sculpt. Written as JPEG albedo, normal and ORM.
5. **Rig.** Armature from the same joints, IK controls on the legs (not exported), bone-heat weights then cleaned
   (smoothed, at most four bones, normalised; the jaw split by geometry; udders and tails fixed), eyes with eyelids.
6. **Clips** (`anim.py`, `anim_dog.py`, `anim_hen.py`): functions of time that pose the controls; every frame is sampled
   into a plain forward-kinematics action, one NLA track per clip.
7. **LODs** by decimation (35 and 10 per cent), weights transferred; export glTF 2.0 (+Z forward in Godot).

Info per animal goes to `info/<name>.json` and `game/animal_info.gd` (heights, UV scale for the fur shader, clip speeds).
Downloads (Poly Haven 1k sets) are cached in `_tools/blender-cache/polyhaven/`; the build expects them there.
