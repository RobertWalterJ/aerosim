// Shared drone parts and plumbing: geometry normalisation, per-material
// batching with a voxel ambient-occlusion bake, a mass model for centre of
// mass and inertia, lofts and lathes, airfoil propellers and blur discs,
// brushless motors, fasteners, cables, straps, zip ties, antennas and LEDs.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { mulberry32 as rng } from '../../util/noise';

export type Lod = 0 | 1;
export type RGB = [number, number, number];
export type V3 = THREE.Vector3;
export const v3 = (x = 0, y = 0, z = 0): V3 => new THREE.Vector3(x, y, z);
export const mm = (x: number): number => x / 1000;

/** sRGB hex -> linear RGB tuple (vertex colors are linear). */
export function lin(hex: number): RGB {
  const c = new THREE.Color().setHex(hex, THREE.SRGBColorSpace);
  return [c.r, c.g, c.b];
}
export const mixRGB = (a: RGB, b: RGB, t: number): RGB => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
export const scaleRGB = (a: RGB, s: number): RGB => [a[0] * s, a[1] * s, a[2] * s];
export const colorToRGB = (c: THREE.Color): RGB => [c.r, c.g, c.b];

// ---------------------------------------------------------------- result types

export interface LedHandle {
  name: string;
  material: THREE.MeshBasicMaterial;
  /** current base color (linear) and intensity; set() updates the material */
  color: THREE.Color;
  intensity: number;
  /** intensity is clamped to the bloom-friendly range 0..6 */
  set(color?: THREE.ColorRepresentation, intensity?: number): void;
}

export interface GimbalPivots { yaw: THREE.Object3D; pitch: THREE.Object3D; roll: THREE.Object3D; }

export interface DronePhysics {
  massKg: number;
  /** where the centre of mass sits in the design frame; the returned root is already shifted so this is the origin */
  comDesign: V3;
  /** inertia tensor about the COM in body axes (kg m²): Ixx, Iyy, Izz, Ixy, Ixz, Iyz */
  inertia: [number, number, number, number, number, number];
  /** rotor hub centres relative to the COM (order 0 FR, 1 RR, 2 RL, 3 FL) */
  motorPositions: V3[];
  propRadius: number;
  /** +1 = counter-clockwise seen from above (positive rotation about +Y), -1 = clockwise */
  spin: [number, number, number, number];
}

export interface DroneStats { triangles: number; staticDrawCalls: number; dynamicDrawCalls: number; ledDrawCalls: number; }

export interface DroneBuild {
  root: THREE.Group;
  rotors: [THREE.Object3D, THREE.Object3D, THREE.Object3D, THREE.Object3D];
  gimbal?: GimbalPivots;
  leds: LedHandle[];
  physics: DronePhysics;
  stats: DroneStats;
}

export interface DroneVariant {
  /** 'hotPink' | 'lime' | 'orange' or any color */
  accent?: AccentName | THREE.ColorRepresentation;
  /** 0 = factory fresh, 1 = beaten */
  wear?: number;
  /** small random variation: decal placement, scuffs, serials */
  seed?: number;
}
export type AccentName = 'hotPink' | 'lime' | 'orange';
export const ACCENTS: Record<AccentName, number> = { hotPink: 0xff2d8a, lime: 0x8cff1a, orange: 0xff6a00 };
export function accentColor(a: DroneVariant['accent'], fallback: AccentName): THREE.Color {
  if (a === undefined) return new THREE.Color().setHex(ACCENTS[fallback], THREE.SRGBColorSpace);
  if (typeof a === 'string' && a in ACCENTS) return new THREE.Color().setHex(ACCENTS[a as AccentName], THREE.SRGBColorSpace);
  return new THREE.Color(a as THREE.ColorRepresentation);
}

// ---------------------------------------------------------------- geometry prep

/** Normalise a geometry to the merge layout: position, normal, uv, color, index. */
export function prep(g: THREE.BufferGeometry, color: RGB = [1, 1, 1]): THREE.BufferGeometry {
  for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(name)) g.deleteAttribute(name);
  const n = g.getAttribute('position').count;
  if (!g.getAttribute('normal')) g.computeVertexNormals();
  if (!g.getAttribute('uv')) g.setAttribute('uv', new THREE.Float32BufferAttribute(new Float32Array(n * 2), 2));
  if (!g.getAttribute('color')) {
    const c = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { c[i * 3] = color[0]; c[i * 3 + 1] = color[1]; c[i * 3 + 2] = color[2]; }
    g.setAttribute('color', new THREE.Float32BufferAttribute(c, 3));
  }
  if (!g.index) {
    const idx = new Uint32Array(n);
    for (let i = 0; i < n; i++) idx[i] = i;
    g.setIndex(new THREE.BufferAttribute(idx, 1));
  }
  g.morphAttributes = {};
  g.clearGroups();
  return g;
}

/** Faceted copy (flat normals) e.g. for hex heads and chamfers. */
export function flat(g: THREE.BufferGeometry): THREE.BufferGeometry {
  const f = g.index ? g.toNonIndexed() : g;
  f.deleteAttribute('normal');
  f.computeVertexNormals();
  if (f !== g) g.dispose();
  return f;
}

export function paint(g: THREE.BufferGeometry, fn: RGB | ((p: V3, n: V3) => RGB)): THREE.BufferGeometry {
  prep(g);
  const P = g.getAttribute('position'), N = g.getAttribute('normal'), C = g.getAttribute('color') as THREE.BufferAttribute;
  const p = v3(), n = v3();
  for (let i = 0; i < P.count; i++) {
    const c = typeof fn === 'function' ? fn(p.fromBufferAttribute(P, i), n.fromBufferAttribute(N, i)) : fn;
    C.setXYZ(i, c[0], c[1], c[2]);
  }
  C.needsUpdate = true;
  return g;
}

export function shade(g: THREE.BufferGeometry, fn: (p: V3, n: V3) => number): THREE.BufferGeometry {
  prep(g);
  const P = g.getAttribute('position'), N = g.getAttribute('normal'), C = g.getAttribute('color') as THREE.BufferAttribute;
  const p = v3(), n = v3();
  for (let i = 0; i < P.count; i++) {
    const k = fn(p.fromBufferAttribute(P, i), n.fromBufferAttribute(N, i));
    C.setXYZ(i, C.getX(i) * k, C.getY(i) * k, C.getZ(i) * k);
  }
  return g;
}

/** Planar/box UVs in meters: top/bottom faces use (x, z), sides use (x|z, y).
 *  scale = UV units per meter; offset added after scaling. */
export function boxUV(g: THREE.BufferGeometry, scale: number, offset: [number, number] = [0, 0], center: [number, number] = [0, 0]): THREE.BufferGeometry {
  prep(g);
  const P = g.getAttribute('position'), N = g.getAttribute('normal'), U = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < P.count; i++) {
    const x = P.getX(i) - center[0], y = P.getY(i), z = P.getZ(i) - center[1];
    const ax = Math.abs(N.getX(i)), ay = Math.abs(N.getY(i)), az = Math.abs(N.getZ(i));
    let u: number, v: number;
    if (ay >= ax && ay >= az) { u = x; v = -z; } else if (ax >= az) { u = z; v = y; } else { u = x; v = y; }
    U.setXY(i, u * scale + offset[0], v * scale + offset[1]);
  }
  return g;
}

export function xf(pos: V3, rot?: THREE.Euler, scale?: V3): THREE.Matrix4 {
  return new THREE.Matrix4().compose(pos, new THREE.Quaternion().setFromEuler(rot ?? new THREE.Euler()), scale ?? v3(1, 1, 1));
}

// ---------------------------------------------------------------- mass model

export class MassModel {
  private items: { m: number; c: V3; s: V3 }[] = [];
  add(mass: number, box: THREE.Box3): void {
    if (mass <= 0 || box.isEmpty()) return;
    this.items.push({ m: mass, c: box.getCenter(v3()), s: box.getSize(v3()) });
  }
  addPoint(mass: number, c: V3, size = v3(0.01, 0.01, 0.01)): void { this.items.push({ m: mass, c: c.clone(), s: size }); }
  /** Scale all masses so the total equals `total` (spec all-up weight). */
  result(total?: number): { mass: number; com: V3; inertia: [number, number, number, number, number, number] } {
    let M = 0;
    const com = v3();
    for (const it of this.items) { M += it.m; com.addScaledVector(it.c, it.m); }
    com.divideScalar(M || 1);
    const k = total ? total / M : 1;
    let Ixx = 0, Iyy = 0, Izz = 0, Ixy = 0, Ixz = 0, Iyz = 0;
    for (const it of this.items) {
      const m = it.m * k, d = it.c.clone().sub(com), s = it.s;
      Ixx += (m / 12) * (s.y * s.y + s.z * s.z) + m * (d.y * d.y + d.z * d.z);
      Iyy += (m / 12) * (s.x * s.x + s.z * s.z) + m * (d.x * d.x + d.z * d.z);
      Izz += (m / 12) * (s.x * s.x + s.y * s.y) + m * (d.x * d.x + d.y * d.y);
      Ixy -= m * d.x * d.y; Ixz -= m * d.x * d.z; Iyz -= m * d.y * d.z;
    }
    return { mass: M * k, com, inertia: [Ixx, Iyy, Izz, Ixy, Ixz, Iyz] };
  }
}

// ---------------------------------------------------------------- batching

/** Collects transformed geometries per material key, then AO-bakes and merges. */
export class Batch {
  readonly parts = new Map<string, THREE.BufferGeometry[]>();
  constructor(readonly mass?: MassModel) {}
  add(mat: string, g: THREE.BufferGeometry, m?: THREE.Matrix4, color?: RGB | ((p: V3, n: V3) => RGB), massKg = 0): THREE.BufferGeometry {
    prep(g);
    if (color) paint(g, color);
    if (m) g.applyMatrix4(m);
    let list = this.parts.get(mat);
    if (!list) { list = []; this.parts.set(mat, list); }
    list.push(g);
    if (massKg > 0 && this.mass) { g.computeBoundingBox(); this.mass.add(massKg, g.boundingBox!); }
    return g;
  }
  all(): THREE.BufferGeometry[] { return [...this.parts.values()].flat(); }
  merged(mat: string): THREE.BufferGeometry | null {
    const l = this.parts.get(mat);
    if (!l || l.length === 0) return null;
    const g = l.length === 1 ? l[0]! : mergeGeometries(l, false);
    if (!g) throw new Error('merge failed for ' + mat);
    g.computeBoundingBox(); g.computeBoundingSphere();
    return g;
  }
  meshes(materials: Record<string, THREE.Material>): THREE.Mesh[] {
    const out: THREE.Mesh[] = [];
    for (const key of this.parts.keys()) {
      const mat = materials[key];
      if (!mat) throw new Error('no material for ' + key);
      const g = this.merged(key);
      if (!g) continue;
      const mesh = new THREE.Mesh(g, mat);
      mesh.name = key;
      mesh.castShadow = mesh.receiveShadow = true;
      out.push(mesh);
    }
    return out;
  }
}

/** Cosine-weighted hemisphere directions (z-up), deterministic. */
function hemisphere(n: number): V3[] {
  const out: V3[] = [];
  const ga = Math.PI * (3 - Math.sqrt(5));
  for (let i = 0; i < n; i++) {
    const r = Math.sqrt((i + 0.5) / n), a = i * ga;
    out.push(v3(Math.cos(a) * r, Math.sin(a) * r, Math.sqrt(Math.max(0, 1 - r * r))));
  }
  return out;
}

/**
 * Voxel ambient occlusion baked into vertex colors. All occluders are
 * rasterised into an occupancy grid; each target vertex marches a set of
 * hemisphere rays. Darkens crevices, the underside of plates and ground-facing
 * pockets without any external tools.
 */
export function bakeAO(targets: THREE.BufferGeometry[], occluders: THREE.BufferGeometry[], o: { voxel: number; maxDist: number; strength: number; rays?: number; floor?: number }): void {
  const box = new THREE.Box3();
  for (const g of occluders) { g.computeBoundingBox(); box.union(g.boundingBox!); }
  for (const g of targets) { g.computeBoundingBox(); box.union(g.boundingBox!); }
  const vs = o.voxel;
  box.expandByScalar(o.maxDist + vs * 2);
  const nx = Math.ceil((box.max.x - box.min.x) / vs), ny = Math.ceil((box.max.y - box.min.y) / vs), nz = Math.ceil((box.max.z - box.min.z) / vs);
  const grid = new Uint8Array(nx * ny * nz);
  const mark = (x: number, y: number, z: number): void => {
    const i = Math.floor((x - box.min.x) / vs), j = Math.floor((y - box.min.y) / vs), k = Math.floor((z - box.min.z) / vs);
    if (i >= 0 && j >= 0 && k >= 0 && i < nx && j < ny && k < nz) grid[(k * ny + j) * nx + i] = 1;
  };
  const a = v3(), b = v3(), c = v3();
  for (const g of occluders) {
    const P = g.getAttribute('position'), I = g.index!;
    for (let t = 0; t < I.count; t += 3) {
      a.fromBufferAttribute(P, I.getX(t)); b.fromBufferAttribute(P, I.getX(t + 1)); c.fromBufferAttribute(P, I.getX(t + 2));
      const e = Math.max(a.distanceTo(b), b.distanceTo(c), c.distanceTo(a));
      const n = Math.max(1, Math.ceil(e / (vs * 0.5)));
      for (let i = 0; i <= n; i++)
        for (let j = 0; j <= n - i; j++) {
          const u = i / n, w = j / n;
          mark(a.x + (b.x - a.x) * u + (c.x - a.x) * w, a.y + (b.y - a.y) * u + (c.y - a.y) * w, a.z + (b.z - a.z) * u + (c.z - a.z) * w);
        }
    }
  }
  const occ = (x: number, y: number, z: number): boolean => {
    const i = Math.floor((x - box.min.x) / vs), j = Math.floor((y - box.min.y) / vs), k = Math.floor((z - box.min.z) / vs);
    if (i < 0 || j < 0 || k < 0 || i >= nx || j >= ny || k >= nz) return false;
    return grid[(k * ny + j) * nx + i] === 1;
  };
  const dirs = hemisphere(o.rays ?? 14);
  const p = v3(), n = v3(), t1 = v3(), t2 = v3(), d = v3();
  const steps = Math.ceil(o.maxDist / (vs * 0.8));
  for (const g of targets) {
    const P = g.getAttribute('position'), N = g.getAttribute('normal'), C = g.getAttribute('color') as THREE.BufferAttribute;
    for (let vi = 0; vi < P.count; vi++) {
      p.fromBufferAttribute(P, vi); n.fromBufferAttribute(N, vi);
      if (n.lengthSq() < 1e-8) continue;
      n.normalize();
      t1.set(Math.abs(n.y) < 0.9 ? 0 : 1, Math.abs(n.y) < 0.9 ? 1 : 0, 0).cross(n).normalize();
      t2.crossVectors(n, t1);
      let hit = 0;
      for (const h of dirs) {
        d.set(0, 0, 0).addScaledVector(t1, h.x).addScaledVector(t2, h.y).addScaledVector(n, h.z);
        for (let s = 2; s <= steps; s++) {
          const dist = s * vs * 0.8;
          if (occ(p.x + n.x * vs * 1.2 + d.x * dist, p.y + n.y * vs * 1.2 + d.y * dist, p.z + n.z * vs * 1.2 + d.z * dist)) {
            hit += Math.pow(1 - dist / o.maxDist, 0.6);
            break;
          }
        }
      }
      const ao = Math.max(o.floor ?? 0.25, 1 - (hit / dirs.length) * o.strength);
      C.setXYZ(vi, C.getX(vi) * ao, C.getY(vi) * ao, C.getZ(vi) * ao);
    }
    C.needsUpdate = true;
  }
}

// ---------------------------------------------------------------- lofts and lathes

export interface Section {
  /** half width, top and bottom extents and corner radius (meters) */
  hw: number; top: number; bot: number; r: number;
}

function roundedRectRing(s: Section, n: number): [number, number][] {
  // dense polyline, starting at bottom centre, going toward +x (right)
  const r = Math.max(1e-5, Math.min(s.r, s.hw, (s.top + s.bot) / 2));
  const pts: [number, number][] = [];
  const arc = (cx: number, cy: number, a0: number, a1: number): void => {
    for (let i = 0; i <= 8; i++) { const a = a0 + ((a1 - a0) * i) / 8; pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); }
  };
  pts.push([0, -s.bot]);
  arc(s.hw - r, -s.bot + r, -Math.PI / 2, 0);
  arc(s.hw - r, s.top - r, 0, Math.PI / 2);
  arc(-s.hw + r, s.top - r, Math.PI / 2, Math.PI);
  arc(-s.hw + r, -s.bot + r, Math.PI, Math.PI * 1.5);
  pts.push([0, -s.bot]);
  // resample by arc length into n segments
  const L: number[] = [0];
  for (let i = 1; i < pts.length; i++) L.push(L[i - 1]! + Math.hypot(pts[i]![0] - pts[i - 1]![0], pts[i]![1] - pts[i - 1]![1]));
  const total = L[L.length - 1]!;
  const out: [number, number][] = [];
  let k = 0;
  for (let i = 0; i <= n; i++) {
    const target = (i / n) * total;
    while (k < L.length - 2 && L[k + 1]! < target) k++;
    const f = (target - L[k]!) / Math.max(1e-9, L[k + 1]! - L[k]!);
    out.push([pts[k]![0] + (pts[k + 1]![0] - pts[k]![0]) * f, pts[k]![1] + (pts[k + 1]![1] - pts[k]![1]) * f]);
  }
  return out;
}

/**
 * Loft rounded-rectangle sections along a polyline. uv: u around the section
 * (0 bottom centre, 0.25 right, 0.5 top, 0.75 left), v along the path (0..1).
 * "right" is up x tangent, so a path running +Z has its right side at +X.
 */
export function loft(path: V3[], sections: Section[], around: number, o: { capStart?: boolean; capEnd?: boolean; up?: V3 } = {}): THREE.BufferGeometry {
  const up0 = o.up ?? v3(0, 1, 0);
  const pos: number[] = [], uv: number[] = [], idx: number[] = [];
  const L: number[] = [0];
  for (let i = 1; i < path.length; i++) L.push(L[i - 1]! + path[i]!.distanceTo(path[i - 1]!));
  const total = L[L.length - 1]! || 1;
  const frames: { p: V3; r: V3; u: V3 }[] = [];
  for (let i = 0; i < path.length; i++) {
    const t = v3().subVectors(path[Math.min(path.length - 1, i + 1)]!, path[Math.max(0, i - 1)]!).normalize();
    const right = v3().crossVectors(up0, t).normalize();
    const up = v3().crossVectors(t, right).normalize();
    frames.push({ p: path[i]!, r: right, u: up });
  }
  const row = around + 1;
  for (let i = 0; i < path.length; i++) {
    const ring = roundedRectRing(sections[i]!, around);
    const f = frames[i]!;
    for (let j = 0; j <= around; j++) {
      const [x, y] = ring[j]!;
      const p = f.p.clone().addScaledVector(f.r, x).addScaledVector(f.u, y);
      pos.push(p.x, p.y, p.z);
      uv.push(j / around, L[i]! / total);
    }
  }
  for (let i = 0; i < path.length - 1; i++)
    for (let j = 0; j < around; j++) {
      const a = i * row + j;
      // outward winding: around (right, up) x along the path
      idx.push(a, a + 1, a + row, a + 1, a + row + 1, a + row);
    }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  seamNormals(g, path.length, row);
  const parts: THREE.BufferGeometry[] = [prep(g)];
  const cap = (i: number, sign: number): void => {
    const ring = roundedRectRing(sections[i]!, around);
    const f = frames[i]!;
    const shape = new THREE.Shape(ring.slice(0, around).map(([x, y]) => new THREE.Vector2(x, y)));
    const sg = new THREE.ShapeGeometry(shape, 1);
    const m = new THREE.Matrix4().makeBasis(f.r, f.u, v3().crossVectors(f.r, f.u)).setPosition(f.p);
    if (sign < 0) sg.applyMatrix4(new THREE.Matrix4().makeScale(-1, 1, -1));
    sg.applyMatrix4(m);
    parts.push(prep(sg));
  };
  if (o.capStart) cap(0, -1);
  if (o.capEnd) cap(path.length - 1, 1);
  return parts.length === 1 ? parts[0]! : mergeGeometries(parts, false)!;
}

/** Average normals across the u seam of a lofted/lathed grid. */
function seamNormals(g: THREE.BufferGeometry, rows: number, row: number): void {
  const N = g.getAttribute('normal') as THREE.BufferAttribute;
  const n = v3(), m = v3();
  for (let i = 0; i < rows; i++) {
    const a = i * row, b = i * row + row - 1;
    n.fromBufferAttribute(N, a).add(m.fromBufferAttribute(N, b)).normalize();
    N.setXYZ(a, n.x, n.y, n.z); N.setXYZ(b, n.x, n.y, n.z);
  }
}

/** Lathe around +Y. profile: [radius, y, v?]; v defaults to normalised length. */
export function lathe(profile: readonly (readonly [number, number, number?])[], segs: number, phase = 0): THREE.BufferGeometry {
  const pos: number[] = [], uv: number[] = [], idx: number[] = [];
  const L: number[] = [0];
  for (let i = 1; i < profile.length; i++) L.push(L[i - 1]! + Math.hypot(profile[i]![0] - profile[i - 1]![0], profile[i]![1] - profile[i - 1]![1]));
  const total = L[L.length - 1]! || 1;
  for (let i = 0; i < profile.length; i++) {
    const [r, y, v] = profile[i]!;
    for (let j = 0; j <= segs; j++) {
      const a = (j / segs) * Math.PI * 2 + phase;
      pos.push(Math.sin(a) * r, y, Math.cos(a) * r);
      uv.push(j / segs, v ?? L[i]! / total);
    }
  }
  const row = segs + 1;
  for (let i = 0; i < profile.length - 1; i++)
    for (let j = 0; j < segs; j++) {
      const a = i * row + j;
      idx.push(a, a + 1, a + row, a + 1, a + row + 1, a + row);
    }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  seamNormals(g, profile.length, row);
  return prep(g);
}

export function cylinder(r: number, h: number, segs: number, y0 = 0, capped = true): THREE.BufferGeometry {
  const g = new THREE.CylinderGeometry(r, r, h, segs, 1, !capped);
  g.translate(0, y0 + h / 2, 0);
  return prep(g);
}

export function box(w: number, h: number, d: number, m?: THREE.Matrix4): THREE.BufferGeometry {
  const g = prep(new THREE.BoxGeometry(w, h, d));
  if (m) g.applyMatrix4(m);
  return g;
}

/** Extrude a 2D shape (in X/Z plan, Y up) with a chamfer. */
export function plate(shape: THREE.Shape, thickness: number, chamfer: number, y0: number, curveSegments = 8): THREE.BufferGeometry {
  const g = new THREE.ExtrudeGeometry(shape, {
    depth: thickness - chamfer * 2, bevelEnabled: chamfer > 0, bevelThickness: chamfer, bevelSize: chamfer, bevelSegments: 1, curveSegments,
  });
  // shape is drawn in (x, -z); extrusion goes along +Z -> rotate to +Y
  g.rotateX(-Math.PI / 2);
  g.translate(0, y0 + chamfer, 0);
  return prep(g);
}

/** Tube along a smooth curve (cables, wires). */
export function cable(points: V3[], radius: number, lod: Lod, closed = false): THREE.BufferGeometry {
  const curve = new THREE.CatmullRomCurve3(points, closed, 'centripetal');
  const len = curve.getLength();
  const segs = Math.max(4, Math.round(len / (lod === 0 ? 0.006 : 0.015)));
  return prep(new THREE.TubeGeometry(curve, segs, radius, lod === 0 ? 5 : 3, closed));
}

/** Sweep a rectangle (width along `side`, thickness along the curve normal) along a closed or open path. */
export function band(points: V3[], width: number, thickness: number, closed: boolean, sideHint: V3, samples = 48): THREE.BufferGeometry {
  const curve = new THREE.CatmullRomCurve3(points, closed, 'centripetal');
  const N = samples;
  const pos: number[] = [], idx: number[] = [], uv: number[] = [];
  const prof: [number, number][] = [[-width / 2, -thickness / 2], [width / 2, -thickness / 2], [width / 2, thickness / 2], [-width / 2, thickness / 2]];
  const rows = closed ? N : N + 1;
  for (let i = 0; i < rows; i++) {
    const t = i / N;
    const p = curve.getPointAt(t), tan = curve.getTangentAt(t);
    const side = sideHint.clone().addScaledVector(tan, -sideHint.dot(tan)).normalize();
    const nrm = v3().crossVectors(tan, side).normalize();
    for (const [sx, sy] of prof) {
      const q = p.clone().addScaledVector(side, sx).addScaledVector(nrm, sy);
      pos.push(q.x, q.y, q.z); uv.push(t, sx > 0 ? 1 : 0);
    }
  }
  for (let i = 0; i < N; i++) {
    const a = i * 4, b = ((i + 1) % rows) * 4;
    if (!closed && i === N) break;
    for (let k = 0; k < 4; k++) {
      const k1 = (k + 1) % 4;
      idx.push(a + k, b + k, a + k1, a + k1, b + k, b + k1);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  return flat(g);
}

// ---------------------------------------------------------------- fasteners

const STEEL = lin(0xb9bcc0), DARK = lin(0x111111);

/** Socket head cap screw head (hex socket) sitting on y = 0, axis +Y. */
export function socketHead(d: number, lod: Lod, color: RGB = STEEL, button = false): THREE.BufferGeometry {
  const r = d * (button ? 0.95 : 0.85), h = button ? d * 0.55 : d;
  const s = lod === 0 ? 10 : 6;
  const prof: [number, number][] = button
    ? [[0.0001, 0], [r, 0], [r, h * 0.25], [r * 0.75, h * 0.8], [r * 0.45, h], [d * 0.36, h], [d * 0.36, h - d * 0.3], [0.0001, h - d * 0.3]]
    : [[0.0001, 0], [r, 0], [r, h * 0.9], [r * 0.9, h], [d * 0.36, h], [d * 0.36, h - d * 0.45], [0.0001, h - d * 0.45]];
  const g = lathe(prof, s);
  paint(g, (p) => (Math.hypot(p.x, p.z) < d * 0.37 && p.y < h - 0.0001 ? DARK : color));
  if (lod === 0) {
    // hex socket walls (6-sided) so the recess reads as a hex key socket
    const hex = flat(new THREE.CylinderGeometry(d * 0.36, d * 0.36, d * 0.3, 6, 1, true));
    hex.translate(0, h - d * 0.15, 0);
    paint(hex, DARK);
    return mergeGeometries([g, prep(hex)], false)!;
  }
  return g;
}

/** Tiny pan-head Phillips screw (mini drone), on y = 0, axis +Y. */
export function panHead(d: number, lod: Lod, color: RGB = lin(0x8a8d91)): THREE.BufferGeometry {
  const r = d * 0.95, h = d * 0.45;
  const g = lathe([[0.0001, 0], [r, 0], [r, h * 0.4], [r * 0.7, h], [0.0001, h]], lod === 0 ? 10 : 5);
  paint(g, color);
  if (lod === 1) return g;
  const c1 = box(d * 1.1, h * 0.5, d * 0.22, xf(v3(0, h * 0.9, 0)));
  const c2 = box(d * 0.22, h * 0.5, d * 1.1, xf(v3(0, h * 0.9, 0)));
  paint(c1, DARK); paint(c2, DARK);
  return mergeGeometries([g, c1, c2], false)!;
}

export function hexNut(d: number, h: number, color: RGB): THREE.BufferGeometry {
  const g = flat(new THREE.CylinderGeometry(d * 0.95, d * 0.95, h, 6));
  g.translate(0, h / 2, 0);
  paint(g, color);
  return g;
}

/** Hex aluminium standoff (M3) from y0 to y1. */
export function standoff(y0: number, y1: number, lod: Lod): THREE.BufferGeometry {
  const g = flat(new THREE.CylinderGeometry(0.00288, 0.00288, y1 - y0, 6, lod === 0 ? 2 : 1));
  g.translate(0, (y0 + y1) / 2, 0);
  prep(g);
  // brushed normal map runs along u: map u around the hex
  const P = g.getAttribute('position'), U = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < P.count; i++) U.setXY(i, (Math.atan2(P.getX(i), P.getZ(i)) / (Math.PI * 2)) * 2, P.getY(i) * 40);
  return g;
}

// ---------------------------------------------------------------- props

export interface PropSpec {
  radius: number;
  rootRadius: number;
  hubRadius: number;
  hubHeight: number;
  blades: number;
  /** geometric pitch in meters (inches * 0.0254) */
  pitch: number;
  /** chord in meters at normalised radius x in [0,1] (root..tip) */
  chord: (x: number) => number;
  /** max thickness ratio */
  thickness: (x: number) => number;
  camber: number;
  /** leading-edge sweep offset (m) along the chord direction */
  sweep: (x: number) => number;
  /** blade coning, radians */
  coning: number;
  /** 'round' tip tapers to a point-ish ellipse, 'bull' keeps a blunt rounded tip */
  tip: 'round' | 'bull';
}

/**
 * Airfoil propeller blades (no hub), rotor-local: y up, blade plane at y = 0.
 * dir = +1 for counter-clockwise rotation seen from above (positive rotation
 * about +Y), -1 for clockwise; the leading edge faces the direction of travel
 * and the twist follows the geometric pitch atan(P / 2 pi r).
 */
export function propBlades(spec: PropSpec, lod: Lod, dir: 1 | -1, base: RGB, wear: number, seed: number, phase = 0): THREE.BufferGeometry {
  const r = rng(seed);
  const NS = lod === 0 ? 14 : 5, NC = lod === 0 ? 8 : 3;
  // cosine-spaced chordwise stations
  const xs: number[] = [];
  for (let i = 0; i <= NC; i++) xs.push(0.5 * (1 - Math.cos((i / NC) * Math.PI)));
  const loopLen = NC * 2;
  const geos: THREE.BufferGeometry[] = [];
  const pale = mixRGB(base, [0.75, 0.75, 0.72], 0.75);
  for (let b = 0; b < spec.blades; b++) {
    const ang = phase + (b / spec.blades) * Math.PI * 2;
    const nicks: { x: number; depth: number; w: number }[] = [];
    const nn = Math.floor(wear * 4 + r() * wear * 3);
    for (let k = 0; k < nn; k++) nicks.push({ x: 0.55 + r() * 0.42, depth: mm(0.4 + r() * 1.2) * wear, w: 0.02 + r() * 0.03 });
    const tipChip = wear > 0.4 && r() < wear ? mm(r() * 1.5) : 0;
    const pos: number[] = [], col: number[] = [], idx: number[] = [];
    for (let s = 0; s <= NS; s++) {
      const x = 1 - Math.pow(1 - s / NS, 1.5);
      const rad = spec.rootRadius + (spec.radius - tipChip - spec.rootRadius) * x;
      let c = spec.chord(x);
      // planform rounding at the tip
      const tipStart = spec.tip === 'bull' ? 0.9 : 0.8;
      if (x > tipStart) c *= Math.sqrt(Math.max(0.0, 1 - Math.pow((x - tipStart) / (1 - tipStart), 2))) * (spec.tip === 'bull' ? 0.85 : 1) + (spec.tip === 'bull' ? 0.15 : 0.02);
      let le = 0;
      for (const nk of nicks) le += nk.depth * Math.max(0, 1 - Math.abs(x - nk.x) / nk.w);
      const beta = Math.atan(spec.pitch / (2 * Math.PI * Math.max(rad, 0.002)));
      const tr = spec.thickness(x);
      const rootBlend = Math.max(0, 1 - x / 0.12); // round, thick root merging into the hub
      for (let k = 0; k < loopLen; k++) {
        // loop: upper surface TE->LE (k 0..NC), then lower LE->TE
        const upper = k <= NC;
        const xc = upper ? xs[NC - k]! : xs[k - NC]!;
        const t = 5 * tr * (0.2969 * Math.sqrt(xc) - 0.126 * xc - 0.3516 * xc * xc + 0.2843 * xc ** 3 - 0.1036 * xc ** 4);
        const cam = spec.camber * 4 * xc * (1 - xc) * (1 - rootBlend);
        let yy = (cam + (upper ? t : -t)) * c;
        let zc = (xc - 0.25) * c; // chord from LE (-) to TE (+)
        if (rootBlend > 0) {
          // morph toward an ellipse at the root
          const a = (upper ? 1 : -1) * Math.sqrt(Math.max(0, 1 - Math.pow(2 * xc - 1, 2)));
          yy = yy * (1 - rootBlend) + a * c * 0.22 * rootBlend;
          zc = zc * (1 - rootBlend * 0.3);
        }
        zc += le * (1 - xc) * (xc < 0.2 ? 1 : 0.2) - spec.sweep(x);
        // twist: rotate about the radial axis so the leading edge rises
        const yR = yy * Math.cos(beta) - zc * Math.sin(beta);
        const zR = zc * Math.cos(beta) + yy * Math.sin(beta);
        const yC = yR + rad * Math.sin(spec.coning);
        pos.push(rad, yC, zR);
        const edge = Math.max(xc < 0.06 ? 1 : 0, x > 0.9 ? (x - 0.9) * 10 : 0);
        const cc = mixRGB(base, pale, Math.min(1, wear * edge * (0.6 + r() * 0.4)));
        col.push(cc[0], cc[1], cc[2]);
      }
    }
    for (let s = 0; s < NS; s++)
      for (let k = 0; k < loopLen; k++) {
        const a = s * loopLen + k, bb = s * loopLen + ((k + 1) % loopLen);
        idx.push(a, bb, a + loopLen, bb, bb + loopLen, a + loopLen);
      }
    // tip cap
    const last = NS * loopLen, ci = pos.length / 3;
    let cx = 0, cy = 0, cz = 0;
    for (let k = 0; k < loopLen; k++) { cx += pos[(last + k) * 3]!; cy += pos[(last + k) * 3 + 1]!; cz += pos[(last + k) * 3 + 2]!; }
    pos.push(cx / loopLen + mm(0.3), cy / loopLen, cz / loopLen);
    col.push(...mixRGB(base, pale, wear * 0.8));
    for (let k = 0; k < loopLen; k++) idx.push(last + k, last + ((k + 1) % loopLen), ci);
    let g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
    g.setIndex(idx);
    if (dir < 0) {
      // mirror for clockwise props, then restore winding
      g.applyMatrix4(new THREE.Matrix4().makeScale(1, 1, -1));
      const I = g.index!;
      for (let t = 0; t < I.count; t += 3) { const tmp = I.getX(t + 1); I.setX(t + 1, I.getX(t + 2)); I.setX(t + 2, tmp); }
    }
    g.computeVertexNormals();
    g.rotateY(ang);
    g = prep(g);
    geos.push(g);
  }
  return mergeGeometries(geos, false)!;
}

/** Prop hub (plastic) with a bore, sitting on y = -hubHeight/2..+hubHeight/2. */
export function propHub(spec: PropSpec, lod: Lod, color: RGB, bore: number): THREE.BufferGeometry {
  const r = spec.hubRadius, h = spec.hubHeight;
  const g = lathe([[bore, -h / 2], [r * 0.92, -h / 2], [r, -h / 2 + h * 0.15], [r, h / 2 - h * 0.15], [r * 0.92, h / 2], [bore, h / 2], [bore, -h / 2]], lod === 0 ? 24 : 8);
  return paint(g, color);
}

/** Annulus for the motion-blur disc; uv.x = normalised radius for the alpha map. */
export function blurDisc(inner: number, outer: number, segs: number): THREE.BufferGeometry {
  const pos: number[] = [], uv: number[] = [], idx: number[] = [];
  const rings = 2;
  for (let i = 0; i <= rings; i++) {
    const t = i / rings, r = inner + (outer - inner) * t;
    for (let j = 0; j <= segs; j++) {
      const a = (j / segs) * Math.PI * 2;
      pos.push(Math.cos(a) * r, 0, Math.sin(a) * r);
      uv.push(t, j / segs);
    }
  }
  for (let i = 0; i < rings; i++)
    for (let j = 0; j < segs; j++) {
      const a = i * (segs + 1) + j;
      idx.push(a, a + 1, a + segs + 1, a + 1, a + segs + 2, a + segs + 1);
    }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(idx);
  g.computeVertexNormals();
  return g;
}

/** Blade coverage (solidity) profile for the blur alpha, plus an opaque hub. */
export function solidityProfile(spec: PropSpec, inner: number): (u: number) => number {
  return (u: number): number => {
    const rad = inner + (spec.radius - inner) * u;
    if (rad < spec.hubRadius) return 0.97;
    const x = (rad - spec.rootRadius) / (spec.radius - spec.rootRadius);
    if (x > 1) return 0;
    const c = spec.chord(Math.max(0, x)) * (x > 0.85 ? Math.sqrt(Math.max(0, 1 - Math.pow((x - 0.85) / 0.15, 2))) : 1);
    const sol = (spec.blades * c) / (2 * Math.PI * rad);
    return Math.min(0.85, sol * 1.6 + 0.04);
  };
}

// ---------------------------------------------------------------- motors

export interface MotorParts { fixed: THREE.BufferGeometry[]; fixedMat: string[]; spinning: THREE.BufferGeometry[]; }

/**
 * 2306-class outrunner, motor-local (base at y = 0). Returns stationary parts
 * (base, stator, windings) and spinning parts (bell with knurl band, magnets,
 * bearing, shaft, washer, nut). Spinning parts are colored per vertex.
 */
export function motor2306(lod: Lod, bell: RGB, winding: RGB, nut: RGB): MotorParts {
  const fixed: THREE.BufferGeometry[] = [], fixedMat: string[] = [], spinning: THREE.BufferGeometry[] = [];
  const S = lod === 0 ? 28 : 10;
  // base: black anodised, with four mounting lobes
  const base = lathe(lod === 0 ? [[0.004, 0], [0.0133, 0], [0.0136, 0.0012], [0.0128, 0.003], [0.0062, 0.0036], [0.004, 0.0036]] : [[0.004, 0], [0.0135, 0], [0.0128, 0.0036], [0.004, 0.0036]], S);
  fixed.push(base); fixedMat.push('blackAnodized');
  if (lod === 0) for (let k = 0; k < 4; k++) {
    const lobe = box(0.006, 0.0016, 0.004, xf(v3(Math.cos(k * Math.PI / 2 + Math.PI / 4) * 0.0128, 0.0008, Math.sin(k * Math.PI / 2 + Math.PI / 4) * 0.0128), new THREE.Euler(0, -(k * Math.PI / 2 + Math.PI / 4), 0)));
    fixed.push(lobe); fixedMat.push('blackAnodized');
  }
  // stator stack and windings, visible through the bell vents and lower gap
  const stator = cylinder(0.0112, 0.0065, lod === 0 ? 24 : 10, 0.0036);
  paint(stator, lin(0x4b4d50));
  fixed.push(stator); fixedMat.push('bareMetal');
  if (lod === 0) for (let k = 0; k < 12; k++) {
    const a = (k / 12) * Math.PI * 2;
    const g = box(0.0036, 0.0058, 0.0048);
    g.applyMatrix4(xf(v3(Math.cos(a) * 0.0078, 0.0068, Math.sin(a) * 0.0078), new THREE.Euler(0, -a, 0)));
    paint(g, winding);
    fixed.push(g); fixedMat.push('bareMetal');
  }
  // bell: outer wall with knurled upper band (v in [0.55, 0.95]), inner lip
  const R = 0.01395;
  const bellG = lathe(lod === 0 ? [
    [0.0128, 0.0042, 0.25], [R, 0.0042, 0.25], [R, 0.0052, 0.25], [R, 0.0098, 0.25], [R, 0.0102, 0.55],
    [R, 0.0158, 0.95], [R * 0.985, 0.0166, 0.25], [R * 0.93, 0.0173, 0.25], [0.0125, 0.0176, 0.25], [0.0125, 0.0168, 0.25], [0.0128, 0.0168, 0.25], [0.0128, 0.0042, 0.25],
  ] : [[0.0128, 0.0042, 0.25], [R, 0.0042, 0.25], [R, 0.0102, 0.55], [R, 0.0158, 0.95], [0.0125, 0.0176, 0.25]], S);
  paint(bellG, bell);
  spinning.push(bellG);
  // top cap: centre boss + spokes over the vents
  const boss = lathe(lod === 0 ? [[0.0026, 0.0168], [0.0058, 0.0168], [0.0062, 0.0176], [0.0056, 0.0184], [0.0026, 0.0184]] : [[0.0026, 0.0168], [0.0062, 0.0172], [0.0026, 0.0184]], lod === 0 ? 20 : 8);
  paint(boss, bell);
  spinning.push(boss);
  const spokes = lod === 0 ? 6 : 3;
  for (let k = 0; k < spokes; k++) {
    const a = (k / spokes) * Math.PI * 2;
    const sp = box(0.0068, 0.0012, 0.0024, xf(v3(Math.cos(a) * 0.0092, 0.0172, Math.sin(a) * 0.0092), new THREE.Euler(0, -a, 0)));
    paint(sp, bell);
    spinning.push(sp);
  }
  if (lod === 0) {
    // magnets ring inside the bell
    for (let k = 0; k < 14; k++) {
      const a = (k / 14) * Math.PI * 2;
      const mg = box(0.0012, 0.0074, 0.0044, xf(v3(Math.cos(a) * 0.0121, 0.0085, Math.sin(a) * 0.0121), new THREE.Euler(0, -a, 0)));
      paint(mg, lin(0x55585c));
      spinning.push(mg);
    }
    // bearing: steel race with dark seal
    const brg = lathe([[0.0026, 0.0184], [0.0042, 0.0184], [0.0042, 0.0186], [0.0026, 0.0186]], 18);
    paint(brg, (p) => (Math.hypot(p.x, p.z) > 0.0036 ? lin(0xc4c6c8) : lin(0x1c1c1e)));
    spinning.push(brg);
  }
  // shaft (M5), washer and nyloc nut above the prop
  const shaft = cylinder(0.0025, 0.0155, lod === 0 ? 12 : 6, 0.0184);
  paint(shaft, lin(0xbdbfc2));
  spinning.push(shaft);
  const washer = lathe([[0.0026, 0.0262], [0.0055, 0.0262], [0.0055, 0.0272], [0.0026, 0.0272]], lod === 0 ? 20 : 6);
  paint(washer, nut);
  spinning.push(washer);
  const n = hexNut(0.0045, 0.0055, nut);
  n.translate(0, 0.0272, 0);
  spinning.push(n);
  if (lod === 0) {
    const nylon = lathe([[0.0026, 0.0327], [0.0039, 0.0327], [0.0037, 0.0335], [0.0026, 0.0335]], 16);
    paint(nylon, lin(0x1d3f8a));
    spinning.push(nylon);
  }
  return { fixed, fixedMat, spinning };
}

// ---------------------------------------------------------------- misc parts

/** Zip tie looped around a rectangular cross-section (centered at origin, loop in the XY plane). */
export function zipTie(hw: number, hh: number, lod: Lod, color: RGB = lin(0x151515)): THREE.BufferGeometry {
  const r = Math.min(hw, hh) * 0.5;
  const pts: V3[] = [];
  const n = lod === 0 ? 4 : 2;
  const corners: [number, number, number][] = [[hw - r, hh - r, 0], [-hw + r, hh - r, Math.PI / 2], [-hw + r, -hh + r, Math.PI], [hw - r, -hh + r, Math.PI * 1.5]];
  for (const [cx, cy, a0] of corners) for (let i = 0; i <= n; i++) { const a = a0 + (i / n) * Math.PI / 2; pts.push(v3(cx + Math.cos(a) * (r + 0.0006), cy + Math.sin(a) * (r + 0.0006), 0)); }
  const loop = band(pts, 0.0025, 0.001, true, v3(0, 0, 1), lod === 0 ? 32 : 12);
  const head = box(0.0042, 0.0034, 0.0046, xf(v3(hw + 0.0022, 0, 0)));
  const tail = box(0.0016, 0.001, 0.0025, xf(v3(hw + 0.0048, 0, 0)));
  paint(loop, color); paint(head, color); paint(tail, color);
  return mergeGeometries([loop, head, tail], false)!;
}

/** Small LED lens (box with a domed top) on y = 0. */
export function ledGeometry(w: number, d: number, h: number, lod: Lod): THREE.BufferGeometry {
  if (lod === 1) return box(w, h, d, xf(v3(0, h / 2, 0)));
  return prep(new THREE.CapsuleGeometry(Math.min(w, d) / 2, Math.max(w, d) - Math.min(w, d), 3, 8)).applyMatrix4(xf(v3(0, h / 2, 0), new THREE.Euler(0, 0, w > d ? Math.PI / 2 : 0), v3(1, h / Math.max(w, d), 1)));
}

export function makeLed(name: string, color: THREE.ColorRepresentation, intensity: number): LedHandle {
  const material = new THREE.MeshBasicMaterial({ name: 'led-' + name, toneMapped: true });
  const handle: LedHandle = {
    name, material, color: new THREE.Color(color), intensity,
    set(c?: THREE.ColorRepresentation, i?: number): void {
      if (c !== undefined) handle.color.set(c);
      if (i !== undefined) handle.intensity = Math.max(0, Math.min(6, i));
      material.color.copy(handle.color).multiplyScalar(Math.max(0.02, handle.intensity));
      material.userData['intensity'] = handle.intensity;
    },
  };
  handle.set(color, intensity);
  return handle;
}

/** Count triangles under an object (visible meshes only by default). */
export function countTriangles(o: THREE.Object3D): number {
  let t = 0;
  o.traverse((c) => {
    const m = c as THREE.Mesh;
    if (m.isMesh) t += (m.geometry.index ? m.geometry.index.count : m.geometry.getAttribute('position').count) / 3;
  });
  return t;
}

// ---------------------------------------------------------------- assembly

export interface RotorSpec {
  /** prop-plane centre in the design frame */
  pos: V3;
  /** rotor-local spinning parts (bell, nut, magnets), opaque */
  hub: THREE.BufferGeometry | null;
  sharp: THREE.BufferGeometry;
  blur: THREE.BufferGeometry;
  blurAlpha: THREE.Texture;
  propColor: THREE.Color;
}

export interface LedSpec { handle: LedHandle; geometry: THREE.BufferGeometry; }

export interface AssembleOptions {
  name: string;
  lod: Lod;
  batch: Batch;
  materials: Record<string, THREE.Material>;
  rotors: RotorSpec[];
  spin: readonly number[];
  hubMat: string;
  propMat: string;
  gimbal?: { root: THREE.Object3D; pivots: GimbalPivots; meshes: THREE.Mesh[] };
  leds: LedSpec[];
  mass: MassModel;
  totalMass: number;
  propRadius: number;
  ao: { voxel: number; maxDist: number; strength: number; rays: number };
}

/** AO-bake, merge per material, build rotors, shift the origin to the centre of mass. */
export function assemble(o: AssembleOptions): DroneBuild {
  // AO: static parts and hubs at rest occlude each other
  const hubWorld = o.rotors.map((r) => (r.hub ? r.hub.clone().translate(r.pos.x, r.pos.y, r.pos.z) : null));
  const statics = o.batch.all();
  const targets = [...statics, ...hubWorld.filter((g): g is THREE.BufferGeometry => !!g)];
  bakeAO(targets, targets, { voxel: o.ao.voxel, maxDist: o.ao.maxDist, strength: o.ao.strength, rays: o.ao.rays });
  o.rotors.forEach((r, i) => { const w = hubWorld[i]; if (r.hub && w) r.hub.setAttribute('color', w.getAttribute('color')); });

  const root = new THREE.Group();
  root.name = o.name;
  const frame = new THREE.Group();
  frame.name = o.name + '-frame';
  root.add(frame);
  const staticMeshes = o.batch.meshes(o.materials);
  for (const m of staticMeshes) frame.add(m);

  const rotors: THREE.Object3D[] = [];
  o.rotors.forEach((r, i) => {
    const obj = new THREE.Object3D();
    obj.name = `rotor${i}`;
    obj.position.copy(r.pos);
    obj.userData['spin'] = o.spin[i];
    obj.userData['spinDirection'] = o.spin[i]! > 0 ? 'ccw' : 'cw';
    if (r.hub) {
      const hub = new THREE.Mesh(r.hub, o.materials[o.hubMat]);
      hub.name = 'hub'; hub.castShadow = true; hub.receiveShadow = true;
      obj.add(hub);
    }
    const sharp = new THREE.Mesh(r.sharp, o.materials[o.propMat]);
    sharp.name = 'bladesSharp'; sharp.castShadow = true; sharp.receiveShadow = true;
    const blurMat = new THREE.MeshStandardMaterial({ name: `${o.name}-blur${i}`, color: r.propColor, alphaMap: r.blurAlpha, transparent: true, opacity: 0, depthWrite: false, side: THREE.DoubleSide, roughness: 0.55, metalness: 0 });
    blurMat.userData['baseOpacity'] = 1;
    const blur = new THREE.Mesh(r.blur, blurMat);
    blur.name = 'bladesBlur'; blur.renderOrder = 2; blur.visible = false;
    obj.add(sharp, blur);
    frame.add(obj);
    rotors.push(obj);
  });
  if (o.gimbal) frame.add(o.gimbal.root);
  for (const l of o.leds) {
    const m = new THREE.Mesh(l.geometry, l.handle.material);
    m.name = 'led-' + l.handle.name;
    frame.add(m);
  }
  const mres = o.mass.result(o.totalMass);
  frame.position.copy(mres.com).multiplyScalar(-1);
  root.updateMatrixWorld(true);
  const motorPositions = rotors.map((r) => r.getWorldPosition(v3()));
  const stats: DroneStats = {
    triangles: countTriangles(root),
    staticDrawCalls: staticMeshes.length,
    dynamicDrawCalls: rotors.length * 2 + (o.gimbal ? o.gimbal.meshes.length : 0),
    ledDrawCalls: o.leds.length,
  };
  return {
    root,
    rotors: rotors as [THREE.Object3D, THREE.Object3D, THREE.Object3D, THREE.Object3D],
    gimbal: o.gimbal?.pivots,
    leds: o.leds.map((l) => l.handle),
    physics: { massKg: mres.mass, comDesign: mres.com, inertia: mres.inertia, motorPositions, propRadius: o.propRadius, spin: [o.spin[0]!, o.spin[1]!, o.spin[2]!, o.spin[3]!] },
    stats,
  };
}
