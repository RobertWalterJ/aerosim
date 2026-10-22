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

## Status

Phase 1 spike. Done: physics port, terrain, trees with trunk collisions, sky and sun, five drones, touch and
keyboard and gamepad controls, pause window with Fly, Drone, Weather and Display tabs, snow.
Next: look on a real screen and tune, an Android export, the memorial park, grass, tree sway, the sensor camera look.
