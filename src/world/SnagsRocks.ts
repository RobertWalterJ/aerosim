// Dead trees, snags, hollow stumps and rock outcrops for the valley wall.
// Wind: dead wood uses aSway = height / tree height * 0.35 (stiff), so a
// shared wind shader gives a slight creak without rubbery branches.
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3, type Mark,
  v3, UP, hex, mix, mul, clamp01, smoothstep, tube, blob, perpendicular, boxColliderOf, withinBudget,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, chance, createNoise3D, subSeed, type Rnd } from './assetkit/AssetRng';
import { woodMaterial, stoneMaterial } from './assetkit/AssetMaterials';
import { paintStone, STONE_STYLES, type StoneStyle } from './assetkit/StoneWeathering';

export const SNAG_PALETTE = {
  bark: [hex(0x5a5146), hex(0x4e463c), hex(0x625848)] as RGB[],
  weathered: [hex(0x7a7468), hex(0x8a8478), hex(0x6e685c)] as RGB[],
  silver: hex(0xa29b8e),
  rot: hex(0x6a5038),
  punk: hex(0x3a2c20),
  moss: hex(0x55602e),
  lichen: hex(0x8f9a7a),
  fungus: [hex(0xb0a080), hex(0x8a6a44), hex(0xc8bca0)] as RGB[],
};

function paintDeadWood(b: MeshBuilder, m: Mark, seed: number, H: number, barkLoss: number, moss: number): void {
  const n3 = createNoise3D(subSeed(seed, 800));
  const bark = SNAG_PALETTE.bark[Math.abs(seed) % 3]!;
  const grey = SNAG_PALETTE.weathered[Math.abs(seed >> 2) % 3]!;
  b.paint(m, (p, n) => {
    let c = mix(bark, grey, smoothstep(-0.3, 0.5, n3(p.x * 0.8, p.y * 0.4, p.z * 0.8)));
    // bark sloughs off in vertical sheets exposing silver-grey wood
    const loss = smoothstep(0.45 - barkLoss * 0.7, 0.55 - barkLoss * 0.7, n3(p.x * 2.2, p.y * 0.35, p.z * 2.2) * 0.8 + n3(p.x * 7, p.y * 1.2, p.z * 7) * 0.2);
    c = mix(c, SNAG_PALETTE.silver, loss * 0.85);
    // lichen speckle and moss on the shaded lower trunk and upper faces
    c = mix(c, SNAG_PALETTE.lichen, smoothstep(0.55, 0.75, n3(p.x * 9, p.y * 9, p.z * 9)) * 0.5);
    const m2 = moss * (smoothstep(H * 0.25, 0, p.y) * 0.8 + smoothstep(0.4, 0.9, n.y) * 0.6) * smoothstep(-0.2, 0.3, n3(p.x * 4, p.y * 4, p.z * 4));
    c = mix(c, SNAG_PALETTE.moss, clamp01(m2));
    const ao = 0.5 + 0.5 * smoothstep(0, 0.4, p.y);
    return mul(c, ao);
  });
}

interface Branch { path: Vec3[]; r0: number; r1: number; level: number; }

function grow(rnd: Rnd, start: Vec3, dir: Vec3, len: number, r0: number, level: number, maxLevel: number, out: Branch[], segsFor: (l: number) => number, gravity: number): void {
  const segs = segsFor(level);
  const pts = [start.clone()];
  const d = dir.clone().normalize();
  const p = start.clone();
  for (let i = 1; i <= segs; i++) {
    const wob = level === 0 ? 0.05 : 0.18;
    d.add(v3(gauss(rnd) * wob, (level === 0 ? 0 : -gravity * 0.1) + gauss(rnd) * 0.06, gauss(rnd) * wob)).normalize();
    p.addScaledVector(d, len / segs);
    pts.push(p.clone());
  }
  const broken = level > 0 && chance(rnd, 0.35);
  const r1 = broken ? r0 * 0.55 : r0 * 0.2;
  out.push({ path: pts, r0, r1, level });
  if (level >= maxLevel) return;
  const kids = level === 0 ? irange(rnd, 5, 8) : level === 1 ? irange(rnd, 3, 5) : irange(rnd, 2, 3);
  for (let k = 0; k < kids; k++) {
    const t = level === 0 ? range(rnd, 0.45, 0.92) : range(rnd, 0.3, 0.85);
    const idx = Math.min(pts.length - 2, Math.max(1, Math.round(t * segs)));
    const at = pts[idx]!;
    const tan = v3().subVectors(pts[idx + 1]!, pts[idx - 1]!).normalize();
    const side = perpendicular(tan).applyAxisAngle(tan, rnd() * Math.PI * 2);
    const ang = range(rnd, 0.5, 1.1);
    const nd = tan.clone().multiplyScalar(Math.cos(ang)).addScaledVector(side, Math.sin(ang)).add(v3(0, level === 0 ? 0.25 : 0, 0)).normalize();
    const rr = Math.max(0.006, (r0 + (r1 - r0) * t) * range(rnd, 0.45, 0.65));
    const kl = len * range(rnd, 0.35, 0.6) * (chance(rnd, 0.25) ? 0.25 : 1); // some snapped short
    grow(rnd, at, nd, kl, rr, level + 1, maxLevel, out, segsFor, gravity);
  }
}

export interface DeadTreeOptions { height?: number; }

/** Standing dead tree with bare, partly broken branching crown. */
export function deadTree(seed: number, lod: LOD, opts: DeadTreeOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 7000);
  const H = opts.height ?? range(rnd, 8, 16);
  const r0 = H * range(rnd, 0.022, 0.032);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const branches: Branch[] = [];
  const maxLevel = lod === 0 ? 3 : lod === 1 ? 2 : 1;
  const segsFor = (l: number): number => (lod === 0 ? [12, 6, 4, 2][l]! : lod === 1 ? [6, 3, 2][l]! : [3, 1][l]!);
  grow(rnd, v3(0, 0, 0), v3(gauss(rnd) * 0.04, 1, gauss(rnd) * 0.04), H * 0.75, r0, 0, maxLevel, branches, segsFor, range(rnd, -0.3, 0.6));
  const radialFor = (l: number): number => (lod === 0 ? [10, 6, 4, 3][l]! : lod === 1 ? [6, 4, 3][l]! : [4, 3][l]!);
  branches.sort((a, c) => a.level - c.level);
  const m0 = b.mark();
  const n3 = createNoise3D(subSeed(seed, 7001));
  for (const br of branches) {
    const ok = withinBudget(b, budget, () => {
      tube(b, br.path, {
        radial: radialFor(br.level),
        radius: (t) => {
          let r = br.r0 + (br.r1 - br.r0) * t;
          if (br.level === 0) r *= 1 + 0.7 * Math.exp(-t * H / 0.6); // root flare
          return r;
        },
        radialNoise: br.level === 0 ? (t, a) => 1 + 0.18 * Math.exp(-t * H / 0.8) * Math.pow(Math.abs(Math.cos(a * 2.5 + seed)), 3) + 0.03 * n3(Math.cos(a) * 2, t * 20, Math.sin(a) * 2) : undefined,
        capEnd: br.level === 0 || br.r1 > 0.03,
        vScale: 1 / Math.max(0.05, br.r0 * 6),
      });
    });
    if (!ok && br.level <= 1) continue;
  }
  paintDeadWood(b, m0, seed, H, range(rnd, 0.3, 0.8), range(rnd, 0.2, 0.7));
  b.setSway(m0, (p) => (p.y / H) * 0.35);
  const g = b.build();
  return { geometry: g, material: woodMaterial(), collider: { type: 'cylinder', center: [0, H * 0.4, 0], radius: r0 * 1.3, halfHeight: H * 0.4 } };
}

/** Broken-topped snag 3 to 9 m with stubs and woodpecker holes. */
export function snag(seed: number, lod: LOD): AssetResult {
  const rnd = makeRnd(seed, 7100);
  const H = range(rnd, 3, 9), r0 = range(rnd, 0.18, 0.4);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const segs = lod === 0 ? 16 : lod === 1 ? 6 : 3, radial = lod === 0 ? 12 : lod === 1 ? 7 : 5;
  const pts: Vec3[] = [];
  const d = v3(gauss(rnd) * 0.05, 1, gauss(rnd) * 0.05);
  for (let i = 0; i <= segs; i++) { const t = i / segs; pts.push(v3(d.x * H * t + Math.sin(t * 4) * 0.05, H * t, d.z * H * t)); }
  const n3 = createNoise3D(subSeed(seed, 7101));
  const m = tube(b, pts, {
    radial, radius: (t) => r0 * (1 - t * 0.3) * (1 + 0.6 * Math.exp(-t * H / 0.5)),
    radialNoise: (t, a) => 1 + 0.15 * Math.exp(-t * H / 0.7) * Math.pow(Math.abs(Math.cos(a * 2 + seed)), 3) + 0.04 * n3(Math.cos(a) * 2, t * 12, Math.sin(a) * 2),
    vScale: 1 / (r0 * 5),
  });
  // jagged broken top: displace last ring and add a spiky splinter cap
  const top = m.v + segs * (radial + 1);
  const p = v3();
  for (let j = 0; j <= radial; j++) { b.getP(top + j, p); p.y += (j % radial === 0 ? 0 : range(rnd, -0.25, 0.35)) * r0 * 2.5; b.setP(top + j, p); }
  const c = b.vert(v3(pts[segs]!.x, H - r0 * 0.4, pts[segs]!.z), UP, 0.5, 0, [1, 1, 1]);
  for (let j = 0; j < radial; j++) b.tri(top + j + 1, top + j, c);
  b.smoothNormals(m);
  paintDeadWood(b, m, seed, H, range(rnd, 0.4, 0.9), range(rnd, 0.3, 0.8));
  // the broken top and splinters are pale, punky heartwood
  b.paint({ v: top, i: 0 }, (q) => mul(SNAG_PALETTE.silver, 0.6 + 0.3 * clamp01((q.y - H + r0) / r0)));
  // stubs
  const stubs = lod === 0 ? irange(rnd, 3, 7) : lod === 1 ? 2 : 0;
  for (let i = 0; i < stubs; i++) {
    withinBudget(b, budget, () => {
      const t = range(rnd, 0.3, 0.9), a = rnd() * Math.PI * 2;
      const at = v3(d.x * H * t, H * t, d.z * H * t);
      const dir = v3(Math.cos(a), range(rnd, 0, 0.6), Math.sin(a)).normalize();
      const sm = tube(b, [at, at.clone().addScaledVector(dir, range(rnd, 0.2, 0.7))], { radial: lod === 0 ? 5 : 3, radius: (tt) => r0 * range(rnd, 0.2, 0.35) * (1 - tt * 0.4), capEnd: true });
      paintDeadWood(b, sm, seed + i, H, 0.8, 0.2);
    });
  }
  // woodpecker holes: dark recessed discs
  if (lod === 0) for (let i = 0; i < irange(rnd, 1, 5); i++) {
    const t = range(rnd, 0.35, 0.85), a = rnd() * Math.PI * 2;
    const rr = r0 * (1 - t * 0.3) * 1.01;
    const cpos = v3(d.x * H * t + Math.cos(a) * rr, H * t, d.z * H * t + Math.sin(a) * rr);
    const nrm = v3(Math.cos(a), 0, Math.sin(a));
    const tan = v3(-Math.sin(a), 0, Math.cos(a));
    const hm = b.mark();
    const hr = range(rnd, 0.025, 0.05);
    const cc = b.vert(cpos.clone().addScaledVector(nrm, -0.01), nrm, 0.5, 0.5, SNAG_PALETTE.punk);
    for (let k = 0; k < 6; k++) {
      const an = (k / 6) * Math.PI * 2;
      b.vert(cpos.clone().addScaledVector(tan, Math.cos(an) * hr).add(v3(0, Math.sin(an) * hr * 1.2, 0)), nrm, 0.5, 0.5, mul(SNAG_PALETTE.punk, 0.6));
    }
    for (let k = 0; k < 6; k++) b.tri(cc, hm.v + 1 + k, hm.v + 1 + ((k + 1) % 6));
  }
  b.setSway({ v: 0, i: 0 }, (q) => (q.y / H) * 0.2);
  const g = b.build();
  return { geometry: g, material: woodMaterial(), collider: { type: 'cylinder', center: [0, H / 2, 0], radius: r0, halfHeight: H / 2 } };
}

/** Hollow, rotting stump with jagged rim, root flare, moss and bracket fungi. */
export function hollowStump(seed: number, lod: LOD): AssetResult {
  const rnd = makeRnd(seed, 7200);
  const H = range(rnd, 0.35, 1.2), R = range(rnd, 0.28, 0.6), wall = range(rnd, 0.06, 0.14);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const radial = lod === 0 ? 20 : lod === 1 ? 10 : 6, rows = lod === 0 ? 6 : lod === 1 ? 3 : 1;
  const n3 = createNoise3D(subSeed(seed, 7201));
  const rim = (a: number): number => H * (1 + 0.35 * n3(Math.cos(a) * 1.5, 3, Math.sin(a) * 1.5) + (lod === 0 ? 0.12 * Math.max(0, n3(Math.cos(a) * 6, 1, Math.sin(a) * 6)) : 0));
  const outerR = (a: number, y: number): number => R * (1 + 0.5 * Math.exp(-y / 0.18) * Math.pow(Math.abs(Math.cos(a * 2.5 + seed)), 2) + 0.06 * n3(Math.cos(a) * 3, y * 4, Math.sin(a) * 3));
  const m = b.mark();
  // outer wall rows from ground to rim, then inner wall down to the floor
  const ring = (k: number): void => {
    for (let j = 0; j <= radial; j++) {
      const a = (j / radial) * Math.PI * 2;
      let p: Vec3;
      if (k <= rows) { const y = (k / rows) * rim(a); const r = outerR(a, y); p = v3(Math.cos(a) * r, y, Math.sin(a) * r); }
      else { const f = (k - rows - 1) / Math.max(1, rows); const y = rim(a) * (1 - f) * 0.98 + 0.08 * f; const r = (R - wall) * (1 + 0.08 * n3(Math.cos(a) * 3, y * 4 + 9, Math.sin(a) * 3)); p = v3(Math.cos(a) * r, y, Math.sin(a) * r); }
      b.vert(p, UP, j / radial, p.y * 2, [1, 1, 1]);
    }
  };
  const nRings = rows + 1 + (rows + 1);
  for (let k = 0; k < nRings; k++) ring(k);
  const row = radial + 1;
  for (let k = 0; k < nRings - 1; k++)
    for (let j = 0; j < radial; j++) {
      const a = m.v + k * row + j;
      b.quad(a, a + row, a + row + 1, a + 1);
    }
  // floor
  const fc = b.vert(v3(0, 0.06, 0), UP, 0.5, 0, [1, 1, 1]);
  const last = m.v + (nRings - 1) * row;
  for (let j = 0; j < radial; j++) b.tri(last + j, last + j + 1, fc);
  b.smoothNormals(m);
  paintDeadWood(b, m, seed, H, 0.6, range(rnd, 0.4, 1));
  // inside and rim: dark punky rot
  b.paint({ v: m.v + (rows + 1) * row, i: 0 }, (p) => mul(mix(SNAG_PALETTE.rot, SNAG_PALETTE.punk, 1 - clamp01(p.y / H)), 0.5 + 0.5 * clamp01(p.y / H)));
  // bracket fungi
  if (lod < 2) for (let i = 0; i < irange(rnd, 0, lod === 0 ? 5 : 2); i++) {
    withinBudget(b, budget, () => {
      const a = rnd() * Math.PI * 2, y = range(rnd, 0.1, 0.8) * H;
      const r = outerR(a, y);
      const s = range(rnd, 0.05, 0.12);
      const fm = blob(b, lod === 0 ? 2 : 1, v3(Math.cos(a) * (r + s * 0.3), y, Math.sin(a) * (r + s * 0.3)), v3(s, s * 0.22, s), undefined, 0);
      const fc2 = pick(rnd, SNAG_PALETTE.fungus);
      b.paint(fm, (_p, n) => mul(fc2, n.y > 0 ? 1 : 0.6));
    });
  }
  b.boxUV({ v: 0, i: 0 }, 2);
  const g = b.build();
  return { geometry: g, material: woodMaterial(), collider: { type: 'cylinder', center: [0, H / 2, 0], radius: R * 1.1, halfHeight: H / 2 } };
}

// ---------------------------------------------------------------- rock outcrop

export interface OutcropOptions { size?: number; style?: StoneStyle; }

/** Stratified rock outcrop (3 to 6 lumps) partly buried, with ledges, moss on
 *  tops and streaking under ledges. Origin at ground level. */
export function rockOutcrop(seed: number, lod: LOD, opts: OutcropOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 7300);
  const S = opts.size ?? range(rnd, 1.5, 5);
  const style = opts.style ?? (chance(rnd, 0.6) ? STONE_STYLES.limestone : STONE_STYLES.fieldstone);
  const b = new MeshBuilder();
  const n3 = createNoise3D(subSeed(seed, 7301));
  const layer = range(rnd, 0.18, 0.4) * (S / 3);
  const dip = gauss(rnd) * 0.12;
  const lumps = lod === 2 ? 2 : irange(rnd, 3, 6);
  const sub = lod === 0 ? Math.max(5, Math.min(11, Math.floor(Math.sqrt(5800 / (12 * lumps))))) : lod === 1 ? Math.max(3, Math.floor(Math.sqrt(1150 / (12 * lumps)))) : 3;
  for (let i = 0; i < lumps; i++) {
    const a = (i / lumps) * Math.PI * 2 + gauss(rnd) * 0.5;
    const d = i === 0 ? 0 : range(rnd, 0.3, 0.6) * S;
    const sz = v3(range(rnd, 0.5, 0.8) * S, range(rnd, 0.35, 0.6) * S, range(rnd, 0.4, 0.7) * S).multiplyScalar(i === 0 ? 1 : 0.7);
    const c = v3(Math.cos(a) * d, sz.y * 0.25, Math.sin(a) * d);
    const m = blob(b, sub, c, sz.clone().multiplyScalar(0.5), (dir) => {
      const base = 1 + n3(dir.x * 1.4 + i, dir.y * 1.4, dir.z * 1.4) * 0.28 + n3(dir.x * 4, dir.y * 4, dir.z * 4 + i) * 0.08;
      // stratification: stepped ledges along (slightly dipping) bedding planes
      const yy = c.y + dir.y * sz.y * 0.5 + dir.x * dip * S;
      const f = ((yy / layer) % 1 + 1) % 1;
      return base * (1 - 0.12 * smoothstep(0.0, 0.35, f) + 0.12 * smoothstep(0.8, 1, f));
    }, 0.25);
    if (b.triangleCount > TRI_BUDGET[lod] - 4) { b.rollback(m); break; }
    paintStone(b, m, style, seed + i, { height: S * 0.6, age: 1.3, baseColor: mul(pick(rnd, style.base), range(rnd, 0.9, 1.08)) });
    // per-bed tint banding
    const bed = createNoise3D(subSeed(seed, 7302 + i));
    for (let k = m.v; k < b.vertexCount; k++) {
      const p = b.getP(k, v3());
      const band = 0.88 + 0.22 * bed(0, Math.floor((p.y + p.x * dip * S) / layer) * 1.7 + 0.5, 0);
      b.setC(k, mul(b.getC(k), band));
    }
  }
  b.boxUV({ v: 0, i: 0 }, 1);
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g, 0.85) };
}
