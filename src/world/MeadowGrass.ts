// Tall autumn meadow: grass and wildflower clumps for unmown valley slopes.
//
// Wind: every vertex carries aSway = arc length from the ground along its
// stem, divided by the clump's tallest stem (0 at the base, 1 at the tallest
// tip). Leaves and heads inherit the sway of the node they hang from.
import * as THREE from 'three';
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3, type UVRect,
  v3, UP, hex, mix, tint, clamp01, smoothstep, lerp, ribbon, card, discCard, lathe, withinBudget, perpendicular,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, pickWeighted, chance, type Rnd } from './assetkit/AssetRng';
import { Cell, cellUV, solidUV, type CellId } from './textures/AssetTextures';
import { foliageMaterial } from './assetkit/AssetMaterials';
import { scatterInstances, type ScatterOptions, type ScatterBatch } from './assetkit/AssetScatter';

export type MeadowSpecies =
  | 'foxtail' | 'timothy' | 'bluestem' | 'queenAnnesLace' | 'goldenrod' | 'aster' | 'milkweed' | 'leafGrass';

/** Autumn meadow palette (sRGB authored, linear stored). Tune freely. */
export const MEADOW_PALETTE = {
  straw: [hex(0xc0a060), hex(0xb49658), hex(0xc8ae78)] as RGB[],
  tan: [hex(0xc6b28c), hex(0xb8a684), hex(0xcdbc98)] as RGB[],
  bronze: [hex(0x9a5c34), hex(0x88502e), hex(0xa66c3e), hex(0x7c4a30)] as RGB[],
  olive: [hex(0x6c7238), hex(0x5e6a34), hex(0x7b7a40)] as RGB[],
  stemPurple: hex(0x7a4c3c),
  seedSilver: hex(0xc9c0ae),
  qalFresh: hex(0xd2ccbc),
  qalDried: [hex(0x7a6448), hex(0x8a7454), hex(0x6a5640)] as RGB[],
  goldenrodFluff: [hex(0xb0a48c), hex(0xa89a80)] as RGB[],
  goldenrodGold: [hex(0xb89434), hex(0xa8862e)] as RGB[],
  asterPurple: [hex(0x7c5f9e), hex(0x6b4f8c), hex(0x9a88b2)] as RGB[],
  asterWhite: hex(0xd8d4da),
  asterFaded: hex(0x8c7c74),
  milkweedLeaf: [hex(0xbea650), hex(0x9a7a46), hex(0x86683e), hex(0x6e5a40)] as RGB[],
  thatch: [hex(0x9c8c70), hex(0xa89878), hex(0x8a7a60)] as RGB[],
  milkweedPod: [hex(0x7a6c52), hex(0x6a5e46), hex(0x8a7a5a)] as RGB[],
  silk: hex(0xdcd8cc),
};

export interface MeadowVariant {
  name: string;
  mix: readonly (readonly [MeadowSpecies, number])[];
  stems: readonly [number, number];
  radius: readonly [number, number];
  height: readonly [number, number];
  /** share of stems that are still olive-green */
  green: number;
  bigBluestem?: boolean;
}

export const MEADOW_VARIANTS: readonly MeadowVariant[] = [
  { name: 'foxtail-straw', mix: [['foxtail', 0.65], ['leafGrass', 0.35]], stems: [18, 36], radius: [0.12, 0.25], height: [0.6, 1.0], green: 0.08 },
  { name: 'timothy', mix: [['timothy', 0.7], ['leafGrass', 0.3]], stems: [16, 32], radius: [0.1, 0.22], height: [0.8, 1.2], green: 0.18 },
  { name: 'little-bluestem', mix: [['bluestem', 0.85], ['leafGrass', 0.15]], stems: [24, 40], radius: [0.1, 0.2], height: [0.6, 0.95], green: 0 },
  { name: 'big-bluestem', mix: [['bluestem', 0.9], ['leafGrass', 0.1]], stems: [14, 28], radius: [0.15, 0.3], height: [1.1, 1.4], green: 0.04, bigBluestem: true },
  { name: 'goldenrod', mix: [['goldenrod', 0.7], ['leafGrass', 0.3]], stems: [10, 22], radius: [0.18, 0.35], height: [0.8, 1.3], green: 0.1 },
  { name: 'queen-annes-lace', mix: [['queenAnnesLace', 0.45], ['timothy', 0.2], ['leafGrass', 0.35]], stems: [12, 26], radius: [0.15, 0.3], height: [0.7, 1.2], green: 0.12 },
  { name: 'aster-edge', mix: [['aster', 0.5], ['foxtail', 0.15], ['leafGrass', 0.35]], stems: [10, 24], radius: [0.15, 0.3], height: [0.6, 1.0], green: 0.25 },
  { name: 'milkweed-stand', mix: [['milkweed', 0.3], ['goldenrod', 0.2], ['leafGrass', 0.5]], stems: [8, 18], radius: [0.2, 0.35], height: [0.8, 1.3], green: 0.1 },
  { name: 'mixed-tawny', mix: [['foxtail', 0.25], ['timothy', 0.2], ['bluestem', 0.25], ['leafGrass', 0.3]], stems: [20, 40], radius: [0.14, 0.28], height: [0.7, 1.15], green: 0.1 },
  { name: 'olive-remnant', mix: [['leafGrass', 0.75], ['timothy', 0.25]], stems: [16, 34], radius: [0.12, 0.25], height: [0.6, 0.9], green: 0.55 },
];

interface Ctx {
  b: MeshBuilder;
  rnd: Rnd;
  lod: LOD;
  refH: number;
  widthMul: number;
  cardMul: number;
  green: number;
  solid: UVRect;
  variant: MeadowVariant;
}

interface Tone { base: RGB; tip: RGB; }

function grassTone(c: Ctx, bronzeBias = 0): Tone {
  const P = MEADOW_PALETTE;
  const cat = pickWeighted(c.rnd, [['straw', 0.42], ['tan', 0.3], ['bronze', 0.1 + bronzeBias], ['olive', 0.04 + c.green]] as const);
  const base = tint(pick(c.rnd, P[cat]), range(c.rnd, 0.82, 1.08), range(c.rnd, -0.04, 0.06));
  const tip = cat === 'olive' ? mix(base, pick(c.rnd, P.straw), range(c.rnd, 0.3, 0.7)) : mix(base, pick(c.rnd, P.tan), range(c.rnd, 0.2, 0.55));
  return { base, tip };
}

/** Integrates a bending stem. tilt is measured from vertical; > pi/2 points down. */
function stemPath(origin: Vec3, az: number, tilt0: number, tilt1: number, length: number, segs: number, rnd: Rnd, wobble = 0.15): Vec3[] {
  const pts = [origin.clone()];
  const p = origin.clone();
  let a = az;
  for (let i = 1; i <= segs; i++) {
    const t = (i - 0.5) / segs;
    const tilt = tilt0 + (tilt1 - tilt0) * Math.pow(t, 1.6);
    a += (rnd() - 0.5) * wobble;
    p.x += Math.sin(tilt) * Math.cos(a) * (length / segs);
    p.y += Math.cos(tilt) * (length / segs);
    p.z += Math.sin(tilt) * Math.sin(a) * (length / segs);
    pts.push(p.clone());
  }
  return pts;
}

const horizSide = (az: number): Vec3 => v3(-Math.sin(az), 0, Math.cos(az));
const outwardUp = (az: number, k = 0.6): Vec3 => v3(Math.cos(az) * k, 1, Math.sin(az) * k).normalize();

function blade(c: Ctx, path: Vec3[], az: number, w0: number, tone: Tone, s0 = 0, twist = 0): void {
  ribbon(c.b, path, {
    width: (t) => w0 * c.widthMul * Math.max(0.12, Math.pow(1 - t, 0.75)),
    side: () => horizSide(az),
    twist,
    color: (t) => mix(tone.base, tone.tip, smoothstep(0.25, 1, t)),
    sway: (_t, s) => (s0 + s) / c.refH,
    uv: c.solid,
    normalBias: outwardUp(az),
    normalBiasAmt: 0.55,
  });
}

function stalk(c: Ctx, path: Vec3[], az: number, w0: number, w1: number, tone: Tone, crossed: boolean, s0 = 0): void {
  const doRibbon = (side: Vec3): void => {
    ribbon(c.b, path, {
      width: (t) => lerp(w0, w1, t) * c.widthMul,
      side: () => side,
      color: (t) => mix(tone.base, tone.tip, t),
      sway: (_t, s) => (s0 + s) / c.refH,
      uv: c.solid,
      normalBias: outwardUp(az, 0.4),
      normalBiasAmt: 0.6,
    });
  };
  doRibbon(horizSide(az));
  if (crossed) doRibbon(v3(Math.cos(az), 0, Math.sin(az)));
}

function arcLen(path: Vec3[]): number {
  let s = 0;
  for (let i = 1; i < path.length; i++) s += path[i]!.distanceTo(path[i - 1]!);
  return s;
}
function tangentAt(path: Vec3[], i: number): Vec3 {
  const a = path[Math.max(0, i - 1)]!, b = path[Math.min(path.length - 1, i + 1)]!;
  return v3().subVectors(b, a).normalize();
}

/** Seed head cards along an axis; head cells have the stalk attachment ~18% up the card. */
function headCards(c: Ctx, tip: Vec3, axis: Vec3, cell: CellId, w: number, h: number, color: RGB, sway: number, curl?: Vec3, attach = 0.18): void {
  const uv = cellUV(cell);
  const u1 = v3().crossVectors(axis, UP);
  if (u1.lengthSq() < 1e-6) u1.copy(perpendicular(axis));
  u1.normalize();
  const u2 = v3().crossVectors(axis, u1).normalize();
  const W = w * c.cardMul, H = h * c.cardMul;
  const origin = tip.clone().addScaledVector(axis, -attach * H);
  const n = v3(axis.x * 0.3, 1, axis.z * 0.3).normalize();
  const segs = curl && c.lod === 0 ? 3 : 1;
  const sw: [number, number] = [sway, Math.min(1, sway + H / c.refH)];
  card(c.b, origin, u1, axis, W, H, { uv, color, sway: sw, normal: n, segments: segs, curl: curl?.clone().multiplyScalar(c.cardMul) });
  if (c.lod < 2) card(c.b, origin, u2, axis, W, H, { uv, color, sway: sw, normal: n, segments: segs, curl: curl?.clone().multiplyScalar(c.cardMul) });
}

/** Leaf card hanging from a node, roughly horizontal, drooping at the tip. */
function leafCard(c: Ctx, node: Vec3, az: number, rise: number, len: number, wid: number, color: RGB, sway: number, droop = 0.4): void {
  const dir = v3(Math.cos(az) * Math.cos(rise), Math.sin(rise), Math.sin(az) * Math.cos(rise));
  const side = horizSide(az);
  const L = len * c.cardMul;
  card(c.b, node, side, dir, (wid / 0.36) * c.cardMul, L, {
    uv: cellUV(Cell.Broadleaf), color, sway: [sway, Math.min(1, sway + L / c.refH)],
    normal: v3(0, 1, 0).lerp(dir, 0.25).normalize(),
    segments: c.lod === 0 ? 2 : 1, curl: v3(0, -droop * L, 0),
  });
}

function stemSegs(c: Ctx, hi: number): number {
  return c.lod === 0 ? hi : c.lod === 1 ? Math.max(2, Math.ceil(hi / 2)) : 1;
}

// ---------------------------------------------------------------- species

function grassLeaves(c: Ctx, path: Vec3[], az: number, tone: Tone, count: number, maxLen: number): void {
  for (let k = 0; k < count; k++) {
    const ni = Math.min(path.length - 2, Math.floor(range(c.rnd, 0, 0.45) * path.length));
    const node = path[ni]!;
    const laz = az + gauss(c.rnd) * 1.4;
    const len = range(c.rnd, 0.5, 1) * maxLen;
    const p = stemPath(node, laz, range(c.rnd, 0.3, 0.7), range(c.rnd, 1.2, 2.3), len, stemSegs(c, 5), c.rnd, 0.1);
    blade(c, p, laz, range(c.rnd, 0.004, 0.007), { base: tone.base, tip: mix(tone.tip, MEADOW_PALETTE.tan[0]!, 0.3) }, (node.y / Math.max(1e-3, path[path.length - 1]!.y)) * arcLen(path), range(c.rnd, -1, 1));
  }
}

function addGrass(c: Ctx, sp: MeadowSpecies, base: Vec3, az: number, out: number, H: number): void {
  const r = c.rnd;
  const leaves = c.lod === 0 ? irange(r, 2, 4) : c.lod === 1 ? 1 : 0;
  if (sp === 'leafGrass') {
    const n = c.lod === 2 ? 1 : c.lod === 1 ? 2 : irange(r, 3, 6);
    for (let k = 0; k < n; k++) {
      const laz = az + gauss(r) * 0.9;
      const tone = grassTone(c);
      const p = stemPath(base, laz, range(r, 0.1, 0.35) + out * 0.3, range(r, 1.0, 2.0), H * range(r, 0.45, 0.8), stemSegs(c, 6), r);
      blade(c, p, laz, range(r, 0.005, 0.009), tone, 0, range(r, -1.5, 1.5));
    }
    return;
  }
  const bronze = sp === 'bluestem' ? 0.7 : 0;
  const tone = grassTone(c, bronze);
  if (sp === 'bluestem') tone.base = mix(tone.base, MEADOW_PALETTE.stemPurple, 0.45);
  const lean = range(r, 0.03, 0.12) + out * 0.35;
  const bend = sp === 'foxtail' ? range(r, 0.25, 0.6) : sp === 'timothy' ? range(r, 0.02, 0.12) : range(r, 0.05, 0.25);
  const path = stemPath(base, az, lean, lean + bend, H, stemSegs(c, 6), r, 0.08);
  const L = arcLen(path);
  stalk(c, path, az, 0.0035, 0.002, tone, false);
  grassLeaves(c, path, az, tone, leaves, H * 0.4);
  const tip = path[path.length - 1]!, ax = tangentAt(path, path.length - 1);
  const sTip = L / c.refH;
  const outDir = v3(Math.cos(az), 0, Math.sin(az));
  if (sp === 'foxtail') {
    const hl = range(r, 0.07, 0.13);
    const col = tint(mix(tone.tip, pick(r, MEADOW_PALETTE.straw), 0.5), range(r, 0.85, 1.05), 0.03);
    headCards(c, tip, ax, Cell.Foxtail, 0.045, hl / 0.8, col, sTip, outDir.clone().multiplyScalar(hl * 0.3).add(v3(0, -hl * 0.55, 0)));
  } else if (sp === 'timothy') {
    const hl = range(r, 0.06, 0.11);
    headCards(c, tip, ax, Cell.Timothy, 0.026, hl / 0.8, tint(mix(tone.tip, MEADOW_PALETTE.tan[1]!, 0.5), range(r, 0.75, 0.95)), sTip, undefined, 0.16);
  } else if (sp === 'bluestem') {
    const seed = mix(MEADOW_PALETTE.seedSilver, tone.tip, range(r, 0.2, 0.5));
    if (c.variant.bigBluestem && chance(r, 0.7)) {
      const n = c.lod === 2 ? 1 : 3;
      for (let k = 0; k < n; k++) {
        const a = az + (k - 1) * 0.9 + gauss(r) * 0.2;
        const d = v3(Math.cos(a) * 0.35, 1, Math.sin(a) * 0.35).normalize();
        headCards(c, tip, d, Cell.Bluestem, 0.035, range(r, 0.08, 0.12), seed, sTip, undefined, 0.02);
      }
    } else {
      const n = c.lod === 0 ? irange(r, 3, 5) : c.lod === 1 ? 2 : 1;
      for (let k = 0; k < n; k++) {
        const i = Math.max(1, path.length - 1 - Math.floor((k / n) * path.length * 0.35));
        const a = az + gauss(r) * 1.2;
        const d = v3().copy(tangentAt(path, i)).add(v3(Math.cos(a) * 0.45, 0, Math.sin(a) * 0.45)).normalize();
        headCards(c, path[i]!, d, Cell.Bluestem, 0.03, range(r, 0.05, 0.08), seed, (i / (path.length - 1)) * sTip, undefined, 0.02);
      }
    }
  }
}

function addQAL(c: Ctx, base: Vec3, az: number, out: number, H: number): void {
  const r = c.rnd, P = MEADOW_PALETTE;
  const tone: Tone = { base: tint(pick(r, P.straw), 0.8), tip: tint(pick(r, P.tan), 0.85) };
  if (chance(r, c.green * 1.5)) tone.base = pick(r, P.olive);
  const lean = range(r, 0.03, 0.1) + out * 0.25;
  const path = stemPath(base, az, lean, lean + range(r, 0, 0.15), H, stemSegs(c, 6), r, 0.1);
  const L = arcLen(path);
  stalk(c, path, az, 0.006, 0.0035, tone, c.lod === 0);
  const fresh = chance(r, 0.3);
  const umbel = (at: Vec3, rad: number, sway: number): void => {
    const rot = r() * Math.PI * 2;
    const u = v3(Math.cos(rot), 0, Math.sin(rot)), vv = v3(-Math.sin(rot), 0, Math.cos(rot));
    const col = fresh ? tint(P.qalFresh, range(r, 0.9, 1.02)) : tint(pick(r, P.qalDried), range(r, 0.85, 1.1));
    const depth = fresh ? rad * 0.15 : rad * range(r, 0.45, 0.8); // dried umbels curl into "bird's nests"
    const ring = c.lod === 0 ? 8 : c.lod === 1 ? 6 : 4;
    discCard(c.b, at.clone().add(v3(0, -depth * 0.5, 0)), vv, u, rad * c.cardMul, ring, cellUV(Cell.Umbel), col, sway, depth * c.cardMul, UP);
  };
  umbel(path[path.length - 1]!, range(r, 0.04, 0.07), L / c.refH);
  if (c.lod === 0 && chance(r, 0.6)) {
    const i = Math.floor(path.length * 0.6);
    const baz = az + range(r, 1, 2.5) * (chance(r, 0.5) ? 1 : -1);
    const bp = stemPath(path[i]!, baz, 0.4, 0.6, H * range(r, 0.2, 0.35), 3, r);
    stalk(c, bp, baz, 0.003, 0.002, tone, false, (i / (path.length - 1)) * L);
    umbel(bp[bp.length - 1]!, range(r, 0.025, 0.045), Math.min(1, ((i / (path.length - 1)) * L + arcLen(bp)) / c.refH));
  }
  if (c.lod < 2) for (let k = 0; k < (c.lod === 0 ? 2 : 1); k++)
    leafCard(c, base.clone().add(v3(0, 0.02, 0)), az + range(r, -2, 2), range(r, 0.1, 0.4), range(r, 0.12, 0.22), 0.05, tint(pick(r, P.qalDried), 0.9), 0.05, 0.6);
}

function addGoldenrod(c: Ctx, base: Vec3, az: number, out: number, H: number): void {
  const r = c.rnd, P = MEADOW_PALETTE;
  const tone: Tone = { base: tint(pick(r, P.bronze), 0.8), tip: tint(pick(r, P.straw), 0.75) };
  const lean = range(r, 0.02, 0.08) + out * 0.2;
  const path = stemPath(base, az, lean, lean + range(r, 0.05, 0.2), H, stemSegs(c, 6), r, 0.06);
  const L = arcLen(path);
  stalk(c, path, az, 0.006, 0.004, tone, c.lod === 0);
  const nLeaves = c.lod === 0 ? irange(r, 6, 10) : c.lod === 1 ? 3 : 0;
  for (let k = 0; k < nLeaves; k++) {
    const f = range(r, 0.15, 0.85);
    const i = Math.min(path.length - 1, Math.round(f * (path.length - 1)));
    const lc = chance(r, c.green + 0.15) ? pick(r, P.olive) : tint(pick(r, P.bronze), range(r, 0.7, 1));
    leafCard(c, path[i]!, az + k * 2.4 + gauss(r) * 0.4, range(r, 0.3, 0.8), range(r, 0.06, 0.1) * (1.2 - f * 0.5), 0.016, lc, f * L / c.refH, 0.35);
  }
  const gold = chance(r, 0.3);
  const nPl = c.lod === 2 ? 1 : irange(r, 2, 3);
  const tip = path[path.length - 1]!;
  for (let k = 0; k < nPl; k++) {
    const a = az + (k / nPl) * Math.PI * 2 + gauss(r) * 0.4;
    const d = v3(Math.cos(a) * range(r, 0.2, 0.6), 1, Math.sin(a) * range(r, 0.2, 0.6)).normalize();
    const hgt = range(r, 0.14, 0.26);
    const col = gold ? tint(pick(r, P.goldenrodGold), range(r, 0.85, 1)) : tint(pick(r, P.goldenrodFluff), range(r, 0.9, 1.05));
    const sw = Math.min(1, L / c.refH);
    card(c.b, tip.clone().addScaledVector(d, -0.02), horizSide(a), d, hgt * 0.85 * c.cardMul, hgt * c.cardMul, {
      uv: cellUV(Cell.Goldenrod), color: col, sway: [sw, Math.min(1, sw + hgt / c.refH)], normal: outwardUp(a, 0.5),
      segments: c.lod === 0 ? 2 : 1, curl: v3(Math.cos(a) * hgt * 0.25, -hgt * 0.3, Math.sin(a) * hgt * 0.25),
    });
  }
}

function addAster(c: Ctx, base: Vec3, az: number, out: number, H: number): void {
  const r = c.rnd, P = MEADOW_PALETTE;
  const tone: Tone = { base: mix(pick(r, P.olive), P.stemPurple, range(r, 0.2, 0.6)), tip: pick(r, P.olive) };
  const lean = range(r, 0.05, 0.15) + out * 0.3;
  const path = stemPath(base, az, lean, lean + range(r, 0.1, 0.3), H, stemSegs(c, 5), r, 0.12);
  const L = arcLen(path);
  stalk(c, path, az, 0.0045, 0.003, tone, false);
  const fl = pickWeighted(r, [[pick(r, P.asterPurple), 0.55], [P.asterWhite, 0.25], [P.asterFaded, 0.2]] as const);
  const nb = c.lod === 0 ? irange(r, 3, 6) : c.lod === 1 ? 2 : 1;
  for (let k = 0; k < nb; k++) {
    const f = k === 0 ? 1 : range(r, 0.55, 0.92);
    const i = Math.min(path.length - 1, Math.round(f * (path.length - 1)));
    const baz = az + gauss(r) * 1.6;
    const bl = k === 0 ? 0.01 : range(r, 0.06, 0.2);
    const bp = stemPath(path[i]!, baz, range(r, 0.5, 0.9), range(r, 0.3, 0.6), bl, c.lod === 0 ? 2 : 1, r);
    const s0 = f * L;
    if (k > 0) stalk(c, bp, baz, 0.0025, 0.0015, tone, false, s0);
    const tip = bp[bp.length - 1]!;
    const tilt = range(r, 0.15, 0.7);
    const fwd = v3(Math.cos(baz) * Math.cos(tilt), Math.sin(tilt), Math.sin(baz) * Math.cos(tilt));
    const size = range(r, 0.07, 0.12) * c.cardMul;
    const sw = Math.min(1, (s0 + arcLen(bp)) / c.refH);
    card(c.b, tip, horizSide(baz), fwd, size, size, {
      uv: cellUV(Cell.Aster), color: tint(fl, range(r, 0.85, 1.05)), sway: [sw, sw], pivot: 'center', normal: v3(0, 1, 0).lerp(fwd, 0.3).normalize(),
    });
  }
  if (c.lod === 0) for (let k = 0; k < irange(r, 3, 6); k++) {
    const f = range(r, 0.15, 0.75);
    const i = Math.round(f * (path.length - 1));
    leafCard(c, path[i]!, az + k * 2.4, range(r, 0.2, 0.6), range(r, 0.05, 0.08), 0.012, tint(tone.tip, range(r, 0.7, 0.95)), f * L / c.refH, 0.3);
  }
}

function addMilkweed(c: Ctx, base: Vec3, az: number, out: number, H: number): void {
  const r = c.rnd, P = MEADOW_PALETTE;
  const tone: Tone = { base: tint(pick(r, P.milkweedPod), 0.75), tip: tint(pick(r, P.milkweedPod), 0.9) };
  const lean = range(r, 0.02, 0.08) + out * 0.15;
  const path = stemPath(base, az, lean, lean + range(r, 0, 0.12), H, stemSegs(c, 5), r, 0.05);
  const L = arcLen(path);
  stalk(c, path, az, 0.009, 0.006, tone, c.lod === 0);
  const nodes = c.lod === 0 ? irange(r, 4, 6) : c.lod === 1 ? 2 : 0;
  for (let k = 0; k < nodes; k++) {
    const f = 0.2 + (k / Math.max(1, nodes)) * 0.6;
    const i = Math.round(f * (path.length - 1));
    const na = az + k * 1.57;
    for (const s of [0, Math.PI]) {
      if (chance(r, 0.15)) continue; // some leaves already shed
      const lc = tint(pick(r, P.milkweedLeaf), range(r, 0.85, 1.05));
      leafCard(c, path[i]!, na + s, range(r, -0.2, 0.3), range(r, 0.1, 0.15), range(r, 0.045, 0.065), lc, f * L / c.refH, range(r, 0.4, 0.9));
    }
  }
  if (c.lod === 2) return;
  const pods = irange(r, 1, 4);
  for (let k = 0; k < pods; k++) {
    const f = range(r, 0.6, 0.85);
    const i = Math.round(f * (path.length - 1));
    const pa = az + gauss(r) * 2;
    const tilt = range(r, 0.4, 1.0);
    const dir = v3(Math.cos(pa) * Math.sin(tilt), Math.cos(tilt), Math.sin(pa) * Math.sin(tilt));
    const len = range(r, 0.08, 0.11), rad = range(r, 0.014, 0.02);
    const segs = c.lod === 0 ? 6 : 4;
    const prof: [number, number][] = [];
    for (let j = 0; j <= segs; j++) {
      const t = j / segs;
      prof.push([Math.max(0.0005, rad * Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.05)), 0.8) * (1 - 0.35 * t)), t * len]);
    }
    const m = lathe(c.b, prof, c.lod === 0 ? 6 : 4);
    const sw = f * L / c.refH + 0.05;
    const col = tint(pick(r, P.milkweedPod), range(r, 0.85, 1.1));
    c.b.paint(m, (p) => mul3(col, 0.75 + 0.25 * (p.y / len)));
    c.b.setSway(m, () => sw);
    const q = new THREE.Quaternion().setFromUnitVectors(UP, dir);
    const at = path[i]!.clone().addScaledVector(dir, 0.01);
    c.b.transform(m, new THREE.Matrix4().compose(at, q, v3(1, 1, 1)));
    if (chance(r, 0.5)) {
      const top = at.clone().addScaledVector(dir, len * 0.7);
      const sz = range(r, 0.06, 0.1) * c.cardMul;
      card(c.b, top, horizSide(pa), dir.clone().lerp(UP, 0.5).normalize(), sz, sz, {
        uv: cellUV(Cell.Silk), color: tint(P.silk, range(r, 0.85, 1)), sway: [sw, Math.min(1, sw + 0.1)], normal: UP,
      });
    }
  }
}
const mul3 = (c: RGB, s: number): RGB => [c[0] * s, c[1] * s, c[2] * s];

// ---------------------------------------------------------------- public

/**
 * One meadow clump (8 to 40 stems) at the origin. variant defaults to
 * seed mod MEADOW_VARIANTS.length; seed also drives every per-stem choice.
 */
export function meadowClump(seed: number, lod: LOD, variant?: number): AssetResult {
  const vi = (variant ?? Math.abs(seed)) % MEADOW_VARIANTS.length;
  const V = MEADOW_VARIANTS[vi]!;
  const rnd = makeRnd(seed, 1000 + vi);
  const b = new MeshBuilder();
  b.windFlex = 0.45; b.windFlutter = 0.35;
  const height = range(rnd, V.height[0], V.height[1]);
  const radius = range(rnd, V.radius[0], V.radius[1]);
  const stemsFull = irange(rnd, V.stems[0], V.stems[1]);
  const stems = lod === 0 ? stemsFull : lod === 1 ? Math.max(6, Math.round(stemsFull * 0.55)) : Math.max(6, Math.round(stemsFull * 0.4));
  const c: Ctx = {
    b, rnd, lod, refH: height * 1.05, green: V.green * range(rnd, 0.6, 1.4), solid: solidUV(), variant: V,
    widthMul: lod === 0 ? 1 : lod === 1 ? 1.7 : 3.2, cardMul: lod === 0 ? 1 : lod === 1 ? 1.2 : 1.5,
  };
  const budget = TRI_BUDGET[lod] - 4;
  const leanAz = rnd() * Math.PI * 2, leanAmt = range(rnd, 0, 0.5);
  const plan: { sp: MeadowSpecies; base: Vec3; az: number; out: number; H: number }[] = [];
  for (let i = 0; i < stems; i++) {
    const sp = pickWeighted(rnd, V.mix);
    const d = Math.pow(rnd(), 0.8);
    const a = rnd() * Math.PI * 2;
    const base = v3(Math.cos(a) * d * radius, 0, Math.sin(a) * d * radius);
    // stems lean outward, biased toward a clump-wide lean direction
    const ox = Math.cos(a) * d + Math.cos(leanAz) * leanAmt, oz = Math.sin(a) * d + Math.sin(leanAz) * leanAmt;
    const az = Math.atan2(oz, ox) + gauss(rnd) * 0.35;
    const H = height * range(rnd, 0.7, 1.05) * (1 - d * 0.15);
    plan.push({ sp, base, az, out: Math.min(1, Math.hypot(ox, oz)), H });
  }
  // flowers and tall stems first so the budget guard trims filler, not heroes
  const order: Record<MeadowSpecies, number> = { milkweed: 0, queenAnnesLace: 1, goldenrod: 2, aster: 3, foxtail: 4, timothy: 5, bluestem: 6, leafGrass: 7 };
  plan.sort((x, y) => order[x.sp] - order[y.sp]);
  for (const s of plan) {
    b.curPhase = rnd();
    const ok = withinBudget(b, budget, () => {
      switch (s.sp) {
        case 'queenAnnesLace': addQAL(c, s.base, s.az, s.out, s.H); break;
        case 'goldenrod': addGoldenrod(c, s.base, s.az, s.out, s.H); break;
        case 'aster': addAster(c, s.base, s.az, s.out, s.H * 0.85); break;
        case 'milkweed': addMilkweed(c, s.base, s.az, s.out, s.H); break;
        default: addGrass(c, s.sp, s.base, s.az, s.out, s.H);
      }
    });
    if (!ok) break;
  }
  // basal tuft: short bleached blades that hide the stem bases
  const basal = lod === 0 ? Math.round(stems * 2.2) + 10 : lod === 1 ? Math.round(stems * 0.9) + 4 : 8;
  for (let i = 0; i < basal; i++) {
    const ok = withinBudget(b, budget, () => {
      const d = Math.pow(rnd(), 0.7) * radius * 1.1, a = rnd() * Math.PI * 2;
      const base = v3(Math.cos(a) * d, 0, Math.sin(a) * d);
      const az = a + gauss(rnd) * 0.6;
      const tone = grassTone(c);
      const p = stemPath(base, az, range(rnd, 0.3, 0.7), range(rnd, 1.3, 2.4), height * range(rnd, 0.25, 0.5), stemSegs(c, 4), rnd);
      blade(c, p, az, range(rnd, 0.005, 0.008), { base: mul3(tone.base, 0.9), tip: tone.tip }, 0, range(rnd, -1, 1));
    });
    if (!ok) break;
  }
  // lodged / thatch layer: old blades bent over near the ground. Cheap
  // coverage that reads as the matted meadow floor from drone height.
  const lodged = lod === 0 ? Math.round(stems * 1.2) + 6 : lod === 1 ? Math.round(stems * 0.7) + 4 : 6;
  for (let i = 0; i < lodged; i++) {
    const ok = withinBudget(b, budget, () => {
      const d = Math.pow(rnd(), 0.6) * radius, a = rnd() * Math.PI * 2;
      const base = v3(Math.cos(a) * d, 0, Math.sin(a) * d);
      const az = a + gauss(rnd) * 0.8;
      const old = tint(pick(rnd, MEADOW_PALETTE.thatch), range(rnd, 0.8, 1.05));
      const top = chance(rnd, 0.5) ? pick(rnd, MEADOW_PALETTE.tan) : pick(rnd, MEADOW_PALETTE.straw);
      const p = stemPath(base, az, range(rnd, 0.7, 1.15), range(rnd, 1.45, 1.65), height * range(rnd, 0.35, 0.7), stemSegs(c, 4), rnd, 0.25);
      blade(c, p, az, range(rnd, 0.006, 0.01), { base: mul3(old, 0.85), tip: mix(old, top, 0.5) }, 0, range(rnd, -0.6, 0.6));
    });
    if (!ok) break;
  }
  // baked AO: dark at the ground and in the clump core, open at the tips
  b.shade({ v: 0, i: 0 }, (p) => {
    const h = smoothstep(0, height * 0.45, p.y);
    const rad = clamp01(Math.hypot(p.x, p.z) / (radius * 1.3));
    return (0.38 + 0.62 * h) * (0.82 + 0.18 * Math.max(rad, h));
  });
  return { geometry: b.build(), material: foliageMaterial() };
}

export interface MeadowScatterOptions extends Omit<ScatterOptions, 'variantCount'> {
  /** restrict to some variants, e.g. [2, 3] for bluestem only */
  variants?: readonly number[];
}

/**
 * Field scatter for meadow clumps from a density mask. Returns one batch per
 * variant: build the clump with meadowClump(anySeed, lod, batch.variant) and
 * draw batch.count instances. Typical density 2 to 6 clumps per m².
 */
export function scatterMeadow(o: MeadowScatterOptions): ScatterBatch[] {
  const weights = MEADOW_VARIANTS.map((_, i) => (o.variants ? (o.variants.includes(i) ? 1 : 0) : 1));
  return scatterInstances({
    patchSize: 7, patchiness: 0.75, scale: [0.75, 1.2], maxLean: 0.14, windLean: 0.06,
    ...o, variantCount: MEADOW_VARIANTS.length, variantWeights: o.variantWeights ?? weights,
  });
}
