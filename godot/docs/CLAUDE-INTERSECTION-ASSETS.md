# Claude intersection signal and marking asset brief: Halloway Valley

Status: production request, 2026-11-15. The valley now has five code-built flashing red beacons on wires over rural junctions, stop-ahead diamond signs and stop bars. This brief asks Claude for the final signal and intersection art.

Owner of placement and code: session B. Claude handles the art only. The tone is a rural valley junction: weathered timber poles, galvanised hardware, one red lamp, no big-city traffic gantry.

## Shared contract

- glTF 2.0 `.glb` for poles, cable hardware, beacon housing and backplates.
- PNG with transparency for signal lenses and sign faces, or a UV atlas with clear layout.
- Metre scale, Y up, origin at the base, front face +Z.
- Pole height 6.2 to 6.8 m; beacon centre around 5.3 to 5.6 m above the road.
- Weathered galvanised steel and creosoted timber; a little rust at the brackets.
- No gore, no real crests, no political symbols, no readable advertising.
- Readable from the road at 40 to 120 m and from the drone at 100 to 250 m.

## Priority 0: the beacon assembly

| Asset | Description | Notes |
|---|---|---|
| `beacon_pole_timber` | creosoted timber pole, 6.5 m, with a small metal cap | two per junction |
| `beacon_pole_galv` | galvanised steel pole variant, 6.5 m | optional |
| `beacon_cable_clamp` | cast clamp and eye bolt for the span | small, two per pole |
| `beacon_housing` | black or dark green signal head, one red lens, deep top visor | approx. 0.6 m wide |
| `beacon_backplate` | yellow diamond backplate, slightly dirty, with mounting holes | 0.95 m across |
| `beacon_lens_red` | red fresnel lens with a dark rim | 0.4 m diameter |
| `beacon_lens_red_off` | dark unlit lens variant | optional texture |
| `beacon_bracket` | hanger bracket that joins the housing to the cable | small |

The signal is a single red lamp on both faces. No amber or green.

## Priority 0: the signs and markings

| Asset | Description | Notes |
|---|---|---|
| `sign_stop_ahead` | yellow diamond with a black STOP AHEAD or a stop symbol | front face texture, blank board glb |
| `sign_street_blade` | blank green or cream street-name blade, two-sided | for future junction names |
| `marking_stop_bar` | worn white stop bar, painted or decal | 3 to 4 m across |
| `marking_junction` | subtle asphalt junction patch and worn line ends | optional decal |

## Priority 1: wire and pole detail

- `beacon_wire_span` a sagging cable segment with a slight catenary, for a 20 m span.
- `beacon_insulator` small ceramic or glass insulator.
- `beacon_bird_spike` simple spike strip for the top of the housing.
- `beacon_service_box` small grey control box on one pole.
- `beacon_conduit` conduit and cable clips up the pole.
- `beacon_pole_reflector` white/red reflector band near the base.

## Priority 2: wear and weather

- `beacon_rust_bracket` and `beacon_chipped_paint`.
- `beacon_lens_dirt` dusty lens overlay.
- `beacon_cable_rust` cable and clamp wear.
- `beacon_backplate_fade` a faded yellow backplate variant.
- `beacon_bird_nest` a small, clean nest on the housing top, optional.

## Integration notes

- `game/intersection_signals.gd` places the poles and cable, and hangs the beacon at the wire centre.
- The code currently uses box cable and simple emissive spheres. Replace those with a proper cable and lens assembly while keeping the same junctions and heights.
- The beacon must be readable from both directions; supply a two-sided housing and lens.
- The lens should be a separate material so the code can animate its emission on and off.
- Stop-ahead signs are placed by `road_signs.gd`; the stop bars are placed with the stop signs.
- Junction line suppression is a shader mask in `roads.gd`; no art needed unless the patch decal is preferred.
- No collisions needed for the poles unless the final art makes them substantial.

## What this unlocks

Priority 0 gives the valley a believable rural red beacon and readable stop-ahead signs. Priority 1 gives the span the hardware and sag that sell it. Priority 2 makes the signal look like it has been standing in the weather for twenty years.
