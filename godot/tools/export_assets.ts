// Exports the trees (tools/tree_gen.ts) and the web version's cemetery assets as GLB files for Godot.
// Run from godot/tools:   npx tsx export_assets.ts [--trees-only] [--out <assets folder>]
// Writes godot/assets/trees/*.glb and leaf atlases, assets/textures/bark_birch_diff.jpg, godot/assets/env/*.glb and
// godot/assets/manifest.json. --trees-only skips the env models and keeps their manifest entries.
// Each mesh carries: position, normal, uv, COLOR_0 (baked AO and tint, linear), and TEXCOORD_1 = (wind phase or sway, wind flex or polish).
import * as THREE from 'three';
import { CanvasElement, ImageData, createCanvas } from '@napi-rs/canvas';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// ---- Node stand-ins for the browser features the generators and the exporter use
const g = globalThis as any;
g.document = { createElement: (tag: string) => { if (tag !== 'canvas') throw new Error('shim: ' + tag); return createCanvas(1, 1); } };
g.HTMLCanvasElement = CanvasElement; g.ImageData = ImageData;
// napi canvases have a data() method; the exporter reads `image.data` to detect raw-pixel textures, so hide it
Object.defineProperty(CanvasElement.prototype, 'data', { value: undefined, configurable: true, writable: true });
(CanvasElement as any).prototype.toBlob = function (cb: (b: Blob) => void, type?: string) {
  // encode now (synchronously): the exporter reuses one canvas for every image
  const buf: Buffer = (this as any).toBuffer('image/png');
  Promise.resolve().then(() => cb(new Blob([buf], { type: type || 'image/png' })));
};
g.FileReader = class {
  result: ArrayBuffer | null = null; onloadend: (() => void) | null = null; onload: (() => void) | null = null;
  readAsArrayBuffer(b: Blob) { b.arrayBuffer().then(r => { this.result = r; this.onload?.(); this.onloadend?.(); }); }
  readAsDataURL(b: Blob) { b.arrayBuffer().then(r => { (this as any).result = 'data:' + b.type + ';base64,' + Buffer.from(r).toString('base64'); this.onload?.(); this.onloadend?.(); }); }
};

const { GLTFExporter } = await import('three/examples/jsm/exporters/GLTFExporter.js');
const TG = await import('./tree_gen');

// Options: --trees-only (write only the trees, their leaf atlases and birch bark, and update the tree entries of the
// manifest; leaves env/all.glb alone), --out <assets folder> (default: the assets folder next to this script).
const argv = process.argv.slice(2);
const treesOnly = argv.includes('--trees-only');
const here = dirname(fileURLToPath(import.meta.url));
const outIdx = argv.indexOf('--out');
const out = outIdx >= 0 ? argv[outIdx + 1] : join(here, '..', 'assets');
console.log('writing to', out);
mkdirSync(join(out, 'trees'), { recursive: true });
mkdirSync(join(out, 'env'), { recursive: true });
mkdirSync(join(out, 'textures'), { recursive: true });

async function toGlb(root: THREE.Object3D): Promise<Buffer> {
  const exporter = new GLTFExporter();
  const buf: ArrayBuffer = await new Promise((res, rej) => exporter.parse(root, r => res(r as ArrayBuffer), rej, { binary: true, onlyVisible: false }));
  return Buffer.from(buf);
}

/** Move the web-only attributes into TEXCOORD_1 so they survive the trip: (aWind.x, aWind.y) or (aSway, aPolish). */
function packExtras(geo: THREE.BufferGeometry): THREE.BufferGeometry {
  const n = geo.getAttribute('position').count;
  const uv1 = new Float32Array(n * 2);
  const wind = geo.getAttribute('aWind'), sway = geo.getAttribute('aSway'), polish = geo.getAttribute('aPolish');
  for (let i = 0; i < n; i++) {
    if (polish) { uv1[i * 2] = polish.getX(i); uv1[i * 2 + 1] = sway ? sway.getX(i) : 0; }   // stone: (polish, sway)
    else if (wind) { uv1[i * 2] = wind.getX(i); uv1[i * 2 + 1] = wind.getY(i); }
    else { uv1[i * 2] = sway ? sway.getX(i) : 0; uv1[i * 2 + 1] = polish ? polish.getX(i) : 0; }
  }
  const c = geo.clone();
  for (const a of ['aWind', 'aSway', 'aPolish']) if (c.getAttribute(a)) c.deleteAttribute(a);
  c.setAttribute('uv1', new THREE.BufferAttribute(uv1, 2));
  return c;
}

const manifest: Record<string, unknown>[] = [];
const tris = (geo: THREE.BufferGeometry) => (geo.index ? geo.index.count : geo.getAttribute('position').count) / 3;

// ---- trees (tools/tree_gen.ts): nine species, two detail levels each. The models carry no textures: the materials are
// named "bark:<set>" and "leaf:<atlas>" and game/assets.gd puts the shared bark sets (assets/textures/bark_*.jpg) and the
// leaf atlases written here (assets/trees/leaves_*.webp) on them, so each texture is stored once.
// Bark sets and their metres per repeat around the stem (see assets/textures/README.md).
const BARK = { furrow: { name: 'furrow', tile: 1.0 }, oak: { name: 'oak', tile: 1.0 }, smooth: { name: 'smooth', tile: 1.89 }, pine: { name: 'pine', tile: 2.0 }, birch: { name: 'birch', tile: 1.0 } };
// leaf atlases: four cells (three sprays, one dense clump for the lighter model). Palettes are [colour, weight].
type Pal = [string, number][];
const P = {
  red: [['#b3221a', 3], ['#c8341c', 3], ['#a11a16', 2], ['#d84a1e', 2], ['#8c1d14', 1], ['#e0681f', 1.5], ['#e8a028', 0.6], ['#6f8a2c', 0.25]] as Pal,
  orange: [['#d8521c', 3], ['#e47220', 3], ['#c8341c', 1.5], ['#eaa22a', 1.5], ['#b3221a', 1], ['#7f8f2e', 0.3]] as Pal,
  redInner: [['#e8a028', 2], ['#d86a1e', 2], ['#c8401c', 1.5], ['#a8a030', 1.2], ['#6f8a2c', 1.2], ['#b3221a', 1]] as Pal,
  gold: [['#e6b422', 3], ['#f0c63a', 2.5], ['#d89a1a', 2], ['#e08a1e', 1.2], ['#c4701a', 0.8], ['#b8b032', 0.6]] as Pal,
  goldWarm: [['#e8a020', 3], ['#e47a1e', 2], ['#f0c63a', 1.5], ['#d0581c', 1], ['#c4701a', 1]] as Pal,
  goldInner: [['#d8c040', 2], ['#b8b032', 2], ['#e6b422', 2], ['#98a02c', 1.5], ['#7f9030', 0.8]] as Pal,
  oak: [['#8e3c1a', 2], ['#a3501e', 2], ['#7a3418', 1.5], ['#9a6224', 1.5], ['#b4702a', 1], ['#c0661e', 1], ['#6a7a2c', 0.5]] as Pal,
  oakInner: [['#7a7a2c', 2], ['#5f6e26', 1.5], ['#9a6224', 1.5], ['#8e3c1a', 1], ['#a3501e', 1]] as Pal,
  beech: [['#b8641e', 3], ['#c87a28', 2.5], ['#a65a1c', 2], ['#d89a30', 1.2], ['#8a5424', 1], ['#7a8a2a', 0.3]] as Pal,
  beechInner: [['#c89a30', 2], ['#a8902c', 1.5], ['#b8641e', 1.5], ['#7a8a2a', 1], ['#8a5424', 1]] as Pal,
  birch: [['#e8c42c', 3], ['#f0d244', 2.5], ['#d8b020', 2], ['#c8c040', 1], ['#a8b038', 0.6], ['#b8862a', 0.5]] as Pal,
  birchInner: [['#c8c040', 2], ['#a8b038', 2], ['#e8c42c', 1.5], ['#88a032', 1]] as Pal,
  poplar: [['#e2b828', 3], ['#eec83a', 2.5], ['#d0a018', 2], ['#c8b030', 1], ['#a8a830', 0.6], ['#b88a24', 0.4]] as Pal,
};
const ATLAS: Record<string, any> = {
  maple_red: { shape: 'maple', pals: [P.red, P.orange, P.redInner, P.orange], leafPx: 17, count: 230, spots: 2.5 },
  maple_gold: { shape: 'maple', pals: [P.goldWarm, P.gold, P.goldInner, P.gold], leafPx: 17, count: 230, spots: 2.5 },
  oak: { shape: 'oak', pals: [P.oak, P.oak, P.oakInner, P.oak], leafPx: 17, count: 230, spots: 1.5 },
  beech: { shape: 'beech', pals: [P.beech, P.beech, P.beechInner, P.beech], leafPx: 12, count: 400, spots: 1 },
  birch: { shape: 'birch', pals: [P.birch, P.birch, P.birchInner, P.birch], leafPx: 10, count: 480, spots: 1 },
  poplar: { shape: 'poplar', pals: [P.poplar, P.poplar, P.birchInner, P.poplar], leafPx: 11, count: 440, spots: 1 },
};
const woodMat = (set: string) => new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.9, metalness: 0, name: 'bark:' + set });
const leafMat = (atlas: string) => new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.6, metalness: 0, alphaTest: 0.5, side: THREE.DoubleSide, name: 'leaf:' + atlas });
const broad = (o: Partial<import('./tree_gen').BroadSpec>) => (l: 0 | 1) => TG.buildBroad({ clusters: 30, cards: 3, cardS: 1.25, fold: 0.5, sub: 3, droop: 0.05, leader: false, clumps: 11, clumpR: 0.42, barkTint: [1, 1, 1], ...o } as any, l);
const TREES: { name: string; conifer: boolean; atlas: string; bark: string; build: (l: 0 | 1) => import('./tree_gen').TreeGeo; post?: (g: import('./tree_gen').TreeGeo) => void }[] = [
  { name: 'spruce_a', conifer: true, atlas: 'spruce', bark: 'pine', build: l => TG.buildSpruce(11, l, BARK.pine, 20) },
  { name: 'spruce_b', conifer: true, atlas: 'spruce', bark: 'pine', build: l => TG.buildSpruce(29, l, BARK.pine, 18.5) },
  { name: 'maple_red', conifer: false, atlas: 'maple_red', bark: 'furrow', build: broad({ seed: 21, H: 13, trunkH: 3.0, crownY: 8.2, Rx: 5.3, Ry: 4.7, slope: 1.0, trunkR: 0.36, bark: BARK.furrow, barkTint: [0.95, 0.95, 0.95] }) },
  { name: 'maple_gold', conifer: false, atlas: 'maple_gold', bark: 'furrow', build: broad({ seed: 35, H: 12.5, trunkH: 2.8, crownY: 7.8, Rx: 5.0, Ry: 4.5, slope: 1.1, trunkR: 0.34, bark: BARK.furrow, barkTint: [0.95, 0.95, 0.95] }) },
  { name: 'oak', conifer: false, atlas: 'oak', bark: 'oak', build: broad({ seed: 47, H: 14, trunkH: 3.0, crownY: 8.6, Rx: 6.9, Ry: 4.9, clumps: 13, clumpR: 0.38, clusters: 25, cardS: 1.2, slope: 0.55, trunkR: 0.5, flatTop: 0.2, fold: 0.6, bark: BARK.oak }) },
  { name: 'beech', conifer: false, atlas: 'beech', bark: 'smooth', build: broad({ seed: 63, H: 15, trunkH: 2.2, crownY: 8.4, Rx: 7.2, Ry: 5.8, lowerSkirt: 0.62, clumps: 13, clumpR: 0.4, clusters: 25, cardS: 1.15, slope: 0.7, trunkR: 0.42, bark: BARK.smooth, coolCells: true }) },
  { name: 'birch', conifer: false, atlas: 'birch', bark: 'birch', build: broad({ seed: 77, H: 15, trunkH: 3.6, crownY: 10.0, Rx: 3.3, Ry: 4.8, clumps: 10, clumpR: 0.46, clusters: 24, cardS: 0.95, slope: 1.6, trunkR: 0.2, leader: true, droop: 0.6, sparse: 0.5, sub: 4, fold: 0.4, bark: BARK.birch, coolCells: true }),
    // a dark, rough band at the foot of the trunk, as on real birches
    post: g => { const p = g.wood.getAttribute('position'), c = g.wood.getAttribute('color'); for (let i = 0; i < p.count; i++) { const k = 0.32 + 0.68 * Math.min(1, Math.max(0, (p.getY(i) - 0.3) / 1.4)); c.setXYZ(i, c.getX(i) * k, c.getY(i) * k, c.getZ(i) * k); } } },
  { name: 'poplar', conifer: false, atlas: 'poplar', bark: 'furrow', build: broad({ seed: 91, H: 22, trunkH: 1.4, crownY: 12.2, Rx: 2.5, Ry: 10.0, lowerSkirt: 0.9, clumps: 14, clumpR: 0.62, clusters: 22, cardS: 1.0, slope: 4.0, trunkR: 0.38, leader: true, sub: 2, fold: 0.45, bark: BARK.furrow, barkTint: [0.85, 0.85, 0.85], coolCells: true }) },
  { name: 'pine', conifer: true, atlas: 'pine', bark: 'pine', build: l => TG.buildPine(103, l, BARK.pine) },
];
// leaf atlases and the birch bark (all painted in tree_gen.ts)
for (const [name, spec] of Object.entries(ATLAS)) writeFileSync(join(out, 'trees', `leaves_${name}.webp`), TG.paintLeafAtlas(spec, name.length * 977 + 13).toBuffer('image/webp', 92));
writeFileSync(join(out, 'trees', 'leaves_spruce.webp'), TG.paintConiferAtlas('spruce', 31).toBuffer('image/webp', 92));
writeFileSync(join(out, 'trees', 'leaves_pine.webp'), TG.paintConiferAtlas('pine', 37).toBuffer('image/webp', 92));
writeFileSync(join(out, 'textures', 'bark_birch_diff.jpg'), TG.paintBirchBark(512).toBuffer('image/jpeg', 88));
const treeEntries: Record<string, unknown>[] = [];
for (const t of TREES) for (const lod of [0, 1] as const) {
  const geo = t.build(lod);
  t.post?.(geo);
  const root = new THREE.Group(); root.name = `${t.name}_l${lod}`;
  const w = new THREE.Mesh(geo.wood, woodMat(t.bark)); w.name = 'wood';
  const l = new THREE.Mesh(geo.leaf, leafMat(t.atlas)); l.name = 'leaf';
  root.add(w, l);
  writeFileSync(join(out, 'trees', `${root.name}.glb`), await toGlb(root));
  treeEntries.push({ kind: 'tree', name: root.name, conifer: t.conifer, lod, height: +geo.height.toFixed(2), crownR: +geo.crownR.toFixed(2), crownBase: +geo.crownBase.toFixed(2), tris: geo.woodTris + geo.leafTris, woodTris: geo.woodTris, leafTris: geo.leafTris });
  console.log('tree', root.name, geo.woodTris + geo.leafTris, 'tris (wood', geo.woodTris, 'leaf', geo.leafTris + ')', 'height', geo.height.toFixed(1));
}

// ---- distant silhouettes (about 100 triangles each), used beyond the near trees; game/shaders/tree_far.gdshader varies each copy
for (const kind of ['conifer', 'broadleaf'] as const) {
  const geo = TG.buildFar(kind);
  const root = new THREE.Group(); root.name = `far_${kind}`;
  const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, name: 'far' })); m.name = 'far';
  root.add(m);
  writeFileSync(join(out, 'trees', `${root.name}.glb`), await toGlb(root));
  treeEntries.push({ kind: 'tree', name: root.name, conifer: kind === 'conifer', lod: 2, tris: tris(geo) });
  console.log('far', kind, tris(geo), 'tris');
}
manifest.push(...treeEntries);

if (treesOnly) {
  // keep everything else in the manifest as it is, replace only the tree entries
  const mf = join(out, 'manifest.json');
  const old: Record<string, unknown>[] = existsSync(mf) ? JSON.parse(readFileSync(mf, 'utf8')) : [];
  const merged = [...treeEntries, ...old.filter(e => e.kind !== 'tree')];
  writeFileSync(mf, JSON.stringify(merged, null, 1));
  console.log('done (trees only):', treeEntries.length, 'tree models');
  process.exit(0);
}
const { ENV_ASSETS } = await import('../../src/world/EnvironmentAssets');

// ---- cemetery, fences, hedges, clutter, snags: every family and variant at the near detail level
const SKIP = new Set<string>();
const WITH_LOD1 = new Set(['meadowClump', 'lawnTuft']);   // ground cover also gets a lighter model for the middle distance
// all environment assets go into ONE file so their stone, bark and iron textures are stored once
const envRoot = new THREE.Group(); envRoot.name = 'env';
for (const a of ENV_ASSETS) {
  if (SKIP.has(a.name)) continue;
  for (let seed = 0; seed < a.variants; seed++) {
    const r = a.build(seed, 0);
    const m = new THREE.Mesh(packExtras(r.geometry), r.material); m.name = `${a.name}_${seed}`;
    envRoot.add(m);
    r.geometry.computeBoundingBox();
    manifest.push({ kind: 'env', family: a.family, name: m.name, collider: r.collider ?? null, tris: tris(r.geometry), bbox: [r.geometry.boundingBox!.min.toArray(), r.geometry.boundingBox!.max.toArray()] });
    if (WITH_LOD1.has(a.name)) {
      const r1 = a.build(seed, 1);
      const m1 = new THREE.Mesh(packExtras(r1.geometry), r1.material); m1.name = `${a.name}L1_${seed}`;
      envRoot.add(m1);
      manifest.push({ kind: 'env', family: a.family, name: m1.name, collider: null, tris: tris(r1.geometry) });
    }
  }
  console.log('env', a.family, a.name, a.variants, 'variants');
}
writeFileSync(join(out, 'env', 'all.glb'), await toGlb(envRoot));
writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 1));
console.log('done:', manifest.length, 'assets');
