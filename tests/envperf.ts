// Environment instancing cost per quality preset: build time, draw calls, triangles and
// visible instances from a few reference viewpoints. Run: npx tsx tests/envperf.ts
import * as THREE from 'three';
import { createCanvas, ImageData } from '@napi-rs/canvas';
const g = globalThis as any;
g.document = { createElement: (tag: string) => { if (tag !== 'canvas') throw new Error('shim: ' + tag); return createCanvas(1, 1); } };
g.ImageData = ImageData;
const { ValleyTerrain } = await import('../src/world/ValleyTerrain');
const { Colliders } = await import('../src/world/Colliders');
const { FoliageInstancer } = await import('../src/world/FoliageInstancer');
const { MemorialParkAssets } = await import('../src/world/MemorialParkAssets');
const { EnvironmentInstancer } = await import('../src/world/EnvironmentInstancer');
const { QUALITY, WORLD } = await import('../src/config');
const T = new ValleyTerrain(); T.bake(() => {});
for (const q of ['low', 'medium', 'high', 'ultra'] as const) {
  const Q = QUALITY[q]; const C = new Colliders();
  const t0 = performance.now();
  const fol = new FoliageInstancer(T, C, Q); const park = new MemorialParkAssets(T, C);
  const t1 = performance.now();
  const h = WORLD.home; const rect: [number, number, number, number] = [h.x - h.clearR, h.z - h.clearR, h.x + h.clearR, h.z + h.clearR];
  const env = new EnvironmentInstancer(T, C, Q, { trees: fol.trees, exclusions: [rect, ...park.exclusions], chapelPos: park.chapelPos, monumentPos: park.monumentPos });
  const t2 = performance.now();
  const views: [string, THREE.Vector3][] = [['home', new THREE.Vector3(h.x, T.height(h.x, h.z) + 2, h.z)], ['memorial', new THREE.Vector3(-58, 150, -110)], ['chapel', new THREE.Vector3(163, 138, -38)], ['overview', new THREE.Vector3(0, 220, 60)]];
  const out: string[] = [];
  for (const [n, p] of views) { env.rebucket(p, true); out.push(`${n}: ${env.stats.meshes} calls, ${(env.stats.tris / 1000).toFixed(0)}k tris, ${env.stats.instances} inst`); }
  console.log(`${q.padEnd(6)} build ${(t2 - t1).toFixed(0)} ms | ${out.join(' | ')}`);
}
