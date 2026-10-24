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

- **Grass mask:** `Roads` bakes a 1024 px corridor mask, including the boat launch apron, and the grass shader keeps blades off it. The shoulders now read as shoulders instead of a strip of grass with a road underneath.
- **Textures and normals:** the road shader samples `asphalt_diff`, `asphalt_nor` and `asphalt_arm`; the shoulder samples `gravel_diff`, `gravel_nor` and `gravel_arm`. The mesh now carries tangents and terrain-following normals so the normal maps work.
- **Surface detail:** aggregate at two scales, wheel tracks, tar cracks, repaired patches, frayed edges, gravel in the edge, and slightly polished wheel paths.
- **Markings:** edge lines and a worn dashed centre line only on roads 6.5 m and wider. The narrow lanes are unmarked, which is what a rural lane looks like. The lines are wider, brighter and still worn.
- **Shoulders:** the outer lip sinks below the terrain, so the shoulder blends into the ground instead of hovering. The gravel shader adds tyre ruts, stones and grass creeping in at the outer edge.
- **Delineator posts:** white posts with red reflectors along the wider roads every 60 m on both sides, built as two multi-meshes.
- **Rain:** the weather's wetness value is passed to both shaders. Wet asphalt darkens and the wheel tracks pick up a little reflection; wet gravel darkens and smooths.
- **Boat launch access:** the launch lane is a short branch from the lakeside lane and ends on the gravel apron. The apron and ramp head are included in the grass mask.

## Evidence

- `docs/realism/roads/12_road_surface_and_posts.jpg`, the dry road with texture, markings and delineator posts.
- `docs/realism/roads/13_wet_road.jpg`, the same kind of road in rain.
- `docs/realism/roads/14_clean_shoulder.jpg`, the shoulder and grass margin in daylight.
- `docs/realism/boat_launch/00_boat_launch_aerial.jpg`, the launch from the air.
- `docs/realism/boat_launch/01_boat_launch_ramp.jpg`, the ramp and dock at the water.

## Honest limits

- The asphalt and gravel maps tile visibly when the camera is very close to the surface.
- There are no standing puddles, spray or tyre wet marks; wetness only darkens and polishes the material.
- There is no road camber, no banking and no deformation; the mesh still follows the terrain as a ribbon.
- No guardrails, chevron signs, road signs, cattle grids or passing places yet. The delineator posts are the only roadside furniture.
- The grass mask is 1024 px over 4 km, so the exact grass edge at the shoulder is coarse. The shader hides most of it, but a close inspection can find it.
- The lane-width threshold is a simple width test; a future route can still opt in or out of markings only by changing its width.
- Traffic does not leave tyre marks or dust, and wet roads do not change grip.

## Questions for Robert

- ROADR1. Do you want road signs, chevrons and gate markers next, or are the delineator posts enough?
- ROADR2. Should the wider roads get a yellow centre line, or stay white?
- ROADR3. Do you want visible puddles and wet tyre tracks in rain, or is the darkening enough?
- ROADR4. Should the narrow lanes become gravel roads with a different surface, rather than unmarked asphalt?
- ROADR5. Should the boat launch lane stay asphalt to the apron, or turn to gravel for the last few metres?
