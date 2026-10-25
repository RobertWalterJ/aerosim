// Original 1980s-style cars typical of the UK and Canada (no real makes,
// badges or logos): supermini, hatchback, saloon, estate and panel van for the
// UK (white front and yellow rear plates); full-size sedan, woodgrain wagon,
// compact, pickup and minivan for Canada. Paint, sun fading and road-salt rust
// are seed driven. Front faces -Z, origin at the ground under the body centre.
//
// Same contract as the other environment assets: vehicle(seed, lod, opts) ->
// { geometry, material[], collider }. Materials are shared across all cars
// (paint, trim, bright metal, lenses, decals), so a parked fleet batches well.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { MeshBuilder, TRI_BUDGET, type LOD, type RGB, v3, hex, mix, mul, clamp01, mat4, cachedMaterial, boxColliderOf, type Collider } from './assetkit/AssetCore';
import { makeRnd, range, pick, chance, irange } from './assetkit/AssetRng';
import { mkCanvas, tex } from './ProceduralTextures';

export type Region = 'UK' | 'CA';
export type BodyType = 'saloon' | 'hatch' | 'estate' | 'van' | 'pickup' | 'minivan';

export interface VehicleStyle {
  name: string; region: Region; body: BodyType;
  /** overall length, width, height and wheelbase (m) */
  L: number; W: number; H: number; wb: number;
  overF: number; wheelR: number;
  /** hood height at the nose, belt line, rear deck height */
  hood: number; belt: number; deck: number;
  /** windshield base, roof start, roof end, rear-glass base, measured from the nose (m) */
  zA: number; zW: number; zR: number; zC: number;
  quadLights?: boolean; chrome?: boolean; woodgrain?: boolean; roundLights?: boolean;
}

export const VEHICLE_STYLES: readonly VehicleStyle[] = [
  { name: 'UK supermini', region: 'UK', body: 'hatch', L: 3.62, W: 1.58, H: 1.37, wb: 2.29, overF: 0.62, wheelR: 0.28, hood: 0.78, belt: 0.88, deck: 0.88, zA: 1.12, zW: 1.72, zR: 2.95, zC: 3.5, roundLights: true },
  { name: 'UK hatchback', region: 'UK', body: 'hatch', L: 3.99, W: 1.65, H: 1.38, wb: 2.40, overF: 0.75, wheelR: 0.29, hood: 0.76, belt: 0.88, deck: 0.88, zA: 1.28, zW: 1.92, zR: 3.05, zC: 3.86 },
  { name: 'UK saloon', region: 'UK', body: 'saloon', L: 4.35, W: 1.70, H: 1.40, wb: 2.60, overF: 0.82, wheelR: 0.30, hood: 0.78, belt: 0.90, deck: 0.96, zA: 1.40, zW: 2.02, zR: 3.12, zC: 3.62 },
  { name: 'UK estate', region: 'UK', body: 'estate', L: 4.45, W: 1.70, H: 1.45, wb: 2.60, overF: 0.82, wheelR: 0.30, hood: 0.78, belt: 0.90, deck: 0.90, zA: 1.40, zW: 2.02, zR: 4.3, zC: 4.42 },
  { name: 'UK panel van', region: 'UK', body: 'van', L: 4.40, W: 1.75, H: 1.95, wb: 2.60, overF: 0.70, wheelR: 0.31, hood: 0.92, belt: 1.02, deck: 1.02, zA: 1.0, zW: 1.55, zR: 4.36, zC: 4.4, roundLights: true },
  { name: 'Canadian full-size sedan', region: 'CA', body: 'saloon', L: 5.30, W: 1.95, H: 1.40, wb: 2.94, overF: 1.02, wheelR: 0.34, hood: 0.84, belt: 0.92, deck: 0.98, zA: 1.95, zW: 2.6, zR: 3.75, zC: 4.3, quadLights: true, chrome: true },
  { name: 'Canadian woodgrain wagon', region: 'CA', body: 'estate', L: 5.45, W: 1.98, H: 1.45, wb: 2.94, overF: 1.02, wheelR: 0.34, hood: 0.84, belt: 0.92, deck: 0.92, zA: 1.95, zW: 2.6, zR: 5.3, zC: 5.42, quadLights: true, chrome: true, woodgrain: true },
  { name: 'Canadian compact', region: 'CA', body: 'saloon', L: 4.50, W: 1.73, H: 1.34, wb: 2.54, overF: 0.88, wheelR: 0.31, hood: 0.78, belt: 0.88, deck: 0.94, zA: 1.48, zW: 2.1, zR: 3.25, zC: 3.75, quadLights: true },
  { name: 'Canadian pickup', region: 'CA', body: 'pickup', L: 5.30, W: 2.00, H: 1.82, wb: 3.33, overF: 0.88, wheelR: 0.38, hood: 1.10, belt: 1.18, deck: 1.18, zA: 1.55, zW: 2.05, zR: 2.75, zC: 2.95, quadLights: true, chrome: true },
  { name: 'Canadian minivan', region: 'CA', body: 'minivan', L: 4.50, W: 1.83, H: 1.64, wb: 2.85, overF: 0.80, wheelR: 0.32, hood: 0.86, belt: 0.98, deck: 0.98, zA: 0.95, zW: 1.62, zR: 4.40, zC: 4.48, quadLights: true },
];

export const VEHICLE_PAINT: Record<Region, number[]> = {
  UK: [0x7a2e2a, 0x2d3e5c, 0xa8a39a, 0xc9b48a, 0x5a4632, 0x224d33, 0xc8c4b8, 0xa8352c, 0x353537, 0xb89a3a, 0x6e8aa0],
  CA: [0x7d5a3a, 0xd6cdb8, 0x2c4a6e, 0x8a1f24, 0x9aa3a8, 0x4a5a3a, 0xe0dccd, 0x5a6e8a, 0xc0a070, 0x3c2e26],
};

// ---------------------------------------------------------------- materials

const MAT_KEYS = ['paint', 'trim', 'bright', 'lens', 'decal'] as const;
type MatKey = (typeof MAT_KEYS)[number];

export function vehicleMaterials(): Record<MatKey, THREE.Material> {
  return {
    paint: cachedMaterial('veh-paint', () => new THREE.MeshPhysicalMaterial({ name: 'veh-paint', vertexColors: true, roughness: 0.42, metalness: 0, clearcoat: 0.7, clearcoatRoughness: 0.14 })),
    trim: cachedMaterial('veh-trim', () => new THREE.MeshStandardMaterial({ name: 'veh-trim', vertexColors: true, roughness: 0.78, metalness: 0 })),
    bright: cachedMaterial('veh-bright', () => new THREE.MeshStandardMaterial({ name: 'veh-bright', vertexColors: true, roughness: 0.2, metalness: 1 })),
    lens: cachedMaterial('veh-lens', () => new THREE.MeshPhysicalMaterial({ name: 'veh-lens', vertexColors: true, roughness: 0.12, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.05 })),
    decal: cachedMaterial('veh-decal', () => new THREE.MeshStandardMaterial({ name: 'veh-decal', map: decalAtlas(), alphaTest: 0.5, roughness: 0.55, metalness: 0, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -4 })),
  };
}

// ---------------------------------------------------------------- decal atlas

interface Rect { u0: number; v0: number; u1: number; v1: number; }
const AT = 1024;
const rectPx = (x: number, y: number, w: number, h: number): Rect => ({ u0: x / AT, v0: 1 - (y + h) / AT, u1: (x + w) / AT, v1: 1 - y / AT });
/** plates: index 0..7 UK front, 8..15 UK rear, 16..23 Canadian */
const plateRect = (i: number): Rect => rectPx((i % 4) * 256, Math.floor(i / 4) * 64, 248, 56);
const rustRect = (i: number): Rect => rectPx(i * 128, 448, 128, 128);
const WOOD = rectPx(0, 600, 1024, 120);
const badgeRect = (i: number): Rect => rectPx((i % 8) * 128, 740, 120, 36);

let atlas: THREE.Texture | null = null;
function decalAtlas(): THREE.Texture {
  if (atlas) return atlas;
  const c = mkCanvas(AT, AT), g = c.getContext('2d')!;
  g.clearRect(0, 0, AT, AT);
  const r = makeRnd(1985, 1);
  const L = 'ABCDEFGHJKLMNPRSTVWXY';
  for (let i = 0; i < 24; i++) {
    const x = (i % 4) * 256, y = Math.floor(i / 4) * 64, w = 248, h = 56;
    const uk = i < 16, rear = i >= 8 && i < 16;
    g.fillStyle = uk ? (rear ? '#e8c22a' : '#eeeee8') : '#f2f2ee';
    g.fillRect(x, y, w, h);
    g.strokeStyle = '#111'; g.lineWidth = 2; g.strokeRect(x + 2, y + 2, w - 4, h - 4);
    g.textAlign = 'center'; g.textBaseline = 'middle';
    if (uk) {
      // 1983-2001 style: year letter prefix, numbers, three letters (fictional)
      const t = `${L[irange(r, 0, 4)]}${irange(r, 10, 999)} ${L[irange(r, 0, L.length - 1)]}${L[irange(r, 0, L.length - 1)]}${L[irange(r, 0, L.length - 1)]}`;
      g.fillStyle = '#111'; g.font = 'bold 40px sans-serif'; g.fillText(t, x + w / 2, y + h / 2 + 2);
    } else {
      g.fillStyle = '#1d3f8a'; g.font = 'bold 12px sans-serif'; g.fillText('ONTARIO', x + w / 2, y + 11);
      const t = `${L[irange(r, 0, L.length - 1)]}${L[irange(r, 0, L.length - 1)]}${L[irange(r, 0, L.length - 1)]} ${irange(r, 100, 999)}`;
      g.font = 'bold 34px sans-serif'; g.fillText(t, x + w / 2, y + h / 2 + 6);
    }
  }
  // rust patches: blistered brown with ragged alpha edges
  for (let i = 0; i < 8; i++) {
    const x0 = i * 128, y0 = 448;
    for (let k = 0; k < 220; k++) {
      const a = r() * Math.PI * 2, d = Math.pow(r(), 0.7) * 54;
      const px = x0 + 64 + Math.cos(a) * d * (i % 2 ? 1.4 : 1), py = y0 + 64 + Math.sin(a) * d * 0.7;
      const s = 3 + r() * 9;
      g.fillStyle = pick(r, ['#5a2e16', '#7a3e1a', '#8f4f22', '#3e2414', '#a2622e']);
      g.globalAlpha = 0.6 + r() * 0.4;
      g.beginPath(); g.arc(px, py, s, 0, Math.PI * 2); g.fill();
    }
    g.globalAlpha = 1;
  }
  // woodgrain side panel with a light frame (wagon)
  {
    const y0 = 600;
    g.fillStyle = '#6a4224'; g.fillRect(0, y0, 1024, 120);
    for (let k = 0; k < 90; k++) {
      g.strokeStyle = pick(r, ['#4e2e18', '#7a4e2c', '#8a5a34', '#3e2412']);
      g.lineWidth = 1 + r() * 3; g.beginPath();
      const yy = y0 + r() * 120; g.moveTo(0, yy);
      for (let xx = 0; xx <= 1024; xx += 64) g.lineTo(xx, yy + Math.sin(xx * 0.01 + k) * 4 + (r() - 0.5) * 3);
      g.stroke();
    }
    g.strokeStyle = '#c9b48a'; g.lineWidth = 8; g.strokeRect(4, y0 + 4, 1016, 112);
  }
  // trim badges (generic)
  ['GL', 'L', '1.6', 'V6', 'XL', '2.0i', 'ESTATE', 'DIESEL'].forEach((t, i) => {
    g.fillStyle = '#d8d8d4'; g.font = 'bold 26px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(t, (i % 8) * 128 + 60, 740 + 18);
  });
  atlas = tex(c, true, false);
  atlas.name = 'vehicle-decals';
  return atlas;
}

// ---------------------------------------------------------------- geometry helpers

type P2 = [number, number];

/** Offset a convex polygon inward by d (counter-clockwise input). */
function insetConvex(poly: P2[], d: number): P2[] {
  const n = poly.length, lines: { p: P2; t: P2 }[] = [];
  for (let i = 0; i < n; i++) {
    const a = poly[i]!, b = poly[(i + 1) % n]!;
    const tx = b[0] - a[0], ty = b[1] - a[1], l = Math.hypot(tx, ty) || 1;
    const nx = -ty / l, ny = tx / l; // left normal = inward for CCW
    lines.push({ p: [a[0] + nx * d, a[1] + ny * d], t: [tx / l, ty / l] });
  }
  const out: P2[] = [];
  for (let i = 0; i < n; i++) {
    const A = lines[(i + n - 1) % n]!, B = lines[i]!;
    const den = A.t[0] * B.t[1] - A.t[1] * B.t[0];
    if (Math.abs(den) < 1e-6) { out.push(B.p); continue; }
    const s = ((B.p[0] - A.p[0]) * B.t[1] - (B.p[1] - A.p[1]) * B.t[0]) / den;
    out.push([A.p[0] + A.t[0] * s, A.p[1] + A.t[1] * s]);
  }
  return out;
}
/** Keep the part of a polygon with x between lo and hi. */
function clipX(poly: P2[], lo: number, hi: number): P2[] {
  const clip = (pts: P2[], keep: (p: P2) => boolean, edge: number): P2[] => {
    const out: P2[] = [];
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i]!, b = pts[(i + 1) % pts.length]!;
      const ia = keep(a), ib = keep(b);
      if (ia) out.push(a);
      if (ia !== ib) { const t = (edge - a[0]) / (b[0] - a[0]); out.push([edge, a[1] + (b[1] - a[1]) * t]); }
    }
    return out;
  };
  return clip(clip(poly, (p) => p[0] >= lo, lo), (p) => p[0] <= hi, hi);
}

const shapeOf = (pts: P2[]): THREE.Shape => new THREE.Shape(pts.map(([x, y]) => new THREE.Vector2(x, y)));

// ---------------------------------------------------------------- build

export interface VehicleOptions {
  style?: number;
  /** paint as sRGB hex (default: seed-picked period colour) */
  paint?: number;
  /** 0 = showroom, 1 = salt-belt survivor */
  wear?: number;
}

export interface VehicleResult { geometry: THREE.BufferGeometry; material: THREE.Material[]; collider: Collider; style: VehicleStyle; }

/**
 * Build one car. Geometry groups map to the five shared materials (paint,
 * trim, bright metal, lenses, decals); each LOD is one InstancedMesh-ready
 * geometry with at most five draw calls.
 */
export function vehicle(seed: number, lod: LOD, opts: VehicleOptions = {}): VehicleResult {
  const si = (opts.style ?? Math.abs(seed)) % VEHICLE_STYLES.length;
  const S = VEHICLE_STYLES[si]!;
  const rnd = makeRnd(seed, 8800 + si);
  const wear = opts.wear ?? range(rnd, 0.1, 0.9);
  const paint = hex(opts.paint ?? pick(rnd, VEHICLE_PAINT[S.region]));
  const second = chance(rnd, S.body === 'pickup' ? 0.6 : S.region === 'CA' ? 0.25 : 0.05) ? hex(pick(rnd, VEHICLE_PAINT[S.region])) : null;
  const vinyl = S.body === 'saloon' && S.region === 'CA' && chance(rnd, 0.5);
  const fade = clamp01(wear * 0.45 + (rnd() - 0.5) * 0.15);
  const B: Record<MatKey, MeshBuilder> = { paint: new MeshBuilder(), trim: new MeshBuilder(), bright: new MeshBuilder(), lens: new MeshBuilder(), decal: new MeshBuilder() };
  const zN = (z: number): number => -S.L / 2 + z; // distance-from-nose -> car z
  const zFA = zN(S.overF), zRA = zFA + S.wb;
  const ra = S.wheelR + 0.05;
  const clear = 0.17 + (S.body === 'pickup' ? 0.08 : 0);
  const BLACK = hex(0x151515), GLASS = hex(0x10161c), CHROME = hex(0xd8dadc), RUBBER = hex(0x18181a);
  const faded = (c: RGB, n: THREE.Vector3): RGB => mix(c, mix(c, hex(0xd8d4c8), 0.35), fade * Math.max(0, n.y) * 0.8);

  // --- lower body: side profile extruded across the width, wheel arches cut out
  {
    const arch = (cz: number, pts: P2[]): void => {
      // circle around the axle (height = wheel radius), from the front sill round to the rear sill
      const n = lod === 0 ? 10 : lod === 1 ? 6 : 3;
      const dl = Math.asin(Math.min(1, (S.wheelR - clear) / ra));
      for (let i = 0; i <= n; i++) { const a = Math.PI + dl - (i / n) * (Math.PI + 2 * dl); pts.push([cz + Math.cos(a) * ra, S.wheelR + Math.sin(a) * ra]); }
    };
    const rearTop = S.body === 'saloon' ? S.deck : S.body === 'pickup' ? S.belt * 0.55 : S.belt;
    const prof: P2[] = [];
    prof.push([zN(0.02), clear + 0.05]);
    arch(zFA, prof);
    arch(zRA, prof);
    prof.push([zN(S.L - 0.03), clear + 0.08], [zN(S.L), clear + 0.25], [zN(S.L), rearTop - 0.05], [zN(S.L - 0.06), rearTop]);
    if (S.body === 'saloon') prof.push([zN(S.zC + 0.05), S.deck - 0.01]);
    if (S.body === 'pickup') prof.push([zN(S.zC + 0.06), rearTop], [zN(S.zC + 0.06), S.belt]);
    prof.push([zN(S.zA), S.belt], [zN(0.15), S.hood + 0.02], [zN(0), S.hood - 0.06], [zN(-0.01), clear + 0.3]);
    // shape coords: x = -z so that the extrusion ends up with the nose at -Z
    const sh = shapeOf(prof.map(([z, y]) => [-z, y]).reverse() as P2[]);
    const bev = lod === 2 ? 0 : 0.035;
    const g = new THREE.ExtrudeGeometry(sh, { depth: S.W - bev * 2, bevelEnabled: lod < 2, bevelThickness: bev, bevelSize: bev, bevelSegments: lod === 0 ? 2 : 1, curveSegments: 4 });
    g.rotateY(Math.PI / 2);
    g.translate(-S.W / 2 + bev, 0, 0);
    const flatG = g.index ? g.toNonIndexed() : g; flatG.computeVertexNormals(); if (flatG !== g) g.dispose();
    const m = B.paint.appendGeometry(flatG);
    flatG.dispose();
    B.paint.paint(m, (p, n) => {
      if (n.y < -0.6) return mul(BLACK, 0.7); // underbody
      const inArch = (Math.abs(p.z - zFA) < ra + 0.02 || Math.abs(p.z - zRA) < ra + 0.02) && p.y < S.wheelR + ra + 0.01 && Math.abs(n.x) < 0.5 && n.y < 0.3;
      if (inArch) return BLACK; // wheel-well liner
      let c = second && p.y < S.belt * 0.62 ? second : paint;
      c = faded(c, n);
      return c;
    });
  }

  // --- greenhouse (cab for the pickup)
  const roofH = S.H - 0.02;
  const gw = S.W - 0.14;
  const tumble = (x: number, y: number): number => x * (1 - 0.1 * clamp01((y - S.belt) / (roofH - S.belt)));
  const ghRear = S.body === 'saloon' ? S.deck : S.belt;
  const gh: P2[] = [[zN(S.zA), S.belt], [zN(S.zW), roofH], [zN(S.zR), roofH], [zN(S.zC), ghRear]];
  if (S.body === 'pickup' || S.body === 'van' || S.body === 'estate' || S.body === 'minivan') gh[3] = [zN(S.zC), S.belt];
  {
    const sh = shapeOf(gh.map(([z, y]) => [-z, y]).reverse() as P2[]);
    const g = new THREE.ExtrudeGeometry(sh, { depth: gw - 0.06, bevelEnabled: lod < 2, bevelThickness: 0.03, bevelSize: 0.03, bevelSegments: 1, curveSegments: 2 });
    g.rotateY(Math.PI / 2);
    g.translate(-gw / 2 + 0.03, 0, 0);
    const P = g.getAttribute('position') as THREE.BufferAttribute;
    for (let i = 0; i < P.count; i++) P.setX(i, tumble(P.getX(i), P.getY(i)));
    const flatG = g.index ? g.toNonIndexed() : g; flatG.computeVertexNormals(); if (flatG !== g) g.dispose();
    const m = B.paint.appendGeometry(flatG);
    flatG.dispose();
    B.paint.paint(m, (p, n) => {
      if (n.y > 0.85) return vinyl ? hex(0x2a2826) : faded(paint, n);
      if (Math.abs(n.x) > 0.6) return faded(paint, n); // pillars; windows are overlays
      if (p.y < S.belt + 0.03) return faded(paint, n);
      return GLASS; // windshield and back glass
    });
  }
  // side windows with black rubber surrounds
  {
    const sidePoly = gh.map(([z, y]) => [z, y] as P2);
    // CCW in (z, y) with +z rearward: reverse if needed
    let area = 0;
    for (let i = 0; i < sidePoly.length; i++) { const a = sidePoly[i]!, b = sidePoly[(i + 1) % sidePoly.length]!; area += a[0] * b[1] - b[0] * a[1]; }
    const ccw = area > 0 ? sidePoly : [...sidePoly].reverse();
    const frame = insetConvex(ccw, 0.045), glass = insetConvex(ccw, 0.065);
    const zB = zN(S.zA + (S.body === 'hatch' && S.L < 3.8 ? (S.zR - S.zA) * 0.62 : (S.zR - S.zA) * 0.48));
    const windows: [number, number][] = [];
    if (S.body === 'van') windows.push([-99, zN(S.zW + 0.3)]);
    else if (S.body === 'pickup') windows.push([-99, 99]);
    else {
      windows.push([-99, zB - 0.05]);
      const cEnd = S.body === 'saloon' ? zN(S.zR - 0.15) : 99;
      if (S.body === 'estate' || S.body === 'minivan') { const zD = zN(S.zR - (S.zR - S.zA) * 0.22); windows.push([zB + 0.05, zD - 0.04], [zD + 0.04, 99]); }
      else windows.push([zB + 0.05, cEnd]);
    }
    for (const side of [-1, 1]) {
      for (const [lo, hi] of windows) {
        for (const [poly, mat, out, col] of [[frame, 'trim', 0.004, RUBBER], [glass, 'paint', 0.007, GLASS]] as const) {
          const clipped = clipX(poly, lo, hi);
          if (clipped.length < 3) continue;
          const sg = new THREE.ShapeGeometry(shapeOf(clipped), 1);
          // shape (x = z, y = y) -> side plane at x = +-half width (with tumblehome)
          const P = sg.getAttribute('position') as THREE.BufferAttribute;
          for (let i = 0; i < P.count; i++) {
            const z = P.getX(i), y = P.getY(i);
            P.setXYZ(i, side * (tumble(gw / 2, y) + out), y, z);
          }
          if (side > 0) { const I = sg.index!; for (let t = 0; t < I.count; t += 3) { const tmp = I.getX(t + 1); I.setX(t + 1, I.getX(t + 2)); I.setX(t + 2, tmp); } }
          sg.computeVertexNormals();
          const mm = B[mat].appendGeometry(sg);
          B[mat].paint(mm, () => col);
          sg.dispose();
        }
      }
    }
  }

  // --- pickup bed
  if (S.body === 'pickup') {
    const z0 = zN(S.zC + 0.08), z1 = zN(S.L - 0.02), y0 = S.belt * 0.55, y1 = S.belt;
    const bed = (sx: number, sy: number, sz: number, x: number, y: number, z: number, c: RGB): void => {
      const mm = B.paint.appendGeometry(new THREE.BoxGeometry(sx, sy, sz), mat4(v3(x, y, z)));
      B.paint.paint(mm, (_p, n) => faded(c, n));
    };
    bed(0.06, y1 - y0, z1 - z0, -S.W / 2 + 0.03, (y0 + y1) / 2, (z0 + z1) / 2, second ?? paint);
    bed(0.06, y1 - y0, z1 - z0, S.W / 2 - 0.03, (y0 + y1) / 2, (z0 + z1) / 2, second ?? paint);
    bed(S.W - 0.12, y1 - y0, 0.05, 0, (y0 + y1) / 2, z1 - 0.025, paint);
    if (lod < 2) bed(S.W - 0.12, 0.03, z1 - z0, 0, y0 + 0.1, (z0 + z1) / 2, mul(BLACK, 1.4));
  }

  // --- wheels
  const track = S.W - 0.22;
  for (const z of [zFA, zRA]) for (const side of [-1, 1]) {
    const segs = lod === 0 ? 20 : lod === 1 ? 10 : 6;
    const R = S.wheelR, Wt = 0.19 + (S.region === 'CA' ? 0.03 : 0);
    if (lod === 2) {
      const cg = new THREE.CylinderGeometry(R, R, Wt, segs, 1, true);
      const mm = B.trim.appendGeometry(cg, mat4(v3(side * track / 2, R, z), new THREE.Euler(0, 0, Math.PI / 2)));
      B.trim.paint(mm, () => RUBBER);
      continue;
    }
    const tire = new THREE.LatheGeometry([[R * 0.66, -Wt / 2], [R * 0.93, -Wt / 2], [R, -Wt * 0.32], [R, Wt * 0.32], [R * 0.93, Wt / 2], [R * 0.66, Wt / 2]].map(([r, y]) => new THREE.Vector2(r, y)), segs);
    const mm = B.trim.appendGeometry(tire, mat4(v3(side * track / 2, R, z), new THREE.Euler(0, 0, Math.PI / 2)));
    B.trim.paint(mm, () => RUBBER);
    // inner face of the wheel (brake drum side) so the tyre never reads as a hollow ring
    const inner = B.trim.appendGeometry(new THREE.CircleGeometry(R * 0.68, segs), mat4(v3(side * (track / 2 - Wt / 2 + 0.01), R, z), new THREE.Euler(0, -side * Math.PI / 2, 0)));
    B.trim.paint(inner, () => mul(BLACK, 1.3));
    const cap = S.chrome || chance(rnd, 0.5);
    const hub = new THREE.LatheGeometry([[0.001, 0.012], [R * 0.3, 0.01], [R * 0.45, 0.0], [R * 0.62, -0.01], [R * 0.67, -0.02]].map(([r, y]) => new THREE.Vector2(r, y)), segs);
    const hm = (cap ? B.bright : B.trim).appendGeometry(hub, mat4(v3(side * (track / 2 + Wt / 2 - 0.01), R, z), new THREE.Euler(0, 0, -side * Math.PI / 2)));
    (cap ? B.bright : B.trim).paint(hm, (p) => {
      const r = Math.hypot(p.y - R, p.z - z);
      if (!cap) return r < R * 0.2 ? hex(0x7a7c80) : hex(0x5a5c60); // painted steel wheel
      return r > R * 0.5 && r < R * 0.58 ? hex(0x6a6c70) : CHROME;
    });
  }

  // --- bumpers, grille, lights, plates, details
  const bumperMat: MatKey = S.chrome ? 'bright' : 'trim';
  const bumperCol = S.chrome ? CHROME : hex(0x222224);
  const yb = clear + 0.2;
  for (const [z, dir] of [[zN(-0.02), -1], [zN(S.L + 0.02), 1]] as const) {
    const mm = B[bumperMat].appendGeometry(new THREE.BoxGeometry(S.W + 0.02, 0.14, 0.12), mat4(v3(0, yb, z + dir * 0.0)));
    B[bumperMat].paint(mm, () => bumperCol);
  }
  if (lod < 2) {
    // grille
    const gH = Math.max(0.12, S.hood - yb - 0.12), gWd = S.W * (S.quadLights ? 0.42 : 0.5);
    const gy = yb + 0.08 + gH / 2;
    const gm = B.trim.appendGeometry(new THREE.BoxGeometry(gWd, gH, 0.03), mat4(v3(0, gy, zN(-0.044))));
    B.trim.paint(gm, () => BLACK);
    if (lod === 0) for (let k = 0; k < 4; k++) {
      const sm = (S.chrome ? B.bright : B.trim).appendGeometry(new THREE.BoxGeometry(gWd - 0.02, 0.012, 0.02), mat4(v3(0, gy - gH / 2 + (k + 0.5) * gH / 4, zN(-0.058))));
      (S.chrome ? B.bright : B.trim).paint(sm, () => (S.chrome ? CHROME : hex(0x2a2a2c)));
    }
    // headlights
    const hy = gy;
    const lightW = S.quadLights ? 0.14 : S.roundLights ? 0.17 : 0.24;
    for (const side of [-1, 1]) {
      const xs = side * (gWd / 2 + 0.03 + lightW / 2);
      const n = S.quadLights ? 2 : 1;
      for (let k = 0; k < n; k++) {
        const x = xs + side * k * (lightW + 0.02);
        const geo = S.roundLights ? new THREE.CylinderGeometry(lightW / 2, lightW / 2, 0.03, lod === 0 ? 14 : 8).rotateX(Math.PI / 2) : new THREE.BoxGeometry(lightW, Math.min(0.13, gH), 0.03);
        const lm = B.lens.appendGeometry(geo, mat4(v3(x, hy, zN(-0.046))));
        B.lens.paint(lm, () => hex(0xc8ccd0));
      }
      // amber indicator under or beside the headlamp
      const im = B.lens.appendGeometry(new THREE.BoxGeometry(0.1, 0.05, 0.03), mat4(v3(side * (S.W / 2 - 0.09), yb + 0.11, zN(-0.042))));
      B.lens.paint(im, () => hex(0xc8781e));
      // tail lights: red band with amber indicator and white reverse lamp
      const ty = S.body === 'saloon' ? S.deck - 0.16 : S.belt - 0.12;
      const tl = B.lens.appendGeometry(new THREE.BoxGeometry(S.W * 0.28, 0.12, 0.03), mat4(v3(side * (S.W / 2 - S.W * 0.15 - 0.03), ty, zN(S.L + 0.046))));
      B.lens.paint(tl, (p) => {
        const f = (Math.abs(p.x) - (S.W / 2 - S.W * 0.29)) / (S.W * 0.28);
        return f > 0.7 ? hex(0xb8701a) : f < 0.18 ? hex(0xd8d8d0) : hex(0x8a1012);
      });
    }
    // plates (UK: white front, yellow rear; Canada: rear only on most, both here)
    const pi = irange(rnd, 0, 7);
    const plates: [Rect, number, number][] = S.region === 'UK' ? [[plateRect(pi), zN(-0.082), -1], [plateRect(8 + pi), zN(S.L + 0.047), 1]] : [[plateRect(16 + pi), zN(-0.082), -1], [plateRect(16 + pi), zN(S.L + 0.047), 1]];
    for (const [r, z, dir] of plates) {
      const pw = S.region === 'UK' ? 0.52 : 0.31, ph = S.region === 'UK' ? 0.112 : 0.155;
      const g = new THREE.PlaneGeometry(pw, ph);
      if (dir < 0) g.rotateY(Math.PI);
      const uv = g.getAttribute('uv') as THREE.BufferAttribute;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, r.u0 + (r.u1 - r.u0) * uv.getX(i), r.v0 + (r.v1 - r.v0) * uv.getY(i));
      const mm = B.decal.appendGeometry(g, mat4(v3(0, yb + (dir < 0 ? 0 : 0.18), z + dir * 0.002)));
      B.decal.paint(mm, () => [0.85, 0.85, 0.85]);
    }
    // woodgrain side panels on the wagon
    if (S.woodgrain) for (const side of [-1, 1]) {
      const z0 = zFA + ra + 0.05, z1 = zRA - ra - 0.05;
      const g = new THREE.PlaneGeometry(z1 - z0 + ra * 1.6, S.belt - clear - 0.28);
      g.rotateY(side * Math.PI / 2);
      const uv = g.getAttribute('uv') as THREE.BufferAttribute;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, WOOD.u0 + (WOOD.u1 - WOOD.u0) * uv.getX(i), WOOD.v0 + (WOOD.v1 - WOOD.v0) * uv.getY(i));
      const mm = B.decal.appendGeometry(g, mat4(v3(side * (S.W / 2 + 0.004), (S.belt + clear + 0.28) / 2 + 0.02, (z0 + z1) / 2)));
      B.decal.paint(mm, () => [0.8, 0.8, 0.8]);
    }
    // road-salt rust: arch lips, sills, door bottoms
    const nr = Math.round(wear * (S.region === 'CA' ? 10 : 7));
    for (let k = 0; k < nr; k++) {
      const side = rnd() < 0.5 ? -1 : 1;
      const atArch = rnd() < 0.6;
      const z = atArch ? (rnd() < 0.5 ? zFA : zRA) + (rnd() - 0.5) * ra * 1.6 : range(rnd, zFA + ra, zRA - ra);
      const y = atArch ? clear + ra * range(rnd, 0.7, 1.15) : clear + range(rnd, 0.08, 0.2);
      const s = range(rnd, 0.08, 0.22) * (0.5 + wear);
      const g = new THREE.PlaneGeometry(s, s * 0.7);
      g.rotateY(side * Math.PI / 2);
      const r = rustRect(irange(rnd, 0, 7));
      const uv = g.getAttribute('uv') as THREE.BufferAttribute;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, r.u0 + (r.u1 - r.u0) * uv.getX(i), r.v0 + (r.v1 - r.v0) * uv.getY(i));
      const mm = B.decal.appendGeometry(g, mat4(v3(side * (S.W / 2 + 0.006), y, z)));
      B.decal.paint(mm, () => [0.9, 0.9, 0.9]);
    }
    if (lod === 0) {
      // trim badge on the tail
      const r = badgeRect(irange(rnd, 0, 7));
      const g = new THREE.PlaneGeometry(0.14, 0.04);
      const uv = g.getAttribute('uv') as THREE.BufferAttribute;
      for (let i = 0; i < uv.count; i++) uv.setXY(i, r.u0 + (r.u1 - r.u0) * uv.getX(i), r.v0 + (r.v1 - r.v0) * uv.getY(i));
      const bm = B.decal.appendGeometry(g, mat4(v3(S.W * 0.28, (S.body === 'saloon' ? S.deck : S.belt) - 0.05, zN(S.L + 0.048))));
      B.decal.paint(bm, () => [0.9, 0.9, 0.9]);
      // door seams, handles, rubbing strips, mirrors, wipers, aerial
      const zB = zN(S.zA + (S.zR - S.zA) * 0.48);
      const seams = S.body === 'van' || S.body === 'pickup' || (S.body === 'hatch' && S.L < 3.8) ? [zN(S.zA + 0.05), zB + 0.15] : [zN(S.zA + 0.05), zB, zRA - ra - 0.04];
      for (const side of [-1, 1]) {
        for (const z of seams) {
          const sm = B.trim.appendGeometry(new THREE.BoxGeometry(0.006, S.belt - clear - 0.12, 0.006), mat4(v3(side * (S.W / 2 + 0.001), (S.belt + clear + 0.06) / 2, z)));
          B.trim.paint(sm, () => BLACK);
        }
        for (const z of seams.slice(1)) {
          const hm = (S.chrome ? B.bright : B.trim).appendGeometry(new THREE.BoxGeometry(0.02, 0.025, 0.12), mat4(v3(side * (S.W / 2 + 0.01), S.belt - 0.1, z - 0.12)));
          (S.chrome ? B.bright : B.trim).paint(hm, () => (S.chrome ? CHROME : BLACK));
        }
        const strip = (S.chrome ? B.bright : B.trim).appendGeometry(new THREE.BoxGeometry(0.012, S.chrome ? 0.02 : 0.05, zRA - zFA - ra * 2.1), mat4(v3(side * (S.W / 2 + 0.006), S.chrome ? S.belt - 0.03 : clear + 0.28, (zFA + zRA) / 2)));
        (S.chrome ? B.bright : B.trim).paint(strip, () => (S.chrome ? CHROME : hex(0x202022)));
        const mir = B.trim.appendGeometry(new THREE.BoxGeometry(0.06, 0.08, 0.11), mat4(v3(side * (S.W / 2 + 0.05), S.belt + 0.1, zN(S.zA + 0.12))));
        B.trim.paint(mir, () => BLACK);
      }
      for (const side of [-0.22, 0.2]) {
        const wm = B.trim.appendGeometry(new THREE.BoxGeometry(0.42, 0.012, 0.02), mat4(v3(side * S.W, S.belt + 0.03, zN(S.zA + 0.04)), new THREE.Euler(0.5, 0, 0.12)));
        B.trim.paint(wm, () => BLACK);
      }
      const am = B.bright.appendGeometry(new THREE.CylinderGeometry(0.003, 0.003, 0.75, 4), mat4(v3(-S.W / 2 + 0.12, S.hood + 0.35, zN(S.zA - 0.25)), new THREE.Euler(0.25, 0, 0)));
      B.bright.paint(am, () => CHROME);
    }
  }

  // ground-contact AO on body and trim
  for (const k of ['paint', 'trim'] as const) B[k].shade({ v: 0, i: 0 }, (p) => 0.6 + 0.4 * clamp01((p.y - 0.04) / 0.28));
  // budget guard: simplify by dropping decals first if needed
  let total = MAT_KEYS.reduce((a, k) => a + B[k].triangleCount, 0);
  if (total > TRI_BUDGET[lod]) { B.decal.rollback({ v: 0, i: 0 }); total = MAT_KEYS.reduce((a, k) => a + B[k].triangleCount, 0); }
  // merge into one geometry with groups (one per non-empty material)
  const geos: THREE.BufferGeometry[] = [], mats: THREE.Material[] = [];
  const M = vehicleMaterials();
  for (const k of MAT_KEYS) {
    if (B[k].triangleCount === 0) continue;
    if (k !== 'decal') B[k].boxUV({ v: 0, i: 0 }, 1);
    const g = B[k].build();
    g.deleteAttribute('aPolish');
    geos.push(g); mats.push(M[k]);
  }
  const geometry = mergeGeometries(geos, true)!;
  geometry.computeBoundingBox(); geometry.computeBoundingSphere();
  for (const g of geos) g.dispose();
  return { geometry, material: mats, collider: boxColliderOf(geometry), style: S };
}
