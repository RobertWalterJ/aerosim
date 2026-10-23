# Who edits what (Claude, Opus agents, DSH): so nobody steps on anybody

Written 2026-10-23. Read before starting any stage. Goal: few handoffs, no collisions, low usage.

## Lanes (file ownership)
| Lane | Owner | Files (only this lane edits them) |
|---|---|---|
| **Sky and clouds** | DSH (own task) | `game/shaders/sky.gdshader`, `game/shaders/cloud_shadow.gdshaderinc` (the cloud part only), new `game/sky_*.gd`, `game/weather.gd`, the sky/weather block in `main.gd` (`_apply_weather_state`, `apply_weather`) |
| **Camera and post** | DSH (own task, branch `lane/camera`) | `game/sensor_pipeline.gd`, `game/shaders/{sensor,isp,codec,bloom_*,meter,adapt,blit}.gdshader` |
| **Water** | DSH (own task, branch `lane/water`) | `game/shaders/water.gdshader`, new `game/shaders/water_*.gdshader`; `game/lake.gd` shape and shore logic stay as they are |
| **Trees** | Opus agent T | `tools/export_assets.ts`, `assets/trees/*`, `game/shaders/foliage.gdshader`, tree parts of `game/assets.gd` and `game/world.gd` |
| **Ground, stone, drones** | Opus agent G | `game/shaders/{ground,grass,stone}.gdshader`, `game/grass.gd`, `game/far_hills.gd`, stone parts of `assets.gd`, `game/drone_parts.gd`, `game/drone_view.gd`, `game/hedgerow.gd` |
| **Drone in wind** | Opus agent W | `physics/quad.gd`, `physics/flight_controller.gd`, `game/wind.gd`, `game/drone_audio.gd` (strain only), a small `game/shake.gd`, the camera-shake call in `main.gd` |
| **Menu, HUD, release, merges** | Claude | `game/hud.gd`, `game/menu_style.gd`, `game/main.gd` (everything not named above), `export_presets.cfg`, all releases |

Shared files (`main.gd`, `hud.gd`): add small insertions only, re-read the file immediately before each edit, never reformat.

## Git, so commits never collide
- Each lane works on its **own branch in its own worktree**, so working trees never mix:
  `git -C <repo> worktree add ..\AeroSim-<lane> -b lane/<lane>` (then work inside `<AeroSim-<lane>>\godot`; Godot needs its own import: run `--headless --import` once there).
  Lanes: `lane/sky`, `lane/camera`, `lane/water` (DSH), `lane/trees`, `lane/ground`, `lane/wind` (Opus). Worktrees sit beside the main one as `AeroSim-<lane>`.
- A lane commits only its own files, runs `tools/gate.ps1 -Tag <lane>`, and writes its entry in `LOGIC-NOTES.md`.
- **Merging is Claude's job**, done once per batch, not per commit: `git merge lane/<x>` into `master`, run the gate, fix conflicts (they should be rare given the lanes), push. Lanes then `git merge master` to catch up.
- Merge order: wind, ground, trees, sky (smallest touch first). `LOGIC-NOTES.md` conflicts: keep both sections.
- No lane pushes. No lane deletes files. No lane touches another lane's files; if it needs a change there, write it under "Requests" in `LOGIC-NOTES.md`.

## Keeping handoffs few
- Each lane is **one long brief with a single end report**, not a stage-by-stage conversation. The lane works until its gate is green and writes one summary: what changed, evidence images, open questions.
- Taste questions are collected in the summary, not asked one by one. Claude answers them all in one pass with you.
- Claude's per-batch review is one contact sheet per lane plus the gate result. No code review unless the gate fails.
- Measure, do not guess: `python tools/look_metrics.py before.png after.png`. A stage that should not change the picture must differ by under 2 grey levels from `docs/realism/golden/*.jpg`.
- Phone: nobody changes the Simple (phone) camera path. Release builds are made only by Claude, after a merge, with your go.
