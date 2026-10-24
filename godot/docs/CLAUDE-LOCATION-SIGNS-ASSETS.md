# Claude location and business sign asset brief: Halloway Valley

Status: production request, 2026-11-15. The valley now has code-built location signs: a large cemetery gateway, farm and business boards, lake, festival, camp, cabin and boat launch signs, plus small gate boards. This brief asks Claude for the final art.

Owner of placement and code: session B. Claude handles the art only; integration stays on this lane. The tone is a lived-in rural valley: painted timber, weathered stone, a little moss, no corporate signage.

## The signs in the valley

| Sign | Where | Current code |
|---|---|---|
| `sign_gateway_cemetery` | east gate turn off | large stone pillars, cross beam and a 6.4 m board, HALLOWAY CEMETERY with CHAPEL / WAR MEMORIAL / EAST GATE |
| `sign_gate_south` | south gate | small two-post board, HALLOWAY CEMETERY / SOUTH GATE |
| `sign_gate_north` | north gate | small two-post board, HALLOWAY CEMETERY / NORTH GATE |
| `sign_gate_west` | west gate | small two-post board, HALLOWAY CEMETERY / WEST GATE |
| `sign_farm_toby` | Toby Farm drive | two-post board, TOBY FARM, EGGS / FIREWOOD / HAY |
| `sign_garage_voss` | Voss and Son yard | two-post business board, VOSS AND SON / MOTOR WORKS / REPAIRS |
| `sign_lake_halloway` | lake turn | two-post board, HALLOWAY LAKE / BOAT LAUNCH / OVERLOOK |
| `sign_festival` | festival field | two-post board, FESTIVAL FIELD / HALLOWAY ANNUAL / BUS PARK |
| `sign_village` | village lane approach | two-post business board, HALLOWAY VILLAGE / THE GREEN / STORES / GARAGE |
| `sign_ridge_camp` | ridge camp | two-post board, RIDGE CAMP / PRIVATE TRACK / KEEP GATES CLOSED |
| `sign_old_cabin` | cabin track | small board, OLD CABIN / PRIVATE / NO TRESPASSING |
| `sign_boat_launch` | launch junction | small board, BOAT LAUNCH / SLOW / NO WAKE |
| `sign_chapel` | east gate | small wayfinding board, CHAPEL / WAR MEMORIAL / VISITOR PATH |

## Shared contract

- glTF 2.0 `.glb` for posts, frames, stone pillars and beams.
- Sign faces as PNG with transparency, or a UV atlas with a clear layout so the game can swap the text.
- Metre scale, Y up, origin at the base, front face +Z.
- Board heights: big gateway 2.7 m to the board centre; business boards 2.2 to 2.6 m; small gate boards 2.0 to 2.3 m.
- Weathered timber, painted boards, cast or galvanised brackets, moss and road dust at the base.
- No gore, no real crests, no political symbols, no advertising logos.
- Text may be baked into the board face for the place names above, or left blank with a UV guide. Either is useful; tell us which.
- The sign should read from the road at 20 to 60 m and again from a drone at 80 to 150 m.

## Priority 0: the gateway and the business signs

| Asset | Description | Notes |
|---|---|---|
| `gateway_cemetery_stone` | two stone pillars with caps, cross beam and a painted board frame | 7 m wide, 3.5 m tall; the board and lettering are separate |
| `gateway_cemetery_board` | 6.4 m by 1.55 m dark green board, cream lettering, a narrow cream border | front face texture |
| `gateway_gate_board` | 3.0 m by 0.95 m smaller board for the other three gates | one asset, different text faces |
| `sign_farm_double_post` | two oak posts, cross brace, 3.6 m board | board texture separate |
| `sign_business_double_post` | two timber posts, steel frame, 4.2 m board for Voss and Son | board texture separate |
| `sign_lake_double_post` | same as business, lake colours, 4.2 m board | board texture separate |
| `sign_field_double_post` | simpler field board for the festival and camp | 3.6 m |
| `sign_small_post` | single or double small post for the cabin, boat launch and chapel | 2.6 m |

## Priority 1: boards and lettering

- `board_cemetery` front face with HALLOWAY CEMETERY and the subtitle.
- `board_gate_south_north_west` three text variants.
- `board_farm`, `board_garage`, `board_lake`, `board_festival`, `board_camp`, `board_cabin`, `board_boat_launch`, `board_chapel`.
- A blank board face with a painted border, for future places.
- A small arrow blade set: left, right and straight, for the fingerposts.

## Priority 2: weathering and detail

- Moss, ivy and damp streaks on the stone pillars.
- Rusted bracket set and bolt caps.
- Chipped paint and a faded board variant.
- A small stone base and gravel apron for the gateway.
- A simple lamp bracket for the cemetery gateway, unlit.
- A notice case beside the gateway, closed.

## Integration notes

- `game/landmark_signs.gd` places the signs; text is currently Label3D. If Claude supplies baked boards, the game can swap to a textured quad and keep the same root.
- The big cemetery gateway is at the east gate turn off, beside the east car park. The other gates have smaller boards.
- The farm, garage, lake, festival, camp, cabin, boat launch and chapel signs each sit on the approach, not in the road.
- The sign face must be +Z. The code rotates the root to face the traffic.
- No collisions are needed for the first pass; add a simple collider for the stone pillars only if the art makes them substantial.

## What this unlocks

Priority 0 gives the valley its main place-making signs, especially the cemetery gateway at the turn. Priority 1 gives every destination a proper face. Priority 2 makes the signs feel like they have stood in the weather for decades.
