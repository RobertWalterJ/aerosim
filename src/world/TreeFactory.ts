import * as THREE from 'three';
import { mulberry32 } from '../util/noise';

class Builder {
  pos: number[] = []; nor: number[] = []; uv: number[] = []; col: number[] = []; wnd: number[] = []; idx: number[] = [];
  get n() { return this.pos.length / 3; }
  vert(p: THREE.Vector3, n: THREE.Vector3, u: number, v: number, ao: number, tint: [number, number, number], w: [number, number, number]) {
    this.pos.push(p.x, p.y, p.z); this.nor.push(n.x, n.y, n.z); this.uv.push(u, v); this.col.push(ao * tint[0], ao * tint[1], ao * tint[2]); this.wnd.push(w[0], w[1], w[2]);
  }
  geometry(): THREE.BufferGeometry {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(this.nor, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2)); g.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 3));
    g.setAttribute('aWind', new THREE.Float32BufferAttribute(this.wnd, 3)); g.setIndex(this.idx);
    g.computeBoundingSphere(); g.computeBoundingBox(); return g;
  }
  /** tapered tube through points with radii; UV tiles bark once per ~1 m of length */
  tube(pts: THREE.Vector3[], radii: number[], sides: number, ao = 1, flex = 0.2, phase = 0) {
    const base = this.n; let len = 0;
    const T = new THREE.Vector3(), N = new THREE.Vector3(), B = new THREE.Vector3();
    for (let i = 0; i < pts.length; i++) {
      const a = pts[Math.max(i - 1, 0)], b = pts[Math.min(i + 1, pts.length - 1)];
      T.subVectors(b, a).normalize();
      N.set(Math.abs(T.y) > 0.95 ? 1 : 0, Math.abs(T.y) > 0.95 ? 0 : 1, 0).cross(T).normalize(); B.crossVectors(T, N).normalize();
      if (i > 0) len += pts[i].distanceTo(pts[i - 1]);
      for (let s = 0; s <= sides; s++) {
        const t = (s / sides) * Math.PI * 2, c = Math.cos(t), sn = Math.sin(t);
        const nn = new THREE.Vector3().addScaledVector(N, c).addScaledVector(B, sn);
        const p = pts[i].clone().addScaledVector(nn, radii[i]);
        this.vert(p, nn, (s / sides) * Math.max(1, Math.round(radii[0] * 6.28)), len, ao, [1, 1, 1], [phase, flex * (i / (pts.length - 1)), 0]);
      }
    }
    for (let i = 0; i < pts.length - 1; i++) for (let s = 0; s < sides; s++) {
      const a = base + i * (sides + 1) + s, b = a + 1, c = a + sides + 1, d = c + 1; this.idx.push(a, c, b, b, c, d);
    }
  }
  /** curved card strip: centre-line points, half-width per point, side vector per point */
  strip(pts: THREE.Vector3[], half: number[], side: THREE.Vector3[], normal: THREE.Vector3[], ao: number[], tint: [number, number, number], wind: [number, number, number][]) {
    const base = this.n;
    for (let i = 0; i < pts.length; i++) {
      const u = i / (pts.length - 1);
      this.vert(pts[i].clone().addScaledVector(side[i], -half[i]), normal[i], u, 0, ao[i], tint, wind[i]);
      this.vert(pts[i].clone().addScaledVector(side[i], half[i]), normal[i], u, 1, ao[i], tint, wind[i]);
    }
    for (let i = 0; i < pts.length - 1; i++) { const a = base + i * 2; this.idx.push(a, a + 2, a + 1, a + 1, a + 2, a + 3); }
  }
  quad(c: THREE.Vector3, right: THREE.Vector3, up: THREE.Vector3, normal: THREE.Vector3, ao: number, tint: [number, number, number], w: [number, number, number]) {
    const b = this.n;
    const p = (sx: number, sy: number) => c.clone().addScaledVector(right, sx).addScaledVector(up, sy);
    this.vert(p(-1, -1), normal, 0, 0, ao, tint, w); this.vert(p(1, -1), normal, 1, 0, ao, tint, w); this.vert(p(-1, 1), normal, 0, 1, ao, tint, w); this.vert(p(1, 1), normal, 1, 1, ao, tint, w);
    this.idx.push(b, b + 1, b + 2, b + 2, b + 1, b + 3);
  }
}

export interface TreeGeo { wood: THREE.BufferGeometry; leaf: THREE.BufferGeometry; height: number; crownR: number; crownBase: number; }

/** Norway spruce: tapered trunk, whorls of drooping sprig-card branches with upturned tips. */
export function buildSpruce(seed: number, lod: 0 | 1): TreeGeo {
  const rng = mulberry32(seed), W = new Builder(), L = new Builder();
  const H = 20 + rng() * 1.5;
  const pts: THREE.Vector3[] = [], rad: number[] = [];
  for (let i = 0; i <= 10; i++) { const t = i / 10; pts.push(new THREE.Vector3(Math.sin(t * 3 + seed) * 0.12 * t, t * H * 0.97, Math.cos(t * 2.3 + seed) * 0.1 * t)); rad.push(0.34 * Math.pow(1 - t, 0.9) + 0.02); }
  W.tube(pts, rad, lod === 0 ? 8 : 5, 1, 0.1, 0);
  const whorls = lod === 0 ? 36 : 20, per = lod === 0 ? 10 : 7, segs = lod === 0 ? 4 : 3;
  const crownC = new THREE.Vector3(0, H * 0.45, 0);
  for (let w = 0; w < whorls; w++) {
    const t = 0.1 + 0.88 * (w / (whorls - 1)), y = t * H * 0.97;
    const Lmax = (4.6 * Math.pow(1 - t, 0.82) + 0.35) * (0.9 + rng() * 0.2);
    const a0 = rng() * 6.28;
    for (let b = 0; b < per; b++) {
      const az = a0 + (b / per) * 6.28 + (rng() - 0.5) * 0.4, len = Lmax * (0.75 + rng() * 0.35);
      const dir = new THREE.Vector3(Math.cos(az), 0, Math.sin(az));
      const droop = 0.55 - 0.9 * t + (rng() - 0.5) * 0.15;     // lower branches droop, upper ones lift
      const centre: THREE.Vector3[] = [], ao: number[] = [], half: number[] = [], wind: [number, number, number][] = [];
      const start = new THREE.Vector3(0, y, 0);
      for (let s = 0; s <= segs; s++) {
        const u = s / segs;
        const p = start.clone().addScaledVector(dir, u * len); p.y += -droop * u * len * 0.45 + 0.35 * len * u * u * u * u;
        centre.push(p); ao.push((0.3 + 0.75 * Math.pow(u, 0.8)) * (0.72 + 0.28 * t) * (0.9 + rng() * 0.15)); half.push(Math.max(0.12, len * 0.26 * (1 - 0.55 * u * u)));
        wind.push([rng(), u * u * (0.35 + 0.65 * (1 - t)), u * 0.5]);
      }
      const tangent = dir.clone();
      for (const roll of [-0.62, 0.62]) {
        const side = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), tangent).normalize();
        const up = new THREE.Vector3(0, 1, 0);
        const sv = side.clone().applyAxisAngle(tangent, roll), nv = up.clone().applyAxisAngle(tangent, roll);
        const sides: THREE.Vector3[] = [], norms: THREE.Vector3[] = [];
        for (let s = 0; s <= segs; s++) {
          const radial = centre[s].clone().sub(crownC.clone().setY(centre[s].y * 0.8 + H * 0.1)).normalize();
          norms.push(nv.clone().multiplyScalar(0.5).addScaledVector(radial, 0.55).add(new THREE.Vector3(0, 0.25, 0)).normalize()); sides.push(sv);
        }
        L.strip(centre, half, sides, norms, ao, [1, 1, 1], wind);
      }
      if (lod === 0 && rng() < 0.65) { // one thin wood twig
        const tp = centre.slice(0, 3); W.tube(tp, [0.03 * (1 - t) + 0.008, 0.02 * (1 - t) + 0.006, 0.006], 4, 0.8, 0.5, rng());
      }
    }
  }
  return { wood: W.geometry(), leaf: L.geometry(), height: H, crownR: 4.4, crownBase: 1.5 };
}

/** Broadleaf (maple / oak): forked limb skeleton + clustered leaf cards, outward-biased normals for volumetric shading. */
export function buildBroadleaf(seed: number, lod: 0 | 1, species: 'maple' | 'oak'): TreeGeo {
  const rng = mulberry32(seed), W = new Builder(), L = new Builder();
  const H = (species === 'oak' ? 13 : 12) + rng() * 2, trunkH = 3.2 + rng() * 1.6, crownR = species === 'oak' ? 6.8 : 5.4;
  const anchors: THREE.Vector3[] = [];
  const sides = lod === 0 ? 7 : 5;
  const crownC = new THREE.Vector3(0, trunkH + (H - trunkH) * 0.5, 0);
  const grow = (p0: THREE.Vector3, dir: THREE.Vector3, len: number, r0: number, depth: number, maxDepth: number) => {
    const n = 4, pts: THREE.Vector3[] = [p0.clone()], rr: number[] = [r0];
    const d = dir.clone();
    for (let i = 1; i <= n; i++) {
      d.x += (rng() - 0.5) * 0.28; d.z += (rng() - 0.5) * 0.28; d.y += 0.06; d.normalize();
      pts.push(pts[i - 1].clone().addScaledVector(d, len / n)); rr.push(r0 * (1 - 0.7 * i / n) + 0.01);
    }
    W.tube(pts, rr, sides, 1, 0.15 + depth * 0.2, rng());
    const end = pts[n];
    if (depth >= maxDepth - 1) { anchors.push(end.clone()); anchors.push(pts[n - 1].clone().lerp(end, 0.5)); }
    if (depth < maxDepth) {
      const k = depth === 0 ? 2 : 2 + (rng() < 0.45 ? 1 : 0);
      for (let i = 0; i < k; i++) {
        const az = rng() * 6.28 + i * (6.28 / k), spread = 0.55 + rng() * 0.45;
        const nd = d.clone().multiplyScalar(0.8).add(new THREE.Vector3(Math.cos(az) * spread, 0.1, Math.sin(az) * spread)).normalize();
        grow(end, nd, len * (0.72 + rng() * 0.12), rr[n] * 1.15, depth + 1, maxDepth);
      }
    }
    if (depth >= 1) anchors.push(pts[2].clone());
  };
  // trunk
  const tp: THREE.Vector3[] = [], tr: number[] = [];
  for (let i = 0; i <= 5; i++) { const t = i / 5; tp.push(new THREE.Vector3(Math.sin(seed + t * 2) * 0.1 * t, t * trunkH, Math.cos(seed * 2 + t) * 0.1 * t)); tr.push(0.42 * (1 - 0.35 * t) + (species === 'oak' ? 0.05 : 0)); }
  W.tube(tp, tr, sides + 2, 1, 0.05, 0);
  const limbs = 4 + Math.floor(rng() * 2), maxDepth = lod === 0 ? 3 : 2;
  for (let i = 0; i < limbs; i++) {
    const az = (i / limbs) * 6.28 + rng() * 0.6, tilt = 0.75 + rng() * 0.45;
    grow(tp[5].clone(), new THREE.Vector3(Math.cos(az) * tilt, 1, Math.sin(az) * tilt).normalize(), (species === 'oak' ? 5.2 : 4.4) * (0.9 + rng() * 0.2), 0.27, 0, maxDepth);
  }
  // leaf cards
  const want = lod === 0 ? 200 : 70, cardS = lod === 0 ? 1.55 : 3.4;
  while (anchors.length < want / 2) anchors.push(anchors[Math.floor(rng() * anchors.length)].clone().add(new THREE.Vector3(rng() - 0.5, rng() * 0.6, rng() - 0.5).multiplyScalar(2.2)));
  for (let a = 0; a < Math.min(anchors.length, want); a++) {
    const A = anchors[a];
    for (let k = 0; k < 2; k++) {
      const c = A.clone().add(new THREE.Vector3(rng() - 0.5, (rng() - 0.35) * 0.8, rng() - 0.5).multiplyScalar(1.1));
      const out = c.clone().sub(crownC); const rho = THREE.MathUtils.clamp(out.length() / crownR, 0, 1.4); out.normalize();
      const nrm = new THREE.Vector3(rng() - 0.5, rng() * 0.8 - 0.1, rng() - 0.5).normalize();
      if (nrm.dot(out) < 0) nrm.negate();
      const right = new THREE.Vector3().crossVectors(nrm, new THREE.Vector3(0, 1, 0)); if (right.lengthSq() < 1e-3) right.set(1, 0, 0); right.normalize();
      const up = new THREE.Vector3().crossVectors(right, nrm).normalize();
      const sz = cardS * (0.8 + rng() * 0.5);
      const shadeN = nrm.clone().multiplyScalar(0.35).addScaledVector(out, 0.7).add(new THREE.Vector3(0, 0.15, 0)).normalize();
      const ao = 0.28 + 0.8 * THREE.MathUtils.smoothstep(rho, 0.25, 1.0);
      const hue = 0.88 + rng() * 0.24;
      L.quad(c, right.multiplyScalar(sz), up.multiplyScalar(sz), shadeN, ao, [hue, hue * (0.95 + rng() * 0.1), hue * 0.95], [rng(), 0.25 + 0.4 * rng(), 1]);
    }
  }
  return { wood: W.geometry(), leaf: L.geometry(), height: H, crownR, crownBase: trunkH };
}

/** Distant (LOD2) silhouettes with baked top-light gradient. */
export function buildFarTree(kind: 'conifer' | 'broadleaf'): THREE.BufferGeometry {
  const B = new Builder();
  const ring = (y: number, r: number, n: number) => { const a: THREE.Vector3[] = []; for (let i = 0; i < n; i++) { const t = (i / n) * 6.283; a.push(new THREE.Vector3(Math.cos(t) * r, y, Math.sin(t) * r)); } return a; };
  const add = (rings: { y: number; r: number; ao: number }[], tip?: { y: number; ao: number }) => {
    const n = 8;
    for (let k = 0; k < rings.length - 1; k++) {
      const A = ring(rings[k].y, rings[k].r, n), C = ring(rings[k + 1].y, rings[k + 1].r, n);
      for (let i = 0; i < n; i++) {
        const j = (i + 1) % n; const nrm = (v: THREE.Vector3, up: number) => new THREE.Vector3(v.x, up * Math.hypot(v.x, v.z) + 0.2, v.z).normalize();
        const b = B.n; const up = kind === 'conifer' ? 0.7 : 0.3;
        B.vert(A[i], nrm(A[i], up), 0, 0, rings[k].ao, [1, 1, 1], [0, 0, 0]); B.vert(A[j], nrm(A[j], up), 0, 0, rings[k].ao, [1, 1, 1], [0, 0, 0]);
        B.vert(C[i], nrm(C[i], up), 0, 0, rings[k + 1].ao, [1, 1, 1], [0, 0, 0]); B.vert(C[j], nrm(C[j], up), 0, 0, rings[k + 1].ao, [1, 1, 1], [0, 0, 0]);
        B.idx.push(b, b + 2, b + 1, b + 1, b + 2, b + 3);
      }
    }
    if (tip) { const last = rings[rings.length - 1], A = ring(last.y, last.r, n); const t = B.n; B.vert(new THREE.Vector3(0, tip.y, 0), new THREE.Vector3(0, 1, 0), 0, 0, tip.ao, [1, 1, 1], [0, 0, 0]); for (const v of A) B.vert(v, new THREE.Vector3(0, 1, 0), 0, 0, last.ao, [1, 1, 1], [0, 0, 0]); for (let i = 0; i < n; i++) B.idx.push(t, t + 1 + ((i + 1) % n), t + 1 + i); }
  };
  if (kind === 'conifer') {
    add([{ y: 1.5, r: 3.8, ao: 0.35 }, { y: 7.5, r: 2.7, ao: 0.55 }], undefined);
    add([{ y: 6, r: 3.2, ao: 0.45 }, { y: 13, r: 1.9, ao: 0.75 }], undefined);
    add([{ y: 11.5, r: 2.2, ao: 0.6 }, { y: 20.5, r: 0.05, ao: 1 }], undefined);
  } else {
    add([{ y: 2.5, r: 3.2, ao: 0.32 }, { y: 6.5, r: 5.6, ao: 0.55 }, { y: 10, r: 4.6, ao: 0.9 }, { y: 13.2, r: 1.6, ao: 1 }], { y: 14.2, ao: 1 });
  }
  return B.geometry();
}
