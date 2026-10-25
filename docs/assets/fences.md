# Railings, gates and stone walls (`src/world/FencesWalls.ts`)

Wrought-iron cemetery railings with spear, fleur or ball finials, chipped black paint, chalking and rust that collects low and at joints; double arched gates with stone piers, scrolls and rings; mortared fieldstone walls with upright or flat coping, lichen, moss and rain streaks.

## API

```ts
ironFence(seed, lod, { length = 2.4, height?, curb?, endPost = true, finial?, rust? }): AssetResult
ironGate(seed, lod, { width?, height?, piers = true, ajar? }): AssetResult
stoneWall(seed, lod, { length = 3, height?, width?, coping?: 'flat' | 'upright', mortar = true, style? }): AssetResult
IRON_PALETTE, STONE_STYLES (assetkit/StoneWeathering.ts)
```

Sections run along +X centred on the origin and chain at a spacing equal to `length` (posts sit at -length/2).

## Triangles

| Asset | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| ironFence (2.4 m) | 2080 to 2520 | 676 to 804 | 90 to 104 |
| ironGate | 4224 to 5376 | 808 to 1000 | 88 to 96 |
| stoneWall (3 m) | 3708 to 5244 | 560 to 848 | 108 |

## In the simulator

A dry-stone boundary wall rings the park at r = 238 m (3 m sections following the slope). Where the two avenues cross it, an iron gate with stone piers stands on the avenue and 26 m of railings on a granite curb run either side. Walls, railings and gates cast shadows on every preset and add small cylinder colliders.

## Tuning

`IRON_PALETTE`, `rust` option, `STONE_STYLES.fieldstone`, wall radius, gate wing length (`fenceHalf`) in `EnvironmentInstancer`.
