# World Builder: Chapter 4, Transport Networks, Utility Corridors and the OpenStreetMap-to-Pack Mapping

Written 2026-10-23 by Claude (research chapter). Companion to `CHAPTER-1-ARCHITECTURE-TERRAIN.md` (pack format 1.0, data sources, terrain, carving), `CHAPTER-2-ENVIRONS-SLOPES-ASSETS.md` (settlements, biomes, slopes, asset catalogue, gap finder, style file) and `CHAPTER-3-SUBURBS-RURAL-WILD.md` (suburbs, farmland, wilderness, highways, utilities in brief, discoveries, land-use layer). Sources are numbered [n] and listed in `SOURCES-4.md`. Where this chapter quotes a number from an earlier chapter, it is written as "Ch3 [12]" (Chapter 3, its source 12).

Tags follow Chapter 3:

* **Region**: **[ON]** Ontario and the Great Lakes; **[NA]** North America; **[EU]** Europe or elsewhere.
* **Confidence**: **(S)** taken from a cited source; **(C)** computed by me from sourced inputs; **(D)** a design default chosen so the generator has a number (tune by test); **(V)** common practice I know but did not confirm in a source this session.

## 0. Summary

This chapter does three jobs. First, it turns railways, urban transit, ferries, airports and utility corridors into classes and numbers a generator can use, the same way Chapter 3 did for highways. Second, it gives the complete mapping from OpenStreetMap (OSM) tags to world-pack classes, so that `wb import osm` can turn a real area (Hamilton, a Toronto neighbourhood, a stretch of the Rideau) into a correct pack. Third, it says what new assets these classes need, in Chapter 2's slot names, so the gap finder can report them.

The most important decisions:

1. **Rail gets its own graph file, `network/rail.json`, with the same shape as `roads.json`.** Chapter 1 put `rail` in the road classes and Chapter 3 put railways in `lines.json`. Neither works for trains: a game needs switches, track counts, gauge, electrification, cant and platforms, and must be able to route a train. Section 9 records the change.
2. **Transit routes are a separate layer, `network/transit.json`, that refers to edges in the road and rail graphs.** A streetcar route is not new geometry: it is an ordered list of rail edges in the street, plus stops at measured distances along the route. Buses do the same on road edges. Ferries are the one mode whose route carries its own geometry (a line across water). This is the shape that lets a game animate vehicles, and it maps one-to-one onto OSM route relations and onto GTFS timetables [4][54].
3. **Non-building structures get a new file, `infra/structures.geojson`.** Substations, tanks, masts, piers, breakwaters, platforms, runways and lock chambers are not buildings and not lines. Buildings with walls and a roof stay in `urban/buildings.geojson`. Small repeated objects (poles, buoys, signals, markers) are prop families in `props/props.json`, placed by rule.
4. **Airports write a height-limit raster.** The obstacle limitation surfaces (inner horizontal 45 m above the aerodrome within 4 km, conical slope 5 percent for a further 100 m of height, approach surfaces at 2 to 2.5 percent [34]) become `limits/height_cap.u16.zlib`, which the building generator must respect.
5. **Corridors are lines with a width and a clearing rule.** A 230 kV line is a 46 m corridor [21] that clears forest and leaves a mown or meadow strip; a 500 kV corridor is at least 64 m [22]; a pipeline has a 30 m regulated strip each side [26]. In Toronto, many hydro corridors are parks and trails [50].
6. **One machine-readable rule file drives OSM import**: `osm_rules.json`, with match, target layer, class, attributes, defaults and priority (Appendix A has 262 rules). The importer is a rule engine, not hand-written code per tag.

### 0.1 New and changed pack files

All additions are optional layers, so they are a minor version bump under Chapter 1's rules (pack format 1.1).

| File | Type | Contents | Section |
|---|---|---|---|
| `network/rail.json` | graph, schema `rwj-rail-1` | Track centrelines (one edge per track or per bundle), switches, crossings, stations, platforms, signals, cant, electrification | 1.9 |
| `network/transit.json` | routes, schema `rwj-transit-1` | Stops, stations, stop areas, routes as edge sequences or own geometry, optional timetables and frequencies, vehicle types | 2.6, 10 |
| `infra/structures.geojson` | polygons and points | Non-building structures: substations, tanks, towers, masts, piers, breakwaters, quays, platforms, runways, aprons, locks, dams, portals, shafts | 3, 4, 5 |
| `infra/aerodromes.json` | JSON | Aerodrome reference points, runways, taxiway graph, OLS parameters | 4.4 |
| `limits/height_cap.u16.zlib` | raster on the cover grid | Maximum permitted structure top height in metres above datum (same encoding as height), 65535 = no limit | 4.3 |
| `network/lines.json` | existing (Chapter 3) | Gains utility line ids, voltages, tower positions, corridor widths and clearing rules | 5 |
| `landuse/use.u8.zlib` | existing (Chapter 3) | Gains ids 191 to 230 (transport and utility areas) | 1.7, 9 |
| `osm/` | folder | Raw OSM cache and import report (`import-report.json`), never read by games | 6 |

`world.json` `layers` gains `"rail"`, `"transit"`, `"structures"`, `"aerodromes"` and `"height_cap"` keys, each pointing at its file.

---

## 1. Railways

### 1.1 Rail line classes

Every rail edge in `rail.json` has a `class`. The class sets defaults for right of way (ROW), track centres, curve radius, grade, speed and the cross-section. OSM tags select the class (section 1.10).

| class | What it is | Typical tracks | ROW (m) | Design speed (km/h) | R min (m) | Ruling grade | Tag |
|---|---|---|---|---|---|---|---|
| `main_freight` | Class I main line (CN, CPKC) [NA] | 1 with sidings, or 2 | 30 (100 ft) (V, Ch3) | 80 to 100 | 580 (3 degrees); preferred 1,750+ (1 degree) | 1.0 percent preferred; 2.2 percent historic limit (S, Ch3 [12]) | S/V |
| `main_passenger` | Shared or passenger main (GO Lakeshore, VIA corridor) [ON] | 2 to 4 | 30 to 45 (V) | 130 to 160 | 1,000 to 2,000 (D) | 1.0 to 1.5 percent; GO's steepest revenue grade is about 2.1 percent (weak, [36]) | V/D |
| `branch` | Branch line | 1 | 20 to 30 (V) | 40 to 80 | 290 (6 degrees) (D) | 1.5 to 2.5 percent (V) | V |
| `short_line` | Regional short line (e.g. Ontario Southland, Goderich-Exeter) [ON] | 1 | 20 (V) | 16 to 50 | 175 (10 degrees) (C from Ch3 [12]) | 2.5 percent (V) | V |
| `industrial_lead` / `spur` | Track to one customer | 1 | 10 to 15 (D) | 16 | 140 (12.5 degrees) (S, Ch3 [13]) | 2 to 3 percent (V) | S/V |
| `siding` | Passing siding beside a main | 1 | inside main ROW | 30 to 50 | as main | as main | V |
| `yard` | Classification, storage, intermodal | many | yard area | 16 | 120 to 150 (D) | 0.2 percent or flatter in body tracks (V); hump 1 to 2 percent (V) | V |
| `heritage` | Preserved or tourist railway | 1 | 15 to 20 | 15 to 40 | 100 (D) | 3 percent (V) | V |
| `abandoned` | Removed track, grade still visible [1] | 0 | 20 to 30 | n/a | as former class | as former class | S |
| `disused` | Track in place, no traffic [1] | 1 | as former class | n/a | as former class | as former class | S |
| `narrow_gauge` | Gauge under 1,435 mm [1] | 1 | 10 to 15 | 15 to 60 | 60 to 100 (D) | 3 to 4 percent (V) | V |
| `subway` | Metro, mostly grade-separated [1] | 2 | 15 to 20 on surface (D) | 80 to 90 | 90 to 150 main, 60 yard (V) | 3 to 4 percent (V) | V |
| `light_rail` | LRT on its own right of way [1] | 2 | 8 to 15 (D) | 70 to 80 (Flexity cars top out at 70 km/h [14]) | 25 (Flexity design standard [13]) | 6 percent (V) | S/V |
| `tram` | Streetcar in the street [1] | 1 to 2 in the road | inside road ROW | 40 to 70 | 11 (Toronto minimum 10.97 m [13][14]) | 8 to 9 percent (V) | S/V |
| `funicular` | Cable-hauled incline [1] | 1 (passing loop at mid-point) | 6 to 10 | 10 to 30 | straight preferred | 15 to 100+ percent | V |
| `monorail` | Beam railway [1] | 2 beams | 8 to 12 (D) | 50 to 80 | 50 to 100 (V) | 6 percent (V) | V |
| `miniature` | Park railway [1] | 1 | 3 to 5 | 10 | 20 (D) | 3 percent (D) | D |

Radius from degree of curve: R (m) = 1,746.4 / D (C, Ch3). Curve grade compensation: subtract 0.04 percent of grade per degree of curve (S, Ch3 [12]), so a 1.0 percent ruling grade on a 3 degree curve is limited to 0.88 percent.

**Generator rule (D):** pick the class first, then route; never pick a class from the result of routing. A seeded world gets one or two `main_*` lines across the map (railways were built between places beyond the map), branches to towns not on the main, and spurs to every `IN2`/`IN3` industrial lot and grain elevator within 2 km of a line.

### 1.2 Track geometry numbers

**Gauge.**

| Gauge | mm | Where | Tag |
|---|---|---|---|
| Standard | 1,435 | All Canadian and US main lines, GO, UP Express, Lines 5 and 6 in Toronto [15] | S |
| Toronto gauge | 1,495 | TTC streetcars and subway Lines 1, 2 and 4 [13][15] | S |
| Cape gauge | 1,067 | Historic Newfoundland, many tourist lines worldwide | V |
| Three foot | 914 | White Pass and Yukon, US heritage lines | V |
| Metre | 1,000 | Europe, Switzerland, many trams | V |
| Broad (Iberian, Russian, Indian) | 1,668 / 1,520 / 1,676 | [EU] and world presets | V |

Store `gauge_mm` on every edge. Games use it to scale rail spacing on the track mesh; the pack never assumes 1,435.

**Track centres (minimum distance between parallel track centrelines), Transport Canada TC E-05 [28]:**

| Case | Minimum | Generator default (D) |
|---|---|---|
| Main tracks | 3.96 m (13 ft) (S) | 4.3 m |
| Main and siding, main and parallel yard track | 4.27 m (14 ft) (S) | 4.6 m |
| Yard tracks | 4.11 m (13 ft 6 in) (S) | 4.6 m (room for walkways, V) |
| Ladder tracks | 4.57 m (15 ft); parallel ladders 5.49 m (S) | as minimum |
| Passenger station tracks without a platform between | 3.96 m (S) | 4.3 m |
| Curves | add 50.8 mm per degree of curve, plus 63.5 mm per 25.4 mm of cant difference (S) | apply |
| Tram double track in the street [ON] | 3.0 to 3.4 m (V) | 3.2 m |
| High-speed [EU] | 4.0 to 5.0 m (S [29]) | 4.5 m |

**Horizontal curves and cant (superelevation).** For standard gauge the equilibrium cant is e (mm) = 11.8 V^2 / R, with V in km/h and R in m (C: from e = G v^2 / (g R) with G about 1,500 mm between rail centres). Apply only part of it, because slow freight shares the track:

```
e_eq      = 11.8 * V^2 / R                  (mm)
e_applied = min(e_eq - d_allow, e_max)      d_allow = cant deficiency allowed
e_max     = 152 mm passenger main (D, below the US 178 mm limit for most track classes [30])
            100 mm mixed freight main (D); 0 in yards, turnouts and street track
d_allow   = 75 mm default (the US default of 3 in for untested equipment [30]); 125 mm for tilt or modern passenger stock [30]
V_max(R)  = sqrt( (e_applied + d_allow) * R / 11.8 )
```

Store the applied cant in mm per edge (`cant_mm`, sign by curve direction). Games tilt the track mesh and the rolling stock by asin(cant / 1,500).

**Transition spirals (easements).** Cant and curvature cannot jump; both ramp along a clothoid [30]. The length is the larger of the cant-ramp rule and the deficiency-rate rule (V; the metric form of a common North American rule L = 1.63 E_u V in feet, inches and mph):

```
L_spiral = max( 0.40 * e_applied_mm ,            (cant gradient 1:400, V)
                0.0122 * d_allow_mm * V_kmh ,      (V, converted)
                20 m )                            (D floor)
```

Tram and streetcar curves usually have no spirals or very short ones (V), and loops are tight circular arcs at 11 to 15 m radius [13].

**Vertical curves.** Rail vertical curves are long. Use a minimum length L = 30 m per 0.1 percent change of grade on mains and 15 m on branches and yards (V; this reproduces the old AREA rate of change of 0.05 to 0.1 feet per station in feet units within the right order of magnitude, not confirmed). Chapter 1's profile smoother takes these as K values: K_rail_main = 300 m per percent, K_rail_branch = 150 m per percent (D).

**Grades by class**: see the table in 1.1. A generator that cannot meet the ruling grade between two settlements must lengthen the line (loops, horseshoe curves along valley sides), cut, fill, bridge or tunnel; it must never exceed the class maximum.

### 1.3 Cross-section and the track bed

Track sits on sleepers (ties), on ballast, on sub-ballast, on the subgrade. Numbers for a North American main line:

| Element | Value | Tag |
|---|---|---|
| Sleeper (wood) | 2.59 m long (8 ft 6 in), about 0.23 m wide, 178 mm deep | S [49] (length and depth); width V |
| Sleeper spacing | wood 0.48 to 0.50 m centres (about 2,019 per km); concrete 0.61 m (1,640 per km) | S [48] |
| Rail | 136 lb/yd (about 67 kg/m) on mains, 115 lb on branches (V); head 74 mm wide (V) | V |
| Ballast depth under sleepers | 305 mm on main running tracks, 203 mm elsewhere | S [49] |
| Sub-ballast | 150 mm minimum on mains | S [49] |
| Ballast shoulder beyond sleeper end | 300 to 400 mm | S [49] |
| Ballast side slope | 2:1 down to the subgrade | S [49] |
| Subgrade top width | 7 to 8 m single track; add the track centres for double track | V, Ch3 |
| Ditches | 0.6 to 1.0 m deep each side in cuts and on low fills (V) | V |
| Cut slopes | soil 1.5:1, rock 0.25:1 to 0.5:1 (V, Ch3) | V |
| Fill slopes | 2:1 (V, Ch3) | V |
| Embankment height | up to 10 to 15 m before a bridge or trestle (V, Ch3) | V |

**Template for the carving pass (extends Chapter 3 section 4.10):**

```json
{ "template": "rail_main_single",
  "gauge_mm": 1435, "sleeper_len_m": 2.59, "sleeper_depth_m": 0.178,
  "ballast_depth_m": 0.305, "subballast_m": 0.15, "shoulder_m": 0.35, "ballast_slope": 2.0,
  "subgrade_width_m": 7.3, "crown_pct": 3.0,
  "ditch": { "depth_m": 0.8, "bottom_w_m": 0.6, "in_cut": true, "on_fill_below_m": 1.5 },
  "cut_ratio": { "soil": 1.5, "rock": 0.33 }, "fill_ratio": 2.0,
  "top_of_rail_above_subgrade_m": 0.67 }
```

`top_of_rail_above_subgrade_m` = ballast + sub-ballast + sleeper depth + rail height (about 0.185 m, V) = 0.81 m on mains; 0.67 m is used here because sub-ballast sits partly below the subgrade line (D). Store the graded **top-of-rail** height as z in `rail.json` (like roads, the graded value). The terrain under the formation is lowered to top of rail minus 0.81 m inside the subgrade width and shaped by the template outside it.

### 1.4 Bridges, tunnels, cuts and embankments

| Structure | Use when (D) | Typical span or size | OSM | Tag |
|---|---|---|---|---|
| Culvert | Stream drainage area under 5 km2 (Ch3 4.6) | pipe 0.9 to 3 m; box 2 to 4 m | `tunnel=culvert` on the waterway | D |
| Plate girder (deck or through) | Gap 5 to 40 m; road and creek crossings | spans 10 to 35 m (V) | `bridge=yes`, `bridge:structure=beam` | V |
| Timber trestle | Old branch lines, gap height 5 to 25 m, any length | bents every 4 to 5 m (V) | `bridge=trestle` (V tag) | V |
| Steel trestle (viaduct) | Deep valleys on mains, heights 20 to 60 m | towers every 20 to 30 m, girders between (V) | `bridge=viaduct` | V |
| Truss (through) | River crossings, spans 40 to 150 m | 1 to 6 spans | `bridge:structure=truss` [38] | V |
| Concrete box girder or arch | Modern mains, LRT viaducts | 30 to 60 m spans (V) | `bridge:structure=beam/arch` [38] | V |
| Swing, lift, bascule | Navigable water with low approach (Welland Canal has three vertical-lift road bridges on its current line [32]) | span 40 to 120 m | `bridge:movable=*` | S/V |
| Tunnel (bored or drill and blast) | Ridge where the cut would exceed 20 to 25 m or the line would leave the ruling grade | bore 6 m single track (subway twin bores are about 6 m each [53]), 8 to 10 m freight single (V) | `tunnel=yes`, `layer=-1` | S/V |
| Cut and cover | Urban subways, shallow underpasses | box 10 to 12 m wide for two tracks (V) | `tunnel=yes` + `location=underground` | V |
| Rock cut | Shield and escarpment crossings | walls 5 to 20 m (Ch3) | `cutting=yes` | V |
| Embankment | Valleys and floodplains below about 12 m fill | 2:1 sides | `embankment=yes` | V |

**Rule for the generator (D):** fill depth over 12 m or water: bridge, choosing the type from span and era (`era: "1880"` gives timber trestle or truss; `"1960"` plate girder; `"2010"` concrete). Cut deeper than 20 m in soil or 25 m in rock over more than 300 m: tunnel. Vertical clearance under a rail bridge over a road: 5.3 m (Ch3); road over rail: 7.0 m above top of rail (Ch3, consistent with the North American 22 to 23 ft practice, V; TC E-05 gives the exact value only in a diagram not read here [28]).

### 1.5 Level crossings, warning devices and grade separation

| Road over the crossing | Warning devices (default) | OSM tags on the shared node [37] | Tag |
|---|---|---|---|
| Farm lane, private | Crossbuck only, "stop" sign optional | `railway=level_crossing`, `crossing:barrier=no`, `crossing:light=no`, `crossing:saltire=yes` | V |
| Gravel or local road, light traffic | Crossbuck and flashing lights with bell | `crossing:light=yes`, `crossing:bell=yes`, `crossing:barrier=no` | V |
| Paved collector or arterial | Lights, bell and gates (half barriers each side) | `crossing:barrier=half`, `crossing:light=yes`, `crossing:bell=yes`, `crossing:activation=automatic` | V |
| Four-lane arterial | Lights on cantilevers, gates, sometimes four-quadrant gates | `crossing:barrier=double_half` | V |
| Expressway or freeway | Never at grade: grade separation | none (bridge) | D |
| Footpath or trail | Pedestrian crossing, maze or swing gates | `railway=crossing` [1][37] | S |
| Tram crossing a road | Traffic signals; no gates | `railway=tram_level_crossing` [1] | S |

Canada regulates all of this through the Grade Crossings Regulations and Standards, which cover sightlines, signs and warning systems (lights, bells, gates) [27]. I did not read the Standards' numeric tables, so the defaults above are practice values (V).

**Grade separation rule (D):** separate when the road class is `motorway`, `trunk` or a four-lane `primary`, or the rail line has more than 2 tracks, or the line is `subway`/`light_rail` on its own right of way. Otherwise make a level crossing. Pick the road over rail if the road's approach terrain is higher, else rail over road; never put a level crossing within 30 m of a road junction (D) or on a rail curve over 2 degrees (D).

**Pack form.** A level crossing is a node in `rail.json` with `kind: "level_crossing"` and `road_node` set to the matching node id in `roads.json`. Both graphs share the coordinate. Crossing assets (gates, lights, crossbuck, panels) are props placed from this node: one signal mast per road approach on the right-hand side, 3.5 to 5 m from the nearest rail (V), gate arm length equal to the approach half-width (D).

### 1.6 Electrification and signals

| Item | Value | Tag |
|---|---|---|
| Main line electrification [ON] | GO Expansion uses 25 kV 60 Hz AC overhead [56] | S |
| Toronto streetcars | 600 V DC overhead; pantograph since 2017 on 509, trolley pole retained in carhouses [13][14] | S |
| Toronto subway Lines 1, 2, 4 | 600 V DC third rail [15] | S |
| Toronto LRT Lines 5, 6 | 750 V DC overhead [15] | S |
| Contact wire height, main line | 5.0 to 5.6 m above top of rail (V); about 5.3 m quoted for GO (weak, [56]); higher (6.5 to 7.4 m) where double-stack freight runs (V) | V |
| Contact wire height, street tram | 5.5 to 6.0 m over the road (V) | V |
| Catenary type | messenger plus contact wire with droppers for speed; simple trolley wire for trams and depots [31] | S |
| Mast spacing | main catenary 50 to 65 m on straight track, closer on curves (V); street tram poles 25 to 40 m, or span wires from buildings (V) | V |
| Wire tension | 9 to 20 kN auto-tensioned; 10 kN fixed for low speed [31] | S |
| Stagger | contact wire zigzags left and right of centre between supports [31]; plus or minus 0.2 to 0.3 m (V) | S/V |
| Block signals (main) | every 2 to 3 km on CTC territory, at every control point and siding end (V) | V |
| Signal bridges / cantilevers | at control points on multi-track lines, interlockings and yard throats (V) | V |
| Subway signals | every 200 to 400 m in tunnels; CBTC lines have few wayside signals (V) | V |

**Electrification attributes** on every rail edge: `electrified` (`contact_line`, `rail`, `no`) and `voltage`, `frequency` exactly as OSM [1]. **Signals** are nodes in `rail.json` with `kind: "signal"`, `facing` (direction along the edge) and `form` (`mast`, `bridge`, `cantilever`, `dwarf`); games pick the head style. A signal bridge spans all tracks of a bundle at that station.

### 1.7 Stations, platforms, yards and railway land use

**New use classes (ids 191 to 203), continuing Chapter 3's `IF` codes.** Ch3's `IF3` (182, rail ROW and yard) stays as the generic rail corridor class.

| id | code | class | colour | cover | footprint and rules | assets |
|---|---|---|---|---|---|---|
| 191 | IF12 | Classification yard | #6a5446 | 14 | 3 to 5 km long, 200 to 500 m wide (V, Ch3); a hump at one end; ladders at both ends | rail.track, rail.switch, rail.light_tower, yard.office, rolling_stock rows |
| 192 | IF13 | Intermodal terminal | #75604f | 14 | 30 to 120 ha; working tracks 1.5 to 3 km; stacked containers 2 to 4 high; wide-span gantry or reach stackers (V) | crane.rmg, reach_stacker, container.stack, trailer rows |
| 193 | IF14 | Engine facility (roundhouse, shop, fuelling) | #806a58 | 14 | roundhouse arcs of 10 to 40 stalls round a 25 to 35 m turntable (V); fuel racks; sand tower | roundhouse, turntable, shop.diesel, tank.fuel |
| 194 | IF15 | Passenger station (surface) | #b39a7d | 14 | building plus platforms, forecourt, bus loop, parking: GO stations 3 to 20 ha with surface lots (V) | station.small or station.large, platform, shelter.platform, canopy, parking.surface |
| 195 | IF16 | Transit maintenance yard (subway, LRT, streetcar) | #8b7764 | 14 | 8 to 30 ha; storage tracks, a large shop building; Toronto's Leslie Barns serves Flexity cars [13] | carhouse, rail.track, overhead.wire |
| 196 | IF17 | Bulk rail terminal (grain, aggregates, oil, coal) | #7e6650 | 14 | loop track 2 to 3 km, or parallel sidings at an elevator (Ch3 2.9) | elevator.grain_terminal, conveyor, tank.storage, hopper rows |
| 197 | IF18 | Rail trail (abandoned grade as trail) | #b4a27a | 6 | 8 to 15 m cleared strip, 3 m surfaced trail on the old grade (V) | path.rail_trail, bridge.truss_ped, sign.trailhead |
| 198 | IF19 | Bus terminal or garage | #9a8d7f | 14 | terminal 0.5 to 3 ha with saw-tooth bays; garage 5 to 15 ha (V) | bus.bay_canopy, garage.bus, bus rows |
| 199 | IF20 | Subway station surface works | #a28c75 | 14 | entrance buildings, bus bays, vent shafts on a 0.2 to 2 ha site (V) | entrance.subway, shaft.vent, bus.bay_canopy |
| 200 | IF21 | Streetcar or tram loop | #a89079 | 14 | a 0.1 to 0.4 ha block with a track loop of 11 to 15 m radius [13] and a shelter | rail.track_street, shelter.tram, overhead.wire |
| 201 | IF22 | Ferry terminal | #7c8fa3 | 14 | see section 3.2 | ferry.terminal_bldg, ramp.linkspan, queue.lanes |
| 202 | IF23 | Container or bulk port | #6c7f93 | 14 | see section 3.4 | crane.sts, container.stack, crane.rtg, warehouse.port |
| 203 | IF24 | Canal lock and lock station | #5f7f9a | 1 | chamber plus walls, gates, lock office, approach walls | lock.chamber, lock.gate_mitre, bollard, building.lock_office |

**Platforms and stations (V unless marked):**

| Mode | Platform length | Platform width | Height above rail | Station spacing | Station footprint |
|---|---|---|---|---|---|
| GO commuter rail [ON] | 300 to 320 m, from 12 bilevel coaches of about 26 m (C, coach length V; 12-car platforms per [36], weak) | 4 to 8 m side, 8 to 12 m island | low (about 0.2 m) historically; level boarding being added [36] | 3 to 8 km (V) | 3 to 20 ha with parking |
| Intercity (VIA) | 150 to 400 m | 4 to 6 m | low | 20 to 80 km | small building, 0.2 to 2 ha |
| Subway (TTC Lines 1, 2) | about 152 m for 6-car trains (V) | island 10 to 14 m, side 4 to 6 m | high, level boarding | 0.8 to 1.2 km downtown, 1.5 to 2 km suburban (V); Line 5 averages 0.79 km (C from 19 km and 25 stops [15]) | box 150 to 200 m x 20 to 25 m under the street |
| LRT | 40 to 90 m (one or two cars; Line 5 runs 2-car trains [15]) | 3 to 5 m side, 6 to 8 m centre | low-floor, about 0.35 m above rail (V) | 0.5 to 1 km; Line 6 averages 0.6 km (C from 10.3 km and 18 stops [15]) | median platforms in the road |
| Streetcar | 30 to 35 m for a 28 m Flexity [14] (C) | 2.5 to 3.5 m island where provided (V) | kerb or low platform | 300 to 400 m (S, TTC standard [45]) | on-street stop |
| BRT | 40 to 60 m (V) | 3 to 5 m | kerb or level | 400 to 800 m (V) | median or kerbside stations |

### 1.8 Routing rail across terrain

Chapter 3 section 4.10 gives the general route search. Rail uses the same lattice search with these changes (D):

```
cost grid      10 m (S, M tiers) or 20 m (L tier); heading lattice 32 directions (rail turns are gentler than roads)
hard limits    grade (after curve compensation) <= class ruling grade
               turn radius >= class R_min (reject any lattice move tighter than that)
               no level crossing with motorway or trunk (bridge forced)
               slopes over 25 degrees across the corridor: forbidden unless tunnel or bridge is chosen
earthwork      cut and fill estimated from the 1D profile against a straight grade line between lattice nodes
bridge         allowed over water and where fill > 12 m; cost = c_bridge * span_m, c_bridge = 40 x plain track per metre (D)
tunnel         allowed where cut > 25 m for > 300 m; cost = 120 x plain track per metre (D)
attractors     river valleys (cost x 0.7 inside 300 m of a river with gentle floodplain), existing ROW x 0.3, settlements as waypoints
order          rail mains first, before freeways (Chapter 3)
```

Then:

1. **Profile.** Sample every 10 m; solve a smoothed profile with the class ruling grade and K values (1.2). Rail profiles stay much flatter than roads, so long cuts and fills are normal.
2. **Spirals.** Fit circular arcs at each lattice turn with R at least the class minimum, insert clothoid spirals (1.2), and recompute the profile on the fitted line.
3. **Structures.** Mark bridges and tunnels (1.4); bridges over water get clearance from the navigable status of the water (section 3.4).
4. **Carve.** Apply the template in 1.3 to the heightmap: formation at top of rail minus 0.81 m, ballast prism, ditches, cut and fill side slopes, blend 2 to 4 samples. Bridges and tunnels do not carve (the terrain stays; abutments get a 6 to 10 m wide pad and a wing wall).
5. **Drainage.** Every stream crossing becomes a culvert or bridge so the embankment never dams flow in Chapter 1's hydrology (Ch3 4.6).
6. **Stations.** Place stations on straight, level stretches (grade under 0.5 percent over the platform length plus 100 m, D) near settlement centres; widen the formation for platforms and sidings.

**Heightmap changes a drone sees:** long benches cut into valley sides, embankments with culverts, rock cuts with vertical walls on the Shield, straight lines across fields with a ditch both sides, and hairpin-free gentle curves. That straightness is the signature (Ch3 4.5).

### 1.9 `network/rail.json` (schema `rwj-rail-1`)

Same structure as `roads.json`: nodes and edges, with graded z. One edge per **track** where the generator or OSM knows individual tracks; one edge per **bundle** with `tracks: n` where it does not (most OSM main lines in Canada are drawn track by track; many branch lines are one way with no `tracks` tag).

```json
{
  "schema": "rwj-rail-1",
  "classes": {
    "main_freight": { "gauge_mm": 1435, "row_m": 30, "track_centres_m": 4.3, "r_min_m": 580, "ruling_grade": 0.010,
                      "cant_max_mm": 100, "template": "rail_main_single", "speed_kmh": 100 },
    "tram":         { "gauge_mm": 1495, "row_m": 0, "track_centres_m": 3.2, "r_min_m": 11, "ruling_grade": 0.08,
                      "cant_max_mm": 0, "template": "rail_street_embedded", "speed_kmh": 50 }
  },
  "nodes": [
    { "id": 501, "p": [412.0, -88.0, 96.84], "kind": "switch", "switch": { "number": 12, "legs": [9001, 9002, 9003] } },
    { "id": 502, "p": [655.0, -90.5, 96.40], "kind": "level_crossing", "road_node": 77,
      "crossing": { "barrier": "half", "light": true, "bell": true } },
    { "id": 503, "p": [910.0, -91.0, 96.10], "kind": "signal", "signal": { "form": "mast", "facing_edge": 9004, "dir": 1 } },
    { "id": 504, "p": [1210.0, -92.0, 95.80], "kind": "end" }
  ],
  "edges": [
    { "id": 9001, "a": 501, "b": 502, "class": "main_freight", "service": null, "usage": "main",
      "gauge_mm": 1435, "tracks": 1, "electrified": "no", "maxspeed_kmh": 95,
      "bridge": false, "tunnel": false, "layer": 0, "cutting": false, "embankment": true,
      "cant_mm": [[0, 0], [120, 45], [380, 45], [500, 0]],
      "pts": [[412.0, -88.0, 96.84], [530.0, -89.5, 96.62], [655.0, -90.5, 96.40]],
      "name": "Grimsby Subdivision", "ref": null, "operator": "CN",
      "source": "osm:way/23456789", "confidence": "tagged" },
    { "id": 9010, "a": 610, "b": 611, "class": "tram", "gauge_mm": 1495, "tracks": 1,
      "electrified": "contact_line", "voltage": 600, "frequency": 0,
      "embedded": "road", "road_edge": 10, "lateral_m": -1.6,
      "pts": [[0.0, 6.4, 133.60], [60.0, 6.4, 131.88]], "source": "osm:way/34567890" }
  ],
  "platforms": [
    { "id": "pf-1", "station": "st-1", "edge": 9001, "s_from_m": 40.0, "s_to_m": 340.0, "side": "left",
      "height_m": 0.2, "width_m": 6.0, "ref": "1", "source": "osm:way/45678901" }
  ],
  "stations": [
    { "id": "st-1", "name": "Aldershot", "kind": "commuter", "p": [190.0, -60.0, 97.2],
      "lot": "lot-3001", "building": "b-5001", "source": "osm:node/1234" }
  ]
}
```

Rules: `cant_mm` is a list of `[s_m, cant]` pairs along the edge (linear between); `embedded: "road"` plus `road_edge` and `lateral_m` (offset from the road centreline, positive to the left of the road's a-to-b direction) ties street track to the road graph so the game lays rails in the pavement and the road builder leaves a track zone; a `switch` node lists its three legs (the through leg first). `s_m` is distance along the edge from node `a`.

### 1.10 OSM mapping for railways

| OSM | Pack | Notes |
|---|---|---|
| `railway=rail` + `usage=main` | `main_freight` (or `main_passenger` if the line carries `passenger=*` or is a member of a `route=train` relation and has `maxspeed>=130`) | [1] |
| `railway=rail` + `usage=branch` | `branch` | [1] |
| `railway=rail` + `usage=industrial` or `service=spur` | `industrial_lead` | [1] |
| `railway=rail` + `usage=tourism` or `railway:preserved=yes` | `heritage` | [1] |
| `railway=rail` + `usage=military/test/scientific` | `branch` with `usage` kept | [1] |
| `railway=rail` + `service=siding` | `siding` | [1] |
| `railway=rail` + `service=yard` | `yard` | [1] |
| `railway=rail` + `service=crossover` | `siding` with `crossover: true` | [1] |
| `railway=rail`, no usage, no service | `branch` (D); upgrade to `main_freight` if `tracks>=2` or `maxspeed>=80` | D |
| `railway=narrow_gauge` | `narrow_gauge`, `gauge` from tag else 1,067 (D) | [1] |
| `railway=subway` | `subway` | [1] |
| `railway=light_rail` | `light_rail` | [1] |
| `railway=tram` | `tram`; `embedded: "road"` if the way shares nodes with or lies within 3 m of a highway way for over 70 percent of its length (C) | [1] |
| `railway=funicular` / `monorail` / `miniature` | same-named class | [1] |
| `railway=abandoned` | `abandoned` (no track; a grade, often a trail) | [1] |
| `railway=disused` | `disused` | [1] |
| `railway=construction` / `proposed` / `razed` | skipped by default; recipe flag `include_lifecycle` | [1] |
| `gauge=*` | `gauge_mm`; a value like `1435;1495` (dual gauge) keeps the first and records `dual_gauge` | [1] |
| `tracks=*` | `tracks` | [1] |
| `electrified`, `voltage`, `frequency` | copied | [1] |
| `maxspeed` | `maxspeed_kmh` (convert `mph`) | |
| `bridge`, `tunnel`, `layer`, `cutting`, `embankment` | copied; see 6.4 | [7] |
| `name`, `ref`, `operator`, `railway:track_ref` | copied | [1] |
| `railway=switch` node | `kind: "switch"` | [1] |
| `railway=level_crossing` node | `kind: "level_crossing"` + `crossing:*` | [37] |
| `railway=crossing` node | `kind: "foot_crossing"` | [1] |
| `railway=railway_crossing` node | `kind: "diamond"` | [1] |
| `railway=buffer_stop` / `derail` | `kind: "end"` with `stop: "buffer"` | [1] |
| `railway=signal` node | `kind: "signal"` | [1] |
| `railway=station` / `halt` / `stop` / `tram_stop` | stations and stops (section 2.6) | [1][4] |
| `railway=platform` (way or area) | `platforms[]` and `infra/structures.geojson` `kind: "platform"` | [1] |
| `railway=roundhouse`, `turntable`, `traverser`, `workshop`, `wash` | structures; use class 193 inside a landuse=railway area | [1] |
| `railway=subway_entrance`, `ventilation_shaft` | structures `entrance.subway`, `shaft.vent` | [1] |
| `landuse=railway` | use class 182 (IF3); upgraded to 191/192/195 by contents (D) | |

---

## 2. Urban transit

### 2.1 Modes and their numbers

| Mode | Pack layer | Running way | Typical stop spacing | Vehicle (example) | Road interaction | Tag |
|---|---|---|---|---|---|---|
| Subway / metro | `rail.json` class `subway`; routes in `transit.json` | twin bored tunnels about 6 m each, or cut and cover box; elevated or at grade in suburbs | 0.8 to 1.5 km (V); TTC Line 1 is 38.8 km [15] | 6-car trains, about 138 m (V) | none, except entrances, bus bays and vent shafts | S/V |
| LRT, own right of way | `light_rail` | median reservation 7 to 9 m in the road or separate alignment (V) | 0.5 to 1 km; Line 6: 18 stops in 10.3 km [15] | Flexity Freedom, 2-car on Line 5 [15] | signals with transit priority at every cross street | S/V |
| Streetcar in mixed traffic | `tram`, `embedded: "road"` | track in the curb or centre lanes | 300 to 400 m (S [45]) | Flexity Outlook: 28 m long, 2.54 m wide, 3.84 m tall, 130 riders, 70 km/h [14] | shares lanes; cars wait behind at stops (Ontario law, V) | S |
| Streetcar in dedicated lanes | `tram`, lanes `psv` | centre reservation with raised island platforms (St Clair, Spadina, Queens Quay [13]) | 300 to 500 m | as above | signal priority; left turns at signals only | S/V |
| BRT | road class `busway` or road lanes `psv` | median busway or curb lanes | 400 to 800 m (V) | 12 m and 18 m buses (V) | queue jumps, signal priority | V |
| Local bus | stops on road edges | general lanes | 300 to 400 m (S [45]) | 12 m bus (V) | stops at the curb or in bays | S |
| Express bus | stops on road edges | general or HOV lanes | 650 to 1,000 m (S [45]) | 12 to 18 m | as local | S |
| Commuter rail (GO, UP Express) | `rail.json` `main_passenger` | shared main lines | 3 to 8 km (V) | GO bilevel coaches; UP Express DMUs (V) | level crossings outside the core | V |
| Trolleybus | road + `overhead: true` on lanes | general lanes, two overhead wires | as bus | 12 to 18 m | needs overhead wire props over the lane | V |
| Funicular | `rail.json` `funicular` | single track, passing loop | 2 stations | 1 or 2 cars | none | S [1] |
| Aerial tramway / gondola | `transit.json` mode `aerial` with own geometry | cable between towers | 2 to 4 stations | cabins 8 to 200 riders (V) | towers on the ground every 100 to 400 m (V) | V |
| Monorail / people mover | `rail.json` `monorail` | elevated beam | 0.5 to 1.5 km | 2 to 6 cars | columns in medians | V |

### 2.2 Subways in detail

| Element | Rule | Tag |
|---|---|---|
| Tunnels | twin bores about 6 m inside diameter, one track each [53]; or a cut-and-cover box about 10 to 12 m wide by 6 to 7 m high for two tracks (V). Toronto's oldest sections are cut and cover; newer ones mostly bored [53] | S/V |
| Depth | cut and cover: top of rail 8 to 12 m below the street (V); bored: 15 to 30 m (V); some new deep stations reach 40 m (the Ontario Line pit at Moss Park is up to 40 m [53]) | S/V |
| Station box | 150 to 200 m long, 20 to 25 m wide (V) under the street, with 2 to 4 entrances | V |
| Entrances | building or stair kiosk 5 x 10 to 15 x 30 m (V), within 100 m of the platform ends | V |
| Ventilation shafts | one at each station end and every 0.5 to 1 km between stations (V); a grate in the boulevard or a small building | V |
| Portals | where the line rises to grade: a ramp at 3 to 4 percent with retaining walls, 150 to 300 m long (C from a 6 to 10 m depth change) | C |
| Elevated sections | guideway 8 to 10 m wide on columns every 25 to 35 m, 6 to 10 m above ground (V) | V |
| Yards | 10 to 30 ha at line ends (V) | V |

In the pack, subway edges carry `tunnel: true`, `layer: -2` or lower, and a `depth_m` (top of rail below ground). The terrain is **not** carved for tunnels. Only portals, open cuts, entrances and vent shafts touch the surface.

### 2.3 Streetcars in the street (Toronto as the reference)

| Item | Value | Tag |
|---|---|---|
| Gauge | 1,495 mm [13] | S |
| Network | 11 daytime routes, 83 km, 685 stops [13] | S |
| Car | Flexity Outlook, 5 modules, about 28 m, 2.54 m wide, 3.84 m high, 70 seated and 130 maximum [14] | S |
| Minimum radius | 10.97 m; tightest in carhouses 11.3 m; loops usually under 15 m; the Flexity standard asks 25 m for new work [13][14] | S |
| Overhead | 600 V DC trolley wire, pantograph pickup [13] | S |
| Track in pavement | girder rail in concrete, 1.5 to 1.8 m wide concrete track slab per track (V) | V |
| Lane with track | 3.3 to 3.5 m curb lane in mixed traffic (V); centre reservation 6.5 to 7.5 m for two tracks plus 2.5 to 3 m side platforms at stops (V) | V |
| Stop spacing | 300 to 400 m [45] | S |
| Stop | pole and sign at the curb, or a raised island 30 to 35 m long; shelters at busy stops (V) | V |
| Loops | a block-sized loop or a street loop (around a block) at route ends; turnback loops at intermediate points [13] | S |
| Carhouses | Roncesvalles, Russell, Leslie Barns [13] | S |

**Rules for the road builder (D).** When a tram edge is embedded in a road edge, the road gets lane attributes: `lanes_tram: 1` per direction, `tram_position: "curb" | "centre"`, `reserved: false | true`. Junctions with tram tracks get the special-work layout (curves and diamonds) as rail nodes. The road surface material for the track zone is `concrete_track_slab`.

### 2.4 Buses, BRT, stops and terminals

* **Stops**: a point on the road edge at distance `s_m`, side `left|right`, with `shelter`, `bench`, `bay` (pull-in lay-by 3 m deep, 15 m long plus 15 m tapers, V). Place stops 10 to 30 m after a signalised intersection (far side) on arterials (V), skip stops within 150 m of each other on the same route (D).
* **Bus lanes**: lane attributes `psv`, `bus`, `busway` (OSM `lanes:psv`, `bus:lanes`, `busway=lane`, V tag names checked only in passing). Painted red in Toronto (V); games decide colour.
* **Terminals**: saw-tooth bays at 45 to 60 degrees, 4 m wide bays, 12 to 15 m bus length plus 6 m manoeuvre (V); a canopy; a driver building.
* **BRT stations**: median platform 40 to 60 m long, 3 to 5 m wide, with a shelter canopy and fare gates or none (V).

### 2.5 How transit interacts with the road graph

| Situation | Road edge attribute | Effect in the game |
|---|---|---|
| Shared lane with streetcar | `lanes_tram`, `tram_position: "curb"` | cars and streetcars share; cars stop behind an open streetcar door |
| Median reservation (LRT or streetcar) | `median: { "kind": "transit", "width_m": 7.0 }` | no left turns except at signals; platforms in the median |
| Bus lane | `lanes_psv: { "forward": 1, "backward": 1 }` | buses only, taxis optional |
| Busway on its own alignment | road class `busway` (new) | road graph edge closed to general traffic |
| Signal priority | junction node `control: "signals"` + `transit_priority: true` | signal plan favours transit |
| Bus stop | stop in `transit.json` with `road_edge` and `s_m` | buses pull in; a prop family for poles and shelters |

### 2.6 `network/transit.json` (schema `rwj-transit-1`)

```json
{
  "schema": "rwj-transit-1",
  "modes": ["subway", "light_rail", "tram", "bus", "trolleybus", "train", "ferry", "aerial", "funicular", "monorail"],
  "vehicles": {
    "flexity_outlook": { "mode": "tram", "length_m": 28.0, "width_m": 2.54, "height_m": 3.84, "capacity": 130, "max_kmh": 70, "doors": "right" },
    "bus_12m":         { "mode": "bus", "length_m": 12.2, "width_m": 2.6, "capacity": 70, "max_kmh": 80 },
    "ferry_island":    { "mode": "ferry", "length_m": 39.0, "beam_m": 10.0, "capacity": 915, "max_kn": 10 }
  },
  "stops": [
    { "id": "sp-1", "name": "King St West at Spadina Ave", "mode": ["tram"], "on": { "graph": "rail", "edge": 9010, "s_m": 42.0 },
      "platform": { "kind": "island", "length_m": 32, "width_m": 3.0, "side": "right" },
      "area": "sa-1", "source": "osm:node/5550001" },
    { "id": "sp-2", "name": "Jack Layton Ferry Terminal", "mode": ["ferry"], "p": [210.0, -1500.0, 75.0], "dock": "dk-1", "area": "sa-2" }
  ],
  "stop_areas": [ { "id": "sa-1", "name": "King/Spadina", "members": ["sp-1", "sp-3"] } ],
  "routes": [
    { "id": "rt-504a", "mode": "tram", "ref": "504", "name": "504A King: Dundas West to Distillery", "colour": "#ed1c24",
      "network": "TTC", "vehicle": "flexity_outlook",
      "path": [ { "graph": "rail", "edge": 9010, "dir": 1 }, { "graph": "rail", "edge": 9011, "dir": 1 } ],
      "stops": [ { "stop": "sp-1", "s_m": 42.0 }, { "stop": "sp-4", "s_m": 398.5 } ],
      "length_m": 11240.0, "service": { "headway_s": [[ "06:00", "22:00", 300 ], [ "22:00", "25:30", 600 ]] },
      "source": "osm:relation/1000001" },
    { "id": "rt-ferry-centre", "mode": "ferry", "name": "Centre Island", "vehicle": "ferry_island",
      "geometry": [[210.0, -1500.0], [260.0, -1800.0], [240.0, -2950.0]],
      "stops": [ { "stop": "sp-2", "s_m": 0 }, { "stop": "sp-9", "s_m": 1480.0 } ],
      "service": { "headway_s": [[ "08:00", "23:00", 1800 ]] } }
  ],
  "timetables": null
}
```

* A route's `path` is an ordered list of edges with a direction (1 = a to b, -1 = b to a) on the road or rail graph; `geometry` (a polyline in pack metres) is used instead for ferries, aerial lifts and anything not on a graph.
* `stops[].s_m` is distance along the whole route, so a game can move a vehicle with one number.
* `service` is optional: headway bands (a frequency model) or a pointer to explicit timetables (section 10).

### 2.7 From an OSM route relation to a drawn line and stops

A PTv2 route relation lists stops and platforms first (stop position then platform, in order), then the ways from start to end with an empty role; each direction and each variant is its own relation; `route_master` groups them [4]. The algorithm (C):

```
input: relation R (type=route, route in {train, subway, light_rail, tram, bus, trolleybus, ferry, monorail, funicular})
1. split members: stops  = members with role in {stop, stop_entry_only, stop_exit_only}
                  plats  = role in {platform, platform_entry_only, platform_exit_only}
                  ways   = members with role "" (or "forward"/"backward" in old PTv1 data)
2. chain the ways: start from the way that touches the first stop; at each step take the next listed way and
   orient it so its first node equals the previous last node; if it does not connect, search the other listed ways
   for one that does (out-of-order members are common); record a GAP if none connects
3. map each OSM way segment to pack edges: the importer keeps a table osm_way_id -> [(graph, edge_id, s_from, s_to)];
   a way that was split at junctions maps to several edges; emit path entries with dir from node order
4. gaps: try a shortest path on the same graph between the gap ends, restricted to the mode's allowed classes,
   max 2 km; mark "repaired": true; otherwise split the route into parts and warn
5. stops: for each stop (or, if missing, each platform), project onto the chained path; take the projection whose
   s_m increases monotonically (a looped route can pass a stop twice); for platforms without a stop position,
   use the nearest path point within 30 m (D)
6. ferries: if the ways are route=ferry ways over water, keep their geometry; do not map to a graph
7. copy ref, name, from, to, network, operator, colour (route_master tags fill gaps)
8. PTv1 fallback (no public_transport:version=2): stops are nodes tagged highway=bus_stop or railway=tram_stop
   anywhere within 30 m of the path, ordered by s_m
```

### 2.8 Worked case: a TTC slice of Toronto

**Area.** King Street West between Bathurst and Spadina, plus Spadina Avenue to Union Station and the Island ferry terminal (about 2.5 x 2 km).

**Overpass query** (bbox south, west, north, east [9]):

```
[out:json][timeout:180];
(
  relation["type"="route"]["route"~"^(tram|subway|bus|ferry|train|light_rail)$"](43.635,-79.410,43.655,-79.375);
  relation["type"="route_master"](43.635,-79.410,43.655,-79.375);
  nwr["public_transport"](43.635,-79.410,43.655,-79.375);
  nwr["railway"](43.635,-79.410,43.655,-79.375);
  nwr["amenity"="ferry_terminal"](43.635,-79.410,43.655,-79.375);
  way["route"="ferry"](43.60,-79.42,43.66,-79.36);
);
out geom;
```

`out geom` on a relation returns the geometry of its member ways, which is what the chaining step needs [9]. For the full routes (they leave the box), fetch the relation ids found, then re-query `relation(id:...)` with `out geom` and no bbox; clip later.

**What comes out:** `rail.json` gets the tram edges along King and Spadina (`tram`, gauge 1,495, `embedded: "road"` along King; `light_rail`-like centre reservation on Spadina with `reserved: true` [13]), the Line 1 subway edges under University and Front (`subway`, `tunnel: true`), and the Union Station rail corridor (`main_passenger`, many tracks). `transit.json` gets routes 504A/504B, 510, 509, the Line 1 directions, the ferry routes, and every stop and platform with `s_m` values. The road graph gets lane attributes on King (transit priority corridor [13]) and Spadina (median reservation). Use classes: the ferry terminal area (201), the Union Station rail corridor (182) and station (194).

**Validation for this case (D):** every 504 stop lies within 400 m of the next (TTC standard [45]) and no tram edge has a radius under 11 m [13]; the Spadina route's stops sit on island platforms in the median.
---

## 3. Ferries and water transport

### 3.1 Ferry types and real dimensions

| Type | How it works | Example and numbers | Crossing | Tag |
|---|---|---|---|---|
| Passenger island ferry | double-ended or single-ended screw ferry, foot passengers | Toronto Island fleet: Sam McBride (1939) 915 passengers, Thomas Rennie (1951) 736, William Inglis (1935) 400, Trillium (1910 paddle steamer) 955 [16]; hull lengths not given in the source, about 30 to 40 m (V) | Jack Layton terminal to Centre Island, Hanlan's Point, Ward's Island; every 30 to 45 minutes [16] | S/V |
| Small car-and-passenger ferry | double-ended, ramps at both ends | Ongiara: 220 passengers, 10 cars [16]; new Lady of the Quays: 615 passengers and 14 vehicles, or 1,300 passengers only, electric [16] | Island ferries 1 to 2 km | S |
| Shuttle over a gap | short double-ended ferry | Toronto island airport ferry: 121 m crossing in about 90 seconds [16] | 0.1 to 0.5 km | S |
| Lake car ferry | double-ended ro-ro | Wolfe Islander IV: 98 m long, 19.8 m beam, 2.7 m draft, 75 vehicles, 399 passengers, 12 knots, hybrid electric [17] | Kingston to Wolfe Island, about 20 minutes (V) | S/V |
| Free provincial ferry [ON] | double-ended car ferry | Glenora (MTO): free, every 15 minutes at peak and 30 minutes otherwise [19] | Bay of Quinte, about 1 km (V) | S/V |
| Island lake ferry [ON] | single-ended ro-ro, bow and stern doors | Pelee Island service (Leamington, Kingsville, Pelee, Sandusky); vessel dimensions not confirmed (V) | 1.5 to 2 hours (V) | V |
| Large double-ended car ferry [NA] | Washington State Ferries, double-ended with a wheelhouse at each end (V) | Olympic class: 110.4 m, 25.3 m beam, 5.5 m draft, 144 vehicles, 1,500 passengers, 17 knots, deck clearance 4.9 m [18] | 5 to 60 minutes | S/V |
| Large single-ended ferry [NA] | BC Ferries major routes | Spirit class: 167.5 m, 5 m draft, 358 cars, 2,100 passengers and crew, 19.5 knots [51] | Tsawwassen to Swartz Bay, about 95 minutes (V) | S/V |
| Cable ferry | guided (and often pulled) along cables fixed to both shores; slack cables sink so boats can pass [20] | Baynes Sound Connector (BC): 1,961 m, the longest cable ferry link, 8.5 knots, three wire ropes [20]; many small river cable ferries 20 to 40 m long (Pritzerbe ferry 22 m [20]) | 0.1 to 2 km | S |
| Reaction ferry | uses the river current; the cable angle is set by pulleys [20] | BC interior river ferries (Big Bar) [20] | 50 to 200 m | S |
| Chain or hand ferry | cranked or pulled | Saugatuck chain ferry, about 0.3 m/s, 24 passengers [20] | under 100 m | S |
| Hydrofoil, fast catamaran | high-speed passenger | 25 to 40 knots, 30 to 50 m (V) | 10 to 50 km | V |
| Water taxi | small launches, 6 to 12 m (V) | Toronto harbour taxis (V) | anywhere in a harbour | V |

### 3.2 Terminals and docks

| Element | Size and rule | Tag |
|---|---|---|
| Slip (berth for a car ferry) | a notch in the shore or a dock between fender dolphins, 5 to 10 m wider than the ferry beam, as long as the ferry plus 10 m (D) | D |
| Transfer span / linkspan (vehicle ramp) | hinged bridge from shore to the ferry deck, 20 to 40 m long, 8 to 15 m wide (one or two lanes), adjustable for water level (V) | V |
| Passenger overhead walkway | on big terminals (WSF, BC Ferries), 3 to 4 m wide at upper deck level (V) | V |
| Apron | paved area at the head of the ramp, 15 to 30 m deep (D) | D |
| Holding compound (vehicle queue) | rows of lanes 3.0 to 3.5 m wide, each 1.2 to 1.5 ferry loads long; capacity 1.5 to 3 sailings (D); WSF and BC Ferries terminals hold hundreds of cars (V) | D/V |
| Terminal building | small kiosk (5 x 8 m) for local ferries; 20 x 40 to 50 x 150 m for big terminals (V) | V |
| Passenger dock (island ferries) | pier with gates; Jack Layton terminal has four piers, Centre Island two, Hanlan's three, Ward's one [16] | S |
| Mooring dolphins and fenders | piles or cells at the slip edges, every 10 to 20 m (V) | V |
| Winter layup | ferries tie up at the main terminal in winter [16] | S |

### 3.3 Generating ferry routes

```
input: two terminals T1, T2 on water (each a dock point with an approach heading), water mask, depth (if known)
1. navigable raster: water cells with depth >= draft + 1.0 m keel clearance (D), at least half the beam + 10 m
   from shore, breakwaters, piers and marked shoals (seamark rock, wreck) (D); without depth data use distance
   to shore >= 30 m as a proxy (D)
2. path: A* on the navigable raster with 16 headings; turning radius >= 3 x vessel length (D);
   cost = length + 5 x heading change in radians x vessel length (D)
3. approach: the last 2 to 4 vessel lengths are straight and aligned with the slip (D)
4. smooth: Catmull-Rom then resample at 10 m; check clearance again
5. two-way traffic: if both directions share the path, offset each by +/- (beam + 20 m) / 2 to the right (D)
6. timing: cruise speed from the vehicle (Wolfe Islander IV 12 kn [17], Olympic 17 kn [18]), with
   acceleration and docking phases of 2 to 4 minutes each end (D); dwell (load and unload) 8 to 15 minutes for car
   ferries, 3 to 5 for passenger ferries (D)
7. schedule: headway = max(round trip time, service headway); a second vessel if the round trip exceeds the headway
```

Cable ferries skip steps 1 to 5: the route is a straight line between the two slips with a cable sag (store `cable: true`, `cables: 2` or `3`), at 1 to 8 knots.

**Turning basins (D):** a circle of diameter 1.5 to 2 times vessel length off the terminal for single-ended ships; double-ended ferries need none.

### 3.4 Harbour, canal and port structures

| Feature | Numbers and rules | OSM | Tag |
|---|---|---|---|
| Pier | raised walkway or deck over water on piles [39]; 3 to 30 m wide | `man_made=pier` way or area | S |
| Quay / wharf | vertical wall along navigable water for loading [39]; apron 15 to 30 m (Ch2, D) | `man_made=quay` | S |
| Breakwater | rubble mound of armour stone, crest 2 to 5 m above water, 10 to 40 m wide at the base (V) | `man_made=breakwater` [39] | S/V |
| Groyne | short wall at right angles to the shore, limiting sediment flow [39]; 20 to 100 m, every 50 to 200 m along a beach (V) | `man_made=groyne` | S/V |
| Lighthouse | on breakwater ends and headlands (Ch3 4.8); 10 to 30 m tall (V) | `man_made=lighthouse` + `seamark:type=light_major` [39][41] | S/V |
| Buoys and channel markers | lateral (port and starboard), cardinal, isolated danger, safe water, special purpose [41]; 200 to 1,000 m apart along a channel (D). North America uses IALA region B (red on the right returning from sea, "red right returning") (V) | `seamark:type=buoy_lateral` etc. [41] | S/V |
| Marina | floating docks with slips 3 to 5 m wide and 9 to 15 m long; fairways at least 1.5 boat lengths (Ch3 4.8) | `leisure=marina` | V |
| Boat launch (slipway) | concrete ramp at 12 to 15 percent (Ch3 4.8), 4 to 8 m wide, with a trailer parking lot | `leisure=slipway` | V |
| Canal lock (ship) | Welland Canal: 8 locks over 43.5 km, chambers 233.5 m long (Lock 8: 349.9 m) and 24.4 m wide, 8.2 m deep, each lift 13 to 15 m, total 99.5 m, twinned flight locks 4 to 6; largest ship (Seawaymax) 225.5 x 23.8 m, 8.08 m draft; about 11 hours to transit [32] | `waterway=canal` + `lock=yes`; `waterway=lock_gate` [40] | S |
| Canal lock (small craft) | Rideau and Trent-Severn: chambers about 30 to 40 m long, 9 to 10 m wide, lifts 1 to 5 m, hand-cranked gates (V) | as above | V |
| Lift bridges over canals | vertical-lift and bascule road bridges (three vertical lifts on the current Welland line [32]); the Garden City Skyway gives 35.5 m clearance [32] | `bridge:movable=*` | S |
| Drydock | 150 to 300 m long, 25 to 50 m wide, a caisson gate (V) | `waterway=dock` or `man_made=drydock` (V tag) | V |
| Container terminal | quay 300 m per berth (V); ship-to-shore cranes with 30.48 m rail span, 65 to 73 m outreach, 45 to 51 m lift height above rail [47]; container stacks 4 to 6 high in blocks behind (V); 60 to 120 ha per 1 million TEU per year (V, not confirmed) | `industrial=port`, `landuse=industrial` + cranes as `man_made=crane` | S/V |
| Bulk and grain terminal | Great Lakes elevators: concrete silo rows 30 to 40 m high, conveyor galleries to the ship (V); Hamilton and Thunder Bay are the Ontario examples (V) | `man_made=silo`, `building=silo` | V |
| Fairway | buoy-marked navigable route [40] | `waterway=fairway` | S |
| Turning point | place for vessels to turn [40] | `waterway=turning_point` + `maxlength` | S |

### 3.5 Moving traffic versus static objects

| Generated as moving (a route in `transit.json` or a spawn zone) | Generated as static (structures and props) |
|---|---|
| Scheduled ferries along their routes | Docks, slips, ramps, terminals, dolphins |
| Lake freighters along shipping lanes (`waterway=fairway` or generated lanes between ports), 1 to 6 per day on the Great Lakes per lane (V) | Lighthouses, buoys (they bob in place, animated by the game, not moved) |
| Pleasure boats in spawn zones near marinas and launches; density by season and weather (D: 0 to 30 per km2 of open water on a summer weekend near a marina) | Moored boats in marina slips (props, 60 to 90 percent occupancy in summer, 0 in winter, D) |
| Sailboats in sailing areas (`leisure=sailing` or a recipe polygon) | Container stacks, cranes (cranes may animate in place) |
| Water taxis and tour boats on harbour loops | Moored laid-up ships in winter |
| Canal traffic through locks (a lock cycle of 30 to 45 minutes, V) | Lock gates (animate in place) |

Spawn zones are entries in `transit.json` under `"spawn_zones"`: `{ "id": "sz-1", "mode": "boat_leisure", "area": [[...]], "density_per_km2": 12, "season": [5, 10], "speed_kn": [3, 20] }`.

### 3.6 OSM mapping for water transport

| OSM | Pack |
|---|---|
| `route=ferry` way | ferry route geometry in `transit.json`; `motor_vehicle=yes` or `motorcar=yes` makes it a car ferry, `foot=yes` only a passenger ferry; `duration` (hh:mm) sets cruise time; `ref`, `name`, `operator` copied |
| `route=ferry` relation | route made from its member ways (2.7 step 6) |
| `amenity=ferry_terminal` | stop with `dock`; area becomes use class 201 |
| `waterway=canal` | water polygon (if `area` or with a `water=canal` polygon) plus a centreline in `hydro/rivers.geojson` with `kind: "canal"`, flat surface per lock pound |
| `lock=yes`, `waterway=lock_gate` | structure `lock.chamber`, gates at each end; the surface steps by the lift |
| `waterway=dock` | water polygon, `kind: "dock"` |
| `waterway=fairway` | shipping lane for moving traffic |
| `harbour=yes`, `seamark:type=harbour` | marker `kind: "harbour"`; seeds port use classes nearby |
| `seamark:type=*` | props: `buoy.lateral.port`, `buoy.lateral.starboard`, `buoy.cardinal.*`, `light.major`, `light.minor`, and `marker kind: "hazard"` for rock and wreck |
| `man_made=pier/quay/breakwater/groyne/lighthouse/dolphin` | structures with those kinds |
| `leisure=marina` | use class 190 (IF11); docks inside become structures |
| `leisure=slipway` | structure `ramp.boat` |
| `industrial=port` or `landuse=port` (V tag) | use class 202 |
| `man_made=crane` inside a port | prop `crane.sts` if `crane:type=portal_crane` or near a quay edge, else `crane.generic` |

---

## 4. Air

### 4.1 Aerodrome elements

Chapter 3 section 4.7 sets runway classes (farm strip 500 to 900 m, small public 800 to 1,200 m, regional 1,200 to 1,800 m at 30 m width, large 1,800 to 3,500 m at 45 to 60 m). This section adds the parts and the airspace.

| Element | Rule (D unless tagged) | OSM [5] |
|---|---|---|
| Aerodrome area | fence line around everything; use class 183 (IF4) | `aeroway=aerodrome` (node or area), `icao`, `iata`, `ele` |
| Runway | rectangle along the centreline: length from the way, width from `width` or the class table; designation = magnetic heading / 10 rounded (e.g. 06/24) (V) | `aeroway=runway` way, `ref` "06/24" |
| Runway strip (graded and mown) | 30 to 150 m each side of the centreline by class (V); no structures | derived |
| Taxiway | 7.5 to 23 m wide (V); parallel to the runway at 90 to 190 m centre-to-centre on bigger airports (V) | `aeroway=taxiway` way |
| Apron | paved areas by the terminal and hangars | `aeroway=apron` area |
| Terminal | building | `aeroway=terminal` |
| Hangar | 15 x 15 to 60 x 80 m, door height 5 to 25 m (V) | `aeroway=hangar` or `building=hangar` |
| Control tower | 15 to 60 m (V) | `aeroway=tower` |
| Helipad | 15 to 30 m pad (Ch3) | `aeroway=helipad` |
| Windsock | one at each runway end on small fields, near mid-field on grass strips (V) | `aeroway=windsock` |
| Navigation aids | VOR, NDB, ILS antennas as small structures | `aeroway=navigationaid` |
| Fuel | `aeroway=fuel` | prop `tank.fuel_small` |

### 4.2 Runway orientation from a wind rose (seeded worlds)

1. Take the world's wind climate from the recipe as 16 direction bins with frequency and speed classes (D default for southern Ontario: prevailing W to SW, as Ch3).
2. For each candidate heading (every 10 degrees), compute the share of time the crosswind component is under the limit: 19 km/h (10 kn) for small aircraft, 24 km/h (13 kn) for code B, 37 km/h (20 kn) for code C and larger (V, ICAO-style limits not confirmed here).
3. Pick the heading with the highest share. If it is under 95 percent (the usual usability target, V), add a crosswind runway at the next best heading at least 30 degrees off.
4. Rotate to fit flat land: allow plus or minus 10 degrees to minimise earthworks; the runway longitudinal grade stays under 1 to 2 percent (V).

### 4.3 Obstacle limitation surfaces and the height cap

ICAO Annex 14 surfaces protect the airspace around a runway. The figures below come from an ICAO training deck on the classic and new surfaces [34]. Canada applies them through TP 312, which uses the ICAO method [35]; I did not read TP 312 itself.

| Surface | Numbers (code 3 and 4, precision approach) | Tag |
|---|---|---|
| Inner horizontal | 45 m above the aerodrome elevation datum, radius 4,000 m from the runway reference points | S [34] |
| Conical | rises at 5 percent from the edge of the inner horizontal surface to 100 m above it (so 2,000 m wide) | S [34] |
| Approach (precision) | inner edge 280 m wide, 60 m before the threshold; sides diverge 15 percent; 3,000 m at 2 percent, then 3,600 m at 2.5 percent, then 8,400 m level; 15 km total | S [34] |
| Take-off climb | inner edge 180 m at the end of the take-off distance; 12.5 percent divergence to 1,800 m wide; 15 km long; slope 2 percent (V for the slope) | S/V [34] |
| Transitional | from the runway strip edge and approach sides up to the inner horizontal, 14.3 percent for code 3 and 4 (V) | V |
| Small aerodromes (code 1 and 2) | inner horizontal 45 m but radius 2,000 to 2,500 m; approach slopes 4 to 5 percent (V) | V |

ICAO has adopted a **new OLS concept** (obstacle free surfaces and obstacle evaluation surfaces, grouped by aeroplane design group) with an applicability date in 2030 [34]. Use the classic surfaces above for version 1.

**Height cap raster (C).** For every cover-grid sample, compute the lowest surface above it (each surface is a plane or a cone over the pack's terrain datum, with the aerodrome elevation as datum) and write `cap_m = min over surfaces`. Write it to `limits/height_cap.u16.zlib` with the height encoding of Chapter 1 (65535 means no cap). The building generator clamps `base_m + height <= cap_m - 3 m` (D margin), and the tower and mast generator (section 5) does too. Imported OSM buildings that exceed the cap are kept (they are real) and listed in the import report.

**Flight path corridors (D).** For AeroSim, store each runway's approach and departure centrelines (15 km) in `infra/aerodromes.json` so the game can spawn arriving and departing traffic.

### 4.4 `infra/aerodromes.json`

```json
{ "schema": "rwj-aero-1",
  "aerodromes": [
    { "id": "ad-1", "name": "Hamilton (John C. Munro)", "icao": "CYHM", "ref_point": [-5200.0, -8400.0], "elev_m": 238.0,
      "code": { "number": 4, "letter": "E" }, "source": "osm:way/111",
      "runways": [ { "ref": "12/30", "thr_a": [-6100.0, -7700.0], "thr_b": [-4250.0, -9150.0], "width_m": 45, "surface": "asphalt",
                     "approach": { "12": "precision", "30": "non_precision" } } ],
      "taxiways": [ { "id": "tw-1", "pts": [[-6000.0, -7600.0], [-4300.0, -9000.0]], "width_m": 23 } ],
      "ols": { "standard": "icao_annex14_classic", "ihs_height_m": 45, "ihs_radius_m": 4000, "conical_slope": 0.05, "conical_height_m": 100 } } ] }
```

(The coordinates and elevation in this example are illustrative, not measured.)

### 4.5 OSM mapping for aeroways

`aeroway=aerodrome` to an aerodrome record plus use class 183; `runway`, `taxiway`, `taxilane`, `stopway` ways to buffered polygons in `infra/structures.geojson` (`kind` same as the tag, width from `width` else class default) and to the aerodrome record; `apron` area to a structure; `hangar`, `terminal`, `tower` to buildings (`use` = the tag value); `helipad`, `heliport` to structures and a heliport aerodrome record with no OLS (V: heliports have their own surfaces, not modelled); `windsock`, `navigationaid`, `holding_position`, `parking_position`, `gate` to props or markers; `highway_strip` to a road edge with `aeroway: "highway_strip"`; `model_runway` to a structure only [5].

---

## 5. Utility and service corridors

### 5.1 Electricity transmission

| Voltage | Corridor width | Structures | Height | Span | Tag |
|---|---|---|---|---|---|
| 115 kV [ON] | 30 to 37 m (15 to 18 m from the centreline to each edge, C from 50 to 60 ft [23]) | steel lattice or steel and wood poles (V) | 20 to 35 m (V) | 200 to 300 m (V) | S/V |
| 230 kV [ON] | about 46 m [21] | lattice towers (Ch3) or steel poles | 30 to 60 m; footprint 6 x 6 to 12 x 12 m [21] | 300 to 450 m (V, Ch3) | S/V |
| 500 kV [ON] | at least 64 m (210 ft) [22]; the Bruce to Milton double circuit took a further 53 to 61 m beside an existing corridor [25] | lattice towers, double circuit | 45 to 70 m (V) | 400 to 500 m (V) | S/V |
| Multiple lines | corridor = sum of single widths minus 10 to 20 percent shared edge (D); Toronto's big corridors carry 2 to 6 circuits (V) | | | | D |
| Underground cable | 3 to 10 m trench zone, invisible except vaults and transition stations (V) | | | | V |

Placement rules (D):

* Straight segments between angle towers; angle at most 30 to 60 degrees per tower (V); towers at local high points where possible so the span clears the ground by 7 to 12 m at mid-span (V, sag model below).
* Sag: s = w L^2 / (8 T) per span; use s = 3 to 6 percent of the span for drawing (D). Conductors attach at 60 to 80 percent of tower height (V).
* Keep 15 m clear around every tower: a Toronto rule for secondary uses in corridors [50].
* **Through forest**: clear the full corridor width; maintain shrub and meadow, no trees above 3 to 4 m (V). The drone sees a straight, pale strip with towers marching across ridges.
* **Across water**: spans up to 800 to 1,500 m with taller river-crossing towers (V); lakes are crossed by submarine cable instead (V).
* **Across roads and rail**: crossing angle at least 45 degrees (D); towers at least one tower height plus 5 m from the road or track edge (D).
* **In towns**: the corridor becomes a use class `IF6` (185) strip, often a park.

**Toronto hydro corridors as linear parks [ON].** The City leases about 485 ha of hydro corridor land for trails, meadows and recreation; secondary uses allowed by the Official Plan include parks, trails, agriculture, parking, open storage, stormwater ponds, transit facilities and garden centres; earlier licences include sports fields, splash pads, allotment gardens and playgrounds; the Meadoway turns 16 km of the Gatineau corridor into a meadow and trail park [50]. Hydro One limits stormwater ponds to two thirds of the corridor width under 115 and 230 kV lines and one third under 500 kV [24].

**Generator rule (D)**: in urban and suburban worlds, fill a hydro corridor with one secondary use per 300 to 800 m segment: trail plus meadow 50 percent, mown park with sports fields 20 percent, allotment gardens 10 percent, parking or storage 10 percent, stormwater pond (within the width limit) 10 percent. New use class **IF25 (204) Hydro corridor park** marks the park version; plain `IF6` (185) stays for rural corridors.

### 5.2 Distribution

| Item | Value | Tag |
|---|---|---|
| Wood poles | 12 to 14 m, every 40 to 60 m, along one side of most rural roads (Ch3) | V |
| Urban pole lines | 30 to 50 m spacing (Ch2) in older districts (SB1, SB2 and rural sections only; later suburbs are buried, Ch3 1.3) | V |
| Pole-top transformers | one per 3 to 8 houses in rural areas (D) | D |
| Pad-mounted transformers | green boxes every 3 to 4 lots in buried-service suburbs (Ch3) | V |
| Line voltage | 4.16 to 44 kV (V) | V |
| Shared poles | telephone and cable on the same poles, 1 to 2 m below power (V) | V |
| Street lights | on the poles where poles exist (V) | V |

### 5.3 Substations and generation

| Feature | Footprint | Placement | From the air | Tag |
|---|---|---|---|---|
| Transformer station (230/500 kV) | 1 to 5 ha (Ch3); big switching stations 10 to 30 ha (V) | where corridors meet, near load centres | fenced gravel yard, steel frames, transformers, control building | V |
| Distribution substation | 0.2 to 0.8 ha (Ch3) | every few km in towns | small fenced yard | V |
| Nuclear station | 100 to 400 ha, on a lake shore (Pickering, Darlington, Bruce are Ontario examples) (V) | lake shore, exclusion zone 1 km (V) | domes or square reactor buildings, turbine hall, switchyard, cooling water outfalls | V |
| Hydro station | dam plus powerhouse; penstocks; spillway; tailrace (Ch3 IF10) | rivers with head | concrete wall across a river, white water below | V |
| Gas-fired station | 5 to 20 ha; stacks 40 to 80 m (V) | near gas pipelines and transmission | boxy halls, tall stacks | V |
| Wind farm | see Ch3 2.9: hub 80 to 120 m, rotor 80 to 140 m, 550 m from receptors [Ch3 21] | ridges and lake-plain farmland | white turbines, gravel pads | S/V |
| Solar farm | 3 to 5 ha per MW (Ch3) | flat farmland, capped landfills | dark rows facing south (north in the southern hemisphere) | V |
| Battery storage | 0.5 to 5 ha of container rows (V) | at substations | white container rows | V |

### 5.4 Pipelines

| Item | Value | Tag |
|---|---|---|
| Regulated strip (CER, federal lines) | 30 m each side of the pipe centreline (the "prescribed area"), measured from the outermost pipe where there are several; ground disturbance over 30 cm inside it needs consent [26] | S |
| Right of way | varies with pipe size, routing and number of lines, and is usually narrower than the prescribed area [26]; 18 to 30 m for a single large line, 10 to 15 m for small lines (V) | S/V |
| Cleared width in forest | 15 to 30 m (Ch3, V), kept in grass and shrubs | V |
| Markers | yellow or orange posts at every road, rail, water crossing and fence line, and at line-of-sight intervals (V) | V |
| Valve sites | every 15 to 30 km on gas transmission (V); a small fenced pad with above-ground pipework | V |
| Compressor stations | every 60 to 150 km (V); 3 to 10 ha with buildings and coolers | V |
| Pumping stations (oil) | every 50 to 100 km (V) | V |
| Water crossings | horizontal directional drilling (invisible) or trenched with a cleared strip down both banks (V) | V |

Placement (D): straight segments, bends at least 5 degrees apart smoothed over 20 m, avoid slopes over 25 degrees across the line, follow other corridors (hydro, rail, highway) where they go the right way (corridor sharing); keep 30 m from buildings.

### 5.5 Water, sewer and stormwater

| Feature | Footprint and rule | OSM | Tag |
|---|---|---|---|
| Water tower | tank 10 to 20 m across, 30 to 50 m tall, on high ground, one per pressure zone (Ch3) | `man_made=water_tower` | V |
| Standpipe or ground reservoir | 20 to 60 m diameter (V) | `man_made=storage_tank` + `content=water`, `man_made=reservoir_covered` | V |
| Water treatment plant | 1 to 10 ha at a lake or river intake (Ch3) | `man_made=water_works` | V |
| Pumping station | 10 x 15 m building at low points (Ch3) | `man_made=pumping_station` | V |
| Watermains | under roads; only hydrants and valve boxes show (Ch2 hydrant spacing 90 to 150 m) | `man_made=pipeline` + `substance=water` (rare in OSM) | D |
| Wastewater plant | 2 to 50 ha with round clarifiers 20 to 50 m across and rectangular tanks (V) | `man_made=wastewater_plant` [39], `man_made=clarifier` | S/V |
| Sewage lagoon | Ch3 IF7 (186) | `landuse=basin` + `basin=wastewater` (V tag) | V |
| Stormwater pond | Ch3 CV5 (34); in hydro corridors limited as in 5.1 [24] | `landuse=basin` / `water=basin` / `basin=detention/retention` | S/V |
| Outfall | headwall at the shore or a ditch (Ch3) | `man_made=outfall` (V tag) | V |
| Culvert | Ch3 4.6 | `tunnel=culvert` [40] | S |
| Sewer vent | `man_made=sewer_vent` [39] | | S |

### 5.6 Telecom

| Feature | Value | OSM | Tag |
|---|---|---|---|
| Cell tower (lattice or monopole) | 40 to 90 m in farm country, every 5 to 15 km on hills (Ch3); 20 to 40 m monopoles in towns (V); 15 x 15 m fenced compound | `man_made=mast` or `tower` + `tower:type=communication` [39] | V |
| Rooftop antennas | on mid-rise and towers in cities (V) | `man_made=antenna` [39] | V |
| Broadcast mast | guyed, 150 to 600 m (V); guy anchors at 60 to 80 percent of the height out (V) | `man_made=mast` + `guy_wire` [39] | V |
| Communications tower (concrete) | the CN Tower class; landmarks | `man_made=communications_tower` [39] | S |
| Fibre routes | buried along roads and rail; only marker posts and huts | `telecom=*` (V) | V |
| Street cabinets | 1 x 0.5 x 1.5 m at lot corners (Ch2 utility box) | `man_made=street_cabinet` [39] | S |

All masts and towers obey the airport height cap (4.3) and get red obstruction lights over 90 m (V, Canadian practice not confirmed).

### 5.7 District energy, fuel and waste

| Feature | Footprint | OSM | Tag |
|---|---|---|---|
| District energy plant | 0.5 to 3 ha, a stack 30 to 60 m (V) | `power=plant` + `plant:output:heat` (V) | V |
| Gas station | Ch3 CM9 (44); canopy 20 x 30 m, 4 to 8 pumps | `amenity=fuel` | V |
| Fuel depot / tank farm | 5 to 50 ha of round tanks 15 to 60 m across in bermed cells (V) | `landuse=industrial` + `industrial=oil` / `man_made=storage_tank` | V |
| Propane yard | 0.5 to 2 ha, horizontal bullet tanks (V) | `man_made=storage_tank` + `content=gas` (V) | V |
| Landfill | Ch3 IF8 (187) | `landuse=landfill` | V |
| Transfer station | 1 to 4 ha, a tipping building and truck scale (V) | `amenity=waste_transfer_station` | V |
| Recycling depot | 0.5 to 2 ha (V) | `amenity=recycling` + `recycling_type=centre` | V |

### 5.8 Easements in the city and along roads and rail (D)

* Utility easements along rear lot lines: 3 m wide where poles run behind houses (SB1, SB2) (V).
* Road allowance utility zones: in a 20 m ROW, gas and water under one boulevard, hydro and telecom under the other (V); the pack does not draw them, but the props (hydrants, valve boxes, pedestals) follow them.
* Rail corridors carry signal and communication pole lines on older lines (Ch3 4.5); new development keeps a 30 m setback from principal main lines with a 2.5 m berm, 300 m from freight yards, under the FCM and RAC guidelines [46].

### 5.9 What a drone sees (50 to 500 m above ground)

| Feature | 50 m | 150 m | 500 m |
|---|---|---|---|
| Single-track main line | rails, sleepers, ballast colour, signals, pole line | clear double line of steel on grey ballast; ditches | a straight grey thread with cuts and fills |
| Streetcar tracks | rails in pavement, wires, poles, stops | thin bright lines in the road, wire shadow | not readable except at loops |
| Transmission line | conductors, insulators, tower lattice | towers and conductors, corridor edge | pale strip through forest, towers as dots |
| Distribution line | wires, transformers, cross-arms | pole shadows | invisible except the pole line shadow at low sun |
| Pipeline | marker posts | cleared strip | straight cutline (in forest) |
| Substation | equipment rows, insulators | fenced grey yard with frames | grey rectangle |
| Ferry | deck, cars, people | the ship and its wake | wake lines |
| Harbour | buoys, cleats, boats | piers, boats, cranes | breakwater shapes, lighthouse |
| Runway | markings, lights | the strip and taxiways | long dark rectangle |
| Water tower | text and rust | the bowl and legs | a dot with a long shadow |

### 5.10 OSM mapping for utilities

| OSM | Pack |
|---|---|
| `power=line` | `lines.json` `ln.power_transmission`, `voltage` (first value of a list), `circuits`, `cables`; towers from member nodes [3] |
| `power=minor_line` | `ln.power_distribution`; lines above 150 kV are always `power=line` [3] |
| `power=cable` | `ln.power_cable` (underground or underwater, not drawn in 3D) [3] |
| `power=tower` node | tower position on the line; `structure`, `design`, `height` if present |
| `power=pole` node | pole position (prop `pole.wood` unless `material=concrete/steel`) |
| `power=portal`, `power=terminal` | structure inside substations [3] |
| `power=substation` | structure `substation`, use class 184 (IF5) |
| `power=plant` | use class by `plant:source`: nuclear, hydro (189 IF10), gas, wind (100 EN2), solar (99 EN1) |
| `power=generator` | `generator:source=wind` to a turbine prop; `solar` to a panel area; others to structures |
| `power=transformer`, `power=switch`, `power=compensator` | props inside substations |
| `man_made=pipeline` | `lines.json` `ln.pipeline`, `substance`, `location` (`underground` default), `diameter` |
| `pipeline=marker` / `marker=*` | prop `marker.pipeline` |
| `pipeline=valve` / `substation=valve` | structure `pipeline.valve_site` |
| `man_made=water_tower`, `storage_tank`, `silo`, `reservoir_covered` | structures with `height` and `diameter` defaults (6.7) |
| `man_made=mast`, `tower`, `communications_tower`, `antenna`, `chimney` | structures (tall); `height` else defaults |
| `man_made=wastewater_plant`, `water_works`, `pumping_station` | use class 184 (IF5) with kind recorded |
| `telecom=*` | `ln.telecom` (not drawn in 3D) and `man_made=street_cabinet` props |
| `landuse=landfill` | use class 187 (IF8) |
| `amenity=waste_transfer_station` | use class 205 (IF26, new) |
---

## 6. The complete OSM-to-pack translation

### 6.1 The import pipeline

```
fetch        Overpass (areas up to about 20 km) or a Geofabrik extract cut with osmium     -> osm/raw/*.osm.pbf or *.json
normalise    one in-memory store of nodes, ways, relations; lifecycle prefixes dropped; units parsed (6.7)
assemble     closed ways to polygons; multipolygon and boundary relations to (multi)polygons (6.3);
             route relations to ordered member lists (2.7)
classify     run osm_rules.json on every element: highest-priority match wins per target layer (Appendix A)
resolve      overlaps and conflicts (6.5); layers and vertical order (6.4)
project      lon/lat to pack metres with the world's local Transverse Mercator (Chapter 1 2.5)
clip         to the world extent plus a 200 m apron for graphs, exact extent for areas (6.6)
simplify     per layer tolerance (6.6)
build        graphs (roads, rail), transit routes, structures, buildings, lines, rasters (cover, use, water mask)
grade        Chapter 1 stage F with the real DEM: roads and rail profiles, bridges, building pads
check        quality checks with automatic fixes (6.9); write osm/import-report.json
attribute    ATTRIBUTION.txt and world.json attribution entries (Chapter 1 2.10, 3.3)
```

**What existing tools teach.** OSM2World (Java, LGPL) turns OSM into glTF and OBJ and follows the Simple 3D Buildings scheme, but its elevation handling is experimental and off by default, so it flattens the world [42]. Arnis (Rust, Apache-2.0) builds Minecraft worlds from OSM plus real elevation, takes a bounding box, and offers modes that drop buildings or terrain [43]. Neither publishes default widths or heights we could adopt, and neither keeps a routable graph or transit routes. The lesson taken: keep the semantic import (this chapter) separate from meshing (each game), and treat elevation as a first-class input from the start, which Chapter 1's DEM import already does.

### 6.2 Fetching

**Overpass, bounding box** (south, west, north, east [9]). One query per layer group keeps each response under the server's memory limit and lets the cache re-use groups. The full-world query for a small area:

```
[out:json][timeout:300][maxsize:1073741824][bbox:43.240,-79.900,43.270,-79.850];
(
  way["highway"];
  node["highway"~"^(traffic_signals|stop|give_way|crossing|bus_stop|street_lamp|turning_circle|mini_roundabout|motorway_junction)$"];
  nwr["railway"];
  nwr["public_transport"];
  relation["type"~"^(route|route_master)$"];
  nwr["aeroway"];
  nwr["power"];
  nwr["man_made"];
  nwr["building"];
  nwr["building:part"];
  nwr["landuse"];
  nwr["natural"];
  nwr["water"];
  nwr["waterway"];
  nwr["leisure"];
  nwr["amenity"];
  nwr["shop"];
  nwr["tourism"];
  nwr["historic"];
  nwr["barrier"];
  nwr["place"];
  nwr["boundary"="administrative"]["admin_level"~"^(6|8|10)$"];
  nwr["seamark:type"];
  nwr["harbour"];
  nwr["route"="ferry"];
  nwr["pipeline"];
  nwr["telecom"];
  nwr["military"];
);
out geom qt;
```

Notes: the global `[bbox:...]` setting applies the box to every statement [9]; `out geom` returns coordinates inline so no second pass is needed; `qt` sorts output by quadtile, which is faster [9]. Relations that extend beyond the box come back with all member geometry (the importer clips them). For a big multipolygon (a lake, a forest) this can be large; that is expected.

**Overpass, polygon** (`poly:` takes "lat lon lat lon ..." pairs [9]; simplify the polygon to under about 100 vertices first, [9] advises simplifying):

```
[out:json][timeout:300];
(
  way["highway"](poly:"43.2400 -79.9000 43.2700 -79.9000 43.2750 -79.8700 43.2600 -79.8450 43.2400 -79.8500");
  nwr["building"](poly:"43.2400 -79.9000 43.2700 -79.9000 43.2750 -79.8700 43.2600 -79.8450 43.2400 -79.8500");
  nwr["landuse"](poly:"43.2400 -79.9000 43.2700 -79.9000 43.2750 -79.8700 43.2600 -79.8450 43.2400 -79.8500");
);
out geom qt;
```

**Overpass, named area** (for a whole city): `area["name"="Hamilton"]["boundary"="administrative"]["admin_level"="6"]->.a; nwr["building"](area.a); out geom qt;` (area ids are relation ids plus 3,600,000,000 [9]; the admin level for Hamilton is a guess, V).

**Be polite** (Chapter 1 [30]): one query at a time, 30 s wait after a 429, cache by query hash.

**Large areas: Geofabrik plus osmium.** The Ontario extract is 984 MB as `.osm.pbf` (October 2026), with daily builds and `.osc.gz` change files [12]. Cut and filter:

```
osmium extract -s smart -S types=multipolygon,route -b -80.25,43.05,-79.60,43.47 ontario-latest.osm.pbf -o hamilton.osm.pbf
osmium tags-filter -o hamilton-wb.osm.pbf hamilton.osm.pbf -e wb-filter.txt
```

`-b` takes LONG1,LAT1,LONG2,LAT2 [11]. The `smart` strategy (three passes) makes multipolygon relations complete; `-S types=` can add `route` so transit relations are complete too [11]. The filter file (one expression per line, `#` comments [10]):

```
# wb-filter.txt : keep what the world builder reads
nwr/highway
nwr/railway
nwr/public_transport
r/type=route,route_master,multipolygon,boundary
nwr/building
nwr/building:part
nwr/landuse
nwr/natural
nwr/water
nwr/waterway
nwr/leisure
nwr/amenity
nwr/shop
nwr/tourism
nwr/historic
nwr/barrier
nwr/aeroway
nwr/power
nwr/man_made
nwr/place
nwr/seamark:type
nwr/route
nwr/pipeline
nwr/telecom
nwr/military
```

Without `-R`, osmium adds the nodes and members the matches reference [10], which is what we want. Osmium is optional (it may need conda or OSGeo4W on Windows, Chapter 1); a pure TypeScript PBF reader can do the same filter more slowly.

**Formats.**

| Format | Size vs PBF | Read speed | Use |
|---|---|---|---|
| `.osm.pbf` (protobuf blocks) | 1x | fastest; streamable | Geofabrik extracts, cached imports |
| `.osm` XML | about 10 to 15x (V) | slow | avoid |
| Overpass JSON with `out geom` | about 8 to 15x (V) | fast to parse in JS; geometry inline | small areas, the studio |
| GeoJSON sequence (`osmium export`) | about 10x (V) | fast | debugging in QGIS |

**Size and speed estimates (C and V, to be measured at gate P4).** Hamilton (about 1,100 km2, V) holds perhaps 3 to 4 percent of Ontario's data volume (my guess from population share, V), so a filtered `hamilton.osm.pbf` is about 25 to 40 MB and an Overpass JSON of the same content about 250 to 500 MB. That is too big for one Overpass request (default maxsize 512 MB [9]): use the extract route for a whole city, Overpass for 2 to 10 km boxes. A 4 km box in central Hamilton is about 10 to 40 MB of JSON (V). Osmium cuts a box out of the 984 MB Ontario file in about 30 to 90 s on a laptop (V). The TypeScript import of a city (parse, assemble, classify, project) should take 30 to 120 s and 1 to 2 GB of memory (estimate).

**Caching and incremental updates (D).**

* Cache key = sha256 of (query text or extract name + filter + bbox). Responses are stored in `osm/raw/` with the retrieval timestamp; rebuilds never re-query unless the user presses "Refresh OSM".
* For extract-based imports, keep the cut file and apply Geofabrik's daily `.osc.gz` change files with `osmium apply-changes` (V), then re-cut.
* Incremental rebuild: the importer hashes each output layer's input element set; only layers whose hash changes are rebuilt (Chapter 1's stage graph).
* Manual edits on top of OSM are kept in the project as a separate **patch layer** keyed by OSM id (`osm:way/123 -> {class: "local"}`), so a refresh re-applies them; this also keeps Robert's own data out of the ODbL layer (Chapter 1 3.3).

### 6.3 Geometry assembly

**Closed ways as areas.** A closed way is an area if it has an area key (`building`, `landuse`, `natural` except `coastline`, `cliff`, `tree_row`, `ridge`, `arete`; `leisure`, `amenity`, `aeroway=apron/helipad`, `man_made=pier` only with `area=yes`, `highway` only with `area=yes` or `highway=platform/pedestrian` with `area=yes`, `railway=platform`, `power=substation/plant`, `water`, `waterway=dock/boatyard/dam`, `place`), or `area=yes`. `area=no` forces a line. Closed `highway`, `barrier`, `waterway`, `railway`, `power=line` ways are lines (a roundabout, a fence round a field) unless `area=yes` (C, following common renderer rules, V).

**Multipolygons** [8]: tags live on the relation (old-style data before 2017 may carry them on the outer way; accept both, prefer the relation). Assembly:

```
1. collect member ways with role outer, inner (empty role: treat as outer, warn)
2. build rings: start with any closed way as its own ring; join open ways end to end (direction and member
   order do not matter [8]); an endpoint must be shared by exactly two open ways [8]
3. if a ring cannot close: try snapping endpoints within 1 m (D); else drop the relation and log it
4. classify rings by containment (point-in-polygon of one vertex), not by role, when roles are wrong;
   nested rings alternate outer/inner by depth
5. touching inner rings are merged into one hole [8]
6. inner ways that carry their own tags (a lake in a forest) are also emitted as their own feature [8]
7. output: one MultiPolygon per relation, outer rings counter-clockwise and inner clockwise (Chapter 1 2.11)
```

**Boundary relations** (`type=boundary`) assemble the same way. **Building relations** (`type=building`, roles `outline` and `part`) group parts with their outline [6]. **Route relations** are handled in 2.7. **Site and stop_area relations** group objects (a station's platforms and entrances) and become `stop_areas` or a `site` id on structures.

### 6.4 Bridges, tunnels, layers and vertical order

`layer` is a relative ordering for crossing objects only; it says nothing about height, and a negative layer does not mean underground (`location=underground` does) [7]. The importer therefore computes heights itself:

```
for each road or rail edge:
  if bridge=*:        deck z = max(terrain under the span ends, profile) and clearance >= the class rule
                      over whatever it crosses (5.3 m over roads, 7.0 m over rail, navigable clearance over water);
                      layer only breaks ties between two bridges at one crossing (higher layer above)
  elif tunnel=* or covered=yes:  z from the profile; tunnel=culvert applies to waterways only [40]
                      underground depth = max(6 m, 3 m per unit of -layer) (D) for transit tunnels without depth data
  elif location=underground or level < 0: underground, not drawn on the surface
  else:               at grade (graded to the terrain by Chapter 1 stage F)
crossing rule: two ways that cross without sharing a node must differ in bridge/tunnel/layer; if they do not,
               it is a data error (6.9 check Q5)
draw order for 2D and default 3D order [7]: underground < landcover/landuse/natural < waterways < highways and
               railways < man_made and buildings < bridges and overhead (power lines)
```

`layer` on landuse and natural is ignored [7]. `level` (floors inside buildings) is ignored by the world builder except for `highway=corridor` and indoor features, which are skipped.

**Embankment and cutting**: `embankment=yes` and `cutting=yes` on roads and rail tell the grader to expect fill or cut; they do not move the geometry. `man_made=embankment` and `man_made=dyke` lines become terrain constraints (a ridge line of 1 to 4 m, D).

### 6.5 Duplicates, overlaps and tag conflicts

**Landuse and natural overlap.** OSM layers land use (`landuse=*`) and land cover (`natural=*`, `landuse=forest`, `leisure=park`) freely. The pack separates them already: **cover** comes from cover-type tags, **use** from use-type tags. Rules (D):

| Situation | Cover raster | Use raster |
|---|---|---|
| `landuse=residential` with `natural=wood` patches inside | wood (10, 11 or 12) where the wood polygon is, else built-up low density (13) | residential use everywhere in the polygon |
| `leisure=park` containing `natural=water` | water (1) where water | park use (33) outside water; water mask from the water polygon |
| `landuse=forest` and `natural=wood` overlapping | same cover | `landuse=forest` sets managed forest use (115 plantation if `leaf_type` and rows, else 111) |
| `landuse=farmland` overlapping `landuse=meadow` | smaller polygon wins | smaller polygon wins |
| Two polygons of the same class | union | union |
| Any area overlapping `natural=water` or `waterway=riverbank` | water wins for cover | use kept (a marina basin is still port use) |

**Priority rule for rasterising (C).** When two area features compete for a cell in the same raster, the winner is the one with the higher rule `priority` (Appendix A); ties go to the **smaller area** (a park inside a residential area wins), then to the newer OSM version. Priorities run 0 to 100: water 95, buildings 90 (cover only, as built-up dense), roads and rail ROW 85 (cover 14 under the paved width), wetland 70, specific leisure 60, natural cover 50, specific landuse 40, generic landuse 20, boundaries 0.

**Duplicates (D).**

* Two ways with the same class sharing over 90 percent of their length within 1 m: keep the one with more tags, merge names.
* A node POI inside an area with the same main tag (an `amenity=school` node inside an `amenity=school` area): drop the node, copy its tags to the area.
* Building drawn twice (outline plus an identical part): treat as outline with one part.
* `building=*` plus `building:part=*` overlap: parts render, outline does not [6].

**Tag conflicts (D).** Resolve in this order: explicit `area=*` beats the area-key list; lifecycle prefixes (`disused:`, `abandoned:`, `demolished:`, `razed:`, `construction:`, `proposed:`) hide the main tag; `highway=construction` + `construction=primary` builds a `primary` only if the recipe asks for planned features; conflicting numbers (`lanes=2` and `width=20`) trust `width` for geometry and `lanes` for markings; `oneway=-1` reverses the way; unknown values fall back to the key's generic rule with a warning.

### 6.6 Clip and simplify

* **Clip** areas exactly to the world extent (Sutherland-Hodgman or a robust polygon clipper); **lines** in graphs are clipped at the extent plus a 200 m apron and the cut ends become `kind: "edge"` nodes so routes can leave the world (vehicles despawn there).
* **Simplify** (Douglas-Peucker on projected metres, D): roads and rail 0.25 m (keep every junction node and every node shared with another way); building footprints 0.1 m and never below 4 vertices; landuse and natural 1.0 m; water shorelines 0.5 m; coastline 1.0 m; power lines 0 (keep every tower).
* **Densify** long straight road and rail segments to a 5 m spacing before grading (Chapter 1 4.8 samples every 2 to 5 m).

### 6.7 Defaults when tags are missing

**Roads.** The `highway=*` values and their geometry types follow the OSM key page [33]. OSM `width` is the carriageway kerb to kerb [44]. If missing, width = lanes x lane width + paved shoulders. Lane counts are per way: a dual carriageway is two oneway ways.

| highway | Pack class (Ch1/Ch2/Ch3) | hierarchy | lanes default (two-way / oneway) | lane width (m) | paved shoulder (m, each side) | row_m default | maxspeed default [ON] |
|---|---|---|---|---|---|---|---|
| motorway | motorway | expressway | 4 / 2 | 3.75 | 3.0 outside, 1.0 inside (Ch3) | 90 (rural), 60 (urban) (Ch3) | 100 (V) |
| motorway_link | motorway_link | expressway | 1 (oneway) | 4.5 (Ch3) | 2.5 / 1.0 | n/a | 60 to 80 |
| trunk | trunk | arterial_major | 2 / 2 | 3.65 | 2.5 rural (Ch3) | 36 | 80 (rural, Ontario default [52]) |
| primary | primary | arterial_major | 4 urban, 2 rural / 2 | 3.5 | 0 urban, 1.5 rural | 30 to 36 (Ch3) | 50 urban, 80 rural [52] |
| secondary | secondary | arterial_minor | 2 / 2 | 3.5 | 0 urban, 1.0 rural | 26 to 30 | 50 / 80 |
| tertiary | tertiary | collector | 2 / 1 | 3.3 | 0 / 0.5 | 23 to 26 | 50 / 80 |
| unclassified | unclassified | rural_paved | 2 / 1 | 3.0 | 0.5 gravel | 20.1 (Ch3 survey allowance) | 80 rural |
| residential | residential | local | 2 / 1 | 3.0 (8 to 8.5 m pavement incl. parking, Ch3) | 0 | 20 | 50 (40 where posted) |
| living_street | residential (`living: true`) | local | 1 / 1 | 3.0 | 0 | 15 | 20 |
| service | service (`service` subtype: driveway, alley, parking_aisle, drive-through) | lane / drive | 1 | 3.0 to 4.5 (alley 6 m pavement, Ch3) | 0 | 6 to 8 | 20 |
| track | track (`tracktype` grade1 to grade5 to surface) | track | 1 | 3.5 | 0 | 4 to 5 | n/a |
| busway | busway (new) | arterial_minor | 2 | 3.5 | 0 | 10 to 15 | 50 |
| bus_guideway | busway (`guided: true`) | arterial_minor | 2 | 3.0 | 0 | 10 | 70 |
| pedestrian | path (`path_kind: "pedestrian"`, area if `area=yes`) | n/a | 0 | width 6 (D) | n/a | n/a | n/a |
| footway | path (`footway`, `footway=sidewalk/crossing` as sidewalk geometry) | n/a | 0 | width 1.8 (D) | | | |
| cycleway | path (`cycleway`) | | 0 | width 3.0 two-way, 1.8 one-way (D) | | | |
| path / bridleway | path | | 0 | 1.5 / 2.5 (D) | | | |
| steps | path (`steps`, `step_count`) | | 0 | 2.0 (D) | | | |
| raceway | service (`raceway: true`) | | | 12 (D) | | | |
| road (unknown) | residential (warn) | local | 2 | 3.0 | | | |
| construction / proposed | skipped unless `include_lifecycle` | | | | | | |

Other road attributes copied straight through: `oneway` (`yes`, `-1`, `no`; motorways and roundabouts imply oneway), `lanes`, `lanes:forward/backward`, `turn:lanes`, `surface` (asphalt, concrete, paving_stones, sett, gravel, compacted, unpaved, ground, dirt, grass), `smoothness`, `lit`, `sidewalk` (`both`, `left`, `right`, `no`, `separate`), `cycleway` and `cycleway:left/right` (`lane`, `track`, `shared_lane`, `share_busway`), `parking:left/right` and `parking:both`, `access`, `motor_vehicle`, `psv`, `bus`, `hgv`, `maxheight`, `maxweight`, `junction=roundabout`, `bridge`, `tunnel`, `layer`, `name`, `ref`. Node tags become junction controls: `highway=traffic_signals`, `stop`, `give_way`, `mini_roundabout`, `crossing` (with `crossing=marked/traffic_signals/uncontrolled`), `turning_circle`, `turning_loop`, `motorway_junction` (exit number in `ref`).

**Buildings.** Overture names as in Chapter 1 2.8 (`height`, `min_height`, `num_floors`, `roof_shape`, `roof_height`). Order of evidence (Chapter 1 3.4, extended):

```
height = OSM height (strip units; "15 m", "50'") 
      or building:levels x storey_h(type) + roof part
      or Overture height / Microsoft ML height (if those layers were imported)
      or type default (table below)
roof part = roof:height, else roof:levels x 2.5 m, else from roof:angle and the footprint short side,
            else 0 for flat and 0.35 x short side x tan(35 deg) for gabled/hipped defaults (D)
min_height = min_height, else building:min_level x storey_h, else 0
storey_h(type): residential 3.0, generic (type unknown) 3.2 (Chapter 1), commercial and office 3.8, retail ground
                floor 4.5 then 3.5, industrial and warehouse 6.0, school 4.0, church nave 8.0 (D except Ch1's 3.2)
roof_shape = roof:shape (Simple 3D Buildings vocabulary [6]) else by type: house/detached/semidetached/terrace in
             [ON] gabled (50 percent) or hipped (50 percent) by hash; apartments/commercial/industrial/retail flat;
             barn gambrel (30 percent) or gabled; church gabled; garage/shed gabled or skillion
parts: when building:part exists, render parts only, outline is for 2D [6]; each part uses its own tags
```

Type values follow the OSM `building=*` list [55].

| building= | levels default | height default (m) | roof default | use |
|---|---|---|---|---|
| house, detached, semidetached_house, terrace, residential (small, under 200 m2) | 2 | 8.5 (incl. roof) | gabled/hipped | residential |
| bungalow | 1 | 5.5 | hipped | residential |
| apartments, residential (over 400 m2) | 4 (6 in districts tagged `downtown_tower` or `midrise_avenue`) | levels x 3.0 | flat | residential |
| commercial, retail, supermarket | 1 | 6 | flat | commercial |
| office | 4 | levels x 3.8 | flat | office |
| industrial, warehouse | 1 | 9 | flat | industrial |
| school, college, university, hospital | 2 / 3 / 4 / 5 | levels x 4.0 | flat | civic |
| church, cathedral, chapel, mosque, synagogue, temple | 1 | 12 (spire extra if `tower` part) | gabled | worship |
| train_station, transportation | 1 | 8 | flat or gabled | transport |
| garage, garages, carport | 1 | 3 (carport min_height 0, open sides) | flat or skillion | ancillary |
| shed, hut | 1 | 2.8 | gabled or skillion | ancillary |
| barn, farm_auxiliary, cowshed, stable | 1 | 9 | gambrel or gabled | farm |
| greenhouse | 1 | 4 | gabled glass | farm |
| hangar | 1 | 12 | round or flat | transport |
| silo, storage_tank, water_tower | n/a | 25 / 12 / 40 | dome or flat | structure |
| roof (canopy) | n/a | 5, `min_height` 4 | flat | canopy |
| grandstand, stadium | 2 | 15 | flat | sports |
| ruins | n/a | 3, no roof | none | discovery |
| yes (unknown) | 1 if under 60 m2, 2 if under 500 m2, else 3 | levels x 3.2 | flat over 300 m2, else gabled | by surrounding land use |

**Clamps (D):** heights over 400 m are capped and flagged (6.9 Q8); `building:levels` over 120 is ignored; footprints under 4 m2 are dropped unless tagged as kiosk or similar.

**Other defaults (D):** `natural=tree_row` spacing 6 m; `natural=tree` height 12 m (broadleaf) or 15 m (conifer, `leaf_type=needleleaved`); `barrier=fence` 1.5 m, `wall` 2.0 m, `hedge` 1.5 m, `retaining_wall` 1.5 m, `guard_rail` 0.8 m, `city_wall` 6 m, `gate` 1.5 m; `waterway=stream` width 2 m, `river` 15 m, `canal` 15 m, `ditch` and `drain` 1.5 m when untagged; `man_made=mast` 40 m, `tower` 25 m, `chimney` 40 m, `communications_tower` 100 m, `water_tower` 40 m, `lighthouse` 15 m, `silo` 25 m, `storage_tank` 12 m; `power=tower` 45 m on lines of 230 kV or more, 30 m at 115 kV, 25 m below; `power=pole` 12 m.

### 6.8 Translation tables by group

The program-ready version is Appendix A. This section explains the groups and the decisions that are not obvious.

**highway**: section 6.7. Paths and sidewalks drawn as separate ways (`footway=sidewalk`) become sidewalk geometry tied to the nearest parallel road edge (within 15 m, D), not separate graph edges, unless `sidewalk=separate` on the road says they are the official sidewalks; they always stay in the walking graph.

**railway**: section 1.10. **routes**: section 2.7. **aeroway**: 4.5. **power, pipelines, telecom**: 5.10. **water transport**: 3.6.

**waterway**: `river`, `stream`, `tidal_channel`, `canal`, `drain`, `ditch` become river reaches in `hydro/rivers.geojson` (Chapter 1 2.6) with `kind` and width (tag or default); the DEM-derived drainage network (Chapter 1 stage D) is snapped to them: OSM centrelines win inside 30 m (D). `dam`, `weir`, `waterfall`, `rapids`, `lock_gate`, `sluice_gate` become nodes or structures on the reach [40]; `tunnel=culvert` marks a culvert; `intermittent=yes` sets `seasonal: true`.

**natural and water**: `natural=water` plus `water=lake/pond/reservoir/river/canal/basin/lagoon/oxbow/wastewater/stream_pool` to water polygons (`kind` from `water`); `natural=coastline` assembled into land and sea polygons (ways run with land on the left, V) and on the Great Lakes treated as `kind: "lake"` with the lake's surface elevation (Lake Ontario about 74 to 75 m, Lake Erie about 174 m, V); `natural=wetland` with `wetland=marsh/swamp/bog/fen/reedbed/wet_meadow` to cover 2 and use 140 to 144 or 118; `natural=wood` to cover 10/11/12 by `leaf_type`; `natural=scrub/heath` to 9; `grassland` to 6; `beach/sand/dune` to 5 (use 160); `bare_rock` to 3; `scree/shingle` to 4; `glacier` to 15; `cliff` (a line, cliff face on the left of the way direction, V) to a cliff break line feeding Chapter 2's cliff pipeline; `ridge`, `arete`, `valley` (lines) to soft terrain constraints for drawn or DEM-light worlds; `peak`, `saddle`, `volcano` (nodes with `ele`) to spot heights and markers; `cave_entrance`, `spring`, `sinkhole` to discovery markers (Chapter 3 section 5); `tree`, `tree_row` to props.

**landuse**: to use classes (Appendix A): `residential` to the Chapter 2 district picked by building density and street pattern inside the polygon (6.8.1); `commercial` and `retail` to `CM1` to `CM3` by size or Chapter 2 `strip_commercial`/`main_street`; `industrial` to `IN1` to `IN3` (by `industrial=*`); `farmland` to `AG` classes by `crop` (corn, soybean, wheat, hay) else `AG1` to `AG4` by a seeded rotation; `meadow` to `AG4` or `NT2`; `orchard`, `vineyard`, `greenhouse_horticulture`, `farmyard` to `AG6`, `AG7`, `AG8`, `FM1`; `forest` to `FS` classes; `quarry` to `EX2`, `landfill` to `IF8`, `cemetery` to `CV6`, `religious` to `CV2`, `railway` to `IF3`, `military` to a new military class, `construction` and `brownfield` to bare soil, `grass` to cover 7, `recreation_ground` to `CV4`, `allotments` to a new class, `basin` to `CV5` or `IF7` by `basin=*`, `reservoir` to water.

**leisure**: `park` to `CV4`, `pitch` to `CV4` with a sports-field prop by `sport`, `playground`, `garden`, `golf_course` (`RC1`), `marina` (`IF11`), `slipway`, `nature_reserve` (no use change; a `protected: true` flag that blocks discoveries of the "abandoned" kind), `stadium`, `sports_centre`, `track`, `swimming_pool`, `dog_park`, `picnic_table`, `firepit`, `campsite` (`RC2`).

**amenity**: areas become use classes (`school`, `college`, `university` to `CV1` or campus; `hospital` to a civic campus class; `place_of_worship` to `CV2`; `parking` to a parking structure or surface lot polygon with `parking=surface/multi-storey/underground`; `fuel` to `CM9`; `grave_yard` to `CV6`; `ferry_terminal` to `IF22`; `bus_station` to `IF19`); nodes become POI markers with a semantic `poi` value for games (the full `amenity=*` value list is long; the importer keeps the raw value and maps about 40 common ones in Appendix A, others to `poi.generic`).

**shop and tourism**: nodes and areas become POI markers (`poi.shop.<value>`, `poi.tourism.<value>`); a shop node inside a building sets the building's ground-floor `use` to retail. `tourism=camp_site`, `caravan_site` to `RC2`; `tourism=attraction`, `viewpoint` to discovery or POI markers.

**barrier**: lines to `lines.json` fences and walls with heights (6.7); nodes (`gate`, `bollard`, `lift_gate`, `stile`, `cattle_grid`, `kerb`) to props and to access restrictions on the road edge.

**man_made**: Appendix A; tall structures in 5.6, water features in 5.5, harbour features in 3.4, `cutline` to `ln.cutline_seismic` (Ch3), `embankment` and `dyke` to terrain constraints, `bridge` (area) to the bridge outline used to size the deck, `works` to `IN3`, `clearcut` to `FS7`.

**place and boundary**: `place=city/town/village/hamlet/isolated_dwelling/neighbourhood/suburb/quarter/locality/island/islet/square` nodes and areas seed settlement names and grades for Chapter 2's hierarchy (city to the top grade, town, village, hamlet to `HM1`), each with `population` when tagged; `boundary=administrative` relations (admin levels 6 to 10) become `markers.json` regions with names, used for labels and for the township grid's bearing (Ch3 1.1).

**addresses**: `addr:housenumber`, `addr:street`, `addr:unit` copied onto buildings (and onto the nearest building for address nodes within 5 m, D); `addr:interpolation` ways ignored.

**elevation**: `ele` on peaks, saddles and aerodromes become spot-height constraints only when the world has no DEM (drawn or seeded worlds with an OSM street layer); otherwise they are checks (6.9 Q12). Contour lines from OSM (`contour=elevation`, rare) are ignored in favour of the DEM.

**6.8.1 Residential polygon to Chapter 2 district (C).** Inside each `landuse=residential` polygon compute: building count per ha, mean footprint, share of `apartments`, street segment count per km2 and the share of culs-de-sac (dead-end edges). Then: apartments share over 50 percent and mean levels over 8 to `SB7`/`downtown_tower`; mean footprint 55 to 90 m2 on a grid with lanes to `SB1`/`suburb_inner`; cul-de-sac share over 20 percent to `SB2`/`SB3` (era by mean footprint: under 160 m2 is SB2); lots over 0.4 ha to `SB4`; else `SB3`. Thresholds are (D), tuned on Hamilton.

### 6.9 Quality checks and automatic fixes

| # | Check | Detection | Automatic fix | Report level |
|---|---|---|---|---|
| Q1 | Disconnected road islands | connected components of the drivable road graph; any component under 5 percent of total length and not touching the world edge | snap dangling ends to the nearest road within 5 m (D); otherwise keep and mark `island: true` (ferry docks and private estates are real islands) | warning |
| Q2 | Dangling ends near a road | end node within 2 m of another edge but not on it | split the other edge and connect | fix |
| Q3 | Roads crossing water without a bridge | road edge intersects a water polygon or river reach and has no `bridge`, `tunnel`, `ford` | if the crossing is under 3 m wide and the road is minor: `ford: true` (if `ford` absent) or culvert; else mark `bridge: true` with `inferred: true` | fix + warning |
| Q4 | Roads through buildings | road centreline inside a building footprint for more than 2 m, not `tunnel=building_passage` or `covered=yes` | mark `tunnel: "building_passage"` if the building has `min_height` or is over 2 storeys; else shrink nothing, report | warning |
| Q5 | Crossing ways without a shared node and equal layer | segment intersection of two road or rail ways with the same bridge/tunnel/layer state | if one is a footway: insert a crossing node; if both are roads: insert a junction; if one is rail: insert a level crossing node for minor roads, else assume the bigger road is a bridge (`inferred`) | fix + warning |
| Q6 | Buildings overlapping roads | footprint intersects the carriageway buffer by more than 1 m2 | clip the building by the carriageway if under 10 percent of its area; else keep and report (often road width is wrong: reduce road width to fit, never under 2.5 m per lane) | fix + warning |
| Q7 | Overlapping buildings | two footprints overlapping more than 5 percent | if one is inside the other: make it a part; else keep the taller one's overlap | fix |
| Q8 | Building heights over 400 m | parsed height over 400 m (Canada's tallest building is under 400 m, V) | treat as feet if `height / 3.28` is plausible for the levels; else fall back to levels or type default | fix + warning |
| Q9 | Zero-length or degenerate ways | ways with under 2 distinct nodes, or length under 0.1 m; areas under 3 distinct vertices | drop | fix |
| Q10 | Self-intersecting polygons | ring validity check | repair with a buffer-zero or ring split; drop if area under 1 m2 | fix |
| Q11 | Unclosed multipolygons | assembly failure (6.3) | snap within 1 m; else drop and report the relation id | warning |
| Q12 | Elevation conflicts | `ele` tag differs from the DEM by over 15 m at a peak or aerodrome | trust the DEM, report | info |
| Q13 | Rail too steep or too sharp for its class | graded rail edge over class grade or under class radius | downgrade class (main to branch to spur) if the data is real; never re-route real data | warning |
| Q14 | Tram not near a road | `tram` edge over 15 m from any road for more than 100 m | set `embedded: null` (own right of way) | fix |
| Q15 | Route relation gaps | 2.7 step 4 fails | split the route into parts | warning |
| Q16 | Stops off their route | stop over 30 m from the chained path | drop from the route, keep the stop | warning |
| Q17 | Power line without towers | `power=line` with no `power=tower/pole` nodes | generate towers at the class span (5.1) on straight segments and at every bend | fix |
| Q18 | Water polygons not matching rivers | river centreline outside its riverbank polygon for over 50 percent of length | trust the polygon, re-centre the line | fix |
| Q19 | Landuse gaps | cells with no use after rasterising, inside settlement boundaries | fill by majority of 8 neighbours within 50 m; else leave 0 | fix |
| Q20 | Structures above the airport height cap | top over `height_cap` | keep real OSM data, report; generated objects are clamped | info |
| Q21 | Coastline errors | coastline rings not closed after clipping | close along the world edge with water on the coastline's right-hand side (V) | fix |
| Q22 | Unknown tags | elements matched by no rule | count by key=value in the report, top 50 listed for rule writing | info |

The import report (`osm/import-report.json`) lists counts per rule, every fix with the OSM id, and every warning, so Robert can fix the real data upstream in OSM where it is wrong.

---

## 7. Drawn-map equivalent (2D editor)

### 7.1 Symbols and colours

These extend the Chapter 3 `lines.json` colours (kept unchanged) and Chapter 1's 2D view. All colours are placeholders that must pass Robert's colour-blindness audit; to help that, every class also has a **distinct line pattern**, so no class is told apart by colour alone.

| Class | Colour | Pattern in 2D | Width on screen | Notes |
|---|---|---|---|---|
| `main_freight`, `main_passenger` | #3b3b3b (Ch3 ln.rail_main) | solid with cross ticks every 12 px | 3 px + 1 px per extra track | tick count shows tracks |
| `branch`, `short_line` | #555555 (Ch3) | solid with ticks every 20 px | 2 px | |
| `siding`, `yard`, `industrial_lead`, `spur` | #777777 (Ch3) | thin solid | 1 px | |
| `abandoned` | #8f7f6f (Ch3) | dashed 6-4 | 2 px | rail trail overlay if a path is present |
| `disused` | #8f7f6f | solid with sparse ticks | 2 px | |
| `heritage` | #6b4f3a | ticks with a dot every 40 px | 2 px | |
| `subway` (tunnel) | #1f5fbf | dashed 10-5, darker casing | 3 px | stations as white circles with dark ring |
| `subway` (surface or elevated) | #1f5fbf | solid with casing | 3 px | |
| `light_rail` | #2e8b57 | solid with short ticks | 2.5 px | |
| `tram` | #c0392b | solid thin line with ticks on the road casing | 1.5 px | drawn on top of the road |
| `busway` | #d35400 | road casing with a centre stripe | road width | |
| bus lanes (`lanes_psv`) | #e67e22 | edge stripe on the road | 1 px | |
| `monorail`, `funicular`, aerial lifts | #8e44ad | dotted (aerial: dots at tower positions) | 2 px | |
| Ferry route | #2a5d8f | dashed 8-6 over water | 2 px | arrow every 300 m when one-way |
| Shipping lane / fairway | #5b7fa6 | long dashes 16-8 | 1 px | |
| `ln.power_transmission` | #e0c040 (Ch3) | solid with a square at each tower | 1.5 px (2.5 px at 500 kV) | corridor shown as a translucent band at zoom-in |
| `ln.power_distribution` | #c7a43a (Ch3) | solid with dots at poles | 1 px | |
| `ln.power_cable` | #c7a43a | dotted | 1 px | |
| `ln.pipeline` | #b07ad0 (Ch3) | dash-dot | 1.5 px | |
| `ln.telecom` | #7f8c8d | dotted | 1 px | |
| Level crossing | white X on the road | | | |
| Stations | white circle, mode-coloured ring | | | names at zoom |
| Stops | small mode-coloured dot | | | |
| Runway | #4d4d4d filled with white centreline dashes | | true width | |
| OLS height cap | contour lines every 10 m in #b03a2e, translucent fill under 30 m | | | toggle |

Use-class area colours are in the tables in 1.7 and 9.

### 7.2 Drawing, snapping and validating a hand-drawn network

**Tools (extend Chapter 1 5.3):** rail line (pick class, tracks), station (click on a rail line), platform (drag along a line), level crossing (automatic), transit route (click stops in order on existing roads or rails), ferry route (click two terminals), power line (pick voltage; click towers or draw and let the tool place them), pipeline, substation, airport (draw a runway, the tool builds the rest).

**Snapping (D):**

* Vertex snap radius 8 screen pixels or 5 m, whichever is smaller in metres; snap targets in order: existing nodes of the same graph, then edges of the same graph (split them), then crossing edges of the other graph (make a crossing node).
* A drawn rail line that ends within 20 m of another rail line joins it with a switch, aligned so the diverging angle is at most 1:12 (about 4.8 degrees, V) for mains and 1:8 for yards (D).
* A transit route snaps to the shortest path between consecutive clicked stops on its mode's graph; the user can drag a waypoint to force a detour.
* A ferry route snaps its ends to dock points and is routed by 3.3.
* A power line snaps to substations at both ends; a line drawn across a road gets a crossing angle check.

**Validation while drawing (live, D):**

| Rule | Feedback |
|---|---|
| Rail curve under class R min | segment turns red; tooltip gives the radius and the minimum |
| Rail grade over ruling grade (after a quick profile on the current terrain) | orange dashes along the steep part; offer "add bridge", "add tunnel", "lengthen" |
| Level crossing with motorway or trunk | refuse; insert a grade separation |
| Stop spacing under 150 m or over 1.5 x the mode norm | warning dot |
| Ferry route through land or shallow water | refuse; show the navigable mask |
| Power line span over 600 m (500 kV) or 450 m (230 kV) without a river crossing | auto-insert towers |
| Building inside the height cap zone above the cap | building outline turns red |

**Default attributes for hand-drawn features (D):** rail: `gauge_mm` from the world preset (1,435), class `branch`, tracks 1, `electrified: "no"`; tram: gauge from preset (1,495 in a Toronto preset), embedded in the road under it; routes: headway 10 minutes daytime; ferry: vehicle from the route length (under 300 m: shuttle; under 3 km: small car ferry; else lake car ferry); power line: 230 kV, lattice, 46 m corridor; pipeline: gas, 20 m ROW, buried. Every drawn feature gets `source: "drawn"` and `confidence: "rule"`.

---

## 8. Asset and style needs

Slots follow Chapter 2's scheme `<kind>.<family>.<name>[.<variant>][.<lod>]` [Ch2 4.1]. Chapter 3's bare role names (`rail.track`, `tower.lattice_230kv`) map to these slots by adding the kind (`kit.rail.track`, `mesh.utility.pylon_230kv_lattice`); the gap finder accepts both forms.

| Slot | Purpose | Min / rich | Tris desktop / phone (D) | Procedural or authored | Notes |
|---|---|---|---|---|---|
| `kit.rail.track` | rail sweep, sleepers, ballast prism by gauge | 1 / 3 (wood, concrete, street-embedded) | swept; 200 per 10 m near / texture far | **procedural** sweep along `rail.json` | sleepers instanced at 0.5 or 0.61 m [48] |
| `tex.rail.ballast` | ballast and formation | 1 / 2 (clean, dirty) | n/a | sourced texture | metres_per_repeat 2 |
| `kit.rail.switch` | turnout frog, points, guard rails | 1 / 3 (#8, #12, #20) | 1,000 to 3,000 / 300 | procedural from node legs | |
| `mesh.rail.signal_mast` | block and home signals | 1 / 4 | 300 to 1,200 / 100 to 300 | authored | |
| `mesh.rail.signal_bridge` | gantries over multiple tracks | 0 / 2 | 1,500 to 4,000 / 400 | parametric by track count | |
| `mesh.rail.crossing_signal` | lights, bell, crossbuck mast | 1 / 2 | 500 to 1,500 / 150 | authored | Ch3 IF3 |
| `mesh.rail.crossing_gate` | gate arm and mechanism | 1 / 2 | 400 to 1,200 / 150 | authored, arm length parametric | animated |
| `mesh.rail.crossbuck` | sign only | 1 / 1 | 100 / 40 | authored | |
| `mesh.rail.catenary_mast` | OCS masts and cantilevers | 0 / 3 (single, portal, headspan) | 300 to 1,200 / 100 | parametric | spacing from 1.6 |
| `mesh.rail.wire` | contact and messenger wires | 0 / 1 | strip | **procedural** | |
| `mesh.rail.buffer_stop`, `mesh.rail.derail` | track ends | 1 / 2 | 200 to 600 | authored | |
| `kit.rail.platform` | platform edge, surface, tactile strip | 1 / 3 (low, high, island) | parametric | procedural extrusion | |
| `mesh.rail.platform_shelter` | shelters and canopies | 1 / 3 | 500 to 3,000 | authored | |
| `kit.bldg.station_small` / `station_large` | station buildings | 1 / 4 | 2,000 to 10,000 / 500 to 2,500 | authored | GO-style, heritage, VIA |
| `mesh.rail.roundhouse`, `mesh.rail.turntable` | engine facilities | 0 / 2 | 3,000 to 8,000 | authored | |
| `mesh.rail.grain_elevator_track` | elevator on a siding | 0 / 2 | 3,000 to 8,000 | authored | Ch2 `grain_elevator` |
| `mesh.rail.bridge_trestle` / `bridge_truss` / `bridge_girder` | rail bridges | 1 / 3 | parametric | parametric by span and height | Ch2 `mesh.bridge.*` family |
| `mesh.infra.tunnel_portal` | portals | 1 / 2 | 1,000 to 3,000 | authored | Ch2 4.11 |
| `mesh.vehicle.train_freight_loco`, `train_freight_car.<type>` | freight trains | 1 loco + 3 cars / 3 locos + 10 car types | 3,000 to 12,000 / 800 to 2,000 | authored | boxcar, hopper, tank, flat, well car, gondola |
| `mesh.vehicle.train_passenger_loco`, `train_bilevel_coach` | commuter trains | 0 / 3 | as above | authored | |
| `mesh.vehicle.subway_car` | metro car | 0 / 1 | 2,000 to 6,000 | authored | |
| `mesh.vehicle.streetcar` | tram (28 m Flexity-like, generic) | 0 / 2 | 3,000 to 8,000 / 1,000 | authored | articulated, 5 modules |
| `mesh.vehicle.lrv` | LRT car | 0 / 1 | as above | authored | |
| `mesh.vehicle.bus` / `bus_articulated` | buses | 1 / 3 | 2,000 to 6,000 / 500 | authored | Ch2 4.10 `bus` |
| `mesh.transit.tram_stop` | pole, sign, island platform kit | 1 / 2 | 200 to 1,500 | authored + procedural island | |
| `mesh.street.bus_stop` | pole, shelter (exists in Ch2 4.9) | 1 / 2 | 300 to 2,000 | authored | |
| `mesh.transit.subway_entrance` | stair kiosk, entrance building | 0 / 3 | 1,000 to 5,000 | authored | |
| `mesh.transit.vent_shaft` | grates and small buildings | 0 / 2 | 100 to 1,000 | authored | |
| `mesh.transit.trolley_wire_pole` | street poles and span wires | 0 / 2 | 200 to 600 | parametric | |
| `mesh.transit.gondola_tower`, `gondola_cabin` | aerial lifts | 0 / 2 | 1,000 to 4,000 | authored | |
| `mesh.vessel.ferry_passenger` | island ferry | 0 / 2 | 5,000 to 20,000 / 1,500 | authored | |
| `mesh.vessel.ferry_double_ended` | car ferry, both-ends ramps | 0 / 2 (lake, coastal) | 8,000 to 30,000 / 2,000 | authored | animated ramps |
| `mesh.vessel.ferry_cable` | cable ferry with sheaves | 0 / 1 | 2,000 to 6,000 | authored | plus cable strip |
| `mesh.vessel.laker` | Great Lakes bulk freighter | 0 / 2 | 10,000 to 40,000 | authored | |
| `mesh.vessel.container_ship`, `tug`, `sailboat`, `motorboat`, `kayak` | water traffic | 1 / 8 | 500 to 40,000 | authored | Ch2 `boat_small` |
| `kit.harbour.dock_floating` / `pier_fixed` / `quay_wall` | docks and piers | 1 / 4 | parametric | procedural from structures | |
| `mesh.harbour.linkspan`, `mesh.harbour.dolphin`, `mesh.harbour.fender` | ferry terminal parts | 0 / 3 | 500 to 3,000 | authored | |
| `mesh.harbour.breakwater_armour` | armour stone | 1 / 2 | procedural rock scatter along a line | procedural | |
| `mesh.harbour.lighthouse` | lighthouses | 1 / 3 | 1,000 to 4,000 | authored | Ch2 `kit.bldg.port` |
| `mesh.nav.buoy_lateral_red`, `buoy_lateral_green`, `buoy_cardinal`, `light_minor` | aids to navigation | 2 / 6 | 100 to 600 | authored | IALA B colours (V) |
| `mesh.lock.gate_mitre`, `kit.lock.chamber` | locks | 0 / 2 | parametric | procedural chamber + authored gates | |
| `mesh.port.crane_sts`, `crane_rtg`, `container_stack` | ports | 0 / 3 | 4,000 to 15,000 | authored crane; stacks instanced boxes | |
| `kit.air.runway` (markings, lights) | runways | 1 / 2 | procedural | procedural from runway geometry | |
| `mesh.air.windsock`, `control_tower`, `hangar`, `beacon_rotating`, `approach_lights` | aerodromes | 1 / 5 | 200 to 8,000 | authored | Ch3 IF4 |
| `mesh.vehicle.aircraft_light`, `aircraft_regional`, `helicopter` | air traffic | 0 / 3 | 2,000 to 10,000 | authored | |
| `mesh.utility.pylon_115kv`, `pylon_230kv_lattice`, `pylon_500kv_lattice`, `pylon_steel_pole` | transmission | 1 / 4 | 1,000 to 5,000 / 300 (lattice as alpha cards far) | authored or parametric lattice | Ch2 `tower_transmission` |
| `mesh.utility.insulator_string` | insulators | 1 / 2 | 50 to 200 | authored | |
| `mesh.utility.wire_span` | conductors with sag | 1 / 1 | strip | **procedural** catenary | Ch2 4.9 |
| `mesh.utility.pole_wood` / `pole_concrete` / `transformer` | distribution | 2 / 6 | 300 to 1,000 | authored (Ch2 4.9) | |
| `kit.utility.substation` | frames, transformers, breakers, fence, control hut | 1 / 3 | 5,000 to 20,000 per yard | procedural layout + authored parts | Ch3 IF5 |
| `mesh.utility.marker_pipeline` | pipeline marker post | 1 / 2 | 50 to 150 | authored | |
| `mesh.utility.valve_site`, `compressor_station` | pipeline sites | 0 / 2 | 1,000 to 6,000 | authored | |
| `mesh.infra.water_tower` (bowl, cup, standpipe) | water towers | 1 / 3 | 500 to 3,000 | authored | Ch2 4.11 |
| `mesh.utility.tank_round`, `tank_bullet` | storage tanks | 1 / 3 | 200 to 1,500 | parametric | |
| `mesh.utility.clarifier`, `aeration_tank` | treatment plants | 0 / 2 | parametric | procedural | |
| `mesh.infra.radio_mast` / `cell_tower_lattice` / `cell_monopole` | telecom | 1 / 3 | 300 to 3,000 | parametric lattice | Ch2 4.11 |
| `mesh.utility.stack_industrial` | chimneys | 1 / 2 | 200 to 800 | parametric | |
| `mesh.street.signal_tram` | tram-specific signal heads | 0 / 1 | 200 | authored | |
| `fx.water.wake`, `fx.rail.spark` | ferry wake, pantograph spark | 0 / 2 | particles | procedural | |
| `snd.point.train_horn`, `snd.point.crossing_bell`, `snd.point.ferry_horn`, `snd.point.foghorn`, `snd.point.hum_transformer`, `snd.point.buzz_powerline` | audio | 2 / 6 | n/a | sourced (licence check) | Ch2 4.11 |

**Budgets (D):** a 4 km world with one main line, a branch, a town's bus network and a 230 kV line needs about 15 to 25 of these slots at the minimal level; a Toronto-like district with streetcars, subway, ferries and a harbour needs 40 to 60. Rail and power are dominated by procedural sweeps, so the authored triangle budget is small except rolling stock and vessels.

**Gap-finder rules (feed into Chapter 2's `requires.json`):**

```json
{
  "rail_class:main_freight": [
    { "slot": "kit.rail.track", "severity": "blocking", "fallback": ["procedural:rail_sweep_basic"] },
    { "slot": "tex.rail.ballast", "severity": "blocking", "fallback": ["tex.ground.gravel"] },
    { "slot": "mesh.rail.crossing_signal", "severity": "degrading", "fallback": ["mesh.rail.crossbuck"], "per": "level_crossing" },
    { "slot": "mesh.rail.signal_mast", "severity": "cosmetic", "fallback": [] },
    { "slot": "mesh.vehicle.train_freight_loco", "severity": "cosmetic", "fallback": [], "when": "transit.routes.mode=train" }],
  "rail_class:tram": [
    { "slot": "kit.rail.track", "variant": "street_embedded", "severity": "blocking", "fallback": ["decal.road.rail_pair"] },
    { "slot": "mesh.rail.wire", "severity": "degrading", "fallback": ["procedural:wire_strip"] },
    { "slot": "mesh.transit.trolley_wire_pole", "severity": "degrading", "fallback": ["mesh.utility.pole_concrete"] },
    { "slot": "mesh.vehicle.streetcar", "severity": "degrading", "fallback": ["mesh.vehicle.bus"] }],
  "transit_mode:ferry": [
    { "slot": "mesh.vessel.ferry_double_ended", "severity": "degrading", "fallback": ["mesh.vessel.ferry_passenger", "mesh.vehicle.boat_small"] },
    { "slot": "mesh.harbour.linkspan", "severity": "degrading", "fallback": ["kit.harbour.pier_fixed"] }],
  "line:ln.power_transmission": [
    { "slot": "mesh.utility.pylon_{voltage_band}", "severity": "degrading", "fallback": ["mesh.utility.pylon_230kv_lattice", "mesh.utility.tower_transmission"] },
    { "slot": "mesh.utility.wire_span", "severity": "degrading", "fallback": ["procedural:catenary_strip"] }],
  "structure:substation": [ { "slot": "kit.utility.substation", "severity": "degrading", "fallback": ["mesh.utility.substation"] } ],
  "aerodrome": [ { "slot": "kit.air.runway", "severity": "blocking", "fallback": ["tex.road.asphalt_new"] },
                 { "slot": "mesh.air.windsock", "severity": "cosmetic", "fallback": [] } ]
}
```

---

## 9. Changes to earlier chapters

| # | Chapter and section | What it said | Change | Why |
|---|---|---|---|---|
| 1 | Ch1 2.7 `roads.json` classes | `rail` as a road class (width 4, max grade 2.5 percent) | **Deprecated.** Rail lives in `network/rail.json` (1.9). Readers of format 1.0 packs still accept `rail` road edges and convert them to `rail.json` edges of class `branch` | Trains need switches, gauge, cant, platforms, routes |
| 2 | Ch3 6.5 `lines.json` | `ln.rail_main`, `ln.rail_branch`, `ln.rail_siding`, `ln.rail_abandoned` as line types | **Kept only as 2D display ids** (same colours). The geometry and attributes are in `rail.json`; `lines.json` no longer stores railways | One source of truth |
| 3 | Ch1 2.2 file list and 2.5 `layers` | no rail, transit, structures, aerodrome or height-cap files | **Add** `network/rail.json`, `network/transit.json`, `infra/structures.geojson`, `infra/aerodromes.json`, `limits/height_cap.u16.zlib`, `osm/` (0.1). Format becomes 1.1 | New optional layers are a minor bump (Ch1 2.11) |
| 4 | Ch1 2.11 validation | no rules for these layers | **Add**: rail edges reference existing nodes; graded grade within class ruling grade plus 0.2 percent; radius at least class minimum (warning only for OSM data); every route's path is connected; stop `s_m` increasing; ferry geometry entirely in navigable water; no generated structure above `height_cap`; every level crossing node matches a road node | Keep packs coherent |
| 5 | Ch1 3.3 Overpass example | `way["railway"~"^(rail|light_rail|tram)$"]`, ways only, no relations except water and buildings | **Replace** with the queries in 6.2 (all `railway` values, `nwr`, route and multipolygon relations, power, aeroway, man_made, public transport, seamarks) | The example missed subways, multipolygon landuse, routes and utilities |
| 6 | Ch1 3.4 and 2.8 storey height | `building:levels` x 3.2 m | **Keep 3.2 m as the default when the building type is unknown**; add type-specific storey heights and roof parts (6.7) | Better heights for houses (3.0) and industry (6.0) |
| 7 | Ch1 2.7 road width default | `lanes` x 3.5 m plus shoulders | **Refine** by class (6.7 table: 3.0 to 3.75 m lanes and class shoulders); OSM `width` is the carriageway kerb to kerb [44] | Matches OSM semantics |
| 8 | Ch1 2.7 / Ch2 1.4 / Ch3 6.5 road classes | motorway, primary, secondary, residential, service, track, path, rail, plus tertiary, unclassified (master), plus motorway_link, trunk, lane, logging, farm_lane (Ch3 proposal) | **Add** `busway` (and `path_kind` on `path`: footway, cycleway, bridleway, steps, pedestrian); **adopt** Ch3's `motorway_link` and `trunk` for OSM import; `trunk_link`, `primary_link`, `secondary_link`, `tertiary_link` map to the parent class with `link: true` | Needed for a lossless OSM import |
| 9 | Ch3 4.5 track centres | double track adds 4.3 to 4.6 m (V) | **Replace** with TC E-05: main 3.96 m, main and siding 4.27 m, yard 4.11 m, ladder 4.57 m minimum (S [28]); generator default 4.3 m | Sourced |
| 10 | Ch3 6.5 `ln.power_transmission` | corridor 46 m (230 kV); towers 300 to 450 m | **Extend** with voltage bands: 115 kV 30 to 37 m [23], 230 kV 46 m [21], 500 kV at least 64 m [22]; `voltage` attribute required | 500 kV width now sourced (Ch3 listed it as a gap) |
| 11 | Ch2 4.9 tower spacing | hydro corridor towers every 250 to 400 m (design) | **Replace** by the voltage table in 5.1 (200 to 500 m by voltage) | One number set |
| 12 | Ch2 4.9 bus stops | every 250 to 400 m on transit streets (design) | **Replace** with 300 to 400 m local and 650 to 1,000 m express, the TTC service standard (S [45]) | Sourced |
| 13 | Ch3 6.4 IF3 (182) | "Rail ROW and yard" | **Narrow** to "rail ROW"; yards and other rail land get 191 to 196 | More specific classes |
| 14 | Ch3 6.4 use ids | 191 to 255 free | **Claim 191 to 230** for transport and utilities (table below); 231 to 255 stay free | |
| 15 | Ch2 0.1 / master 3.4 | use ids 60 to 79 reserved for Chapter 2 urban classes, not yet numbered | **Proposal for Chapter 2's owner to confirm**: 60 village_core, 61 main_street, 62 midrise_avenue, 63 downtown_tower, 64 suburb_inner, 65 suburb_outer_grid, 66 campus, 67 waterfront_port, 68 waterfront_residential, 69 informal, 70 residential_generic, 71 retail_generic, 72 office, 73 mixed_use, 74 hospital_campus, 75 university_campus, 76 to 79 free. The OSM importer needs numbers for `landuse=residential/commercial/retail` when the morphology cannot be read | Avoid a gap in the importer |
| 16 | Ch3 4.7 airports | runway sizes only | **Add** OLS and the height cap (4.3) | Buildings near airports were unconstrained |
| 17 | Ch1 2.9 markers | `spawn`, `poi` | **Add** kinds `harbour`, `hazard` (rock, wreck), `region` (admin boundary), and the POI vocabulary `poi.<key>.<value>` from OSM | Needed by import |
| 18 | Ch1 3.3 OSM file separation | OSM layers in their own files | **Unchanged and extended**: `rail.json`, `transit.json`, `structures.geojson` and `aerodromes.json` mark each feature's `source`; when a file mixes OSM and generated features, the manifest flags it ODbL as a whole (Chapter 1's rule); the importer can split them into `*.osm.json` and `*.gen.json` pairs when `split_osm_layers: true` | Licence hygiene |

**New use classes, full list (ids 191 to 230):** 191 to 203 are in 1.7. The rest:

| id | code | class | colour | cover | assets |
|---|---|---|---|---|---|
| 204 | IF25 | Hydro corridor park | #b7cf7a | 7 | tower.lattice by voltage, path.trail, grass.meadow, sportsfield (some), allotment.plots |
| 205 | IF26 | Waste transfer or recycling depot | #8f8a6f | 14 | building.tipping, scale.house, bin.rolloff |
| 206 | IF27 | Fuel depot / tank farm | #9b7f6a | 14 | tank.round (rows), berm, pipe.rack, truck.loading_rack |
| 207 | IF28 | Pipeline facility (valve site, compressor, pumping) | #a07aa8 | 14 | pipeline.valve_site, compressor.building, cooler.fans |
| 208 | IF29 | Water treatment plant | #6f9fb0 | 14 | tank.rect, clarifier, building.plant |
| 209 | IF30 | Wastewater treatment plant | #6f8f7f | 14 | clarifier, aeration.tank, digester, building.plant |
| 210 | IF31 | Water tower or reservoir site | #8fb0c0 | 7 | water_tower, reservoir.covered, fence |
| 211 | IF32 | Nuclear generating station | #7a7f9a | 14 | reactor.building, turbine.hall, switchyard, outfall |
| 212 | IF33 | Thermal generating station (gas, oil, biomass) | #8a7f8f | 14 | stack.tall, turbine.hall, cooling.tower_small |
| 213 | IF34 | Battery storage | #9aa0b0 | 14 | container.battery rows, fence |
| 214 | IF35 | Telecom compound | #9a9aa8 | 6 | tower.cell, hut.equipment, fence |
| 215 | IF36 | Airport terminal and apron | #9c9c9c | 14 | terminal.building, apron, jet_bridge |
| 216 | IF37 | Heliport | #a8a8a8 | 14 | pad.helicopter, windsock |
| 217 | IF38 | Water aerodrome and float plane base | #7f9fb5 | 1 | dock.floating, float_plane |
| 218 | IF39 | Marina dry storage and boatyard | #8fa3b5 | 14 | boat.cradled rows, travel_lift, shed.boat |
| 219 | IF40 | Drydock and shipyard | #6f8296 | 14 | drydock, crane.shipyard, shed.fabrication |
| 220 | IF41 | Grain or bulk port terminal | #7f8b78 | 14 | elevator.grain_terminal, conveyor.gallery, ship_loader |
| 221 | IF42 | Bus rapid transit station area | #b0947a | 14 | brt.station_canopy |
| 222 | IF43 | Park and ride lot | #b0a090 | 14 | parking.surface_large, shelter |
| 223 | IF44 | Military area | #8a8f6f | 6 | fence.security, building.military |
| 224 | IF45 | Allotment gardens | #a8c46b | 8 | allotment.plots, shed.small |
| 225 to 230 | | reserved for this chapter's later revisions | | | |

---

## 10. Moving routes and timetables

Games animate four kinds of movers: trains, streetcars and LRT, buses, and ferries and other boats. The pack gives each a **path**, a **speed profile** and optionally a **schedule**. Nothing in the pack moves; the game runs the clock.

**Path.** A route (2.6) resolves to one polyline by concatenating its edges' `pts` (reversed where `dir: -1`), or its own `geometry`. The game samples position by distance `s` along it. Rail paths include switch legs so a train follows the right track through a junction.

**Speed profile (C).** For each route the importer writes `profile`: a list of `[s_m, v_max_kmh]` breakpoints from the edges' `maxspeed_kmh`, curve limits (`V_max(R)` from 1.2 for rail; for roads the Chapter 3 radius table inverted), stop positions (v = 0) and terminal approaches. Vehicles accelerate at a mode rate (D: freight 0.1 m/s2, commuter 0.5, subway 1.0, streetcar 1.2, bus 1.0, ferry 0.05) and brake at 1.5 times that (D); dwell at stops (D: subway 25 s, streetcar 20 s, bus 15 s, commuter 60 s, ferry from 3.3).

**Schedules.** Three levels, from cheapest to richest:

1. **None.** The game spawns vehicles at a headway of its choosing.
2. **Headway bands** (`service.headway_s`, as in 2.6): `[start, end, seconds]`, times as "HH:MM" that may exceed 24:00 for after-midnight service, like GTFS [54]. The game spawns vehicles at the route start at that headway and runs them along the profile. Ferries default to one vessel shuttling.
3. **Explicit timetables** in `network/timetables.json` (optional), a GTFS-shaped subset: `trips` (trip id, route id, service days, direction), `stop_times` (trip id, stop sequence, arrival and departure "HH:MM:SS", the stop's `s_m`). GTFS `route_type` maps to pack modes (0 tram or light rail, 1 subway, 2 rail, 3 bus, 4 ferry, 5 cable tram, 6 aerial lift, 7 funicular, 11 trolleybus, 12 monorail [54]). `wb import gtfs <zip>` matches GTFS stops to pack stops by name and distance (within 50 m, D) and GTFS shapes to pack routes by Hausdorff distance (within 30 m, D). GTFS feeds carry their own licences; record them in `attribution`.

**Freight and other unscheduled movers (D).** Main lines get `freight_density` per day (CN and CPKC mains 10 to 40 trains, branches 0 to 4, V); the game spawns trains of 50 to 150 cars on mains, 5 to 30 on branches (V) and shunting moves in yards. Shipping lanes get `vessels_per_day`. Leisure boats use spawn zones (3.5). Aircraft use the approach and departure centrelines (4.3).

**Consists.** `transit.json` `vehicles` holds the vehicle types; a route or freight density entry gives a consist rule (`{"loco": 2, "cars": [50, 120], "mix": {"hopper": 0.4, "tank": 0.2, "boxcar": 0.2, "intermodal": 0.2}}`, D) so the gap finder knows which rolling-stock slots matter.

---

## 11. Gaps and uncertainty

* **Transport Canada and Metrolinx standards not read in full.** I read the TC E-05 track-centre table [28] but its clearance diagrams are images not read; the Grade Crossings Standards [27], TP 312 [35] and GO Transit Track Standards [36] were located but not read. Clearance envelopes, crossing device rules, runway strip widths and GO curve and grade limits are therefore (V).
* **AREMA numbers** (spiral length rules, vertical curve rates, superelevation practice in Canada) are from memory or general sources [30]; marked (V).
* **Ferry hull dimensions** for the Toronto Island fleet and the Pelee Island ferries were not found [16]; Washington State Ferries' double-ended design and BC Ferries crossing times are (V).
* **Transmission span lengths and 500 kV tower heights** were not found in Hydro One sources; spans are (V). The 500 kV width is a minimum from one Hydro One submission [22].
* **Pipeline ROW widths** are not fixed by the regulator; only the 30 m prescribed area is sourced [26].
* **The ICAO transitional slope and small-aerodrome surfaces** were not confirmed [34]; the new OLS concept (applicable 2030) is not modelled.
* **Station spacing norms** for subway, BRT and commuter rail are practice values; TCRP's Transit Capacity manual was located but its numbers were not read [57]. The streetcar and bus figures are sourced [45].
* **Hamilton OSM sizes and import timings** are estimates; gate P4 must measure them.
* **OSM tagging details** read only in part: the `power=*` value list did not load [2], seamark buoy category values were not listed [41], and the Default speed limits page was read only partly [52]. Appendix A uses values I know are in wide use; a taginfo pass (most-used values per key in Ontario) should confirm them before the importer is finalised.
* **Container terminal densities and stack layouts** were not found; (V).
* **Legal**: the ODbL questions in Chapter 1 apply with more force here, because transit routes and stops are a database a game could extract. Keep OSM-derived transit layers separate (change 18).

---
## Appendix A. `osm_rules.json` (sketch, 262 rules)

**Format.** The importer evaluates rules against every element. Per target `layer`, the matching rule with the highest `priority` wins; ties go to the rule listed first. One element can feed several layers (a `landuse=residential` polygon feeds both `use` and `cover`), so rules for different layers do not compete.

* `geom`: `node`, `way` (open line), `area` (closed way with an area key or a multipolygon), `rel` (relation), or a list.
* `match`: every key must match. A value is an exact string, a list (any of), `"*"` (key present), `"!"` (key absent), or a string starting with `~` (POSIX regex, no backslashes needed in these rules).
* `layer`: `roads`, `rail`, `transit`, `structures`, `buildings`, `lines`, `rivers`, `water`, `cover`, `use`, `props`, `markers`, `aerodromes`, `constraints`, `skip`.
* `class`: the pack class (road class, rail class, line id, structure kind, cover id, use id, prop family, marker kind).
* `copy`: OSM keys copied (renamed with `key>name`); `attrs`: fixed attributes; `defaults`: values used when the matching tag is missing; `then`: a named post-processing step.
* Cover and use ids are from Chapters 1 and 3 and section 9. Use ids 60 to 79 are the provisional numbering in change 15.

```json
{
  "schema": "rwj-osm-rules-1",
  "version": "0.1",
  "lifecycle_prefixes_hide": ["disused:", "abandoned:", "demolished:", "razed:", "removed:", "construction:", "proposed:", "planned:", "was:"],
  "area_keys": ["building", "building:part", "landuse", "leisure", "amenity", "natural", "water", "place", "aeroway", "power", "man_made", "military", "tourism", "shop", "historic", "harbour", "public_transport", "railway"],
  "area_key_exceptions": { "natural": ["coastline", "cliff", "ridge", "arete", "tree_row", "valley"], "man_made": ["pipeline", "cutline", "embankment", "dyke", "breakwater", "groyne", "pier"], "railway": ["*"], "power": ["line", "minor_line", "cable"], "public_transport": ["stop_position"] },
  "rules": [
    {"id":"r001","geom":"way","match":{"highway":"motorway"},"layer":"roads","class":"motorway","attrs":{"hierarchy":"expressway"},"copy":["lanes","width","maxspeed","oneway","ref","name","bridge","tunnel","layer","surface"],"defaults":{"oneway":"yes","lanes":2,"lane_w":3.75,"shoulder_out":3.0,"shoulder_in":1.0,"maxspeed":100},"priority":90},
    {"id":"r002","geom":"way","match":{"highway":"motorway_link"},"layer":"roads","class":"motorway_link","attrs":{"hierarchy":"expressway","link":true},"copy":["lanes","width","maxspeed","oneway","ref","bridge","tunnel","layer"],"defaults":{"oneway":"yes","lanes":1,"lane_w":4.5,"shoulder_out":2.5,"maxspeed":70},"priority":90},
    {"id":"r003","geom":"way","match":{"highway":"trunk"},"layer":"roads","class":"trunk","attrs":{"hierarchy":"arterial_major"},"copy":["lanes","width","maxspeed","oneway","ref","name","bridge","tunnel","layer","surface"],"defaults":{"lanes":2,"lane_w":3.65,"shoulder_out":2.5,"maxspeed":80},"priority":90},
    {"id":"r004","geom":"way","match":{"highway":"trunk_link"},"layer":"roads","class":"trunk","attrs":{"hierarchy":"arterial_major","link":true},"copy":["lanes","width","oneway","bridge","tunnel","layer"],"defaults":{"lanes":1,"lane_w":4.0,"maxspeed":60},"priority":90},
    {"id":"r005","geom":"way","match":{"highway":"primary"},"layer":"roads","class":"primary","attrs":{"hierarchy":"arterial_major"},"copy":["lanes","width","maxspeed","oneway","ref","name","bridge","tunnel","layer","surface","sidewalk","cycleway","parking:both","lanes:psv","busway"],"defaults":{"lanes_urban":4,"lanes_rural":2,"lane_w":3.5,"maxspeed_urban":50,"maxspeed_rural":80},"priority":90},
    {"id":"r006","geom":"way","match":{"highway":"primary_link"},"layer":"roads","class":"primary","attrs":{"hierarchy":"arterial_major","link":true},"copy":["lanes","width","oneway","bridge","tunnel","layer"],"defaults":{"lanes":1,"lane_w":3.75},"priority":90},
    {"id":"r007","geom":"way","match":{"highway":"secondary"},"layer":"roads","class":"secondary","attrs":{"hierarchy":"arterial_minor"},"copy":["lanes","width","maxspeed","oneway","ref","name","bridge","tunnel","layer","surface","sidewalk","cycleway","parking:both"],"defaults":{"lanes":2,"lane_w":3.5,"maxspeed_urban":50,"maxspeed_rural":80},"priority":90},
    {"id":"r008","geom":"way","match":{"highway":"secondary_link"},"layer":"roads","class":"secondary","attrs":{"hierarchy":"arterial_minor","link":true},"copy":["lanes","width","oneway","bridge","tunnel","layer"],"defaults":{"lanes":1,"lane_w":3.5},"priority":90},
    {"id":"r009","geom":"way","match":{"highway":"tertiary"},"layer":"roads","class":"tertiary","attrs":{"hierarchy":"collector"},"copy":["lanes","width","maxspeed","oneway","name","bridge","tunnel","layer","surface","sidewalk","cycleway","parking:both"],"defaults":{"lanes":2,"lane_w":3.3,"maxspeed_urban":50,"maxspeed_rural":80},"priority":90},
    {"id":"r010","geom":"way","match":{"highway":"tertiary_link"},"layer":"roads","class":"tertiary","attrs":{"hierarchy":"collector","link":true},"copy":["oneway","bridge","tunnel","layer"],"defaults":{"lanes":1,"lane_w":3.3},"priority":90},
    {"id":"r011","geom":"way","match":{"highway":"unclassified"},"layer":"roads","class":"unclassified","attrs":{"hierarchy":"rural_paved"},"copy":["lanes","width","maxspeed","surface","name","bridge","tunnel","layer"],"defaults":{"lanes":2,"lane_w":3.0,"shoulder_out":0.5,"row_m":20.1,"maxspeed":80},"priority":90},
    {"id":"r012","geom":"way","match":{"highway":"residential"},"layer":"roads","class":"residential","attrs":{"hierarchy":"local"},"copy":["lanes","width","maxspeed","oneway","surface","name","sidewalk","parking:both","bridge","tunnel","layer"],"defaults":{"lanes":2,"lane_w":3.0,"row_m":20,"maxspeed":50},"priority":90},
    {"id":"r013","geom":"way","match":{"highway":"living_street"},"layer":"roads","class":"residential","attrs":{"hierarchy":"local","living":true},"copy":["width","name","surface"],"defaults":{"lanes":1,"lane_w":3.0,"row_m":15,"maxspeed":20},"priority":90},
    {"id":"r014","geom":"way","match":{"highway":"service","service":"alley"},"layer":"roads","class":"service","attrs":{"hierarchy":"lane"},"copy":["width","surface","oneway","name"],"defaults":{"lanes":1,"width":6.0,"row_m":7.5},"priority":91},
    {"id":"r015","geom":"way","match":{"highway":"service","service":"driveway"},"layer":"roads","class":"service","attrs":{"hierarchy":"drive"},"copy":["width","surface"],"defaults":{"lanes":1,"width":3.5},"priority":91},
    {"id":"r016","geom":"way","match":{"highway":"service","service":["parking_aisle","drive-through"]},"layer":"roads","class":"service","attrs":{"hierarchy":"drive"},"copy":["width","oneway","surface"],"defaults":{"lanes":1,"width":6.0},"priority":91},
    {"id":"r017","geom":"way","match":{"highway":"service"},"layer":"roads","class":"service","attrs":{"hierarchy":"lane"},"copy":["width","surface","oneway","name","access","bridge","tunnel","layer"],"defaults":{"lanes":1,"width":4.5},"priority":90},
    {"id":"r018","geom":"way","match":{"highway":"track"},"layer":"roads","class":"track","attrs":{"hierarchy":"track"},"copy":["tracktype","surface","width","access"],"defaults":{"width":3.5,"surface_by_tracktype":{"grade1":"asphalt","grade2":"gravel","grade3":"compacted","grade4":"dirt","grade5":"grass"}},"priority":90},
    {"id":"r019","geom":"way","match":{"highway":"busway"},"layer":"roads","class":"busway","attrs":{"hierarchy":"arterial_minor","access":"psv"},"copy":["lanes","width","name","bridge","tunnel","layer"],"defaults":{"lanes":2,"lane_w":3.5},"priority":90},
    {"id":"r020","geom":"way","match":{"highway":"bus_guideway"},"layer":"roads","class":"busway","attrs":{"guided":true,"access":"psv"},"copy":["width","bridge","tunnel","layer"],"defaults":{"lanes":2,"lane_w":3.0},"priority":90},
    {"id":"r021","geom":["way","area"],"match":{"highway":"pedestrian"},"layer":"roads","class":"path","attrs":{"path_kind":"pedestrian"},"copy":["width","surface","name","area"],"defaults":{"width":6.0},"priority":80},
    {"id":"r022","geom":"way","match":{"highway":"footway","footway":"sidewalk"},"layer":"roads","class":"path","attrs":{"path_kind":"sidewalk"},"copy":["width","surface"],"defaults":{"width":1.8},"then":"attach_to_parallel_road","priority":81},
    {"id":"r023","geom":"way","match":{"highway":"footway","footway":"crossing"},"layer":"roads","class":"path","attrs":{"path_kind":"crossing"},"copy":["crossing"],"defaults":{"width":3.0},"priority":81},
    {"id":"r024","geom":"way","match":{"highway":"footway"},"layer":"roads","class":"path","attrs":{"path_kind":"footway"},"copy":["width","surface","bridge","tunnel","layer","name"],"defaults":{"width":1.8},"priority":80},
    {"id":"r025","geom":"way","match":{"highway":"cycleway"},"layer":"roads","class":"path","attrs":{"path_kind":"cycleway"},"copy":["width","surface","oneway","bridge","tunnel","layer"],"defaults":{"width":3.0},"priority":80},
    {"id":"r026","geom":"way","match":{"highway":["path","bridleway"]},"layer":"roads","class":"path","attrs":{"path_kind":"path"},"copy":["width","surface","sac_scale","bridge","layer"],"defaults":{"width":1.5},"priority":80},
    {"id":"r027","geom":"way","match":{"highway":"steps"},"layer":"roads","class":"path","attrs":{"path_kind":"steps"},"copy":["width","step_count","incline"],"defaults":{"width":2.0},"priority":80},
    {"id":"r028","geom":"way","match":{"highway":"raceway"},"layer":"roads","class":"service","attrs":{"raceway":true},"copy":["width","surface","name"],"defaults":{"width":12.0},"priority":80},
    {"id":"r029","geom":"way","match":{"highway":"road"},"layer":"roads","class":"residential","attrs":{"hierarchy":"local","warn":"unknown_road_type"},"copy":["name","width"],"defaults":{"lanes":2,"lane_w":3.0},"priority":70},
    {"id":"r030","geom":"way","match":{"highway":["construction","proposed"]},"layer":"skip","class":"lifecycle","attrs":{"recipe_flag":"include_lifecycle"},"priority":95},
    {"id":"r031","geom":"node","match":{"highway":"traffic_signals"},"layer":"roads","class":"node_control","attrs":{"control":"signals"},"priority":90},
    {"id":"r032","geom":"node","match":{"highway":["stop","give_way"]},"layer":"roads","class":"node_control","copy":["highway>control","direction"],"priority":90},
    {"id":"r033","geom":"node","match":{"highway":"mini_roundabout"},"layer":"roads","class":"node_control","attrs":{"control":"mini_roundabout"},"priority":90},
    {"id":"r034","geom":"node","match":{"highway":["turning_circle","turning_loop"]},"layer":"roads","class":"node_turning","copy":["highway>kind"],"defaults":{"radius_m":12},"priority":90},
    {"id":"r035","geom":"node","match":{"highway":"crossing"},"layer":"roads","class":"node_crossing","copy":["crossing","crossing_ref"],"priority":90},
    {"id":"r036","geom":"node","match":{"highway":"motorway_junction"},"layer":"roads","class":"node_exit","copy":["ref","name"],"priority":90},
    {"id":"r037","geom":"node","match":{"highway":"street_lamp"},"layer":"props","class":"street.lamp","priority":50},
    {"id":"r038","geom":"node","match":{"highway":"bus_stop"},"layer":"transit","class":"stop","attrs":{"mode":["bus"]},"copy":["name","ref","shelter","bench","bin","tactile_paving"],"priority":80},
    {"id":"r039","geom":["way","area"],"match":{"highway":"platform"},"layer":"structures","class":"platform","attrs":{"mode":"bus"},"copy":["name","ref","width"],"priority":80},
    {"id":"r040","geom":"way","match":{"railway":"rail","usage":"main"},"layer":"rail","class":"main_freight","copy":["gauge","tracks","electrified","voltage","frequency","maxspeed","name","ref","operator","bridge","tunnel","layer","cutting","embankment"],"defaults":{"gauge":1435,"tracks":1},"then":"upgrade_main_passenger_if_passenger_route","priority":92},
    {"id":"r041","geom":"way","match":{"railway":"rail","usage":"branch"},"layer":"rail","class":"branch","copy":["gauge","tracks","electrified","maxspeed","name","ref","operator","bridge","tunnel","layer"],"defaults":{"gauge":1435,"tracks":1},"priority":92},
    {"id":"r042","geom":"way","match":{"railway":"rail","usage":"industrial"},"layer":"rail","class":"industrial_lead","copy":["gauge","name","operator","bridge","layer"],"defaults":{"gauge":1435},"priority":92},
    {"id":"r043","geom":"way","match":{"railway":"rail","usage":"tourism"},"layer":"rail","class":"heritage","copy":["gauge","name","operator","bridge","layer"],"defaults":{"gauge":1435},"priority":92},
    {"id":"r044","geom":"way","match":{"railway":"rail","usage":["military","test","scientific"]},"layer":"rail","class":"branch","copy":["usage","gauge","name","bridge","layer"],"defaults":{"gauge":1435},"priority":92},
    {"id":"r045","geom":"way","match":{"railway":"rail","service":"siding"},"layer":"rail","class":"siding","copy":["gauge","name","bridge","layer"],"defaults":{"gauge":1435},"priority":93},
    {"id":"r046","geom":"way","match":{"railway":"rail","service":"yard"},"layer":"rail","class":"yard","copy":["gauge","name","bridge","layer"],"defaults":{"gauge":1435},"priority":93},
    {"id":"r047","geom":"way","match":{"railway":"rail","service":"spur"},"layer":"rail","class":"industrial_lead","copy":["gauge","name","bridge","layer"],"defaults":{"gauge":1435},"priority":93},
    {"id":"r048","geom":"way","match":{"railway":"rail","service":"crossover"},"layer":"rail","class":"siding","attrs":{"crossover":true},"copy":["gauge"],"defaults":{"gauge":1435},"priority":93},
    {"id":"r049","geom":"way","match":{"railway":"rail","railway:preserved":"yes"},"layer":"rail","class":"heritage","copy":["gauge","name","operator"],"defaults":{"gauge":1435},"priority":94},
    {"id":"r050","geom":"way","match":{"railway":"rail"},"layer":"rail","class":"branch","copy":["gauge","tracks","electrified","maxspeed","name","ref","operator","bridge","tunnel","layer"],"defaults":{"gauge":1435,"tracks":1},"then":"upgrade_main_if_tracks_ge_2_or_maxspeed_ge_80","priority":91},
    {"id":"r051","geom":"way","match":{"railway":"narrow_gauge"},"layer":"rail","class":"narrow_gauge","copy":["gauge","name","bridge","tunnel","layer"],"defaults":{"gauge":1067},"priority":92},
    {"id":"r052","geom":"way","match":{"railway":"subway"},"layer":"rail","class":"subway","copy":["gauge","electrified","voltage","name","ref","bridge","tunnel","layer","location"],"defaults":{"gauge":1435,"tracks":1},"then":"depth_from_layer","priority":92},
    {"id":"r053","geom":"way","match":{"railway":"light_rail"},"layer":"rail","class":"light_rail","copy":["gauge","electrified","voltage","name","ref","bridge","tunnel","layer"],"defaults":{"gauge":1435,"electrified":"contact_line","voltage":750},"priority":92},
    {"id":"r054","geom":"way","match":{"railway":"tram"},"layer":"rail","class":"tram","copy":["gauge","electrified","voltage","name","bridge","tunnel","layer"],"defaults":{"gauge":1435,"electrified":"contact_line","voltage":600},"then":"embed_in_road_if_coincident","priority":92},
    {"id":"r055","geom":"way","match":{"railway":"funicular"},"layer":"rail","class":"funicular","copy":["gauge","name"],"defaults":{"gauge":1000},"priority":92},
    {"id":"r056","geom":"way","match":{"railway":"monorail"},"layer":"rail","class":"monorail","copy":["name","bridge","layer"],"priority":92},
    {"id":"r057","geom":"way","match":{"railway":"miniature"},"layer":"rail","class":"miniature","copy":["gauge","name"],"defaults":{"gauge":381},"priority":92},
    {"id":"r058","geom":"way","match":{"railway":"abandoned"},"layer":"rail","class":"abandoned","copy":["name","bridge","layer"],"then":"rail_trail_if_path_on_grade","priority":92},
    {"id":"r059","geom":"way","match":{"railway":"disused"},"layer":"rail","class":"disused","copy":["gauge","name","bridge","layer"],"defaults":{"gauge":1435},"priority":92},
    {"id":"r060","geom":"way","match":{"railway":["construction","proposed","razed"]},"layer":"skip","class":"lifecycle","attrs":{"recipe_flag":"include_lifecycle"},"priority":95},
    {"id":"r061","geom":"node","match":{"railway":"switch"},"layer":"rail","class":"node_switch","copy":["railway:switch","ref"],"priority":90},
    {"id":"r062","geom":"node","match":{"railway":"level_crossing"},"layer":"rail","class":"node_level_crossing","copy":["crossing:barrier","crossing:light","crossing:bell","crossing:saltire","crossing:activation"],"defaults":{"crossing:barrier":"no","crossing:saltire":"yes"},"then":"link_road_node","priority":90},
    {"id":"r063","geom":"node","match":{"railway":"crossing"},"layer":"rail","class":"node_foot_crossing","priority":90},
    {"id":"r064","geom":"node","match":{"railway":"tram_level_crossing"},"layer":"rail","class":"node_tram_crossing","then":"link_road_node","priority":90},
    {"id":"r065","geom":"node","match":{"railway":"railway_crossing"},"layer":"rail","class":"node_diamond","priority":90},
    {"id":"r066","geom":"node","match":{"railway":["buffer_stop","derail"]},"layer":"rail","class":"node_end","copy":["railway>stop"],"priority":90},
    {"id":"r067","geom":"node","match":{"railway":"signal"},"layer":"rail","class":"node_signal","copy":["railway:signal:direction","railway:signal:position"],"defaults":{"form":"mast"},"priority":90},
    {"id":"r068","geom":["node","area"],"match":{"railway":["station","halt"]},"layer":"transit","class":"station","copy":["name","station","operator","network","railway>kind"],"priority":85},
    {"id":"r069","geom":"node","match":{"railway":["stop","tram_stop"]},"layer":"transit","class":"stop_position","copy":["name","ref"],"priority":85},
    {"id":"r070","geom":["way","area"],"match":{"railway":"platform"},"layer":"structures","class":"platform","copy":["name","ref","width","height"],"defaults":{"width":4.0},"then":"attach_platform_to_track","priority":85},
    {"id":"r071","geom":["node","area"],"match":{"railway":["roundhouse","turntable","traverser","workshop","wash","water_crane"]},"layer":"structures","class":"rail_facility","copy":["railway>kind"],"priority":80},
    {"id":"r072","geom":"node","match":{"railway":"subway_entrance"},"layer":"structures","class":"entrance.subway","copy":["name","ref","wheelchair"],"priority":80},
    {"id":"r073","geom":"node","match":{"railway":"ventilation_shaft"},"layer":"structures","class":"shaft.vent","priority":80},
    {"id":"r074","geom":"node","match":{"public_transport":"stop_position"},"layer":"transit","class":"stop_position","copy":["name","ref","bus","tram","train","subway","light_rail","ferry"],"priority":84},
    {"id":"r075","geom":["node","way","area"],"match":{"public_transport":"platform"},"layer":"transit","class":"platform","copy":["name","ref","shelter","bench"],"priority":84},
    {"id":"r076","geom":["node","area"],"match":{"public_transport":"station"},"layer":"transit","class":"station","copy":["name","operator","network"],"priority":84},
    {"id":"r077","geom":"rel","match":{"type":"public_transport","public_transport":"stop_area"},"layer":"transit","class":"stop_area","copy":["name"],"priority":84},
    {"id":"r078","geom":"rel","match":{"type":"route","route":["train","subway","light_rail","tram","monorail","funicular"]},"layer":"transit","class":"route","copy":["route>mode","ref","name","from","to","network","operator","colour","public_transport:version","service"],"then":"chain_route_members","priority":85},
    {"id":"r079","geom":"rel","match":{"type":"route","route":["bus","trolleybus","coach"]},"layer":"transit","class":"route","copy":["route>mode","ref","name","from","to","network","operator","colour"],"then":"chain_route_members","priority":85},
    {"id":"r080","geom":"rel","match":{"type":"route","route":"ferry"},"layer":"transit","class":"route","attrs":{"mode":"ferry"},"copy":["ref","name","operator","duration"],"then":"ferry_route_from_ways","priority":85},
    {"id":"r081","geom":"rel","match":{"type":"route_master"},"layer":"transit","class":"route_master","copy":["route_master>mode","ref","name","network","operator","colour"],"priority":84},
    {"id":"r082","geom":"way","match":{"route":"ferry"},"layer":"transit","class":"ferry_way","copy":["name","ref","operator","duration","motor_vehicle","motorcar","foot","bicycle"],"defaults":{"foot":"yes"},"priority":85},
    {"id":"r083","geom":"way","match":{"aerialway":["cable_car","gondola","mixed_lift","chair_lift"]},"layer":"transit","class":"route","attrs":{"mode":"aerial"},"copy":["aerialway>kind","name","occupancy","capacity"],"priority":80},
    {"id":"r084","geom":["node","area"],"match":{"aeroway":"aerodrome"},"layer":"aerodromes","class":"aerodrome","copy":["name","icao","iata","ele","aerodrome:type"],"priority":85},
    {"id":"r085","geom":"area","match":{"aeroway":"aerodrome"},"layer":"use","class":183,"priority":45},
    {"id":"r086","geom":"way","match":{"aeroway":"runway"},"layer":"structures","class":"runway","copy":["ref","width","surface","length"],"defaults":{"width":30,"surface":"asphalt"},"then":"buffer_by_width_and_register_runway","priority":85},
    {"id":"r087","geom":"way","match":{"aeroway":["taxiway","taxilane"]},"layer":"structures","class":"taxiway","copy":["ref","width","surface"],"defaults":{"width":15},"then":"buffer_by_width","priority":84},
    {"id":"r088","geom":"way","match":{"aeroway":"stopway"},"layer":"structures","class":"stopway","copy":["width"],"defaults":{"width":30},"then":"buffer_by_width","priority":84},
    {"id":"r089","geom":"area","match":{"aeroway":"apron"},"layer":"structures","class":"apron","copy":["surface"],"priority":84},
    {"id":"r090","geom":["node","area"],"match":{"aeroway":["hangar","terminal","tower"]},"layer":"buildings","class":"aeroway_building","copy":["aeroway>use","name","height","building:levels"],"defaults":{"height_hangar":12,"height_terminal":12,"height_tower":30},"priority":86},
    {"id":"r091","geom":["node","area"],"match":{"aeroway":["helipad","heliport"]},"layer":"structures","class":"helipad","copy":["name","ref"],"defaults":{"diameter":20},"priority":84},
    {"id":"r092","geom":"node","match":{"aeroway":["windsock","navigationaid","holding_position","parking_position","gate","fuel"]},"layer":"props","class":"aeroway_prop","copy":["aeroway>kind","ref"],"priority":60},
    {"id":"r093","geom":["way","area"],"match":{"aeroway":"highway_strip"},"layer":"roads","class":"primary","attrs":{"aeroway":"highway_strip"},"priority":60},
    {"id":"r094","geom":"way","match":{"waterway":"river"},"layer":"rivers","class":"river","copy":["name","width","intermittent","tunnel","boat"],"defaults":{"width":15},"then":"snap_drainage","priority":90},
    {"id":"r095","geom":"way","match":{"waterway":"stream"},"layer":"rivers","class":"stream","copy":["name","width","intermittent","tunnel"],"defaults":{"width":2},"then":"snap_drainage","priority":90},
    {"id":"r096","geom":"way","match":{"waterway":"tidal_channel"},"layer":"rivers","class":"tidal_channel","copy":["name","width"],"defaults":{"width":5},"priority":90},
    {"id":"r097","geom":"way","match":{"waterway":"canal"},"layer":"rivers","class":"canal","copy":["name","width","lock","boat","tunnel","bridge"],"defaults":{"width":15},"then":"flat_pounds_between_locks","priority":90},
    {"id":"r098","geom":"way","match":{"waterway":["drain","ditch"]},"layer":"rivers","class":"ditch","copy":["width","intermittent","tunnel"],"defaults":{"width":1.5,"depth":0.8},"priority":90},
    {"id":"r099","geom":"way","match":{"waterway":"pressurised"},"layer":"lines","class":"ln.penstock","copy":["location","diameter"],"priority":70},
    {"id":"r100","geom":"way","match":{"waterway":"fairway"},"layer":"transit","class":"shipping_lane","copy":["name","seamark:fairway:category"],"priority":70},
    {"id":"r101","geom":["node","area"],"match":{"waterway":["dock","boatyard"]},"layer":"water","class":"dock","copy":["waterway>kind","name"],"priority":88},
    {"id":"r102","geom":["way","area"],"match":{"waterway":"dam"},"layer":"structures","class":"dam","copy":["name","height","material"],"defaults":{"height":5},"then":"terrain_dam_crest","priority":88},
    {"id":"r103","geom":["node","way"],"match":{"waterway":"weir"},"layer":"structures","class":"weir","copy":["height"],"defaults":{"height":1.5},"priority":88},
    {"id":"r104","geom":"node","match":{"waterway":"waterfall"},"layer":"markers","class":"waterfall","copy":["name","height"],"then":"cliff_at_river","priority":80},
    {"id":"r105","geom":["node","way","area"],"match":{"waterway":"rapids"},"layer":"rivers","class":"rapids_section","priority":80},
    {"id":"r106","geom":["node","way"],"match":{"waterway":["lock_gate","sluice_gate","floodgate"]},"layer":"structures","class":"gate.water","copy":["waterway>kind"],"priority":85},
    {"id":"r107","geom":"node","match":{"waterway":["turning_point","water_point","fuel"]},"layer":"markers","class":"harbour_service","copy":["waterway>kind","maxlength"],"priority":60},
    {"id":"r108","geom":"area","match":{"natural":"water","water":["lake","reservoir","oxbow","lagoon"]},"layer":"water","class":"lake","copy":["name","ele","water>kind"],"priority":95},
    {"id":"r109","geom":"area","match":{"natural":"water","water":["pond","basin","stream_pool"]},"layer":"water","class":"pond","copy":["name","water>kind"],"priority":95},
    {"id":"r110","geom":"area","match":{"natural":"water","water":["river","canal"]},"layer":"water","class":"river_area","copy":["name"],"priority":95},
    {"id":"r111","geom":"area","match":{"natural":"water","water":"wastewater"},"layer":"use","class":209,"priority":60},
    {"id":"r112","geom":"area","match":{"natural":"water"},"layer":"water","class":"lake","copy":["name"],"priority":94},
    {"id":"r113","geom":"area","match":{"waterway":"riverbank"},"layer":"water","class":"river_area","attrs":{"legacy":true},"priority":94},
    {"id":"r114","geom":"way","match":{"natural":"coastline"},"layer":"water","class":"coastline","then":"assemble_coastline","priority":96},
    {"id":"r115","geom":"area","match":{"natural":"water"},"layer":"cover","class":1,"priority":95},
    {"id":"r116","geom":"area","match":{"natural":"wetland","wetland":["marsh","reedbed","wet_meadow"]},"layer":"use","class":140,"priority":70},
    {"id":"r117","geom":"area","match":{"natural":"wetland","wetland":"swamp"},"layer":"use","class":118,"priority":70},
    {"id":"r118","geom":"area","match":{"natural":"wetland","wetland":"bog"},"layer":"use","class":141,"priority":70},
    {"id":"r119","geom":"area","match":{"natural":"wetland","wetland":"fen"},"layer":"use","class":142,"priority":70},
    {"id":"r120","geom":"area","match":{"natural":"wetland"},"layer":"cover","class":2,"priority":70},
    {"id":"r121","geom":"area","match":{"natural":"wood","leaf_type":"needleleaved"},"layer":"cover","class":11,"priority":50},
    {"id":"r122","geom":"area","match":{"natural":"wood","leaf_type":"broadleaved"},"layer":"cover","class":10,"priority":50},
    {"id":"r123","geom":"area","match":{"natural":"wood"},"layer":"cover","class":12,"priority":49},
    {"id":"r124","geom":"area","match":{"natural":["scrub","heath"]},"layer":"cover","class":9,"priority":50},
    {"id":"r125","geom":"area","match":{"natural":"grassland"},"layer":"cover","class":6,"priority":50},
    {"id":"r126","geom":"area","match":{"natural":["beach","sand","dune"]},"layer":"cover","class":5,"priority":55},
    {"id":"r127","geom":"area","match":{"natural":["beach","dune"]},"layer":"use","class":160,"priority":55},
    {"id":"r128","geom":"area","match":{"natural":"bare_rock"},"layer":"cover","class":3,"priority":55},
    {"id":"r129","geom":"area","match":{"natural":["scree","shingle"]},"layer":"cover","class":4,"priority":55},
    {"id":"r130","geom":"area","match":{"natural":"glacier"},"layer":"cover","class":15,"priority":55},
    {"id":"r131","geom":"way","match":{"natural":"cliff"},"layer":"constraints","class":"cliff_line","copy":["height"],"attrs":{"face":"left"},"then":"chapter2_cliff_pipeline","priority":80},
    {"id":"r132","geom":"way","match":{"natural":["ridge","arete"]},"layer":"constraints","class":"ridge_line","attrs":{"soft":true},"priority":40},
    {"id":"r133","geom":"way","match":{"natural":"valley"},"layer":"constraints","class":"valley_line","attrs":{"soft":true},"priority":40},
    {"id":"r134","geom":"node","match":{"natural":["peak","saddle","volcano","hill"]},"layer":"markers","class":"spot_height","copy":["name","ele","natural>kind"],"then":"ele_check_or_constraint","priority":60},
    {"id":"r135","geom":"node","match":{"natural":["cave_entrance","spring","sinkhole"]},"layer":"markers","class":"discovery_seed","copy":["natural>kind","name"],"priority":60},
    {"id":"r136","geom":"node","match":{"natural":"tree"},"layer":"props","class":"tree.single","copy":["leaf_type","height","species","genus"],"defaults":{"height":12},"priority":50},
    {"id":"r137","geom":"way","match":{"natural":"tree_row"},"layer":"props","class":"tree.row","copy":["leaf_type","species"],"defaults":{"spacing_m":6},"priority":50},
    {"id":"r138","geom":"area","match":{"landuse":"residential"},"layer":"use","class":70,"then":"classify_residential_morphology","priority":20},
    {"id":"r139","geom":"area","match":{"landuse":"residential"},"layer":"cover","class":13,"priority":20},
    {"id":"r140","geom":"area","match":{"landuse":"retail"},"layer":"use","class":71,"then":"plaza_or_main_street","priority":40},
    {"id":"r141","geom":"area","match":{"landuse":"commercial"},"layer":"use","class":72,"priority":40},
    {"id":"r142","geom":"area","match":{"landuse":["retail","commercial","industrial"]},"layer":"cover","class":14,"priority":40},
    {"id":"r143","geom":"area","match":{"landuse":"industrial","industrial":["port","shipyard"]},"layer":"use","class":202,"priority":42},
    {"id":"r144","geom":"area","match":{"landuse":"industrial","industrial":["oil","fuel","depot"]},"layer":"use","class":206,"priority":42},
    {"id":"r145","geom":"area","match":{"landuse":"industrial","industrial":["warehouse","distributor"]},"layer":"use","class":51,"priority":41},
    {"id":"r146","geom":"area","match":{"landuse":"industrial"},"layer":"use","class":50,"then":"heavy_if_stacks_or_tanks","priority":40},
    {"id":"r147","geom":"area","match":{"landuse":"farmland","crop":["maize","corn"]},"layer":"use","class":80,"priority":41},
    {"id":"r148","geom":"area","match":{"landuse":"farmland","crop":["soy","soybean","soybeans"]},"layer":"use","class":81,"priority":41},
    {"id":"r149","geom":"area","match":{"landuse":"farmland","crop":["wheat","barley","oats","cereal"]},"layer":"use","class":82,"priority":41},
    {"id":"r150","geom":"area","match":{"landuse":"farmland"},"layer":"use","class":80,"then":"seeded_rotation_AG1_AG4","priority":40},
    {"id":"r151","geom":"area","match":{"landuse":"farmland"},"layer":"cover","class":8,"priority":40},
    {"id":"r152","geom":"area","match":{"landuse":"meadow"},"layer":"use","class":83,"priority":40},
    {"id":"r153","geom":"area","match":{"landuse":["meadow","grass","village_green"]},"layer":"cover","class":7,"priority":40},
    {"id":"r154","geom":"area","match":{"landuse":"orchard"},"layer":"use","class":85,"priority":40},
    {"id":"r155","geom":"area","match":{"landuse":"vineyard"},"layer":"use","class":86,"priority":40},
    {"id":"r156","geom":"area","match":{"landuse":"greenhouse_horticulture"},"layer":"use","class":87,"priority":40},
    {"id":"r157","geom":"area","match":{"landuse":"farmyard"},"layer":"use","class":90,"priority":40},
    {"id":"r158","geom":"area","match":{"landuse":"forest"},"layer":"use","class":111,"then":"plantation_if_rows","priority":40},
    {"id":"r159","geom":"area","match":{"landuse":"forest"},"layer":"cover","class":12,"priority":48},
    {"id":"r160","geom":"area","match":{"landuse":"quarry"},"layer":"use","class":94,"then":"pit_if_resource_sand_gravel","priority":40},
    {"id":"r161","geom":"area","match":{"landuse":"landfill"},"layer":"use","class":187,"priority":40},
    {"id":"r162","geom":"area","match":{"landuse":"cemetery"},"layer":"use","class":35,"priority":42},
    {"id":"r163","geom":"area","match":{"landuse":"religious"},"layer":"use","class":31,"priority":42},
    {"id":"r164","geom":"area","match":{"landuse":"railway"},"layer":"use","class":182,"then":"upgrade_rail_land_by_contents","priority":40},
    {"id":"r165","geom":"area","match":{"landuse":"military"},"layer":"use","class":223,"priority":40},
    {"id":"r166","geom":"area","match":{"landuse":["construction","brownfield"]},"layer":"cover","class":5,"attrs":{"note":"bare soil, cover 5 until a soil class exists"},"priority":40},
    {"id":"r167","geom":"area","match":{"landuse":"recreation_ground"},"layer":"use","class":33,"priority":40},
    {"id":"r168","geom":"area","match":{"landuse":"allotments"},"layer":"use","class":224,"priority":42},
    {"id":"r169","geom":"area","match":{"landuse":"basin","basin":["detention","retention","infiltration"]},"layer":"use","class":34,"priority":42},
    {"id":"r170","geom":"area","match":{"landuse":"basin","basin":"wastewater"},"layer":"use","class":186,"priority":42},
    {"id":"r171","geom":"area","match":{"landuse":"reservoir"},"layer":"water","class":"lake","attrs":{"legacy":true},"priority":94},
    {"id":"r172","geom":"area","match":{"landuse":"port"},"layer":"use","class":202,"priority":40},
    {"id":"r173","geom":"area","match":{"leisure":"park"},"layer":"use","class":33,"priority":60},
    {"id":"r174","geom":"area","match":{"leisure":["park","garden","golf_course","pitch","dog_park"]},"layer":"cover","class":7,"priority":58},
    {"id":"r175","geom":["node","area"],"match":{"leisure":"pitch"},"layer":"props","class":"sportsfield","copy":["sport","surface"],"priority":62},
    {"id":"r176","geom":["node","area"],"match":{"leisure":"playground"},"layer":"props","class":"playground","priority":62},
    {"id":"r177","geom":"area","match":{"leisure":"golf_course"},"layer":"use","class":95,"priority":60},
    {"id":"r178","geom":["node","area"],"match":{"leisure":"marina"},"layer":"use","class":190,"priority":60},
    {"id":"r179","geom":["node","way"],"match":{"leisure":"slipway"},"layer":"structures","class":"ramp.boat","defaults":{"grade":0.13,"width":6},"priority":70},
    {"id":"r180","geom":"area","match":{"leisure":["stadium","sports_centre","track"]},"layer":"use","class":32,"priority":60},
    {"id":"r181","geom":"area","match":{"leisure":"nature_reserve"},"layer":"markers","class":"region","attrs":{"protected":true},"copy":["name"],"priority":10},
    {"id":"r182","geom":["node","area"],"match":{"tourism":["camp_site","caravan_site"]},"layer":"use","class":96,"priority":60},
    {"id":"r183","geom":"area","match":{"amenity":["school","kindergarten"]},"layer":"use","class":30,"priority":60},
    {"id":"r184","geom":"area","match":{"amenity":["college","university"]},"layer":"use","class":75,"priority":60},
    {"id":"r185","geom":"area","match":{"amenity":"hospital"},"layer":"use","class":74,"priority":60},
    {"id":"r186","geom":["node","area"],"match":{"amenity":"place_of_worship"},"layer":"use","class":31,"copy":["religion","denomination","name"],"priority":61},
    {"id":"r187","geom":"area","match":{"amenity":"parking"},"layer":"structures","class":"parking","copy":["parking","capacity","surface"],"defaults":{"parking":"surface"},"priority":70},
    {"id":"r188","geom":["node","area"],"match":{"amenity":"fuel"},"layer":"use","class":44,"priority":62},
    {"id":"r189","geom":"area","match":{"amenity":"grave_yard"},"layer":"use","class":35,"priority":61},
    {"id":"r190","geom":["node","area"],"match":{"amenity":"ferry_terminal"},"layer":"use","class":201,"then":"make_ferry_stop","priority":62},
    {"id":"r191","geom":["node","area"],"match":{"amenity":"bus_station"},"layer":"use","class":198,"then":"make_bus_terminal_stop","priority":62},
    {"id":"r192","geom":["node","area"],"match":{"amenity":"waste_transfer_station"},"layer":"use","class":205,"priority":62},
    {"id":"r193","geom":["node","area"],"match":{"amenity":["community_centre","library","townhall","fire_station","police"]},"layer":"markers","class":"poi","copy":["amenity>poi","name"],"priority":50},
    {"id":"r194","geom":"node","match":{"amenity":["bench","waste_basket","bicycle_parking","drinking_water","post_box","telephone","toilets","shelter"]},"layer":"props","class":"street_furniture","copy":["amenity>kind"],"priority":50},
    {"id":"r195","geom":["node","area"],"match":{"amenity":"*"},"layer":"markers","class":"poi","copy":["amenity>poi","name"],"attrs":{"poi_prefix":"poi.amenity."},"priority":10},
    {"id":"r196","geom":["node","area"],"match":{"shop":"*"},"layer":"markers","class":"poi","copy":["shop>poi","name"],"attrs":{"poi_prefix":"poi.shop."},"then":"ground_floor_retail","priority":10},
    {"id":"r197","geom":["node","area"],"match":{"tourism":["attraction","viewpoint","museum","artwork"]},"layer":"markers","class":"poi","copy":["tourism>poi","name"],"attrs":{"poi_prefix":"poi.tourism."},"priority":12},
    {"id":"r198","geom":["node","area"],"match":{"historic":"*"},"layer":"markers","class":"discovery_seed","copy":["historic>kind","name"],"priority":12},
    {"id":"r199","geom":"area","match":{"building":"*"},"layer":"buildings","class":"building","copy":["building>type","height","min_height","building:levels","building:min_level","roof:shape","roof:height","roof:angle","roof:levels","roof:direction","roof:orientation","building:colour","roof:colour","building:material","roof:material","name","addr:housenumber","addr:street"],"then":"building_height_rules","priority":90},
    {"id":"r200","geom":"area","match":{"building:part":"*"},"layer":"buildings","class":"building_part","copy":["height","min_height","building:levels","building:min_level","roof:shape","roof:height","roof:angle","building:colour","roof:colour"],"then":"attach_part_to_outline","priority":91},
    {"id":"r201","geom":"rel","match":{"type":"building"},"layer":"buildings","class":"building_relation","then":"group_outline_and_parts","priority":91},
    {"id":"r202","geom":"area","match":{"building":"*"},"layer":"cover","class":14,"priority":90},
    {"id":"r203","geom":"area","match":{"building":["roof","carport"]},"layer":"buildings","class":"canopy","defaults":{"height":5,"min_height":4},"priority":91},
    {"id":"r204","geom":"area","match":{"building":"ruins"},"layer":"buildings","class":"ruin","defaults":{"height":3,"roof_shape":"none"},"then":"discovery_seed","priority":91},
    {"id":"r205","geom":"area","match":{"building":["storage_tank","silo","water_tower"]},"layer":"structures","class":"tank","copy":["building>kind","height","diameter","content"],"defaults":{"height_storage_tank":12,"height_silo":25,"height_water_tower":40},"priority":92},
    {"id":"r206","geom":"way","match":{"barrier":["fence","wall","hedge","retaining_wall","guard_rail","city_wall","jersey_barrier","kerb"]},"layer":"lines","class":"barrier","copy":["barrier>kind","height","material","fence_type"],"defaults":{"height_fence":1.5,"height_wall":2.0,"height_hedge":1.5,"height_retaining_wall":1.5,"height_guard_rail":0.8,"height_city_wall":6.0},"priority":70},
    {"id":"r207","geom":"node","match":{"barrier":["gate","lift_gate","bollard","stile","cattle_grid","block","toll_booth"]},"layer":"props","class":"barrier_point","copy":["barrier>kind","access"],"then":"restrict_road_access","priority":70},
    {"id":"r208","geom":["way","area"],"match":{"man_made":"pier"},"layer":"structures","class":"pier","copy":["width","name","floating"],"defaults":{"width":4},"priority":85},
    {"id":"r209","geom":["way","area"],"match":{"man_made":"quay"},"layer":"structures","class":"quay","priority":85},
    {"id":"r210","geom":["way","area"],"match":{"man_made":"breakwater"},"layer":"structures","class":"breakwater","defaults":{"width":12,"crest_m":3},"priority":85},
    {"id":"r211","geom":["way","area"],"match":{"man_made":"groyne"},"layer":"structures","class":"groyne","defaults":{"width":3},"priority":85},
    {"id":"r212","geom":"node","match":{"man_made":"lighthouse"},"layer":"structures","class":"lighthouse","copy":["height","name"],"defaults":{"height":15},"priority":85},
    {"id":"r213","geom":["node","area"],"match":{"man_made":"water_tower"},"layer":"structures","class":"water_tower","copy":["height","name"],"defaults":{"height":40,"diameter":15},"priority":85},
    {"id":"r214","geom":["node","area"],"match":{"man_made":["storage_tank","reservoir_covered"]},"layer":"structures","class":"tank","copy":["content","height","diameter"],"defaults":{"height":12,"diameter":20},"priority":85},
    {"id":"r215","geom":["node","area"],"match":{"man_made":"silo"},"layer":"structures","class":"silo","copy":["height","diameter","content"],"defaults":{"height":25,"diameter":8},"priority":85},
    {"id":"r216","geom":["node","area"],"match":{"man_made":["mast","tower"]},"layer":"structures","class":"tall_structure","copy":["man_made>kind","tower:type","tower:construction","height"],"defaults":{"height_mast":40,"height_tower":25},"then":"respect_height_cap_report_only","priority":85},
    {"id":"r217","geom":["node","area"],"match":{"man_made":"communications_tower"},"layer":"structures","class":"tall_structure","copy":["height","name"],"defaults":{"height":100},"priority":86},
    {"id":"r218","geom":"node","match":{"man_made":"chimney"},"layer":"structures","class":"chimney","copy":["height"],"defaults":{"height":40},"priority":85},
    {"id":"r219","geom":"way","match":{"man_made":"pipeline"},"layer":"lines","class":"ln.pipeline","copy":["substance","location","diameter","operator","name"],"defaults":{"location":"underground","row_m":20},"priority":80},
    {"id":"r220","geom":["node","area"],"match":{"man_made":"wastewater_plant"},"layer":"use","class":209,"priority":62},
    {"id":"r221","geom":["node","area"],"match":{"man_made":"water_works"},"layer":"use","class":208,"priority":62},
    {"id":"r222","geom":["node","area"],"match":{"man_made":"pumping_station"},"layer":"structures","class":"pumping_station","defaults":{"height":5},"priority":80},
    {"id":"r223","geom":["node","area"],"match":{"man_made":"clarifier"},"layer":"structures","class":"clarifier","defaults":{"diameter":30},"priority":80},
    {"id":"r224","geom":"way","match":{"man_made":["embankment","dyke"]},"layer":"constraints","class":"ridge_line","defaults":{"relief_m":2.5},"priority":60},
    {"id":"r225","geom":"way","match":{"man_made":"cutline"},"layer":"lines","class":"ln.cutline_seismic","defaults":{"width":6},"priority":60},
    {"id":"r226","geom":["node","area"],"match":{"man_made":"crane"},"layer":"props","class":"crane","copy":["crane:type","height"],"then":"sts_if_on_quay","priority":60},
    {"id":"r227","geom":["node","area"],"match":{"man_made":["works","kiln","cooling_tower","gasometer"]},"layer":"use","class":52,"priority":45},
    {"id":"r228","geom":"area","match":{"man_made":"bridge"},"layer":"structures","class":"bridge_outline","copy":["bridge:structure","name"],"then":"size_bridge_deck","priority":80},
    {"id":"r229","geom":"node","match":{"man_made":["street_cabinet","utility_pole","manhole","sewer_vent","flagpole","surveillance"]},"layer":"props","class":"utility_point","copy":["man_made>kind"],"priority":40},
    {"id":"r230","geom":"area","match":{"man_made":"clearcut"},"layer":"use","class":116,"priority":45},
    {"id":"r231","geom":"way","match":{"power":"line"},"layer":"lines","class":"ln.power_transmission","copy":["voltage","circuits","cables","name","ref","operator","layer"],"defaults":{"voltage":230000},"then":"towers_from_nodes_or_generate","priority":85},
    {"id":"r232","geom":"way","match":{"power":"minor_line"},"layer":"lines","class":"ln.power_distribution","copy":["voltage","cables"],"defaults":{"voltage":27600},"then":"poles_from_nodes_or_generate","priority":85},
    {"id":"r233","geom":"way","match":{"power":"cable"},"layer":"lines","class":"ln.power_cable","copy":["voltage","location"],"defaults":{"location":"underground"},"priority":80},
    {"id":"r234","geom":"node","match":{"power":"tower"},"layer":"lines","class":"line_support","attrs":{"support":"tower"},"copy":["structure","design","height","material"],"priority":85},
    {"id":"r235","geom":"node","match":{"power":"pole"},"layer":"lines","class":"line_support","attrs":{"support":"pole"},"copy":["material","height"],"defaults":{"height":12,"material":"wood"},"priority":85},
    {"id":"r236","geom":["node","area"],"match":{"power":"substation"},"layer":"structures","class":"substation","copy":["voltage","substation","name","operator"],"priority":85},
    {"id":"r237","geom":"area","match":{"power":"substation"},"layer":"use","class":184,"priority":62},
    {"id":"r238","geom":"area","match":{"power":"plant","plant:source":"nuclear"},"layer":"use","class":211,"priority":63},
    {"id":"r239","geom":"area","match":{"power":"plant","plant:source":"hydro"},"layer":"use","class":189,"priority":63},
    {"id":"r240","geom":"area","match":{"power":"plant","plant:source":["gas","oil","coal","biomass"]},"layer":"use","class":212,"priority":63},
    {"id":"r241","geom":"area","match":{"power":"plant","plant:source":"solar"},"layer":"use","class":99,"priority":63},
    {"id":"r242","geom":"area","match":{"power":"plant","plant:source":"wind"},"layer":"use","class":100,"priority":63},
    {"id":"r243","geom":"area","match":{"power":"plant","plant:source":"battery"},"layer":"use","class":213,"priority":63},
    {"id":"r244","geom":"node","match":{"power":"generator","generator:source":"wind"},"layer":"props","class":"turbine.wind","copy":["height","rotor:diameter","generator:output:electricity"],"defaults":{"height":100,"rotor:diameter":110},"priority":80},
    {"id":"r245","geom":"area","match":{"power":"generator","generator:source":"solar"},"layer":"structures","class":"solar_array","copy":["generator:method"],"priority":80},
    {"id":"r246","geom":"node","match":{"power":["transformer","switch","compensator","portal","terminal"]},"layer":"props","class":"power_equipment","copy":["power>kind"],"priority":60},
    {"id":"r247","geom":"node","match":{"pipeline":["marker","valve"]},"layer":"props","class":"marker.pipeline","copy":["pipeline>kind"],"priority":60},
    {"id":"r248","geom":"way","match":{"telecom":"*"},"layer":"lines","class":"ln.telecom","copy":["telecom>kind","location"],"defaults":{"location":"underground"},"priority":50},
    {"id":"r249","geom":["node","area"],"match":{"place":["city","town"]},"layer":"markers","class":"settlement","copy":["name","population","place>grade"],"priority":30},
    {"id":"r250","geom":["node","area"],"match":{"place":["village","hamlet","isolated_dwelling"]},"layer":"markers","class":"settlement","copy":["name","population","place>grade"],"priority":30},
    {"id":"r251","geom":["node","area"],"match":{"place":["suburb","neighbourhood","quarter","locality"]},"layer":"markers","class":"place_label","copy":["name","place>kind"],"priority":20},
    {"id":"r252","geom":["node","area"],"match":{"place":["island","islet"]},"layer":"markers","class":"place_label","copy":["name","place>kind"],"priority":20},
    {"id":"r253","geom":"area","match":{"place":"square"},"layer":"roads","class":"path","attrs":{"path_kind":"pedestrian","area":true},"copy":["name"],"priority":60},
    {"id":"r254","geom":"rel","match":{"boundary":"administrative","admin_level":["6","8","10"]},"layer":"markers","class":"region","copy":["name","admin_level"],"then":"township_bearing_hint","priority":5},
    {"id":"r255","geom":"node","match":{"seamark:type":"buoy_lateral"},"layer":"props","class":"buoy.lateral","copy":["seamark:buoy_lateral:category","seamark:buoy_lateral:colour","seamark:buoy_lateral:shape"],"priority":70},
    {"id":"r256","geom":"node","match":{"seamark:type":["buoy_cardinal","buoy_isolated_danger","buoy_safe_water","buoy_special_purpose"]},"layer":"props","class":"buoy.other","copy":["seamark:type>kind"],"priority":70},
    {"id":"r257","geom":"node","match":{"seamark:type":["light_major","light_minor","beacon_lateral","beacon_cardinal"]},"layer":"props","class":"light.nav","copy":["seamark:type>kind","seamark:light:colour","seamark:light:height"],"priority":70},
    {"id":"r258","geom":["node","area"],"match":{"seamark:type":["rock","wreck"]},"layer":"markers","class":"hazard","copy":["seamark:type>kind","seamark:wreck:depth"],"then":"block_navigable_mask","priority":70},
    {"id":"r259","geom":["node","area"],"match":{"harbour":"yes"},"layer":"markers","class":"harbour","copy":["name"],"priority":40},
    {"id":"r260","geom":"area","match":{"military":"*"},"layer":"use","class":223,"priority":39},
    {"id":"r261","geom":"area","match":{"area:highway":"*"},"layer":"skip","class":"road_surface_area","attrs":{"note":"used only to refine carriageway width"},"then":"refine_road_width","priority":10},
    {"id":"r262","geom":"node","match":{"addr:housenumber":"*","building":"!"},"layer":"buildings","class":"address_point","then":"attach_to_building_within_5m","priority":5}
  ]
}
```

This sketch has 262 rules (r001 to r262). Rules marked with `then` call a named step implemented in code; everything else is data. New rules are added by editing the file, and every import writes, per rule, how many elements it matched, so unused or over-broad rules show up in the report.
