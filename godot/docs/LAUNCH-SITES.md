# Launch sites and the valley map

Status: implemented, 2026-11-15. The pilot does not have to fly every mission from the home pad. The phone now has a Map app with ten roadside launch sites, distance and drive-time figures, a suggested site for the current case beat, and a Drive here button that moves the kit while the drone is on the ground. The last flight now requires the pilot to stage at the ridge trailhead or the north gate pull-off, which makes the trip north part of the story rather than a teleport.

## Why it works this way

The drone is one small vehicle and the valley is several kilometres across. The old home pad is beside the cemetery, which is nowhere near the lake, the farm or the north cabin. Flying every chapter from home made the story feel smaller than the roads looked. The map turns the drive into a visible decision: the player sees the distance, picks a site that suits the next beat, packs the kit and launches from there.

There is no real-time drive and no timer. The map reports the distance and an approximate drive time, the drone must be on the ground, and then the kit is unpacked at the new site. It is implied travel, not a driving minigame.

## The sites

| id | Name | Place | Use |
|---|---|---|---|
| `home` | Cemetery home pad | (-18, 36) | The old home pad, chapel and east gate |
| `east_gate` | East gate car park | (264, 58) | The cemetery car park and the valley highway |
| `north_ridge` | North gate pull-off | (24, -263) | The ridge road, the camp and the last flight |
| `farm` | Toby Farm gate | (188, 512) | The sheep pasture, hay field and Riley's favour |
| `lake` | Boat launch | (-424, 118) | Halloway Lake, the ramp and the long shore |
| `garage` | Voss and Son yard | (66, -592) | The garage, ridge road and the old car |
| `cabin_track` | Ridge trailhead | (38, -752) | The old dirt track to the abandoned cabin and the last flight |
| `camp` | Ridge camp | (42, -1108) | The camp, the railway and the high ridge |
| `festival` | Festival field | (292, 292) | The festival ground and the south lane |
| `village` | Halloway village | (438, 268) | The village lane by the green, pub, stores and garage |

## Suggested launch sites for missions

The Map app highlights the site that fits the current beat:

- Lake Car chapters: the lake site for the car, the garage for the VIN, the camp for the camp beat and the festival for the bus.
- Riley's night pasture: the farm gate.
- The last flight: the ridge trailhead. The finale will not start until the kit is at the ridge trailhead or the north gate pull-off, and Rennick tells the player to drive up.

The suggestions are soft for the normal chapters; the last flight is the one hard staging requirement.

## Map app

The Map app is the seventh app on the phone home screen. It shows:

- a schematic road atlas drawn from the actual road paths;
- the cemetery boundary, the western lake and a 100 m grid;
- all ten launch-site pins, with the current and suggested sites picked out;
- the current site, the suggested site for the current beat, and the drive distance and approximate time to every other site;
- a Drive here button on each site card.

The current site is saved to `user://launch_site.cfg`, so the game remembers where the kit was parked.

## Travel behaviour

- The drone must be on the ground. If it is flying, the app says: "Land the drone before driving to a new launch site."
- On a successful move the app closes, the drone is unpacked at the new site, the HUD minimap home marker moves, and a toast names the site.
- The battery is refreshed by the travel and launch, like packing the kit and charging it.
- Return to Home returns to the current launch site, not the old home pad.
- RTH and launch messages now say launch site rather than home.

## Evidence

- `docs/realism/launch_sites/00_map.jpg`, the map after driving the kit to the boat launch, with the ridge trailhead suggested for the last flight.
- `docs/realism/launch_sites/01_map_home.jpg`, the map at the home pad.

## Honest limits

- The drive is implied; there is no animation, vehicle trip or time passing.
- The map is a schematic drawn from road paths, not the live camera minimap, and the lake shape is approximate.
- The sites have no dedicated pad geometry, windsock or parked kit prop yet. The player is placed on the site position.
- Site unlocking is not story-gated; every site is available from the start.
- Only the last flight hard-requires a particular site. The other chapter suggestions are highlights, not gates.
- The map does not route along roads; the distance is straight-line and the drive time is an estimate.
- The launch site save file is new and separate from the story save.
