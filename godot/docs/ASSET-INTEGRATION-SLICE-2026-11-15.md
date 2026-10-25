# Shared-asset integration slice — 2026-11-15

This slice wires the highest-story-impact categories that were still code-only or on the old fleet. It does **not** claim the whole shared library is wired.

## Village — 21 asset models

`village.gd` now loads:

- `town_bakery_a` instead of one code cottage.
- `town_police_house_a` instead of one code cottage.
- `town_chip_shop_a` instead of one code cottage.
- `town_village_hall_a` instead of one code cottage.
- Existing high-detail `town_pub_a`, `town_shop_a` and `garage_shell_a`.
- `town_bench_a`, `town_lamp_post_a`, `town_bus_shelter_a`, `town_post_box_a`, `town_noticeboard_a`, `town_bin_a`.
- Halloway garage props: cluttered workbench, tyre stack, fuel pump, engine hoist, toolbox.

Fallback code geometry remains for any missing asset. Runtime log: `village: ... assets=21`.

## Pike anti-drone ridge — 13 site assets + 3 hunter models

`anti_drone.gd` now loads:

- `pike_clearing_patch`, `pike_jammer_mast`, `pike_generator`, `pike_floodlight`
- `pike_fence`, `pike_fence_8m`, `pike_fence_folk`
- `pike_chair`, `pike_cable_run`, `pike_beacon`
- `hunter_drone_a`, `hunter_drone_b`, `hunter_drone_c`

When the jammer goes down, the standing mast is hidden and `pike_mast_wreck` replaces it. Runtime log: `pike site assets: 13 / hunters=3`.

The code mast/dish/beacon fallback is still there if the GLBs are absent.

## Boat launch — 9 asset models

`boat_launch.gd` now tries:

- gravel patch, ramp, dock, launch sign, notice board, bollards
- aluminium hull and trailer (already present)
- police dive van and Anne Voss wreck (already present)

Fallback code geometry remains for every piece. Runtime log: `boat launch: ... asset models=9`.

## Cabin track / cave — 14 asset models

`cabin_track.gd` now loads:

- tree falls and rockfalls (already present)
- cave apron, outcrop, boulder arch, fallen slab, scree, chalk mark, damp stain, warning board, old lantern
- old fallen log

Runtime log: `cabin track: ... asset models=14`.

## Traffic — latest vehicle GLBs

`traffic.gd` now points the sparse fleet at the current `/assets/models/vehicles/` files:

- `car_hatch_a`, `car_hatch_b`, `pickup_a`, `van_a`, `tractor_a`.

Right-hand lane offsets, town passing pair, night-only highway car and headlights are unchanged. The latest night capture is `55_traffic_latest_night.png`.

## Evidence

- `56_village_assets2.png`, `60_village_high_assets.png`
- `57_boat_assets2.png`
- `58_cabin_cave_assets2.png`
- `59_pike_assets2.png`, `61_pike_close.png`, `62_pike_mast.png`
- `55_traffic_latest_night.png`
- Contact sheet: `contact_asset_slice2.jpg`

## Still not wired / needs follow-up

- **Signs and road surfaces**: no matching sign model set was found in the received library; `RoadSigns`/`LandmarkSigns` and the road shaders remain the code-built versions.
- **Claude drone GLBs** (`nightowl`, `raptor`, pods) are still not driving the player/chase drone; `DroneView` remains code-built.
- **VehicleAssets runtime** (armature wheels, doors, LODs, wreck shaders) is still not the traffic/story driver; this slice swaps geometry only.
- **AnimalHerd runtime** is still not used.
- **Story/endgame interior props** remain partial; endgame vehicle geometry is in, interiors are not.
- The Pike mast was loaded but was hard to frame in the available camera positions; it needs a clean close-up verification next.
- Village people remain deliberately invisible; their models are in the people library and asset sheets, not in the street.

`GATE PASS (assetslicefinal)`.

## Next slice

1. Get a clean Pike mast/wreck close-up and verify orientation.
2. Wire the Claude drone GLBs into `DroneView`/thumbnails.
3. Sign/road-surface assets if a matching art set is confirmed.
4. Story/endgame interior props and remaining vehicle runtime.
