# Road realism pass

Status: implemented, 2026-11-15. This is the appearance work on top of the road route plan. The roads now use the project's asphalt, gravel and normal maps, keep grass off the carriageway, carry lane markings only where a rural road should, and darken in the rain.

## What was wrong

- Grass grew straight through the asphalt and shoulders because the meadow shader only knew about the park paths, not the new country roads.
- The asphalt was a flat procedural colour with no albedo or normal texture.
- The road mesh normals were all world-up, so the surface did not catch the terrain light.
- The outer shoulder edge floated a few centimetres above the ground.
- Every route, including the narrow lanes, got the same edge and centre markings.
- There was no wet response, no delineator posts and no visible repair or wear detail.

## What changed

- **Grass mask:** `Roads` bakes a 2048 px corridor mask, including the boat launch apron, and the grass shader keeps blades off it with a hard 0.02 to 0.30 threshold. The corridor is painted 5.5 m wider than each carriageway plus shoulder so a root at the verge cannot lean a tall blade over the asphalt. The shoulders read as shoulders instead of a strip of grass with a road underneath.
- **Textures and normals:** the road shader samples `asphalt_diff`, `asphalt_nor` and `asphalt_arm`; the shoulder samples `gravel_diff`, `gravel_nor` and `gravel_arm`. The mesh now carries tangents and terrain-following normals so the normal maps work.
- **Surface detail:** aggregate at two scales, wheel tracks, tar cracks, repaired patches, frayed edges, gravel in the edge, and slightly polished wheel paths.
- **Markings:** edge lines and a dashed centre line only on roads 6.5 m and wider. The narrow lanes are unmarked. The paint is now separate geometry at real-world sizes: 120 mm edge lines and 120 mm centre dashes in a 3 m paint / 9 m gap rhythm, lifted clear of the asphalt and stopped short of the junction aprons.
- **Shoulders:** the outer lip sinks below the terrain, so the shoulder blends into the ground instead of hovering. The gravel shader adds tyre ruts, stones and grass creeping in at the outer edge.
- **Delineator posts:** white posts with red reflectors along the wider roads every 60 m on both sides, built as two multi-meshes.
- **Rain:** the weather's wetness value is passed to both shaders. Wet asphalt darkens and the wheel tracks pick up a little reflection; wet gravel darkens and smooths.
- **Boat launch access:** the launch lane is a short branch from the lakeside lane and ends on the gravel apron. The apron and ramp head are included in the grass mask.

## Signs, speed limits and junctions

`game/road_signs.gd` now puts the traffic language on the roads:

- **Stop signs** on the six minor approaches to the main junctions: the south lane, east lane at both ends, lakeside lane at the farm, launch lane and west lane. Each stop sign has a white stop line across the approach.
- **Speed limit plates** at the route entries: 40 on the valley highway and ridge, 30 on the east lane, 25 on the lakeside lane, 20 on the south and west lanes and 10 on the boat launch lane.
- **Junction warning diamonds** before the south-lane, east-gate and west-lane junctions.
- **A fingerpost** at the east gate car park pointing to Halloway Lake.
- **Traffic behaviour:** vehicles are capped at 85 percent of the route speed limit in `traffic.gd`; the signs and the traffic share the same limits in `roads.gd`.
- The signs are code placeholders with readable text plates and galvanised posts. Final sign faces are requested in `docs/CLAUDE-ROAD-SIGNS-ASSETS.md`.

## Location signs and turnoffs

The bigger place-making signs are in `game/landmark_signs.gd`:

- an 8.2 m HALLOWAY CEMETERY gateway on two stone pillars at the east gate turnoff, with CHAPEL / WAR MEMORIAL / EAST GATE on both faces;
- smaller gate boards at the south, north and west gates;
- Toby Farm, Voss and Son Motor Works, Halloway Lake, the festival field, the ridge camp, the old cabin, the boat launch and the chapel signs.

The road network now has explicit turnoffs instead of signs floating beside a through route:

- the main lanes approach all four cemetery gates, and the east gate has its car park;
- the short gate, farm and festival asphalt spurs were removed after they left untidy tongues at the junctions;
- the boat launch lane remains a real access, and the camp, garage and lake are reached from the ridge and lake roads. The old cabin is different: its last approach is the separate dirt and gravel track in `game/cabin_track.gd`, not asphalt.

The traffic route pool only uses the through roads, so vehicles do not loop around a 10 m driveway. The cemetery audit uses the actual wall line at 238 m and still reports `inside_cemetery: 0`.

### Location sign evidence

- `docs/realism/location_signs/00_cemetery_gateway.jpg`
- `docs/realism/location_signs/01_cemetery_gateway_back.jpg`
- `docs/realism/location_signs/02_garage_sign.jpg`

The final gateway and place-sign art is requested in `docs/CLAUDE-LOCATION-SIGNS-ASSETS.md`.

## The road as a landing surface

The drone does not use a rigid-body road collider. It samples a ground height at the four corners of its body, so the road collider is the `Roads.surface_height(x, z)` function in `game/roads.gd`.

`Roads` bakes a second 2048 px field beside the grass mask. It stores the road top offset: 0.06 m on the asphalt, 0.20 m on the junction aprons and 0.24 m on the old cabin dirt track. `surface_height()` samples that field and adds it to the terrain height. `main.gd` now feeds that function into both the quad and the plane as `ground_h`.

Verified values on the valley highway at (286, 180): terrain 131.143, road surface 131.203, delta 0.060. Off the road at (250, 240): terrain 133.499, surface 133.499, delta 0.000. A drone placed on the asphalt sits 0.010 m above the sampled surface, not inside it.

This fixes the old case where the drone landed on the bare terrain while the raised asphalt ribbon was still 5 to 20 cm above it, so the body appeared to sink into or pass through the road.

Honest limits: this is height sampling, not a generated collision mesh, so there is no side-surface collision, no skid material response and no landing gear contact shape. The 2048 field is about 2 m per pixel at the road edge. Only the asphalt, junction apron and cabin track are raised; shoulders still follow the terrain.
## Grounding the road and assembling the paint

The ribbon was lowered from 140 mm to 55 mm above the sampled ground, and the asphalt now has three vertices across instead of two. The left edge, crown and right edge all follow the terrain, so the road cannot bridge over a rise in the middle and hover. A short vertical edge skirt drops from each asphalt edge to the ground and the shoulder outer lip sinks below the grass.

The paint is not baked into the asphalt shader any more. `roads.gd` builds it as separate meshes at real-world dimensions:

- 120 mm edge lines, inset 0.55 m from the asphalt edge;
- 120 mm centre dashes, 3 m of paint and 9 m of gap;
- both lifted 100 mm above the datum and stopped 11 m short of a junction;
- a plain white line material today, ready to be replaced by the final marking decals.

**Asset brief:** `docs/CLAUDE-ROAD-SURFACE-ASSETS.md` asks for seamless asphalt PBR sets, a modular pavement marking kit with real dimensions and clean pivots, shoulder and junction blends, and channel/tiling documentation.

Evidence: `docs/realism/roads/18_modular_markings.jpg`, `19_road_edge_grounding.jpg`.
## The old cabin track

The abandoned cabin is deliberately not served by a country highway. `game/cabin_track.gd` builds a narrow dirt and gravel track from the ridge road at (45, -760) through the trees to the cabin at (-250, -820). It has two worn wheel ruts, no markings, no shoulders and no asphalt connection.

The track is obstructed by two fallen trees lying across it and two rockfalls. A cave entrance sits in an outcrop west of the cabin, with a dark mouth, boulder arch, bare rock apron and an old KEEP OUT board. The cave is a named photo subject. None of the obstructions have collisions; they are scenery for the air and for the cabin approach.

Evidence: `docs/realism/cabin_track/00_dirt_track.jpg`, `01_fallen_tree.jpg`, `02_cave_entrance.jpg`.

Honest limits: the track is a simple unshaded ribbon with ruts, not a full gravel road with individual stones. The fallen trees and rocks are code-built primitives. The cave is a rock cluster around a dark mouth, not a modelled cave interior. The cave is difficult to see from directly above because the entrance faces the cabin, which is why the evidence uses an oblique view.
## Intersections and flashing red beacons

- **Five rural flashing-red beacons** hang from cables between two 6.5 m timber poles at the east gate, south junction, Toby Farm junction, north gate and west junction. Each has a yellow diamond backplate, black housing, red lenses on both faces and a pulsing red OmniLight. Lens and light flash together, about 0.68 seconds on and 0.67 off.
- **Pause switch:** Display > World > Intersection beacons turns the flashing and red light off; the poles and housings remain.
- **Markings:** every stop sign has a white stop bar. The separate edge and centre marking meshes stop short of the junction aprons, so no lane line runs across an intersection.
- **Signs:** stop approach signs, STOP AHEAD warning diamonds on the busier approaches and the existing junction warnings.
- The beacons are scenery. Traffic does not stop for them, and there is no signal controller or give-way logic.
- Evidence: `docs/realism/intersections/00_beacon_at_night.jpg`, `01_east_gate_beacon.jpg`, `02_south_junction.jpg`, `03_stop_ahead.jpg`.
- Full notes: `docs/INTERSECTIONS.md`; final signal art request: `docs/CLAUDE-INTERSECTION-ASSETS.md`.
## Junction cleanup

The independent route ribbons used to run over each other at shared junctions, leaving overlapping shoulders and wedges. The fix is two-part:

- the asphalt and gravel shaders discard any fragment inside a junction mask, so no route ribbon or shoulder is drawn across the crossing;
- `roads.gd` builds a paved junction apron as the convex hull of the approaching carriageway corners. It is one asphalt patch, not a roundabout disc and not stacked ribbons.

The very short gate, farm and festival spurs were removed from the road network because they produced long narrow tongues at the junctions. The gates, farm and festival still have their signs and approaches; they are reached by the lane, car park and park paths rather than by extra asphalt stubs.

The result in the junction overviews is a clean T or corner with one surface, one set of edges and no overlapping shoulder geometry. Evidence: docs/realism/roads/15_junction_clean_east.jpg, 16_junction_clean_south.jpg, 17_junction_clean_farm.jpg.

### Sign evidence

- `docs/realism/road_signs/00_stop_sign.jpg`
- `docs/realism/road_signs/01_speed_limit.jpg`
- `docs/realism/road_signs/02_east_gate_signs.jpg`

## Evidence

- `docs/realism/roads/12_road_surface_and_posts.jpg`, the dry road with texture, markings and delineator posts.
- `docs/realism/roads/13_wet_road.jpg`, the same kind of road in rain.
- `docs/realism/roads/14_clean_shoulder.jpg`, the shoulder and grass margin in daylight.
- `docs/realism/roads/18_modular_markings.jpg`, separate edge and centre markings on the road.
- `docs/realism/roads/19_road_edge_grounding.jpg`, the lowered ribbon and edge skirt.
- `docs/realism/roads/20_grass_edge_clear.jpg`, the road edge at close range with no blades through the asphalt.
- `docs/realism/boat_launch/00_boat_launch_aerial.jpg`, the launch from the air.
- `docs/realism/boat_launch/01_boat_launch_ramp.jpg`, the ramp and dock at the water.

## Honest limits

- The asphalt and gravel maps tile visibly when the camera is very close to the surface.
- There are no standing puddles, spray or tyre wet marks; wetness only darkens and polishes the material.
- There is no road camber, no banking and no deformation; the mesh still follows the terrain as a ribbon.
- No guardrails, chevron boards, cattle grids or passing places yet. The delineator posts and the new stop, speed and warning signs are the main roadside furniture.
- The sign art is placeholder: text plates and simple octagons and diamonds, not final reflective sign faces. Stop signs are scenery; traffic does not actually stop at them.
- The big gateway is placeholder board-and-pillar geometry, not a designed entrance. Its lettering is Label3D, pushed in front of the board to stop z-fighting. The junction aprons are convex hulls of the approach carriageways; they remove overlapping ribbons but are still simple flat polygon patches.
- Location and business boards are two-sided simple boxes; only the east gate has a large gateway sign.
- The gate and farm approaches are lanes, car park and park paths now; the short asphalt gate and farm spurs are gone. Only the east car park has formal parking and parked cars.
- Speed signs show one plate at each route entry rather than a full sign schedule along every road.
- The grass mask is 1024 px over 4 km, so the exact grass edge at the shoulder is coarse. The shader hides most of it, but a close inspection can find it.
- The lane-width threshold is a simple width test; a future route can still opt in or out of markings only by changing its width.
- Traffic does not leave tyre marks or dust, and wet roads do not change grip.

## Questions for Robert

- ROADR1. Do you want road signs, chevrons and gate markers next, or are the delineator posts enough?
- ROADR2. Should the wider roads get a yellow centre line, or stay white?
- ROADR3. Do you want visible puddles and wet tyre tracks in rain, or is the darkening enough?
- ROADR4. Should the narrow lanes become gravel roads with a different surface, rather than unmarked asphalt?
- ROADR5. Are the current speed limits right, and should they be in mph or km/h?
- ROADR6. Should traffic actually stop and give way at the junctions, or are the signs scenery?
- ROADR7. Should the cemetery gateway arch over the driveway or sit beside it?
- ROADR8. Should the gate driveways get gravel aprons and formal parking bays?
- ROADR5. Should the boat launch lane stay asphalt to the apron, or turn to gravel for the last few metres?
