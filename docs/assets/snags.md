# Snags, stumps and rock outcrops (`src/world/SnagsRocks.ts`)

Standing dead trees with partly broken crowns, broken-topped snags with stubs and woodpecker holes, hollow stumps with root flare and bracket fungi, and stratified rock outcrops with ledges, moss on tops and streaks below ledges.

## API

```ts
deadTree(seed, lod, { height? }), snag(seed, lod), hollowStump(seed, lod)
rockOutcrop(seed, lod, { size?, style? })   // partly buried, up to about 0.7 m below y = 0
SNAG_PALETTE
```

Dead wood `aSway` = height / tree height x 0.35 (a slight creak, no rubbery branches).

## Triangles

| Asset | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| deadTree | 1724 to 2830 | 454 to 718 | 61 to 85 |
| snag | 447 to 519 | 109 | 35 |
| hollowStump | 588 to 684 | 150 to 174 | 42 |
| rockOutcrop | 4356 to 4860 | 768 to 960 | 108 |

## In the simulator

Snags at the forest margin (forest cover 0.25 to 0.75, gentle slope) and rock outcrops on the steep valley walls between 220 and 1120 m from the centre: 160 and 260 x `env.density`. Cull at 900 m (snags) and 1200 m (rocks) x `env.lodScale`. Both cast shadows on every preset; snags add trunk colliders.

## Tuning

`SNAG_PALETTE`, `paintDeadWood` (bark loss, moss), `STONE_STYLES.limestone`, placement filters in `EnvironmentInstancer`.
