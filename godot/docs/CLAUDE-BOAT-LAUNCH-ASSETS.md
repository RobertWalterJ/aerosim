# Claude boat launch asset brief: Halloway Lake

Status: production request, 2026-11-15. The lake end of the new launch lane now has a playable code placeholder: a gravel parking apron, a concrete ramp into the water, a short timber dock, a small aluminium boat, an empty trailer with a hull on the bunks, a timber sign and a life ring. This brief asks Claude for the real assets that replace those placeholders.

Owner of placement and code: session B. Claude handles the art only; integration stays on this lane. The tone is a working rural lake launch on an autumn morning, not a marina and not a horror scene.

## The place

The boat launch sits at the east shore of Halloway Lake at the end of a short asphalt lane off the lakeside road. The ground falls from the parking apron at about 84 m to the water at 76 m over roughly 30 m, so the ramp is a real slope. The dock runs north from the ramp head into deeper water. The car park is gravel with worn turning strips. The boat is small, old and cared for.

## Shared contract

- glTF 2.0 binary `.glb`, metre scale, Y up, origin at the base, +Z forward.
- Low poly: boat 1,500 to 3,000 triangles, trailer 1,000 to 2,000, ramp and dock 500 to 2,000, signs and small props 100 to 800.
- PBR kit materials and vertex colours, muted late-autumn valley palette.
- Separate named nodes for the ramp slab, curbs, dock deck, dock posts, floats, trailer frame, wheels, winch, boat hull, outboard, sign board and sign posts.
- Static poses. No rig.
- No gore, no people, no weapons, no text baked into meshes except the sign board lettering.
- Every asset should read at 1280 x 720 from a drone at 20 to 120 m and again from a person standing on the apron.

## Priority 0: the launch itself

| Asset | Description | Dimensions |
|---|---|---|
| `boat_ramp_slab` | concrete ramp with a grooved surface and a slight crown, stained at the waterline | 7 m wide, 30 m long, 0.25 m thick |
| `boat_ramp_curb` | left and right concrete curbs, weathered | 30 m long, 0.3 m wide, 0.25 m high |
| `boat_ramp_grooves` | transverse grooves or a texture-ready ramp face | optional separate mesh |
| `boat_parking_gravel` | gravel apron with two worn wheel-turn strips and a soft edge | 20 m by 13 m |
| `boat_dock_deck` | timber deck on posts, planks running along the dock | 2.4 m wide, 14 m long |
| `boat_dock_posts` | six weathered timber posts with iron caps | 3 to 4 m long |
| `boat_dock_floats` | white float boxes under the deck | 1.5 m by 0.4 m by 2.7 m |
| `boat_dock_cleats` | two iron mooring cleats | small |
| `boat_launch_sign` | two-post timber sign, cream board with a simple red border, no readable text in the model; the game adds the words | 3.1 m by 1.0 m |
| `boat_life_ring` | red and white life ring on the sign post | 0.9 m diameter |

## Priority 0: the boat and trailer

| Asset | Description | Notes |
|---|---|---|
| `boat_aluminium_hull` | small open aluminium boat, riveted, pale grey, bench seats, outboard | 3.6 m long, 1.4 m beam |
| `boat_outboard` | small tiller outboard, dark cowling | 0.5 m tall |
| `boat_trailer` | galvanised trailer, two wheels, bunks, winch post, hitch | 4.2 m long |
| `boat_trailer_winch` | hand winch and strap | small |
| `boat_trailer_hull` | the aluminium hull sitting on the trailer bunks, optional second instance | matches hull |

The scene uses one hull floating beside the dock and one on the trailer, so a single hull asset with colour variation is enough.

## Priority 1: working detail

- `boat_launch_bollards` two timber bollards at the ramp head.
- `boat_launch_wheel_stop` rubber or timber wheel stops at the apron edge.
- `boat_mooring_rope` coiled rope on the dock.
- `boat_fuel_tank` small portable tank on the dock.
- `boat_paddle` wooden oar leaning against the sign post.
- `boat_launch_marker` small white channel marker for the water edge.
- `boat_launch_bin` a plain bin and a notice board.
- `boat_launch_gravel_patch` loose gravel and tyre ruts at the lane end.

## Priority 2: atmosphere

- `boat_cover_tarp` faded blue cover, optional over the trailer hull.
- `boat_fishing_box` small tackle box and rod on the dock, no hooks visible.
- `boat_launch_gate` a simple wooden gate at the lane entrance, open.
- `boat_launch_weather_post` a small wind sock and a rain gauge on the sign post.
- `boat_launch_damage_decals` rust, algae, waterline marks and concrete cracks as decals or textures.

## Integration notes

- The code places the apron at `CaseObjects.BOAT_LAUNCH_SPOT`, the ramp from around x -436 to -466 at z 112, and the dock north of the ramp.
- The ramp surface must be a separate mesh so the game can follow the real terrain or a fixed slope.
- The boat launch is linked by the `launch` road route, the short lane from the lakeside lane.
- The launch is a named photo subject (`boat_launch`), so it should look good from the air as well as from the ground.
- The existing placeholder boat and dock are in `game/boat_launch.gd`; replace them by model references without changing the placement constants.
- No collisions are required for the first pass; add a simple trailer and sign collider only if the art pass makes them solid.

## What this unlocks

Priority 0 turns the placeholder into a believable working boat launch. Priority 1 gives it the small working detail that makes a place feel used. Priority 2 lets the lake launch become a photo subject and a quiet story location without any extra code.
