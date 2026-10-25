// Shared stone weathering model: base mottle, vertical rain streaks, black
// crust under ledges, crustose lichen, moss on tops, algae splash and ground
// AO near the base, plus per-vertex polish for polished granite faces.
import * as THREE from 'three';
import { MeshBuilder, type Mark, type RGB, type Vec3, hex, mix, mul, clamp01, smoothstep, blob, v3 } from './AssetCore';
import { createNoise3D, subSeed } from './AssetRng';

export interface StoneStyle {
  base: RGB[];
  /** large-scale color mottle 0..1 */
  mottle: number;
  /** lichen coverage 0..1 */
  lichen: number;
  /** rain streak darkness 0..1 */
  streak: number;
  /** green-black algae/soil splash near the ground 0..1 */
  algae: number;
  /** moss on upward faces 0..1 */
  moss: number;
  /** max polish on polished faces 0..1 (drives aPolish) */
  polish: number;
  /** black crust on sheltered undersides 0..1 (marble, limestone) */
  crust: number;
}

export const STONE_STYLES = {
  greyGranite: { base: [hex(0x8e8c86), hex(0x7e7c77), hex(0x9a9790)], mottle: 0.25, lichen: 0.35, streak: 0.5, algae: 0.6, moss: 0.25, polish: 0.75, crust: 0.1 },
  pinkGranite: { base: [hex(0x9a8078), hex(0x8c7268), hex(0xa48a80)], mottle: 0.25, lichen: 0.3, streak: 0.45, algae: 0.5, moss: 0.2, polish: 0.8, crust: 0.1 },
  darkGranite: { base: [hex(0x4a4a4a), hex(0x3e3e3f), hex(0x55534f)], mottle: 0.15, lichen: 0.25, streak: 0.3, algae: 0.4, moss: 0.15, polish: 0.9, crust: 0.05 },
  whiteMarble: { base: [hex(0xc2bfb6), hex(0xb6b2a8), hex(0xcac6bc)], mottle: 0.12, lichen: 0.55, streak: 0.8, algae: 0.8, moss: 0.35, polish: 0.15, crust: 0.7 },
  sandstone: { base: [hex(0x9e8a6c), hex(0x8e7a5e), hex(0xa89474)], mottle: 0.35, lichen: 0.5, streak: 0.6, algae: 0.7, moss: 0.5, polish: 0, crust: 0.3 },
  fieldstone: { base: [hex(0x8a8578), hex(0x9a8c74), hex(0x7a6e60), hex(0x6a665e), hex(0xa49a88), hex(0x8a6e58)], mottle: 0.4, lichen: 0.55, streak: 0.4, algae: 0.6, moss: 0.6, polish: 0, crust: 0.2 },
  limestone: { base: [hex(0x9a9484), hex(0x8a8476), hex(0xa8a090)], mottle: 0.35, lichen: 0.5, streak: 0.7, algae: 0.5, moss: 0.55, polish: 0, crust: 0.4 },
} satisfies Record<string, StoneStyle>;
export type StoneStyleName = keyof typeof STONE_STYLES;

const LICHEN: RGB[] = [hex(0xb39a56), hex(0x9a9f88), hex(0xc2beb0), hex(0x8c8c72)];
const MOSS: RGB[] = [hex(0x55602e), hex(0x6a7234), hex(0x4a5628)];
const ALGAE = hex(0x46483a);
const STREAK = hex(0x3a3833);
const CRUST = hex(0x2c2a27);

export interface PaintStoneOpts {
  /** object height, for streak and AO falloff */
  height: number;
  /** override base color (one stone of a wall) */
  baseColor?: RGB;
  ground?: number;
  /** returns 0..1 polish weight per face normal (e.g. polished front/back) */
  polishFaces?: (n: Vec3, p: Vec3) => number;
  /** multiplies all weathering (fresh stone = 0.2, old = 1.2) */
  age?: number;
}

export function paintStone(b: MeshBuilder, m: Mark, style: StoneStyle, seed: number, o: PaintStoneOpts): void {
  const n3 = createNoise3D(subSeed(seed, 500));
  const age = o.age ?? 1;
  const g = o.ground ?? 0;
  const lichenMask = new Float32Array(b.vertexCount - m.v);
  const streakMask = new Float32Array(b.vertexCount - m.v);
  const base0 = o.baseColor ?? style.base[0]!;
  b.paint(m, (p, n, i) => {
    const yN = clamp01((p.y - g) / Math.max(0.05, o.height));
    let c: RGB = o.baseColor ?? mix(base0, style.base[1 % style.base.length]!, 0.5 + 0.5 * n3(p.x * 1.3, p.y * 1.3, p.z * 1.3));
    c = mul(c, 1 + style.mottle * 0.35 * n3(p.x * 4.1, p.y * 4.1, p.z * 4.1));
    // rain streaks on vertical faces, strongest just below the top
    const vert = 1 - Math.abs(n.y);
    const s = n3(p.x * 13 + p.z * 13, p.y * 0.9, 7.7) * 0.7 + n3(p.x * 31 + p.z * 29, p.y * 2.1, 1.1) * 0.3;
    const streak = clamp01(style.streak * age * vert * smoothstep(0.0, 0.5, s) * (0.35 + 0.65 * yN));
    c = mix(c, STREAK, streak * 0.55);
    // black crust in sheltered undersides
    if (n.y < -0.2) c = mix(c, CRUST, style.crust * age * smoothstep(-0.2, -0.8, n.y) * 0.8);
    // crustose lichen: favours tops and edges, patchy
    const ln = n3(p.x * 6.3 + 3, p.y * 6.3, p.z * 6.3) * 0.65 + n3(p.x * 17, p.y * 17, p.z * 17) * 0.35 + Math.max(0, n.y) * 0.25 + yN * 0.1;
    const lich = smoothstep(0.62 - style.lichen * age * 0.5, 0.72 - style.lichen * age * 0.5, ln);
    const lc = LICHEN[Math.floor((n3(p.x * 2.1, p.y * 2.1 + 9, p.z * 2.1) * 0.5 + 0.5) * LICHEN.length) % LICHEN.length]!;
    c = mix(c, lc, lich * 0.85);
    // moss on upward faces
    const mossW = style.moss * age * smoothstep(0.45, 0.95, n.y) * smoothstep(-0.1, 0.4, n3(p.x * 3, p.y * 3 + 5, p.z * 3));
    c = mix(c, MOSS[Math.floor(Math.abs(n3(p.x, p.y, p.z)) * 3) % 3]!, clamp01(mossW));
    // algae and soil splash near the ground, then contact AO
    const splash = style.algae * age * Math.pow(clamp01(1 - (p.y - g) / 0.3), 2);
    c = mix(c, ALGAE, splash * 0.7);
    c = mul(c, 0.5 + 0.5 * smoothstep(0, 0.12, p.y - g));
    const k = i - m.v;
    lichenMask[k] = Math.max(lich, mossW);
    streakMask[k] = streak;
    return [clamp01(c[0]), clamp01(c[1]), clamp01(c[2])];
  });
  if (style.polish > 0 && o.polishFaces) {
    const pf = o.polishFaces;
    b.setPolish(m, (p, n) => style.polish * pf(n, p));
    for (let k = m.v; k < b.vertexCount; k++) {
      const j = k - m.v;
      b.polish[k] = b.polish[k]! * (1 - lichenMask[j]!) * (1 - streakMask[j]! * 0.8) / Math.max(0.6, age);
    }
  } else {
    b.emitPolish = true; // keep the attribute present (zeros) on all stone
  }
}

/** Rough, roundish fieldstone block. */
export function roughStone(b: MeshBuilder, n: number, center: Vec3, size: Vec3, rot: THREE.Quaternion, seed: number, squareness = 0.55, roughness = 0.12): Mark {
  const noise = createNoise3D(subSeed(seed, 501));
  const m = blob(b, n, v3(), size.clone().multiplyScalar(0.5), (d) => 1 + noise(d.x * 1.7, d.y * 1.7, d.z * 1.7) * roughness + noise(d.x * 4, d.y * 4, d.z * 4) * roughness * 0.35, squareness);
  b.transform(m, new THREE.Matrix4().compose(center, rot, v3(1, 1, 1)));
  return m;
}
