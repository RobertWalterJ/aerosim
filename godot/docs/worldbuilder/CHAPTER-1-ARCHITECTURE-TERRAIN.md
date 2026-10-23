# World Builder: Chapter 1, Architecture and Terrain

*Specification draft, 2026-10-23. Sources are numbered [n] and listed in `SOURCES-1.md`. Local files are [L1] to [L5]. Where I could not confirm something, the text says "not verified".*

## 0. Summary

The World Builder is a **compiler** with a **studio** in front of it. The compiler turns a small editable project (painted layers, drawn lines, imported real data, a seed and some settings) into a **world pack**. A world pack is a folder of plain files that any game can read: a height grid, a land-cover grid, water, a road graph, lots and buildings, prop placements, markers, and a manifest. The pack holds **meaning, not looks**. It says "conifer woodland" and "secondary road, 10 m wide"; each game decides what those look like.

My main recommendations:

1. **Write the whole core in TypeScript**, as one library that runs in Node (the command-line compiler) and in the browser (the studio, inside Web Workers). This is the language AeroSim's web build and exporter already use [L1, L3], it runs on Windows with no installs beyond Node, it needs no GPU, and both Claude and DeepSeek work well in it. Rust compiled to WebAssembly stays as an escape hatch for one or two hot kernels if measurement shows a need.
2. **The pack stores data rasters as raw little-endian integers compressed with zlib (deflate)**, described by a JSON manifest. Godot reads deflate natively [58], browsers read it natively with `DecompressionStream` [59], and AeroSim already does exactly this for its heights [L1, L2]. PNG is used only for preview pictures, because Godot imports PNG at 8 bits per channel [56].
3. **Terrain from a seed uses "uplift plus stream-power erosion" at coarse resolution, then amplification**, the approach of Schott et al. [19, 20], solved with the fast implicit method of Braun and Willett [18]. This gives believable valleys and ridges that drain properly, and it is the most controllable method found: you paint where mountains rise.
4. **Drawn maps are constraints, not pictures.** Painted heights, ridge lines and valley lines become target fields with weights (soft) or pins (hard), filled in by multigrid diffusion [63] and respected by every later stage.
5. **One studio, in the browser**: a WebGL2 2D landform view (stage 1) and a three.js 3D preview (stage 2) in the same app, served locally and opened by a double-click launcher. Godot gets a small reference loader add-on, not a second editor.

---

## 1. Architecture

### 1.1 The split: compiler, studio, loaders

```
                 +--------------------------+
 drawn layers -> |                          |
 OSM, DEM    ->  |  wb-core (TypeScript)    | -> world pack (folder)
 seed+params ->  |  pure functions, no DOM  |       |
                 +-----+--------------+-----+       |
                       |              |             +--> wb-godot add-on (GDScript): AeroSim, Main Street
              Node CLI "wb"     Web Workers         +--> wb-three (TypeScript): Squall Cove, AeroSim web
              (full builds,     inside wb-studio    +--> QGIS (debug: COG + GeoJSON exports)
               validation,      (2D editor, 3D
               batch, CI)       preview, proxy builds)
```

* **wb-core**: every algorithm (noise, erosion, hydrology, rasterising lines, road grading, classification, urban layout, pack read/write, validation). No DOM, no Node-only APIs in the core; input and output go through small adapters. The same code produces the studio preview and the final build, so "what you see is what the game gets".
* **wb CLI** (Node, run through `tsx` like AeroSim's tools [L1]): `wb build project.wbproj.json`, `wb import osm`, `wb import dem`, `wb validate pack/`, `wb render pack/ --view landform --png out.png`. The CLI is what AI coding sessions drive and what every gate test calls.
* **wb-studio** (Vite web app): 2D landform editor and 3D preview, running the core in Web Workers. Started by `Launch World Builder.bat` with a desktop shortcut, per Robert's standing rule that apps never need a terminal.
* **Loaders**: `wb-godot` (a Godot add-on, best placed in the shared `RWJ-Shared-Assets` add-on family next to `rwj_procgen` [L5]) and `wb-three` (an npm-style package for three.js games). Each is small: read the manifest, read rasters, sample heights, build or stream terrain, hand the semantic layers to the game.

The key idea is the **project versus pack** split. The project (recipe) is small, editable, and kept in git. The pack is a build output: deterministic, versioned and disposable. The same project, seed and generator version must produce byte-identical packs (checked by hash). Every layer in a build is a stage in a dependency graph with a content hash, so editing a road reruns only road grading, classification and props, not erosion.

### 1.2 Language choice

| Option | Speed on 4 to 40 million cells | AI-session friendliness | Windows, no GPU | Embedding in Godot and three.js | Verdict |
|---|---|---|---|---|---|
| **TypeScript / Node** | Good with typed arrays and Web Workers; the AeroSim valley (2049 squared, analytic heights, cover, distance transform) already bakes in the browser [L3] | Very high; Robert's web games and tools already use it | Node only; no native builds | three.js: same language, can even run builds in-game. Godot: reads the pack files | **Choose** |
| Python (numpy, numba, rasterio, richdem) | Good with numpy and numba | High | Wheels now bundle a minimal GDAL [61], but numba and GDAL extras on Windows remain fiddly | No browser path: the studio would need a second implementation or a server | Reject as core; acceptable as an optional import helper |
| Rust (+ WASM) | Best (often 2 to 5 times faster than careful JS, not measured here) | Medium: slower edit-compile loops; borrow-checker churn costs AI sessions time | Needs the Rust toolchain on his PC | WASM in browser; GDExtension in Godot is possible but heavy | Reject as core; keep as escape hatch for hot kernels |
| Godot-native (GDScript or C# tool) | GDScript loops are slow at this scale (AeroSim's u16 decode loop over 4.2 M samples is already the slow part of load [L2]) | Medium | Fine | Godot only; no three.js path | Reject |
| C++ (like SimpleHydrology, StreamPowerErosion) | Best | Low for this team | Needs MSVC | Same as Rust | Learn from, do not use |

Two honest costs of choosing TypeScript. First, JavaScript is single-threaded per worker, so the core must split big grids into tiles that workers process in parallel (noise, thermal erosion, classification are easy to tile; priority-flood needs the tiled variant [17]). Second, GDAL is the gold standard for reprojection and odd formats and has no JavaScript equivalent. The core reads Cloud Optimized GeoTIFFs with geotiff.js (MIT, windowed reads [55]) and reprojects with proj4js (MIT, licence not re-verified). For any odd source, the import step can shell out to `gdalwarp` if Robert has QGIS or OSGeo4W installed; that is optional, never required.

### 1.3 Existing tools: what to adopt, learn from, or skip

| Tool | What it is (confirmed) | Licence | Decision |
|---|---|---|---|
| geotiff.js | Reads GeoTIFF and COG windows in browser and Node [55] | MIT | **Adopt** for DEM and land-cover import |
| proj4js | Coordinate reprojection in JS | MIT (not re-verified) | **Adopt** |
| Overpass API | Query OSM by area and tag [29] | ODbL data; public servers rate-limited [30] | **Adopt** for areas up to about 20 km |
| Geofabrik extracts + osmium | Daily regional .osm.pbf files; osmium cuts boxes [31] | ODbL data; osmium-tool GPL (not verified) | **Adopt** for bigger areas, as an optional external tool |
| GDAL / rasterio | Raster I/O and reprojection [61] | MIT / BSD (GDAL not re-verified) | Optional external helper only |
| QGIS | Desktop GIS | GPL | **Use as a debug viewer**: the pack can export COG + GeoJSON copies |
| MapLibre GL JS | Web map library [54] | BSD-3 | **Adopt** only as the "pick an area" locator map in the import dialog |
| Tiled | 2D tile-map editor [49] | GPL editor, BSD parts | Skip: tile grids, not continuous terrain |
| OSM2World | OSM to 3D (glTF, glb, obj) [12] | Open (exact licence not confirmed) | **Learn**: how OSM tags map to roofs, building parts, road surfaces |
| Arnis | OSM + terrain tiles to Minecraft, in Rust [11] | Apache-2.0 per OSM wiki | **Learn**: layering order of OSM features, elevation from Terrarium tiles, caching |
| osm2xp | OSM to X-Plane scenery | Not verified | Skip |
| Cities: Skylines importers, terrain.party | 1081 squared 16-bit heightmaps over about 17 to 18 km [44] | Various | **Learn the pitfall**: a fixed-pixel map whose scale changes with area. Our pack always records metres per sample |
| World Machine, Gaea, World Creator | Commercial terrain generators [45] | Commercial (World Machine Indie USD 119, Pro USD 299 in 2026) | Skip as dependencies; **accept their RAW/R16 exports** as an optional "base heightmap" source |
| Houdini | Commercial procedural suite | Commercial | Skip |
| BlenderGIS | Blender add-on, SRTM + OSM import [47] | GPL-3 | Skip; useful for one-off renders |
| CityEngine | Procedural city tool, CGA rules [46] | Subscription only since 2025 | **Learn**: rule-based building envelopes (ProceduralMainStreet already does this in GDScript [L5]) |
| Wave Function Collapse (mxgmn) | Tile constraint solver [48] | MIT (secondary source) | Use later for small tile-like layouts (plazas, yards); not for terrain or road networks |
| Parish and Mueller L-system streets [28]; tensor-field streets | Road-network growth methods | Papers | **Adopt ideas** for seeded streets (section 4.7) |
| Tangram, Mapbox Vector Tiles | Web map styling and tiling | MIT / spec | Skip: these are display formats, not game-world formats |
| Godot Terrain3D | Clipmap-style terrain for Godot 4, up to 65.5 km, 10 LODs [8, 9] | MIT | **Adopt as the optional Godot back end for big worlds** |
| Godot HTerrain | Older Godot terrain plugin [10] | MIT | Skip: last listed release 2023; power-of-two-plus-one limit |
| three-geospatial, 3DTilesRendererJS, Cesium | Globe-scale web rendering, atmosphere, 3D Tiles [53] | MIT / Apache-2.0 | Skip for the pack (local metres, not a globe); the takram atmosphere could be borrowed by a game later |
| Unreal World Partition | Grid-cell streaming and HLOD [50] | Unreal licence | **Learn**: cells loaded around "streaming sources", coarse proxies for unloaded cells. Our tile ring and coarse pyramid copy this |
| Landlab / FastScape | Landscape-evolution models [18, 67] | Open source | **Reimplement** the Braun-Willett solver in TS |
| RichDEM / Priority-Flood | Hydrology algorithms [16, 17] | Paper and code | **Reimplement** from the paper |
| StreamPowerErosion (Schott) | Uplift-painting erosion demo [19] | MIT | **Port ideas** (MIT allows code reuse with notice) |
| SimpleHydrology | Particle erosion with streams and pools [26] | MIT | **Port ideas** for the detail pass |
| Terrain diffusion models | Learned terrain from sketches or seeds [21, 22] | Varies; weights licences not checked | Skip for v1 (section 4.6) |

---

## 2. The world pack format (version 1.0)

### 2.1 Principles

* **Metres everywhere.** Every raster says its spacing in metres and its origin. Nothing depends on pixel counts.
* **Semantic, not visual.** Classes and attributes, never textures or meshes (an optional `extras/` folder may hold landmark glTF files, but no game may require it).
* **Plain files.** JSON for structure and vectors; raw integer grids compressed with zlib for rasters; PNG and JPG only for previews.
* **Engine-neutral axes.** The pack uses map axes: **x east, y north, z up**, in metres, origin at the world centre. Both Godot and three.js are right-handed and Y-up, so both loaders use the same mapping: `engine.x = x`, `engine.y = z`, `engine.z = -y` (north is -Z, which is Godot's forward direction).
* **Sample-registered grids.** A grid of N samples per side spans exactly (N-1) x spacing metres, with samples on cell corners. This matches AeroSim today (2049 samples over 4000 m, DX = 4000/2048 [L2]).

### 2.2 File list

```
valley.worldpack/
  world.json                    manifest (required)
  ATTRIBUTION.txt               human-readable credits (required if any external data)
  terrain/
    height.u16.zlib             single-grid worlds (tier S and M)
    L0.bundle, L1.bundle, ...   tiled worlds (tier L): concatenated zlib tiles + index in world.json
  cover/
    class.u8.zlib               land-cover class per sample (required)
    density.u8x4.zlib           optional 4-channel weights (e.g. canopy, grass, rock, wetness)
  hydro/
    water.geojson               lakes, ponds, sea: polygons with surface elevation
    rivers.geojson              river centrelines with width, depth, order, flow
    water_mask.u8.zlib          0 dry, 1 river, 2 lake, 3 sea (same grid as cover)
    flow.u16.zlib               optional log-scaled flow accumulation (for wetness, puddles)
  network/
    roads.json                  road graph: nodes, edges, classes, widths, profiles
  urban/
    blocks.geojson              optional: faces of the street graph
    lots.geojson                parcels with zoning/use attributes
    buildings.geojson           footprints with heights, floors, roof, use
  props/
    props.json                  families and small instance lists
    <family>.f32.zlib           large instance lists, packed floats
  markers/
    markers.json                spawn points, POIs, gameplay hooks
  previews/
    landform.png  hillshade.png  thumb.jpg
  exports/                      optional: height.tif (COG), *.geojson in lon/lat for QGIS
  source/                       optional: copy of the project recipe used for the build
```

### 2.3 Rasters

**Height.** Unsigned 16-bit, little-endian, row-major, row 0 at the **north** edge, zlib-wrapped deflate. Metres = `offset_m + value * scale_m`. The compiler chooses `scale_m` as the smallest of {0.005, 0.01, 0.02, 0.05, 0.1} that fits the height range in 65,535 steps, so the step is a round number and identical across rebuilds. Examples: AeroSim's valley (37 to 242 m) gets 5 mm steps; a 3,000 m mountain range gets 5 cm steps. Value 65535 is reserved as "no data" (holes, outside a sparse tile).

Why not the alternatives:

* *16-bit PNG*: Godot's importer limits PNG to 8 bits per channel [56], and browsers decode PNG through 8-bit canvases (well-known behaviour, not re-verified here). Precision would silently drop to 256 levels.
* *32-bit float*: twice the size, and the extra precision is useless below 1 mm. It is used inside the compiler, never in the pack.
* *Half float (Godot `FORMAT_RH` [57])*: only 11 bits of mantissa, so 0.5 m steps at 1,000 m. Too coarse.
* *GeoTIFF/COG as the canonical file*: neither engine reads it natively. The pack can export a COG copy for QGIS.

Load cost: Godot reads it with `FileAccess.get_file_as_bytes` then `PackedByteArray.decompress(size, FileAccess.COMPRESSION_DEFLATE)` [58], exactly as AeroSim does now [L2]. One improvement: keep the decompressed bytes and call `decode_u16` per height query instead of converting 4.2 million values in a GDScript loop at load. three.js reads it with `fetch`, `new Response(stream.pipeThrough(new DecompressionStream('deflate')))`, then a `Uint16Array` view [59]. Zstandard would be smaller, and Godot supports it [58], but browser support for `zstd` in `DecompressionStream` is not confirmed [59], so deflate is the common ground.

**Cover.** One byte per sample, class IDs from the table below, same compression. Cover resolution may be coarser than height (declared separately). Optional `density.u8x4.zlib` holds four 0 to 255 weights the generator knows (canopy cover, grass, exposed rock, wetness), which games use for blending and scattering.

| ID | Class | Typical source mapping | Preview colour |
|---|---|---|---|
| 0 | no data | outside world | #000000 |
| 1 | water (lake, river, sea) | water mask | #3a78b5 |
| 2 | wetland | WorldCover 90, OSM `natural=wetland` | #6aa5a0 |
| 3 | bare rock / cliff | slope > 45 degrees, WorldCover 60 | #8c8279 |
| 4 | scree / gravel | slope 35 to 45 degrees above treeline | #a99f8f |
| 5 | sand / beach | coast band, OSM `natural=beach` | #d9c48f |
| 6 | grassland / meadow | WorldCover 30 | #a4b55e |
| 7 | mown lawn / park | OSM `leisure=park`, `landuse=grass` | #7fb04f |
| 8 | cropland | WorldCover 40, OSM `landuse=farmland` | #d1c46a |
| 9 | shrubland | WorldCover 20 | #8e9a4c |
| 10 | broadleaf woodland | WorldCover 10 + broadleaf hint | #3f7a35 |
| 11 | conifer woodland | WorldCover 10 + conifer hint or elevation | #2d5b3a |
| 12 | mixed woodland | WorldCover 10 default | #376b37 |
| 13 | built-up, low density | WorldCover 50 + OSM residential | #b9a8a0 |
| 14 | built-up, dense / paved | OSM commercial, industrial | #9d8f8b |
| 15 | snow / ice | WorldCover 70 or elevation rule | #f0f3f5 |
| 16 to 63 | reserved for the format | | |
| 64 to 255 | game- or project-specific | declared in `world.json` | |

The preview colours are placeholders. They must pass Robert's existing colour-blindness audit before release.

### 2.4 Resolution tiers, tiling, LOD and streaming

| Tier | Example extent | Finest spacing | Samples | Raw height size | Layout |
|---|---|---|---|---|---|
| S (site) | 4.096 km | 2 m | 2049 squared (4.2 M) | 8.4 MB | single grid (AeroSim valley today) |
| M (district) | 16.384 km | 4 m | 4097 squared (16.8 M) | 33.6 MB | single grid |
| M2 | 20.48 km | 8 m | 2561 squared (6.6 M) | 13.1 MB | single grid |
| L (region) | 32.768 to 65.536 km | 8 m base + 2 m detail zones | e.g. 50 km at 8 m is 6251 squared (39 M) | 78 MB base + 8.4 MB per 4 km detail zone | tiled bundles |

Covering 50 km at 2 m everywhere would be 625 million samples (1.25 GB raw). That is not needed for a drone or a tactical game, so tier L uses a coarse base everywhere plus **detail zones** where play happens. This is the same idea as Terrain3D's variable regions [8].

**Tiles.** In tier L each level stores 256 x 256-cell tiles (257 samples, sharing edge samples with neighbours). Level 0 is the finest spacing; level k has spacing 2^k times finer-level spacing and covers the whole world. Coarser levels are always complete; level 0 tiles exist only in detail zones. Tiles of one level are concatenated into `Lk.bundle`; `world.json` holds an index of byte offset and length per tile, so the Godot loader uses `FileAccess.seek` and the web loader uses HTTP `Range` requests (the same trick COG uses [62]). Bundles avoid thousands of small files, which are slow on Windows and over HTTP.

**Streaming for 10 to 50 km.** Borrowing from World Partition [50]: keep the coarsest level that fits about 4 MB (for 50 km, 32 m spacing, 1563 squared) always loaded for the horizon and for map screens. Around each "streaming source" (the player or drone camera) keep a ring of finer tiles loaded, for example level 0 within 1 km, level 1 within 3 km, level 2 within 8 km. Load and decompress on a worker thread (Godot `WorkerThreadPool`, browser Web Worker). Physics only needs level 0 or 1 near the player. Float32 precision is adequate to 25 km from the origin (step about 2 mm), so origin shifting is optional for 50 km worlds.

**Rendering LOD** is the loader's choice, not the pack's. Recommended: CDLOD (a quadtree of regular grid patches with distance-based vertex morphing, no stitching [51]) for three.js, and either AeroSim's existing near/far mesh with skirts [L2] for small worlds or Terrain3D [8] for big ones in Godot. Geometry clipmaps [52] are the alternative; CDLOD is simpler to write and fits quadtree tiles directly.

### 2.5 `world.json` (manifest)

```json
{
  "format": "rwj-worldpack",
  "format_version": "1.0",
  "id": "aerosim-valley",
  "title": "AeroSim valley",
  "created": "2026-10-23T14:02:11Z",
  "generator": { "name": "wb-core", "version": "0.3.0", "git": "a1b2c3d" },
  "build_hash": "sha256:5f0c...e1",
  "seed": 48213,
  "units": "metre",
  "axes": "x_east_y_north_z_up",
  "extent": { "min_x": -2000, "min_y": -2000, "max_x": 2000, "max_y": 2000 },
  "geo": {
    "kind": "fictional",
    "crs_wkt": null,
    "origin_lonlat": null,
    "note": "Fictional world; for real places kind = 'real', crs is a local Transverse Mercator centred on origin_lonlat"
  },
  "terrain": {
    "layout": "single",
    "grid": { "n_x": 2049, "n_y": 2049, "spacing_m": 1.953125, "registration": "sample" },
    "file": "terrain/height.u16.zlib",
    "encoding": { "type": "uint16le", "compression": "zlib", "offset_m": 36.9, "scale_m": 0.005, "nodata": 65535 },
    "range_m": [36.915, 242.022],
    "sea_level_m": null,
    "sha256": "9e1d...04"
  },
  "cover": {
    "grid": { "n_x": 1025, "n_y": 1025, "spacing_m": 3.90625, "registration": "sample" },
    "file": "cover/class.u8.zlib",
    "encoding": { "type": "uint8", "compression": "zlib" },
    "class_table": "standard-1",
    "custom_classes": { "64": "memorial_lawn" },
    "density": { "file": "cover/density.u8x4.zlib", "channels": ["canopy", "grass", "rock", "wetness"] },
    "sha256": "77ab...c2"
  },
  "layers": {
    "water": "hydro/water.geojson",
    "rivers": "hydro/rivers.geojson",
    "water_mask": { "file": "hydro/water_mask.u8.zlib", "grid": "cover" },
    "roads": "network/roads.json",
    "lots": "urban/lots.geojson",
    "buildings": "urban/buildings.geojson",
    "props": "props/props.json",
    "markers": "markers/markers.json"
  },
  "previews": { "landform": "previews/landform.png", "hillshade": "previews/hillshade.png" },
  "attribution": [],
  "licences": { "pack": "CC-BY-4.0", "osm_layers": null },
  "validation": { "validator_version": "0.3.0", "passed": true, "warnings": 0 }
}
```

For a real place the `geo` block becomes:

```json
"geo": {
  "kind": "real",
  "origin_lonlat": [-79.8711, 43.2557],
  "crs_wkt": "PROJCS[\"local_tm\",GEOGCS[\"WGS 84\",...],PROJECTION[\"Transverse_Mercator\"],PARAMETER[\"latitude_of_origin\",43.2557],PARAMETER[\"central_meridian\",-79.8711],PARAMETER[\"scale_factor\",1],PARAMETER[\"false_easting\",0],PARAMETER[\"false_northing\",0],UNIT[\"metre\",1]]",
  "proj4": "+proj=tmerc +lat_0=43.2557 +lon_0=-79.8711 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m",
  "vertical_datum": "CGVD2013 (from HRDEM) or EGM2008 (from Copernicus)",
  "source_crs": ["EPSG:3979", "EPSG:4326"]
}
```

A local Transverse Mercator centred on the world keeps scale distortion tiny: about 8 parts per million at 25 km from the centre (my calculation: (25/6371) squared divided by 2). UTM would also work but puts most sites far from its central meridian.

Tiled worlds replace `terrain.layout` with:

```json
"terrain": {
  "layout": "tiled",
  "tile_cells": 256,
  "levels": [
    { "level": 0, "spacing_m": 2,  "file": "terrain/L0.bundle", "complete": false,
      "tiles": [ { "tx": 40, "ty": 51, "offset": 0, "length": 61234, "sha256": "..." } ] },
    { "level": 2, "spacing_m": 8,  "file": "terrain/L2.bundle", "complete": true,  "tiles": [ "..." ] },
    { "level": 4, "spacing_m": 32, "file": "terrain/L4.bundle", "complete": true,  "tiles": [ "..." ] }
  ],
  "encoding": { "type": "uint16le", "compression": "zlib", "offset_m": -12.0, "scale_m": 0.05, "nodata": 65535 }
}
```

### 2.6 Water

`hydro/water.geojson` (coordinates in pack metres, x east, y north):

```json
{
  "type": "FeatureCollection",
  "features": [
    { "type": "Feature",
      "properties": { "id": "lake-1", "kind": "lake", "surface_m": 118.40, "max_depth_m": 6.2,
                      "outlet": [812.5, -340.0], "source": "generated" },
      "geometry": { "type": "Polygon", "coordinates": [[[700.0,-420.0],[905.5,-410.0],[930.0,-300.0],[700.0,-420.0]]] } },
    { "type": "Feature",
      "properties": { "id": "sea", "kind": "sea", "surface_m": 0.0, "source": "osm:coastline" },
      "geometry": { "type": "Polygon", "coordinates": [[[-2000,-2000],[-1200,-2000],[-1450,-900],[-2000,-2000]]] } }
  ]
}
```

`hydro/rivers.geojson`: each river reach is a LineString whose coordinates carry z as the **water surface** height, plus:

```json
{ "type": "Feature",
  "properties": { "id": "r-12", "order": 3, "flow_area_km2": 18.4, "width_m": 11.0, "depth_m": 1.4,
                  "downstream": "r-9", "ends_in": "lake-1", "source": "generated" },
  "geometry": { "type": "LineString", "coordinates": [[-1180.0, 300.0, 52.10], [-1172.4, 280.5, 51.95]] } }
```

Rules: river surface heights never increase downstream; a river ends in a lake, the sea, another river, or the world edge; the terrain under the centreline is at least `depth_m` below the surface.

### 2.7 Road graph

`network/roads.json` is a graph, not just lines, so games can drive vehicles along it, place junction meshes, and route.

```json
{
  "schema": "rwj-roads-1",
  "classes": {
    "motorway":    { "width_m": 25.0, "max_grade": 0.05, "lanes": 4, "surface": "asphalt" },
    "primary":     { "width_m": 12.0, "max_grade": 0.08, "lanes": 2, "surface": "asphalt" },
    "secondary":   { "width_m": 10.0, "max_grade": 0.10, "lanes": 2, "surface": "asphalt" },
    "residential": { "width_m": 7.0,  "max_grade": 0.12, "lanes": 2, "surface": "asphalt" },
    "service":     { "width_m": 4.5,  "max_grade": 0.15, "lanes": 1, "surface": "asphalt" },
    "track":       { "width_m": 3.5,  "max_grade": 0.18, "lanes": 1, "surface": "gravel" },
    "path":        { "width_m": 2.0,  "max_grade": 0.25, "lanes": 0, "surface": "compacted" },
    "rail":        { "width_m": 4.0,  "max_grade": 0.025, "lanes": 0, "surface": "ballast" }
  },
  "nodes": [
    { "id": 1, "p": [0.0, 8.0, 133.62], "kind": "junction" },
    { "id": 2, "p": [60.0, 8.0, 131.90], "kind": "junction" },
    { "id": 3, "p": [128.0, 28.0, 128.75], "kind": "end" }
  ],
  "edges": [
    { "id": 10, "a": 1, "b": 2, "class": "residential", "width_m": 7.0, "lanes": 2, "oneway": false,
      "name": "Avenue East", "bridge": false, "tunnel": false, "layer": 0,
      "pts": [[0.0, 8.0, 133.62], [30.1, 7.2, 132.80], [60.0, 8.0, 131.90]],
      "sidewalk": "both", "source": "drawn" },
    { "id": 11, "a": 2, "b": 3, "class": "path", "width_m": 2.5, "lanes": 0, "oneway": false,
      "bridge": true, "deck_m": 1.2, "layer": 1,
      "pts": [[60.0, 8.0, 131.90], [128.0, 28.0, 128.75]], "source": "osm:way/123456789" }
  ]
}
```

The class widths and grades above are my working defaults, not a published standard. An OSM `width` tag overrides the class width; otherwise `lanes` times 3.5 m plus shoulders. The `pts` carry graded z values: the compiler has already smoothed the road's vertical profile and cut or filled the terrain to match (section 4.8), so a game never has to regrade.

### 2.8 Lots and buildings

`urban/lots.geojson`:

```json
{ "type": "Feature",
  "properties": { "id": "lot-204", "block": "blk-17", "use": "mixed_main_street", "frontage_edge": 10,
                  "frontage_m": 7.6, "depth_m": 36.0, "zoning": { "max_height_m": 20.0, "streetwall_m": 16.0,
                  "front_angular_plane_deg": 45 }, "source": "generated" },
  "geometry": { "type": "Polygon", "coordinates": [[[12.0,14.0],[19.6,14.0],[19.6,50.0],[12.0,50.0],[12.0,14.0]]] } }
```

`urban/buildings.geojson` follows the Overture building attribute names where they exist (`height`, `min_height`, `num_floors`, `roof_shape`, `roof_height` [13]) so imported and generated buildings look the same to a game:

```json
{ "type": "Feature",
  "properties": { "id": "b-881", "lot": "lot-204", "base_m": 131.9, "height": 13.5, "num_floors": 3,
                  "roof_shape": "flat", "roof_height": 0, "use": "retail_residential",
                  "era": "heritage", "parts": [ { "min_height": 10.5, "height": 13.5, "inset_m": 3.0 } ],
                  "source": "generated", "confidence": "rule" },
  "geometry": { "type": "Polygon", "coordinates": [[[12.0,14.0],[19.6,14.0],[19.6,30.0],[12.0,30.0],[12.0,14.0]]] } }
```

`base_m` is the graded ground level under the footprint (the compiler flattens a pad). `source` can be `generated`, `osm:way/...`, `overture:...` or `microsoft-ml`; `confidence` is `measured`, `tagged`, `estimated` or `rule`.

### 2.9 Props and markers

`props/props.json` uses **semantic family names**; each game maps families to its own models:

```json
{
  "schema": "rwj-props-1",
  "stride_fields": ["x", "y", "z", "yaw", "scale", "variant", "tint"],
  "families": [
    { "family": "tree.conifer", "count": 18234, "file": "props/tree.conifer.f32.zlib" },
    { "family": "tree.broadleaf", "count": 9120, "file": "props/tree.broadleaf.f32.zlib" },
    { "family": "street.lamp", "count": 64,
      "items": [[12.4, 9.8, 133.6, 1.571, 1.0, 0, 1.0]] },
    { "family": "fence.post_rail", "kind": "linear", "count": 3,
      "lines": [ { "pts": [[100,10,130.2],[140,12,129.9]], "spacing_m": 2.4 } ] }
  ],
  "exclusions": [ { "id": "home", "rect": [-30, 24, -6, 48] } ]
}
```

Binary instance files are `float32` little-endian with the stated stride (7 floats, 28 bytes per instance), zlib-compressed. Small families stay inline. This replaces the anonymous number arrays in AeroSim's `layout.json` [L1] with named fields.

`markers/markers.json`:

```json
{ "schema": "rwj-markers-1",
  "markers": [
    { "id": "home", "kind": "spawn", "p": [-18, -36, 0], "yaw": 0, "clear_r": 12, "snap": "ground" },
    { "id": "monument", "kind": "poi", "p": [0, -8, 0], "snap": "ground" },
    { "id": "chapel", "kind": "poi", "p": [188, 74, 126.19] }
  ] }
```

(Note the sign change: AeroSim's current `layout.json` uses engine x and z [L4]; in the pack, y is north, so engine z = -y.)

### 2.10 Attribution in the pack

`world.json` `attribution` is a list the loader must be able to show:

```json
"attribution": [
  { "layer": ["roads", "buildings", "water"], "text": "© OpenStreetMap contributors", "licence": "ODbL-1.0",
    "url": "https://www.openstreetmap.org/copyright", "retrieved": "2026-10-23", "query": "overpass:sha256:..." },
  { "layer": ["terrain"], "text": "Contains information licensed under the Open Government Licence - Canada (NRCan HRDEM)",
    "licence": "OGL-Canada-2.0", "retrieved": "2026-10-23", "items": ["hrdem-mosaic-1m/..."] },
  { "layer": ["cover"], "text": "© ESA WorldCover project / Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium",
    "licence": "CC-BY-4.0", "retrieved": "2026-10-23" }
]
```

### 2.11 Versioning and validation

* `format_version` is MAJOR.MINOR. Readers accept any pack with the same major version and ignore unknown fields and unknown layers. A new optional layer is a minor bump; any change to an existing field's meaning is a major bump.
* Every file listed has a `sha256`. `build_hash` covers the recipe, seed, generator version and source-data hashes.
* `wb validate` checks, and fails the build on:
  1. all listed files exist, hashes match, decompressed sizes equal n_x x n_y x bytes;
  2. extent equals (n-1) x spacing for every grid;
  3. no `nodata` inside a complete level; heights within `range_m`;
  4. hydrology: every non-lake, non-sea sample drains to a lake, the sea or the edge (no pits left by mistake); river surfaces never rise downstream;
  5. roads: edges reference existing nodes; graded grade at most class `max_grade` plus 1 percent tolerance; terrain within 5 cm of the road surface across the carriageway unless `bridge` or `tunnel`;
  6. buildings inside their lot; lots do not overlap; footprints are valid polygons (closed, counter-clockwise outer rings, no self-intersection);
  7. props not inside water, roads, buildings or exclusions;
  8. any external source in the recipe has an `attribution` entry.

Warnings (not failures): slopes over 60 degrees in large areas, rivers narrower than 2 samples, very small lakes.

### 2.12 How each engine loads it

**Godot** (`addons/rwj_worldpack/world_pack.gd`): parse `world.json`; read and decompress `height.u16.zlib` into a `PackedByteArray`; `height(x, z)` decodes the four neighbours with `decode_u16` and interpolates bilinearly (the same maths as AeroSim's `height()` [L2]); for the GPU, upload the bytes as an `Image` in `FORMAT_RG8` and rebuild the 16-bit value in the shader, or convert once to `FORMAT_RF` [57] in a worker thread. Small worlds use a ported version of AeroSim's near/far mesh; big worlds call Terrain3D's importer with the height range from the manifest (Terrain3D needs it supplied for RAW data [9]). GeoJSON files are parsed with `JSON.parse_string`. A `StyleMap` resource maps cover classes, road classes and prop families to the game's materials and scenes.

**three.js** (`wb-three`): `loadWorldPack(url)` fetches `world.json`, then each file with `DecompressionStream('deflate')` [59]; heights become a `Uint16Array` (CPU sampling) and a `DataTexture` (R16 integer format or packed RG8) for vertex displacement in a CDLOD patch shader. Tiled packs use `fetch` with `Range` headers into the bundle. Vectors are plain JSON. Squall Cove and AeroSim web supply a style map in JavaScript.

---

## 3. Data sources and licences

### 3.1 Summary table

| Data | Resolution | Coverage | Access | Licence | Ease |
|---|---|---|---|---|---|
| **NRCan HRDEM mosaic** (DTM and DSM) | 1 m and 2 m mosaics | Much of southern Canada (lidar), north from stereo | S3 `canelevation-dem` (ca-central-1), STAC search [4] | OGL-Canada 2.0 [5] | **Easy** (COG plus STAC) |
| NRCan MRDEM-30 | 30 m | All Canada | same bucket, `mrdem-30/` [4] | OGL-Canada | Easy |
| **Ontario DTM (lidar-derived)** | Fine (cell size not verified) | Ontario lidar project areas | 1 km tile packages from Ontario GeoHub [6]; point cloud as LAZ [7] | OGL-Ontario | Medium (manual packages) |
| **Copernicus GLO-30** | 30 m (1 arc-second) | Global land (some countries withheld) | S3 `copernicus-dem-30m`, COG, no account [1] | Free licence; specific attribution [2] | **Easy** |
| SRTM / NASADEM | 30 m | 60 N to 56 S [38] | NASA Earthdata (login) | US government works [38] | Medium |
| ASTER GDEM v3 | 30 m | Near-global | NASA LP DAAC (login) | No redistribution limits in v3; citation requested [39] | Medium; noisier than Copernicus |
| USGS 3DEP | 1 m (lidar), 1/3 arc-second seamless | United States | COG downloads, TNM API [37] | US public domain (not re-verified) | Easy |
| Mapzen Terrarium tiles | Varies by zoom (about 30 m in Canada, finer in US) | Global | `https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png` [35] | Attribution required [35] | **Easiest** for quick fictional-ish or preview work |
| Mapterhorn | Not stated | Europe first [36] | PMTiles, Terrarium encoding | Open (terms not stated) [36] | Watch list |
| **ESA WorldCover 2021** | 10 m | Global | S3 `esa-worldcover` COG, 3x3 degree tiles [34] | CC BY 4.0 [34] | **Easy** |
| Ontario Land Cover 1.0, SOLRIS 2.0 | Not verified | Ontario | Ontario Data Catalogue [41] | OGL-Ontario [41] | Medium |
| NLCD (annual) | 30 m | United States | MRLC, cloud copies [40] | Public domain [40] | Easy |
| CORINE | 100 m | Europe | Copernicus Land [40] | Free and open; attribution text not confirmed | Easy |
| **OpenStreetMap** | Vector | Global | Overpass [29], Geofabrik [31] | ODbL | **Easy** |
| Overture buildings | Vector + heights where known | Global | GeoParquet on S3/Azure [14] | ODbL for buildings [14] | Medium (GeoParquet) |
| Microsoft ML footprints | Vector + some heights | 225 regions incl. Canada [15] | GeoJSONL in quadkey files [15] | CDLA Permissive 2.0 per README; older pages say ODbL [15] | Medium |

### 3.2 Elevation notes that matter

* **Copernicus is a surface model.** It includes buildings and tree canopy [2, 3]. A forest shows up as a 20 m plateau, and a town as lumps. For game terrain use a **DTM** (bare earth) where one exists (HRDEM DTM, Ontario DTM, 3DEP), and treat Copernicus as a fallback for areas without lidar, smoothed under forests and towns using the cover map.
* **Vertical datums differ** (CGVD2013 for Canadian lidar, EGM2008 for Copernicus). Mixing them causes steps of up to a metre or so at seams (general GIS knowledge, size not verified for Hamilton). The importer records the datum and blends across a 200 m feather where sources meet.
* **Resolution versus tier.** 1 to 2 m lidar suits tier S; 30 m data upsampled to 8 m needs the amplification pass (section 4.5) to avoid smooth, blurry hills.

Example requests:

```
# NRCan HRDEM 1 m tiles for a Hamilton box (STAC search, then read COG windows with geotiff.js)
GET https://datacube.services.geo.ca/stac/api/search?collections=hrdem-mosaic-1m&bbox=-79.90,43.24,-79.85,43.27

# Copernicus GLO-30: list tiles (no AWS account)
aws s3 ls --no-sign-request s3://copernicus-dem-30m/
# tile naming pattern (verify against the listing before coding it):
#   Copernicus_DSM_COG_10_N43_00_W080_00_DEM/Copernicus_DSM_COG_10_N43_00_W080_00_DEM.tif

# Terrarium tile (zoom 12) and decode:  metres = R*256 + G + B/256 - 32768   [35]
GET https://s3.amazonaws.com/elevation-tiles-prod/terrarium/12/1143/1495.png

# ESA WorldCover listing
aws s3 ls --no-sign-request s3://esa-worldcover/
```

(The Terrarium tile numbers above are illustrative, not checked to cover Hamilton.)

### 3.3 OpenStreetMap: fetching and obligations

For areas up to about 20 km, one Overpass query per layer group, with `out geom` so ways arrive with coordinates [29]:

```
[out:json][timeout:180][maxsize:536870912];
(
  way["highway"](43.24,-79.90,43.27,-79.85);
  way["railway"~"^(rail|light_rail|tram)$"](43.24,-79.90,43.27,-79.85);
  way["building"](43.24,-79.90,43.27,-79.85);
  relation["building"](43.24,-79.90,43.27,-79.85);
  way["waterway"](43.24,-79.90,43.27,-79.85);
  way["natural"~"^(water|wetland|beach|coastline)$"](43.24,-79.90,43.27,-79.85);
  relation["natural"="water"](43.24,-79.90,43.27,-79.85);
  way["landuse"](43.24,-79.90,43.27,-79.85);
  way["leisure"~"^(park|pitch|garden)$"](43.24,-79.90,43.27,-79.85);
);
out geom;
```

Be polite: one request at a time, wait at least 30 s after a 429, stay well under the guideline of about 10,000 requests and 1 GB a day [30]. Cache every response by query hash in the project folder so rebuilds never re-query. For larger areas, download the Ontario extract from Geofabrik (about 866 MB, updated daily [31]) and cut a box with osmium (`osmium extract -b -79.90,43.24,-79.85,43.27 ontario-latest.osm.pbf -o site.osm.pbf`, then `osmium export site.osm.pbf -o site.geojsonseq`). The osmium commands are from my knowledge of the tool and were not re-verified; osmium on Windows may need conda or OSGeo4W.

**ODbL obligations** (my reading; not legal advice):

1. A game showing OSM-derived streets publicly is a **Produced Work**. It needs a visible "© OpenStreetMap contributors" credit that people see without having to dig, near the map or where credits are normally expected [32]. A credits screen plus a line on any in-game map screen is the safe pattern.
2. The pack's OSM-derived files (roads, buildings, water) are data meant to be extracted and reused, so under the OSMF purpose test they are most likely a **Derivative Database** [33]. If a game built from them is made public, the derived database must be offered under ODbL [33]. The simple way to comply: keep OSM-derived features in their own files, mark them ODbL in `world.json`, and publish those files (or the pack) alongside any public release.
3. Keep generated or hand-drawn data in **separate layers** from OSM data so that the share-alike duty does not spread to Robert's own work. A pack mixing both in one file must be treated as ODbL as a whole.

The manifest records for OSM: the query or extract name, retrieval date, the `©` line, the licence, and which layers contain OSM content.

### 3.4 Buildings and heights

Priority for heights: OSM `height` or `building:levels` x 3.2 m (my assumed storey height) > Overture `height` [13] > Microsoft ML height (metres, -1 means unknown) [15] > a rule from use and lot size. Overture buildings are ODbL [14], so they carry OSM-like obligations. Microsoft's README says CDLA Permissive 2.0 [15] while older OSM wiki pages say ODbL; check the licence file inside each download before relying on it. The pack records `source` and `confidence` for every building.

### 3.5 Imagery: what is not allowed

* **Google** map tiles and Photorealistic 3D Tiles: no caching, extraction, offline use or derivative works [42]. Baking them into a game world is not allowed without a separate licence.
* **Bing** imagery: similar restrictions; even Cesium cannot clip it [42].
* **Esri World Imagery**: not for offline export; the "for Export" variant allows small volumes inside ArcGIS apps only [43]. Not usable in a game.
* Open options exist (Sentinel-2 at 10 m; government orthophotos under open licences, not checked here), but the recommendation is simpler: **no imagery in the pack**. Colour comes from cover classes and the game's own materials. That avoids the licence problem and keeps the pack style-neutral.

---

## 4. Terrain generation

### 4.1 Pipeline overview

One pipeline handles all three inputs; they differ only in where the base comes from.

```
 A. base height      seed: fBm + ridged + domain warp, or uplift map      | real: DEM import | drawn: diffusion from sketch
 B. constraints      painted heights, ridge and valley lines, pins (soft and hard)
 C. macro landscape  stream-power erosion under uplift, at coarse grid (e.g. 513 to 1025 squared)
 D. hydrology        priority-flood, flow directions, accumulation, lakes kept, river network
 E. amplify          upsample to final spacing + slope-aware detail noise + thermal + droplet erosion
 F. carve            rivers, lakes, coast, roads (graded), building pads, lot terraces
 G. classify         slope, aspect, curvature, landform classes, cover/biome
 H. urban            settlements, arterials, streets, blocks, lots, buildings   (section 4.7)
 I. scatter          props by rules on cover, slope, distance to roads and water
 J. pack             write, validate, previews
```

Stages C and E are skipped or lightened for real-world terrain (the DEM already has real valleys), but D, F and G always run.

### 4.2 Seeded base (stage A)

* **Simplex fBm**: 6 to 8 octaves, lacunarity 2.0, gain 0.5, base wavelength about one third of the world. Cheap: about 10 to 30 ns per sample per octave in JS (my estimate), so 4.2 M samples x 8 octaves is about 0.5 to 1 s on one core, divided by the number of workers.
* **Ridged multifractal** for mountain zones: 1 - |noise|, squared, with each octave weighted by the previous one so ridges are sharp and valleys smooth.
* **Domain warping** [27]: evaluate fBm at coordinates displaced by another fBm, warp amplitude about 0.1 to 0.3 of the base wavelength. This removes the "noise look" and gives folded, tectonic-looking forms at almost no cost.
* **Uplift map** instead of heights when stage C runs: the seed generates a smooth uplift field (high along one or two warped "plate boundary" curves, low near coasts). This is the "tectonic-style uplift" of Schott et al. [19]: you describe where land rises, and erosion makes the shapes.

### 4.3 Drawn constraints (stage B)

Constraint kinds the studio offers:

| Constraint | Representation | Effect |
|---|---|---|
| Elevation brush (raise, lower, set, flatten, smooth) | raster target T and weight W, per tile | blended: h = (1 - W) h_gen + W T |
| Pin (hard) | raster mask, W = 1, flag hard | re-applied after every erosion iteration so erosion cannot move it |
| Ridge line | polyline with crest height or relief, width, profile | adds to uplift (seed mode) and to target field; profile from a distance field |
| Valley line | polyline with depth, width, profile | negative uplift, pre-carved channel, forced river candidate |
| Contour or spot heights | polylines or points with heights | sparse targets filled by diffusion |
| Landform paint | class raster (mountains, hills, plain, plateau, valley, wetland, coast) | sets noise mix, uplift and roughness per class |
| Coastline | polyline or painted sea | sets sea level boundary condition |

Lines become fields through an exact Euclidean distance transform, which AeroSim's valley already implements [L3]. For sparse constraints (contours, spot heights, ridge and valley crest heights) the compiler solves a **membrane (Laplace) or thin-plate interpolation with multigrid**, the method of Hnaidi et al. [63]: constraints are fixed, the solver fills smooth terrain between them in a few V-cycles, and noise is then added with amplitude that is also diffused from the curves (so a "rough" ridge gets rough slopes). Multigrid on 4 M samples is a few hundred milliseconds in JS (estimate).

Soft constraints guide; hard constraints win. A painted lake surface or a pinned airfield is hard. A sketched ridge is soft by default, because erosion should be allowed to break it into spurs.

### 4.4 Macro landscape: uplift and stream-power erosion (stage C)

The model is dh/dt = U - K A^m S^n (+ hillslope diffusion), where U is uplift, A is upstream drainage area, S is slope. Use **m = 0.45 to 0.5, n = 1** (so the concavity m/n is about 0.45, which matches Robert's Deep Time sandbox measurement of 0.447 for the same law). With n = 1 the **Braun-Willett implicit solver** is O(n) per step and stable at large time steps [18]: compute receivers (steepest-descent neighbour), order nodes from outlets upstream, accumulate area in reverse, then solve each node's new height from its receiver's in one pass. Steady state does not depend on time step [18], which is exactly what a terrain authoring tool wants: run to near-equilibrium, fast.

Practical settings:

* Run at a **coarse grid**: 513 squared for tier S, 1025 squared for M and L. Schott et al. show that erosion at coarse scale plus amplification gives hydrologically consistent detail [20].
* 100 to 300 iterations with large dt. Choose K so steady-state relief matches the requested relief (the studio exposes "relief" in metres, not K).
* Add hillslope diffusion (kappa) for rounded hills in lowland worlds; reduce it for alpine worlds.
* Each iteration on 1 M cells: receivers (8 neighbours), a stack sort and two sweeps, roughly 0.1 to 0.2 s in TypeScript (estimate, to be measured at gate P5).

This is the step that makes seeded worlds look like real landscapes rather than noise: dendritic valleys, ridges with spurs, and a drainage network that actually reaches the sea.

### 4.5 Hydrology, amplification and detail erosion (stages D and E)

**Depressions.** Priority-Flood [16] fills pits from the edges inward using a priority queue: O(n log n) for float data. Use the epsilon variant so filled flats still drain, and the improved variant that uses a plain queue inside depressions (up to 37 percent faster [16]). Do not fill everything: depressions with an area above a threshold (for example 2,000 square metres) and a depth above 1 m become **lakes** with surface at the spill height; small ones are filled. For 50 km tiled worlds use the parallel tiled Priority-Flood [17].

**Flow and rivers.** D8 flow directions on the filled surface; flow accumulation by a single sweep in topological order. A river starts where drainage area exceeds a threshold (0.5 to 2 square km, a project setting). Width follows a hydraulic-geometry rule, width_m = c x sqrt(area_km2) with c about 2 to 3 (my assumed calibration, based on the general hydraulic-geometry relationship, not taken from a source in this list), clamped to at least 2 samples so rivers render. Drawn valley lines and drawn rivers are forced: their cells get a large "virtual area" so the network routes through them. A rivers-first method [66] is the alternative for fully drawn river maps; ours supports that by letting drawn rivers carve before the macro step.

**Amplification.** Upsample the coarse eroded terrain bicubically to the final spacing, then add detail noise whose amplitude depends on slope and landform class (none on floodplains and lakes, most on steep slopes and ridges), oriented along the flow direction so gullies line up with drainage. Schott et al. 2024 [20] is the research version of this; ours is a simpler practical version.

**Thermal erosion.** Talus angle 30 to 35 degrees (tan about 0.6 to 0.7) for soil, 40 to 45 degrees for rock zones; 20 to 50 iterations. Use the **gather form** (each cell reads neighbours and writes only itself): deterministic, parallel without atomics, about 4 to 5 times slower than scatter but still cheap [25].

**Droplet hydraulic erosion** for final-resolution texture: 100,000 to 500,000 droplets with inertia 0.05, capacity 4, erosion 0.3, deposition 0.3, evaporation 0.01, radius 2 to 3 samples (common parameter values from widely shared droplet implementations; not taken from a source in this list). Particle methods with stream and pool memory [26] add believable small channels. The droplet pass must be seeded and run in a fixed order so builds stay deterministic; parallel droplets on tiles, with a halo, then a merge.

**GPU option.** Virtual-pipes erosion [23] runs at about 6 ms per step at 2048 squared on a mid-range NVIDIA card in CUDA [24], and WebGPU now ships in all major desktop browsers on Windows [60]. That is a real speed-up for the studio's interactive brushes, but the compiler **must not need a GPU** (Robert's laptop is not guaranteed to have one). So: CPU path is the reference and the gate; a WebGPU path is an optional accelerator added later, tested to give results within tolerance of the CPU path.

### 4.6 Learned (diffusion) terrain: not for version 1

Sketch-guided diffusion models now produce realistic terrain from rivers, ridges and basins drawn by users [21], and a 2025 model offers infinite, seed-consistent generation as a "successor to Perlin noise" [22]. They are impressive but: they need a GPU for inference at useful speed, their weights and training data carry licences I did not check, they do not guarantee drainage or exact constraint satisfaction, and they are hard to debug in AI coding sessions. The Galin et al. review [64] frames the choice well: simulation and procedural methods give control; learned methods give realism at the cost of control. **Recommendation:** keep a slot in stage E for an optional "style amplifier" plug-in later, fed by the hydrologically correct coarse terrain, and evaluate it after the core works.

### 4.7 Urban logic from a seed (stage H, outline)

Full urban rules belong in a later chapter; the terrain pipeline must leave room for them:

1. **Settlement sites** scored on flat ground, river crossings, confluences, coast, and distance from each other.
2. **Arterials** connect settlements by least-cost paths on a cost field (slope penalty rising steeply above each class's `max_grade`, water crossing cost, existing-road discount). This is the "least-elevation" pattern of Parish and Mueller [28].
3. **Local streets** grow from arterials using pattern templates (grid, organic, radial) steered by a tensor field that follows terrain contours and the coast, with the self-closing growth and local constraints of [28]. Grid-style districts suit Ontario towns.
4. **Blocks** are the faces of the planar street graph; **lots** come from recursive splitting of blocks along street frontage.
5. **Buildings** come from lot rules: this is where ProceduralMainStreet's envelope logic (streetwall, step-back, angular planes [L5]) plugs in as a "building rule set".

### 4.8 Carving and grading (stage F)

* **Roads**: sample terrain along the centreline every 2 to 5 m; smooth the profile and limit grade to the class `max_grade` (a 1D constrained smoothing pass); where cut or fill exceeds about 8 m, or the road crosses water, mark a bridge or tunnel instead of earthworks. Then blend the terrain to the road profile across the carriageway plus a shoulder whose width grows with cut or fill depth at a 1:2 batter slope. Write the graded z back into `roads.json`.
* **Rivers and lakes**: carve to `depth_m` below the water surface, with banks blended over a few samples.
* **Building pads and lots**: flatten each footprint to one level (lot average, clamped to the road level at the frontage); terrace steep lots.

### 4.9 Expected run times (estimates, to be measured at gates P2 and P5)

Assumptions: TypeScript in Node on an ordinary 8-core laptop CPU, no GPU, workers for tileable stages. These are engineering estimates from the cost per sample of each algorithm, not measurements.

| Stage | 4 km at 2 m (2049 squared, 4.2 M) | 20 km at 8 m (2561 squared, 6.6 M) | 50 km at 8 m + two 4 km 2 m zones (39 M + 8.4 M) |
|---|---|---|---|
| A base (noise, warp, uplift) | 1 s | 1 to 2 s | 5 to 10 s |
| B constraints (distance fields, multigrid) | 1 s | 1 to 2 s | 5 to 10 s |
| C macro erosion (coarse 513 or 1025 squared, 200 iterations) | 5 to 10 s | 20 to 40 s | 30 to 60 s |
| D hydrology (Priority-Flood, flow, rivers) | 2 to 4 s | 3 to 6 s | 30 to 60 s (tiled) |
| E amplify + thermal + droplets | 5 to 15 s | 10 to 30 s | 2 to 5 min |
| F carve and grade | under 2 s | 2 to 5 s | 10 to 30 s |
| G classify, I scatter | 2 s | 3 s | 20 to 40 s |
| J write + validate + previews | 2 s | 3 s | 20 to 40 s |
| **Total** | **about 20 to 40 s** | **about 1 to 2 min** | **about 5 to 10 min** |
| Peak memory | about 150 MB | about 250 MB | about 1.5 GB |

The studio does not rebuild the full world on every brush stroke. It rebuilds a **proxy** (for example 1025 squared for any world size) in about 2 to 5 s, and only the stages a change affects. The full build runs from a "Build" button through the CLI.

---

## 5. Stage 1: the 2D landform view

### 5.1 Technology

**WebGL2 in the studio**, with the height grid uploaded as float textures in 1024 squared GPU tiles, and every visual layer computed in a fragment shader. This keeps pan and zoom at 60 frames per second on integrated graphics, because the CPU never redraws pixels. Vectors (roads, rivers, lines, polygons) are drawn as WebGL line and polygon meshes in metre coordinates on top. A small HTML panel holds layers, tools and the legend.

Rejected: a Canvas2D renderer (CPU-bound redraw at these sizes); Leaflet or OpenLayers (built around 8-bit image tiles in Web Mercator, not metre grids); MapLibre as the editor (its Web Mercator projection fights local metre coordinates, though it stays as the locator map [54]); QGIS as the editor (GPL, heavy, not embeddable; kept as a debug viewer); a Godot-built editor (does not share code with the three.js preview or Squall Cove).

### 5.2 What the view shows (all in the shader, all toggleable)

* **Hillshade**: normal from four neighbour heights, light from the north-west at 45 degrees; multi-directional option (average of three azimuths) for flat areas.
* **Slope shading**: tint by slope bands (0 to 3, 3 to 8, 8 to 15, 15 to 30, 30 to 45, over 45 degrees), useful for buildability.
* **Aspect**: optional hue wheel.
* **Contours**: from `fract(h / interval)` with screen-space derivatives for constant-width anti-aliased lines; index contour every fifth line; interval auto-chosen from zoom (1, 2, 5, 10, 20, 50 m).
* **Landform classes**: classification by slope, curvature and topographic position (valley floor, plain, rolling hills, steep slope, cliff, ridge, peak), coloured from the palette in section 2.3 and shown with a legend.
* **Cover / biome**, **water**, **flow accumulation** (log scale, shows drainage), **uplift** (seed mode), **constraint weights** (where the user has pinned or painted).
* A hover readout: x, y, height, slope, class, flow area, and the nearest road or river name.

### 5.3 Editing tools

* Brushes: raise, lower, set height, flatten to sample, smooth, noise stamp, erode-here (local thermal and droplet pass), paint landform class, paint uplift, paint cover override, paint pin and unpin. Radius, strength and falloff in metres.
* Lines: ridge, valley, river, coast, road (with class), contour (with height). Editable vertices, Catmull-Rom smoothing (as AeroSim's paths already use [L3]).
* Polygons: lake (with surface), urban area (density, pattern), forest, park, no-build zone, detail zone (tier L).
* Points: settlement seed, peak (height), spot height, marker (spawn, POI).
* **Seed button** with a lock icon per stage: re-roll noise but keep erosion settings, or re-roll everything. Seeds are shown as words or numbers so Robert can note good ones.
* Layers panel with visibility, lock and opacity; import buttons (DEM, OSM, cover) open a locator map to pick a box.

### 5.4 Undo and performance

* Undo uses a command stack. Vector edits store their inverse. Raster strokes store the **before-image of only the dirty 256 squared tiles**, compressed in memory, so a stroke on a 4097 squared grid costs kilobytes, not 64 MB. Cap the history at about 256 MB and drop the oldest steps.
* All heavy work runs in Web Workers; the main thread only draws. A brush stroke updates the affected GPU tiles immediately (direct preview), then queues a proxy rebuild of downstream stages, which arrives a few seconds later and is cross-faded in.
* Large worlds are edited at proxy resolution with an optional "full-resolution window" around the cursor.
* Prototype approach: build the viewer first as a read-only `wb render` (CLI writes PNGs of each view; these are the gate images), then the same shader code in the studio, then tools one at a time.

---

## 6. Stage 2: the 3D preview and how games consume the pack

### 6.1 Recommendation: three.js inside the studio

The 3D preview is a second tab of the same web app, reading the same in-memory pack the 2D view uses. It is a **planning-model level of fidelity**, enough to judge landform, sightlines, road grades, and town layout, not final art:

* Terrain: CDLOD quadtree [51] of 64 x 64-quad patches, heights from the texture in the vertex shader, vertex morphing between levels, skirts at the world edge.
* Ground: colour from cover classes plus hillshade-matched lighting, triplanar rock on steep slopes, simple detail noise.
* Water: flat lake and sea planes at `surface_m`, river ribbons from `rivers.geojson`.
* Roads: ribbon meshes from the graph at graded z, coloured by class.
* Buildings: footprints extruded to height, simple roof shapes from `roof_shape`.
* Props: instanced proxies (cones for conifers, spheres for broadleaf, boxes for street furniture), with counts capped by distance.
* Sun from date, time and latitude (ProceduralMainStreet already has a solar position routine [L5] that can be ported).
* Fly and orbit cameras, plus a "drone height" camera to see what AeroSim will see.

Why not a Godot app for the preview: it would duplicate the preview in a second language, and Godot's web export is heavier than a three.js page. Godot still matters: the **Godot loader is tested by AeroSim itself** (gate P7), which is a stronger test than a separate Godot previewer.

### 6.2 Styles and asset kits

A pack never names a texture or mesh. Each game supplies a **style map**, a small JSON (or Godot resource) such as:

```json
{
  "style": "aerosim-autumn",
  "cover": { "11": { "material": "res://materials/conifer_floor.tres", "scatter": ["tree.conifer"] },
             "7":  { "material": "res://materials/lawn.tres", "grass": "mown" } },
  "roads": { "residential": { "material": "res://materials/asphalt.tres", "curb": true },
             "path": { "material": "res://materials/gravel.tres" } },
  "props": { "tree.conifer": { "scene": "res://props/spruce.tscn", "variants": 6 },
             "street.lamp": { "scene": "res://props/lamp_heritage.tscn" } },
  "buildings": { "rule": "rwj_procgen/main_street", "era.heritage": "res://kits/toronto_storefronts" }
}
```

Changing the style map changes the look of every pack without touching any pack. Squall Cove can render the same pack as a stylised harbour town that AeroSim renders as an autumn valley. Unknown classes fall back to a default (grey ground, box props), so a newer pack never breaks an older game.

---

## 7. Phased build plan

Each phase ends with a **gate**: a test that must pass and an image that must exist, before the next phase starts. Effort is in focused AI-session days, assuming one session per day plus Robert's review. Ordered by usefulness: AeroSim benefits from phase 0 and phase 7; Squall Cove from phase 7; seeded worlds from phase 2.

| Phase | What is built | Gate test | Gate image | Effort | Main risk |
|---|---|---|---|---|---|
| **P0 Pack spec + converter** | `wb-core` pack reader/writer, `wb validate`, JSON schemas; `wb convert-aerosim` turns `valley_height.bin`, `valley_cover.png`, `valley_path.png` and `layout.json` into a v1 pack | Validator passes; round-trip heights equal the old file to within one u16 step at all samples; Godot test scene loads the pack and compares `height()` at 10,000 random points with the old `Terrain.height()` (max difference under 1 cm) | `previews/hillshade.png` of the valley next to a Godot screenshot | 2 to 3 days | Choosing axis signs wrongly; caught by the 10,000-point test |
| **P1 2D renders (CLI)** | Shader-equivalent CPU renderer for hillshade, slope, contours, landform classes, legend; `wb render` | Golden-image tests (pixel difference under 1 percent against approved images); contour lines land on exact heights at probe points | Five PNG views of the valley | 2 to 3 days | Classification thresholds look wrong; tune with Robert |
| **P2 Seeded terrain v1** | Noise, warp, landform paint, multigrid constraints, Priority-Flood, flow, rivers, lakes, thermal, droplets, cover rules | Same seed gives identical `build_hash` twice; no undrained pits; rivers monotonic; 4 km build under 60 s (record actual time) | Landform and flow views for three seeds | 4 to 6 days | Droplet determinism across workers; fix by tile order and halos |
| **P3 Studio 2D editor** | Vite app, WebGL2 view, layers, brushes, lines, polygons, seed button, undo, Worker proxy rebuild, launcher .bat + desktop shortcut | Scripted browser test: a stroke changes the pack; undo restores bit-identical heights; pan/zoom holds 60 fps on a 4097 squared world | Screen capture of an edit before and after | 6 to 8 days | Browser test tooling on his PC: one headless window at a time and kill it after (it once froze his machine) |
| **P4 Real-world import** | DEM import (HRDEM STAC, Ontario DTM tiles, Copernicus COG, Terrarium), OSM via Overpass and cached files, WorldCover; datum and seam blending; attribution capture | Hamilton test box: pack heights versus source at 200 control points, RMS under 0.5 m after resampling; OSM roads overlay within one sample of source; attribution present for every source | Hamilton hillshade with OSM roads overlaid | 5 to 7 days | Network access from his PC through the GPA proxy (Studio needed truststore before); cache aggressively |
| **P5 Macro erosion + amplification** | Uplift painting, Braun-Willett solver, hillslope diffusion, amplification pass | Slope-area regression gives concavity 0.40 to 0.50; drainage reaches outlets; 20 km build timed | Before/after erosion images of the same seed | 4 to 6 days | Results look "too eroded" or too uniform; expose relief and age as two sliders |
| **P6 Roads and grading** | Road graph from drawn and OSM lines, profile smoothing, cut/fill, bridges, pads | No graded edge exceeds class grade plus 1 percent; terrain within 5 cm of road surfaces; bridges where cut or fill over 8 m | Long-section plot of one road plus an oblique render | 5 to 7 days | Junctions on slopes; flatten junction discs first, then roads |
| **P7 3D preview + loaders** | Studio 3D tab (CDLOD, water, roads, buildings, props); `wb-three` package; `rwj_worldpack` Godot add-on; AeroSim switched to the loader | Same pack, same camera: three.js and Godot height probes agree to 1 cm; AeroSim runs unchanged in play | Side-by-side three.js and Godot screenshots from one camera | 6 to 8 days | Godot loader performance; keep bytes and decode lazily |
| **P8 Urban seed logic** | Settlements, arterials, local streets, blocks, lots, buildings; ProceduralMainStreet as a building rule set | Planar street graph; lots inside blocks and non-overlapping; buildings inside lots; envelope rules pass Main Street's own checks | Town render from a seed | 8 to 12 days | Scope creep; ship grid towns first |
| **P9 Big worlds** | Tiled bundles, level pyramid, detail zones, streaming in both loaders, tiled Priority-Flood | 50 km build completes; streaming keeps frame spikes under 8 ms on his laptop; memory within budget | Fly-through capture across a tile seam | 5 to 7 days | Memory in the browser; studio edits a proxy only |
| **P10 Scatter rules and style maps** | Rule-based props, exclusions, style-map loader in both engines | No props in water, roads or buildings; density follows cover | Same pack in two styles | 3 to 5 days | Asset kits are each game's job; keep the pack side small |

Total: roughly 50 to 70 session days for everything; **P0 to P3 (about 15 to 20 days) already gives a usable seeded-terrain tool with AeroSim on the pack**.

### 7.1 Migrating AeroSim

Today AeroSim's world is defined in the web build (analytic `baseHeight()` and hand-placed paths in `ValleyTerrain.ts` [L3]), exported by `tools/export_world.ts` [L1], and read by `game/terrain.gd` [L2].

1. **P0**: add `wb convert-aerosim` that reads the current exported files and writes `valley.worldpack/`. Mapping: `valley_height.bin` becomes `terrain/height.u16.zlib` with a re-quantised round step (5 mm); `valley_cover.png` R (woodland) and B (lawn) become cover classes (woodland, lawn, meadow) plus `density` channels; `valley_path.png` is dropped in favour of the real path polylines from `layout.json` `paths`, which become `roads.json` edges of class `path`; `home`, `monument`, `chapel` become markers; `trees` and `farTrees` become `tree.*` prop families; `exclusions` become prop exclusions.
2. **Kept game-side**: `props.glb`, `park.glb`, colliders and the memorial park's one-off pieces stay AeroSim assets. They are dressing, not world data. The park can be placed via a marker.
3. **P7**: replace `terrain.gd`'s loading code with the `rwj_worldpack` loader; keep its mesh building and shader for now. `cover_at()` reads density channels; `dist_to_path()` is computed from the road graph by the loader (a distance field baked at load, or shipped as an optional raster).
4. Later, `export_world.ts` itself becomes a thin script: build the valley from its recipe with `wb build`, then export only the game-specific glb files.

### 7.2 Migrating ProceduralMainStreet

ProceduralMainStreet [L5] is currently a self-contained generator: it invents its own street, lots and buildings and applies Toronto rules. It moves onto the pack in two directions:

* **As a consumer (dresser).** A pack's `lots.geojson` along a main-street corridor, with `zoning` attributes, is handed to `main_street.gd`, which builds the heritage and mid-rise buildings with its existing envelope logic. The sun study runs on the pack's terrain and buildings.
* **As a producer (urban template).** Its parametric street (frontage, lot depth, lane, right-of-way) is exported into a pack as roads, lots and buildings, so AeroSim or Squall Cove can fly over or fight in a Main Street block.

The loader belongs in the shared add-on family (`RWJ-Shared-Assets`, next to `rwj_procgen`), so every Godot project gets the same reader.

### 7.3 Squall Cove

Squall Cove is three.js. It uses `wb-three` and its own style map. Its current harbour world can be described as a recipe (coast line, harbour basin, town polygon) and rebuilt as a pack in P8, after the urban logic exists. No Squall Cove change is needed before P7.

---

## 8. What I could not verify

* The cell size of the Ontario DTM and of Ontario Land Cover 1.0 [6, 41].
* Exact Copernicus tile file names and the current wording of its licence (two versions circulated [1, 2]).
* Whether `zstd` works in browser `DecompressionStream` [59].
* Licences of osmium-tool, proj4js, GDAL, RichDEM and Landlab (stated from memory where used).
* The Microsoft footprints licence conflict (CDLA in the README, ODbL on OSM wiki pages) [15].
* All run-time estimates in section 4.9: none are measured. Gates P2, P5 and P9 measure them.
* Whether Godot's PNG importer drops 16-bit precision silently or refuses; the docs say 8 bits [56], forum reports conflict. The design avoids PNG for data either way.
* The ODbL reading in section 3.3 is mine, not legal advice; the OSMF guidelines do not discuss games [33].
