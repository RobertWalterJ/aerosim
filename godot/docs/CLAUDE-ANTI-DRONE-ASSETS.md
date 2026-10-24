# Claude anti-drone ridge asset brief: Harlan Pike

Status: production request, 2026-11-15. The north ridge now has a story hazard: Harlan Pike, a freeman-on-the-land who never appears in the chat himself, but whom Rennick, Riley and Alex know of. He has a manifesto, a jammer mast and hunter drones. The current placeholders are code-built boxes and cylinders. These are the final models.

Owner of placement and code: session B. Claude handles the models and textures only. Nothing here should be a weapon that can hurt the player; the drone is forced back to the launch site, never destroyed with gore.

## The character

Harlan Pike is a middle-aged freeman-on-the-land. He believes the county has no jurisdiction over the ridge. He has written a short, badly printed manifesto called **The Unbound Valley**, full of fences, fees and jurisdiction. He is not a cartoon villain: he is a neighbour with a bad fence, a worse pamphlet, a shotgun and a genuine grudge against drones.

He must not appear as a readable chat account. The story only knows him through the other contacts and through the things on his land.

## Shared contract

- glTF 2.0 `.glb`, metre scale, Y up, origin at the base, front face +Z.
- Low poly for the ridge: jammer trailer 3,000 to 8,000 triangles, hunter drone 2,000 to 5,000, shack 3,000 to 7,000.
- PBR materials, muted tarpaulin, rust, galvanised steel, faded paint and taped paper.
- Separate named nodes for moving parts: `mast`, `dish`, `beacon`, `rotor_1` to `rotor_4`, `shotgun`, `door`.
- No readable text on the models. The game puts text on the manifesto board and the warning sign through Label3D.
- No real militia, county, police or political insignia. Fictional Halloway marks only.
- No gore, no bodies, no functioning weapons. The shotgun is a prop, never fired at a person.

## Priority 0: the jammer site

| Asset | Description | Notes |
|---|---|---|
| `pike_jammer_trailer.glb` | a small rusty box trailer with a 14 m telescopic mast, a dish and a red beacon | the mast is a separate node so the code can lower it when the jammer goes down |
| `pike_jammer_mast.glb` | separate mast and dish, if the trailer and mast are easier as two pieces | mast at 14 m, dish 1.1 m |
| `pike_beacon.glb` | caged red beacon, glass and a dark metal cage | separate emissive material |
| `pike_manifesto_board.glb` | a lopsided plywood board, 2.4 x 1.4 m, two posts and a taped paper sheet | the paper face is blank for the game text |
| `pike_warning_sign.glb` | a small roadside board, NO DRONES / PRIVATE LAND | blank face for Label3D |
| `pike_shack.glb` | a small shack with corrugated roof, one door, a lean-to, a generator and a rain barrel | lived-in, not a fortress |
| `pike_generator.glb` | a small rusty generator, fuel can and cable reel | for the jammer power |
| `pike_fence.glb` | a broken post-and-wire fence section | 4 m and 8 m pieces |
| `pike_cable_run.glb` | a cable running from the generator to the mast | 8 m |

## Priority 0: the hunter drones

| Asset | Description | Notes |
|---|---|---|
| `hunter_drone_a.glb` | a brutal little quadcopter, 0.9 m across, dark frame, red forward eye, four exposed rotors | separate rotors; no weapons |
| `hunter_drone_b.glb` | a heavier six-rotor variant with a net launcher pod, no gun | separate rotors and pod |
| `hunter_drone_c.glb` | a stripped racing frame with a red strobe | fastest silhouette |
| `hunter_rotor.glb` | the shared rotor and guard | separate node, named `rotor_1` to `rotor_4` |
| `hunter_net_pod.glb` | a net launcher pod, closed and empty | optional, no projectile |

The game has three hunters and makes them chase by distance. They need a strong forward silhouette and a red eye so the player can read the threat from 100 m.

## Priority 1: the land

- `pike_ridge_clearing.jpg` ground texture: beaten grass, oil stains, wheel ruts and a bare patch under the trailer.
- `pike_tarp.glb` a tarpaulin lump over something under the lean-to.
- `pike_toolbox.glb` an open toolbox, spanners and a shotgun cleaning kit.
- `pike_chair.glb` a folding camp chair and a thermos by the shack door.
- `pike_floodlight.glb` a battery floodlight pointed at the mast.
- `pike_radio.glb` a battered CB radio and aerial by the shack.
- `pike_log_pile.glb` a cut log pile and an axe in a stump.
- `pike_no_drone_stencil.png` a spray-painted drone with a slash, for the trailer or a sign.

## Priority 1: story props

- `pike_manifesto_paper.png` a single taped page, yellowed, with unreadable lines, no actual text.
- `pike_notice_stack.png` a stack of damp notices and envelopes.
- `pike_mast_wreck.glb` the mast after it goes down: bent, dark, no beacon, a snapped guy wire.
- `pike_smoke.glb` a thin smoke wisp or a smoke card for the broken mast.

## Priority 2: atmosphere

- A small red strobe card that the code can flash on the beacon.
- A warning lamp on the generator.
- A set of tyre tracks and a jerked trailer mark in the clearing.
- A deer skull or a tied ribbon on the fence, for a folk edge.
- A distant antenna on the ridge line.

## Integration notes

- The site is placed at `AntiDrone.JAMMER_SPOT` (-260, -807), inside a 9 m clearing in the new cabin forest. The mast and beacon must be high enough to read from 60 m above the canopy.
- The code lowers or disables the beacon when the jammer goes down. Provide a separate `mast` node with a clean pivot at the trailer deck.
- The three hunters are spawned by `game/anti_drone.gd`. They only need rotors that can spin, a red forward eye and a dark readable silhouette.
- The manifesto board is a Label3D surface in code today. Keep the plywood face blank and readable as a surface.
- The shotguns are scenery. There must be no muzzle flash aimed at the player and no gore.
- Everything should feel homemade and slightly broken, not military hardware.

## Delivery

- Contact sheet per asset: front three-quarter, side, top, close-up of the mast and hunter eye.
- A group shot of the trailer, shack and three hunters at real scale in the clearing.
- Manifest with sizes, origins, node names, LODs and texture channels.
- A note on any material that must be emissive or renamed for the code.

## What this unlocks

Priority 0 gives the ridge a visible reason to stay away: the jammer mast, the manifesto and the hunters. Priority 1 makes Pike's land feel lived in. Priority 2 makes it a place the player remembers.
