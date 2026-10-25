# Wind shelter: trees, canopies and buildings

Status: 2026-11-15. Low flight in sheltered air is now meaningfully calmer than open-air flight.

## What counts as shelter

- **Woodland directly overhead:** the terrain land-cover map at the drone's own position is the strongest term. Flying into or under the treeline is no longer only “downwind of trees”.
- **Woodland around and upwind:** local ring samples and the existing upwind samples still contribute, so the edge of a wood and its lee both count.
- **Buildings:** the village registers every cottage, pub, shop and garage footprint. The story landmarks (cabin, garage, camp, festival, boat launch) register their own areas. The shelter call is sampled from `Wind.drive` every 0.25 s.
- **Height:** all shelter fades out between roughly 7 m and 34 m above ground, so flying above the canopy puts the drone back in the open wind.

## What changes in shelter

- Mean wind at the drone is reduced by up to **68%** at full shelter.
- Turbulence (`sigma`/`turb`) is reduced by up to **62%**, which also calms camera shake, wind sound and the “Strong wind” warning.
- Gust puffs are reduced by up to **55%**.
- The eddy torque that throws a light airframe about is reduced by up to **62%**.

The result is that a Mini can hold a stable hover in the lee of a wood or a building, and a heavy cinema drone flies with noticeably less shake in the same place.

## Test hook

`shelterprobe` reads the shelter at a village building and at a forest point:

```text
village buildings=9
shelter village=0.58 turb=0.22 wind=0.2
shelter forest=1.0 turb=0.13 wind=0.2
```

Open-air values for comparison are about `shelter 0.0`, `turb 0.35`, `wind 0.4` for the same wind setting.

## Limits

- Building shelter is footprint-based, not a full fluid simulation; it does not model the exact vortex downwind of a gable.
- The tree cover comes from the baked land-cover map, so individual trees outside mapped woodland do not create a local pocket.
- Shelter is sampled four times a second, which is deliberately cheap for the phone.
- It reduces wind and turbulence; it does not alter collisions or add a separate airflow volume.

## Verification

- `GATE PASS (windshelter)`.
- Probe output above from the live terrain.
