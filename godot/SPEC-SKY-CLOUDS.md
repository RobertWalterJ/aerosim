# AeroSim (Godot): sky and clouds. A standalone task for DSH

Written 2026-10-23. This is the whole brief. Read `COORDINATION.md` first (your lane, your branch, what you may touch), then this file, then `LOGIC-NOTES.md`.

## Goal
From a drone at 20 to 150 m the sky is half the picture. Make it look like real footage: volumetric cumulus with lit edges and
shaded undersides, thin cirrus, a believable horizon and haze, correct sunrise and sunset colour, a night sky that is dark, and
ground cloud shadows that match what is overhead. All driven by the existing weather and clock, cheap enough for a phone.

## Working setup
- Project: `C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim\godot` (Godot 4.7.2, GDScript, shaders).
- Create your worktree and branch first (see `COORDINATION.md`): branch `lane/sky`. All your work and commits stay there. Never push. Never delete files.
- Godot: `RWJ Coding Projects\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`. One Godot window at a time; close it. Use `timeout 250`.
- Gate (run after every stage): `powershell -ExecutionPolicy Bypass -File tools\gate.ps1 -Tag sky`. It must print `GATE PASS`.
- Measure look changes: `python tools\look_metrics.py <before.png> <after.png>`. Golden images: `docs\realism\golden\*.jpg`.
- Screenshot command and tokens are in `SPEC-REALISM-PASS.md` section 0, item 10 (`sky0` to `sky6` weather, `clock<h>`, `date1..4`, `facesun`). Yaw is unusual: try 90 and 190.
- Files that may be CRLF: preserve line endings. Write files with the Write/Edit tools, not shell heredocs (they mangle backslashes).
- Text rules for anything the player reads: plain words, at most 20 words a sentence, no em dashes, no timers.

## What exists (read these)
- `game/shaders/sky.gdshader`: analytic clear sky (zenith/horizon, Mie glow, sun disc), two cloud layers drawn on a plane (`cumulus` fbm, cirrus streaks), night (stars, Milky Way, moon disc with phase), lightning flash. Uniforms: `sun_dir, cover, dark, cirrus, haze, fog, drift, flash, moon_dir, moon_illum`.
- `game/weather.gd` (`WeatherSystem`): seven conditions (Clear, Partly cloudy, Overcast, Fog, Rain, Storm, Snow) as a table, eased transitions, wetness, snow cover, lightning.
- `game/main.gd`: `_apply_weather_state` feeds the sky, fog, sun and moon each frame; `_update_celestial` places the sun and moon from the real clock (`game/solar.gd`).
- `game/shaders/cloud_shadow.gdshaderinc`: moving cloud shadows on ground, grass and foliage (`g_cloud`: cover, drift, time).
- The sky is a Godot `Sky` with a `ShaderMaterial` (shader_type sky) used as environment background AND as ambient and reflection light, so it must stay cheap. Process mode is `REALTIME`.
- Cameras: a sensor pipeline turns the HDR scene into video with auto-exposure and bloom; the phone uses a plain mode (`simple`). Sky brightness values must be physically sensible HDR (sun disc many times brighter than the sky; clouds near 1.0 in sunlight).

## Stages (do in order; one commit each on `lane/sky`; gate green before the next)

### S1. Volumetric cumulus
Replace the flat plane clouds with ray-marched layers: a cloud slab between roughly 1,500 and 3,500 m, density from layered noise (a low-frequency coverage map shaped by `cover`, plus detail erosion), 6 to 8 primary steps with a sun-direction light step of 2 to 3 samples, Beer-Lambert with a powder term, silver lining toward the sun, and darker bases. Cloud colour comes from the sun colour (warm at low sun) and the sky (blue fill). `dark` darkens and greys the clouds toward storm. Clouds move with `drift` (wind) and slowly morph with time.
Quality uniform `quality` (0 low, 1 medium, 2 high): steps and noise octaves. Touch devices and `--rendering-method mobile` use low.
Evidence: clear, partly cloudy, overcast, storm, sunset (`clock18.6 date3`), looking toward and away from the sun, at heights 20 m and 150 m. Frame cost measured with `Engine.get_frames_per_second()` over 300 frames, before and after. Budget: under 1.5 ms extra on this PC, under 3 ms low quality on a phone-class GPU (estimate by measuring `--rendering-method mobile` and scaling; report numbers).

### S2. Cirrus, haze, horizon
Thin high cirrus bands with soft streaks, lit at sunset; horizon haze that thickens with `haze` and `fog`, brightens toward the sun (forward scattering) and desaturates distant hills (the far hills in `game/far_hills.gd` use vertex colour for aerial perspective: expose one uniform or a global `g_haze` so the hills and sky agree at the horizon, no visible seam). Fix any visible band or line where the terrain edge meets the sky.
Evidence: horizon view from 150 m in clear, hazy and foggy weather; no seam.

### S3. Sun, sunrise, sunset, twilight, night
Correct colour through the day from the real solar position: golden hour, sunset reds on cloud undersides, blue hour, civil/nautical twilight fading to a dark night sky. Night: stars and Milky Way must be visible but dim, moon halo, clouds lit faintly by moonlight, and the overall night sky must be darker than now (the auto-exposure brightens night, so the raw sky must be dark: check with the real camera path, not just the raw sky).
Evidence: a time series at `clock5.5, 6.5, 7.5, 12.5, 17.5, 18.5, 19.2, 20.5, 23.0` on `date3` (autumn) in clear weather; contact sheet.

### S4. Cloud shadows that match the sky
`cloud_shadow.gdshaderinc` currently uses its own noise. Make the shadow pattern come from the same coverage function and drift as the sky clouds (project the sky coverage map straight down along the sun direction at cloud height), so a shadow on the ground lines up with its cloud. Keep the cost per pixel low (it runs in ground, grass and foliage shaders; foliage and grass already evaluate it per vertex). Overcast has no hard patches; scattered cloud has strong ones.
Evidence: an aerial shot where a shadow patch and the cloud that casts it are both visible (use `facesun`-like tokens or set the camera to look at the sun side), and the old vs new shadow pattern.

### S5. Weather integration
Rain and storm skies: low dark cloud deck with ragged base, rain curtains toward the horizon (soft vertical streaks, not particles), lightning illuminating the cloud volume from inside, snow sky (flat bright grey, low contrast). Weather transitions blend smoothly over about 10 to 20 seconds without popping (cover, dark, haze eased). Keep `weather.gd`'s public interface: add fields rather than rename.
Evidence: a transition filmstrip (every second for 20 s) from clear to storm and back; screenshots per weather.

### S6. Phone and cost
Provide quality tiers and measure each. On touch devices (`OS.has_feature("mobile")`) default to low quality: 3 to 4 steps, 2 octaves, no light step (fake with the density gradient). Make sure the Simple camera path shows the sky correctly (use `simple` token screenshots), with a normal tone map (the phone has no sensor exposure pass). Add a pause-menu setting Display > Graphics > "Sky quality" (Low / Medium / High, default Medium on desktop, Low on phones) following the `_choice` pattern in `game/hud.gd` (insert only; Claude owns hud.gd, keep your edit to a few lines and put it in the section named for your lane).

## Done means
`GATE PASS`; the evidence images saved in `docs/realism/sky/<stage>/` (small JPEGs, under 400 KB); a `LOGIC-NOTES.md` entry per stage with frame-time numbers; one summary report at the end listing what changed, what you could not verify, and a numbered list of taste questions for Claude and the owner (do not stop to ask them one at a time; make a reasonable choice, record it, and continue).

## Do not
- Touch files outside your lane (see `COORDINATION.md`). Do not edit `sensor_pipeline.gd`, `foliage.gdshader`, `ground.gdshader`, the drone files, or `hud.gd` beyond the few-line setting.
- Enable the HDR sensor passes for phones. Do not change the Simple camera path.
- Push, delete files, or hide a failing check. If a check is red for two rounds, question the check before the code.
- Make a stage depend on a taste decision: make the choice, record it, move on.
