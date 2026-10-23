# World Builder: Chapter 3, Suburbs, Farmland, Wilderness, Infrastructure and Discoveries

Written 2026-10-23 by Claude (research chapter). Companion to `CHAPTER-1-ARCHITECTURE-TERRAIN.md` (pack format, terrain, carving) and the Chapter 2 work on urban grading, biomes, slopes and the asset catalogue. Sources are numbered [n] and listed in `SOURCES-3.md`. Robert's own documents are cited as [R1] to [R6] at the end of that file.

## 0. Summary

This chapter turns the parts of a world that are not a town centre into rules a compiler can run: suburbs and their plazas, Ontario farm country, the forests and lakes of the Shield, highways and other infrastructure, and a catalogue of hidden places for a drone to find. Every rule is a table row or a numbered step. Each number carries two tags:

* **Region**: **[ON]** typical of Ontario and the Great Lakes; **[NA]** North America in general; **[EU]** Europe or elsewhere.
* **Confidence**: **(S)** taken from a cited source; **(C)** computed by me from a sourced formula or sourced inputs; **(D)** a design default I chose so the generator has a number (tune by test); **(V)** common practice that I know but did not confirm in a source this session (verify before calling it real).

The most important decisions, in one place:

1. **Ontario's survey grid is the master pattern.** Concession and side roads every 1.3 to 2.1 km (S/C), 66 foot (20.1 m) road allowances (S). Suburban arterials, farm lots, woodlots and hamlets all hang off this grid. A generator that lays the grid first gets the rest almost for free.
2. **Land use is a separate layer from land cover.** Chapter 1's `cover/class.u8` says what is on the ground (grass, trees, paving). This chapter adds `landuse/use.u8` (what the land is for: cul-de-sac housing, strip plaza, corn field, red pine plantation) plus a `landuse/stage.u8` layer for season and growth stage. Every use class names a fallback cover class, so a game that ignores the new layer still works.
3. **Commercial placement is driven by catchment.** Plazas go at arterial intersections, sized by the population that lives within the tier's trade radius, using the ICSC classes (S).
4. **Roads are routed on a cost field with hard grade limits per class**, then graded with class-specific cross-sections and side slopes. The minimum curve radius table is computed from the standard point-mass formula and checked against a published table (C, matched to [15]).
5. **Discoveries obey a density budget per square kilometre and a seeded placement that cannot overlap** roads, water, steep slopes or each other. Rarity tiers, hidden-ness from roads and narrative clusters (a ghost town is a rail grade plus a station, foundations, lilacs and a cemetery) make them feel found, not sprinkled.

---

## 1. Suburbs: a computable design guideline

### 1.1 Where suburbs sit: the concession grid feeds the arterials [ON]

Southern Ontario was surveyed before it was settled. Road allowances one chain (66 ft, 20.1 m) wide were laid out between concessions and at regular side-road intervals [1][2]. When farms became suburbs, the concession and side roads became the arterials. So an Ontario suburb is a set of **super-blocks** bounded by arterials on the old allowances, each filled with its own internal street network that touches the arterials at only a few points. This is why GTA arterials are straight, evenly spaced and meet at right angles, while the streets inside are curved.

| Survey system [ON] | Lot | Lot size | Concession road spacing | Side road spacing | Super-block |
|---|---|---|---|---|---|
| Single front (early, about 1783 to 1818) | 19 x 105.26 chains | 200 acres (81 ha) | about 2.14 km (C from [2]) | about 1.93 km, every 5 lots (C from [2]) | about 1.9 x 2.1 km |
| Double front | 30 x 66.67 chains, patented as 100 acre half lots | 200 acres | about 1.36 km (C from [2]) | about 3.04 km, every 5 lots (C from [2]) | about 1.4 x 3.0 km |
| 1,000 acre sectional | 20 x 50 chains | 100 acres (40 ha) | 2.0 km (S [1]) | 2.0 km (S [1]) | 2.0 x 2.0 km |
| 30 x 33.33 chain variant | 30 x 33.33 chains | 100 acres | about 1.36 km (S [1], approximately) | about 3.0 km (S [1]) | about 1.4 x 3.0 km |

One chain = 20.117 m; ten square chains = one acre. Allowance width 1 chain [1]. The AMCTO handout gives township block sizes of 6,270 x 6,947 ft (single front), 4,400 x 9,900 ft (double front) and 6,600 x 6,600 ft (sectional) [2]; the lot dimensions above are my arithmetic from those blocks. The legal rules for each system are in the Ontario Surveys Act [3].

**Generator rule (D):** pick a survey system per township (default double front for a GTA-like suburb, sectional for later townships), rotate the grid to a township bearing (Ontario townships are often rotated off true north to follow the lake shore; pick a bearing within plus or minus 20 degrees of the shoreline normal), and lay allowances. Add **jogs** where townships meet and, for single front systems, at side-road junctions (offsets of 10 to 100 m, because survey errors were absorbed at the junctions [2]). Every allowance becomes either an arterial (in urban areas), a concession or county road (rural), an unopened allowance (a hedgerow or tree line with a farm track) or nothing (where it hits a lake or a cliff). In a suburb, mark 1 in 2 allowances as major arterial, the rest as minor arterial (D).

**Arterial feeding (D, informed by [R1]):** each super-block gets 1 to 2 collector roads that enter from the arterials at 2 to 4 points, roughly at the mid-points of the block sides (signalised), forming a cross, a loop or a figure-eight. Locals hang off the collectors. No local street meets an arterial except at a right-in right-out (rare). This matches the hierarchy rules already written for Squall Cove [R1] ("up and down by one step"); this chapter supplies the Ontario spacings.

### 1.2 Suburban morphologies

Each morphology is a template the generator applies to a super-block. Numbers are per template. Densities are net (lots only) unless marked gross.

| Code | Morphology (era) | Street network | Block | Lot frontage x depth | House | Storeys | Garage and drive | Front setback | Net density (units/ha) | Sidewalks and trees |
|---|---|---|---|---|---|---|---|---|---|---|
| SB1 | Inter-war streetcar suburb (1900 to 1940) [ON][NA] | Grid, short blocks, some rear lanes; shops on the streetcar arterial | 60 to 90 m x 180 to 300 m (D) | 7.5 to 12 m x 30 to 40 m; US lots "no wider than 30 to 40 ft" (S [52]) | Detached, semi, row; footprint 55 to 90 m2 (D) | 2 to 2.5 | None at first; later a rear garage off the lane or a shared side drive (S [52], informal) | 3 to 6 m (D) | 21 to 44 (C) | Both sides, boulevard trees, mature closed canopy (D) |
| SB2 | Post-war curvilinear neighbourhood unit (1950 to 1975), e.g. Don Mills [ON] | Loops, crescents and many cul-de-sacs; a ring road around a central shopping centre; four quadrants each with a school, a church and a park (S [26]) | Irregular, 80 to 150 m wide (D) | 15 to 20 m x 33 to 40 m (V) | Bungalow, side-split, back-split; 100 to 160 m2 footprint (V) | 1 to 1.5 | Single attached garage or carport at the side, single-width drive (V) | 6 to 9 m (V) | 12 to 20 (C) | Often none on locals; trees now mature, canopy 40 to 60 percent (D) |
| SB3 | Late suburban subdivision (1980 to 2010) [ON][NA] | Long curvilinear collectors forming loops; crescents; reverse-frontage lots along arterials behind a continuous wood or concrete acoustic fence (V) | 70 to 120 m x 200 to 400 m (D) | 9 to 15 m x 30 to 33 m; Markham post-1996 zones 9.15 m to 18 m frontage, 30 m depth (S [4]) | 2-storey detached and semi; 180 to 300 m2 floor area (V) | 2 | Double garage, often projecting (the "snout house" [28]); Markham now caps garage doors at 50 percent of the facade and projection at 1.8 m (S [4]) | 3 to 6 m to the house; garage door 5.8 m from the lot line so a car fits on the drive (S [4]) | 20 to 37 (C) | One side on locals, both on collectors; young trees, low canopy (D) |
| SB4 | Estate and exurban (1960 to now) [ON][NA] | Rural cross-section (ditches, no curbs), long cul-de-sacs | Very large | Markham RES-ES: 36.5 m frontage, 0.4 ha minimum (S [4]); rural estate lots 0.4 to 2 ha (V) | Large detached, 300 to 600 m2 | 1 to 2 | Triple garage, long curving drive | 7.5 m minimum (S [4]); typically 15 to 40 m (D) | 0.5 to 2.5 (C) | None; woodland lots common |
| SB5 | New urbanist and "complete community" (1995 to now), e.g. Cornell in Markham [ON][NA] | Modified grid with rear lanes; parkettes; a main street with shops below apartments | 60 to 90 m x 120 to 200 m (D) | Lane townhouse 5.5 to 7 m; lane detached 9 to 11 m; depth 25 to 30 m (V) | Townhouse, semi, detached with porch | 2 to 3 | Rear garage on the lane, no front drives (rear lanes support 30 or more dwellings per ha, S [29]) | 2 to 4.5 m, porch forward (V) | 30 to 70 (C) | Both sides, street trees every 8 to 10 m (D) |
| SB6 | Townhouse and low-rise clusters (1970 to now) [ON] | Private internal roads 6 to 7 m wide (V), parking courts | Cluster parcel 1 to 5 ha | Units 5 to 7 m wide, rows of 4 to 8 (D) | Row, stacked and back-to-back towns, 3 to 4 storey walk-ups | 2 to 4 | Integral garage or a shared parking court | 3 to 6 m | 40 to 120 (C) | Internal walks; small trees |
| SB7 | Towers in the park (1955 to 1985) [ON] | Arterial frontage, a private loop drive, open lawns | Parcel 1 to 6 ha | n/a | Slab or point towers; slab footprint about 15 to 20 m x 50 to 100 m (V) | 8 to 30; the GTA has about 1,925 rental towers of 8 storeys or more (S [27]) | Surface lots and an underground garage | 20 to 60 m from the arterial (D) | 150 to 350 (C) | Lawns, mature trees, often a ravine edge |
| SB8 | Modern mid-rise on avenues | (handled by the urban chapter) | | | | | | | | |

**How the densities were computed (C):** net density = 10,000 / (frontage x depth). Example: 15 m x 33 m = 495 m2, so 20 units per ha. Gross density (super-block including streets, parks, schools, ponds) is about 0.55 to 0.65 of net in SB2 and SB3 (D). People per unit for population estimates (V, typical Ontario planning assumptions): detached 3.0 to 3.4, townhouse 2.6 to 3.0, apartment 1.7 to 2.1.

**Era mix rule (D):** a super-block's distance from the old town centre drives its era: inner (under 5 km) SB1, then SB2 and SB7, then SB3, and on the fringe SB5 and SB6. Add 10 to 20 percent of a neighbouring era per super-block so edges are not abrupt.

### 1.3 Street classes and widths (suburban) [ON]

These extend the Squall Cove typology [R1], which already holds the asphalt widths and junction rules. Here are right-of-way (ROW) widths and cross-sections for Ontario suburbs.

| Class | ROW | Pavement | Lanes | Boulevard and sidewalk | Notes |
|---|---|---|---|---|---|
| Major arterial (regional road) | 36 to 45 m (V) | 4 to 6 lanes, 3.3 to 3.75 m each; 3.5 m is accepted for multi-lane urban roads under 80 km/h (S [59]) | 4 to 6 + turn lanes + raised median 4 to 6 m | 1.5 to 2.0 m sidewalk or 3 m multi-use path each side, 3 to 5 m boulevard | Acoustic fence or reverse-frontage lots on both sides in SB3 |
| Minor arterial | 26 to 30 m (V) | 13 to 15 m | 4 (or 2 + centre turn lane) | sidewalks both sides | |
| Collector | 23 to 26 m (V) | 10 to 14 m | 2 + parking or bike lanes | 1.5 m sidewalk both sides, 2 to 4 m boulevard with trees | Schools, parks and townhouses front it |
| Local | 18 to 20 m (V); 20 m is the old 66 ft chain | 8 to 8.5 m (V) | 2, parking one side | one side or none (SB2) | |
| Cul-de-sac bulb | radius 15 to 18 m ROW (V) | pavement radius 12 to 15 m [R1] | | | |
| Rear lane (SB5) | 7.5 to 8.5 m (V) | 6 m | 1 two-way | none | garages, waste collection |
| Private condo road (SB6) | 6 to 8 m | 6 to 7 m | | | |

Default cross-section generator (D): `ROW = pavement + 2 x (curb 0.15 + boulevard + sidewalk + 0.3 m to property line)`; street trees at 8 to 12 m spacing on boulevards wider than 2 m; utility poles only in SB1, SB2 and rural sections (SB3 and later have buried hydro with green transformer boxes every 3 to 4 lots, V).

### 1.4 Lots and the house on the lot [ON]

Use these rules for every residential parcel. The Markham comprehensive zoning by-law (2024) is used as the reference set because it is current, Ontario and covers several eras [4].

| Rule | Value | Tag |
|---|---|---|
| Minimum frontage, post-1996 large lot detached (RES-LR1) | 18.0 m | S [4] |
| Minimum frontage, detached (RES-LR2) | 9.15 m interior, 10.5 m corner | S [4] |
| Minimum frontage, semi per unit | 7.0 m interior, 10.35 m corner (as listed) | S [4] |
| Minimum depth | 30.0 m | S [4] |
| Front yard (to house) | 3.0 m minimum | S [4] |
| Garage door to lot line | 5.8 m minimum | S [4] |
| Rear yard | 7.5 m minimum | S [4] |
| Interior side yards | 1.2 m and 0.6 m (detached) | S [4] |
| Height | 12 m, 3 storeys | S [4] |
| Garage door width | at most 50 percent of the building facade | S [4] |
| Garage projection beyond main wall | at most 1.8 m | S [4] |
| Parking space | 2.75 x 5.8 m | S [4] |

**House footprint rule (D):** `footprint = min(max_coverage x lot_area, (frontage - side_yards) x (depth - front - rear))`, with max coverage 30 to 40 percent for SB2 and SB3 (V), then the house is 10 to 14 m deep for a 2-storey SB3 house and 9 to 11 m deep for an SB2 bungalow (D). The garage is a 6.1 x 6.1 m (double) or 3.4 x 6.1 m (single) box (V) at the side, set forward by `projection` drawn from 0 to 1.8 m.

**Yards (D):** front yards are lawn, a foundation planting strip and one or two trees; back yards are lawn with a 1.8 m wood privacy fence on all three sides in SB3 and later (chain-link in SB2), a deck (3 x 4 m) on 50 percent of lots, a shed on 30 percent, a pool on 5 to 15 percent of SB2 and SB3 lots (more on larger lots). Pools are a strong visual cue from the air: bright cyan rectangles or kidney shapes.

### 1.5 Community facilities and open space [ON]

| Facility | Site area | Rule for placement | Tag |
|---|---|---|---|
| Elementary school | 2.0 to 3.0 ha (V) | One per neighbourhood of about 3,000 to 5,000 people; on a collector, next to a neighbourhood park so fields are shared; walking catchment 800 m | V/D |
| Secondary school | 6 to 8 ha (V) | One per 3 to 4 elementary catchments; on an arterial or a collector next to one | V/D |
| Place of worship | 0.4 to 2 ha | At collector or arterial corners; parking at 1 space per 4 people of occupant load (S [4]); in Don Mills, one per quadrant (S [26]) | S/D |
| Community centre and library | 1 to 4 ha with fields | Centre of the super-block or next to a secondary school; parking 1 per 40 m2 (S [4]) | S/D |
| Parkette | 0.1 to 0.5 ha | SB5: one every 2 to 3 blocks | D |
| Neighbourhood park | 1 to 3 ha | Within 400 to 500 m walk of every home; next to the elementary school | D |
| Community park | 5 to 15 ha | One per 2 to 4 super-blocks; sports fields, arena | D |
| Stormwater pond | 1 to 4 ha | At the lowest point of each catchment, before the outfall to a creek; length to width at least 3:1 (S [24], cited as a design-table minimum); a forebay at the inlet at least 1 m deep (S [24]); allow about 5 to 8 percent of the developed area (V) | S/V |
| Ravine and valley lands | as found | Stay natural; development set back from the top of bank (V: 10 m from the long-term stable top of slope is a common conservation authority rule) | V |
| Hydro corridor | 46 m for a 230 kV line (S [25]) | Straight lines across super-blocks; towers 30 to 60 m tall, footprints 6 x 6 to 12 x 12 m (S [25]); used for parking, trails, community gardens, and ponds that take up at most two thirds of the corridor width under 115 and 230 kV lines and one third under 500 kV lines (S [25]) | S |
| Rail corridor | ROW about 30 m (V) | Buildings 30 m back from a principal main line with a 2.5 m earth berm; 15 m from branch lines (S [53], secondary) | S/V |

Planning Act parkland dedication (land conveyance) sets the total amount of parkland in new subdivisions; I have not used the exact current rate here (it changed in 2022 and may change again under Bill 98). Use 5 percent of the residential land as a default (D) and see Chapter 2.

**Visual cues from 50 to 500 m (D):** school (a flat-roofed L or H shaped building, 6,000 to 10,000 m2 of roof with rooftop units, a running track oval or a baseball diamond, portables in rows); church (a steep roof or a spire, a large parking lot used only on Sundays); stormwater pond (a teardrop or kidney of water with a fringe of cattails, a gravel maintenance path and a concrete outfall headwall); hydro corridor (a grass strip with lattice towers, a worn path under the wires).

### 1.6 Suburban plazas and commercial

#### 1.6.1 Centre types (ICSC classes) [NA]

The International Council of Shopping Centers classification gives size, site area and trade area by type [5]. Converted to metric:

| Code | Type | GLA (sq ft) | GLA (m2, C) | Site (acres) | Site (ha, C) | Anchors | Trade area (miles) | Trade radius (km, C) |
|---|---|---|---|---|---|---|---|---|
| CM1 | Strip or convenience | under 30,000 | under 2,800 | under 3 | under 1.2 | none or a convenience store | under 1 | under 1.6 |
| CM2 | Neighbourhood centre | 30,000 to 125,000 | 2,800 to 11,600 | 3 to 5 (as listed) | 1.2 to 2.0 | 1 or more (supermarket) | 3 | 4.8 |
| CM3 | Community centre ("large neighbourhood") | 125,000 to 400,000 | 11,600 to 37,000 | 10 to 40 | 4 to 16 | 2 or more | 3 to 6 | 4.8 to 9.7 |
| CM4 | Power centre | 250,000 to 600,000 | 23,000 to 56,000 | 25 to 80 | 10 to 32 | 3 or more category killers | 5 to 10 | 8 to 16 |
| CM5 | Lifestyle centre | 150,000 to 500,000 | 14,000 to 46,000 | 10 to 40 | 4 to 16 | 0 to 2 | 8 to 12 | 13 to 19 |
| CM6 | Regional mall (enclosed) | 400,000 to 800,000 | 37,000 to 74,000 | 40 to 100 | 16 to 40 | 2 or more department stores | 5 to 15 | 8 to 24 |
| CM7 | Super-regional mall | over 800,000 | over 74,000 | 60 to 120 | 24 to 49 | 3 or more | 5 to 25 | 8 to 40 |
| CM8 | Factory outlet | 50,000 to 400,000 | 4,600 to 37,000 | 10 to 50 | 4 to 20 | none | 25 to 75 | 40 to 120 |

The ICSC lists neighbourhood centres at 3 to 5 acres, but with parking at 4 spaces per 1,000 sq ft a 125,000 sq ft centre needs about 6.5 acres (C), so treat 3 to 5 acres as the small end. ICSC also states that strip and neighbourhood centres can be straight, L-shaped or U-shaped, with parking in front of the stores [5].

**Ontario note:** Canadian centres follow the same types. The ICSC numbers are US. Canadian suburbs have somewhat fewer square metres of retail per person than the US (V; not quantified here).

#### 1.6.2 Parking ratios and the parking field [ON][NA]

| Use | Ratio | Per 100 m2 of floor area (C) | Source |
|---|---|---|---|
| Shopping centre over 2,500 m2 (Markham) | 1 per 18.5 m2 | 5.4 | S [4] |
| Shopping centre up to 1,200 m2 (Markham) | 1 per 25 m2 | 4.0 | S [4] |
| Retail store up to 6,000 m2 net (Markham) | 1 per 30 m2 | 3.3 | S [4] |
| ULI community centre under 400,000 sq ft | 4.0 per 1,000 sq ft (weekend peak) | 4.3 | S [6] |
| Restaurant, banquet hall (Markham) | 1 per 9 m2 | 11.1 | S [4] |
| Business office (Markham) | 1 per 35 m2 | 2.9 | S [4] |
| Medical office (Markham) | 1 per 20 m2 | 5.0 | S [4] |
| Hotel | 0.85 per room plus meeting space | | S [4] |
| Commercial storage (self-storage) | 2 plus 1 per 200 m2 | 0.5 | S [4] |
| Golf course | 11 per hole | | S [4] |
| Elementary school | 1.5 per classroom | | S [4] |

**Parking field area (C):** one 2.75 x 5.8 m stall [4] plus its share of a 6.7 m two-way aisle (V) is 2.75 x (5.8 + 3.35) = 25.2 m2; add 15 to 20 percent for drive lanes, islands and landscape, so **use 30 m2 per stall gross** (D). Then:

```
parking_area = ratio_per_100m2 / 100 * GFA * 30
site_area    = (GFA / storeys) + parking_area + landscape_and_setbacks
landscape_and_setbacks = 0.15 * site_area     (D)
=> coverage = (GFA/storeys) / site_area
```

Example (C): a 10,000 m2 one-storey neighbourhood centre at 5.4 per 100 m2 needs 540 stalls, 16,200 m2 of parking, so the site is (10,000 + 16,200) / 0.85 = 30,800 m2 (3.1 ha) and building coverage is 32 percent. Real strip plazas sit at 20 to 30 percent coverage (V), so this is in range.

#### 1.6.3 Building forms and footprints

| Element | Dimensions | Tag |
|---|---|---|
| Strip shop bay | 6 to 9 m wide (column grids of 20, 25 and 30 ft are common) by 18 to 30 m deep; a stock 4-unit strip is about 18 x 20 m | S [39] for grids and the stock plan; ranges D |
| Supermarket anchor | 3,500 to 6,000 m2, more than 45 m deep | S [39] (depth over 150 ft); area V |
| Big box (home improvement, discount, warehouse club) | 8,000 to 15,000 m2, 90 to 130 m on a side, 9 to 12 m tall | V |
| Pad site (bank, fast food) | building under 465 m2 (5,000 sq ft); at most one pad per 2 ha (5 acres) of centre | S [39] (one city's plan) |
| Drive-through | lot at least 0.3 ha; stacking lane of 3.0 x 6.5 m spaces: 10 for a restaurant, 4 for a bank or pharmacy, 8 for a car wash; stacking 15 m from any residential zone | S [4] |
| Gas station with store | 0.4 to 0.6 ha (about 1.1 to 1.5 acres) for 8 dispensers or islands; canopy about 500 m2; store 150 to 450 m2 | S [40] (project examples) |
| Truck stop | 1.5 to 3.5 ha with a separate diesel canopy | S [40] |
| Car dealership | 0.8 to 2.5 ha; showroom 1,000 to 2,500 m2 with glass front; display lot on the arterial frontage | V |
| Self-storage | 1 to 3 ha; rows of single-storey units 9 to 12 m wide with orange or blue doors, or a 3 to 4 storey climate-controlled box | V |
| Enclosed mall | 37,000 to 74,000 m2 GLA (S [5]); a cross or dumbbell plan with department stores at the ends; parking all round (S [5]) | S |
| Light industrial or flex building | 2,000 to 30,000 m2, 50 to 150 m deep, 8 to 12 m clear height, loading docks on one side; lot coverage 35 to 50 percent | V |
| Distribution warehouse | 30,000 to 100,000 m2+, 150 to 200 m deep, truck courts 40 to 60 m deep with trailer rows | V |
| Office park building | 3 to 8 storeys, 2,000 m2 floor plates; surface parking ring; pond and lawns | V |

**Setbacks (D, typical suburban zoning):** strip plaza building 15 to 60 m back from the arterial (parking in front); pad sites 3 to 6 m from the arterial; big boxes 50 to 150 m back with parking in front; loading and service always at the rear, screened from houses by a 2 to 3 m wall or berm.

#### 1.6.4 Placement algorithm (catchment-driven)

Inputs: the road graph with classes, the residential parcels with population (from 1.2), highway interchanges, and the land-use plan (any area pre-painted commercial or employment).

```
1. Candidate nodes = all arterial-arterial intersections, plus arterial-collector
   intersections for CM1 only, plus highway interchange areas (within 1.5 km).
2. For each candidate and each tier t, catchment_pop[t] = population within
   trade_radius[t] by road-network distance (not straight line).
3. Tier thresholds (D; tune so the count per 100,000 people looks right):
      CM1 strip:              2,000 within 1.6 km     (about 1 per 3,000 to 6,000 people)
      CM2 neighbourhood:      8,000 within 3 km       (about 1 supermarket per 10,000 to 15,000)
      CM3 community:         30,000 within 6 km
      CM4 power centre:      80,000 within 12 km, AND interchange within 2 km
      CM6 regional mall:    150,000 within 15 km, AND interchange within 2 km
      CM7 super-regional:   400,000 within 30 km, AND freeway-freeway junction within 5 km
4. Place tiers from the top down (CM7 first). For each tier, greedily take the
   candidate with the highest catchment, then remove candidates closer than
   0.8 x trade_radius[t] for the same tier (spacing rule). Reduce the remaining
   population of each served household by a share (D: 0.6) so the next centre
   of the same tier is pushed outward.
5. Quadrant choice at the intersection: score the four corner quadrants by
   (inbound traffic side, flat ground, no ravine, existing zoning) and place the
   site touching both arterials. CM1 and CM2 may take 1 to 2 corners;
   gas stations take a different corner of the same intersection (max 2 per
   intersection, opposite corners preferred).
6. Size the site with 1.6.2. Lay the building(s) as a straight, L or U line
   along the back and side lot lines, parking in front, pads on the arterial edge.
7. Access: driveways at least 40 m from the intersection on arterials (D),
   right-in right-out on the arterial, a full-movement entrance on the collector
   or at a signal shared with the opposite site.
8. Auto row: dealerships cluster in a line of 4 to 12 along one arterial within
   3 km of an interchange (D).
9. Employment lands: business parks and warehouses fill painted employment
   areas or, if none, the super-blocks touching a freeway or a rail line, never
   directly next to SB lots (put an arterial, a pond, a woodlot or a park between).
```

#### 1.6.5 Industry separation [ON]

Ontario's D-6 guideline (land use compatibility between industry and sensitive uses) sets minimum separations by class (V: Class I light 20 m, Class II medium 70 m, Class III heavy 300 m, with larger "potential influence areas" of 70 m, 300 m and 1,000 m). The ministry's newer compatibility guideline may replace D-6; treat these as defaults to verify. Landfills trigger study within 500 m (S [49], D-4), and sewage lagoons need 100 to 150 m by capacity (S [49], D-2).

### 1.7 Transitions and edges

| Edge | What planners do | Generator rule | Tag |
|---|---|---|---|
| Suburb to farmland (urban boundary) | Hard edge, often the boundary sits on an arterial or concession road; MDS keeps new houses away from livestock barns (formula-based, by animal numbers and manure system) [7] | The urban boundary runs along an allowance; last row of lots backs onto the road with a fence or faces a single-loaded street; farms beyond keep barns at the MDS distance (use 150 to 600 m as a placeholder range, V) | S/V |
| Suburb to ravine or wetland | Natural heritage buffers; the Greenbelt sets a 30 m minimum vegetation protection zone for wetlands, streams, lakes and significant woodlands, and requires evaluation within 120 m (S [9]) | No lot or road inside the feature plus 30 m; a single-loaded street, a park or the rear of lots faces the edge; trail heads at street ends | S |
| Suburb to freeway | Noise walls up to 5 m (MTO maximum, S [54]); a buffer strip; reverse-frontage lots | 14 m minimum building setback from the freeway ROW (V); berm plus wall totalling 4 to 6 m; first row of lots backs onto it | S/V |
| Suburb to arterial (SB3) | Reverse frontage behind an acoustic fence 1.8 to 2.4 m tall, a 3 to 5 m landscape strip | Fence lines are continuous wood or precast panels, broken only at collector entrances | V |
| Suburb to rail | 30 m plus 2.5 m berm at main lines (S [53]) | | S |
| Commercial to houses | Wall or berm, rear service, lighting turned away | 15 m stacking setback (S [4]); 3 m planted strip (D) | S/D |
| Farmland to forest | Hedgerow, fence, woodlot edge | Woodlot edges are straight along lot lines and ragged along creeks (D) | D |

**Land-use grading (D):** grade intensity from the arterial inward and down toward natural features. A simple compatibility matrix scores neighbouring parcels (1 = good, 0 = needs a buffer, -1 = not allowed adjacent). The generator rejects -1 pairs and inserts a buffer parcel (road, park, pond, hedgerow, woodlot) for 0 pairs.

| | Detached | Townhouse | Apartment | Commercial | Light industry | Heavy industry | Farm (livestock) | Natural feature |
|---|---|---|---|---|---|---|---|---|
| Detached | 1 | 1 | 0 | 0 | -1 | -1 | 0 (MDS) | 1 (with 30 m) |
| Townhouse | 1 | 1 | 1 | 1 | 0 | -1 | 0 | 1 |
| Apartment | 0 | 1 | 1 | 1 | 0 | -1 | 0 | 1 |
| Commercial | 0 | 1 | 1 | 1 | 1 | 0 | 0 | 0 |
| Light industry | -1 | 0 | 0 | 1 | 1 | 1 | 1 | 0 |
| Heavy industry | -1 | -1 | -1 | 0 | 1 | 1 | 1 | 0 |

---

## 2. Rural farmland

### 2.1 Survey and field patterns by region

| Region | System | Unit sizes | What it looks like from the air | Tag |
|---|---|---|---|---|
| Southern Ontario | Concession and lot grid (section 1.1) | Lots 100 or 200 acres (40 or 81 ha); allowances 20.1 m [1][2] | Long thin farms running back from the road, rotated grids, jogs at side roads, woodlots at the back of lots | S |
| Northern Ontario clay belts and Shield | Front-and-rear and later surveys (V) | 150 to 160 acre lots (V) | Farms only on clay pockets between rock ridges | V |
| Quebec and the St. Lawrence | Seigneurial long lots in "rangs" (V) | Very narrow strips, roughly 1:10 width to depth, 150 to 250 m wide (V) | Houses strung along the road like beads, strip fields running back | V |
| US Midwest and Plains | PLSS: 6 mile townships of 36 one-mile sections of 640 acres; quarter section 160 acres, quarter-quarter 40 acres; correction lines every 24 to 30 miles (S [37]) | 1 mile (1.6 km) road grid | Perfect one-mile road squares; jogs at correction lines; centre-pivot circles 800 m across in the dry west (V) | S/V |
| Canadian Prairies | Dominion Land Survey: 1 mile sections, road allowances around every section in one direction and every 2 miles in the other (V) | 160 acre quarters | Similar to PLSS | V |
| England and northern Europe (medieval) | Open fields of furlongs split into strips (selions) (S [47]) | Strips around 200 m long and 8 to 20 m wide; ridges about 3 to 20 m apart (S [47]) | Ridge-and-furrow corrugations visible in low sun in old pasture | S |
| Europe (enclosure and modern) | Hedged fields; later consolidated | Bocage fields 1 to 5 ha (V); consolidated arable 5 to 30 ha (V) | Irregular hedge networks; villages nucleated, farms in the village, not on each lot | V |

**[EU] note:** the big change in Europe is settlement form. Farms cluster in villages and fields radiate out, so the Ontario rule "one farmstead per lot frontage" becomes "one village every 2 to 5 km with no farmsteads in between" (V).

### 2.2 Lots, farms and fields [ON]

**Frontage gives farmstead spacing (C):** a single front 200 acre lot is 19 chains (382 m) wide; a double front half lot is 30 chains (603 m) wide [2]. Many lots were later split into halves or quarters. So along an Ontario concession road expect a farmstead every **190 to 600 m**, mostly 300 to 400 m (C). In single front townships, lots front only one road, so one side of each concession road is lined with farmsteads and the other side shows the back ends of the next concession's lots (fields, woodlots, rarely a house). This alternating look is distinctive and cheap to generate.

**Splits (D):** for each original lot draw a split: 30 percent stay whole, 45 percent halves (by depth for single front; by front and rear for double front), 20 percent quarters, 5 percent smaller. Then merge 20 to 40 percent of adjacent farms into one operation (one active farmstead, the other house kept or abandoned: a source of discoveries, section 5). Minimum new farm lot in an Ontario OP is often about 40 ha (100 acres) (S [10] mentions 40 ha and 31 ha cases).

**Fields within a farm (D):** fields are rectangles aligned with the lot lines. Long axis runs along the lot depth. Default for a 400 m wide lot: 3 to 6 fields, each 300 to 500 m along the lot and the full lot width or half of it, so 6 to 20 ha. Mixed or livestock farms have smaller fields and fenced pastures near the barn (2 to 8 ha). Cash-crop farms in southwest Ontario have removed many fencerows, so fields run 20 to 60 ha across several old lots (V).

| Crop or cover | Typical field size [ON] | Shape and pattern | Tag |
|---|---|---|---|
| Corn (grain or silage) | 8 to 40 ha | Rectangle; rows 76 cm (30 in) apart along the long axis | V |
| Soybeans | 8 to 40 ha | As corn; 38 or 76 cm rows; rotates with corn and wheat | V |
| Winter wheat | 5 to 30 ha | Drilled rows 19 cm; straw bales after harvest | V |
| Hay (alfalfa and grass) | 3 to 15 ha | Near the barn; cut 2 to 4 times a year, windrows then bales | V |
| Pasture | 2 to 20 ha | Irregular, on slopes, wet ground and stony land; fenced; trails to the barn and a water trough | D |
| Apple orchard | 2 to 15 ha | Modern high density: trees 1 to 1.5 m apart in rows 3.5 to 4 m apart, trellis wire; old standard trees on an 8 to 10 m grid | V |
| Vineyard (Niagara, Prince Edward County, Lake Erie North Shore) | 2 to 20 ha | Rows 2.4 to 3 m apart, vines 1.2 to 1.5 m apart, posts every 6 to 8 m | V |
| Tender fruit (peach, cherry) | 2 to 10 ha | Open-centre trees on 5 to 6 m grids | V |
| Greenhouse (Leamington and Kingsville, Niagara) | 1 to 20 ha under glass per operation | White or glass sawtooth roofs in long ranges; at night grow lights make an orange-pink glow visible for km | V |
| Specialty crops (tobacco in Norfolk once, ginseng under black shade cloth, sod farms) | 5 to 40 ha | Ginseng: black shade-cloth rectangles; sod: stripes of cut turf | V |
| Fallow or cover crop | any | Green in late autumn and early spring | D |

### 2.3 Crop calendar and appearance [ON]

Dates are for southern Ontario; shift 1 to 3 weeks later for the north and the snowbelt. Corn reaches 95 percent of yield potential when planted by about May 20 to 30 depending on location; soybeans yield best from early plantings in the first 10 days of May; winter wheat is sown after soybean harvest and needs about 130 growing degree days before winter (S [23]). Other dates are (V).

| Month | Corn | Soybean | Winter wheat | Hay | Pasture | Orchard | Vineyard |
|---|---|---|---|---|---|---|---|
| Jan to Mar | Stubble or snow; brown stalk rows | Bare or snow | Green under snow, flat | Brown or snow | Brown | Bare trees, pruned | Bare vines on wire |
| Apr | Bare dark soil, tillage stripes | Bare | Bright green, first to green up | Greening | Greening | Bud | Bare |
| May | Planting, dark soil with faint rows | Planting | Lush green, 20 to 40 cm | Green, first cut late May | Green | Pink-white blossom (apple mid May) | Bud break |
| Jun | Emerged, green rows on brown | Emerged rows | Heading, blue-green | First and second cut: windrows, then bales | Green | Fruit set, green | Green rows |
| Jul | Full canopy, deep green, 2 to 3 m; tassels late July | Full green canopy, low | Turns gold, harvest mid to late July, then straw rows and bales | Green regrowth | Green, dry in drought | Green | Green |
| Aug | Deep green, tasselled | Dark green | Stubble, gold-brown; some cover crop | Third cut | Yellowing in drought | Fruit colour | Veraison |
| Sep | Leaves drying at the bottom; silage harvest | Leaves yellow then drop; brown pods | Seeding begins late Sep | Green | Green | Harvest | Harvest begins |
| Oct | Tan, dry; grain harvest Oct to Nov | Harvest late Sep to Oct; tan stubble | Seeded fields show green rows | Last growth | Green | Leaves turning | Harvest ends; yellow leaves |
| Nov to Dec | Stubble, some fields unharvested into winter | Stubble | Green rows | Brown | Brown | Bare | Bare |

**Suggested base colours (D, for the 2D map and far LOD tint; pass Robert's colour audit before release):**

| Stage | Hex |
|---|---|
| Bare tilled soil (dark loam) | #5b4a3a |
| Bare soil, light (clay, sand) | #9c8466 |
| Emerged rows | #7d8a4a |
| Full canopy corn | #2f6b2a |
| Full canopy soy | #3e7a32 |
| Ripe wheat | #d8b45a |
| Stubble | #b9a272 |
| Dry corn | #bfa46a |
| Senescent soy | #c9a43c |
| Hay, fresh cut | #9fae5a |
| Snow | #eef2f4 |

Each field carries a `stage` value (section 6.3) so the game picks a material and a far colour. Fields in one region should not all be at the same stage: offset planting and harvest by 0 to 21 days per field (D), drawn from a seeded per-field value. Rotation (D): corn, soy, wheat in a 3 year cycle on 60 percent of cash-crop fields; corn and soy alternate on 30 percent; hay stays 3 to 5 years.

### 2.4 Farmsteads [ON]

| Element | Size | Placement rule | From the air (50 to 500 m) | Tag |
|---|---|---|---|---|
| Farm lane | 3 to 5 m gravel | Straight from the concession road to the farmyard; may continue as a grass track between fields to the woodlot at the back | Pale line ending in a yard | D |
| Farmhouse | 10 x 12 m to 12 x 15 m, 1.5 to 2 storeys; Ontario Gothic (centre gable), brick or frame | 15 to 60 m from the road, facing it; front lawn, large maples along the road | Red-brick or white box, steep roof, big shade trees | V/D |
| Bank barn | Many records show 11 x 15 m to 14 x 20 m (36 x 48 ft, 46 x 64 ft) with additions (S [35], US records); an Ontario-style bank barn is tall with a steep gable and a ramp to the upper floor (S [35]) | 30 to 100 m behind or beside the house, built into a slope where possible, ramp on the high side; downwind (east) of the house (D) | Long gable roof, red, grey or weathered; a ramp and a stone foundation | S/D |
| Modern livestock barn (dairy free-stall, hog, poultry) | 25 to 40 m wide, 60 to 150 m long, low pitch, white or grey | MDS from neighbours' houses [7]; next to the manure storage | Long white roofs, curtain sides, a round manure tank or lagoon | V |
| Silo, concrete stave | about 4.5 to 6 m diameter (15 ft recorded, S [35]); 15 to 25 m tall (V); steel hoops about 38 cm apart (S [35]) | Against the barn's end or side (S [35]); 1 to 4 in a row | Grey cylinder with a domed or conical cap; strong vertical landmark | S/V |
| Silo, glass-lined steel ("blue silo") | 6 to 9 m diameter, 20 to 30 m (V) | Dairy farms | Dark blue cylinder, white trim | V |
| Grain bins | 5 to 15 m diameter, 6 to 15 m eave, cone roof; with a leg (tall elevator tower) and a dryer (V) | Cash-crop farms, grouped 2 to 8 around a leg | Silver corrugated drums | V |
| Bunker silo and bale wrap | Concrete walls 3 to 4 m high; white plastic with black tyres; wrapped bales in long white "marshmallow" rows (V) | Behind the barn | White rectangles and rows | V |
| Machine shed | 15 x 30 m to 25 x 60 m steel | Beside the yard | Grey or coloured steel roof | V |
| Windbreak | 3 or more rows of mixed species (S [36]); protection out to 10 to 20 times tree height (S [36]); do not enclose all four sides (S [36]) | On the north and west sides of the farmyard (prevailing NW winter wind) (D) | Dark L of conifers around the yard | S/D |
| Farm pond | 0.05 to 0.5 ha (V) | In a low spot near the barn or a field corner, fed by a ditch | Small dark pond, often algae green | V |
| Kitchen garden and orchard | 0.05 to 0.3 ha; an apple tree, asparagus, rhubarb and a lilac are the traditional four (S [31]) | Beside the house | A few old fruit trees and a lilac clump | S |
| Yard | gravel 30 x 60 m (D) | Between house and barn | Pale gravel, machinery parked | D |

**Farmyard template (D):** a 60 to 120 m square plot at the road end of the lot. House near the road; barn behind; silos at the barn end; machine shed and bins along one side; windbreak on the north and west edges; pond downhill. Mirror the template per farm and jitter angles by up to 5 degrees.

### 2.5 Hedgerows, fences, ditches and tile drains [ON]

* **Fencerows and hedgerows** (D): along lot lines and between fields, 3 to 10 m wide, trees 10 to 20 m tall (maple, ash, hawthorn, buckthorn), with gaps at field gates (5 to 8 m). Remove 0 to 80 percent of interior fencerows by farm type (cash-crop farms remove most).
* **Fences** (V): page wire or barbed wire on cedar or steel T-posts every 3 to 5 m; stone fences (piles of field stone) along old fence lines in stony areas; split rail fences in old pasture.
* **Ditches** (V): roadside ditches 1 to 1.5 m deep, 3 to 5 m from the road edge; **municipal drains** (open drains 2 to 4 m deep with spoil banks) follow lot lines and outlet to creeks.
* **Tile drains** (S [55]): laterals at about 0.65 to 0.85 m depth and 4.6 to 7.5 m spacing in a Harrow trial; laterals run across or at an angle to the tillage direction (S [55]). In spring, after rain on bare soil, tile lines show from the air as faint parallel light and dark stripes, a lovely drone detail (V).

### 2.6 Woodlots [ON]

* **The back forty (D):** woodlots sit at the far end of the lot from the road, where the land was cleared last or was wettest or stoniest. Because neighbouring lots do the same, woodlots join into **bands mid-concession**, parallel to the roads. This is the single most recognisable pattern of southern Ontario from the air.
* **Size (D):** 2 to 20 ha per lot, joined bands of 20 to 200 ha.
* **Targets (S):** Environment Canada recommends at least 30 percent forest cover in a watershed for marginally healthy aquatic systems, with 40 to 50 percent better (S [18]). Bruce County treats woodlots of 40 ha or more as significant where township cover is under 30 percent (S [10]).
* **Generator rule (D):** set a target forest cover per township (10 to 25 percent in cash-crop counties, 25 to 50 percent in mixed farming areas). Fill the back third of lots first, then wet soils, steep slopes and creek valleys, until the target is met.

### 2.7 Rural roads [ON]

| Class | ROW | Surface | Cross-section | Tag |
|---|---|---|---|---|
| Concession or side road (township) | 20.1 m (66 ft) allowance (S [1]) | Gravel, 6 to 7 m travelled | Crowned, ditches both sides, poles on one side | S/V |
| County road | 26 to 30 m (widened allowance) (V) | Paved, 3.3 to 3.5 m lanes, 1 to 1.5 m gravel shoulders | Ditches, guide rail at culverts | V |
| Provincial highway (two-lane) | 30 to 36 m (V) | Paved 3.5 to 3.75 m lanes, 2 to 3 m shoulders, part paved | Ditches 1 to 1.5 m deep, back slopes 2:1 to 3:1 | V |
| Farm lane | n/a | Gravel or grass, 3 to 5 m | | D |
| Unopened allowance | 20.1 m | Grass track or hedgerow | Fence lines both sides | D |

### 2.8 Hamlets [ON]

Hamlets are settlement areas much smaller than towns and villages, usually on private wells and septic systems, and not places where growth is directed (S [9]). Bruce County treats them as local service centres with a limited range of uses (S [10]).

* **Spacing (D):** one every 5 to 10 km in older settled counties, usually at a concession and side road crossing, a mill site on a creek, or a rail station.
* **Contents (D, ordered by probability):** 8 to 60 houses on 0.2 to 1 ha lots strung along both roads for 200 to 600 m; a church (60 to 80 percent of hamlets) with a cemetery beside it or on a nearby knoll; a general store or variety store (often closed now); a community hall; a former one-room school (S.S. No. n, often now a house); a gas station or garage; a feed mill or grain elevator near the rail line; a ball diamond; a fire hall.
* **Cemetery (V):** 0.2 to 1.5 ha, rectangular, rows of headstones facing east, a cedar hedge or wire fence, a gate, big old trees.

### 2.9 Rural infrastructure and other land uses

| Feature | Footprint | Placement and spacing | From the air | Tag |
|---|---|---|---|---|
| Country grain elevator | 0.5 to 3 ha; tall concrete or steel bins 20 to 40 m, a headhouse | At hamlets on rail lines or main roads; prairie wooden elevators were once spaced every few miles along rail lines (V) | Tallest thing for 10 km; silver or white cylinders | V |
| Rail siding | 0.5 to 2 km long | Beside the main line at an elevator or mill | Parallel track, hopper cars | V |
| Wind turbine | Pad 20 x 20 m, crane pad, gravel access road; hub 80 to 120 m, rotor 80 to 140 m (V) | At least 550 m from noise receptors for turbines over 102 dBA (S [21]); road and lot line setbacks such as blade length plus 10 m (S [22], one project); spacing 3 to 5 rotor diameters across the wind and 6 to 10 along it (V); rows on farmland near Lake Huron and Lake Erie shores (V) | White towers, rotating; red night lights blinking in sync | S/V |
| Solar farm | 3 to 5 ha per MW (V); 5 to 40 ha | On flat, south-facing farmland or capped landfills; fenced; rows facing south | Dark blue-black stripes | V |
| Cell tower | Lattice or guyed, 40 to 90 m (V) | On hills, every 5 to 15 km in farm country (V); fenced compound 15 x 15 m | Thin mast, red lights at night | V |
| Distribution power line | Wood poles 12 to 14 m every 40 to 60 m (V) | Along one side of most concession roads | Pole line, shadows | V |
| Transmission line | 46 m corridor for 230 kV, towers 30 to 60 m (S [25]) | Straight lines across country; spans 300 to 450 m (V) | Lattice towers, cleared strip through forests | S/V |
| Gravel pit | 5 to 60 ha | On eskers, moraines and outwash sand; excavation 15 m from the site edge, 30 m from houses and highways, 50 m from water (S [10]) | Tan bowl, stockpiles, a pond if below water table, conveyors | S |
| Limestone quarry | 20 to 300 ha, benches 10 to 15 m (V) | Along escarpments and limestone plains | Grey stepped pit, haul roads, crusher | V |
| Golf course | 18 holes: 120 to 200 acres (49 to 81 ha), about 150 acres (61 ha) common (S [41], low-quality sources) | Rolling land near towns, along creeks; 11 parking spaces per hole (S [4]) | Bright mown fairways, sand bunkers, ponds | S |
| Conservation area | 20 to 2,000 ha | Valleys, wetlands, reservoirs; a gate, a parking lot, trails | Forest with a parking lot and trail lines | D |
| Fairground | 5 to 20 ha | Edge of a town; a racetrack oval (400 to 800 m), barns, grandstand | Oval track, long barns | V |
| Sugar bush | 5 to 40 ha of sugar maple | Back woodlots; sap tubing mainlines 30 to 45 m apart (100 to 150 ft, S [46]) running downhill at 2 to 4 percent slope to a sugar shack (S [46]) | Blue tubing webs in March; steam from the shack chimney | S |

---

## 3. Forests, wilderness and landscape features

### 3.1 Stand types [ON]

Heights and crowns are (V) unless marked. Colours are far-LOD tints (D). Robert's canopy grid for Squall Cove [R2] (cover 0 to 1 per 4 to 8 m cell, seasonal leaf factor, derived from crown placement) is adopted here as the forest rule layer; each stand type supplies its inputs.

| Code | Stand type | Species | Height | Stems and spacing | Summer cover | Leaf factor by season (summer, early autumn, peak, late, winter) | Far colour summer / autumn / winter | Where |
|---|---|---|---|---|---|---|---|---|
| FS1 | Tolerant hardwood (Great Lakes-St. Lawrence) | Sugar maple, beech, basswood, red oak, ash | 22 to 30 m | Mature: 150 to 300 stems/ha, mean spacing 6 to 8 m | 0.9 | 1.0, 0.9, 0.6, 0.25, 0.1 [R2] | #3f7a35 / #c8642a and #e0a43a / #7b6f66 | Upland loam, south of the Shield and on its southern edge |
| FS2 | GLSL mixedwood | Maple, white pine, hemlock, yellow birch, red oak | 22 to 30 m, white pine super-canopy to 35 to 40 m | Mixed | 0.9 | conifer share holds cover | #36683a / mixed / #3b4a3f | Shield edge, Algonquin, Muskoka |
| FS3 | Boreal conifer upland | Jack pine, black spruce | 12 to 20 m | Dense, 1,000 to 3,000 stems/ha in young stands | 0.6 to 0.8 | 0.9 all year | #2b4f35 | Sand and thin soils on rock, north of about 47 degrees N |
| FS4 | Boreal lowland conifer | Black spruce, tamarack | 6 to 15 m, spire crowns | Open to dense | 0.4 to 0.7 | 0.9; tamarack turns gold in October then bare | #2f4a36 / gold flecks | Peatlands, poorly drained flats |
| FS5 | Boreal mixedwood | Trembling aspen, white birch, balsam fir, white spruce | 18 to 25 m | | 0.85 | aspen gold late September | #3c6e34 / #d9b23c / grey-white trunks | Clay belts, better upland soils |
| FS6 | Red pine plantation | Red pine (also white pine, white spruce) | 15 to 25 m, even | Rows about 1.8 to 2.4 m apart (V), thinned by removing every 3rd to 5th row | 0.8 | 0.9 | #2e5a3a, visible row texture | Sandy farmland planted 1920s to 1970s (county forests, e.g. Simcoe) |
| FS7 | Regeneration after harvest | Saplings of the original or pioneer species | 0 to 8 m | Very dense | 0.1 to 0.6 by age | follows species | brown slash then bright green | Cut blocks (3.2) |
| FS8 | Old growth | White pine, hemlock, maple, oak | 30 to 40 m+, uneven | Big trees, snags, logs, gaps | 0.8 with gaps | | rough texture, gaps | Rare patches, parks |
| FS9 | Swamp forest | Eastern white cedar, black ash, silver maple, red maple, tamarack | 12 to 20 m | Dense, wet | 0.85 | cedar holds cover | dark green, standing water in spring | Floodplains, wet depressions, along creeks |
| FS10 | Ravine and escarpment forest | Hemlock on cool north slopes, maple and oak on south slopes | 20 to 30 m | Steep ground, roots, logs | 0.85 | per species | as FS1 / FS2 | Valley walls; detailed in [R2] |
| FS11 | Burn, 0 to 15 years | Standing dead snags, fireweed, then aspen and jack pine | Snags 10 to 20 m | Snag forest | 0.1 to 0.4 | | grey and black, pink fireweed in July to August, then bright green | Fire perimeters (3.2) |
| FS12 | Hedgerow and windbreak (linear) | Mixed | 10 to 20 m | 1 to 5 rows | 0.8 | | | Lot lines, farmyards (2.4, 2.5) |
| FS13 | Rock barren, savanna and alvar | Scattered pine, oak, juniper, lichen | 2 to 15 m | Very open | 0.1 to 0.3 | | grey-pink rock, scattered dark trees | Shield ridgetops, limestone plains |

**Forest region selection (D):** pick the biome from latitude and the Shield mask. South of the Shield: FS1, FS2, FS6, FS9, FS10 in woodlots and valleys. Shield south of about 46.5 degrees N: FS2 dominant, FS13 on ridges, FS4 and wetlands in lowlands. North of about 47 to 48 degrees N: FS3, FS4, FS5, FS11.

### 3.2 Disturbance: fire and harvest [ON]

**Fire (S/D):** stand-replacing fire in the central boreal has mean return intervals of roughly 190 to 230 years at two northwestern Ontario sites, with large ranges (S [56]); black spruce and jack pine forest about 200 years (S [56]). Generator (D): divide the boreal area into fire patches using a power-law size distribution (most fires small, most burned area from a few large fires), elliptical shapes stretched downwind 2:1 to 4:1, with unburned islands covering 5 to 15 percent of the inside and ragged edges. Assign each patch an age from an exponential distribution with the region's mean return interval. The age sets the stand stage: 0 to 15 years FS11, 15 to 60 years young FS3 or FS5, older mature.

**Harvest (S/D):** Ontario's natural disturbance emulation guide set a standard that most planned clearcuts be under 260 ha: 80 percent in the boreal and 90 percent in the Great Lakes-St. Lawrence forest by count; the rest can be larger if justified (S [17]). Generator (D):
* Cut blocks: irregular polygons 20 to 260 ha (10 percent larger, up to 1,000 ha+ in the boreal), clustered around a road network.
* Residual patches: 2 to 10 percent of each block left standing as islands (D).
* Shoreline and stream buffers: no cutting within 30 m of water (D; Ontario's stand and site guide uses wider buffers on slopes, verify), so a strip of mature forest always lines lakes and rivers.
* Landings: 0.25 to 1 ha cleared yards at the roadside every 0.5 to 1 km, with piled slash (D).
* Skid trails radiate from landings at 30 to 60 m spacing (D).
* Age the blocks from 0 to 40 years; 0 to 3 is brown slash and stumps, 3 to 10 dense green regeneration, 10 to 40 a sharp-edged young forest lower than the neighbours.
* In the GLSL forest, partial cuts (shelterwood and selection) are common: leave 40 to 70 percent cover and mark skid trails only (D).

### 3.3 Edges and gaps

* **Interior forest** begins about 100 m from an edge, the common Ontario benchmark (S [50]); some frameworks use a second class at 200 m (S [50]). In a northwestern Ontario study, most edge effects weakened within 10 m, some reached 40 m (S [50]).
* **Generator (D):** compute distance-to-edge for every forest cell. Within 0 to 15 m of an edge use denser low shrubs and more saplings (an edge "wall" seen from fields); from 15 to 100 m normal stand; beyond 100 m mark `interior = true` (useful for wildlife spawns like the deer, owls and wolves in section 5).
* **Canopy gaps (D):** single tree-fall gaps 50 to 400 m2 at 2 to 6 per ha in FS1, FS2 and FS8; larger blowdown patches 0.5 to 5 ha at 1 per 2 to 10 km2.

### 3.4 Shield, water and landform features [ON]

| Feature | Size and numbers | Placement rule | From a drone | Tag |
|---|---|---|---|---|
| Rock outcrop | 5 to 40 percent of ridgetops exposed (D) | On convex ridges and steep slopes over about 20 degrees, where soil is thin; elongated parallel to glacial flow (NE-SW in much of central Ontario, V) | Pink-grey granite or grey gneiss, black lichen streaks, pines clinging in cracks | D/V |
| Lakes | Ontario has more than 250,000 lakes (S [45]); one area of 250 square miles in western Ontario had 700 lakes, about 1.1 per km2 (S [45], C) | Fill depressions in rock-basin terrain (Chapter 1 priority flood keeps depressions as lakes); size follows a power law; long axes follow structure and ice flow; many islands; lakes chain into each other through rapids (S [45]) | Black to tea-brown water, rocky shores, islands with pines | S |
| Beaver pond and dam | Colonies 0.4 to 0.8 per km2 in BC typical, more at saturation (S [19]); dams about 3 to 11 per km on small streams (S [19]) | On streams of order 1 to 4 with gradient under about 6 percent (D), in valleys narrow enough for a dam 5 to 100 m long; ponds 0.1 to 5 ha; abandoned ponds drain into "beaver meadows" | Ring of grey drowned trees, a dark pond, a stick lodge 4 to 6 m across and 1 to 2 m high (V), a curved dam of sticks | S/V |
| Creek | Order 1 to 3, 1 to 8 m wide | From the Chapter 1 river network | Thin dark line through trees, alder fringe | |
| Rapids | 20 to 300 m long | At lake outlets and where the river crosses a ridge (gradient over 2 percent) | White water, rocks | D |
| Waterfall | 2 to 40 m drop | Where a stream crosses a cliff, the Niagara Escarpment edge or a fault scarp (D) | White plunge, mist on cold mornings; a swimming hole below | D |
| Bog | 1 to 500 ha | Raised peat in poorly drained flats, no inflow; pools; FS4 trees round the edges | Pale yellow-green and ochre sphagnum, dark pools, stunted spruce | V |
| Fen | 1 to 1,000 ha | Groundwater-fed lowlands; patterned "strings" (ridges) and "flarks" (pools) across the slope in the north | Sedge green, striped patterns | V |
| Marsh | 0.5 to 500 ha | Lake edges, river mouths, behind sand spits; cattails | Green-brown reeds with open water channels | V |
| Esker | 5 to 20 m high, segments up to 15 km in southern Ontario (S [38]); Canadian eskers often hundreds of km and nearly straight (S [38]) | Sinuous ridge of sand and gravel across lowlands, roughly along ice flow; often has a road or rail on top, gravel pits, pine forest, kettle lakes on both sides | Snaking pine-covered ridge, gravel pits | S |
| Drumlin | Typically 250 to 1,000 m long, 120 to 300 m wide (S [38]; British and Irish data); Peterborough field covers about 5,000 km2 with over 1,000 measured drumlins (S [38]) | In fields of hundreds, all aligned with ice flow; spacing 300 to 800 m (D); farms on top, swamps between | Rounded, streamlined hills like a school of fish | S/D |
| Cliff | 5 to 100 m | Escarpments, fault scarps, river gorges, lake shores; see Chapter 2 for the slope classification | Grey wall, talus below, cedars on the edge | |
| Cave | Small: talus caves, karst on dolostone, mine adits (V) | At cliff bases on limestone or dolostone; at old mines | A dark opening at a cliff foot | V |

### 3.5 People in the wild [ON]

| Feature | Size | Placement and spacing | From a drone | Tag |
|---|---|---|---|---|
| Hiking trail | 0.5 to 2 m | Ridges, lakeshores, between viewpoints; loops of 2 to 15 km; blazes on trees | Faint line through canopy gaps, lookout clearings | D |
| Canoe portage | 1 to 1.5 m, 50 to 3,000 m long (V) | Around every rapid or falls and between lakes on canoe routes; landing at each end | Thin path linking two waters, a canoe rest | V |
| Campsite (backcountry) | 10 to 20 m clearing | On points and islands, 2 to 5 per km of canoe route shoreline (D) | A tiny clearing on a point, a fire ring, a flat rock landing | D |
| Fire lookout tower | Mostly 80 ft (24 m) light steel; some 100 ft (30 m) heavy steel; Ontario had about 316 to 325 towers in the 1960s, now about 156 standing (S [20]) | On the highest hill in a 10 to 20 km radius (D), a cabin at the base, a trail up | Thin steel frame with a cab on top above the trees | S/D |
| Hydro cutline | 46 m for 230 kV (S [25]); 500 kV wider (not found) | Straight for tens of km, angle changes at towers on hills | A straight grass and shrub strip through forest; white in winter | S |
| Pipeline cutline | 15 to 30 m (V) | Straight, gentle bends, marker posts at roads | Grass strip, no towers | V |
| Logging roads | Primary 8 to 10 m gravel, secondary 6 m, tertiary 4 m and winter roads (V) | Primary roads follow eskers and ridges; branches every 1 to 3 km; landings | Pale sand roads in a dendritic pattern, cut blocks hanging off them | V |
| Mine | Headframe 20 to 60 m; mill; tailings 10 to 500 ha; waste rock piles; open pits (V) | On geology belts (Sudbury, Timmins, Red Lake, Kirkland Lake) | Grey or orange tailings ponds, rust-coloured water, a headframe | V |
| Dam and generating station | Concrete or timber control dams at lake outlets; generating stations at falls; log chutes on old ones (V) | At outlets of lake chains and at drops on large rivers | A straight wall across the water, spillway foam, a powerhouse, a switchyard and a transmission line leaving it | V |
| Provincial park campground | Loops of 30 to 100 sites, sites about 15 x 15 to 20 m (V), a comfort station per loop, a beach and a boat launch | Sandy lakeshores, near a highway | Loops of small clearings, cars and tents | V |
| Cottage cluster | Lot water frontage 60 to 90 m common (D); Muskoka Lakes requires 90 to 150 m frontage on slopes over 20 percent (S [43]); docks at most 25 percent of frontage width (S [43]) | On lakes within about 3 hours of cities; on bays and sheltered shores, south and west facing preferred; served by a private road from a county road; boathouses on the larger lakes | Roofs in trees every 60 to 100 m along the shore, docks, boats, a boathouse | S/D |
| Float plane base | Dock and ramp, 1 to 6 planes | Lakes near northern towns and fishing lodges | Planes on floats at a dock | V |

---

## 4. Highways and infrastructure

### 4.1 Cross-sections

| Class | Lanes | Lane | Shoulders | Median | ROW | Tag |
|---|---|---|---|---|---|---|
| Freeway, rural (Ontario 400-series style) | 2 to 3 each way | 3.75 m (V) | Outside 3.0 m paved; inside 1.0 to 3.0 m (full inside shoulder at 3+ lanes, S weak [59]) | 10 to 30 m depressed grass with cable or no barrier (V) | 90 to 110 m (V) | V |
| Freeway, urban | 3 to 8 each way, collector-express on the 401 | 3.75 m (V) | 3.0 m | Tall-wall concrete barrier 1 to 2 m wide | 60 to 150 m (V) | V |
| Two-lane rural highway | 1 each way, passing lanes every 10 to 20 km (V) | 3.5 to 3.75 m | 2.0 to 3.0 m, partly paved | none | 30 to 36 m | V |
| Arterial | see 1.3 | | | | | |
| Gravel road | see 2.7 | | | | | |

**[EU] note:** European motorways use 3.5 to 3.75 m lanes too, with narrower medians and frequent service areas; rural roads are narrower (5.5 to 6.5 m) and follow old field boundaries rather than a survey grid (V).

### 4.2 Design speed, curve radius and grade

The minimum radius follows the point-mass formula R = V squared / (127 (e + f)), where V is the design speed in km/h, e is superelevation and f is side friction. With the friction values below the formula reproduces a published table for e max of 8 percent exactly (60, 70 and 80 km/h give 113, 168 and 229 m; S [15], C). Use e max = 6 percent (the preferred maximum in the Canadian TAC framework, per a BC supplement, S [16] notes) for rural roads and 4 percent for urban roads with traffic lights.

| Design speed (km/h) | f (assumed, AASHTO-style) | R min, e = 0.04 (C) | R min, e = 0.06 (C) | R min, e = 0.08 (C) | Use |
|---|---|---|---|---|---|
| 40 | 0.23 | 47 m | 43 m | 41 m | Loop ramps, local roads |
| 50 | 0.19 | 86 m | 79 m | 73 m | Collectors, loop ramps |
| 60 | 0.17 | 135 m | 123 m | 113 m | Collectors, gravel roads |
| 70 | 0.15 | 203 m | 184 m | 168 m | Arterials, directional ramps |
| 80 | 0.14 | 280 m | 252 m | 229 m | Rural roads, arterials |
| 90 | 0.13 | 375 m | 336 m | 304 m | Rural highways |
| 100 | 0.12 | 492 m | 437 m | 394 m | Rural highways, urban freeways |
| 110 | 0.11 | 635 m | 560 m | 501 m | Freeways |
| 120 | 0.09 | 872 m | 756 m | 667 m | Freeways |
| 130 | 0.08 | 1,109 m | 950 m | 832 m | New Ontario freeways (130 km/h design speed exists in the MTO supplement, S [16]) |

**Desirable radius (D):** use 2 to 3 times the minimum where terrain allows, because real freeways rarely sit at the minimum.

**Maximum grades (S [14] for the freeway and arterial pattern; others V):**

| Class | Level terrain | Rolling | Mountainous |
|---|---|---|---|
| Freeway | 3 to 4 percent | 4 to 5 percent | 5 to 6 percent |
| Rural arterial (100 to 110 km/h) | 3 percent | 4 percent | 5 to 6 percent |
| Collector and county road | 5 to 7 percent | 7 to 9 percent | 9 to 10 percent |
| Local street | 8 percent | 10 percent | 12 to 15 percent |
| Logging or farm road | 10 percent sustained | 12 percent | 15 to 18 percent short pitches |
| Railway main line | under 1 percent preferred; the old US "standard" limit was 2.2 percent (S [12]) | | |
| Driveway | 10 to 15 percent | | |

Reduce the grade on railway curves by about 0.04 percent per degree of curve (S [12]).

**Vertical curves (V, AASHTO metric values from memory, verify):** K = L / A (curve length in metres per percent grade change). Crest K: 60 km/h 11, 80 km/h 26, 100 km/h 52, 120 km/h 95. Sag K: 60 km/h 18, 80 km/h 30, 100 km/h 45, 120 km/h 63. The Chapter 1 profile smoother should enforce these as a minimum curvature on the graded profile.

### 4.3 Interchanges

Spacing (S [11]): at least 1.6 km (1 mile) in urban areas and 3.2 km (2 miles) in rural areas between crossroads is the old Green Book rule; Caltrans adds 3 miles on rural Interstates; an access management manual recommends 3 and 6 miles. Use 2 km urban and 5 km rural as defaults (D).

| Type | Where | Ramp radii (C from 4.2) | Footprint outside the mainline ROW (D, estimates; calibrate by measuring OSM examples) | Notes |
|---|---|---|---|---|
| Diamond | Freeway to arterial, moderate traffic, least land (S [11]) | Straight ramps; terminals 120 to 200 m from the bridge | 6 to 12 ha, 500 to 800 m along the freeway | Two signalised or stop-controlled ramp terminals |
| Partial cloverleaf (parclo) | Freeway to arterial, the common Ontario 400-series form (V) | Loops R = 50 to 80 m (40 to 50 km/h) | 15 to 30 ha | One or two loops plus diamond ramps |
| Full cloverleaf | Older freeway to freeway or busy arterial; uses a lot of land and has tight loops (S [11]) | Loops R = 45 to 75 m | 25 to 45 ha | Weaving between loops; collector-distributor roads |
| Trumpet | Freeway end, toll road entrance, a T junction | One loop R = 50 to 80 m, one directional ramp R = 150 to 250 m | 10 to 20 ha | |
| Directional or stack | Freeway to freeway (e.g. 401 and 427) | Flyovers R = 200 to 400 m (70 to 90 km/h) | 30 to 80 ha; 2 to 4 levels, decks 7 to 25 m up | The best drone landmark in any world |
| Roundabout interchange, SPUI | Urban, tight sites | | 4 to 10 ha | |

**Ramp details (V):** deceleration lanes and tapers 150 to 250 m; acceleration 250 to 400 m; ramp lanes 4.0 to 5.0 m with shoulders.

### 4.4 Structures and roadside facilities

| Element | Rule | Tag |
|---|---|---|
| Overpass | Vertical clearance 5.0 to 5.3 m over a freeway (V); deck 1.5 to 2 m deep; spans 30 to 80 m. Approach fill rises about 7 m; at 4 percent the approach is about 180 m each side plus vertical curves (C), so 400 to 600 m of the crossing road is raised on a 2:1 sided embankment | V/C |
| Underpass | The crossing road dips 6 to 7 m into a cut; retaining walls in towns | V |
| Noise wall | Up to 5 m on Ontario freeways (S [54]); 2 to 3 m in many residential programs (S [54], anecdotal) | S |
| Sign gantry | Every 1 to 2 km near interchanges, 300 to 1,000 m before each exit (D) | D |
| Service centre | Ontario's 400-series have about 20 ONroute centres, spaced roughly 40 to 100 km (V); each 3 to 8 ha with fuel, a food hall and truck parking | V |
| Rest area or truck inspection station | Every 50 to 150 km; 1 to 3 ha (V) | V |
| Toll plaza | Not used in Ontario (Highway 407 is all-electronic with overhead gantries) (V); in the US and Europe plazas are 10 to 30 lanes wide, 100 to 250 m long with a canopy (V) | V |
| Weigh station | 1 to 3 ha beside the freeway, a scale building and ramps | V |
| Highway lighting | At interchanges only on rural freeways, continuous in cities (V) | V |

### 4.5 Railways

| Element | Rule | Tag |
|---|---|---|
| Main line grade | Under 1 percent preferred; 2.2 percent as a historic limit (S [12]); curve compensation 0.04 percent per degree (S [12]) | S |
| Main line curvature | 1 to 2 degrees is most common on main lines, under 1 degree for fast freight (S [13]); radius in m = 1746.4 / degree (C): 1 degree = 1,746 m, 2 degrees = 873 m, 10 degrees = 175 m (matches 573.7 ft, S [12]) | S/C |
| Industrial spur curvature | Up to about 12.5 degrees (R about 140 m) (S [13]) | S |
| ROW | About 30 m (100 ft) (V); development setbacks from the property line as in 1.5 (S [53]) | V |
| Subgrade | 7 to 8 m wide for single track, ballast shoulders, ditches; double track adds 4.3 to 4.6 m track centres (V) | V |
| Yards | Classification yards 3 to 5 km long, 200 to 500 m wide (V); small yards 1 to 2 km | V |
| Passing siding | 2 to 4 km long (V), every 15 to 30 km on single track (V) | V |
| Level crossing | On most rural roads; crossbucks, plus lights and gates on paved roads (V) | V |
| Bridges and trestles | Steel truss or deck girder over rivers; timber trestles on old branch lines; embankments up to 10 to 15 m across valleys | V |
| Abandoned lines | Many Ontario branch lines are now rail trails: a straight, level, tree-lined grade with old bridges and station sites | V |

**From a drone:** rails are the straightest, flattest lines in the landscape. Long cuts and fills, gentle curves, grey ballast, a pole line beside older track.

### 4.6 Bridges and culverts (D)

* Every road and stream crossing gets a culvert if the upstream drainage area is under about 5 km2, a box culvert or a short bridge from 5 to 50 km2, and a bridge above that (D; real practice sizes these by design flow).
* Culvert sizes (D): 0.6 m round under drives, 0.9 to 1.8 m under roads, concrete boxes 2 to 4 m.
* Bridge length (D): channel width plus 2 x 10 m; add floodplain spans where the valley is flat.
* Keep the fill continuous across a culvert in the heightmap and mark the crossing in `roads.json` so water passes through the embankment (Chapter 1 hydrology must not see the road as a dam).

### 4.7 Airports and airstrips

ICAO and Transport Canada use a code number by runway length and a code letter by wingspan; Transport Canada's TP 312 follows the ICAO method (S [34]). The width and length figures below are the widely reproduced ICAO Annex 14 values (V); TP 312 itself was not read.

| Class | Runway length | Runway width | Other | Tag |
|---|---|---|---|---|
| Farm or private grass strip | 500 to 900 m | 20 to 30 m mown, 15 to 18 m used | Windsock, a hangar or two, cones; aligned with the prevailing wind (W to SW in southern Ontario, D) | V/D |
| Small public aerodrome (code 1 to 2) | 800 to 1,200 m | 18 to 23 m | Taxiway, apron, fuel, rotating beacon | V |
| Regional airport (code 3) | 1,200 to 1,800 m | 30 m (DHC-8 class needs 30 m, S [34]) | Terminal, FBO hangars, approach lights | S/V |
| Large airport (code 4) | 1,800 to 3,500 m | 45 m (60 m for the largest jets) | Parallel taxiways, terminals | V |
| FAA groups [NA] | Design group I under 49 ft wingspan, II 49 to 79 ft, III 79 to 118 ft (S [34]) | | | S |
| Water aerodrome | 1,000 to 2,000 m of clear water | | Dock, float plane base | V |
| Heliport | 15 to 30 m pad | | Hospital roofs, remote bases | V |

### 4.8 Ports, marinas and water infrastructure (V)

Marina slips 3 to 5 m wide and 9 to 15 m long on floating docks; fairways at least 1.5 times boat length; armour-stone breakwaters; boat launch ramps at 12 to 15 percent. Great Lakes ports have bulk piers, grain terminals, and lighthouses on breakwater ends.

### 4.9 Utilities and services

| Feature | Footprint | Placement | From the air | Tag |
|---|---|---|---|---|
| Transformer station | 1 to 5 ha | Where transmission lines meet, near towns | Fenced gravel yard of steel frames and transformers | V |
| Distribution substation | 0.2 to 0.8 ha | Every few km in towns | Small fenced yard | V |
| Water tower | Tank 10 to 20 m across, 30 to 50 m tall | One per serviced town or pressure zone, on high ground | A big painted ball or cup on legs; often the town name | V |
| Pumping station | 10 x 15 m building | At low points and treatment plants | Small brick building | V |
| Water treatment plant | 1 to 10 ha | Lakeshore or river intake | Rectangular tanks | V |
| Sewage lagoon | Cells 2 to 10 ha each, 2 to 4 cells | Edge of small towns and hamlets with sewers; separation 100 m (under 500 m3 per day) to 150 m (up to 25,000 m3 per day) (S [49]) | Rectangles of green-brown water with berms and a gravel ring road | S |
| Landfill | 10 to 100 ha, mounded 15 to 40 m | Study area 500 m (S [49]); on clay away from water | A grassy flat-topped mound with gas wells, an active face with gulls, a scale house | S/V |
| Pipeline | Buried, 15 to 30 m cleared | Straight between pumping and compressor stations | Cutline with yellow marker posts | V |
| Wind farm | see 2.9 | | | |

### 4.10 Routing infrastructure across terrain

This expands Chapter 1 section 4.7 (arterials by least-cost path) and 4.8 (carving).

**Route search (D):**

```
grid: cost cells at 10 m (tier S and M) or 20 m (tier L)
state: (cell, heading in 16 directions) so turning is costed (a "state lattice")
edge cost =
    length
  * (1 + w_slope * max(0, grade - g_pref[class]) / (g_max[class] - g_pref[class]))^2
  * landcover_factor              forest 1.2, farmland 1.0, wetland 4, built-up 20 (D)
  + turn_cost(heading change, class)   reject turns tighter than R_min (4.2)
  + earthwork(cut/fill estimate from the local height difference to a smoothed profile)
hard limits:
  grade > g_max[class]       -> forbidden (except switchbacks for track and logging road)
  water: forbidden, except as a bridge edge whose cost = c_bridge[class] * span_m
  wetlands inside the Greenbelt-style 30 m buffer -> cost x 10 (S [9] for the buffer width)
  slopes over 35 degrees     -> forbidden for all road classes (needs a tunnel; tunnels only by request)
attractors:
  survey allowances (1.1) cost x 0.5 for rural roads in Ontario-style worlds, so roads follow the grid
  existing roads cost x 0.3 (Chapter 1)
order: rail mains, then freeways, then highways, arterials, collectors, local, tracks.
```

`g_pref` is the comfortable grade (D: freeway 2 percent, highway 3, arterial 4, collector 6, local 8, track 10, rail 0.5) and `g_max` the table in 4.2.

**Ontario quirk (D):** concession roads go straight over hills on the allowance, accepting 8 to 12 percent grades for short pitches, and only bend where a lake, a swamp or a cliff makes the allowance impossible (a "deviation" road that leaves and rejoins the allowance). Highways and railways do not follow the grid.

**Vertical profile (D):** after the horizontal line is chosen, sample every 5 m, solve a smoothed profile with grade limits and the K values from 4.2, minimising cut and fill (a 1D constrained least-squares pass, as Chapter 1 describes). Then:

* fill over 10 to 12 m: bridge or viaduct;
* cut over 15 to 20 m in soil: reroute or accept a deep cut with benches every 6 to 8 m;
* a crossing of a river or a road of equal or higher class: bridge, with the profile raised for clearance (5.3 m for roads, 7 m for rail, more for navigable water).

**Heightmap changes (D, cross-section templates):**

```
for each terrain sample p near the corridor:
  s  = nearest station on the centreline; z_r = profile height at s; d = lateral offset
  half = roadbed half-width (pavement + shoulders + 0.5 m)
  if d <= half:                     h = z_r - crown(d)         crown 2 percent paved, 3 to 4 percent gravel
  else if rural and d <= half+ditch: h = z_r - ditch_depth * ditch_shape(d)   ditch 0.6 to 1.5 m deep
  else:
     run = d - half - ditch_w
     if terrain above road (cut):  h = min(h_terrain, z_r + run / cut_ratio)
     if terrain below road (fill): h = max(h_terrain, z_r - run / fill_ratio)
side slopes (run per rise): fill 3:1 near traffic (clear zone, under 6 m tall), 2:1 above;
  cut in soil 2:1, in rock 0.25:1 to 0.5:1 (near-vertical rock cuts are classic on Shield highways)
retaining wall where the side slope footprint would hit a building, water or a property line in towns
blend: smooth the last 2 to 4 samples into the natural ground
```

**Rock cuts (D):** on the Shield, highways blast straight through ridges, leaving pink and grey rock walls 5 to 20 m high on both sides with drill marks: a strong, cheap regional signature.

**Railways:** same templates with a 7 to 8 m subgrade, 2:1 fills and 1.5:1 cuts (V), stricter grades and radii.

**Rules for water and wetlands (D):** never fill a lake or a mapped wetland except at a crossing; at a crossing use a bridge, or a causeway with culverts for small wetlands; keep a 30 m buffer from wetlands for parallel routes where possible (S [9] for the buffer width as a planning rule).

---

## 5. Abandoned and surprising places

### 5.1 Design principles for discoveries

* **Points and lines.** Breath of the Wild was planned around high landmarks (towers) and the routes between them, with events placed along the routes (S [30]). From any point, a player should see at least one landmark and a couple of points of interest (S [30], a gamedev write-up of the same idea; Metro Exodus uses a similar rule). Disney's "weenie" is the same idea: a tall object pulls people toward it (S [30]).
* **Reward looking, not grinding.** Discoveries reward a drone pilot who goes low, looks at odd shapes and follows lines (old rail grades, lilac clumps, straight tree rows). No timers, no countdowns, no gore (Robert's standing rules); plain-word messages that can be read aloud.
* **Truth to place.** Each type has a real reason to be where it is. A ghost town sits on a dead rail line near a mine; a homestead ruin sits on a lot that was merged into a bigger farm; a fire tower sits on the highest hill.
* **Readable from the air.** Every type has one strong aerial cue (colour, shape, or a pattern break) defined in the catalogue.

### 5.2 Rarity tiers

| Tier | Share of placed discoveries (D) | Minimum spacing between two of the same type (D) | Message style |
|---|---|---|---|
| Common | 60 percent | 150 m | One short sentence |
| Uncommon | 28 percent | 400 m | Two short sentences |
| Rare | 10 percent | 1.5 km | Two to three sentences and an optional "story" link |
| Legendary | 2 percent, at most 1 to 3 per world | 4 km | A small story chain across 2 to 4 sites |

### 5.3 Surprise budget per km2 (D)

These are design defaults to tune by play. They count only discoveries from this catalogue, not ordinary buildings.

| Region type | Discoveries per km2 | Notes |
|---|---|---|
| Urban core | 0.5 to 1 | Mostly handled by the urban chapter |
| Suburb | 0.5 to 1 | Ravine finds, hydro corridor, a backyard rink in winter, a drive-in on the edge |
| Farmland (old settled) | 1.5 to 3 | The richest: foundations, lilacs, barns, cemeteries, orchards |
| Southern forest and woodlot bands | 1 to 2 | Sugar bush, cabins, deer, old roads |
| Shield wilderness | 0.5 to 1.5 | Wider spacing, bigger rewards: plane wreck, fire tower, mine, ghost town |
| Highway corridor | 1 per 2 to 5 km of road | Motels, gas stations, roadside giants |
| Lake shore | 1 per 2 to 4 km of shoreline | Wrecks, old docks, lighthouses, cottages |

AeroSim's world is 4 km wide (16 km2) [R5][R6]. At a mixed farmland and forest budget of about 1.5 per km2 it gets about 24 discoveries: about 14 common, 7 uncommon, 2 rare, 1 legendary (C).

### 5.4 Catalogue

Columns: **id** (the POI type id used in the pack), **rarity** (C common, U uncommon, R rare, L legendary), **needs** (terrain and biome), **footprint** (m), **from the air** (how to spot it), **kit** (semantic asset pieces, same naming style as Chapter 1 prop families), **sound** (optional), **message** (plain words, read aloud).

#### 5.4.1 Homesteads, farms and rural life

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.homestead_ruin | C | Farmland or regrown woods on an old lot; near an old road or allowance; slope under 10 degrees | 20 x 20 | A rectangle of stone foundation in grass or young trees; a lilac clump; 1 to 4 old apple trees; a chimney stub. Lilacs, apples, maples outlast buildings (S [31]) | ruin.foundation_stone, ruin.chimney, shrub.lilac_old, tree.apple_old, plant.rhubarb | wind, a crow | Someone farmed here long ago. The lilacs still bloom each spring. |
| disc.root_cellar | C | Next to a homestead ruin, in a slope | 4 x 6 | A grassy hump with a stone or timber doorway facing downhill | ruin.root_cellar | drip | An old root cellar, dug into the hill to keep food cool. |
| disc.barn_collapsing | C | Farm lot with no active farmstead or a merged farm | 15 x 25 | A sagging roof, a gap of sky through it, grey boards, a stone foundation, weeds | barn.bank_collapsed, ruin.foundation_stone, debris.boards | creak, pigeons | This barn is slowly falling in. Swallows nest in the beams. |
| disc.old_orchard | C | Farmland edge or woods; near a ruin or a lane | 40 x 60 | Rows of gnarled, wide trees in tall grass or among young forest; blossom white in May | tree.apple_old (rows, gaps), fence.wire_old | bees in May | An orchard nobody prunes any more. Deer come for the apples. |
| disc.farm_abandoned | U | Farm lot merged into another farm; house kept or empty | 100 x 100 | House with dark windows, overgrown lane, roof patches, rusting machinery in the yard | house.farm_empty, barn.bank_old, vehicle.tractor_rusted, silo.stave_capless | wind, a door | The family moved away. The fields are rented to a neighbour now. |
| disc.cemetery_old | C | Hamlet edge, church site, or a knoll on a farm lot; slope under 8 degrees | 20 x 40 to 80 x 120 | Rows of small pale stones in grass, a cedar hedge or iron fence, big old trees | cemetery.headstones (variants), fence.iron, tree.cedar_hedge, gate.iron | birdsong | An old cemetery. Some stones are too worn to read. |
| disc.pioneer_cemetery | U | Isolated in a field or woodlot | 10 x 15 | A tiny fenced square in the middle of a field that the plough goes around | cemetery.headstones_small, fence.iron | | A family burial plot. The farmer ploughs around it every year. |
| disc.one_room_school | U | Concession road corner, every few km | 10 x 15 | A small brick or frame box with a bell cupola, often now a house | building.schoolhouse_1room | | A one-room school once stood at this corner. Children walked here from every farm around. |
| disc.church_abandoned | U | Hamlet or crossroads | 12 x 25 | Steeple, boarded windows, a cemetery beside it | building.church_frame, cemetery.headstones | wind in the belfry | The congregation left years ago. The bell is still in the tower. |
| disc.sugar_shack | C (in season) | Sugar maple woodlot (FS1), March to April for steam | 8 x 12 | Blue tubing web in the trees, a shed with a steam plume from a roof vent | building.sugar_shack, line.maple_tubing, tank.sap | crackling fire, dripping | Maple sap is boiling here. It takes about forty litres of sap to make one litre of syrup. (ratio V) |
| disc.hunt_stand | C | Forest edge facing a field or trail | 2 x 2 | A tiny box or ladder stand at the edge of trees, a corn pile below | stand.ladder, stand.box | | A hunter's stand, looking out over the field edge. |
| disc.corn_maze | U (Sep to Oct) | Corn field near a road and a town | 150 x 200 | A pattern cut into corn that is only readable from above | crop.corn_maze_mask, parking.field, tent.farm_stand | voices, laughter | A corn maze. From up here you can see the whole puzzle. |
| disc.crop_circle | R | Wheat or barley field, June to July, out of sight of roads | 30 to 120 diameter | Flattened rings and circles in standing grain | crop.flattened_pattern_mask | silence | Strange circles in the wheat. Nobody saw who made them. |
| disc.stone_pile_fence | C | Stony farmland, along lot lines | 2 x 100 | A line of grey field stones with trees growing through | fence.stone_pile, tree.hedgerow | | Every stone here was carried off the field by hand. |
| disc.tile_lines | C (spring) | Bare cropland after rain | field | Faint parallel stripes in bare soil (V) | terrain decal only | | The stripes are drain tiles under the soil. They show when the field dries. |

#### 5.4.2 Roadside and highway

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.gas_station_abandoned | U | Old highway or a bypassed road | 30 x 40 | A canopy with no pumps or rusted pumps, cracked concrete with grass, a faded sign pole | gas.canopy_old, gas.pump_old, sign.pole_blank, building.kiosk | wind, a sign creaking | The new highway took the traffic. This station never reopened. |
| disc.motel_abandoned | U | Old highway, outskirts | 20 x 60 | An L or U of single-storey rooms around a cracked lot, an empty pool | motel.row, pool.empty, sign.pole_blank | | A roadside motel from the old highway days. The pool has been empty for years. |
| disc.roadside_giant | R | Highway edge in a small town | 10 x 10 | A giant figure (a fish, a goose, a coin, a farmer) taller than the trees | statue.giant (variants) | | A giant statue welcomes drivers to town. You can see it from a long way off. |
| disc.drive_in | U | Town edge on a highway; 4 to 8 ha | 250 x 250 | A big blank screen 40 to 60 ft tall (S [42]), curved rows of ramps facing it, a projection booth in the middle | drivein.screen, drivein.ramps, drivein.booth, sign.pole_blank | | An old drive-in theatre. The rows are tilted so every car can see the screen. |
| disc.old_highway_bridge | U | Where a highway was realigned beside a river | 10 x 60 | A short truss or concrete arch bridge leading nowhere, beside the new bridge | bridge.truss_old, road.abandoned_segment | water | The old road crossed the river here. The new bridge took its place. |
| disc.roadside_shrine | C | Rural road bend or crossroads | 2 x 2 | A small cross or box with flowers, white or painted | shrine.roadside | | A small roadside shrine, kept tidy with fresh flowers. |
| disc.abandoned_car | C | Field edge, woods near a track | 2 x 5 | A rusty car or truck in tall grass, trees growing through | vehicle.car_rusted, vehicle.truck_rusted | | This truck has not moved in a very long time. |
| disc.vehicle_graveyard | U | Rural lot behind a farm | 60 x 80 | Rows of rusting cars and machines in weeds | vehicle.car_rusted (many), vehicle.tractor_rusted | | A field full of old cars. Some are older than anyone who drives today. |
| disc.fruit_stand | C (summer) | Rural road near orchards | 6 x 8 | A small roofed stand with crates of colour | stand.fruit, sign.board_blank | | A farm stand. Payment goes in the box. |

#### 5.4.3 Rail, industry and towns

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.rail_grade | C | An old branch line route; level, straight, cuts and fills | 6 x 2,000+ | A straight tree-lined line with no rails, cuts through hills, embankments over valleys | path.rail_trail, fence.wire_old | | An old railway bed. The rails are gone but the line is still straight. |
| disc.station_abandoned | U | On a rail grade at a hamlet | 10 x 30 | A long low wooden building with a deep roof overhang, a platform edge, a freight shed | rail.station_wood, rail.platform | | Trains used to stop here several times a day. |
| disc.trestle | R | Rail grade crossing a valley | 8 x 80 to 300 | A timber or steel trestle high over a creek | bridge.trestle_timber, bridge.trestle_steel | water below | A railway trestle, built by hand over the valley. |
| disc.ghost_town | L | Dead rail line plus a mine or mill site in Shield country; Ontario examples include Lochalsh after a mine closed and Ramsey after its mill closed (S [48]) | 300 x 500 cluster | Grid of foundations, a few standing buildings, a church, a cemetery, lilacs and poplars, a rail grade | cluster: station_abandoned, homestead_ruin x 6 to 15, church_abandoned, cemetery_old, mine.headframe_old | wind, a loose sheet of tin | A whole town lived here when the mine was open. When it closed, people left in a year. |
| disc.company_town_mill | R | River with a falls, rail grade | 100 x 200 | A brick or stone mill with a dam and a millrace, empty windows | mill.stone, dam.timber_old, race.channel | falling water | The mill used the falls to turn its machines. The water still runs through the race. |
| disc.factory_abandoned | U | Town edge on a rail spur | 60 x 120 | Saw-tooth roof with holes, broken windows, trees in the yard, a chimney | factory.sawtooth, chimney.brick | pigeons | The factory closed decades ago. Trees grow on the loading dock. |
| disc.mine_headframe | R | Shield geology belt | 30 x 30 plus tailings | A tall timber or steel headframe, rust-orange tailings, a pit lake | mine.headframe_old, mine.tailings, mine.waste_rock | | A mine shaft goes straight down from here, hundreds of metres. |
| disc.quarry_lake | U | Old quarry below the water table | 100 x 300 | Vivid turquoise or deep blue water in a stepped grey pit | quarry.benches, water.quarry | | A flooded quarry. The water is clear and very cold. |

#### 5.4.4 Water and shore

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.shipwreck_shallow | R | Clear lake water under 10 m deep, near a harbour or a reef; Great Lakes estimates run from about 6,000 to many more wrecks (S [51]); the schooner Sweepstakes at Tobermory lies about 6 m down in clear water (S [51]) | 10 x 40 | A dark hull shape under clear water, ribs and a keel line | wreck.schooner_hull, wreck.ribs | lapping water | A sailing ship sank here more than a hundred years ago. You can see it from the air on a calm day. |
| disc.old_dock | C | Lake shore near a ghost town, mill or old resort | 3 x 40 | A line of rotting crib posts and stones running into the water | dock.cribs_old | | An old timber dock. Steamers once tied up here. |
| disc.lighthouse | U | Point, island or breakwater end on a large lake | 6 x 6 | A white or red tower on rocks, a keeper's house | lighthouse.tower, house.keeper | gulls, waves | A lighthouse still guards this point. |
| disc.beaver_lodge | C | Beaver pond (3.4) | 5 x 5 | A dome of sticks in a pond, a dam line, drowned grey trees | wildlife.beaver_lodge, wildlife.beaver_dam, tree.snag_grey | a tail slap | A beaver lodge. The family lives inside, under the sticks and mud. |
| disc.beaver_meadow | C | Drained beaver pond | 60 x 120 | A wet meadow with a creek meander inside a ring of forest and grey snags | meadow.wet, tree.snag_grey | | Beavers flooded this valley, then left. A meadow grew in the pond. |
| disc.hidden_pond | U | A closed depression in forest, more than 300 m from any road | 30 x 60 | A small round dark pond with no trail to it | water.pond_forest, plant.lily | frogs | A small pond, hidden in the woods. There is no path to it. |
| disc.waterfall_hidden | R | Stream over a cliff, more than 500 m from roads | 10 x 30 | White water falling into a pool | water.falls, rock.cliff_wet | rushing water | A waterfall that you can only reach on foot. |
| disc.ice_village | U (Jan to Mar) | Large frozen lake with bays near a town; Lake Simcoe huts must be off by March 15 (S [33]) | 300 x 600 | Dozens of small coloured huts in rows on the ice, plough tracks, trucks | ice.hut (variants), ice.plough_road, vehicle.pickup | wind, an auger | A village of ice fishing huts. It disappears every spring. |
| disc.float_plane_dock | U | Remote lake with a lodge | 20 x 40 | A float plane at a dock, a lodge and cabins | aircraft.float_plane, dock.wood, lodge.log | | A fly-in fishing lodge. The only road here is the lake. |

#### 5.4.5 Forest, wilderness and signal

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.log_cabin_ruin | C | Forest near water or an old track | 6 x 8 | Low log walls, a fallen roof, a stone chimney | cabin.log_ruin, ruin.chimney | | A log cabin, falling back into the forest. |
| disc.trapper_shack | U | Shield forest on a lake or creek, far from roads | 4 x 5 | A tiny shack with a stovepipe, a canoe rack | cabin.trapper, rack.canoe | | A trapper's shack. Someone still uses it in winter. |
| disc.hunt_camp | C | Forest on a track, Shield edge | 30 x 30 | A cabin or trailer, an outhouse, a meat pole, an ATV track | cabin.hunt, outhouse, trailer.old | | A hunt camp. It is busy for two weeks in November and empty the rest of the year. |
| disc.fire_tower | R | Highest hill within 10 km, Shield or forest | 6 x 6 | A steel frame 24 to 30 m tall with a small cab on top (S [20]) | tower.fire_lookout_80ft, cabin.small | wind in steel | A fire lookout tower. Watchers lived up here all summer looking for smoke. |
| disc.plane_wreck | L | Remote forest or a ridge, far from roads, under canopy | 15 x 20 | A glint of aluminium and a wing shape in a small tree gap; green and white paint | wreck.bush_plane, debris.metal | | The wreck of a small bush plane. The pilot walked out safely, and the plane was left where it fell. |
| disc.radar_station | L | High ground in the north; Pinetree Line stations closed in the 1970s and 1980s, some buildings left standing (S [32]) | 300 x 500 | A grid of empty barracks, a radome base ring, a sports field gone to weeds | radar.base_ring, building.barracks_empty, tower.radio | wind, a loose door | A Cold War radar station. It watched the sky for bombers until it closed in the 1980s. (CFS Lowther closed in 1987, S [32]) |
| disc.bunker | R | Hillside near a military area or a town | 10 x 20 visible | A concrete door in a hill, vent stacks, a fenced grass mound | bunker.door, bunker.vent, fence.chainlink | hum | A Cold War bunker. Most of it is underground. |
| disc.radio_mast | U | Hilltop or flat field | 10 x 10 base, guy wires to 100 m | A tall guyed mast with red lights | tower.guyed_mast | hum | A tall radio mast, held up by steel cables. |
| disc.stone_circle | R | Open hilltop or meadow | 20 x 20 | A ring of upright stones (modern folly, art installation, or mystery) | stone.standing (variants) | | A ring of standing stones. Nobody here is sure who set them up. |
| disc.eagle_nest | U | Tall white pine or snag near a big lake | 2 x 2 | A huge stick nest in the top of a dead tree | wildlife.nest_large, tree.pine_supercanopy | eagle call | A bald eagle nest. Eagles add to the same nest every year. |
| disc.deer_yard | U (winter) | Conifer stand (cedar, hemlock) near browse; deer travel up to 95 km to yards (S [44]) | 200 x 400 | Packed trails in snow under conifers, deer bedded in groups | wildlife.deer (herd), snow.trail_network | | A deer yard. Deer gather under the cedars here to get through deep snow. |
| disc.meadow_hidden | C | Forest clearing more than 200 m from roads | 50 x 80 | A sunny clearing full of flowers or ferns | meadow.flowers, log.fallen | insects | A sunny clearing deep in the woods. |
| disc.portage_trail | C | Between two lakes, around rapids | 1 x 100 to 1,000 | A thin path in trees linking two waters, a canoe rest | path.portage, rack.canoe_rest | | A portage. Paddlers carry their canoes along this path. |
| disc.tent_camp | C | Backcountry campsite on a point (3.5) | 15 x 15 | A coloured tent, a canoe pulled up, a thin smoke trail | tent.dome, canoe.on_shore, campfire | crackle | Campers on the point. Their fire is just smoke this morning. |
| disc.campfire | C (evening) | Campsite or cottage beach | 3 x 3 | An orange point of light at dusk, smoke | campfire, chair.muskoka | crackle | A campfire at the water's edge. |

#### 5.4.6 Gatherings and events

| id | rarity | needs | footprint | from the air | kit | sound | message |
|---|---|---|---|---|---|---|---|
| disc.fairground | U | Town edge | 300 x 400 | An oval track, long barns, a grandstand, a midway when the fair is on (late summer to early autumn, V) | fair.track_oval, fair.barn, fair.grandstand, fair.ride (variants) | music, crowds | The fall fair is on. There are cattle, pies and a Ferris wheel. |
| disc.rodeo_ground | R | Rural, flat | 80 x 120 | A dirt arena with pens and chutes, trailers parked around | rodeo.arena, rodeo.pens | crowd | A small rodeo arena with pens for the stock. |
| disc.festival_ground | U | Farm field or park, summer | 200 x 300 | A stage, tents, rows of cars on grass | stage.outdoor, tent.event, parking.field | music | A music festival in a farmer's field. |

### 5.5 Dynamic and seasonal surprises

These are events, not fixed sites. AeroSim already has birds, fireworks and balloons [R6]; this table adds the rest and gives rules (all D unless marked).

| id | When | Where | What it looks like | Frequency |
|---|---|---|---|---|
| evt.valley_fog | Clear, calm nights, late summer and autumn; dawn | Valley floors, over lakes and rivers, wetlands | White fog filling valleys up to 20 to 80 m, burning off by mid-morning | 1 in 4 suitable mornings |
| evt.aurora | Clear dark nights, more often further north | Whole sky | Green curtains, rarely red tops | Rare in the south; uncommon in the north |
| evt.geese | March to April, September to November [R6] | Over farmland and lakes | V formations; feeding flocks on stubble fields | Common in season |
| evt.wolves | Winter, Shield | Frozen lakes, logging roads | A pack of 3 to 8 crossing a lake, tracks in a line | Rare |
| evt.bear | May to October | Forest edges, berry patches, near campgrounds | One black bear in a clearing | Uncommon |
| evt.deer_herd | Dawn and dusk, all year | Forest edges next to fields; deer yards in winter (S [44]) | 3 to 15 deer; they lift heads and run when the drone is low [R6] | Common |
| evt.moose | Summer | Shield ponds and marshes | A moose standing in water | Uncommon |
| evt.wildfire | Dry summers, boreal and Shield | Forest, never in towns | A smoke column bending downwind, an orange front at night, water bombers | Rare; off by default; no damage to the player |
| evt.controlled_burn | Spring, savanna and prairie remnants, sometimes farm ditches | Small fenced plots | A slow low line of flame, crews in yellow | Rare |
| evt.rural_fireworks | Victoria Day weekend and Canada Day (V) | Farm fields, cottage lakes | Small bursts over a farmhouse or a dock | Uncommon in season |
| evt.county_fair | Late August to early October (V) | Fairground | Lights, rides, crowds | Once per fair site per year |
| evt.harvest | July (wheat), September to November (soy, corn) | Fields | A combine with a dust plume, a grain cart, a truck at the field edge | Common in season |
| evt.hay_baling | June to August | Hay fields | Windrows, a baler, round bales dropping | Common in season |
| evt.manure_spreading | Spring and autumn | Fields near livestock barns | A tractor and spreader leaving dark stripes | Common in season |
| evt.snowmobiles | January to February | Trails along rail grades and hydro lines (V) | Headlights in a line at dusk | Uncommon |
| evt.maple_steam | March to April | Sugar bush | Steam from the sugar shack | Common in season |

### 5.6 Placement algorithm (seeded, no overlap)

**Inputs:** heights, slope, water mask and polygons, road graph with corridor widths, buildings and lots, land use and cover, forest age and stand, season, the catalogue table above, the budget table, the world seed.

**Determinism:** all randomness comes from `rng(hash(world_seed, "disc", type_id, attempt))` with a counter-based generator (for example PCG or a SplitMix hash), never from iteration order of a hash map. Types are processed in a fixed order: legendary, rare, uncommon, common, then each list sorted by id.

```
1. Budget: for each region type r (painted or classified), area_r * density_r
   gives N_r. Split N_r into tiers by the shares in 5.2 (round with the seeded
   remainder). Cap legendary at 1 to 3 per world.

2. Masks per type t (boolean rasters on the cover grid):
   - land use and cover allowed (needs column)
   - max slope inside the footprint: 10 degrees for buildings and ruins,
     20 for small props, none for cliffs and falls
   - water: forbidden unless the type lives on or in water; for shore types,
     require distance to water within [0, d_shore]
   - roads: forbidden inside any road or rail corridor plus a buffer
     (buffer = 5 m for small props, 15 m for buildings)
   - distance to nearest road in [d_road_min[t], d_road_max[t]]
       roadside types (motel, gas station, shrine, giant): [10, 80] m
       farm types: [30, 800] m from a public road, on a lot with a lane
       hidden types (plane wreck, hidden pond, waterfall): [300, inf) m
   - season gates (sugar shack steam, ice village, corn maze)

3. Concealment score for hidden types: sample the road network every 25 m within
   600 m; cast a line of sight from 1.5 m above each road point to 2 m above the
   site (terrain plus canopy height from the canopy grid [R2]); concealment =
   1 - visible_fraction. Hidden types need concealment >= 0.9; roadside types
   need visibility >= 0.5. From the air everything is visible (except under
   full canopy, where only types marked "glint" or "gap" show).

4. Candidates: Bridson Poisson-disk samples inside each type's mask at radius
   min_spacing[tier]. Score each candidate:
     score = w1 * habitat_fit       (how well it meets the needs column)
           + w2 * story_fit         (near its narrative partners, step 6)
           + w3 * landmark_gap      (prefers areas with no landmark within 600 m)
           + w4 * rng_jitter
   Take the best-scoring candidates until the tier quota is met.

5. Footprint test (hard): build the oriented footprint (rectangle or circle,
   oriented to the nearest road, contour or shore). Reject if it intersects:
   any road or rail corridor polygon, water polygon (unless water type), any
   building or lot with a building, any already placed discovery footprint
   expanded by its spacing, or terrain whose height range inside the
   footprint exceeds dh_max[t] (2 m for buildings; flatten is allowed up to
   that). On reject, try the next candidate.

6. Narrative clusters: some types spawn children around them in a fixed
   pattern, then the children are tested with step 5.
     ghost_town -> rail_grade (through), station_abandoned (on the grade),
                   homestead_ruin x 6 to 15 on a small grid, church_abandoned,
                   cemetery_old (on a knoll within 400 m), lilac and poplar
                   groves, mine_headframe within 1.5 km
     farm_abandoned -> barn_collapsing, old_orchard, abandoned_car (50 percent)
     homestead_ruin -> lilac, 1 to 4 old apples, root_cellar (30 percent)
     plane_wreck -> story link to the nearest fire_tower or trapper_shack
     mine_headframe -> quarry_lake or tailings, company houses (ruins)
   Each cluster gets a story_id; messages can mention each other in plain words.

7. Landmark rule check: sample the world on a 300 m grid at 120 m altitude; each
   sample must see at least one landmark (tall structure, fire tower, water
   tower, silo group, steeple, mast, big lake, cliff) within 1.5 km. If not,
   promote a nearby discovery to a landmark variant (e.g. add a tall silo or
   a mast) or add a natural landmark (a lone big pine on a ridge).

8. Write markers (section 6.5). Record for each: id, type, tier, story_id,
   footprint, season gates, discovery radius (default 40 m horizontal and
   below 120 m above ground, D) and the message text key.

9. Validation (must pass, all deterministic):
   - same seed gives a byte-identical markers file
   - no footprint overlaps a road corridor, water polygon, building or another
     discovery (polygon test, zero tolerance)
   - every slope and height-range limit is met
   - tier counts within plus or minus 1 of the budget per region
   - every hidden type meets its concealment threshold
   - every cluster's children exist or the parent is removed
```

**Discovery trigger (D):** a discovery counts as found when the drone is within the discovery radius and the site is in the camera frustum for at least 1 second of flight (no countdown shown), or when the player photographs it (AeroSim's "photo goal" idea [R6]).

---

## 6. Outputs for the world pack

### 6.1 New layers

This chapter adds a **land-use** layer next to Chapter 1's land-cover layer. Land cover says what the surface is; land use says what it is for and drives buildings, props and seasons. All new files are optional (a minor version bump under Chapter 1's rules).

| File | Type | Contents |
|---|---|---|
| `landuse/use.u8.zlib` | uint8 raster on the cover grid | Use class ids (6.2 to 6.4) |
| `landuse/stage.u8.zlib` | uint8 raster | Season and growth stage: crop stage (0 bare, 1 emerged, 2 vegetative, 3 full, 4 ripe, 5 harvested stubble, 6 tilled, 7 cover crop), or stand age class for forests (0 to 255 years, capped) |
| `landuse/canopy.u8.zlib` | uint8 raster (4 to 8 m cells) | Summer canopy cover 0 to 255, and a parallel `canopy_h.u8` in metres; the Squall Cove canopy grid rule [R2] |
| `landuse/parcels.geojson` | polygons | Farm lots, fields (with crop, rotation, planting offset), woodlots, plaza sites, industrial lots |
| `network/lines.json` | polylines | Infrastructure and boundary lines (6.4) |
| `markers/markers.json` | existing | Adds `kind: "discovery"` and `kind: "event_site"` entries (6.5) |
| `landuse/class_table.json` | JSON | The tables below with colours and fallback cover classes |

The manifest gets a `landuse` block:

```json
"landuse": {
  "grid": "cover",
  "file": "landuse/use.u8.zlib",
  "stage": "landuse/stage.u8.zlib",
  "canopy": { "file": "landuse/canopy.u8.zlib", "height": "landuse/canopy_h.u8.zlib", "cell_m": 6 },
  "class_table": "use-standard-1",
  "season": { "month": 7, "day": 15, "hemisphere": "north" }
}
```

### 6.2 Use classes: suburban, commercial, industrial, civic

Colours are placeholders for the 2D map; they must pass Robert's colour-blindness audit. `cover` is the Chapter 1 fallback class.

| id | code | class | colour | cover | assets the class needs (semantic roles) |
|---|---|---|---|---|---|
| 20 | SB1 | Inter-war grid residential | #c9a27e | 13 | house.detached_2st_1920s, house.semi_1920s, garage.rear_small, tree.street_mature, fence.picket, lamp.street_old |
| 21 | SB2 | Post-war curvilinear residential | #d8b48f | 13 | house.bungalow_1950s, house.sidesplit, carport, tree.yard_mature, pool.backyard, fence.chainlink |
| 22 | SB3 | Late suburban subdivision | #e3c39f | 13 | house.detached_2st_garage2 (snout variants), house.semi_modern, fence.privacy_wood, fence.acoustic, deck, shed, pool.backyard, tree.street_young |
| 23 | SB4 | Estate residential | #efd9b9 | 13 | house.estate, drive.long_curved, tree.woodlot, ditch.roadside |
| 24 | SB5 | New urbanist (lanes) | #c48f6a | 13 | house.townhouse_lane, house.detached_lane, garage.lane, porch, parkette, lamp.street_heritage |
| 25 | SB6 | Townhouse and low-rise clusters | #b97d5d | 13 | house.townhouse_row, house.stacked_town, apartment.walkup_4st, parking.court |
| 26 | SB7 | Towers in the park | #9f6b56 | 13 | tower.slab_1960s, tower.point_1970s, parking.surface, lawn, playground |
| 30 | CV1 | School | #e6a3b5 | 7 | school.elementary_1storey, school.secondary, sportsfield.track, portable.classroom, playground |
| 31 | CV2 | Place of worship | #d98ca3 | 13 | church.suburban, church.steeple_frame, parking.surface |
| 32 | CV3 | Community centre, arena, library | #cf7f98 | 13 | civic.community_centre, arena.ice, sportsfield.soccer |
| 33 | CV4 | Park (neighbourhood, community) | #8cc46b | 7 | lawn, tree.park, playground, sportsfield.baseball, path.park |
| 34 | CV5 | Stormwater pond | #6fb3c2 | 1 | water.pond_swm, plant.cattail, path.maintenance, outfall.headwall |
| 35 | CV6 | Cemetery | #9fbf8f | 7 | cemetery.headstones, tree.cemetery, fence.iron, gate.iron |
| 40 | CM1 | Strip plaza | #e46b5a | 14 | retail.strip_bay, sign.pylon_blank, parking.surface, lamp.parking |
| 41 | CM2 | Neighbourhood centre | #da5a4c | 14 | retail.supermarket, retail.strip_bay, pad.bank, pad.fastfood_drivethru |
| 42 | CM3 | Community and power centre | #c94a40 | 14 | retail.big_box, retail.strip_bay, pad.fastfood, parking.surface_large |
| 43 | CM6 | Enclosed mall | #b33c36 | 14 | mall.enclosed, mall.dept_store, parking.surface_large, parking.deck |
| 44 | CM9 | Gas station | #f08a5d | 14 | gas.canopy, gas.pump, gas.kiosk_store, sign.pylon_blank |
| 45 | CM10 | Car dealership | #e5794f | 14 | dealer.showroom_glass, vehicle.car_display (rows), flag.pole |
| 46 | CM11 | Self-storage | #c86f4f | 14 | storage.row_units, storage.office, fence.security |
| 47 | CM12 | Hotel and highway services | #d77a63 | 14 | hotel.suburban_4st, service_centre.onroute_like, truck.parking |
| 50 | IN1 | Light industrial and flex | #9a8fb3 | 14 | industrial.flex, loading.dock, truck.trailer, fence.chainlink |
| 51 | IN2 | Warehouse and distribution | #8578a8 | 14 | warehouse.large, truck.court, truck.trailer (rows) |
| 52 | IN3 | Heavy industry | #6f6293 | 14 | factory.heavy, stack.industrial, tank.storage, rail.spur |
| 53 | IN4 | Office park | #a89cc6 | 14 | office.suburban_midrise, parking.surface, pond.ornamental |

### 6.3 Use classes: farmland and rural

| id | code | class | colour | cover | assets the class needs |
|---|---|---|---|---|---|
| 80 | AG1 | Corn | #c9b04a | 8 | crop.corn (stages 0 to 7), crop.corn_stubble |
| 81 | AG2 | Soybean | #a7b14a | 8 | crop.soy (stages) |
| 82 | AG3 | Winter wheat and small grains | #dcc36a | 8 | crop.wheat (stages), bale.straw_round, bale.straw_square |
| 83 | AG4 | Hay | #b8c46e | 6 | crop.hay, windrow, bale.hay_round, bale.wrapped_white |
| 84 | AG5 | Pasture | #9fbe6b | 6 | grass.pasture, fence.wire, trough, livestock.cattle, livestock.horse |
| 85 | AG6 | Orchard | #8faa4f | 9 | tree.apple_trellis, tree.apple_old, tree.peach, trellis.wire, bin.apple |
| 86 | AG7 | Vineyard | #7f9a4a | 9 | vine.row, post.vineyard |
| 87 | AG8 | Greenhouse | #dfe8ec | 14 | greenhouse.range_glass, greenhouse.poly_hoop, light.grow_glow |
| 88 | AG9 | Specialty (ginseng, sod, tobacco) | #6c7a44 | 8 | shade.ginseng_black, sod.stripes |
| 89 | AG10 | Fallow and old field | #b5b07a | 6 | grass.tall, shrub.hawthorn, tree.juniper |
| 90 | FM1 | Farmstead yard | #a68a6d | 13 | house.farm_gothic, barn.bank, barn.livestock_modern, silo.concrete_stave, silo.blue, bin.grain, shed.machine, tree.windbreak_conifer, pond.farm, shrub.lilac |
| 91 | FM2 | Rural residential lot | #c2a98b | 13 | house.rural_bungalow, drive.gravel, mailbox, tree.yard |
| 92 | HM1 | Hamlet core | #b58f78 | 13 | church.frame, store.general, hall.community, school.one_room, fire_hall, elevator.grain_country |
| 93 | EX1 | Gravel pit | #d1b98b | 5 | pit.face_sand, stockpile, conveyor, loader, water.pit_pond |
| 94 | EX2 | Quarry | #a9a39a | 3 | quarry.benches, crusher, haul_road, water.quarry |
| 95 | RC1 | Golf course | #7fd36b | 7 | golf.fairway, golf.green, golf.bunker, golf.tee, golf.clubhouse, cart_path |
| 96 | RC2 | Campground | #6fae67 | 12 | campsite.pad, comfort_station, picnic_table, firepit |
| 97 | RC3 | Fairground | #c3a6d8 | 6 | fair.track_oval, fair.barn, fair.grandstand |
| 98 | RC4 | Cottage lot | #b9b37e | 12 | cottage.small, boathouse, dock.floating, chair.muskoka, boat.runabout |
| 99 | EN1 | Solar farm | #3f4f6b | 6 | solar.row, fence.security, inverter.box |
| 100 | EN2 | Wind turbine pad | #e8e8e8 | 6 | turbine.wind_3blade, pad.crane, road.access_gravel |

### 6.4 Use classes: forest, wetland, natural, infrastructure areas

| id | code | class | colour | cover | assets |
|---|---|---|---|---|---|
| 110 | FS1 | Tolerant hardwood | #3f7a35 | 10 | tree.sugar_maple, tree.beech, tree.red_oak, tree.basswood, understory.sapling, log.fallen, canopy.sheet_deciduous |
| 111 | FS2 | GLSL mixedwood | #36683a | 12 | tree.white_pine_super, tree.hemlock, tree.yellow_birch, tree.maple, canopy.sheet_mixed |
| 112 | FS3 | Boreal conifer upland | #2b4f35 | 11 | tree.jack_pine, tree.black_spruce, ground.lichen, rock.outcrop |
| 113 | FS4 | Boreal lowland conifer | #2f4a36 | 11 | tree.black_spruce_spire, tree.tamarack, ground.sphagnum |
| 114 | FS5 | Boreal mixedwood | #3c6e34 | 12 | tree.aspen, tree.white_birch, tree.balsam_fir, tree.white_spruce |
| 115 | FS6 | Plantation | #2e5a3a | 11 | tree.red_pine_row, ground.needle_litter |
| 116 | FS7 | Regeneration (cut block) | #7f9a52 | 9 | slash.pile, stump, sapling.dense, landing.yard |
| 117 | FS8 | Old growth | #24502c | 12 | tree.white_pine_giant, tree.hemlock_old, snag, log.mossy |
| 118 | FS9 | Swamp forest | #3d6656 | 2 | tree.cedar, tree.black_ash, tree.silver_maple, water.pool_forest |
| 119 | FS10 | Ravine forest | #355f3a | 12 | per [R2] forest kit |
| 120 | FS11 | Burn | #6b6158 | 9 | snag.burnt, plant.fireweed, sapling.aspen |
| 121 | FS12 | Hedgerow (as area) | #4c7f3e | 10 | tree.hedgerow_mix, shrub.hawthorn |
| 122 | FS13 | Rock barren, alvar | #9a8f86 | 3 | rock.outcrop_granite, tree.pine_scattered, shrub.juniper, ground.lichen |
| 140 | WT1 | Marsh | #79b1a2 | 2 | plant.cattail, water.open_channel, muskrat.lodge |
| 141 | WT2 | Bog | #b6b27a | 2 | ground.sphagnum, tree.black_spruce_stunted, water.bog_pool |
| 142 | WT3 | Fen | #9fb58a | 2 | plant.sedge, water.flark |
| 143 | WT4 | Beaver pond | #4f8d9c | 1 | wildlife.beaver_lodge, wildlife.beaver_dam, snag.grey |
| 144 | WT5 | Beaver meadow | #a9c08a | 6 | grass.wet, snag.grey |
| 160 | NT1 | Beach and dune | #e2cf96 | 5 | sand, grass.marram, driftwood |
| 161 | NT2 | Meadow and old field | #b3c27c | 6 | grass.tall, flower.goldenrod |
| 162 | NT3 | Cliff and talus | #7d746c | 3 | rock.cliff_limestone, rock.talus |
| 180 | IF1 | Freeway ROW | #5d5d5d | 14 | road surfaces, barrier.median, barrier.guide_rail, gantry.sign_blank, wall.noise, lamp.highway |
| 181 | IF2 | Interchange infield | #8aa070 | 6 | grass.mown, tree.planted_cluster |
| 182 | IF3 | Rail ROW and yard | #6e5c4e | 14 | rail.track, rail.ballast, rail.signal, rail.crossing_signal, rolling_stock (variants) |
| 183 | IF4 | Airport and airstrip | #a6a6a6 | 14 | runway.asphalt, runway.grass_mown, hangar, windsock, beacon.rotating |
| 184 | IF5 | Utility yard (substation, treatment) | #8c8c99 | 14 | substation.frame, transformer, fence.chainlink |
| 185 | IF6 | Hydro corridor | #c7d38b | 6 | tower.lattice_230kv, wire.conductor, grass.mown |
| 186 | IF7 | Sewage lagoon | #6f8a6a | 1 | lagoon.cell, berm, fence.chainlink |
| 187 | IF8 | Landfill | #9c9271 | 6 | landfill.mound, gas.well_head, scale.house |
| 188 | IF9 | Mine and tailings | #b58d6a | 3 | mine.headframe, mine.mill, mine.tailings_pond |
| 189 | IF10 | Dam and generating station | #6a7b8f | 14 | dam.concrete, dam.timber, powerhouse, switchyard |
| 190 | IF11 | Port, marina | #7c8fa3 | 14 | dock.floating, slip, breakwater.armour, boat (variants), lighthouse |

Ids 0 to 19 are left for the Chapter 1 cover equivalents if a game wants one table; ids 54 to 79, 101 to 109, 123 to 139, 145 to 159, 163 to 179 and 191 to 255 are free. The urban chapter should take ids in a block it declares (suggest 60 to 79) so the two tables can merge into `use-standard-1`. Notes in brackets inside a message cell (such as "(ratio V)") are for the author and are not part of the player text.

### 6.5 Line types (`network/lines.json`)

| id | line | width | profile and rule | colour | assets |
|---|---|---|---|---|---|
| ln.power_transmission | Transmission line | corridor 46 m (230 kV) [25] | Towers every 300 to 450 m, straight segments, angle towers at turns | #e0c040 | tower.lattice, wire.conductor, insulator |
| ln.power_distribution | Pole line | 0 (props) | Poles every 40 to 60 m along roads | #c7a43a | pole.wood, wire.conductor, transformer.pole |
| ln.pipeline | Pipeline | corridor 15 to 30 m | Buried; marker posts at road crossings | #b07ad0 | marker.pipeline |
| ln.rail_main / ln.rail_branch / ln.rail_siding / ln.rail_abandoned | Railways | ROW 30 m | 4.5; abandoned lines become trails | #3b3b3b / #555 / #777 / #8f7f6f | rail.track, rail.ballast, path.rail_trail |
| ln.fence_wire / ln.fence_privacy / ln.fence_acoustic / ln.fence_stone | Fences | 0.1 to 2 m | Lot lines, rear yards, arterials, old fields | #7a6a5a | fence.* |
| ln.hedgerow | Hedgerow | 3 to 10 m | Lot and field lines | #4c7f3e | tree.hedgerow_mix |
| ln.windbreak | Windbreak | 6 to 15 m | 3+ rows, N and W of farmyards [36] | #2f5a3a | tree.spruce_row, tree.cedar_row |
| ln.ditch / ln.municipal_drain | Ditches | 3 to 8 m | Along roads and lot lines; carve 0.6 to 4 m | #6a8fa6 | ditch.grass, culvert.pipe |
| ln.tile_lateral | Tile drain (decal only) | 0.3 m | 4.6 to 7.5 m spacing [55] | none | decal.tile_stripe |
| ln.maple_tubing | Sap tubing | 0 | Mainlines 30 to 45 m apart, downhill 2 to 4 percent [46] | #4a7fd0 | line.maple_tubing |
| ln.trail / ln.portage / ln.cutline_seismic | Trails | 1 to 6 m | 3.5 | #a08060 | path.* |
| ln.noise_wall | Noise wall | 0.3 m, up to 5 m tall [54] | Freeway edges by houses | #8a8a8a | wall.noise |
| ln.boundary_survey | Survey allowance (unopened) | 20.1 m [1] | Becomes a track or hedgerow | #d0c0a0 | (none; drives other layers) |

Road classes: Chapter 1's `roads.json` classes cover most needs. This chapter proposes adding `motorway_link` (ramps), `trunk` (two-lane rural highway), `tertiary` (collector), `unclassified` (gravel concession road), `lane` (rear lane), `logging` and `farm_lane`, each with the widths and grades from 1.3, 2.7, 4.1 and 4.2.

### 6.6 Markers for discoveries and events

```json
{ "id": "d-0017", "kind": "discovery", "type": "disc.homestead_ruin", "tier": "common",
  "p": [812.4, -240.9, 0], "snap": "ground", "yaw": 1.12,
  "footprint": { "shape": "rect", "w": 20, "d": 20 },
  "story_id": "st-03", "season": null,
  "discover": { "radius_m": 40, "max_agl_m": 120 },
  "message_key": "disc.homestead_ruin.1",
  "children": ["d-0018", "d-0019"] }
```

```json
{ "id": "e-0004", "kind": "event_site", "type": "evt.ice_village",
  "area": [[1200, 300], [1500, 300], [1500, 900], [1200, 900]],
  "season": { "months": [1, 2, 3], "until": "03-15" } }
```

Message text lives in a separate `markers/messages.en.json` so games can translate it and read it aloud, and so the plain-writing audit Robert already uses can check it.

### 6.7 The asset gap finder

Every class row above lists **asset roles** (semantic names such as `silo.concrete_stave` or `tree.red_pine_row`). The gap finder is a small tool that:

1. Reads `landuse/class_table.json`, `props/props.json`, `network/lines.json` and `markers/markers.json` from a pack and collects the set of roles actually used, with counts and the largest on-screen size each needs (from the footprint and the nearest camera distance the game expects).
2. Reads a game's **asset kit manifest**, for example:

```json
{ "game": "aerosim", "kit": [
  { "role": "silo.concrete_stave", "files": ["models/silo_a.glb"], "variants": 1, "lod": ["near", "far"] },
  { "role": "tree.red_pine_row", "maps_to": "tree.conifer", "variants": 3 },
  { "role": "barn.bank", "files": ["models/barn_bank_red.glb", "models/barn_bank_grey.glb"], "variants": 2 } ] }
```

3. Reports, per role: **present**, **mapped** (falls back to a generic family through `maps_to`), **missing**, or **thin** (fewer variants than the instance count needs: rule of thumb at least 1 variant per 50 instances on screen, D, up to 6). It also flags roles needed for the current season only (crop stages, snow) and roles needed only by discoveries.
4. Prints a short plain-word list sorted by impact (instance count times screen size), so Robert can see that, for example, "silo.concrete_stave: missing, used 38 times, visible from 2 km" is the next model to make.

Fallback chain (D): a missing specific role falls back to its family (the text before the first dot: `silo.*` to `silo.generic`), then to the Chapter 1 cover class (so a missing orchard shows as generic trees on grass). The gap finder never fails a build; it reports.

---

## 7. Gaps and uncertainty

* **Ontario design manuals not read in full.** The MTO Design Supplement (2023) and the June 2026 freeway design speed memo [16], the TAC Geometric Design Guide, and the MTO noise guide [54] were located but not read. Freeway lane, shoulder, median and ROW widths are common practice values (V). The radius table is computed and matches a published table for one superelevation [15]; the other columns use the same friction values.
* **Interchange footprints** are my estimates (D). They should be calibrated by measuring 5 to 10 real Ontario examples of each type in OSM, which the world builder's OSM importer could do automatically.
* **ICAO and TP 312 runway widths** are widely known values I did not confirm in TP 312 (V).
* **500 kV corridor width** and pipeline corridor widths were not found.
* **Ontario lot, block and ROW widths for older suburbs (SB1, SB2)** come from practice (V); Toronto's former municipal zoning by-laws in Robert's library would give exact numbers for Scarborough, Etobicoke and North York and are the next thing to mine.
* **Shopping centre types** are US ICSC figures [5]; Canadian per-person retail space is lower but not quantified here.
* **MDS distances** are formula-based [7]; this chapter uses a placeholder range. Implementing the actual MDS I and II formulae would make farm-to-house spacing exact.
* **D-6 industrial separations** are from memory (V) and the guideline may have been replaced.
* **Farm building dimensions** rely on US barn records and an Ontario-style barn in Manitoba [35]; an Ontario barn survey would be better.
* **Field sizes, crop colours, orchard and vineyard spacings** are practice values and design defaults; OMAFRA's crop calendars and Statistics Canada field data would firm them up.
* **Wildlife densities** (deer, bears, wolves, moose) are not given as numbers; the events table uses rarity words instead.
* **The surprise budget** is a design proposal. It should be tuned by flying the worlds, not by research.
* **Some sources are weak** and marked so in `SOURCES-3.md`: golf course acreage, gas station sizes from project examples, shipwreck counts, lilac and farmstead lore, ghost town lists.
