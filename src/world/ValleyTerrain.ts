import * as THREE from 'three';
import { WORLD } from '../config';
import { fbm2, noise2 } from '../util/noise';
import { smoothstep, clamp } from '../util/math';
import { makeAsphalt, makeGroundDetail } from './ProceduralTextures';

export type P2 = [number, number];
const N = 2049;                       // heightmap vertices per side (2048 cells)
const SIZE = WORLD.size;
const DX = SIZE / (N - 1);
const PATH_SPAN = 512, PATH_RES = 1024;

/** Analytic base terrain: overlook park on a bench above a valley, river, distant wooded ridge. */
export function baseHeight(x: number, z: number): number {
  const r = Math.hypot(x, z);
  let h = 128;
  const t = clamp((-x - 140) / 560, 0, 1); h -= 82 * t * t * (3 - 2 * t);                 // western valley
  const riverX = -1180 + 140 * Math.sin(z / 420) + 60 * Math.sin(z / 150 + 1);
  h -= 9 * Math.exp(-Math.pow((x - riverX) / 55, 2));                                      // river channel
  h += 175 * Math.exp(-Math.pow((x + 1700 + 120 * Math.sin(z / 600)) / 400, 2)) * (0.65 + 0.35 * noise2(z / 500, 3.1)); // distant ridge
  h += 70 * smoothstep(400, 1800, x) + 25 * smoothstep(300, 1500, Math.abs(z));           // eastern uplands / side slopes
  const park = 1 - smoothstep(180, 380, r);
  const roll = (fbm2(x / 340, z / 340, 4) - 0.5) * 2, fine = (fbm2(x / 62 + 9, z / 62 - 4, 3) - 0.5) * 2, micro = (fbm2(x / 17, z / 17, 2) - 0.5) * 2;
  h += roll * (9 + 12 * (1 - park)) + fine * (1.6 + 1.0 * (1 - park)) + micro * 0.22;
  h += 7 * Math.exp(-Math.pow(r / 150, 2));                                                // park knoll
  return h;
}

function catmull(pts: P2[], closed: boolean, step = 1): P2[] {
  const out: P2[] = []; const n = pts.length; const segs = closed ? n : n - 1;
  const g = (i: number) => (closed ? pts[((i % n) + n) % n] : pts[clamp(i, 0, n - 1)]);
  for (let s = 0; s < segs; s++) {
    const p0 = g(s - 1), p1 = g(s), p2 = g(s + 1), p3 = g(s + 2);
    const L = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]); const m = Math.max(2, Math.ceil(L / step));
    for (let k = 0; k < m; k++) {
      const t = k / m, t2 = t * t, t3 = t2 * t;
      out.push([0, 1].map(c => 0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)) as P2);
    }
  }
  if (!closed) out.push(pts[n - 1]);
  return out;
}

function edt(grid: Float32Array, w: number, h: number): void {
  const INF = 1e12, n = Math.max(w, h); const v = new Int32Array(n), z = new Float32Array(n + 1), f = new Float32Array(n), d = new Float32Array(n);
  const pass = (len: number) => {
    let k = 0; v[0] = 0; z[0] = -INF; z[1] = INF;
    for (let q = 1; q < len; q++) {
      let s: number;
      while (true) { const p = v[k]; s = ((f[q] + q * q) - (f[p] + p * p)) / (2 * q - 2 * p); if (s <= z[k] && k > 0) k--; else break; }
      k++; v[k] = q; z[k] = s; z[k + 1] = INF;
    }
    k = 0; for (let q = 0; q < len; q++) { while (z[k + 1] < q) k++; const p = v[k]; d[q] = (q - p) * (q - p) + f[p]; }
  };
  for (let x = 0; x < w; x++) { for (let y = 0; y < h; y++) f[y] = grid[y * w + x]; pass(h); for (let y = 0; y < h; y++) grid[y * w + x] = d[y]; }
  for (let y = 0; y < h; y++) { for (let x = 0; x < w; x++) f[x] = grid[y * w + x]; pass(w); for (let x = 0; x < w; x++) grid[y * w + x] = d[x]; }
}

export const GROUND_GLSL = /* glsl */`
float gh(vec2 p){ p = fract(p*vec2(0.1031,0.1030)); p += dot(p, p.yx+33.33); return fract((p.x+p.y)*p.x); }
float gn(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f); return mix(mix(gh(i),gh(i+vec2(1,0)),f.x), mix(gh(i+vec2(0,1)),gh(i+vec2(1,1)),f.x), f.y); }
float gfbm(vec2 p){ float s=0., a=.5; for(int i=0;i<5;i++){ s+=a*gn(p); p=p*2.03+17.1; a*=.5;} return s; }
vec3 lin(vec3 c){ return pow(c, vec3(2.2)); }
vec3 groundPalette(vec3 cover, vec2 xz, float n1, float n2){
  vec3 lawn   = mix(lin(vec3(0.255,0.355,0.115)), lin(vec3(0.355,0.405,0.135)), n1);
  vec3 meadow = mix(lin(vec3(0.45,0.40,0.17)), lin(vec3(0.33,0.34,0.13)), n2);
  vec3 forest = mix(lin(vec3(0.17,0.14,0.085)), lin(vec3(0.30,0.19,0.075)), n2*n1*1.6);
  vec3 c = mix(meadow, lawn, cover.b);
  return mix(c, forest, cover.r);
}
`;

export class ValleyTerrain {
  readonly heights = new Float32Array(N * N);
  readonly cover = new Uint8Array(1024 * 1024 * 4);
  readonly pathDist = new Float32Array(PATH_RES * PATH_RES);
  readonly paths: { name: string; pts: P2[]; closed: boolean }[] = [];
  readonly polylines: P2[][] = [];
  heightTex!: THREE.DataTexture; coverTex!: THREE.DataTexture; pathTex!: THREE.DataTexture;
  mesh = new THREE.Group();
  material!: THREE.MeshStandardMaterial;
  ready = false;

  constructor() {
    this.defineLayout();
  }

  private defineLayout() {
    const P = (name: string, pts: P2[], closed = false) => this.paths.push({ name, pts, closed });
    P('loop', [[0, -112], [82, -92], [126, -22], [112, 62], [42, 112], [-48, 106], [-116, 46], [-122, -40], [-72, -96]], true);
    P('avenue-ew', [[290, 46], [200, 40], [128, 28], [60, 8], [0, 8], [-60, 12], [-130, 22], [-200, 10], [-280, -20]]);
    P('avenue-ns', [[12, -260], [10, -190], [4, -112], [2, -50], [3, 8], [10, 70], [18, 112], [24, 190], [10, 270]]);
    P('spur-a', [[82, -92], [60, -50], [34, -20], [2, 8]]);
    P('spur-b', [[-116, 46], [-80, 38], [-42, 22], [3, 8]]);
    P('spur-c', [[42, 112], [30, 80], [14, 44], [3, 8]]);
    P('plaza', [[11, 8], [8, 16], [0, 19], [-8, 16], [-11, 8], [-8, 0], [0, -3], [8, 0]], true);
    P('chapel-walk', [[126, -22], [150, -34], [172, -52], [186, -70]]);
    for (const p of this.paths) this.polylines.push(catmull(p.pts, p.closed, 0.8));
  }

  /** Heavy one-time bake: heightfield, land cover, path distance field, GPU textures. */
  bake(onProgress?: (f: number) => void): void {
    for (let j = 0; j < N; j++) {
      const z = -SIZE / 2 + j * DX;
      for (let i = 0; i < N; i++) this.heights[j * N + i] = baseHeight(-SIZE / 2 + i * DX, z);
      if (onProgress && (j & 127) === 0) onProgress(j / N * 0.6);
    }
    // Land cover
    const C = 1024;
    for (let j = 0; j < C; j++) for (let i = 0; i < C; i++) {
      const x = -SIZE / 2 + (i + 0.5) * SIZE / C, z = -SIZE / 2 + (j + 0.5) * SIZE / C, r = Math.hypot(x, z);
      const h = this.height(x, z), sl = 1 - this.normalY(x, z);
      const f = fbm2(x / 520 + 3, z / 520 - 8, 4);
      let forest = smoothstep(0.50, 0.60, f) * smoothstep(250, 420, r);
      forest = Math.max(forest, smoothstep(0.06, 0.16, sl) * smoothstep(200, 420, r) * 0.9);        // wooded valley banks
      forest = Math.max(forest, smoothstep(190, 230, h) * 0.95);                                      // ridge forest
      forest = Math.max(forest, smoothstep(160, 190, Math.hypot(x * 0.8, z)) * (1 - smoothstep(190, 240, r)) * smoothstep(0.55, 0.7, fbm2(x / 70, z / 70, 3)) * 0.8);
      const park = 1 - smoothstep(175, 235, r);
      const mown = park * (1 - smoothstep(0.62, 0.72, fbm2(x / 90 + 5, z / 90, 3)) * smoothstep(120, 170, r));
      const k = (j * C + i) * 4;
      this.cover[k] = Math.round(clamp(forest, 0, 1) * 255); this.cover[k + 1] = 0; this.cover[k + 2] = Math.round(clamp(mown, 0, 1) * 255); this.cover[k + 3] = 255;
    }
    onProgress?.(0.75);
    // Path distance field around the park (exact EDT)
    const g = this.pathDist; g.fill(1e12);
    const px = PATH_RES / PATH_SPAN;
    for (const pl of this.polylines) for (let s = 0; s < pl.length - 1; s++) {
      const a = pl[s], b = pl[s + 1], L = Math.hypot(b[0] - a[0], b[1] - a[1]), m = Math.max(1, Math.ceil(L * px * 2));
      for (let k = 0; k <= m; k++) {
        const t = k / m, x = a[0] + (b[0] - a[0]) * t, z = a[1] + (b[1] - a[1]) * t;
        const ix = Math.floor((x + PATH_SPAN / 2) * px), iz = Math.floor((z + PATH_SPAN / 2) * px);
        if (ix >= 0 && ix < PATH_RES && iz >= 0 && iz < PATH_RES) g[iz * PATH_RES + ix] = 0;
      }
    }
    // closing polylines
    edt(g, PATH_RES, PATH_RES);
    const pd8 = new Uint8Array(PATH_RES * PATH_RES);
    for (let i = 0; i < g.length; i++) { g[i] = Math.sqrt(g[i]) / px; pd8[i] = Math.round(clamp(g[i] / 8, 0, 1) * 255); }
    // GPU textures
    this.heightTex = new THREE.DataTexture(this.heights, N, N, THREE.RedFormat, THREE.FloatType);
    this.heightTex.minFilter = this.heightTex.magFilter = THREE.LinearFilter; this.heightTex.wrapS = this.heightTex.wrapT = THREE.ClampToEdgeWrapping; this.heightTex.needsUpdate = true;
    this.coverTex = new THREE.DataTexture(this.cover, C, C, THREE.RGBAFormat, THREE.UnsignedByteType);
    this.coverTex.minFilter = this.coverTex.magFilter = THREE.LinearFilter; this.coverTex.needsUpdate = true;
    this.pathTex = new THREE.DataTexture(pd8, PATH_RES, PATH_RES, THREE.RedFormat, THREE.UnsignedByteType);
    this.pathTex.minFilter = this.pathTex.magFilter = THREE.LinearFilter; this.pathTex.needsUpdate = true;
    this.buildMeshes(); this.ready = true;
    onProgress?.(1);
  }

  /** bilinear terrain height (m) */
  height(x: number, z: number): number {
    const fx = clamp((x + SIZE / 2) / DX, 0, N - 1.001), fz = clamp((z + SIZE / 2) / DX, 0, N - 1.001);
    const ix = Math.floor(fx), iz = Math.floor(fz), tx = fx - ix, tz = fz - iz, H = this.heights;
    const a = H[iz * N + ix], b = H[iz * N + ix + 1], c = H[(iz + 1) * N + ix], d = H[(iz + 1) * N + ix + 1];
    return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz;
  }
  normal(x: number, z: number, out: number[]): void {
    const e = DX; const hx = this.height(x + e, z) - this.height(x - e, z), hz = this.height(x, z + e) - this.height(x, z - e);
    const inv = 1 / Math.hypot(hx, 2 * e, hz); out[0] = -hx * inv; out[1] = 2 * e * inv; out[2] = -hz * inv;
  }
  normalY(x: number, z: number): number { const e = DX; const hx = this.height(x + e, z) - this.height(x - e, z), hz = this.height(x, z + e) - this.height(x, z - e); return 2 * e / Math.hypot(hx, 2 * e, hz); }
  /** distance (m) to nearest path centreline; large outside the mapped area */
  distToPath(x: number, z: number): number {
    const px = PATH_RES / PATH_SPAN, fx = (x + PATH_SPAN / 2) * px, fz = (z + PATH_SPAN / 2) * px;
    if (fx < 0 || fz < 0 || fx >= PATH_RES - 1 || fz >= PATH_RES - 1) return 99;
    return this.pathDist[Math.floor(fz) * PATH_RES + Math.floor(fx)];
  }
  forest(x: number, z: number): number { const C = 1024; const i = clamp(Math.floor((x + SIZE / 2) / SIZE * C), 0, C - 1), j = clamp(Math.floor((z + SIZE / 2) / SIZE * C), 0, C - 1); return this.cover[(j * C + i) * 4] / 255; }
  mown(x: number, z: number): number { const C = 1024; const i = clamp(Math.floor((x + SIZE / 2) / SIZE * C), 0, C - 1), j = clamp(Math.floor((z + SIZE / 2) / SIZE * C), 0, C - 1); return this.cover[(j * C + i) * 4 + 2] / 255; }

  private grid(i0: number, i1: number, j0: number, j1: number, stride: number, holeI0 = -1, holeI1 = -1, holeJ0 = -1, holeJ1 = -1, skirtOuter = false, skirtHole = false): THREE.BufferGeometry {
    const nx = Math.floor((i1 - i0) / stride) + 1, nz = Math.floor((j1 - j0) / stride) + 1;
    const pos: number[] = [], nor: number[] = [];
    const H = this.heights;
    const vi = (a: number, b: number) => b * nx + a;
    for (let b = 0; b < nz; b++) for (let a = 0; a < nx; a++) {
      const i = i0 + a * stride, j = j0 + b * stride;
      const x = -SIZE / 2 + i * DX, z = -SIZE / 2 + j * DX, y = H[j * N + i];
      pos.push(x, y, z);
      const il = Math.max(i - stride, 0), ir = Math.min(i + stride, N - 1), ju = Math.max(j - stride, 0), jd = Math.min(j + stride, N - 1);
      const hx = (H[j * N + ir] - H[j * N + il]) / ((ir - il) * DX), hz = (H[jd * N + i] - H[ju * N + i]) / ((jd - ju) * DX);
      const inv = 1 / Math.hypot(hx, 1, hz); nor.push(-hx * inv, inv, -hz * inv);
    }
    const idx: number[] = [];
    for (let b = 0; b < nz - 1; b++) for (let a = 0; a < nx - 1; a++) {
      const i = i0 + a * stride, j = j0 + b * stride;
      if (holeI0 >= 0 && i >= holeI0 && i + stride <= holeI1 && j >= holeJ0 && j + stride <= holeJ1) continue;
      const v00 = vi(a, b), v10 = vi(a + 1, b), v01 = vi(a, b + 1), v11 = vi(a + 1, b + 1);
      // alternate diagonal to reduce faceting
      if (((a + b) & 1) === 0) idx.push(v00, v01, v10, v10, v01, v11); else idx.push(v00, v01, v11, v00, v11, v10);
    }
    const skirt = (list: number[]) => { // list of vertex indices along a loop/edge; drop 12 m
      const base = pos.length / 3;
      for (const v of list) { pos.push(pos[v * 3], pos[v * 3 + 1] - 12, pos[v * 3 + 2]); nor.push(nor[v * 3], nor[v * 3 + 1], nor[v * 3 + 2]); }
      for (let k = 0; k < list.length - 1; k++) { const a = list[k], b = list[k + 1], c = base + k, d = base + k + 1; idx.push(a, b, c, b, d, c, a, c, b, b, c, d); }
    };
    if (skirtOuter) {
      const e1: number[] = [], e2: number[] = [], e3: number[] = [], e4: number[] = [];
      for (let a = 0; a < nx; a++) { e1.push(vi(a, 0)); e2.push(vi(a, nz - 1)); }
      for (let b = 0; b < nz; b++) { e3.push(vi(0, b)); e4.push(vi(nx - 1, b)); }
      skirt(e1); skirt(e2); skirt(e3); skirt(e4);
    }
    if (skirtHole && holeI0 >= 0) {
      const a0 = (holeI0 - i0) / stride, a1 = (holeI1 - i0) / stride, b0 = (holeJ0 - j0) / stride, b1 = (holeJ1 - j0) / stride;
      const e1: number[] = [], e2: number[] = [], e3: number[] = [], e4: number[] = [];
      for (let a = a0; a <= a1; a++) { e1.push(vi(a, b0)); e2.push(vi(a, b1)); }
      for (let b = b0; b <= b1; b++) { e3.push(vi(a0, b)); e4.push(vi(a1, b)); }
      skirt(e1); skirt(e2); skirt(e3); skirt(e4);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setIndex(idx);
    g.computeBoundingSphere(); g.computeBoundingBox();
    return g;
  }

  private buildMeshes(): void {
    const c = (N - 1) / 2; const half = 256; // L0: +-500 m at 1.953 m
    const L0 = this.grid(c - half, c + half, c - half, c + half, 1, -1, -1, -1, -1, true, false);
    const stride = 8; const L1 = this.grid(0, N - 1, 0, N - 1, stride, c - half, c + half, c - half, c + half, true, true);
    this.material = this.makeMaterial();
    const m0 = new THREE.Mesh(L0, this.material), m1 = new THREE.Mesh(L1, this.material);
    m0.receiveShadow = m1.receiveShadow = true; m0.frustumCulled = m1.frustumCulled = false;
    this.mesh.add(m0, m1);
    // far backdrop ring (analytic, 160 m) out to 8 km so the horizon is never a cliff
    const pos: number[] = [], idx: number[] = [], nor: number[] = []; const S = 160, R = 8000, n = (2 * R) / S + 1;
    for (let b = 0; b < n; b++) for (let a = 0; a < n; a++) { const x = -R + a * S, z = -R + b * S; const inside = Math.abs(x) <= SIZE / 2 + 1 && Math.abs(z) <= SIZE / 2 + 1; pos.push(x, inside ? -400 : baseHeight(x, z) - (Math.max(Math.abs(x), Math.abs(z)) < SIZE / 2 + 400 ? 6 : 0), z); nor.push(0, 1, 0); }
    for (let b = 0; b < n - 1; b++) for (let a = 0; a < n - 1; a++) {
      const x0 = -R + a * S, z0 = -R + b * S; if (Math.abs(x0 + S / 2) < SIZE / 2 && Math.abs(z0 + S / 2) < SIZE / 2) continue;
      const v = b * n + a; idx.push(v, v + n, v + 1, v + 1, v + n, v + n + 1);
    }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); g.setIndex(idx);
    g.computeVertexNormals();
    const m2 = new THREE.Mesh(g, this.material); m2.frustumCulled = false; this.mesh.add(m2);
  }

  private makeMaterial(): THREE.MeshStandardMaterial {
    const asphalt = makeAsphalt(1024), detail = makeGroundDetail(512);
    const mat = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.96, metalness: 0 });
    const U = {
      uCover: { value: this.coverTex }, uPath: { value: this.pathTex }, uAsphalt: { value: asphalt.map }, uAsphaltN: { value: asphalt.normalMap },
      uDetail: { value: detail.map }, uDetailN: { value: detail.normalMap }, uPathMin: { value: new THREE.Vector2(-PATH_SPAN / 2, -PATH_SPAN / 2) },
      uSize: { value: SIZE },
    };
    (mat as any).userData.uniforms = U;
    mat.onBeforeCompile = (sh) => {
      Object.assign(sh.uniforms, U);
      sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nvarying vec3 vWP;').replace('#include <begin_vertex>', '#include <begin_vertex>\nvWP = position;');
      sh.fragmentShader = sh.fragmentShader
        .replace('#include <common>', `#include <common>
varying vec3 vWP; uniform sampler2D uCover,uPath,uAsphalt,uAsphaltN,uDetail,uDetailN; uniform vec2 uPathMin; uniform float uSize;
${GROUND_GLSL}
float gAsph; float gEdge; float gForest; float gDistFade; vec3 gDetailN; vec3 gAsphN;`)
        .replace('#include <color_fragment>', `#include <color_fragment>
{
  vec2 xz = vWP.xz;
  vec3 cover = texture2D(uCover, (xz + 0.5*uSize)/uSize).rgb;
  vec2 puv = (xz - uPathMin)/${PATH_SPAN.toFixed(1)};
  float pd = 99.0; if (puv.x>0.001 && puv.y>0.001 && puv.x<0.999 && puv.y<0.999) pd = texture2D(uPath, puv).r*8.0;
  float wob = (gfbm(xz*0.45)-0.5)*0.42;
  float hw = 1.55 + wob;
  gAsph = 1.0 - smoothstep(hw-0.04, hw+0.04, pd);
  gEdge = (1.0-gAsph) * (1.0 - smoothstep(hw+0.05, hw+0.55+wob, pd));
  float dist = length(vViewPosition);
  gDistFade = 1.0 - smoothstep(40.0, 120.0, dist);
  float n1 = gfbm(xz*0.045), n2 = gfbm(xz*0.011+7.0);
  vec3 g = groundPalette(cover, xz, n1, n2);
  // field patchwork across the valley floor
  vec2 fq = mat2(0.82,-0.57,0.57,0.82)*xz/160.0; vec2 fid = floor(fq);
  float fr = gh(fid); vec3 fieldTint = mix(vec3(1.0), mix(vec3(1.25,1.12,0.7), vec3(0.78,0.95,0.7), fr), (1.0-cover.b)*(1.0-cover.r)*smoothstep(260.0,500.0,length(xz)));
  g *= fieldTint;
  vec3 dt = texture2D(uDetail, xz*1.3).rgb; vec3 dt2 = texture2D(uDetail, xz*0.17+0.3).rgb;
  g *= (0.55 + 0.9*dt.r) * (0.75 + 0.5*dt2.r);
  // autumn leaf-litter flecks in forest
  float lit = step(0.8, gn(xz*3.1)) * cover.r; g = mix(g, lin(vec3(0.55,0.25,0.07))*0.7, lit*0.5);
  // steep banks expose soil
  float sl = 1.0 - normalize(vNormal).y;
  // asphalt
  vec3 a1 = texture2D(uAsphalt, xz*1.25).rgb, a2 = texture2D(uAsphalt, xz*0.29+0.13).rgb;
  vec3 asph = a1 * (0.62 + 0.9*a2) * (0.85 + 0.3*gfbm(xz*0.6));
  float rut = exp(-pow((pd-0.62)/0.28,2.0)) * 0.22; asph *= 1.0 - rut;
  asph *= mix(1.0, 0.75, smoothstep(0.0, 0.6, gn(xz*0.9)*gfbm(xz*0.08)));
  vec3 lip = mix(lin(vec3(0.22,0.20,0.15)), g, 0.4) * (0.6+0.8*dt.g);
  gForest = cover.r;
  vec3 albedo = mix(g, lip, gEdge*0.85);
  albedo = mix(albedo, asph, gAsph);
  // darker root-zone so blades read as the lit surface layer
  albedo *= mix(1.0, 0.62, (1.0-gAsph)*gDistFade*0.75);
  diffuseColor.rgb = albedo;
  vec3 nd = texture2D(uDetailN, xz*1.3).xyz*2.0-1.0; vec3 na = texture2D(uAsphaltN, xz*1.25).xyz*2.0-1.0;
  gDetailN = nd; gAsphN = na;
}`)
        .replace('#include <roughnessmap_fragment>', '#include <roughnessmap_fragment>\nroughnessFactor = mix(0.97, 0.9, gAsph);')
        .replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
{
  float sA = gAsph * 0.9 * (1.0 - smoothstep(30.0, 90.0, length(vViewPosition)));
  float sD = (1.0-gAsph) * 0.5 * gDistFade;
  vec3 pert = vec3(gAsphN.x*sA + gDetailN.x*sD, 0.0, -(gAsphN.y*sA + gDetailN.y*sD));
  normal = normalize(normal + (viewMatrix*vec4(pert,0.0)).xyz);
}`);
    };
    return mat;
  }
}
