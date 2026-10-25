# Mown lawn (`src/world/LawnGrass.ts`, `src/world/textures/AssetTextures.ts`)

Colour model, tileable ground-detail textures and a near-field blade tuft.

## API

```ts
lawnColor(tone: number, drought: number, rnd): RGB     // 0 blue-green .. 1 yellow-green, drought toward straw
lawnTuft(seed, lod): AssetResult                         // ~0.3 m patch of 4 to 8 cm blades, clover at LOD0
lawnTextures(seed = 1, size = 1024): LawnTextureSet      // albedo, normal, wornAlbedo, wornNormal (tile 2 m) + macro (tile 64 m)
LAWN_PALETTE
```

Blend the macro texture on top of the albedo (`albedo.rgb *= macro.rgb * 2.0`, sampled at `tileMeters / macroTileMeters`) for yellow-green and blue-green swaths and drought patches without visible repetition. Blend the worn set with a path mask for trampled turf.

## Triangles

| LOD0 | LOD1 | LOD2 |
|---|---|---|
| 462 to 630 | 128 to 172 | 32 |

## In the simulator

Not wired into the terrain in this session: the existing GPU grass layer and the terrain ground shader already cover the lawns, and changing `ValleyTerrain`'s ground shader would affect every surface. The textures and tufts are ready for that step (see CHANGELOG, "what to tune next").

## Tuning

`LAWN_PALETTE`, tuft height `H` and blade counts in `lawnTuft`, macro contrast in `paintLawnMacro`.
