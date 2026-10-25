# Claude vehicle asset brief: photoreal traffic, parked cars and story vehicles

Status: production request, 2026-11-15. The road traffic is still code-built boxes with wheels and emissive lamp blocks. That is not photoreal and is not acceptable for the final valley. This brief asks Claude to model and texture the full vehicle set, with the exact origins, wheel pivots, orientation, material names and LODs the game needs.

Owner of placement and code: session B. Claude handles the models and textures only. The traffic system already looks for these files and falls back to boxes until they arrive.

## The valley's vehicles

Halloway is a British-leaning rural valley: narrow lanes, right-hand-drive cars, traffic keeps left, and the fleet is ordinary, older and slightly shabby rather than glossy.

The fleet:

- a small five-door hatchback in several colours;
- a second hatchback or small estate in a different colour;
- a farmer's double-cab pickup with a loaded tray;
- a white panel van with rust and a ladder;
- an older tractor with a canopy, exhaust and big rear wheels;
- parked cars for the east cemetery car park and the farm;
- the story vehicles: the abandoned Lake Car, the festival bus and the 1980s police cruiser.

## Shared contract

- glTF 2.0 binary `.glb`, metre scale, Y up.
- **Origin at the ground under the vehicle centre.** Wheels rest at Y = 0.
- **Forward is local -Z.** Right is local +X. This matches the Godot traffic node.
- **Drive on the left, right-hand drive.** Steering wheel on the right.
- **Wheel nodes:** `wheel_fl`, `wheel_fr`, `wheel_rl`, `wheel_rr`. Each is a Node3D at the wheel centre. The wheel axle is local X, so rolling is rotation around local X. The game spins these nodes.
- **Headlight materials:** name them exactly `headlight` and `taillight`. They must be emissive StandardMaterial3D-compatible PBR materials so the game can pulse the emission at dusk. The lens geometry can be separate.
- **Lights:** separate named meshes `lamp_head_l`, `lamp_head_r`, `lamp_tail_l`, `lamp_tail_r`, plus indicator and brake meshes. No real light nodes.
- **Glass:** separate transparent material, not part of the body shell. Windows, windscreen and mirrors separate.
- **LODs:** one scene with LOD0 close, LOD1 mid, LOD2 far. LOD0 from 0 to 30 m, LOD1 30 to 110 m, LOD2 110 m and beyond. Traffic can be seen at 200 m from the air.
- **Scale and proportions:** real vehicle dimensions, accurate wheelbase, track, overhangs and roofline. No cartoon proportions.
- **Materials:** PBR with albedo, normal, roughness and AO. Cars will be seen from 1 m to 250 m; the normal map should hold bevels, panel gaps and badges.
- **Texture budget:** 4K for the hero story vehicles, 2K for the traffic fleet, 1K for the far LODs.
- **No real logos, badges, plates or trademarks.** Use fictional valley plates, e.g. `HY 84 AV` for the Lake Car and `VX 16 FARM` for the pickup.
- **No gore, no weapons, no bodies.** The police cruiser is an empty period vehicle.
- **Interiors:** visible through glass at close range: seats, dashboard, steering wheel, mirror, door cards. Keep them simple but present.

## Priority 0: the moving traffic fleet

These file paths are already wired in `game/traffic.gd`; the code will use them as soon as they exist.

| File | Vehicle | Dimensions | Notes |
|---|---|---|---|
| `assets/traffic/hatchback_a.glb` | small five-door hatchback | 4.05 x 1.76 x 1.46 m | old but clean, dark red; steel wheels or small alloys; right-hand drive |
| `assets/traffic/hatchback_b.glb` | second hatchback or small estate | 4.35 x 1.78 x 1.50 m | dusty blue, roof rack; different wheel style |
| `assets/traffic/pickup_a.glb` | double-cab farm pickup | 5.25 x 1.92 x 1.92 m | faded white, tray with hay string, tools and mud; tow ball |
| `assets/traffic/van_a.glb` | white panel van | 5.20 x 2.00 x 2.30 m | rust at arches, ladder on roof, no rear windows |
| `assets/traffic/tractor_a.glb` | older farm tractor | 4.20 x 1.90 x 2.65 m | green and rust, canopy, exhaust, big rear wheels, small front wheels |

Each needs:

- a clean contact sheet from front three-quarter, rear three-quarter, side, top and wheel close-up;
- a dirt/clean variant or a dirt layer that can be turned down;
- a colour variant if the body paint is easy to swap;
- front and rear number plates as separate meshes or decals;
- realistic wheel sidewalls, tread, brake discs and calipers;
- mirrors, wipers, door handles, panel gaps, exhaust, tow ball and underbody;
- LODs with wheels preserved in LOD0 and LOD1.

## Priority 0: parked vehicles

| File | Vehicle | Notes |
|---|---|---|
| `assets/vehicles/parked_car_a.glb` | ordinary saloon or estate | grey, muddy, parked |
| `assets/vehicles/parked_car_b.glb` | small hatchback | faded green |
| `assets/vehicles/parked_car_c.glb` | farm pickup | reuse `pickup_a` if possible |
| `assets/vehicles/parked_van_a.glb` | delivery van | white, faded sign panel, no readable brand |

These can reuse the fleet geometry with the wheels turned and a parked pose. They need a collider box for future on-foot play, but no wheel animation.

## Priority 1: the story vehicles

### Lake Car: `assets/story/lake_car.glb`
A 1980s blue estate, the car Anne Voss drove into the lake road storm. It has sat at the shore for forty years.

- About 4.6 x 1.8 x 1.45 m.
- Faded navy blue, bleached roof, algae line at the sills, rust at the arches, flat tyres or missing hubcaps.
- Empty interior, no bodies, no gore. Water damage, silt in the footwells, a cracked windscreen.
- Fictional plate `HY 84 AV`.
- The boot can be open or closed; keep one clean closed variant.
- A separate VIN plate decal and a small evidence tag mesh for the story chapter.

### Festival bus: `assets/story/festival_bus.glb`
An old single-decker bus that Ellis Voss kept for the festival parade.

- About 10.5 x 2.5 x 3.1 m.
- Faded cream and rust-red paint, HALLOWAY FESTIVAL lettering on a separate decal material, warm interior light.
- Rows of worn seats, a driver cab, a destination blind, round headlights, mudguards.
- One passenger door open, one closed; no people.
- It must read as a bus from 150 m and as a worn interior from 5 m.

### Police cruiser: `assets/story/police_cruiser.glb`
The 1980s provincial cruiser outside the cabin.

- About 4.8 x 1.85 x 1.45 m.
- Period four-door saloon or estate, provincial livery, a low-profile light bar, a spotlight, radio antenna, rust at the rear arches.
- Empty, no weapons, no bodies. One tyre flat. Door closed; a small evidence marker optional.
- Fictional period plate, e.g. `PR 84 12`.
- The light bar should be a separate material so it can stay unlit in the final scene.

## Priority 1: farm and utility vehicles

- `assets/vehicles/farm_trailer_a.glb` small flatbed or livestock trailer for the tractor.
- `assets/vehicles/farm_truck_a.glb` older farm pickup with a flatbed and toolbox.
- `assets/vehicles/boat_trailer.glb` already covered by the boat launch brief; do not duplicate.
- `assets/vehicles/coal_truck.glb` optional old flatbed lorry for the ridge.

## Priority 2: variation and life

- A bicycle and a walker? No, keep traffic vehicle-only for this pass.
- A tractor with a hay trailer variant.
- A second van with a different faded sign panel.
- A car with a roof box or a dog guard.
- Windscreen wiper positions, indicator states, brake light mesh, reversing light mesh.
- A dirt overlay atlas for all bodies and wheels.
- A fictional garage plate frame for Voss and Son.

## Integration details

- `game/traffic.gd` loads the five fleet paths above when the file exists and falls back to the box placeholder if missing.
- It finds wheel nodes named `wheel_*`, spins them around local X, and looks for StandardMaterial3D materials whose resource name contains `headlight` for the dusk light pulse.
- The traffic node is placed on the left lane at 1.85 m from the centreline and oriented along local -Z.
- The story vehicles are placed by `case_objects.gd`; keep the same ground origin and forward -Z, or state a different forward axis in the delivery notes.
- The car park vehicles are part of the park layout; supply sizes and pivots so they can replace the current parked meshes.
- LOD ranges must be set in the imported scene or a companion `.import` note; do not rely on the game to build LODs.
- Collision: a simple box proxy for parked and story vehicles; moving traffic has no collisions in the current game.

## Delivery package Claude must include

- `manifest.md` with file names, dimensions, origin, forward axis, wheel node names, material names, LOD ranges and texture sizes.
- A contact sheet per vehicle: front three-quarter, rear three-quarter, side, top, wheel close-up, night headlight view.
- A 3/4 view of the full fleet together at real scale.
- Texture channel notes and source/licence notes.
- A note on any material or node that has to be renamed for the traffic code.

## What this unlocks

Priority 0 replaces the moving and parked placeholders with real right-hand-drive rural traffic. Priority 1 gives the Lake Car, festival bus and police cruiser the hero models the story deserves. Priority 2 adds the variation that stops a small fleet from repeating.
