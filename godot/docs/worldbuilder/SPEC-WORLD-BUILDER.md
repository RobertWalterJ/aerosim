# World Builder ("Worldsmith"): master specification

Written 2026-10-23 from three research chapters. This file is the entry point. The chapters hold the detail and the sources. If two
chapters disagree, this file decides (section 3).

## 1. What it is
A reusable tool that builds worlds for Robert's games. Three ways in: a drawn map, real data (OpenStreetMap, open elevation and land cover),
or a seed. It computes terrain, water, roads, land use, biomes, lots, buildings and points of interest. It shows a colour-coded 2D map
(stage 1) and a 3D preview (stage 2). Its one output is a **world pack**: files with classes and numbers, never textures or meshes. Each
game dresses the pack with its own **style file** (class to asset and material). An **asset gap finder** reads a pack and a game's asset
kit and reports exactly what is missing.

## 2. Document map (all in `docs/worldbuilder/`)
| File | What it holds |
|---|---|
| `CHAPTER-1-ARCHITECTURE-TERRAIN.md` | Architecture, world pack format 1.0 with JSON examples, data sources and licences, terrain algorithms, 2D and 3D views, the 11-phase build plan P0 to P10, migration of AeroSim, ProceduralMainStreet and Squall Cove |
| `CHAPTER-2-ENVIRONS-SLOPES-ASSETS.md` | Settlement grading, Toronto built-form rules as formulas, siting and street growth, biomes (13 Great Lakes, 16 world), slope classes S0 to S8 and cliffs, 26-row landform table, the asset catalogue by slot, the gap finder, the style file |
| `CHAPTER-3-SUBURBS-RURAL-WILD.md` | Seven suburb morphologies, plazas and commercial, farmland and the Ontario concession grid, forests and wilderness, highways, interchanges and utilities, about 60 discoveries and events, the surprise budget per km2, the land-use layer (about 90 classes) |
| `SOURCES-1.md`, `SOURCES-2.md`, `SOURCES-3.md` | Every source, what was taken, and how well it was read |

## 3. Decisions that settle the disagreements between chapters
1. **Core:** one TypeScript library. It runs as the command-line tool `wb` (build, validate, render, convert, gap-find) and inside a browser
   studio (Web Workers). Godot reads packs through an add-on `rwj_worldpack`; three.js through `wb-three`. (Chapter 1.)
2. **Height:** compressed 16-bit height tiles with a per-pack offset and step, not PNG. Sizes: 4 km at 2 m, 16 to 20 km at 4 to 8 m, 50 km as an
   8 m base with 2 m detail zones; large worlds stream as tiles. (Chapter 1.)
3. **Road classes:** use Chapter 1's list plus `tertiary` (collector) and `unclassified` (rural paved) from Chapter 2, and every road gets
   `width_m` (paved), `row_m` (right of way) and `hierarchy`. (Chapter 2 section 0.1.)
4. **Rasters:** `cover` (Chapter 1) stays the base land cover; add `biome.u8`, `landuse/use.u8` (Chapter 3), an optional `feature.u8` for
   landforms, and `canopy` as in Chapter 3. Land use is separate from land cover. Use-class ids 60 to 79 are reserved for the urban classes
   from Chapter 2; the others come from Chapter 3.
5. **Slopes:** FAO classes S0 to S8 as in Chapter 2. Scree 31 to 40 degrees on loose ground; bare rock above 40 degrees; cliff above 55
   to 65 degrees; triplanar texturing from about 35 degrees. Chapter 1's single cliff threshold is replaced by this.
6. **Settlements:** Squall Cove's town rules, generalised, plus the Toronto envelope formulas of Chapter 2 (lowest of several limits,
   snapped to whole storeys). The Ontario concession grid (Chapter 3) is the master pattern for rural land and suburban super-blocks.
7. **Licensing rule:** assets and data are CC0, open licences or Robert's own. The pack never contains aerial imagery. OSM layers stay in their own
   files with credit recorded in the pack. Before any public release that uses OSM-derived packs, Robert checks the ODbL "derivative
   database" duty with a lawyer (Chapter 1 section 8).
8. **Everything has a confidence tag** in Chapter 3: sourced (S), computed (C), design default (D), common practice not confirmed (V). Tune
   (D) and (V) values by looking at output, not by argument.
9. **Defaults tuned by test:** siting weights, biome thresholds, discovery budget (about 24 discoveries on AeroSim's 16 km2). Expose them in
   a recipe file so they can be changed without code.

## 4. Where it lives and how it is built
- **Project folder:** `C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\Worldsmith` (its own git repo; later pushed to GitHub by
  Robert). The research chapters are copied into its `docs/` as a first step.
- **Packages:** `wb-core` (pack IO, schemas), `wb-gen` (terrain, hydrology, roads, settlements, lots, buildings, POIs), `wb-render` (2D CLI
  renders), `wb-studio` (browser editor and 3D preview), `wb-three`, `rwj_worldpack` (Godot add-on), `wb-gap` (asset gap finder).
- **Method:** the same lane and board method as AeroSim: one DSH session per lane in its own git worktree, a gate script at every stage that
  must print `GATE PASS`, an evidence image per stage, the shared board, and a merge lock. Taste is Robert's; DSH records questions and
  continues. DSH does not model. Claude is asked only for models and for rare reviews.
- **First pack:** AeroSim's valley (phase P0), because it proves the format against something that already works (heights must match the old
  `Terrain.height()` within 1 cm at 10,000 points).

## 5. Build order (from Chapter 1, with the new chapters slotted in)
| Order | Phase | Notes |
|---|---|---|
| 1 | P0 pack spec and converter | the AeroSim valley becomes pack number one; JSON schemas; `wb validate` |
| 2 | P1 2D renders | hillshade, slope classes S0 to S8, landform colours from Chapter 2's table, contours, legend |
| 3 | P2 seeded terrain | noise, warp, painted landform, hydrology, rivers, lakes; later P5 erosion |
| 4 | Landform detection | cliffs, scree, gullies, escarpments from the heightmap (Chapter 2 section on slopes) so the 2D map shows them |
| 5 | P3 studio 2D editor | layers, brushes, seed button, undo |
| 6 | P7 loaders and 3D preview | Godot add-on and three.js package; AeroSim switches to the loader |
| 7 | P4 real-world import | elevation, OSM, land cover, attribution capture |
| 8 | P6 roads and grading | road graph, cut and fill, bridges, interchanges (Chapter 3) |
| 9 | Biomes and land use | biome grading, farmland and concession grid, suburbs, plazas, forests (Chapters 2 and 3) |
| 10 | P8 urban seed logic | settlements, streets, lots, buildings with the Toronto envelopes; ProceduralMainStreet becomes a rule set |
| 11 | Discoveries | the POI and event placement with the surprise budget |
| 12 | Gap finder and style files | `wb gap-find`, the Squall Cove low-poly and AeroSim realistic style files |
| 13 | P9 big worlds, P10 scatter rules | tiling and streaming; props by rule |
About 50 to 70 session days for everything; orders 1 to 6 (about 20 to 25 days) give a seeded-terrain tool, the 2D map and AeroSim on the pack.

## 6. Prompts (use two DSH sessions, as with AeroSim)
Both start by reading, in this order: `docs/worldbuilder/SPEC-WORLD-BUILDER.md`, then the chapters named for their task, then the project's
`LOGIC-NOTES.md` once it exists. Create the project folder first (see section 4), copy `docs/worldbuilder` into it, add a `tools/gate.ps1`
that runs unit tests, validates the sample packs, renders the standard images and prints `GATE PASS` or `GATE FAIL`, and copy AeroSim's
`HANDOFF-TO-DSH.md` rules (one Godot window at a time, never delete, record questions, name the proof) into the project's own handoff file.

**Session W1 (Pro model): the core.** Tasks in order: P0 (pack format, schemas, `wb validate`, `wb convert-aerosim`), P1 (2D renders and
landform classes), P2 (seeded terrain and hydrology), landform detection, P7 (the Godot add-on and `wb-three`, and AeroSim loader switch;
this touches the AeroSim repo, so do it on a branch of AeroSim and gate it with AeroSim's `tools\gate.ps1`), then P4 (real-world import).
Read Chapter 1 fully, Chapter 2 sections on slopes and landforms.

**Session W2 (Flash model): the content.** Tasks in order, starting after W1 has P0 merged: P3 (studio 2D editor), biomes and land use
(Chapters 2 and 3), roads and grading (P6), suburbs, plazas and farmland generators (Chapter 3), the urban generator (P8, with
Chapter 2's Toronto envelope formulas), discoveries (Chapter 3 section 5), then the gap finder and style files. Read Chapters 2 and 3
fully and Chapter 1 sections 2 and 5.
Both sessions: one lane branch each, merge into `main` under the lock only when the gate prints `GATE PASS`, post status on the board.
Questions that need Robert go in `LOGIC-NOTES.md` under "Questions for Claude and the owner".
