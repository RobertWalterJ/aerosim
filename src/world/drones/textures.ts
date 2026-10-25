// Canvas-generated textures for the drones: carbon twill (albedo, normal,
// roughness, anisotropy direction), brushed metal, knurling, PCB silk screen,
// decals and labels, shell panel detail, prop blur gradients and a small
// studio cube map for fake lens and glass reflections.
import * as THREE from 'three';
import { makeCanvas, toTexture, rng, makeValueNoise, normalCanvas, putPixels, readHeight, css, type Ctx2D } from './canvas';

const cache = new Map<string, unknown>();
function cached<T>(key: string, make: () => T): T {
  if (!cache.has(key)) cache.set(key, make());
  return cache.get(key) as T;
}

export interface UVRect { u0: number; v0: number; u1: number; v1: number; }

// ---------------------------------------------------------------- carbon

export interface CarbonSet {
  map: THREE.Texture; normalMap: THREE.Texture; roughnessMap: THREE.Texture; anisotropyMap: THREE.Texture;
}

export interface CarbonOptions {
  seed: number;
  wear: number;
  accent: THREE.Color;
  /** world size covered by each half of the texture (meters) */
  meters: number;
  /** tow width in meters (3k twill ~ 3 mm) */
  tow?: number;
  /** scuff centers in meters (x, z), drawn in the right half */
  scuffs?: [number, number][];
  /** decal text printed in the left half (top plate) */
  sticker?: string;
  stickerAt?: [number, number];
}

/**
 * Frame carbon: a 2:1 canvas whose left half maps the top plate's top-down
 * footprint (with decal) and whose right half maps everything else (arms,
 * bottom and middle plates, with crash scuffs). Map with planarUV().
 */
export function carbonFrame(o: CarbonOptions): CarbonSet {
  const key = `carbon:${o.seed}:${o.wear.toFixed(2)}:${o.accent.getHexString()}:${o.meters}:${o.sticker ?? ''}`;
  return cached(key, () => {
    const H = 1024, W = 2048;
    const towPx = (H / o.meters) * (o.tow ?? 0.003);
    const noise = makeValueNoise(o.seed + 11, 256);
    const alb = new Uint8ClampedArray(W * H * 4), rough = new Uint8ClampedArray(W * H * 4), aniso = new Uint8ClampedArray(W * H * 4);
    const height = new Float32Array(W * H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++) {
        const tx = x / towPx, ty = y / towPx;
        const i = Math.floor(tx), j = Math.floor(ty);
        const fx = tx - i, fy = ty - j;
        const warp = (((i + j) % 4) + 4) % 4 < 2; // 2x2 twill
        const across = warp ? fx : fy, along = warp ? fy : fx;
        const lens = Math.pow(Math.sin(Math.PI * across), 0.45);
        const step = (((warp ? j : i) + (warp ? i : j)) % 2) * 0.08;
        const fib = noise(warp ? x * 0.9 : x * 0.04, warp ? y * 0.04 : y * 0.9);
        const h = lens * (0.82 + step + 0.12 * Math.sin(Math.PI * along)) + (fib - 0.5) * 0.12;
        const o4 = (y * W + x) * 4;
        height[y * W + x] = Math.max(0, h);
        // albedo: dark resin gaps, tows with slight per-bundle variation
        const towVar = 0.9 + 0.2 * noise(i * 7.3 + 0.5, j * 5.1 + 0.5);
        const v = (0.12 + 0.07 * lens * towVar + 0.03 * (fib - 0.5)) * 255;
        alb[o4] = v; alb[o4 + 1] = v; alb[o4 + 2] = v * 1.04; alb[o4 + 3] = 255;
        const r = (0.3 + 0.28 * (1 - lens)) * 255;
        rough[o4] = r; rough[o4 + 1] = r; rough[o4 + 2] = r; rough[o4 + 3] = 255;
        // anisotropy direction along the fibres (tangent space rg), strength in b
        aniso[o4] = warp ? 128 : 255; aniso[o4 + 1] = warp ? 255 : 128; aniso[o4 + 2] = 255 * (0.4 + 0.6 * lens); aniso[o4 + 3] = 255;
      }
    const A = makeCanvas(W, H), R = makeCanvas(W, H), S = makeCanvas(W, H), HC = makeCanvas(W, H);
    putPixels(A.ctx, alb, W, H);
    putPixels(R.ctx, rough, W, H);
    putPixels(S.ctx, aniso, W, H);
    const hb = new Uint8ClampedArray(W * H * 4);
    for (let k = 0; k < W * H; k++) { const v = height[k]! * 255; hb[k * 4] = v; hb[k * 4 + 1] = v; hb[k * 4 + 2] = v; hb[k * 4 + 3] = 255; }
    putPixels(HC.ctx, hb, W, H);

    const toPx = (mx: number, mz: number, half: 0 | 1): [number, number] => [half * H + (mx / o.meters + 0.5) * H, (mz / o.meters + 0.5) * H];
    // decal on the top plate (left half): printed, slightly raised, glossy
    if (o.sticker) {
      const [sx, sy] = toPx(o.stickerAt?.[0] ?? 0, o.stickerAt?.[1] ?? 0, 0);
      for (const c of [A.ctx, R.ctx, HC.ctx]) {
        c.save();
        c.translate(sx, sy);
        c.rotate(-Math.PI / 2);
        c.font = `bold ${Math.round(H * 0.034)}px sans-serif`;
        c.textAlign = 'center';
        c.textBaseline = 'middle';
        c.fillStyle = c === A.ctx ? css(o.accent) : c === R.ctx ? '#4a4a4a' : '#ffffff';
        c.fillText(o.sticker, 0, 0);
        c.fillRect(-H * 0.09, H * 0.024, H * 0.18, H * 0.004);
        c.restore();
      }
    }
    // crash scuffs: abraded resin exposes pale fibre, raises roughness, grooves the surface
    const r = rng(o.seed + 99);
    const nScuff = Math.round(o.wear * 60);
    for (const [mx, mz] of o.scuffs ?? []) {
      for (let k = 0; k < nScuff; k++) {
        const [cx, cy] = toPx(mx + (r() - 0.5) * 0.02, mz + (r() - 0.5) * 0.02, 1);
        const len = (4 + r() * 22) * (H / 1024), ang = r() * Math.PI;
        const x1 = cx + Math.cos(ang) * len, y1 = cy + Math.sin(ang) * len;
        const lw = 0.6 + r() * 2.2;
        A.ctx.strokeStyle = `rgba(150,150,150,${0.25 + r() * 0.5})`;
        R.ctx.strokeStyle = `rgba(200,200,200,${0.6 + r() * 0.4})`;
        HC.ctx.strokeStyle = 'rgba(40,40,40,0.8)';
        for (const c of [A.ctx, R.ctx, HC.ctx]) { c.lineWidth = lw; c.beginPath(); c.moveTo(cx, cy); c.lineTo(x1, y1); c.stroke(); }
      }
    }
    // light general wear: faint swirl marks across both halves
    for (let k = 0; k < Math.round(o.wear * 200); k++) {
      const cx = r() * W, cy = r() * H, rad = 10 + r() * 40;
      A.ctx.strokeStyle = 'rgba(120,120,120,0.08)';
      A.ctx.lineWidth = 0.7;
      A.ctx.beginPath(); A.ctx.arc(cx, cy, rad, r() * 6, r() * 6 + 0.8); A.ctx.stroke();
    }
    const Nc = normalCanvas(readHeight(HC.ctx, W, H), W, H, 3.5);
    return {
      map: toTexture(A.canvas, { srgb: true, name: 'carbon-albedo' }),
      roughnessMap: toTexture(R.canvas, { srgb: false, name: 'carbon-roughness' }),
      normalMap: toTexture(Nc, { srgb: false, name: 'carbon-normal' }),
      anisotropyMap: toTexture(S.canvas, { srgb: false, name: 'carbon-anisotropy' }),
    };
  });
}

// ---------------------------------------------------------------- metal

/** Brushed-metal normal map: fine streaks along u (repeat). */
export function brushedNormal(): THREE.Texture {
  return cached('brushed', () => {
    const S = 512;
    const n1 = makeValueNoise(7, 512), n2 = makeValueNoise(8, 64);
    const h = new Float32Array(S * S);
    for (let y = 0; y < S; y++)
      for (let x = 0; x < S; x++) h[y * S + x] = n1(x * 0.02, y * 1.0) * 0.7 + n2(x * 0.01, y * 0.25) * 0.3;
    return toTexture(normalCanvas(h, S, S, 1.2), { srgb: false, repeat: true, name: 'brushed-normal' });
  });
}

/** Knurled band normal map. v in [0.5, 1] is knurled (diamond), below is flat
 *  (so a lathe can place the grip band by choosing v per profile point). */
export function knurlNormal(): THREE.Texture {
  return cached('knurl', () => {
    const W = 512, H = 512, N = 56, rows = 10;
    const h = new Float32Array(W * H);
    for (let y = 0; y < H / 2; y++)
      for (let x = 0; x < W; x++) {
        const u = x / W, v = y / (H / 2);
        const a = (u * N + v * rows) % 1, b = (((u * N - v * rows) % 1) + 1) % 1;
        h[y * W + x] = 1 - Math.max(Math.abs(a - 0.5), Math.abs(b - 0.5)) * 2;
      }
    for (let y = H / 2; y < H; y++) for (let x = 0; x < W; x++) h[y * W + x] = 0.5;
    return toTexture(normalCanvas(h, W, H, 2.0), { srgb: false, repeat: true, name: 'knurl-normal' });
  });
}

// ---------------------------------------------------------------- PCB

export const PCB_UV = {
  fc: { u0: 0, v0: 0.5, u1: 0.5, v1: 1 } as UVRect,
  esc: { u0: 0.5, v0: 0.5, u1: 1, v1: 1 } as UVRect,
  vtx: { u0: 0, v0: 0, u1: 0.5, v1: 0.5 } as UVRect,
  bottom: { u0: 0.5, v0: 0, u1: 1, v1: 0.5 } as UVRect,
};

function drawBoard(c: Ctx2D, x0: number, y0: number, s: number, kind: 'fc' | 'esc' | 'vtx' | 'bottom', accent: string, r: () => number): void {
  const mask = kind === 'vtx' ? '#0f2a1c' : kind === 'fc' ? '#101318' : '#121212';
  c.fillStyle = mask;
  c.fillRect(x0, y0, s, s);
  // copper traces under mask
  c.strokeStyle = kind === 'vtx' ? '#1a3d2a' : '#20242a';
  c.lineWidth = s * 0.004;
  for (let k = 0; k < 140; k++) {
    let x = x0 + r() * s, y = y0 + r() * s;
    c.beginPath(); c.moveTo(x, y);
    for (let seg = 0; seg < 3; seg++) {
      if (r() < 0.5) x += (r() - 0.5) * s * 0.3; else y += (r() - 0.5) * s * 0.3;
      c.lineTo(Math.max(x0, Math.min(x0 + s, x)), Math.max(y0, Math.min(y0 + s, y)));
    }
    c.stroke();
  }
  const gold = '#c8a046';
  const pad = (x: number, y: number, w: number, h: number): void => { c.fillStyle = gold; c.fillRect(x0 + x * s, y0 + y * s, w * s, h * s); };
  const ring = (x: number, y: number, rr: number): void => {
    c.fillStyle = gold; c.beginPath(); c.arc(x0 + x * s, y0 + y * s, rr * s, 0, Math.PI * 2); c.fill();
    c.fillStyle = '#050505'; c.beginPath(); c.arc(x0 + x * s, y0 + y * s, rr * s * 0.55, 0, Math.PI * 2); c.fill();
  };
  const text = (t: string, x: number, y: number, size: number, rot = 0): void => {
    c.save(); c.translate(x0 + x * s, y0 + y * s); c.rotate(rot);
    c.fillStyle = '#e6e6e2'; c.font = `bold ${Math.round(size * s)}px sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText(t, 0, 0); c.restore();
  };
  const box = (x: number, y: number, w: number, h: number): void => { c.strokeStyle = '#e6e6e2'; c.lineWidth = s * 0.004; c.strokeRect(x0 + x * s, y0 + y * s, w * s, h * s); };
  if (kind === 'fc' || kind === 'esc') {
    // 30.5 mm mounting pattern on a 36 mm board
    const m = (36 - 30.5) / 2 / 36;
    for (const [x, y] of [[m, m], [1 - m, m], [m, 1 - m], [1 - m, 1 - m]] as const) ring(x, y, 0.06);
  }
  if (kind === 'fc') {
    box(0.36, 0.36, 0.28, 0.28);
    text('STRIX F7', 0.5, 0.18, 0.07);
    text('V2.1', 0.5, 0.26, 0.045);
    const labels = ['5V', 'G', 'TX1', 'RX1', 'TX2', 'RX2', 'LED', 'BZ-', 'BZ+', 'CAM', 'VTX', 'SBUS'];
    labels.forEach((l, k) => {
      const x = 0.16 + (k % 6) * 0.135, y = k < 6 ? 0.8 : 0.9;
      pad(x - 0.025, y - 0.02, 0.05, 0.035);
      text(l, x, y - 0.05, 0.03);
    });
    text('ARROW', 0.85, 0.45, 0.025);
    c.fillStyle = '#e6e6e2';
    c.beginPath(); c.moveTo(x0 + 0.85 * s, y0 + 0.36 * s); c.lineTo(x0 + 0.82 * s, y0 + 0.41 * s); c.lineTo(x0 + 0.88 * s, y0 + 0.41 * s); c.fill();
    c.fillStyle = accent; c.fillRect(x0 + 0.08 * s, y0 + 0.08 * s, s * 0.06, s * 0.02);
  } else if (kind === 'esc') {
    text('4IN1 45A  3-6S', 0.5, 0.5, 0.06);
    text('ESC', 0.5, 0.58, 0.05);
    const corners: [number, number, string][] = [[0.12, 0.3, 'M1'], [0.88, 0.3, 'M2'], [0.12, 0.7, 'M4'], [0.88, 0.7, 'M3']];
    for (const [x, y, l] of corners) {
      for (let k = 0; k < 3; k++) pad(x - 0.04, y - 0.12 + k * 0.08, 0.08, 0.06);
      text(l, x, y + 0.16, 0.035);
    }
    pad(0.4, 0.86, 0.08, 0.1); pad(0.52, 0.86, 0.08, 0.1);
    text('+', 0.44, 0.82, 0.05); text('-', 0.56, 0.82, 0.05);
    for (let k = 0; k < 12; k++) box(0.24 + (k % 6) * 0.09, 0.2 + Math.floor(k / 6) * 0.48, 0.06, 0.08);
  } else if (kind === 'vtx') {
    text('VTX 5.8G', 0.5, 0.2, 0.08);
    text('25-800mW', 0.5, 0.3, 0.05);
    text('CH  BAND', 0.5, 0.82, 0.045);
    box(0.3, 0.4, 0.4, 0.3);
    ring(0.1, 0.1, 0.05); ring(0.9, 0.1, 0.05); ring(0.1, 0.9, 0.05); ring(0.9, 0.9, 0.05);
    pad(0.82, 0.45, 0.12, 0.12);
  } else {
    for (let k = 0; k < 30; k++) pad(r(), r(), 0.02 + r() * 0.03, 0.02 + r() * 0.03);
    text('MADE FOR AEROSIM', 0.5, 0.5, 0.05);
  }
}

export function pcbTexture(accent: THREE.Color, seed: number): THREE.Texture {
  return cached(`pcb:${accent.getHexString()}:${seed}`, () => {
    const S = 1024, { canvas, ctx } = makeCanvas(S, S);
    const r = rng(seed + 5);
    // canvas y is flipped vs v: v in [0.5,1] is the top half of the canvas
    drawBoard(ctx, 0, 0, S / 2, 'fc', css(accent), r);
    drawBoard(ctx, S / 2, 0, S / 2, 'esc', css(accent), r);
    drawBoard(ctx, 0, S / 2, S / 2, 'vtx', css(accent), r);
    drawBoard(ctx, S / 2, S / 2, S / 2, 'bottom', css(accent), r);
    return toTexture(canvas, { srgb: true, name: 'pcb' });
  });
}

// ---------------------------------------------------------------- mini shell

export interface ShellLayout {
  /** v along the front shell: 0 nose, 1 battery joint */
  noseSeam: number;
}

/** Mini shell albedo + normal on loft UVs (u: 0 bottom, 0.25 right, 0.5 top, 0.75 left). */
export function miniShellTextures(base: THREE.Color, wear: number, seed: number): { map: THREE.Texture; normalMap: THREE.Texture } {
  return cached(`shell:${base.getHexString()}:${wear.toFixed(2)}:${seed}`, () => {
    const S = 1024;
    const A = makeCanvas(S, S), Hc = makeCanvas(S, S);
    const noise = makeValueNoise(seed + 3, 128);
    // base: matte plastic with faint mould texture
    const img = A.ctx.createImageData(S, S), hd = new Uint8ClampedArray(S * S * 4);
    const b = [base.r, base.g, base.b].map((c) => Math.pow(c, 1 / 2.2) * 255);
    for (let y = 0; y < S; y++)
      for (let x = 0; x < S; x++) {
        const n = noise(x * 0.35, y * 0.35) * 0.6 + noise(x * 0.05, y * 0.05) * 0.4;
        const k = 0.97 + 0.05 * n, o = (y * S + x) * 4;
        img.data[o] = b[0]! * k; img.data[o + 1] = b[1]! * k; img.data[o + 2] = b[2]! * k; img.data[o + 3] = 255;
        const hv = 128 + (n - 0.5) * 6;
        hd[o] = hv; hd[o + 1] = hv; hd[o + 2] = hv; hd[o + 3] = 255;
      }
    A.ctx.putImageData(img, 0, 0);
    putPixels(Hc.ctx, hd, S, S);
    const P = (u: number, v: number): [number, number] => [u * S, (1 - v) * S];
    const line = (u0: number, v0: number, u1: number, v1: number, w: number, dark: string): void => {
      for (const [c, col] of [[A.ctx, dark], [Hc.ctx, '#303030']] as const) {
        c.strokeStyle = col; c.lineWidth = w; c.beginPath(); c.moveTo(...P(u0, v0)); c.lineTo(...P(u1, v1)); c.stroke();
      }
    };
    const seam = 'rgba(40,42,45,0.75)';
    // top/bottom shell parting line along both sides
    line(0.25, 0, 0.25, 1, 2.2, seam); line(0.75, 0, 0.75, 1, 2.2, seam);
    // nose cap seam (around the gimbal bay) and a top service cover
    line(0, 0.13, 1, 0.13, 2, seam);
    const rr = (u0: number, v0: number, u1: number, v1: number, w: number, fill?: string): void => {
      const [x0, y0] = P(u0, v1), [x1, y1] = P(u1, v0);
      for (const [c, col, f] of [[A.ctx, seam, fill], [Hc.ctx, '#303030', fill ? '#202020' : undefined]] as const) {
        c.lineWidth = w; c.strokeStyle = col;
        c.beginPath();
        const r = Math.min(x1 - x0, y1 - y0) * 0.2;
        c.moveTo(x0 + r, y0); c.arcTo(x1, y0, x1, y1, r); c.arcTo(x1, y1, x0, y1, r); c.arcTo(x0, y1, x0, y0, r); c.arcTo(x0, y0, x1, y0, r);
        c.closePath();
        if (f) { c.fillStyle = f; c.fill(); }
        c.stroke();
      }
    };
    rr(0.41, 0.3, 0.59, 0.82, 2);
    // side vents (both sides), rear lower
    for (const uc of [0.19, 0.81])
      for (let k = 0; k < 7; k++) rr(uc - 0.035, 0.58 + k * 0.045, uc + 0.035, 0.6 + k * 0.045, 1, '#202124');
    // micro SD door, right side, with a pull notch
    rr(0.14, 0.82, 0.22, 0.95, 2);
    line(0.175, 0.95, 0.185, 0.95, 4, 'rgba(30,30,30,0.9)');
    // bottom intake grille under the body
    for (let k = 0; k < 9; k++) rr(0.96 - 0.01, 0.4 + k * 0.03, 1.0, 0.415 + k * 0.03, 1, '#1d1e20');
    for (let k = 0; k < 9; k++) rr(0.0, 0.4 + k * 0.03, 0.04, 0.415 + k * 0.03, 1, '#1d1e20');
    // wear: scuffs on nose and belly, fine scratches
    const r = rng(seed + 17);
    for (let k = 0; k < Math.round(wear * 160); k++) {
      const belly = r() < 0.6;
      const u = belly ? (r() < 0.5 ? r() * 0.12 : 0.88 + r() * 0.12) : r();
      const v = belly ? r() : r() * 0.2;
      const [x, y] = P(u, v), len = 3 + r() * 18, ang = r() * Math.PI;
      A.ctx.strokeStyle = r() < 0.5 ? `rgba(255,255,255,${0.15 + r() * 0.25})` : `rgba(60,60,60,${0.1 + r() * 0.2})`;
      A.ctx.lineWidth = 0.6 + r();
      A.ctx.beginPath(); A.ctx.moveTo(x, y); A.ctx.lineTo(x + Math.cos(ang) * len, y + Math.sin(ang) * len); A.ctx.stroke();
    }
    return { map: toTexture(A.canvas, { srgb: true, name: 'mini-shell' }), normalMap: toTexture(normalCanvas(readHeight(Hc.ctx, S, S), S, S, 2.5), { srgb: false, name: 'mini-shell-normal' }) };
  });
}

// ---------------------------------------------------------------- decals

export const MINI_DECALS = {
  label: { u0: 0, v0: 0.5, u1: 0.5, v1: 1 } as UVRect,
  battery: { u0: 0.5, v0: 0.5, u1: 1, v1: 1 } as UVRect,
  serial: { u0: 0, v0: 0.25, u1: 0.25, v1: 0.5 } as UVRect,
  propMark: { u0: 0.25, v0: 0.25, u1: 0.375, v1: 0.5 } as UVRect,
  levelLeds: { u0: 0.375, v0: 0.25, u1: 0.5, v1: 0.5 } as UVRect,
  wordmark: { u0: 0.5, v0: 0.25, u1: 1, v1: 0.5 } as UVRect,
  arrow: { u0: 0, v0: 0, u1: 0.125, v1: 0.25 } as UVRect,
};

/** Decal atlas for the mini (1024 x 1024). Transparent outside stickers. */
export function miniDecals(accent: THREE.Color, seed: number): THREE.Texture {
  return cached(`minidecal:${accent.getHexString()}:${seed}`, () => {
    const S = 1024, { canvas, ctx: c } = makeCanvas(S, S);
    const r = rng(seed + 23);
    const rect = (u: UVRect): [number, number, number, number] => [u.u0 * S, (1 - u.v1) * S, (u.u1 - u.u0) * S, (u.v1 - u.v0) * S];
    const txt = (t: string, x: number, y: number, size: number, col: string, weight = 'normal', align: CanvasTextAlign = 'left'): void => {
      c.fillStyle = col; c.font = `${weight} ${size}px sans-serif`; c.textAlign = align; c.textBaseline = 'middle'; c.fillText(t, x, y);
    };
    // manufacturing label: white sticker, black text, fictional brand
    {
      const [x, y, w, h] = rect(MINI_DECALS.label);
      c.fillStyle = '#ecebe6'; c.fillRect(x + 8, y + 8, w - 16, h - 16);
      txt('AeroLite', x + 30, y + 60, 54, '#151515', 'bold');
      txt('Model: AL-249 Mini', x + 30, y + 120, 26, '#202020');
      txt('Input: 7.7 V  2.4 A', x + 30, y + 156, 22, '#202020');
      txt('Takeoff weight < 250 g', x + 30, y + 188, 22, '#202020');
      txt('SN 3K7AL' + Math.floor(r() * 9e6 + 1e6), x + 30, y + 220, 22, '#202020');
      txt('Designed by AeroLite. Fictional product.', x + 30, y + 256, 18, '#404040');
      // matrix code made of random cells
      const cx = x + w - 200, cy = y + 120, cell = 9;
      c.fillStyle = '#111';
      for (let i = 0; i < 17; i++) for (let j = 0; j < 17; j++) if (r() < 0.5 || (i < 3 && j < 3) || (i > 13 && j < 3) || (i < 3 && j > 13)) c.fillRect(cx + i * cell, cy + j * cell, cell, cell);
      for (let k = 0; k < 40; k++) c.fillRect(x + 30 + k * 7, y + 300, r() < 0.5 ? 2 : 4, 60);
      txt('MADE BY AEROLITE INDUSTRIES', x + 30, y + 400, 20, '#303030');
    }
    // battery top print (on dark plastic): grey wordmark and specs
    {
      const [x, y, w, h] = rect(MINI_DECALS.battery);
      c.globalAlpha = 0.9;
      txt('AeroLite', x + w / 2, y + 90, 64, '#9c9fa3', 'bold', 'center');
      txt('Intelligent Flight Battery', x + w / 2, y + 160, 28, '#8a8d91', 'normal', 'center');
      txt('2250 mAh  7.38 V  16.6 Wh', x + w / 2, y + 205, 28, '#8a8d91', 'normal', 'center');
      txt('Li-ion  2S', x + w / 2, y + 245, 24, '#8a8d91', 'normal', 'center');
      c.globalAlpha = 1;
      void h;
    }
    {
      const [x, y, w, h] = rect(MINI_DECALS.serial);
      c.fillStyle = '#2a2b2d'; c.fillRect(x + 6, y + 6, w - 12, h - 12);
      txt('AL-249', x + w / 2, y + h / 2 - 20, 36, '#b0b3b6', 'bold', 'center');
      txt('ID ' + Math.floor(r() * 9e5 + 1e5), x + w / 2, y + h / 2 + 30, 24, '#a0a3a6', 'normal', 'center');
    }
    {
      // prop marking: a ring and a dot to tell CW/CCW props apart
      const [x, y, w, h] = rect(MINI_DECALS.propMark);
      c.strokeStyle = css(accent); c.lineWidth = 14; c.beginPath(); c.arc(x + w / 2, y + h / 2, w * 0.32, 0, Math.PI * 2); c.stroke();
    }
    {
      const [x, y, w, h] = rect(MINI_DECALS.levelLeds);
      c.fillStyle = '#18191b'; c.fillRect(x, y, w, h);
      for (let k = 0; k < 4; k++) { c.fillStyle = '#3a3d40'; c.fillRect(x + 12 + k * (w - 24) / 4, y + h / 2 - 6, (w - 24) / 4 - 10, 12); }
    }
    {
      const [x, y, w, h] = rect(MINI_DECALS.wordmark);
      txt('AeroLite', x + w / 2, y + h / 2, 110, '#d9dadb', 'bold', 'center');
    }
    {
      const [x, y, w, h] = rect(MINI_DECALS.arrow);
      c.fillStyle = '#e8e8e6';
      c.beginPath(); c.moveTo(x + w / 2, y + 10); c.lineTo(x + w - 14, y + h / 2); c.lineTo(x + w / 2 + 14, y + h / 2); c.lineTo(x + w / 2 + 14, y + h - 10);
      c.lineTo(x + w / 2 - 14, y + h - 10); c.lineTo(x + w / 2 - 14, y + h / 2); c.lineTo(x + 14, y + h / 2); c.closePath(); c.fill();
    }
    return toTexture(canvas, { srgb: true, name: 'mini-decals' });
  });
}

/** LiPo shrink-wrap print on loft UVs (u: 0 bottom, 0.5 top; v along length). */
export function lipoTexture(accent: THREE.Color, wear: number, seed: number): THREE.Texture {
  return cached(`lipo:${accent.getHexString()}:${wear.toFixed(2)}:${seed}`, () => {
    const W = 1024, H = 512, { canvas, ctx: c } = makeCanvas(W, H);
    const r = rng(seed + 31);
    c.fillStyle = '#121214'; c.fillRect(0, 0, W, H);
    // diagonal accent band wrapping the pack
    c.fillStyle = css(accent);
    const off = r() * 200;
    c.beginPath(); c.moveTo(off, 0); c.lineTo(off + 140, 0); c.lineTo(off + 360, H); c.lineTo(off + 220, H); c.closePath(); c.fill();
    c.fillStyle = '#e8e8e8';
    c.beginPath(); c.moveTo(off + 160, 0); c.lineTo(off + 180, 0); c.lineTo(off + 400, H); c.lineTo(off + 380, H); c.closePath(); c.fill();
    const txt = (t: string, x: number, y: number, size: number, col: string, weight = 'bold', rot = 0): void => {
      c.save(); c.translate(x, y); c.rotate(rot); c.fillStyle = col; c.font = `${weight} ${size}px sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(t, 0, 0); c.restore();
    };
    // side faces at u ~ 0.25 and 0.75 (x = W/4, 3W/4); v runs down the canvas
    txt('VOLTKIT', W * 0.25, H * 0.45, 64, '#f0f0f0', 'bold', Math.PI / 2);
    txt('VOLTKIT', W * 0.75, H * 0.45, 64, '#f0f0f0', 'bold', -Math.PI / 2);
    txt('1300mAh 4S1P 14.8V 120C', W * 0.5, H * 0.5, 30, '#f0f0f0', 'bold', Math.PI / 2);
    txt('HV LiPo  19.2Wh', W * 0.56, H * 0.5, 22, css(accent), 'bold', Math.PI / 2);
    txt('DO NOT OVERCHARGE  STORE AT 3.8V/CELL', W * 0.02 + 20, H * 0.5, 14, '#aaaaaa', 'normal', Math.PI / 2);
    // wear: whitened scrapes on edges, small dents
    for (let k = 0; k < Math.round(wear * 120); k++) {
      const x = [0.125, 0.375, 0.625, 0.875][Math.floor(r() * 4)]! * W + (r() - 0.5) * 50, y = r() * H;
      c.strokeStyle = `rgba(220,220,220,${0.2 + r() * 0.4})`; c.lineWidth = 0.8 + r() * 1.5;
      c.beginPath(); c.moveTo(x, y); c.lineTo(x + (r() - 0.5) * 30, y + (r() - 0.5) * 30); c.stroke();
    }
    return toTexture(canvas, { srgb: true, name: 'lipo' });
  });
}

// ---------------------------------------------------------------- prop blur

/** Radial alpha profile for the blur disc: u = normalized radius. */
export function blurAlpha(key: string, alpha: (r: number) => number): THREE.Texture {
  return cached('blur:' + key, () => {
    const W = 512, H = 4, { canvas, ctx } = makeCanvas(W, H);
    const img = ctx.createImageData(W, H);
    for (let x = 0; x < W; x++) {
      const a = Math.max(0, Math.min(1, alpha(x / (W - 1))));
      // faint banding where the blade's airfoil catches light at different radii
      const v = a * (0.92 + 0.08 * Math.sin(x * 0.35)) * 255;
      for (let y = 0; y < H; y++) { const o = (y * W + x) * 4; img.data[o] = v; img.data[o + 1] = v; img.data[o + 2] = v; img.data[o + 3] = 255; }
    }
    ctx.putImageData(img, 0, 0);
    return toTexture(canvas, { srgb: false, name: 'blur-' + key });
  });
}

// ---------------------------------------------------------------- env

/** Small studio cube map (sky gradient, soft boxes, dark ground) for lens and
 *  glass reflections. Used only on glass so it doesn't fight the scene env. */
export function studioEnv(): THREE.CubeTexture {
  return cached('env', () => {
    const S = 128;
    const faces = [0, 1, 2, 3, 4, 5].map((f) => {
      const { canvas, ctx: c } = makeCanvas(S, S);
      if (f === 2) { // +Y sky
        const g = c.createRadialGradient(S / 2, S / 2, 4, S / 2, S / 2, S * 0.75);
        g.addColorStop(0, '#ffffff'); g.addColorStop(0.4, '#cfe0f0'); g.addColorStop(1, '#8aa3bd');
        c.fillStyle = g; c.fillRect(0, 0, S, S);
      } else if (f === 3) { // -Y ground
        c.fillStyle = '#2a2722'; c.fillRect(0, 0, S, S);
      } else {
        const g = c.createLinearGradient(0, 0, 0, S);
        g.addColorStop(0, '#9fb6cf'); g.addColorStop(0.48, '#e8eef4'); g.addColorStop(0.52, '#4a463e'); g.addColorStop(1, '#2a2722');
        c.fillStyle = g; c.fillRect(0, 0, S, S);
        c.fillStyle = 'rgba(255,255,255,0.9)';
        c.fillRect(S * (0.15 + 0.1 * f), S * 0.18, S * 0.22, S * 0.16); // soft box
      }
      return canvas;
    });
    const t = new THREE.CubeTexture(faces);
    t.colorSpace = THREE.SRGBColorSpace;
    t.needsUpdate = true;
    t.name = 'drone-studio-env';
    return t;
  });
}
