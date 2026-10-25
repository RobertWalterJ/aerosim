# Ground clutter (`src/world/GroundClutter.ts`)

Fallen autumn leaves in drifts (oak, maple, beech, decayed), acorns and conkers with split husks, twigs, fallen branches with stubs, raised moss cushions and bare soil scuffs with pebbles.

## API

```ts
leafDrift(seed, lod, { radius?, pile?, mix?: 'oak' | 'maple' | 'beech' | 'mixed' })
nutScatter(seed, lod, { radius?, kind?: 'acorn' | 'chestnut' | 'mixed', count? })
twigs(seed, lod, { radius?, count? })
fallenBranch(seed, lod, { length? })
mossPatch(seed, lod, { radius? })
soilPatch(seed, lod, { radius? })
LEAF_PALETTE, WOOD_PALETTE
```

Leaves and nuts have `aSway` = 0 (they lie on the ground); moss and soil are rigid ground patches with polygon offset.

## Triangles

| Asset | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| leafDrift | 3086 to 5996 | 398 to 1196 | 94 to 196 |
| nutScatter | 1920 to 4632 | 360 to 704 | 192 |
| twigs | 692 to 1124 | 60 | 16 |
| fallenBranch | 348 to 783 | 74 | 16 |
| mossPatch | 760 | 180 | 36 |
| soilPatch | 720 to 792 | 126 | 36 |

## In the simulator

Leaf drifts under park broadleaf trees, nuts under oaks, branches and twigs at the woodland edge (r > 200 m), moss at tree bases and monuments, soil scuffs at path edges and monument fronts. Counts scale with `env.density`; short cull distances (45 to 140 m x `env.lodScale`); no shadows on low and medium.

## Tuning

`LEAF_PALETTE`, drift density (900 leaves per m² at LOD0), leaf size, placement probabilities in the clutter block of `EnvironmentInstancer`.
