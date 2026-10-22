import * as THREE from 'three';
import { QualityPreset, WORLD } from '../config';
import { mulberry32, noise2, fbm2 } from '../util/noise';
import { smoothstep, clamp } from '../util/math';
import type { ValleyTerrain } from './ValleyTerrain';
import type { Colliders } from './Colliders';
import type { WindObstacle } from '../physics/WindFieldVolume';
import { buildSpruce, buildBroadleaf, buildFarTree, TreeGeo } from './TreeFactory';
import { makeBark, makeSpruceSprig, makeLeafCluster } from './ProceduralTextures';
import { makeFoliageMaterial, FoliageUniforms, patchSSS } from './FoliageMaterials';
import { GROUND_GLSL } from './ValleyTerrain';
import { SnowCover } from './SnowFall';

export interface TreeRec { x: number; y: number; z: number; rot: number; s: number; sw: number; variant: number; tint: number; conifer: boolean; H: number; crownR: number; }

interface Variant {
  conifer: boolean; geo0: TreeGeo; geo1: TreeGeo; w0: THREE.InstancedMesh; l0: THREE.InstancedMesh; w1: THREE.InstancedMesh; l1: THREE.InstancedMesh; list: number[];
}

export class FoliageInstancer {
  group = new THREE.Group();
  trees: TreeRec[] = [];      // near set (r < 560 m)
  farCount = 0;
  private variants: Variant[] = [];
  private farNear: { conifer: THREE.InstancedMesh; broad: THREE.InstancedMesh };
  private farStatic: { conifer: THREE.InstancedMesh; broad: THREE.InstancedMesh };
  private nearFarLists: number[][] = [[], []];
  private lastBucket = -1;
  grass: GrassLayer[] = [];
  private tmpM = new THREE.Matrix4();

  constructor(private terrain: ValleyTerrain, private colliders: Colliders, private q: QualityPreset, onProgress?: (f: number) => void) {
    // --- materials
    const barkB = makeBark(512, 'brown'), barkG = makeBark(512, 'grey');
    const sprig = makeSpruceSprig(512), leafMaple = makeLeafCluster(512, 'maple', 41), leafGold = makeLeafCluster(512, 'gold', 77), leafOak = makeLeafCluster(512, 'oak', 91);
    const barkMat = (t: typeof barkB) => makeFoliageMaterial({ map: t.map, normalMap: t.normalMap, vertexColors: true, roughness: 0.95, side: THREE.FrontSide, sss: 0 });
    const spruceLeaf = makeFoliageMaterial({ map: sprig.map, alphaTest: 0.45, sss: 1.0, tint: '0.55,0.80,0.18', roughness: 0.65 });
    const mapleLeaf = makeFoliageMaterial({ map: leafMaple.map, alphaTest: 0.5, sss: 1.7, tint: '1.0,0.62,0.12', roughness: 0.62 });
    const goldLeaf = makeFoliageMaterial({ map: leafGold.map, alphaTest: 0.5, sss: 1.7, tint: '1.0,0.78,0.15', roughness: 0.62 });
    const oakLeaf = makeFoliageMaterial({ map: leafOak.map, alphaTest: 0.5, sss: 1.4, tint: '0.95,0.62,0.18', roughness: 0.7 });
    const mats = [
      { conifer: true, wood: barkMat(barkB), leaf: spruceLeaf }, { conifer: true, wood: barkMat(barkB), leaf: spruceLeaf },
      { conifer: false, wood: barkMat(barkG), leaf: mapleLeaf }, { conifer: false, wood: barkMat(barkG), leaf: goldLeaf }, { conifer: false, wood: barkMat(barkB), leaf: oakLeaf },
    ];
    // --- place trees first so we can size instance buffers
    this.placeTrees();
    onProgress?.(0.3);
    const geos: [TreeGeo, TreeGeo][] = [
      [buildSpruce(11, 0), buildSpruce(11, 1)], [buildSpruce(29, 0), buildSpruce(29, 1)],
      [buildBroadleaf(21, 0, 'maple'), buildBroadleaf(21, 1, 'maple')], [buildBroadleaf(35, 0, 'maple'), buildBroadleaf(35, 1, 'maple')], [buildBroadleaf(47, 0, 'oak'), buildBroadleaf(47, 1, 'oak')],
    ];
    const counts = new Array(5).fill(0); for (const t of this.trees) counts[t.variant]++;
    mats.forEach((m, i) => {
      const cap = Math.max(4, counts[i]);
      const mk = (g: THREE.BufferGeometry, mat: THREE.Material, shadow: boolean) => { const im = new THREE.InstancedMesh(g, mat, cap); im.frustumCulled = false; im.castShadow = shadow; im.receiveShadow = true; im.count = 0; im.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.group.add(im); return im; };
      this.variants.push({ conifer: m.conifer, geo0: geos[i][0], geo1: geos[i][1], w0: mk(geos[i][0].wood, m.wood, true), l0: mk(geos[i][0].leaf, m.leaf, true), w1: mk(geos[i][1].wood, m.wood, true), l1: mk(geos[i][1].leaf, m.leaf, true), list: [] });
    });
    // --- far (LOD2) meshes
    const farMat = (sss: number) => { const m = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1, metalness: 0, side: THREE.FrontSide }); m.onBeforeCompile = sh => { if (sss) patchSSS(sh, 'vec3(1.0,0.7,0.2)', sss); }; return m; };
    const mkFar = (g: THREE.BufferGeometry, mat: THREE.Material, cap: number, shadow: boolean) => { const im = new THREE.InstancedMesh(g, mat, Math.max(cap, 1)); im.frustumCulled = false; im.castShadow = shadow; im.receiveShadow = true; im.count = 0; this.group.add(im); return im; };
    const gC = buildFarTree('conifer'), gB = buildFarTree('broadleaf');
    const nearCap = this.trees.length;
    this.farNear = { conifer: mkFar(gC, farMat(0.5), nearCap, false), broad: mkFar(gB, farMat(1.2), nearCap, false) };
    this.farNear.conifer.instanceMatrix.setUsage(THREE.DynamicDrawUsage); this.farNear.broad.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    this.farStatic = this.buildFarForest(gC, gB, farMat, mkFar);
    onProgress?.(0.7);
    // --- grass layers
    this.grass.push(new GrassLayer(terrain, { patch: 13, count: q.grassNear, h: [0.10, 0.28], width: 0.0085, mode: 0 }));
    this.grass.push(new GrassLayer(terrain, { patch: 46, count: q.grassMid, h: [0.18, 0.55], width: 0.02, mode: 0 }));
    this.grass.push(new GrassLayer(terrain, { patch: 16, count: Math.floor(q.grassNear * 0.5), h: [0.05, 0.09], width: 0.045, mode: 1 }));
    for (const g of this.grass) this.group.add(g.mesh);
    this.rebucket(new THREE.Vector3(0, 100, 0), true);
    onProgress?.(1);
  }

  private pickKind(x: number, z: number, h: number, rng: () => number, parkBias = 0): { variant: number; conifer: boolean } {
    const coniferP = clamp(0.28 + 0.5 * smoothstep(150, 250, h) + 0.25 * this.terrain.forest(x, z) - parkBias, 0.05, 0.92);
    if (rng() < coniferP) return { variant: rng() < 0.5 ? 0 : 1, conifer: true };
    const r = rng(); return { variant: r < 0.42 ? 2 : r < 0.75 ? 3 : 4, conifer: false };
  }

  private placeTrees(): void {
    const T = this.terrain, rng = mulberry32(2024);
    const add = (x: number, z: number, minSep = 0): boolean => {
      if (Math.abs(x) > 1990 || Math.abs(z) > 1990) return false;
      const dp = T.distToPath(x, z); if (dp < 3.2) return false;
      const h = T.height(x, z), k = this.pickKind(x, z, h, rng, 0.0);
      const conifer = k.conifer; const s = conifer ? 0.7 + rng() * 0.75 : 0.75 + rng() * 0.6;
      const H = (conifer ? 21 : 13) * s, crownR = (conifer ? 4.4 : 5.8) * s * 0.9;
      if (Math.hypot(x - WORLD.home.x, z - WORLD.home.z) < WORLD.home.clearR + crownR) return false;
      for (const t of this.trees) { if (minSep && Math.abs(t.x - x) < minSep && Math.abs(t.z - z) < minSep && Math.hypot(t.x - x, t.z - z) < minSep) return false; }
      this.trees.push({ x, y: h - 0.15, z, rot: rng() * 6.283, s, sw: 0.85 + rng() * 0.3, variant: k.variant, tint: 0.85 + rng() * 0.3, conifer, H, crownR });
      return true;
    };
    // park: allee trees along avenues/loop
    const rows: { idx: number; step: number; off: number }[] = [{ idx: 1, step: 15, off: 5.2 }, { idx: 2, step: 16, off: 5.5 }, { idx: 0, step: 22, off: 6.5 }];
    for (const row of rows) {
      const pl = T.polylines[row.idx]; let acc = 0, side = 1;
      for (let i = 1; i < pl.length - 1; i++) {
        acc += Math.hypot(pl[i][0] - pl[i - 1][0], pl[i][1] - pl[i - 1][1]);
        if (acc < row.step + rng() * 3) continue; acc = 0; side = -side;
        const tx = pl[i + 1][0] - pl[i - 1][0], tz = pl[i + 1][1] - pl[i - 1][1], L = Math.hypot(tx, tz) || 1;
        const x = pl[i][0] + (-tz / L) * row.off * side + (rng() - 0.5) * 1.5, z = pl[i][1] + (tx / L) * row.off * side + (rng() - 0.5) * 1.5;
        if (Math.hypot(x - 5, z - 8) < 24) continue;
        add(x, z, 6);
      }
    }
    // park groves + specimen trees
    for (let g = 0; g < 22; g++) {
      const a = rng() * 6.283, d = 40 + rng() * 190, cx = Math.cos(a) * d, cz = Math.sin(a) * d, n = 4 + Math.floor(rng() * 9);
      for (let i = 0; i < n; i++) { const aa = rng() * 6.283, dd = Math.sqrt(rng()) * 16; add(cx + Math.cos(aa) * dd, cz + Math.sin(aa) * dd, 5); }
    }
    for (let i = 0; i < 140; i++) { const a = rng() * 6.283, d = 25 + Math.sqrt(rng()) * 200; const x = Math.cos(a) * d, z = Math.sin(a) * d; if (Math.hypot(x - 5, z - 8) > 30) add(x, z, 9); }
    // surrounding woodland and hedgerows (jittered grid)
    const S = 9 / Math.sqrt(this.q.nearTrees / 1200);
    for (let gx = -560; gx < 560; gx += S) for (let gz = -560; gz < 560; gz += S) {
      const x = gx + rng() * S, z = gz + rng() * S, r = Math.hypot(x, z);
      if (r < 205 || r > 560) continue;
      const f = T.forest(x, z); const hedge = smoothstep(0.62, 0.8, fbm2(x / 38 + 3, z / 38 - 1, 2)) * 0.5;
      if (rng() < f * 0.75 + hedge * (1 - f)) add(x, z, 0);
    }
    for (const t of this.trees) {
      this.colliders.addCyl({ x: t.x, z: t.z, r: (t.conifer ? 0.3 : 0.4) * t.s, y0: t.y, y1: t.y + t.H, kind: 'trunk' });
      this.colliders.addCyl({ x: t.x, z: t.z, r: t.crownR, y0: t.y + (t.conifer ? 0.12 : 0.28) * t.H, y1: t.y + t.H, kind: 'canopy' });
    }
  }

  windObstacles(): WindObstacle[] { return this.trees.filter(t => Math.hypot(t.x, t.z) < 450).map(t => ({ x: t.x, z: t.z, r: t.crownR * 0.9, h: t.H, base: t.y })); }

  private buildFarForest(gC: THREE.BufferGeometry, gB: THREE.BufferGeometry, farMat: (s: number) => THREE.Material, mkFar: (g: THREE.BufferGeometry, m: THREE.Material, cap: number, sh: boolean) => THREE.InstancedMesh) {
    const T = this.terrain, rng = mulberry32(777), cap = this.q.farTrees;
    const spacing = Math.max(7, Math.sqrt(5.4e6 / cap)); const cs: number[] = [], bs: number[] = [], cc: number[] = [], bc: number[] = [];
    const palette = [[0.85, 0.28, 0.08], [0.92, 0.5, 0.1], [0.95, 0.72, 0.18], [0.45, 0.55, 0.12], [0.7, 0.35, 0.1], [0.6, 0.62, 0.14]];
    let n = 0; const m = new THREE.Matrix4(), q = new THREE.Quaternion(), p = new THREE.Vector3(), sc = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
    const cMat: THREE.Matrix4[] = [], bMat: THREE.Matrix4[] = [];
    for (let gx = -1990; gx < 1990 && n < cap; gx += spacing) for (let gz = -1990; gz < 1990 && n < cap; gz += spacing) {
      const x = gx + rng() * spacing, z = gz + rng() * spacing; if (Math.hypot(x, z) < 540) continue;
      const f = T.forest(x, z); const fn = f + 0.35 * (noise2(x / 53, z / 53) - 0.5);
      if (fn < 0.38 || rng() > smoothstep(0.38, 0.62, fn) + 0.05) continue;
      const h = T.height(x, z); const conifer = rng() < clamp(0.3 + 0.55 * smoothstep(140, 240, h), 0.1, 0.9);
      const s = (conifer ? 0.75 + rng() * 0.7 : 0.8 + rng() * 0.6); p.set(x, h - 0.3, z); q.setFromAxisAngle(up, rng() * 6.28); sc.set(s * (0.9 + rng() * 0.25), s * (conifer ? 1 : 1) , s * (0.9 + rng() * 0.25)); m.compose(p, q, sc);
      if (conifer) { cMat.push(m.clone()); const g = 0.75 + rng() * 0.35; cc.push(g * 0.85, g, g * 0.85); } else { bMat.push(m.clone()); const c = palette[Math.floor(rng() * palette.length)]; const k = 0.8 + rng() * 0.4; bc.push(c[0] * k, c[1] * k, c[2] * k); }
      n++;
    }
    const mkSet = (g: THREE.BufferGeometry, mats: THREE.Matrix4[], cols: number[], sss: number) => {
      const im = mkFar(g, farMat(sss), mats.length, false); mats.forEach((mm, i) => im.setMatrixAt(i, mm)); im.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(cols.length ? cols : [1, 1, 1]), 3); im.count = mats.length; im.instanceMatrix.needsUpdate = true; return im;
    };
    this.farCount = n; void cs; void bs;
    return { conifer: mkSet(gC, cMat, cc, 0.5), broad: mkSet(gB, bMat, bc, 1.2) };
  }

  /** Re-bucket near trees by camera distance into LOD0/LOD1/LOD2 (call ~2 Hz). */
  rebucket(cam: THREE.Vector3, force = false): void {
    const now = Math.floor(performance.now() / 450); if (!force && now === this.lastBucket) return; this.lastBucket = now;
    const V = this.variants; for (const v of V) v.list.length = 0;
    this.nearFarLists[0].length = 0; this.nearFarLists[1].length = 0;
    const d0 = 58, d1 = 230;
    const near0: number[] = [], near1: number[] = [];
    for (let i = 0; i < this.trees.length; i++) {
      const t = this.trees[i]; const dx = t.x - cam.x, dz = t.z - cam.z, d2 = dx * dx + dz * dz;
      if (d2 < d0 * d0 + t.crownR * 40) near0.push(i); else if (d2 < d1 * d1) near1.push(i); else this.nearFarLists[t.conifer ? 0 : 1].push(i);
    }
    const counters = V.map(() => [0, 0]); const m = new Float32Array(16);
    const put = (im: THREE.InstancedMesh, idx: number, t: TreeRec) => {
      const c = Math.cos(t.rot), s = Math.sin(t.rot), sx = t.s * t.sw, sy = t.s;
      m.set([c * sx, 0, -s * sx, 0, 0, sy, 0, 0, s * sx, 0, c * sx, 0, t.x, t.y, t.z, 1]); im.instanceMatrix.array.set(m, idx * 16);
    };
    const tintSet = (im: THREE.InstancedMesh, idx: number, t: TreeRec) => { if (!im.instanceColor) im.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(im.instanceMatrix.count * 3), 3); im.instanceColor.setXYZ(idx, t.tint, t.tint, t.tint); };
    for (const i of near0) { const t = this.trees[i], v = V[t.variant], k = counters[t.variant][0]++; put(v.w0, k, t); put(v.l0, k, t); tintSet(v.l0, k, t); tintSet(v.w0, k, t); }
    for (const i of near1) { const t = this.trees[i], v = V[t.variant], k = counters[t.variant][1]++; put(v.w1, k, t); put(v.l1, k, t); tintSet(v.l1, k, t); tintSet(v.w1, k, t); }
    V.forEach((v, i) => { v.w0.count = v.l0.count = counters[i][0]; v.w1.count = v.l1.count = counters[i][1]; for (const im of [v.w0, v.l0, v.w1, v.l1]) { im.instanceMatrix.needsUpdate = true; if (im.instanceColor) im.instanceColor.needsUpdate = true; } });
    const palette = [[0.85, 0.3, 0.1], [0.95, 0.55, 0.12], [0.95, 0.75, 0.2], [0.55, 0.6, 0.15]];
    [this.farNear.conifer, this.farNear.broad].forEach((im, w) => {
      const list = this.nearFarLists[w]; im.count = list.length;
      if (!im.instanceColor) im.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(im.instanceMatrix.count * 3), 3);
      list.forEach((ti, k) => { const t = this.trees[ti]; put(im, k, t); const c = w === 0 ? [t.tint * 0.8, t.tint * 0.95, t.tint * 0.8] : palette[ti % palette.length]; im.instanceColor!.setXYZ(k, c[0] * t.tint, c[1] * t.tint, c[2] * t.tint); });
      im.instanceMatrix.needsUpdate = true; im.instanceColor.needsUpdate = true;
    });
  }

  update(cam: THREE.Vector3, t: number): void {
    FoliageUniforms.uTime.value = t;
    for (const g of this.grass) g.update(cam);
    this.rebucket(cam);
  }
}

export interface GrassOpts { patch: number; count: number; h: [number, number]; width: number; mode: 0 | 1; }
/** GPU-driven grass: positions derived in the vertex shader from a camera-anchored world lattice (no CPU work per frame). */
export class GrassLayer {
  mesh: THREE.Mesh;
  private u: Record<string, THREE.IUniform>;
  constructor(terrain: ValleyTerrain, o: GrassOpts) {
    const g = new THREE.InstancedBufferGeometry();
    if (o.mode === 0) {
      g.setAttribute('position', new THREE.Float32BufferAttribute([-1, 0, 0, 1, 0, 0, -0.78, 0.5, 0, 0.78, 0.5, 0, 0, 1, 0], 3)); g.setIndex([0, 1, 2, 1, 3, 2, 2, 3, 4]);
    } else {
      g.setAttribute('position', new THREE.Float32BufferAttribute([-1, 0, -1, 1, 0, -1, -1, 0, 1, 1, 0, 1], 3)); g.setIndex([0, 2, 1, 1, 2, 3]);
    }
    const rng = mulberry32(o.mode * 1000 + o.count), a = new Float32Array(o.count * 4);
    for (let i = 0; i < a.length; i++) a[i] = rng();
    g.setAttribute('aSeed', new THREE.InstancedBufferAttribute(a, 4)); g.instanceCount = o.count;
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e5);
    const mat = new THREE.MeshStandardMaterial({ side: THREE.DoubleSide, roughness: o.mode === 0 ? 0.62 : 0.8, metalness: 0 });
    this.u = {
      uCam: { value: new THREE.Vector3() }, uPatch: { value: o.patch }, uBH: { value: new THREE.Vector2(o.h[0], o.h[1]) }, uWidth: { value: o.width },
      uHT: { value: terrain.heightTex }, uCV: { value: terrain.coverTex }, uPT: { value: terrain.pathTex }, uExcl: { value: Array.from({ length: 16 }, () => new THREE.Vector4(1e9, 1e9, 1e9, 1e9)) },
    };
    (this as any).exclusions = this.u.uExcl.value;
    mat.onBeforeCompile = (sh) => {
      Object.assign(sh.uniforms, this.u, { uTime: FoliageUniforms.uTime, uWind: FoliageUniforms.uWind, uDrone: FoliageUniforms.uDrone, uWash: FoliageUniforms.uWash, uSnow: SnowCover.uSnow });
      const LIT = o.mode === 1 ? '#define LITTER 1\n' : '';
      sh.vertexShader = sh.vertexShader
        .replace('#include <common>', `${LIT}#include <common>
attribute vec4 aSeed; uniform vec3 uCam, uWind; uniform float uPatch, uWidth, uTime, uWash; uniform vec2 uBH; uniform vec4 uDrone; uniform sampler2D uHT, uCV, uPT; uniform vec4 uExcl[16]; uniform float uSnow;
varying vec3 vGrassCol;
${GROUND_GLSL}
float hsh(float x){ return fract(sin(x*127.1)*43758.5453); }`)
        .replace('#include <beginnormal_vertex>', `float ang0 = aSeed.z*6.2831853;
vec3 objectNormal = normalize(vec3(-sin(ang0)*0.55, 1.0, cos(ang0)*0.55));
#ifdef USE_TANGENT
vec3 objectTangent = vec3( tangent.xyz );
#endif`)
        .replace('#include <begin_vertex>', `
vec2 baseP = aSeed.xy * uPatch;
vec2 wxz = baseP + uPatch * floor((uCam.xz - baseP)/uPatch + 0.5);
float dc = length(wxz - uCam.xz);
float fade = 1.0 - smoothstep(0.36*uPatch, 0.5*uPatch, dc);
vec2 huv = ((wxz + 2000.0)/${(4000 / 2048).toFixed(6)} + 0.5)/2049.0;
float gy = texture2D(uHT, huv).r;
vec3 cv = texture2D(uCV, (wxz + 2000.0)/4000.0).rgb;
vec2 puv = (wxz - vec2(-256.0))/512.0; float pd = 99.0;
if (puv.x>0.001 && puv.y>0.001 && puv.x<0.999 && puv.y<0.999) pd = texture2D(uPT, puv).r*8.0;
float keep = smoothstep(1.55, 1.9, pd);
for (int i=0;i<16;i++){ vec4 e = uExcl[i]; if (wxz.x>e.x && wxz.y>e.y && wxz.x<e.z && wxz.y<e.w) keep = 0.0; }
float dens = mix(1.0, 0.18, cv.r);
keep *= step(fract(aSeed.z*37.7), dens);
float hv = aSeed.w;
float mowed = cv.b;
float hMul = mix(mix(0.9, 3.4, smoothstep(0.35,0.75,gfbm(wxz*0.02))), 0.75, mowed);
float H = mix(uBH.x, uBH.y, hv) * hMul * keep * fade * (1.0 - 0.5 * uSnow);
float ang = ang0; vec3 right = vec3(cos(ang), 0.0, sin(ang)); vec3 fwd = vec3(-sin(ang), 0.0, cos(ang));
vec3 transformed;
#ifndef LITTER
float yy = position.y; float side = position.x;
float curl = (0.2 + 0.55*hsh(aSeed.w*91.7)) * yy*yy * H;
vec2 wd = normalize(uWind.xz + vec2(0.001)); float ws = length(uWind.xz) * 0.55;
float gust = 0.5 + 0.5*sin(dot(wxz, wd)*0.33 - uTime*(1.3+0.25*ws) + aSeed.z*6.28);
vec2 wl = wd * (0.05 + 0.04*ws) * (0.4+gust) * yy*yy * H;
vec3 rv = vec3(wxz.x, gy, wxz.y) - uDrone.xyz; float rd = length(rv.xz);
float wk = smoothstep(uDrone.w + 1.0, 0.3, rd) * uWash;
vec2 push = normalize(rv.xz + vec2(1e-3)) * wk * 0.85 * yy * H + wd * wk * 0.1 * yy * H;
float flat1 = 1.0 - 0.35 * wk * yy;
transformed = vec3(wxz.x, gy, wxz.y) + right * side * uWidth * (1.0 - 0.78*yy) * step(0.001, H) + fwd * curl + vec3(wl.x + push.x, 0.0, wl.y + push.y) + vec3(0.0, yy * H * flat1, 0.0);
// colour: root -> tip, lawn green vs meadow straw, autumn variation
vec3 root = lin(vec3(0.10,0.17,0.05));
vec3 tipLawn = mix(lin(vec3(0.32,0.45,0.13)), lin(vec3(0.46,0.52,0.17)), hsh(aSeed.z*53.3));
vec3 tipMead = mix(lin(vec3(0.72,0.62,0.30)), lin(vec3(0.52,0.50,0.20)), hsh(aSeed.z*17.9));
vec3 tip = mix(tipMead, tipLawn, mowed); tip = mix(tip, lin(vec3(0.25,0.20,0.10)), cv.r*0.7);
vGrassCol = mix(root, tip, pow(yy, 0.75)) * (0.8 + 0.4*hsh(aSeed.w*7.7));
#else
float sz = (0.035 + 0.045*hsh(aSeed.w*13.3)) * keep * fade * step(0.35, gn(wxz*0.7)+cv.r*0.5+mowed*0.0);
vec3 nrm = normalize(vec3(sin(ang)*0.35, 1.0, cos(ang)*0.35));
transformed = vec3(wxz.x, gy + 0.010 + 0.01*hsh(aSeed.w*5.0), wxz.y) + (right*position.x + fwd*position.z) * sz;
int pi_ = int(floor(hsh(aSeed.z*71.3)*5.0));
vec3 lc = pi_==0 ? lin(vec3(0.62,0.17,0.08)) : pi_==1 ? lin(vec3(0.82,0.38,0.09)) : pi_==2 ? lin(vec3(0.85,0.62,0.14)) : pi_==3 ? lin(vec3(0.45,0.26,0.10)) : lin(vec3(0.66,0.50,0.17));
vGrassCol = lc * (0.7 + 0.5*hsh(aSeed.w*3.1));
#endif
vGrassCol = mix(vGrassCol, vec3(0.78, 0.82, 0.90), uSnow * 0.8);
`);
      sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nvarying vec3 vGrassCol;').replace('#include <color_fragment>', '#include <color_fragment>\ndiffuseColor.rgb = vGrassCol;');
      if (o.mode === 0) patchSSS(sh, 'vec3(0.55,0.75,0.12)', 1.25);
    };
    this.mesh = new THREE.Mesh(g, mat); this.mesh.frustumCulled = false; this.mesh.receiveShadow = true; this.mesh.castShadow = false;
  }
  setExclusions(rects: [number, number, number, number][]) { rects.slice(0, 16).forEach((r, i) => this.u.uExcl.value[i].set(r[0], r[1], r[2], r[3])); }
  update(cam: THREE.Vector3): void { this.u.uCam.value.copy(cam); }
}
void WORLD;
