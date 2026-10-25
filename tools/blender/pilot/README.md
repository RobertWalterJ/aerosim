# Pilot model pipeline (Blender)

Builds `public/models/pilot.glb` from scratch. Everything is scripted so the result is reproducible; the editable scene is also kept at `assets/blender/pilot.blend` (packed, opens without add-ons).

## One-time setup
1. Blender 4.2 LTS or later.
2. MPFB2 (MakeHuman plugin for Blender, GPL code, CC0 assets): install it as an extension so that it loads as `bl_ext.user_default.mpfb` (Edit > Preferences > Get Extensions, or copy `src/mpfb` from https://github.com/makehumancommunity/mpfb2 into Blender's `extensions/user_default/`).
3. MakeHuman system assets (CC0): download `makehuman_system_assets_cc0.zip` from https://files.makehumancommunity.org/asset_packs/makehuman_system_assets/ and unzip it into MPFB's user data folder (`extensions/.user/user_default/mpfb/data/`), or install it from MPFB's Apply Assets panel.

## Build
```
BLENDER=/path/to/blender tools/blender/pilot/build.sh [work_dir]
```
Stages (each saves a .blend in the work folder, default `assets/blender/pilot_work/`):
| stage | does |
|---|---|
| `stageA.py` | human from macros and face targets, skin, game rig, eyes, brows, lashes, clothing, shoes; bakes targets and masks |
| `stageB.py` | paints the beard, moustache and close-cropped hairline into the skin; writes the beard fur map; recolours the top to white |
| `stageC.py` | beard fur shells, six-panel cap with brim, clear round glasses |
| `stageD.py` | transmitter and the holding pose (two-bone IK, thumbs on the sticks). Pose tweaks without editing: `POSE="wy=-0.09,hx=-0.6,f1=30" blender -b C.blend --python stageD.py` |
| `stageE.py` | bakes the pose into the rest pose, shrinks textures, exports the GLB |

`render.py` makes Cycles previews: `SHOTS="face=0.45,-0.9,1.72,0,-0.1,1.62,85" blender -b E_rest.blend --python render.py` (camera x,y,z, target x,y,z, lens mm; Blender coordinates, the pilot faces -Y).
