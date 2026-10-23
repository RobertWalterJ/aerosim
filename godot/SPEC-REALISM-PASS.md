# AeroSim (Godot) realism pass: full specification

Written 2026-10-23 for the owner (Robert) and for any agent that picks up a stage (Claude, or DSH, the DeepSeek Harness).
Goal: push the picture from "good game" toward "believable drone footage". Fifteen items in five groups, each with what to build,
where it lives, how to prove it works, and what it must not break.

Project: `RWJ Coding Projects\AeroSim\godot` (Godot 4.7.2, GDScript). Godot: `RWJ Coding Projects\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`.
Phone: Android export, Mobile renderer, S23. Release steps are at the end.

---

## 0. Rules that apply to every stage (read first)

1. **Phone first.** The phone shows a white-out and black foliage whenever the HDR sensor passes run. Since v0.7 the phone starts in
   *Simple* camera mode (`SensorPipeline.simple`), which skips every sensor pass. Every stage below belongs to the **Full** camera
   path (desktop default) unless it says "both". Rendering items (6 to 15) belong to both and must be tested with
   `--rendering-method mobile`. No stage may change what Simple mode shows without a screenshot in Simple mode.
2. **Every effect has a switch.** Add a setting in the pause menu (Display > Graphics or Camera tab; follow `_choice` in `game/hud.gd`, styling in
   `game/menu_style.gd`), default On on desktop, and a sensible default on touch devices (`DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")`).
3. **Cost budget.** Desktop (RTX 4070 laptop): no stage may drop below 60 fps at 1280x720 in the test scene. Phone: no stage adds more than 1 ms per frame in Simple mode.
   Report the measured frame time before and after (`Engine.get_frames_per_second()` averaged over 300 frames in the test shot, or the in-game `fps sensor` readout).
4. **Do not break flight.** After every stage run `-- apstest` and require `after takeoff agl` and `rth finished ... crashed=false`, and no `SCRIPT ERROR`.
5. **Do not break loading.** The game must start with no script errors and show the loading page, then the flight screen.
6. **Taste is the owner's.** An agent that cannot judge a look must produce the A/B screenshots listed under "Evidence" and stop. Do not tune colours by guess.
7. **One stage at a time, a commit per stage.** Commit only `godot/` paths (`git add godot`), end the message with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` when Claude commits, never push without the owner's go (a normal `git push` of the stage is fine once the gate below is green; releases need a go).
8. **Text rules** for anything the player reads: plain words, sentences of at most 20 words, no em dashes, no timers or countdowns (the owner is dyslexic).
9. **Shell tips.** Bash heredocs mangle backslashes and apostrophes: write files with the Write/Edit tools. Files may be CRLF: preserve line endings. In GDScript avoid `:=` on untyped (Variant) values. After adding a `class_name` file run `Godot... --headless --path <godot> --import` once.
10. **Test commands** (all in the `godot` folder):
    - Screenshot: `Godot_v4.7.2-stable_win64_console.exe --path . -- "shot=C:/Users/ROBERT~1/AppData/Local/Temp/shots/<name>.png,300,<fpv|chase>,clock16.0,at-18_<height>_36_<yaw>_<gimbal>"`
      Tokens: `drone<id>` (mini, freestyle, race, cinewhoop, cinema), `armed`, `lens<standard|wide>`, `cd<m>` (chase distance), `sky<0..6>` (clear, partly, overcast, fog, rain, storm, snow), `clock<hour>`, `date<1..4>`, `facesun`, `simple`, `dof0|1|2`, `noamb`, `keep3d`. Yaw is unusual: try 90 and 190.
    - Mobile renderer: add `--rendering-method mobile` before the `--`. Compatibility renderer: `--rendering-method gl_compatibility`.
    - Flight test: `... --path . -- apstest`.
    - Always `timeout 250`, one Godot window at a time, confirm none is left (`tasklist | grep -i godot`).
    - Read PNGs with the Read tool; crop and zoom with Python PIL.

**Gate for every stage ("green"):** loads clean; `apstest` passes; screenshots in Full mode (desktop), Simple mode (`simple` token) and Mobile renderer all render sensibly; frame time within budget; setting works; evidence images saved; `LOGIC-NOTES.md` updated (section at the end).

---

## 1. Camera and post-processing (Full camera path, `game/sensor_pipeline.gd` and `game/shaders/`)

How the pipeline works today: the 3D camera renders to an HDR overscan viewport (`scene_vp`). Passes: meter, reduce (metering, read back on the CPU in `_readback`,
exposure state `_log_e` in `process_frame`), bloom chain (`bloom_pre`, `bloom_down`, `bloom_up`), `sensor` (rolling shutter, distortion, flare, noise, white balance), `isp` (S-curve, saturation, sharpen), `codec` (blocks when the link is poor), `blit`.
Depth of field is Godot's `CameraAttributesPractical` on the scene camera (`_setup_dof`).

### 1.1 Real lens bloom and glare (item 1)
- **Build:** replace the plain blur bloom with a physically shaped one: a bright narrow core plus a wide soft halo (energy-conserving, e.g. a 6 to 7 level pyramid with weights that fall off like a lens point-spread function), with a threshold knee so only highlights above the scene's exposed white bloom, and glare streaks only on the brightest points (a few faint diagonal streaks, not star filters).
- **Where:** `bloom_pre.gdshader`, `bloom_down.gdshader`, `bloom_up.gdshader`, the bloom block in `_build`. Keep the bloom amount tied to exposure (`uExpV`) so bloom is correct after the auto-exposure changes.
- **Setting:** Camera tab "Bloom" already exists (On/Off); add strength Low/Natural/High.
- **Evidence:** A/B screenshots at golden hour looking toward and away from the sun; wet leaves; white gravestones in rain. Measure that mean image brightness changes by less than 3% between old and new bloom for a scene with no highlights (bloom must not fog the picture).
- **Do not:** reintroduce the white-out. A scene with no highlight above 1.0 must look the same with bloom On or Off within 2 grey levels.

### 1.2 Colour grading and looks (item 2)
- **Build:** a grading stage in `isp.gdshader` (or a new `grade.gdshader` between `sensor` and `isp`) with: highlight roll-off (soft shoulder), lifted shadow toe, saturation by luminance, a warm/cool bias, and a 3-look selector: **Natural** (current), **D-Cinelike** (flat: lower contrast, lower saturation, lifted blacks, wide highlight range, like DJI's flat profile), **Vivid** (more contrast and saturation). Looks are parameter sets, no LUT files.
- **Setting:** Camera tab "Colour look": Natural / Flat (D-Cinelike) / Vivid.
- **Evidence:** the same shot in all three looks, plus histograms (the in-game `LUMA` panel) showing Flat compresses the range into roughly 10 to 90%.
- **Do not:** change the default look.

### 1.3 Everyday compression and sensor character (item 3)
- **Build:** subtle H.264 look always on when "Video link effects" is On: soft chroma subsampling (chroma blurred 2x relative to luma), mosquito noise around hard edges (small ringing, amplitude about 1 to 2 grey levels), banding in dark smooth gradients (quantise shadows slightly), plus fixed-pattern sensor noise that is temporally stable per pixel at low ISO. Strength rises with the existing `rf_bad` link badness (`codec.gdshader` already blocks up).
- **Where:** `codec.gdshader`, `sensor.gdshader` noise block.
- **Evidence:** a crop at 4x zoom of tree edges against sky, link good vs poor.

### 1.4 Lens character (item 4)
- **Build:** corner softness (blur radius rising with distance from centre, 0 to about 1.2 px at the corners), a faint dirt/smudge layer (procedural noise texture) that only lights up when the sun or a very bright point is in or near the frame (reuse the flare `uSunS`), mild lateral and longitudinal chromatic aberration scaled by lens (already `uCA`; add longitudinal fringe on high-contrast edges).
- **Where:** `sensor.gdshader`.
- **Evidence:** wide-lens shot of a treeline; sun-in-frame shot showing dirt bloom.

### 1.5 Motion blur (item 5)
- **Build:** per-pixel motion blur from camera motion (translation and rotation) with a 180 degree shutter model: blur length = frame time x shutter fraction. Use the true shutter shown on screen (`shutter_shown`: 1/50 s in low light, shorter in sun). Implementation: a velocity reconstruction from the depth buffer plus the camera's previous transform is not available in the canvas pass, so use **camera-rotation blur** (screen-space directional blur from the camera's angular velocity, already computed as `ang_vel_cam` in `process_frame`) plus **forward-motion radial blur** from drone speed (radial from the focus of expansion, strength rises with speed and nearness; the ground blurs more than the horizon). Sample count 8 to 12, clamp blur length to 3% of frame height.
- **Rotor blur:** the props already use `prop_blur.gdshader`; leave it alone.
- **Setting:** Camera tab "Motion blur": Off / Natural.
- **Evidence:** a fast yaw (set via a test token if needed) and a fast forward pass, A/B; at hover the picture must be identical with blur On or Off (zero velocity gives zero blur).
- **Do not:** blur the HUD (it is drawn after).

### 1.6 Items already done that must keep working
Auto-exposure (CPU side), sun glare and white balance, depth of field and autofocus, rolling shutter. Each stage must re-run one shot proving they still work.

---

## 2. Rendering (both camera modes)

### 2.1 Contact-hardening shadows (item 6)
- **Build:** the sun already has `light_angular_distance = 0.5`. Add PCSS-style softness: sun `shadow_blur`, split settings (`directional_shadow_*`), and bias tuning so shadows are sharp at the caster and soften with distance; verify no shadow acne on grass and no peter-panning under trees. On Mobile, keep 2 splits and a shorter `directional_shadow_max_distance`.
- **Where:** `game/main.gd` `_build_world` sun block; per-platform branch.
- **Evidence:** shadow of a tree trunk close and far; the drone's own shadow (`drone_shadow.gd`) still reads.

### 2.2 Cheap global illumination (item 7)
- **Why:** SDFGI blackened the leaf cards (they are two-sided cards with baked AO in vertex colour). Do not enable SDFGI again without fixing that.
- **Build, in this order, stop at the first one that works and is safe on the phone:**
  (a) **Ambient from the sky plus a ground bounce:** a second, downward-pointing weak light (or hemispheric ambient) coloured from the ground (green-brown) so tree undersides pick up warm green light. Tint by cover (`terrain.cover_at`) and by season.
  (b) **VoxelGI/LightmapGI probe volume** for the cemetery area only (baked offline, static geometry), if (a) is not enough. Keep the bake in `assets/world/` and under 8 MB.
  (c) **SDFGI** only if the leaf-card blackout is solved (set `leaf` materials' `ALBEDO` and use `cull_disabled` with proper normals; test).
- **Evidence:** the underside of a canopy seen from below; a gravestone in shadow beside a bright lawn (should pick up a little green).

### 2.3 Volumetric light (item 8)
- **Build:** Godot volumetric fog (`env.volumetric_fog_enabled`) on desktop at low density with sun scattering, giving visible light shafts through the canopy and a glowing haze toward the sun. Density driven by weather (`wx.cur` fog and haze), time of day (strongest at low sun), and moisture. Mobile: use the existing height fog only (volumetric fog is Forward+ only; `RenderingServer.get_current_rendering_method() == "forward_plus"` guard, as in `_build_world`).
- **Evidence:** golden hour looking along the tree line; overcast (almost no shafts); fog weather.
- **Do not:** hurt frame time by more than 2 ms on desktop; `volumetric_fog_detail_spread` and `length` tuned.

### 2.4 Volumetric clouds and sky (item 9)
- **Build:** upgrade `game/shaders/sky.gdshader`: replace the flat 2D noise deck with raymarched cloud layers (6 to 8 steps for cumulus, 1 for cirrus), lit with a simple Beer-Powder and a silver-lining term toward the sun, shaded undersides, and horizon fade. Keep the weather uniforms (`cover`, `dark`, `cirrus`, `haze`, `fog`, `drift`, `flash`, `moon_dir`, `moon_illum`). Cloud **shadows on the ground** already exist (`cloud_shadow.gdshaderinc`): make their pattern match the sky's clouds (use the same noise function and drift so the shadows line up with what is overhead).
- **Cost:** the sky renders once per frame at screen resolution; keep under 1.5 ms desktop. Provide `sky.gdshader` quality levels via a `#define`-like uniform (`steps`), low on touch.
- **Evidence:** clear, partly cloudy, overcast, storm and sunset skies; before/after pairs; a shot where a cloud shadow on the ground lines up with its cloud.

### 2.5 Water (item 10)
- **Build:** upgrade `game/shaders/water.gdshader` (lake in `game/lake.gd`): sky and tree reflections (Forward+: SSR is already on; Mobile: a cheap fresnel-weighted sky colour with a sun glint), shoreline foam (depth-based using the terrain height texture and the lake `LEVEL`), wind-driven waves that grow with `g_wind` (two or three scrolling normal layers, one large swell), and darkening with depth. Add subtle floating leaves near the shore if cheap.
- **Evidence:** the lake from 30 m, from 150 m, low-angle glare toward the sun, and in wind 1 vs 8 m/s.

---

## 3. Assets and modelling

### 3.1 Trees (item 11), the biggest remaining gap
- **Build:** better leaf clusters and trunks. Current trees are exported GLBs (`assets/trees/*.glb`, made by `tools/export_assets.ts` from the web version) with leaf cards and baked AO in vertex colour, swapped to `foliage.gdshader`. Improve in this order: (a) **bark**: real PBR bark texture (CC0 Poly Haven sets, 1k) with normal map on trunks, wet response; (b) **leaf cards**: more cards per cluster with random rotation and 3 to 4 leaf atlas variants, alpha-to-coverage (`ALPHA_ANTIALIASING_MODE`) on desktop and alpha scissor on mobile, subsurface translucency kept; (c) **silhouette variety**: 3 new maple and oak variants plus per-tree random scale and lean in `world.gd` (the per-tree colour variety shader already exists); (d) **lower LODs** that keep the canopy volume (impostor billboards for far trees: check `trees/far_*`).
- **Where:** `tools/export_assets.ts`, `game/assets.gd`, `game/shaders/foliage.gdshader`, `game/world.gd`.
- **Texture rules:** CC0 or our own work only; record source URL, author, licence, and scale in `assets/textures/README.md`; add any new set to `RWJ-Shared-Assets` under its house rules (copy, update `catalogue.json` and README, never delete).
- **Budget:** near trees under 6,000 triangles each at LOD0; whole new set under 12 MB compressed.
- **Evidence:** close view of a canopy from 8 m (before/after), a trunk at 2 m, a far tree line.

### 3.2 Distant trees and hills (item 12)
- **Build:** `game/far_hills.gd` currently makes a bare ring of coloured hills. Add forest to the far hills using a few thousand instanced tree billboards or a noise-driven forest texture on the hill mesh (dark conifer and warm broadleaf mix), in layered bands that get paler and bluer with distance (aerial perspective is already done via vertex colour; add fog interaction). Make the ridge silhouette more varied.
- **Evidence:** the view from 150 m toward the lake and hills, in clear weather and in haze.

### 3.3 Grass and ground (item 13)
- **Build:** more variety in `game/shaders/ground.gdshader` and `grass.gdshader`: clover and moss patches, bare patchy dirt, worn paths along desire lines, wet-ground darkening and puddles (exists), grass darker in shade (use the world shadow term), and individual blades readable up close (normal-map detail on blades, 2 more colour tints). Add cobble/gravel path edges using the stone/cobble CC0 set (this was not done in the stone pass).
- **Evidence:** a 1.5 m low pass over lawn, meadow and path edge.

### 3.4 Gravestones and buildings (item 14)
- **Build:** weathering by shader (lichen, rain streaks running down faces, dirt at the base, chipped edges via a noise mask on albedo and normal) on the stone families already textured (`game/shaders/stone.gdshader`); 4 to 6 more gravestone shapes (crosses, angels, rounded tops, slab with a kerb) added to `tools/export_world.ts` families or generated in `game/world.gd` from simple meshes; chapel details (windows, door, steps, roof ridge cap).
- **Evidence:** a row of headstones at 3 m; the chapel from 20 m.

### 3.5 Drone models (item 15)
- **Build:** small detail on the five airframes (`game/drone_parts.gd`, `game/drone_view.gd`): screw heads, cable runs, labels as tiny quad decals (plain text or simple logo-free marks, no real brand marks), light scratches via a normal/roughness noise, battery strap, antenna details. Keep one mesh per material (draw calls).
- **Evidence:** close-ups from 0.5 m for all five drones (`cd0.5`).
- The drone chooser schematics (`game/drone_schematic.gd`) must still draw (they read the model's recorded outlines).

---

## 4. Suggested order and who does what

| Order | Stage | Items | Who | Why |
|---|---|---|---|---|
| 1 | Motion blur | 1.5 | DSH | Mechanical, measurable (zero blur at hover) |
| 2 | Bloom and glare, grading looks | 1.1, 1.2 | DSH builds, **Claude/Robert judge the look** | Needs A/B pictures |
| 3 | Everyday compression, lens character | 1.3, 1.4 | DSH | Parametric |
| 4 | Contact shadows, cheap GI | 2.1, 2.2 | Claude (or DSH with Claude review) | Must not regress the leaf cards |
| 5 | Volumetric light, sky clouds | 2.3, 2.4 | Claude | Taste-heavy, easy to wreck the phone |
| 6 | Water | 2.5 | DSH | Self-contained shader |
| 7 | Trees (bark, leaves, variants) | 3.1 | Claude with Opus agent | The largest visible gain |
| 8 | Far hills forest, grass and ground | 3.2, 3.3 | DSH | Mechanical, check by screenshot |
| 9 | Gravestones, buildings, drone detail | 3.4, 3.5 | DSH, Claude reviews | |

After every two stages: build a phone release (steps below) and ask the owner for phone feedback before continuing.

---

## 5. Evidence each stage must leave

Folder: `AeroSim/godot/docs/realism/<stage>/` (create it) with: before and after PNGs for Full camera mode on desktop, one in Simple mode, one with `--rendering-method mobile`; a one-line frame-time before/after; the exact commands used. Commit them (small JPEGs, under 400 KB each).

## 6. Check script (write once, run every stage)

Create `tools/gate.ps1` (or `.bat`) that runs, in order, with timeouts and cleanup: import; start-up with a 120-frame shot and fail on `SCRIPT ERROR`; `apstest`; three standard shots (`fpv` golden hour, `chase` close-up of the freestyle, `fpv` toward the lake) in Full, Simple and Mobile; prints frame times; closes any Godot started. One command, one yes or no.

## 7. Phone release steps (Claude does these, with the owner's go)

1. Bump `version/code` and `version/name` in `export_presets.cfg`.
2. `Godot... --headless --path godot --export-debug "Android" godot/build/aerosim-debug.apk`
3. `git add godot`, commit, `git push`; `git tag -f android-vX.Y`; `git push origin android-vX.Y`.
4. `gh release create android-vX.Y godot/build/aerosim-debug.apk#AeroSim-android-debug.apk --repo RobertWalterJ/aerosim ...`
5. The owner installs from the release link on the S23. Known phone issue: HDR sensor passes white out the picture and black out foliage, which is why the phone starts in Simple mode. Do not turn the sensor passes on for the phone default until a phone log says why (needs the phone plugged in with USB debugging).

## 8. Open items from earlier work (not part of this pass, but record them in `LOGIC-NOTES.md`)

Touch sticks and tap-to-focus untested on a real screen; Return arrow icon; drones sit 3 cm low on the ground; menu hotkey tab highlight; cobble/gravel edges (3.3); lake could be farther away (owner may want it moved); night sky still on the bright side.

## 9. LOGIC-NOTES.md

Keep one page `godot/LOGIC-NOTES.md`: per system, the inputs, decisions, outputs, where the code lives (file and a search string), and which test covers it. Update it in the same commit as any logic change. This is the memory a cold-start agent reads first.

---

## 10. Brief for DSH (paste this as the first message)

> You are working in `C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim\godot`. Read `SPEC-REALISM-PASS.md` fully, then `LOGIC-NOTES.md` if it exists, then the files named in your stage. Do one stage at a time, in the order of section 4, starting at the first stage not marked done in `LOGIC-NOTES.md`. For each stage: implement, run the gate in section 6, save the evidence in section 5, write the entry in `LOGIC-NOTES.md`, make one local commit (`git add godot` only; no push). If a stage needs a taste decision (how it should look or feel), do not guess: finish the measurable part, leave the A/B pictures, write the question in `LOGIC-NOTES.md` under "Questions for Claude and the owner", and move to a stage that does not depend on the answer. Never delete files. Never run more than one Godot window at a time and always close it. Do not enable the HDR sensor passes for the phone default. Do not touch other projects.
