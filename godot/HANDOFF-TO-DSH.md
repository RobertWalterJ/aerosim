# Handoff to DSH: where things stand, and how to work without Claude

Written 2026-10-23, because the owner (Robert) is near his Claude usage limit and wants the rest of this project run by DSH
through its own paid API credits. Claude is available only for short, rare reviews. Read this file first, then
`COORDINATION.md`, then `LOGIC-NOTES.md`, then the spec for your task.

## What this project is
AeroSim: a Godot 4.7.2 drone simulator (GDScript, shaders) with a realistic camera pipeline (sensor, exposure, bloom, depth of
field, rolling shutter, video-link breakup), five drones, weather, real sun and moon, a cemetery park valley with a lake, and a
phone-style HUD. Desktop first; also an Android build for his Samsung S23. Repo `RobertWalterJ/aerosim`, Godot project in `godot/`.
Godot binary: `RWJ Coding Projects\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`.

## What is done (on `main`)
Physics, camera pipeline, weather, sun and moon clock, night flight, depth of field and autofocus, lens raindrops (wind-blown),
drifting leaves and dust, continuous hedgerows, stone and brick textures, DJI-style icons, menu, drone models and chooser
schematics, drone shadow, lake and far hills with forest, ground detail and new graves, drone struggles in wind, phone-safe
plain camera mode (phones start in it), release tooling (`tools/release.ps1`), gate (`tools/gate.ps1`), look metrics.

## What is in flight (branches and worktrees beside `...\AeroSim`)
| Branch / worktree | Owner | State |
|---|---|---|
| `lane/trees` (`AeroSim-trees`) | an Opus agent | running; Claude merges it when it reports, or the integrator (below) merges it when the branch has a commit and the gate passes |
| `lane/models` (`AeroSim-models`) | an Opus agent | building `game/new_models.gd` (plane, birds, balloon, deer, barge). Merge into `main` when committed and the gate passes. Every new-experience task needs it |
| `lane/sky` (`AeroSim-sky`) | DSH task 1 | not started |
| `lane/camera` (`AeroSim-camera`) | DSH task 2 | not started |
| `lane/water` (`AeroSim-water`) | DSH task 3 | not started |
| `lane/fireworks`, `lane/birds`, `lane/plane` | DSH tasks 4 to 6 | create the worktree when you start |

## The rules that matter most (learned the hard way)
1. **Never enable the HDR sensor passes for phones.** On the S23 they white out the picture and black out foliage. Phones start in
   `SensorPipeline.simple`. Do not change the Simple path.
2. **Do not model.** All new models come from `game/new_models.gd`. If one is wrong, add a line under "Requests for Claude" in
   `LOGIC-NOTES.md` and carry on.
3. **One Godot window at a time, always close it.** Use `timeout 250`. Never leave one running. `tools/gate.ps1` already does this.
4. **A claim needs proof.** Name the check or the image that proves it. The earlier DSH log shows guards that did not guard; check the
   check.
5. **Taste is the owner's.** You cannot judge a look. Produce before/after images, measure with `python tools\look_metrics.py a.png b.png`,
   make a reasonable choice, record the question in `LOGIC-NOTES.md` under "Questions for Claude and the owner", and continue.
6. **No em dashes, no timers or countdowns** in anything a player reads (the owner is dyslexic). Plain words, short sentences.
7. **Files may be CRLF.** Preserve line endings. In GDScript avoid `:=` on untyped (Variant) values. After adding a `class_name`
   file run `Godot... --headless --path . --import` once.
8. **Every effect has a switch** in the pause menu (follow `_choice` in `game/hud.gd`; styling is `game/menu_style.gd`) and a
   frame-time budget (see `SPEC-REALISM-PASS.md` section 0).

## How merging works without Claude (the "integrator" job)
Each lane commits only to its own branch. The integrator (a DSH session, run whenever lanes have finished stages) does this, from
the main checkout `C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim`:
```
git status --short godot            (must be clean)
git merge lane/<x>                  (one lane at a time; order: models, wind-done, ground-done, trees, camera, water, sky, fireworks, birds, plane)
powershell -ExecutionPolicy Bypass -File godot\tools\gate.ps1 -Tag merge-<x>      (must print GATE PASS)
```
If the merge conflicts: the lanes own disjoint files so conflicts are rare and usually in `main.gd`, `hud.gd` or `LOGIC-NOTES.md`.
Keep both sides of every conflict (they are insertions), fix, re-run the gate. If the gate fails after a merge: `git merge --abort`
(or `git reset --hard HEAD~1` only if the merge already committed and you have not pushed), write what failed in `LOGIC-NOTES.md`,
and stop; do not push. After a green gate: `git push`. Then bring the other lanes up to date: `git -C ..\AeroSim-<lane> merge main`.

## Releasing a phone build without Claude
The owner or DSH runs, from the `godot` folder (it refuses to run unless the gate passes, the branch is `main`, and nothing is
uncommitted):
```
powershell -ExecutionPolicy Bypass -File tools\release.ps1 -Version 0.8 -Notes "plain words about what changed"
```
It builds the APK, bumps the version, commits, tags, pushes and publishes the GitHub release. The owner installs it on the phone from
`https://github.com/RobertWalterJ/aerosim/releases`. Known phone issue: black or white-out trees in the full camera; the phone
default is the plain mode. Test phone-specific things with `--rendering-method mobile` and the `simple` token.

## Prompts
`DSH-PROMPTS.md` has copy-ready prompts: tasks 1 to 3 (sky, camera, water), tasks 4 to 6 (fireworks, birds, FPV plane), and the
integrator task. Run at most three DSH sessions at once (one GPU, one Godot window each).

## When Claude is needed (keep it rare)
Only for: a taste review of a contact sheet when the owner asks; a bug DSH cannot find in two rounds; the final decision on a phone
problem. Put the request in `LOGIC-NOTES.md` under "Requests for Claude" with the evidence image paths, and the owner will pass it on.
