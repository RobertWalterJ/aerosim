// Wrought-iron cemetery fence and gate sections, and fieldstone walls.
// Sections run along +X, centered on the origin, so they chain end to end
// at a spacing of `length` (posts sit at -length/2).
import * as THREE from 'three';
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3, type Mark,
  v3, hex, mix, mul, clamp01, smoothstep, tube, lathe, box, mat4, boxColliderOf, quad, withinBudget,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, chance, createNoise3D, subSeed, type Rnd } from './assetkit/AssetRng';
import { paintStone, roughStone, STONE_STYLES, type StoneStyle } from './assetkit/StoneWeathering';
import { ironMaterial, stoneMaterial } from './assetkit/AssetMaterials';

export const IRON_PALETTE = {
  paint: [hex(0x2f2d2a), hex(0x34312d), hex(0x3a3732)] as RGB[],
  chalky: hex(0x48443e),
  rust: [hex(0x6e3b20), hex(0x84482a), hex(0x5a3220), hex(0x96582e)] as RGB[],
  rustDark: hex(0x3e2a1e),
};

/** Black paint, chalking, chipped edges and rust that collects low and at joints. */
function paintIron(b: MeshBuilder, m: Mark, seed: number, rustiness: number, groundY: number, jointYs: number[]): void {
  const n3 = createNoise3D(subSeed(seed, 600));
  const paint = IRON_PALETTE.paint[Math.abs(seed) % 3]!;
  b.paint(m, (p, n) => {
    let c: RGB = mix(paint, IRON_PALETTE.chalky, smoothstep(0.3, 1, n.y) * 0.5); // chalking on upward faces
    let joint = 0;
    for (const y of jointYs) joint = Math.max(joint, 1 - Math.abs(p.y - y) / 0.06);
    const low = Math.pow(clamp01(1 - (p.y - groundY) / 0.35), 2);
    const r = n3(p.x * 7, p.y * 7, p.z * 7) * 0.6 + n3(p.x * 29, p.y * 29, p.z * 29) * 0.4;
    const rust = smoothstep(0.55, 0.7, r + rustiness * 0.6 + low * 0.5 + joint * 0.35);
    const chip = smoothstep(0.72, 0.78, n3(p.x * 61, p.y * 61, p.z * 61) + rustiness * 0.3);
    const rc = IRON_PALETTE.rust[Math.floor((n3(p.x * 3, p.y * 3, 5) * 0.5 + 0.5) * 4) % 4]!;
    c = mix(c, rc, Math.max(rust, chip) * 0.9);
    c = mix(c, IRON_PALETTE.rustDark, low * 0.4);
    return mul(c, 0.6 + 0.4 * smoothstep(0, 0.15, p.y - groundY));
  });
}

type Finial = 'spear' | 'fleur' | 'ball';
const FINIALS: Record<Finial, [number, number][]> = {
  spear: [[0.011, 0], [0.016, 0.012], [0.008, 0.03], [0.02, 0.045], [0.022, 0.055], [0.012, 0.09], [0.0005, 0.125]],
  fleur: [[0.011, 0], [0.018, 0.015], [0.01, 0.03], [0.03, 0.05], [0.028, 0.07], [0.01, 0.09], [0.016, 0.11], [0.0005, 0.14]],
  ball: [[0.011, 0], [0.016, 0.01], [0.009, 0.02], [0.022, 0.035], [0.025, 0.05], [0.02, 0.066], [0.0005, 0.075]],
};

function finial(b: MeshBuilder, lod: LOD, kind: Finial, at: Vec3, scale: number): Mark {
  let prof = FINIALS[kind];
  if (lod === 1) prof = [prof[0]!, prof[3]!, prof[prof.length - 1]!];
  const m = lathe(b, prof.map(([r, y]) => [r * scale, y * scale] as [number, number]), lod === 0 ? 6 : 4, { phase: Math.PI / 4 });
  b.transform(m, mat4(at));
  return m;
}

function bar(b: MeshBuilder, lod: LOD, from: Vec3, to: Vec3, r: number, bend = 0, rnd?: Rnd): Mark {
  if (lod === 2) {
    const d = v3().subVectors(to, from);
    const c = v3().addVectors(from, to).multiplyScalar(0.5);
    const up = d.clone().normalize();
    const side = v3(0, 0, 1).cross(up).normalize();
    return quad(b, c, side, up, r * 2.2, d.length(), [1, 1, 1], { u0: 0, v0: 0, u1: 1, v1: 1 });
  }
  const pts = [from.clone(), from.clone().lerp(to, 0.5), to.clone()];
  if (bend && rnd) pts[1]!.add(v3(gauss(rnd) * bend, 0, gauss(rnd) * bend));
  return tube(b, pts, { radial: lod === 0 ? 6 : 4, radius: () => r });
}

export interface FenceOptions {
  length?: number;
  height?: number;
  /** granite curb under the fence (default: seed-driven, 60%) */
  curb?: boolean;
  /** include the post at -length/2 (default true) */
  endPost?: boolean;
  finial?: Finial;
  /** 0..1, default seed-driven */
  rust?: number;
}

/** Wrought-iron cemetery fence section with finials, optional granite curb. */
export function ironFence(seed: number, lod: LOD, opts: FenceOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 4000);
  const L = opts.length ?? 2.4, H = opts.height ?? range(rnd, 1.1, 1.5);
  const curb = opts.curb ?? chance(rnd, 0.6);
  const endPost = opts.endPost ?? true;
  const fin: Finial = opts.finial ?? pick(rnd, ['spear', 'spear', 'fleur', 'ball'] as const);
  const rust = opts.rust ?? range(rnd, 0.1, 0.7);
  const alternate = chance(rnd, 0.5);
  const b = new MeshBuilder();
  const curbH = curb ? range(rnd, 0.18, 0.28) : 0;
  const iron = b.mark();
  const yBot = curbH + (curb ? 0.07 : 0.1), yTop = H - 0.1;
  const spacing = range(rnd, 0.1, 0.13);
  const n = Math.floor((L - 0.08) / spacing);
  const r = lod === 2 ? 0.012 : 0.009;
  // rails (flat bar)
  for (const y of [yBot, yTop]) box(b, v3(L, 0.04, 0.012), mat4(v3(0, y, 0)));
  // pickets
  for (let i = 0; i < n; i++) {
    const x = -L / 2 + 0.06 + (i + 0.5) * ((L - 0.06) / n);
    const tall = alternate && i % 2 === 0;
    const top = H - 0.02 + (tall ? 0.08 : 0);
    const lean = gauss(rnd) * 0.006;
    const base = v3(x, curbH + (curb ? 0 : 0.02), 0);
    const tipP = v3(x + lean, top, gauss(rnd) * 0.004);
    bar(b, lod, base, tipP, r, chance(rnd, 0.05) ? 0.02 : 0, rnd);
    if (lod < 2) finial(b, lod, fin, tipP, tall ? 1.15 : 1);
  }
  // post
  if (endPost) {
    const px = -L / 2;
    box(b, v3(0.08, H + 0.08 - curbH, 0.08), mat4(v3(px, curbH + (H + 0.08 - curbH) / 2, 0)));
    if (lod < 2) {
      box(b, v3(0.1, 0.03, 0.1), mat4(v3(px, H + 0.095, 0)));
      const cap = lathe(b, lod === 0
        ? [[0.02, 0], [0.025, 0.02], [0.045, 0.05], [0.05, 0.07], [0.04, 0.095], [0.02, 0.11], [0.0005, 0.12]]
        : [[0.02, 0], [0.05, 0.06], [0.0005, 0.12]], lod === 0 ? 8 : 4);
      b.transform(cap, mat4(v3(px, H + 0.11, 0)));
    } else {
      box(b, v3(0.1, 0.1, 0.1), mat4(v3(px, H + 0.13, 0)));
    }
  }
  paintIron(b, iron, seed, rust, curbH, [yBot, yTop]);
  b.boxUV(iron, 3);
  b.emitPolish = true;
  // curb
  if (curb) {
    const seg = lod === 0 ? [12, 2, 2] : lod === 1 ? [4, 1, 1] : [1, 1, 1];
    const g = new THREE.BoxGeometry(L, curbH + 0.08, 0.3, seg[0], seg[1], seg[2]);
    const cm = b.appendGeometry(g, mat4(v3(0, (curbH + 0.08) / 2 - 0.08, 0)));
    g.dispose();
    paintStone(b, cm, STONE_STYLES.greyGranite, seed, { height: curbH, age: range(rnd, 0.7, 1.3) });
    b.boxUV(cm, 2);
  }
  const g = b.build();
  return { geometry: g, material: ironMaterial(), collider: { type: 'box', center: [0, H / 2, 0], halfExtents: [L / 2, H / 2, 0.15] } };
}

export interface GateOptions {
  /** clear opening between piers. default 3.2 */
  width?: number;
  height?: number;
  piers?: boolean;
  /** opening angle of the right leaf in radians (default seed-driven: mostly closed) */
  ajar?: number;
}

/** Double-leaf arched cemetery gate with stone piers, scrolls and finials. */
export function ironGate(seed: number, lod: LOD, opts: GateOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 4100);
  const W = opts.width ?? range(rnd, 2.6, 3.6);
  const Hs = opts.height ?? range(rnd, 1.5, 1.8);
  const rise = range(rnd, 0.25, 0.5);
  const piers = opts.piers ?? true;
  const ajar = opts.ajar ?? (chance(rnd, 0.3) ? range(rnd, 0.15, 0.5) : 0);
  const rust = range(rnd, 0.15, 0.6);
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const iron = b.mark();
  const leafW = W / 2 - 0.02;
  const yB = 0.08, yM = 0.45;
  const archY = (x: number): number => Hs + rise * Math.sqrt(clamp01(1 - Math.pow(x / (W / 2), 2)));
  const plank = (size: Vec3, at: Vec3): void => {
    if (lod < 2) box(b, size, mat4(at));
    else quad(b, at, v3(1, 0, 0), v3(0, 1, 0), size.x, size.y, [1, 1, 1], { u0: 0, v0: 0, u1: 1, v1: 1 });
  };
  const leaf = (side: 1 | -1): void => {
    const lm = b.mark();
    const hx = side * (W / 2); // hinge
    const inner = hx - side * leafW;
    // stiles
    for (const x of [hx - side * 0.02, inner]) {
      const h = archY(x);
      plank(v3(0.04, h - yB + 0.04, 0.04), v3(x, (h + yB) / 2, 0));
    }
    plank(v3(leafW, 0.04, 0.03), v3((hx + inner) / 2, yB, 0));
    plank(v3(leafW, 0.03, 0.025), v3((hx + inner) / 2, yM, 0));
    // arched top rail
    const segs = lod === 0 ? 10 : lod === 1 ? 5 : 3;
    const arc: Vec3[] = [];
    for (let i = 0; i <= segs; i++) { const x = hx + (inner - hx) * (i / segs); arc.push(v3(x, archY(x), 0)); }
    if (lod === 2) {
      for (let i = 0; i < segs; i++) {
        const a = arc[i]!, c = arc[i + 1]!;
        quad(b, a.clone().lerp(c, 0.5), v3(0, 1, 0), v3().subVectors(c, a).normalize(), 0.04, a.distanceTo(c), [1, 1, 1], { u0: 0, v0: 0, u1: 1, v1: 1 });
      }
    } else tube(b, arc, { radial: 4, radius: () => 0.02 });
    // pickets
    const n = Math.floor(leafW / (lod === 2 ? 0.2 : lod === 1 ? 0.14 : 0.11));
    for (let i = 1; i < n; i++) {
      const x = hx + (inner - hx) * (i / n);
      const top = archY(x) + 0.12;
      withinBudget(b, budget, () => {
        bar(b, lod, v3(x, yB, 0), v3(x, top, 0), 0.009);
        if (lod < 2) finial(b, lod, 'spear', v3(x, top, 0), 1);
      });
    }
    // rings between bottom and middle rail, scrolls at the hinge
    if (lod === 0) {
      const rings = Math.floor(leafW / 0.22);
      for (let i = 0; i < rings; i++) {
        const cx = hx + (inner - hx) * ((i + 0.5) / rings), cy = (yB + yM) / 2, rr = Math.min(0.1, (yM - yB) / 2 - 0.02);
        const pts: Vec3[] = [];
        for (let k = 0; k <= 12; k++) pts.push(v3(cx + Math.cos((k / 12) * Math.PI * 2) * rr, cy + Math.sin((k / 12) * Math.PI * 2) * rr, 0));
        withinBudget(b, budget, () => { tube(b, pts, { radial: 4, radius: () => 0.007 }); });
      }
      const sp: Vec3[] = [];
      for (let k = 0; k <= 16; k++) {
        const t = k / 16, a = t * Math.PI * 3, rr = 0.16 * (1 - t * 0.8);
        sp.push(v3(hx - side * (0.05 + rr * (1 - Math.cos(a)) * 0.5), Hs - 0.05 - rr * Math.sin(a) * 0.6, 0));
      }
      withinBudget(b, budget, () => { tube(b, sp, { radial: 4, radius: () => 0.008 }); });
    }
    if (side === 1 && ajar) b.transform(lm, new THREE.Matrix4().makeTranslation(hx, 0, 0).multiply(new THREE.Matrix4().makeRotationY(ajar)).multiply(new THREE.Matrix4().makeTranslation(-hx, 0, 0)));
  };
  leaf(-1); leaf(1);
  paintIron(b, iron, seed, rust, 0, [yB, yM, Hs]);
  b.boxUV(iron, 3);
  b.emitPolish = true;
  if (piers) {
    const style = chance(rnd, 0.6) ? STONE_STYLES.greyGranite : STONE_STYLES.sandstone;
    const pw = range(rnd, 0.45, 0.6), ph = Hs + rise + range(rnd, 0.2, 0.5);
    for (const side of [-1, 1]) {
      const x = side * (W / 2 + pw / 2);
      const pm = b.mark();
      const seg = lod === 0 ? [2, 6, 2] : [1, 1, 1];
      const g1 = new THREE.BoxGeometry(pw, ph, pw, seg[0], seg[1], seg[2]);
      b.appendGeometry(g1, mat4(v3(x, ph / 2, 0)));
      g1.dispose();
      if (lod < 2) {
        box(b, v3(pw + 0.1, 0.25, pw + 0.1), mat4(v3(x, 0.125, 0)));
        box(b, v3(pw + 0.08, 0.08, pw + 0.08), mat4(v3(x, ph + 0.04, 0)));
      }
      const cap = lathe(b, [[(pw / 2) * 1.35, 0], [0.0005, pw * 0.45]], 4, { phase: Math.PI / 4 });
      b.transform(cap, mat4(v3(x, ph + 0.08, 0)));
      if (lod < 2) {
        const ball = lathe(b, lod === 0 ? [[0.05, 0], [0.08, 0.03], [0.12, 0.1], [0.12, 0.16], [0.08, 0.23], [0.0005, 0.26]] : [[0.06, 0], [0.12, 0.12], [0.0005, 0.25]], lod === 0 ? 8 : 4);
        b.transform(ball, mat4(v3(x, ph + 0.08 + pw * 0.45 * 0.6, 0)));
      }
      paintStone(b, pm, style, seed + side, { height: ph + 0.4 });
      b.boxUV(pm, 2);
    }
  }
  const g = b.build();
  return { geometry: g, material: ironMaterial(), collider: boxColliderOf(g) };
}

// ---------------------------------------------------------------- stone wall

export interface StoneWallOptions {
  length?: number;
  height?: number;
  width?: number;
  coping?: 'flat' | 'upright';
  mortar?: boolean;
  style?: StoneStyle;
}

/** Mortared fieldstone wall segment, running along X. */
export function stoneWall(seed: number, lod: LOD, opts: StoneWallOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 4200);
  const L = opts.length ?? 3, H = opts.height ?? range(rnd, 0.8, 1.2), W = opts.width ?? range(rnd, 0.45, 0.6);
  const coping = opts.coping ?? (chance(rnd, 0.5) ? 'upright' : 'flat');
  const mortar = opts.mortar ?? true;
  const style = opts.style ?? STONE_STYLES.fieldstone;
  const b = new MeshBuilder();
  const budget = TRI_BUDGET[lod] - 4;
  const copeH = coping === 'upright' ? range(rnd, 0.18, 0.28) : range(rnd, 0.08, 0.12);
  const bodyH = H - copeH;
  const mortarCol = mortar ? hex(0x8c8678) : hex(0x2e2a24);

  if (lod === 2) {
    const g = new THREE.BoxGeometry(L, H, W, 6, 3, 1);
    const m = b.appendGeometry(g, mat4(v3(0, H / 2, 0)));
    g.dispose();
    b.paint(m, (p) => mul(mix(pick(rnd, style.base), mortarCol, 0.25), 0.55 + 0.45 * smoothstep(0, 0.2, p.y)));
    b.boxUV(m, 2);
    b.emitPolish = true;
    const gg = b.build();
    return { geometry: gg, material: stoneMaterial(), collider: boxColliderOf(gg) };
  }

  // mortar core (recessed)
  {
    const seg = lod === 0 ? [6, 3, 1] : [2, 1, 1];
    const g = new THREE.BoxGeometry(L, bodyH, W - 0.08, seg[0], seg[1], seg[2]);
    const m = b.appendGeometry(g, mat4(v3(0, bodyH / 2, 0)));
    g.dispose();
    b.paint(m, (p) => mul(mortarCol, 0.5 + 0.3 * smoothstep(0, bodyH, p.y)));
    b.boxUV(m, 2);
  }
  const sizeMul = lod === 0 ? 1 : 1.45;
  interface S { c: Vec3; s: Vec3; q: THREE.Quaternion; }
  const stones: S[] = [];
  for (const face of [-1, 1]) {
    let y = 0;
    while (y < bodyH - 0.06) {
      const ch = Math.min(bodyH - y, range(rnd, 0.14, 0.28) * sizeMul);
      let x = -L / 2 - range(rnd, 0, 0.2);
      while (x < L / 2) {
        let sl = range(rnd, 0.22, 0.5) * sizeMul;
        const x0 = Math.max(x, -L / 2);
        const x1 = Math.min(x + sl, L / 2);
        sl = x1 - x0;
        if (sl > 0.08) {
          const depth = range(rnd, 0.16, 0.24);
          stones.push({
            c: v3((x0 + x1) / 2, y + ch / 2, face * (W / 2 - depth / 2 + range(rnd, 0.005, 0.03))),
            s: v3(sl - 0.025, ch - 0.025, depth),
            q: new THREE.Quaternion().setFromEuler(new THREE.Euler(gauss(rnd) * 0.06, gauss(rnd) * 0.05, gauss(rnd) * 0.08)),
          });
        }
        x += sl + 0.012;
      }
      y += ch + 0.012;
    }
  }
  // coping
  let x = -L / 2;
  while (x < L / 2 - 0.05) {
    const sl = coping === 'upright' ? range(rnd, 0.08, 0.14) : range(rnd, 0.3, 0.6);
    const x1 = Math.min(L / 2, x + sl);
    const hh = coping === 'upright' ? copeH * range(rnd, 0.8, 1.1) : copeH;
    stones.push({
      c: v3((x + x1) / 2, bodyH + hh / 2, gauss(rnd) * 0.01),
      s: v3(x1 - x - 0.01, hh, W + (coping === 'flat' ? 0.05 : -0.02)),
      q: new THREE.Quaternion().setFromEuler(new THREE.Euler(0, gauss(rnd) * 0.03, coping === 'upright' ? gauss(rnd) * 0.12 : gauss(rnd) * 0.02)),
    });
    x = x1 + 0.005;
  }
  const subdiv = lod === 0 && stones.length * 48 < budget - b.triangleCount ? 2 : 1;
  for (const st of stones) {
    const ok = withinBudget(b, budget, () => {
      const m = roughStone(b, subdiv, st.c, st.s, st.q, irange(rnd, 0, 1e6), range(rnd, 0.55, 0.8), 0.1);
      const base = mul(pick(rnd, style.base), range(rnd, 0.85, 1.12));
      paintStone(b, m, style, irange(rnd, 0, 1e6), { height: H, baseColor: base });
      b.boxUV(m, 2);
    });
    if (!ok) break;
  }
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: { type: 'box', center: [0, H / 2, 0], halfExtents: [L / 2, H / 2, W / 2] } };
}

