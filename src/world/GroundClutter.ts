// Ground clutter: autumn leaf drifts, acorns and chestnuts, twigs, fallen
// branches, moss cushions and bare soil patches. All sit on y = 0 with
// contact AO baked in. Leaves and nuts use aSway = 0 (they do not sway);
// moss and soil are rigid ground decals.
import * as THREE from 'three';
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3, type Mark,
  v3, UP, hex, mix, tint, mul, clamp01, smoothstep, card, tube, blob, lathe, mat4, withinBudget, boxColliderOf,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, pickWeighted, chance, createNoise3D, subSeed, type Rnd } from './assetkit/AssetRng';
import { Cell, cellUV, solidUV, type CellId } from './textures/AssetTextures';
import { foliageMaterial, woodMaterial, groundMaterial } from './assetkit/AssetMaterials';

export const LEAF_PALETTE = {
  oak: [hex(0x7a5a3a), hex(0x8f6a40), hex(0x6e5034), hex(0x9a7a4c)] as RGB[],
  maple: [hex(0x8a2f1e), hex(0xa4401f), hex(0xb0581f), hex(0xb8902e), hex(0xa87a2a)] as RGB[],
  beech: [hex(0x9a5a2a), hex(0xa86a34), hex(0x8a4e26)] as RGB[],
  decayed: [hex(0x4a3a2a), hex(0x5a4632), hex(0x3e3226)] as RGB[],
  duff: hex(0x40301f),
};
export const WOOD_PALETTE = {
  bark: [hex(0x5a5046), hex(0x6a5e50), hex(0x4e463c)] as RGB[],
  grey: [hex(0x7a7468), hex(0x8a8478), hex(0x706a5e)] as RGB[],
  silver: hex(0xa49d90),
  rot: hex(0x6a5038),
  moss: hex(0x55602e),
};

const contactAO = (y: number, h = 0.05): number => 0.45 + 0.55 * smoothstep(0, h, y);

function irregularRadius(noise: (x: number, y: number, z: number) => number, a: number, base: number, rough: number): number {
  return base * (1 + rough * (noise(Math.cos(a) * 1.3, Math.sin(a) * 1.3, 0.5) * 0.7 + noise(Math.cos(a) * 3.1, Math.sin(a) * 3.1, 2.5) * 0.3));
}

/** Polar-grid ground patch with a noisy outline that sinks at the edge. */
function groundPatch(b: MeshBuilder, seed: number, radius: number, rings: number, segs: number, height: (r: number, a: number, x: number, z: number) => number, rough = 0.35): Mark {
  const noise = createNoise3D(subSeed(seed, 700));
  const m = b.mark();
  const c = b.vert(v3(0, height(0, 0, 0, 0), 0), UP, 0, 0, [1, 1, 1]);
  for (let i = 1; i <= rings; i++) {
    const f = i / rings;
    for (let j = 0; j < segs; j++) {
      const a = (j / segs) * Math.PI * 2;
      const R = irregularRadius(noise, a, radius, rough) * f;
      const x = Math.cos(a) * R, z = Math.sin(a) * R;
      b.vert(v3(x, i === rings ? -0.005 : height(f, a, x, z), z), UP, x, z, [1, 1, 1]);
    }
  }
  for (let j = 0; j < segs; j++) b.tri(c, m.v + 1 + ((j + 1) % segs), m.v + 1 + j);
  for (let i = 1; i < rings; i++)
    for (let j = 0; j < segs; j++) {
      const a = m.v + 1 + (i - 1) * segs + j, bb = m.v + 1 + (i - 1) * segs + ((j + 1) % segs);
      b.quad(a, bb, bb + segs, a + segs);
    }
  b.smoothNormals(m);
  return m;
}

// ---------------------------------------------------------------- leaves

export interface LeafDriftOptions {
  radius?: number;
  /** 0..1 how much leaves pile toward one side (against a wall or stone) */
  pile?: number;
  /** dominant leaf type; default seed-driven mix */
  mix?: 'oak' | 'maple' | 'beech' | 'mixed';
}

/** Drift of fallen leaves lying on a dark duff layer. */
export function leafDrift(seed: number, lod: LOD, opts: LeafDriftOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5000);
  const R = opts.radius ?? range(rnd, 0.6, 1.4);
  const pile = opts.pile ?? range(rnd, 0, 0.8);
  const mixKind = opts.mix ?? pick(rnd, ['oak', 'maple', 'beech', 'mixed', 'mixed'] as const);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const pileDir = rnd() * Math.PI * 2;
  const pd = v3(Math.cos(pileDir), 0, Math.sin(pileDir));
  const depthAt = (x: number, z: number): number => {
    const r = Math.hypot(x, z) / R;
    const side = (x * pd.x + z * pd.z) / R;
    return Math.max(0, (1 - r * r)) * (0.015 + pile * 0.06 * smoothstep(-0.2, 0.8, side));
  };
  // duff layer
  const dm = groundPatch(b, seed, R * 0.85, lod === 0 ? 4 : 2, lod === 2 ? 10 : lod === 1 ? 14 : 24, (_f, _a, x, z) => depthAt(x, z) * 0.6, 0.3);
  b.paint(dm, () => tint(LEAF_PALETTE.duff, range(rnd, 0.9, 1.1)));
  const s = solidUV();
  for (let k = dm.v; k < b.vertexCount; k++) { b.uvs[k * 2] = s.u0; b.uvs[k * 2 + 1] = (s.v0 + s.v1) / 2; }
  const area = Math.PI * R * R;
  const want = Math.round(area * (lod === 0 ? 900 : lod === 1 ? 110 : 20));
  const sizeMul = lod === 0 ? 1 : lod === 1 ? 1.9 : 3.8;
  const kinds: [CellId, RGB[], number][] = [];
  if (mixKind === 'oak' || mixKind === 'mixed') kinds.push([Cell.OakLeaf, LEAF_PALETTE.oak, mixKind === 'oak' ? 1 : 0.4]);
  if (mixKind === 'maple' || mixKind === 'mixed') kinds.push([Cell.MapleLeaf, LEAF_PALETTE.maple, mixKind === 'maple' ? 1 : 0.35]);
  if (mixKind === 'beech' || mixKind === 'mixed') kinds.push([Cell.EllipticLeaf, LEAF_PALETTE.beech, mixKind === 'beech' ? 1 : 0.3]);
  for (let i = 0; i < want; i++) {
    const ok = withinBudget(b, budget, () => {
      // density falls off toward the drift edge
      const r = R * Math.pow(rnd(), 0.62) * (1 + gauss(rnd) * 0.1);
      const a = rnd() * Math.PI * 2;
      const x = Math.cos(a) * r, z = Math.sin(a) * r;
      const d = depthAt(x, z);
      const [cell, pal] = pickWeighted(rnd, kinds.map((k) => [[k[0], k[1]] as const, k[2]] as const));
      let col = tint(pick(rnd, pal), range(rnd, 0.8, 1.1), range(rnd, -0.05, 0.05));
      if (chance(rnd, 0.25)) col = mix(col, pick(rnd, LEAF_PALETTE.decayed), range(rnd, 0.3, 0.8));
      const size = range(rnd, 0.08, 0.14) * sizeMul;
      const rot = rnd() * Math.PI * 2;
      const u = v3(Math.cos(rot), 0, Math.sin(rot)), vv = v3(-Math.sin(rot), 0, Math.cos(rot));
      // small random tilt and a curl so leaves aren't perfectly flat
      const tilt = new THREE.Quaternion().setFromEuler(new THREE.Euler(gauss(rnd) * 0.35, 0, gauss(rnd) * 0.35));
      u.applyQuaternion(tilt); vv.applyQuaternion(tilt);
      const y = d * rnd() + 0.003 + size * 0.1;
      const n = UP.clone().lerp(v3().crossVectors(u, vv).normalize(), 0.3).normalize();
      const shade = 0.6 + 0.4 * clamp01((y - d * 0.3) / Math.max(0.01, d * 0.7 + 0.01));
      card(b, v3(x, y, z), u, vv, size, size, {
        uv: cellUV(cell), color: mul(col, shade), sway: [0, 0], pivot: 'center', normal: n,
        segments: 1, curl: v3(0, size * range(rnd, 0, 0.2), 0),
      });
    });
    if (!ok) break;
  }
  return { geometry: b.build(), material: foliageMaterial() };
}

// ---------------------------------------------------------------- nuts

export interface NutOptions { radius?: number; kind?: 'acorn' | 'chestnut' | 'mixed'; count?: number; }

/** Scatter of acorns (with and without caps), conkers and split husks. */
export function nutScatter(seed: number, lod: LOD, opts: NutOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5100);
  const R = opts.radius ?? range(rnd, 0.6, 1.4);
  const kind = opts.kind ?? pick(rnd, ['acorn', 'chestnut', 'mixed'] as const);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const n = opts.count ?? (lod === 0 ? irange(rnd, 40, 80) : lod === 1 ? 30 : 24);
  const s = solidUV();
  const acornC = [hex(0x7a5a32), hex(0x8a6a3a), hex(0x6a4a2a), hex(0x8a7a40)];
  const capC = [hex(0x6a5a42), hex(0x5a4a36)];
  const conkerC = [hex(0x5a2e1a), hex(0x6a3820), hex(0x4e2816)];
  const huskC = [hex(0x6a6a38), hex(0x5a4e30), hex(0x7a6a40)];
  for (let i = 0; i < n; i++) {
    const ok = withinBudget(b, budget, () => {
      const r = R * Math.pow(rnd(), 0.7), a = rnd() * Math.PI * 2;
      const at = v3(Math.cos(a) * r, 0, Math.sin(a) * r);
      const yaw = rnd() * Math.PI * 2;
      const isAcorn = kind === 'acorn' || (kind === 'mixed' && chance(rnd, 0.55));
      const m = b.mark();
      if (lod === 2) {
        const sz = isAcorn ? 0.02 : 0.03;
        blob(b, 1, v3(0, sz * 0.4, 0), v3(sz, sz * 0.6, sz), undefined, 0);
        b.paint(m, () => pick(rnd, isAcorn ? acornC : conkerC));
      } else if (isAcorn) {
        const L = range(rnd, 0.018, 0.028), W = L * range(rnd, 0.55, 0.7);
        const segs = lod === 0 ? 6 : 4;
        const nm = lathe(b, lod === 0 ? [[0.0005, 0], [W * 0.45, L * 0.12], [W * 0.5, L * 0.45], [W * 0.42, L * 0.8], [0.0005, L]] : [[0.0005, 0], [W * 0.5, L * 0.45], [0.0005, L]], segs);
        b.paint(nm, () => tint(pick(rnd, acornC), range(rnd, 0.85, 1.1)));
        if (chance(rnd, 0.5)) {
          const cm = lathe(b, [[W * 0.55, 0], [W * 0.5, L * 0.18], [W * 0.1, L * 0.3]], segs);
          b.transform(cm, mat4(v3(0, 0, 0)));
          b.paint(cm, () => pick(rnd, capC));
        }
        // lie on the side
        b.transform(m, new THREE.Matrix4().makeRotationZ(Math.PI / 2 + gauss(rnd) * 0.2).premultiply(new THREE.Matrix4().makeTranslation(L * 0.5, W * 0.45, 0)));
      } else {
        const husk = chance(rnd, 0.35);
        const rr = husk ? range(rnd, 0.025, 0.035) : range(rnd, 0.014, 0.019);
        const noise = createNoise3D(irange(rnd, 0, 1e6));
        blob(b, lod === 0 ? 2 : 1, v3(0, rr * 0.75, 0), v3(rr, rr * 0.8, rr), (d) => (husk ? 1 + Math.max(0, noise(d.x * 9, d.y * 9, d.z * 9)) * 0.35 : 1 + noise(d.x * 2, d.y * 2, d.z * 2) * 0.12), 0);
        const base = husk ? pick(rnd, huskC) : pick(rnd, conkerC);
        b.paint(m, (_p, nn) => {
          // conker: pale hilum patch on one side
          if (!husk && nn.x > 0.7) return hex(0x9a8a6a);
          return mul(base, 0.8 + 0.4 * clamp01(nn.y));
        });
      }
      b.transform(m, new THREE.Matrix4().makeRotationY(yaw).premultiply(new THREE.Matrix4().makeTranslation(at.x, 0, at.z)));
      b.shade(m, (p) => contactAO(p.y, 0.02));
      for (let k = m.v; k < b.vertexCount; k++) { b.uvs[k * 2] = s.u0; b.uvs[k * 2 + 1] = (s.v0 + s.v1) / 2; }
    });
    if (!ok) break;
  }
  return { geometry: b.build(), material: foliageMaterial() };
}

// ---------------------------------------------------------------- wood

function branchTube(b: MeshBuilder, rnd: Rnd, lod: LOD, from: Vec3, dir: Vec3, len: number, r0: number, segs: number, sag: number): { m: Mark; path: Vec3[] } {
  const pts: Vec3[] = [];
  const d = dir.clone().normalize();
  const side = v3().crossVectors(d, UP).normalize();
  for (let i = 0; i <= segs; i++) {
    const t = i / segs;
    const p = from.clone().addScaledVector(d, len * t);
    p.addScaledVector(side, Math.sin(t * Math.PI * range(rnd, 0.8, 1.6)) * len * 0.04 * gauss(rnd));
    p.y += Math.sin(t * Math.PI) * sag;
    pts.push(p);
  }
  const m = tube(b, pts, { radial: lod === 0 ? (r0 > 0.03 ? 7 : 4) : 3, radius: (t) => r0 * (1 - t * 0.55), vScale: 1 / (r0 * 12), capEnd: lod === 0 });
  return { m, path: pts };
}

function paintWood(b: MeshBuilder, m: Mark, rnd: Rnd, seed: number, barkLoss: number, mossy: number): void {
  const n3 = createNoise3D(subSeed(seed, 710));
  const bark = pick(rnd, WOOD_PALETTE.bark);
  const grey = pick(rnd, WOOD_PALETTE.grey);
  b.paint(m, (p, n) => {
    let c = mix(bark, grey, smoothstep(-0.2, 0.6, n3(p.x * 2, p.y * 2, p.z * 2)));
    const loss = smoothstep(0.5 - barkLoss * 0.6, 0.6 - barkLoss * 0.6, n3(p.x * 3.3 + 4, p.y * 3.3, p.z * 3.3));
    c = mix(c, WOOD_PALETTE.silver, loss * 0.8);
    c = mix(c, WOOD_PALETTE.moss, mossy * smoothstep(0.2, 0.9, n.y) * smoothstep(0, 0.5, n3(p.x * 5, p.y * 5 + 3, p.z * 5)));
    return mul(c, contactAO(p.y, 0.08) * (0.85 + 0.15 * clamp01(n.y + 0.5)));
  });
}

export interface TwigOptions { radius?: number; count?: number; }

/** Litter of small twigs (8 to 30) lying in a patch. */
export function twigs(seed: number, lod: LOD, opts: TwigOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5200);
  const R = opts.radius ?? range(rnd, 0.7, 1.5);
  const n = opts.count ?? (lod === 0 ? irange(rnd, 14, 30) : lod === 1 ? 10 : 8);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  for (let i = 0; i < n; i++) {
    const ok = withinBudget(b, budget, () => {
      const r = R * Math.sqrt(rnd()), a = rnd() * Math.PI * 2;
      const at = v3(Math.cos(a) * r, 0.006, Math.sin(a) * r);
      const yaw = rnd() * Math.PI * 2;
      const len = range(rnd, 0.12, 0.5), rad = range(rnd, 0.003, 0.008) * (lod === 2 ? 2 : 1);
      if (lod === 2) {
        const m = card(b, at, v3(-Math.sin(yaw), 0, Math.cos(yaw)), v3(Math.cos(yaw), 0, Math.sin(yaw)), rad * 2, len, { uv: { u0: 0, v0: 0, u1: 1, v1: 1 }, color: pick(rnd, WOOD_PALETTE.grey), sway: [0, 0], pivot: 'center', normal: UP });
        b.shade(m, () => 0.7);
        return;
      }
      const dir = v3(Math.cos(yaw), range(rnd, -0.02, 0.06), Math.sin(yaw));
      const main = branchTube(b, rnd, lod, at.clone().add(v3(0, rad, 0)), dir, len, rad, lod === 0 ? 3 : 1, rad * 2);
      if (lod === 0 && chance(rnd, 0.6)) {
        const k = main.path[Math.floor(main.path.length / 2)]!;
        const fork = dir.clone().applyAxisAngle(UP, (chance(rnd, 0.5) ? 1 : -1) * range(rnd, 0.4, 0.8));
        branchTube(b, rnd, lod, k, fork, len * range(rnd, 0.3, 0.5), rad * 0.6, 2, 0);
      }
      paintWood(b, main.m, rnd, irange(rnd, 0, 1e6), 0.4, 0.1);
    });
    if (!ok) break;
  }
  return { geometry: b.build(), material: woodMaterial() };
}

export interface FallenBranchOptions { length?: number; }

/** Fallen limb 1.5 to 4 m with side branches and stubs, resting on the ground. */
export function fallenBranch(seed: number, lod: LOD, opts: FallenBranchOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5300);
  const L = opts.length ?? range(rnd, 1.5, 4);
  const r0 = range(rnd, 0.04, 0.09) * (L / 2.5);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const ws = irange(rnd, 0, 1e6);
  const segs = lod === 0 ? 10 : lod === 1 ? 5 : 2;
  const mainDir = v3(1, 0.03, gauss(rnd) * 0.1);
  const start = v3(-L / 2, r0 * 0.9, 0);
  const pts: Vec3[] = [];
  for (let i = 0; i <= segs; i++) {
    const t = i / segs;
    const p = start.clone().addScaledVector(mainDir.clone().normalize(), L * t);
    p.z += Math.sin(t * 3 + rnd()) * L * 0.03;
    p.y = r0 * (1 - t * 0.55) * 0.9 + Math.max(0, Math.sin(t * Math.PI * 1.3)) * 0.04; // touches down, slightly arched
    pts.push(p);
  }
  if (lod === 2) {
    const m = tube(b, pts, { radial: 4, radius: (t) => r0 * (1 - t * 0.55) });
    paintWood(b, m, rnd, ws, 0.3, 0.3);
  } else {
    const m = tube(b, pts, {
      radial: lod === 0 ? 9 : 5, radius: (t) => r0 * (1 - t * 0.55) * (t < 0.03 ? 1.15 : 1),
      radialNoise: (t, a) => 1 + 0.06 * Math.sin(a * 5 + t * 20), vScale: 1 / (r0 * 8),
    });
    paintWood(b, m, rnd, ws, range(rnd, 0.2, 0.6), range(rnd, 0.2, 0.6));
    // side branches, some broken off as stubs
    const nb = lod === 0 ? irange(rnd, 3, 7) : 2;
    for (let i = 0; i < nb; i++) {
      withinBudget(b, budget, () => {
        const t = range(rnd, 0.25, 0.9);
        const idx = Math.round(t * segs);
        const at = pts[idx]!;
        const rr = r0 * (1 - t * 0.55) * range(rnd, 0.35, 0.6);
        const side = chance(rnd, 0.5) ? 1 : -1;
        const dir = v3(range(rnd, 0.4, 1), range(rnd, -0.1, 0.5), side * range(rnd, 0.5, 1));
        const len = chance(rnd, 0.35) ? rr * 3 : L * range(rnd, 0.15, 0.4);
        const bt = branchTube(b, rnd, lod, at, dir, len, rr, lod === 0 ? 4 : 2, 0);
        paintWood(b, bt.m, rnd, ws + i, 0.4, 0.2);
        if (lod === 0 && len > rr * 4) for (let k = 0; k < 3; k++) {
          const tw = bt.path[irange(rnd, 1, bt.path.length - 1)]!;
          const twm = branchTube(b, rnd, lod, tw, dir.clone().applyAxisAngle(UP, gauss(rnd) * 1.2).add(v3(0, 0.3, 0)), len * range(rnd, 0.2, 0.4), rr * 0.3, 2, 0);
          paintWood(b, twm.m, rnd, ws + i * 7 + k, 0.5, 0.1);
        }
      });
    }
  }
  const g = b.build();
  return { geometry: g, material: woodMaterial(), collider: boxColliderOf(g) };
}

// ---------------------------------------------------------------- moss / soil

export interface PatchOptions { radius?: number; }

/** Raised moss cushion, 1 to 4 cm, irregular outline sinking into the ground. */
export function mossPatch(seed: number, lod: LOD, opts: PatchOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5400);
  const R = opts.radius ?? range(rnd, 0.3, 1.2);
  const noise = createNoise3D(subSeed(seed, 5401));
  const b = new MeshBuilder();
  const rings = lod === 0 ? 10 : lod === 1 ? 5 : 2, segs = lod === 0 ? 40 : lod === 1 ? 20 : 12;
  const H = range(rnd, 0.015, 0.04);
  const m = groundPatch(b, seed, R, rings, segs, (f, _a, x, z) => H * (1 - f * f) * Math.max(0.1, 0.6 + 0.6 * noise(x * 9, 0, z * 9) + 0.3 * noise(x * 31, 2, z * 31)), 0.45);
  const cols = [hex(0x4e6228), hex(0x62702e), hex(0x425224), hex(0x6e7236), hex(0x58542c)];
  b.paint(m, (p, n) => {
    const k = noise(p.x * 6, 3, p.z * 6) * 0.5 + 0.5;
    let c = mix(cols[0]!, cols[1]!, k);
    c = mix(c, cols[Math.floor(k * 4.99)]!, 0.4);
    if (noise(p.x * 20, 7, p.z * 20) > 0.45) c = mix(c, hex(0x3e3a24), 0.5); // dead brown bits
    return mul(c, (0.7 + 0.3 * clamp01(p.y / H)) * (0.85 + 0.15 * n.y));
  });
  b.boxUV(m, 4);
  return { geometry: b.build(), material: groundMaterial() };
}

/** Bare soil scuff with a few embedded pebbles (LOD0). */
export function soilPatch(seed: number, lod: LOD, opts: PatchOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 5500);
  const R = opts.radius ?? range(rnd, 0.4, 1.5);
  const noise = createNoise3D(subSeed(seed, 5501));
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const rings = lod === 0 ? 8 : lod === 1 ? 4 : 2, segs = lod === 0 ? 36 : lod === 1 ? 18 : 12;
  const m = groundPatch(b, seed, R, rings, segs, (f, _a, x, z) => 0.006 * (1 - f) + noise(x * 7, 1, z * 7) * 0.006, 0.5);
  const moist = hex(0x4e3e2c), dry = hex(0x7a6648), thatch = hex(0x6e6046);
  b.paint(m, (p) => {
    const r = Math.hypot(p.x, p.z) / R;
    let c = mix(moist, dry, smoothstep(-0.3, 0.5, noise(p.x * 3, 2, p.z * 3)));
    c = mix(c, thatch, smoothstep(0.6, 1.0, r)); // grades into thatch at the edge
    return mul(c, 0.9 + 0.2 * noise(p.x * 25, 5, p.z * 25));
  });
  b.boxUV(m, 3);
  if (lod === 0) {
    for (let i = 0; i < irange(rnd, 15, 45); i++) {
      withinBudget(b, budget, () => {
        const r = R * 0.85 * Math.sqrt(rnd()), a = rnd() * Math.PI * 2;
        const sz = range(rnd, 0.015, 0.05);
        const pm = blob(b, 1, v3(Math.cos(a) * r, sz * 0.15, Math.sin(a) * r), v3(sz, sz * 0.45, sz * range(rnd, 0.6, 1)), undefined, 0.3);
        const pc = tint(pick(rnd, [hex(0x8a8478), hex(0x9a8c74), hex(0x6a665e), hex(0xa8a090)]), range(rnd, 0.85, 1.1));
        b.paint(pm, (p) => mul(pc, contactAO(p.y, sz * 0.4)));
        b.boxUV(pm, 6);
      });
    }
  }
  return { geometry: b.build(), material: groundMaterial() };
}
