// Textures for the environment asset families: the shared foliage atlas and
// the mown-lawn ground-detail set. Rasterised into typed arrays and wrapped as
// THREE.DataTexture so they also build in Node tests without a DOM. Stone and
// bark detail come from ProceduralTextures (makeGranite, makeBark).
import * as THREE from 'three';
import { hash3i, makeRnd, range, type Rnd } from '../assetkit/AssetRng';
import { clamp01, lerp, smoothstep, type RGB, type UVRect, hex, mix } from '../assetkit/AssetCore';

// ---------------------------------------------------------------- pixel buffer

const SRGB_LUT = (() => {
  const t = new Uint8Array(4096);
  for (let i = 0; i < 4096; i++) {
    const l = i / 4095;
    const s = l <= 0.0031308 ? l * 12.92 : 1.055 * Math.pow(l, 1 / 2.4) - 0.055;
    t[i] = Math.round(s * 255);
  }
  return t;
})();

export class Pixels {
  readonly data: Float32Array;
  constructor(readonly w: number, readonly h: number) {
    this.data = new Float32Array(w * h * 4);
  }
  /** Alpha-over composite of a color at (x, y) with coverage a. */
  over(x: number, y: number, c: RGB, a: number): void {
    if (a <= 0) return;
    const o = (y * this.w + x) * 4;
    const d = this.data;
    const da = d[o + 3]!;
    if (da >= 1) { // opaque destination: plain lerp
      const ia = 1 - a;
      d[o] = c[0] * a + d[o]! * ia; d[o + 1] = c[1] * a + d[o + 1]! * ia; d[o + 2] = c[2] * a + d[o + 2]! * ia;
      return;
    }
    const na = a + da * (1 - a);
    for (let k = 0; k < 3; k++) d[o + k] = (c[k]! * a + d[o + k]! * da * (1 - a)) / Math.max(na, 1e-6);
    d[o + 3] = na;
  }
  /** Pixels hold LINEAR values. srgb = true encodes RGB with the sRGB
   *  transfer curve (alpha stays linear) for SRGBColorSpace textures. */
  toBytes(srgb = false): Uint8Array<ArrayBuffer> {
    const out = new Uint8Array(new ArrayBuffer(this.w * this.h * 4));
    const d = this.data;
    const lut = srgb ? SRGB_LUT : null;
    for (let i = 0; i < out.length; i++) {
      const v = d[i]!;
      const c = v <= 0 ? 0 : v >= 1 ? 1 : v;
      out[i] = lut && (i & 3) !== 3 ? lut[(c * 4095) | 0]! : (c * 255 + 0.5) | 0;
    }
    return out;
  }
  toImageData(srgb = true): ImageData {
    return new ImageData(new Uint8ClampedArray(this.toBytes(srgb)), this.w, this.h);
  }
  toTexture(opts: { srgb: boolean; repeat: boolean }): THREE.DataTexture {
    const t = new THREE.DataTexture(this.toBytes(opts.srgb), this.w, this.h, THREE.RGBAFormat, THREE.UnsignedByteType);
    t.colorSpace = opts.srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
    t.wrapS = t.wrapT = opts.repeat ? THREE.RepeatWrapping : THREE.ClampToEdgeWrapping;
    t.magFilter = THREE.LinearFilter;
    t.minFilter = THREE.LinearMipmapLinearFilter;
    t.generateMipmaps = true;
    t.anisotropy = 8;
    t.flipY = false;
    t.needsUpdate = true;
    return t;
  }
}

// ---------------------------------------------------------------- tileable noise

/** Periodic value noise: tiles every `period` lattice units. */
export function tileNoise(x: number, y: number, period: number, seed: number): number {
  const xi = Math.floor(x), yi = Math.floor(y);
  const fx = x - xi, fy = y - yi;
  const ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy);
  const m = (k: number): number => ((k % period) + period) % period;
  const h = (i: number, j: number): number => hash3i(m(i), m(j), 0, seed);
  return lerp(lerp(h(xi, yi), h(xi + 1, yi), ux), lerp(h(xi, yi + 1), h(xi + 1, yi + 1), ux), uy);
}
/** Tileable fbm in [0,1]; u,v in [0,1) tile space. */
export function tileFbm(u: number, v: number, basePeriod: number, octaves: number, seed: number, gain = 0.5): number {
  let s = 0, a = 1, n = 0, p = basePeriod;
  for (let o = 0; o < octaves; o++) {
    s += a * tileNoise(u * p, v * p, p, seed + o * 101);
    n += a; a *= gain; p *= 2;
  }
  return s / n;
}

/**
 * Whole-image tileable fbm in [0,1] (fast path for texture generation).
 * periodX/periodY are lattice cells across the image for the first octave.
 */
export function fbmMap(S: number, periodX: number, periodY: number, octaves: number, seed: number, gain = 0.5): Float32Array {
  const out = new Float32Array(S * S);
  let amp = 1, norm = 0, px = periodX, py = periodY;
  for (let o = 0; o < octaves; o++) {
    const PX = Math.max(1, Math.round(px)), PY = Math.max(1, Math.round(py));
    const lat = new Float32Array(PX * PY);
    for (let j = 0; j < PY; j++) for (let i = 0; i < PX; i++) lat[j * PX + i] = hash3i(i, j, o, seed);
    for (let y = 0; y < S; y++) {
      const fy = (y / S) * PY, yi = Math.floor(fy), ty = fy - yi, uy = ty * ty * (3 - 2 * ty);
      const r0 = (yi % PY) * PX, r1 = ((yi + 1) % PY) * PX;
      for (let x = 0; x < S; x++) {
        const fx = (x / S) * PX, xi = Math.floor(fx), tx = fx - xi, ux = tx * tx * (3 - 2 * tx);
        const x0 = xi % PX, x1 = (xi + 1) % PX;
        const a = lat[r0 + x0]! + (lat[r0 + x1]! - lat[r0 + x0]!) * ux;
        const b = lat[r1 + x0]! + (lat[r1 + x1]! - lat[r1 + x0]!) * ux;
        out[y * S + x] = out[y * S + x]! + amp * (a + (b - a) * uy);
      }
    }
    norm += amp; amp *= gain; px *= 2; py *= 2;
  }
  for (let i = 0; i < out.length; i++) out[i] = out[i]! / norm;
  return out;
}

// ---------------------------------------------------------------- foliage atlas

export const ATLAS_SIZE = 1024;
const CELLS = 4;
const CELL = ATLAS_SIZE / CELLS;

export const Cell = {
  Foxtail: 0, Timothy: 1, Bluestem: 2, Umbel: 3,
  Goldenrod: 4, Aster: 5, Silk: 6, Broadleaf: 7,
  Boxwood: 8, Yew: 9, Lilac: 10, Forsythia: 11,
  OakLeaf: 12, MapleLeaf: 13, EllipticLeaf: 14, Solid: 15,
} as const;
export type CellId = (typeof Cell)[keyof typeof Cell];

/** UV rectangle for an atlas cell, inset to avoid mip bleeding. */
export function cellUV(id: CellId): UVRect {
  const cx = id % CELLS, cy = Math.floor(id / CELLS);
  const pad = 3 / ATLAS_SIZE;
  return { u0: cx / CELLS + pad, v0: cy / CELLS + pad, u1: (cx + 1) / CELLS - pad, v1: (cy + 1) / CELLS - pad };
}
/** A 1-texel-wide opaque UV strip inside the Solid cell (for ribbons, blobs). */
export function solidUV(): UVRect {
  const r = cellUV(Cell.Solid);
  return { u0: lerp(r.u0, r.u1, 0.2), v0: r.v0, u1: lerp(r.u0, r.u1, 0.8), v1: r.v1 };
}

type LeafShape = 'ellipse' | 'lance' | 'heart' | 'oak' | 'needle' | 'round';

class CellPainter {
  constructor(private px: Pixels, private ox: number, private oy: number, private rnd: Rnd) {}
  private put(x: number, y: number, c: RGB, a: number): void {
    const X = Math.floor(x), Y = Math.floor(y);
    if (X < 0 || Y < 0 || X >= CELL || Y >= CELL) return;
    this.px.over(this.ox + X, this.oy + Y, c, a);
  }
  /** Capsule from (x0,y0) to (x1,y1), coordinates in cell units 0..1 (y up = +v). */
  line(x0: number, y0: number, x1: number, y1: number, width: number, c: RGB): void {
    const S = CELL;
    const ax = x0 * S, ay = y0 * S, bx = x1 * S, by = y1 * S, hw = Math.max(0.35, (width * S) / 2);
    const minX = Math.floor(Math.min(ax, bx) - hw - 1), maxX = Math.ceil(Math.max(ax, bx) + hw + 1);
    const minY = Math.floor(Math.min(ay, by) - hw - 1), maxY = Math.ceil(Math.max(ay, by) + hw + 1);
    const dx = bx - ax, dy = by - ay, L2 = dx * dx + dy * dy || 1;
    const thin = hw < 0.5 ? hw * 2 : 1;
    for (let y = minY; y <= maxY; y++)
      for (let x = minX; x <= maxX; x++) {
        const px = x + 0.5 - ax, py = y + 0.5 - ay;
        const t = clamp01((px * dx + py * dy) / L2);
        const ex = px - dx * t, ey = py - dy * t;
        const d = Math.sqrt(ex * ex + ey * ey);
        this.put(x, y, c, clamp01(Math.max(hw, 0.5) - d + 0.5) * thin);
      }
  }
  disc(cx: number, cy: number, r: number, c: RGB, soft = 0): void {
    const S = CELL, X = cx * S, Y = cy * S, R = r * S;
    for (let y = Math.floor(Y - R - 1); y <= Y + R + 1; y++)
      for (let x = Math.floor(X - R - 1); x <= X + R + 1; x++) {
        const d = Math.hypot(x + 0.5 - X, y + 0.5 - Y);
        const a = soft > 0 ? clamp01((R - d) / (soft * S + 0.5)) : clamp01(R - d + 0.5);
        this.put(x, y, c, a);
      }
  }
  /** Leaf with base at (cx,cy), pointing at angle (radians, 0 = up). */
  leaf(cx: number, cy: number, angle: number, len: number, wid: number, shape: LeafShape, tone: number, opts: { vein?: boolean; serrate?: number } = {}): void {
    const S = CELL, X = cx * S, Y = cy * S, Lp = len * S, Wp = (wid * S) / 2;
    const sa = Math.sin(angle), ca = Math.cos(angle);
    const R = Lp + Wp + 2;
    const lobes = 2 + Math.floor(this.rnd() * 3);
    const phase = this.rnd() * 6.28;
    for (let y = Math.floor(Y - R); y <= Y + R; y++)
      for (let x = Math.floor(X - R); x <= X + R; x++) {
        const dx = x + 0.5 - X, dy = y + 0.5 - Y;
        const along = (dx * sa + dy * ca) / Lp;
        const acr = (dx * ca - dy * sa) / Wp;
        if (along < -0.02 || along > 1.02) continue;
        const u = clamp01(along);
        let w: number;
        switch (shape) {
          case 'ellipse': w = Math.pow(Math.sin(Math.PI * u), 0.75); break;
          case 'lance': w = Math.pow(Math.sin(Math.PI * Math.pow(u, 0.7)), 1.1); break;
          case 'heart': w = Math.pow(Math.sin(Math.PI * Math.pow(u, 0.62)), 0.7) * (1 + 0.25 * (1 - u)); break;
          case 'oak': w = Math.pow(Math.sin(Math.PI * u), 0.6) * (0.55 + 0.45 * Math.pow(Math.abs(Math.cos(u * Math.PI * (lobes + 1.5) + phase * 0.1)), 0.6)); break;
          case 'needle': w = u < 0.92 ? 1 : (1 - u) / 0.08; break;
          case 'round': w = Math.sqrt(Math.max(0, 1 - Math.pow(2 * u - 1, 2))); break;
        }
        if (opts.serrate) w *= 1 - opts.serrate * (0.5 + 0.5 * Math.sin(u * 60));
        const d = (w - Math.abs(acr)) * Wp; // pixels inside edge
        const a = clamp01(d + 0.5) * clamp01((0.5 - Math.abs(along - 0.5)) * Lp + 0.5);
        if (a <= 0) continue;
        let v = tone * (0.92 + 0.08 * Math.sin(dx * 0.9 + dy * 1.3)); // fine mottle
        v *= 1 - 0.12 * Math.max(0, acr); // fold shading
        v *= 0.86 + 0.14 * smoothstep(0, 3, d); // darker rim
        if (opts.vein !== false) {
          if (Math.abs(acr) < 0.07) v *= 1.08;
          const lat = Math.abs(((along * 7 - Math.abs(acr) * 1.2) % 1) - 0.5);
          if (lat < 0.05) v *= 0.94;
        }
        this.put(x, y, [v, v, v], a);
      }
  }
  dots(cx: number, cy: number, rx: number, ry: number, n: number, r: number, tone: [number, number], c?: RGB): void {
    for (let i = 0; i < n; i++) {
      const a = this.rnd() * Math.PI * 2, d = Math.sqrt(this.rnd());
      const v = range(this.rnd, tone[0], tone[1]);
      this.disc(cx + Math.cos(a) * d * rx, cy + Math.sin(a) * d * ry, r * range(this.rnd, 0.6, 1.2), c ? [c[0] * v, c[1] * v, c[2] * v] : [v, v, v]);
    }
  }
}

const g = (v: number): RGB => [v, v, v];

function paintAtlas(seed: number): Pixels {
  const px = new Pixels(ATLAS_SIZE, ATLAS_SIZE);
  const rnd = makeRnd(seed, 77);
  const at = (id: CellId): CellPainter => new CellPainter(px, (id % CELLS) * CELL, Math.floor(id / CELLS) * CELL, rnd);
  const R = (a: number, b: number): number => range(rnd, a, b);

  // 0 foxtail: bristly nodding cylinder, rachis at bottom
  {
    const c = at(Cell.Foxtail);
    c.line(0.5, 0.0, 0.5, 0.25, 0.012, g(0.7));
    for (let i = 0; i < 520; i++) {
      const t = R(0.2, 0.97);
      const env = Math.pow(Math.sin(Math.PI * (t - 0.2) / 0.77), 0.6);
      const side = rnd() < 0.5 ? -1 : 1;
      const x0 = 0.5 + side * R(0, 0.09) * env, len = R(0.08, 0.2) * env;
      const ang = side * R(0.25, 1.1);
      c.line(x0, t, x0 + Math.sin(ang) * len, t + Math.cos(ang) * len * 0.8, 0.005, g(R(0.75, 1.0)));
    }
    c.dots(0.5, 0.58, 0.08, 0.36, 160, 0.012, [0.6, 0.85]);
  }
  // 1 timothy: dense cylindrical spike
  {
    const c = at(Cell.Timothy);
    c.line(0.5, 0.0, 0.5, 0.2, 0.014, g(0.72));
    for (let i = 0; i < 900; i++) {
      const t = R(0.16, 0.96);
      const env = 1 - Math.pow(Math.abs(t - 0.56) / 0.4, 6);
      c.disc(0.5 + R(-0.11, 0.11) * env, t, R(0.012, 0.022), g(R(0.62, 1.0)));
    }
    for (let i = 0; i < 160; i++) {
      const t = R(0.18, 0.95);
      c.line(0.5 + R(-0.1, 0.1), t, 0.5 + R(-0.17, 0.17), t + R(0, 0.03), 0.004, g(R(0.85, 1)));
    }
  }
  // 2 bluestem: zigzag rachis with silvery hairs
  {
    const c = at(Cell.Bluestem);
    let x = 0.5, y = 0.0;
    for (let k = 0; k < 9; k++) {
      const nx = 0.5 + (k % 2 ? 0.05 : -0.05), ny = y + 0.11;
      c.line(x, y, nx, ny, 0.012, g(0.62));
      for (let h = 0; h < 40; h++) {
        const a = R(-1.3, 1.3), l = R(0.05, 0.16);
        c.line(nx, ny, nx + Math.sin(a) * l, ny + Math.cos(a) * l * 0.7, 0.004, g(R(0.88, 1.0)));
      }
      c.leaf(nx, ny, (k % 2 ? 0.5 : -0.5), 0.07, 0.03, 'lance', R(0.55, 0.75), { vein: false });
      x = nx; y = ny;
    }
  }
  // 3 umbel (top view): rays to umbellets of tiny florets
  {
    const c = at(Cell.Umbel);
    const n = 34;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + R(-0.08, 0.08), r = R(0.18, 0.42);
      const ex = 0.5 + Math.cos(a) * r, ey = 0.5 + Math.sin(a) * r;
      c.line(0.5, 0.5, ex, ey, 0.006, g(0.66));
      c.dots(ex, ey, 0.05, 0.05, 26, 0.009, [0.78, 1.0]);
    }
    c.dots(0.5, 0.5, 0.12, 0.12, 40, 0.008, [0.8, 1.0]);
    c.disc(0.5, 0.5, 0.012, g(0.25));
  }
  // 4 goldenrod plume: arching axis with one-sided fluffy racemes
  {
    const c = at(Cell.Goldenrod);
    let x = 0.5, y = 0.0, a = 0;
    for (let k = 0; k < 14; k++) {
      a += 0.07;
      const nx = x + Math.sin(a) * 0.07, ny = y + Math.cos(a) * 0.07;
      c.line(x, y, nx, ny, 0.012, g(0.6));
      if (k > 2) {
        for (const side of [-1, 1]) {
          const ba = a + side * R(0.7, 1.3), bl = R(0.1, 0.26) * (1 - k / 18);
          let bx = nx, by = ny;
          for (let s = 0; s < 5; s++) {
            const tx = bx + Math.sin(ba + s * 0.15 * side) * bl / 5, ty = by + Math.cos(ba + s * 0.2 * side) * bl / 5 - 0.004 * s;
            c.line(bx, by, tx, ty, 0.005, g(0.6));
            c.dots(tx, ty + 0.012, 0.02, 0.016, 7, 0.011, [0.7, 1.0]);
            bx = tx; by = ty;
          }
        }
      }
      x = nx; y = ny;
    }
  }
  // 5 asters: cluster of small daisies (petals white, disc yellow -> tinted by vertex color)
  {
    const c = at(Cell.Aster);
    const heads: [number, number, number][] = [];
    for (let i = 0; i < 40 && heads.length < 8; i++) {
      const hx = R(0.18, 0.82), hy = R(0.18, 0.82), hr = R(0.08, 0.13);
      if (heads.every(([x, y, r]) => Math.hypot(x - hx, y - hy) > (r + hr) * 0.8)) heads.push([hx, hy, hr]);
    }
    for (const [hx, hy, hr] of heads) {
      const np = 18 + Math.floor(rnd() * 10);
      for (let p = 0; p < np; p++) {
        if (rnd() < 0.15) continue; // late season, petals dropping
        const a = (p / np) * Math.PI * 2 + R(-0.1, 0.1);
        c.leaf(hx + Math.cos(a) * hr * 0.25, hy + Math.sin(a) * hr * 0.25, Math.PI / 2 - a, hr * R(0.7, 0.95), hr * 0.16, 'ellipse', R(0.86, 1.0), { vein: false });
      }
      c.disc(hx, hy, hr * 0.3, [0.95, 0.72, 0.22]);
      c.dots(hx, hy, hr * 0.22, hr * 0.22, 12, hr * 0.06, [0.6, 0.9], [0.9, 0.62, 0.2]);
    }
  }
  // 6 silk tuft: radiating fine hairs with seeds (milkweed / thistle fluff)
  {
    const c = at(Cell.Silk);
    for (let s = 0; s < 4; s++) {
      const sx = R(0.35, 0.65), sy = R(0.15, 0.4);
      for (let h = 0; h < 90; h++) {
        const a = R(-1.4, 1.4), l = R(0.25, 0.55);
        c.line(sx, sy, sx + Math.sin(a) * l, sy + Math.cos(a) * l, 0.003, g(R(0.9, 1.0)));
      }
      c.leaf(sx, sy - 0.05, 0, 0.06, 0.04, 'ellipse', 0.4, { vein: false });
    }
  }
  // 7 broadleaf: single lanceolate leaf, base at bottom-center
  { const c = at(Cell.Broadleaf); c.line(0.5, 0.0, 0.5, 0.06, 0.02, g(0.7)); c.leaf(0.5, 0.04, 0, 0.94, 0.36, 'lance', 0.88); }

  // 8 boxwood: dense small oval leaves on twigs
  {
    const c = at(Cell.Boxwood);
    for (let t = 0; t < 7; t++) {
      const a = (t / 7) * Math.PI * 2 + R(-0.3, 0.3);
      const L = R(0.3, 0.45);
      const ex = 0.5 + Math.sin(a) * L, ey = 0.5 + Math.cos(a) * L;
      c.line(0.5, 0.5, ex, ey, 0.01, g(0.45));
      for (let k = 1; k <= 6; k++) {
        const f = k / 6.5, bx = lerp(0.5, ex, f), by = lerp(0.5, ey, f);
        for (const side of [-1, 1]) c.leaf(bx, by, a + side * R(0.5, 1.0), R(0.07, 0.1), R(0.045, 0.06), 'ellipse', R(0.7, 1.0), { vein: false });
      }
      c.leaf(ex, ey, a, 0.08, 0.05, 'ellipse', R(0.8, 1.0), { vein: false });
    }
    c.dots(0.5, 0.5, 0.36, 0.36, 70, 0.025, [0.55, 0.95]);
  }
  // 9 yew: flat sprays of two-ranked needles
  {
    const c = at(Cell.Yew);
    for (let s = 0; s < 5; s++) {
      const a = (s / 5) * Math.PI * 2 + R(-0.4, 0.4);
      const L = R(0.32, 0.46);
      const ex = 0.5 + Math.sin(a) * L, ey = 0.5 + Math.cos(a) * L;
      c.line(0.5, 0.5, ex, ey, 0.008, g(0.5));
      for (let k = 0; k < 22; k++) {
        const f = 0.1 + (k / 22) * 0.9, bx = lerp(0.5, ex, f), by = lerp(0.5, ey, f);
        for (const side of [-1, 1]) c.leaf(bx, by, a + side * R(1.0, 1.4), R(0.06, 0.085), 0.016, 'needle', R(0.7, 1.0), { vein: false });
      }
    }
  }
  // 10 lilac: heart-shaped leaves around a node
  {
    const c = at(Cell.Lilac);
    const n = 6;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + R(-0.25, 0.25);
      const sx = 0.5 + Math.sin(a) * 0.06, sy = 0.5 + Math.cos(a) * 0.06;
      c.line(0.5, 0.5, sx, sy, 0.012, g(0.55));
      c.leaf(sx, sy, a, R(0.3, 0.42), R(0.22, 0.3), 'heart', R(0.75, 1.0));
    }
  }
  // 11 forsythia: twig with opposite serrated lance leaves
  {
    const c = at(Cell.Forsythia);
    c.line(0.15, 0.08, 0.85, 0.92, 0.014, g(0.5));
    for (let k = 1; k < 8; k++) {
      const f = k / 8, bx = lerp(0.15, 0.85, f), by = lerp(0.08, 0.92, f);
      for (const side of [-1, 1]) c.leaf(bx, by, 0.7 + side * R(0.7, 1.1), R(0.18, 0.26), R(0.07, 0.09), 'lance', R(0.7, 1.0), { serrate: 0.06 });
    }
  }
  // 12-14 fallen leaves, centered
  { const c = at(Cell.OakLeaf); c.line(0.5, 0.02, 0.5, 0.12, 0.018, g(0.6)); c.leaf(0.5, 0.08, 0, 0.88, 0.5, 'oak', 0.86); }
  {
    const c = at(Cell.MapleLeaf);
    c.line(0.5, 0.02, 0.5, 0.3, 0.014, g(0.6));
    for (const [a, l] of [[0, 0.6], [0.8, 0.48], [-0.8, 0.48], [1.7, 0.3], [-1.7, 0.3]] as const)
      c.leaf(0.5, 0.3, a, l, l * 0.55, 'lance', R(0.8, 0.95), { serrate: 0.15 });
    c.disc(0.5, 0.36, 0.09, g(0.88));
  }
  { const c = at(Cell.EllipticLeaf); c.line(0.5, 0.02, 0.5, 0.1, 0.016, g(0.6)); c.leaf(0.5, 0.08, 0, 0.88, 0.48, 'ellipse', 0.86, { serrate: 0.04 }); }

  // 15 solid with faint longitudinal striation (blades, stems, blobs)
  {
    const ox = (Cell.Solid % CELLS) * CELL, oy = Math.floor(Cell.Solid / CELLS) * CELL;
    for (let y = 0; y < CELL; y++)
      for (let x = 0; x < CELL; x++) {
        const v = 0.9 + 0.06 * Math.sin(x * 1.7) * Math.sin(x * 0.37 + 1) + 0.03 * (hash3i(x, y >> 4, 1, seed) - 0.5);
        px.over(ox + x, oy + y, g(v), 1);
      }
  }

  // Bleed: give transparent texels the average color of their cell so
  // mipmapped edges don't darken into halos.
  for (let id = 0; id < CELLS * CELLS; id++) {
    const ox = (id % CELLS) * CELL, oy = Math.floor(id / CELLS) * CELL;
    let r = 0, gg = 0, b = 0, n = 0;
    for (let y = 0; y < CELL; y++)
      for (let x = 0; x < CELL; x++) {
        const o = ((oy + y) * ATLAS_SIZE + ox + x) * 4;
        const a = px.data[o + 3]!;
        r += px.data[o]! * a; gg += px.data[o + 1]! * a; b += px.data[o + 2]! * a; n += a;
      }
    if (n > 0) { r /= n; gg /= n; b /= n; }
    for (let y = 0; y < CELL; y++)
      for (let x = 0; x < CELL; x++) {
        const o = ((oy + y) * ATLAS_SIZE + ox + x) * 4;
        const a = px.data[o + 3]!;
        px.data[o] = lerp(r, px.data[o]!, a); px.data[o + 1] = lerp(gg, px.data[o + 1]!, a); px.data[o + 2] = lerp(b, px.data[o + 2]!, a);
      }
  }
  return px;
}

let atlasTex: THREE.DataTexture | null = null;
/** Shared 1024x1024 foliage atlas (sRGB, alpha cutout). Mostly neutral grey
 *  detail; hue comes from vertex colors so one atlas serves all species. */
export function foliageAtlas(): THREE.DataTexture {
  if (!atlasTex) {
    atlasTex = paintAtlas(1234).toTexture({ srgb: true, repeat: false });
    atlasTex.name = 'aerosim-foliage-atlas';
  }
  return atlasTex;
}

// ---------------------------------------------------------------- lawn set

export interface LawnPalette {
  yellowGreen: RGB; blueGreen: RGB; drought: RGB; straw: RGB;
  thatch: RGB; soil: RGB; clover: RGB; cloverMark: RGB;
}
export const LAWN_PALETTE: LawnPalette = {
  yellowGreen: hex(0x667a3a), blueGreen: hex(0x47603c), drought: hex(0x948e58), straw: hex(0xa69c70),
  thatch: hex(0x5e5440), soil: hex(0x4a3e30), clover: hex(0x3e5a38), cloverMark: hex(0x728a62),
};

export interface LawnTextureSet {
  albedo: THREE.DataTexture; normal: THREE.DataTexture;
  /** low-frequency color multiplier (linear, texel * 2 = multiplier), tile it
   *  every ~64 m on top of albedo to break repetition: yellow-green vs
   *  blue-green swaths and drought-yellowed patches */
  macro: THREE.DataTexture;
  macroTileMeters: number;
  /** same tile with thin, trampled turf and soil showing; blend with a path mask */
  wornAlbedo: THREE.DataTexture; wornNormal: THREE.DataTexture;
  /** world size of one tile in meters */
  tileMeters: number;
}

function paintLawn(seed: number, size: number, wear: number, pal: LawnPalette): { alb: Pixels; nrm: Pixels } {
  const S = size, alb = new Pixels(S, S), H = new Float32Array(S * S);
  const rnd = makeRnd(seed, 900 + Math.round(wear * 10));
  const tone = fbmMap(S, 4, 4, 4, seed + 1), dry = fbmMap(S, 8, 8, 3, seed + 2), bare = fbmMap(S, 6, 6, 4, seed + 3), und = fbmMap(S, 16, 16, 3, seed + 4);
  for (let y = 0; y < S; y++)
    for (let x = 0; x < S; x++) {
      const i = y * S + x;
      // keep in-tile macro contrast low: large-scale variation belongs to the macro texture
      tone[i] = 0.5 + (tone[i]! - 0.5) * 0.6;
      dry[i] = smoothstep(0.66, 0.82, dry[i]! + wear * 0.08) * 0.35;
      bare[i] = smoothstep(0.7 - wear * 0.43, 0.86 - wear * 0.36, bare[i]!);
      // under-layer: thatch and soil
      const under = mix(pal.thatch, pal.soil, smoothstep(0.4, 0.7, und[i]!) * (0.4 + wear * 0.6));
      alb.over(x, y, under, 1);
    }
  const blades = Math.round(S * S * (0.42 - wear * 0.22));
  for (let k = 0; k < blades; k++) {
    const x0 = rnd() * S, y0 = rnd() * S;
    const i0 = (Math.floor(y0) % S) * S + (Math.floor(x0) % S);
    if (rnd() < bare[i0]! * 0.85) continue;
    const ang = rnd() * Math.PI * 2;
    const len = range(rnd, 4, 12) * (1 - wear * 0.4);
    const t = tone[i0]!, dr = dry[i0]!;
    let c = mix(pal.blueGreen, pal.yellowGreen, smoothstep(0.3, 0.7, t + (rnd() - 0.5) * 0.25));
    c = mix(c, rnd() < 0.5 ? pal.drought : pal.straw, dr * range(rnd, 0.5, 1));
    if (rnd() < 0.06) c = mix(c, pal.straw, 0.7); // dead blade
    if (wear > 0) c = mix(c, pal.thatch, wear * 0.45 * rnd());
    const lift = range(rnd, 0.5, 1);
    const steps = Math.ceil(len);
    for (let s = 0; s <= steps; s++) {
      const f = s / steps;
      const x = Math.floor(x0 + Math.cos(ang) * len * f + S) % S, y = Math.floor(y0 + Math.sin(ang) * len * f + S) % S;
      const sh = 0.72 + 0.4 * f * lift; // tips catch light, bases shadowed
      alb.over(x, y, [c[0] * sh, c[1] * sh, c[2] * sh], 0.9);
      const hi = y * S + x;
      H[hi] = Math.max(H[hi]!, lift * (0.4 + 0.6 * f));
    }
  }
  // clover flecks: trifoliate clusters, sheltered in the greener patches
  const clovers = Math.round(S * S * 0.0007 * (1 - wear * 0.6));
  for (let k = 0; k < clovers; k++) {
    const cx = rnd() * S, cy = rnd() * S;
    const ci = (Math.floor(cy) % S) * S + (Math.floor(cx) % S);
    if (dry[ci]! > 0.5 || rnd() < 0.4) continue;
    const n = 1 + Math.floor(rnd() * 5);
    for (let c2 = 0; c2 < n; c2++) {
      const ox = cx + range(rnd, -14, 14), oy = cy + range(rnd, -14, 14), rot = rnd() * 6.28, r = range(rnd, 2.5, 4.5);
      for (let l = 0; l < 3; l++) {
        const a = rot + (l * Math.PI * 2) / 3;
        const lx = ox + Math.cos(a) * r, ly = oy + Math.sin(a) * r;
        for (let dy = -r - 1; dy <= r + 1; dy++)
          for (let dx = -r - 1; dx <= r + 1; dx++) {
            const d = Math.hypot(dx, dy);
            const cov = clamp01(r - d + 0.5);
            if (cov <= 0) continue;
            const mark = Math.abs(d - r * 0.55) < 0.8 ? 0.6 : 0;
            const col = mix(pal.clover, pal.cloverMark, mark);
            const x = Math.floor(lx + dx + S) % S, y = Math.floor(ly + dy + S) % S;
            alb.over(x, y, mul3(col, 0.9 + 0.2 * (1 - d / r)), cov);
            H[y * S + x] = Math.max(H[y * S + x]!, 0.9);
          }
      }
    }
  }
  // normal from height (OpenGL convention, +Y green up), wrapped
  const nrm = new Pixels(S, S);
  const strength = 2.2;
  const nd = nrm.data;
  for (let y = 0; y < S; y++) {
    const yu = ((y + 1) % S) * S, yd = ((y - 1 + S) % S) * S, yc = y * S;
    for (let x = 0; x < S; x++) {
      const xr = (x + 1) % S, xl = (x - 1 + S) % S;
      const dx = (H[yc + xr]! - H[yc + xl]!) * strength, dy = (H[yu + x]! - H[yd + x]!) * strength;
      const il = 1 / Math.sqrt(dx * dx + dy * dy + 1);
      const o = (yc + x) * 4;
      nd[o] = -dx * il * 0.5 + 0.5; nd[o + 1] = -dy * il * 0.5 + 0.5; nd[o + 2] = il * 0.5 + 0.5; nd[o + 3] = 1;
    }
  }
  return { alb, nrm };
}
const mul3 = (c: RGB, s: number): RGB => [c[0] * s, c[1] * s, c[2] * s];

function paintLawnMacro(seed: number, pal: LawnPalette): Pixels {
  const S = 512, px = new Pixels(S, S);
  const mid = mix(pal.blueGreen, pal.yellowGreen, 0.5);
  const T = fbmMap(S, 3, 3, 5, seed + 11), D = fbmMap(S, 4, 4, 5, seed + 12), SH = fbmMap(S, 16, 16, 3, seed + 13);
  for (let y = 0; y < S; y++)
    for (let x = 0; x < S; x++) {
      const i = y * S + x;
      const tone = smoothstep(0.3, 0.7, T[i]!);
      const dry = smoothstep(0.58, 0.72, D[i]!);
      let c = mix(pal.blueGreen, pal.yellowGreen, tone);
      c = mix(c, pal.drought, dry * 0.7);
      const shade = 0.92 + 0.16 * SH[i]!;
      px.over(x, y, [clamp01((c[0] / mid[0]) * shade * 0.5), clamp01((c[1] / mid[1]) * shade * 0.5), clamp01((c[2] / mid[2]) * shade * 0.5)], 1);
    }
  return px;
}

const lawnCache = new Map<string, LawnTextureSet>();
/** Tileable short-lawn ground-detail set (albedo sRGB, normal linear).
 *  Generation takes ~1-2 s at 1024 px; it is cached per (seed, size). */
export function lawnTextures(seed = 1, size = 1024, palette: LawnPalette = LAWN_PALETTE): LawnTextureSet {
  const key = seed + ':' + size + ':' + JSON.stringify(palette);
  const hit = lawnCache.get(key);
  if (hit) return hit;
  const a = paintLawn(seed, size, 0, palette);
  const w = paintLawn(seed, size, 1, palette);
  const set: LawnTextureSet = {
    macro: paintLawnMacro(seed, palette).toTexture({ srgb: false, repeat: true }),
    macroTileMeters: 64,
    albedo: a.alb.toTexture({ srgb: true, repeat: true }),
    normal: a.nrm.toTexture({ srgb: false, repeat: true }),
    wornAlbedo: w.alb.toTexture({ srgb: true, repeat: true }),
    wornNormal: w.nrm.toTexture({ srgb: false, repeat: true }),
    tileMeters: 2,
  };
  lawnCache.set(key, set);
  return set;
}
