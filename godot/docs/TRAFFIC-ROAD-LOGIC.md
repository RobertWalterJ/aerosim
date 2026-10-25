# Traffic and road-direction logic

Status: 2026-11-15. Traffic now uses the road centreline and the correct right-hand lane.

## Direction and lanes

- The road ribbon is built from the route centreline. Traffic samples the centreline, then offsets to the **right of its direction of travel** by `route_width * 0.25` (1.25 m on a 5 m lane, 1.5 m on a 6 m lane).
- Opposite directions therefore pass on opposite sides of the centreline with a real gap, instead of sharing a line.
- The town route runs two vehicles in opposite directions, so the player can see a proper pass.
- The highway car runs the other way as the sparse long-road traffic.

## Density and time of day

- There are **two town vehicles** plus **one highway vehicle** on desktop, and **one town vehicle** plus **one highway vehicle** on mobile.
- The highway car is **night-only**: it appears after dark and is hidden during the day. The town pair remains.
- At night the highway car runs with two real `SpotLight3D` headlights and emissive lamps; it is the “single car on an empty road” atmospheric beat.
- This keeps traffic sparse while making town and the middle of the night feel more lived-in.

## Behaviour

- Vehicles loop the route; speed is capped at 85% of the road’s speed limit and the vehicle’s own speed.
- Wheels spin with speed.
- Headlights and lamp emission come on with `darkness`; tail-light glow is intentionally minimal.
- Thermal heat shells only move with visible vehicles; a hidden day-time highway car leaves no ghost heat.
- `trace_sources()` skips hidden vehicles, so tyre tracks follow only cars that are actually there.
- No collisions, no lane changes and no junction turns yet.

## Test

- `trafficlogic` gate passes.
- Runtime log confirms the three routes/directions: `village` forward, `village` opposite, `valley` opposite.
- `TRAFFIC-ROAD-LOGIC.md` is the design note for future changes.
