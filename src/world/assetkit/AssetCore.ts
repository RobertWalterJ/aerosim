// Shared geometry builder, primitives, color utilities and material cache
// used by every asset family in src/world/.
import * as THREE from 'three';

export type LOD = 0 | 1 | 2;
export type RGB = [number, number, number];
export type Vec3 = THREE.Vector3;

export interface BoxCollider { type: 'box'; center: [number, number, number]; halfExtents: [number, number, number]; }
export interface CylinderCollider { type: 'cylinder'; center: [number, number, number]; radius: number; halfHeight: number; }
export interface SphereCollider { type: 'sphere'; center: [number, number, number]; radius: number; }
export type Collider = BoxCollider | CylinderCollider | SphereCollider;

export interface AssetResult {
  geometry: THREE.BufferGeometry;
  material: THREE.Material;
  collider?: Collider;
}

export const TRI_BUDGET: Readonly<Record<LOD, number>> = { 0: 6000, 1: 1200, 2: 200 };

// ---------------------------------------------------------------- math

export const clamp = (x: number, a: number, b: number): number => (x < a ? a : x > b ? b : x);
export const clamp01 = (x: number): number => clamp(x, 0, 1);
export const lerp = (a: number, b: number, t: number): number => a + (b - a) * t;
export const smoothstep = (a: number, b: number, x: number): number => {
  const t = clamp01((x - a) / (b - a));
  return t * t * (3 - 2 * t);
};
export const v3 = (x = 0, y = 0, z = 0): Vec3 => new THREE.Vector3(x, y, z);
export const UP = Object.freeze(new THREE.Vector3(0, 1, 0)) as Vec3;

/** Any unit vector perpendicular to n. */
export function perpendicular(n: Vec3): Vec3 {
  const a = Math.abs(n.y) < 0.9 ? UP : v3(1, 0, 0);
  return v3().crossVectors(n, a).normalize();
}

// ---------------------------------------------------------------- color

const s2l = (c: number): number => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));

/** sRGB hex (as you'd pick it in a paint program) -> linear RGB, which is
 *  what three.js expects in vertex colors. All palettes are authored in sRGB. */
export function hex(h: number): RGB {
  return [s2l(((h >> 16) & 255) / 255), s2l(((h >> 8) & 255) / 255), s2l((h & 255) / 255)];
}
export function mix(a: RGB, b: RGB, t: number): RGB {
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
}
export function mul(a: RGB, s: number): RGB {
  return [a[0] * s, a[1] * s, a[2] * s];
}
export function mulc(a: RGB, b: RGB): RGB {
  return [a[0] * b[0], a[1] * b[1], a[2] * b[2]];
}
/** Brightness/warmth jitter. v: value scale, w: warm(+)/cool(-) shift. */
export function tint(c: RGB, v: number, w = 0): RGB {
  return [clamp(c[0] * v * (1 + w), 0, 0.9), clamp(c[1] * v, 0, 0.9), clamp(c[2] * v * (1 - w), 0, 0.9)];
}
export function luminance(c: RGB): number {
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

// ---------------------------------------------------------------- builder

export interface Mark { v: number; i: number; }

/**
 * Accumulates indexed triangles with the AeroSim attribute set:
 *   position(3) normal(3) uv(2) color(3, linear, AO baked in) aSway(1)
 * and optionally aPolish(1) for stone.
 */
export class MeshBuilder {
  readonly pos: number[] = [];
  readonly nor: number[] = [];
  readonly uvs: number[] = [];
  readonly col: number[] = [];
  readonly sway: number[] = [];
  readonly polish: number[] = [];
  readonly idx: number[] = [];
  readonly phase: number[] = [];
  emitPolish = false;
  /** wind phase written to aWind.x for the vertices added next (set per stem or blade) */
  curPhase = 0;
  /** aWind.y = aSway * windFlex (branch flex), aWind.z = aSway * windFlutter (leaf flutter) */
  windFlex = 0.35;
  windFlutter = 0.5;

  get vertexCount(): number { return this.pos.length / 3; }
  get triangleCount(): number { return this.idx.length / 3; }
  mark(): Mark { return { v: this.vertexCount, i: this.idx.length }; }

  rollback(m: Mark): void {
    const n = m.v;
    this.pos.length = n * 3; this.nor.length = n * 3; this.uvs.length = n * 2;
    this.col.length = n * 3; this.sway.length = n; this.polish.length = n; this.phase.length = n;
    this.idx.length = m.i;
  }

  vert(p: Vec3, n: Vec3, u: number, v: number, c: RGB, sway = 0): number {
    this.pos.push(p.x, p.y, p.z);
    this.nor.push(n.x, n.y, n.z);
    this.uvs.push(u, v);
    this.col.push(c[0], c[1], c[2]);
    this.sway.push(sway < 0 ? 0 : sway > 1 ? 1 : sway);
    this.polish.push(0);
    this.phase.push(this.curPhase);
    return this.vertexCount - 1;
  }
  tri(a: number, b: number, c: number): void { this.idx.push(a, b, c); }
  /** Quad a-b-c-d counter-clockwise as seen from the front. */
  quad(a: number, b: number, c: number, d: number): void { this.idx.push(a, b, c, a, c, d); }

  getP(i: number, out: Vec3): Vec3 { return out.set(this.pos[i * 3]!, this.pos[i * 3 + 1]!, this.pos[i * 3 + 2]!); }
  getN(i: number, out: Vec3): Vec3 { return out.set(this.nor[i * 3]!, this.nor[i * 3 + 1]!, this.nor[i * 3 + 2]!); }
  setP(i: number, p: Vec3): void { this.pos[i * 3] = p.x; this.pos[i * 3 + 1] = p.y; this.pos[i * 3 + 2] = p.z; }
  setN(i: number, n: Vec3): void { this.nor[i * 3] = n.x; this.nor[i * 3 + 1] = n.y; this.nor[i * 3 + 2] = n.z; }
  setC(i: number, c: RGB): void { this.col[i * 3] = c[0]; this.col[i * 3 + 1] = c[1]; this.col[i * 3 + 2] = c[2]; }
  getC(i: number): RGB { return [this.col[i * 3]!, this.col[i * 3 + 1]!, this.col[i * 3 + 2]!]; }

  /** Recompute smooth normals for vertices added since mark, from triangles added since mark. */
  smoothNormals(m: Mark): void {
    const acc = new Float64Array((this.vertexCount - m.v) * 3);
    const a = v3(), b = v3(), c = v3(), e1 = v3(), e2 = v3(), fn = v3();
    for (let t = m.i; t < this.idx.length; t += 3) {
      const ia = this.idx[t]!, ib = this.idx[t + 1]!, ic = this.idx[t + 2]!;
      this.getP(ia, a); this.getP(ib, b); this.getP(ic, c);
      fn.crossVectors(e1.subVectors(b, a), e2.subVectors(c, a)); // area weighted
      for (const k of [ia, ib, ic]) {
        if (k < m.v) continue;
        const o = (k - m.v) * 3;
        acc[o] = acc[o]! + fn.x; acc[o + 1] = acc[o + 1]! + fn.y; acc[o + 2] = acc[o + 2]! + fn.z;
      }
    }
    for (let k = m.v; k < this.vertexCount; k++) {
      const o = (k - m.v) * 3;
      fn.set(acc[o]!, acc[o + 1]!, acc[o + 2]!);
      if (fn.lengthSq() < 1e-20) fn.set(0, 1, 0);
      this.setN(k, fn.normalize());
    }
  }

  /** Paint every vertex since mark: fn(position, normal, index) -> linear RGB. */
  paint(m: Mark, fn: (p: Vec3, n: Vec3, i: number) => RGB): void {
    const p = v3(), n = v3();
    for (let k = m.v; k < this.vertexCount; k++) this.setC(k, fn(this.getP(k, p), this.getN(k, n), k));
  }
  /** Multiply existing colors since mark by a scalar function (AO passes). */
  shade(m: Mark, fn: (p: Vec3, n: Vec3) => number): void {
    const p = v3(), n = v3();
    for (let k = m.v; k < this.vertexCount; k++) this.setC(k, mul(this.getC(k), fn(this.getP(k, p), this.getN(k, n))));
  }
  setSway(m: Mark, fn: (p: Vec3) => number): void {
    const p = v3();
    for (let k = m.v; k < this.vertexCount; k++) this.sway[k] = clamp01(fn(this.getP(k, p)));
  }
  setPolish(m: Mark, fn: (p: Vec3, n: Vec3) => number): void {
    this.emitPolish = true;
    const p = v3(), n = v3();
    for (let k = m.v; k < this.vertexCount; k++) this.polish[k] = clamp01(fn(this.getP(k, p), this.getN(k, n)));
  }
  transform(m: Mark, mat: THREE.Matrix4): void {
    const p = v3(), n = v3();
    const nm = new THREE.Matrix3().getNormalMatrix(mat);
    for (let k = m.v; k < this.vertexCount; k++) {
      this.setP(k, this.getP(k, p).applyMatrix4(mat));
      this.setN(k, this.getN(k, n).applyMatrix3(nm).normalize());
    }
    if (mat.determinant() < 0) {
      for (let t = m.i; t < this.idx.length; t += 3) {
        const tmp = this.idx[t + 1]!; this.idx[t + 1] = this.idx[t + 2]!; this.idx[t + 2] = tmp;
      }
    }
  }
  /** Box-projected UVs (for tiling detail maps on stone/wood/metal). */
  boxUV(m: Mark, scale: number): void {
    const p = v3(), n = v3();
    for (let k = m.v; k < this.vertexCount; k++) {
      this.getP(k, p); this.getN(k, n);
      const ax = Math.abs(n.x), ay = Math.abs(n.y), az = Math.abs(n.z);
      let u: number, v: number;
      if (ay >= ax && ay >= az) { u = p.x; v = p.z; } else if (ax >= az) { u = p.z; v = p.y; } else { u = p.x; v = p.y; }
      this.uvs[k * 2] = u * scale; this.uvs[k * 2 + 1] = v * scale;
    }
  }

  /** Append another (indexed or not) geometry. Colors default to white; paint afterwards. */
  appendGeometry(geo: THREE.BufferGeometry, mat?: THREE.Matrix4): Mark {
    const m = this.mark();
    const P = geo.getAttribute('position');
    const N = geo.getAttribute('normal');
    const U = geo.getAttribute('uv');
    const p = v3(), n = v3();
    const nm = mat ? new THREE.Matrix3().getNormalMatrix(mat) : null;
    for (let k = 0; k < P.count; k++) {
      p.set(P.getX(k), P.getY(k), P.getZ(k));
      if (N) n.set(N.getX(k), N.getY(k), N.getZ(k)); else n.set(0, 1, 0);
      if (mat && nm) { p.applyMatrix4(mat); n.applyMatrix3(nm).normalize(); }
      this.vert(p, n, U ? U.getX(k) : 0, U ? U.getY(k) : 0, [1, 1, 1], 0);
    }
    const flip = mat ? mat.determinant() < 0 : false;
    const I = geo.getIndex();
    const count = I ? I.count : P.count;
    for (let t = 0; t < count; t += 3) {
      const a = (I ? I.getX(t) : t) + m.v, b = (I ? I.getX(t + 1) : t + 1) + m.v, c = (I ? I.getX(t + 2) : t + 2) + m.v;
      if (flip) this.tri(a, c, b); else this.tri(a, b, c);
    }
    return m;
  }

  build(): THREE.BufferGeometry {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uvs, 2));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 3));
    g.setAttribute('aSway', new THREE.Float32BufferAttribute(this.sway, 1));
    // project wind shader input (FoliageMaterials.patchWind): phase, branch flex, leaf flutter
    const aw = new Float32Array(this.vertexCount * 3);
    for (let i = 0; i < this.vertexCount; i++) { const s = this.sway[i]!; aw[i * 3] = this.phase[i]!; aw[i * 3 + 1] = s * this.windFlex; aw[i * 3 + 2] = s * this.windFlutter; }
    g.setAttribute('aWind', new THREE.Float32BufferAttribute(aw, 3));
    if (this.emitPolish) g.setAttribute('aPolish', new THREE.Float32BufferAttribute(this.polish, 1));
    g.setIndex(this.vertexCount > 65535 ? new THREE.Uint32BufferAttribute(this.idx, 1) : new THREE.Uint16BufferAttribute(this.idx, 1));
    g.computeBoundingBox();
    g.computeBoundingSphere();
    return g;
  }
}

// ---------------------------------------------------------------- frames

export interface Frame { p: Vec3; t: Vec3; n: Vec3; b: Vec3; s: number; }

/** Parallel-transport frames along a polyline; s = arc length from start. */
export function pathFrames(path: Vec3[]): Frame[] {
  const out: Frame[] = [];
  let prevN: Vec3 | null = null;
  let s = 0;
  for (let i = 0; i < path.length; i++) {
    const a = path[Math.max(0, i - 1)]!, c = path[Math.min(path.length - 1, i + 1)]!;
    const t = v3().subVectors(c, a);
    if (t.lengthSq() < 1e-14) t.set(0, 1, 0);
    t.normalize();
    if (i > 0) s += path[i]!.distanceTo(path[i - 1]!);
    let n: Vec3;
    if (!prevN) n = perpendicular(t);
    else {
      n = prevN.clone().addScaledVector(t, -prevN.dot(t));
      if (n.lengthSq() < 1e-10) n = perpendicular(t);
      n.normalize();
    }
    const b = v3().crossVectors(t, n).normalize();
    out.push({ p: path[i]!.clone(), t, n, b, s });
    prevN = n;
  }
  return out;
}

// ---------------------------------------------------------------- primitives

export interface UVRect { u0: number; v0: number; u1: number; v1: number; }

export interface TubeOpts {
  radial: number;
  radius: (t: number, s: number) => number;
  /** radius multiplier around the circumference, a in [0, 2pi) */
  radialNoise?: (t: number, a: number) => number;
  capEnd?: boolean;
  vScale?: number;
  color?: RGB;
}
/** Tube along a path. Returns mark. uv: u around, v along (meters * vScale). */
export function tube(b: MeshBuilder, path: Vec3[], o: TubeOpts): Mark {
  const m = b.mark();
  const fr = pathFrames(path);
  const L = fr[fr.length - 1]!.s || 1;
  const R = o.radial;
  const col = o.color ?? [1, 1, 1];
  const p = v3(), n = v3();
  for (let i = 0; i < fr.length; i++) {
    const f = fr[i]!;
    const t = f.s / L;
    const r0 = o.radius(t, f.s);
    for (let j = 0; j <= R; j++) {
      const a = (j / R) * Math.PI * 2;
      const r = r0 * (o.radialNoise ? o.radialNoise(t, a % (Math.PI * 2)) : 1);
      n.copy(f.n).multiplyScalar(Math.cos(a)).addScaledVector(f.b, Math.sin(a));
      p.copy(f.p).addScaledVector(n, r);
      b.vert(p, n, j / R, f.s * (o.vScale ?? 1), col);
    }
  }
  const row = R + 1;
  for (let i = 0; i < fr.length - 1; i++)
    for (let j = 0; j < R; j++) {
      const a = m.v + i * row + j;
      b.quad(a, a + 1, a + row + 1, a + row);
    }
  if (o.capEnd) {
    const f = fr[fr.length - 1]!;
    const c = b.vert(f.p, f.t, 0.5, f.s * (o.vScale ?? 1), col);
    const base = m.v + (fr.length - 1) * row;
    for (let j = 0; j < R; j++) b.tri(base + j, base + j + 1, c);
  }
  b.smoothNormals(m);
  return m;
}

export interface RibbonOpts {
  width: (t: number) => number;
  /** side direction at parameter t (will be orthogonalized against the tangent) */
  side: (t: number, tangent: Vec3) => Vec3;
  /** twist in radians accumulated at the tip */
  twist?: number;
  color: (t: number) => RGB;
  sway: (t: number, s: number) => number;
  uv: UVRect;
  /** blend the geometric normal toward this direction (soft volumetric shading) */
  normalBias?: Vec3;
  normalBiasAmt?: number;
}
/** Flat tapered strip along a path (grass blades, thin stems). 2 tris per segment. */
export function ribbon(b: MeshBuilder, path: Vec3[], o: RibbonOpts): Mark {
  const m = b.mark();
  const fr = pathFrames(path);
  const L = fr[fr.length - 1]!.s || 1;
  const p = v3(), n = v3(), side = v3(), q = new THREE.Quaternion();
  for (let i = 0; i < fr.length; i++) {
    const f = fr[i]!;
    const t = f.s / L;
    side.copy(o.side(t, f.t));
    side.addScaledVector(f.t, -side.dot(f.t));
    if (side.lengthSq() < 1e-10) side.copy(f.n);
    side.normalize();
    if (o.twist) side.applyQuaternion(q.setFromAxisAngle(f.t, o.twist * t));
    n.crossVectors(side, f.t).normalize();
    if (o.normalBias) n.lerp(o.normalBias, o.normalBiasAmt ?? 0.5).normalize();
    const w = o.width(t) * 0.5;
    const c = o.color(t);
    const sw = o.sway(t, f.s);
    const vv = lerp(o.uv.v0, o.uv.v1, t);
    p.copy(f.p).addScaledVector(side, -w);
    b.vert(p, n, o.uv.u0, vv, c, sw);
    p.copy(f.p).addScaledVector(side, w);
    b.vert(p, n, o.uv.u1, vv, c, sw);
  }
  for (let i = 0; i < fr.length - 1; i++) {
    const a = m.v + i * 2;
    b.quad(a, a + 1, a + 3, a + 2);
  }
  return m;
}

export interface CardOpts {
  uv: UVRect;
  color: RGB | ((s: number, t: number) => RGB);
  /** sway at bottom and top edge */
  sway: [number, number];
  normal?: Vec3;
  /** 'bottom': origin is the bottom-center; 'center': origin is the middle */
  pivot?: 'bottom' | 'center';
  segments?: number;
  /** offset added at the far end, scaled by t^2 (droop/curl) */
  curl?: Vec3;
}
/** Alpha-cutout card spanned by axisU (width) and axisV (height). */
export function card(b: MeshBuilder, origin: Vec3, axisU: Vec3, axisV: Vec3, w: number, h: number, o: CardOpts): Mark {
  const m = b.mark();
  const segs = o.segments ?? 1;
  const n = o.normal ? o.normal.clone().normalize() : v3().crossVectors(axisU, axisV).normalize();
  const p = v3();
  const v0 = o.pivot === 'center' ? -0.5 : 0;
  for (let i = 0; i <= segs; i++) {
    const t = i / segs;
    for (let j = 0; j <= 1; j++) {
      p.copy(origin).addScaledVector(axisU, (j - 0.5) * w).addScaledVector(axisV, (t + v0) * h);
      if (o.curl) p.addScaledVector(o.curl, t * t);
      const c = typeof o.color === 'function' ? o.color(j, t) : o.color;
      b.vert(p, n, lerp(o.uv.u0, o.uv.u1, j), lerp(o.uv.v0, o.uv.v1, t), c, lerp(o.sway[0], o.sway[1], t));
    }
  }
  for (let i = 0; i < segs; i++) {
    const a = m.v + i * 2;
    b.quad(a, a + 1, a + 3, a + 2);
  }
  return m;
}

/** Surface of revolution around +Y. profile: [radius, y]. */
export function lathe(
  b: MeshBuilder, profile: readonly (readonly [number, number])[], segs: number,
  o: { radialDisplace?: (a: number, y: number, r: number) => number; phase?: number; capTop?: boolean } = {},
): Mark {
  const m = b.mark();
  const p = v3(), n = v3(0, 1, 0);
  const ph = o.phase ?? 0;
  for (let i = 0; i < profile.length; i++) {
    const [r0, y] = profile[i]!;
    for (let j = 0; j <= segs; j++) {
      const a = (j / segs) * Math.PI * 2 + ph;
      const r = r0 + (o.radialDisplace ? o.radialDisplace(a, y, r0) : 0);
      p.set(Math.cos(a) * r, y, Math.sin(a) * r);
      b.vert(p, n, j / segs, y, [1, 1, 1]);
    }
  }
  const row = segs + 1;
  for (let i = 0; i < profile.length - 1; i++)
    for (let j = 0; j < segs; j++) {
      const a = m.v + i * row + j;
      b.quad(a, a + row, a + row + 1, a + 1);
    }
  if (o.capTop) {
    const last = profile[profile.length - 1]!;
    const c = b.vert(v3(0, last[1], 0), v3(0, 1, 0), 0.5, last[1], [1, 1, 1]);
    const base = m.v + (profile.length - 1) * row;
    for (let j = 0; j < segs; j++) b.tri(base + j + 1, base + j, c);
  }
  b.smoothNormals(m);
  return m;
}

/** Cube-sphere blob with shared vertices. disp(dir) is a radius multiplier.
 *  squareness 0 = sphere, 1 = box. */
export function blob(
  b: MeshBuilder, n: number, center: Vec3, radii: Vec3,
  disp?: (dir: Vec3) => number, squareness = 0,
): Mark {
  const m = b.mark();
  const map = new Map<string, number>();
  const p = v3(), d = v3();
  const id = (ix: number, iy: number, iz: number): number => {
    const key = ix + ',' + iy + ',' + iz;
    const got = map.get(key);
    if (got !== undefined) return got;
    p.set((ix / n) * 2 - 1, (iy / n) * 2 - 1, (iz / n) * 2 - 1);
    d.copy(p).normalize();
    const q = d.clone().lerp(p.clone().multiplyScalar(0.8), squareness);
    const k = disp ? disp(d) : 1;
    const pos = v3(center.x + q.x * radii.x * k, center.y + q.y * radii.y * k, center.z + q.z * radii.z * k);
    const v = b.vert(pos, d, 0, 0, [1, 1, 1]);
    map.set(key, v);
    return v;
  };
  // six faces; each face as (axis, sign)
  const faces: [number, number][] = [[0, 1], [0, -1], [1, 1], [1, -1], [2, 1], [2, -1]];
  for (const [axis, sign] of faces) {
    const fixed = sign > 0 ? n : 0;
    for (let i = 0; i < n; i++)
      for (let j = 0; j < n; j++) {
        const g = (a: number, c: number): number => {
          const co = [0, 0, 0];
          co[axis] = fixed;
          co[(axis + 1) % 3] = a;
          co[(axis + 2) % 3] = c;
          return id(co[0]!, co[1]!, co[2]!);
        };
        const a = g(i, j), bb = g(i + 1, j), c = g(i + 1, j + 1), dd = g(i, j + 1);
        if (sign > 0) b.quad(a, bb, c, dd); else b.quad(a, dd, c, bb);
      }
  }
  b.smoothNormals(m);
  return m;
}

/** Axis-aligned box (flat normals) transformed by mat. 12 tris. */
export function box(b: MeshBuilder, size: Vec3, mat: THREE.Matrix4): Mark {
  const g = new THREE.BoxGeometry(size.x, size.y, size.z);
  const m = b.appendGeometry(g, mat);
  g.dispose();
  return m;
}

/** Round card (fan) for umbels, flower heads, leaf drifts seen from above.
 *  depth > 0 raises the rim (cupped), < 0 domes it. */
export function discCard(
  b: MeshBuilder, center: Vec3, axisU: Vec3, axisV: Vec3, radius: number, ring: number,
  uv: UVRect, color: RGB, sway: number, depth = 0, normal?: Vec3,
): Mark {
  const m = b.mark();
  const n = normal ? normal.clone().normalize() : v3().crossVectors(axisU, axisV).normalize();
  const up = v3().crossVectors(axisU, axisV).normalize();
  const uc = (uv.u0 + uv.u1) / 2, vc = (uv.v0 + uv.v1) / 2, hu = (uv.u1 - uv.u0) / 2, hv = (uv.v1 - uv.v0) / 2;
  const c = b.vert(center, n, uc, vc, color, sway);
  const p = v3();
  for (let i = 0; i < ring; i++) {
    const a = (i / ring) * Math.PI * 2;
    p.copy(center).addScaledVector(axisU, Math.cos(a) * radius).addScaledVector(axisV, Math.sin(a) * radius).addScaledVector(up, depth);
    b.vert(p, n, uc + Math.cos(a) * hu, vc + Math.sin(a) * hv, color, sway);
  }
  for (let i = 0; i < ring; i++) b.tri(c, m.v + 1 + i, m.v + 1 + ((i + 1) % ring));
  return m;
}

/** Thin quad facing the given normal (cheap far LOD pieces). */
export function quad(b: MeshBuilder, center: Vec3, axisU: Vec3, axisV: Vec3, w: number, h: number, c: RGB, uv: UVRect): Mark {
  return card(b, center, axisU, axisV, w, h, { uv, color: c, sway: [0, 0], pivot: 'center' });
}

export const mat4 = (pos: Vec3, rot?: THREE.Euler | THREE.Quaternion, scale?: Vec3): THREE.Matrix4 => {
  const q = rot instanceof THREE.Euler ? new THREE.Quaternion().setFromEuler(rot) : rot ?? new THREE.Quaternion();
  return new THREE.Matrix4().compose(pos, q, scale ?? v3(1, 1, 1));
};

/** Build a box collider from a geometry's bounding box. */
export function boxColliderOf(g: THREE.BufferGeometry, shrink = 1): BoxCollider {
  if (!g.boundingBox) g.computeBoundingBox();
  const bb = g.boundingBox!;
  const c = bb.getCenter(v3()), s = bb.getSize(v3()).multiplyScalar(0.5 * shrink);
  return { type: 'box', center: [c.x, c.y, c.z], halfExtents: [s.x, s.y, s.z] };
}

// ---------------------------------------------------------------- materials

const materialCache = new Map<string, THREE.Material>();
/** Materials are cached by key so every instance of a family shares one
 *  program and one draw-call state. Treat returned materials as read-only;
 *  clone before customizing. */
export function cachedMaterial<T extends THREE.Material>(key: string, make: () => T): T {
  let m = materialCache.get(key);
  if (!m) { m = make(); materialCache.set(key, m); }
  return m as T;
}

/** Ensures no asset exceeds its LOD budget: runs `step` while it fits, rolls
 *  back the step that overflows and stops. Returns false once full. */
export function withinBudget(b: MeshBuilder, budget: number, step: () => void): boolean {
  const m = b.mark();
  step();
  if (b.triangleCount > budget) { b.rollback(m); return false; }
  return true;
}
