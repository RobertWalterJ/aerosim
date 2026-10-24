# Claude village asset brief: Halloway village

Status: production request, 2026-11-15. The town finally exists east of the cemetery. It is a small English-border valley village, not a city and not a film set: one street, a green, a pub, a stores, a garage and a handful of cottages. The code placeholders are coloured boxes with photographed textures. These are the final models.

Owner of placement and code: session B. Claude handles models, PBR textures and contact sheets only.

## The place

Halloway village sits on the village lane at (330 to 512, 226 to 318), east of the cemetery wall and south of the festival field. The cemetery stays a separate, walled, tree-lined place. The village is the working, lived-in counterpart: warm stone and brick, slate roofs, white sills, a green with an oak, a red phone box and a bus shelter where the school bus stops.

The look is the Welsh Marches: weathered limestone and red brick, dark slate, cream plaster, faded painted timber, moss, gravel, wet grass and low mist on autumn mornings. Not chocolate-box. Not a theme park. A place with a leaking gutter and a good pub.

## Shared contract

- glTF 2.0 `.glb`, metre scale, Y up, origin at the ground, front face +Z, door on the front.
- PBR: base colour, normal, roughness, ambient occlusion. 2K for hero buildings, 1K for furniture.
- Separate named nodes for doors, windows, pub sign, garage doors and the phone box door.
- No readable text baked into meshes. The game puts names on signs with Label3D.
- No real brands, no real pub chains, no political slogans.
- Cottages 3,000 to 10,000 triangles; pub 8,000 to 18,000; garage and stores 5,000 to 12,000; furniture 500 to 3,000.
- LOD0, LOD1 and LOD2 for every building; the village is read from 60 m and from the street.
- Window glass should be dark and slightly reflective by day, warm by night.

## Priority 0: the buildings

| Asset | Description | Notes |
|---|---|---|
| `cottage_stone_a.glb` | two-storey limestone cottage, slate gable roof, two chimneys, sash windows, white sills, painted door | the base cottage, 9.5 x 8 m |
| `cottage_stone_b.glb` | one-and-a-half-storey stone cottage, lower eaves, small dormer | the older, lower cottage |
| `cottage_plaster.glb` | cream rendered cottage, dark timber door, slate roof | 8.5 x 7.5 m |
| `cottage_brick.glb` | red-brick cottage, white lintels, slate roof, small porch | 8 x 7 m |
| `pub_hollow_crown.glb` | two-storey stone pub, 15 x 10 m, hanging sign bracket, warm ground-floor windows, black rainwater goods, side gate to a small yard | THE HOLLOW CROWN, ale, food, rooms |
| `village_stores.glb` | 11 x 8 m single-storey stores with a shallow slate roof, timber shopfront, striped awning, produce boxes, noticeboard by the door | HALLOWAY STORES |
| `village_garage.glb` | 14 x 9 m red-brick garage, two roller doors, forecourt canopy, oil drum, tyre stack, hand-painted HALLOWAY GARAGE board | repair, not a chain |
| `bus_shelter.glb` | timber and glass shelter, 4 x 2.2 m, bench, parish noticeboard, timetable frame | blank timetable face |
| `phone_box.glb` | classic red K6 phone box, glass panes, crown, door ajar | no real telecom mark |
| `post_box.glb` | red pillar box on a small concrete base | no royal cipher |
| `village_noticeboard.glb` | glazed parish board with a pitched roof, 1.6 x 1.0 m | blank paper faces for the game |
| `village_gate.glb` | a five-bar timber field gate and a stile at the green edge | 3 m |

## Priority 1: street and green

- `village_lamp.glb` black cast-iron lamp column, 4.6 m, warm lantern.
- `village_bench.glb` timber slat bench with cast-iron ends.
- `village_bin.glb` black litter bin on a post.
- `village_bollard.glb` short painted bollard.
- `village_planter.glb` stone planter with winter pansies and ivy.
- `village_hanging_basket.glb` bracket and basket for the pub and stores.
- `village_signpost.glb` fingerpost: THE GREEN, STORES, GARAGE, FOOTPATH.
- `village_name_sign.glb` stone and painted board for HALLOWAY VILLAGE at the lane entry.
- `village_parking_sign.glb` small parking plate for the pub and stores.
- `village_kerb.glb` 2 m kerb and 2 m gutter sections, straight and curved.
- `village_pavement.glb` 2 m flagstone paving sections, worn and uneven.
- `village_dropped_kerb.glb` dropped kerb and tactile paving for the crossing.
- `village_bench_picnic.glb` picnic table on the green.
- `village_oak.glb` mature oak for the green, 8 to 10 m, broad autumn crown.
- `village_hedge.glb` clipped hedge, 2 m sections, dark green.
- `village_wall.glb` low limestone garden wall, 2 m and 4 m, with coping.
- `village_gate_garden.glb` small white timber garden gate and fence.
- `village_flowerbed.glb` low stone edging and a mixed border.
- `village_gravel.glb` gravel yard and driveway material cards.
- `village_lawn.glb` worn lawn and verge cards.

## Priority 1: props and life

- `village_car_a.glb` a dusty small hatchback, 1990s, parked outside the pub.
- `village_car_b.glb` an old estate car outside a cottage.
- `village_van.glb` a small white plumber's van by the stores.
- `village_bicycle.glb` a bicycle leaning on the pub wall.
- `village_milk_crate.glb` two crates by a doorstep.
- `village_bin_bag.glb` a tied bin bag by the bus shelter.
- `village_notice_paper.glb` a pinned paper and a drawing pin for the board.
- `village_chalkboard.glb` a pub A-board on the pavement.
- `village_dog.glb` optional, a small terrier on the green (no animation required).
- `village_robin.glb` optional, a robin on the hedge.

## Priority 2: finish

- A set of eight worn paint and plaster shaders: cream, white, sage, faded blue, dark green, black, oxide red, tar.
- A slate roof material with moss in the valleys and a wet sheen.
- A stone wall material with lichen, damp and mortar repairs.
- A red phone box material with chipped paint and dirty glass.
- A pub glass material: dark amber, warm pool of light at dusk.
- A village green grass patch with daisies, worn paths and a muddy edge.
- A lane mud and leaf card for the verges.

## Integration notes

- The village lane is a real road route from (286, 260) east to (455, 276); it joins the south lane at the existing junction.
- Lots are at the north row (z 242 to 245) and the south row (z 296 to 306), front doors facing the lane. The green is at (342, 274), the pub at (382, 299), stores at (414, 301), garage at (477, 306).
- The village bounds clear trees and are audited against the cemetery, the farm fields and the festival field. Do not add new buildings outside the bounds without telling session B.
- The game places signs and names with Label3D; keep every sign face blank.
- A pavement and kerb set should align with the lane curve, not float. The code version removed its temporary slabs because they read as floating; Claude's modular kerb sections should follow the route.
- Keep the front doors on the lane-facing side.

## Delivery

- Contact sheet per building: front, side, rear, roof and door detail.
- A street group shot from the west approach at 1.7 m and a 60 m aerial.
- Manifest with sizes, origins, node names, LODs, collision suggestions and texture channels.
- A note on any material that must be emissive for the dusk/night look.
- Foliage cards should work with the game's existing wind shader.

## What this unlocks

Priority 0 makes the town real and distinct from the cemetery. Priority 1 makes the street feel lived in. Priority 2 makes Halloway a place the player can photograph and remember at golden hour.
