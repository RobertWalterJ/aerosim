// Density-mask scatter that produces per-variant instance matrices and tints
// for THREE.InstancedMesh. Used by meadow, lawn tufts, clutter and shrubs.
import * as THREE from 'three';
import { clamp01, smoothstep, type AssetResult, type LOD } from './AssetCore';
import { createNoise3D, makeRnd, subSeed, range } from './AssetRng';

/** Row-major grid covering ScatterOptions.area. Values 0..max (max defaults
 *  to 255 for Uint8Array/Uint8ClampedArray, 1 otherwise). */
export interface DensityMask {
  width: number;
  height: number;
  data: ArrayLike<number>;
  max?: number;
}

export interface ScatterOptions {
  seed: number;
  /** world-space rectangle, meters (x/z of the min corner) */
  area: { x: number; z: number; width: number; depth: number };
  /** instances per square meter where the mask is 1 */
  density: number;
  mask?: DensityMask | ((x: number, z: number) => number);
  /** number of variants to distribute (asset variant index = batch.variant) */
  variantCount: number;
  /** optional relative weight per variant */
  variantWeights?: readonly number[];
  /** size of same-variant patches in meters (species form swaths). default 6 */
  patchSize?: number;
  /** 0 = variants fully random, 1 = hard patches. default 0.7 */
  patchiness?: number;
  /** clumpiness of density, 0..1. default 0.5 */
  clumping?: number;
  heightAt?: (x: number, z: number) => number;
  /** uniform scale range, default [0.8, 1.2]; correlated with a low-freq field */
  scale?: readonly [number, number];
  /** random lean in radians, default 0.12 */
  maxLean?: number;
  /** prevailing lean direction (radians around Y, 0 = +X) and amount (radians) */
  windDir?: number;
  windLean?: number;
  /** per-instance brightness spread for instanceColor, default 0.14 */
  tintSpread?: number;
  /** warm/cool spread for instanceColor, default 0.06 */
  warmSpread?: number;
  maxInstances?: number;
}

export interface ScatterBatch {
  variant: number;
  count: number;
  /** count * 16 floats, column-major, ready for InstancedMesh.instanceMatrix */
  matrices: Float32Array;
  /** count * 3 floats (linear RGB multipliers around 1.0) for instanceColor */
  colors: Float32Array;
}

function sampleMask(mask: ScatterOptions['mask'], o: ScatterOptions, x: number, z: number): number {
  if (!mask) return 1;
  if (typeof mask === 'function') return clamp01(mask(x, z));
  const max = mask.max ?? (mask.data instanceof Uint8Array || mask.data instanceof Uint8ClampedArray ? 255 : 1);
  const u = ((x - o.area.x) / o.area.width) * (mask.width - 1);
  const v = ((z - o.area.z) / o.area.depth) * (mask.height - 1);
  const x0 = Math.max(0, Math.min(mask.width - 2, Math.floor(u))), y0 = Math.max(0, Math.min(mask.height - 2, Math.floor(v)));
  const fx = clamp01(u - x0), fy = clamp01(v - y0);
  const at = (i: number, j: number): number => mask.data[j * mask.width + i] ?? 0;
  const a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * fx;
  const b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * fx;
  return clamp01((a + (b - a) * fy) / max);
}

/** Stratified (jittered-grid) scatter with density rejection, patchy variant
 *  selection, correlated scale, lean and tint. Deterministic for a given seed. */
export function scatterInstances(o: ScatterOptions): ScatterBatch[] {
  const rnd = makeRnd(o.seed, 31);
  const noise = createNoise3D(subSeed(o.seed, 32));
  const cell = 1 / Math.sqrt(Math.max(1e-6, o.density));
  const nx = Math.ceil(o.area.width / cell), nz = Math.ceil(o.area.depth / cell);
  const patch = 1 / (o.patchSize ?? 6);
  const patchiness = o.patchiness ?? 0.7;
  const clumping = o.clumping ?? 0.5;
  const [s0, s1] = o.scale ?? [0.8, 1.2];
  const maxLean = o.maxLean ?? 0.12;
  const windLean = o.windLean ?? 0;
  const wd = o.windDir ?? 0;
  const tintSpread = o.tintSpread ?? 0.14, warm = o.warmSpread ?? 0.06;
  const weights = o.variantWeights;
  const lists: { m: number[]; c: number[] }[] = Array.from({ length: o.variantCount }, () => ({ m: [], c: [] }));
  const mat = new THREE.Matrix4(), q = new THREE.Quaternion(), qy = new THREE.Quaternion(), pos = new THREE.Vector3(), scl = new THREE.Vector3();
  const axis = new THREE.Vector3();
  let total = 0;
  const maxN = o.maxInstances ?? Infinity;
  for (let j = 0; j < nz && total < maxN; j++)
    for (let i = 0; i < nx && total < maxN; i++) {
      const x = o.area.x + (i + rnd()) * cell, z = o.area.z + (j + rnd()) * cell;
      if (x > o.area.x + o.area.width || z > o.area.z + o.area.depth) continue;
      let d = sampleMask(o.mask, o, x, z);
      const clump = smoothstep(-0.35, 0.45, noise(x * 0.35, 1.7, z * 0.35) + noise(x * 1.3, 4.1, z * 1.3) * 0.4);
      d *= 1 - clumping + clumping * clump * 1.6;
      if (rnd() >= d) continue;
      // variant: argmax of per-variant patch noise + randomness
      let best = 0, bestV = -Infinity;
      for (let v = 0; v < o.variantCount; v++) {
        const w = weights ? weights[v] ?? 1 : 1;
        if (w <= 0) continue;
        const s = noise(x * patch + v * 13.71, v * 3.3, z * patch - v * 7.9) * patchiness + (rnd() - 0.5) * (1.1 - patchiness) + Math.log(w) * 0.25;
        if (s > bestV) { bestV = s; best = v; }
      }
      const y = o.heightAt ? o.heightAt(x, z) : 0;
      const sField = 0.5 + 0.5 * noise(x * 0.08, 9.3, z * 0.08);
      const s = s0 + (s1 - s0) * clamp01(sField * 0.6 + rnd() * 0.4);
      pos.set(x, y, z);
      qy.setFromAxisAngle(axis.set(0, 1, 0), rnd() * Math.PI * 2);
      const la = rnd() * Math.PI * 2, lm = maxLean * Math.sqrt(rnd());
      const lx = Math.cos(la) * lm + Math.cos(wd) * windLean, lz = Math.sin(la) * lm + Math.sin(wd) * windLean;
      const lean = Math.hypot(lx, lz);
      if (lean > 1e-5) q.setFromAxisAngle(axis.set(lz, 0, -lx).normalize(), lean); else q.identity();
      q.multiply(qy);
      scl.set(s, s * range(rnd, 0.9, 1.1), s);
      mat.compose(pos, q, scl);
      const L = lists[best]!;
      for (let k = 0; k < 16; k++) L.m.push(mat.elements[k]!);
      const tn = noise(x * 0.12, 5.5, z * 0.12);
      const v = 1 + tn * tintSpread * 0.7 + (rnd() - 0.5) * tintSpread * 0.6;
      const w = (noise(x * 0.05, 7.7, z * 0.05) + (rnd() - 0.5) * 0.5) * warm;
      L.c.push(v * (1 + w), v, v * (1 - w));
      total++;
    }
  return lists
    .map((L, variant) => ({ variant, count: L.c.length / 3, matrices: new Float32Array(L.m), colors: new Float32Array(L.c) }))
    .filter((b) => b.count > 0);
}

/** Convenience: one InstancedMesh per batch, built from an asset function. */
export function toInstancedMeshes(
  batches: readonly ScatterBatch[],
  build: (variant: number, lod: LOD) => AssetResult,
  lod: LOD,
): THREE.InstancedMesh[] {
  return batches.map((b) => {
    const a = build(b.variant, lod);
    const mesh = new THREE.InstancedMesh(a.geometry, a.material, b.count);
    mesh.instanceMatrix.array.set(b.matrices);
    mesh.instanceMatrix.needsUpdate = true;
    mesh.instanceColor = new THREE.InstancedBufferAttribute(b.colors, 3);
    mesh.computeBoundingSphere();
    return mesh;
  });
}
