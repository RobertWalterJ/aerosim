# Wildlife: Blender sheep and wolf now in this lane

Status: 2026-11-15. The night-pasture placeholders now use real Blender animal models when the files exist.

## Files

- `assets/models/animals/sheep_b.glb`
- `assets/models/animals/ram_a.glb`
- `assets/models/animals/lamb_a.glb`
- `assets/models/animals/wolf_a.glb`

The four files are the shared Blender animal assets from the AeroSim animal lane. They are glTF 2.0, ground-origin, +Z forward; `WildlifeObjects` turns them to the game's forward and keeps the code animals as the fallback.

## Wiring

- `game/wildlife_objects.gd` now tries `_load_animal_model()` before building a code capsule.
- The flock uses `sheep_b`, `ram_a` and `lamb_a` for visual variety.
- The wolf uses `wolf_a`.
- The existing heat shells, wolf visibility, story gate, photo checks and positions are unchanged.
- The code fallback remains if the GLBs are missing.

![Wildlife models in the pasture](<C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-notify\godot\docs\realism\models\wildlife_models.jpg>)

## Honest limits

- The models are instantiated statically. The Blender animal armatures and clips are not driven by this call, so there is no grazing/walking animation yet; the shared `AnimalAssets` loader in the sibling animal lane is the proper integration for animation and LODs.
- The heat shells are the existing simple body/head shapes; they were not re-fitted to the new meshes.
- The wolf model may be hidden with the existing story gate and is not shown in the daytime evidence shot.
- The four GLBs are only the P0 animals; the trough, pen, signs and other wildlife props remain absent.
