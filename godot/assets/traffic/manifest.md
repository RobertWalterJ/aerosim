# Vehicle brief files (lane/sites)

Made by `tools/blender/build_vehicle_aliases.py` from the lane/vehicles Blender models (`assets/models/vehicles/*.glb`) for
`docs/CLAUDE-VEHICLE-ASSETS.md` (lane/notify). Generated table below; contract in `game/README-models.md`, section
"Sites (lane/sites)".

**Contract:** glTF 2.0 binary, metres, Y up. Origin on the ground under the middle of the vehicle. Forward is local **-Z**,
right is +X. Right-hand drive (steering wheel on the right). Wheels: nodes `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr`
with their origin at the hub; roll them by rotating about local X (a positive rotation.x turns the top of the wheel
toward +Z, i.e. rolls backward: forward travel along -Z is a negative rotation.x).
Lamps: meshes `lamp_head_l/_r` (material `headlight`, an opaque warm lens) and `lamp_tail_l/_r` (material `taillight`),
both emissive StandardMaterial3D on import with the lamp colour as emission at multiplier 1: code sets `emission_energy_multiplier` (traffic.gd: 2.4 x darkness; 0 by day).
Indicator, brake and reverse lenses stay in the body mesh (materials `lamp_ind_l/_r`, `lamp_brake`, `lamp_reverse`).
Glass is its own alpha-blended material (`glass`, `glass_tint`); interiors (seats, dash, wheel, door cards) are modelled.
Texture channels: none embedded; plain PBR materials (kit names: `paint`, `paint2`, `chrome`, `rubber`, `trim`...) times
a vertex colour (COLOR_0, linear: baked ambient occlusion x rust where the finish has worn x road dirt low down).
LOD: one mesh level per file (the lane's LOD1, about 35 % of LOD0, for traffic and parked vehicles; LOD0 for the story
vehicles); Godot's importer generates its automatic mesh LODs. Parked vehicles: a `<name>-colonly` box (StaticBody3D).
Plates: fictional and blank-faced on the source models (the Lake Car's plates are missing, as the story has it).

**Renames for traffic.gd:** none needed. It finds `wheel_*` Node3Ds and materials whose name contains `headlight`.
Note its roll: `rotation.x += speed * delta / 0.34` rolls these wheels backward and assumes 0.34 m; the real radii are
in the table (use `-speed * delta / radius`).

**Dirt overlay atlas** `assets/textures/vehicle_dirt_atlas.png` (1024 px RGBA, own work, CC0): RGB dirt colour, A coverage.
Quadrants: top left lower-body splash (dense at the bottom edge); top right wheel-arch spray fan (contact patch at the
bottom middle); bottom left rim brake dust (a ring); bottom right windscreen grime with two wiper arcs wiped clean.

| File | Source | What | Size x, y, z (m) | Wheel radius (m) | Tris | Collider | Plate |
|---|---|---|---|---|---|---|---|
| `assets/story/festival_bus.glb` | `festival_bus_garage` | the festival bus before restoration, HALLOWAY FESTIVAL, passenger door open | 2.85 x 3.05 x 9.21 | 0.479 | 45271 |  |  |
| `assets/story/lake_car.glb` | `lake_car_estate_a` | the Lake Car: late-1980s blue estate (BRASK 245), rust, algae line, flat tyre, smashed rear window, plates missing (the story), tailgate closed | 2.16 x 1.43 x 5.03 | 0.307 | 33029 |  | missing (story) |
| `assets/story/police_cruiser.glb` | `cruiser_1984_flat` | 1984 provincial police cruiser, rear left tyre flat, lightbar unlit | 2.36 x 2.10 x 5.55 | 0.348 | 35666 |  |  |
| `assets/traffic/hatchback_a.glb` | `car_hatch_b` | small five-door hatchback, dark red, alloys (ARDEN) | 2.20 x 1.44 x 4.40 | 0.316 | 10728 |  | HY 07 KTL |
| `assets/traffic/hatchback_b.glb` | `car_estate_a` | small estate, dusty blue, roof rails (VELIA) | 2.23 x 1.51 x 4.87 | 0.334 | 12530 |  | HY 11 DRW |
| `assets/traffic/pickup_a.glb` | `pickup_a` | double-cab farm pickup, faded white, loaded tray (CORVAN) | 2.40 x 1.83 x 5.35 | 0.388 | 11056 |  | VX 16 FARM |
| `assets/traffic/tractor_a.glb` | `tractor_a` | farm tractor, green, four-post cab (HALDEN 6140) | 2.47 x 3.96 x 4.97 | 0.880 | 9847 |  |  |
| `assets/traffic/van_a.glb` | `van_a` | white panel van with a ladder on the roof (CORVAN) | 2.40 x 2.11 x 5.37 | 0.343 | 11686 |  | HY 09 VAN |
| `assets/vehicles/car_dogguard_a.glb` | `car_estate_dogguard_a` | estate with a dog guard behind the rear seats | 2.23 x 1.51 x 4.87 | 0.334 | 12607 | yes |  |
| `assets/vehicles/car_roofbox_a.glb` | `car_estate_roofbox_a` | estate with a roof box | 2.23 x 1.93 x 4.87 | 0.334 | 12609 | yes |  |
| `assets/vehicles/farm_trailer_a.glb` | `farm_trailer_a` | small farm trailer, mesh sides and a ramp gate | 1.98 x 1.54 x 4.19 | 0.289 | 3152 | yes |  |
| `assets/vehicles/farm_truck_a.glb` | `farm_truck_a` | older farm pickup on a flatbed with a toolbox | 2.24 x 1.85 x 5.05 | 0.344 | 9304 | yes |  |
| `assets/vehicles/hay_trailer_a.glb` | `hay_trailer_a` | tandem bale trailer loaded with small square bales | 2.46 x 2.50 x 8.49 | 0.430 | 7156 | yes |  |
| `assets/vehicles/parked_car_a.glb` | `car_estate_a` | parked estate, grey, muddy | 2.23 x 1.51 x 4.87 | 0.334 | 12530 | yes |  |
| `assets/vehicles/parked_car_b.glb` | `car_hatch_a` | parked small hatchback, faded green | 2.12 x 1.45 x 4.10 | 0.301 | 10350 | yes |  |
| `assets/vehicles/parked_car_c.glb` | `pickup_b` | parked older farm pickup (BRASK) | 2.24 x 1.69 x 5.04 | 0.344 | 10369 | yes |  |
| `assets/vehicles/parked_van_a.glb` | `van_b` | parked delivery van, white, blank panels | 2.22 x 1.85 x 4.47 | 0.326 | 10636 | yes |  |

Sheets: `docs/realism/models/sites_fleet.jpg` (all of them at real scale, from the front three-quarter, from above,
and at dusk with the headlights raised), `docs/realism/models/sites_vehicles_new.jpg` (the new recipes).
