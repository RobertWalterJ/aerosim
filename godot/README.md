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

## Status

Phase 1 and 2 spike. Done: physics port, five drones, terrain, the web trees and cemetery, sky and fog, the sensor pipeline,
the display, touch and keyboard and gamepad controls, the pause window, snow.
Next: grass and leaf litter, foliage wind sway and downwash, paths and benches and lamps and the chapel, audio and birds,
the mission rings, soft shadows, lighting calibration against the web captures, phone speed and an Android export.
