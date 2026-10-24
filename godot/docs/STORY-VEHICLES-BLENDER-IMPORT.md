# Story vehicles: Blender bus and 1984 cruiser now in this lane

Status: 2026-11-15. The festival bus and the 1984 police cruiser outside the cabin now use the shared Blender vehicle models when their files exist.

## Files

- `assets/models/vehicles/festival_bus_restored.glb`
- `assets/models/vehicles/cruiser_1984_a.glb`
- The abandoned cabin model is copied to `assets/models/story/cabin/cabin_abandoned_a_broken_roof.glb` and is now wired as the cabin shell, with the existing porch/window lights re-added by `_cabin_asset_lights()`.

## Wiring

`CaseObjects` now tries `_try_story_model()` before the code-built bus and cruiser:

- festival bus at the garage; the existing `move_bus_to_festival()` still moves the root to the festival field;
- the cruiser outside the cabin;
- both keep their existing evidence positions, photo subjects and story state;
- if a GLB is missing, the code vehicle is built as before.

The models are glTF 2.0 with ground-level origins. The loading call rotates them to the lane's forward direction; the models' own wheel/armature animations are not driven yet.

## Honest limits

- Direct static loading means the bus and cruiser do not play their doors, wheels or light-bar clips. The shared `VehicleAssets` loader is the proper driver; this pass only gets the geometry into the world.
- The GLBs use their exported materials, not the vehicle lane's per-instance paint and glass shaders. They may need a material remap for the final look.
- The cabin GLB is wired with the existing scripted porch/window lights; its separate lit-window material nodes are not remapped, so the built-in window glow is not yet driven.
- These are two of the many story-brief files. The cabin interior, Wren/Rennick character models, police dive van, Anne's wreck and the rest of the endgame set remain.
