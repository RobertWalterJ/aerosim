# Memorial details (`src/world/MemorialDetails.ts`)

Headstones in eight kinds (round top, gothic, shouldered, pediment, weeping willow relief, obelisk, open book, lawn marker), draped urns, Latin, Celtic and rustic crosses, angels in three poses, kerbed plots with gravel or marble chips, bouquets and small grave flags. Seven stone styles (grey, pink and dark granite, white marble, sandstone, fieldstone, limestone) with lichen, rain streaks, black crust under ledges, algae splash and polish.

## API

```ts
headstone(seed, lod, { kind?: HeadstoneKind, style?: StoneStyleName })
willowMarker(seed, lod), urnMonument(seed, lod)
crossMonument(seed, lod, { kind?: 'latin' | 'celtic' | 'rustic' })
angelMonument(seed, lod, { pose?: 'praying' | 'pointing' | 'wreath' })
kerbedPlot(seed, lod, { length?, width?, infill?, headstone? })
bouquet(seed, lod), graveFlag(seed, lod, { bands?, widths?, horizontal? })
```

Stone geometry carries `aPolish`. Bouquets and flags use the foliage material; the flag cloth has `aSway` 0 at the hoist and 1 at the fly. The default flag is a generic red, white, red tri-band with no emblem.

## Triangles

| Asset | LOD0 | LOD1 | LOD2 |
|---|---|---|---|
| headstone | 120 to 568 | 12 to 208 | 12 to 52 |
| willowMarker | 532 to 596 | 192 to 208 | 24 to 40 |
| urnMonument | 762 to 794 | 208 | 96 |
| crossMonument | 88 to 461 | 48 to 134 | 36 to 64 |
| angelMonument | 1268 to 1380 | 328 to 384 | 92 |
| kerbedPlot | 222 to 674 | 120 to 302 | 72 to 100 |
| bouquet | 402 to 788 | 96 to 140 | 56 to 64 |
| graveFlag | 72 | 24 | 12 |

## In the simulator

`EnvironmentInstancer.findClearBlock` searches the mown park for a 28 x 16 m block clear of paths, monuments and trees and lays out a Victorian section there (5 rows of 9, with gaps), with bouquets and flags at about 40 % of graves. The existing instanced headstone fields in `MemorialParkAssets.ts` are unchanged.

## Tuning

`STONE_STYLES` (assetkit/StoneWeathering.ts), `BOUQUET_PALETTE`, flag bands, section size and row spacing in `EnvironmentInstancer`.
