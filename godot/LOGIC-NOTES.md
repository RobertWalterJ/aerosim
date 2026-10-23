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
| 3.2 Far hills forest, 3.3 Grass and ground | not started |
| 3.4 Gravestones, 3.5 Drone detail | not started |

## Questions for Claude and the owner
(none yet)

## Systems (short)
- **Sensor camera** (`game/sensor_pipeline.gd`, shaders in `game/shaders/`): HDR scene viewport, metering (CPU exposure `_log_e`), bloom, sensor, ISP, codec, blit. `simple` mode (phone default) skips all passes. Test: `-- apstest`, screenshots with `simple` and without.
- **Sun and moon** (`game/solar.gd`, `main.gd` `_update_celestial`): real clock or set time. Sky in `shaders/sky.gdshader`.
- **Drone shadow and cloud shadow** (`game/drone_shadow.gd`, `shaders/cloud_shadow.gdshaderinc`, globals `g_cloud`, `g_ds*`): applied in ground, grass, foliage shaders per vertex or pixel.
- **Depth of field and autofocus** (`sensor_pipeline.gd`, `focus_box.gd`): `CameraAttributesPractical`, thin-lens maths, tap to focus.
- **World** (`terrain.gd`, `world.gd`, `hedgerow.gd`, `lake.gd`, `far_hills.gd`, `ambient_particles.gd`, `assets.gd`).
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
