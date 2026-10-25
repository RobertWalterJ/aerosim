# Ground traces and Pike's laser

Status: 2026-11-15. Two thermal-camera features and one anti-drone hazard.

## Thermal ground traces

A new `GroundTraces` node creates **thermal-only** marks from recent movement:

- **Human footprints** — from the invisible village cast and Wren while she is revealed; a paired print, warm body code, about 55 s lifetime.
- **Animal prints** — from the sheep and the wolf while they are visible; smaller paired hoof marks, about 42 s lifetime.
- **Vehicle tracks** — two tyre strips from each moving vehicle over the road, grass or trail; engine-heat code, about 32 s lifetime.

The marks are heat-code planes that are **hidden in the normal camera** and shown only while the thermal camera is on. They age every frame, fade gradually, and free themselves; the pool is capped at 280. They are sampled only near the drone (430 m) and only when the source has actually moved since the last mark.

This gives the pilot a way to read where people and animals have just been without rendering humans close-up.

## Pike's camera laser

Harlan Pike's ridge now has a laser dazzler in addition to the jammer mast and hunter drones:

- when an armed drone is within **118 m** of the mast, a red laser line tracks it;
- after a short lock the camera feed burns red-white for about **1.5 s** and the HUD shows a **CAMERA BURN** warning;
- the laser is **below the HUD**, so it obscures the camera feed without hiding the instruments;
- holding the beam within **58 m** for too long forces the drone back to its launch site with a laser-specific message;
- the laser is disabled when the jammer mast goes down for the finale, so the cabin remains reachable.

This is a warning/keep-out hazard, not a damage system.

## Evidence

- `docs/realism/cameras/traces_vehicle_heat.png`
- `docs/realism/cameras/traces_village_heat.png`
- `docs/realism/cameras/laser_burn.png`

## Limits

- Footprints are simplified heat quads, not textured boot or paw prints.
- Human prints come from the invisible cast routes and Wren; no extra human models are drawn.
- There is no wind/rain erasure beyond the lifetime fade, and no persistence across a reload.
- Traces are sampled only near the drone, so a track laid far away may not exist when the pilot arrives.
