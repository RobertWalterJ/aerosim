# Night vision, moonlight, fireworks and laser blinding

Status: 2026-11-15. The night-vision feed now responds to the actual light in the scene and to bright events in front of the camera.

## Moonlight

- The moon is a real directional light: intensity scales with phase, elevation, cloud cover and the end of daylight.
- Moonlight also raises the night ambient slightly and colours the fog/haze; the moon disc and phase come from the solar model.
- `moonless` test hook removes the moon light entirely for comparison. Moonless open ground stays genuinely dark rather than being lifted into daylight.

## Night vision with no light

- The intensifier shader receives `moon_light` and `night_dark`.
- In a moonless scene it subtracts a black floor, lowers the gain, and lets photon grain/speckle carry the image. It does not invent daylight.
- In moonlight it lifts real detail: grass, tracks and trees read by the actual moonlit scene.
- The screen-space flash from fireworks is added by screen position, so the bloom originates at the burst rather than at the centre of the lens.

## Fireworks overwhelming night vision

- `SensorPipeline.burst_uvs()` exposes the active burst screen positions and strengths.
- Each frame, after the fireworks update, `NightVision.set_scene()` passes those into the green intensifier.
- Each burst adds:
  - a hot core at its screen position;
  - a softer halo;
  - a short white-green wash that can swamp the gain for a moment.
- The lens pipeline already had its own burst flash/streak/exposure dip; the night-vision pass now sees the same event.

## Laser

- Pike’s laser is a full camera-feed dazzle, not a tint: at peak the picture is opaque warm white with only the HUD visible.
- It rises almost immediately, holds, then fades over the existing burn duration; it sits above the night-vision layer, so it completely blinds that feed too.
- Test hook `laserdemo` shows the full-white frame.

## Verification

- `nightvisiondemo` at 23:00: moonlit intensifier.
- `moonless,nightvisiondemo`: dark, grainy, moonless intensifier.
- `nightvisiondemo,fwbig0`: firework flash through the intensifier.
- `nightvisiondemo,laserdemo`: complete white camera burn with HUD visible.
- `GATE PASS (nightflash)`.

## Limits

- The night-vision firework flash is a screen-space post effect, not a physically simulated iris/phosphor recovery.
- The laser is intentionally absolute while it is at peak; the afterimage fade is not modelled as retinal persistence.
- Moonlight is a directional light plus ambient/sky treatment; it is not a spectral night-sky simulation.
