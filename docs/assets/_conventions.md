# Environment asset conventions (shared by every family)

All environment families live in `src/world/` and share `src/world/assetkit/`.

## Contract

```ts
build(seed: number, lod: 0 | 1 | 2, opts?) => { geometry: THREE.BufferGeometry; material: THREE.Material; collider?: Collider }
```

- Units are meters, Y up, origin at the base centre. Sections that chain (fences, walls, hedges) run along +X centred on the origin. Memorial fronts face +Z. Vehicles face -Z.
- Same seed and LOD give identical geometry (checked by `tests/assets.test.ts`).
- Randomness comes from `src/util/noise.ts` (mulberry32, noise3, hash3) through `assetkit/AssetRng.ts`. Nothing is duplicated.
- Materials are cached and shared per surface family, so every InstancedMesh of a family batches on one program.

## Vertex attributes

| Attribute | Size | Meaning |
|---|---|---|
| `position`, `normal`, `uv` | 3, 3, 2 | Standard. Foliage normals are authored "volume" normals (up and away from the plant centre). |
| `color` | 3 | Linear albedo with baked ambient occlusion (ground contact, clump and crown interiors, crevices). |
| `aSway` | 1 | Wind weight, 0 at the base and 1 at the tips. Present on every asset. |
| `aWind` | 3 | Input for `FoliageMaterials.patchWind`: x phase (per stem), y branch flex (`aSway * windFlex`), z leaf flutter (`aSway * windFlutter`). |
| `aPolish` | 1 | Stone only: 0 honed or weathered, 1 polished face (used by `withPolish`). |

## Materials

| Material | Used by | Base | Notes |
|---|---|---|---|
| `foliageMaterial(instanced)` | meadow, lawn tufts, hedges, shrubs, leaf drifts, nuts, bouquets, flags | `makeFoliageMaterial` | Atlas map, alphaTest 0.45, DoubleSide, wind and downwash, backlit SSS (tint 1.0, 0.78, 0.32, strength 1.3), plus `withSharedFaceNormals` so card back faces are not black. |
| `stoneMaterial()` | memorials, stone wall, rocks | `makeGranite` map and normal | roughness 0.82, metalness 0, `withPolish` (polished faces down to 0.16). |
| `woodMaterial()` | dead trees, snags, stumps, branches, twigs | `makeBark` map and normal | roughness 0.92, metalness 0. |
| `ironMaterial()` | railings, gates | vertex colors | roughness 0.7, metalness 0 (paint and rust are dielectric). |
| `groundMaterial()` | moss, soil | vertex colors | roughness 0.97, polygon offset against z-fighting. |

## LOD budgets

LOD0 under 6000 triangles, LOD1 under 1200, LOD2 under 200 per instance. Every builder runs under a budget guard that drops the last piece rather than overflow.

## Wiring

`src/world/EnvironmentInstancer.ts` (created in `main.ts`, `?env=0` disables it) places every family on the terrain and re-buckets instances by camera distance at about 2 Hz. Per family it owns one `InstancedMesh` per variant and LOD. Distances, density, variant count and shadow casting come from `QUALITY[preset].env` in `src/config.ts`.
