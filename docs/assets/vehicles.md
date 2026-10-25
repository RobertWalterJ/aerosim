# 1980s cars, UK and Canada (`src/world/Vehicles.ts`)

Original designs in the style of the period, with no real makes, badges or logos. Plate numbers are made up.

| Style | Region | Body | Length |
|---|---|---|---|
| UK supermini | UK | 3-door hatch, round lamps | 3.62 m |
| UK hatchback | UK | 5-door hatch | 3.99 m |
| UK saloon | UK | 4-door saloon | 4.35 m |
| UK estate | UK | estate | 4.45 m |
| UK panel van | UK | small panel van | 4.40 m |
| Canadian full-size sedan | CA | sedan, quad lamps, chrome bumpers, optional vinyl roof | 5.30 m |
| Canadian woodgrain wagon | CA | wagon with woodgrain side panels | 5.45 m |
| Canadian compact | CA | compact sedan, quad lamps | 4.50 m |
| Canadian pickup | CA | full-size pickup, open bed, two-tone option | 5.30 m |
| Canadian minivan | CA | one-box minivan | 4.50 m |

UK cars carry a white front and yellow rear plate in the 1983 to 2001 prefix format; Canadian cars a white plate with blue text and a province name. Paint comes from a period palette per region; sun fading (lighter tops) and road-salt rust patches at the arch lips and sills scale with `wear`.

## API

```ts
vehicle(seed, lod, { style?: number, paint?: number, wear?: number }): { geometry, material: Material[], collider, style }
VEHICLE_STYLES, VEHICLE_PAINT, vehicleMaterials()
```

Front faces -Z, origin on the ground under the body centre. One geometry per car with groups for five shared materials (paint, trim, bright metal, lenses, decals), so a parked fleet costs at most five draw calls per variant and LOD.

## Materials

| Material | Type | Values |
|---|---|---|
| paint (also glass) | MeshPhysicalMaterial | vertex colours, roughness 0.42, clearcoat 0.7, clearcoatRoughness 0.14, metalness 0 |
| trim (rubber, black plastic, wells) | MeshStandardMaterial | roughness 0.78, metalness 0 |
| bright (chrome, hubcaps) | MeshStandardMaterial | roughness 0.2, metalness 1 |
| lens (lamps) | MeshPhysicalMaterial | roughness 0.12, clearcoat 1 |
| decal (plates, rust, woodgrain, badges) | MeshStandardMaterial | canvas atlas, alphaTest 0.5, polygon offset |

## Triangles

| LOD0 | LOD1 | LOD2 |
|---|---|---|
| about 2250 | about 1100 | 156 to 192 |

## In the simulator

Parked in the chapel car park and on the verges of the east-west avenue outside the gates, with box colliders. Cull at 520 m x `env.lodScale`; shadows on every preset.

## Tuning

`VEHICLE_STYLES` (proportions), `VEHICLE_PAINT`, rust count and size, fading strength (`fade` in `vehicle`), parking spots in `EnvironmentInstancer`.
