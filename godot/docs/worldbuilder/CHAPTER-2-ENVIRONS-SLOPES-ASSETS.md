# World Builder, Chapter 2: what the world contains and how it is graded

Settlements, biomes, slopes and cliffs, and the asset and texture catalogue needed to compile a believable 3D map.

- Written 2026-10-23 for Robert Walter-Joseph. Companion to the chapter on architecture, file formats and terrain algorithms (written by another researcher).
- Sources are numbered [n] and listed in `SOURCES-2.md` in this folder.
- Marks used: **(src)** means the number is quoted from a source; **(design)** means a default chosen here for the tool, to be tuned by test; **(unverified)** means a commonly quoted figure that was not checked against a primary source during this research.

## 0. How to read this chapter

The World Builder produces an engine-neutral **world pack**. This chapter specifies the *vocabulary* that pack uses (the classes) and the *rules* that grade the land into those classes. A game (AeroSim in Godot, Squall Cove on the web) then maps each class to its own assets through a **style file** (section 5).

Four class families run through everything:

| Family | Example ids | Grades what | Section |
|---|---|---|---|
| Settlement and land-use class | `rural_farm`, `suburb_curvilinear`, `midrise_avenue`, `industrial` | built form, density, streets, lots | 1 |
| Road class | `arterial`, `collector`, `local`, `lane`, `rural_paved`, `track` | network, profile, junctions | 1.4 |
| Biome and cover class | `gl_mixedwood`, `marsh_emergent`, `dune_fore`, `alpine_meadow` | vegetation, ground, season, sound | 2 |
| Terrain feature class | `cliff`, `talus`, `gully`, `drumlin`, `bluff` | ground material, props, movement | 3 |

Every class resolves to **asset slots** (section 4). A slot is a named need, such as `tex.ground.grass_lawn` or `mesh.tree.acer_saccharum.lod0`. The gap finder (section 4.12) compares the slots a pack needs against what a game's kit supplies.

Two of Robert's projects already hold most of the right ideas, and this chapter builds on them rather than starting fresh:

- **Squall Cove** has a road class table, connection rules, a class-to-building "stitching" rule, and a parcels-first town pipeline with boundary types [7][8][10]. Those are adopted here as the core of the settlement generator, generalised beyond one game.
- **ProceduralMainStreet** has Toronto's mid-rise, tall building, townhouse and neighbourhood rules extracted into machine-readable specs, and a working Godot generator [1][2][3][4][5]. Those become the built-form envelopes in section 1.3.

### 0.1 Alignment with Chapter 1 (pack format)

Chapter 1 defines the pack files: a one-byte cover raster with 16 standard classes (ids 64 to 255 free for projects), `roads.json` with OSM-style road classes, `lots.geojson` and `buildings.geojson` with Overture-style attributes, and a game-side style map. This chapter's classes fit into that format as follows (proposed; to be agreed between the two chapters):

| This chapter | Where it lives in the Chapter 1 pack | Mapping |
|---|---|---|
| Road hierarchy (`expressway`, `arterial_major`, `arterial_minor`, `collector`, `local`, `lane`, `rural_paved`, `track`) | `roads.json` edge `class` (OSM style) plus a new edge attribute `hierarchy` | motorway = expressway; primary = arterial_major; secondary = arterial_minor; **add `tertiary` = collector and `unclassified` = rural_paved**; residential = local; service = lane or drive; track = track; path = path; rail = rail. Chapter 1's `width_m` is the carriageway; this chapter's ROW (property line to property line) goes in a new `row_m`. |
| Settlement and district classes (1.2) | `lots.geojson` property `use` plus a new `district` property; envelope rule in `zoning` | e.g. `district: "midrise_avenue"`, `zoning: {"envelope_rule": "toronto_midrise_2024", "row_m": 30}` |
| Biome classes (2.3) | cover ids 64 to 255 declared in `world.json`, or a separate `biome.u8.zlib` raster (preferred, so cover stays the 16 standard classes) | each biome declares its parent cover id: `gl_mixedwood` to 12, `gl_boreal` to 11, `gl_carolinian` to 10, `marsh`/`swamp`/`fen`/`bog` to 2, `gl_old_field` to 6, `gl_farm` to 8, `coastal_dune` to 5, `alpine` to 6 or 4 |
| Terrain features (3.4) | a new optional `feature.u8.zlib` raster plus cliff break lines in `markers` | cliff segments as polylines with height band and substrate |
| Slope classes (3.1) | derived by each game from height, or stored in `feature.u8` | Chapter 1 cover uses rock above 45 degrees and scree 35 to 45; this chapter uses scree 31 to 40, rock slope 40 to 55, cliff above 55. **Reconcile**: suggest cover 3 = slope above 40, cover 4 = 31 to 40 on loose substrate. |
| Style file (section 5) | Chapter 1's style map (section 6.2) | section 5 is a superset: same keys plus slot patterns, budgets per platform, palettes and allowed licences |

---

## 1. Settlement grading

### 1.1 The hierarchy

A settlement is graded on two axes: **size** (how many people, how far apart) and **form** (which district types it contains). Size picks the list of districts; form rules (1.2) fill them.

| Rank | Settlement | Population (design) | Typical districts it contains | Spacing to the next of the same rank (design, from Christaller k=3 [29]) |
|---|---|---|---|---|
| 0 | Farmstead / dispersed | 1 to 10 per farm | `rural_farm` | 0.4 to 1.5 km (one per concession lot) |
| 1 | Hamlet | 20 to 200 | crossroads cluster, church or store, `rural_farm` around | 7 km |
| 2 | Village | 200 to 3,000 | `main_street` (short), `suburb_inner` small grid, `park`, `cemetery`, mill or elevator | 12 km |
| 3 | Small town | 3,000 to 30,000 | `main_street`, `suburb_inner`, `suburb_outer_grid`, `suburb_curvilinear`, `strip_commercial`, `industrial`, `park`, `cemetery`, rail station, possibly `waterfront` | 21 km |
| 4 | City | 30,000 to 500,000 | all of rank 3 plus `midrise_avenue`, `campus`, larger `industrial`, `waterfront_port` | 36 km |
| 5 | Metropolis core | 500,000+ | all of the above plus `downtown_tower` | 63 km |

Notes:

- Christaller's marketing principle spaces same-rank places by a factor of the square root of 3 per rank, often quoted from a 7 km base (7, 12, 21 km) [29]. It is a simplification; the reason it is still useful is that it gives a spacing law that a generator can obey and a player reads as "plausible".
- **Game compression.** Real spacing is too sparse for a 4 km game map. A pack stores a `compression` factor (default 0.25 for flight sims, 0.1 for tactical sandboxes) that multiplies all inter-settlement distances but **never** multiplies street, lot or building dimensions. Players notice a 4 m wide house; they do not notice that two villages are 3 km apart rather than 12.
- **Size by rank (design).** Within a generated region, rank-size follows Zipf's rule as a default: population of the r-th largest place is about P1 / r. This is a common empirical regularity (unverified for any particular region) and is only a seed for variety.

### 1.2 District form rules

The three tables below are one table split for width. Values are defaults for a temperate Great Lakes (Ontario) context. Density can be computed from lot size, so the tool never needs to store density separately: **net dwellings per hectare = 10,000 / lot area (m²) x units per lot**.

Reference densities found in sources:

- Toronto's Neighbourhoods average **25 dwellings per net hectare** (17 in detached and semi-detached zones, 48 in townhouse and multiple zones), and **65 persons per net hectare** (47 and 113) [18].
- Prewar Toronto-area residential areas ran about **28 to 36 units per gross hectare**; late-1990s subdivisions about **10 to 15** (Neptis, quoted via search, original page now 404) [68].
- Provincial targets: **50 residents and jobs per gross hectare** for designated growth areas in large and fast-growing municipalities (PPS 2024, s. 2.3.1.5); **200 / 160 / 150** residents and jobs per hectare around subway / LRT or BRT / commuter rail stations within about 500 to 800 m (s. 2.4.2.1 and 2.4.2.2) [15]. Toronto's Official Plan sets **400 jobs and residents per hectare** for each Centre [16].

#### Table 1A. Density and built form

| Class id | Net dwellings/ha | FSI (floor space index) | Building types | Storeys (metres) | Typical roofs | Lot coverage |
|---|---|---|---|---|---|---|
| `rural_farm` | under 0.1 | under 0.01 | farmhouse, bank barn, drive shed, silo, machine shed, grain bins | house 1.5 to 2.5 (6 to 10 m); barn ridge 10 to 14 m; silo 15 to 25 m (design) | gable, gambrel barns, steel-clad sheds | under 1% of farm |
| `hamlet` | 2 to 5 | 0.05 to 0.1 | detached houses on large lots, church, general store, hall, garage | 1 to 2 (4 to 9 m) | gable, hip | 5 to 10% |
| `village` core | 8 to 15 | 0.15 to 0.3 | detached, semi, few main-street blocks | 1.5 to 2.5; main street 2 to 3 | gable, some flat with parapet on main street | 15 to 30% |
| `suburb_inner` (prewar grid with lanes) | 25 to 50 [18] | 0.5 to 1.0 | semi, row, detached on narrow lots, corner stores | 2 to 3 (8 to 11 m); zone caps 10 to 13 m [4] | front gable, cross gable, flat-roof rows | 35 to 50% |
| `suburb_outer_grid` (1950s to 70s) | 12 to 20 | 0.25 to 0.4 | bungalow, split-level, two-storey detached | 1 to 2 (5 to 9 m) | low hip, side gable | 20 to 30% |
| `suburb_curvilinear` (1980s on) | 10 to 25 [68] | 0.3 to 0.5 | two-storey detached, semi, townhouse rows on collectors | 2 (8 to 10 m) | hip with gables, complex | 30 to 45% |
| `suburb_culdesac` (bulb lots) | 8 to 15 | 0.25 to 0.4 | detached on pie lots | 2 | hip | 25 to 35% |
| `townhouse_block` (infill, collector frontage) | 40 to 75 | 0.8 to 1.5 | rows, stacked, back-to-back [3] | 2 to 4 (up to about 13 m) | flat, gable | 40 to 60% |
| `strip_commercial` | 0 | 0.15 to 0.35 | plaza, big box, pad sites, gas station, drive-through | 1 (5 to 10 m; big box 8 to 12 m) | flat with parapet, standing-seam on pads | 20 to 35% |
| `main_street` | 30 to 80 (units above shops) | 1.5 to 3.0 | heritage storefront rows on 5.5 to 9.5 m lots [5] | 2 to 4 (ground floor 4.5 m, upper 3.0 to 3.6 m) | flat with parapet and cornice, some gable fronts | 80 to 100% |
| `midrise_avenue` | 150 to 400 | 2.5 to 5.0 | mid-rise mixed use on consolidated lots | 5 to 14 (16.5 to 45 m), equals ROW width [1] | flat, mechanical penthouse up to 5 m [1] | 60 to 90% |
| `downtown_tower` | 400 to 1,500 | 6 to 15+ | tower on podium, slab office, heritage remnants | podium 3 to 7 (10.5 to 24 m); towers 15 to 60+ (47 to 182 m+) [2] | flat, mechanical screens, crowns | podium 80 to 100%, tower plate at most 750 m² [2] |
| `industrial` | 0 | 0.3 to 0.6 | warehouse, plant, yard, tanks, sheds | 1 to 2 (8 to 14 m clear height) | flat, low-slope, sawtooth (older), barrel | 35 to 55% |
| `campus` (school, college, hospital) | 0 (residences extra) | 0.3 to 1.5 | institutional blocks, quads, parking, sports fields | 2 to 8 | flat, some pitched | 15 to 35% |
| `park` | 0 | 0 to 0.02 | pavilion, washroom, playground, sports courts | 1 | gable, hip | 0 to 2% |
| `cemetery` | 0 | 0 to 0.01 | chapel, mausoleum, maintenance shed, monuments | 1 to 2 | gable | under 2% buildings; plots in sections |
| `waterfront_port` | 0 to 50 | 0.3 to 1.0 | warehouses, sheds, port buildings, fish plant, lighthouse, cranes | 1 to 4 | flat, gable, sawtooth | 30 to 60% |
| `waterfront_residential` | 15 to 150 | 0.3 to 3.0 | cottages (rural lake), condos (urban) | 1 to 2, or mid-rise | gable, flat | 15 to 50% |
| `informal` (optional) | 150 to 600+ | 1.0 to 2.5 | self-built 1 to 3 storey compounds | 1 to 3 (3 to 9 m) | flat concrete slab, corrugated sheet mono-pitch | 60 to 90% |

All values marked in the table without a source number are **(design)** defaults derived from lot size and building type, not quoted figures. Informal-settlement density varies enormously: one study of Lusaka reports 148 people per hectare in informal areas against 95 city-wide, while parts of inner Karachi exceed 4,000 people per hectare [65]; the default above assumes a mid-range case.

#### Table 1B. Streets, blocks and lots

ROW = right-of-way width (property line to property line). Spacing values are between parallel streets of that class.

| Class id | Network pattern | Street spacing / block size | ROW of frontage street | Lot frontage x depth | Front setback | Side / rear |
|---|---|---|---|---|---|---|
| `rural_farm` | Ontario concession grid: concession roads parallel, side roads every fifth lot | concessions about 1.34 km apart (66.67 chains); side roads about 3.0 km (5 lots of 30 chains) for 200-acre single-front lots [30] | 20.1 m road allowance (1 chain = 66 ft) (unverified as universal) | farm lot 603 x 1,341 m (30 x 66.67 chains, 81 ha) [30]; double-front townships use 100-acre half lots [30] | house 15 to 60 m (design) | barns 30 to 120 m behind house (design) |
| `hamlet` | crossroads, one or two short streets | n/a | 20 m | 30 to 60 x 60 to 80 m (private well and septic) (design) | 10 to 20 m | 3 to 10 m sides |
| `village` | linear along one road, or small grid | blocks 100 to 160 x 60 to 100 m | 20 m | 15 to 25 x 40 to 60 m | 6 to 10 m | 2 to 5 m |
| `suburb_inner` | rectilinear grid with rear lanes | blocks 150 to 250 m long x 60 to 80 m deep (two lot rows + lane) (design) | 15 to 20 m [17]; lanes 5 to 6 m [7] | 5.5 / 7 / 10 / 16 x 36 m (City test lots) [4] | 3 to 6 m, match neighbour average [3] | side 0 to 1.2 m (semis, rows); rear yard 7.5 m+ |
| `suburb_outer_grid` | regular grid, few lanes | blocks 200 to 300 x 70 to 90 m | 20 m | 15 x 33 to 40 m | 6 to 7.5 m | 1.2 to 1.8 m sides; rear 7.5 m+ |
| `suburb_curvilinear` | collector spine, loops returning to it, crescents, curve radius at least 75 m [7] | local junctions on a collector at least 60 m apart; collectors 400 to 800 m apart (design) | local 18 to 20 m; collector 20 to 26 m [17] | 12 to 18 x 28 to 35 m [7] | 6 m (garage door 6 m from property line [3]) | 1.2 m sides; rear 7.5 m |
| `suburb_culdesac` | stem 60 to 120 m (limit 150 to 300 m), one connection only [7] | at most about 25 lots per bulb (US practice, unverified for Ontario) [7] | 18 m stem; bulb paved radius 12 to 15 m [7] | pie lots: 12 m frontage at the bulb, 25 to 35 m depth [7] | 6 m | 1.2 m |
| `townhouse_block` | faces collectors; mews behind | blocks broken every 36 m (6 units at 6 m) [3] | 20 to 26 m | 4.5 to 8 m per unit (5.5 m minimum one-side entry; 6 m for front garage) [3] | 3.0 m (4.5 m with front garage) [3] | facing distance 11 / 13 / 15 m by face height [3]; rear 7.5 m + 45 degree plane [3] |
| `strip_commercial` | arterial frontage only, service lane behind | parcels 40 to 150 m deep | 30 to 36 m arterial | pad 30 x 40 m; plaza 100 to 250 x 80 to 150 m | big box 30 to 40 m behind front parking [7]; strip 1 to 2 m [7] | 0 to 10 m |
| `main_street` | one street, side streets every 80 to 160 m [5] | blocks 80 to 160 m along the street | 20 m (Toronto Avenues 20 to 36 m) [1][6] | 5.5 to 9.5 x 30 to 40 m [5] | 0 m (sidewalk zone 6 m curb to building [1]) | 0 sides; lane behind 5 to 6 m |
| `midrise_avenue` | arterial spine, grid behind | 215 to 400 m between signals [17] | 20 / 27 / 30 / 36 / 45 m [1] | consolidated: 18 to 60 m frontage x 30 to 37 m depth (ideal depth by ROW [1]) | 0 to 6 m to make a 6 m sidewalk zone [1] | rear 7.5 m (lane counts) [1] |
| `downtown_tower` | fine grid, lanes, PATH-style links | blocks 60 to 120 m | 20 to 30 m (some 45 m) [17] | tower site about 50 x 45 m minimum for a 750 m² plate after setbacks [2] | 0 to 6 m (6 m sidewalk zone) [2] | tower 12.5 m from side and rear lines; 25 m between towers [2] |
| `industrial` | large grid or loop, truck turning | blocks 250 to 500 m | 26 to 30 m | 0.4 to 4 ha; frontage 40 to 150 m | 9 to 15 m (design) | 6 to 15 m; truck court 35 to 40 m deep (design) |
| `campus` | internal loop road + paths | superblock 200 to 600 m | 20 to 26 m | single parcel 2 to 50 ha | 10 to 30 m | n/a |
| `park` | path network, 1 entrance per 100 to 150 m of frontage (design) | neighbourhood park 0.5 to 3 ha within 400 to 500 m walk (design) | any | n/a | n/a | n/a |
| `cemetery` | grid or curvilinear drives 4 to 6 m | sections 30 to 60 m | 20 m | burial plot about 1.2 x 2.4 m (unverified), rows 1 m apart | n/a | perimeter wall or fence |
| `waterfront_port` | quay road along the water, collectors inland [7] | n/a | quay road 7 to 9 m paved [7] | 30 to 100 m deep warehouse lots | 0 to 10 m [7] | apron 15 to 30 m at quay (design) |
| `informal` | organic paths, irregular blocks | footpaths 1.5 to 4 m, vehicle access 4 to 8 m (design) | n/a | 6 x 10 to 10 x 15 m plots (design) | 0 | 0 |

#### Table 1C. Landscape, trees and parking

| Class id | Tree canopy target | Street trees | Sidewalks | Parking | Transition to neighbours |
|---|---|---|---|---|---|
| `rural_farm` | 5 to 25% (woodlot at back of lot, fencerows, windbreak) (design) | none; fencerow trees irregular 5 to 15 m | none; gravel shoulders, ditches both sides [7] | farmyard gravel | hedgerow or wire fence to fields; woodlot to forest |
| `hamlet` / `village` | 25 to 40% | 10 to 15 m spacing, irregular | one side, 1.5 m, or none | driveways, main-street angle or parallel | edge of town: last lots face fields, no fence |
| `suburb_inner` | 30 to 40% (Toronto city-wide 28 to 31%, target 40% [20]) | 8 to 10 m on boulevard (design; the TGS sets soil, not spacing: at least 30 m³ soil per tree [19]) | both sides, 1.5 to 2.1 m clear [1] | lane garages, front pads | to main street: rear lane plus 45 degree plane [6] |
| `suburb_outer_grid` | 25 to 35% | 10 to 12 m, one per lot | one or both sides | double driveway, garage | to arterial: rear-lot fence or noise wall |
| `suburb_curvilinear` | 15 to 25% when young, 30% at maturity (design) | one per lot, 10 to 15 m | both sides on collectors, one side on locals [7] | 2-car garage, 6 m driveway | reverse lots back onto arterials with 2 m noise wall (design) |
| `townhouse_block` | 20 to 30% | 8 to 10 m | both sides | rear lane garages or underground [3] | 45 degree plane and 7.5 m rear to Neighbourhoods [3] |
| `strip_commercial` | 5 to 10% (islands) | 10 to 15 m along frontage, if any | arterial sidewalk 2 to 3 m | surface lot in front; stall 2.6 x 5.6 m (unverified standard), 6.0 m aisle [66] | rear service lane and fence to housing |
| `main_street` | 10 to 20% | 6 to 10 m in pits or trenches, 1.5 x 1.5 m openings [19] | 6 m sidewalk zone: 2.1 m clearway, 1.9 m planter [1] | on-street parallel, rear lots | lane and 7.5 m rear setback to houses [1] |
| `midrise_avenue` | 10 to 20% | 8 m (design), trees 3 to 5 m from building face [1] | 6 m zone [1] | underground | rear: 7.5 m setback, 2.5 m step-back at 7th storey [1] |
| `downtown_tower` | 5 to 15% | 8 m where soil allows | 6 m+ [2] | underground, few surface | 45 degree plane to Neighbourhoods, tower 20 m back [2] |
| `industrial` | 5 to 15% | sparse, 15 m | often none | large truck courts, employee lots | landscape buffer 6 to 15 m and berm to housing (design) |
| `campus` | 20 to 40% | 10 to 15 m allées | path network | lots at edge | open lawn edge |
| `park` | 30 to 60% | path trees 10 to 15 m | paths 2 to 4 m | small lot, 1 per 3 to 5 ha (design) | open edge, low rail [8] |
| `cemetery` | 30 to 50% (specimen trees) | drive trees 12 to 20 m | drives only | along drives | stone wall or iron fence |
| `waterfront_port` | under 5% | none | quay edge | apron, container stacks | security fence to town [8] |
| `informal` | under 5% | none | none | none | abrupt edge to formal city or open land |

### 1.3 Toronto built-form envelopes as computable rules

These are Toronto **guidelines**, not zoning, and they read "generally" and "should" [1][2]. The tool uses them as the default envelope for the Great Lakes urban style and exposes each number as a parameter. All are written as **height limits h(x, y) over the lot**, so an envelope is just the minimum of several functions, then snapped to whole storeys. This is how ProceduralMainStreet already behaves [5].

Coordinates: `d_f` is distance behind the front property line, `d_r` is distance in front of the rear property line (plus any public lane width behind, which counts toward rear setbacks [1][6]), `d_s` is distance from the side lot line. Storey heights: ground floor at least 4.5 m; upper floors 3.0 m residential and 3.6 m commercial (tool defaults consistent with the guideline tables) [1][2][6].

#### 1.3.1 Mid-rise (Mid-Rise Building Design Guidelines, 2024 draft) [1]

```
H_max        = min(ROW, 45)                  # 1:1 height to ROW; Table 1: 20/27/30/36/45 m ROW -> 6/8/9/11/14 storeys
streetwall   = clamp(0.8 * ROW, 10.5, ROW < 27 ? 20.0 : 25.5)
front        : vertical at the setback line up to streetwall, then step back >= 3.0 m
               setback line = max(0, 6.0 - existing_boulevard)  # 6 m sidewalk zone curb to building
rear         : building face >= 7.5 m from rear lot line (lane counts)
               if height > 20 m: step back >= 2.5 m at the 7th storey
               alternative: 10 m setback and no rear step-backs
               beside a park: 10 m setback + 2.5 m step-back between storeys 3 and 7
side         : 0 m within streetwall on main streets; >= 5.5 m above streetwall when > 6 storeys
facades      : break frontages longer than 60 m
penthouse    : up to +5 m, inside a 1:1 line from the roof edge
sun test     : >= 5 consecutive hours of sun on the opposite boulevard, Mar 21 and Sep 21,
               window generally 9:18 to 18:18
ideal depth  : ROW 20/27/30/36/45 m -> lot depth 30/34/34/36/37 m
```

#### 1.3.2 Mid-rise, 2010 Avenues and Mid-Rise Buildings Study (angular-plane version) [6]

Kept because many approved Avenue studies and existing buildings follow it, and because angular planes are easy to compute and to show.

```
H_max        = ROW                            # Table 3: 20 m -> 6 st (19.5 m); 27 -> 8 (25.5); 30 -> 9 (28.5); 36 -> 11 (34.5)
min height   = 10.5 m (3 storeys) streetwall
front plane  : h <= 0.8 * ROW + d_f           # 45 degrees from 80% of ROW at the front property line
deep lot     : (depth > 32.6 / 41.0 / 44.6 / 51.8 m for ROW 20 / 27 / 30 / 36)
               face >= 7.5 m from rear line, and h <= d_r   # 45 degrees from the rear property line at grade, to 1:1
shallow lot  : face >= 7.5 m, and h <= 10.5 + (d_r - 7.5)   # 45 degrees from 10.5 m at the 7.5 m line
overlook     : principal windows >= 10 m from rear line; no balconies below 10.5 m on the rear
```

Worked example (30 m ROW, deep lot 50 m): streetwall up to 24 m at the front line; above that the face moves back 1 m per metre of height; the building tops out at 30 m, which the front plane allows from d_f = 6 m; the rear plane allows 30 m only from d_r = 30 m, so the top floor is the band between d_f = 6 m and d_r = 30 m, that is 14 m deep. ProceduralMainStreet's `min_floorplate_depth` stops adding storeys when this band gets too thin [5].

#### 1.3.3 Tall buildings (Tall Building Design Guidelines 2013, Downtown supplement) [2]

```
tall         : height > adjacent ROW width
podium       = clamp(0.8 * ROW, 10.5, 24)     # optional second tier up to 1.0 * ROW, still <= 24, with a >= 3 m step
canyon mode  : Downtown canyon streets build to 47 / 62 / 77 m instead
tower        : step back >= 3 m from podium face on every street, park and open-space frontage (balconies included)
               >= 12.5 m from side and rear lot lines (or the centre line of an abutting lane)
               >= 25 m wall to wall from any other tower on the site
               floor plate <= 750 m2 (excluding balconies)
               up to 1/3 of the frontage may come straight to grade (not on Yonge)
transition   : 45 degree angular plane from the property line of an abutting Neighbourhood
               Downtown: tower >= 20 m from a lower-scale neighbourhood lot line
sun          : 5 hours on the opposite sidewalk (podium); Downtown signature parks: no new net shadow 10:00 to 16:00 Sep 21
mechanical   : up to 5 m excluded
validity     : inset the lot by 12.5 m (side, rear) and 3 m (fronts); if the remaining area cannot hold a
               viable plate (suggest 400 m2, design), fall back to mid-rise
```

Downtown height bands are 47 to 77 m up to 137 m and unlimited, by High Street segment; subway corners may add about 30 m [2]. For a generated downtown the tool draws tower heights from a band tied to distance from the core and to transit nodes (design).

#### 1.3.4 Low-rise and neighbourhood infill [3][4]

```
townhouse    : 2 to 4 storeys; rear >= 7.5 m and under a 45 degree plane from the rear property line [3]
               upper storeys under a 45 degree plane from the top of the main front wall [3]
               facing distance by main face height H: < 9.5 m -> 11 m; 9.5 to 11.5 m -> 13 m; > 11.5 m -> 15 m (+1 m with sunken entries)
               break rows every 36 m
multiplex    : 10 m height minimum citywide; depth 17 m (19 m on deep lots); no storey cap [4]
garden suite : height 4.0 m (6.3 m if >= 7.5 m from house); separation 4.0 / 7.5 m; GFA <= 60 m2 one storey, 120 m2 two [4]
laneway suite: height 4.0 / 6.3 m; footprint <= 10 x 8 m; separation 4.0 / 7.5 m [4]
landscape    : graded slopes <= 33% (3:1); retaining walls <= 1.0 m [3]
```

#### 1.3.5 Using the envelopes outside Toronto

The envelopes are style-agnostic geometry. A pack records `envelope_rule: toronto_midrise_2024 | toronto_avenues_2010 | toronto_tall_2013 | generic_far` per district so that a non-Toronto world can use a simpler rule (`generic_far`: height cap plus FSI target plus setbacks). The streetwall-to-ROW ratio of about 0.8 to 1.0 is worth keeping everywhere, because it is what makes a street read as a "street" rather than a road through buildings, and it is what keeps sun on the sidewalk [1][6].

### 1.4 Road classes (adopted from Squall Cove, with Toronto checks)

Squall Cove's class table [7] is adopted as the pack's road vocabulary. Toronto's road classification criteria [17] confirm the ranges:

| Class | ROW | Lanes | Daily volume | Speed | Signal spacing | Grade limit |
|---|---|---|---|---|---|---|
| `expressway` | over 45 m | 4+ | over 40,000 | 80 to 100 km/h | grade separated | 4 to 5% (design) |
| `arterial_major` | 20 to 45 m (new: wider) | 4+ | over 20,000 | 50 to 60 | 215 to 400 m | 8% [10] |
| `arterial_minor` | 20 to 30 m | 2 to 4 | 8,000 to 20,000 | 40 to 60 | 215 to 400 m | 8% |
| `collector` | 20 to 27 m | 2 | 2,500 to 8,000 | 40 to 50 | 215 to 400 m | 10% (design) |
| `local` | 15 to 22 m | 1 to 2 | under 2,500 | 40 to 50 | 0 to 150 m | 12% [10] |
| `lane` | 5 to 6 m | 1 | n/a | n/a | n/a | 12% |
| `rural_paved` | 20 m allowance; 7 m paved [7] | 2 | n/a | 60 to 80 | n/a | 10% |
| `track` (gravel or farm) | 4 to 5 m [7] | 1 | n/a | n/a | n/a | 18% [10] |
| `rail_main` | 30 m corridor (design) | 1 to 2 tracks | n/a | n/a | n/a | 1.0 to 1.5% ruling grade (unverified) |

Volumes, speeds, spacing and ROW from [17]; asphalt widths, profiles and the connection rules (up and down one class at a time, cul-de-sacs terminal, loops return, junction angles 75 to 105 degrees and never below 60) from [7].

### 1.5 The seed generator: placing settlements, growing roads, parcelling, assigning use

Literature, and what is practical to take:

| Method | What it does | Take it? |
|---|---|---|
| Parish and Mueller 2001, extended L-systems [21] | grows highways and streets from population density and land/water maps; each proposed segment is checked against **local constraints** (water, slope, snapping to nearby junctions) | **Yes, the local-constraint idea**: every proposed road segment is tested and either accepted, shortened, snapped to a node within a radius, or rejected. Skip the L-system formalism. |
| Chen et al. 2008, tensor fields [22] | a field of two orthogonal directions (grid, radial, boundary-following) steers streamline tracing; easy to blend a grid core with a coast-following edge | **Yes, for street orientation inside settlements**, especially to make grids bend to coasts and rivers. |
| Kelly and McCabe 2006 survey; CityGen [23] | road network first, then buildings in the cells | **Yes, the order**: network, blocks, parcels, buildings. Same as Squall Cove's pipeline [8]. |
| Vanegas et al. 2012, parcels [24] | OBB subdivision for regular blocks, straight-skeleton subdivision for irregular ones; parcels must front a street | **Yes**: OBB for grid blocks (fast, robust), skeleton for curvilinear and odd blocks. |
| CityEngine CGA [25] | shape grammar: extrude a lot, split into facade, floors and bays | **Yes, as the building-dressing idea**, executed by each game, not by the pack (the pack stores the envelope and typology, not the facade). |
| Townscaper / Stalberg [26] | irregular quad grid plus wave-function-collapse tile matching of modular pieces | **For the style layer only**: a low-poly or toy style can rebuild buildings from modular tiles by adjacency rules. |
| Watabou city generator [27] | Voronoi wards, walls, outskirts; later straight-skeleton lots | **Reference for old-town or medieval styles**, not the default. |
| Red Blob polygon maps, mapgen4 [28] | elevation, moisture, Whittaker lookup on a Voronoi mesh | **Yes, for the biome lookup idea** (section 2). |
| Horizon Zero Dawn GPU placement [54] | density maps per placement layer, deterministic and locally stable, artist-directable | **Yes, for vegetation and prop scatter**: the pack stores densities and rules; the game scatters. |

#### 1.5.1 Settlement placement (siting score)

For every candidate cell (default 50 m cells), compute a score; place settlements greedily by score with a Poisson-disk minimum spacing by rank (1.1, times the compression factor).

```
score = 3.0 * flat(slope_mean_250m < 5%)          # flat land, graded 1 at 0-2%, 0 at >= 8%
      + 2.5 * water_access                         # river within 300 m, lake or sea shore within 500 m, but not in it
      + 2.0 * crossing                             # river narrowest point (width < 40 m) or confluence within 500 m
      + 2.0 * harbour                              # coast cell whose 2 km fetch is blocked in >= 270 degrees of bearing
      + 1.5 * route_node                           # on a least-cost corridor between two existing settlements (after first pass)
      + 1.0 * soil                                 # biome or soil class good for crops (section 2)
      + 0.5 * defence                              # hilltop or river bend; only for "old" or "military" style
      - 4.0 * floodplain                           # height above nearest drainage (HAND) < 2 m
      - 3.0 * wetland                              # TWI high and slope < 2%
      - 3.0 * steep                                # slope_mean_250m > 15%
      - 2.0 * altitude                             # within 300 m of the tree line or above it
```

Weights are **(design)**. The terms are the classic siting factors (water supply, bridging point, harbour, route centrality, defence, avoidance of flood land); Far Cry 5's team describes the same kind of reasoning for nature (grassland on exposed hills, forest in valleys and on north faces) [55]. Rules after placement:

1. The highest-score site becomes rank 4 or 5 (by map size); then ranks fall by score and spacing.
2. Ports require `harbour > 0.5`. River towns snap their centre to the crossing point.
3. A settlement's footprint grows outward from the centre by district rings (core, inner, outer) and stops at slope > 15%, floodplain, wetland, or water. Hills are avoided by the ring, not by the whole town, so a town wraps around a hill and the hill becomes a park or cemetery (design).
4. Farmland fills the remaining flat to rolling land (slope under 10%) within the agricultural biomes; forest keeps steep land, wet land and the back of farm lots (the classic Ontario woodlot pattern; design).

#### 1.5.2 Road network growth

1. **Inter-settlement links.** Build a Gabriel graph (or relative-neighbourhood graph) of settlements; keep its minimum spanning tree plus every edge whose detour ratio without it exceeds 1.4 (design). Route each kept edge by A* on a cost surface: base 1, plus `k * grade^2` above half the class grade limit, impassable above the limit, water impassable except at bridge sites, wetland x4, forest x1.5. Class: rank 4 to 5 pairs get `expressway` or `arterial_major`, rank 2 to 3 pairs `rural_paved`, rank 0 to 1 `track`.
2. **Rural grid.** In `rural_farm` areas lay a concession grid aligned to the dominant direction of the nearest major road or shoreline (that is how Ontario townships were surveyed against a base line): concession roads every 1.34 km, side roads every 3.0 km (single front) [30]; jog side roads at concession lines by 0 to 20 m (survey error character, [30]). Drop grid roads that cross water or slope over 18%; a dropped road becomes an unopened road allowance (kept as a hedgerow line).
3. **Inside settlements.** Build a tensor field from: a grid basis aligned to the main road (weight 1), a radial basis at the centre for villages and old towns (weight 0.5), and boundary-following bases along coast and river (weight decaying over 200 m). Trace arterials first at 400 to 800 m spacing, collectors at 200 to 400 m, locals at the block depth of the district (60 to 100 m between parallel locals; 150 to 250 m between cross streets) [7][22]. Apply Parish and Mueller local constraints on every segment: snap to a node within 15 m, end at a crossing segment, reject if it enters water or exceeds the grade limit, shorten to the last valid point [21].
4. **Junction legality.** Enforce Squall Cove's rules: one class step per connection, angles at least 60 degrees, spacing at least 25 m between junctions on one street, opposite minor streets aligned or offset at least 40 m, cul-de-sacs attach to one road only [7].
5. **Bridges, culverts and fords.** Where a road crosses water: if flow accumulation implies a channel narrower than 3 m, a **culvert**; 3 to 15 m, a short bridge; over 15 m, a span bridge; rural tracks over shallow wide streams may ford. Approach within plus or minus 20 degrees of perpendicular to the channel (design). Channel width can be estimated from discharge by downstream hydraulic geometry (width proportional to discharge to the power of about 0.5) [51], and discharge is roughly proportional to drainage area in a uniform climate (design simplification).
6. **Rail.** Rail is routed before local streets with a grade limit of 1.0 to 1.5% (unverified ruling grade) and curve radius at least 400 m (design); it follows valleys, crosses roads with level crossings on locals and grade separation on arterials, and every rank 3+ settlement on its line gets a station at its edge, which seeds an industrial district alongside.

#### 1.5.3 Blocks and parcels

1. Blocks are the faces of the planar road graph, inset by half the ROW [8].
2. Small or awkward faces (area under 1,500 m², or shape compactness under 0.3) become `park`, plaza or parking, never buildings [7][8].
3. Parcels: OBB subdivision for blocks whose OBB fill ratio is above 0.85; straight-skeleton subdivision otherwise [24]. Target frontage and depth from Table 1B, with plus or minus 15% jitter, and the rule that every parcel fronts exactly one street (corner lots: two frontages, one primary) [8].
4. Lot pieces (yards, drives, paths, fences) are derived from the parcel, never from the building; each shared boundary gets one fence run owned by one side; the treatment comes from what lies across the edge (neighbour, road, lane, field, forest, water, slope, rail, restricted area) [8].

#### 1.5.4 Land-use assignment

Squall Cove's stitching rule [7] generalises well: use follows the class of the street a parcel fronts and its distance from the nearest arterial or centre.

| Fronts | Within 0 to 150 m of centre or node | 150 to 500 m | Beyond 500 m |
|---|---|---|---|
| arterial | `downtown_tower` (rank 5), `midrise_avenue` (rank 4), `main_street` (ranks 2 to 3) | `midrise_avenue` or `strip_commercial` | `strip_commercial`, `industrial` near rail |
| collector | `main_street` corners, `townhouse_block` | `townhouse_block`, schools, parks | `suburb_curvilinear` |
| local | `suburb_inner` | `suburb_inner` or `suburb_outer_grid` | `suburb_curvilinear`, `suburb_culdesac` |
| rural road | `hamlet` lots near crossroads | `rural_farm` | `rural_farm` |
| quay or dock road | `waterfront_port` | `waterfront_port` or `industrial` | `waterfront_residential` |

Era is a second dial: distance from the historic centre maps to construction era (prewar inner ring, postwar grid, curvilinear outer), which picks lot sizes and roof types (Table 1A). Every rank 2+ settlement gets at least one `park` per 400 m walking radius and one `cemetery` at its edge on a gentle slope (design).

### 1.6 Transitions between classes

The visual failure of most generated cities is the seam between districts. Rules (design, grounded in [1][2][3][6]):

- **Height steps at most 1:2 across a street or lane**, and use the envelope rules (45 degree planes, 7.5 m rear setbacks) where tall meets low.
- **Back-to-back, not face-to-back.** Districts meet at rear lot lines or lanes, not across a front street, unless the street is an arterial.
- **Industrial to residential**: 6 to 15 m planted buffer plus fence; never truck courts facing houses.
- **Town to farm**: the last row of lots faces fields with no fence or a rail fence; field edges get a hedgerow; the road changes profile (kerb to ditch) at the town limit.
- **Forest edge**: a 10 to 30 m band of shrubs and young trees outside the forest canopy (the "mantle"), never a straight tree wall (design).

---

## 2. Biomes and environs

### 2.1 The grading model

Inputs per terrain cell (all derivable from a heightmap plus a climate preset):

| Input | Symbol | How obtained |
|---|---|---|
| Mean annual temperature at sea level | T0 | climate preset (Toronto about 9 C, unverified) |
| Lapse rate | L | 6.5 C per km of elevation (standard atmosphere); use 5.5 C/km for the growing season (design) |
| Cell temperature | T | T0 - L * z/1000 + aspect_offset |
| Aspect offset | | on slopes > 15 degrees: north-facing -1.5 C, south-facing +1.5 C in the northern mid-latitudes (design; north faces hold moisture and denser forest [55]) |
| Annual precipitation | P | preset plus orographic term: +10% per 100 m rise on windward slopes, -20% in lee (design) |
| Wetness | TWI | topographic wetness index ln(a / tan b), a = upslope area per unit contour, b = slope |
| Height above nearest drainage | HAND | from the flow network |
| Distance to water | dw | from water masks |
| Distance to sea and exposure | ds | salt spray and wind exposure on coasts |
| Substrate | soil | preset map or inferred: rock where slope > 40 degrees or terrain feature = cliff / outcrop; sand on dunes and beaches; peat in fens and bogs; till elsewhere |

**Decision order** (first match wins):

1. **Water**: open water by depth band (deep, shallow, littoral).
2. **Ice and snow**: above the snow line.
3. **Alpine**: above the tree line.
4. **Wetland**: TWI high and slope < 2% and HAND < 1 m (bog or fen if cold and peat; marsh if fluctuating water; swamp if wooded).
5. **Shore and dune**: within the shoreline band (2.4).
6. **Rock and cliff**: from section 3 terrain features.
7. **Climatic biome**: Whittaker-style lookup on (T, P) (2.2).
8. **Land use overlay**: settlements and farms replace the natural cover where section 1 says so; the natural biome still sets hedgerow, woodlot, street tree and park species.

Whittaker plotted biomes against mean annual temperature and precipitation; the boundaries are approximate, not sharp [31]. Holdridge adds potential evapotranspiration (aridity) as a third axis and uses biotemperature (temperatures below 0 C and above 30 C counted as 0) [32]. Red Blob's map generator uses exactly this kind of lookup on elevation and moisture for games [28]. The WWF scheme groups the world's 867 ecoregions into 14 biomes [33] and is the reference for naming.

**Tree line.** Use the global climate rule: the tree line sits where the mean growing-season temperature is about **6.4 C** (season at least 94 days with daily mean above 0.9 C) [34]. In practice: `z_treeline = (T_gs0 - 6.4) / 0.0055` metres, where T_gs0 is the growing-season mean at sea level. With a temperate T_gs0 of about 17 C this gives about 1,900 m; local tree lines vary (the global model fits poorly in some semi-arid ranges [34]). Put a **krummholz band** 100 to 200 m below the tree line where tree height falls linearly to 1 m and spacing doubles (design).

**Snow line.** Climatic snow line about 4,500 to 5,000 m near the equator and roughly 800 to 3,200 m in the temperate zone, falling to sea level toward the poles [35]. Default formula (design, fits those ranges): `z_snow = 5000 - 75 * max(0, |latitude| - 20)` metres, clamped at 0. Seasonal snow in winter presets reaches the valley floor in the Great Lakes region; the season, not the snow line, decides it there.

### 2.2 Climatic lookup (world set)

Bands below are **approximations** of the Whittaker diagram for code [31]; tune per world.

| T (mean annual C) | P under 250 mm | 250 to 500 | 500 to 1,000 | 1,000 to 2,000 | over 2,000 |
|---|---|---|---|---|---|
| under -5 | `tundra` / polar desert | `tundra` | `tundra` | `tundra` | `tundra` |
| -5 to 3 | `cold_desert` | `boreal_open` (taiga woodland) | `boreal` | `boreal` | `boreal` |
| 3 to 12 | `cold_desert` / `steppe` | `grassland` (prairie) | `temperate_deciduous` or `temperate_mixed` | `temperate_mixed` | `temperate_rainforest` |
| 12 to 20 | `desert` | `grassland` or `mediterranean` (if summer precipitation < 30% of annual) | `mediterranean` or `temperate_deciduous` | `temperate_deciduous` (warm) / subtropical forest | `subtropical_rainforest` |
| over 20 | `desert` | `savanna` / dry shrubland | `savanna` | `tropical_seasonal` | `tropical_rainforest` |

Special overlays not on the climate grid: `wetland`, `coastal_dune`, `alpine`, `island_archipelago` (a coastal preset, 2.3), `volcanic` (a substrate preset, 2.3).

### 2.3 Biome profiles

Heights and spacing are for mature trees; "spacing" is centre to centre in mature closed stands. Ground colours are albedo hex tokens (design) for the 2D map and for flat-shaded styles.

#### 2.3.1 Great Lakes region set (Ontario)

Ontario's southern forest regions are the **Deciduous (Carolinian)** zone south of a line roughly from Grand Bend to Toronto [37], and the **Great Lakes to St. Lawrence** mixed forest north of it, with maple, oak, yellow birch, white and red pine, hemlock and white cedar [36]. The Lake Erie plains have the highest tree diversity in Canada [38]. The Shield north of that grades into **boreal**.

| Class id | Canopy | Canopy species (height, spacing) | Understory and ground | Ground palette | Seasons | Uses and water | Fauna and sound tags |
|---|---|---|---|---|---|---|---|
| `gl_carolinian` (Ecoregion 7E) | 70 to 90% | sugar maple (25 to 35 m) [69], red and white oak (20 to 30 m, crown about as wide as tall) [69], shagbark hickory, black walnut, tulip tree, sassafras, beech; spacing 8 to 12 m | spicebush, dogwood, pawpaw; spring ephemerals (trillium); leaf litter | litter `#6b5536`, moss `#4f6b33` | spring: green haze, white trillium carpet; summer: deep green `#3f6b2a`; autumn: red, orange, yellow, oak brown; winter: bare, grey trunks, snow patches | farmland matrix, woodlots, ravines, creeks | `birds_forest_dawn`, `woodpecker`, `treefrog_spring`, `wind_leaves`; wood thrush, pileated woodpecker [38] |
| `gl_mixedwood` (Great Lakes to St. Lawrence) | 70 to 90% | sugar maple (25 to 35 m), red maple, yellow birch, eastern white pine (20 to 40 m, emergent above the canopy, 12 m crown) [39], red pine, eastern hemlock (20 to 30 m), white cedar; spacing 6 to 10 m | maple saplings, hobblebush, ferns, moss on rocks; needle and leaf litter | `#5c4a30`, needles `#7a5a35` | autumn maple reds strongest; conifers keep 0.9 cover in winter [9] | woodlots, cottage lakes, rock knobs | `loon` (lakes), `chickadee`, `wind_pines`, `creek` |
| `gl_boreal` (Shield north) | 50 to 80% | black spruce (10 to 20 m), white spruce, jack pine, balsam fir, trembling aspen, white birch; spacing 3 to 6 m | Labrador tea, blueberry, feather moss, reindeer lichen on rock | moss `#5a6b3a`, lichen `#b8b89a`, rock `#7d7a75` | aspen and birch gold in autumn; heavy snow winter | lakes in every hollow, bogs, rock outcrops | `loon`, `wolf_far` (night), `raven`, `mosquito` (summer) |
| `gl_escarpment` (cliff forest, Niagara Escarpment) | 60 to 80% on slopes | sugar maple and basswood on the talus; eastern white cedar clinging to the cliff face and brow (ancient, stunted; widely reported, unverified here) | ferns, moss, limestone rubble, fallen logs [9] | rubble `#9a948a`, moss `#4a6233` | as `gl_mixedwood` | ravine creeks, waterfalls (Hamilton), trails [9] | `waterfall`, `creek`, `birds_forest`, `trail_walkers` |
| `gl_savanna` (oak savanna, tallgrass remnants) | 10 to 40% | black and bur oak (15 to 25 m), widely spaced 20 to 40 m | big bluestem, Indian grass, prairie forbs | dry grass `#b59a5a` | summer green-gold, autumn bronze-red grasses | parks (High Park style), sand plains | `crickets`, `meadowlark`, `wind_grass` |
| `gl_old_field` (abandoned farm, meadow) | 0 to 15% | scattered hawthorn, sumac, young ash and pine | goldenrod, aster, grasses, Queen Anne's lace | `#9fa05a` | autumn goldenrod yellow and aster purple | edge of farms, hydro corridors | `crickets`, `bobolink`, `wind_grass` |
| `gl_farm` (cropland) | 0 to 5% plus hedgerows | fencerow maples, ash, hawthorn; windbreak spruce rows | crops by stage (4.6) | ploughed soil `#5a4632`, stubble `#c2a96b` | spring bare soil and green shoots; summer corn and soy; autumn harvest stubble; winter snow with stubble rows | concession grid, farmsteads, drains | `tractor_far`, `crows`, `wind_open` |
| `gl_alvar` | 0 to 10% | stunted cedar, bur oak | thin soil on flat limestone pavement, grasses, moss, bare rock | pavement `#b0aba0` | very dry summer | open, rare | `wind_open`, `insects` |
| `marsh` (coastal or inland) | 0% (emergent) | none; emergent cattail and bulrush 1 to 3 m | wet meadow sedges at the edge | `#6b7a3a`, water `#3b5a5a` | autumn tan cattails; winter frozen | lake edges, river mouths | `red_winged_blackbird`, `frogs`, `marsh_wind` |
| `swamp` (forested or thicket) | 25%+ trees or tall shrubs [40] | silver and red maple, black ash, cedar (10 to 25 m); thicket: willow, alder, dogwood | standing water seasonally, hummocks, skunk cabbage | dark muck `#3a3424` | spring flooded | creek bottoms | `frogs`, `drip`, `mosquito` |
| `fen` | 0 to 25% | tamarack, cedar | sedges, brown mosses; groundwater fed, less acidic [40] | `#8a8a50` | autumn tamarack gold | spring-fed hollows | `insects`, `wind_grass` |
| `bog` | 0 to 30% | black spruce, tamarack, stunted | Sphagnum carpet, Labrador tea, pitcher plants; rain-fed, acidic [40] | sphagnum `#8a7a40` to `#9a5a4a` | autumn red sphagnum | kettle hollows, Shield | `quiet`, `insects` |
| `urban_forest` | 28 to 31% (Toronto) [20] | Norway and silver maple, honey locust, linden, oak, London plane | lawn | lawn `#5e8a3a` | autumn colour; winter bare | streets and yards | city ambience (4.10) |

Species heights from Ontario sources for white pine [39] and from Ontario municipal tree guides for sugar maple and red oak [69]; the others are typical figures (unverified).

#### 2.3.2 World set (extended)

| Class id | Canopy | Key plants (height, spacing) | Ground and palette | Seasons | Uses and water | Sound tags |
|---|---|---|---|---|---|---|
| `boreal` | 40 to 80% | spruce, fir, pine, larch, birch, aspen (10 to 25 m, 3 to 6 m) | moss, lichen, needles `#5a6b3a` | long snow winter; brief green summer | logging roads, lakes, bogs | `raven`, `wind_pines`, `loon` |
| `temperate_deciduous` | 70 to 95% | oak, beech, maple, ash, lime (20 to 35 m, 8 to 12 m) | leaf litter `#6b5536` | four strong seasons, leaf-off winter | farmland, villages, hedgerows | `birds_forest`, `wind_leaves` |
| `temperate_mixed` | 70 to 90% | above plus pine, hemlock, spruce | litter + needles | conifers hold winter cover | as above | as above |
| `temperate_rainforest` | 90%+ | Douglas fir, cedar, hemlock, spruce (40 to 70 m, 8 to 15 m) | ferns, moss on everything `#3e5a2a` | wet winters, mild | logging, rivers, fog | `rain_drip`, `creek` |
| `grassland` / prairie | 0 to 10% | grasses 0.3 to 2 m; trees only along rivers (gallery forest: cottonwood, willow) | `#a59a55` summer, `#c8b070` dry | green spring, gold summer, brown winter, snow | ranching, grain, grid roads, shelterbelts | `wind_grass`, `meadowlark`, `crickets` |
| `steppe` / cold desert | 0 to 5% | sagebrush, bunchgrass 0.3 to 1 m, 1 to 3 m apart | dusty `#b8a578` | harsh winter, short green spring | grazing, dirt tracks | `wind_dry` |
| `mediterranean` | 20 to 60% | holm and cork oak, stone pine, olive (5 to 15 m, 6 to 12 m); maquis and garrigue shrubs 1 to 4 m | red soil `#9a5a3a`, limestone `#c9c0aa` | green wet winter, dry gold summer | terraces, vineyards, olive groves, white villages | `cicadas` (summer), `wind_dry` |
| `desert` (hot) | 0 to 5% | cacti, acacia, creosote 1 to 3 m, 5 to 20 m apart; palms at oases | sand `#d8bf8a`, gravel pavement `#a88a60`, rock `#a0603a` | little seasonality; flash floods | wadis, oases, mesas | `wind_desert`, `silence` |
| `savanna` | 10 to 40% | acacia, baobab (8 to 20 m) widely spaced 20 to 60 m; tall grass 1 to 2 m | `#b8a050` dry, `#8aa045` wet | wet green season, dry gold season, fire scars | grazing, villages with compounds | `insects_day`, `birds_savanna` |
| `tropical_seasonal` | 60 to 90% | teak, sal, many deciduous species (20 to 35 m) | litter dry season | leaf drop in dry season | farming, rivers | `birds_tropical` |
| `tropical_rainforest` | 90%+ in layers | emergents 45 to 60 m, canopy 25 to 35 m, understory palms; spacing irregular | dark litter `#3a3424` | no winter; daily rain | rivers as roads, clearings | `rainforest_dense`, `rain_heavy` |
| `tundra` | 0% | dwarf willow and birch under 0.5 m, sedges, lichens | `#8a8a6a`, lichen `#b8b89a` | snow 8+ months; summer ponds and bugs | none or few | `wind_cold`, `geese_far` |
| `alpine` | 0% above tree line | cushion plants, grasses, scree | rock `#8a8580`, meadow `#7a8a4a` | snow most of the year | trails, huts | `wind_high`, `marmot` |
| `wetland` | varies | see Great Lakes marsh, swamp, fen, bog; tropical: mangrove 5 to 20 m | | | | `frogs`, `water_birds` |
| `coastal_dune` | 0 to 20% | marram and lyme grass 0.5 to 1.2 m [42], then shrubs and pines on grey dune | sand `#e0cfa0` | winter storms reshape | beaches, boardwalks | `surf`, `gulls`, `wind_coast` |
| `island_archipelago` (preset) | inherits climate biome | wind-pruned trees on exposed shores; dense in lee | rock shores `#7d7a75` | storms | harbours, ferries, lighthouses | `surf`, `gulls`, `foghorn_far` |
| `volcanic` (substrate preset) | 0 to 70% depending on age | pioneer ferns, grasses on young flows; full forest on old soil | black basalt `#2e2b2a`, ash `#5a5550`, red cinder `#7a3a2a` | | fumaroles, crater lakes | `wind_high`, `steam_vent` |

### 2.4 Ecotones and bands

**Forest edges.** Blend over 20 to 60 m with a dithered boundary (blue-noise jitter of the class mask), shrubs and saplings concentrated in the outer 10 to 30 m (design). Squall Cove's canopy-cover grid already gives a clean rule: cover from placement `1 - exp(-sum(crown_area) / cell_area)`, recomputed by season [9].

**Altitude bands.** Montane forest, then subalpine (conifers dominate), then krummholz (2.1), then alpine meadow, then scree and bare rock, then snow and ice. Each band boundary is a soft blend of 50 to 150 m in elevation with noise (design).

**Treeless wetlands.** Open where water stands most of the growing season: marsh and open fen/bog. Trees only where hummocks or drier margins exist (swamp, treed peatland).

**Lakeshore vegetation bands (Great Lakes marsh).** Lake to upland: submergent, floating-leaved, emergent, wet meadow, shrub; wave-exposed shores lose most aquatic vegetation and keep wetlands only behind dunes or beach ridges [41]. Depth defaults (design, consistent with the zonation in [41]):

| Band | Water depth | Plants |
|---|---|---|
| Submergent | 1.0 to 3.0 m | pondweeds, wild celery (visible only as dark patches) |
| Floating-leaved | 0.5 to 2.0 m | water lily, spatterdock |
| Emergent | 0.1 to 1.0 m | cattail, bulrush, reeds 1 to 3 m |
| Wet meadow | 0 to 0.15 m, saturated | sedges, grasses, joe-pye weed |
| Shrub swamp | seasonal flooding | willow, alder, dogwood |
| Upland | dry | biome forest or field |

**Sandy coast (dune) bands.** Strandline and beach, embryo dunes (a few metres high, pioneer grasses), foredune, yellow (mobile) dune with marram, grey (fixed) dune with moss and lichen, dune slacks in hollows, then scrub and forest [42]. Width defaults (design): beach 20 to 60 m, embryo 5 to 15 m, foredune 15 to 40 m, yellow dune 30 to 100 m, grey dune 50 to 300 m. Dune slip faces rest at the angle of repose of dry sand (about 34 degrees [44]).

**Rocky coast bands.** Splash zone (bare dark rock, lichen), storm zone (wave-pruned shrubs), then forest (design).

**River corridors.** Gravel bars, then willow and alder thickets (5 to 15 m), then floodplain forest (silver maple, cottonwood) out to the edge of the flood zone (HAND under 2 to 3 m), then upland.

---

## 3. Slopes, cliffs and geomorphology

### 3.1 Slope classification

FAO's Guidelines for Soil Description give the standard field classes [43]:

| FAO class | Percent | Degrees |
|---|---|---|
| Flat | 0 to 0.2 | 0 to 0.11 |
| Level | 0.2 to 0.5 | 0.11 to 0.29 |
| Nearly level | 0.5 to 1.0 | 0.29 to 0.57 |
| Very gently sloping | 1 to 2 | 0.57 to 1.15 |
| Gently sloping | 2 to 5 | 1.15 to 2.86 |
| Sloping | 5 to 10 | 2.86 to 5.71 |
| Strongly sloping | 10 to 15 | 5.71 to 8.53 |
| Moderately steep | 15 to 30 | 8.53 to 16.7 |
| Steep | 30 to 60 | 16.7 to 31.0 |
| Very steep | over 60 | over 31.0 |

FAO stops at "very steep". Games need more classes above 31 degrees, so the pack uses these **slope classes** (design, FAO-compatible below S5):

| Class | Range | Ground texture | Vegetation | Buildability | Movement |
|---|---|---|---|---|---|
| `S0 flat` | 0 to 2% (0 to 1.15 deg) | biome ground; ponding if TWI high | all | anything; big boxes, rail yards, airfields need under 1 to 2% | full speed; poor drainage |
| `S1 gentle` | 2 to 5% (to 2.9 deg) | biome ground | all, crops ideal | anything | full |
| `S2 moderate` | 5 to 15% (to 8.5 deg) | biome ground, more soil exposure on tracks | crops (erosion risk rises), forest, pasture | houses yes; large floorplates need cut and fill; roads: arterials to 8%, locals to 12% [10] | walking slightly slower; trucks slow |
| `S3 steep` | 15 to 30% (to 16.7 deg) | grass and forest; dirt on paths | pasture, forest; no row crops (design) | hillside houses with walk-outs; stepped townhouses; tracks to 18% [10]; graded landscape max 33% [3] | walking clearly slower (Tobler) |
| `S4 very steep` | 30 to 60% (to 31 deg) | forest floor or rough grass, roots, exposed soil on convex parts | forest, scrub; no mowing | no buildings (design); no roads except switchbacks | hands sometimes; light vehicles marginal |
| `S5 talus or scree` | 31 to 40 deg (60 to 84%) | scree, gravel, boulders where loose; thin soil and roots where vegetated | sparse; pioneer shrubs | none | slow scrambling; no vehicles |
| `S6 rock slope` | 40 to 55 deg (84 to 143%) | rock with soil pockets | trees only on ledges | none | climbing; cover from fire |
| `S7 cliff` | 55 to 80 deg (143 to 567%) | bare rock (triplanar), strata | ledge plants only | none | impassable without ladders, stairs, ropes |
| `S8 vertical or overhang` | over 80 deg | rock mesh, not heightmap | none | none | impassable |

Walking speed on slope: Tobler's hiking function, `v = 6 * exp(-3.5 * |tan(theta) + 0.05|)` km/h, about 5 km/h on the flat, peak about 6 km/h on a gentle descent; multiply by 0.6 off-path [67]. A heightmap cannot store S8; overhangs and true vertical faces need meshes (3.5).

### 3.2 Angle of repose and snow

| Material | Angle | Use in the generator |
|---|---|---|
| Dry sand | about 34 deg (30 to 35) [44] | dune slip faces, sand piles at quarries |
| Natural gravel with sand | 25 to 30 deg [44] | gravel bars, spoil, road embankments |
| Crushed stone | about 45 deg [44] | rail ballast shoulders, quarry piles |
| Talus or scree (angular rock) | 33 to 38 deg (unverified, commonly cited) | talus aprons below cliffs |
| Dry soil and till | 30 to 35 deg (unverified) | stable natural slopes on glacial till; bluff faces fail steeper |
| Wet clay | 15 to 25 deg (unverified) | slumps, river banks in clay |
| Snow (avalanche start zones) | most avalanches on 30 to 45 deg; possible 25 to 60; slopes over 45 deg shed snow often, below 25 deg rarely slide [45] | avalanche zones in alpine presets; snow does not build up beyond a thin dusting on faces over 50 to 55 deg (design) |

### 3.3 How a renderer should use slope, aspect and curvature

Material weights per terrain cell are computed in the pack (as a few weight channels or a material id plus blend) and then rendered by each game. The pack stores the **class**; the game picks the textures.

```
w_rock   = smoothstep(35, 50, slope_deg) + 0.5 * cliff_mask
w_scree  = smoothstep(28, 36, slope_deg) * (1 - smoothstep(42, 50, slope_deg)) * below_cliff(dist <= 1.5 * cliff_height)
w_dirt   = smoothstep(18, 30, slope_deg) * convexity          # thin soil on convex ridges and shoulders
         + path_mask + erosion_mask(flow_accumulation high and slope > 10 deg)
w_wet    = smoothstep(TWI_wet, TWI_wet + 2, TWI) * (slope_deg < 5)  # mud, moss, darker
w_grass  = biome_ground * (1 - w_rock - w_scree - w_dirt)
w_snow   = snow_cover * (1 - smoothstep(50, 60, slope_deg)) * aspect_bias   # north faces hold snow longer
w_litter = canopy_cover                                         # leaf litter or needles under crowns [12]
```

Thresholds are **(design)** and match the class table in 3.1. Rules of thumb:

- **Concave places** (negative plan curvature: gullies, hollows, footslopes) collect water, soil and debris: darker, wetter, more vegetation, scree at cliff bases.
- **Convex places** (ridges, shoulders, spurs) lose soil: thinner grass, exposed dirt and rock, wind-pruned trees.
- **Aspect**: in the northern hemisphere, north faces are cooler and moister (more moss, denser forest, longer snow); south faces are drier (more grass, dry soil) [55].
- **Height blending, not linear blending**: use each texture's height map so stones poke through grass rather than fading into it (Terrain3D uses height blending for this reason [56]).
- **Macro variation**: multiply albedo by a low-frequency noise (50 to 200 m wavelength) to break tiling; this matters more than texture resolution from drone height.

**Triplanar projection.** A single top-down UV projection stretches textures on steep faces. Triplanar mapping projects from three axes and blends by the surface normal, which removes stretching on cliffs [52]. Use it only where needed (slope over about 35 degrees), because it costs three texture samples per layer. Normal maps need proper triplanar handling, not the mesh tangents, or lighting is wrong on cliffs [52]. Research shows triplanar mapping can also drive displacement to extrude geometry along steep faces at render time [53]; that is optional and desktop only.

### 3.4 Terrain features: detection and dressing

Derived rasters (computed once by the pack builder from the heightmap at its native cell size):

- `slope` (Horn 3x3), `aspect`;
- `curv_plan`, `curv_profile` (Zevenbergen-Thorne);
- `tpi_s`, `tpi_l`: topographic position index at small (about 50 m) and large (about 500 m) radii, standardised; positive means higher than surroundings [47];
- `relief_w`: max minus min elevation in a window (default 30 m radius);
- `facc`: flow accumulation (D8 or D-infinity) in m² of upslope area; `twi`; `hand`;
- `geomorphon`: the 10-class pattern (flat, peak, ridge, shoulder, spur, slope, hollow, footslope, valley, pit) [46].

Weiss's TPI method gives slope position (valley, lower, flat, middle, upper, ridge) and a 10-class landform map using two radii [47]; geomorphons classify landforms by line-of-sight patterns in eight directions [46]. Both are standard GIS tools and reproducible in a few hundred lines of code.

**Scale warning.** Slope depends on cell size. A 10 m DEM smooths a 15 m cliff into a 40 degree slope. Detection thresholds below assume 1 to 2 m cells; for coarser cells use the **relief rule** as well: a cliff exists where `relief_w(r = cell) / (2 * cell) > tan(55 deg)` or where elevation drops more than 8 m across 2 cells (design).

| Feature | Detection rule (design unless cited) | 2D map colour | Ground material | Props and dressing |
|---|---|---|---|---|
| Flat valley floor / plain | slope < 2%, `tpi_l` near 0, low `relief_w` | `#c8d6a0` | biome ground, crops | fields, farmsteads |
| Floodplain | `hand` < 2 m and within 500 m of a channel with `facc` > 5 km² | `#a8c8b0` | wet meadow, silt | willows, debris lines |
| Stream channel | `facc` > 0.5 km² (permanent) or > 0.05 km² (seasonal) | `#4a90c8` | gravel bed, mud | stones, logs, culverts at roads |
| River bank / cut bank | channel edge cells with slope > 25 deg on the outer side of a bend | `#8a6a4a` | exposed soil, roots | undercut trees, erosion decals |
| Gully | `facc` > 0.01 km², plan curvature strongly concave, slope > 10 deg | `#7a6a50` | dirt, gravel, litter | fallen logs, rocks |
| Ravine | gully with `relief_w` > 15 m and side slopes > 30 deg | `#5e6b4a` | forest floor, rock on walls | trail, footbridge, stairs [9] |
| Ridge / crest | `tpi_l` > 1 sd and plan curvature convex, or geomorphon = ridge | `#c8b88a` | thin grass, rock | wind-pruned trees, towers, lookouts |
| Spur | geomorphon = spur | `#d0c090` | as ridge | |
| Peak | geomorphon = peak, `tpi_l` > 2 sd | `#e0d0a0` | rock, alpine meadow | cairn, mast |
| Saddle / pass | ridge cell that is a local minimum along the ridge line | `#d8c890` | grass, track | road or trail crossing |
| Plateau / terrace | slope < 5% and `tpi_l` > 0.5 sd, bounded by S4+ edges | `#d8d0a8` | biome ground | fields, town sites |
| River terrace | step in the valley wall: flat band above the floodplain (`hand` 3 to 15 m) | `#c0c898` | fields | farms, roads |
| Scarp / escarpment | linear band of slope > 30 deg with `relief_w` > 30 m over > 500 m length, flat above and below | `#9a7a5a` line | rock face over talus over forest | cliff kit, talus, trails, waterfalls |
| Cliff | slope > 55 deg (1 to 2 m cells) or the relief rule; connected components > 20 m² | `#6a5a4a` hatched | rock (triplanar), strata | cliff meshes, ledges, decals |
| Bluff | cliff or S5+ slope in **unconsolidated** material (till, sand, clay) along a shore, `relief_w` > 15 m | `#b89a70` | bare till and sand, slumps, gullied face | slump blocks, sparse shrubs on top, beach at base |
| Talus apron | below a cliff: slope 30 to 40 deg, within 1.5 x cliff height of the cliff base | `#a09a90` | scree | boulders, scree decals |
| Ledge | cells inside a cliff band with slope < 35 deg and width > 1 m | `#7a8a5a` | soil, moss | cedars, shrubs, nests |
| Waterfall / rapids | channel (`facc` large) crossing a cliff or scarp cell; rapids where channel slope > 2% | `#2a70c8` | wet rock | waterfall mesh, mist, plunge pool, sound |
| Beach | land within the beach band above water, slope < 10% | `#e8d8a8` | sand or shingle | driftwood, wrack line |
| Dune | sand substrate, `relief_w` 2 to 30 m, crest-and-hollow pattern | `#e0cfa0` | sand + marram | fences, boardwalks |
| Drumlin | elongated hill: `tpi_l` > 0, footprint ellipse long axis 0.5 to 2 km, width several hundred m, aligned with others [50] | `#b8c890` outline | pasture, fields | farms on the crests, wet hollows between |
| Esker | sinuous narrow ridge 5 to 20 m high, kilometres long, gravel (unverified dimensions) | `#c8b878` line | gravel, pine | gravel pits, trails |
| Moraine hummock | hummocky `tpi_s` noise, mixed sizes, kettle pits | `#b0b888` | mixed | kettle ponds, wetlands |
| Kettle | closed depression (geomorphon = pit) 10 to 500 m across | `#5a90b0` | water, bog | bog ring |
| Rock outcrop (Shield knob) | bare-rock substrate and slope 5 to 30 deg, convex | `#8a8580` | rock, lichen | pines in cracks |
| Lakeshore / sea shore | water edge, band per 2.4 | `#6aa8d0` | per band | docks, ramps |

**Ontario landforms worth hand-checking:**

- **Niagara Escarpment** (Hamilton "mountain"): a hard dolostone caprock (Lockport) over weaker shales; the shale erodes, the caprock is undercut and breaks off, so the face is a near-vertical rock cap above a steep talus and shale slope [48]. Model: cliff band (S7) 10 to 30 m, talus (S5) below, forested slope (S4) to the lower town, with waterfalls where creeks cross the brow. Total relief at Hamilton is on the order of 90 to 100 m (unverified).
- **Scarborough Bluffs**: glacial and lake sediments, 50 to over 90 m above Lake Ontario, eroding by shallow slumps and gullying [49]. Model as `bluff`, not `cliff`: gullied, unvegetated till face with a sand beach and fallen material at the base.
- **Drumlin fields** (Peterborough): thousands of drumlins over more than 5,000 km², kilometre-scale long, several hundred metres wide, oriented north-north-east [50].

### 3.5 Cliff pipeline (heightmap to geometry)

1. **Mask.** `cliff = slope > 55 deg OR relief rule`; `steep = slope > 40 deg`.
2. **Clean.** Morphological close (1 cell) then open (1 cell); drop components under 20 m².
3. **Break lines.** Trace the top edge (cliff cells next to non-cliff cells that are higher) and the base edge (next to lower ones) as polylines; simplify with 0.5 m tolerance.
4. **Segment.** Cut the top line into pieces of 4 to 12 m; for each piece store position, outward normal (from the aspect), height (top minus base elevation sampled along the normal), and material class (from substrate: dolostone, granite, sandstone, till).
5. **Height band.** Classify each piece: 2 to 4 m, 4 to 8 m, 8 to 16 m, 16 to 32 m, over 32 m (stack pieces). Games choose a cliff module per band from their kit and scale it by at most plus or minus 25% (design).
6. **Seat the terrain.** Lower the heightmap under the cliff mesh by 0.5 to 1 m inside the cliff footprint so the mesh hides the terrain seam (the terrain becomes the collider of last resort; the mesh carries its own collider).
7. **Talus apron.** From the base line, extend an apron at 33 to 37 degrees outward for a length of 0.5 to 1.0 x cliff height (design), blending into the slope below; place boulder scatter densest at the base, thinning outward, with the largest boulders farthest out (bigger blocks roll further).
8. **Strata.** For sedimentary substrates, the material uses world-space height bands (period 0.5 to 3 m with noise) so layers line up across pieces; caprock band thicker and paler at the top (escarpment style [48]).
9. **Ledges.** Where cliff cells have local slope under 35 degrees and width over 1 m, place ledge vegetation (cedar, shrubs, moss) and a soil decal.
10. **Waterfalls.** Where a stream with `facc` above threshold crosses the top line: place a waterfall element sized to the height band, a plunge pool basin (depth 1 to 3 m), mist particles and a sound emitter; bend the channel above to meet the lip.
11. **Overhangs and caves** come only from authored meshes (S8); the pack may mark sites (`cave_mouth` at cliff bases facing away from prevailing wind) for a game to dress (Squall Cove already has a cave mouth frame [11]).
12. **Low-end fallback.** Without cliff meshes, a game can render the cliff band with triplanar rock plus a rock normal map and vertical strata, and still read correctly from drone height.

---

## 4. The asset and texture catalogue

### 4.1 Conventions

- **Slot naming**: `<kind>.<family>.<name>[.<variant>][.<lod>]`, lowercase, underscores inside names. Kinds: `tex` (PBR material), `mat` (shader-only material), `mesh`, `kit` (set of meshes), `decal`, `fx`, `snd`, `sky`. Examples: `tex.ground.grass_lawn`, `mesh.tree.pinus_strobus.mature.lod1`, `kit.road.collector`, `snd.amb.marsh.day`.
- **Real scale everywhere**: textures carry `metres_per_repeat` (RWJ-Shared-Assets already records this [14]); meshes are in metres, Y up, origin at ground contact.
- **Maps**: albedo (sRGB), OpenGL normal, ARM (occlusion, roughness, metal), optional height for height-blending; this matches the existing AeroSim and shared-library format [12][14].
- **Licence**: every asset carries `licence` and `source`; allowed by default: CC0 and own work. Poly Haven and ambientCG are CC0 and allow redistribution and commercial use without attribution [59][60]; Kenney assets are CC0 [62]; Sketchfab has CC0 models among mostly CC BY ones, filterable by licence [63]. Megascans were free under Fab's standard licence only to the end of 2024 and are now mostly paid; legacy Quixel-library assets fall under a separate Epic content licence [61]. **Rule: the gap finder flags any non-CC0, non-own asset**, and treats CC BY as allowed only when the game has a credits screen, and NC or ND as not allowed (design).
- **Texel density** (design, from [58]): aerial or drone camera 256 to 512 px/m on terrain, 512 px/m on buildings; walk-level 1,024 px/m near the player. Ground textures repeat, so resolution is chosen by repeat size: a 2 m repeat at 1k gives 512 px/m.
- **Budgets** below are **(design)** starting points, informed by AeroSim's measured tree LODs (LOD0 4,400 to 5,950 triangles with a 6,000 budget, LOD1 450 to 720, far silhouettes 42 and 96, switching at 110 m and 430 m) [13] and Squall Cove's forest kit (trees about 3,000 to 5,000 triangles each, about 32,000 for 17 pieces) [9]. No authoritative current mobile triangle budget was found; profile on the target phone.

### 4.2 Ground and terrain PBR textures

| Slot | Purpose | Metres per repeat | Variants min / rich | Desktop / phone res | Procedural? | CC0 sources |
|---|---|---|---|---|---|---|
| `tex.ground.grass_lawn` | mown lawns, parks, yards | 2 to 3 | 1 / 3 (green, patchy, dry) | 2k / 1k | albedo tint procedural; base sourced | Poly Haven, ambientCG (shared library has `grass`, `grass2`, `grass_dry`) [14] |
| `tex.ground.grass_meadow` | rough grass, old field | 3 to 4 | 1 / 3 | 2k / 1k | sourced | Poly Haven, ambientCG |
| `tex.ground.forest_litter` | leaf litter under deciduous canopy | 2.5 (shown larger for drones) [12] | 1 / 3 (fresh autumn, decayed, wet) | 2k / 1k | sourced | shared `soil_leaves` [12] |
| `tex.ground.needles` | pine and spruce floors | 2 | 1 / 2 | 1k / 1k | sourced | Poly Haven, ambientCG |
| `tex.ground.soil` | bare soil, garden beds, erosion | 2 | 1 / 3 (dry, moist, clay) | 2k / 1k | sourced | shared `dirt`, `mulch` [14] |
| `tex.ground.field_ploughed` | tilled fields (rows by decal or UV direction) | 4 | 1 / 2 | 2k / 1k | row direction procedural | ambientCG |
| `tex.ground.mud` | wetland margins, tracks | 2 | 1 / 2 | 1k / 1k | sourced | Poly Haven |
| `tex.ground.moss` | north faces, swamp hummocks, rocks | 2 | 1 / 2 | 1k / 1k | sourced | Poly Haven |
| `tex.ground.sand` | beaches, dunes | 3 | 1 / 3 (dry, wet, rippled) | 2k / 1k | ripples by normal procedural | Poly Haven, ambientCG |
| `tex.ground.gravel` | gravel bars, yards, verges | 2 [12] | 1 / 3 | 1k / 1k | sourced | shared `gravel` [12] |
| `tex.ground.scree` | talus, scree | 3 | 1 / 2 | 2k / 1k | sourced | Poly Haven |
| `tex.ground.rock_cliff` | cliffs (triplanar) | 4 to 8 | 1 / 4 (limestone, granite, sandstone, basalt) | 2k / 1k | strata procedural | Poly Haven (shared `mossrock`, `limestone`) [12] |
| `tex.ground.rock_outcrop` | Shield knobs, bedrock | 3 | 1 / 2 | 2k / 1k | sourced | Poly Haven |
| `tex.ground.snow` | snow cover | 4 | 1 / 2 (fresh, wind-packed) | 1k / 1k | could be procedural (white + noise normal) | Poly Haven |
| `tex.ground.ice` | frozen lakes | 6 | 0 / 1 | 1k / 512 | procedural feasible | ambientCG |
| `tex.ground.peat` | bog surface | 2 | 0 / 1 | 1k / 1k | sourced | ambientCG |
| `tex.ground.ash` | volcanic preset | 3 | 0 / 1 | 1k / 1k | sourced | ambientCG |
| `tex.ground.crop.<type>.<stage>` | crop ground layer seen from the air | 6 to 10 | 2 / 8 | 1k / 512 | **procedural** stripe patterns from row spacing | own work |

Minimal temperate set: 10 textures (lawn, meadow, litter, soil, field, sand, gravel, scree, rock cliff, snow). Rich set: about 30. Terrain3D in Godot caps a terrain at 32 texture sets [56], which fits the rich set.

### 4.3 Rock and cliff sets

| Slot | Purpose | Min / rich count | Tris desktop / phone | Procedural? | Source |
|---|---|---|---|---|---|
| `kit.cliff.<substrate>` (pieces per height band 2-4, 4-8, 8-16, 16-32 m; straight, inner corner, outer corner, end cap) | cliffs from 3.5 | 4 / 20 per substrate | 1,500 to 6,000 / 300 to 1,200 per piece | Generated by Blender script feasible; photogrammetry better | own work (Squall Cove `rock_cliff_face` PREVIEW [11]); Poly Haven models |
| `mesh.rock.boulder` (0.5 to 3 m) | talus, fields, shores | 3 / 10 | 300 to 1,500 / 60 to 300 | procedural feasible | Poly Haven, own |
| `mesh.rock.outcrop` (5 to 20 m) | Shield knobs, cover | 2 / 6 | 2,000 to 8,000 / 400 to 1,500 | authored | Squall Cove `rock_outcrop_a/b` [11] |
| `mesh.rock.bedrock_large` (20 to 40 m) | landmarks | 1 / 3 | 5,000 to 15,000 / 1,000 to 3,000 | authored | Squall Cove `rock_bedrock_large` [11] |
| `mesh.rock.spire`, `mesh.rock.overhang`, `mesh.rock.cave_mouth` | S8 features | 0 / 3 | as outcrop | authored | Squall Cove previews [11] |
| `decal.rock.scree`, `decal.rock.cliff_stain`, `decal.ground.erosion` | blend seams, water staining | 2 / 8 | quads | textures sourced | Poly Haven, ambientCG |
| `fx.water.waterfall` (by height band) + `fx.water.mist` | waterfalls | 1 / 4 | 500 to 2,000 / 200 to 600 | shader procedural | own work |

### 4.4 Roads and surface materials

| Slot | Purpose | Repeat | Min / rich | Procedural? | Source |
|---|---|---|---|---|---|
| `tex.road.asphalt_new` / `asphalt_worn` / `asphalt_patched` | arterials, collectors, locals | 5 m [12] | 1 / 4 | wear and patches by mask procedural | Poly Haven (`asphalt_02`, `asphalt_floor`) [12] |
| `tex.road.chip_seal` | rural paved | 2.35 [12] | 0 / 1 | sourced | Poly Haven [12] |
| `tex.road.gravel` / `tex.road.dirt_rut` / `tex.road.grass_track` | tracks | 2 to 3 | 1 / 3 | ruts by profile procedural | Poly Haven, ambientCG |
| `tex.road.concrete_slab` | highways, aprons, industrial | 4 (joints every 4.5 to 6 m) | 0 / 2 | joints procedural | ambientCG |
| `tex.road.cobble` / `setts` | old town, kerb strips | 2 [12] | 0 / 2 | sourced | shared `cobble` [12] |
| `tex.walk.sidewalk_concrete` | sidewalks (1.5 m panels) | 1.8 [5] | 1 / 2 | sourced | shared `sidewalk` [14] |
| `tex.walk.pavers` / `brick_herringbone` / `flagstone` | plazas, patios, paths | 1 to 2 | 0 / 4 | sourced | Poly Haven, ambientCG |
| `mesh.road.kerb` (barrier, mountable, drop) | kerbs per profile | n/a | 1 / 3 | **procedural** sweep along road edges | own |
| `decal.mark.*` (centre line, edge line, lane line, stop bar, crosswalk ladder and zebra, turn arrows, bike symbol, parking bays) | markings, owned by arm per junction rules [7][10] | n/a | 6 / 15 | **procedural** geometry or decals from the graph | own |
| `decal.road.*` (cracks, oil stains, manhole, drain grate, patch) | realism | n/a | 0 / 10 | sourced textures | Poly Haven, ambientCG |
| `kit.road.junction` | junctions built from incoming arms [10] | n/a | generated | **procedural** | own |
| `mesh.road.bridge_deck` (short, span, culvert headwall) | crossings | n/a | 2 / 6 | parametric procedural | own |

Roads are the clearest case for **procedural over authored**: Squall Cove's own analysis found that fixed road pieces cannot meet at arbitrary angles and widths without gaps, and moved to profiles swept along a graph with junctions built from the arms [10].

### 4.5 Building facade and roof materials

| Slot | Repeat | Min / rich | Notes | Source |
|---|---|---|---|---|
| `tex.facade.brick_red` / `brick_buff` / `brick_painted` | 1.0 m [12] | 1 / 4 | Toronto heritage and inner suburbs are brick-dominant | shared `brick`, `brick2` [14] |
| `tex.facade.stone_ashlar` / `stone_rubble` | 2 to 3 m [12] | 0 / 2 | civic, heritage, barn foundations | shared `ashlar`, `rubble` [12] |
| `tex.facade.stucco` | 3 m [5] | 1 / 2 | | shared `stucco` [5] |
| `tex.facade.siding_vinyl` / `siding_wood` / `board_batten` | 1.5 m | 1 / 3 | suburbs, cottages, barns (`barnwood` [12]) | Poly Haven |
| `tex.facade.concrete` / `precast` | 3 m [5] | 1 / 2 | mid-rise, industrial | shared `concrete` [5] |
| `tex.facade.curtain_wall` | per bay 1.5 x 3.6 m | 1 / 3 | towers: mullions procedural, reflections from the sky | **procedural** shader |
| `tex.facade.metal_panel` / `corrugated` | 1.12 m [12] | 1 / 2 | industrial, farm sheds | Poly Haven `corrugated_iron` [12] |
| `tex.roof.asphalt_shingle` | 2 m | 1 / 3 | most Ontario houses | ambientCG |
| `tex.roof.metal_standing_seam` | 1 m | 0 / 2 | barns, cottages | ambientCG |
| `tex.roof.flat_membrane` / `gravel_ballast` | 4 m | 1 / 2 | flat roofs | ambientCG |
| `tex.roof.slate`, `clay_tile` | 1.5 m | 0 / 2 | heritage, Mediterranean | Poly Haven |
| `tex.window.*` (glass, frames, lit-window atlas) | per window | 1 / 4 | lit windows by hash (Squall Cove does this) [8] | own |

### 4.6 Building kits

The pack stores **typology, footprint, height, storeys, roof shape, ridge axis, door side**, never facade geometry. OpenStreetMap's `roof:shape` values (flat, gabled, hipped, half-hipped, skillion, gambrel, mansard, pyramidal, dome and others) are adopted as the roof vocabulary, with `roof:height` or `roof:angle` [64]. Squall Cove already treats houses as shells with door, garage side and ridge-axis metadata, with yards supplied by a separate lot kit [8].

| Kit slot | Contents | Variation min / rich | Tris per building desktop / phone | Procedural or authored |
|---|---|---|---|---|
| `kit.bldg.house_detached` | bungalow, two-storey, split-level, 1.5-storey cottage; gable, hip, cross-gable roofs; porch, dormer, garage modules | 4 / 24 | 1,500 to 5,000 / 300 to 1,200 | **procedural** from footprint + roof rule (ProceduralMainStreet's neighbourhood mode already does gables, dormers, porches [5]); authored hero houses optional |
| `kit.bldg.house_attached` | semi, row, stacked townhouse modules (bay 4.5 to 8 m) | 3 / 12 | 1,000 to 3,000 per unit / 250 to 800 | procedural bays |
| `kit.bldg.storefront` | heritage main-street fronts: shopfront, cornice, sash windows, signs blank | 4 / 20 | 1,500 to 4,000 / 400 to 1,000 | procedural (ProceduralMainStreet `_heritage` [5]) |
| `kit.bldg.midrise` | podium, streetwall, step-backs, balconies, penthouse | 3 / 10 | 4,000 to 12,000 / 1,000 to 3,000 | **procedural** from the envelope (1.3) |
| `kit.bldg.tower` | podium + point tower, curtain wall or punched; crown | 3 / 12 | 5,000 to 20,000 / 1,500 to 5,000 | procedural massing; authored crowns optional |
| `kit.bldg.commercial_box` | big box, strip plaza, pad (gas, drive-through) | 3 / 10 | 1,000 to 4,000 / 200 to 1,000 | procedural box + authored canopies |
| `kit.bldg.industrial` | warehouse, plant, sawtooth shed, tanks, silos, stacks, conveyors | 4 / 16 | 2,000 to 8,000 / 400 to 2,000 | procedural box + authored equipment |
| `kit.bldg.farm` | farmhouse, bank barn, drive shed, silo, grain bins, corn crib | 4 / 12 | 2,000 to 6,000 / 400 to 1,500 | authored (AeroSim barn and silo exist [12]) |
| `kit.bldg.civic` | church, school, library, fire hall, town hall | 3 / 10 | 3,000 to 10,000 / 800 to 2,500 | authored |
| `kit.bldg.port` | warehouse, fish plant, harbour office, lighthouse, crane | 3 / 15 [11] | 2,000 to 10,000 / 500 to 2,500 | authored |
| `kit.bldg.informal` | block and sheet-roof modules, stairs, water tanks | 0 / 8 | 500 to 2,000 / 150 to 500 | procedural stacking |
| `kit.lot` | fence segments (picket, chain-link, rail, privacy), gates, hedges, driveway and path pieces, mailbox, bins, shed [8] | 6 / 20 | 50 to 800 / 20 to 200 | authored small parts, placed procedurally |
| `kit.bldg.interior` | enterable room shells | 0 / 9 (Squall Cove has nine) [11] | n/a | authored |

### 4.7 Vegetation

Species follow the biome profile; each species needs LODs. AeroSim's tested bands: near to 110 m full mesh, 110 to 430 m reduced cards, beyond 430 m silhouette [13]. Octahedral impostors replace distant trees with two triangles and a view-dependent atlas and are standard for large forests [57]; their memory cost grows fast with species count.

| Slot | Purpose | Min / rich count | Tris LOD0 / LOD1 / far | Phone LOD0 | Procedural? | Source |
|---|---|---|---|---|---|---|
| `mesh.tree.<species>.<age>` (young, mature, old, dead snag) | canopy trees | temperate: 4 species x 2 ages = 8 / 12 species x 3 ages + snags = 40 | 6,000 / 700 / 40 to 100 [13] | 1,500 to 2,500 | **procedural** (AeroSim's `tree_gen.ts` [12], Squall Cove's `pg_forest.py` [9]) | own work; bark CC0 [12] |
| `mesh.tree.<species>.winter` | leaf-off variant (or a crown-less trunk piece) [9] | 1 per deciduous species | 2,000 / 400 / 40 | 800 | procedural | own |
| `mat.leaf.<species>.<season>` | seasonal leaf atlases | 2 / 4 per species | n/a | 512 px atlases [12] | painted procedurally [12] | own |
| `mesh.canopy_sheet` | far forest roof tiles (32 x 32 m) [9] | 1 / 3 | 200 to 800 per tile | same | procedural | own |
| `mesh.shrub.<type>` | dogwood, sumac, juniper, sapling clump | 3 / 12 | 300 to 1,500 | 150 to 500 | procedural | own |
| `mesh.grass.<type>` (cards or blades) | lawn tufts, meadow, prairie tall grass | 2 / 8 | 4 to 40 per clump (GPU-instanced) | cards only | procedural | own |
| `mesh.flower.<type>`, `mesh.fern`, `mesh.groundcover.*` | colour accents, forest floor | 3 / 15 | 10 to 200 | same | procedural cards | own |
| `mesh.reed.cattail`, `bulrush`, `mesh.waterlily` | marsh bands (2.4) | 2 / 5 | 50 to 300 per clump | same | procedural | Squall Cove has reed and cattail [9] |
| `mesh.crop.<type>.<stage>` | corn, soy, wheat, hay (stages: bare, emergent, vegetative, mature, harvested stubble, bales) | 2 crops x 4 stages / 6 crops x 6 stages | instanced cards 4 to 20 per plant clump; far = texture only | texture only beyond 50 m | **procedural** row placement; plant models simple | own |
| `mesh.log`, `stump`, `deadfall`, `root_flare` | forest floor cover [9] | 3 / 8 | 200 to 1,500 | 100 to 400 | authored | Squall Cove forest kit [9] |

### 4.8 Water

| Slot | Purpose | Min / rich | Notes |
|---|---|---|---|
| `mat.water.lake` | lakes, ponds; depth colour from the pack's bathymetry | 1 / 2 | **procedural shader**: depth tint, normal-map waves, sky reflection, shore fade |
| `mat.water.river` | flowing water with flow direction | 1 / 2 | flow map from the pack's channel direction; foam at rapids |
| `mat.water.sea` | open water with swell | 0 / 1 | Squall Cove has a wind-driven sea |
| `mat.water.shore_foam` | foam and wet-sand band | 1 / 2 | shader band driven by distance to shore |
| `tex.water.normal_small` / `normal_large` | ripples, waves | 2 / 4 | procedural or CC0 normal maps |
| `mat.water.ice` / `snow_on_ice` | winter lakes | 0 / 2 | seasonal |
| `fx.water.splash`, `wake`, `rain_rings`, `mist` | interaction | 1 / 6 | particles |

### 4.9 Street furniture, utilities and props

| Slot | Min / rich | Tris desktop / phone | Placement rule (pack) | Notes |
|---|---|---|---|---|
| `mesh.street.lamp` (cobra head, heritage, park bollard) | 1 / 4 | 300 to 1,500 / 100 to 400 | every 30 to 40 m on arterials and collectors, 40 to 60 m on locals (design) | link to power grid for outages (Squall Cove) [11] |
| `mesh.street.sign_*` (stop, yield, street name, speed, one-way) | 3 / 12 | 50 to 300 | from the junction control matrix [7] | blank text plates, games fill names [9] |
| `mesh.street.signal` (mast arm, pedestrian head, controller box) | 1 / 3 | 800 to 3,000 / 300 to 800 | signals at arterial-arterial and arterial-collector junctions [7] | |
| `mesh.street.hydrant` | 1 / 2 | 200 to 600 | every 90 to 150 m along streets (design) | |
| `mesh.street.bench`, `bin`, `bike_ring`, `planter`, `bollard`, `newspaper_box` | 4 / 12 | 100 to 800 | main streets and parks | |
| `mesh.street.bus_stop` (pole, shelter) | 1 / 2 | 300 to 2,000 | every 250 to 400 m on transit streets (design) | |
| `mesh.utility.pole_wood`, `pole_concrete`, `transformer`, `wire_span` | 2 / 6 | 300 to 1,000 | poles 30 to 50 m apart along streets with overhead lines (design) | wires as one strip [11] |
| `mesh.utility.tower_transmission`, `substation` | 0 / 3 | 1,000 to 5,000 | hydro corridor every 250 to 400 m (design) | |
| `mesh.utility.box` (telecom, hydro pedestal) | 1 / 3 | 50 to 200 | at lot corners | |
| `mesh.utility.manhole`, `drain` | decals | n/a | road centre lines and gutters | |
| `mesh.fence.*`, `wall.*`, `hedge.*` | 4 / 12 | per segment 50 to 400 | per boundary type [8] | |
| `mesh.farm.*` (field gate, hay bales, feeder, trough, windmill pump) | 3 / 10 | 100 to 1,500 | farmsteads and fields | |
| `mesh.park.*` (play structure, picnic table, sports goals, washroom, gazebo) | 3 / 10 | 300 to 5,000 | parks | AeroSim has 89 park props [14] |
| `mesh.cemetery.*` (headstones, monuments, crosses, mausoleum) | 5 / 20 | 50 to 2,000 | sections in rows | AeroSim cemetery [14] |

### 4.10 Vehicles, people and animals

These are for **ambience at map scale**, not playable units.

| Slot | Min / rich | Near / far | Notes |
|---|---|---|---|
| `mesh.vehicle.car` (sedan, SUV, pickup, van) | 2 / 8 | 2,000 to 8,000 / 200 to 600 / impostor | parked by lot type, moving along road graph |
| `mesh.vehicle.truck`, `bus`, `tractor`, `farm_implement`, `boat_small` | 2 / 10 | as above | depots, farms, marinas |
| `mesh.person.*` | 1 / 8 | 1,500 to 5,000 / 300 / **sprite or impostor** beyond 50 to 80 m | crowds are instanced; drone views see dots |
| `mesh.animal.*` (cattle, horses, deer, geese, gulls, crows) | 2 / 10 | 500 to 3,000 / 100 / sprite | by biome and land use (fields: cattle; marsh: geese) |

### 4.11 Infrastructure, sky, weather and audio

| Slot | Min / rich | Procedural? | Notes |
|---|---|---|---|
| `mesh.bridge.*` (culvert, short span, truss, arch, pedestrian) | 2 / 8 | parametric | from 1.5.2 |
| `mesh.rail.*` (track sweep, ballast, level crossing, signals, platform, station) | 2 / 8 | track **procedural**; station authored | Squall Cove has rail requested [11] |
| `mesh.infra.tunnel_portal`, `dam`, `weir`, `retaining_wall`, `noise_wall`, `water_tower`, `radio_mast`, `wind_turbine`, `grain_elevator` | 3 / 15 | mixed | settlement anchors [11] |
| `sky.hdri.*` | 1 / 6 (clear, partly cloudy, overcast, sunset, night, storm) | sourced or procedural | shared HDRI with sun removed [14]; AeroSim procedural weather sky [14] |
| `fx.weather.*` (rain, snow, fog, lightning, wind debris) | 2 / 7 | procedural | AeroSim weather system has seven conditions [14] |
| `snd.amb.<biome>.<time>` | 4 / 30 | sourced or synthesised | beds by biome tag (2.3) x day/night x season; e.g. `snd.amb.gl_mixedwood.day.summer` |
| `snd.amb.urban.*` (traffic far, traffic near, main street, industrial hum, port, highway) | 3 / 10 | sourced | by land use and road class |
| `snd.point.*` (waterfall, creek, surf, wind in pines, church bell, train horn) | 4 / 20 | sourced | emitters placed by feature (3.4) |

CC0 audio is less plentiful than CC0 textures; Freesound hosts mixed licences, so every sound needs a licence check (no source verified for this chapter; flagged as a gap).

### 4.12 The asset gap finder

**Inputs**

1. `pack.json` (from the world pack): lists of classes used with quantities, for example:
   ```json
   {"settlement_classes": {"suburb_inner": {"area_ha": 42, "buildings": 610}, "main_street": {"area_ha": 6, "buildings": 88}},
    "road_classes": {"arterial_major": {"km": 4.1}, "local": {"km": 18.0}, "track": {"km": 6.3}},
    "biomes": {"gl_mixedwood": {"area_ha": 900}, "marsh": {"area_ha": 35}},
    "terrain_features": {"cliff": {"count": 14, "height_bands": {"4-8": 9, "8-16": 5}}, "waterfall": {"count": 2}},
    "roof_shapes": {"gabled": 420, "hipped": 160, "flat": 118},
    "seasons": ["summer", "autumn", "winter"], "platforms": ["desktop", "phone"]}
   ```
2. `requires.json` (ships with the World Builder): rules from class to slots, each with a **severity** and a **fallback chain**:
   ```json
   {"road_class:local": [
      {"slot": "tex.road.asphalt_worn", "severity": "blocking", "fallback": ["tex.road.asphalt_new"]},
      {"slot": "mesh.road.kerb", "severity": "degrading", "fallback": ["procedural:kerb_box"]},
      {"slot": "decal.mark.stop_bar", "severity": "degrading", "fallback": []},
      {"slot": "mesh.street.hydrant", "severity": "cosmetic", "fallback": []}],
    "biome:gl_mixedwood": [
      {"slot": "mesh.tree.acer_saccharum.mature", "severity": "blocking", "fallback": ["mesh.tree.generic_broadleaf.mature"], "per_season": true},
      {"slot": "mesh.tree.pinus_strobus.mature", "severity": "degrading", "fallback": ["mesh.tree.generic_conifer.mature"]},
      {"slot": "tex.ground.forest_litter", "severity": "blocking", "fallback": ["tex.ground.soil"]},
      {"slot": "snd.amb.gl_mixedwood.day", "severity": "cosmetic", "fallback": ["snd.amb.forest.day"]}],
    "terrain_feature:cliff": [
      {"slot": "kit.cliff.{substrate}", "severity": "degrading", "fallback": ["mat.rock_triplanar"], "per_height_band": true}]}
   ```
   Severity: **blocking** (the map cannot compile: a road with no surface, a biome with no ground), **degrading** (compiles, but visibly wrong or generic), **cosmetic** (missing life and detail).
3. `style.json` (section 5): maps classes to the game's slot names, can rename or merge slots, and sets budgets.
4. `kit.json` (the game's asset manifest): for each available slot: files, LODs present, triangle counts per LOD, texture resolution, `metres_per_repeat`, seasons, licence, source.

**Algorithm**

```
needed = {}
for each (class, qty) in pack:
    for rule in requires[class]:
        slots = expand(rule.slot, pack)               # fill {substrate}, per_season, per_height_band
        for s in slots: needed[s].weight += weight(qty) ; needed[s].severity = max(...)
for s in needed:
    t = style.resolve(s)                              # style may remap, merge, or mark "procedural:..."
    if t is procedural and game supports it: status = OK_PROCEDURAL
    elif t in kit: status = check(kit[t])             # LODs for each platform, budgets, seasons, licence, scale present
    else:
        f = first fallback in chain that resolves in kit
        status = FALLBACK(f) if f else MISSING
score = sum(weight * ok) / sum(weight)                # coverage, weighted by area, length or instance count
```

Weights (design): area classes by hectares, roads by kilometres, features and props by instance count, all normalised so blocking slots dominate (x10), degrading x3, cosmetic x1.

**Checks inside `check()`**: every platform in the pack has a LOD within budget (style sets budgets); seasonal variants exist for each season in the pack; `metres_per_repeat` present on textures; licence in the allowed set; normal map convention declared (OpenGL); triangle count of LOD0 not more than 1.5x the budget.

**Outputs**

`gap-report.json`:
```json
{"pack": "valley_v3", "style": "aerosim_realistic", "coverage": 0.81,
 "blocking_missing": [{"slot": "tex.ground.sand", "needed_by": ["biome:coastal_dune"], "weight": 35.0}],
 "fallbacks_used": [{"slot": "mesh.tree.pinus_strobus.mature", "used": "mesh.tree.generic_conifer.mature"}],
 "over_budget": [{"slot": "kit.bldg.tower", "platform": "phone", "lod0_tris": 9200, "budget": 5000}],
 "licence_flags": [{"slot": "mesh.vehicle.car", "licence": "CC-BY-4.0", "action": "needs credits screen"}],
 "season_gaps": [{"slot": "mat.leaf.acer_saccharum", "missing": ["winter"]}]}
```
and `gap-report.md`, a plain-language list ordered by severity then weight, ending with a **shopping list**: each missing slot with its catalogue row (purpose, minimal count, budget, suggested CC0 source or "procedural: generator name").

### 4.13 Master checklist (temperate region, minimal set)

The gap finder treats these as the default `requires` for a Great Lakes map; a slot is ticked when it resolves to a kit asset, a procedural generator or an accepted fallback.

- **Terrain**: lawn, meadow, forest litter, needles, soil, ploughed field, sand, gravel, scree, cliff rock (triplanar), snow (if winter), mud or wetland.
- **Rock**: boulders (3), outcrop (2), cliff kit for the pack's substrates and height bands, talus decal.
- **Roads**: asphalt (new, worn), chip seal, gravel or dirt track, concrete sidewalk, kerb sweep, markings set, junction generator, bridge (culvert, short span), rail track (if rail).
- **Facades and roofs**: brick (2), siding, stucco, concrete, curtain wall, metal panel; asphalt shingle, standing-seam metal, flat membrane; window glass and lit-window atlas.
- **Building kits**: detached house, attached house, storefront, mid-rise, tower (if rank 5), commercial box, industrial, farm set, civic, lot kit.
- **Vegetation**: at least 4 broadleaf and 2 conifer species with LOD0, LOD1, far; leaf-off variants; seasonal leaf materials; 3 shrubs; 2 grasses; 2 groundcover; reeds and lilies (if wetland); 2 crops x 4 stages (if farmland); canopy sheet for far forest.
- **Water**: lake, river, shore foam; ice (if winter).
- **Props**: street lamp, signs, signal, hydrant, bench, bin, bus stop, utility pole and wire, fences (3), hedges, farm gate and bales, park set, cemetery set (if present).
- **Life**: 2 cars, 1 truck, people (sprites at least), 2 animal types.
- **Sky and weather**: 2 skies (clear, overcast), rain, fog, snow (if winter).
- **Audio**: one bed per biome present, urban bed, water point sources (creek, waterfall, surf).

---

## 5. The style layer (one page)

A **style** maps the pack's classes to a game's assets and materials without changing the pack. The same valley can be a photoreal drone survey in AeroSim and a cartoon battlefield in Squall Cove.

**What a style may do**: rename slots to the game's names; merge slots (all broadleaf species to one low-poly tree); declare a slot procedural (the game generates it); set per-platform budgets and LOD distances; set palette overrides (colour tokens per class and season); set density multipliers (fewer trees, fewer props); choose rule variants the pack offers (for example render `cliff` as mesh kit or triplanar only). **What a style may not do**: move, add or remove anything in the pack (roads, parcels, buildings, vegetation density maps), because gameplay rules such as Squall Cove's canopy cover grid read the pack, not the pictures [9].

**Schema** (`style.json`):

```json
{
  "style_id": "string",
  "extends": "string | null",
  "pack_schema": "worldpack/2",
  "platforms": {"desktop": {"budgets": {}, "lod_distances_m": []}, "phone": {"budgets": {}, "lod_distances_m": []}},
  "palette": {"<class or slot>": {"<season>": "#rrggbb"}},
  "map": {"<pack class or slot pattern>": "<game slot> | procedural:<generator> | merge:<slot> | omit"},
  "density": {"<slot pattern>": 0.0},
  "rules": {"cliff_render": "mesh_kit | triplanar", "roof_detail": "full | simple", "markings": "decal | geometry | none"},
  "licences_allowed": ["CC0", "own", "CC-BY"]
}
```

**Example**: Squall Cove's low-poly military sandbox, built on a generic base:

```json
{
  "style_id": "squall_lowpoly",
  "extends": "base_temperate",
  "pack_schema": "worldpack/2",
  "platforms": {
    "desktop": {"budgets": {"mesh.tree.*": 3000, "kit.bldg.*": 4000}, "lod_distances_m": [80, 300]},
    "phone":   {"budgets": {"mesh.tree.*": 600,  "kit.bldg.*": 1200}, "lod_distances_m": [50, 180]}
  },
  "palette": {
    "biome:gl_mixedwood": {"summer": "#4f7a3a", "autumn": "#b0603a", "winter": "#d8dcd8"},
    "tex.ground.grass_lawn": {"summer": "#6a9a48"}
  },
  "map": {
    "mesh.tree.acer_*": "merge:forest_tall_canopy",
    "mesh.tree.pinus_*": "merge:forest_conifer",
    "mesh.tree.*.winter": "forest_bare",
    "tex.ground.*": "procedural:flat_vertex_colour",
    "kit.cliff.*": "rock_cliff_face",
    "mesh.rock.outcrop": "rock_outcrop_a",
    "kit.road.*": "procedural:road_profile_sweep",
    "decal.road.*": "omit",
    "mesh.person.*": "procedural:capsule_sprite",
    "snd.amb.gl_mixedwood.*": "amb_forest"
  },
  "density": {"mesh.grass.*": 0.2, "mesh.flower.*": 0.0, "decal.*": 0.3},
  "rules": {"cliff_render": "mesh_kit", "roof_detail": "simple", "markings": "geometry"},
  "licences_allowed": ["CC0", "own"]
}
```

AeroSim's `aerosim_realistic` style would instead map each species to its own procedural photoreal tree with three LODs [13], keep PBR ground textures at their published repeat sizes [12], render cliffs with mesh kits plus triplanar rock, and allow full decal density. The gap finder runs once per (pack, style, kit) triple, so the same pack can show "ready" for one game and a shopping list for the other.

---

## 6. Open questions and uncertainty

- **Density figures by typology.** No Ontario source with a clean net-density table per building type was found; Table 1A densities are derived from lot sizes and are **(design)**. Toronto's 2021 bulletin [18] and the PPS targets [15] anchor the scale.
- **Ontario road allowance and survey geometry** varies by township and era (single front, double front, 1,000-acre sections and others) [30]; the concession defaults model one common 200-acre single-front layout.
- **Talus, till, clay and esker figures** are commonly cited values not confirmed against a primary source in this research.
- **Mobile budgets** are design starting points; the only measured numbers are AeroSim's tree LODs [13] and Squall Cove's forest kit [9].
- **Parking stall dimensions** (2.6 x 5.6 m) were not confirmed against the Toronto by-law text; the 6.0 m aisle was [66].
- **Hamilton escarpment relief** (about 90 to 100 m) is unverified.
- **Audio licensing** sources were not researched.
