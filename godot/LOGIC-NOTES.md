# AeroSim (Godot) logic notes

The memory for any agent starting cold. One section per system: inputs, decisions, outputs, where the code lives, which test covers it.
Update this in the same commit as any logic change. Realism pass stages are listed in `SPEC-REALISM-PASS.md` section 4.

## Realism pass status
| Stage | State |
|---|---|
| 1.5 Motion blur | not started |
| 1.1 Bloom and glare, 1.2 Colour looks | not started |
| 1.3 Compression, 1.4 Lens character | not started |
| 2.1 Contact shadows, 2.2 Cheap GI | not started |
| 2.3 Volumetric light, 2.4 Sky clouds | not started |
| 2.5 Water | not started |
| 3.1 Trees | not started |
| 3.2 Far hills forest, 3.3 Grass and ground | built on lane/ground (2026-10-23), gate green, awaiting the owner's look review (questions G1 to G6) |
| 3.4 Gravestones, 3.5 Drone detail | built on lane/ground (2026-10-23), gate green, awaiting the owner's look review (questions G7 to G10) |

## Questions for Claude and the owner
Ground lane (each was decided and built one way; the evidence is in `docs/realism/ground/`):
- G1. Far hills: four layered ranges (3.7, 6.4, 10.5, 16.5 km), rounded with the odd sharper crest. Keep them this pale, or more contrast?
- G2. The crest trees on the near hills are drawn 1.6 to 2.6 times life size so they read at 3 to 6 km. Acceptable?
- G3. Every asphalt path now has a 30 cm cobble kerb and a ragged gravel verge. Keep on all paths, or only the avenues?
- G4. Six worn short cuts (desire lines) across the lawn, about a metre wide. More, fewer, or wider?
- G5. Leaf litter under the crowns uses a photographed mud and leaves set: right darkness, or brighter and more orange?
- G6. Clover patches are slightly bluer and darker than the lawn, with white heads up close. Too blue?
- G7. 230 new graves (about 14% more): Celtic crosses, angels, obelisks, Gothic headstones, kerbed plots. Right number and mix?
- G8. Weathering: lichen, rain streaks, moss on the north side, dirt at the foot, paler chipped edges. Polished granite stays nearly clean. Stronger or weaker?
- G9. Chapel: entrance steps, door surround, round gable windows, sills, ridge cap, gutters and downpipes, louvred bell stage. Anything to drop?
- G10. Drone stickers are plain pale labels with bar marks, no words. Want any plain text (for example a model size)? Real brand marks stay out.

## Requests to other lanes (ground lane)
- **Sky and fog (sky lane):** toward the sun the far hills read whiter than the sky above them (fog sun-scatter on geometry, `fog_sky_affect` lower on the sky). It was there before this pass. The far hills now read a global `g_haze` (rgb = haze colour, a = strength), which `FarHills._process` copies from `env.fog_light_color` each frame; the sky lane may take over setting it.
- **Main and terrain (Claude):** `GroundDetail.dress(terrain)` is called from `FarHills.build` because `terrain.gd` is outside this lane; a one-line call after `terrain.build()` in `main.gd` would be cleaner. `Graveyard.build` is called from the end of `Hedgerow.build` for the same reason, so `world.gd` stays untouched.

## Systems (short)
- **Sensor camera** (`game/sensor_pipeline.gd`, shaders in `game/shaders/`): HDR scene viewport, metering (CPU exposure `_log_e`), bloom, sensor, ISP, codec, blit. `simple` mode (phone default) skips all passes. Test: `-- apstest`, screenshots with `simple` and without.
- **Sun and moon** (`game/solar.gd`, `main.gd` `_update_celestial`): real clock or set time. Sky in `shaders/sky.gdshader`.
- **Drone shadow and cloud shadow** (`game/drone_shadow.gd`, `shaders/cloud_shadow.gdshaderinc`, globals `g_cloud`, `g_ds*`): applied in ground, grass, foliage shaders per vertex or pixel.
- **Depth of field and autofocus** (`sensor_pipeline.gd`, `focus_box.gd`): `CameraAttributesPractical`, thin-lens maths, tap to focus.
- **World** (`terrain.gd`, `world.gd`, `hedgerow.gd`, `lake.gd`, `far_hills.gd`, `ambient_particles.gd`, `assets.gd`).
- **Ground detail** (`game/ground_detail.gd`, used by `shaders/ground.gdshader` and `shaders/grass.gdshader`): a canopy map (512 px over 1200 m, from the layout's near trees: crown radius 2.6 m x scale for conifers, 4.8 m for broadleaf, spilling 1.35 times) drives leaf litter (photo set `soil_leaves`), moss, damp darker shade, and thinner, shorter grass under trees. `DESIRE` holds six worn short cuts [x0, z0, x1, z1]; both shaders run the same `desire_at` (skipped beyond 1.8 m of a track). Paths: asphalt to 1.55 m (plus a quarter of the old wobble), a 0.30 m cobble kerb (`cobble`), then a patchy gravel verge (`gravel`); grass is cut at 1.8 to 2.0 m and thinned out to 2.9 m (path map `uPathT`). Clover (bluer, shorter, white heads in the lawn layer only) and moss patches use the same noise in both shaders. Blades: normals tilt to each side of a midrib, the midrib is lighter; 12% blue-green fescue and 10% bleached straw blades. Search: `desire_at`, `uCanopy`, `kerb_out`. Test: the lawn and path-edge shots below.
- **Far hills** (`game/far_hills.gd`, `shaders/far_hills.gdshader`, `shaders/far_tree.gdshader`): a ring mesh 76 x 320 from 1.4 to 22 km. `_ground` = rolling noise plus four `RANGES` (Gaussian ridges with ridged-noise crests and gaps), eased up from the valley's edge height (no step). Per vertex COLOR: r forest (noise, steepness, crests; far ranges wooded), g conifer share (more up high), b crest. Forest raises the surface by `CANOPY_H` (16 m) for a ragged skyline. The shader draws autumn broadleaf and dark conifer with a crown speckle that fades below pixel size, a field patchwork (240 x 170 m, turned per 2.6 km district) with hedgerow lines, snow and wet looks, and aerial perspective to `g_haze` (`uHazeDist` 9 km, `uHazeAmt` 0.2; Godot fog adds the rest). Crest trees: up to 4500 (1200 on phones) far tree models on forested crests and forest edges within 6.5 km, only outside the valley square (so never in the lake), coloured from the layout's far-tree palette. Search: `RANGES`, `_crest_trees`, `g_haze`.
- **Graveyard** (`game/graveyard.gd`, called from `Hedgerow.build`): six code-built shapes (Celtic cross, angel, obelisk, Gothic headstone, kerbed plot with a headstone, kerbed plot with a cross). 230 are placed on the existing 2.8 m headstone lattice (its holes and block edges), weighted, with a small random lean and stone tint each. They keep clear of the start pad (15 m), paths (2.3 m plus their radius), layout colliders, hedges, trunks, buildings and exclusions (1 to 1.5 m). Each adds collision cylinders. One MultiMesh per shape, one shared limestone material. Chapel details are built only if the layout's chapel is still at (188, -74): steps, door surround, gable round windows, sills, ridge cap, gutters, downpipes, louvred bell stage (constants `CH_*` measured from park.glb). Test hook: `-- gravedebug` prints where each shape went.
- **Stone weathering** (`shaders/stone.gdshader`): `weather_amt` (default 1) scales rain streaks on upright faces, lichen blotches (grey-green, pale grey, orange on tops), moss weighted to the north (-z) side and the foot, dirt at the base (`base_y` = the model's ground line; `Assets._park_stone_walk` sets it from each one-off mesh's box), and paler chipped edges found from the surface curvature. Polish reduces all of it.
- **Drone details** (`game/drone_view.gd`, section "small details"): screws, arm bolts, motor leads with heat-shrink, antenna fittings, battery buckles and grip pads, plain stickers (`_sticker`: pale label, print lines, bar marks; no words, no brands), tube clamps and fin antennas on the cinema drone, vents and hinge pins on the Mini. All use outline "none" (the chooser drawings are unchanged) and go into the existing per-material surfaces, plus one vertex-coloured `decal` surface. Wear: a 256 px roughness map (`_wear_tex`: scratches and scuffs) on the drone materials, projected from three sides, so no UVs are needed. Camera pod, gimbal and camera offsets unchanged.

### Ground lane evidence and numbers (2026-10-23)
- Images: `docs/realism/ground/*_before.jpg` and `*_after.jpg` (hills from 150 m toward the lake, 1.5 m lawn pass, gravestones at 3 m, chapel at 20 m, wet sky4, snow sky6, Mobile renderer), plus after-only shots: overcast haze, path edge, new grave shapes, kerbed plot close-up, chapel door end, Simple mode, all five drones at cd0.5, and a zoomed drone strip.
- Commands (godot folder): `Godot... --path . -- "shot=<png>,300,fpv,clock16.0,at-18_150_36_90_-8"` (hills), `at-24_1.5_27_0_-15` (lawn), `at30_3_-72_0_-25` (graves), `at170_8_-55_-45_-10` (chapel), `at201.3_4_-52.3_31.5_-8` (chapel door), `chase,clock13.0,drone<id>,cd0.5,at-18_3_36_150_-20` (drones); add `sky4` or `sky6`, `--rendering-method mobile`, `simple`.
- Frame rate (`--print-fps`, last 4 s of a 420-frame shot, baseline and new run alternately twice; other agents were using the same GPU, so the spread is about 5 fps either way): lawn pass 41.6 to 40.0 fps, hills 42.3 to 54.0 (noise), Mobile renderer lawn 44.6 to 42.4. No regression shows above the noise. The 60 fps desktop budget could not be checked on a shared machine (the baseline was under 60 too).
- Size: textures add 3.6 MB (cobble, gravel and soil_leaves 1k sets); evidence JPEGs 5.9 MB.
- Not verified: the phone (S23). Load time added: canopy map about 90 ms, graveyard about 100 ms; the far hills mesh and crest trees were not timed separately.
- **Menu** (`hud.gd`, `menu_style.gd`, `drone_schematic.gd`, `keyboard_guide.gd`).
- **Icons** (`hud_icons.gd`, `round_button.gd`, `shutter_button.gd`).
- **Phone**: `export_presets.cfg`, release steps in `SPEC-REALISM-PASS.md` section 7.

## Drone in wind (wind lane, 2026-10-23)
Owner's aim: in strong, gusty wind the drone visibly and audibly works harder, wobbles and drifts, and stays flyable. Calm by default.
- **Inputs:** `Wind.sample` (unchanged: log profile, slow gusts, fast flutter) gives `quad.wind`. Then `Wind.drive(quad, terrain, pos, agl, dt)` runs once per physics tick (main.gd `_physics_process`, after the sample) for the drone only.
- **Turbulence at the drone:** `sigma = intensity(agl) x profile(agl) x (1 + shelter)`. `shelter` (0..1) = woodland cover (`Terrain.cover_at`) 8, 20 and 40 m upwind, faded out above 8 to 40 m AGL; in the lee the mean wind drops 35% and the turbulence doubles. `burst` (0..1) is a slow noise for gust spells; `spell = 0.55 + 0.9 burst`.
- **Gust puffs (drift):** a 2.5 s Ornstein-Uhlenbeck vector added to `quad.wind`, size `GUST_H x sigma/(1+sigma/6) x spell x susc`. Position hold brings the drone back.
- **Eddy torque (wobble):** body torque `quad.gust_tau` = smooth 0.15 s two-stage noise x `TORQUE_K x rho x Cd x A x arm x soft(|v_rel| + sigma) x sigma x spell x susc`, soft limit `x/(1+x/10)` so a storm stays flyable. Physics divides by inertia, so light drones are thrown more. `susc = (0.6/mass)^0.35` (Mini 1.36, Cinema 0.74) is the owner's "light drones much more than heavy" direction.
- **Rotor flapping:** a gust change (wind high-passed at 0.5 s, in the body frame) tips the drone downwind for a moment: `FLAP_K x m g R` per m/s.
- **Weathervane (crab):** side airspeed gives a small yaw torque (centre of side pressure `VANE_L x arm` behind the centre); the yaw loop's I term stops it after a few degrees, so the nose sits a little into the wind.
- **Position hold** (`flight_controller.gd`): Normal and Sport, sticks centred, stopped (under 0.6 m/s): holds the spot, flies back at up to 2.5 m/s (gain 0.9 N, 0.6 S). Released by a stick, landing, or a jump over 2 m (reset/teleport). Blown over 20 m away: the spot is dragged along. `saturated`: the velocity loop asked for more than the bank limit. `losing_hold()`: saturated and over 3 m off the spot. `tilt_error()`: uncommanded tilt (test metric).
- **Off switch:** Weather tab "Wind effects on the drone: Off / Natural" (`hud.wind_fx`, signal `wind_fx_changed`), sets `wind.struggle`; Off zeroes `gust_tau` and skips puffs and shelter (old model exactly). `quad.gust_tau` defaults to zero, so the physics parity test is unchanged.
- **Motor strain:** comes from the physics (uneven RPM while the controller fights the torque; more thrust and power in strong wind). Sound (`drone_audio.gd`, `strain_in`): each motor's loudness follows its own speed, a soft triangle whine at the electrical frequency (7 pole pairs) when a motor runs over 1.06 to 1.4 x its hover speed, plus rough-air rumble on the onboard microphone (Buffet bus) from `turb x burst`.
- **Camera shake** (`game/shake.gd`, `CamShake`, applied in main.gd after the first-person camera is placed, Full camera only, not in Simple): smooth noise in time (9/s buzz + 2.5/s knock) scaled by `turb x (0.45 + 0.55 burst)`, eased over 0.3 s. Gimbal: 0.6 deg x level plus a 4 ms gimbal lag on body rates, capped 1.5 deg. FPV: 1.6 deg x level, capped 4 deg (the frame wobble itself is already in the picture). Also adds to the sensor `vibration` (jello). Setting "Camera shake: Off / Natural".
- **Warnings** (`Wind.feedback`, called each frame from main.gd): wind at the drone smoothed over 1.5 s. Over the airframe's comfortable wind (`COMFORT`: Mini 8, Freestyle/Race 12, Cinewhoop 9, Cinema 14 m/s): "Strong wind". Losing the hold for 1.5 s: "Wind too strong to hold position". Shown as a quiet amber line on the display and beside the WIND readout; a notice (`hud.toast`) at most once per level per windy spell; a spell ends after about 20 s well under the limit.
- **Test:** `test/wind_test.gd` (run in two parts, it is slow: `-- ids=mini,cinema` and `-- ids=freestyle,race,cinewhoop`): 60 s hover at 10 m in five winds per airframe; asserts calm wobble under 0.3 deg, storm wobble RMS under 6 deg, no crash, Mini more disturbed than Cinema, jolt recovery under 0.7 s, take off, hover and land with the sticks in strong, storm and strong storm, warnings. Dev tokens in a `shot=` run: `windms<m/s>` (menu wind, gusty), `hover` (after `sky<n>`, stops the auto climb), `nowindfx`; and `windlog` prints the struggle and shake once a second.
