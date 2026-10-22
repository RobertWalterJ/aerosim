// Exports the web version's procedural trees and cemetery assets as GLB files for Godot.
// Run from godot/tools:   npx tsx export_assets.ts
// Writes godot/assets/trees/*.glb, godot/assets/env/*.glb and godot/assets/manifest.json.
// Each mesh carries: position, normal, uv, COLOR_0 (baked AO and tint, linear), and TEXCOORD_1 = (wind phase or sway, wind flex or polish).
import * as THREE from 'three';
import { CanvasElement, ImageData, createCanvas } from '@napi-rs/canvas';
import { mkdirSync, writeFileSync } from 'node:fs';
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
const { buildSpruce, buildBroadleaf, buildFarTree } = await import('../../src/world/TreeFactory');
const { makeBark, makeSpruceSprig, makeLeafCluster } = await import('../../src/world/ProceduralTextures');
const { ENV_ASSETS } = await import('../../src/world/EnvironmentAssets');

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'assets');
mkdirSync(join(out, 'trees'), { recursive: true });
mkdirSync(join(out, 'env'), { recursive: true });

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

// ---- trees: the five variants the web version plants (2 spruce, 2 maple, 1 oak), two detail levels each
const barkB = makeBark(512, 'brown'), barkG = makeBark(512, 'grey');
const sprig = makeSpruceSprig(512), leafMaple = makeLeafCluster(512, 'maple', 41), leafGold = makeLeafCluster(512, 'gold', 77), leafOak = makeLeafCluster(512, 'oak', 91);
const wood = (t: { map: THREE.Texture; normalMap: THREE.Texture }) => new THREE.MeshStandardMaterial({ map: t.map, normalMap: t.normalMap, vertexColors: true, roughness: 0.95, metalness: 0, name: 'bark' });
const leaf = (map: THREE.Texture, rough: number) => new THREE.MeshStandardMaterial({ map, alphaTest: 0.5, side: THREE.DoubleSide, vertexColors: true, roughness: rough, metalness: 0, name: 'leaf' });
const TREES = [
  { name: 'spruce_a', conifer: true, build: (l: 0 | 1) => buildSpruce(11, l), wood: barkB, leaf: leaf(sprig.map, 0.65) },
  { name: 'spruce_b', conifer: true, build: (l: 0 | 1) => buildSpruce(29, l), wood: barkB, leaf: leaf(sprig.map, 0.65) },
  { name: 'maple_red', conifer: false, build: (l: 0 | 1) => buildBroadleaf(21, l, 'maple'), wood: barkG, leaf: leaf(leafMaple.map, 0.62) },
  { name: 'maple_gold', conifer: false, build: (l: 0 | 1) => buildBroadleaf(35, l, 'maple'), wood: barkG, leaf: leaf(leafGold.map, 0.62) },
  { name: 'oak', conifer: false, build: (l: 0 | 1) => buildBroadleaf(47, l, 'oak'), wood: barkB, leaf: leaf(leafOak.map, 0.7) },
];
for (const t of TREES) for (const lod of [0, 1] as const) {
  const geo = t.build(lod);
  const root = new THREE.Group(); root.name = `${t.name}_l${lod}`;
  const w = new THREE.Mesh(packExtras(geo.wood), wood(t.wood)); w.name = 'wood';
  const l = new THREE.Mesh(packExtras(geo.leaf), t.leaf); l.name = 'leaf';
  root.add(w, l);
  writeFileSync(join(out, 'trees', `${root.name}.glb`), await toGlb(root));
  manifest.push({ kind: 'tree', name: root.name, conifer: t.conifer, lod, height: geo.height, crownR: geo.crownR, crownBase: geo.crownBase, tris: tris(geo.wood) + tris(geo.leaf) });
  console.log('tree', root.name, tris(geo.wood) + tris(geo.leaf), 'tris');
}

// ---- distant silhouettes (about 100 triangles each), used beyond the near trees
for (const kind of ['conifer', 'broadleaf'] as const) {
  const geo = packExtras(buildFarTree(kind));
  const root = new THREE.Group(); root.name = `far_${kind}`;
  const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, name: 'far' })); m.name = 'far';
  root.add(m);
  writeFileSync(join(out, 'trees', `${root.name}.glb`), await toGlb(root));
  manifest.push({ kind: 'tree', name: root.name, conifer: kind === 'conifer', lod: 2, tris: tris(geo) });
}

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
