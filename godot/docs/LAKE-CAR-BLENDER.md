# The Lake Car: first Blender model in this lane

Status: 2026-11-15. This is the first real delivered model from the vehicle backlog. It is a low-poly hero prop, not the final textured Claude vehicle.

![Lake Car Blender preview](<C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-notify\godot\docs\realism\models\lake_car_preview.png>)

## Files

- Source script: `tools/blender/build_lake_car.py`
- Asset: `assets/story/lake_car.glb` (350 KB, glTF 2.0 binary)
- Preview: `docs/realism/models/lake_car_preview.png`
- In-scene evidence: `docs/realism/models/lake_car_scene.jpg`
- Loader: `game/case_objects.gd`, `_try_lake_car_asset()`; falls back to the old code car when the GLB is missing.

Build command:

```powershell
blender.exe -b --factory-startup --python tools/blender/build_lake_car.py
```

The script builds, exports and renders the preview in one headless run. It uses only Blender primitives and materials, no external asset dependencies.

## What it is

A 1980s five-door estate at the north shore:

- Faded navy body, bleached roof, roof rack, chrome bumpers and grille.
- Separate glass panels, cracked rear screen and one missing hubcap.
- Rust at the arches and wings, algae along the sills, a broken mirror and loose rear trim.
- Right-hand-drive interior: dash, worn front seats, rear bench, steering wheel.
- Separate named wheels `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr`, each with a tyre, rim and hubcap pivot.
- Named `lamp_head_l`, `lamp_head_r`, `lamp_tail_l`, `lamp_tail_r` meshes.
- Fictional plate `HY 84 AV` front and rear, and a small orange evidence tag at the rear.
- Origin on the ground under the centre; the Blender model is authored with front +Y, which exports as glTF local **-Z**, matching the project vehicle contract.

## Integration

The car is placed by `CaseObjects._build_car()` at the existing `case_lake_car` evidence point. The GLB is instantiated and rotated, and the code-box car remains as the fallback. The evidence radius, photo subject, story chapter and thermal state are unchanged.

## Honest limits

- It is low-poly and untextured except for material colours: no PBR albedo/normal/roughness set, no 4K hero texture, no dirt/clean variant, no LOD1/LOD2, no interior detail beyond the simple seats and dash.
- The roof line is boxier than the brief's final hero car; the next pass should extend the rear roof, soften the pillars and add wheel-arch cuts.
- No collision proxy yet; the story car is scenery like the rest of the road props.
- This is one model out of the roughly 450–480 files in the 13 briefs. The traffic fleet, village, wildlife, anti-drone set, boat launch, cabin track, signs, road surface and characters are still missing.
