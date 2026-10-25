# Cameras, render order, night and launch audit

Status: 2026-11-15. This pass checked the camera stack and the map/launch system.

## Render order

The screen is built in layers, bottom to top:

| Layer | Owner | What it is |
|---:|---|---|
| 1 | `SensorPipeline` video | the world render, sensor exposure, bloom, colour and lens effects |
| 8 | `NightVision` | green low-light pass over the video |
| 9 | `ThermalCamera` | false-colour thermal pass over the video, plus its own thermal badge and scale |
| 10 | `Hud` | flight UI, OSD, camera controls, minimap and settings |
| 28 | `PhoneOS` | the in-game tablet |
| 34 | `PhoneNotes` | notification shade and heads-up cards |
| 60 | `Ending` | the intentional end-card wash |
| 100 | loading | loading page |

Thermal and night vision both use `hint_screen_texture` in a `CanvasLayer` below the HUD. They therefore sample the video and world only; the HUD is drawn afterwards and is not tinted, scanned or false-coloured. The thermal badge and scale are part of the thermal layer, so they sit under the HUD by design, not over it.

Screenshots confirm the status bar, flight buttons, OSD, minimap and camera readouts stay normal while the world is green or thermal.

## Night vision

`NightVision` is the existing Facade add-on, toggled with `K`. It is an image intensifier, not thermal:

- green monochrome, grain, scanlines and a vignette;
- adaptive gain rises when the scene is moonless and falls when the moon is up;
- it remains below the HUD, so all instruments stay readable;
- it can be used with the drone light for low-light evenings.

## Dark nights

The night ambient floor is now lower, the sky background follows the moon, and the sensor exposure is held back on moonless nights instead of opening the whole valley into daylight.

- clear full-moon night: lifted by moonlight, readable and still blue;
- overcast night: darker;
- moonless night: the darkest case, with stars and the drone light carrying the picture;
- a moonless test hook (`moonless`) and low-light test shots were used to check the range.

## Drone lights

The drone has a forward/downward light with a profile per airframe:

- **Cinema / Cinewhoop:** soft, wide film light;
- **Night Owl:** long, bright floodlight;
- **Raptor / Race:** narrow, bright spot;
- **Mini / Freestyle:** small general spot;
- **Wing:** landing light.

The HUD **Drone light** switch still turns it on and off; the toast names the fitted type. The light is a real `SpotLight3D`, below the HUD, so it illuminates the world without washing out any UI.

## Launch-point audit

`Map → LAUNCH SITES` lists every site with distance and drive time, a current marker, a suggested site for the story, and a **Drive here** button. `travel_to_site()`:

- refuses to move while the drone is armed and airborne;
- updates `launch_pos` and `launch_yaw`;
- moves the minimap home marker;
- respawns the kit at the new site;
- closes the phone and shows a toast.

Tested via the map screen and direct travel tokens: **Ridge trailhead → Festival field → North gate pull-off** all moved and spawned correctly. The map pin labels were overlapping around the village/gate cluster; the pin pass now places labels greedily with leader lines, so the sites stay readable.

The site list is complete: cemetery home, east/south/west gate car parks, north gate pull-off, Toby Farm gate, boat launch, Voss and Son yard, ridge trailhead, ridge camp, festival field and Halloway village.

Remaining map limits:

- All sites are available from the start; there is no unlock progression.
- The move is implied rather than driven as a vehicle journey.
- The site marker is a point; individual parking bays are not modelled.
- The map is a road atlas, not a live satellite image.
