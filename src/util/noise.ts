export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export function hash2(x: number, y: number): number {
  let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
export function hash3(x: number, y: number, z: number): number {
  let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263) + Math.imul(z | 0, 1442695041)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
const fade = (t: number) => t * t * t * (t * (t * 6 - 15) + 10);
export function noise2(x: number, y: number): number {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = fade(xf), v = fade(yf);
  const a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
export function fbm2(x: number, y: number, oct = 5, lac = 2.0, gain = 0.5): number {
  let s = 0, a = 0.5, f = 1, n = 0;
  for (let i = 0; i < oct; i++) { s += a * noise2(x * f + i * 17.3, y * f - i * 9.1); n += a; a *= gain; f *= lac; }
  return s / n;
}
export function noise3(x: number, y: number, z: number): number {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = x - xi, yf = y - yi, zf = z - zi;
  const u = fade(xf), v = fade(yf), w = fade(zf);
  const h = (i: number, j: number, k: number) => hash3(xi + i, yi + j, zi + k);
  const x00 = h(0, 0, 0) + (h(1, 0, 0) - h(0, 0, 0)) * u, x10 = h(0, 1, 0) + (h(1, 1, 0) - h(0, 1, 0)) * u;
  const x01 = h(0, 0, 1) + (h(1, 0, 1) - h(0, 0, 1)) * u, x11 = h(0, 1, 1) + (h(1, 1, 1) - h(0, 1, 1)) * u;
  const y0 = x00 + (x10 - x00) * v, y1 = x01 + (x11 - x01) * v;
  return y0 + (y1 - y0) * w;
}
/** Divergence-free curl of a 3-field potential built from value noise. */
export function curl3(x: number, y: number, z: number, out: number[]): void {
  const e = 0.35;
  const P = (ox: number, oy: number, oz: number, c: number) => noise3(x + ox + c * 31.7, y + oy + c * 17.1, z + oz + c * 53.9) - 0.5;
  // potential A = (P0,P1,P2); curl = (dA2/dy - dA1/dz, dA0/dz - dA2/dx, dA1/dx - dA0/dy)
  const dA2dy = (P(0, e, 0, 2) - P(0, -e, 0, 2)) / (2 * e), dA1dz = (P(0, 0, e, 1) - P(0, 0, -e, 1)) / (2 * e);
  const dA0dz = (P(0, 0, e, 0) - P(0, 0, -e, 0)) / (2 * e), dA2dx = (P(e, 0, 0, 2) - P(-e, 0, 0, 2)) / (2 * e);
  const dA1dx = (P(e, 0, 0, 1) - P(-e, 0, 0, 1)) / (2 * e), dA0dy = (P(0, e, 0, 0) - P(0, -e, 0, 0)) / (2 * e);
  out[0] = dA2dy - dA1dz; out[1] = dA0dz - dA2dx; out[2] = dA1dx - dA0dy;
}
export function gauss(rng: () => number): number {
  let u = 0, v = 0; while (u === 0) u = rng(); while (v === 0) v = rng();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}
