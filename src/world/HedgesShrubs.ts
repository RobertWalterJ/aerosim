// Hedges and shrubs: clipped boxwood and yew hedges, lilac, forsythia,
// boxwood balls and spreading yew mounds. Dense rounded forms built from a
// dark inner core (stops see-through) plus leaf-cluster cards whose normals
// follow the overall volume, so the mass shades as one soft form.
//
// Wind: aSway = height above ground / plant height, scaled down near the
// core (clipped hedges barely move; forsythia canes use arc length).
import * as THREE from 'three';
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3,
  v3, UP, hex, mix, tint, mul, clamp01, smoothstep, card, blob, tube, perpendicular, boxColliderOf,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, chance, createNoise3D, subSeed, type Rnd } from './assetkit/AssetRng';
import { Cell, cellUV, solidUV, type CellId } from './textures/AssetTextures';
import { foliageMaterial } from './assetkit/AssetMaterials';

export const SHRUB_PALETTE = {
  boxwood: [hex(0x4c602e), hex(0x42572a), hex(0x57693a), hex(0x4f6430)] as RGB[],
  boxwoodBronze: [hex(0x7a6a38), hex(0x857040)] as RGB[],
  yew: [hex(0x3a4e2e), hex(0x405432), hex(0x36492c)] as RGB[],
  yewNew: hex(0x56683a),
  yewDead: hex(0x5e4e34),
  lilac: [hex(0x55643a), hex(0x5f6c3c), hex(0x4c5a34), hex(0x8a8244), hex(0x6e5c3a)] as RGB[],
  forsythia: [hex(0x6b6a36), hex(0x7a5c3c), hex(0x6a4240), hex(0x8a8242), hex(0x9a8a40)] as RGB[],
  bark: [hex(0x6a6052), hex(0x5a5246), hex(0x7a6e5e)] as RGB[],
  core: hex(0x1f2a17),
};

interface CardSpec { cell: CellId; size: [number, number]; palette: RGB[]; }

/** Place a leaf-cluster card at p with outward volume normal n. */
function leafCluster(b: MeshBuilder, rnd: Rnd, p: Vec3, n: Vec3, size: number, cell: CellId, col: RGB, sway: number, tiltMax = 0.6): void {
  const t = perpendicular(n);
  t.applyAxisAngle(n, rnd() * Math.PI * 2);
  const vAxis = v3().crossVectors(n, t).normalize();
  // tilt the card out of the tangent plane so clusters stick out
  const q = new THREE.Quaternion().setFromAxisAngle(t, gauss(rnd) * tiltMax);
  vAxis.applyQuaternion(q);
  const nn = n.clone().lerp(UP, 0.2).normalize();
  card(b, p, t, vAxis, size, size, { uv: cellUV(cell), color: col, sway: [sway, sway], pivot: 'center', normal: nn });
}

// ---------------------------------------------------------------- hedges

export type HedgeType = 'boxwood' | 'yew';
export interface HedgeOptions {
  type?: HedgeType;
  /** along +X, meters. default 2 */
  length?: number;
  height?: number;
  width?: number;
  /** close the hedge ends; use 'none' when chaining segments. default 'both' */
  caps?: 'both' | 'none' | 'start' | 'end';
}

/** Clipped formal hedge segment centered on the origin, running along X. */
export function hedge(seed: number, lod: LOD, opts: HedgeOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 3000);
  const noise = createNoise3D(subSeed(seed, 3001));
  const type: HedgeType = opts.type ?? (Math.abs(seed) % 2 === 0 ? 'boxwood' : 'yew');
  const box = type === 'boxwood';
  const L = opts.length ?? 2;
  const H = opts.height ?? (box ? range(rnd, 0.5, 0.9) : range(rnd, 1.3, 2.0));
  const W = opts.width ?? (box ? range(rnd, 0.45, 0.7) : range(rnd, 0.8, 1.2));
  const caps = opts.caps ?? 'both';
  const capH = box ? W * range(rnd, 0.35, 0.5) : W * range(rnd, 0.15, 0.25);
  const e = box ? range(rnd, 2.2, 3) : range(rnd, 3.5, 5);
  const batter = box ? 0.04 : range(rnd, 0.04, 0.1);
  const y0 = H - capH;
  const per = 2 * y0 + Math.PI * (W / 2 + capH) / 2;
  const a = y0 / per;
  const R = Math.min(0.15, W * 0.3);
  const capStart = caps === 'both' || caps === 'start', capEnd = caps === 'both' || caps === 'end';

  // surface: u in [0,1] along X, s in [0,1] around the section
  const S = (u: number, s: number, inset = 0): Vec3 => {
    let y: number, z: number;
    if (s < a) { y = (s / a) * y0; z = (W / 2) * (1 + batter * (1 - y / H)); }
    else if (s > 1 - a) { y = ((1 - s) / a) * y0; z = -(W / 2) * (1 + batter * (1 - y / H)); }
    else {
      const phi = (Math.PI * (s - a)) / (1 - 2 * a), c = Math.cos(phi), sn = Math.sin(phi);
      z = (W / 2) * Math.sign(c) * Math.pow(Math.abs(c), 2 / e);
      y = y0 + capH * Math.pow(Math.abs(sn), 2 / e);
    }
    const x = (u - 0.5) * L;
    // round the vertical corners at capped ends
    let k = 1;
    const ds = x + L / 2, de = L / 2 - x;
    if (capStart && ds < R) k = Math.sqrt(Math.max(0, 1 - Math.pow((R - ds) / R, 2)));
    if (capEnd && de < R) k = Math.min(k, Math.sqrt(Math.max(0, 1 - Math.pow((R - de) / R, 2))));
    z *= 0.75 + 0.25 * k;
    const wob = noise(x * 1.8, y * 1.8, z * 1.8) * 0.025 + noise(x * 5, y * 5, z * 5) * 0.01;
    const p = v3(x, y, z);
    const dir = v3(0, y - y0 * 0.5, z).normalize();
    return p.addScaledVector(dir, wob - inset);
  };
  const normalAt = (u: number, s: number): Vec3 => {
    const du = 1e-3, ds = 1e-3;
    const pu = v3().subVectors(S(Math.min(1, u + du), s), S(Math.max(0, u - du), s));
    const ps = v3().subVectors(S(u, Math.min(1, s + ds)), S(u, Math.max(0, s - ds)));
    const n = v3().crossVectors(pu, ps).normalize();
    return n.lengthSq() > 0 ? n : v3(0, 1, 0);
  };

  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const pal = box ? SHRUB_PALETTE.boxwood : SHRUB_PALETTE.yew;
  const leafColor = (p: Vec3): RGB => {
    let c = tint(pick(rnd, pal), range(rnd, 0.82, 1.12));
    const patch = noise(p.x * 0.9 + 11, p.y * 0.9, p.z * 0.9);
    if (box && patch > 0.25) c = mix(c, pick(rnd, SHRUB_PALETTE.boxwoodBronze), smoothstep(0.25, 0.6, patch) * 0.8);
    if (!box && p.y > H * 0.8 && chance(rnd, 0.35)) c = mix(c, SHRUB_PALETTE.yewNew, 0.6);
    if (!box && patch > 0.55) c = mix(c, SHRUB_PALETTE.yewDead, 0.6);
    return c;
  };
  const ao = (p: Vec3, depth: number): number => (0.5 + 0.5 * smoothstep(-0.05, H * 0.7, p.y)) * (1 - depth * 6);

  // core
  const nu = lod === 0 ? Math.max(4, Math.round(L * 4)) : lod === 1 ? Math.max(2, Math.round(L * 2)) : Math.max(2, Math.round(L * 1.5));
  const ns = lod === 0 ? 12 : lod === 1 ? 8 : 6;
  const coreInset = lod === 2 ? 0 : 0.06;
  const m0 = b.mark();
  for (let i = 0; i <= nu; i++) for (let j = 0; j <= ns; j++) {
    const p = S(i / nu, j / ns, coreInset);
    b.vert(p, normalAt(i / nu, j / ns), 0.5, 0.5, [1, 1, 1], 0);
  }
  for (let i = 0; i < nu; i++) for (let j = 0; j < ns; j++) {
    const q = m0.v + i * (ns + 1) + j;
    b.quad(q, q + ns + 1, q + ns + 2, q + 1);
  }
  const endFace = (u: number, sign: number): void => {
    const c = b.vert(v3((u - 0.5) * L - sign * 0.0, H * 0.45, 0), v3(sign, 0, 0), 0.5, 0.5, [1, 1, 1], 0);
    for (let j = 0; j < ns; j++) {
      const q = m0.v + Math.round(u * nu) * (ns + 1) + j;
      if (sign < 0) b.tri(c, q, q + 1); else b.tri(c, q + 1, q);
    }
  };
  if (capStart) endFace(0, -1);
  if (capEnd) endFace(1, 1);
  const solid = solidUV();
  b.paint(m0, (p) => (lod === 2 ? mul(leafColor(p), ao(p, 0) * 0.85) : mul(SHRUB_PALETTE.core, ao(p, 0))));
  for (let k = m0.v; k < b.vertexCount; k++) { b.uvs[k * 2] = solid.u0; b.uvs[k * 2 + 1] = (solid.v0 + solid.v1) / 2; }
  b.setSway(m0, (p) => (p.y / H) * 0.15);

  // leaf-cluster cards
  const coreTris = b.triangleCount;
  const area = per * L + (capStart ? W * H * 0.9 : 0) + (capEnd ? W * H * 0.9 : 0);
  const baseSize = box ? range(rnd, 0.11, 0.15) : range(rnd, 0.15, 0.2);
  const want = Math.round((2.6 * area) / (0.55 * baseSize * baseSize));
  const maxCards = Math.floor((budget - coreTris) / 2);
  const N = lod === 2 ? Math.min(maxCards, 40) : Math.min(want, maxCards);
  const size = lod === 2 ? baseSize * 3 : baseSize * Math.max(1, Math.sqrt(want / Math.max(1, N)) * 0.85);
  const cell = box ? Cell.Boxwood : Cell.Yew;
  const endShare = ((capStart ? 1 : 0) + (capEnd ? 1 : 0)) * W * H * 0.9 / area;
  for (let i = 0; i < N; i++) {
    let p: Vec3, n: Vec3;
    if (rnd() < endShare) {
      const end = capStart && (!capEnd || rnd() < 0.5) ? 0 : 1;
      const s = rnd(), r = Math.sqrt(rnd());
      const edge = S(end, s);
      const center = v3((end - 0.5) * L, H * 0.45, 0);
      p = center.lerp(edge, r * 0.97);
      n = v3(end === 0 ? -1 : 1, 0, 0).lerp(normalAt(end, s), r * r * 0.6).normalize();
    } else {
      const u = rnd(), s = rnd();
      p = S(u, s);
      n = normalAt(u, s);
    }
    const off = range(rnd, -0.03, box ? 0.015 : 0.02);
    p.addScaledVector(n, off);
    p.y = Math.max(p.y, size * 0.5);
    const depth = clamp01(-off);
    const col = mul(leafColor(p), ao(p, depth));
    leafCluster(b, rnd, p, n, size * range(rnd, 0.8, 1.2), cell, col, (p.y / H) * 0.25, box ? 0.45 : 0.35);
  }
  const g = b.build();
  return { geometry: g, material: foliageMaterial(), collider: boxColliderOf(g, 0.95) };
}

// ---------------------------------------------------------------- shrubs

export type ShrubType = 'lilac' | 'forsythia' | 'boxwoodBall' | 'yewMound';
export const SHRUB_TYPES: readonly ShrubType[] = ['lilac', 'forsythia', 'boxwoodBall', 'yewMound'];

interface Lump { c: Vec3; r: Vec3; }

function insideOther(p: Vec3, lumps: Lump[], self: number, k: number): boolean {
  for (let i = 0; i < lumps.length; i++) {
    if (i === self) continue;
    const l = lumps[i]!;
    const dx = (p.x - l.c.x) / l.r.x, dy = (p.y - l.c.y) / l.r.y, dz = (p.z - l.c.z) / l.r.z;
    if (dx * dx + dy * dy + dz * dz < k * k) return true;
  }
  return false;
}

function lumpyShrub(b: MeshBuilder, rnd: Rnd, lod: LOD, lumps: Lump[], H: number, spec: CardSpec, layers: number, offset: [number, number], noiseSeed: number): void {
  const noise = createNoise3D(noiseSeed);
  const budget = TRI_BUDGET[lod] - 4;
  const solid = solidUV();
  // dark cores
  for (const l of lumps) {
    const m = blob(b, lod === 0 ? 3 : 2, l.c, l.r.clone().multiplyScalar(lod === 2 ? 0.95 : 0.72), (d) => 1 + noise(d.x * 2 + l.c.x, d.y * 2, d.z * 2) * 0.18, 0);
    if (b.triangleCount > budget * 0.6) { b.rollback(m); continue; }
    b.paint(m, (p) => {
      const base = lod === 2 ? mul(pick(rnd, spec.palette), 0.8) : SHRUB_PALETTE.core;
      return mul(base, 0.45 + 0.55 * smoothstep(0, H * 0.8, p.y));
    });
    for (let k = m.v; k < b.vertexCount; k++) { b.uvs[k * 2] = solid.u0; b.uvs[k * 2 + 1] = (solid.v0 + solid.v1) / 2; }
    b.setSway(m, (p) => (p.y / H) * 0.3);
  }
  let area = 0;
  for (const l of lumps) area += 4 * Math.PI * Math.pow((l.r.x * l.r.y + l.r.y * l.r.z + l.r.x * l.r.z) / 3, 1) * 0.7;
  const base = range(rnd, spec.size[0], spec.size[1]);
  const want = Math.round((layers * area) / (0.5 * base * base));
  const maxCards = Math.floor((budget - b.triangleCount) / 2);
  const N = lod === 2 ? Math.min(maxCards, 30) : Math.min(want, maxCards);
  const size = lod === 2 ? base * 2.6 : base * Math.max(1, Math.sqrt(want / Math.max(1, N)) * 0.85);
  const weights = lumps.map((l) => l.r.x * l.r.y + l.r.y * l.r.z + l.r.x * l.r.z);
  const wsum = weights.reduce((x, y) => x + y, 0);
  let placed = 0, tries = 0;
  while (placed < N && tries < N * 4) {
    tries++;
    let x = rnd() * wsum, li = 0;
    while (li < lumps.length - 1 && x > weights[li]!) { x -= weights[li]!; li++; }
    const l = lumps[li]!;
    const d = v3(gauss(rnd), gauss(rnd), gauss(rnd)).normalize();
    const k = range(rnd, offset[0], offset[1]);
    const p = v3(l.c.x + d.x * l.r.x * k, l.c.y + d.y * l.r.y * k, l.c.z + d.z * l.r.z * k);
    if (p.y < 0.04) continue;
    if (insideOther(p, lumps, li, 0.92)) continue;
    const n = v3(d.x / l.r.x, d.y / l.r.y, d.z / l.r.z).normalize();
    const shade = (0.5 + 0.5 * smoothstep(0, H * 0.75, p.y)) * (0.72 + 0.28 * smoothstep(0.75, 1.05, k));
    leafCluster(b, rnd, p, n, size * range(rnd, 0.8, 1.2), spec.cell, mul(tint(pick(rnd, spec.palette), range(rnd, 0.85, 1.12)), shade), clamp01(p.y / H), 0.7);
    placed++;
  }
}

function barkStem(b: MeshBuilder, rnd: Rnd, lod: LOD, path: Vec3[], r0: number, H: number): void {
  if (lod === 2) return;
  const m = tube(b, path, { radial: lod === 0 ? 5 : 3, radius: (t) => r0 * (1 - t * 0.6) });
  const c = pick(rnd, SHRUB_PALETTE.bark);
  b.paint(m, (p) => mul(c, 0.45 + 0.55 * smoothstep(0, H * 0.6, p.y)));
  const s = solidUV();
  for (let k = m.v; k < b.vertexCount; k++) { b.uvs[k * 2] = s.u0; b.uvs[k * 2 + 1] = (s.v0 + s.v1) / 2; }
  b.setSway(m, (p) => p.y / H);
}

export interface ShrubOptions { type?: ShrubType; height?: number; }

/** Free-standing shrub at the origin. type defaults from seed (4 types),
 *  and every seed varies proportions, lumps and color. */
export function shrub(seed: number, lod: LOD, opts: ShrubOptions = {}): AssetResult {
  const type = opts.type ?? SHRUB_TYPES[Math.abs(seed) % SHRUB_TYPES.length]!;
  const rnd = makeRnd(seed, 3100 + SHRUB_TYPES.indexOf(type));
  const b = new MeshBuilder();
  const ns = subSeed(seed, 3101);
  let H: number;
  if (type === 'lilac') {
    H = opts.height ?? range(rnd, 2.0, 3.4);
    const nStems = irange(rnd, 5, 9);
    const lumps: Lump[] = [];
    const nl = irange(rnd, 5, 8);
    const spread = range(rnd, 0.28, 0.42) * H;
    for (let i = 0; i < nl; i++) {
      const a = (i / nl) * Math.PI * 2 + gauss(rnd) * 0.5, d = i === 0 ? 0 : range(rnd, 0.4, 1) * spread;
      const hgt = range(rnd, 0.42, 0.78) * H;
      const r = range(rnd, 0.24, 0.34) * H * (1 - 0.3 * (d / spread));
      lumps.push({ c: v3(Math.cos(a) * d, hgt, Math.sin(a) * d), r: v3(r * 1.05, Math.min(r * range(rnd, 0.9, 1.2), hgt - 0.25), r * 1.05) });
    }
    // top-most lump makes the crown irregular
    lumps.push({ c: v3(gauss(rnd) * 0.2, H * 0.82, gauss(rnd) * 0.2), r: v3(H * 0.2, H * 0.18, H * 0.2) });
    for (let i = 0; i < nStems; i++) {
      const tgt = lumps[i % lumps.length]!.c;
      const st = v3(gauss(rnd) * 0.12, 0, gauss(rnd) * 0.12);
      const mid = st.clone().lerp(tgt, 0.5).add(v3(gauss(rnd) * 0.1, 0, gauss(rnd) * 0.1));
      barkStem(b, rnd, lod, [st, mid, tgt.clone()], range(rnd, 0.018, 0.035), H);
    }
    lumpyShrub(b, rnd, lod, lumps, H, { cell: Cell.Lilac, size: [0.3, 0.4], palette: SHRUB_PALETTE.lilac }, 2.8, [0.78, 1.05], ns);
  } else if (type === 'forsythia') {
    H = opts.height ?? range(rnd, 1.5, 2.4);
    const canes = lod === 0 ? irange(rnd, 16, 24) : lod === 1 ? irange(rnd, 8, 12) : 0;
    const budget = TRI_BUDGET[lod] - 4;
    // low dense core so the fountain doesn't read as transparent
    const lumps: Lump[] = [{ c: v3(0, H * 0.48, 0), r: v3(H * 0.6, H * 0.45, H * 0.6) }, { c: v3(gauss(rnd) * 0.2, H * 0.7, gauss(rnd) * 0.2), r: v3(H * 0.35, H * 0.3, H * 0.35) }];
    lumpyShrub(b, rnd, lod, lumps, H, { cell: Cell.Forsythia, size: [0.22, 0.3], palette: SHRUB_PALETTE.forsythia }, lod === 2 ? 1.5 : 1.4, [0.82, 1.05], ns);
    const sUV = solidUV();
    for (let i = 0; i < canes; i++) {
      const m = b.mark();
      const az = rnd() * Math.PI * 2;
      const len = range(rnd, 1.4, 2.6) * (H / 2);
      const segs = lod === 0 ? 8 : 4;
      const pts: Vec3[] = [v3(gauss(rnd) * 0.12, 0, gauss(rnd) * 0.12)];
      const p = pts[0]!.clone();
      const t0 = range(rnd, 0.05, 0.45), t1 = range(rnd, 1.6, 2.4);
      for (let k = 1; k <= segs; k++) {
        const t = (k - 0.5) / segs, tilt = t0 + (t1 - t0) * Math.pow(t, 1.4);
        p.x += Math.sin(tilt) * Math.cos(az) * (len / segs); p.y += Math.cos(tilt) * (len / segs); p.z += Math.sin(tilt) * Math.sin(az) * (len / segs);
        pts.push(p.clone());
      }
      if (lod === 0) {
        const tm = tube(b, pts, { radial: 3, radius: (t) => 0.008 * (1 - t * 0.6) });
        const c = mul(pick(rnd, SHRUB_PALETTE.bark), 0.6);
        b.paint(tm, (q) => mul(c, 0.6 + 0.4 * smoothstep(0, H, q.y)));
        for (let k = tm.v; k < b.vertexCount; k++) { b.uvs[k * 2] = sUV.u0; b.uvs[k * 2 + 1] = (sUV.v0 + sUV.v1) / 2; }
      }
      const nLeaves = lod === 0 ? irange(rnd, 14, 22) : 7;
      for (let k = 0; k < nLeaves; k++) {
        const f = Math.sqrt(range(rnd, 0.1, 1));
        const idx = f * segs, i0 = Math.floor(idx), i1 = Math.min(segs, i0 + 1);
        const q = pts[i0]!.clone().lerp(pts[i1]!, idx - i0);
        const tan = v3().subVectors(pts[i1]!, pts[i0]!).normalize();
        const outN = v3(Math.cos(az), 0.6, Math.sin(az)).normalize();
        const side = v3().crossVectors(tan, outN).normalize();
        const sz = range(rnd, 0.2, 0.3) * (lod === 0 ? 1 : 1.4);
        card(b, q, side, tan.clone().applyAxisAngle(outN, gauss(rnd) * 0.8), sz, sz, {
          uv: cellUV(Cell.Forsythia), color: mul(tint(pick(rnd, SHRUB_PALETTE.forsythia), range(rnd, 0.85, 1.1)), 0.6 + 0.4 * smoothstep(0, H, q.y)),
          sway: [f, f], pivot: 'center', normal: outN,
        });
      }
      b.setSway(m, (q) => Math.min(1, Math.hypot(q.x, q.z) / (H * 0.9) + q.y / (H * 2)));
      if (b.triangleCount > budget) { b.rollback(m); break; }
    }
  } else if (type === 'boxwoodBall') {
    H = opts.height ?? range(rnd, 0.6, 1.2);
    const n = chance(rnd, 0.6) ? 1 : irange(rnd, 2, 3);
    const lumps: Lump[] = [];
    for (let i = 0; i < n; i++) {
      const r = (H / 2) * (i === 0 ? 1 : range(rnd, 0.6, 0.85));
      const a = rnd() * Math.PI * 2, d = i === 0 ? 0 : r * 0.9;
      lumps.push({ c: v3(Math.cos(a) * d, r * 0.95, Math.sin(a) * d), r: v3(r * range(rnd, 1, 1.15), r, r * range(rnd, 1, 1.15)) });
    }
    lumpyShrub(b, rnd, lod, lumps, H, { cell: Cell.Boxwood, size: [0.11, 0.15], palette: SHRUB_PALETTE.boxwood }, 2.6, [0.93, 1.02], ns);
  } else {
    H = opts.height ?? range(rnd, 0.9, 1.6);
    const n = irange(rnd, 3, 5);
    const lumps: Lump[] = [];
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + gauss(rnd) * 0.4, d = i === 0 ? 0 : range(rnd, 0.3, 0.6) * H;
      const r = H * range(rnd, 0.45, 0.6);
      lumps.push({ c: v3(Math.cos(a) * d, r * 0.7, Math.sin(a) * d), r: v3(r * 1.25, r * 0.8, r * 1.25) });
    }
    lumpyShrub(b, rnd, lod, lumps, H, { cell: Cell.Yew, size: [0.16, 0.22], palette: SHRUB_PALETTE.yew }, 2.4, [0.85, 1.03], ns);
  }
  const g = b.build();
  const bb = g.boundingBox!;
  const rad = Math.max(bb.max.x - bb.min.x, bb.max.z - bb.min.z) * 0.4;
  return { geometry: g, material: foliageMaterial(), collider: { type: 'cylinder', center: [0, H * 0.5, 0], radius: rad, halfHeight: H * 0.5 } };
}
