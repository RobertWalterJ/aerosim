# AeroSim (Godot): extreme weather, sky events and things to fly through. Spec for DSH sessions A and B

Written 2026-10-23. Read `HANDOFF-TO-DSH.md`, `COORDINATION.md` and `LOGIC-NOTES.md` first. All rules from `SPEC-REALISM-PASS.md` section 0
apply (phone first, a menu switch for each effect, a frame budget, gate green, no modelling by DSH, no em dashes or timers in player text).
Everything in this file is code: shaders, particles, physics hooks, sound. Do not stop to ask taste questions: choose, record under
"Questions for Claude and the owner" in `LOGIC-NOTES.md`, continue. Models, if truly needed, are requested on the board as
`[REQUEST CLAUDE]`: collect them and ask once, in one batch. Models Claude can build quickly if asked: barn, windmill, freight train,
helicopter, kite. A tornado, waterspout, dust devil, smoke, rainbow and aurora need no models.

How a player starts these: the Weather tab gets a section "Events" with a plain-word choice for each ("Waterspout over the lake", "Tornado",
"Thunderstorm", ...) and an On/Off for "Surprise events" (off by default). An event is a scripted scene on the clock, never a timer on
screen. Events never damage the drone beyond what the wind lane already does (strong turbulence, a warning "Strong wind", the drone can
be thrown about; no crashes are forced). Flying into a funnel is allowed and is rough, not fatal.

Owners: **session B** builds everything under "B" (particles, funnels, lightning, thermals, course mode); **session A** builds the sky-side
pieces under "A" (they live in sky and camera files). Where B needs a sky change it writes `[REQUEST A]` on the board, and the other way round.

## B1. Waterspout (first) and tornado (second), one shared funnel system
New `game/funnel.gd` (class `Funnel`) and `game/shaders/funnel_*.gdshader`.
1. **The funnel:** a tall, slightly curved, tapering tube drawn as stacked rotating billboard rings or a lathe-style mesh made in code
   (this is a procedural tube, not a modelled asset) with a scrolling noise shader: dark grey-brown core, lighter edges, bands that rotate faster
   near the base, a thin rope-like stage for the decaying phase. Height 300 to 900 m, base width 20 to 150 m (waterspout 10 to 40 m).
   The top joins a wall cloud (ask session A for the sky hook, see A2) so it hangs from the cloud base.
2. **Base effects:** waterspout: a ring of spray and a cone of mist on the lake, a dark water patch; tornado: a debris cloud and dust skirt on
   the ground, leaves and twigs orbiting (GPU particles with orbital velocity), flashes of lightning in the funnel at night.
3. **Movement:** it forms (about 40 to 90 seconds, widening from the cloud), tracks across the valley at 6 to 15 m/s along the wind,
   wobbles, then ropes out and dissipates. Waterspout stays over the lake (use `Lake.is_wet` and `assets/world/lake_mask.png`); the tornado
   crosses the open meadow and stays out of the cemetery park (no collision with grave models; it only throws leaves and dust there).
4. **Wind field:** feed the wind lane: write `Funnel.wind_at(pos: Vector3) -> Vector3` (rotating plus inflow plus updraft, strongest at the
   core radius, falling off as 1/r) and add it to the wind the drone feels through `wind.sample` (one small commented insertion in
   `game/wind.gd`: `v += Funnel.wind_at(pos)` when a funnel is active). Keep it flyable: cap the extra wind at 22 m/s so every drone can
   stay in control with the sticks, and show "Strong wind" and "Wind too strong to hold position" through the existing warning code.
5. **Camera and sound:** a rotor-like roar that rises as you near it (low rumble, rising to a freight-train noise), dust and droplets on the lens
   through the existing lens-drop and shake hooks (`sensor.rain_lens`, `CamShake`), exposure dips as the funnel darkens the scene.
6. **Budget:** 2500 particles on desktop, 600 on phones; the funnel mesh under 3000 triangles; Mobile renderer must work.
Test tokens: `waterspout`, `tornado` in `_screenshot_mode`; evidence from 300 m, 80 m, inside the dust skirt, at dusk, and a frame-time table.

## B2. Thunderstorm cell with lightning
1. **Lightning:** branching bolts as animated line meshes with HDR glow (cloud-to-ground and sheet lightning inside cloud); a flash lights the
   world (reuse `WeatherSystem.flash` and the sky's `flash` uniform; coordinate any needed sky change with session A) and the camera
   exposure reacts. Thunder as synthesised sound arriving late (distance / 343 m/s), with rolling rumble and a close crack.
2. **Rain curtain and hail:** a dense rain shaft under the cell with a visible edge you can fly around; optional hail (white pellets, rattle on the
   microphone, small bounce on the ground); strong gust front before the rain.
3. **Safety rule:** no real lightning strikes on the drone; flying close only adds turbulence and a "Storm nearby" warning in plain words.

## B3. Thermals and the hawks
Invisible rising air columns over sun-warmed ground (open meadow in clear afternoon weather). Inside one the drone gains height (add an
updraft term to the wind at that point, 1 to 3 m/s) and the two hawks circle in it (session B owns the bird code: bring their circle centres to
the thermal centres). A faint shimmer or a few drifting seeds/dust motes make them findable. Off at night and in rain.

## B4. Dust devil, fog bank, snow squall, blowing snow (small ones, do after B1 to B3)
Dust devil: small funnel (reuse `Funnel` at 3 to 10 m wide) over dry ground in summer afternoons. Fog bank: a rolling wall of mist across the lake
with a defined edge that advances at 2 m/s. Snow squall: a local whiteout cell that drifts across; blowing snow near the ground in snow weather.

## B5. Fly-through courses (gameplay)
`game/courses.gd`: ring courses with glowing gates through the park and over the lake (three courses: easy, lake run, tree slalom), a ghost drone
that replays your best run, and a "Photograph this" mode (photograph named places from the air). Plain results screen, no countdown timer on
screen during the run; the finish time appears only afterwards. Menu: Flight tab "Courses". Gates avoid trees and graves (check against
`World.obstacle_hit`). Keep the code simple and robust: this is the main gameplay addition.

## B6. Things that cross the sky or ground (only if a model exists, otherwise a coloured stand-in)
Freight train on the far hills with a horn heard late; a small rescue helicopter far off with its rotor sound; kites; a flag on a pole near the
chapel waving with the wind (cloth shader). Request models from Claude only after B1 to B5 are done, in one batch.

## A1. Sky-side events (session A, in the sky and camera lanes)
1. Aurora on clear nights (rare, a slow green-violet curtain in the northern sky, faint, additive in the sky shader).
2. Rainbow after rain: appears opposite the sun at 42 degrees when the sun is low and rain has just stopped; fades over a minute.
3. Wildfire-smoke haze at sunset: an orange-red sun and thick low haze (a weather option "Smoke haze").
4. Sun halo and sun dogs on thin cirrus on cold days; heat shimmer over the lawn on hot afternoons (a small refraction in the camera shader).
5. Contrails from high airliners, with a faint far sound.

## A2. Hooks for the weather events (session A, small and early: do these first, B is waiting for them)
1. **Wall cloud and funnel anchor:** in the sky lane add a "Storm cell" cloud type: a dark rotating base 600 to 1200 m up, a lowered wall cloud, and
   a global `g_storm` (xz position of the funnel anchor, a 0 to 1 strength) so session B's funnel hangs from it; a green-grey sky tint when
   it is active; the shelf cloud (a rolling arcus edge) on the leading side.
2. **Sky colour global for night shows and storms:** a global `g_sky_dark` that lets other effects darken the sky (session B asked for this for fireworks; see the board entry), and
   the existing `flash` uniform to accept bolt flashes from lightning at a direction.
3. **Camera hook for events:** the camera lane exposes `sensor.event_dim(strength)` (exposure dip when a funnel or storm darkens the scene) and
   the burst-brightness hook session B asked for (see the board). Keep them tiny.

## Order
B: B1 waterspout, B1 tornado, B2 thunderstorm, B3 thermals, B5 courses, B4 small ones, B6. A: A2 hooks first (small), then A1 in order.
Branches and worktrees: B uses `lane/weather` (create `AeroSim-weather`), A uses its existing lanes (`lane/sky`, `lane/camera`).
Merge protocol is in `HANDOFF-TO-DSH.md`. Update the status table in `LOGIC-NOTES.md` as you finish each piece.
