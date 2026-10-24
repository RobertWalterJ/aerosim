# Boat launch and cabin track: shared Blender assets wired

Status: 2026-11-15. Two more site categories now use the shared Blender asset library.

## Boat launch

`game/boat_launch.gd` now loads:

- `assets/models/sites/boat_aluminium_hull.glb` for the moored boat;
- `assets/models/sites/boat_trailer.glb` for the empty trailer.

The gravel apron, concrete ramp, timber dock, sign and bollards remain code-built for now; the code boat/trailer are the fallback when the GLBs are missing.

## Cabin track

`game/cabin_track.gd` now loads:

- `tree_fall_a` / `tree_fall_b` for the two fallen trees;
- `rockfall_a` for the two rockfalls.

The track surface, ruts, cave apron and cave shell remain code-built. The models are static direct loads; they do not carry collision or animation.

## Honest limits

- The boat and trailer are at the existing scene positions and rotations; the shared models may need a later scale/pivot audit against the ramp and trailer frame.
- The fallen-tree models replace the trunk/branches but not the exact blocking orientation of the code fall; the scene still reads as blocked.
- No boat launch sign, wheel stops, gravel patch, marker or cave arch assets are wired yet; those are available in `assets/models/sites/`.
- No gate was run by Session B while Session A was editing the tablet UI; the final combined gate is the next step.
