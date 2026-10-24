# Intersections: markings, signs and flashing red beacons

Status: implemented, 2026-11-15. This is the intersection pass on top of the road network and the location signs. The valley now has rural-style junction markings, stop approach signs and five flashing red beacons hanging over the main crossings on wires between two poles.

## Why flashing red rather than full traffic lights

A rural valley junction with a handful of cars a day does not usually have a three-colour signal. The common country treatment is:

- a stop sign on each minor approach;
- a white stop bar painted across the approach;
- a yellow junction warning before it;
- and, at the busier or less visible crossings, a single red beacon hanging from a cable between two poles.

That is what this pass adds. It is scenery, not a traffic-control simulation: traffic still follows its loop and does not stop for the beacons.

## The beacons

`game/intersection_signals.gd` builds five:

| Junction | Wire axis | Poles |
|---|---|---|
| east gate and east car park | east-west | outside the road, 20 m apart |
| south gate lane and valley highway | north-south | 18 m apart |
| Toby Farm and lake junction | east-west | 20 m apart |
| north gate and ridge road | north-south | 18 m apart |
| west lane and lakeside lane | east-west | 18 m apart |

Each beacon has:

- two weathered timber poles, 6.5 m tall;
- a taut dark cable between the pole tops;
- a yellow diamond backplate;
- a dark housing with a top visor;
- a red lens on both faces;
- a red OmniLight that pulses with the lens.

The lens and light flash together, on for about 0.68 seconds and off for about 0.67 seconds. The beacons are visible in daylight and read strongly at night.

**Pause switch:** Display > World > Intersection beacons turns the flashing and the red light off. The poles, cable and housings remain.

## Intersection markings

- **Stop bars:** each stop sign has a white stop bar across its approach.
- **Stop ahead signs:** yellow warning diamonds reading STOP sit further back on the busier stop approaches (south lane, east lane, farm, cabin track).
- **Junction line suppression:** the asphalt shader now samples a junction mask built in `roads.gd`. The painted edge and centre lines fade through the junction apron, so a lane line does not run straight across a crossing.
- **Existing junction signs:** yellow warning diamonds and the speed plates at each route entry remain in `road_signs.gd`.

## Evidence

- `docs/realism/intersections/00_beacon_at_night.jpg`
- `docs/realism/intersections/01_east_gate_beacon.jpg`
- `docs/realism/intersections/02_south_junction.jpg`
- `docs/realism/intersections/03_stop_ahead.jpg`

## Honest limits

- Traffic does not stop for the flashing beacons or the stop signs. There is no signal controller, no queue detection and no give-way logic.
- The beacon is a single red lamp, not a full traffic light. There is no amber or green phase, because these are rural priority junctions.
- The wires are straight boxes, not true catenary curves. There is no wind sway on the cable.
- The beacon lenses are simple emissive spheres, not modelled fresnel lenses. There is no light flare or lens dirt.
- The stop bars are flat white boxes; they do not wear with traffic yet.
- The junction mask is a 1024 px raster, so the painted line fade at the junction edge is coarse.
- The STOP AHEAD signs are placeholder diamond plates with Label3D lettering, not final reflective signs.
- There is no street-name blade at the junctions yet.

## Questions for Robert

- INT1. Are five beacons the right number, or should more or fewer junctions have one?
- INT2. Should the beacons flash together or alternate across the valley?
- INT3. Should the cable sag like a real span, and should it sway in the wind?
- INT4. Should there be stop-ahead signs on every stop approach, or only the busier ones?
- INT5. Should any junction become a full three-colour signal, or is flashing red the ceiling for this valley?
- INT6. Should street-name blades be added at the main junctions?
