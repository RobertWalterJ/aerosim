# Traffic fleet: Blender models now in this lane

Status: 2026-11-15. The five Priority 0 traffic vehicles are now real Blender GLBs in `assets/traffic/`. The traffic loader already pointed at these exact paths; it now takes the model branch instead of the code boxes.

![Traffic fleet in the engine](<C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-notify\godot\docs\realism\models\traffic_fleet.jpg>)

## Files

| Traffic id | File | Source |
|---|---|---|
| `hatchback_a` | `assets/traffic/hatchback_a.glb` | Blender vehicle library, `car_hatch_a` |
| `hatchback_b` | `assets/traffic/hatchback_b.glb` | Blender vehicle library, `car_hatch_b` |
| `pickup_a` | `assets/traffic/pickup_a.glb` | Blender vehicle library, `pickup_a` |
| `van_a` | `assets/traffic/van_a.glb` | Blender vehicle library, `van_a` |
| `tractor_a` | `assets/traffic/tractor_a.glb` | Blender vehicle library, `tractor_a` |

The files are glTF 2.0, metre scale, ground-level origin and local -Z forward, which matches `game/traffic.gd`. They are the existing Blender vehicle models from the shared AeroSim vehicle lane; the files were copied into this lane rather than remodelled because the code paths and contract already matched.

## What works

- `traffic.gd` checks the five model paths at startup and instantiates the GLB when present.
- The vehicles render in the valley instead of the old box placeholder.
- The code fallback remains, so a checkout without the GLBs still runs.
- A test row of all five was rendered in the engine: `docs/realism/models/traffic_fleet.jpg`.

## Honest limits

- The current loader only knows plain child nodes named `wheel_*` and material names containing `headlight`. These Blender vehicles use armatures and custom material slots, so their **wheels do not spin and their doors/lights are not driven** by the traffic code yet. The body, glass and colours render.
- The models are full vehicle-library files with armatures, not the final exported traffic variants or LOD policy from the brief.
- The tractor is included; the farm trailer and other variation vehicles are not.
- The traffic line-up screenshot is a debug placement on the cemetery lawn, not a road traffic capture.

## Next integration step

To finish the traffic pass, use the existing `VehicleAssets` loader from the shared vehicle lane: it knows the armature/bone wheel names, LODs, paint slots and light groups, and drives wheel roll, steering, doors and lamps. The current `traffic.gd` model branch would call that loader instead of instantiating the GLB directly. That is a code merge, not another modelling pass.
