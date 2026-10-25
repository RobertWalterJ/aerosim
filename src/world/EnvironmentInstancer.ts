// Places the procedural environment asset families (meadow clumps, hedges,
// shrubs, iron railings and gates, the stone boundary wall, ground clutter,
// a Victorian memorial section, snags, rock outcrops and parked 1980s cars)
// on the valley terrain and keeps them in distance-based LOD buckets.
// Density, LOD distances, variant count and shadow casting scale with the
// quality preset (QualityPreset.env in src/config.ts).
import * as THREE from 'three';
import type { QualityPreset } from '../config';
import { mulberry32, fbm2 } from '../util/noise';
import { smoothstep } from '../util/math';
import type { ValleyTerrain } from './ValleyTerrain';
import type { Colliders } from './Colliders';
import type { TreeRec } from './FoliageInstancer';
import type { AssetResult, LOD } from './assetkit/AssetCore';
import { meadowClump, MEADOW_VARIANTS } from './MeadowGrass';
import { hedge, shrub, SHRUB_TYPES } from './HedgesShrubs';
import { ironFence, ironGate, stoneWall } from './FencesWalls';
import { leafDrift, nutScatter, twigs, fallenBranch, mossPatch, soilPatch } from './GroundClutter';
import { headstone, willowMarker, urnMonument, crossMonument, angelMonument, kerbedPlot, bouquet, graveFlag } from './MemorialDetails';
import { deadTree, snag, hollowStump, rockOutcrop } from './SnagsRocks';
import { vehicle, VEHICLE_STYLES } from './Vehicles';

interface Inst { x: number; y: number; z: number; ry: number; rx: number; rz: number; s: number; v: number; tint: number; }

type Built = { geometry: THREE.BufferGeometry; material: THREE.Material | THREE.Material[] };
interface FamilyDef {
  name: string;
  /** variant builders (each must be deterministic) */
  variants: ((lod: LOD) => Built)[];
  /** LOD0 / LOD1 switch distances and cull distance in meters (scaled by quality) */
  d: [number, number, number];
  /** true for objects big enough to keep casting shadows on 'large' presets */
  large: boolean;
}

/** One asset family: per (variant, LOD) InstancedMeshes plus the instance list. */
class Family {
  readonly items: Inst[] = [];
  private meshes: THREE.InstancedMesh[][] = [];  // [variant][lod]
  private built = false;
  constructor(readonly def: FamilyDef, private group: THREE.Group, private lodScale: number, private shadowsAll: boolean) {}
  add(i: Inst): void { this.items.push(i); }
  build(): void {
    if (this.built) return;
    this.built = true;
    const counts = this.def.variants.map(() => 0);
    for (const it of this.items) counts[it.v]!++;
    this.def.variants.forEach((mk, v) => {
      const row: THREE.InstancedMesh[] = [];
      for (const lod of [0, 1, 2] as LOD[]) {
        if (counts[v] === 0) { row.push(null as unknown as THREE.InstancedMesh); continue; }
        const a = mk(lod);
        const im = new THREE.InstancedMesh(a.geometry, a.material, counts[v]!);
        im.name = `${this.def.name}:v${v}:lod${lod}`;
        im.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
        im.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(counts[v]! * 3), 3);
        im.count = 0; im.visible = false; im.frustumCulled = false;
        im.castShadow = lod < 2 && (this.shadowsAll || this.def.large);
        im.receiveShadow = true;
        this.group.add(im);
        row.push(im);
      }
      this.meshes.push(row);
    });
  }
  private m = new THREE.Matrix4(); private q = new THREE.Quaternion(); private e = new THREE.Euler(0, 0, 0, 'YXZ');
  private p = new THREE.Vector3(); private sc = new THREE.Vector3();
  rebucket(cam: THREE.Vector3): { visible: number; tris: number } {
    const [d0, d1, d2] = this.def.d.map((d) => d * this.lodScale) as [number, number, number];
    const n = this.meshes.map((r) => (r ? [0, 0, 0] : [0, 0, 0]));
    let visible = 0, tris = 0;
    for (const it of this.items) {
      const dx = it.x - cam.x, dz = it.z - cam.z, dy = it.y - cam.y;
      const dd = Math.sqrt(dx * dx + dz * dz + dy * dy * 0.25);
      if (dd > d2) continue;
      const lod = dd < d0 ? 0 : dd < d1 ? 1 : 2;
      const im = this.meshes[it.v]?.[lod];
      if (!im) continue;
      const k = n[it.v]![lod]!++;
      this.e.set(it.rx, it.ry, it.rz);
      this.m.compose(this.p.set(it.x, it.y, it.z), this.q.setFromEuler(this.e), this.sc.set(it.s, it.s, it.s));
      im.setMatrixAt(k, this.m);
      im.instanceColor!.setXYZ(k, it.tint, it.tint, it.tint);
      visible++;
    }
    this.meshes.forEach((row, v) => row.forEach((im, lod) => {
      if (!im) return;
      im.count = n[v]![lod]!;
      im.visible = im.count > 0;
      im.instanceMatrix.needsUpdate = true;
      if (im.instanceColor) im.instanceColor.needsUpdate = true;
      tris += im.count * (im.geometry.index ? im.geometry.index.count / 3 : 0);
    }));
    return { visible, tris };
  }
  meshCount(): number { return this.meshes.reduce((a, r) => a + r.filter((m) => m && m.visible).length, 0); }
}

export interface EnvironmentContext {
  trees: TreeRec[];
  exclusions: [number, number, number, number][];
  chapelPos: THREE.Vector3;
  monumentPos: THREE.Vector3;
}

export class EnvironmentInstancer {
  group = new THREE.Group();
  readonly families: Family[] = [];
  private lastBucket = -1;
  /** last rebucket statistics: instances in range and triangles submitted */
  stats = { instances: 0, tris: 0, meshes: 0 };

  constructor(private T: ValleyTerrain, private C: Colliders, private q: QualityPreset, private ctx: EnvironmentContext, onProgress?: (f: number) => void) {
    this.group.name = 'environment-assets';
    const E = q.env;
    const vn = (n: number): number => Math.max(1, Math.round(n * E.variants));
    const fam = (name: string, variants: ((lod: LOD) => Built)[], d: [number, number, number], large: boolean): Family => {
      const f = new Family({ name, variants, d, large }, this.group, E.lodScale, E.shadows === 'all');
      this.families.push(f);
      return f;
    };
    const seeds = (n: number, f: (s: number, lod: LOD) => AssetResult, base = 0): ((lod: LOD) => AssetResult)[] => Array.from({ length: n }, (_, i) => (lod: LOD) => f(base + i, lod));

    // ---- families
    const meadow = fam('meadow', MEADOW_VARIANTS.map((_, v) => (lod: LOD) => meadowClump(v * 31 + 5, lod, v)).slice(0, vn(MEADOW_VARIANTS.length)), [22, 55, 150], false);
    const box = fam('hedge-boxwood', [(lod: LOD) => hedge(2, lod, { type: 'boxwood', length: 2, caps: 'none', height: 0.75, width: 0.6 }), (lod: LOD) => hedge(4, lod, { type: 'boxwood', length: 2, caps: 'none', height: 0.75, width: 0.6 })].slice(0, vn(2)), [35, 90, 420], true);
    const yew = fam('hedge-yew', [(lod) => hedge(7, lod, { type: 'yew', length: 3, height: 1.7, width: 1.0 })], [40, 110, 500], true);
    const shrubs = fam('shrubs', SHRUB_TYPES.flatMap((t, ti) => [0, 1].map((k) => (lod: LOD) => shrub(ti * 2 + k + 1, lod, { type: t }))).slice(0, vn(8)), [35, 100, 450], true);
    const fence = fam('iron-fence', seeds(vn(3), (s, lod) => ironFence(s, lod, { length: 3, curb: true, rust: 0.35 + s * 0.12 })), [30, 80, 350], true);
    const gate = fam('iron-gate', [(lod) => ironGate(3, lod, { width: 3.4, piers: true, ajar: 0 })], [40, 120, 600], true);
    const wall = fam('stone-wall', seeds(vn(4), (s, lod) => stoneWall(s, lod, { length: 3, height: 1.05, coping: s % 2 ? 'upright' : 'flat' })), [35, 110, 700], true);
    const drift = fam('leaf-drift', seeds(vn(4), (s, lod) => leafDrift(s, lod, { mix: (['oak', 'maple', 'beech', 'mixed'] as const)[s % 4] })), [18, 45, 120], false);
    const nuts = fam('nuts', seeds(vn(2), nutScatter), [10, 25, 45], false);
    const twig = fam('twigs', seeds(vn(2), twigs), [12, 30, 60], false);
    const branch = fam('fallen-branch', seeds(vn(3), fallenBranch), [20, 55, 140], false);
    const moss = fam('moss', seeds(vn(3), mossPatch), [15, 40, 90], false);
    const soil = fam('soil', seeds(vn(2), soilPatch), [15, 40, 100], false);
    const memVariants: ((lod: LOD) => AssetResult)[] = [
      ...seeds(8, headstone), ...seeds(2, willowMarker, 3), ...seeds(2, urnMonument, 1), ...seeds(3, crossMonument), ...seeds(3, angelMonument, 1), ...seeds(2, kerbedPlot, 1),
    ];
    const mem = fam('memorials', memVariants.slice(0, Math.max(6, vn(memVariants.length))), [30, 80, 320], true);
    const tokens = fam('bouquets-flags', [...seeds(vn(4), bouquet), ...seeds(2, graveFlag)], [14, 35, 80], false);
    const snags = fam('snags', [...seeds(vn(3), (s, lod) => deadTree(s + 1, lod)), ...seeds(vn(3), snag, 2), ...seeds(2, hollowStump, 3)], [45, 130, 900], true);
    const rocks = fam('rocks', seeds(vn(4), (s, lod) => rockOutcrop(s + 1, lod)), [50, 150, 1200], true);
    const cars = fam('vehicles', VEHICLE_STYLES.map((_, i) => (lod: LOD) => vehicle(i * 17 + 3, lod, { style: i })).slice(0, Math.max(5, vn(VEHICLE_STYLES.length))), [30, 90, 520], true);
    onProgress?.(0.1);

    // ---- placement
    const rng = mulberry32(9090);
    const D = E.density;
    const excluded = (x: number, z: number, pad = 0): boolean => ctx.exclusions.some(([x0, z0, x1, z1]) => x > x0 - pad && x < x1 + pad && z > z0 - pad && z < z1 + pad);
    const nearTrunk = (x: number, z: number, r: number): boolean => { const p = [0, 0, 0]; return this.C.hit(x, 1.0, z, r, p); };
    const nrm = [0, 1, 0];
    const tilt = (x: number, z: number, k = 1): [number, number] => { T.normal(x, z, nrm); return [Math.atan2(nrm[2]!, nrm[1]!) * k, -Math.atan2(nrm[0]!, nrm[1]!) * k]; };
    const put = (f: Family, x: number, z: number, o: Partial<Inst> & { v: number }, sink = 0): void => {
      const [rx, rz] = tilt(x, z, 0.8);
      f.add({ x, y: T.height(x, z) - sink, z, ry: o.ry ?? rng() * Math.PI * 2, rx: o.rx ?? rx, rz: o.rz ?? rz, s: o.s ?? 1, v: o.v, tint: o.tint ?? 0.9 + rng() * 0.2 });
    };
    const nv = (f: Family): number => f.def.variants.length;

    // meadow: unmown, unforested ground between the park lawns and the woods
    {
      const target = Math.round(46000 * D);
      const R0 = 120, R1 = 380, area = Math.PI * (R1 * R1 - R0 * R0);
      const step = Math.sqrt(area / (target * 2.2));
      let placed = 0;
      for (let gx = -R1; gx < R1 && placed < target; gx += step) for (let gz = -R1; gz < R1 && placed < target; gz += step) {
        const x = gx + rng() * step, z = gz + rng() * step, r = Math.hypot(x, z);
        if (r < R0 || r > R1) continue;
        const open = (1 - T.mown(x, z)) * (1 - T.forest(x, z));
        if (open < 0.35 || T.distToPath(x, z) < 2.4 || excluded(x, z, 1)) continue;
        const patch = smoothstep(0.35, 0.65, fbm2(x / 40 + 7, z / 40 - 3, 3));
        if (rng() > open * (0.35 + 0.65 * patch)) continue;
        // species form swaths: variant from low-frequency noise
        const v = Math.min(nv(meadow) - 1, Math.floor(fbm2(x / 28 - 11, z / 28 + 5, 2) * nv(meadow) * 1.6 + rng() * 1.5) % nv(meadow));
        put(meadow, x, z, { v, s: 0.75 + 0.5 * rng() * (0.6 + 0.4 * patch), rx: (rng() - 0.5) * 0.15, rz: (rng() - 0.5) * 0.15 });
        placed++;
      }
    }
    onProgress?.(0.3);

    // boxwood hedges along the three spur walks near the memorial plaza, yew around the chapel
    for (const pi of [3, 4, 5]) {
      const pl = T.polylines[pi]!;
      let acc = 0;
      for (let i = 1; i < pl.length; i++) {
        const [ax, az] = pl[i - 1]!, [bx, bz] = pl[i]!;
        const L = Math.hypot(bx - ax, bz - az);
        acc += L;
        if (acc < 2.05) continue;
        acc = 0;
        const dist = Math.hypot(bx - ctx.monumentPos.x, bz - ctx.monumentPos.z);
        if (dist < 14 || dist > 70) continue;
        const tx = (bx - ax) / L, tz = (bz - az) / L;
        for (const side of [-1, 1]) {
          const x = bx + -tz * 2.9 * side, z = bz + tx * 2.9 * side;
          if (excluded(x, z, 0.5) || nearTrunk(x, z, 0.8)) continue;
          put(box, x, z, { v: Math.floor(rng() * nv(box)), ry: -Math.atan2(tz, tx), rx: 0, rz: 0, tint: 0.95 + rng() * 0.1 }, 0.02);
          this.C.addCyl({ x, z, r: 0.45, y0: T.height(x, z), y1: T.height(x, z) + 0.8, kind: 'small' });
        }
      }
    }
    {
      const c = ctx.chapelPos;
      for (let k = 0; k < 8; k++) {
        const a = (k / 8) * Math.PI * 2, x = c.x + Math.cos(a) * 15, z = c.z + Math.sin(a) * 15;
        if (excluded(x, z, 0.5) || T.distToPath(x, z) < 2.5 || nearTrunk(x, z, 1.5)) continue;
        put(yew, x, z, { v: 0, ry: Math.atan2(-Math.cos(a), -Math.sin(a)), rx: 0, rz: 0 }, 0.03);
        this.C.addCyl({ x, z, r: 0.9, y0: T.height(x, z), y1: T.height(x, z) + 1.7, kind: 'small' });
      }
    }
    // shrubs: lilac, forsythia, boxwood balls and yew mounds along the loop verges
    {
      const pl = T.polylines[0]!;
      const n = Math.round(90 * D);
      for (let k = 0; k < n; k++) {
        const i = Math.floor(rng() * (pl.length - 2)) + 1;
        const [ax, az] = pl[i - 1]!, [bx, bz] = pl[i + 1]!;
        const L = Math.hypot(bx - ax, bz - az) || 1, side = rng() < 0.5 ? -1 : 1, off = 5 + rng() * 6;
        const x = pl[i]![0] + (-(bz - az) / L) * off * side, z = pl[i]![1] + ((bx - ax) / L) * off * side;
        if (excluded(x, z, 1.5) || T.distToPath(x, z) < 3 || nearTrunk(x, z, 2.5)) continue;
        put(shrubs, x, z, { v: Math.floor(rng() * nv(shrubs)), s: 0.85 + rng() * 0.3, rx: 0, rz: 0 });
        this.C.addCyl({ x, z, r: 0.8, y0: T.height(x, z), y1: T.height(x, z) + 2.0, kind: 'small' });
      }
    }
    onProgress?.(0.45);

    // boundary: dry stone wall ring at r ~ 238 m with iron railings and gates where the avenues cross
    {
      const R = 238, avenues: number[] = [];
      for (const pi of [1, 2]) {
        const pl = T.polylines[pi]!;
        for (let i = 1; i < pl.length; i++) {
          const r0 = Math.hypot(pl[i - 1]![0], pl[i - 1]![1]), r1 = Math.hypot(pl[i]![0], pl[i]![1]);
          if ((r0 - R) * (r1 - R) <= 0) avenues.push(Math.atan2(pl[i]![1], pl[i]![0]));
        }
      }
      const angDist = (a: number, b: number): number => Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b)));
      const segA = 3 / R, gateHalf = 2.4 / R, fenceHalf = 26 / R;
      for (let a = 0; a < Math.PI * 2; a += segA) {
        const am = a + segA / 2;
        const near = Math.min(...avenues.map((av) => angDist(am, av)));
        const x = Math.cos(am) * R, z = Math.sin(am) * R;
        const ry = Math.atan2(-Math.cos(am), -Math.sin(am)); // local +X along the ring tangent
        if (near < gateHalf) continue;
        const y0 = T.height(x, z);
        const xa = Math.cos(a) * R, za = Math.sin(a) * R, xb = Math.cos(a + segA) * R, zb = Math.sin(a + segA) * R;
        const pitch = Math.atan2(T.height(xb, zb) - T.height(xa, za), 3);
        if (near < fenceHalf) {
          // railing wings either side of each gate
          fence.add({ x, y: y0 - 0.06, z, ry, rx: 0, rz: pitch, s: 1, v: Math.floor(rng() * nv(fence)), tint: 1 });
        } else {
          wall.add({ x, y: y0 - 0.08, z, ry, rx: 0, rz: pitch, s: 1, v: Math.floor(rng() * nv(wall)), tint: 0.92 + rng() * 0.12 });
        }
        this.C.addCyl({ x, z, r: 1.6, y0: y0, y1: y0 + 1.1, kind: 'small' });
      }
      for (const av of avenues) {
        const x = Math.cos(av) * R, z = Math.sin(av) * R;
        gate.add({ x, y: T.height(x, z) - 0.05, z, ry: Math.atan2(-Math.cos(av), -Math.sin(av)), rx: 0, rz: 0, s: 1, v: 0, tint: 1 });
      }
    }
    onProgress?.(0.55);

    // ground clutter under trees, along paths and at the wall foot
    {
      for (const t of ctx.trees) {
        const r = Math.hypot(t.x, t.z);
        if (r > 520 || rng() > D) continue;
        if (!t.conifer && rng() < 0.75) {
          const a = rng() * Math.PI * 2, d = 1 + rng() * t.crownR * 0.6;
          const x = t.x + Math.cos(a) * d, z = t.z + Math.sin(a) * d;
          if (T.distToPath(x, z) > 1.8 && !excluded(x, z)) put(drift, x, z, { v: Math.floor(rng() * nv(drift)), s: 0.8 + rng() * 0.8 }, 0.01);
          if (t.variant === 4 && rng() < 0.6) put(nuts, t.x + Math.cos(a + 2) * 1.5, t.z + Math.sin(a + 2) * 1.5, { v: Math.floor(rng() * nv(nuts)) });
        }
        if (r > 200 && rng() < 0.35) {
          const a = rng() * Math.PI * 2, x = t.x + Math.cos(a) * 3, z = t.z + Math.sin(a) * 3;
          put(rng() < 0.5 ? branch : twig, x, z, { v: Math.floor(rng() * 2) }, 0.02);
        }
        if (r < 230 && rng() < 0.25) put(moss, t.x + 0.8, t.z - 0.6, { v: Math.floor(rng() * nv(moss)), s: 0.6 + rng() * 0.6 });
      }
      for (const [x0, z0, x1, z1] of ctx.exclusions) {
        if (rng() > 0.6) continue;
        put(moss, x1 + 0.4, (z0 + z1) / 2, { v: Math.floor(rng() * nv(moss)), s: 0.5 + rng() * 0.4 });
        put(soil, (x0 + x1) / 2, z1 + 0.6, { v: Math.floor(rng() * nv(soil)), s: 0.6 + rng() * 0.5 });
        void x0;
      }
      const pl = T.polylines[0]!;
      for (let k = 0; k < Math.round(60 * D); k++) {
        const p = pl[Math.floor(rng() * pl.length)]!;
        const x = p[0] + (rng() - 0.5) * 5, z = p[1] + (rng() - 0.5) * 5;
        if (T.distToPath(x, z) > 1.4 && T.distToPath(x, z) < 3 && !excluded(x, z)) put(soil, x, z, { v: Math.floor(rng() * nv(soil)), s: 0.5 + rng() * 0.5 });
      }
    }
    onProgress?.(0.65);

    // Victorian memorial section: find a clear lawn block and lay out rows
    {
      const site = this.findClearBlock(28, 16, ctx);
      if (site) {
        const [cx, cz, yaw] = site;
        const ca = Math.cos(yaw), sa = Math.sin(yaw);
        let k = 0;
        for (let row = 0; row < 5; row++) for (let col = 0; col < 9; col++) {
          k++;
          if (rng() < 0.12) continue;
          const lx = (col - 4) * 2.8 + (rng() - 0.5) * 0.3, lz = (row - 2) * 3.0 + (rng() - 0.5) * 0.2;
          const x = cx + lx * ca - lz * sa, z = cz + lx * sa + lz * ca;
          if (excluded(x, z, 0.5) || nearTrunk(x, z, 0.8)) continue;
          const v = (k * 7 + Math.floor(rng() * 5)) % nv(mem);
          put(mem, x, z, { v, ry: -yaw + Math.PI + (rng() - 0.5) * 0.06, rx: (rng() - 0.5) * 0.04, rz: (rng() - 0.5) * 0.04 }, 0.03);
          this.C.addCyl({ x, z, r: 0.45, y0: T.height(x, z), y1: T.height(x, z) + 1.3, kind: 'small' });
          if (rng() < 0.4) {
            const bx = x + 0.45 * Math.cos(yaw + Math.PI / 2), bz = z + 0.45 * Math.sin(yaw + Math.PI / 2);
            put(tokens, bx, bz, { v: Math.floor(rng() * nv(tokens)), s: 1 });
          }
        }
      }
    }
    onProgress?.(0.75);

    // snags at the forest margin, rock outcrops on the steep valley walls
    {
      const nS = Math.round(160 * D), nR = Math.round(260 * D);
      let s = 0, r = 0;
      for (let k = 0; k < 40000 && (s < nS || r < nR); k++) {
        const a = rng() * Math.PI * 2, d = 220 + Math.sqrt(rng()) * 900;
        const x = Math.cos(a) * d, z = Math.sin(a) * d;
        const f = T.forest(x, z), ny = T.normalY(x, z);
        if (s < nS && f > 0.25 && f < 0.75 && ny > 0.9 && T.distToPath(x, z) > 4) {
          put(snags, x, z, { v: Math.floor(rng() * nv(snags)), rx: (rng() - 0.5) * 0.08, rz: (rng() - 0.5) * 0.08, s: 0.8 + rng() * 0.4 }, 0.05);
          this.C.addCyl({ x, z, r: 0.35, y0: T.height(x, z), y1: T.height(x, z) + 9, kind: 'trunk' });
          s++;
        } else if (r < nR && ny < 0.93 && ny > 0.6) {
          put(rocks, x, z, { v: Math.floor(rng() * nv(rocks)), s: 0.7 + rng() * 1.1 }, 0.1);
          this.C.addCyl({ x, z, r: 1.5, y0: T.height(x, z), y1: T.height(x, z) + 2, kind: 'small' });
          r++;
        }
      }
    }
    // parked cars: chapel car park (nose-in bays) and occasional cars on the avenue verges outside the gates
    {
      const c = ctx.chapelPos;
      const lot: [number, number, number][] = [];
      for (let k = 0; k < 9; k++) lot.push([c.x - 13 + k * 2.9, c.z + 22, rng() < 0.75 ? 0 : Math.PI]);
      for (const pi of [1, 2]) {
        const pl = T.polylines[pi]!;
        let acc = 0, next = 6 + rng() * 10;
        for (let i = 1; i < pl.length; i++) {
          const [ax, az] = pl[i - 1]!, [bx, bz] = pl[i]!;
          const L = Math.hypot(bx - ax, bz - az) || 1;
          acc += L;
          const r = Math.hypot(bx, bz);
          if (r < 250 || r > 340 || acc < next) continue;
          acc = 0; next = 7 + rng() * 26;
          const side = rng() < 0.5 ? -1 : 1;
          lot.push([bx + (-(bz - az) / L) * 4.0 * side, bz + ((bx - ax) / L) * 4.0 * side, Math.atan2(-(bx - ax), -(bz - az)) + (side < 0 ? Math.PI : 0)]);
        }
      }
      const want = Math.max(4, Math.round(lot.length * Math.min(1, 0.4 + D)));
      for (const [x, z, ry] of lot.slice(0, want)) {
        if (excluded(x, z, 1) || nearTrunk(x, z, 2.2) || T.distToPath(x, z) < 2.2) continue;
        put(cars, x, z, { v: Math.floor(rng() * nv(cars)), ry: ry + (rng() - 0.5) * 0.08 }, 0.0);
        this.C.addCyl({ x, z, r: 1.6, y0: T.height(x, z), y1: T.height(x, z) + 1.5, kind: 'small' });
      }
    }
    onProgress?.(0.85);
    for (const f of this.families) f.build();
    this.rebucket(new THREE.Vector3(0, 60, 0), true);
    onProgress?.(1);
  }

  /** Search the mown park for a rectangle clear of paths, exclusions and trees. Returns centre and yaw. */
  private findClearBlock(w: number, d: number, ctx: EnvironmentContext): [number, number, number] | null {
    const T = this.T;
    let best: [number, number, number] | null = null, bestScore = -1;
    const p = [0, 0, 0];
    for (let r = 40; r < 170; r += 9) for (let a = 0; a < Math.PI * 2; a += 0.21) {
      const cx = Math.cos(a) * r, cz = Math.sin(a) * r, yaw = a + Math.PI / 2;
      const ca = Math.cos(yaw), sa = Math.sin(yaw);
      let ok = true, score = 0;
      for (let i = -2; i <= 2 && ok; i++) for (let j = -2; j <= 2 && ok; j++) {
        const lx = (i / 2) * (w / 2), lz = (j / 2) * (d / 2);
        const x = cx + lx * ca - lz * sa, z = cz + lx * sa + lz * ca;
        if (T.distToPath(x, z) < 4 || T.mown(x, z) < 0.6 || this.C.hit(x, 1, z, 2.5, p)) ok = false;
        if (ctx.exclusions.some(([x0, z0, x1, z1]) => x > x0 - 2 && x < x1 + 2 && z > z0 - 2 && z < z1 + 2)) ok = false;
        score += T.normalY(x, z);
      }
      if (ok && score > bestScore) { bestScore = score; best = [cx, cz, yaw]; }
    }
    return best;
  }

  /** Re-bucket all families by camera distance (call every frame; runs ~2 Hz). */
  rebucket(cam: THREE.Vector3, force = false): void {
    const now = Math.floor(performance.now() / 450);
    if (!force && now === this.lastBucket) return;
    this.lastBucket = now;
    let inst = 0, tris = 0, meshes = 0;
    for (const f of this.families) { const r = f.rebucket(cam); inst += r.visible; tris += r.tris; meshes += f.meshCount(); }
    this.stats = { instances: inst, tris, meshes };
  }

  update(cam: THREE.Vector3): void { this.rebucket(cam); }
}
