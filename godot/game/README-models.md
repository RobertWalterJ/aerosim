# New models (built by Claude, not DSH): the contract

DSH finds modelling hard, so all new 3D models for `SPEC-NEW-EXPERIENCES.md` are made first, by Claude, as code in
`game/new_models.gd` (class `NewModels`). DSH only wires them up. DSH must not model anything: if a model is wrong, write the
request in `LOGIC-NOTES.md` under "Requests for Claude" and carry on with the model that exists.

Each function returns an `ArrayMesh` (materials set; vertex colours used for variation) or a `Dictionary` of named meshes.
Scale is real metres; forward is -Z; up is +Y; the origin is the centre of mass (planes, birds) or the ground contact point (deer, balloon basket).

| Function | Returns | Notes |
|---|---|---|
| `NewModels.plane()` | `{"body": ArrayMesh, "prop": ArrayMesh, "prop_pivot": Vector3, "prop_radius": float, "prop_chord": float, "spin_sign": float, "camera": Vector3, "span": float, "length": float, "mass": float, "outline_plan": PackedVector2Array, "outline_side": PackedVector2Array, "plan": Array, "side": Array}` | FPV pod-and-boom plane, 1.104 m span, 1.06 m long, orange wing and white fuselage. **Pusher**: the motor sits on a pylon behind the wing, so `prop_pivot` (0, 0.1, 0.239) is behind the wing, not at the nose, and the nose camera sees no prop. `prop` (blades, folding yoke, spinner) spins about its own +Z: rotate by `spin_sign * omega * t` (spin_sign is -1). `prop_radius` and `prop_chord` feed the blur disc (turn the disc to face +Z). `camera` is the nose lens. `outline_plan` (x, z) and `outline_side` (z, y) are one merged silhouette each (shadow); `plan` and `side` are per-part outlines in the same format as `DroneView` records (chooser drawings). |
| `NewModels.bird(kind, flap)` | `ArrayMesh` (one surface, vertex colours, double-sided) | kind in `"goose"`, `"gull"`, `"starling"`, `"hawk"`; body and both wings in ONE mesh per pose. `flap` 0..1 is the wing cycle (0 top, 0.5 bottom, 0.5 to 1 upstroke with the hand folded back); 0.25 is a level glide pose. Bake `NewModels.bird_wing_pose_count()` (8) poses at flap k/8 into 8 MultiMeshes (or swap meshes per instance). Each pose is cached. `NewModels.bird_info(kind)` gives length, span, a rough flap rate (Hz) and the glide flap value. Triangles: goose 360, gull 360, starling 132, hawk 376. |
| `NewModels.balloon(scheme := 0)` | `{"envelope": ArrayMesh, "basket": ArrayMesh, "flame": Vector3, "flames": Array, "height": float, "width": float}` | hot-air balloon, origin on the basket floor. Envelope 21 m mouth to crown plus a 1.5 m skirt (22.5 m), 17.3 m wide, 16 gores with load tapes; scheme 0 (red, yellow, blue, green gores), 1 (red and yellow with a blue band), 2 (harlequin chevrons). Basket includes poles, burner frame, twin burner, gas cylinders and the cables up to the mouth. `flame` is the jet point above the burner (0, 2.62, 0); `flames` are the two burner outlets. 4584 triangles. |
| `NewModels.deer()` | `{"body": ArrayMesh, "body_flag": ArrayMesh, "head_up": ArrayMesh, "head_down": ArrayMesh, "height": float, "length": float}` | white-tailed doe (no antlers), origin at the ground between the feet, 0.95 m at the shoulder. Head meshes include the neck and are already placed in body space: draw `body` plus one head. `body_flag` is the body with the tail raised (white flag) for running. About 1200 triangles for body plus head. |
| `NewModels.firework_shell_proxy()` | `ArrayMesh` | a 6 cm aerial shell with lift cup and leader fuse, origin at the sphere centre. |
| `NewModels.barge()` | `ArrayMesh` | launch barge 12 x 5 m (long axis along z), origin at the waterline middle, deck 0.7 m up; two racks of 10 mortar tubes, rails, bollards, firing box, generator, red flag. One surface. `NewModels.barge_tubes()` returns 20 `[mouth, direction, base]` in barge space for launching shells. |

## Batch 2: `game/new_models2.gd` (class `NewModels2`)

Same rules: real metres, forward -Z, up +Y, one surface per material, vertex colours, every model cached after the first call. Moving parts are separate meshes with a pivot; turn them about the axis named below.

| Function | Returns | Notes |
|---|---|---|
| `NewModels2.barn()` | `ArrayMesh` | Red gambrel barn, 12 x 24 m (long axis along z), ridge 8.7 m, cupola and vane to 10.9 m. Origin: the ground at the middle of the footprint. Sliding double doors on a track on the front (-z) gable, hay loft door under a hay hood, smaller doors at the back, side windows, a person door on the +x side. **Textured** (models3): the mesh already carries `farm_material` surfaces: weathered red-painted 30 cm boards with the grain upright and the paint worn through in streaks (`"wood"`), white painted trim, corrugated galvanised roof with the corrugations from eave to ridge (`"roof"`), fieldstone foundation (`"stone"`), glass. Rain darkens and glosses it (`g_wet`), snow lies on the upper roof slopes (`g_snow`), cloud and drone shadows fall on it (`world_shade`). The game just adds the mesh. 1936 triangles, 4 surfaces. |
| `NewModels2.silo()` | `ArrayMesh` | Concrete stave silo with steel hoops and a galvanised dome, 5 m wide, 18 m high, chute on the -x side, blower pipe. Origin: the ground at its centre. **Textured** (models3): concrete staves in courses wrapped round it (`"concrete"`), galvanised dome, chute and pipe (`"galv"`), same rain, snow and shadows. 748 triangles, 2 surfaces. Put it beside the barn (for example 4 m off a long wall). |
| `NewModels2.farm_material(key)` | `ShaderMaterial` (cached) | The barn and silo materials (`game/shaders/farm.gdshader`), for other farm buildings: `"wood"` (vertex rgb = paint, alpha = paint left, 0 bare grey boards), `"roof"` (corrugated steel on flat faces, rgb tints it), `"stone"` (fieldstone), `"concrete"` and `"galv"` (wrapped round the model's y axis, radius 2.5 m). Textures at real size in the model's own axes (no UVs needed); see `assets/textures/README.md`. |
| `NewModels2.windmill()` | `{"tower", "cap", "sails": ArrayMesh, "sail_pivot": Vector3, "spin_sign": float, "sail_radius": float, "height": float}` | Dutch stage mill: tapered brick tower 16 m, gallery at 7.5 m, thatched cap with tail pole and capstan wheel, four sails 7 m long (8 m from the hub). Sails (models3): a bold lattice that reads at distance: eight 18 cm sail bars (`WM_BAR`), 20 and 16 cm hemlaths, a dark 44 cm leading-edge board, the cloth spread over the inner third of each sail (double-sided) and the rest rolled along the outer hemlath. Tower and cap are in the tower frame (origin: ground at the middle). Draw `sails` at `sail_pivot` (0, 17.3, -3.2) and rotate about its own +Z by `spin_sign * omega * t` (spin_sign -1: anticlockwise seen from the front). Cap and sails may yaw together about the tower's +Y. 2804 triangles in all. Distance check: `docs/realism/models/mills_distance.jpg` (before: `mills_distance_before.jpg`). |
| `NewModels2.wind_pump()` | `{"tower", "wheel", "tail": ArrayMesh, "wheel_pivot": Vector3, "head_pivot": Vector3, "spin_sign": float, "wheel_radius": float, "height": float}` | Farm water-pumping windmill, 12.0 m to the top of the wheel: lattice tower (models3: 12 cm legs, 8 cm rings, 4 cm braces), pump stand and stock tank. `wheel` (18 blades 19 to 42 cm wide, 3.6 m) spins about its own +Z at `wheel_pivot` (0, 10.2, -0.75). `tail` (gearbox, boom, vane) is in tower space; tail and wheel may yaw together about the vertical through `head_pivot`. 1792 triangles. |
| `NewModels2.freight_train(cars := 12)` | `{"locomotive", "boxcar", "hopper", "tanker", "flatcar", "flatcar_empty": ArrayMesh, "wheels": Dictionary, "wheel_axis": Vector3, "car_length": 16.6, "loco_length": 21.6, "consist": Array, "gauge": 1.435}` | Separate meshes for MultiMesh. Every mesh: origin at the top of the rail under its middle, front towards -z. **Locomotive (models4):** a six-axle road-switcher in the manner of an EMD SD40-2, plain dark blue and yellow, no marks: lofted hoods with rounded tops and sloped ends (low short hood with headlight and number boards, full-width cab with raked front, big windows and sun visors, long hood with the dynamic-brake blister and fan behind the cab, engine-room doors, exhaust stack, radiator section with three roof fans and side grilles), walkway with yellow handrails, corner steps, yellow pilots with black hazard chevrons and coupler pockets, ditch lights, bell, horn, rear sand box, fuel tank between two three-axle trucks (deep cast side frames, journal boxes, coil springs, brake cylinders and rod, a traction motor on every axle). 21.6 m over couplers, 4.52 m high, body with trucks 2488 triangles. Cars 16.6 m with three-piece two-axle trucks (side frames with columns and a three-spring nest, bolster, brake beams with shoes on the treads); bodies: boxcar 1102, hopper 1136, tank car 1166, flatcar with lumber 1000, empty flatcar 904 triangles. **Wheels are separate** (models4 rebuilt them to real proportions): `wheels[kind]` = `{"mesh", "mesh_mid", "mesh_far": ArrayMesh, "positions": PackedVector3Array, "radius": float}`. Each wheel is a thin steel wheel turned from the AAR profile: back of the flange 0.68 m from the centre line (back to back 1.36 m, inside the rail heads at 0.7175), flange 2.5 cm deep, coned tread 11.9 cm (11.1 cm at full radius), rim 15.5 cm wide, a 2.6 cm dished plate web and a hub; the axle runs through to roller bearings with turning end caps and three cap screws. Cars 36 inch (0.914 m) wheels, locomotive 40 inch (1.016 m, as on real road diesels). `mesh` (close, under about 25 m) 1652 triangles; `mesh_mid` (to about 80 m) about 520; `mesh_far` two six-sided discs, 48. Origin at the axle centre, axle along +X (`wheel_axis`): place one at each position and turn it about its own +X by `-distance / radius`. Wheels sit on y = 0, flanges 2.5 cm below. Close-ups: `docs/realism/models/loco_close.jpg` (locomotive, trucks, a lone wheelset) and `train_close.jpg`. `consist` is `[kind, z]` for the locomotive (z 0) and each car behind it (+z, middles 16.6 m apart). |
| `NewModels2.track_section()` | `ArrayMesh` | 20 m of single standard-gauge track along z (z -10 to 10): rails, 28 timber sleepers, ballast bed. Origin: rail top on the centre line, so cars sit at the same y as the track. The ballast foot is 0.62 m below: lift the piece 0.62 m above the ground. 388 triangles. |
| `NewModels2.helicopter()` | `{"body", "main_rotor", "tail_rotor": ArrayMesh, "rotor_pivot": Vector3, "tail_pivot": Vector3, "main_spin_sign", "tail_spin_sign", "rotor_radius", "tail_radius", "length": float}` | **models4:** light twin rescue helicopter of the EC135 / BK117 kind, red and white, no operator marks, body 11.2 m long, skids on the ground at y 0 (origin under the mast). Teardrop cabin with a see-through wraparound bubble windscreen and chin windows (a transparent glass surface; inside: lining, instrument panel with screens, glare shield, console, two seats, two pilots in helmets with arms to the controls, a cabin bench), hinged cockpit doors and a sliding cabin door on its rail, engine cowling with intakes and two exhausts, mast fairing, slim tail boom, stabiliser with end plates, fin and ventral fin, skids on arched cross tubes with steps, searchlight (emissive) under the nose, rescue hoist. `main_rotor` (4 blades with a cambered aerofoil, twist and swept tips, 10.2 m across) spins about its own +Y at `rotor_pivot` (0, 3.38, 0), clockwise from above (`main_spin_sign` -1). `tail_rotor` (2 blades, 1.94 m) spins about its own +X at `tail_pivot` (-0.3, 2.78, 6.72) on the left of the fin, about 5 times faster. 4242 triangles in all. Close-up: `docs/realism/models/heli_close.jpg`. |
| `NewModels2.airliner_far(gear := false)` | `{"mesh": ArrayMesh, "mesh_far": ArrayMesh, "length": 38.0, "wingspan": 33.95, "height": float, "gear": bool}` (**models4: now a Dictionary**, was a bare ArrayMesh) | Twin-jet narrowbody of the A320 / 737 class: 38 m long, round 3.96 m fuselage with a drooped nose, six dark cockpit windscreen panels, a dark row of cabin windows with gaps at the doors and overwing exits, grey belly and belly fairing; low wing (27 degree leading edge, about 25 at quarter chord, 5.1 degree dihedral, cranked trailing edge, root chord 7.2 m, tip 1.45 m) with flap-track fairings and blended winglets; two engines under the wings with intake lips, fans and spinners, core cowls and exhaust plugs; swept tailplane; tall swept fin with a dorsal fillet and rudder hinge, plain blue with a light blue band. White, no marks. Origin: middle of the fuselage at the wing root, nose -z. `gear` true draws the landing gear down (nose leg, two twin-wheel main legs, doors). `mesh`: 1780 triangles gear up, 2192 gear down, for anything nearer than about 2 km; `mesh_far` (304 triangles, gear up) beyond. Close-up: `docs/realism/models/airliner_close.jpg`. |
| `NewModels2.kite(kind := 0)` | `ArrayMesh` (one surface, double-sided) | 1 m across. 0: diamond kite with a 2.5 m tail of bows (58 triangles); 1: rainbow delta with keel and streamer (61). The sail faces -Z (towards the flyer); origin at the tow point. `NewModels2.kite_line()` is a 1 m cord along +Z from the origin (4 triangles): scale z to the line length and aim +Z at the flyer's hand. |
| `NewModels2.flag(scheme := 0)` | `{"pole": ArrayMesh, "cloth": ArrayMesh, "cloth_origin": Vector3, "cloth_size": Vector2, "grid": Vector2i, "schemes": int}` | **models4:** 9 m flagpole (to 9.18 m with the ball), origin at its foot: base plate with four bolts and a flash collar, satin aluminium shaft tapering in three sections with sleeve joints, the truck with its pulley, a gilded ball finial on a neck, the halyard down both sides of the pulley to a cleat on a plate at 1.2 m. 1010 triangles. `cloth`: 1.8 x 0.9 m (indexed, double-sided), a 40 x 24 grid (`grid`) plus extra lines at the hems and seams so colour edges stay crisp (2900 to 4800 triangles by scheme); slight pre-wave droop and ripple at rest (at most 6 cm deep). Same conventions as before: origin at its top hoist corner, x along the fly, y down, normal about +Z, UV.x 0 at the hoist to 1 at the fly (= x / 1.8), UV.y 0 top to 1 bottom; place it at `cloth_origin` (0.075, 8.85, 0). Canvas header at the hoist with two brass grommets and the hoist rope along the hoist edge, darker hems with stitching round the other edges, stitched seams between colour panels. scheme (none a real national flag, no text): 0 horizontal tricolour (plum, gold, teal), 1 orange centred cross on green, 2 crimson border round a cream field, 3 cream disc on maroon, 4 plain red; any int wraps (`schemes` is 5). Turn the whole flag about +Y so +X points downwind. Close-up: `docs/realism/models/flag_close.jpg`. |
| `NewModels2.debris_pieces()` | `Array` of 6 `ArrayMesh` | Plank (1.2 m), forked branch (1.5 m), roof shingle, leaf cluster, twig bundle, paper sheet; each centred on its origin, under 30 triangles, dark colours, double-sided. For tornado particles. |
| `NewModels2.funnel_tube(rings := 24, segments := 24)` | `ArrayMesh` (indexed, no material) | Unit-height tapered tube for the tornado and waterspout shaders: y 0 (radius 0.07) to y 1 (radius 0.5), the middle bowed 0.06 towards +X, no caps. UV.x round (seam repeated), UV.y up; normals outward. 1152 triangles at the defaults. Scale it in the game. |
| `NewModels2.funnel_ring_disc(segments := 48, inner := 0.55)` | `ArrayMesh` (indexed, no material) | Flat annulus in the x-z plane facing up, outer radius 1, for the spray ring at a waterspout's foot. UV.x round, UV.y 0 inner to 1 outer. 96 triangles. |

Batch 2 test: `test/new_models2_test.gd` (headless: finite, winding, budgets, real sizes; models3 adds the barn and silo shader and texture size, the sail cloths and bar width, the wheelsets on the gauge and the far-wheel budgets). Close views: `test/models3_views.gd` (`set=barn`: 8 m and 40 m, dry, wet and snow, `barn_views.jpg`; `set=mills`: 20, 60, 120 and 250 m; `set=train`: 3 m side and three-quarter). Sheet: `docs/realism/models/new_models2_sheet.jpg`, rendered by `test/new_models2_sheet.gd` (needs a window; `only=<title word>` renders a subset). models4 adds the wheel proportions (tread, rim, flange back to back, thin plate, 0.914 and 1.016 m diameters, the 1.435 m gauge), the locomotive budget (2500), the helicopter's see-through glass and rotor sizes, both airliner versions and its far mesh, and the flag cloth grid and UV. Close-ups: `test/models4_views.gd` (`set=loco|airliner|heli|flag`, needs a window) writes `loco_close.jpg`, `airliner_close.jpg`, `heli_close.jpg`, `flag_close.jpg`.

Materials are shared and cached inside `NewModels`; every model is built once and cached. The preview contact sheet is `docs/realism/models/new_models_sheet.jpg`; the test is `test/new_models_test.gd` (headless) and the sheet is rendered by `test/new_models_sheet.gd` (needs a window).


## Batch 5: farm pieces (`game/new_models3.gd`, class `NewModels3`; models5)

One entry point, because there are 26 models and each has three levels of detail: `NewModels3.mesh(name, lod := 0) -> ArrayMesh` (lod 0 near, under about 25 m; 1 middle, to about 80 m; 2 far). Meshes are built once and kept. `NewModels3.NAMES` lists every name. `NewModels3.colliders(name) -> Array` gives AABB box strips (model frame) for fences and hay, empty for crops, weeds and ground. `NewModels3.TILE[name]` (x, z) is the repeat size of what is laid side by side. Real metres, forward -z, up +y, origin on the ground. Materials are `ShaderMaterial`s (`game/shaders/farm_props.gdshader` for fences, hay and ground; `game/shaders/farm_plant.gdshader` for crops) that read the vertex colour as the finish. Do not swap their materials for a plain colour: the photographed sets, wind and shadows live in them.

| Name | Size and layout | Notes (triangles near / middle / far) |
|---|---|---|
| `fence_post_rail_a` | post at x = 0, three round rails run to x = 3; 1.3 m high | grey weathered posts with a chamfered top and a split; 130 / 60 / 40 |
| `fence_post_rail_b` | square posts and four horizontal boards with nail heads; 1.35 m | dark brown; 75 / 70 / 35 |
| `fence_post_rail_c` | slim leaning posts, two rustic poles crossing the post | pale silver-grey; 95 / 65 / 25 |
| `fence_wire_a` | wood end post, steel T-post at x = 1.5, four sagging strands, barbs on the top one | 230 / 100 / 30 |
| `fence_wire_b` | woven wire panel 0.8 m with two strands above, posts at 0 and 1.5 | 380 / 190 / 70 |
| `fence_gate_a` | hinge post x = 0, latch post x = 3, galvanised pipe gate 3 m between | five bars, three uprights, diagonal brace; 300 / 210 / 110 |
| `fence_corner_a` | corner post at the origin, sections run +x and -z, a strut and a diagonal brace on each leg | 345 / 235 / 125 |
| `fence_broken_a` | leaning end post, snapped top rail, a middle rail dropped to the grass | 140 / 95 / 60 |
| `hay_round_a` | round bale on its side (axis x), 1.2 m across and wide; pale plastic wrap with hay showing at the ends | smooth barrel; 900 / 120 / 24 |
| `hay_round_b` | the same, unwrapped net-bound hay | |
| `hay_roll_a` | 1.5 m round roll, 1.2 m wide, tight straw | |
| `hay_square_a` | 0.9 x 0.45 x 0.35 m (x, z, y), gold hay with orange twine | 68 / 32 / 12 |
| `hay_square_b` | same size, older grey-brown hay, green twine | |
| `hay_stack_a` | 1.8 x 1.8 m footprint, 1.4 m high, four layers (8, 8, 4, 2 bales) crossed and a little off true | 650 / 240 / 36 |
| `corn_stand_a` / `corn_stand_b` | a clump of 4 / 5 stalks 1.9 to 2.6 m, green summer / ripening; arching folded leaves, cob with husk leaves and silk, tassel | about 2000 / 130 / 18 |
| `corn_row_chunk` | 4 m of one row along z (z -2 to 2, leaves overhang to about 2.5), stalk about every 0.4 m; tiles end to end at 4 m | 3000 / 320 / 14 |
| `barley_patch_a` / `_b` | 0.5 m wide, about 0.8 m high: folded blades, stems and heads with awns; a ripening green-gold, b ripe gold, heads drooping | 1100 / 470 / 18 |
| `alfalfa_patch_a` / `_b` | 0.5 m wide, 0.5 m high; trifoliate leaves; b in purple flower | 1500 (2200) / 480 / 18 |
| `crop_edge_weeds` | 1.2 x 0.5 m margin strip, up to 1.1 m: tall grass, cream umbels, goldenrod, dock | 1200 / 60 / 18 |
| `field_furrow_a` | tilled soil in ridges 0.76 m apart along z, 3.04 x 4 m, ridges 0.2 m high; tiles on both axes | lowest point about 0.01 m: lay it at the ground height; 2560 / 640 / 64 |
| `field_furrow_b` | freshly ploughed, slices 0.45 m apart along z, 3.15 x 4.2 m; tiles on both axes | 3500 / 880 / 330 |
| `field_headland_a` | 6 x 3 m turn row, flat packed soil with two tyre ruts swinging in an S, grass at the long edges; tiles along x | 1600 / 400 / 36 |
| `field_track_a` | 2.6 x 8 m two-rut mud track, ruts 1.7 m apart holding wet shine; tiles along z | 2400 / 600 / 32 |

How the finish works: the vertex colour carries the tint, and its alpha carries the grain direction (wood and hay: 1 up, 0.75 along x, 0.5 along z, 0.25 none) or, on a leaf, the way across the blade for veins and the pale midrib. Plants sway with `g_wind` (taller more), flutter at the leaf edge, lean away from the rotor downwash and take a per-field colour from where they stand. Fences, hay and soil darken and shine in rain (`g_wet`) and take snow and the cloud and drone shadows. Instancing: use a `MultiMesh` per model per level of detail; the plants' per-field colour reads the instance's world origin.
Test: `test/new_models3_test.gd` (headless; finite, winding, budgets that must fall from near to far, real sizes, colliders inside their model, tiles whose edges meet, rebuilds identical, shaders and textures present). Sheets: `test/new_models3_sheet.gd` (needs a window; `set=fences|crops|ground`, `light=golden|overcast`) writes `docs/realism/models/new_models3_<set>_<light>.jpg`.

## Batch 7: farm animals, boats and the lake shore, farm machinery and yard, wire and gate (`game/new_models5.gd`, class `NewModels5`; models7)
Written for session B's request of 2026-10-23 21:08 (items 3 to 6). 31 models, each in three levels of detail. Real metres, forward is -z, up is +y. The test (`test/new_models5_test.gd`) prints every size and triangle count; the tables below are its numbers.

Entry points:
- `NewModels5.mesh(name, lod := 0) -> ArrayMesh` the whole model (lod 0 near, under about 25 m; 1 middle, to about 80 m; 2 far).
- `NewModels5.parts(name, lod := 0) -> Dictionary` the movable parts: `{part: {"mesh": ArrayMesh, "pivot": Vector3}}`. Each part's mesh is drawn about its own pivot, so put a `MeshInstance3D` for it at `pivot` (in the model's frame) and turn that node. `"body"` is always there (pivot at the origin). The parts always add up to exactly `mesh()` (do not draw both).
- `NewModels5.colliders(name) -> Array` box strips (`AABB` in the model's frame), for the animals only.
- `NewModels5.NAMES`.
Test hook for looking at them in the real scene: the screenshot token `props5animals`, `props5cows`, `props5farm` or `props5lake` (see `game/gallery5.gd`); fly to them with `at<x>_<up>_<z>_<yaw>_<gimbal>`.

### Animals: shell fur (`game/shaders/fur.gdshader`; the hen uses `farm_coat.gdshader` with scalloped feathers)
The body, head and jaw wear the **fur shader**: the mesh is drawn once as skin and then again in a stack of shells (16 near, 6 middle, none far on a desktop; 6 / 3 / none on a phone: `NewModels5.fur_shells(lod)`), so the coat has a soft hairy outline. Strands thin toward the tip, roots are darker and in shadow, two Kajiya-Kay highlights run along the hair, sunlight shines through thin strands when you look into it, markings (the Holstein patches) come from a noise on the model's axes, sheep wool is clumped curls with a photographed curly-pile texture (Poly Haven, CC0) for its fibre relief, dirt and lanolin, and rain, snow, wind (`g_wind`) and the cloud and drone shadows all act on it. Vertex alpha is how much fur there is (full on the body, short on a sheep's face and legs, 0 on a hoof, about 0.07 for bare wet skin such as a muzzle). **Use level of detail by distance: lod 0 inside 8 m, lod 1 to 25 m, lod 2 beyond** (at a drone's usual distance one strand is far smaller than a pixel, so the shells fade to a plain coat there). Anatomy note: lane/animals (Opus, Blender) is rebuilding the animal bodies; carry this shader over to those meshes by giving them the vertex colour and alpha described above (`NewModels5._fur_chain(key, lod, part_offset, leg_height)` builds the chained materials).
Each animal here is a smooth body: ellipsoids and round cones blended in a distance field, then meshed, so the neck grows out of the shoulders and the thigh melts into the flank. Eyes are glossy, noses are wet skin, hooves are dark horn. Parts: `head` (pivot at the poll; nod and turn it about this point), `jaw` (pivot at its hinge; chewing is a few degrees about x), `tail` (pivot at the tail head; swish about y or x), `body`. The chicken has `body` and `head` (neck and head, pivot at the neck base: peck by turning about x).

| Name | What it is | Size (x wide, y high, z long; metres) |
|---|---|---|
| `cow_a` | Holstein, white with black patches, udder, standing, head lowered a little | 0.9 x 1.6 x 3.1 |
| `cow_b` | Hereford, chestnut with a white face, belly and socks, grazing (head down) | 0.9 x 1.5 x 3.0 |
| `cow_c` | Jersey, fawn, lying down chewing the cud, head up and turned | 0.8 x 1.2 x 3.0 |
| `calf_a` | Holstein calf, standing, big head, long legs | 0.5 x 0.9 x 1.9 |
| `sheep_a` / `sheep_b` | ewe in thick wool; a white face standing alert / a black face grazing | 0.6 x 0.8 x 1.3 |
| `lamb_a` | lamb, a little over half the ewe | 0.3 x 0.5 x 0.8 |
| `horse_a` / `horse_b` | a bay standing, black mane and tail / a chestnut grazing, flaxen mane, white socks | 0.6 x 1.9 (1.6 grazing) x 2.8 |
| `dog_a` | a farm dog, black and white, standing, tail down with a curl | 0.3 x 0.7 x 1.0 |
| `chicken_a` | a Rhode Island Red hen standing, comb and wattle, scaled yellow legs | 0.23 x 0.47 x 0.6 |

Origin is the ground under the animal (lowest point within 0.05 m); an animal faces -z. Colliders: one box for the body and one for the head on the cattle and horses.

### Boats, jetty and lake shore (`farm_paint.gdshader` for paint, glass-fibre and metal; the NewModels3 photographed wood for planks and piles)
Origin is the waterline for everything that floats: the hull hangs below y = 0, so place it at the lake level (76.0 m). The jetty is the same: its deck is 0.6 m above y = 0 and its piles go down to -1.6 m.

| Name | What it is | Size |
|---|---|---|
| `rowboat_a` | clinker dinghy, white strakes, varnished inside, thwarts, floorboards, ribs, two oars, a rope; bow at -z | 1.6 x 0.8 x 4.2 |
| `sailboat_a` | 4.2 m single-handed dinghy: glass-fibre hull and deck, cockpit, mast, boom, a bellied mainsail with a red number, rudder and tiller | 1.2 x 6.3 x 4.4 |
| `sailboat_b` | 7.6 m cruising sloop: white hull with a blue stripe and red antifouling, cabin with windows, teak cockpit, wheel, mast, boom, main and jib, stays, fin keel | 2.6 x 11.7 x 7.6 |
| `fishing_boat_a` | 6.8 m workboat: blue hull with white top, planked deck, wheelhouse with windows, mast and derrick boom, floats, crates, net, tyre fenders | 2.5 x 5.0 x 6.8 |
| `jetty_a` | timber pier 8.4 m by 2.2 m: boards with gaps, stringers, round piles (some taller), diagonal braces, two iron cleats, a rope coil, a ladder at the end. Starts at the origin and runs out along -z | 2.6 x 2.6 x 8.4 |
| `mooring_post_a` | timber bollard 0.97 m high with four turns of rope, a loose end, an iron ring (origin at the foot) | 0.6 x 1.0 x 0.9 |
| `buoy_a` | red and white channel buoy, half below the waterline, steel cage and a lamp, a chain going down | 0.9 x 3.2 x 0.9 |

### Farm machinery and yard (`farm_paint.gdshader`: clear coat on new paint, chalking, rust, rubbed-bare scratches and dried mud on the lower parts; `farm_props.gdshader` for wood and steel)
| Name | What it is | Size |
|---|---|---|
| `combine_a` | grain combine: green body, glazed cab, grain tank, folded unloading auger, big front and small rear wheels with lugs, a 6 m header with cutter bar and a turning reel. Parts: `body`, `reel` (pivot on the reel axis, spin about x) | 6.2 x 4.6 x 9.4 |
| `baler_a` | towed round baler: red chamber, pickup reel with tines, tailgate, twine box, two wheels, drawbar and jack | 3.2 x 2.5 x 4.9 |
| `plough_a` | four-furrow mounted plough: angled red beam, headstock, four bodies with twisted polished mouldboards, shares, a depth wheel | 1.2 x 1.6 x 4.9 |
| `seed_drill_a` | 3 m coulter drill: hopper with lid, 14 coulter discs, seed tubes, press wheels, drawbar, two wheels | 3.5 x 1.8 x 4.3 |
| `water_trough_a` | galvanised trough 2.0 m, water in it (reflective), rolled rim, float valve, a hose | 2.4 x 1.0 x 1.2 |
| `feed_rack_a` | timber hay rack on legs with a V of slats and hay in it | 2.4 x 1.5 x 1.3 |
| `wood_pile_a` | stacked firewood, about 120 split logs with bark sides and pale cut ends, two stakes | 2.6 x 1.3 x 0.7 |
| `oil_tank_a` | farm fuel tank on cradles: domed ends, filler cap, gauge, tap and hose | 1.2 x 1.6 x 2.7 |
| `grain_silo_a` | small galvanised corrugated bin, cone roof and vent, ladder, door, concrete ring | 3.5 x 5.3 x 3.5 |
| `chicken_coop_a` | timber henhouse on stilts, pitched steel roof, ramp, pop door, nest box with a lid | 2.3 x 2.4 x 2.2 |
| `dog_kennel_a` | painted timber kennel, gable roof, arched door with trim | 1.2 x 1.5 x 1.5 |
| `telegraph_wire_10m` | one span of wire, 10 m along +x from the origin, sagging 0.35 m; hang many from the pole insulators (4 sides, 5 mm) | 10 x 0.36 x 0.01 |
| `fence_gate_hanging_a` | a five-bar timber field gate hung on a round post and swung open 50 degrees, galvanised hinges and latch | 2.4 x 1.7 x 2.8 |

Origin: the ground (the lowest point is within 0.1 m of y = 0 for everything on land).

What is honest about the look: the fur shading is real (see the sheets), but the animal anatomy is a code-drawn stand-in: heads are the weakest part (a cow's head is a rounded wedge), legs are plain tubes with joint bumps, the dog and horse bodies are too heavy; the boats and the jetty, wood pile, feed rack, silo, oil tank and mooring post are the closest to photographic. The sails are plain cloth with a belly. Thin things (wire, rigging, fence rails far away) will shimmer; use lod 2 beyond 80 m.
Test: `test/new_models5_test.gd` (headless; finite, winding, budgets that fall from near to far, real sizes, parts that add up to the whole and have sensible pivots, colliders inside their model, rebuilds identical, materials and shaders present). Contact sheets: `docs/realism/models/new_models5_*_{golden,overcast}.jpg` from `test/new_models5_sheet.gd`.

## Batch 6: road vehicles and roadside furniture (`game/new_models4.gd` with `new_models4_big.gd` and `new_models4_props.gd`; class `NewModels4`; models6)

Real metres, forward -z (a vehicle's front, a sign's face), up +y, origin on the ground in the middle of the vehicle's length. Three levels of detail everywhere (lod 0 near, under about 25 m; 1 middle, to about 80 m; 2 far). Everything is built once and kept. Finish: every surface is a `ShaderMaterial` of `game/shaders/vehicle.gdshader` (clear-coated car paint with metallic flake, wear, rust and road dirt on the lower panels; rubber; chrome and aluminium; reflective glass; trim plastic; glowing lamp lenses; painted sheet; concrete), or the farm wood and galvanised-steel materials of batch 5 for poles, gates and signs' backs. The vertex colour is the finish and its alpha is how worn it is (1 clean, lower dirtier and rustier). Do not swap in plain materials: the paint, glass and dirt live in the shader. Rain (`g_wet`), snow (`g_snow`) and the cloud and drone shadows act on all of it.

Entry points:
- `NewModels4.NAMES` lists every model. `CARS`, `BIG` (the farm and heavy vehicles) and `PROPS` split it.
- `NewModels4.mesh(name, lod := 0, paint := Color(0, 0, 0, 0)) -> ArrayMesh`: the whole model as one still mesh, wheels in place. `paint` is the body colour in sRGB (transparent black = the model's own). `NewModels4.PAINTS` is a palette to pick from; each colour is built once and cached, so use a handful.
- `NewModels4.vehicle(name, lod, paint) -> Dictionary` for the cars, pickups, vans, tractor, trailer, tanker, bus and motorcycle: `"body"` (ArrayMesh without wheels), `"wheels"` (Array of `{"name", "pos" (hub centre in the model frame), "radius", "steer" (true on the front wheels), "mesh"}`), `"size"` (Vector3 m), `"wheel_radius"`, `"track"` (distance between left and right hubs), `"wheelbase"`, `"colliders"`. A wheel mesh is made for its own side, with its axle along local x through the origin: spin it with `rotation.x -= distance / radius` for either side. A front wheel steers by turning its pivot about y.
- `NewModels4.build_node(name, lod, paint) -> Node3D` is the easy way: a `Body` MeshInstance3D and one pivot Node3D per wheel named `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr` (tractor and tanker also `wheel_a*`, `wheel_b*`; the motorcycle `wheel_f`, `wheel_r`) holding a `Wheel` MeshInstance3D. Steer by turning the pivot, roll by turning its `Wheel` child about x.
- `NewModels4.colliders(name) -> Array` box strips (AABB, model frame) for everything a drone can hit.
- `NewModels4.attachments(name) -> Array` of Vector3: where a wire hangs (the insulator tops of `telegraph_pole_a/b` and the insulator strings of `power_pylon_a/b`), so a wire mesh can span from model to model.

| Name | Size and layout |
|---|---|
| `car_hatch_a` | 4.0 x 1.72 x 1.46 m supermini, alloy wheels, silver |
| `car_hatch_b` | 4.3 x 1.80 x 1.45 m hatchback, alloy wheels, red, some wear |
| `car_estate_a` | 4.7 x 1.82 x 1.5 m estate with roof rails, dark blue-grey |
| `pickup_a` | 5.3 x 1.98 x 1.82 m full-size pickup, open bed, blue |
| `pickup_b` | 4.9 x 1.82 x 1.7 m older compact pickup, steel wheels, sun-faded and rusty |
| `van_a` | 5.3 x 1.98 x 2.1 m panel van, white, rear doors with windows |
| `van_b` | 4.4 x 1.8 x 1.9 m small van, blue, blank rear doors |
| `tractor_a` | 4.7 x 2.4 x 2.95 m cab tractor, lugged tyres, 3-point linkage and PTO; front wheels steer |
| `tractor_wheels_a` | the tractor's four wheels in place as one mesh (stand-in); the wheels as parts are in `vehicle("tractor_a")` |
| `tractor_trailer_a` | 6.6 x 2.4 x 2.05 m tandem-axle farm trailer, hitch eye at -z |
| `milk_tanker_a` | 9.4 x 2.5 x 3.4 m rigid tanker: cab, stainless tank, manways, ladder, six wheels |
| `bus_a` | 10.6 x 2.5 x 3.2 m single-decker, door on the +x side, blank destination board, cream with a red band |
| `motorcycle_a` | 2.1 x 0.8 x 1.35 m naked motorcycle, no rider |
| `telegraph_pole_a` | 8.6 m wooden pole with a four-pin crossarm and a top pin; wires along x |
| `telegraph_pole_b` | 10.4 m distribution pole, three-pin crossarm, pole-mounted transformer |
| `power_pylon_a` | 36 m steel lattice tower, three tiers of arms, glass insulator strings; wires along x |
| `power_pylon_b` | 19.5 m tubular steel monopole, three tiers of arms |
| `road_sign_bend_a` / `road_sign_junction_a` | yellow warning diamonds on a galvanised post, 2.3 m to the centre; face toward -z |
| `road_sign_speed_a` | white regulatory sign reading 60, on a post |
| `road_marker_a` | 1.1 m white roadside post with a black band and an amber reflector |
| `cattle_grid_a` | 3.6 x 2.4 m steel-bar grid over a pit, concrete sills; lay it flush with the road (top at y = 0) |
| `field_gate_a` | 3.6 m timber five-bar gate hung on two posts (x = 0 and 3.6) |
| `field_gate_b` | 3.8 m galvanised livestock gate on tubular posts (x = 0 and 3.8) |
| `bus_shelter_a` | 3 x 1.4 x 2.5 m shelter, glass back and ends, bench, timetable case, stop sign pole |
| `post_box_a` | roadside rural mailbox on a wooden post, flag up |
| `road_works_a` | striped barrier, four cones, a blank orange warning sign |
| `milestone_a` | 0.9 m stone post with a white face reading 12 |
| `road_bridge_rail_a` | 4 m of bridge parapet along +x: kerb, three steel posts, two rails |

Tests: `test/new_models4_test.gd` (headless; finite, winding, budgets that must fall from near to far, real sizes, wheels named, on the ground and facing outward, colliders inside, wire attachment points on the poles, rebuilds identical). Sheets: `test/new_models4_sheet.gd` (needs a window; `set=cars|big|props`, `light=golden|overcast`, `only=<word>`, `cell=WxH`, `cols=N`, `views=N`). In the game's own sky and haze: screenshot token `models4demo:<name>+<name>` (see `game/model_demo4.gd`).


## Batch 8: the story assets (`game/new_models6*.gd`, `StoryAssets`; models8)

The Lake Car and Halloway (brief: `docs/story/CLAUDE-NARRATIVE-ASSETS.md` on lane/notify). One entry point per use:
- **In the game:** `StoryAssets.place(parent, name, Transform3D, lod := 0) -> Node3D` or `StoryAssets.instance(name, lod)`. It loads the exported glTF from `assets/models/story/<group>/<name>.glb` (`_lod1`, `_lod2` for the bus), gives the nodes back the farm kit's photographed materials (the file carries plain vertex-colour stand-ins whose material names are the kit keys: `wood`, `paintwood`, `brick`, `roof`, `stone`, `concrete`, `steel`, `paint`, `gloss`, `sheet`, `cloth`, `canvas`, `tarp`, `rubber`, `skin`, `fur`, `leather`, `enamel`, `chrome`, `glass`, `lamp`, `warm`, `flame`...) and falls back to building from code if a file is missing. `NewModels6.names()` lists every asset, `NewModels6.group_of(name)` its folder (`characters`, `camp`, `festival`, `halloway`, `evidence`, `reward`), `NewModels6.colliders(name)` AABB hulls.
- **Frame (the story brief's, not the older batches'):** metres, Y up, **+Z is the front**, origin at the base. The model's right-hand side is -x. One root node named after the asset, a `body` mesh, then named children: `wheel_fl wheel_fr wheel_rl wheel_rr` (spin about x at the axle), `door` (pivot at the hinge), `destination_board`, `headlamp_glass`, `interior_light`, `lamp_glass`, `blue_lamp`, `window_light` (the lit panes, hide by day), `card_stand`, `flame`, `steam`, `bulbs`, `roller_door`. Collision comes from `hullN-colonly` boxes (Godot's importer makes a StaticBody3D): the bus, buildings, benches, barriers and larger props; none on people, dogs, cloth, bunting or camp soft goods.
- **Lettering** is real geometry (a 5 x 7 block alphabet in `new_models6.gd`: `HALLOWAY FESTIVAL`, `VOSS & SON`, `MOTOR WORKS`, `HALLOWAY PROVINCIAL POLICE`, `VILLAGE HALL`, `THE PLOUGH`, `HALLOWAY STORES`, `MOTOR PARTS`...), all fictional.
- **Regenerate:** `Godot --headless --path godot -s res://tools/export_story.gd [-- only=<name prefix>]` writes the .glb files and the two 2D pieces (`reward/livery_voss_son_decal.png`, `reward/casebook_badge_voss.png`). Checks: `test/story_probe.gd` (headless: triangles and sizes), `test/story_sheet.gd` (contact sheets, golden and overcast), `StoryAssets.dev_row` through the game's `story<distance>_<name>+<name>` shot token (the assets in the real scene with the real lighting).

### Batch 5b: photoreal pass on the farm pieces (models5b)
Same names, same sizes and colliders; what changed is how they look and what the triangle budgets are.
- **Crops, middle and far levels are leaf cards, not blocks.** `corn_stand_*`, `corn_row_chunk`, `barley_patch_*`, `alfalfa_patch_*` and `crop_edge_weeds` at lod 1 and 2 are standing quads cut out by drawn plant textures (`assets/textures/cards/*.png`, made by `test/gen_card_textures.gd`; r light, g stem, b accent, a cut-out) through `farm_plant.gdshader` kind 2. The row chunk adds a flat canopy quad (kind 3) so a field seen from above reads as rows of leaves. Texture coordinates come from the vertex position, so the quads carry no UVs. Cards are the size of their texture tile (corn 1.0 x 2.35, barley 0.55 x 0.8, alfalfa 0.5 x 0.5, weeds 0.9 x 0.8 m): scale a whole instance, never one card.
- **Near corn** (lod 0) has longer leaves with a wavy margin and a ripple along the blade, more segments, the translucency turned down (no cream glow) and wrapped diffuse lighting so low sun does not leave the far side black.
- **Hay (lod 0):** loose stalks stand out of the bales and fray at the cut ends, net lines on `hay_round_b`, rope rings on `hay_roll_a`, the raised overlap lips and gathered ties of the film on `hay_round_a`. Budgets near: round bales 3000, standalone square bales 1100 (the stack is unchanged). Bounds are a little larger (loose straw).
- **Fences (lod 0):** soil collar at each post, three cracks and lichen patches, staples on wire posts, strands of wire with ten segments so the sag is a curve.
- `game/farm_demo.gd` places a patch of all of it in the real scene: screenshot token `farmdemo<x>_<z>` in `game/main.gd` (put it after the `at...` token).


## Batch 9: storm and tornado assets, then the endgame props and cabin (models9; `game/new_models7*.gd`)

Same loader and frame as Batch 8: `StoryAssets.place(parent, name, Transform3D, lod := 0)` loads `assets/models/story/<group>/<name>.glb` (groups `storm`, `cabin`, `gear`), gives the nodes the farm kit's photographed materials back by name, and falls back to building from code. Metres, +Z front, origin at the base. **Debris pieces are centred on their own origin** (for the tornado MultiMesh). Three material keys are new in the exported files: `soil`, `mud`, `hay` (the farm_props photographed sets), plus the plain `water` and `steam` (translucent). Regenerate: `Godot --headless --path godot -s res://tools/export_story.gd -- only=<prefix>`; check: `test/story_probe.gd` (triangles and sizes), `test/story_load_test.gd` (every exported file loads with its named nodes), `test/story_sheet.gd` (contact sheets, `cols=` and `views=1` for a one-view grid).

### Storm (group `storm`; `new_models7_storm.gd`, `new_models7_archive.gd`)
- **Debris, centred (0.3 to 3 m):** `storm_debris_plank_a` `_plank_b` `_roof_sheet_a` (real corrugation, 76 mm pitch) `_shingles_a` `_branch_a` `_fence_a` `_tin_a` `_barrel_a` `_sack_a` `_leaves_a`.
- **Damage props:** `storm_barn_panel_a` (collider) `storm_tree_fallen_a` (colliders) `storm_fence_broken_a` (colliders) `storm_scoured_patch_a` `storm_post_uprooted_a` `storm_sign_twisted_a`.
- **Buried shelter:** `storm_shelter_hatch_closed_a`, `storm_shelter_hatch_open_a` (node `hatch`, pivot on the hinge edge; collider on the surround) `storm_shelter_steps_a` (origin at the top step, +Z leads down) `storm_shelter_wall_a` (collider) `storm_shelter_debris_a` (5 x 5 m spread).
- **Archive:** `storm_weather_station_a` (nodes `cups`, `vane`: spin them) `storm_rain_gauge_a` `storm_glass_a` `storm_barometer_a` `storm_diary_a` `_open` `storm_archive_box_a` `storm_drawing_a`. The festival programme is `camp_programme_a`.
- **Priority 1:** `storm_bell_a` and `storm_bell_a_knotted` (nodes `bell` swings about the axle at y 2.0, `rope` hangs from the wheel rim) `storm_lantern_a` (node `flame`) `_off` `storm_coat_post_a` `storm_logbook_a` `_open` `storm_map_a` `storm_sandbags_a` `storm_tarp_a`. The railway signal lamp is `railway_signal_lamp_a`.
- **Priority 2:** `storm_shelter_interior_a` `storm_chapel_interior_a` (node `window_light`) `storm_rail_hut_a` (collider) `storm_ditch_flooded_a` `storm_power_line_a` (dead, with a cone) `storm_sign_damaged_a` (node `board`) `storm_crowd_watching_a` `storm_crowd_sheltering_a` (placeholder figures, being replaced).

### Endgame props and cabin (groups `cabin` and `gear`; `new_models7_cabin.gd`, `new_models7_interior.gd`, `new_models7_gear.gd`)
The people (Wren, Constable Rennick in 1984, the ghost variant) and the vehicles (`cruiser_1984_a` and its open variants, `anne_car_wreck_a`, `anne_car_door_a`, `police_dive_van_a`, `police_boat_a`) are made by the people and vehicles lanes; their names from `docs/story/CLAUDE-ENDGAME-ASSETS.md` are kept so their files drop into `assets/models/story/`. Everything else from that brief is here.
- **The cabin:** `cabin_abandoned_a` and `cabin_abandoned_a_broken_roof` (8 x 6 m weatherboard hut, 4.2 m to the ridge, hollow so the interior fits inside; lod 0, 1, 2; nodes `door` (hinge at the left jamb), `windows` (glass), `window_light` (warm panes, hide by day); colliders on the body and the porch deck) `cabin_door_a` `_ajar` `_open` (node `door`) `cabin_window_a` `_lit` `_cracked` `cabin_chimney_a` `cabin_porch_light_a` `_off` (node `bulb`) `cabin_woodpile_a` `cabin_lean_to_a`.
- **Cabin yard:** `cabin_fallen_tree_a` (colliders) `cabin_tyre_ruts_a` `cabin_fence_broken_a` `cabin_old_sign_a` (THE OLD PLOT) `cabin_yard_tools_a` `cabin_radio_aerial_a` `cabin_search_flag_a` `search_tape_a` `cabin_chimney_smoke_a` (a smoke plume and a node `glow`).
- **Interior set** (no colliders): `cabin_bed_a` `_stripped` `cabin_table_a` `cabin_chair_a` `_b` `cabin_stove_a` `_lit` (nodes `door`, `flame`) `cabin_shelf_a` `cabin_radio_a` `cabin_radio_handheld_a` `cabin_case_file_a` `cabin_calendar_a` `cabin_uniform_a` `cabin_boots_a` `cabin_lantern_a` `_off` `cabin_kettle_a` (node `steam`) `cabin_drawing_a` `cabin_map_a` `cabin_hiker_gear_a`, and two arrangements: `cabin_interior_set_a` (everything laid out in the cabin, floor at y 0.35) and `cabin_interior_variant_a` (a smaller 4 x 3 m room with its own walls). Things that hang on a wall have their origin at the bottom edge and face +Z.
- **Gear:** `thermal_pod_a` (52 x 42 x 62 mm, origin at the mounting face, top flat; node `led`) `thermal_pod_led_a` `_off` `thermal_pod_mount_a`; `lake_buoy_a` `dive_marker_a` (waterline at y 0, line and weight hang below) `anne_photo_a`; `cruiser_plate_a` `cruiser_lightbar_a` (nodes `lightbar_red`, `lightbar_blue`: swap in the `lamp_red` and `lamp_blue` materials to light them) `cruiser_aerial_a` `cruiser_door_lettering_a` `cruiser_boot_kit_a` `cruiser_old_kit_a`; `wren_backpack_a` `wren_phone_a` `wren_torch_a` (node `beam`) `_off` `wren_space_blanket_a` `_b` `wren_water_bottle_a` `wren_hiking_gear_a` `wren_tent_a`; `rennick_hat_a` `rennick_case_file_a` `rennick_portrait_a`; `cabin_thermos_a` `cabin_newspaper_a`.
- **Textures used:** `docs/realism/models/storm_endgame_final_textures.jpg` (labelled swatches: name, Poly Haven source, author, licence, where used), built by `test/story_textures_sheet.gd`; views of every asset: `storm_endgame_final_views.jpg` (golden hour) and `storm_endgame_final_views_overcast.jpg`.

## Blender 3: vehicles (lane/vehicles)

Modelled in Blender 4.2 by headless scripts in `tools/blender/` (regenerate with
`blender -b --factory-startup --python godot/tools/blender/build_vehicles.py -- [only=a,b] [nobake] [render=<dir>]`), exported as
rigged glTF 2.0 to `assets/models/vehicles/<name>.glb`, loaded by `game/vehicle_assets.gd` (class `VehicleAssets`). These replace
the batch 6 code-built vehicles (which stay as the fallback when a file is missing) and give the story its vehicles.

**Frame:** metres, forward **-z**, up +y, right +x, origin on the ground at the middle of the length (the batch 6 frame).
`VehicleAssets.instance(name, paint, front_plus_z := true)` turns it to the story frame (+z forward); `StoryAssets.instance/place`
does this for every vehicle name automatically and adds box colliders.

**One file per vehicle:** one armature, three skinned meshes on it, `<name>_LOD0` (near), `_LOD1` (about 35 %), `_LOD2` (far),
switched by visibility range at 25 m and 80 m. Real modelling: a lofted body with pressed shoulder and belt creases, real panel
gaps with return flanges, doors, bonnet and tailgate cut out as their own panels, wheel arches cut with wheel wells, lamp units
(chrome reflector behind a clear lens; tail, brake, indicator and reverse sections), grille, plates in recesses (blank fictional
plates), handles, mirrors, wipers, exhaust, tyres turned from a real section with tread and sidewall, alloy or steel rims with
nuts, brake disc and caliper, and an interior (seats, dash, steering wheel, door cards, headliner) seen through transparent glass.
UVs in metres (box projection), tangents exported, ambient occlusion baked into the vertex colour (red), the finish condition
in the vertex alpha (1 clean, lower = worn and rusty).

**Material slots** (names are the contract; `VehicleAssets` swaps in `game/shaders/vehicle_pbr.gdshader`, `vehicle_pbr_ds.gdshader`
(cabin, both sides) and `vehicle_glass.gdshader`, all with rain `g_wet`, snow `g_snow` and the cloud and drone shadows):
`paint` (the instance's paint colour), `paint2` (livery), `glass`, `glass_tint`, `chrome`, `mirror`, `rubber`, `rim`, `rim_steel`,
`metal`, `caliper`, `trim`, `trim_grey`, `interior`, `seat`, `dash`, `plate`, `plate_text`, `lettering`, `lettering2`, `primer`,
`sheet_white`, `canvas`, `wood`, `straw`, `flag_a/b/c`, and the lamps `lamp_front`, `lamp_reflector`, `lamp_tail`, `lamp_brake`,
`lamp_ind_l`, `lamp_ind_r`, `lamp_reverse`, `lamp_beacon`, `lightbar_red`, `lightbar_blue` (each vehicle gets its own lamp materials
so its lights switch alone). The shader reads the vertex colour as occlusion and condition; the colour comes from `tint`.

**Bones.** Every pivot bone points along its turning axis, so a part turns about the bone's own +Y. Common to all:
`root` (on the ground), `body` (child of root: lift, pitch and roll it for suspension; everything on the body follows),
`wheel_fl wheel_fr wheel_rl wheel_rr` (spin about the axle), `steer_fl steer_fr` (parents of the front wheels; turn about vertical).
Three-axle trucks add `wheel_m1l wheel_m1r`; the motorcycle has `steer_f wheel_f wheel_r stand`. Twin rear tyres share one bone.
Doors and panels (children of body): `door_fl door_fr door_rl door_rr` (front-hinged), `bonnet`, `tailgate` or `boot`,
`door_rear_l door_rear_r` (van barn doors), `door_slide_r` (van sliding door), `bus_door_a bus_door_b` (bus folding leaves),
`serving_window` (ice cream van), `door_rear` (ice cream van), `shutter` (lorry roller shutter), `tip_bed` (tipping trailer),
`drawbar`, `hitch` (the trailer eye / tractor hitch point, child of root), `pto` (tractor power take-off), `valve` (milk tanker
outlet hand wheel), `destination_board` (buses), `wiper_l wiper_r` (or `wiper_f` on the tractor), `steering_wheel`, `handlebar` (quad).
The manifest (`game/vehicle_manifest.gd`, generated) lists every vehicle's bones, animations, wheels (bone, hub position in the game
frame, radius, steer), sizes, triangle counts, paints, hinge angles, colliders and its defect checks.

**Animations** (AnimationPlayer, baked from Blender actions): `doors_open doors_close door_driver_open door_driver_close`,
`bonnet_open/_close`, `tailgate_open/_close` or `boot_open/_close`, `rear_doors_open/_close`, `slide_door_open/_close`, `wipers`
(one sweep, loopable), `steer_left steer_right` (front wheels to full lock and the steering wheel 1.25 turns), and per vehicle:
`bus_door_open/_close`, `serving_window_open/_close`, `shutter_open/_close`, `valve_open/_close`, `tip_raise tip_lower`, `pto_spin`,
`stand_down`. Wheels are not animated: drive them from code.

**Calls:**
- `VehicleAssets.place(parent, name, Transform3D, paint := Color(0,0,0,0), front_plus_z := false) -> Node3D` (a root named after the
  vehicle holding `rig`, the imported scene). `instance(...)` the same without adding it. `has(name)`, `names()`, `info(name)`.
- `VehicleAssets.roll(v, metres)` turns every wheel by -distance / radius; `steer(v, radians)` (+ = left); `bounce(v, lift, pitch, roll)`.
- `VehicleAssets.play(v, "doors_open")`, `pose(v, "tailgate_open", at := 1.0)` (jump to a point of an animation).
- `VehicleAssets.set_lights(v, {"head": 1, "tail": 1, "brake": 0, "ind_l": 0, "ind_r": 0, "reverse": 0, "beacon_red": 1, "beacon_blue": 1, "beacon_amber": 0})`.
- `VehicleAssets.add_colliders(v)` (a StaticBody3D of the manifest boxes), `colliders(name)`.
- Posed variants by name: `cruiser_1984_a_driver_open`, `cruiser_1984_a_open`, `festival_bus_restored_open`, `lake_car_estate_a_closed`,
  `festival_ice_cream_van_a_open`.

| Name | What it is | Notes |
|---|---|---|
| `car_hatch_a` | 4.0 m three-door supermini, TAMSIN, silver | 185/60R15 alloys |
| `car_hatch_b` | 4.3 m five-door hatchback, ARDEN, red | 205/55R16 alloys |
| `car_estate_a` | 4.8 m estate, VELIA, dark grey-green, roof rails | 215/55R17 multi-spoke |
| `pickup_a` | 5.3 m crew-cab pickup, CORVAN, blue | separate bed with liner and its own `tailgate` (hinged at the bottom) |
| `pickup_b` | 4.9 m older pickup, BRASK, sun-faded and rusty | chrome front bumper, steel wheels with caps |
| `van_a` | 5.3 m panel van, white | sliding door, barn doors with windows, cargo lining |
| `van_b` | 4.4 m small van, blue | blank barn doors |
| `police_suv_a` | 4.9 m provincial police SUV (fictional HALLOWAY PROVINCIAL POLICE livery) | low lightbar, push bar, lower cladding |
| `police_saloon_a` | 4.85 m plain grey saloon | low lightbar, thin fictional stripe and door lettering |
| `lake_car_estate_a` / `_b` | the Lake Car: late-1980s boxy blue estate (BRASK 245) | rust, flat rear tyre, smashed rear window, plates missing, posed with the tailgate open; `_b` has the VOSS & SON tow sticker |
| `cruiser_1984_a` | 1984 provincial police cruiser: long boxy saloon, white with dark roof and doors | faded HALLOWAY / PROVINCIAL POLICE lettering, 1980s domed lightbar, whip aerial, A-pillar spotlight, rusted sills, chrome bumpers |
| `bus_a`, `bus_b` | 10.6 / 11.2 m single-deckers (VALLEY LINES cream and red; KESTREL COACHES white and blue) | twin rear tyres, folding door on +x, lit destination board, rows of seats |
| `festival_bus_restored` | 9 m 1960s green and cream single-decker, HALLOWAY FESTIVAL | split screen, chrome bumpers, roof rack, VOSS & SON maker's sticker |
| `festival_bus_garage` | the same bus before restoration | faded, rusted, a grey primer panel, a blue tarp half over the roof |
| `festival_ice_cream_van_a` | 5.75 m coachbuilt soft-serve van, HALLOWAY ICES | sliding serving window, counter, striped awning, menu boards, roof cone and swirl, lit ICES sign, chime horns, soft-serve machine and freezer inside |
| `lorry_a` | 8.4 m rigid box lorry, MARSH & DAUGHTERS | roller shutter, side guards, fuel tank, exhaust stack |
| `milk_tanker_a` | 9.4 m three-axle milk tanker, VALLEY DAIRY | stainless tank, walkway and rails, manways, ladder, rear cabinet, hose, `valve` |
| `tractor_a` | 1990s four-post-cab tractor, HALDEN 6140, blue | 18.4R38 / 14.9R28 lugged tyres with sidewall lettering, cab interior, perforated louvres, exhaust heat shield, three-point linkage with assist rams, PTO, couplers, front weights, beacon, work lamps |
| `tractor_wheels_a` | the tractor's four wheels alone | |
| `parade_tractor_a` | 1950s TAMSIN Series 2, red with cream wheels | chrome radiator bars, pan seat, clamshell fenders, festival rosette |
| `tractor_trailer_a` | 6.6 m tandem tipping trailer | leaf springs, tipping ram, `tip_bed` |
| `parade_trailer_a` | festival flatbed: timber deck, straw bales, bunting, HALLOWAY FESTIVAL banners | |
| `motorcycle_a` | naked roadster | |
| `farm_quad_a` | 450 cc utility quad, KESTREL 450 4x4 | wishbones and coil-over shocks, racks, winch, handlebar on its own bone |

Checks: `test/vehicles_blender_test.gd` (headless: every file loads, bones and animations named in the manifest exist, sizes in metres,
wheels on the ground, front toward -z, triangle budgets, no NaN, winding matches the normals, no floating parts, painted faces face
outward, the rig really rolls, steers and opens doors, the story names resolve). Sheets: `test/vehicles_blender_sheet.gd` (views,
lights golden / overcast / backlit / wet, animation strips) and `test/vehicles_textures_sheet.gd` (every material on a sphere with its
source and licence), written to `docs/realism/models/vehicles_*.jpg`.
## Blender 2: people (lane/people)

Loader `game/people_assets.gd` (class `PeopleAssets`). Story names for the endgame people (`wren_standing_phone_a`, `wren_sitting_porch_a`, `wren_walking_torch_a`, `wren_waving_a`, `wren_crouched_a`, `rennick_1984_standing_a`, `rennick_1984_standing_a_notebook`, `rennick_1984_ghost_a`) are served here; the Wren and Rennick props stay in Batch 9.

Rigged, animated, photographed-texture people made in Blender 4.2 by scripts in `godot/tools/blender/` (they regenerate
everything). They replace the code-built figures of Batch 8 under the same story names; the old builders stay as the
fallback when a file is missing. Sources and licences: `assets/models/people/README.md`.
- **Files:** `assets/models/people/<person>.glb` for 19 people: `ellis`, `rennick`, `rennick_uniform`, `rennick_1984`,
  `wren`, `crowd_m1..m3`, `crowd_f1..f3`, `child_boy`, `child_girl`, `band_singer`, `band_guitar`, `band_fiddle`,
  `band_drummer`, `pilot`, `bystander`. Clips: `anim_male.glb`, `anim_female.glb`, `anim_child.glb`. Props:
  `people_props.glb` (root nodes `prop_<name>`).
- **Frame:** metres, Y up, +Z is the front, origin on the ground between the feet (seated: the ground under the seat).
- **Nodes:** `<person>/Armature/Skeleton3D/` with skinned meshes `head_LOD0..2` (face, eyes, brows, lashes, hair),
  `body_LOD0..2` (the skin that shows; skin hidden under clothes is deleted), `clothes_LOD0..2`, and where present
  `coat_LODn` (Wren's rain jacket) and `backpack_LODn` (Wren), so a thermal mask can pick `head`, `body`, `coat` and
  `backpack` apart. PeopleAssets sets visibility ranges: LOD0 to 14 m, LOD1 14 to 45 m, LOD2 45 to 400 m.
- **Triangles** (LOD0 / LOD1 / LOD2): about 8.5k to 9.5k / 3.6k to 4k / 1.2k to 1.4k per person, checked by the test
  (limits 9.6k / 4.4k / 1.7k).
- **Skeleton:** one rig for everyone (MakeHuman game_engine rig, 53 bones, renamed to Godot's SkeletonProfileHumanoid names)
  plus `LeftEye` and `RightEye`: Root, Hips, Spine, Chest, UpperChest, Neck, Head, Left/RightEye,
  Left/RightShoulder, UpperArm, LowerArm, Hand, ThumbMetacarpal/Proximal/Distal, Index/Middle/Ring/Little
  Proximal/Intermediate/Distal, UpperLeg, LowerLeg, Foot, Toes. No Jaw bone: the mouth is blend shapes. Limbs are
  IK-ready chains (UpperArm-LowerArm-Hand, UpperLeg-LowerLeg-Foot) for SkeletonIK3D or TwoBoneIK3D. Weights are the
  MakeHuman weights, at most 4 per vertex.
- **Face:** `head_LOD0` has blend shapes `blink`, `smile`, `mouth_open`, `mouth_o`, `mouth_e`, `mouth_mbp`, `brow_up`
  (made from the MakeHuman expression units). `PeopleFace` (added by PeopleAssets) blinks at random and moves the mouth
  during `talk` and `sing`.
- **Clips** (looping, in place, 30 fps): idle, idle_shift, walk, walk_torch, sit_idle, sit_mug, sit_hug_knees, talk, wave,
  wave_up, look_around, look_up, clap, sway, cheer, point, pockets, hands_hips, crouch, kneel, toolbox_kneel, lie_creeper,
  clipboard_hold, clipboard_write, notebook_hold, knock, phone_hold, flag_wave, sing, play_guitar, play_fiddle, play_drum,
  play_cornet. They are keyed on a reference body; PeopleAssets copies them onto each person keeping rotations for every
  bone and the Hips position scaled to the person's hip height (so they retarget to adults and children alike).
  Walking is in place: move the node yourself, about 1.3 m/s for the walk clip at speed 1.
- **API:** `PeopleAssets.place(parent, name, xf)` / `PeopleAssets.instance(name)` for story names;
  `PeopleAssets.person(person, clip, props, tint, ghost, seed)` for anything else (props are `"mug:R"`, `"clipboard:L"`,
  `"guitar:C"`, `"camp_chair"` or `"creeper@x,y,z,yaw"`). `StoryAssets.instance()` routes every story people name here
  first. `PeopleAssets.STORY` is the table of story name -> person, clip, props (the old Ellis, Rennick and crowd names,
  and Wren and Rennick 1984 names from the endgame brief). `crowd_band_a` builds the four-piece band.
- **Materials:** the glTF carries PBR materials (skin, eye, brow, lash, hair, cloth). PeopleAssets adds subsurface
  scattering with transmission to skin (Forward+ only), alpha-to-coverage hair, double-sided cloth with a slight rim;
  `tint` multiplies the cloth colour for crowd variety. Rennick's ghost uses `game/shaders/people_ghost.gdshader`
  (translucent, soft rim, slow breath; no shadows).
- **Regenerate** (Blender 4.2.3 portable in `_tools/blender-4.2.3-windows-x64`, MPFB and the MakeHuman packs in the
  private user folder `_tools/people/bluser`, set up once by `people_setup.py`): from `godot/tools/blender`,
  `sh run_people.sh people_build.py -- all` (people), `sh run_people.sh people_anims.py` (clips),
  `sh run_people.sh people_props.py` (props), `sh run_people.sh people_sheet.py -- --out <dir> --names ellis`
  (Blender contact sheets). The roster (body sliders, skins, clothes, colours, fabrics) is `people_roster.py`; the clips
  are `people_clips.py`.
- **Checks:** `test/people_blender_test.gd` (headless: every person loads, bones, LOD budgets, height, NaN, clips, blend
  shapes, every story name animates with its props). In the scene: `tools/people_scene.sh <out.png> <names> <hour> <distance>`.

## Blender 4: drones (lane/drones; `game/drone_assets.gd`, class `DroneAssets`)

The Facade kit drones from session B's request of 2026-11-07, modelled in Blender 4.2 by `tools/blender/build_drones.py` (with `drones_lib.py`, `drones_parts.py`) and exported as glTF 2.0 into `assets/models/drones/`: `<name>.glb`, `<name>_lod1.glb`, `<name>_lod2.glb` and a manifest `<name>.json`. Robert's direction is photoreal, so LOD 0 carries real detail instead of the brief's 2 to 3k triangles (see the honest limits below).

| Name | What it is | Triangles lod 0 / 1 / 2 |
|---|---|---|
| `raptor_race_a` | 5-inch 6S race quad, 550 g class, orange anodised and dark carbon. 5 mm unibody with angular pads and arm slots, 2 mm top plate on orange hex standoffs, camera side plates, a 19 mm FPV camera tilted 40 degrees, an action camera fixed on a printed mount at 25 degrees, a 30 x 30 stack on orange soft-mount grommets (ESC with MOSFETs, flight controller with MCU, gyro, sockets, USB-C, blue status LED), finned VTX, pagoda VTX antenna on a TPU mount, receiver whiskers in orange tubes, 2207 motors (spun-aluminium bell tops with windows onto the copper windings and stator, 14 nickel magnets, sealed top bearing, titanium shaft), tri-blade 5.1 inch props with washer and M5 lock nut, a 6S pack on a rubber pad with a woven strap and buckle, leads and a balance lead, mated XT60s, a low-ESR capacitor, motor leads in heat-shrink, cable ties, button-head screws | 19.6k / 7.0k / 3.0k |
| `nightowl_a` | quiet 4-inch gimbal ship, 480 g class, navy and black. 4 mm unibody, a navy moulded canopy with side vents showing the stack, carbon battery tray with slotted navy rails and a hinged latch, 4S pack and strap, 2004 navy motors, two-blade wide swept low-noise props (black, blue tips), a compact 3-axis gimbal on four rubber dampers (yaw, roll and pitch motors, camera head with a coated lens), the night-vision pod clipped under the front left, a landing light (reflector, emitter, clear lens), carbon landing legs with rubber feet, paddle aerials, receiver whiskers, a rear status LED bar | 22.8k / 9.6k / 4.1k |
| `night_vision_pod_a` | clip-on low-light camera, 40 x 34 x 46 mm (beside the 52 x 42 x 62 mm `thermal_pod_a`): dark grey anodised case with cooling fins, clip plate with rails and a knurled thumbscrew, knurled bezel, a fast lens with a green coating, two infrared LEDs, a green status LED, a lead out of the back | 1.9k / 0.9k / 0.3k |

- **Frame in the files:** metres, +Y up, **+Z is the nose**, the model's right is -x, origin on the ground under the middle (the lowest point of the feet or pads). The pod's origin is the middle of its **mounting face (its top)**; it hangs below y = 0, lens towards +Z.
- **Nodes** (each pivot on its own axis, no rest rotation): `body`, `battery`, `prop_fr` `prop_rr` `prop_rl` `prop_fl` (pivot on the motor shaft at the hub; **fr and rl turn clockwise seen from above, rr and fl anticlockwise**, which is how DroneView spins them), `camera_lens`, `status_led`, `led_fr` `led_rr` `led_rl` `led_fl` (navigation lamps: green front right, red front left, white behind). Raptor: `camera_fpv` (child `camera_lens`), `action_cam` (children `action_cam_lens`, `action_cam_led`). Night Owl: `gimbal_yaw` > `gimbal_roll` > `gimbal_pitch` > `camera_lens` (yaw about y, roll about z, pitch about x, each pivot on its motor axis), `nv_pod` (children `nv_lens`, `nv_led`, and `nv_led_ir` at lod 0), `landing_light`. Pod: `body`, `camera_lens`, `status_led`.
- **Use:** `DroneAssets.place(parent, name, Transform3D, lod := 0)` or `DroneAssets.instance(name, lod)`. Level of detail: lod 0 inside about 3 m, lod 1 to about 12 m, lod 2 beyond (the importer adds its own automatic LODs too). Lamps are the materials named `lamp_*` (emissive): swap or dim them to switch a lamp.
- **In flight:** `DroneView.model()` asks `DroneAssets.model_data(airframe id)` first. `DroneAssets.MODEL_FOR` maps the Facade airframes `raptor` and `nightowl` (lane/notify's physics/airframes.gd) to these files; Race and Gimbal Mini keep their own code models. DroneView hangs the file under a holder that turns it into the body frame (`DroneAssets.body_xf`: half a turn about y, the manifest's centre of mass at the origin), spins the file's own prop nodes, adds blur discs from the manifest (radius, chord, blur colours), hides `camera_fpv` (Raptor) or `gimbal_yaw` (Night Owl) in the FPV view, and phones (mobile and compatibility renderers) take lod 1. The drone chooser's picture (DroneThumbs) and drawing (DroneSchematic) come from the same data (the manifest's per-part plan and side outlines). Evidence: `docs/realism/drones/00` to `06`.
- **Textures:** the files embed their PBR textures (so they stand alone in Blender or elsewhere); the game's import (`gltf/embedded_image_handling=0`; the `.glb.import` files are committed) discards them and `DroneAssets` puts the one shared set from `assets/textures/drones/` back by material name (one material per name for every drone and level of detail). Sources and licences: `assets/textures/README.md` and `docs/realism/models/drones_final_textures.jpg`.
- **Fallback:** if a file is missing the code placeholder stands in (DroneView's Race for the Raptor, the Mini for the Night Owl, the story `thermal_pod_a` for the pod).
- **Regenerate:** `python tools/blender/drones_prep_textures.py <folder with the extracted ambientCG 1K-JPG sets>`, then `blender -b -P tools/blender/build_drones.py [-- only=<name>] [stats]`. Checks: `test/drones_blender_test.gd` (headless: files, nodes, materials and shared textures, lamps, base and nose, budgets falling from near to far, props on the motors and twisted the right way for their spin, tip to tip, DroneView builds the Facade drones with four props, blur discs and FPV hiding, Race and Mini untouched), `test/drones_sheet.gd` (views in the game's renderer, golden and overcast), `test/drones_chooser_shot.gd` (needs lane/notify's airframes), `tools/blender/render_drones.py` (Cycles views and the 512 px listing photos in `docs/realism/models/drones_thumbs/`), `tools/blender/drones_sheets.py` (`drones_final_views.jpg`, `drones_final_textures.jpg`). Godot runs go through `tools/blender/godot_locked.sh` (the shared godot-run.lock).
- **Honest limits:** LOD 0 is 19.6k and 22.8k triangles, above the 8 to 15k aimed at (the motors with magnets and windings, and the screws, cost the most); the ambientCG sets are CC0 but procedural (no CC0 photographed carbon weave exists on Poly Haven or ambientCG); the lens coating sits under opaque glass, so in Godot the lenses read as glossy black with only a faint tint; screw sockets are round recesses, not hexagons; wires are smooth tubes; the gimbal does not move yet (the nodes are ready); the Night Owl is a 4-inch model on lane/notify's 5-inch airframe numbers (R 0.0635), so the chooser's "5.0 in" label and tip-to-tip figure disagree with the drawn discs until the airframe says R 0.0508; its gimbal lens sits about 4.6 cm below and 2 cm ahead of the physics camOffset (the Raptor's FPV lens is within 2 cm).

## Buildings pass (lane/buildings)

**The upside-down roofs.** The V-shaped, floating roofs Robert saw are in the committed models8 contact sheets
(`docs/realism/models/story_town1_golden.jpg` and `_overcast.jpg`, now re-rendered): those sheets were made while the pitch
rotation in `NewModels6Hall._roof` and `NewModels6Town._garage` had the opposite sign (`Basis(Vector3.RIGHT, -sz * ang)`),
so each pitch rose outwards from the ridge and stood clear of its walls. The committed code and the shipped .glb files
already had the right sign; the sheets were never re-made. Reproduced exactly by flipping the sign back: the three files in
`test/fixtures/roof_broken/` named `*_v.glb` are that broken output, plus `town_shop_a_float.glb` (roof lifted 0.6 m).
The audit also found two real faults in the game: **`cabin_lean_to_a`** (models9) had its tarp tilted the wrong way, high at
the front post and 0.4 m clear of the back one (now laid on the rafters in `new_models7_cabin.gd`), and
**`festival_stage_a`** had its canvas hovering on nothing (now a ridge pole, king posts and rafter poles carry it).

**Automated test:** `test/roof_orientation_test.gd` (headless; `-- fixtures` also runs the broken files, which must fail;
`-- only=<prefix> verbose`). It reads each roofed model from the file the game loads (GLTFDocument) or the mesh the game
builds, and checks: ridge above eaves (the median top-surface profile across the ridge must not dip in the middle), roof
faces up (stored normal and winding), roof sits on its walls (a wall-top-to-roof gap under 0.15 m along the eaves or a
gable top) and no floating pieces. 56 models (every Halloway building and its lods, garage, cabin and variants, lean-to,
rail hut, bus shelters, marquee, stage, stalls, toilets, tents, barn, silos, coop, kennel, and the park chapel cut out of
park.glb): all pass, and all four broken fixtures are caught.

**Rebuilt in Blender** (`tools/blender/build_buildings.py`, library `bldg_lib.py` and `bldg_parts.py`; portable Blender
4.2.3, headless): `town_police_house_a` (and `_open`), `town_pub_a`, `town_village_hall_a`, `town_shop_a`, `town_shop_b`,
`town_bakery_a`, `town_chip_shop_a`, `town_church_a`, `town_school_a`, `garage_shell_a`, `cabin_abandoned_a` (and
`_broken_roof`). Same names, origin (ground, middle of the footprint), +Z front and node names (`body`, `door` with its pivot
at the hinge, `window_light`, `windows`, `blue_lamp`, `card_stand`, `roller_door`, `hullN-colonly`), as direct children of
the scene root. Every building now has `_lod1` and `_lod2` files (LOD0 9k to 23k triangles; the cabin 3k). Hollow wall
shells cut by exact booleans (real reveals); stone sills, lintels or gauged-brick arches, quoins, plinths and string
courses; box-sash windows (two sashes, glazing bars, horns) with glass, curtains and a room behind; panelled doors with
brass ironmongery, fanlights, doorcases and steps; Victorian shopfronts (pilasters, consoles, fascia, cornice, stallriser,
transom lights, recessed door, striped awning); slate or corrugated roofs whose underside rests on the wall plates, with
ridge tiles, fascia, soffit, bargeboards, half-round gutters, downpipes, chimney stacks with oversailing courses,
flaunching, clay pots and lead flashing. Lettering is real glyph geometry (OFL fonts in `tools/blender/fonts/`): HALLOWAY
STORES, MOTOR PARTS, BAKERY, FISH & CHIPS, THE PLOUGH, VILLAGE HALL, HALLOWAY SCHOOL, HALLOWAY PROVINCIAL POLICE,
VOSS & SON and MOTOR WORKS. Heights are now true to life (two storeys about 5.7 to 6.2 m to the eaves); footprints are
unchanged.
- **Materials:** the files carry `bld_*` material names, UVs in metres and a vertex colour (paint times weathering).
  `game/building_mats.gd` (called from `NewModels6.mat`, so `StoryAssets` swaps them in) builds ORM materials from
  `assets/textures/bld_*.jpg` at their real repeat (the brick has parallax from a height map). Sources: `assets/textures/README.md`.
- **Do not re-export these from code:** `tools/export_story.gd` now skips them (and the two buoys) unless given `code_buildings`.
- **Buoys:** `lake_buoy_a` (POLICE DIVE on the blue band, twice round) and `dive_marker_a` (DIVER, an Alpha flag) are
  Blender-made (`tools/blender/build_buoys.py`); the code-built `buoy_a` merges `assets/models/lettering/buoy_a_lettering.glb`
  (the number 4 and HALLOWAY LAKE wrapped to the hull). The old DIVE lettering stood mirrored and half inside the float.
- **Sheets:** `docs/realism/models/buildings_final_views.jpg` (and `_overcast`, `_night`, `_close`, `_props_views`),
  `buildings_final_roofs.jpg` (eye-level gable and front views and roof close-ups; rows one, three and five are the broken
  fixtures for comparison), `buildings_final_textures.jpg`, `buildings_final_scene.jpg` (in the game at 15, 40 and 100 m,
  through the `story<d>_<names>` token), `buoys_final.jpg` (and `_close`). Made by `test/buildings_sheet.gd` and
  `test/buildings_textures_sheet.gd`.
- **Regenerate:** `python -I tools/blender/fetch_textures.py tools/blender/tex_src` (a download, not committed), then
  `python -I tools/blender/make_building_textures.py <godot dir>`, then `blender -b --factory-startup --python
  tools/blender/build_buildings.py [-- only=<names> lods=0,1,2]` and `build_buoys.py`, then a Godot `--import`.

## Blender 1: animals (lane/animals)

The farm animals, the story dogs and the wildlife brief's wolf and sheep rebuilt properly: sculpted in Blender from real
proportions, rigged, weight-painted, animated and textured, then exported as glTF. They replace the code-built NewModels5
animals (which stay as the fallback when a file is missing). Everything is regenerated by scripts kept in
`tools/blender/` (see `tools/blender/README-animals.md`); nothing was modelled by hand.

**In the game:** `AnimalAssets.place(parent, name, Transform3D, opts := {}) -> Node3D` or `AnimalAssets.instance(name, opts)`
(`game/animal_assets.gd`). It loads `assets/models/animals/<name>.glb`, sets every clip to loop, starts `opts.clip` (default
`"idle"`) at a random point, switches the levels of detail by distance and dresses the hide in the shell-fur shader
(`game/shaders/fur.gdshader`, the colleague's shader from models7 with a new `maps` mode for skinned, texture-baked meshes:
strands are laid out in UV space so they stay on the hide while the bones move). `AnimalAssets.play(animal, clip, blend)`
switches clips. opts: `clip`, `seed` (start offset), `fur` (false for a plain PBR coat), `lod` (force 0, 1 or 2),
`speed_scale`, `tint` (`"white"`, `"cream"`, `"grey"` or a Color: tints the wool only), `scale`, `parts` (see heat mask).
If the file is missing, the NewModels5 mesh stands in (still, unrigged, turned to face +Z).

**Frame (as Batch 8):** metres, Y up, **+Z is the front**, origin on the ground under the middle of the animal, its right
side is -x. Root node named after the animal; under it the glTF armature with one `Skeleton3D`, the meshes
`<name>_LOD0` (near, to 25 m: drawn twice by the loader, with 16 fur shells inside 8 m and 6 to 25 m; 6 and 3 on a phone),
`<name>_LOD1` (about 35 per cent, 25 to 80 m, plain coat) and `<name>_LOD2` (about 10 per cent, beyond 80 m),
`<name>_eye_L/_R` and `<name>_lid_L/_R` (to 25 m), and an `AnimationPlayer`.

**Clips** (loop; made in place, the animal does not travel: move the node at the speed in `AnimalInfo.INFO[name].speeds`):
cattle, sheep, lamb, ram, horses: `idle` (breathing, looking about, ear flicks, tail swish, chewing, blinks), `walk`
(four-beat lateral walk), `trot` (diagonal pairs), `run` (canter), `graze` (head down to the grass, tearing and chewing).
Dogs (`dog_a`, `biscuit_a`, `lost_dog_a`): `idle`, `walk`, `trot`, `run` (rotary gallop), `sit` (looking up), `lie`
(on the chest, head up), `tail_wag`, `bark`, `pant`. Wolf (`wolf_a`, `wolf_collar_a`): `idle`, `walk`, `trot`, `run`, `look`.
Hen: `idle` (looks in jerks), `walk` and `run` (the head holds still then thrusts), `peck`.

**Bones** (same names on every four-legged animal; `_L` is the animal's left, +x): `hips` (pelvis; parent of the spine,
thighs and tail), `spine_01`, `spine_02`, `chest`, `neck_01`, `neck_02`, `head`, `jaw`, `ear_L/R`, `eyelid_L/R` (turn
about its own Y to close the upper lid), `tail_01`..`tail_05`, front legs `scapula`, `upperarm`, `forearm`, `cannon_F`,
`pastern_F`, `foot_F` (hoof or paw), hind legs `thigh`, `shin`, `cannon_H`, `pastern_H`, `foot_H` (each with `_L`/`_R`).
On dogs and the wolf `cannon_F/H` are the metacarpals and metatarsals and `pastern`/`foot` the toes. Every bone is rolled
so its local X is the animal's left-right axis: a positive turn about local X lifts the bone's tip up or forward. For
IK in the game: the chains `upperarm, forearm, cannon_F` and `thigh, shin, cannon_H` bend only about X. The hen:
`hips`, `spine_01`, `neck_01..03`, `head`, `jaw` (lower beak), `eyelid_L/R`, `wing_L/R`, `forewing_L/R`, `hand_L/R`,
`thigh_L/R`, `shin_L/R`, `tarsus_L/R`, `toe_L/R`, `tail_01`, `tail_02`. Blink and mouth are bones (eyelids, jaw), not
shape keys.

**Story and brief names:** `StoryAssets.instance("biscuit_sitting_a")` (and `_standing`, `_lying`, `_running`) and
`"lost_dog_a"` now return the rigged dogs playing `sit`, `idle`, `lie`, `run` when the files exist (the old static files stay
as the fallback). The wildlife brief's animals are aliases in `AnimalAssets.ALIASES`: `wolf_standing_a`, `wolf_walking_a`,
`wolf_looking_a`, `wolf_trotting_a`, `wolf_collar_a`, `sheep_grazing_a`, `sheep_standing_a`, `sheep_lamb_a`, `sheep_ram_a`
(the brief's 0.9 m sheep are `sheep_b` and `ram_a` scaled 0.8 and 0.85), `sheepdog_a` (`dog_a`). **Heat mask:**
`AnimalAssets.heat_parts(animal)` (or `opts.parts = true`) splits the near hide into `<name>_body`, `_head`, `_legs` and,
on sheep, `_wool` MeshInstance3Ds on the same skeleton, still animated.

**Props of the wildlife brief:** `WildlifeAssets.place/instance(name, opts)` (`game/wildlife_assets.gd`), files in
`assets/models/wildlife/`, made by `tools/blender/build_props.py`. Same frame. `_LOD0` to 30 m, `_LOD1` beyond where it
matters. Names: `sheep_trough_a`, `sheep_hay_rack_a`, `sheep_salt_lick_a`, `sheep_bell_a`, `wool_on_wire_a/_b`,
`wolf_track_a/_b`, `sheep_print_a/_b` (thin quads with a damp-mud decal, alpha scissor, lay them on the ground),
`night_pen_a` and `night_pen_a_open` (6 x 4 m: `<name>_panel_back/_left/_right/_front_l/_front_r`, `<name>_gate` pivoting
on its hinge post, `<name>_straw`), `pen_gate_a`, `farm_warning_sign_a` (hand-painted: WILDLIFE ADVISORY, wolf seen near the
west pasture, sheep penned at night, dogs on leads please), `hay_bale_small_a`, `straw_patch_a`, `sheep_feed_bucket_a`,
`wolf_ear_tuft_a`, `pasture_gate_a` (the brief's second field gate; `field_gate_a` is already the vehicles lane's name, so
WildlifeAssets maps it here), `farm_lantern_a`, `wolf_collar_tracker_a`, `sheep_shearing_kit_a`; `farm_truck_a` is the
vehicles lane's `pickup_b`. `opts.open = true` swings a gate open. Collision: `-colonly` boxes on the pen panels, gates,
trough and hay rack.

**Regenerate:** `blender -b --python tools/blender/build_animal.py -- name=<name>` (about 2 to 6 minutes each; writes the
.glb, `tools/blender/info/<name>.json` and `game/animal_info.gd`), `build_props.py` for the props. Checks:
`test/animals_blender_test.gd` (headless: skeleton, clips, NaN, heights, lengths, triangle budgets and falling levels of
detail, and the orientation checks: feet on the ground, head toward +Z and above the middle, left eye on +x, normals
pointing out, no floating parts), `test/animals_sheet.gd` (contact sheets in Godot's renderer, any light, any view, or a
strip of a clip), and the game's screenshot token `animals<distance>_<clip>_<name>+<name>` for the real scene.

**Honest limits (2026-10-24):** the anatomy is sculpted from primitives on real skeletons, so the forms are smooth and a little
idealised: no visible ribs, veins or skin folds, and heads are the weakest part close up (the dogs' muzzles and the wolf read as
dogs rather than a particular breed at 2 m). Fur is shells over a baked coat: soft and right at 10 to 40 m, grainy at 2 m and
glittery on dark coats in flat light. The hen's feathers are relief in the normal map and sculpted tail and wing blades, not
feather cards. Mane and tail hair are sculpted locks, not hair cards. Occlusion is not baked (the ORM red channel is 1). The
wildlife brief asked 1,200 to 2,500 triangles for the sheep and wolf: their LOD0 is about 9,000 to 10,000, LOD1 about 3,300
and LOD2 about 950; the brief's static poses are clips of the rigged animals. Clips are made in place by procedural gaits,
not motion capture: the walk and trot read right at drone distance, the canter and gallop are simpler, and the hind legs can
fold a little stiffly. No ear-specific or mouth shape keys (eyelids and jaw are bones).

## Sites (lane/sites)

The boat launch and the old cabin track and cave (briefs `docs/CLAUDE-BOAT-LAUNCH-ASSETS.md` and `docs/CLAUDE-CABIN-TRACK-ASSETS.md`
on lane/notify), modelled in Blender 4.2 by `tools/blender/build_sites.py` (`sites_lib.py`, `sites_launch.py`, `sites_track.py`;
textures first with `python -I tools/blender/make_site_textures.py <godot dir>`), exported to `assets/models/sites/<name>.glb`
and loaded by `game/site_assets.gd` (class `SiteAssets`). `game/site_manifest.gd` (generated) lists every file's named nodes,
pivots, sizes, triangle counts, LOD distance, metadata (waterline, text rectangle, notes) and the Blender-side checks.

**Frame:** metres, Y up, **+Z is the front** (the ramp runs downhill along +Z; the dock runs out along +Z; signs, gates and the
cave face +Z; the hull's bow and the trailer's hitch are +Z; the track runs along Z and the fallen trees lie across it along X
with the roots at -X), origin at the base. Exceptions, stated in each file's `meta.origin`: the dock and the channel marker
have their origin at the water surface (piles and post run on below it), the hull at its keel (draft 0.12 m; the outboard's
skeg reaches 0.17 m below), the outboard at its transom clamp. **Cave pieces share one origin** (the middle of the cave mouth
on the ground at the face): place `cave_outcrop`, `cave_boulder_arch`, `cave_apron`, `cave_fallen_slab`, `cave_scree`,
`cave_damp_stain` and `cave_chalk_mark` with the same transform.

**Files:** each is a set of NAMED NODES at the top of the imported scene (`boat_ramp_slab`, `boat_ramp_curb_l/_r`,
`boat_dock_deck/_posts/_floats/_cleats/_ladder`, `boat_trailer_frame/_bunks/_winch/_hitch/_lights/_wheel_l/_wheel_r`,
`boat_outboard`, `tree_fall_a_trunk/_roots/_branches`, `rockfall_a_boulder_0.._6`, `cave_outcrop`, `cave_mouth`...), each
holding `<node>_LOD0` and (above 150 triangles) `<node>_LOD1` (collapse-decimated to about half), switched by visibility
range at the manifest's `lod_end` (9 x the asset's size, 18 to 70 m). Pivots are real: trailer wheels on the hub (axle along
X), `boat_outboard` on the tilt tube (rotate about X to tilt; on the trailer it is exported tilted 62 degrees),
`boat_launch_gate_leaf` and `track_old_gate_leaf` on their hanging posts (exported open; rotation.y = 0 closes them),
`boat_launch_windsock` on its mast (turn about Y to the wind). Node names never end in `_wheel`, `_col` and the like (Godot's
import hints would turn them into vehicle wheels or colliders).

**Materials:** plain glTF materials named `site_*` with UVs in metres and a vertex colour (ray-cast ambient occlusion against
the asset and the ground, times its weathering: waterline and algae on the ramp, dock and hull, tyre polish in the wheel
paths, zinc bloom and rust on the trailer, moss, lichen and damp on rock and bark, chipped paint), linear and clamped 0..1
(glTF wraps larger values). SiteAssets swaps in the photographed sets by name (`SiteAssets.SETS`; sources in
`assets/textures/README.md`, sheet `docs/realism/models/sites_final_textures.jpg`) and the plain PBR ones (`PLAIN`), multiplied
by the vertex colour. `site_cave_dark` is unshaded black (the mouth stays black in any light); decals (`site_decal_*`) are
alpha-blended with no depth write; `site_lamp_red/_amber` are emissive at 0 (`SiteAssets.set_lamps(node, true)` lights the
trailer lamps); `site_leaves` is the tree lane's beech atlas with alpha scissor.

**Calls:**
- `SiteAssets.place(parent, name, Transform3D, opts := {}) -> Node3D`, `instance(name, opts)`; `has`, `names`, `info`, `meta`.
  A brief part name (`boat_ramp_slab`, `boat_ramp_curb`, `boat_ramp_grooves`, `boat_dock_deck/_posts/_floats/_cleats`,
  `boat_trailer_winch`, `cave_mouth`) returns just that node of its file. A missing file gives a plain stand-in box of the
  manifest size, so placement code never breaks.
- `SiteAssets.fit_ramp(ramp, head_y, water_y)`: the ramp is built level (head at z 0, toe at z 30) with its waterline mark at
  z 24 (`meta.waterline_z`); this shears it so the top falls from head_y at the head to water_y at the mark and runs 6 m on
  under water, as real ramps do. Place it with its origin at the head first. (The placeholder's 84 m to 76 m over 30 m is a
  1:3.75 slope; real launch ramps are 1:7 to 1:9, so a lower head or a longer run reads more truthfully.)
- `SiteAssets.drape(node, height_fn)` moves every vertex of ground pieces (apron, gravel patch, track strip, cave apron,
  puddle, leaf drift, litter) onto `height_fn.call(x, z)` in world space, keeping their own relief.
- `SiteAssets.track_material()` is the cabin-track surface for a code-built ribbon: **u 0..1 across 4.4 m** (a 3.4 m running
  surface and 0.5 m of overgrown edge each side; ruts at u 0.32 and 0.68, i.e. 0.78 m either side of the centre), **v = metres
  along / 8**. Sink the outer 0.3 m of the ribbon about 6 cm so the terrain cuts a ragged edge (`track_y` in `sites_track.py`
  is the section).
- `boat_launch_sign` carries no lettering: `meta.text_rect` gives the face (centre (0, 2.25, 0.114), 2.86 x 0.76 m, facing +Z)
  for a Label3D or a painted face; `meta.ring_hook` is where `boat_life_ring` hangs (the ring's origin is its bottom; its
  hook bracket is on top).

| Asset | Group | Size x, y, z (m) | Tris LOD0 / LOD1 | Named nodes |
|---|---|---|---|---|
| `boat_aluminium_hull` | launch | 1.4 x 1.1 x 4.1 | 3810 / 1904 | `boat_aluminium_hull`, `boat_outboard` |
| `boat_aluminium_hull_b` | launch | 1.4 x 1.1 x 4.1 | 3810 / 1904 | `boat_aluminium_hull_b`, `boat_outboard` |
| `boat_cover_tarp` | launch | 1.5 x 0.4 x 3.4 | 1460 / 656 | `boat_cover_tarp` |
| `boat_dock` | launch | 3.1 x 3.9 x 14.4 | 2668 / 1196 | `boat_dock_cleats`, `boat_dock_deck`, `boat_dock_floats`, `boat_dock_ladder`, `boat_dock_posts` |
| `boat_fishing_box` | launch | 0.6 x 0.3 x 2.1 | 260 / 174 | `boat_fishing_box`, `boat_fishing_rod` |
| `boat_fuel_tank` | launch | 0.5 x 0.3 x 0.7 | 492 / 220 | `boat_fuel_tank` |
| `boat_launch_bin` | launch | 0.9 x 1.4 x 0.6 | 412 / 184 | `boat_launch_bin` |
| `boat_launch_bollard` | launch | 0.2 x 1.3 x 0.2 | 132 / 132 | `boat_launch_bollard` |
| `boat_launch_bollards` | launch | 8.0 x 1.3 x 0.2 | 264 / 264 | `boat_launch_bollard_l`, `boat_launch_bollard_r` |
| `boat_launch_damage_decals` | launch | 1.5 x 0.6 x 1.2 | 10 / 10 | `decal_algae`, `decal_crack_flat`, `decal_oil_flat`, `decal_rust_run`, `decal_waterline` |
| `boat_launch_gate` | launch | 4.3 x 1.9 x 3.8 | 596 / 266 | `boat_launch_gate_leaf`, `boat_launch_gate_posts` |
| `boat_launch_gravel_patch` | launch | 4.6 x 0.1 x 6.2 | 891 / 444 | `boat_launch_gravel_patch` |
| `boat_launch_marker` | launch | 0.2 x 3.0 x 0.2 | 176 / 78 | `boat_launch_marker` |
| `boat_launch_notice_board` | launch | 1.6 x 2.6 x 0.8 | 556 / 250 | `boat_launch_notice_board` |
| `boat_launch_sign` | launch | 3.1 x 3.4 x 0.2 | 348 / 234 | `boat_launch_sign_board`, `boat_launch_sign_posts` |
| `boat_launch_weather_post` | launch | 0.5 x 1.6 x 1.1 | 760 / 340 | `boat_launch_weather_post`, `boat_launch_windsock` |
| `boat_launch_wheel_stop` | launch | 2.0 x 0.1 x 0.2 | 100 / 100 | `boat_launch_wheel_stop` |
| `boat_life_ring` | launch | 0.8 x 0.9 x 0.2 | 902 / 472 | `boat_life_ring`, `boat_life_ring_bracket` |
| `boat_mooring_rope` | launch | 0.9 x 0.0 x 0.5 | 776 / 348 | `boat_mooring_rope` |
| `boat_outboard` | launch | 0.3 x 1.1 x 0.9 | 896 / 402 | `boat_outboard` |
| `boat_paddle` | launch | 0.1 x 2.1 x 0.0 | 200 / 90 | `boat_paddle` |
| `boat_parking_gravel` | launch | 21.0 x 0.1 x 14.4 | 1448 / 724 | `boat_parking_gravel` |
| `boat_ramp` | launch | 7.6 x 0.8 x 30.0 | 2056 / 1027 | `boat_ramp_curb_l`, `boat_ramp_curb_r`, `boat_ramp_slab` |
| `boat_trailer` | launch | 1.9 x 1.1 x 4.3 | 3888 / 2082 | `boat_trailer_bunks`, `boat_trailer_frame`, `boat_trailer_hitch`, `boat_trailer_jack_caster`, `boat_trailer_lights`, `boat_trailer_wheel_l`, `boat_trailer_wheel_r`, `boat_trailer_winch` |
| `boat_trailer_hull` | launch | 1.9 x 1.6 x 5.1 | 7736 / 4006 | `boat_aluminium_hull_b`, `boat_outboard`, `boat_trailer_bunks`, `boat_trailer_frame`, `boat_trailer_hitch`, `boat_trailer_jack_caster`, `boat_trailer_lights`, `boat_trailer_wheel_l`, `boat_trailer_wheel_r`, `boat_trailer_winch` |
| `boat_trailer_hull_covered` | launch | 1.9 x 1.6 x 5.1 | 9196 / 4736 | `boat_aluminium_hull_b`, `boat_cover_tarp`, `boat_outboard`, `boat_trailer_bunks`, `boat_trailer_frame`, `boat_trailer_hitch`, `boat_trailer_jack_caster`, `boat_trailer_lights`, `boat_trailer_wheel_l`, `boat_trailer_wheel_r`, `boat_trailer_winch` |
| `cave_apron` | track | 8.8 x 0.1 x 7.2 | 1931 / 965 | `cave_apron` |
| `cave_boulder_arch` | track | 4.2 x 3.1 x 1.6 | 1200 / 536 | `cave_boulder_0`, `cave_boulder_1`, `cave_boulder_2`, `cave_boulder_3` |
| `cave_chalk_mark` | track | 0.2 x 0.5 x 0.6 | 72 / 72 | `cave_chalk_mark` |
| `cave_damp_stain` | track | 3.8 x 4.3 x 3.3 | 356 / 159 | `cave_damp_stain` |
| `cave_fallen_slab` | track | 1.5 x 0.7 x 1.5 | 192 / 86 | `cave_fallen_slab` |
| `cave_old_lantern` | track | 0.2 x 0.3 x 0.1 | 476 / 214 | `cave_old_lantern` |
| `cave_outcrop` | track | 7.8 x 4.6 x 5.8 | 2851 / 1281 | `cave_mouth`, `cave_outcrop` |
| `cave_scree` | track | 3.7 x 0.2 x 1.7 | 1540 / 770 | `cave_scree` |
| `cave_warning_board` | track | 0.9 x 1.6 x 0.2 | 525 / 236 | `cave_warning_board` |
| `cave_warning_board_blank` | track | 0.9 x 1.6 x 0.2 | 212 / 94 | `cave_warning_board_blank` |
| `dead_branch_scatter` | track | 3.4 x 0.2 x 2.6 | 382 / 190 | `dead_branch_scatter` |
| `fallen_log_old` | track | 4.4 x 0.4 x 0.4 | 208 / 104 | `fallen_log_old` |
| `rockfall_a` | track | 4.9 x 1.1 x 3.7 | 3018 / 1206 | `rockfall_a_boulder_0`, `rockfall_a_boulder_1`, `rockfall_a_boulder_2`, `rockfall_a_boulder_3`, `rockfall_a_boulder_4`, `rockfall_a_boulder_5`, `rockfall_a_boulder_6`, `rockfall_a_litter` |
| `rockfall_b` | track | 3.3 x 0.8 x 2.7 | 1759 / 702 | `rockfall_b_boulder_0`, `rockfall_b_boulder_1`, `rockfall_b_boulder_2`, `rockfall_b_boulder_3`, `rockfall_b_litter` |
| `track_dirt_strip` | track | 4.4 x 0.1 x 12.0 | 1056 / 528 | `track_dirt_strip` |
| `track_grass_tuft` | track | 1.0 x 0.4 x 0.8 | 360 / 360 | `track_grass_tuft` |
| `track_leaf_drift` | track | 1.0 x 0.2 x 3.3 | 611 / 305 | `track_leaf_drift` |
| `track_oil_stain` | track | 0.9 x 0.0 x 0.9 | 2 / 2 | `track_oil_stain` |
| `track_old_gate` | track | 3.7 x 2.0 x 2.0 | 409 / 259 | `track_old_gate_leaf`, `track_old_gate_posts` |
| `track_puddle` | track | 0.7 x 0.0 x 2.0 | 522 / 522 | `track_puddle` |
| `track_rut_pair` | track | 2.0 x 0.0 x 12.0 | 384 / 384 | `track_rut_l`, `track_rut_r` |
| `track_tyre_print` | track | 0.2 x 0.0 x 1.6 | 2 / 2 | `track_tyre_print` |
| `tree_fall_a` | track | 11.2 x 2.7 x 4.6 | 2822 / 1266 | `tree_fall_a_branches`, `tree_fall_a_roots`, `tree_fall_a_trunk` |
| `tree_fall_b` | track | 7.3 x 1.9 x 4.3 | 1535 / 690 | `tree_fall_b_branches`, `tree_fall_b_roots`, `tree_fall_b_trunk` |
| `tree_fall_cut` | track | 11.2 x 2.7 x 5.9 | 3302 / 1484 | `tree_fall_cut_branches`, `tree_fall_cut_roots`, `tree_fall_cut_trunk` |
| `tree_stump_a` | track | 1.8 x 1.0 x 1.8 | 230 / 114 | `tree_stump_a` |

Brief items folded into others: `boat_ramp_grooves` (the waffle grooves are in the slab's normal map; the part name returns the
slab), `boat_trailer_winch` (a node of the trailer), `boat_launch_bin` and `boat_launch_notice_board` (two files),
`boat_launch_damage_decals` (one file of five decal nodes), `cave_mouth` (a node of `cave_outcrop`). Extra: `boat_launch_bollard`
(single), `boat_aluminium_hull_b` (green topsides), `boat_trailer_hull_covered` (with `boat_cover_tarp`), `cave_warning_board_blank`.

**Vehicle brief paths** (`docs/CLAUDE-VEHICLE-ASSETS.md`): `tools/blender/build_vehicle_aliases.py` writes STATIC copies of the
lane/vehicles models in that brief's contract, so `traffic.gd` and the story code can load them raw: origin on the ground under
the middle, forward **-Z**, right +X; `wheel_fl/_fr/_rl/_rr` as their own nodes on the hub (spin about local X);
`lamp_head_l/_r` and `lamp_tail_l/_r` as their own meshes with materials named exactly `headlight` and `taillight` (opaque
lens, the lamp colour as emission at multiplier 1; the game sets `emission_energy_multiplier`, as traffic.gd does with 2.4 x darkness); occlusion, rust and road dirt in the vertex
colour; paint as briefed; parked ones carry a `-colonly` box collider. One mesh level (the lane's LOD1 for traffic and parked
vehicles, LOD0 for the story ones); Godot builds automatic mesh LODs on import. For the full rigged versions (doors, steering,
lights switching, the vehicle shaders) use `VehicleAssets` with the source name. Manifest: `assets/traffic/manifest.json` and
`assets/traffic/manifest.md`.

| File | Source (assets/models/vehicles) | What | Tris |
|---|---|---|---|
| `assets/story/festival_bus.glb` | `festival_bus_garage` | the festival bus before restoration, HALLOWAY FESTIVAL, passenger door open | 45271 |
| `assets/story/lake_car.glb` | `lake_car_estate_a` | the Lake Car: late-1980s blue estate (BRASK 245), rust, algae line, flat tyre, smashed rear window, plates missing (the story), tailgate closed | 33029 |
| `assets/story/police_cruiser.glb` | `cruiser_1984_flat` | 1984 provincial police cruiser, rear left tyre flat, lightbar unlit | 35666 |
| `assets/traffic/hatchback_a.glb` | `car_hatch_b` | small five-door hatchback, dark red, alloys (ARDEN) | 10728 |
| `assets/traffic/hatchback_b.glb` | `car_estate_a` | small estate, dusty blue, roof rails (VELIA) | 12530 |
| `assets/traffic/pickup_a.glb` | `pickup_a` | double-cab farm pickup, faded white, loaded tray (CORVAN) | 11056 |
| `assets/traffic/tractor_a.glb` | `tractor_a` | farm tractor, green, four-post cab (HALDEN 6140) | 9847 |
| `assets/traffic/van_a.glb` | `van_a` | white panel van with a ladder on the roof (CORVAN) | 11686 |
| `assets/vehicles/car_dogguard_a.glb` | `car_estate_dogguard_a` | estate with a dog guard behind the rear seats | 12607 |
| `assets/vehicles/car_roofbox_a.glb` | `car_estate_roofbox_a` | estate with a roof box | 12609 |
| `assets/vehicles/farm_trailer_a.glb` | `farm_trailer_a` | small farm trailer, mesh sides and a ramp gate | 3152 |
| `assets/vehicles/farm_truck_a.glb` | `farm_truck_a` | older farm pickup on a flatbed with a toolbox | 9304 |
| `assets/vehicles/hay_trailer_a.glb` | `hay_trailer_a` | tandem bale trailer loaded with small square bales | 7156 |
| `assets/vehicles/parked_car_a.glb` | `car_estate_a` | parked estate, grey, muddy | 12530 |
| `assets/vehicles/parked_car_b.glb` | `car_hatch_a` | parked small hatchback, faded green | 10350 |
| `assets/vehicles/parked_car_c.glb` | `pickup_b` | parked older farm pickup (BRASK) | 10369 |
| `assets/vehicles/parked_van_a.glb` | `van_b` | parked delivery van, white, blank panels | 10636 |

New lane/vehicles recipes (`tools/blender/vk_farm.py`, built by `build_vehicles.py`, listed in `game/vehicle_manifest.gd`):
`farm_trailer_a` (a 3 m single-axle mesh-sided farm trailer with a ramp gate, `tailgate_open/_close`), `hay_trailer_a` (a 7.3 m
tandem bale trailer, three layers of small square bales), `farm_truck_a` (the older pickup cab on a flatbed with a headache rack
and toolbox), `car_estate_roofbox_a`, `car_estate_dogguard_a`, `cruiser_1984_flat` (rear left tyre flat). Dirt overlay atlas:
`assets/textures/vehicle_dirt_atlas.png` (layout in `assets/traffic/manifest.md`).

Checks: `test/sites_blender_test.gd` (headless: every site file loads through SiteAssets with its named nodes and LODs, finite,
the manifest's size, on its base, no floating parts, no inside-out solids, front probes measured again on the imported scene,
winding matches normals, every material a known `site_*` key, LOD ranges, the cave mouth unshaded, `fit_ramp`; and every
vehicle-brief file: wheel nodes on the hub, head lamps at -Z and tail lamps at +Z, an emissive `headlight`, on the ground,
colliders). `test/vehicles_blender_test.gd` covers the new recipes. Sheets: `test/sites_sheet.gd` (five views per asset,
`mode=grid` overview, `a+b@x_z_yaw` groups), `test/sites_textures_sheet.gd`, `test/fleet_sheet.gd`, written to
`docs/realism/models/sites_*.jpg`.

## Phone app art (lane appui2)

2D art for `docs/CLAUDE-PHONE-APP-UI-PASS.md` and `docs/CLAUDE-APP-ASSETS.md`, on top of the tablet kit (`assets/ui/tablet`).
Everything is in `assets/ui/` at the exact paths the code loads: `icon_<key>.png` (chat, studio, photos, jobs, casebook, market,
map, settings, recents, home, search; plus weather, camera, phone), `avatar_<key>.png` (maya, jo, riley, tom, alex, sam,
rennick, unknown, you, wren, kit), `item_<id>.png` (Facade tiles), the Casebook kit (`casebook_*`, and the `case_art` keys
`stamp_evidence.png`, `stamp_case_closed.png`), status/nav glyphs, badges, channel marks, act stamps, app glyphs, Map art,
banners and thumbnail overlays. Fonts in `assets/fonts/` (Work Sans, IBM Plex Serif, IBM Plex Mono; OFL).
- Generators: `tools/ui_art/build_appui.py` (Pillow) and `tools/blender/appui_portraits.py` / `appui_products.py` (Cycles).
- Contract: no baked text; root PNGs are 2x the nominal size, natives in `assets/ui/sizes/<px>/`; 9-patch margins and
  pivots in `assets/ui/APPUI-MANIFEST.md`; licences in `assets/ui/APPUI-README.md`.
- Check: `Godot --headless --path godot -s res://test/appui_paths_test.gd -- group=all` prints `APPUI PATHS PASS`.
- Sheets: `docs/realism/appui2/*.jpg` (one per group, with file names), `docs/realism/models/appui2_final_views.jpg`,
  `appui2_final_textures.jpg`.

## Avatars (lane/avatars)

The eleven chat and Casebook avatars are illustrated emblems, not people renders (Robert's call): a prop, animal, mascot
or mark per account, one rounded tile, border and palette, a different style family per person. Same file names and sizes
as appui2 (`assets/ui/avatar_<key>.png` 512, `sizes/96|48/avatar_<key>.png`, `avatars/cutout/<key>.png`), so no code
change. Generator `tools/ui_art/build_avatars.py --sheet` (Pillow, 2048 px master); `build_appui.py` now calls it instead
of the retired portrait path. Cast table in `assets/ui/APPUI-README.md`. Sheets `docs/realism/models/avatars_final_views.jpg`
and `avatars_final_textures.jpg`. `test/appui_paths_test.gd` also checks the 96/48 and cutout variants.

## Wreck and dive van (lane/wreckvan)

The two endgame vehicles that were still missing from `docs/story/CLAUDE-ENDGAME-ASSETS.md`, modelled in Blender with the
lane/vehicles kit (`tools/blender/vk_wreckvan.py`, registered by `build_vehicles.py`; regenerate with
`blender -b --factory-startup --python godot/tools/blender/build_vehicles.py -- only=anne_car_wreck_a,police_dive_van_a`).
Same contract as Blender 3: one rigged glTF each in `assets/models/vehicles/`, LOD0/1/2 on one armature (25 m / 80 m),
AO baked into the vertex colour, the condition in the vertex alpha, baked actions, an entry in `game/vehicle_manifest.gd`,
defect checks (floating parts, inside-out solids, paint facing out). `StoryAssets.instance/place` routes both names (and the
posed variants) to these files, turns them to the story frame (+Z front) and adds the colliders.

| Name | What it is | Notes |
|---|---|---|
| `anne_car_wreck_a` | Anne Voss's car: a 1970s pale blue estate, ARDEN 1300 (fictional), 4.3 m, forty years in the lake | sunk 0.34 m into a silt bed (origin = the silt surface), nose down 2.5 deg, listing 3 deg to the driver's side; front left corner crumpled and that headlamp lens gone; roof sagged over the rear seats; windscreen holed on the passenger side and crazed round an impact on the driver's side, driver's window and right rear quarter light gone, a hole in the right rear door glass, tailgate glass mostly out; heavy rust (condition field) and a photographed rust-spotted paint; sedge tufts, limp pondweed and shoots through the silt in the cabin; dried weed draped over the roof and bonnet; plates blank; no bodies, nothing inside but rotted seats and silt |
| `police_dive_van_a` | Halloway Provincial Police dive team van (fictional livery, no crests or badges), CORVAN high-roof panel van, 5.9 m | blue band with yellow lines, HALLOWAY PROVINCIAL POLICE, UNDERWATER SEARCH AND RECOVERY, DIVE UNIT, POLICE / DIVE UNIT on the barn doors; lightbar, red and blue rear beacons, amber rear traffic bar, grille flashers; roof rack with two aluminium cases, a yellow rescue board and poles; ladder on the right barn door; diver-down flag (red, white diagonal) on its own bone; barn doors and sliding door open onto a lined cargo bay with a ply floor, a rack of six cylinders, a shelf of cases, a bench with drysuits and fins, crates and a coil of rope |

- **Silt bed and water line.** The wreck's silt bed is part of its model, on the `root` bone (it does not ride the body): a
  heightfield that rises in a lip against the panels, fills the cabin to the seat bases, ripples, and tucks 5 cm under the
  ground at its wavering edge, so place the wreck on the lake bed or shore at ground level. The manifest's `"sunk": 0.5` says
  how far below the origin the buried parts may go (faces wholly under the silt are dropped); its `"wreck"` entry gives the
  shaders the old water line (`silt_line` 0.38 m above the origin: silt and algae below, a tide mark, dried silt on top
  faces above, silted glass below) and the paint photo. Change the line on a placed wreck with
  `set_shader_parameter("silt_line", h)` on its materials (the materials are shared by every instance of the wreck).
- **New material slots** (`VehicleAssets.SLOTS`): `silt` (kind 8 of `vehicle_body.gdshaderinc`: the mud photo and its
  normal map, wet glossy hollows), `weed` and `weed_dry` (both sides), `crack` (glass cracks), `kit_yellow` (dive kit).
  The include gains `silt_line`, `silt_tex/silt_scale` and `paint_tex/paint_scale/paint_amount`, the glass shader
  `silt_line`; all default off, so no other vehicle changes.
- **Named parts.** Bones as every Blender vehicle (`root body wheel_* steer_f* door_fl door_fr door_rl door_rr bonnet
  wiper_* steering_wheel`), plus `tailgate` on the wreck and `door_rear_l door_rear_r door_slide_r dive_flag` on the van.
  `StoryAssets` adds the brief's node names as BoneAttachment3D: `wheel_fl..wheel_rr`, `door`, `boot_lid`, `bonnet` (wreck);
  `wheel_fl..wheel_rr`, `door`, `rear_door_l`, `rear_door_r`, `side_door`, `dive_flag` (van). Lamps are material slots,
  lit with `VehicleAssets.set_lights(v, {"beacon_red": 1, "beacon_blue": 1, "beacon_amber": 1, "head": 1})`.
- **Poses** (`VehicleAssets.ALIASES`): `police_dive_van_a_rear_open`, `police_dive_van_a_side_open`, `police_dive_van_a_open`
  (both). The wreck has no open pose (its doors are buried in silt); its actions exist but are for the recovery scene only.
- **Colliders:** the wreck's two boxes cover the body only (none on the silt bed or the weed); the van's are the usual two.
- **Not made here:** `anne_car_door_a` (a loose door and boot lid) and `police_boat_a`.
- Checks: `test/vehicles_blender_test.gd` (sizes, budgets, sunk depth, named nodes through StoryAssets, the open pose, the
  silt line on the paint). Sheets: `test/vehicles_blender_sheet.gd -- names=...` and `test/wreckvan_textures_sheet.gd`,
  written to `docs/realism/models/wreckvan_final_views.jpg` and `wreckvan_final_textures.jpg`. Texture sources:
  `assets/textures/README.md` "Wreck and dive van".


## Tablet OS, notifications and flight HUD art (lane osui)

UI art, not 3D models; recorded here so every lane is listed. Everything is under ssets/ui/osui/ (Material 3
adaptive app icons in circle/squircle/themed/mono forms, Material Symbols rasterised at 24/32/48/96, Material 3
component kit light and dark with states, the flight-HUD icon set with four button states and the thermal/night
camera-mode buttons, map symbology with map_style.json, per-app splash/header/empty-state art), plus the downloaded
permissive icon sets in ssets/ui/svg/ (LICENSES.md) and Roboto / Roboto Mono in ssets/ui/fonts_osui/.
Generator: 	ools/ui_art/osui/build_osui.py. Spec and implementation checklist for session B:
docs/OS-UX-SPEC-2026-10-24.md. Manifest: ssets/ui/osui/OSUI-MANIFEST.md. Sheets:
docs/realism/models/osui_final_views.jpg, osui_final_textures.jpg; mocks in docs/realism/osui/.
No game code was changed; nothing loads these files until B wires them.

## Anti-drone (lane/antidrone)

Harlan Pike's ridge and his hunter drones (brief `docs/CLAUDE-ANTI-DRONE-ASSETS.md` on lane/notify), modelled in Blender 4.2 by
`tools/blender/build_antidrone.py` (`antidrone_lib.py` on the sites kit, `antidrone_pike.py`, `antidrone_hunters.py`; textures
first with `python -I tools/blender/make_antidrone_textures.py <godot dir>`), exported to `assets/models/antidrone/<name>.glb`
and loaded by `game/antidrone_assets.gd` (class `AntiDroneAssets`). `game/antidrone_manifest.gd` (generated) lists every
file's nested named nodes (parent, pivot, rot), sizes, triangle counts, LOD distance, metadata and the Blender-side checks.
Fictional and homemade: no real brands, insignia or readable text, no weapons (the brief's shotgun prop is deliberately not
made; the toolbox has no gun-cleaning kit), no gore; the hex hunter's net pod is closed and empty.

**Frame:** metres, Y up, **+Z is the front** (trailer hitch, shack door, board and sign faces, hunter noses; a hunter's right is
-x), origin at the base (hunters: the ground under the skids; `meta.centre` is the middle of the airframe).

**Moving parts** (own nodes, clean pivots): trailer and `pike_jammer_mast`: `mast` (hinge pin at the deck, y 0.62; rotate about
local x by `meta.lower_deg` 88 to lay it forward over the drawbar) > `mast_stage_2` > `mast_stage_3` (slide down local y to
telescope) > `dish` (1.1 m, turn about y) and `beacon` (caged, `ad_lamp_red`); top-level `guy_wires` (hide when the mast is
down), `trailer_wheel_l/_r` (on the hub), `trailer_hitch`, `stencil` (the NO DRONE spray decal). Shack: `door` (hinged on its
right edge seen from outside; rotation.y +80 opens it outward), `shack_generator_lamp`. Hunters: `body`, `eye` (red emissive lens
at the nose), `rotor_1..4` (`rotor_1..6` on `hunter_drone_b`; rotor_1 front right then clockwise from above; spin about local y,
`meta.spin` +1 = anticlockwise from above), `net_pod` > `pod_door` (b), `strobe` (c). Log pile: `axe`. Floodlight:
`floodlight_head`. The mast is 14 m to the head (the brief's figure; lane/notify's code placeholder is 24 m), the beacon on top,
whip aerials to 15.1 m.

**Calls:** `AntiDroneAssets.place(parent, name, Transform3D, opts)` / `instance(name, opts)` (opts `lod_scale`, `lamps`);
`set_beacon(node, on)`, `set_lamp(node, key, energy)`, `lower_mast(node, t)` (0 standing .. 1 down; hides the guys and puts the
beacon out), `spin_rotors(node, delta, rev_per_s)`, `flash(node, time)` (double-blink strobe), `drape(node, height_fn)` (ground
pieces), `text_rect(name)` (blank faces for Label3D: `pike_manifesto_board` 0.96 x 0.88 m sheet centred (0, 1.53, 0.05);
`pike_warning_sign` 0.84 x 0.54 m centred (0, 1.3, 0.04)), `has`, `names`, `info`, `meta`. A missing file gives a stand-in box
of the manifest size; a missing hunter gives a code-built quad or hex with the same `body`, `eye`, `rotor_N` names.

**Materials:** `site_*` keys are swapped by `SiteAssets.mat` (shared photographed sets), `ad_*` by `AntiDroneAssets.mat`
(photographed: paint, rust, planks, ply, corrugated iron, the drones lane's carbon, plastic, motor and strap sets; drawn: the
clearing ground, papers, stencil, tyre marks, smoke, strobe), all multiplied by the vertex colour (occlusion times rust and dirt).
Lamps are emissive materials, not lights: `ad_lamp_red` (beacon, antenna; on), `ad_lamp_eye` (on), `ad_lamp_strobe` (on;
`flash`), `ad_lamp_amber` (generator; on), `ad_lamp_white` (floodlight; off), `ad_lamp_green` (radio LED). Textures and
licences: `assets/textures/README.md` (lane/antidrone) and `docs/realism/models/antidrone_final_textures.jpg`.

| Asset | Size x, y, z (m) | Tris LOD0 / LOD1 | Named nodes |
|---|---|---|---|
| `hunter_drone_a` | 0.9 x 0.3 x 0.8 | 2028 / 1293 | `body`, `eye`, `rotor_1`, `rotor_2`, `rotor_3`, `rotor_4` |
| `hunter_drone_b` | 1.0 x 0.5 x 1.0 | 2884 / 1894 | `body`, `eye`, `net_pod`, `pod_door`, `rotor_1`, `rotor_2`, `rotor_3`, `rotor_4`, `rotor_5`, `rotor_6` |
| `hunter_drone_c` | 0.5 x 0.1 x 0.6 | 2308 / 1199 | `body`, `eye`, `rotor_1`, `rotor_2`, `rotor_3`, `rotor_4`, `strobe` |
| `hunter_net_pod` | 0.2 x 0.2 x 0.4 | 376 / 254 | `net_pod`, `pod_door` |
| `hunter_rotor` | 0.5 x 0.1 x 0.5 | 960 / 550 | `guard`, `rotor_1` |
| `pike_beacon` | 0.2 x 0.2 x 0.1 | 560 / 336 | `beacon` |
| `pike_cable_run` | 0.6 x 0.2 x 8.2 | 712 / 356 | `cable` |
| `pike_chair` | 0.8 x 0.9 x 0.6 | 536 / 322 | `chair`, `thermos` |
| `pike_clearing_patch` | 11.9 x 0.1 x 12.0 | 1554 / 776 | `clearing_ground` |
| `pike_fence` | 4.2 x 1.7 x 0.5 | 592 / 286 | `pike_fence_posts`, `pike_fence_wire` |
| `pike_fence_8m` | 8.1 x 1.7 x 0.5 | 1120 / 536 | `pike_fence_8m_posts`, `pike_fence_8m_wire` |
| `pike_fence_folk` | 4.1 x 1.8 x 0.7 | 1338 / 620 | `pike_fence_folk_folk`, `pike_fence_folk_posts`, `pike_fence_folk_wire` |
| `pike_floodlight` | 0.6 x 0.8 x 0.6 | 248 / 248 | `floodlight_head`, `floodlight_stand` |
| `pike_generator` | 1.5 x 0.6 x 0.6 | 996 / 562 | `generator`, `generator_fuel_can`, `generator_lamp`, `generator_reel` |
| `pike_jammer_mast` | 11.3 x 15.2 x 9.8 | 3316 / 1588 | `beacon`, `dish`, `guy_wires`, `mast`, `mast_base`, `mast_stage_2`, `mast_stage_3` |
| `pike_jammer_trailer` | 11.3 x 15.2 x 9.8 | 6178 / 2852 | `beacon`, `dish`, `guy_wires`, `mast`, `mast_stage_2`, `mast_stage_3`, `stencil`, `trailer_body`, `trailer_hitch`, `trailer_wheel_l`, `trailer_wheel_r` |
| `pike_log_pile` | 2.0 x 0.9 x 1.1 | 1284 / 675 | `axe`, `chopping_stump`, `log_pile` |
| `pike_manifesto_board` | 2.5 x 2.7 x 0.1 | 64 / 64 | `manifesto_board`, `manifesto_paper`, `manifesto_posts` |
| `pike_mast_wreck` | 4.1 x 0.2 x 13.7 | 1056 / 558 | `mast_wreck`, `mast_wreck_cage`, `mast_wreck_dish`, `mast_wreck_guy` |
| `pike_radio` | 0.8 x 4.4 x 0.4 | 624 / 300 | `radio`, `radio_aerial`, `radio_crate`, `radio_led` |
| `pike_ridge_antenna` | 1.4 x 21.0 x 1.6 | 1244 / 602 | `antenna_lamp`, `antenna_tower` |
| `pike_shack` | 4.8 x 3.0 x 3.5 | 3790 / 1788 | `door`, `shack_barrel`, `shack_generator`, `shack_generator_lamp`, `shack_lean_to`, `shack_roof`, `shack_tarp`, `shack_walls` |
| `pike_smoke` | 1.2 x 4.5 x 1.0 | 6 / 6 | `smoke` |
| `pike_strobe_card` | 0.8 x 0.8 x 0.0 | 2 / 2 | `strobe_card` |
| `pike_tarp` | 1.6 x 0.5 x 1.3 | 922 / 414 | `tarp` |
| `pike_toolbox` | 1.1 x 0.4 x 0.5 | 632 / 282 | `toolbox`, `toolbox_tools` |
| `pike_tyre_tracks` | 2.2 x 0.0 x 6.0 | 48 / 48 | `tyre_tracks` |
| `pike_warning_sign` | 0.9 x 2.0 x 0.1 | 106 / 106 | `warning_sign_board`, `warning_sign_post` |

Brief items folded or added: the beacon on its own (`pike_beacon`) and on the mast; the generator on its own and under the
shack's lean-to; the 4 m and 8 m fences plus `pike_fence_folk` (deer skull and rag ribbons); `pike_clearing_patch` (the clearing
texture on a draped disc); `pike_strobe_card`; `pike_tyre_tracks` (wheel tracks and the jerked drag mark as decals);
`pike_ridge_antenna` (the distant 18 m antenna). Textures only: `pike_ridge_clearing.jpg` (+ `_nor`, `_arm`),
`pike_no_drone_stencil.png`, `pike_manifesto_paper.png`, `pike_paper_blank.png`, `pike_notice_stack.png`, `pike_strobe_card.png`,
`pike_smoke_card.png`, `pike_tyre_marks.png` (in `assets/textures/`).

**Checks:** `test/antidrone_blender_test.gd` (headless: every brief file present and loading, nested nodes under their parents
at the manifest's pivots, LODs, size, on its base, no floating parts or inside-out solids, probes, winding, materials, the
brief's budgets, lamps emissive, mast hinge at the deck and beacon at 14 m, `lower_mast`, rotors on their hubs spinning about y,
the eye at the nose, the door's hinge, text faces, stand-ins). Sheets: `test/antidrone_sheet.gd` (views, `mode=grid`,
`light=night`, `fit=<node>`, groups `a+b@x_z_yaw_y`) and `test/antidrone_textures_sheet.gd`, written to
`docs/realism/models/antidrone_final_views.jpg` (every asset), `antidrone_views_golden.jpg` and `antidrone_views_props.jpg`
(five views with the mast-head and hunter-eye close-ups), `antidrone_final_scene.jpg` (trailer, shack, board, sign and the three
hunters at real scale in the clearing), `antidrone_night.jpg`, `antidrone_final_textures.jpg`.

**Honest limits:** low-poly homemade forms; the dish is a smooth paraboloid with no mesh grid; wires and guys are 4 to 8 mm
tubes that vanish beyond about 40 m; the corrugated roofs are sine heightfields; the tarp is a heightfield with nothing under
it; the hunters are 2 to 3k triangles, so motors and props are simple; the smoke is three crossed cards, not particles; rotor
blur, the net and the mast animation are left to the code (the nodes and helpers are ready).

## Anti-drone people (lane/antidrone, job 2)

Nineteen more rigged people for `PeopleAssets` (Blender 2 contract above: same MakeHuman rig, 53 bones with Godot humanoid
names, LOD0..2, face blend shapes, and the 33 shared clips from `anim_male.glb` / `anim_female.glb`), built by
`sh run_people.sh people_build.py -- <names>` from the entries at the end of `tools/blender/people_roster.py`:
`ifeoma_okafor`, `mei_lin`, `ravi_patel`, `grace_adeyemi`, `hana_sato`, `priya_nair`, `daniel_whitlock`, `arthur_bell` (the village
cast of `docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md`, ages, heights, skin tones 0 to 8 and costumes from the brief), `maya`, `jo`,
`riley`, `tom`, `alex`, `sam`, `kit` (the crew, matching their app portraits), `harlan_pike`, `farmer`, `nora_pike`,
`councillor_bain`. **`wren` is rebuilt to the brief** (rich brown skin, crop, mustard rain jacket on the `coat` mesh, dark
trousers, brown scarf, backpack); the old red-jacket Wren is gone. Routing: `PeopleAssets.BODY` lists them (so
`StoryAssets.instance("<name>")` and `PeopleAssets.person("<name>", clip)` work), and `PeopleAssets.ALIASES` /
`PeopleAssets.resolve(name)` map display names ("Ifeoma Okafor", "Ada Okafor", "Riley", "Harlan Pike") to files. Sheets:
`docs/realism/models/antidrone_final_people_views.jpg` (three-quarter and face, Godot render) and
`antidrone_final_people_textures.jpg`. Checks: `test/people_blender_test.gd` (all 38 people). Note for lane/notify:
`case_objects.gd` there tints Wren's skin darker (`PeopleAssets.tint_skin(_hiker, Color(0.56, 0.40, 0.30))`); with the rebuilt
Wren that tint should be removed, or Wren goes near black.
