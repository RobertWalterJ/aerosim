# Meadow grasses and wildflowers (`src/world/MeadowGrass.ts`)

Tall autumn meadow for the unmown valley slopes: foxtail, timothy, little and big bluestem, goldenrod, Queen Anne's lace (fresh and dried "bird's nest" umbels), asters and milkweed with split pods. Palette: straw gold, bleached tan, rusty bronze, remnant olive.

See [_conventions.md](_conventions.md) for attributes, materials and wiring.

## API

```ts
meadowClump(seed: number, lod: 0 | 1 | 2, variant?: number): AssetResult  // 8 to 40 stems
MEADOW_VARIANTS: MeadowVariant[]   // 10 recipes: foxtail-straw, timothy, little-bluestem, big-bluestem, goldenrod,
                                   // queen-annes-lace, aster-edge, milkweed-stand, mixed-tawny, olive-remnant
scatterMeadow(opts): ScatterBatch[] // density-mask scatter: per-variant instance matrices and tints
```

`scatterMeadow` (and the generic `scatterInstances` in `assetkit/AssetScatter.ts`) take a world rectangle, a density in clumps per m², and a mask (row-major grid or `(x, z) => 0..1`). Variants form swaths through per-variant patch noise; scale follows a low-frequency field; every instance gets yaw, lean (random plus prevailing wind) and a brightness and warmth tint.

## Wind

`aSway` is arc length from the ground along each stem divided by the tallest stem (tallest tip = 1). Leaves and heads inherit the value at their node. `aWind` uses a per-stem phase, flex 0.45 and flutter 0.35.

## Triangles (8 seeds)

| LOD0 | LOD1 | LOD2 |
|---|---|---|
| 1090 to 3284 | 160 to 544 | 42 to 84 |

LOD1 and LOD2 blades are widened (x1.7, x3.2) so clumps keep their coverage at distance.

## In the simulator

Placed by `EnvironmentInstancer` on open ground (unmown and unforested land cover) in the ring 120 to 380 m from the park centre, away from paths and monuments. Count: 46000 x `env.density` (low 13800, medium 25300, high 36800, ultra 46000). LOD distances 22 / 55 / 150 m x `env.lodScale`. Shadows only on high and ultra.

## Tuning

| What | Where |
|---|---|
| Colours | `MEADOW_PALETTE` |
| Species mixes, stem counts, clump radius and height, green share | `MEADOW_VARIANTS` |
| Field density, ring radii, patchiness | meadow block in `EnvironmentInstancer` constructor |
| Far-LOD widening | `widthMul`, `cardMul` in `meadowClump` |
| Wind response | `b.windFlex`, `b.windFlutter` in `meadowClump` |
