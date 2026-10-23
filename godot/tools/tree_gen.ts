// Procedural autumn trees for the Godot version of AeroSim (own work, no outside models).
// Nine species, each at two detail levels, plus two light far silhouettes. Used by export_assets.ts.
//
// Every mesh carries:
//   position, normal (leaves: a crown-shaped "shading" normal, so the canopy lights as a volume),
//   uv (bark: metres around and along the stem; leaves: a cell of the species' leaf atlas),
//   COLOR_0 rgba: rgb = baked occlusion times a tint, a = how near the outside of the crown (leaves) or 0 (wood),
//   TEXCOORD_1: (wind phase, branch flex) for the sway shader.
// Materials are named "bark:<set>" and "leaf:<atlas>"; game/assets.gd swaps them for the tree shaders and loads the
// shared textures (assets/textures/bark_*.jpg, assets/trees/leaves_*.webp) so every model reuses one copy.
import * as THREE from 'three';
import { createCanvas } from '@napi-rs/canvas';

// ------------------------------------------------------------------ small helpers
export function rng32(seed: number) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
type R = () => number;
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const UP = V(0, 1, 0);
const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));
const sstep = (e0: number, e1: number, x: number) => { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); };
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
function randUnit(r: R): THREE.Vector3 { const z = r() * 2 - 1, a = r() * Math.PI * 2, s = Math.sqrt(1 - z * z); return V(Math.cos(a) * s, z, Math.sin(a) * s); }
function anyPerp(n: THREE.Vector3): THREE.Vector3 { const t = Math.abs(n.y) < 0.9 ? UP : V(1, 0, 0); return V().crossVectors(t, n).normalize(); }

// ------------------------------------------------------------------ mesh builder
export class MeshB {
  pos: number[] = []; nor: number[] = []; uv: number[] = []; col: number[] = []; uv1: number[] = []; idx: number[] = [];
  get n() { return this.pos.length / 3; }
  get tris() { return this.idx.length / 3; }
  vert(p: THREE.Vector3, n: THREE.Vector3, u: number, v: number, c: number[], w: number[]) {
    this.pos.push(p.x, p.y, p.z); this.nor.push(n.x, n.y, n.z); this.uv.push(u, v);
    this.col.push(c[0], c[1], c[2], c[3] ?? 0); this.uv1.push(w[0], w[1]);
  }
  geometry(): THREE.BufferGeometry {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 4));
    g.setAttribute('uv1', new THREE.Float32BufferAttribute(this.uv1, 2));
    g.setIndex(this.idx); g.computeBoundingBox(); g.computeBoundingSphere();
    return g;
  }
}

export interface Bark { name: string; tile: number }   // texture set and its metres per repeat

/** Tapered tube through points. u runs around in metres (a whole number of repeats so the seam closes), v along it in metres.
 *  ao[i] and tint give the vertex colour; flex rises from flex0 to flex1 along the tube. */
function tube(M: MeshB, pts: THREE.Vector3[], radii: number[], sides: number, bark: Bark, ao: number[], tint: number[], phase: number, flex0: number, flex1: number, v0 = 0) {
  const base = M.n; let len = v0;
  const T = V(), N = V(), B = V();
  let prevN: THREE.Vector3 | null = null;
  const reps = Math.max(1, Math.round((2 * Math.PI * radii[0]) / bark.tile * 1.0));
  for (let i = 0; i < pts.length; i++) {
    const a = pts[Math.max(i - 1, 0)], b = pts[Math.min(i + 1, pts.length - 1)];
    T.subVectors(b, a).normalize();
    // parallel transport keeps the bark from twisting along a bent limb
    if (prevN) { N.copy(prevN).addScaledVector(T, -prevN.dot(T)).normalize(); } else { N.copy(anyPerp(T)); }
    prevN = N.clone();
    B.crossVectors(T, N).normalize();
    if (i > 0) len += pts[i].distanceTo(pts[i - 1]);
    const t = i / (pts.length - 1);
    for (let s = 0; s <= sides; s++) {
      const ang = (s / sides) * Math.PI * 2, c = Math.cos(ang), sn = Math.sin(ang);
      const nn = V().addScaledVector(N, c).addScaledVector(B, sn).normalize();
      const p = pts[i].clone().addScaledVector(nn, radii[i]);
      const under = 0.82 + 0.18 * (nn.y * 0.5 + 0.5);    // the underside of a limb sees less sky
      const k = ao[i] * under;
      M.vert(p, nn, (s / sides) * reps * bark.tile, len, [k * tint[0], k * tint[1], k * tint[2], 0], [phase, lerp(flex0, flex1, t)]);
    }
  }
  for (let i = 0; i < pts.length - 1; i++) for (let s = 0; s < sides; s++) {
    const a = base + i * (sides + 1) + s, b = a + 1, c = a + sides + 1, d = c + 1;
    M.idx.push(a, c, b, b, c, d);
  }
  return len;
}

/** Points along a quadratic bend from p0 to p1, lifted by `bow` at the middle (positive bows upward). */
function bend(p0: THREE.Vector3, p1: THREE.Vector3, n: number, bow: THREE.Vector3, r: R, wobble: number) {
  const out: THREE.Vector3[] = [];
  const mid = p0.clone().lerp(p1, 0.5).add(bow);
  for (let i = 0; i <= n; i++) {
    const t = i / n, a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t;
    const p = V().addScaledVector(p0, a).addScaledVector(mid, b).addScaledVector(p1, c);
    if (i > 0 && i < n) p.add(randUnit(r).multiplyScalar(wobble));
    out.push(p);
  }
  return out;
}

/** A leaf card: a quad folded down its middle (a shallow V), so it never reads as a flat sprite from the side.
 *  cell = [u0, v0, du, dv] in the atlas; the card's "up" maps to the top of the cell. */
function card(M: MeshB, c: THREE.Vector3, nrm: THREE.Vector3, upHint: THREE.Vector3, w: number, h: number, cell: number[], fold: number, shadeN: THREE.Vector3, col: number[], wind: number[], flat = false) {
  let right = V().crossVectors(upHint, nrm);
  if (right.lengthSq() < 1e-4) right = anyPerp(nrm); right.normalize();
  const up = V().crossVectors(nrm, right).normalize();
  const cf = Math.cos(fold), sf = Math.sin(fold);
  const rR = right.clone().multiplyScalar(cf).addScaledVector(nrm, -sf);
  const rL = right.clone().multiplyScalar(-cf).addScaledVector(nrm, -sf);
  const [u0, v0, du, dv] = cell;
  const b = M.n;
  const hw = w / 2, hh = h / 2;
  // the base of the card droops a little (the stem end), the tip lifts: a gentle curve along its length too
  const rows = [-hh, hh];
  for (const y of rows) {
    const vv = y < 0 ? v0 + dv : v0;
    const lift = nrm.clone().multiplyScalar(y < 0 ? -0.06 * h : 0.0);
    const mid = c.clone().addScaledVector(up, y).add(lift);
    if (flat) {
      M.vert(mid.clone().addScaledVector(right, -hw), shadeN, u0, vv, col, wind);
      M.vert(mid.clone().addScaledVector(right, hw), shadeN, u0 + du, vv, col, wind);
    } else {
      M.vert(mid.clone().addScaledVector(rL, hw), shadeN, u0, vv, col, wind);
      M.vert(mid, shadeN, u0 + du / 2, vv, col, wind);
      M.vert(mid.clone().addScaledVector(rR, hw), shadeN, u0 + du, vv, col, wind);
    }
  }
  if (flat) M.idx.push(b, b + 2, b + 1, b + 1, b + 2, b + 3);
  else M.idx.push(b, b + 3, b + 1, b + 1, b + 3, b + 4, b + 1, b + 4, b + 2, b + 2, b + 4, b + 5);
}

/** A strip card along a curved centre line (conifer sprigs): pts, half widths, side and normal per point. */
function strip(M: MeshB, pts: THREE.Vector3[], half: number[], side: THREE.Vector3[], nrm: THREE.Vector3[], cell: number[], col: (i: number) => number[], wind: (i: number) => number[]) {
  const base = M.n; const [u0, v0, du, dv] = cell;
  for (let i = 0; i < pts.length; i++) {
    const u = u0 + du * (i / (pts.length - 1));
    M.vert(pts[i].clone().addScaledVector(side[i], -half[i]), nrm[i], u, v0 + dv, col(i), wind(i));
    M.vert(pts[i].clone().addScaledVector(side[i], half[i]), nrm[i], u, v0, col(i), wind(i));
  }
  for (let i = 0; i < pts.length - 1; i++) { const a = base + i * 2; M.idx.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
}

// 2 x 2 atlas cells (u0, v0, du, dv). Broadleaf: 0..2 sprays (0 most colourful outer leaves, 2 inner/lower leaves), 3 dense clump for LOD1.
const CELL = [[0, 0, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]];
// Conifer atlases are four horizontal bands (sprigs grow left to right): 0..2 sprigs, 3 hanging or tuft variant.
const BAND = [[0, 0, 1, 0.25], [0, 0.25, 1, 0.25], [0, 0.5, 1, 0.25], [0, 0.75, 1, 0.25]];

export interface TreeGeo { wood: THREE.BufferGeometry; leaf: THREE.BufferGeometry; height: number; crownR: number; crownBase: number; woodTris: number; leafTris: number }

// ------------------------------------------------------------------ broadleaf species
export interface BroadSpec {
  seed: number; H: number; trunkH: number; crownY: number; Rx: number; Ry: number;
  clumps: number; clumpR: number; clusters: number; cards: number; cardS: number; cardAspect?: number;
  slope: number;         // rise per metre of reach for the main limbs (steep for poplar, low for oak)
  trunkR: number; leader: boolean; bark: Bark; barkTint: number[];
  droop: number;         // 0 sprays point outward and up; 1 they hang (birch)
  fold: number;          // leaf card fold (radians)
  sparse?: number;       // 0..1: fewer leaves (the birch's airy crown)
  sub: number;           // sub-branches per clump
  flatTop?: number;      // 0..1 squashes the top of the crown
  lowerSkirt?: number;   // how far below the crown centre clumps may hang (as a fraction of Ry)
  coolCells?: boolean;   // inner and lower leaves use the greener cell
}

export function buildBroad(sp: BroadSpec, lod: 0 | 1): TreeGeo {
  const r = rng32(sp.seed);
  const W = new MeshB(), L = new MeshB();
  // ---- crown: an ellipsoid, a little lopsided, made of clumps (the big lumps you see from above)
  const Rx = sp.Rx * (0.92 + r() * 0.16), Rz = sp.Rx * (0.92 + r() * 0.16), Ry = sp.Ry;
  const C = V((r() - 0.5) * 0.5, sp.crownY, (r() - 0.5) * 0.5);
  const rho = (p: THREE.Vector3) => { const d = p.clone().sub(C); const ft = sp.flatTop ?? 0; const ry = d.y > 0 ? Ry * (1 - 0.35 * ft) : Ry; return Math.sqrt((d.x / Rx) ** 2 + (d.y / ry) ** 2 + (d.z / Rz) ** 2); };
  const outN = (p: THREE.Vector3) => { const d = p.clone().sub(C); return V(d.x / (Rx * Rx), d.y / (Ry * Ry), d.z / (Rz * Rz)).normalize(); };
  const clumps: { c: THREE.Vector3; rad: number }[] = [];
  const skirt = sp.lowerSkirt ?? 0.45;
  const golden = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0, k = 0; k < sp.clumps && i < sp.clumps * 4; i++) {
    const y = 1 - (i + 0.5) / (sp.clumps * 1.4) * 2;
    if (y < -skirt) continue;
    const rr = Math.sqrt(1 - y * y), a = i * golden + r() * 0.6;
    const f = 0.58 + r() * 0.16;
    const ft = sp.flatTop ?? 0;
    const c = V(C.x + Math.cos(a) * rr * Rx * f, C.y + y * Ry * f * (y > 0 ? 1 - 0.35 * ft : 1), C.z + Math.sin(a) * rr * Rz * f);
    clumps.push({ c, rad: sp.clumpR * (Rx + Rz) * 0.5 * (0.8 + r() * 0.4) }); k++;
  }
  clumps.push({ c: V(C.x + (r() - 0.5), C.y + Ry * 0.62 * (1 - 0.3 * (sp.flatTop ?? 0)), C.z + (r() - 0.5)), rad: sp.clumpR * (Rx + Rz) * 0.45 });
  const top = sp.H;
  // ---- wood: trunk (with a root flare), main limbs to each clump, sub-branches inside each clump
  const sides = lod === 0 ? 10 : 6;
  const trunkTop = sp.leader ? top * 0.92 : sp.trunkH + (C.y - sp.trunkH) * 0.55;
  const tp: THREE.Vector3[] = [], tr: number[] = [], tao: number[] = [];
  const nT = lod === 0 ? 10 : 6;
  const lean = V((r() - 0.5) * 0.25, 0, (r() - 0.5) * 0.25);
  for (let i = 0; i <= nT; i++) {
    const t = i / nT, y = t * trunkTop;
    tp.push(V(Math.sin(sp.seed + t * 2.3) * 0.12 * t + lean.x * t * t * trunkTop * 0.1, y, Math.cos(sp.seed * 1.7 + t * 1.9) * 0.12 * t + lean.z * t * t * trunkTop * 0.1));
    const flare = 1 + 0.45 * Math.exp(-y / 0.45);
    tr.push(sp.trunkR * flare * (sp.leader ? (1 - 0.88 * t) : (1 - 0.35 * t)) + 0.02);
    tao.push((0.55 + 0.45 * sstep(0, 2.2, y)) * (y > sp.trunkH ? 0.85 : 1));
  }
  tube(W, tp, tr, sides + (lod === 0 ? 2 : 0), sp.bark, tao, sp.barkTint, 0, 0, 0.08);
  const trunkAt = (y: number) => { const t = clamp(y / trunkTop, 0, 1) * nT; const i = Math.min(nT - 1, Math.floor(t)); const f = t - i; return { p: tp[i].clone().lerp(tp[i + 1], f), r: lerp(tr[i], tr[i + 1], f) }; };
  const limbEnds: THREE.Vector3[] = [];
  for (const cl of clumps) {
    const reach = Math.hypot(cl.c.x - C.x * 0, cl.c.z);
    let y0 = cl.c.y - Math.max(0.6, reach * sp.slope) * (0.85 + r() * 0.3);
    y0 = clamp(y0, sp.trunkH * 0.9, trunkTop - 0.3);
    const base = trunkAt(y0);
    const end = cl.c.clone().add(randUnit(r).multiplyScalar(cl.rad * 0.25));
    const n = lod === 0 ? 5 : 3;
    const pts = bend(base.p, end, n, V(0, reach * 0.12 * (1 - sp.droop), 0), r, lod === 0 ? 0.12 : 0.0);
    const r0 = Math.min(base.r * 0.75, sp.trunkR * (0.35 + 0.35 * Math.min(1, reach / 4)));
    const radii = pts.map((_, i) => r0 * (1 - 0.75 * i / n) + 0.02);
    const ao = pts.map(p => 0.5 + 0.5 * clamp(rho(p), 0, 1));
    tube(W, pts, radii, lod === 0 ? 6 : 4, sp.bark, ao, sp.barkTint, r(), 0.05, 0.35);
    limbEnds.push(end);
    if (lod === 0) {
      for (let s = 0; s < sp.sub; s++) {
        const from = pts[Math.max(2, n - 2 - (s % 2))];
        const dir = outN(cl.c).multiplyScalar(0.7).add(randUnit(r)).normalize();
        if (sp.droop > 0.5) dir.y -= 0.6;
        const to = from.clone().addScaledVector(dir.normalize(), cl.rad * (0.5 + r() * 0.4));
        const sp2 = bend(from, to, 2, V(0, -sp.droop * 0.4, 0), r, 0.06);
        const sr = radii[Math.max(2, n - 2)] * 0.55;
        tube(W, sp2, sp2.map((_, i) => sr * (1 - 0.7 * i / 2) + 0.008), 4, sp.bark, sp2.map(p => 0.55 + 0.45 * clamp(rho(p), 0, 1)), sp.barkTint, r(), 0.3, 0.6);
      }
    }
  }
  // ---- leaves: clusters of folded cards in each clump's outer shell; LOD1 uses fewer, larger cards from the dense cell
  const sparse = sp.sparse ?? 0;
  const perClump = lod === 0 ? Math.round(sp.clusters * (1 - 0.35 * sparse)) : Math.round(sp.clusters * 0.42 * (1 - 0.3 * sparse));
  const cardsPer = lod === 0 ? sp.cards : 1;
  const aspect = sp.cardAspect ?? 1;
  for (const cl of clumps) {
    for (let k = 0; k < perClump; k++) {
      const oc = outN(cl.c);
      const dir = randUnit(r).add(oc.clone().multiplyScalar(0.55)).normalize();
      const rad = cl.rad * (lod === 0 ? 0.35 + 0.65 * Math.sqrt(r()) : 0.25 + 0.55 * r());
      const p = cl.c.clone().addScaledVector(dir, rad);
      const rc = rho(p);
      if (rc > 1.12) p.lerp(C, 1 - 1.08 / rc);           // keep inside the crown
      if (p.y < sp.trunkH + 0.3) p.y = sp.trunkH + 0.3 + r() * 0.5;
      const rr2 = clamp(rho(p), 0, 1.2);
      const o = outN(p);
      const hN = clamp((p.y - sp.trunkH) / (top - sp.trunkH), 0, 1);
      // occlusion: deep inside and low in the crown is darker; the outer shell is open to the sky
      // and at the scale of each clump: its top and outside are lit, its core and underside are not (the cauliflower look from above)
      const cd = p.clone().sub(cl.c); const cr = cd.length() / cl.rad; const cup = cd.normalize().y;
      const ao = clamp((0.36 + 0.64 * sstep(0.25, 1.0, rr2)) * (0.78 + 0.22 * hN) * (0.62 + 0.38 * sstep(0.15, 0.95, cr)) * (0.85 + 0.15 * cup) * (0.92 + r() * 0.14), 0.28, 1.05);
      const rim = sstep(0.62, 1.02, rr2);
      // leaf colour: the sunlit outer leaves turn first; inner and lower leaves stay warmer gold or green
      let cellI: number;
      if (lod === 1) cellI = 3;
      else {
        const outer = rim * 0.7 + hN * 0.5 + (r() - 0.5) * 0.6;
        cellI = outer > 0.75 ? 0 : outer > 0.35 ? 1 : 2;
        if (!sp.coolCells && cellI === 2 && r() < 0.5) cellI = 1;
      }
      const hue = 0.9 + r() * 0.2;
      const col = [ao * hue, ao * hue * (0.96 + r() * 0.08), ao * hue * (0.94 + r() * 0.08), rim];
      const shadeN = o.clone().multiplyScalar(0.8).add(V(0, 0.25, 0)).normalize();
      for (let j = 0; j < cardsPer; j++) {
        const c = p.clone().add(randUnit(r).multiplyScalar(lod === 0 ? 0.28 : 0.15));
        const nrm = randUnit(r).add(o.clone().multiplyScalar(0.8)).add(V(0, 0.45, 0)).normalize();
        const upH = o.clone().multiplyScalar(1 - sp.droop).add(V(0, 0.6 - 1.5 * sp.droop, 0)).add(randUnit(r).multiplyScalar(0.7)).normalize();
        const s = (lod === 0 ? sp.cardS : cl.rad * 1.3) * (0.8 + r() * 0.45);
        const sn = shadeN.clone().addScaledVector(nrm, 0.25).normalize();
        card(L, c, nrm, upH, s, s * aspect, CELL[cellI], lod === 0 ? sp.fold * (0.6 + r() * 0.8) : 0.25, sn, col, [r(), 0.25 + 0.45 * rim + 0.15 * r()], lod === 1);
      }
    }
  }
  return { wood: W.geometry(), leaf: L.geometry(), height: top, crownR: (Rx + Rz) / 2, crownBase: sp.trunkH, woodTris: W.tris, leafTris: L.tris };
}

// ------------------------------------------------------------------ spruce (Norway): whorls of drooping sprigs and hanging curtains
export function buildSpruce(seed: number, lod: 0 | 1, bark: Bark, H0 = 20): TreeGeo {
  const r = rng32(seed), W = new MeshB(), L = new MeshB();
  const H = H0 + r() * 2.5;
  const tp: THREE.Vector3[] = [], tr: number[] = [], tao: number[] = [];
  const nT = lod === 0 ? 12 : 6;
  for (let i = 0; i <= nT; i++) { const t = i / nT; tp.push(V(Math.sin(t * 3 + seed) * 0.1 * t, t * H * 0.98, Math.cos(t * 2.3 + seed) * 0.08 * t)); tr.push(0.36 * Math.pow(1 - t, 0.95) * (1 + 0.35 * Math.exp(-t * H / 0.4)) + 0.015); tao.push(0.45 + 0.4 * t); }
  tube(W, tp, tr, lod === 0 ? 9 : 5, bark, tao, [1, 1, 1], 0, 0, 0.1);
  const whorls = lod === 0 ? 34 : 16, per = lod === 0 ? 7 : 6, segs = lod === 0 ? 4 : 3;
  const crownC = V(0, H * 0.42, 0);
  for (let w = 0; w < whorls; w++) {
    const t = 0.06 + 0.92 * (w / (whorls - 1)) + (r() - 0.5) * 0.01, y = t * H * 0.98;
    const Lmax = (4.3 * Math.pow(1 - t, 0.85) + 0.3) * (0.88 + r() * 0.24);
    const a0 = r() * 6.28;
    for (let b = 0; b < per; b++) {
      if (lod === 0 && r() < 0.08) continue;     // a missing branch here and there breaks the perfect cone
      const az = a0 + (b / per) * 6.28 + (r() - 0.5) * 0.5, len = Lmax * (0.7 + r() * 0.45);
      const dir = V(Math.cos(az), 0, Math.sin(az));
      const droop = 0.6 - 0.95 * t + (r() - 0.5) * 0.2;
      const centre: THREE.Vector3[] = [], ao: number[] = [], half: number[] = [], fl: number[] = [];
      for (let s = 0; s <= segs; s++) {
        const u = s / segs;
        const p = V(0, y, 0).addScaledVector(dir, u * len); p.y += -droop * u * len * 0.45 + 0.4 * len * u * u * u * u;
        centre.push(p);
        ao.push(clamp((0.28 + 0.78 * Math.pow(u, 0.75)) * (0.66 + 0.34 * t) * (0.9 + r() * 0.15), 0.25, 1.0));
        half.push(Math.max(0.14, len * 0.27 * (1 - 0.5 * u * u)) * (lod === 0 ? 1 : 1.25));
        fl.push(u * u * (0.35 + 0.65 * (1 - t)));
      }
      const ph = r(); const cellI = Math.floor(r() * 3);
      for (const roll of lod === 0 ? [-0.6, 0.6] : [0]) {
        const side = V().crossVectors(UP, dir).normalize();
        const sv = side.clone().applyAxisAngle(dir, roll), nv = UP.clone().applyAxisAngle(dir, roll);
        const sides: THREE.Vector3[] = [], norms: THREE.Vector3[] = [];
        for (let s = 0; s <= segs; s++) {
          const radial = centre[s].clone().sub(V(0, centre[s].y * 0.8 + H * 0.1, 0)).normalize();
          norms.push(nv.clone().multiplyScalar(0.45).addScaledVector(radial, 0.6).add(V(0, 0.22, 0)).normalize()); sides.push(sv);
        }
        strip(L, centre, half, sides, norms, BAND[cellI], i => [ao[i], ao[i] * (0.97 + 0.05 * ph), ao[i] * 0.98, sstep(0.5, 1, i / segs)], i => [ph, fl[i]]);
      }
      // Norway spruce: curtains of branchlets hang below the outer half of the lower and middle branches
      if (lod === 0 && t < 0.75 && len > 1.2) {
        const s0 = Math.floor(segs / 2);
        const top = centre[s0].clone().lerp(centre[segs], 0.35);
        const hang = V(0, -1, 0).addScaledVector(dir, 0.25).normalize();
        const hl = len * 0.42;
        const pts = [top, top.clone().addScaledVector(hang, hl * 0.5), top.clone().addScaledVector(hang, hl)];
        const side = V().crossVectors(UP, dir).normalize();
        const nrmC = dir.clone().multiplyScalar(0.7).add(V(0, 0.3, 0)).normalize();
        strip(L, pts, [len * 0.22, len * 0.2, len * 0.14], [side, side, side], [nrmC, nrmC, nrmC], BAND[3], i => { const a = ao[s0] * (0.92 - 0.1 * i); return [a, a, a, 0.5]; }, i => [ph, fl[s0] + 0.15 * i]);
      }
    }
  }
  return { wood: W.geometry(), leaf: L.geometry(), height: H, crownR: 4.3, crownBase: 1.4, woodTris: W.tris, leafTris: L.tris };
}

// ------------------------------------------------------------------ Scots pine: tall bare stem, orange upper bark, flat irregular crown of needle tufts
export function buildPine(seed: number, lod: 0 | 1, bark: Bark): TreeGeo {
  const r = rng32(seed), W = new MeshB(), L = new MeshB();
  const H = 17 + r() * 3, clear = H * (0.5 + r() * 0.08);
  const tp: THREE.Vector3[] = [], tr: number[] = [], tao: number[] = [], nT = lod === 0 ? 12 : 6;
  const bx = (r() - 0.5) * 1.2, bz = (r() - 0.5) * 1.2;
  for (let i = 0; i <= nT; i++) {
    const t = i / nT; tp.push(V(Math.sin(t * 3.1) * bx * t, t * H * 0.96, Math.sin(t * 2.4 + 1) * bz * t));
    tr.push(0.3 * (1 - 0.82 * t) * (1 + 0.35 * Math.exp(-t * H / 0.4)) + 0.02); tao.push(0.6 + 0.4 * sstep(0, 0.2, t));
  }
  // grey-brown plated bark low down, the famous orange "fox" bark higher up: blend the tint along the stem
  const W2 = new MeshB();
  tube(W2, tp, tr, lod === 0 ? 10 : 6, bark, tao, [1, 1, 1], 0, 0, 0.08);
  for (let i = 0; i < W2.n; i++) { const y = W2.pos[i * 3 + 1]; const k = sstep(H * 0.3, H * 0.6, y); W2.col[i * 4] *= lerp(0.92, 1.35, k); W2.col[i * 4 + 1] *= lerp(0.9, 0.82, k); W2.col[i * 4 + 2] *= lerp(0.88, 0.6, k); }
  Object.assign(W, W2);
  const crownC = V(tp[nT].x * 0.8, clear + (H - clear) * 0.55, tp[nT].z * 0.8);
  const nb = lod === 0 ? 16 : 10;
  const tufts: { p: THREE.Vector3; o: THREE.Vector3; ao: number; rim: number }[] = [];
  for (let b = 0; b < nb; b++) {
    const t = b / (nb - 1), y = lerp(clear, H * 0.93, t) + (r() - 0.5) * 0.6;
    const az = b * 2.4 + r() * 0.8, reach = (1.6 + 2.8 * Math.sin(Math.PI * (0.15 + 0.7 * (1 - t)))) * (0.75 + r() * 0.4);
    const ti = clamp(y / (H * 0.96), 0, 1) * nT, i0 = Math.min(nT - 1, Math.floor(ti));
    const base = tp[i0].clone().lerp(tp[i0 + 1], ti - i0);
    const end = base.clone().add(V(Math.cos(az) * reach, reach * (0.25 + 0.3 * r()), Math.sin(az) * reach));
    const pts = bend(base, end, lod === 0 ? 5 : 3, V(0, 0.35, 0), r, lod === 0 ? 0.18 : 0);
    const r0 = 0.06 + 0.07 * (1 - t);
    tube(W, pts, pts.map((_, i) => r0 * (1 - 0.7 * i / (pts.length - 1)) + 0.012), lod === 0 ? 5 : 4, bark, pts.map(() => 0.75), [1.2, 0.85, 0.65], r(), 0.1, 0.45);
    // tufts along the last part of the branch and on two or three short side shoots
    const nTuft = lod === 0 ? 10 + Math.floor(r() * 5) : 4;
    for (let k = 0; k < nTuft; k++) {
      const along = pts[pts.length - 1 - Math.floor(r() * Math.min(3, pts.length - 1))];
      const p = along.clone().add(randUnit(r).multiplyScalar(0.55 + reach * 0.12)); p.y += 0.25;
      const o = p.clone().sub(crownC); o.y *= 1.8; o.normalize();
      const d = p.distanceTo(crownC) / 4.2;
      tufts.push({ p, o, ao: clamp(0.4 + 0.6 * sstep(0.2, 1.0, d), 0.35, 1), rim: sstep(0.6, 1.1, d) });
    }
  }
  for (let k = 0; k < (lod === 0 ? 10 : 4); k++) {   // a leader tuft cluster at the top
    const p = tp[nT].clone().add(randUnit(r).multiplyScalar(0.7)); p.y -= 0.3;
    tufts.push({ p, o: V(0, 1, 0), ao: 1, rim: 1 });
  }
  for (const tf of tufts) {
    const cards = lod === 0 ? 3 : 2;
    const sN = tf.o.clone().multiplyScalar(0.7).add(V(0, 0.45, 0)).normalize();
    const ph = r();
    for (let j = 0; j < cards; j++) {
      const nrm = randUnit(r).add(V(0, 0.6, 0)).normalize();
      const s = (lod === 0 ? 1.25 : 2.2) * (0.8 + r() * 0.4);
      const cellI = lod === 0 ? Math.floor(r() * 3) : 3;
      card(L, tf.p.clone().add(randUnit(r).multiplyScalar(0.12)), nrm, tf.o.clone().add(V(0, 0.8, 0)).add(randUnit(r).multiplyScalar(0.6)).normalize(), s, s, CELL[cellI], 0.35, sN, [tf.ao, tf.ao * 1.0, tf.ao * 0.96, tf.rim], [ph, 0.3 + 0.3 * tf.rim], lod === 1);
    }
  }
  return { wood: W.geometry(), leaf: L.geometry(), height: H, crownR: 4.0, crownBase: clear, woodTris: W.tris, leafTris: L.tris };
}

// ------------------------------------------------------------------ far silhouettes (about 100 triangles): lumpy, several heights in one model
export function buildFar(kind: 'conifer' | 'broadleaf'): THREE.BufferGeometry {
  const M = new MeshB();
  const blob = (c: THREE.Vector3, rx: number, ry: number, aoBot: number, aoTop: number, segs = 6, rings = 4, tipY = 0) => {
    const b = M.n;
    for (let j = 0; j <= rings; j++) {
      const v = j / rings, phi = -Math.PI / 2 + v * Math.PI;
      for (let i = 0; i <= segs; i++) {
        const th = (i / segs) * Math.PI * 2;
        const n = V(Math.cos(phi) * Math.cos(th), Math.sin(phi), Math.cos(phi) * Math.sin(th));
        let p = V(c.x + n.x * rx, c.y + n.y * ry, c.z + n.z * rx);
        if (tipY > 0 && j === rings) p = V(c.x, c.y + tipY, c.z);
        const nn = V(n.x, n.y + 0.25, n.z).normalize();
        const k = lerp(aoBot, aoTop, v);
        M.vert(p, nn, i / segs, v, [k, k, k, 1], [0, 0]);
      }
    }
    for (let j = 0; j < rings; j++) for (let i = 0; i < segs; i++) {
      const a = b + j * (segs + 1) + i, bb = a + 1, c2 = a + segs + 1, d = c2 + 1;
      if (j === 0) M.idx.push(a, c2, d); else if (j === rings - 1) M.idx.push(a, c2, bb); else M.idx.push(a, c2, bb, bb, c2, d);
    }
  };
  if (kind === 'conifer') {
    // a narrow cone in three tiers, the tip off-centre
    const b = M.n; const segs = 7;
    const tiers = [[0.8, 3.8, 0.32], [6.5, 2.9, 0.5], [12, 1.9, 0.7], [20.5, 0.0, 1.0]];
    for (let j = 0; j < tiers.length; j++) for (let i = 0; i <= segs; i++) {
      const th = (i / segs) * Math.PI * 2, [y, rr, ao] = tiers[j];
      const wob = 1 + 0.12 * Math.sin(th * 3 + j);
      M.vert(V(Math.cos(th) * rr * wob + (j === 3 ? 0.2 : 0), y, Math.sin(th) * rr * wob), V(Math.cos(th), 0.55, Math.sin(th)).normalize(), 0, 0, [ao, ao, ao, 1], [0, 0]);
    }
    for (let j = 0; j < tiers.length - 1; j++) for (let i = 0; i < segs; i++) { const a = b + j * (segs + 1) + i; M.idx.push(a, a + segs + 1, a + 1, a + 1, a + segs + 1, a + segs + 2); }
  } else {
    // three overlapping lumps at different heights: never the same lollipop twice once the shader varies them
    blob(V(0, 7.6, 0), 5.3, 3.9, 0.3, 0.8, 7, 4);
    blob(V(2.1, 10.4, 1.0), 3.4, 2.8, 0.55, 1.0, 6, 3);
    blob(V(-1.8, 9.8, -1.5), 3.1, 2.6, 0.5, 0.95, 6, 3);
    // a dark trunk stub so the lump does not float at the edge of a field
    const b = M.n; const k = 0.18;
    for (let i = 0; i <= 3; i++) { const th = (i / 3) * Math.PI * 2; M.vert(V(Math.cos(th) * 0.35, 0, Math.sin(th) * 0.35), V(Math.cos(th), 0, Math.sin(th)), 0, 0, [k, k, k, 1], [0, 0]); M.vert(V(Math.cos(th) * 0.3, 4.6, Math.sin(th) * 0.3), V(Math.cos(th), 0, Math.sin(th)), 0, 0, [k, k, k, 1], [0, 0]); }
    for (let i = 0; i < 3; i++) { const a = b + i * 2; M.idx.push(a, a + 1, a + 2, a + 2, a + 1, a + 3); }
  }
  return M.geometry();
}

// ------------------------------------------------------------------ leaf atlases (painted here, 512 px, four cells)
type Pal = [string, number][];
function pick(p: Pal, r: R): string { let t = r() * p.reduce((s, x) => s + x[1], 0); for (const [c, w] of p) { t -= w; if (t <= 0) return c; } return p[0][0]; }
function hexRgb(h: string) { return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]; }
function shadeHex(h: string, k: number, r: R) { const c = hexRgb(h); const j = 1 + (r() - 0.5) * 0.12; return `rgb(${clamp(c[0] * k * j, 0, 255) | 0},${clamp(c[1] * k * (1 + (r() - 0.5) * 0.08), 0, 255) | 0},${clamp(c[2] * k, 0, 255) | 0})`; }

export type LeafShape = 'maple' | 'oak' | 'beech' | 'birch' | 'poplar';
/** Outline of one leaf, tip toward -y, stem at +y*len/2, in unit size. */
function leafOutline(shape: LeafShape, r: R): [number, number][] {
  const pts: [number, number][] = [];
  const N = 72;
  for (let i = 0; i < N; i++) {
    const a = (i / N) * Math.PI * 2 - Math.PI / 2;     // a = -90 deg is the tip (up)
    let rad = 1;
    const da = (x: number) => { let d = a - x; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return Math.abs(d); };
    if (shape === 'maple') {
      // five pointed lobes (tip, two upper side lobes, two small basal lobes), deep rounded sinuses, a few teeth
      const lobes = [[-Math.PI / 2, 1.0, 0.55], [-Math.PI / 2 - 1.0, 0.92, 0.5], [-Math.PI / 2 + 1.0, 0.92, 0.5], [-Math.PI / 2 - 2.05, 0.6, 0.45], [-Math.PI / 2 + 2.05, 0.6, 0.45]];
      rad = 0.34;
      for (const [la, lr, w] of lobes) { const t = 1 - da(la) / w; if (t > 0) rad = Math.max(rad, 0.34 + (lr - 0.34) * Math.pow(t, 0.75)); }
      rad += 0.035 * Math.abs(Math.sin(a * 13)) * (rad > 0.5 ? 1 : 0);
      if (da(Math.PI / 2) < 0.35) rad *= 0.55;      // notch where the stem joins
    } else if (shape === 'oak') {
      // long leaf with rounded lobes along both sides
      const t = (Math.sin(a) + 1) / 2;               // 0 at the tip, 1 at the base
      const env = 0.5 * Math.pow(Math.sin(Math.PI * clamp(0.08 + t * 0.92, 0, 1)), 0.7);
      const lob = 0.5 + 0.5 * Math.pow(Math.abs(Math.sin(t * Math.PI * 4.5)), 0.6);
      const w = env * lob;
      const x = Math.cos(a) >= 0 ? w : -w; const y = -Math.cos(Math.PI * t) * 1.0;
      pts.push([x, y * 0.95]); continue;
    } else if (shape === 'beech') {
      const t = (Math.sin(a) + 1) / 2;
      const w = 0.42 * Math.pow(Math.sin(Math.PI * clamp(t * 0.95 + 0.04, 0, 1)), 0.85) * (1 + 0.04 * Math.sin(t * 40));
      pts.push([Math.cos(a) >= 0 ? w : -w, -Math.cos(Math.PI * t)]); continue;
    } else if (shape === 'birch') {
      // triangular-ovate with a pointed tip and a fine double-toothed edge
      const t = (Math.sin(a) + 1) / 2;
      const w = 0.58 * Math.pow(clamp(t, 0, 1), 0.7) * Math.pow(1 - clamp(t, 0, 1) * 0.92, 0.55) * 1.6 * (1 + 0.06 * Math.abs(Math.sin(t * 60)));
      pts.push([Math.cos(a) >= 0 ? w : -w, -Math.cos(Math.PI * t)]); continue;
    } else {
      // poplar: diamond to round with a short point
      const t = (Math.sin(a) + 1) / 2;
      const w = 0.62 * Math.sin(Math.PI * Math.pow(clamp(t, 0, 1), 0.8)) * (1 + 0.04 * Math.abs(Math.sin(t * 36)));
      pts.push([Math.cos(a) >= 0 ? w : -w, -Math.cos(Math.PI * t) * 0.9]); continue;
    }
    pts.push([Math.cos(a) * rad, Math.sin(a) * rad]);
  }
  void r;
  return pts;
}

interface AtlasSpec { shape: LeafShape; pals: Pal[]; leafPx: number; count: number; size?: number; spots?: number }

/** Four leaf sprays on one 512 px atlas. Each spray: a twig with leaves on short stems, every leaf its own colour. */
export function paintLeafAtlas(spec: AtlasSpec, seed: number) {
  const S = spec.size ?? 512, half = S / 2;
  const cv = createCanvas(S, S), ctx = cv.getContext('2d');
  ctx.clearRect(0, 0, S, S);
  const r = rng32(seed);
  for (let cell = 0; cell < 4; cell++) {
    const ox = (cell % 2) * half, oy = Math.floor(cell / 2) * half;
    ctx.save(); ctx.beginPath(); ctx.rect(ox, oy, half, half); ctx.clip();
    const pal = cell === 3 ? [...spec.pals[0], ...spec.pals[1], ...spec.pals[2]] : spec.pals[cell];   // the clump mixes them all
    const dense = cell === 3;
    const n = Math.round(spec.count * (dense ? 2.6 : 1));
    // twig: from the bottom centre, branching upward
    const twigs: [number, number, number][] = [];
    const grow = (x: number, y: number, a: number, len: number, w: number, d: number) => {
      const steps = 10;
      for (let s = 0; s < steps; s++) {
        const nx = x + Math.cos(a) * len / steps, ny = y + Math.sin(a) * len / steps;
        ctx.strokeStyle = '#3a2a1c'; ctx.lineWidth = Math.max(1, w * (1 - s / steps * 0.6)); ctx.lineCap = 'round';
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(nx, ny); ctx.stroke();
        x = nx; y = ny; a += (r() - 0.5) * 0.12; twigs.push([x, y, a]);
        if (d < 2 && s > 1 && s < steps - 1 && r() < 0.34) grow(x, y, a + (r() < 0.5 ? -1 : 1) * (0.55 + r() * 0.5), len * (0.45 + 0.2 * r()), w * 0.6, d + 1);
      }
    };
    if (!dense) grow(ox + half * 0.5, oy + half * 0.98, -Math.PI / 2 + (r() - 0.5) * 0.3, half * 0.78, 4.2, 0);
    else for (let k = 0; k < 3; k++) grow(ox + half * (0.3 + 0.2 * k), oy + half, -Math.PI / 2 + (k - 1) * 0.5, half * 0.6, 3, 1);
    // leaves, back to front: the ones painted first are shaded darker (they sit behind)
    for (let i = 0; i < n; i++) {
      let x: number, y: number, a: number;
      if (twigs.length && r() < 0.85) { const t = twigs[Math.floor(r() * twigs.length)]; x = t[0]; y = t[1]; a = t[2] + (r() < 0.5 ? -1 : 1) * (0.5 + r() * 0.9); }
      else { x = ox + half * (0.15 + 0.7 * r()); y = oy + half * (0.1 + 0.75 * r()); a = -Math.PI / 2 + (r() - 0.5) * 2.5; }
      const sz = spec.leafPx * (0.7 + r() * 0.55) * (dense ? 0.8 : 1);
      // keep the whole leaf inside the cell (no bleeding into the neighbour cell)
      const m = sz * 1.05;
      x = clamp(x + Math.cos(a) * sz * 0.6, ox + m, ox + half - m); y = clamp(y + Math.sin(a) * sz * 0.6, oy + m, oy + half - m);
      const depth = i / n;
      const base = pick(pal, r);
      const k = 0.62 + 0.42 * depth + (r() - 0.5) * 0.12;
      const outline = leafOutline(spec.shape, r);
      ctx.save(); ctx.translate(x, y); ctx.rotate(a + Math.PI / 2); ctx.scale(sz * (0.62 + 0.38 * r()), sz);   // narrower: the leaf is turned a little away
      // stem
      ctx.strokeStyle = 'rgba(60,40,20,0.9)'; ctx.lineWidth = 1.4 / sz; ctx.beginPath(); ctx.moveTo(0, 0.6); ctx.lineTo(0, 1.25); ctx.stroke();
      ctx.beginPath(); outline.forEach(([px, py], j) => (j ? ctx.lineTo(px, py) : ctx.moveTo(px, py))); ctx.closePath();
      // body: a little lighter in the middle, darker toward the edge
      const g = ctx.createRadialGradient(0, -0.1, 0.05, 0, 0, 1.0);
      g.addColorStop(0, shadeHex(base, k * 1.12, r)); g.addColorStop(0.7, shadeHex(base, k, r)); g.addColorStop(1, shadeHex(base, k * 0.78, r));
      ctx.fillStyle = g; ctx.fill();
      ctx.strokeStyle = `rgba(30,15,5,${0.25 + 0.2 * r()})`; ctx.lineWidth = 0.8 / sz; ctx.stroke();
      // veins
      ctx.strokeStyle = `rgba(255,235,190,${0.18 + 0.12 * r()})`; ctx.lineWidth = 1.0 / sz;
      ctx.beginPath(); ctx.moveTo(0, 0.55); ctx.lineTo(0, -0.85);
      if (spec.shape === 'maple') { for (const s of [-1, 1]) { ctx.moveTo(0, 0.2); ctx.lineTo(s * 0.75, -0.45); ctx.moveTo(0, 0.3); ctx.lineTo(s * 0.55, 0.15); } }
      else { for (let v = -0.5; v < 0.5; v += 0.22) for (const s of [-1, 1]) { ctx.moveTo(0, v + 0.1); ctx.lineTo(s * 0.32, v - 0.12); } }
      ctx.stroke();
      // spots and blemishes (tar spot on maples, brown patches on the rest)
      const ns = Math.floor(r() * (spec.spots ?? 2.5));
      for (let s2 = 0; s2 < ns; s2++) { ctx.fillStyle = `rgba(${40 + r() * 50},${25 + r() * 20},10,${0.35 + r() * 0.35})`; ctx.beginPath(); ctx.ellipse((r() - 0.5) * 0.7, (r() - 0.5) * 0.9, 0.04 + r() * 0.09, 0.04 + r() * 0.07, r() * 3, 0, 6.3); ctx.fill(); }
      ctx.restore();
    }
    ctx.restore();
  }
  return bleed(cv, S);
}

/** Conifer atlas: four bands, each a sprig (spruce) or a needle tuft row (pine). */
export function paintConiferAtlas(kind: 'spruce' | 'pine', seed: number) {
  const S = 512, cv = createCanvas(S, S), ctx = cv.getContext('2d'), r = rng32(seed);
  ctx.clearRect(0, 0, S, S);
  if (kind === 'spruce') {
    // each band: one flat branch spray seen from above, a main axis left to right with side shoots that shorten toward
    // the tip (a feather shape with gaps), short dark needles; band 3 is a looser hanging spray for the curtains
    const bh = S / 4;
    const needle = (x: number, y: number, ang: number, L: number) => {
      const g = 48 + r() * 40, light = r() < 0.1;
      ctx.strokeStyle = light ? `rgb(${60 + r() * 20},${100 + r() * 25},${70 + r() * 20})` : `rgb(${14 + r() * 12},${g},${34 + r() * 20})`;
      ctx.lineWidth = 1.3; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(ang) * L, y + Math.sin(ang) * L); ctx.stroke();
    };
    const shoot = (x: number, y: number, ang: number, len: number, w: number, nl: number, depth = 0): void => {
      const steps = Math.max(2, Math.floor(len / 2.5));
      for (let s = 0; s < steps; s++) {
        const nx = x + Math.cos(ang) * 2.5, ny = y + Math.sin(ang) * 2.5;
        ctx.strokeStyle = '#3b2a1c'; ctx.lineWidth = Math.max(0.7, w * (1 - s / steps)); ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(nx, ny); ctx.stroke();
        x = nx; y = ny; ang += (r() - 0.5) * 0.08;
        for (let k = 0; k < nl; k++) needle(x, y, ang + (r() < 0.5 ? -1 : 1) * (0.5 + r() * 0.9), (7 + r() * 5) * (1 - 0.35 * s / steps));
        // second-order shoots make the spray full
        if (depth === 0 && s > 1 && s % 3 === 0 && s < steps - 1) shoot(x, y, ang + (s % 2 ? 1 : -1) * (0.6 + r() * 0.3), len * 0.38 * (1 - s / steps), w * 0.6, nl - 1, 1);
      }
    };
    for (let band = 0; band < 4; band++) {
      ctx.save(); ctx.beginPath(); ctx.rect(0, band * bh, S, bh); ctx.clip();
      const y0 = band * bh + bh / 2, hang = band === 3;
      let x = 4, y = y0, ang = (r() - 0.5) * 0.04;
      const len = S - 16, steps = Math.floor(len / 3);
      for (let s = 0; s < steps; s++) {
        const nx = x + Math.cos(ang) * 3, ny = y + Math.sin(ang) * 3;
        ctx.strokeStyle = '#35261a'; ctx.lineWidth = Math.max(1, 3.2 - s * 0.012); ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(nx, ny); ctx.stroke();
        x = nx; y = ny; ang += (r() - 0.5) * 0.03 - (y - y0) * 0.002;
        for (let k = 0; k < 2; k++) needle(x, y, ang + (r() < 0.5 ? -1 : 1) * (0.6 + r() * 0.8), 6 + r() * 4);
        // side shoots every few steps, alternating, shorter toward the tip; a gap now and then
        if (s > 2 && s % 3 === 0 && r() < 0.9) {
          const reach = (bh * 0.46) * (1 - 0.75 * s / steps) * (0.7 + 0.4 * r());
          const side = (s / 3) % 2 ? 1 : -1;
          const sa = ang + side * (hang ? 0.9 + r() * 0.3 : 0.75 + r() * 0.35);
          shoot(x, y, sa, reach / Math.abs(Math.sin(sa - ang) || 1), 1.6, hang ? 3 : 4);
        }
      }
      ctx.restore();
    }
  } else {
    // pine: four cells of needle tufts (paired long needles in brushy clusters), grey-green
    const half = S / 2;
    for (let cell = 0; cell < 4; cell++) {
      const ox = (cell % 2) * half, oy = Math.floor(cell / 2) * half;
      ctx.save(); ctx.beginPath(); ctx.rect(ox, oy, half, half); ctx.clip();
      const nt = cell === 3 ? 14 : 9;
      for (let t = 0; t < nt; t++) {
        const cx = ox + half * (0.25 + 0.5 * r()), cy = oy + half * (0.3 + 0.45 * r());
        ctx.strokeStyle = '#4a3322'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(ox + half / 2, oy + half); ctx.lineTo(cx, cy + 20); ctx.stroke();
        const n = 210;
        for (let k = 0; k < n; k++) {
          const a = -Math.PI / 2 + (r() - 0.5) * 2.6, L = half * (0.13 + 0.17 * r()) * (cell === 3 ? 0.8 : 1);
          const sx = cx + (r() - 0.5) * 16, sy = cy + 10 + (r() - 0.5) * 30;
          const g = 85 + r() * 50, light = r() < 0.15;
          ctx.strokeStyle = light ? `rgb(${110 + r() * 20},${140 + r() * 20},${100 + r() * 15})` : `rgb(${40 + r() * 20},${g},${50 + r() * 25})`; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(sx, sy); ctx.quadraticCurveTo(sx + Math.cos(a) * L * 0.5 + (r() - 0.5) * 6, sy + Math.sin(a) * L * 0.5, sx + Math.cos(a) * L, sy + Math.sin(a) * L); ctx.stroke();
        }
      }
      ctx.restore();
    }
  }
  return bleed(cv, S);
}

/** Fill the transparent pixels with the colour of the nearest leaves so mipmaps fade to leaf colour, not to black or white. */
function bleed(cv: any, S: number) {
  const ctx = cv.getContext('2d');
  const img = ctx.getImageData(0, 0, S, S); const d = img.data;
  const filled = new Uint8Array(S * S);
  for (let i = 0; i < S * S; i++) filled[i] = d[i * 4 + 3] > 8 ? 1 : 0;
  for (let pass = 0; pass < 24; pass++) {
    const next = filled.slice();
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      const i = y * S + x; if (filled[i]) continue;
      let rs = 0, gs = 0, bs = 0, n = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= S || yy >= S) continue;
        const j = yy * S + xx; if (!filled[j]) continue; rs += d[j * 4]; gs += d[j * 4 + 1]; bs += d[j * 4 + 2]; n++;
      }
      if (n) { d[i * 4] = rs / n; d[i * 4 + 1] = gs / n; d[i * 4 + 2] = bs / n; next[i] = 1; }
    }
    filled.set(next);
  }
  // whatever is still empty takes the cell's average colour
  let ar = 0, ag = 0, ab = 0, an = 0;
  for (let i = 0; i < S * S; i++) if (d[i * 4 + 3] > 8) { ar += d[i * 4]; ag += d[i * 4 + 1]; ab += d[i * 4 + 2]; an++; }
  for (let i = 0; i < S * S; i++) { if (!filled[i]) { d[i * 4] = ar / an; d[i * 4 + 1] = ag / an; d[i * 4 + 2] = ab / an; } if (d[i * 4 + 3] <= 8) d[i * 4 + 3] = 0; }
  ctx.putImageData(img, 0, 0);
  return cv;
}

/** Birch bark (own work): chalk-white papery bark, dark horizontal lenticels, black diamonds and a darker rough base band.
 *  Albedo only; the shader borrows a smooth bark's normal map for relief. One repeat is 1 m around and 1 m up. */
export function paintBirchBark(size = 512) {
  const cv = createCanvas(size, size), ctx = cv.getContext('2d'), r = rng32(5151);
  const img = ctx.createImageData(size, size), d = img.data;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const i = (y * size + x) * 4;
    const n = 0.5 + 0.5 * Math.sin(x * 0.05 + Math.sin(y * 0.02) * 3) * Math.sin(y * 0.031 + x * 0.004);
    const v = 222 + 18 * n - 10 * r();
    d[i] = v; d[i + 1] = v - 4; d[i + 2] = v - 12; d[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  // faint peach and grey patches where the outer layer has peeled
  for (let k = 0; k < 40; k++) { ctx.fillStyle = r() < 0.5 ? `rgba(215,170,140,${0.15 + r() * 0.2})` : `rgba(150,145,140,${0.12 + r() * 0.15})`; ctx.beginPath(); ctx.ellipse(r() * size, r() * size, 20 + r() * 60, 6 + r() * 14, 0, 0, 6.3); ctx.fill(); }
  // lenticels: thin dark horizontal dashes (they wrap left to right)
  for (let k = 0; k < 260; k++) {
    const x = r() * size, y = r() * size, w = 6 + r() * 34, h = 1 + r() * 2.2;
    ctx.fillStyle = `rgba(40,35,32,${0.45 + r() * 0.45})`;
    for (const ox of [-size, 0, size]) { ctx.beginPath(); ctx.ellipse(x + ox, y, w / 2, h / 2, 0, 0, 6.3); ctx.fill(); }
  }
  // black diamond scars where old branches fell
  for (let k = 0; k < 7; k++) {
    const x = r() * size, y = r() * size, w = 10 + r() * 22, h = 14 + r() * 28;
    ctx.fillStyle = `rgba(25,22,20,${0.7 + r() * 0.25})`;
    for (const ox of [-size, 0, size]) { ctx.beginPath(); ctx.moveTo(x + ox, y - h / 2); ctx.lineTo(x + ox + w / 2, y); ctx.lineTo(x + ox, y + h / 2); ctx.lineTo(x + ox - w / 2, y); ctx.closePath(); ctx.fill(); }
  }
  return cv;
}
