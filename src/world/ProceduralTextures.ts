import * as THREE from 'three';
import { mulberry32 } from '../util/noise';

/** Tileable value noise on an integer lattice (period p) */
export function lattice(seed: number, p: number) {
  const r = mulberry32(seed); const g = new Float32Array(p * p); for (let i = 0; i < g.length; i++) g[i] = r();
  return (x: number, y: number) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const m = (a: number) => ((a % p) + p) % p;
    const a = g[m(yi) * p + m(xi)], b = g[m(yi) * p + m(xi + 1)], c = g[m(yi + 1) * p + m(xi)], d = g[m(yi + 1) * p + m(xi + 1)];
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  };
}
function fbmT(n: (x: number, y: number) => number, x: number, y: number, oct: number, per: number) {
  let s = 0, a = 0.5, f = 1, t = 0; for (let i = 0; i < oct; i++) { s += a * n(x * f, y * f); t += a; a *= 0.5; f *= 2; } return s / t;
}
export function mkCanvas(w: number, h = w) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }

/** Height field -> tangent-space normal map (OpenGL convention, wraps). */
export function normalFromHeight(h: Float32Array, w: number, ht: number, strength: number): HTMLCanvasElement {
  const c = mkCanvas(w, ht), ctx = c.getContext('2d')!, img = ctx.createImageData(w, ht);
  for (let y = 0; y < ht; y++) for (let x = 0; x < w; x++) {
    const xl = (x + w - 1) % w, xr = (x + 1) % w, yu = (y + ht - 1) % ht, yd = (y + 1) % ht;
    const dx = (h[y * w + xr] - h[y * w + xl]) * strength, dy = (h[yd * w + x] - h[yu * w + x]) * strength;
    const inv = 1 / Math.hypot(dx, dy, 1); const i = (y * w + x) * 4;
    img.data[i] = (-dx * inv * 0.5 + 0.5) * 255; img.data[i + 2] = (inv * 0.5 + 0.5) * 255; img.data[i + 3] = 255;
    img.data[i + 1] = (dy * inv * 0.5 + 0.5) * 255;
  }
  ctx.putImageData(img, 0, 0); return c;
}
export function tex(c: HTMLCanvasElement, srgb: boolean, repeat = true): THREE.CanvasTexture {
  const t = new THREE.CanvasTexture(c);
  if (repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.colorSpace = srgb ? THREE.SRGBColorSpace : THREE.NoColorSpace;
  t.anisotropy = 16; t.generateMipmaps = true; t.minFilter = THREE.LinearMipmapLinearFilter; t.needsUpdate = true; return t;
}
export interface PBRSet { map: THREE.Texture; normalMap: THREE.Texture; }

/** Coarse-aggregate asphalt: 20k stones in dark bitumen binder, tire polish and hairline cracks. */
export function makeAsphalt(size = 1024): PBRSet {
  const rng = mulberry32(7), H = new Float32Array(size * size), A = new Float32Array(size * size * 3);
  const n = lattice(3, 64);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) { const i = y * size + x; H[i] = 0.18 * fbmT(n, x / 16, y / 16, 3, 64); const b = 0.05 + 0.02 * n(x / 7, y / 7); A[i * 3] = b; A[i * 3 + 1] = b; A[i * 3 + 2] = b * 1.04; }
  const stones = Math.floor(size * size / 38);
  for (let s = 0; s < stones; s++) {
    const cx = rng() * size, cy = rng() * size, r = 1.2 + Math.pow(rng(), 2.2) * 5.2;
    const tone = 0.12 + rng() * 0.30, tint = rng();
    const cr = tone * (1 + 0.12 * (tint - 0.5)), cb = tone * (1 - 0.1 * (tint - 0.5)); const hh = 0.55 + rng() * 0.45;
    const x0 = Math.floor(cx - r - 1), x1 = Math.ceil(cx + r + 1), y0 = Math.floor(cy - r - 1), y1 = Math.ceil(cy + r + 1);
    const sx = 0.8 + rng() * 0.5, sy = 0.8 + rng() * 0.5, ang = rng() * 3.14, ca = Math.cos(ang), sa = Math.sin(ang);
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const dx = x - cx, dy = y - cy; const ux = (dx * ca + dy * sa) / (r * sx), uy = (-dx * sa + dy * ca) / (r * sy);
      const d2 = ux * ux + uy * uy; if (d2 >= 1) continue;
      const k = Math.sqrt(1 - d2), px = ((x % size) + size) % size, py = ((y % size) + size) % size, i = py * size + px;
      if (k * hh > H[i]) { H[i] = k * hh; const sh = 0.75 + 0.25 * k; A[i * 3] = cr * sh; A[i * 3 + 1] = tone * sh; A[i * 3 + 2] = cb * sh; }
    }
  }
  // hairline cracks
  for (let c = 0; c < 6; c++) { let x = rng() * size, y = rng() * size, a = rng() * 6.28; for (let k = 0; k < 260; k++) { a += (rng() - 0.5) * 0.5; x += Math.cos(a) * 1.5; y += Math.sin(a) * 1.5; const px = ((Math.floor(x) % size) + size) % size, py = ((Math.floor(y) % size) + size) % size, i = py * size + px; H[i] -= 0.6; A[i * 3] *= 0.4; A[i * 3 + 1] *= 0.4; A[i * 3 + 2] *= 0.4; } }
  const cc = mkCanvas(size), ctx = cc.getContext('2d')!, img = ctx.createImageData(size, size);
  for (let i = 0; i < size * size; i++) { img.data[i * 4] = Math.pow(A[i * 3], 1 / 2.2) * 255; img.data[i * 4 + 1] = Math.pow(A[i * 3 + 1], 1 / 2.2) * 255; img.data[i * 4 + 2] = Math.pow(A[i * 3 + 2], 1 / 2.2) * 255; img.data[i * 4 + 3] = 255; }
  ctx.putImageData(img, 0, 0);
  return { map: tex(cc, true), normalMap: tex(normalFromHeight(H, size, size, 5.5), false) };
}

/** Granite with feldspar / quartz / biotite grains. polished -> finer, lower contrast bump. */
export function makeGranite(size = 512, hue: 'grey' | 'pink' | 'black' = 'grey', seed = 11): PBRSet {
  const rng = mulberry32(seed), c = mkCanvas(size), ctx = c.getContext('2d')!;
  const pal = hue === 'pink' ? ['#b08d86', '#c9a79d', '#8e6f69', '#d8c6bd', '#2c2623', '#e9e1da'] : hue === 'black' ? ['#26282b', '#33363a', '#1b1c1e', '#4a4d52', '#111213', '#6b6e73'] : ['#8a8d90', '#a6a9ab', '#6e7173', '#c8cacb', '#2d2f31', '#e0e1e1'];
  ctx.fillStyle = pal[0]; ctx.fillRect(0, 0, size, size);
  const H = new Float32Array(size * size);
  const draw = (x: number, y: number, r: number, col: string) => { for (const ox of [-size, 0, size]) for (const oy of [-size, 0, size]) { if (x + ox < -r || x + ox > size + r || y + oy < -r || y + oy > size + r) continue; ctx.fillStyle = col; ctx.beginPath(); ctx.ellipse(x + ox, y + oy, r, r * (0.6 + rng() * 0.5), rng() * 3, 0, 6.3); ctx.fill(); } };
  for (let i = 0; i < 9000; i++) { const w = rng(); const col = pal[w < 0.35 ? 1 : w < 0.6 ? 2 : w < 0.82 ? 3 : w < 0.93 ? 4 : 5]; draw(rng() * size, rng() * size, 1 + rng() * 3.4, col); }
  const img = ctx.getImageData(0, 0, size, size); const n = lattice(5, 128);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) { const i = y * size + x; const v = (img.data[i * 4] + img.data[i * 4 + 1]) / 510; const m = 0.9 + 0.2 * fbmT(n, x / 12, y / 12, 3, 128); img.data[i * 4] *= m; img.data[i * 4 + 1] *= m; img.data[i * 4 + 2] *= m; H[i] = v * 0.5 + (n(x / 2, y / 2) - 0.5) * 0.3; }
  ctx.putImageData(img, 0, 0);
  return { map: tex(c, true), normalMap: tex(normalFromHeight(H, size, size, 1.6), false) };
}

/** Bark with deep vertical fissures. */
export function makeBark(size = 512, tone: 'grey' | 'brown' = 'brown'): PBRSet {
  const n = lattice(21, 64), n2 = lattice(22, 128), H = new Float32Array(size * size);
  const c = mkCanvas(size), ctx = c.getContext('2d')!, img = ctx.createImageData(size, size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const warp = (n2(x / 40, y / 90) - 0.5) * 18;
    const r = 1 - Math.abs(fbmT(n, (x + warp) / 11, y / 70, 4, 64) * 2 - 1);
    const h = Math.pow(r, 1.6); const i = y * size + x; H[i] = h;
    const base = tone === 'brown' ? [0.22, 0.16, 0.115] : [0.30, 0.285, 0.265]; const k = 0.35 + 0.9 * h;
    img.data[i * 4] = Math.pow(base[0] * k, 1 / 2.2) * 255; img.data[i * 4 + 1] = Math.pow(base[1] * k, 1 / 2.2) * 255; img.data[i * 4 + 2] = Math.pow(base[2] * k, 1 / 2.2) * 255; img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  return { map: tex(c, true), normalMap: tex(normalFromHeight(H, size, size, 7), false) };
}

/** Spruce sprig: curved twig with dense needles; alpha cut-out. Layout: twig runs left->right along the centre line. */
export function makeSpruceSprig(size = 512): { map: THREE.Texture } {
  const c = mkCanvas(size, size / 2), ctx = c.getContext('2d')!, rng = mulberry32(31);
  ctx.clearRect(0, 0, c.width, c.height);
  const W = c.width, Hh = c.height;
  const twig = (x0: number, y0: number, a: number, len: number, depth: number) => {
    let x = x0, y = y0, ang = a;
    const steps = Math.floor(len / 3);
    for (let s = 0; s < steps; s++) {
      ang += (rng() - 0.5) * 0.05 + 0.002; x += Math.cos(ang) * 3; y += Math.sin(ang) * 3;
      ctx.strokeStyle = '#2b1f16'; ctx.lineWidth = Math.max(0.8, 2.2 - s * 0.012 - depth * 0.5); ctx.beginPath(); ctx.moveTo(x - Math.cos(ang) * 3, y - Math.sin(ang) * 3); ctx.lineTo(x, y); ctx.stroke();
      const nl = 5 + Math.floor(rng() * 3);
      for (let k = 0; k < nl; k++) {
        const side = rng() < 0.5 ? -1 : 1, na = ang + side * (0.9 + rng() * 0.9), L = (13 - depth * 3) * (0.6 + 0.6 * rng()) * (1 - s / (steps * 1.8));
        const g = 55 + rng() * 55; ctx.strokeStyle = `rgb(${18 + rng() * 14},${g},${22 + rng() * 14})`; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(na) * L, y + Math.sin(na) * L); ctx.stroke();
      }
      if (depth < 1 && s > 6 && s % 7 === 0 && rng() < 0.9) twig(x, y, ang + (rng() < 0.5 ? -1 : 1) * (0.7 + rng() * 0.3), len * 0.38, depth + 1);
    }
  };
  twig(4, Hh / 2, 0, W - 20, 0);
  return { map: tex(c, true, false) };
}

/** Autumn leaf cluster (maple / oak): ~90 leaves in reds, oranges, golds. */
export function makeLeafCluster(size = 512, palette: 'maple' | 'oak' | 'gold' | 'green' = 'maple', seed = 41): { map: THREE.Texture } {
  const c = mkCanvas(size), ctx = c.getContext('2d')!, rng = mulberry32(seed);
  const cols = palette === 'gold' ? ['#d9a21c', '#e8b923', '#c78a14', '#f0cc4a', '#b5701a', '#9a5a14', '#d8801c'] : palette === 'maple' ? ['#a3231a', '#c8431b', '#df6b1e', '#e8a321', '#f0c53a', '#8c2a14', '#b9381a'] : palette === 'oak' ? ['#8a5a1f', '#a9741f', '#c28a2a', '#6f4a1c', '#b5651d', '#7d5a25'] : ['#3d6b24', '#4f7f2c', '#6a9a34', '#2f5a1f', '#86a83a'];
  const leaf = (x: number, y: number, r: number, a: number, col: string) => {
    ctx.save(); ctx.translate(x, y); ctx.rotate(a); ctx.fillStyle = col; ctx.beginPath();
    if (palette === 'maple' || palette === 'gold') { for (let i = 0; i < 5; i++) { const t = (i / 5) * Math.PI * 2 - Math.PI / 2; ctx.lineTo(Math.cos(t) * r, Math.sin(t) * r); const t2 = t + Math.PI / 5; ctx.lineTo(Math.cos(t2) * r * 0.45, Math.sin(t2) * r * 0.45); } }
    else { ctx.ellipse(0, 0, r * 0.55, r, 0, 0, 6.3); }
    ctx.closePath(); ctx.fill(); ctx.strokeStyle = 'rgba(40,20,5,0.55)'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(0, -r * 0.8); ctx.lineTo(0, r * 0.9); ctx.stroke(); ctx.restore();
  };
  const R = size / 2;
  for (let i = 0; i < 260; i++) { const a = rng() * 6.28, d = Math.sqrt(rng()) * R * 0.86; const x = R + Math.cos(a) * d, y = R + Math.sin(a) * d; const dark = 0.55 + 0.45 * (1 - d / R); ctx.globalAlpha = 1; leaf(x, y, 22 + rng() * 22, rng() * 6.28, cols[Math.floor(rng() * cols.length)]); ctx.fillStyle = `rgba(0,0,0,${0.45 * (1 - dark)})`; }
  return { map: tex(c, true, false) };
}

/** Painted horizontal clapboard (weathered white), with normal. */
export function makeClapboard(size = 512): PBRSet {
  const c = mkCanvas(size), ctx = c.getContext('2d')!, H = new Float32Array(size * size), n = lattice(51, 64), rng = mulberry32(5);
  const img = ctx.createImageData(size, size); const bw = size / 8;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const t = (y % bw) / bw; const lip = Math.pow(t, 0.7); const g = 0.5 + 0.5 * fbmT(n, x / 3, y / 40, 3, 64);
    const h = lip * 0.9 - (t > 0.94 ? 1 : 0); H[y * size + x] = h + 0.1 * g;
    const sh = 0.55 + 0.45 * (1 - Math.pow(t, 8)) ; const w = 0.62 * sh * (0.88 + 0.12 * g);
    const i = (y * size + x) * 4; img.data[i] = Math.pow(w * 0.96, 1 / 2.2) * 255; img.data[i + 1] = Math.pow(w * 0.93, 1 / 2.2) * 255; img.data[i + 2] = Math.pow(w * 0.86, 1 / 2.2) * 255; img.data[i + 3] = 255;
  }
  void rng; ctx.putImageData(img, 0, 0);
  return { map: tex(c, true), normalMap: tex(normalFromHeight(H, size, size, 4), false) };
}
/** Dark slate shingles */
export function makeShingles(size = 512): PBRSet {
  const c = mkCanvas(size), ctx = c.getContext('2d')!, rng = mulberry32(9), H = new Float32Array(size * size);
  const img = ctx.createImageData(size, size); const rows = 12, rh = size / rows, n = lattice(61, 64);
  const offs: number[] = []; for (let r = 0; r <= rows; r++) offs.push(rng() * 40);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const r = Math.floor(y / rh), t = (y % rh) / rh; const sw = 42; const xx = (x + offs[r] + (r % 2) * 21) % sw; const edge = xx < 1.5 ? 0 : 1;
    const tone = 0.07 + 0.05 * hashv(r, Math.floor((x + offs[r] + (r % 2) * 21) / sw)); const g = 0.85 + 0.3 * fbmT(n, x / 5, y / 5, 2, 64);
    const h = Math.pow(t, 1.3) * edge; H[y * size + x] = h; const v = tone * g * (0.55 + 0.45 * Math.pow(1 - t, 0.4)) * (edge ? 1 : 0.4);
    const i = (y * size + x) * 4; img.data[i] = Math.pow(v, 1 / 2.2) * 255; img.data[i + 1] = Math.pow(v * 1.02, 1 / 2.2) * 255; img.data[i + 2] = Math.pow(v * 1.08, 1 / 2.2) * 255; img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  return { map: tex(c, true), normalMap: tex(normalFromHeight(H, size, size, 3), false) };
}
function hashv(a: number, b: number) { const s = Math.sin(a * 127.1 + b * 311.7) * 43758.5453; return s - Math.floor(s); }

/** Fine-scale turf / soil micro normal used by the ground shader. */
export function makeGroundDetail(size = 512): PBRSet {
  const n = lattice(71, 128), H = new Float32Array(size * size);
  const c = mkCanvas(size), ctx = c.getContext('2d')!, img = ctx.createImageData(size, size), rng = mulberry32(72);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) { const i = y * size + x; H[i] = 0.5 * fbmT(n, x / 5, y / 5, 4, 128) + 0.5 * n(x / 1.6, y / 1.6); }
  // blade strokes
  const strokes = new Float32Array(size * size);
  for (let s = 0; s < 14000; s++) { let x = rng() * size, y = rng() * size; const a = rng() * 6.28, L = 3 + rng() * 7; for (let k = 0; k < L; k++) { const px = ((Math.floor(x + Math.cos(a) * k) % size) + size) % size, py = ((Math.floor(y + Math.sin(a) * k) % size) + size) % size; strokes[py * size + px] += 0.35; } }
  for (let i = 0; i < size * size; i++) { H[i] += strokes[i]; const v = clampv(0.55 + 0.5 * (H[i] - 0.7)); img.data[i * 4] = img.data[i * 4 + 1] = img.data[i * 4 + 2] = v * 255; img.data[i * 4 + 3] = 255; }
  ctx.putImageData(img, 0, 0);
  return { map: tex(c, false), normalMap: tex(normalFromHeight(H, size, size, 2.2), false) };
}
const clampv = (v: number) => Math.max(0, Math.min(1, v));

/** Engraved headstone lettering as a normal map (+ albedo tint), tileable false. */
export function makeInscription(lines: string[], w = 256, h = 512, hue: 'grey' | 'pink' | 'black' = 'grey', seed = 3): PBRSet {
  const base = makeGranite(512, hue, seed);
  const c = mkCanvas(w, h), ctx = c.getContext('2d')!;
  ctx.fillStyle = '#808080'; ctx.fillRect(0, 0, w, h);
  ctx.fillStyle = '#000'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  let y = h * 0.28; const sizes = [34, 24, 20, 18, 16, 16];
  lines.forEach((ln, i) => { ctx.font = `${i === 0 ? 'bold ' : ''}${sizes[Math.min(i, 5)]}px Georgia, "Times New Roman", serif`; ctx.fillText(ln, w / 2, y); y += sizes[Math.min(i, 5)] + 14; });
  const id = ctx.getImageData(0, 0, w, h); const H = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) H[i] = id.data[i * 4] / 255;
  // blur for bevel
  const B = new Float32Array(w * h); for (let y2 = 1; y2 < h - 1; y2++) for (let x = 1; x < w - 1; x++) B[y2 * w + x] = (H[y2 * w + x] * 4 + H[y2 * w + x - 1] + H[y2 * w + x + 1] + H[(y2 - 1) * w + x] + H[(y2 + 1) * w + x]) / 8;
  const nm = normalFromHeight(B, w, h, 9); const nt = tex(nm, false, false);
  return { map: base.map, normalMap: nt };
}
