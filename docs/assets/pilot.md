# Pilot

A man in his mid to late thirties standing behind the launch point with a screen-type transmitter. His head follows the drone.

## Files
- `public/models/pilot.glb`: the game model (Blender export, WebP textures).
- `assets/blender/pilot.blend`: the editable Blender scene, textures packed. Opens in Blender 4.2 or later without any add-ons.
- `tools/blender/pilot/`: scripts that rebuild the model from scratch (see the README there).
- `src/world/PilotFigure.ts`: `Pilot` (placement, GLB loading, LOD, head tracking) and `buildPilot()` (the light procedural figure used far away and as the fallback).

## API
```ts
const pilot = new Pilot(lod);                    // procedural figure, LOD 0 or 1
pilot.place(x, groundY, z, heading);             // heading in the simulator convention (radians)
await pilot.loadDetailed('./models/pilot.glb', 60);  // Blender model near, procedural beyond 60 m
pilot.update(dronePosition, dt, camera);         // head tracking and LOD switch, every frame
pilot.screenMaterial();                          // the transmitter screen material (rc_screen)
```
URL options: `?pilot=0` hides him, `?pilot=simple` keeps the procedural figure, `?teleport=pilot` starts the drone hovering in front of him.

## Model
| part | source | notes |
|---|---|---|
| body | MPFB2 / MakeHuman base mesh (CC0), macros male, age 0.59 (about 37), African 1.0, muscle 0.6, weight 0.6, height 0.5 | face targets: rounder head, fuller cheeks, wider nose and nostrils, fuller lips, wider chin, thicker neck |
| skin | MakeHuman `middleage_african_male` diffuse, lightened and warmed slightly, beard and hairline painted in | game material: physical, roughness 0.52, sheen 0.35 (warm) in place of subsurface scattering |
| beard | five fur shells over the beard area, 1.0 to 5.6 mm out, alpha cut 0.22 to 0.67 from one RGBA map | density mask from face landmarks (lips, ears), denser on chin, jaw and moustache, patchy where thin |
| hair | close crop painted into the scalp (only the sides and back show under the cap) | |
| cap | six-panel crown projected onto the head with seams, pre-curved brim, top button | dark olive cotton, roughness 0.9 |
| glasses | round panto rims, keyhole bridge, temples routed over the ears | frame: clear acetate (alpha 0.42, clearcoat); lenses: alpha 0.1 with iridescence for the green AR reflections |
| clothing | MakeHuman `male_casualsuit02` with the top recoloured to a plain white crewneck, `shoes05` trainers | |
| transmitter | modelled in the script: 168 x 118 x 22 mm shell, rear grips, 5.5 in 16:9 screen (`rc_screen`, emissive), two knurled sticks, four green LEDs, three buttons, mode switch, flat folding antennas | grey plastic, no branding |

Rig: MPFB `game_engine` (53 bones). The holding pose (two-bone IK to the grips, thumbs aimed at the stick caps, fingers wrapped behind) is baked into the rest pose, so the game only rotates `neck_01` (40 %) and `head` (60 %).

## Budgets
| | triangles | draw calls | size |
|---|---|---|---|
| GLB (near) | about 50 000 | 16 | 2.1 MB |
| procedural LOD0 / LOD1 (far, fallback) | 6 300 / 1 500 | 6 / 5 | none |

## Tunables
- Placement and clearance: `spots` list in `main.ts` (first spot without a tree crown within 1.5 m).
- LOD switch distance: second argument of `loadDetailed` (30 m on low, 60 m otherwise).
- Head tracking speed and limits: `Pilot.update` (yaw limit 1.1 rad, pitch -0.35 to 0.85 rad, body turns past 0.95 rad).
- Look, pose and accessories: `tools/blender/pilot/stage*.py` (macros and face targets in stage A, beard and hair masks in stage B, cap and glasses in stage C, transmitter and grip in stage D), then run `build.sh`.
