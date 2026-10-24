# Claude asset brief: The Lake Car and Halloway

Status: production request, 2026-11-02. For Claude's 3D asset lane. This extends the earlier story asset request on the board; the abandoned car, the police vehicles, the garage shell, the festival bus, the basic camp props, the evidence props and the Halloway high street were already asked for. This brief is the consolidated, fuller list the finished arc now needs, with the new characters, interiors, festival set and details that were not in the first pass.

Owner of the story and placement: session B. Fictional town of Halloway, fictional Provincial Police detachment. Nothing here should be a real police badge, real livery or a real person.

## House rules for all of these

- Metre scale, Y up, origin at the base, +Z forward, one root node per asset.
- Low poly: props 200 to 2,000 triangles, characters 1,000 to 2,500 triangles, bus 4,000 to 6,000 triangles. Near, mid and far LODs where it matters.
- Kit materials and vertex colours, consistent with the existing models. No external textures unless this brief asks for a texture or decal.
- Muted late autumn rural palette, weathered wood, painted metal, faded canvas.
- Characters are static posed variants rather than full rigs. Poses are separate exports so the game can place an Ellis sitting under the bus, an Ellis waving, and a Rennick with a clipboard without a humanoid animation system. If simple idle or walk cycles are cheap, they are welcome, but poses are the requirement.
- Separate named nodes for moving parts: bus wheels (`wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr`), bus door, bus destination board; tractor wheels if reused for the parade.
- Colliders only where a drone could hit something: the car, the garage, the bus, benches, fences and the police house. No colliders on people, crops, bunting or camp soft goods.
- No weapons, no tactical gear, no handcuffs shown, no gore. The police are doing a welfare check, not a raid.
- Fictional signage only: `HALLOWAY PROVINCIAL POLICE`, `VOSS & SON MOTOR WORKS`, `HALLOWAY FESTIVAL`, `HALLOWAY`, `THE OLD GARAGE`. No real department or brand markings.

## Priority 0: needed to finish the story properly

### 1. Ellis Voss and Biscuit
The man at the heart of the arc and his dog. They stand at the camp and by the bus, and Ellis should read as a retired mechanic in his seventies, not a generic mannequin.

| Asset | Description | Variants |
|---|---|---|
| `ellis_standing_a` | 1.75 m, flat cap, heavy work jacket, boots, hands in pockets | neutral, hands on hips |
| `ellis_sitting_a` | sitting on a camp chair or a crate, mug in hand | with and without mug |
| `ellis_under_bus_a` | lying on a crawler under the bus, only boots and legs visible | one pose |
| `ellis_waving_a` | standing, one hand raised, slight smile | one pose |
| `ellis_toolbox_a` | open toolbox with old spanners beside him | with tools, closed |
| `biscuit_sitting_a` | medium collie cross, brown and white, 0.55 m at the shoulder | sitting, looking up |
| `biscuit_standing_a` | standing, head up, alert | one pose |
| `biscuit_lying_a` | lying by the tent | one pose |
| `biscuit_running_a` | running, ears back | one pose |
| `dog_bowl_a` | steel bowl with water | empty, full |

### 2. Constable Rennick
A new rural constable in plain clothes with a police jacket, so she fits the valley and does not look like an armed response unit. A uniform variant is useful for the police house.

| Asset | Description | Variants |
|---|---|---|
| `rennick_standing_a` | 1.72 m, practical jacket, trousers, boots, notebook, lanyard | neutral, holding clipboard |
| `rennick_walking_a` | walking with purpose, hands free | one pose |
| `rennick_knocking_a` | at a door, notebook in the other hand | one pose |
| `rennick_uniform_a` | provincial uniform jacket, cap, no weapon belt, small radio | standing, writing |
| `police_clipboard_a` | clipboard with paperwork | one |

### 3. Camp set
The camp needs to feel lived in, not like a tent catalogue. Everything is low poly and can be a static prop.

| Asset | Description | Variants |
|---|---|---|
| `camp_tent_a` | green two-person A-frame tent, about 2.4 m by 1.6 m | closed, open flap |
| `camp_tent_b` | low basha or tarp shelter, darker canvas | one |
| `camp_tarp_a` | blue tarp stretched over the camp table and gear | one |
| `camp_stove_a` | small two-ring camping stove with a gas bottle | burning, cold |
| `camp_lantern_a` | battery lantern with a warm emissive glass | on, off |
| `camp_chair_a` | folding canvas chair | one |
| `camp_table_a` | small folding camp table | one |
| `camp_cooler_a` | old cooler box, faded | one |
| `camp_fire_ring_a` | ring of stones with ash and charred logs | lit, cold |
| `camp_firewood_a` | small pile of cut logs | one |
| `camp_axe_a` | axe in a log, no gore | one |
| `camp_bedding_a` | sleeping bag and roll mat | one |
| `camp_washbasin_a` | enamel basin and water bottle | one |
| `camp_toolbox_a` | old mechanic's toolbox, open | one |
| `camp_sketchbook_a` | open sketchbook with bus sketches | one |
| `camp_programme_a` | folded festival programme, cream paper | closed, open |
| `camp_dog_bed_a` | old blanket bed for Biscuit | one |
| `camp_clothes_line_a` | short line between two poles with a few clothes | one |

### 4. The festival bus, restored and unrestored
The bus is the emotional centre of the final chapter. It needs to read as a 1960s or 1970s single decker that a town would have loved, and as the thing under the tarp in chapter 4.

| Asset | Description | Variants |
|---|---|---|
| `festival_bus_restored` | green single decker, cream roof band, HALLOWAY FESTIVAL lettering and a small Voss and Son plate, seats and a simple interior, roof rack, warm interior light, separate wheels and door, about 9 m long | door open, door closed |
| `festival_bus_garage` | same bus but dusty, one panel primed, tarp half over the roof, no lettering yet | one |
| `festival_bus_destination_a` | destination board reading HALLOWAY FESTIVAL | one |
| `festival_bus_plate_a` | small Voss and Son maker plate for the side | one |
| `festival_bus_seats_a` | a few loose bus seats for the garage | one |

### 5. Garage interior
The pilot photographs the yard and the bus through the door, but the inside should read as a working workshop when the door is open.

| Asset | Description | Variants |
|---|---|---|
| `garage_workbench_a` | heavy wooden bench with vice and tools | tidy, cluttered |
| `garage_tool_cart_a` | rolling tool cart | one |
| `garage_tyre_stack_a` | stack of old tyres | one |
| `garage_oil_drum_a` | oil drum, faded label | one |
| `garage_engine_hoist_a` | engine crane, no engine attached | one |
| `garage_spare_engine_a` | old engine block on a pallet | one |
| `garage_air_pump_a` | hand air pump and hose | one |
| `garage_fuel_pump_a` | old fashioned fuel pump, rusted | one |
| `garage_ramp_a` | steel inspection ramp | one |
| `garage_parts_shelf_a` | shelf of tins, belts and boxes | one |
| `garage_bus_seats_a` | stack of removed bus seats | one |
| `garage_sign_a` | old VOSS & SON sign, weathered | one |

### 6. Festival field set
The final chapter needs a place that reads as a small town festival at dusk, not an empty field. Bunting and lights are the cheapest way to sell it.

| Asset | Description | Variants |
|---|---|---|
| `festival_stage_a` | small flatbed stage with a canvas roof | one |
| `festival_marquee_a` | cream marquee, 8 m by 5 m | one |
| `festival_stall_a` | wooden market stall with striped canvas | two colour variants |
| `festival_bunting_a` | 10 m bunting string with triangular flags, separate segment for repeating | three colour sets |
| `festival_flag_a` | tall festival flag on a pole | two |
| `festival_barrier_a` | wooden crowd barrier, 2 m | one |
| `festival_picnic_table_a` | wooden picnic table | one |
| `festival_lamp_string_a` | 8 m string of warm bulb lights with emissive bulbs | one |
| `festival_pa_a` | small PA speaker on a stand | one |
| `festival_banner_a` | HALLOWAY FESTIVAL banner on two poles | one |
| `festival_sign_a` | painted direction sign to the festival field | one |

### 7. Halloway high street, phase one
The town is the source of the story's authority and the place the officer and Ellis come from. A compact set of fronts is enough; interiors can wait.

| Asset | Description | Variants |
|---|---|---|
| `town_police_house_a` | small rural police house with a notice board and a blue lamp | one, door open and closed |
| `town_pub_a` | village pub front, warm windows | one |
| `town_village_hall_a` | hall with a notice board and a small stage entrance | one |
| `town_shop_a` | small shop front with a post card stand | one |
| `town_shop_b` | second shop, maybe a butcher or a garage parts shop | one |
| `town_bus_shelter_a` | wooden bus shelter with a timetable | one |
| `town_noticeboard_a` | village notice board with pinned notices | one |
| `town_post_box_a` | red post box | one |
| `town_bench_a` | wooden bench | one |
| `town_lamp_post_a` | simple iron lamp post with a warm bulb | one |
| `town_bin_a` | metal litter bin | one |
| `town_sign_halloway_a` | HALLOWAY village sign | one |

## Priority 1: immersion and the living edge

### 8. Festival crowd and band
These are low-poly posed people to stand around the field. They are not close-up characters and do not need faces.

| Asset | Description | Variants |
|---|---|---|
| `crowd_stand_a` | adult in a coat and scarf, hands in pockets | 4 colour and pose variants |
| `crowd_walk_a` | adult walking, mid step | 3 variants |
| `crowd_child_a` | child with a flag | 3 variants |
| `crowd_point_a` | person pointing at the bus | 2 variants |
| `crowd_cheer_a` | person clapping or waving | 2 variants |
| `crowd_band_a` | three or four band members with instruments, no weapons | one set |
| `crowd_seated_a` | person on a bench or picnic table | 2 variants |

### 9. Evidence and police detail
Small props for close-up photographs and for the Casebook and garage scenes.

| Asset | Description | Variants |
|---|---|---|
| `police_tape_roll_a` | roll of blue and white police tape | one |
| `police_tape_strip_a` | a short strip of tape, maybe on two posts | one |
| `police_cone_a` | low traffic cone | one |
| `evidence_marker_a` | small numbered tent card | one |
| `evidence_bag_a` | paper evidence bag, no label text | one |
| `police_radio_a` | small handheld radio | one |
| `police_torch_a` | hand torch | on, off |
| `police_notebook_a` | open notebook and pen | one |
| `police_camera_a` | small camera with a strap | one |
| `car_vin_plate_a` | small VIN plate with a generic number | one |
| `car_tow_sticker_a` | VOSS & SON sticker, square | one |
| `car_keys_a` | old car keys on a ring | one |
| `car_glovebox_programme_a` | folded festival programme with a photograph | one |
| `committee_photo_a` | small framed or loose photo of the festival committee, 1970s clothes, no real faces needed | one |

### 10. Reward and Casebook details
The private ending and the Casebook need physical and 2D rewards.

| Asset | Description | Variants |
|---|---|---|
| `livery_voss_son_decal` | 2D texture, small Voss and Son badge for the Gimbal Mini | one |
| `drone_badge_voss` | small 3D plate or magnet that can be attached to a drone | one |
| `casebook_badge_voss` | 2D badge or rosette for the Casebook, cream and green | one |
| `festival_rosette_a` | small rosette for the Casebook or the bus | one |

### 11. Camp and garage extra detail
| Asset | Description | Variants |
|---|---|---|
| `camp_dog_lead_a` | lead and collar | one |
| `camp_mug_a` | enamel mug with steam | one |
| `camp_gas_bottle_a` | small gas bottle | one |
| `camp_paper_a` | loose papers and a map on the table | one |
| `garage_bicycle_a` | old bicycle leaning on the wall | one |
| `garage_toolbox_a` | larger rolling toolbox | one |
| `garage_radio_a` | old workshop radio | one |

## Priority 2: later, for the recurring cases and the town

- `town_police_interior_a` simple front desk and notice board, not open world interiors.
- `town_church_a`, `town_school_a`, `town_chip_shop_a`, `town_bakery_a` for the high street.
- `festival_ice_cream_van_a`, `festival_generator_a`, `festival_toilet_a` for the field.
- `parade_tractor_a` and `parade_trailer_a` for next year's festival.
- `lost_dog_a` and `lost_dog_poster_a` for a small recurring case.
- `crop_circle_a` prop and `crop_circle_stencil_a` decal for the barley field case.
- `milk_churn_a` for the pub case.
- `railway_signal_lamp_a` for the ghost light case.

## What this should look like when it lands

1. The camp chapter has a real lived-in camp with Ellis and Biscuit, and the pilot can photograph it from a respectful distance.
2. The bus chapter has a bus with history, inside a garage that looks like it has been worked in for years.
3. The festival chapter has bunting, lights, a marquee and a crowd, so the bus's first run reads as a town event rather than an empty field.
4. The high street gives Rennick and Ellis somewhere to have come from, for the Casebook and the next cases.
5. The reward pieces give the private ending and the Casebook something to show for the time spent.

## File and naming contract

- Export as glTF 2.0 binary (`.glb`) under `assets/models/story/`, grouped as `camp/`, `halloway/`, `festival/`, `evidence/`, `characters/`, `reward/`.
- One root node per asset, origin at the base, +Z forward, metres.
- Materials reuse the existing kit materials and vertex colour setup.
- Separate named nodes for wheels, doors, bus destination board and any lamp glass that needs to glow.
- No collision on people, cloth or crops. Collision on the car, garage, bus, benches, the police house and the town walls.
- Keep sign text fictional and generic. Keep the town and the force fictional. No real badges, brands or people.

If only part of this can be done, Priority 0 first, in the order above. The story is already playable with the code placeholders, so every P0 piece replaces something the player can already fly to and photograph.
