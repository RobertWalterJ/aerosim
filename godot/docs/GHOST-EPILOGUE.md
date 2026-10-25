# Ghost epilogue

Status: 2026-11-15. After the end card and fade, the game now enters a short playable ghost drift before returning control to the post-story walk.

## Flow

1. The ending card finishes. `Ending.card_finished` calls `Main._on_ending_free()`.
2. `Main` hides the HUD, the phone, the notes and the ending layer, and starts `GhostFlight`.
3. The screen opens through a black frame into a cold, glitching camera feed. The old camera app/OS feed reads `SIGNAL LOST · RECONNECTING`, then the world is visible through a desaturated, scanlined, RGB-shifted ghost pass.
4. The player flies as a ghost with **WASD**, mouse look, **Space/C** up/down and **Shift** boost. There is no collision, battery or damage. The speed is deliberately fast and the motion drifts before it settles.
5. After **90 seconds** (the debug hook compresses this to six), the camera turns to the cemetery. A warm glow appears over a body asleep on the grass beside a small drone.
6. **Click** anywhere (`Esc` also works) after the glow appears. The ghost camera ends, the player drone is placed at the body, and the normal post-story free walk begins. Clicking the drone then resumes flight as before.

## Visuals

- `game/shaders/ghost_glitch.gdshader`: screen-space ghost feed with scanlines, warped bands, RGB split, vignette, grain and app-fragment glitches.
- The ghost camera renders through its own `SubViewport`, not the main camera, because the main viewport's 3D is disabled by the sensor pipeline.
- The body is a simple sleeping silhouette on a sleeping mat, with a low-poly drone beside it. A warm `OmniLight3D`, an emissive orb and a tall beam make the body readable from the air.
- The cemetery planting is kept clear around the body by `CaseObjects.GHOST_BODY_SPOT`.

## Test hooks

- `ghostdemo` — start the drift with the reveal compressed to six seconds.
- `ghostworld` — ghost camera with the overlay off (camera sanity check).
- `ghostwake` — skip the drift and wake immediately.

## Known limits

- This is an atmospheric interlude, not a full spirit-world simulation: no collisions, no new map, no separate ghost lighting model.
- The body is a low-detail silhouette, not the full Lou character model.
- The sequence is time-based; flying far away does not delay it, but the reveal turns the camera back to the cemetery.
- `GATE PASS (ghostepilogue)`; doc and hooks are included for future edits.
