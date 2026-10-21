import { clamp } from '../util/math';

export type ColliderKind = 'trunk' | 'canopy' | 'monument' | 'building' | 'small';
export interface Cyl { x: number; z: number; r: number; y0: number; y1: number; kind: ColliderKind; }
export interface Box { x0: number; z0: number; x1: number; z1: number; y0: number; y1: number; kind: ColliderKind; }

/** Spatial hash of vertical cylinders + AABBs for collisions, RF line-of-sight and acoustic reflections. */
export class Colliders {
  private cell = 24;
  private cyls = new Map<number, Cyl[]>(); private boxes = new Map<number, Box[]>();
  all: Cyl[] = []; allBoxes: Box[] = [];
  private key(i: number, j: number) { return (i + 2048) * 4096 + (j + 2048); }
  addCyl(c: Cyl): void {
    this.all.push(c);
    const i0 = Math.floor((c.x - c.r) / this.cell), i1 = Math.floor((c.x + c.r) / this.cell), j0 = Math.floor((c.z - c.r) / this.cell), j1 = Math.floor((c.z + c.r) / this.cell);
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) { const k = this.key(i, j); let a = this.cyls.get(k); if (!a) this.cyls.set(k, (a = [])); a.push(c); }
  }
  addBox(b: Box): void {
    this.allBoxes.push(b);
    const i0 = Math.floor(b.x0 / this.cell), i1 = Math.floor(b.x1 / this.cell), j0 = Math.floor(b.z0 / this.cell), j1 = Math.floor(b.z1 / this.cell);
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) { const k = this.key(i, j); let a = this.boxes.get(k); if (!a) this.boxes.set(k, (a = [])); a.push(b); }
  }
  /** Sphere vs solid colliders (trunks, monuments, buildings; canopies are soft and ignored). */
  hit(x: number, y: number, z: number, r: number, push: number[]): boolean {
    const i = Math.floor(x / this.cell), j = Math.floor(z / this.cell); let hit = false;
    for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) {
      const k = this.key(i + a, j + b);
      const cs = this.cyls.get(k);
      if (cs) for (const c of cs) {
        if (c.kind === 'canopy' || y < c.y0 - r || y > c.y1 + r) continue;
        const dx = x - c.x, dz = z - c.z, d = Math.hypot(dx, dz), R = c.r + r;
        if (d < R) { const s = (R - d) / Math.max(d, 1e-4); push[0] = dx * s; push[2] = dz * s; hit = true; }
      }
      const bs = this.boxes.get(k);
      if (bs) for (const bx of bs) {
        if (y < bx.y0 - r || y > bx.y1 + r) continue;
        const cx = clamp(x, bx.x0, bx.x1), cz = clamp(z, bx.z0, bx.z1), dx = x - cx, dz = z - cz, d = Math.hypot(dx, dz);
        if (d < r) { const s = d > 1e-4 ? (r - d) / d : 1; push[0] = dx * s + (d <= 1e-4 ? r : 0); push[2] = dz * s; hit = true; }
      }
    }
    return hit;
  }
  /**
   * RF attenuation (dB) along segment a->b: canopy 0.45 dB/m inside foliage cylinders, hard 14 dB per trunk/monument,
   * 26 dB per building. Terrain handled by caller.
   */
  rfLoss(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number {
    const L = Math.hypot(bx - ax, by - ay, bz - az); if (L < 1) return 0;
    const steps = Math.min(200, Math.ceil(L / 3)); let loss = 0; const seen = new Set<object>();
    for (let s = 0; s <= steps; s++) {
      const t = s / steps, x = ax + (bx - ax) * t, y = ay + (by - ay) * t, z = az + (bz - az) * t;
      const i = Math.floor(x / this.cell), j = Math.floor(z / this.cell), k = this.key(i, j);
      const cs = this.cyls.get(k);
      if (cs) for (const c of cs) {
        if (y < c.y0 || y > c.y1) continue;
        const d = Math.hypot(x - c.x, z - c.z); if (d > c.r) continue;
        if (c.kind === 'canopy') loss += 0.45 * (L / steps) * (1 - d / c.r * 0.5);
        else if (!seen.has(c)) { seen.add(c); loss += 14; }
      }
      const bs = this.boxes.get(k);
      if (bs) for (const bb of bs) { if (x > bb.x0 && x < bb.x1 && z > bb.z0 && z < bb.z1 && y > bb.y0 && y < bb.y1 && !seen.has(bb)) { seen.add(bb); loss += 26; } }
    }
    return loss;
  }
  /** nearest hard reflector distance along a horizontal ray (monuments/buildings only) */
  reflectorDistance(x: number, y: number, z: number, dx: number, dz: number, maxD: number): number {
    const steps = Math.ceil(maxD / 0.75);
    for (let s = 1; s <= steps; s++) {
      const d = s * 0.75, px = x + dx * d, pz = z + dz * d; const i = Math.floor(px / this.cell), j = Math.floor(pz / this.cell), k = this.key(i, j);
      const cs = this.cyls.get(k);
      if (cs) for (const c of cs) { if ((c.kind === 'monument' || c.kind === 'building') && y >= c.y0 && y <= c.y1 && Math.hypot(px - c.x, pz - c.z) < c.r) return d; }
      const bs = this.boxes.get(k);
      if (bs) for (const bb of bs) { if (px > bb.x0 && px < bb.x1 && pz > bb.z0 && pz < bb.z1 && y > bb.y0 && y < bb.y1) return d; }
    }
    return Infinity;
  }
}
