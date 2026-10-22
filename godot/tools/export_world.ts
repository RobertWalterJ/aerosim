// Exports the web version's whole world for Godot: the baked valley (height, land cover, path distance), where every
// tree, meadow clump, hedge, fence, wall, memorial, lamp, bench and car stands, the park buildings and monuments, and the
// models for each prop family. Run from godot/tools:   npx tsx export_world.ts
// Writes godot/assets/world/: valley_height.bin (16-bit, zlib), valley_cover.png, valley_path.png, layout.json,
// props.glb (every family variant at two detail levels plus the instanced park pieces) and park.glb (the one-off park pieces).
import * as THREE from 'three';
import { CanvasElement, ImageData, createCanvas } from '@napi-rs/canvas';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const g = globalThis as any;
g.document = { createElement: (tag: string) => { if (tag !== 'canvas') throw new Error('shim: ' + tag); return createCanvas(1, 1); } };
g.HTMLCanvasElement = CanvasElement; g.ImageData = ImageData;
Object.defineProperty(CanvasElement.prototype, 'data', { value: undefined, configurable: true, writable: true });
(CanvasElement as any).prototype.toBlob = function (cb: (b: Blob) => void, type?: string) {
  const buf: Buffer = (this as any).toBuffer('image/png');
  Promise.resolve().then(() => cb(new Blob([buf], { type: type || 'image/png' })));
};
g.FileReader = class {
  result: ArrayBuffer | null = null; onloadend: (() => void) | null = null; onload: (() => void) | null = null;
  readAsArrayBuffer(b: Blob) { b.arrayBuffer().then(r => { this.result = r; this.onload?.(); this.onloadend?.(); }); }
  readAsDataURL(b: Blob) { b.arrayBuffer().then(r => { (this as any).result = 'data:' + b.type + ';base64,' + Buffer.from(r).toString('base64'); this.onload?.(); this.onloadend?.(); }); }
};
g.performance = g.performance ?? { now: () => Date.now() };

const { GLTFExporter } = await import('three/examples/jsm/exporters/GLTFExporter.js');
const { ValleyTerrain } = await import('../../src/world/ValleyTerrain');
const { Colliders } = await import('../../src/world/Colliders');
const { FoliageInstancer } = await import('../../src/world/FoliageInstancer');
const { MemorialParkAssets } = await import('../../src/world/MemorialParkAssets');
const { EnvironmentInstancer } = await import('../../src/world/EnvironmentInstancer');
const { QUALITY, WORLD } = await import('../../src/config');

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '..', 'assets', 'world');
mkdirSync(out, { recursive: true });
const r2 = (v: number) => Math.round(v * 100) / 100;
const r3 = (v: number) => Math.round(v * 1000) / 1000;

async function toGlb(root: THREE.Object3D): Promise<Buffer> {
  const exporter = new GLTFExporter();
  const buf: ArrayBuffer = await new Promise((res, rej) => exporter.parse(root, r => res(r as ArrayBuffer), rej, { binary: true, onlyVisible: false }));
  return Buffer.from(buf);
}
/** Keep the web-only attributes: TEXCOORD_1 = (wind phase, flex) or (polish, sway). */
function packExtras(geo: THREE.BufferGeometry): THREE.BufferGeometry {
  const n = geo.getAttribute('position').count;
  const uv1 = new Float32Array(n * 2);
  const wind = geo.getAttribute('aWind'), sway = geo.getAttribute('aSway'), polish = geo.getAttribute('aPolish');
  for (let i = 0; i < n; i++) {
    if (polish) { uv1[i * 2] = polish.getX(i); uv1[i * 2 + 1] = sway ? sway.getX(i) : 0; }
    else if (wind) { uv1[i * 2] = wind.getX(i); uv1[i * 2 + 1] = wind.getY(i); }
    else if (sway) { uv1[i * 2] = 0.5; uv1[i * 2 + 1] = sway.getX(i); }
  }
  const c = geo.clone();
  for (const a of ['aWind', 'aSway', 'aPolish']) if (c.getAttribute(a)) c.deleteAttribute(a);
  c.setAttribute('uv1', new THREE.BufferAttribute(uv1, 2));
  return c;
}
const tris = (geo: THREE.BufferGeometry) => (geo.index ? geo.index.count : geo.getAttribute('position').count) / 3;

// ---------------------------------------------------------------- build the web world in Node
console.log('baking the valley...');
const T = new ValleyTerrain();
T.bake();
const Q = QUALITY.high;
const colliders = new Colliders();
console.log('planting trees...');
const foliage = new FoliageInstancer(T, colliders, Q);
console.log('building the park...');
const park = new MemorialParkAssets(T, colliders);
const homeEx: [number, number, number, number] = [WORLD.home.x - WORLD.home.clearR, WORLD.home.z - WORLD.home.clearR, WORLD.home.x + WORLD.home.clearR, WORLD.home.z + WORLD.home.clearR];
console.log('placing props...');
const env = new EnvironmentInstancer(T, colliders, Q, { trees: foliage.trees, exclusions: [homeEx, ...park.exclusions], chapelPos: park.chapelPos, monumentPos: park.monumentPos });

// ---------------------------------------------------------------- terrain data
const N = 2049;
let hmin = Infinity, hmax = -Infinity;
for (const h of T.heights) { hmin = Math.min(hmin, h); hmax = Math.max(hmax, h); }
const h16 = new Uint16Array(N * N);
for (let i = 0; i < h16.length; i++) h16[i] = Math.round((T.heights[i]! - hmin) / (hmax - hmin) * 65535);
writeFileSync(join(out, 'valley_height.bin'), deflateSync(Buffer.from(h16.buffer)));
console.log('height', hmin.toFixed(1), hmax.toFixed(1));

function savePng(name: string, w: number, h: number, rgba: Uint8ClampedArray | Uint8Array) {
  const c = createCanvas(w, h); const ctx = c.getContext('2d'); const img = ctx.createImageData(w, h);
  img.data.set(rgba); ctx.putImageData(img, 0, 0); writeFileSync(join(out, name), c.toBuffer('image/png'));
}
savePng('valley_cover.png', 1024, 1024, T.cover);       // r woodland, b mown lawn
const PATH_RES = 1024; const pd = new Uint8Array(PATH_RES * PATH_RES * 4);
for (let i = 0; i < PATH_RES * PATH_RES; i++) { const d = Math.min(255, Math.round(Math.min(T.pathDist[i]! / 8, 1) * 255)); pd[i * 4] = d; pd[i * 4 + 1] = 0; pd[i * 4 + 2] = 0; pd[i * 4 + 3] = 255; }
savePng('valley_path.png', PATH_RES, PATH_RES, pd);      // r = distance to the nearest path in 8 m units over a 512 m square

// ---------------------------------------------------------------- layout
const layout: any = { size: WORLD.size, n: N, hmin, hmax, pathSpan: 512, home: WORLD.home, monument: park.monumentPos.toArray(), chapel: park.chapelPos.toArray(), exclusions: park.exclusions };
layout.paths = T.paths.map((p, i) => ({ name: p.name, closed: p.closed, pts: T.polylines[i]!.filter((_, k) => k % 3 === 0).map(p2 => [r2(p2[0]), r2(p2[1])]) }));
layout.trees = foliage.trees.map(t => [r2(t.x), r2(t.y), r2(t.z), r2(t.rot), r2(t.s), t.variant, r2(t.tint)]);
const far = (foliage as any).farStatic;
const decompose = (im: THREE.InstancedMesh) => {
  const arr: number[] = []; const m = new THREE.Matrix4(), p = new THREE.Vector3(), q = new THREE.Quaternion(), s = new THREE.Vector3(), e = new THREE.Euler(0, 0, 0, 'YXZ');
  const col = im.instanceColor?.array as Float32Array | undefined;
  for (let i = 0; i < im.count; i++) {
    im.getMatrixAt(i, m); m.decompose(p, q, s); e.setFromQuaternion(q, 'YXZ');
    arr.push(r2(p.x), r2(p.y), r2(p.z), r2(e.y), r2((s.x + s.z) / 2), r2(s.y), col ? r2(col[i * 3]!) : 1, col ? r2(col[i * 3 + 1]!) : 1, col ? r2(col[i * 3 + 2]!) : 1);
  }
  return arr;
};
layout.farTrees = { conifer: decompose(far.conifer), broad: decompose(far.broad) };     // 9 numbers each: x y z yaw scaleXZ scaleY r g b
layout.colliders = {
  cyl: colliders.all.filter(c => c.kind !== 'trunk' && c.kind !== 'canopy').map(c => [r2(c.x), r2(c.z), r2(c.r), r2(c.y0), r2(c.y1), c.kind]),
  box: colliders.allBoxes.map(b => [r2(b.x0), r2(b.z0), r2(b.x1), r2(b.z1), r2(b.y0), r2(b.y1), b.kind]),
};
const lodScale = Q.env.lodScale;
layout.families = [];
const propsRoot = new THREE.Group(); propsRoot.name = 'props';
let propTris = 0;
for (const f of env.families) {
  const entry: any = { name: f.def.name, d: f.def.d.map(d => d * lodScale), large: f.def.large, variants: f.def.variants.length, items: f.items.map(it => [r2(it.x), r2(it.y), r2(it.z), r3(it.ry), r3(it.rx), r3(it.rz), r3(it.s), it.v, r2(it.tint)]) };
  layout.families.push(entry);
  if (f.items.length === 0) continue;
  const used = new Set(f.items.map(i => i.v));
  f.def.variants.forEach((mk, v) => {
    if (!used.has(v)) return;
    for (const lod of [0, 1] as const) {
      const b = mk(lod);
      const m = new THREE.Mesh(packExtras(b.geometry), b.material as THREE.Material); m.name = `${f.def.name}__${v}__${lod}`;
      propsRoot.add(m); propTris += tris(b.geometry);
    }
  });
  console.log('family', f.def.name, f.items.length, 'items,', f.def.variants.length, 'variants');
}

// ---------------------------------------------------------------- the park: one-off pieces and instanced pieces
const parkRoot = new THREE.Group(); parkRoot.name = 'park';
layout.parkInstanced = [];
let k = 0;
for (const child of [...park.group.children]) {
  if ((child as THREE.InstancedMesh).isInstancedMesh) {
    const im = child as THREE.InstancedMesh; const mats: number[] = []; const m = new THREE.Matrix4(); const p = new THREE.Vector3(), q = new THREE.Quaternion(), s = new THREE.Vector3(), e = new THREE.Euler(0, 0, 0, 'YXZ');
    for (let i = 0; i < im.count; i++) { im.getMatrixAt(i, m); m.decompose(p, q, s); e.setFromQuaternion(q, 'YXZ'); mats.push(r2(p.x), r2(p.y), r2(p.z), r3(e.x), r3(e.y), r3(e.z), r3(s.x), r3(s.y), r3(s.z)); }
    const proto = new THREE.Mesh(packExtras(im.geometry), im.material as THREE.Material); proto.name = `park__inst${k}`;
    propsRoot.add(proto);
    layout.parkInstanced.push({ name: proto.name, count: im.count, m: mats });
    k++;
  } else {
    parkRoot.add(child.clone());
  }
}
console.log('park instanced', layout.parkInstanced.map((p: any) => `${p.name}:${p.count}`).join(' '));
layout.signs = park.signTargets.map(v => [r2(v.x), r2(v.y), r2(v.z)]);

writeFileSync(join(out, 'layout.json'), JSON.stringify(layout));
writeFileSync(join(out, 'props.glb'), await toGlb(propsRoot));
writeFileSync(join(out, 'park.glb'), await toGlb(parkRoot));
console.log('done. prop triangles exported:', propTris, 'trees', layout.trees.length, 'far', layout.farTrees.conifer.length / 9 + layout.farTrees.broad.length / 9);
