# AeroSim (Godot): new experiences. Spec for DSH

Written 2026-10-23. Four new things to fly through and around, in priority order, plus a short list of cheap extras.
Read `COORDINATION.md`, `HANDOFF-TO-DSH.md` and `LOGIC-NOTES.md` first. Rules in `SPEC-REALISM-PASS.md` section 0 apply
(phone first, every effect has a switch, frame budget, gate green, no em dashes or timers in player text).

Why DSH builds these: the owner wants Claude's usage kept for his real job. **DSH must NOT model anything** (the owner's
experience is that it is poor at 3D modelling). All new 3D models are made first by Claude in `game/new_models.gd` (contract in
`game/README-models.md`: plane, birds, balloon, deer, barge). Branch `lane/models` holds them; merge it into the lane you work
in with `git merge lane/models` once it exists on `main`, then only wire the models up. Everything else here is logic, shaders,
particles, physics and synthesised sound, which DSH is good at. Where a look is a matter of taste, make a sensible
choice, write it under "Questions for Claude and the owner" in `LOGIC-NOTES.md`, and keep going.

---

## E1. Fireworks (first priority: the owner loves the idea, the view from above is rare)

### What the player sees
A fireworks show over the lake and the park, started from the pause menu (Weather tab, "Fireworks show": Off / Start a show) and
automatically on a few set evenings if "Surprise shows" is On (off by default). Shells rise from launch barges (`NewModels.barge()`) on the lake (a
barge row at about x -800, z 100, on the water; use `Lake.LEVEL`), burst 120 to 220 m up, and the drone can fly right through
the bursts. Smoke drifts downwind and lights up in the next burst. The crowd side is optional.

### Build (all in a new `game/fireworks.gd`, class `Fireworks`, shaders `game/shaders/firework_*.gdshader`)
1. **Shells** (GPU particles, one `GPUParticles3D` per shell type, sub-emitters are not available in Godot, so each burst is
   one pooled emitter placed at the burst point): launch trail (a thin rising spark line with a gold tail), burst, and fade.
   Types, at least eight: peony (sphere), chrysanthemum (sphere with long trails), willow (drooping gold), palm (arms), ring,
   heart (outline from a parametric curve), crackle (many tiny flashing sparks), and a finale barrage. Colour sets: red, gold,
   green, blue, white, purple, two-colour. Sparks are additive, HDR-bright (value above 1.0 so the camera bloom picks them up),
   fall with gravity and drag, flicker, and cool from white to orange to dark.
2. **Light:** each burst adds a short-lived light (an `OmniLight3D` from a pool of 4, energy that decays over about 1.5 s) so the
   trees, lake and the drone itself are lit by the colour. Clouds, smoke and the lake surface pick it up too (set a global
   `g_fire` colour and strength that the water shader and smoke use; add the water part as a Request for the water lane, do not
   edit `water.gdshader` yourself).
3. **Smoke:** low-density grey billboard particles that drift with `wind.toward()` and are lit by the current burst colour.
4. **Sound:** synthesise in code with `AudioStreamWAV`, like `game/drone_audio.gd`: launch whoosh, a thump with a low rumble, the
   crackle, and a distant boom. The sound arrives late: delay = distance / 343 m/s per burst (the light comes first). Heard
   from the drone's own microphone it is louder and nearer; use the existing listening perspectives. Add a bus `Fireworks`.
5. **Flying through:** sparks never hurt the drone (no damage), but a close burst makes a rumble on the microphone and flashes
   the exposure (the auto exposure already follows scene brightness; just make sure it reacts and recovers naturally).
6. **Show script:** a `show` is a list of (time, type, position, colour, size) events. Write 3 shows: a 3-minute build-up show,
   a quiet 90-second show, and a 20-second finale. Choose from the list in the menu. A show runs on a timeline (use the game's
   `sim_time`, pausing with the game). No on-screen countdown (the owner is dyslexic).
7. **Budget:** at most 6000 live sparks on desktop, 1500 on phones (`OS.has_feature("mobile")`), one draw call per type. Mobile
   renderer must work. Off by default in Simple camera mode only if it fails the gate there.
8. **Night flight:** a show is only started at night or twilight (sun elevation below -4 degrees). If the player picks "Start a
   show" in daylight, set the clock to the next 21:30 on the same date using the existing clock settings (`hud.weather["hour"]`,
   `clock_mode = 1`) and tell the player in plain words.

### Evidence
Screenshots at 21:45: a burst seen from the park at 20 m, from 120 m among the bursts, through a burst (`dof` Off), lake
reflections, smoke after 60 s, and a finale. Frame times with a full barrage. Note: the screenshot tool needs the show to start by
a test token, add `fireworks<showname>` handled in `_screenshot_mode` in `main.gd`.

---

## E2. The fixed-wing FPV plane

### What the player does
Picks a new airframe in the chooser: **FPV plane** (a foam wing or small trainer, 1.1 m span, 900 g). It flies like a real FPV
plane: it cannot hover, cruises at 18 to 28 m/s (top speed about 35), climbs and dives, banks to turn, and has a camera on the
nose. The owner's memory: someone launches, flies several kilometres out into a low cloud layer, and flies back home. So range
and a return-to-home matter.

### Build
1. `physics/airframes.gd`: add `"wing"` (id) with its own parameters; keep the existing five unchanged. Extend `Airframes.IDS`.
   The drone chooser (`game/drone_schematic.gd`, `game/drone_thumbs.gd`) must still draw: give the wing a plan and side
   outline built from its parts (see how `game/drone_parts.gd` records outlines).
2. `physics/plane.gd` (class `Plane`, same interface as `Quad`: `s` state array, `position()`, `velocity()`, `armed`,
   `step(dt, cmd)`): 6-DOF rigid body with a simple but honest aerodynamic model: lift and drag from angle of attack with stall
   (lift coefficient rising to about 12 degrees then dropping), control surfaces (elevator, ailerons, rudder) producing moments
   proportional to dynamic pressure, propeller thrust that falls with airspeed, weight, inertia from a wing-and-fuselage
   estimate, a little adverse yaw, and gentle ground handling (belly landing or hand launch: the game "hand-launches" it at
   10 m/s, 3 m up, at the home point when the player presses Take off). Respect the wind (`quad.wind` style input).
   Steps at the same 2 ms substeps as the quad, no allocations in the hot loop.
3. `physics/plane_controller.gd`: stick mapping: left stick: throttle (up and down), yaw (rudder, left and right); right stick:
   pitch (elevator) and roll (ailerons). Modes: **Stabilised** (default: self-levelling, limits bank 45 degrees and pitch 30), and
   **Acro** (rate control). A **cruise assist** option holds altitude. **Return to home**: climbs to a safe height, flies to the
   home point, circles down, then lands as a belly landing on the lawn near home (reuse `AutoPilot`'s structure in
   `game/autopilot.gd`; keep the quad autopilot intact).
4. `game/main.gd` wiring: today `quad` is a `Quad`; the least invasive route is to make `Plane` share the properties the rest of
   the game reads (`position()`, `velocity()`, `s[...]`, `armed`, `ground_h`, `ground_n`, `obstacle_hit`, `vrs`, `ang_accel`)
   and to switch by airframe in `switch_drone`. Search `main.gd` for `quad.` to see everything that must keep working. Keep all
   edits to `main.gd` small, commented, and in your own functions. If the integration needs more than about 60 lines in
   `main.gd`, introduce `game/flight_vehicle.gd` as a thin interface and move the touches there.
5. Model: use `NewModels.plane()` (already built, see `game/README-models.md`): do not modify the mesh. Spin `prop` at the
   motor speed (the blur disc logic in `game/drone_view.gd` and `prop_blur.gdshader` supports one propeller; follow how the
   quads do it). A shadow on the ground is already handled by `DroneShadow` (give it the plane's span and a wing-shaped plan
   from `outline_plan`).
6. HUD: show airspeed and altitude in the OSD (replace the hover-oriented readouts for this airframe: `H.S` becomes airspeed with
   a stall warning in plain words "Slow, nose down" when near stall), distance from home, return time estimate in minutes, and a
   battery bar scaled to a longer endurance (about 25 minutes at cruise). Keep the existing OSD layout; put new items in
   `game/osd.gd` behind `t["airframe"] == "wing"`.
7. Camera: nose camera, 84 degree lens, slight up-tilt option (0 to 25 degrees), no gimbal. Fixed to the airframe so the horizon
   banks with the plane (that is the look). The existing rolling shutter and jello effects respond to the wing's angular rate.
8. Sound: a single brushless motor with propeller, airflow whistle that rises with airspeed, and wind noise on the microphone
   (extend `game/drone_audio.gd` with a small `plane` mode driven by `a["omega"]`, airspeed and throttle).
9. Range: the video link already degrades with distance (`_rf_dbm` in `main.gd`): let it reach 5 km on the wing before the
   picture breaks up badly; going past it should make RTH engage automatically ("Link lost, returning home"), as real planes do.
   The world is 4 km wide; the far hills ring gives scenery out to 20 km, and flying beyond the valley edge should stay safe
   (no crash at the valley edge: terrain beyond is flat enough; clamp the plane's flight area to 9 km from home and say so
   in plain words as a notice when it reaches 8 km).

### Tests (add `test/plane_test.gd`, run headless like `test/wind_test.gd`)
Level trim at cruise (stays within 3 m of its altitude in calm for 60 s with a trimmed stick), stall recovery (nose down recovers
in under 3 s and loses under 40 m), a 360 degree bank turn completes with radius within 20% of v^2/(g tan(bank)), RTH from 3 km
away lands within 25 m of home, and no NaN anywhere over a 5 minute random-stick run. `apstest` and the quad tests must still pass.

---

## E3. Low cloud layer, flying into it (coordinate with the sky lane)

The sky DSH task owns the clouds. Add this as stage **S7** to `SPEC-SKY-CLOUDS.md` and do it after S1 to S6 on `lane/sky`:
a low stratus or stratocumulus layer, selectable in the Weather tab as "Low cloud layer" (Off / Thin / Thick, plus a height
slider 150 to 600 m above the valley floor), with an upper surface that glows in the sun from above (rolling top, god rays
on the sunny side) and a base that is grey from below. Flying into it: visibility falls to 20 to 60 m, the picture goes bright
and soft white-grey, the camera exposure reacts (auto exposure darkens and then recovers on exit), droplets appear on the lens
(use the lens-drops setting `sensor.rain_lens`; add a small amount when inside cloud), the motor sound becomes damp, GPS and
link stay fine, and the drone breaks out on top into bright sun or below into the valley. Implementation: a height-based fog /
density function evaluated both in the sky shader (seen from outside) and as a camera-dependent fog density in `main.gd` (the
inside effect: raise `env.fog_density` and set `fog_light_color` smoothly when the camera enters the layer, with a smooth
blend over 20 m of altitude so it does not pop). The plane (E2) and the quad should both work here.

---

## E4. Birds

New `game/birds.gd` (class `Birds`), GPU or MultiMesh for flocks, CPU boids at low rate for flock leaders only:
1. **Flocks:** Canada geese in a V (20 to 30 birds) crossing the valley high (150 to 300 m) at 15 m/s with slow wing flaps and
   honks (sound via `drone_audio.gd` bird phrases, add "honk"); starlings as a murmuration (500 to 2000 points on desktop, 300
   on phones) that twists and flows as a single shape at dusk over the lake; gulls circling and calling over the lake; one or two
   hawks soaring in a thermal over the meadow (circling and rising slowly, they already exist as sound sources in
   `drone_audio.gd` `_soarers`: make them visible at the same positions).
2. **Models:** use `NewModels.bird(kind, flap)` (already built; 8 wing poses). Show them with a `MultiMesh` per kind and pose (or
   a shader that blends poses using instance custom data and `TIME`); you only do the placement, flocking and animation
   timing. At distance they are dots; within 60 m they show wings.
3. **Behaviour:** birds avoid the drone: within 25 m they scatter (flock splits and veers away; starlings pour around it);
   flying very close does no harm and never kills a bird (no gore, ever). Gulls follow the shoreline. Everything obeys wind and
   weather (fewer in rain and fog, none at night, geese only in autumn and spring months by date).
4. **Setting:** Display > Graphics > "Birds" On / Off. Cost: under 0.5 ms; at most 2000 instances on desktop, 500 on phone.
5. The existing bird-flush sound logic (`bird_flush` signal, ground birds in trees) stays; connect scattering flocks to it.

---

## E5. Cheap extras (do if time and budget remain; each is optional and small)
1. **Mist banks on the lake** at dawn: low fog hugging the water, burning off by 09:00 (a height fog volume near `Lake.LEVEL`).
2. **Hot-air balloons** at sunrise: 2 or 3 drifting slowly, using `NewModels.balloon()`, plus a burner flame light at the
   returned `flame` position; they move with the wind at 2 to 4 m/s; the drone can fly close.
3. **Fireflies** at dusk in the meadow and near the lake edge (additive points, gentle flashing).
4. **Boats on the lake:** a few small sailboats and a ferry-like boat on slow paths, with wakes.
5. **Fly-through rings** (free-flight challenge): a ring course through the park and over the lake with an end-of-course time
   shown in plain words, no countdown during play; rings glow; also a "photo goal" mode ("Photograph the chapel from the air").
6. **Aurora** on rare clear nights (sky shader contribution; coordinate with the sky lane).
7. **Wildlife on the ground:** deer at the woodland edge at dawn and dusk, using `NewModels.deer()` (two poses: head down, head
   up); they raise their heads and run (move along the ground) when the drone is low and close.

---

## Order, lanes and branches
| Order | Task | Lane (branch, worktree) | Files |
|---|---|---|---|
| 1 | E1 Fireworks | `lane/fireworks`, `AeroSim-fireworks` | `game/fireworks.gd`, `game/shaders/firework_*`, small `main.gd` and `hud.gd` insertions |
| 2 | E4 Birds | `lane/birds`, `AeroSim-birds` | `game/birds.gd`, `game/shaders/bird_*`, bird phrases in `drone_audio.gd` |
| 3 | E2 FPV plane | `lane/plane`, `AeroSim-plane` | `physics/plane*.gd`, `game/drone_parts.gd` (new wing parts), `game/osd.gd` (wing readouts), small `main.gd` |
| 4 | E3 Low cloud layer | `lane/sky`, S7 | sky lane files |
| 5 | E5 extras | any of the above lanes, in the order listed | |

Create each worktree with `git -C <AeroSim main folder> worktree add ..\AeroSim-<lane> -b lane/<lane>` from the current `main`.
Merge protocol is in `HANDOFF-TO-DSH.md`.
