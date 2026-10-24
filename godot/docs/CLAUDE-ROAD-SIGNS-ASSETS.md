# Claude road sign asset brief: Halloway Valley

Status: production request, 2026-11-15. The road network now has code-built stop signs, speed limit plates, junction warnings and a fingerpost. This brief asks Claude for the final sign assets that replace those placeholders.

Owner of placement and code: session B. Claude handles the art only; integration stays on this lane. The tone is a working rural valley with British and American small-road cues kept simple and consistent. The current copy is readable but the plates and lettering are placeholder.

## Shared contract

- glTF 2.0 binary `.glb` for posts, brackets and sign backs; PNG with transparency for flat sign faces, or a texture atlas with a clear UV layout.
- Metre scale, Y up, origin at the base, +Z forward.
- Sign height at the top edge around 2.2 to 2.6 m above the road; post height around 2.6 m.
- Galvanised grey posts, slightly weathered; timber posts where noted.
- Retroreflective-looking surfaces: flat albedo with a little sheen, not mirror metal.
- Separate named nodes for plate, post, bracket and back.
- No gore, no political symbols, no real crests.
- All plate text must be crisp at 48 px and readable at 20 m in the drone camera.

## Priority 0: the signs in use

### Stop
| Asset | Description |
|---|---|
| `sign_stop_face` | 750 mm octagon, white border, red face, white STOP. Slight edge wear and a little dirt at the rim. |
| `sign_stop_back` | galvanised back and bracket, no text. |

### Speed limit
One plate style, six faces. White rectangle with a black border, black SPEED LIMIT and the number.

| Asset | Number |
|---|---|
| `sign_speed_10` | 10 |
| `sign_speed_15` | 15 |
| `sign_speed_20` | 20 |
| `sign_speed_25` | 25 |
| `sign_speed_30` | 30 |
| `sign_speed_40` | 40 |

These are the limits currently on the network: 40 on the valley highway and ridge, 30 on the east lane, 25 on the lake lane, 20 on the south and west lanes, 15 on the cabin track, 10 on the festival and launch lanes.

### Junction warning
| Asset | Description |
|---|---|
| `sign_warn_junction` | yellow diamond with a simple black side-road symbol, no text |
| `sign_warn_crossroad` | yellow diamond with a black crossroad symbol, optional later |

### Fingerpost
| Asset | Description |
|---|---|
| `sign_fingerpost` | green two-arm direction board on a dark timber post, blank arms with room for HALLOWAY LAKE, FARM, BOAT LAUNCH and CEMETERY. The game adds the words. |
| `sign_fingerpost_arm` | separate arm, blank, so longer place names can be added. |

### Posts and backs
| Asset | Description |
|---|---|
| `sign_post_galv` | galvanised U-channel post, 2.6 m, with two bolt holes |
| `sign_post_timber` | dark creosoted timber post, 2.6 m |
| `sign_bracket` | small bracket set for a flat plate |
| `sign_back_plate` | universal back plate for the stop, speed and warning faces |

## Priority 1: place and traffic signs

- `sign_gate_halloway` and `sign_gate_cemetery`, small stone or painted timber gate name boards.
- `sign_speed_end` white circle with a black diagonal bar, end of limit.
- `sign_no_through` blue or white no-through-road plate.
- `sign_parking` small P plate for the boat launch and east gate car park.
- `sign_launch` small boat launch plate with a ramp symbol.
- `sign_chevron_left` and `sign_chevron_right`, yellow and black bend chevrons for the ridge road.
- `sign_narrow_bridge` and `sign_steep_hill` warning diamonds, optional.
- `sign_mirror` convex mirror on a post for the north gate junction.

## Priority 2: detail and wear

- `sign_sticker_roundel` small faded permit or tax disc for the fingerpost.
- `sign_dent_a` and `sign_dent_b` small impact dents and bent edges.
- `sign_rust_patch` and `sign_moss_patch` decals.
- `sign_bracket_bolt` and `sign_post_cap`.
- `sign_stop_worn` a more faded stop face variant.

## Integration notes

- Placement is in `game/road_signs.gd`: eight stop signs on minor approaches, nine speed plates at route entries, three junction warnings and one fingerpost at the east gate.
- Stop lines are plain white paint strips in the same class; no separate art is needed unless the road markings pass gives them a texture.
- Traffic is capped at 85 percent of the route limit in `game/traffic.gd`; the signs and the behaviour share the same numbers in `game/roads.gd`.
- Keep plate and post origins at the ground; the code places the sign root at the terrain height.
- File names can be anything, but keep one face per speed value so the code can map limits directly.
- Keep the front face +Z. The code rotates the sign root to face oncoming traffic.

## What this unlocks

Priority 0 makes every sign in the valley readable and believable. Priority 1 gives the gates, car parks and ridge a complete traffic language. Priority 2 adds the wear that makes the valley feel used.
