# AeroSim in Godot

The Godot 4.7 version of AeroSim. The flight physics is ported number for number from the web version
(`../src/physics`), and the headless test reproduces the web test results for all five drones.

## Run it

Double-click `Launch AeroSim (Godot).bat`. It uses the Godot editor copy in `..\..\_tools\godot-4.7.2`.
To open the project in the editor instead, run `Godot_v4.7.2-stable_win64.exe --path godot --editor`.

Keyboard: W and S throttle, A and D yaw, arrow keys pitch and roll, Q and E gimbal, R reset, C camera, M mode, Esc pause.
Phone and tablet: two thumb sticks, with PAUSE at the top right.

## Check the physics (no window)

```
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://test/physics_test.gd -- dt=0.002
Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- selftest
```

The first runs the hover, forward flight, braking, wind hold and manual roll tests on every airframe.
The second flies the whole game scene for a few seconds and reports the climb.

## Layout

- `physics/` airframes, rotor model, 6-DOF quadcopter, flight controller (a port of `src/physics`)
- `game/` terrain, wind, drone model, touch sticks, HUD and pause window, main scene
- `test/` headless physics test

## Photoreal pipeline (from the AeroSim v2 spec)

- World: the web version's procedural trees and cemetery models, exported by `tools/export_assets.ts` (run with `npx tsx export_assets.ts` in `godot/tools`).
- Lighting: analytic sky (Rayleigh and Mie), 4000 K sun that warms as it lowers, cascaded shadows, exponential height fog with forward scatter toward the sun.
- Sensor camera (`game/sensor_pipeline.gd` and `game/shaders/`): metering and auto-exposure with lag, bloom chain, rolling shutter and jello, Brown-Conrady distortion with chromatic aberration, sun streak and ghost and veiling glare, vignette, ISO noise, 10-stop S-curve, ISP sharpening, and H.264 macroblocking driven by the video link.
- Drone display (`game/osd.gd`): mode, GPS, link, battery, ISO and shutter, pitch ladder, flight-path marker, gimbal scale, data bar, luma histogram, compass radar.

## The world

The valley is the web version's own: `tools/export_world.ts` bakes it in Node (heightmap, woodland and lawn map, path distance,
where every tree, meadow clump, hedge, railing, wall, memorial, lamp, bench and car stands, the chapel and monuments) and writes
`assets/world/`. Godot loads it in `game/terrain.gd` and `game/world.gd`. Re-run `npx tsx export_world.ts` in `godot/tools` after
changing the web generators. The park paths are drawn with the shared library's asphalt (`assets/textures`, CC0).

## The flight app (phone-on-a-remote feel)

`game/hud.gd` and friends make the screen behave like a drone app: full-screen video with the data overlay, round glass buttons
(back, settings, mode, auto takeoff or land, return to home, camera view, photo or video, shutter), a gimbal scale, a map
thumbnail, notices under the top bar, and a full-screen Settings page (Flight, Drone, Weather, Camera, Display).
Return to Home, Auto Takeoff and Auto Landing fly through the same sticks a pilot would use (`game/autopilot.gd`); moving a
stick cancels Return to Home. The shutter saves the finished video frame to `user://photos`.

Headless checks: `-- selftest` (climb) and `-- apstest` (auto takeoff, fly 60 m out, Return to Home, land).

## Status

Done: physics port, five drones, terrain, the web trees and cemetery, GPU grass and meadow, sky shader and seven weather
conditions with wet surfaces, sensor camera, drone display and flight-app controls, pause window, assisted flight.
Next: paths and park furniture (lamps, benches, the chapel), audio and birds, mission rings, calibration against the web
captures, phone speed and an Android export.

## Android build

The phone version uses the Mobile renderer (no screen-space reflections, ambient occlusion or screen-space bounce light).
Tools live in `RWJ Coding Projects\_tools`: `jdk17`, `android-sdk` (platform-tools, build-tools 35.0.1, platform 35),
`debug.keystore`, and the Godot 4.7.2 export templates in `%APPDATA%\Godot\export_templates`.

Build: `Godot_v4.7.2-stable_win64_console.exe --headless --path godot --export-debug "Android" build/aerosim-debug.apk`
Install: double-click `Install AeroSim on phone.bat` with the phone plugged in (USB debugging on), or copy the .apk to the phone and open it.
Test the Mobile renderer on the PC with `--rendering-method mobile`.
