# The thermal camera realism pass

Status: implemented, 2026-11-15. The thermal camera now has a relative white-hot scale, a better false-colour image, shaped heat shells for people and animals, and engine/cabin heat on vehicles. The sensor is still a game camera, not a radiometer, but the readings now follow the object and the scale is printed on the screen.

## The image

`game/shaders/thermal.gdshader` now renders a white-hot palette:

| Reading | Look |
|---|---|
| Air and water, around 8 C | near-black indigo |
| Ground and cold vegetation, around 12 C | deep purple to maroon |
| Warm surfaces and cabin glass | red to orange |
| Exposed skin, animal heads, body cores | yellow to white |
| Engines and exhausts, 90 C+ | white |

The image is deliberately cool: the valley is mostly indigo and dark purple, the roads and roofs read as warm maroon, and the heat sources are the only white. The old version amplified autumn leaves and bright stone into false hot spots. The new version masks green and blue surfaces down, and the heat shells use a low-green magenta code that the shader decodes, so a red maple or a white headstone is not mistaken for an engine.

The shader keeps the small-sensor look: fine grain, scanlines, a soft vignette and a fixed camera reticle.

## The scale

The thermal HUD now carries a bottom-centre relative scale:

> WHITE-HOT · RELATIVE SCALE
>
> AIR 8 · GROUND 12 · BODY 37 · ENGINE 90+

Each swatch matches the palette range. This fixes the earlier problem where a white pixel could mean a sunlit roof, a person or an engine with no reference. The scale is a relative calibration, not a measured temperature; the game does not carry a true thermal model.

## Heat shells

`game/thermal_heat.gd` owns the heat shells. They are invisible to the normal camera and are only shown while the thermal camera is on.

- **Person:** an insulated coat torso (warm pink), a hot head and two hot hands (magenta). This makes a person read as a person, not a round blob.
- **Animal:** a long body capsule (violet), a hotter head (magenta), used for the sheep and the wolf. The sheep reads warm, the wolf head reads hotter.
- **Vehicle:** a hot engine at the front, a warm cabin, and a hot exhaust at the rear. The body stays cool. Used by the traffic fleet and the parked village cars.
- **The dog at the camp** has an animal heat shell.

The shells follow the object's transform. They are switched from `main._sync_thermal_heat()` and from the wildlife/finale state so the camera, the story and the HUD stay in step.

## Vehicles and animals

- **Traffic:** every moving car, van or truck carries an engine and cabin shell, toggled with the thermal camera. The body stays dark.
- **Village:** both parked cars carry engine and cabin shells, so a car on a drive reads hot at the bonnet and cooler at the cabin.
- **Sheep:** the flock reads as a line of warm bodies with hotter heads.
- **Wolf:** a warmer head and body along the tree line.
- **Wren:** the lost hiker reads as a hot head and hands over a warm coat.
- **Biscuit the dog:** a small warm body at the camp.
- **The abandoned Lake Car:** deliberately cold. It has no engine heat shell, because it has been in the lake for decades.

## Evidence

- `docs/realism/thermal/00_wren.jpg`
- `docs/realism/thermal/01_sheep.jpg`
- `docs/realism/thermal/02_scale.jpg`

## Honest limits

- This is a screen-space false-colour shader plus colour-coded heat shells, not a radiometric sensor. The shell colours are a game code, not a physical temperature buffer.
- The scale is approximate and relative. `BODY 37` and `ENGINE 90+` are reference labels, not measured temperatures.
- Heat shells use no depth test so a body can show through thin foliage. That is a deliberate readability compromise for the search; it is not how a real thermal camera sees through a solid tree.
- The heat shells are hidden in the normal camera, so switching the camera is a visual mode change, not a material change on the normal models.
- The villagers, sheep, wolf and cars are code models until Claude's assets replace them. The shells are sized to the current silhouettes.
- There is no lens choice, focus control, gain control or emissivity setting. The camera is fitted by the story and toggled with T.
- A human is assumed to be one broad body shape; a real person has a much more varied thermal silhouette.
- The base image still uses screen luminance to estimate ground temperature. It is tuned to the valley's autumn palette, not physically simulated.

## Questions for Robert

- TH1. Is the white-hot palette right, or should it be black-hot or ironbow?
- TH2. Should the scale show measured-looking temperatures, or stay as relative labels?
- TH3. Should heat show through trees, or be occluded and make the search harder?
- TH4. Should the thermal camera have a gain or contrast control on the flight screen?
- TH5. Should cars show engine heat only while moving, or also when parked?
