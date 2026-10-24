# Claude endgame asset brief: the cabin, the cruiser, Wren and the last flight

Status: production request, 2026-11-04. This is the asset plan for the ending of the narrative in AeroSim, the last flight in The Lake Car. It extends the story asset requests for the camp, the festival and the storm. The cabin, 1980s cruiser, hiker, ghost officer, cabin interior, case file and thermal pod are currently code placeholders; every Priority 0 item replaces something the player can already fly to in the finale.

Owner of the story and placement: session B. Fictional Halloway Provincial Police, fictional valley, nothing based on a real force or a real person.

## The scene the assets have to sell

A storm at night, forty years after a police officer died on an abandoned plot. An old weatherboard cabin with warm windows in the rain. A 1980s provincial police cruiser, rusted and dark, still parked where she left it. A lost hiker called Wren, cold and turned around in the treeline, visible as a white-hot shape through the thermal camera. A ghost in an old uniform who is never quite there. Then the fade and the credits.

## Shared contract

- glTF 2.0 binary `.glb`, metre scale, Y up, origin at the base, +Z forward, one root node per asset.
- Low poly: props 200 to 2,500 triangles, characters 1,200 to 3,000, cabin and cruiser 4,000 to 8,000. LODs where it matters.
- Kit materials and vertex colours, muted late autumn and wet 1980s rural palette. Separate materials for glowing windows, headlights, lightbar and thermal surfaces.
- Static posed character variants. No rigs required. For Wren, poses are separate exports so the game can place them without a humanoid animation system.
- Separate named nodes for the cruiser's wheels and doors, the cabin door and windows, and any lamp glass that should glow.
- Colliders only on the cabin, the cruiser, Anne's wreck and the fallen tree. No colliders on props, cloth, paper or people.
- Fictional signage only: HALLOWAY PROVINCIAL POLICE, HALLOWAY, THE OLD PLOT, VOSS AND SON. No real badges, plates or brands.
- No weapons, no handcuffs on show, no bodies, no gore, no horror props. The ghost is quiet and human.
- Where a model has to work with the thermal camera, keep the body and clothing as separate named nodes if possible (`body`, `head`, `backpack`, `coat`) so a heat mask can be applied cleanly.

## Priority 0: the ending set

### 1. The abandoned cabin
A small 1980s weatherboard cabin that has been empty for forty years.

| Asset | Description | Variants |
|---|---|---|
| `cabin_abandoned_a` | 8 m by 6 m weatherboard cabin, pitched roof with a broken patch, porch, one door, two front windows, chimney, rotten steps, about 4 m tall | complete, missing roof sheets |
| `cabin_door_a` | plank door, warped, handle, separate hinge node | closed, ajar, open |
| `cabin_window_a` | two-pane wooden window, separate glass node, warm emissive material for the lit variant | dark, warm interior light, cracked |
| `cabin_chimney_a` | stone chimney with a leaning cap | one |
| `cabin_porch_light_a` | small exterior lamp with a separate bulb node and warm glow | on, off |
| `cabin_woodpile_a` | stacked split logs and kindling under the porch | one |
| `cabin_lean_to_a` | small lean-to with a tarpaulin and a few tools | one |

### 2. The 1980s provincial police cruiser
The emotional centre of the outdoor scene. A boxy 1980s saloon that has been sitting in the same spot since 1984.

| Asset | Description | Variants |
|---|---|---|
| `cruiser_1984_a` | boxy four-door saloon, white body, dark roof and doors, faded HALLOWAY PROVINCIAL POLICE door lettering, rusted sills, a lightbar, separate wheels, separate doors, simple interior visible through the glass, about 4.6 m long | closed, driver's door open, all doors open |
| `cruiser_lightbar_a` | low 1980s lightbar with separate red and blue lamp nodes and glass material, unlit in the scene but switchable | one |
| `cruiser_plate_a` | fictional provincial plate and a 1984 tax disc | one |
| `cruiser_aerial_a` | long whip radio aerial, slightly bent | one |
| `cruiser_door_lettering_a` | decal or texture: HALLOWAY PROVINCIAL POLICE, 1984 style, fictional | one |
| `cruiser_boot_kit_a` | old roadside kit: jack, warning triangle, blanket, first aid tin | one |

### 3. Wren, the lost hiker
Wren is the person behind the unknown account. They are cold, tired, turned around and very glad to see the drone. They are never a body on the ground; they are alive and waving.

| Asset | Description | Variants |
|---|---|---|
| `wren_standing_phone_a` | 1.72 m adult in a rain jacket, walking trousers and boots, backpack, holding a phone, hood up | one |
| `wren_sitting_porch_a` | sitting on the cabin step, backpack beside them, arms wrapped around their knees | one |
| `wren_walking_torch_a` | walking with a torch, one arm out for balance, looking up | one |
| `wren_waving_a` | standing, waving at the drone, relieved | one |
| `wren_crouched_a` | crouched behind a fallen branch, cold | one |
| `wren_backpack_a` | separate hiking backpack with a side pocket and a wet cover | one |
| `wren_phone_a` | separate phone, screen glowing | one |
| `wren_torch_a` | separate torch, on and off | one |

### 4. Constable Ada Rennick, 1984 and after
The officer has been a voice in the server for the whole story. The ending may show her once, briefly, as a translucent figure at the cabin, or not at all.

| Asset | Description | Variants |
|---|---|---|
| `rennick_1984_standing_a` | provincial uniform, cap, duty belt with radio and torch but no weapon, boots, practical coat | neutral, holding a notebook |
| `rennick_1984_ghost_a` | the same uniform and pose, pale, translucent, no hard edges, for the cabin apparition | one |
| `rennick_1984_portrait_a` | small 1980s portrait photograph for the case file, waist up, neutral expression | one |
| `rennick_hat_a` | separate cap and badge, fictional | one |
| `rennick_case_file_a` | cardboard case file with a photo clipped to the front, 1984 | one |

### 5. Cabin interior and the case
The cabin should read as a place where a police officer once took shelter and never left, and where a hiker recently stayed.

| Asset | Description | Variants |
|---|---|---|
| `cabin_bed_a` | old iron or timber bed, bare mattress, folded blanket | made, stripped |
| `cabin_table_a` | small kitchen table, one drawer | one |
| `cabin_chair_a` | two mismatched wooden chairs | two |
| `cabin_stove_a` | small cast-iron stove with a pipe and a kettle | cold, lit |
| `cabin_shelf_a` | shelf with tins, a candle and an old radio | one |
| `cabin_radio_a` | 1980s police radio set and handset, plus a separate handheld set | one |
| `cabin_case_file_a` | open case file, loose papers, a map and a photograph | one |
| `cabin_calendar_a` | wall calendar open on 1984 | one |
| `cabin_uniform_a` | uniform jacket and cap hanging on a hook | one |
| `cabin_boots_a` | pair of wet boots by the door | one |
| `cabin_lantern_a` | storm lantern, lit and unlit | two |
| `cabin_kettle_a` | old kettle with steam material | one |
| `cabin_drawing_a` | child's drawing of a funnel and a lake, pinned to the wall, not scary | one |
| `cabin_map_a` | folded 1980s valley map with a route marked | one |
| `cabin_hiker_gear_a` | wet jacket, walking poles and a small food bag left behind | one |

### 6. The thermal camera pod
The hardware that Alex fits to the drone for the search.

| Asset | Description | Variants |
|---|---|---|
| `thermal_pod_a` | small gimbal-mounted pod, lens, heat fins, status LED, fits under the Gimbal Mini's camera | one |
| `thermal_pod_led_a` | separate LED with a warm/white emissive material | on, off |
| `thermal_pod_mount_a` | bracket and cable for the drone | one |

### 7. Anne Voss's car and the lake
The missing woman's car was never found. It can be used in the epilogue, a final lake discovery shot, or the credits.

| Asset | Description | Variants |
|---|---|---|
| `anne_car_wreck_a` | 1970s or early 1980s estate, half-submerged in lake silt, weeds, broken windows, pale blue body, about 4.3 m | one |
| `anne_car_door_a` | separate open door and boot lid | one |
| `lake_buoy_a` | small police dive buoy, white and blue, floating | one |
| `dive_marker_a` | weighted marker line and small flag | one |

## Priority 1: the last-flight detail

| Asset | Description | Variants |
|---|---|---|
| `cabin_fallen_tree_a` | wind-felled tree across the old track | one |
| `cabin_tyre_ruts_a` | two shallow ruts in mud, a decal or thin mesh | one |
| `cabin_fence_broken_a` | broken post and wire fence | one |
| `cabin_old_sign_a` | faded THE OLD PLOT sign on a leaning post | one |
| `wren_space_blanket_a` | silver foil rescue blanket, folded and wrapped | two |
| `wren_water_bottle_a` | plastic water bottle, half empty | one |
| `cabin_thermos_a` | old thermos and two enamel mugs | one |
| `cabin_newspaper_a` | 1984 local newspaper front page, fictional storm headline | one |
| `cabin_yard_tools_a` | old spade, bucket and a coil of rope | one |
| `cruiser_old_kit_a` | police roadside kit: torch, blanket, first aid tin, map | one |
| `cabin_radio_aerial_a` | old radio aerial by the cabin | one |

## Priority 2: epilogue and future cases

- `police_dive_van_a` and `police_boat_a` for the lake recovery in the epilogue or a later case.
- `cabin_search_flag_a` and `search_tape_a` for the recovery scene.
- `wren_tent_a` and `wren_hiking_gear_a` for a small lost-hiker case.
- `anne_photo_a` for the case file and the festival archive.
- `cabin_interior_variant_a` for a second cabin in the valley.
- `cabin_chimney_smoke_a` with a simple smoke card and a warm light.

## What each priority unlocks

- Priority 0 makes the last flight and the ending visually real: cabin, cruiser, Wren, Rennick, interior, case and thermal pod.
- Priority 1 makes the storm search legible from the air and gives the close-up evidence and the rescue a physical texture.
- Priority 2 lets the epilogue and the recurring cases reuse the same set.

## Integration notes for the modeller

- Root names should stay close to the asset names above where possible.
- The cabin should have a `windows` group and a `door` node so the game can switch the lights.
- The cruiser needs `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr`, `door_driver`, `door_passenger`, `lightbar_red`, `lightbar_blue` as separate nodes.
- Wren should have `body`, `head`, `backpack` and `coat` nodes, and a compact silhouette that still reads from 60 m.
- Rennick's ghost variant should use an alpha material with a soft rim, not a glowing monster.
- The thermal pod should mount on the existing Gimbal Mini camera without clipping the gimbal arms.
- No collision on the cabin interior props, the Wren poses, the case file or the thermal pod.

## Delivery

Priority 0 first, then Priority 1, then Priority 2. The ending is already playable with code placeholders; every Priority 0 model replaces something the player can fly to, land near or photograph today.
