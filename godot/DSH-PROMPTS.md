# Prompts for DSH (copy each into its own DSH session)

Three independent DSH tasks. Each has its own git worktree and branch, so they cannot collide with each other or with the
Claude and Opus lanes. Each task is one long brief with one report at the end. Do not paste them into one session.
Each prompt repeats the shared rules so it is self-contained.

---

## DSH task 1: sky and clouds

```
You are working on AeroSim, a Godot 4.7.2 drone simulator. Work ONLY in this git worktree (branch lane/sky):
C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-sky\godot
Do not touch the folder ...\AeroSim (the main checkout) or any other worktree.

Read, in order: COORDINATION.md (your lane and file ownership), SPEC-SKY-CLOUDS.md (your whole brief, six stages S1 to S6),
LOGIC-NOTES.md, then the files the brief names. Do the stages in order. After every stage run
powershell -ExecutionPolicy Bypass -File tools\gate.ps1 -Tag sky
which must print GATE PASS, then save the evidence images the brief asks for in docs\realism\sky\<stage>\, add your entry to
LOGIC-NOTES.md, and make one local commit on lane/sky (git add specific paths only).
Measure look changes with: python tools\look_metrics.py before.png after.png

Rules: never push, never delete files, only edit your lane's files, one Godot window at a time (always close it, use timeout 250),
no HDR sensor passes for phones, do not change the Simple camera path. Do not stop to ask taste questions: make a reasonable
choice, record it in LOGIC-NOTES.md under "Questions for Claude and the owner", and continue. If a check is red for two rounds,
question the check before the code. Before you claim anything works, name the check or the image that proves it.
Finish with ONE report: stages done, gate result, frame-time numbers, what you could not verify, and the numbered questions.
```

---

## DSH task 2: camera and post-processing

```
You are working on AeroSim, a Godot 4.7.2 drone simulator. Work ONLY in this git worktree (branch lane/camera):
C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-camera\godot
Do not touch the folder ...\AeroSim (the main checkout) or any other worktree.

Read, in order: COORDINATION.md (your lane), SPEC-REALISM-PASS.md sections 0 and 1 (stages 1.1 to 1.5), LOGIC-NOTES.md, then
game/sensor_pipeline.gd and the shaders in game/shaders/ named there (sensor, isp, codec, bloom_pre, bloom_down, bloom_up, meter,
reduce, adapt, blit). Your files: sensor_pipeline.gd and those shaders, plus a few-line insertion in game/hud.gd for each setting
(Camera tab, follow the _choice pattern; re-read the file right before editing) and in game/main.gd only if a value must be passed in.

Do these stages in this order, one local commit each on lane/camera, gate green before the next:
 1. Motion blur (1.5): camera-rotation blur from ang_vel_cam plus forward radial blur from speed, 180-degree shutter model, 8 to
    12 samples, clamp 3% of frame height, zero blur at hover. Setting: Motion blur Off / Natural.
 2. Everyday compression and sensor character (1.3): soft chroma, mosquito noise at edges, shadow banding, stable fixed-pattern
    noise at low ISO, strength rising with rf_bad.
 3. Lens character (1.4): corner softness, dirt layer lit by the sun, longitudinal chromatic fringe.
 4. Bloom and glare (1.1): multi-scale lens-shaped bloom, threshold knee, faint streaks on the brightest points only. A scene with
    no highlight must look the same with bloom on or off (within 2 grey levels).
 5. Colour looks (1.2): Natural (default, unchanged), Flat (DJI D-Cinelike style), Vivid. Parameter sets, no LUT files.
After every stage run powershell -ExecutionPolicy Bypass -File tools\gate.ps1 -Tag camera (must print GATE PASS), save
before/after images in docs\realism\camera\<stage>\ (Full camera mode on desktop only; the phone uses the Simple path, which you
must NOT change), measure with python tools\look_metrics.py a.png b.png, and update LOGIC-NOTES.md. Budget: each stage adds under
1 ms on this PC (report numbers). Existing features that must keep working: CPU auto-exposure (_log_e), sun glare and white
balance, depth of field and autofocus, rolling shutter, lens raindrops (sensor.gdshader droplets).

Rules: never push, never delete files, only edit your lane's files, one Godot window at a time (always close it, timeout 250),
plain words and no em dashes in anything a player reads, no timers. Do not stop to ask taste questions: choose, record under
"Questions for Claude and the owner" in LOGIC-NOTES.md, continue. Name the check or image that proves each claim.
Finish with ONE report: stages done, gate result, numbers, what you could not verify, numbered questions.
```

---

## DSH task 3: water

```
You are working on AeroSim, a Godot 4.7.2 drone simulator. Work ONLY in this git worktree (branch lane/water):
C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-water\godot
Do not touch the folder ...\AeroSim (the main checkout) or any other worktree.

Read: COORDINATION.md (your lane), SPEC-REALISM-PASS.md sections 0 and 2.5, LOGIC-NOTES.md, game/lake.gd (the lake outline comes
from assets/world/lake_mask.png and is correct: do NOT change its shape or the shore logic), game/shaders/water.gdshader, and the
shore painting in game/shaders/ground.gdshader (read only; another agent owns that file).
Task: upgrade the water look only, in game/shaders/water.gdshader and new game/shaders/water_*.gdshader or small helper files:
 1. Sky and tree reflections: desktop Forward+ uses the existing screen-space reflections plus sky; the Mobile renderer and the
    Simple path get a cheap fresnel-weighted sky colour with a sun glint (no per-pixel loops).
 2. Wind-driven waves: two or three scrolling normal layers and one large swell, growing with the g_wind global (0 to 10 m/s),
    calm glassy water in light wind, whitecap hints only in a gale.
 3. Shoreline foam and wet edge: a thin foam line where the water meets the land, using terrain height (the terrain height
    texture is the uHT texture used by game/grass.gd; read how it is passed) against the water level (Lake.LEVEL, 76 m).
 4. Depth tint: shallow water near the shore is lighter and shows the mud and sand bed; deep water is dark teal.
 5. Optional if cheap: a few floating autumn leaves near the shore, drifting with the wind.
Budget: under 0.7 ms extra on this PC, and it must look right with --rendering-method mobile and with the simple token.
Run powershell -ExecutionPolicy Bypass -File tools\gate.ps1 -Tag water after each stage (must print GATE PASS), make one local
commit per stage on lane/water, save before/after images in docs\realism\water\ (the lake from 30 m, 150 m, a glare shot toward
the sun at clock17.5 date3, wind 1 vs 8 m/s), and update LOGIC-NOTES.md. Test positions that show the lake: at-300_90_36_90_-18
and at-700_60_-400_90_-25 (screenshot token format is in SPEC-REALISM-PASS.md section 0).

Rules: never push, never delete files, only edit your lane's files, one Godot window at a time (always close it, timeout 250),
no timers or em dashes in player-facing text. Do not stop to ask taste questions: choose, record, continue. Name the check or
image that proves each claim. Finish with ONE report: what changed, gate result, numbers, what you could not verify, questions.
```
