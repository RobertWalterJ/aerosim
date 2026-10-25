# Drone models (`src/world/drones/`)

Two original airframes built entirely in code, shown in the chase camera (`C` key or `?chase=1`).

| File | Content |
|---|---|
| `MiniDrone.ts` | MINI: 249 g folding camera quad, fictional brand "AeroLite", modelled unfolded |
| `FreestyleDrone.ts` | FREESTYLE: 5-inch true-X FPV quad, 750 g with a 4S 1300 mAh pack |
| `parts.ts` | shared parts and pipeline: lofts, lathes, airfoil props and blur discs, 2306 motors, screws, standoffs, nuts, cables, straps, zip ties, LEDs, voxel AO bake, mass model, assembly |
| `textures.ts` | canvas textures: carbon twill (albedo, normal, roughness, anisotropy direction), brushed metal and knurl normal maps, PCB silk screen, shell panel lines, decals, LiPo wrap, blur alpha, studio cube map for glass |
| `canvas.ts` | adapter over `ProceduralTextures.ts` helpers (mkCanvas, normalFromHeight, tex, lattice) |
| `materials.ts` | the PBR materials (table below) |
| `DroneView.ts` | simulator adapter: rotor spin, gimbal and LEDs from the physics state |

## API

```ts
buildMiniDrone(variant?: MiniVariant, lod?: 0 | 1): DroneBuild        // also exported as buildDrone from MiniDrone.ts
buildFreestyleDrone(variant?: FreestyleVariant, lod?: 0 | 1): DroneBuild

interface DroneBuild {
  root: THREE.Group;                                   // origin at the centre of mass
  rotors: [Object3D, Object3D, Object3D, Object3D];    // 0 FR, 1 RR, 2 RL, 3 FL; rotate about local Y only
  gimbal?: { yaw: Object3D; pitch: Object3D; roll: Object3D };   // MINI only
  leds: { name, material: MeshBasicMaterial, color, intensity, set(color?, intensity?) }[];
  physics: { massKg, comDesign, inertia, motorPositions, propRadius, spin };
  stats: { triangles, staticDrawCalls, dynamicDrawCalls, ledDrawCalls };
}
interface DroneVariant { accent?: 'hotPink' | 'lime' | 'orange' | color; wear?: 0..1; seed?: number; spin?: number[] }
```

- Each rotor has children `hub` (spinning bell, magnets, bearing, nut), `bladesSharp` (opaque airfoil blades) and `bladesBlur` (translucent annulus with a radial alpha from blade solidity). `rotor.userData.spin` is +1 for counter-clockwise seen from above (positive rotation about +Y), -1 for clockwise. Prop handedness follows the spin you pass. Without `spin` the brief's order is used (0 and 2 CCW); `DroneView` passes `Quadcopter6DOF.spin` so the geometry matches the simulated torque.
- LEDs: `set(color, intensity)` writes `color x intensity` (intensity clamped 0 to 6) into the MeshBasicMaterial, for bloom. MINI: `frontRight`, `rearRight`, `rearLeft`, `frontLeft`. FREESTYLE: `tailRight`, `tailLeft`, `fcStatus`, `vtxStatus`.
- Variants: MINI `shell` ('lightGrey' | 'white' | 'charcoal'), accent (CW prop ring, label ring), wear (shell scuffs, prop edge whitening), seed (serials, scuffs). FREESTYLE accent (props, bells, standoffs, TPU, LiPo print, decal), wear (carbon scuffs at arm tips, prop nicks and pale edges, LiPo scrapes), seed.

## Dimensions (checked by tests/assets.test.ts, 3 % tolerance)

| | Spec | Model |
|---|---|---|
| MINI flying footprint incl. props | 290 x 370 mm | 290.0 x 370.0 mm |
| MINI height | 62 mm | 62.1 mm |
| MINI props | 3 in | 76.2 mm |
| MINI body plus gimbal length | 145 mm | 147 mm |
| FREESTYLE wheelbase | 225 mm | 225.0 mm |
| FREESTYLE props | 5 in tri-blade, 4.3 in pitch, bullnose | 127.0 mm |

## Triangles and draw calls

| Model | LOD0 tris | LOD1 tris | Static draw calls | Rotors and gimbal | LEDs |
|---|---|---|---|---|---|
| MINI | 18040 | 4496 | 8 (LOD1: 7) | 12 (4 hubs, 4 props, 4 gimbal parts) | 4 |
| FREESTYLE | 37488 | 5956 | 10 | 8 (4 hubs, 4 props) | 4 |

Triangle totals include both the sharp blades and the blur discs. Static parts are merged per material. Rotors, gimbal parts and LEDs stay separate because they move or are driven individually.

## Materials

| Material | Type | Colour | Roughness | Metalness | Extras |
|---|---|---|---|---|---|
| MINI shell | Physical | shell texture (panel lines, vents, SD door) | 0.62 | 0 | clearcoat 0.05, sheen 0.15, shell normal map |
| MINI arms (`shellPlain`) | Physical | shell colour | 0.60 | 0 | clearcoat 0.05 |
| MINI battery (`darkPlastic`) | Physical | vertex | 0.50 | 0 | clearcoat 0.25 |
| MINI gimbal | Physical | vertex | 0.32 | 0 | clearcoat 1.0 (glossy black plastic) |
| MINI motor bells, screws (`metal`) | Physical | vertex | 0.34 | 1 | anisotropy 0.6, brushed normal map |
| rubber (gasket, dampers, feet, strap, wires) | Physical | vertex | 0.85 to 0.88 | 0 | |
| sensor glass | Physical | 0x08090b | 0.06 | 0 | clearcoat 1, studio env map |
| lens glass | Physical | 0x06070a | 0.04 | 0 | clearcoat 1, iridescence 1 (IOR 1.8, 260 to 420 nm), studio env map, no transmission |
| MINI decals | Physical | decal atlas | 0.45 | 0 | alphaTest 0.5, clearcoat 0.3 |
| flex cable | Physical | vertex (amber) | 0.35 | 0 | clearcoat 0.7 |
| props | Physical | vertex | 0.32 to 0.38 | 0 | clearcoat 0.5 to 0.6 |
| carbon | Physical | twill albedo | twill roughness map (0.30 to 0.58) | 0 | anisotropy 0.8 with per-tow direction map, twill normal map, clearcoat 0.35 |
| anodised accent (standoffs) | Physical | accent | 0.30 | 1 | anisotropy 0.7, brushed normal map |
| bare metal (screws, nuts, stator, windings) | Physical | vertex | 0.32 | 1 | anisotropy 0.4 |
| black anodised (motor bases, heat sink) | Physical | 0x1b1b1d | 0.42 | 1 | |
| motor bell | Physical | vertex | 0.30 | 1 | anisotropy 0.5, knurl normal map on the grip band |
| PCB | Physical | silk screen texture | 0.45 | 0 | clearcoat 0.6 (solder mask) |
| plastic (cams, XT60, capacitor) | Physical | vertex | 0.50 | 0 | clearcoat 0.25 |
| TPU | Physical | accent | 0.72 | 0 | sheen 0.4 |
| LiPo wrap | Physical | printed label texture | 0.38 | 0 | clearcoat 0.8 |
| blur discs | Standard | prop colour | 0.55 | 0 | transparent, alphaMap, depthWrite off, one per rotor |
| LEDs | Basic | colour x intensity | | | intensity 0 to 6 |

Vertex colours carry a voxel ambient-occlusion bake (`parts.bakeAO`): all static parts and hubs are rasterised into an occupancy grid (1.1 to 1.2 mm voxels at LOD0) and every vertex marches 14 hemisphere rays, so crevices, plate undersides and parts under the battery darken.

## Simulator wiring

`main.ts` creates `DroneView` instead of `DroneModel` (`?drone=legacy` restores the old model). Each frame it receives `quad.motorOmega` (rotor angle integrates spin x omega x dt; the sharp blades fade to the blur disc between 12 and 28 rev/s), the camera orientation relative to the body (decomposed into yaw, roll and pitch with mechanical limits), `quad.armed` and `quad.battery.soc` for the LEDs. The model is only built the first time the chase view is shown. Detail follows `QUALITY[preset].env.droneLod` (LOD1 on low).

## Notes for the physics side

- MINI: `config.ts` uses `armD = 0.0675` (motor diagonal 191 mm) and `R = 0.0585` (4.6 in props). The brief asks for 3 in props on a 290 x 370 mm footprint, which puts the motors at x = 146.9 mm, z = -102.1 mm (front) and +111.7 mm (rear) from the COM, and front props 12 mm higher than the rear. The model follows the brief; real sub-250 g quads of that footprint fly roughly 6 in props. Either update `armD`/`R` and the rotor positions or change the brief, so the visual rotors and the simulated thrust points agree.
- Spin direction: `Quadcopter6DOF.spin = [-1, 1, -1, 1]` (front-right clockwise) is the opposite of the brief (front-right counter-clockwise). The simulator view follows the physics.
- Inertia from the part mass model (kg m², body axes x right, y up, z back): MINI Ixx 1.12e-3, Iyy 2.53e-3, Izz 1.48e-3; FREESTYLE Ixx 2.39e-3, Iyy 3.20e-3, Izz 1.83e-3. `config.ts` currently has MINI [6.5e-4, 1.2e-3, 6.5e-4] (consistent with the shorter arms) and FREESTYLE [2.6e-3, 4.6e-3, 2.6e-3].
- FREESTYLE centre of mass sits 39 mm above the bottom plate (battery and action camera on top), 3 mm forward of the stack centre; the rotor plane is 9 to 10 mm below the COM, so the props are slightly below the COM.
