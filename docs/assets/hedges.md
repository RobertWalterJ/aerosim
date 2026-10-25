# Hedges and shrubs (`src/world/HedgesShrubs.ts`)

Clipped boxwood and yew hedges; lilac, forsythia, boxwood balls and spreading yew mounds. Dense rounded forms from a dark inner core (stops see-through) plus leaf-cluster cards whose normals follow the overall volume.

## API

```ts
hedge(seed, lod, { type?: 'boxwood' | 'yew', length = 2, height?, width?, caps?: 'both' | 'none' | 'start' | 'end' }): AssetResult
shrub(seed, lod, { type?: 'lilac' | 'forsythia' | 'boxwoodBall' | 'yewMound', height? }): AssetResult
SHRUB_TYPES, SHRUB_PALETTE
```

Hedge segments run along +X; use `caps: 'none'` to chain them. Colliders: box (hedge), cylinder (shrub).

## Wind

`aSway` = height / plant height, damped near the core (clipped hedges reach about 0.25). Forsythia canes use distance along the cane.

## Triangles

| Asset | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| hedge (2 m) | 2024 to 4592 | 1196 | 128 |
| shrub | 1446 to 5996 | 1194 to 1196 | 108 to 156 |

## In the simulator

Boxwood hedges (0.75 m) flank the three spur walks between 14 and 70 m from the memorial; eight yew hedge blocks ring the chapel; 90 x `env.density` shrubs line the loop path verges. All three cast shadows on every preset.

## Tuning

`SHRUB_PALETTE` (including the autumn bronzing of boxwood), hedge sizes in `EnvironmentInstancer`, leaf-card coverage (the `2.6` layers factor in `hedge`, layers per type in `shrub`).
