# Changelog

## 2026-10-21 (second batch): pilot, calmer wind, gimbal controls, aerobatics mode

### Added
- Pilot at the launch spot, built in Blender: MakeHuman/MPFB2 base mesh (CC0), mid to late thirties, deep brown skin, short full beard (painted into the skin plus five alpha-tested fur shells), close-cropped hair, dark olive six-panel cap, clear round acetate glasses, white long-sleeve crewneck, jeans, white trainers. He holds a generic grey screen-type transmitter (5.5 in screen, folding flat antennas, knurled sticks, status LEDs; no branding) with his thumbs on the sticks. `public/models/pilot.glb`: 2.1 MB, about 50k triangles, 16 meshes, 53-bone game rig with the holding pose baked into the rest pose. In game his head and neck turn to follow the drone, and he shuffles round when it goes behind him. He stands 3 m behind the launch point (first spot with no tree crown overhead) and has a collider. The earlier procedural figure stays as the far LOD and the fallback (`?pilot=simple` forces it, `?pilot=0` hides him).
- Blender pipeline: `tools/blender/pilot/` (stage scripts and `build.sh`) rebuilds the GLB from scratch; the editable, fully packed scene is `assets/blender/pilot.blend`.
- Wind levels: calm, light (default), breezy, strong. `Z` key, the WIND touch button or `?wind=calm|light|breezy|strong`. The OSD shows the level next to the wind speed.
- Gimbal controls: `T` levels and centres the camera, `Y` looks straight down (both slew smoothly), `,` and `.` (or Shift+wheel, or gamepad LB/RB) pan up to 60 degrees each way, `Q`/`E`/wheel tilt as before. Gamepad Y recentres, D-pad down looks down. Touch: drag the gimbal slider sideways to pan, LVL and DOWN buttons under it. On the FPV freestyle the same tilt input sets the camera uptilt (0 to 55 degrees). The chase-view drone model shows the pan on its gimbal.
- Aerobatics mode (`4`, or MODE on touch): self-levelling near centre stick with full acro rates at full deflection, altitude-assisted throttle, and one-button tricks: `J` flip, `K` roll, `N` power loop, `M` pirouette (Shift+arrows flip or roll in that direction; gamepad A/B/X; FLIP/ROLL/LOOP/SPIN touch buttons). Tricks need 4 m of height (1.5 m for the pirouette). The OSD shows AEROBATIC and the trick count.
- Tests: `tests/aero.test.ts` (`npm run test:aero`, part of `npm test`) flies every trick on both airframes with the real physics; the asset test now checks the pilot (procedural LODs and the GLB: size, triangles, bones, screen material).
- Docs: `docs/assets/pilot.md`, `docs/flight-and-camera.md`, `tools/blender/pilot/README.md`.

### Files created
- `src/world/PilotFigure.ts`, `src/game/Aerobatics.ts`, `public/models/pilot.glb`, `assets/blender/pilot.blend`
- `tools/blender/pilot/common.py`, `stageA.py` to `stageE.py`, `render.py`, `build.sh`, `README.md`
- `tests/aero.test.ts`, `tests/envperf.ts`, `docs/assets/pilot.md`, `docs/flight-and-camera.md`
- `docs/assets/screenshots/pilot_blender_full.png`, `pilot_blender_face.png`, `after_pilot.png`, `after_carpark.png`, `before_/after_memorial_section.png`

### Files changed
- `src/main.ts`: pilot (placement, GLB load, LOD, head tracking, collider), wind levels, aerobatics wiring (stick shaping before `fc.update`, trick start), gimbal pan in the camera orientation, FPV uptilt, `?teleport=pilot`, the teleport gimbal value now survives (the hoisted `var` no longer overwrites it).
- `src/core/InputManagerHID.ts`: keys and gamepad buttons for aerobatics, tricks, wind and gimbal presets; gimbal pan; smooth preset slewing.
- `src/ui/TouchControls.ts`: WIND button, gimbal LVL/DOWN buttons, sideways drag to pan, trick buttons shown in aerobatics mode.
- `src/ui/TelemetryOSD.ts`: mode `A` (AEROBATIC), wind level and trick line.
- `src/world/drones/DroneView.ts`: gimbal yaw limit 60 degrees to match the pan range.
- `index.html`: help card lists the new keys.
- `tests/assets.extra.ts`, `tests/gallery.ts` (`#pilot`), `package.json` (`test:aero`).

### Touched shared files
- `src/physics/WindFieldVolume.ts` (needed for the wind fix): overlapping tree wakes now share one weight budget instead of adding up, and the wake eddy amplitude is `1.0 u` instead of `1.6 u`. Near groups of trees the old code could produce gusts several times the free-stream speed, which is what made the wind feel far too strong. 4 lines.

### Performance (upper bounds, before frustum culling; `npx tsx tests/envperf.ts`)
| preset | env build | draw calls (home / memorial / chapel) | triangles (home / memorial / chapel) |
|---|---|---|---|
| low | 4.5 s (first run, includes texture generation) | 33 / 43 / 29 | 182k / 90k / 117k |
| medium | 1.9 s | 57 / 75 / 66 | 251k / 140k / 249k |
| high | 2.9 s | 83 / 97 / 102 | 321k / 248k / 474k |
| ultra | 2.1 s | 101 / 115 / 124 | 480k / 646k / 943k |

The pilot adds 16 draw calls and about 50k triangles within 60 m (30 m on low), 6 calls and 6.3k triangles beyond (5 calls and 1.5k on low). The chase drone adds 10 to 15 calls when the chase view is on. The GLB is a 2.1 MB download, cached by the service worker after the first load.

### Known issues
- The pilot is a close, realistic match to the reference photo, not a scanned likeness. The beard is shell fur, so it reads best from about 1 m away and beyond.
- Glasses use alpha blending, not true transmission, to avoid an extra render pass.
- The transmitter screen shows a static live-view image; it does not show the real camera feed yet.
- Hands are posed for the controller; fingers are partly hidden behind it by design, so they are only roughly placed.
- Aerobatics mode uses the M controller with raised rates (the MINI is a camera drone, its stock rates cannot flip). Tricks on the MINI lose a few metres; the loop needs about 10 m of height.

### What to tune next
- Pilot: render the drone camera into a small texture a few times a second and show it on `rc_screen`.
- Wind level values (`WIND_LEVELS` in `main.ts`) and the wake strength in `WindFieldVolume.ts` after a few test flights.
- Trick timing (`AERO` in `src/game/Aerobatics.ts`): punch length, spin throttle, recovery boost.

## 2026-10-21: procedural environment assets, new drone models, 1980s vehicles

### Added
- Environment asset families, all generated in code with deterministic seeds and LOD0/1/2 under 6000/1200/200 triangles:
  - meadow grasses and wildflowers (10 variants)
  - lawn colour model, lawn texture set and blade tufts
  - boxwood and yew hedges, lilac, forsythia, boxwood balls and yew mounds
  - wrought-iron railings and gates, fieldstone walls
  - ground clutter: leaf drifts, nuts, twigs, fallen branches, moss, soil
  - memorial details: eight headstone kinds, willow markers, urns, crosses, angels, kerbed plots, bouquets, flags
  - dead trees, snags, hollow stumps, rock outcrops
- 1980s UK and Canadian cars: 10 original body styles, period paint, sun fading, road-salt rust, fictional UK and Ontario-style plates.
- `EnvironmentInstancer`: places all of the above on the valley terrain (meadow on open land, hedges on the spur walks and round the chapel, shrubs on the loop verges, a stone boundary wall at r = 238 m with railings and gates at the avenues, clutter under trees and at monuments, a Victorian memorial section on a clear lawn block, snags and rocks on the valley walls, parked cars at the chapel and on the avenue verges). LOD re-bucketing runs at about 2 Hz. Density, LOD distances, variant count and shadow casting scale with the quality preset. `?env=0` turns it off.
- Drone models: MINI (249 g folding camera quad, fictional brand "AeroLite", 3-axis gimbal with individually accessible pivots) and FREESTYLE (5-inch true-X, 4S, accent sets hot pink, lime and orange). Both have voxel-baked AO, canvas carbon, brushed, knurl and PCB textures, airfoil props with blur discs, and driveable LEDs.
- `DroneView`: the chase-camera model is driven by `quad.motorOmega`, the gimbal angles, `quad.armed` and `quad.battery.soc`. It replaces `DroneModel` by default; `?drone=legacy` restores the old model. `?chase=1` starts in the chase view.
- Tests: `tests/assets.test.ts` (`npm run test:assets`) builds every asset at every LOD, logs triangle counts, and checks budgets, attributes, determinism, albedo range, drone draw calls, bounding boxes and spec dimensions, and vehicle sizes. `npm test` runs physics and asset tests.
- Dev tools: `tests/gallery.html` (`/tests/gallery.html#drones`, `#vehicles`, `#env`) with `tests/gshot.mjs` for close-up screenshots; `tests/perf.mjs` for draw calls and triangles per quality preset.
- Docs: `docs/assets/` (conventions, one page per family, drones with the materials table and physics notes) and before/after screenshots in `docs/assets/screenshots/`.

### Files created
- `src/world/MeadowGrass.ts`, `LawnGrass.ts`, `HedgesShrubs.ts`, `FencesWalls.ts`, `GroundClutter.ts`, `MemorialDetails.ts`, `SnagsRocks.ts`, `Vehicles.ts`, `EnvironmentAssets.ts`, `EnvironmentInstancer.ts`
- `src/world/assetkit/AssetCore.ts`, `AssetRng.ts`, `AssetScatter.ts`, `AssetMaterials.ts`, `StoneWeathering.ts`
- `src/world/textures/AssetTextures.ts`
- `src/world/drones/MiniDrone.ts`, `FreestyleDrone.ts`, `parts.ts`, `textures.ts`, `materials.ts`, `canvas.ts`, `DroneView.ts`
- `tests/assets.test.ts`, `tests/assets.extra.ts`, `tests/gallery.html`, `tests/gallery.ts`, `tests/gshot.mjs`, `tests/perf.mjs`
- `docs/assets/*.md`, `docs/assets/screenshots/*.png`, `CHANGELOG.md`

### Files changed
- `src/main.ts`: creates `EnvironmentInstancer` (before shader wiring, so CSM applies) and updates it each frame; `DroneView` with the `?drone=legacy` fallback; `?chase=1`; prewarms the drone model 2.5 s after boot; exposes `envAssets` on `window.__aerosim`.
- `src/config.ts`: `QualityPreset.env` (density, lodScale, variants, shadows, droneLod) for each preset.
- `src/world/ProceduralTextures.ts`: `lattice`, `mkCanvas`, `normalFromHeight` and `tex` are now exported, so the new modules reuse them. No behaviour change.
- `tests/shot.mjs`: optional third argument for the wait time; longer navigation and screenshot timeouts (software GL renders slowly).
- `package.json`: `test:assets` and `test` scripts; dev dependency `@napi-rs/canvas` (canvas for Node tests only).

### Touched shared files
- None under `src/physics/`, `src/rendering/` or `src/audio/`.

### Known issues
- MINI geometry follows the brief (3-inch props, 290 x 370 mm footprint) but `config.ts` MINI uses `armD` 67.5 mm and `R` 58.5 mm, so the visual rotors do not sit where the simulated thrust acts. See `docs/assets/drones.md`, "Notes for the physics side".
- `Quadcopter6DOF.spin` makes the front-right rotor clockwise, the opposite of the brief. The simulator view follows the physics.
- Building a drone model takes several seconds the first time (canvas textures plus the AO bake). It is prewarmed after boot, so the first `C` press can still hitch if pressed within the first few seconds.
- The drone model is built after the CSM shader wiring, so it casts shadows but does not receive cascaded shadows.
- The lawn textures and tufts are not yet used by the terrain (the existing GPU grass and ground shader cover the lawns).
- The `teleport` URL parameter's gimbal value was overwritten in `main.ts`. Fixed in the second batch.

### What to tune next
- Decide the MINI arm and prop size, then align `config.ts` (`armD`, `R`, inertia) and the model.
- Meadow density and patch size against the GPU grass (meadow block in `EnvironmentInstancer`).
- Stone albedo under the project's exposure (`stoneMaterial` colour boost) and car paint fading.
- Feed the lawn macro texture into the terrain ground shader.
- Move the drone texture and AO generation into a worker to remove the first-build hitch.
