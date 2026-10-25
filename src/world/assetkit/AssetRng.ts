// Randomness for the environment asset families, built on the project's
// src/util/noise.ts (mulberry32, noise3, hash3) so nothing is duplicated.
import { mulberry32, noise3, hash3 } from '../../util/noise';

export type Rnd = () => number;
export type Noise3 = (x: number, y: number, z: number) => number;

export { mulberry32 };

/** Mix a seed with a salt so sub-generators get independent streams. */
export function subSeed(seed: number, salt: number): number {
  return (Math.imul((seed | 0) ^ 0x5bd1e995, 0x01000193) ^ Math.imul(salt + 0x632be5ab, 0x9e3779b1)) >>> 0;
}

export function makeRnd(seed: number, salt = 0): Rnd {
  return mulberry32(subSeed(seed, salt));
}

/** Seeded 3D noise in roughly [-1, 1]: the project's value noise3, offset per seed. */
export function createNoise3D(seed: number): Noise3 {
  const r = mulberry32(seed);
  const ox = r() * 4096, oy = r() * 4096, oz = r() * 4096;
  return (x: number, y: number, z: number): number => Math.max(-1, Math.min(1, (noise3(x + ox, y + oy, z + oz) - 0.5) * 2.2));
}

/** Integer hash in [0, 1) with a seed, via the project's hash3. */
export function hash3i(x: number, y: number, z: number, seed: number): number {
  return hash3(x ^ Math.imul(seed, 0x27d4eb2d), y + (seed & 0xffff), z - (seed >>> 16));
}

export const range = (r: Rnd, a: number, b: number): number => a + (b - a) * r();
export const irange = (r: Rnd, a: number, b: number): number => Math.floor(a + (b - a + 1) * r());
/** Roughly gaussian in [-1, 1] (sum of 3 uniforms). */
export const gauss = (r: Rnd): number => (r() + r() + r() - 1.5) / 1.5;
export const chance = (r: Rnd, p: number): boolean => r() < p;
export function pick<T>(r: Rnd, arr: readonly T[]): T {
  return arr[Math.min(arr.length - 1, Math.floor(r() * arr.length))]!;
}
export function pickWeighted<T>(r: Rnd, items: readonly (readonly [T, number])[]): T {
  let total = 0;
  for (const [, w] of items) total += w;
  let x = r() * total;
  for (const [v, w] of items) {
    x -= w;
    if (x <= 0) return v;
  }
  return items[items.length - 1]![0];
}
