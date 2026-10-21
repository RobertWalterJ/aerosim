import { WORLD } from '../config';
import { noise3, curl3, noise2 } from '../util/noise';
import { V3, DEG, smoothstep, clamp } from '../util/math';

export interface WindObstacle { x: number; z: number; r: number; h: number; base: number; }

/**
 * Atmospheric boundary layer wind:
 *   u(z) = (u_star / k) ln((z-d)/z0)   logarithmic shear above displacement height d
 *   + frozen-turbulence gusts (Taylor) advected with the mean wind
 *   + curl-noise eddies / downdrafts in the lee of registered obstacles (trees, buildings)
 */
export class WindField {
  dirX: number; dirZ: number;           // unit vector the wind blows TOWARD
  uStar: number; z0 = 0.05; kappa = 0.4;
  gustiness = 1; t = 0;
  private grid = new Map<number, WindObstacle[]>();
  private readonly cell = 96;
  constructor(public groundH: (x: number, z: number) => number) {
    // wind blows FROM windDirDeg (compass, 0 = north = -z, 90 = east = +x)
    const from = WORLD.windDirDeg * DEG;
    const fx = Math.sin(from), fz = -Math.cos(from);
    this.dirX = -fx; this.dirZ = -fz;
    this.uStar = (WORLD.windRefSpeed * this.kappa) / Math.log(WORLD.windRefHeight / this.z0);
  }
  addObstacles(obs: WindObstacle[]): void {
    for (const o of obs) {
      const key = this.key(Math.floor(o.x / this.cell), Math.floor(o.z / this.cell));
      let a = this.grid.get(key); if (!a) this.grid.set(key, (a = [])); a.push(o);
    }
  }
  private key(i: number, j: number) { return (i + 4096) * 8192 + (j + 4096); }
  /** Mean log-profile speed at height above ground. */
  profile(zAgl: number, canopyTop = 0): number {
    const d = canopyTop * 0.7; // displacement above forest canopy
    const z = Math.max(zAgl - d, 0.12);
    const z0 = canopyTop > 0 ? 0.1 * canopyTop : this.z0;
    return Math.max(0, (this.uStar / this.kappa) * Math.log(z / z0)) * (canopyTop > 0 ? 1 : 1);
  }
  sample(x: number, y: number, z: number, t: number, out: V3): V3 {
    const zAgl = Math.max(y - this.groundH(x, z), 0.05);
    // valley channelling: stronger flow once clear of the ridge-line / canopy
    let u = this.profile(zAgl) * (1 + 0.25 * smoothstep(20, 120, zAgl));
    // frozen turbulence advected by mean wind
    const adv = t * WORLD.windRefSpeed * 0.8;
    const ti = (0.10 + 0.22 * Math.exp(-zAgl / 12)) * this.gustiness;
    const gx = noise3(x * 0.021 - this.dirX * adv * 0.021, y * 0.04, z * 0.021 - this.dirZ * adv * 0.021 + t * 0.0) - 0.5;
    const gy = noise3(x * 0.05 + 17.1 - this.dirX * adv * 0.05, y * 0.08 + t * 0.15, z * 0.05 - this.dirZ * adv * 0.05) - 0.5;
    const fast = noise3(x * 0.2 + t * 1.3, y * 0.2, z * 0.2 - t * 0.9) - 0.5;
    const gust = 1 + ti * 3.2 * gx;
    u *= Math.max(0.1, gust);
    const sideSway = (noise2(t * 0.11 + 4.3, 7.7) - 0.5) * 0.5;
    let wx = this.dirX * u + (-this.dirZ) * u * sideSway * 0.3 + fast * ti * u * 0.8;
    let wz = this.dirZ * u + (this.dirX) * u * sideSway * 0.3 + fast * ti * u * 0.8;
    let wy = gy * ti * u * 1.4;
    // leeward eddy volumes
    const ci = Math.floor(x / this.cell), cj = Math.floor(z / this.cell);
    const cv = [0, 0, 0];
    for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) {
      const arr = this.grid.get(this.key(ci + a, cj + b)); if (!arr) continue;
      for (const o of arr) {
        const dx = x - o.x, dz = z - o.z;
        const along = dx * this.dirX + dz * this.dirZ;        // + = downwind of obstacle
        const cross = -dx * this.dirZ + dz * this.dirX;
        const L = 7 * o.h;
        if (along < -o.r || along > L) continue;
        const width = o.r * (1 + 0.28 * Math.max(along, 0) / Math.max(o.r, 1));
        if (Math.abs(cross) > width * 1.4) continue;
        const hAgl = y - o.base;
        if (hAgl > o.h * 1.5 || hAgl < -1) continue;
        const wLat = Math.exp(-Math.pow(cross / width, 2));
        const wLong = Math.exp(-Math.pow(Math.max(along - o.r, 0) / (L * 0.5), 2));
        const wVert = 1 - smoothstep(0.7, 1.5, hAgl / o.h);
        const wgt = wLat * wLong * wVert;
        if (wgt < 0.01) continue;
        curl3(x * 0.35 - adv * 0.2 * this.dirX, y * 0.35 + t * 0.4, z * 0.35 - adv * 0.2 * this.dirZ, cv);
        const amp = u * 1.6 * wgt;
        // wake deficit + turbulent curl + downdraft behind canopy
        const deficit = 0.55 * wgt;
        wx = wx * (1 - deficit) + cv[0] * amp; wz = wz * (1 - deficit) + cv[2] * amp;
        wy += cv[1] * amp - 0.35 * u * wgt;
      }
    }
    out[0] = wx; out[1] = wy; out[2] = wz;
    return out;
  }
  /** cheap canopy-level wind for foliage/audio */
  canopyWind(x: number, z: number, t: number, out: V3): V3 { return this.sample(x, this.groundH(x, z) + 14, z, t, out); }
}
