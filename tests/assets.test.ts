// Builds every procedural asset at every LOD and logs triangle counts, then
// checks budgets, attributes, NaNs, albedo range and determinism.
// Run: npx tsx tests/assets.test.ts
import * as THREE from 'three';
import { createCanvas } from '@napi-rs/canvas';

// Minimal DOM canvas shim so ProceduralTextures (document.createElement) runs in Node.
const g = globalThis as unknown as { document?: unknown };
if (!g.document) g.document = { createElement: (tag: string) => { if (tag !== 'canvas') throw new Error('shim: ' + tag); const c = createCanvas(1, 1); return c; } };

const { ENV_ASSETS } = await import('../src/world/EnvironmentAssets');
const { TRI_BUDGET } = await import('../src/world/assetkit/AssetCore');
const extra = await import('./assets.extra');

let failures = 0;
const fail = (msg: string): void => { failures++; console.log('  FAIL ' + msg); };
const pad = (s: string | number, n: number): string => String(s).padStart(n);
const SEEDS = 8;

function hashGeometry(geo: THREE.BufferGeometry): number {
  let h = 2166136261;
  for (const name of Object.keys(geo.attributes)) {
    const a = geo.getAttribute(name).array as ArrayLike<number>;
    for (let i = 0; i < a.length; i += 7) h = Math.imul(h ^ Math.round(a[i]! * 1e4), 16777619);
  }
  return h >>> 0;
}

console.log('=== environment assets (budgets LOD0 < 6000, LOD1 < 1200, LOD2 < 200 triangles)');
console.log(`${'asset'.padEnd(16)} ${pad('LOD0 min', 8)} ${pad('max', 6)} ${pad('LOD1 min', 8)} ${pad('max', 6)} ${pad('LOD2 min', 8)} ${pad('max', 6)}  ms/build`);
for (const a of ENV_ASSETS) {
  const stats: [number, number][] = [[Infinity, 0], [Infinity, 0], [Infinity, 0]];
  const t0 = performance.now();
  let builds = 0;
  for (let seed = 0; seed < Math.max(SEEDS, a.variants); seed++) {
    for (const lod of [0, 1, 2] as const) {
      const r = a.build(seed, lod);
      builds++;
      const geo = r.geometry;
      const tris = (geo.index ? geo.index.count : geo.getAttribute('position').count) / 3;
      stats[lod]![0] = Math.min(stats[lod]![0], tris);
      stats[lod]![1] = Math.max(stats[lod]![1], tris);
      const tag = `${a.name} seed=${seed} lod=${lod}`;
      if (tris > TRI_BUDGET[lod]) fail(`${tag}: ${tris} tris > budget ${TRI_BUDGET[lod]}`);
      if (tris === 0) fail(`${tag}: empty geometry`);
      for (const attr of ['position', 'normal', 'uv', 'color', 'aSway', 'aWind']) if (!geo.getAttribute(attr)) fail(`${tag}: missing ${attr}`);
      if (!(r.material instanceof THREE.MeshStandardMaterial)) fail(`${tag}: material is not MeshStandardMaterial`);
      if (r.material.transparent) fail(`${tag}: transparent blending enabled`);
      const pos = geo.getAttribute('position').array as Float32Array;
      for (let i = 0; i < pos.length; i++) if (!Number.isFinite(pos[i]!)) { fail(`${tag}: non-finite position`); break; }
      const col = geo.getAttribute('color').array as Float32Array;
      let maxC = 0;
      for (let i = 0; i < col.length; i++) maxC = Math.max(maxC, col[i]!);
      if (maxC > 0.92) fail(`${tag}: vertex albedo ${maxC.toFixed(2)} above plausible range`);
      geo.computeBoundingBox();
      if (geo.boundingBox!.min.y < -0.25 - (a.buried ?? 0)) fail(`${tag}: geometry extends ${geo.boundingBox!.min.y.toFixed(2)} m below origin`);
      if (seed === 0) {
        const again = a.build(seed, lod);
        if (hashGeometry(again.geometry) !== hashGeometry(geo)) fail(`${tag}: not deterministic`);
        again.geometry.dispose();
      }
      geo.dispose();
    }
  }
  const ms = (performance.now() - t0) / builds;
  console.log(`${a.name.padEnd(16)} ${pad(stats[0][0], 8)} ${pad(stats[0][1], 6)} ${pad(stats[1][0], 8)} ${pad(stats[1][1], 6)} ${pad(stats[2][0], 8)} ${pad(stats[2][1], 6)}  ${ms.toFixed(1)}`);
}

failures += await extra.run();
console.log(failures === 0 ? '\nALL ASSET CHECKS PASSED' : `\n${failures} FAILURES`);
process.exit(failures === 0 ? 0 : 1);
