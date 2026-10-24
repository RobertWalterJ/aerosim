# Roads and the cemetery: the new network

Status: implemented, 2026-11-13. The old road plan cut the valley highway through the graves and the chapel, and the ridge road started inside the cemetery. That was not acceptable. The roads now form a ring outside the cemetery walls, connect to its four gates, and link the places that need a road.

## The problem

The cemetery is a walled square of about 476 m by 476 m, centred on the origin, with the home/start pad inside at (-18, 36), the chapel at (188, -74) and gates at:

- east gate, about (234, 43), with the existing car park at x 247 to 280, z 41 to 50,
- south gate, about (17, 237),
- north gate, about (12, -238),
- west gate, about (-238, -4).

The old valley highway went home to chapel to farm directly across the grave rows. The old ridge road went home to the north through the cemetery. Neither should exist.

## The new plan

Every asphalt centreline stays outside a 248 m square around the cemetery. Inside the walls, the park's own gravel paths remain the only paths; the roads end at the gates and their car parks. The audit in `roads.gd` reports `inside_cemetery: 0`.

| Route | From | To | Purpose |
|---|---|---|---|
| valley highway | east gate car park | farm | east and south outside wall, the main valley road |
| south gate lane | valley at (286, 260) | south gate | park access from the south |
| east boundary lane | east gate car park | north gate | outside the east wall, links the north side |
| ridge road | north gate | garage and camp | the ridge and railway side |
| cabin track | ridge at (45, -760) | old cabin | branch to the cabin |
| lakeside lane | farm | lake overlook | south and west outside the park |
| west boundary lane | lakeside lane at (-300, 300) | west gate | access to the west gate and close the ring |
| boat launch lane | lakeside lane at (-410, 120) | boat launch apron | short lane to the Halloway Lake boat launch |

The four gates are now the only motor entrances to the cemetery. The east gate keeps its existing car park. The home pad and chapel are reached by the park paths, not by cars. The festival bus field has moved from inside the park at (24, -96) to the field at (300, 300), so the bus and festival are no longer parked among the graves.

The boat launch lane leaves the lakeside lane at its old overlook end and runs the last few metres to the gravel apron at `CaseObjects.BOAT_LAUNCH_SPOT`, where the concrete ramp goes down into Halloway Lake. The launch itself is built in `game/boat_launch.gd`; see `docs/CLAUDE-BOAT-LAUNCH-ASSETS.md` for the asset brief.

The main lanes approach all four cemetery gates, and the east gate has its car park. The short asphalt gate, farm and festival spurs were removed after they left untidy tongues at the junctions. The gates are reached by the lanes, car park and park paths; the farm and festival remain signed destinations off the main road rather than extra asphalt stubs. The large location and business signs are placed by `game/landmark_signs.gd`: the cemetery gateway at the east turn off, smaller gate boards at the other gates, and signs for Toby Farm, Voss and Son, Halloway Lake, the festival field, the ridge camp, the old cabin, the boat launch and the chapel. The art brief is `docs/CLAUDE-LOCATION-SIGNS-ASSETS.md`.

## Map

The minimap now draws the country roads as a dark line with a warm centre under the pale park paths. The roads and the cemetery paths can be read together: the ring outside, the garden inside, the gates where they meet.

## Evidence

- `docs/realism/roads/10_road_ring_outside_cemetery.jpg`, the high overview showing the ring and the untouched square.
- `docs/realism/roads/11_cemetery_paths_and_minimap.jpg`, the home pad, park paths and minimap at ground level.

## Honest limits

- The roads end at gate points outside the walls; only the east gate has an existing modelled car park with cars. South, north and west gates do not have their own parking bays or bollards yet.
- The audit is a rectangle check on the road centreline, not a full geometric collision test against every grave and hedge; it is a guard against the old mistake, not a survey.
- The road grades follow the terrain automatically and have not been checked for every vehicle angle.
- The west lane runs close to the outside of the wall; it is outside the 248 m guard but a final art pass should check the wall edge and gate posts.
- The festival field has moved; any old screenshots or saves that remember the old field position should be treated as out of date.
- No new Claude asset is needed for the road layout. The gate posts and car parks could be a future model request.

## Questions for Robert

- ROAD1. Is ending the asphalt at the gates the right feel, or should there be a short driveway into each gate?
- ROAD2. Should the south, north and west gates get small gravel car parks and bollards?
- ROAD3. Is the festival field at (300, 300) in the right place, or should it be somewhere else outside the cemetery?
- ROAD4. Should the old park path to the chapel remain the only chapel access, or should there be a service track around the outside and a short walking spur?
- ROAD5. Do you want road signs naming the gates, the farm, the lake and the ridge?
