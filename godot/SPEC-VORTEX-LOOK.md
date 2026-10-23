# Tornado and waterspout: the look Robert wants (session B, replaces the look notes in SPEC-EXTREME-WEATHER.md B1)

Written 2026-10-23. Reference pictures are in `docs/reference/weather/` (read each one with the Read tool before you start; the numbers below
are the file names `ref_12` to `ref_19`). Everything else in SPEC-EXTREME-WEATHER.md B1 (wind field, 22 m/s cap, budgets, tokens, menu) stands.

## The look in one sentence
Volumetric and made of countless particles, not a painted tube: air condensing into wisps that spiral into a funnel, droplets and dust mixed
into the whirling wind, and debris visibly orbiting and being lofted inside it.

## What each reference shows (and what to copy)
- `ref_12` (a storm-chasing tool): a huge, soft, layered storm base with a wall of lower cloud and a bright horizon gap under it.
  Copy: the cloud above the funnel is a wide rotating base, darker in the middle, lit from the horizon gap.
- `ref_13` (a dark tornado over a fence): a tall, soft-edged, nearly black column with no hard outline and a wide debris cloud at the base with
  flecks flung out of it. Copy: soft edges, the base skirt much wider than the funnel, specks flying outward.
- `ref_14` (a game tornado with a barn): a wedge-shaped dark funnel inside rain, a broad brown dust and debris skirt at ground level, large
  planks and sheets flying in the air. Copy: the brown skirt, large debris pieces, rain streaks, the barn-to-funnel scale (a barn is 10 m high; the
  funnel base is 100 m wide).
- `ref_15`, `ref_19` (waterspouts, side view): a pale grey, well-defined, tapering tube hanging from a cloud base, with a white spray plume and mist
  at the water. `ref_19`: the tube is darker at its edges, lighter in the middle, and narrows to a thin rope near the top where it meets the cloud.
- `ref_16`, `ref_17` (a waterspout from the air): the funnel stands in a bright, round spray ring; around it the sea shows concentric dark rings and a
  spiral of disturbed water (a wide circular wake that spreads out 5 to 10 times the funnel width). Copy this exactly for the water patch under a
  waterspout: a bright inner ring of spray, then dark concentric ripple rings and an inward spiral.
- `ref_18` (a rope waterspout): a thin, long, curved rope with an S shape, almost line-like, dissipating at the base with only a small mist. Copy this
  for the decaying stage of both funnels.

## How to build it (particle volume, three layers)
1. **Condensation wisps (the funnel body):** about 2500 GPU particles (desktop; 700 on phones) emitted high in the cloud base and flowing down and
   inward along spiral paths: each particle follows a logarithmic spiral toward the axis while descending, with speed rising toward the core (the
   funnel narrows as the air accelerates), grey-white to dark grey colour, soft round sprites with a noise texture, additive-free alpha blending,
   lifetimes 3 to 6 s, so the funnel is a living column of streaming wisps with visible gaps and strands at the edges, thickest in the core and
   dissolving to loose strands at the outside (not a solid tube). Add a faint core: a very low-alpha dark soft cylinder only to keep the interior
   dark. The funnel shape is a lathe profile (the `NewModels2.funnel_tube` mesh may be used as a faint dark shell or as an emitter shape only; it is
   not the look). Funnel types: **cone** (wide top, narrowing), **wedge** (wide, nearly cylindrical, tornado at its strongest), **rope** (thin S curve,
   dying). Over its life the funnel passes cone, wedge, rope, gone (about 2 to 8 minutes for a tornado, 1 to 3 for a waterspout).
2. **Droplets and condensation:** tiny bright flecks (a second particle layer, 800 on desktop) spiralling inside and just outside the funnel, a little
   lighter than the wisps, so it looks like droplets and cooling air condensing into whisps; drifting slower at the edge.
3. **Debris and dust (tornado):** a wide dust skirt at the base (soft brown-grey billboards, 120 to 200 m wide for a wedge), larger debris pieces
   from `NewModels2.debris_pieces()` (planks, shingles, branches, leaf clusters, paper) in a multi-mesh of 300 pieces orbiting the funnel at heights
   from 0 to 200 m, rising in spirals, tumbling, flung out and falling back; a few large pieces pass the camera (they are harmless: no collision).
   Leaves and twigs from the world's trees (reuse the leaf look of the ambient leaf particles) whirl in the lower part.
4. **Spray ring and water patch (waterspout):** at the water level a bright, dense mist ring (soft white particles, 12 to 30 m wide) with a spray
   plume rising 20 to 60 m inside the funnel; on the water a round surface disturbance of 5 to 10 times the funnel width: concentric dark rings and an
   inward spiral in the water normal map around the funnel (add a hook to the water shader via a global `g_spout` = xz centre, radius, strength; session
   B owns the water shader), with a few rings of foam. For the lake, a waterspout is smaller (10 to 40 m funnel) and lives 1 to 3 minutes.
5. **The cloud above it:** a rotating wall cloud base plus a bright gap at the horizon (from session A's storm cell hooks: `g_storm`), the funnel
   rooted into the base with a darker collar. If A's hooks are not on main yet, draw a dark rotating particle collar yourself.

## Life cycle and duration
Tornado: forms as a pendant lowering from the wall cloud (30 s), touches down (dust skirt appears), becomes a wedge (1 to 3 minutes), then ropes out
and dissipates; the parent storm and its rain last longer than the funnel (10 to 20 minutes with the thunderstorm cell). Waterspout: forms as a dark
spot on the water with a ring first, a spray ring, then the funnel descends from the cloud and joins it; rope-out last. Never an on-screen timer.

## Interaction with the drone (from SPEC-EXTREME-WEATHER.md B1, stays)
Wind field with rotation, inflow and updraft capped at 22 m/s, `Funnel.wind_at(pos)` added in `game/wind.gd`; roar that rises with proximity; dust and
droplets on the lens through the existing hooks; exposure dips as the scene darkens; the particles near the camera are lit by lightning flashes and
the sun; debris is harmless to the drone.

## Budgets and phone
Desktop: total particles in a tornado scene up to about 4500 (wisps 2500, droplets 800, dust 400, spray 400, leaves 400) plus 300 debris instances;
frame cost under 3 ms on this PC (report numbers). Phone and Simple camera: wisps 700, droplets 200, dust 150, debris 80; no per-pixel loops.
The Mobile renderer must work; use `GPUParticles3D` with simple unshaded or lightly lit materials. A menu switch "Funnel detail" Low / Normal / High.

## Evidence (save in docs/realism/weather/)
For tornado and waterspout, each from 400 m, 120 m, 40 m: the life-cycle stages (pendant, cone, wedge, rope), a dusk shot, one inside the dust
skirt, the water patch seen from 60 m directly above, and side by side with the reference picture that matches (say which). Frame-time table.
A short plain-words list of what you could not verify.
