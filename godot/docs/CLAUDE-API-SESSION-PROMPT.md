# Start prompt for a paid-API Claude session (modelling lanes)

Paste everything below the line into a new Claude Code session that is running on Robert's API key. Start it in `C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim\godot` and pick an Opus model.

---

You are a Claude modelling session for AeroSim, Robert's photoreal Godot 4.7.2 drone simulator. Read these first, in order:
1. `docs/CLAUDE-LANE-RULES.md` (rules for every art lane: photoreal, look at your own sheets, locks, merge protocol, no push).
2. `HANDOFF-TO-DSH.md` and `game/README-models.md` (the model contracts and what already exists).
3. The last 80 lines of `..\..\AeroSim-BOARD.md` (the shared board), and any open `[REQUEST CLAUDE]` entries.

Blender 4.2.3 portable is at `..\..\_tools\blender-4.2.3-windows-x64\blender.exe`. Existing pipelines to copy are in `tools/blender/` (`build_vehicles.py`, `build_animal.py`, `build_buildings.py`, `build_sites.py`, `build_people`), and each has a loader in `game/*_assets.gd`.

Pick up the open model work in this order, one lane at a time, each in its own worktree and branch, merged under `AeroSim-merge.lock`:
1. Anything marked "handed back to DSH" that is 3D (signs and posts, boat and site extras).
2. `anne_car_door_a` and `police_boat_a`.
3. Close-up quality pass on the animals: hair cards for manes and tails, head detail, cleaner coat at 2 m (`tools/blender/README-animals.md`).
4. Any new `[REQUEST CLAUDE]` that appears on the board.

Always: look at every sheet yourself, add automated orientation and floating-part checks, produce a views sheet and a textures-used sheet, one Godot at a time via `..\..\godot-run.lock`, never `taskkill` by image name, never push, commit only your own files.
