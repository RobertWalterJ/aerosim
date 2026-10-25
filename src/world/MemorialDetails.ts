// Granite and marble memorials: headstones (8 kinds incl. weeping-willow
// relief), draped urns, crosses, angels, kerbed grave plots, plus bouquets
// and small grave flags. Stone assets carry aPolish (see materials.withPolish).
// Fronts face +Z. Bouquets and flags use the foliage material and aSway.
import * as THREE from 'three';
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, type Vec3, type Mark,
  v3, UP, hex, mix, tint, mul, smoothstep, clamp01, lathe, blob, tube, ribbon, card, box, mat4, boxColliderOf, withinBudget,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, pick, chance, createNoise3D, subSeed, type Rnd } from './assetkit/AssetRng';
import { paintStone, roughStone, STONE_STYLES, type StoneStyle, type StoneStyleName } from './assetkit/StoneWeathering';
import { stoneMaterial, foliageMaterial } from './assetkit/AssetMaterials';
import { Cell, cellUV, solidUV } from './textures/AssetTextures';

const polishFront = (n: Vec3): number => smoothstep(0.85, 0.98, Math.abs(n.z));
const polishTop = (n: Vec3): number => smoothstep(0.85, 0.98, n.y);

function flat(g: THREE.BufferGeometry): THREE.BufferGeometry {
  const f = g.index ? g.toNonIndexed() : g;
  f.computeVertexNormals();
  return f;
}
function addGeo(b: MeshBuilder, g: THREE.BufferGeometry, m4: THREE.Matrix4, makeFlat = false): Mark {
  const src = makeFlat ? flat(g) : g;
  const m = b.appendGeometry(src, m4);
  if (src !== g) src.dispose();
  g.dispose();
  return m;
}
function slab(b: MeshBuilder, size: Vec3, at: Vec3, rot?: THREE.Euler): Mark {
  return box(b, size, mat4(at, rot));
}

function pickStyle(rnd: Rnd, name?: StoneStyleName): StoneStyle {
  if (name) return STONE_STYLES[name];
  return pick(rnd, [STONE_STYLES.whiteMarble, STONE_STYLES.whiteMarble, STONE_STYLES.greyGranite, STONE_STYLES.greyGranite, STONE_STYLES.pinkGranite, STONE_STYLES.darkGranite, STONE_STYLES.sandstone]);
}

function finishStone(b: MeshBuilder, m: Mark, style: StoneStyle, seed: number, height: number, age: number, polish: (n: Vec3, p: Vec3) => number = polishFront): void {
  paintStone(b, m, style, seed, { height, age, polishFaces: polish });
  b.boxUV(m, 2);
}

// ---------------------------------------------------------------- headstones

export type HeadstoneKind = 'roundTop' | 'gothic' | 'shouldered' | 'pediment' | 'willow' | 'obelisk' | 'book' | 'lawnMarker';
export const HEADSTONE_KINDS: readonly HeadstoneKind[] = ['roundTop', 'gothic', 'shouldered', 'pediment', 'willow', 'obelisk', 'book', 'lawnMarker'];

function tabletShape(kind: HeadstoneKind, w: number, h: number): THREE.Shape {
  const s = new THREE.Shape();
  const hw = w / 2;
  s.moveTo(-hw, 0);
  s.lineTo(hw, 0);
  switch (kind) {
    case 'gothic': {
      const h0 = h - w * 0.75;
      s.lineTo(hw, h0);
      s.quadraticCurveTo(hw, h0 + (h - h0) * 0.55, 0, h);
      s.quadraticCurveTo(-hw, h0 + (h - h0) * 0.55, -hw, h0);
      break;
    }
    case 'shouldered': {
      const sh = w * 0.18, r = hw - sh;
      s.lineTo(hw, h - r - sh * 0.6);
      s.lineTo(hw - sh, h - r - sh * 0.6);
      s.lineTo(hw - sh, h - r);
      s.absarc(0, h - r, r, 0, Math.PI, false);
      s.lineTo(-hw + sh, h - r - sh * 0.6);
      s.lineTo(-hw, h - r - sh * 0.6);
      break;
    }
    case 'pediment': {
      const h0 = h - w * 0.28;
      s.lineTo(hw, h0);
      s.lineTo(hw + 0.02, h0);
      s.lineTo(0, h);
      s.lineTo(-hw - 0.02, h0);
      s.lineTo(-hw, h0);
      break;
    }
    default: {
      // roundTop, willow (segmental arch)
      const rise = w * 0.32;
      const R = (hw * hw + rise * rise) / (2 * rise);
      const a0 = Math.asin(hw / R);
      s.lineTo(hw, h - rise);
      s.absarc(0, h - R, R, Math.PI / 2 - a0, Math.PI / 2 + a0, false);
    }
  }
  s.lineTo(-hw, 0);
  return s;
}

/** Inscription: rows of dark (or pale on dark granite) letter marks just proud of the face. */
function inscription(b: MeshBuilder, rnd: Rnd, z: number, w: number, y0: number, y1: number, col: RGB): void {
  const rows = irange(rnd, 3, 6);
  const solid = solidUV();
  for (let r = 0; r < rows; r++) {
    const y = y1 - (r + 0.5) * ((y1 - y0) / rows);
    const lh = r === 0 ? 0.03 : range(rnd, 0.016, 0.024);
    const rowW = w * (r === 0 ? range(rnd, 0.5, 0.7) : range(rnd, 0.35, 0.75));
    let x = -rowW / 2;
    while (x < rowW / 2) {
      const lw = range(rnd, 0.008, 0.016) * (r === 0 ? 1.4 : 1);
      if (!chance(rnd, 0.12)) card(b, v3(x + lw / 2, y, z), v3(1, 0, 0), v3(0, 1, 0), lw, lh, { uv: solid, color: col, sway: [0, 0], pivot: 'center', normal: v3(0, 0, 1) });
      x += lw + range(rnd, 0.004, 0.009);
    }
  }
  b.emitPolish = true;
}

/** Weeping willow over an urn, in low relief on the face plane. */
function willowRelief(b: MeshBuilder, rnd: Rnd, lod: LOD, z: number, w: number, y0: number, y1: number): Mark {
  const m = b.mark();
  const solid = solidUV();
  const Z = v3(0, 0, 1);
  const H = y1 - y0;
  // urn silhouette (extruded)
  const u = new THREE.Shape();
  const prof: [number, number][] = [[0.18, 0], [0.12, 0.05], [0.1, 0.1], [0.3, 0.25], [0.32, 0.4], [0.22, 0.55], [0.16, 0.6], [0.2, 0.65], [0.0, 0.7]];
  const us = H * 0.38;
  u.moveTo(0, y0);
  for (const [r, y] of prof) u.lineTo(r * us, y0 + y * us);
  for (let i = prof.length - 1; i >= 0; i--) u.lineTo(-prof[i]![0] * us, y0 + prof[i]![1] * us);
  const ug = new THREE.ExtrudeGeometry(u, { depth: 0.006, bevelEnabled: false, curveSegments: 2 });
  addGeo(b, ug, mat4(v3(w * 0.12, 0, z)));
  // trunk + drooping fronds
  const side = (_t: number, tan: Vec3): Vec3 => v3().crossVectors(tan, Z);
  const rib = (pts: Vec3[], w0: number): void => {
    ribbon(b, pts, { width: (t) => w0 * (1 - t * 0.7), side, color: () => [1, 1, 1], sway: () => 0, uv: solid, normalBias: Z, normalBiasAmt: 1 });
  };
  const tx = -w * 0.18;
  const trunk = [v3(tx, y0, z + 0.004), v3(tx + 0.01, y0 + H * 0.35, z + 0.004), v3(tx - 0.005, y0 + H * 0.7, z + 0.004), v3(tx + 0.02, y0 + H * 0.88, z + 0.004)];
  rib(trunk, 0.03);
  const fronds = lod === 0 ? irange(rnd, 14, 20) : 7;
  for (let i = 0; i < fronds; i++) {
    const start = trunk[3]!.clone().add(v3(gauss(rnd) * 0.02, -range(rnd, 0, H * 0.25), 0.0005));
    const dir = (i % 2 ? 1 : -1) * range(rnd, 0.3, 1);
    const reach = range(rnd, 0.06, w * 0.35);
    const pts: Vec3[] = [];
    for (let k = 0; k <= 5; k++) {
      const t = k / 5;
      pts.push(v3(start.x + dir * reach * Math.sin(t * Math.PI * 0.5), start.y + H * 0.06 * Math.sin(t * Math.PI) - t * t * H * range(rnd, 0.35, 0.6), z + 0.005));
    }
    rib(pts, 0.008);
  }
  return m;
}

function buildHeadstone(b: MeshBuilder, rnd: Rnd, seed: number, lod: LOD, kind: HeadstoneKind, style: StoneStyle): { h: number; w: number } {
  const age = range(rnd, 0.6, 1.4);
  const bevel = lod === 0;
  const curve = lod === 0 ? 10 : lod === 1 ? 5 : 2;
  const darkFace = style === STONE_STYLES.darkGranite;
  const m = b.mark();
  let H = 0, W = 0;
  if (kind === 'obelisk') {
    const s = range(rnd, 0.8, 1.3);
    const pw = 0.7 * s, dh = 0.5 * s, shaftH = range(rnd, 1.2, 2.0) * s;
    slab(b, v3(pw, 0.2 * s, pw), v3(0, 0.1 * s, 0));
    slab(b, v3(pw * 0.72, dh, pw * 0.72), v3(0, 0.2 * s + dh / 2, 0));
    slab(b, v3(pw * 0.82, 0.08 * s, pw * 0.82), v3(0, 0.2 * s + dh + 0.04 * s, 0));
    const y0 = 0.28 * s + dh;
    const r0 = (pw * 0.5) * Math.SQRT1_2, r1 = r0 * 0.62;
    addGeo(b, new THREE.CylinderGeometry(r1, r0, shaftH, 4, 1, true), mat4(v3(0, y0 + shaftH / 2, 0), new THREE.Euler(0, Math.PI / 4, 0)), true);
    addGeo(b, new THREE.ConeGeometry(r1, r1 * 1.6, 4, 1, true), mat4(v3(0, y0 + shaftH + r1 * 0.8, 0), new THREE.Euler(0, Math.PI / 4, 0)), true);
    H = y0 + shaftH + r1 * 1.6; W = pw;
    finishStone(b, m, style, seed, H, age);
    if (lod === 0) inscription(b, rnd, pw * 0.36 + 0.0015, pw * 0.6, 0.25 * s, 0.2 * s + dh - 0.05, mul(style.base[0]!, darkFace ? 1.8 : 0.45));
    return { h: H, w: W };
  }
  if (kind === 'lawnMarker') {
    W = range(rnd, 0.45, 0.7);
    const sm = roughStone(b, lod === 0 ? 3 : 1, v3(0, 0.04, 0), v3(W, 0.16, W * 0.55), new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.15, 0, 0)), seed, 0.92, 0.01);
    finishStone(b, sm, style, seed, 0.15, age, polishTop);
    if (lod === 0) {
      const im = b.mark();
      inscription(b, rnd, 0, W * 0.7, -0.08, 0.08, mul(style.base[0]!, darkFace ? 1.8 : 0.45));
      b.transform(im, new THREE.Matrix4().makeRotationX(-Math.PI / 2 - 0.15).premultiply(new THREE.Matrix4().makeTranslation(0, 0.122, 0.0)));
    }
    return { h: 0.13, w: W };
  }
  if (kind === 'book') {
    const s = range(rnd, 0.8, 1.1);
    slab(b, v3(0.7 * s, 0.2 * s, 0.45 * s), v3(0, 0.1 * s, 0));
    slab(b, v3(0.55 * s, 0.25 * s, 0.32 * s), v3(0, 0.325 * s, 0), new THREE.Euler(-0.3, 0, 0));
    for (const side of [-1, 1]) {
      roughStone(b, lod === 0 ? 2 : 1, v3(side * 0.14 * s, 0.5 * s, 0.02), v3(0.27 * s, 0.05 * s, 0.36 * s), new THREE.Quaternion().setFromEuler(new THREE.Euler(-0.3, 0, side * -0.12)), seed + side, 0.9, 0.01);
    }
    H = 0.56 * s; W = 0.7 * s;
    finishStone(b, m, style, seed, H, age, polishTop);
    return { h: H, w: W };
  }
  // tablets on a base
  const w = range(rnd, 0.45, 0.85), h = range(rnd, 0.6, 1.25) * (kind === 'gothic' ? 1.1 : 1);
  const t = range(rnd, 0.07, 0.14);
  const hasBase = chance(rnd, 0.55) || style !== STONE_STYLES.whiteMarble;
  const baseH = hasBase ? range(rnd, 0.14, 0.22) : 0;
  const bt = bevel ? 0.006 : 0;
  if (hasBase) slab(b, v3(w + range(rnd, 0.08, 0.2), baseH, t + range(rnd, 0.1, 0.18)), v3(0, baseH / 2, 0));
  const shape = tabletShape(kind, w, h);
  const eg = new THREE.ExtrudeGeometry(shape, { depth: t, bevelEnabled: bevel, bevelThickness: bt, bevelSize: bt, bevelSegments: 1, curveSegments: curve });
  addGeo(b, eg, mat4(v3(0, baseH - 0.03, -t / 2)));
  const front = t / 2 + bt;
  if (kind === 'willow' && lod < 2) willowRelief(b, rnd, lod, front, w, baseH + h * 0.22, baseH + h * 0.85);
  H = baseH + h; W = w;
  finishStone(b, m, style, seed, H, age);
  if (lod === 0) {
    const col = mul(style.base[0]!, darkFace ? 1.8 : 0.45);
    if (kind === 'willow') inscription(b, rnd, front + 0.0015, w * 0.7, baseH + 0.03, baseH + h * 0.2, col);
    else inscription(b, rnd, front + 0.0015, w * 0.75, baseH + h * 0.15, baseH + h * 0.72, col);
  }
  return { h: H, w: W };
}

export interface HeadstoneOptions { kind?: HeadstoneKind; style?: StoneStyleName; }

/** Upright memorial; kind defaults to seed mod 8 (all eight kinds). */
export function headstone(seed: number, lod: LOD, opts: HeadstoneOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 6000);
  const kind = opts.kind ?? HEADSTONE_KINDS[Math.abs(seed) % HEADSTONE_KINDS.length]!;
  const style = pickStyle(rnd, opts.style);
  const b = new MeshBuilder();
  buildHeadstone(b, rnd, seed, lod, kind, style);
  // old stones lean and settle
  if (kind !== 'lawnMarker') {
    const lean = new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(gauss(rnd) * 0.04, 0, gauss(rnd) * 0.025));
    b.transform({ v: 0, i: 0 }, lean.premultiply(new THREE.Matrix4().makeTranslation(0, -range(rnd, 0, 0.03), 0)));
  }
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
}

/** Headstone with a weeping-willow-and-urn relief (Victorian motif marker). */
export function willowMarker(seed: number, lod: LOD): AssetResult {
  return headstone(seed, lod, { kind: 'willow', style: chance(makeRnd(seed, 6001), 0.6) ? 'whiteMarble' : 'greyGranite' });
}

// ---------------------------------------------------------------- urn

const URN_PROFILE: [number, number][] = [
  [0.09, 0], [0.1, 0.03], [0.06, 0.06], [0.045, 0.1], [0.07, 0.13], [0.13, 0.2], [0.16, 0.28], [0.165, 0.33],
  [0.15, 0.4], [0.11, 0.45], [0.08, 0.48], [0.09, 0.5], [0.09, 0.52], [0.06, 0.54], [0.04, 0.56], [0.03, 0.6], [0.0005, 0.62],
];

/** Draped urn on a pedestal (plinth, die, cornice). */
export function urnMonument(seed: number, lod: LOD): AssetResult {
  const rnd = makeRnd(seed, 6100);
  const style = pickStyle(rnd);
  const b = new MeshBuilder();
  const s = range(rnd, 0.85, 1.25);
  const m = b.mark();
  const pw = 0.62 * s, dieH = range(rnd, 0.5, 0.75) * s;
  slab(b, v3(pw, 0.18 * s, pw), v3(0, 0.09 * s, 0));
  slab(b, v3(pw * 0.8, 0.08 * s, pw * 0.8), v3(0, 0.22 * s, 0));
  slab(b, v3(pw * 0.66, dieH, pw * 0.66), v3(0, 0.26 * s + dieH / 2, 0));
  slab(b, v3(pw * 0.8, 0.07 * s, pw * 0.8), v3(0, 0.26 * s + dieH + 0.035 * s, 0));
  const y0 = 0.33 * s + dieH;
  const us = range(rnd, 1.6, 2.2) * s;
  const prof = lod === 2 ? [URN_PROFILE[0]!, URN_PROFILE[4]!, URN_PROFILE[7]!, URN_PROFILE[10]!, URN_PROFILE[16]!] : lod === 1 ? URN_PROFILE.filter((_, i) => i % 2 === 0 || i === 16) : URN_PROFILE;
  const a0 = rnd() * Math.PI * 2, span = range(rnd, 2.2, 3.6);
  const drape = chance(rnd, 0.75) && lod < 2;
  const um = lathe(b, prof.map(([r, y]) => [r * us, y * us] as [number, number]), lod === 0 ? 20 : lod === 1 ? 10 : 6, {
    radialDisplace: drape ? (a, y) => {
      const yn = y / us;
      const da = ((a - a0) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2);
      if (da > span) return 0;
      const edge = 0.47 - 0.12 * Math.pow(Math.abs(Math.sin((da / span) * Math.PI * 2.5)), 0.7) - 0.08 * Math.sin((da / span) * Math.PI);
      if (yn < edge || yn > 0.5) return 0;
      return us * (0.01 + 0.006 * Math.sin(a * 16)) * smoothstep(edge, edge + 0.02, yn);
    } : undefined,
  });
  b.transform(um, mat4(v3(0, y0, 0)));
  const H = y0 + 0.62 * us;
  finishStone(b, m, style, seed, H, range(rnd, 0.7, 1.3), (n) => polishFront(n) * 0.5);
  if (lod === 0) inscription(b, rnd, pw * 0.33 + 0.0015, pw * 0.5, 0.3 * s, 0.26 * s + dieH - 0.06, mul(style.base[0]!, style === STONE_STYLES.darkGranite ? 1.8 : 0.45));
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
}

// ---------------------------------------------------------------- cross

export type CrossKind = 'latin' | 'celtic' | 'rustic';
export const CROSS_KINDS: readonly CrossKind[] = ['latin', 'celtic', 'rustic'];

/** Cross on stepped Calvary base, Celtic ring cross, or rustic log cross on a cairn. */
export function crossMonument(seed: number, lod: LOD, opts: { kind?: CrossKind } = {}): AssetResult {
  const rnd = makeRnd(seed, 6200);
  const kind = opts.kind ?? CROSS_KINDS[Math.abs(seed) % 3]!;
  const b = new MeshBuilder();
  const s = range(rnd, 0.8, 1.3);
  const budget = TRI_BUDGET[lod] - 4;
  if (kind === 'rustic') {
    const style = STONE_STYLES.greyGranite;
    const cm = b.mark();
    const nStones = lod === 2 ? 2 : irange(rnd, 4, 7);
    for (let i = 0; i < nStones; i++) {
      const a = (i / nStones) * Math.PI * 2;
      const r = i === 0 ? 0 : 0.18 * s;
      roughStone(b, lod === 0 ? 2 : 1, v3(Math.cos(a) * r, (i === 0 ? 0.2 : 0.1) * s, Math.sin(a) * r), v3(0.35, i === 0 ? 0.4 : 0.22, 0.32).multiplyScalar(s * range(rnd, 0.8, 1.2)), new THREE.Quaternion().setFromEuler(new THREE.Euler(gauss(rnd) * 0.2, rnd() * 6, gauss(rnd) * 0.2)), seed + i, 0.3, 0.18);
    }
    finishStone(b, cm, STONE_STYLES.fieldstone, seed, 0.5 * s, 1.2, () => 0);
    const lm = b.mark();
    const knots = (t: number, a: number): number => 1 + 0.08 * Math.sin(a * 3 + t * 17) * Math.sin(t * 9);
    const H = range(rnd, 1.2, 1.6) * s;
    const radial = lod === 0 ? 8 : lod === 1 ? 5 : 4;
    tube(b, [v3(0, 0.3 * s, 0), v3(0.01, 0.3 * s + H * 0.5, 0), v3(-0.01, 0.3 * s + H, 0)], { radial, radius: (t) => 0.07 * s * (1 - t * 0.2), radialNoise: knots, capEnd: true });
    const armY = 0.3 * s + H * 0.72;
    tube(b, [v3(-0.32 * s, armY, 0), v3(0, armY + 0.01, 0), v3(0.32 * s, armY - 0.01, 0)], { radial, radius: () => 0.055 * s, radialNoise: knots, capEnd: true });
    if (lod === 0) for (let i = 0; i < 3; i++) {
      withinBudget(b, budget, () => {
        const y = 0.3 * s + range(rnd, 0.2, 0.6) * H, side = chance(rnd, 0.5) ? 1 : -1;
        tube(b, [v3(0, y, 0), v3(side * 0.1 * s, y + 0.04, gauss(rnd) * 0.03)], { radial: 5, radius: (t) => 0.03 * s * (1 - t * 0.3), capEnd: true });
      });
    }
    finishStone(b, lm, mix3Style(style, hex(0x7e7668)), seed + 9, H, 1.1, () => 0);
    const g = b.build();
    return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
  }
  const style = pickStyle(rnd);
  const m = b.mark();
  let y = 0;
  const steps = kind === 'latin' ? (lod === 2 ? 1 : irange(rnd, 2, 3)) : 1;
  for (let i = 0; i < steps; i++) {
    const w = (0.85 - i * 0.2) * s, h = 0.16 * s;
    slab(b, v3(w, h, w * (kind === 'celtic' ? 0.6 : 1)), v3(0, y + h / 2, 0));
    y += h;
  }
  if (kind === 'celtic') { slab(b, v3(0.38 * s, 0.35 * s, 0.24 * s), v3(0, y + 0.175 * s, 0)); y += 0.35 * s; }
  const H = range(rnd, 1.1, 1.6) * s, sw = 0.12 * s, sd = 0.1 * s;
  addGeo(b, new THREE.BoxGeometry(sw, H, sd, 1, lod === 0 ? 4 : 1, 1), mat4(v3(0, y + H / 2, 0)));
  const armY = y + H * 0.72, armW = H * 0.45;
  addGeo(b, new THREE.BoxGeometry(armW, sw, sd, lod === 0 ? 3 : 1, 1, 1), mat4(v3(0, armY, 0)));
  if (kind === 'celtic' && lod < 2) {
    const rr = armW * 0.3, pts: Vec3[] = [];
    const seg = lod === 0 ? 16 : 8;
    for (let k = 0; k <= seg; k++) pts.push(v3(Math.cos((k / seg) * Math.PI * 2) * rr, armY + Math.sin((k / seg) * Math.PI * 2) * rr, 0));
    tube(b, pts, { radial: 4, radius: () => sd * 0.4 });
  }
  finishStone(b, m, style, seed, y + H, range(rnd, 0.7, 1.3));
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
}
function mix3Style(s: StoneStyle, c: RGB): StoneStyle {
  return { ...s, base: [c, mul(c, 0.9), mul(c, 1.08)], lichen: 0.6, moss: 0.4 };
}

// ---------------------------------------------------------------- angel

export type AngelPose = 'praying' | 'pointing' | 'wreath';

/** Robed angel with folded wings on a plinth (marble or granite). */
export function angelMonument(seed: number, lod: LOD, opts: { pose?: AngelPose } = {}): AssetResult {
  const rnd = makeRnd(seed, 6300);
  const pose = opts.pose ?? pick(rnd, ['praying', 'pointing', 'wreath'] as const);
  const style = chance(rnd, 0.7) ? STONE_STYLES.whiteMarble : STONE_STYLES.greyGranite;
  const b = new MeshBuilder();
  const s = range(rnd, 0.9, 1.15);
  const m = b.mark();
  const ph = range(rnd, 0.6, 0.95) * s;
  slab(b, v3(0.8 * s, 0.16 * s, 0.7 * s), v3(0, 0.08 * s, 0));
  slab(b, v3(0.6 * s, ph, 0.5 * s), v3(0, 0.16 * s + ph / 2, 0));
  slab(b, v3(0.68 * s, 0.06 * s, 0.58 * s), v3(0, 0.16 * s + ph + 0.03 * s, 0));
  const y0 = 0.22 * s + ph;
  const fig = b.mark();
  const robe: [number, number][] = [[0.23, 0], [0.21, 0.08], [0.18, 0.35], [0.15, 0.6], [0.13, 0.78], [0.135, 0.92], [0.155, 1.02], [0.12, 1.08], [0.05, 1.12], [0.048, 1.15]];
  const rp = lod === 2 ? [robe[0]!, robe[3]!, robe[6]!, robe[9]!] : robe;
  const ph0 = rnd() * 6;
  lathe(b, rp, lod === 0 ? 16 : lod === 1 ? 8 : 5, { radialDisplace: lod === 0 ? (a, y) => 0.014 * Math.sin(a * 9 + ph0 + y * 2) * clamp01(1 - y / 0.95) : undefined });
  b.transform(fig, new THREE.Matrix4().makeScale(1, 1, 0.72));
  blob(b, lod === 0 ? 3 : 1, v3(0, 1.24, 0.01), v3(0.08, 0.095, 0.085), undefined, 0);
  if (lod < 2) {
    const arm = (pts: Vec3[]): void => { tube(b, pts, { radial: lod === 0 ? 6 : 4, radius: (t) => 0.036 * (1 - t * 0.25), capEnd: true }); };
    for (const sd of [-1, 1]) {
      const sh = v3(sd * 0.14, 1.03, 0);
      if (pose === 'praying') arm([sh, v3(sd * 0.16, 0.86, 0.07), v3(sd * 0.025, 0.95, 0.15)]);
      else if (pose === 'wreath') arm([sh, v3(sd * 0.17, 0.85, 0.08), v3(sd * 0.1, 0.76, 0.2)]);
      else if (sd > 0) arm([sh, v3(0.2, 1.22, 0.03), v3(0.22, 1.46, 0.06)]);
      else arm([sh, v3(-0.18, 0.86, 0.04), v3(-0.16, 0.72, 0.1)]);
    }
    if (pose === 'wreath') {
      const pts: Vec3[] = [];
      const seg = lod === 0 ? 14 : 7;
      for (let k = 0; k <= seg; k++) pts.push(v3(Math.cos((k / seg) * Math.PI * 2) * 0.12, 0.66 + Math.sin((k / seg) * Math.PI * 2) * 0.12, 0.24));
      tube(b, pts, { radial: 4, radius: () => 0.022, radialNoise: (t, a) => 1 + 0.3 * Math.sin(t * 60 + a * 2) });
    }
  }
  // wings
  const wing = new THREE.Shape();
  wing.moveTo(0, 0);
  wing.bezierCurveTo(0.12, 0.25, 0.2, 0.42, 0.34, 0.5);
  const feathers = lod === 0 ? 6 : 2;
  let px = 0.34, py = 0.5;
  for (let i = 0; i < feathers; i++) {
    const t1 = (i + 1) / feathers;
    const nx = 0.34 - t1 * 0.24, ny = 0.5 - t1 * 1.05;
    wing.quadraticCurveTo((px + nx) / 2 + 0.05, (py + ny) / 2, nx, ny);
    px = nx; py = ny;
  }
  wing.quadraticCurveTo(0.04, -0.4, 0, -0.2);
  wing.lineTo(0, 0);
  for (const sd of [-1, 1]) {
    const wg = lod === 2
      ? new THREE.ShapeGeometry(wing, 2)
      : new THREE.ExtrudeGeometry(wing, { depth: 0.035, bevelEnabled: lod === 0, bevelThickness: 0.008, bevelSize: 0.008, bevelSegments: 1, curveSegments: lod === 0 ? 6 : 3 });
    const mm = new THREE.Matrix4().compose(v3(sd * 0.06, 1.0, -0.07), new THREE.Quaternion().setFromEuler(new THREE.Euler(0.1, sd * 0.55 + (sd < 0 ? Math.PI : 0), sd * -0.08)), v3(1, 1, 1));
    addGeo(b, wg, mm);
  }
  b.transform(fig, new THREE.Matrix4().makeScale(s, s, s).premultiply(new THREE.Matrix4().makeTranslation(0, y0, 0)));
  const H = y0 + 1.5 * s;
  finishStone(b, m, style, seed, H, range(rnd, 0.8, 1.4), () => 0);
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
}

// ---------------------------------------------------------------- kerbed plot

export interface KerbedPlotOptions { length?: number; width?: number; infill?: 'gravel' | 'chips' | 'grass'; headstone?: boolean; }

/** Kerbed grave plot (along +Z) with gravel/marble chip infill and an optional headstone at -Z. */
export function kerbedPlot(seed: number, lod: LOD, opts: KerbedPlotOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 6400);
  const L = opts.length ?? range(rnd, 1.9, 2.4), W = opts.width ?? range(rnd, 0.8, 1.1);
  const infill = opts.infill ?? pick(rnd, ['gravel', 'chips', 'grass'] as const);
  const style = pickStyle(rnd);
  const b = new MeshBuilder();
  const km = b.mark();
  const kh = range(rnd, 0.12, 0.2), kt = range(rnd, 0.08, 0.12);
  const sunk = rnd() * 0.03;
  slab(b, v3(kt, kh, L), v3(-W / 2 + kt / 2, kh / 2 - sunk, 0), new THREE.Euler(0, 0, gauss(rnd) * 0.02));
  slab(b, v3(kt, kh, L), v3(W / 2 - kt / 2, kh / 2 - sunk, 0), new THREE.Euler(0, 0, gauss(rnd) * 0.02));
  slab(b, v3(W - kt * 2, kh, kt), v3(0, kh / 2 - sunk, L / 2 - kt / 2));
  slab(b, v3(W - kt * 2, kh, kt), v3(0, kh / 2 - sunk, -L / 2 + kt / 2));
  if (lod < 2) for (const x of [-1, 1]) for (const z of [-1, 1]) slab(b, v3(kt * 1.3, kh + 0.04, kt * 1.3), v3(x * (W / 2 - kt / 2), (kh + 0.04) / 2 - sunk, z * (L / 2 - kt / 2)));
  finishStone(b, km, style, seed, kh, range(rnd, 0.7, 1.4), polishTop);
  if (infill !== 'grass') {
    const seg = lod === 0 ? [8, 16] : lod === 1 ? [3, 6] : [1, 1];
    const g = new THREE.PlaneGeometry(W - kt * 2, L - kt * 2, seg[0], seg[1]).rotateX(-Math.PI / 2);
    const im = b.appendGeometry(g, mat4(v3(0, kh * 0.6 - sunk, 0)));
    g.dispose();
    const n3 = createNoise3D(subSeed(seed, 6401));
    const base = infill === 'chips' ? hex(0xbdb8ac) : hex(0x8a8478);
    b.paint(im, (p) => {
      const k = n3(p.x * 9, 0, p.z * 9);
      let c = mul(base, 0.85 + 0.3 * k);
      c = mix(c, hex(0x55602e), smoothstep(0.35, 0.7, n3(p.x * 2, 4, p.z * 2)) * 0.6); // weeds and moss creeping in
      return c;
    });
    b.boxUV(im, 6);
    b.emitPolish = true;
  }
  if (opts.headstone ?? true) {
    const hm = b.mark();
    const kinds: HeadstoneKind[] = ['roundTop', 'gothic', 'shouldered', 'pediment', 'willow'];
    buildHeadstone(b, rnd, seed + 1, lod, pick(rnd, kinds), style);
    b.transform(hm, mat4(v3(0, -0.02, -L / 2 + 0.01), new THREE.Euler(gauss(rnd) * 0.03, 0, gauss(rnd) * 0.02)));
  }
  const g = b.build();
  return { geometry: g, material: stoneMaterial(), collider: boxColliderOf(g) };
}

// ---------------------------------------------------------------- bouquet

export const BOUQUET_PALETTE = {
  mum: [hex(0x9a5a2a), hex(0xbe9a2c), hex(0x5c1c24), hex(0xcfc8b8), hex(0xa8452e)] as RGB[],
  rose: [hex(0x8a1a1c), hex(0x9e2a2a), hex(0xc8b8a0)] as RGB[],
  wilted: [hex(0x6a4a30), hex(0x5a3e2a), hex(0x7a5a3a)] as RGB[],
  stem: hex(0x4a5a2a),
  bronze: [hex(0x4e4232), hex(0x5a6a5a)] as RGB[],
  wrap: [hex(0xa08a64), hex(0x7a8a8a), hex(0x8a3a3a)] as RGB[],
};

/** Cut flowers in a bronze grave vase, or a wrapped bunch lying on the ground. */
export function bouquet(seed: number, lod: LOD): AssetResult {
  const rnd = makeRnd(seed, 6500);
  const P = BOUQUET_PALETTE;
  const b = new MeshBuilder();
  const solid = solidUV();
  const inVase = chance(rnd, 0.6);
  const wilted = chance(rnd, 0.3);
  const budget = TRI_BUDGET[lod] - 4;
  const setSolid = (m: Mark): void => { for (let k = m.v; k < b.vertexCount; k++) { b.uvs[k * 2] = solid.u0; b.uvs[k * 2 + 1] = (solid.v0 + solid.v1) / 2; } };
  const xf = new THREE.Matrix4();
  let mouth = v3(0, 0.24, 0);
  if (inVase) {
    const vm = lathe(b, lod === 2 ? [[0.05, 0], [0.065, 0.24]] : [[0.05, 0], [0.06, 0.02], [0.045, 0.06], [0.055, 0.18], [0.07, 0.235], [0.062, 0.245]], lod === 0 ? 10 : lod === 1 ? 6 : 4);
    const vc = pick(rnd, P.bronze);
    const n3 = createNoise3D(irange(rnd, 0, 1e6));
    b.paint(vm, (p) => mul(mix(vc, hex(0x5e7a68), smoothstep(0.2, 0.6, n3(p.x * 30, p.y * 30, p.z * 30)) * 0.6), 0.6 + 0.4 * smoothstep(0, 0.08, p.y)));
    setSolid(vm);
  } else {
    // lying bunch along +X: stems toward -X, heads at +X
    mouth = v3(0, 0, 0);
    xf.makeRotationZ(-Math.PI / 2 + 0.12).premultiply(new THREE.Matrix4().makeTranslation(-0.1, 0.04, 0));
  }
  const fm = b.mark();
  const n = lod === 0 ? irange(rnd, 7, 14) : lod === 1 ? 5 : 3;
  const H = inVase ? range(rnd, 0.22, 0.35) : range(rnd, 0.35, 0.45);
  for (let i = 0; i < n; i++) {
    withinBudget(b, budget, () => {
      const a = rnd() * Math.PI * 2, spread = range(rnd, 0.03, 0.12);
      const droop = wilted ? range(rnd, 0.05, 0.12) : 0;
      const top = v3(Math.cos(a) * spread, mouth.y + H * range(rnd, 0.75, 1.05) - droop, Math.sin(a) * spread);
      const pts = [mouth.clone().add(v3(Math.cos(a) * 0.01, 0, Math.sin(a) * 0.01)), mouth.clone().lerp(top, 0.5).add(v3(0, 0.02, 0)), top];
      ribbon(b, pts, { width: () => (lod === 2 ? 0.012 : 0.005), side: () => v3(-Math.sin(a), 0, Math.cos(a)), color: () => wilted ? mix(P.stem, P.wilted[0]!, 0.5) : P.stem, sway: (t) => t * 0.8, uv: solid, normalBias: UP, normalBiasAmt: 0.4 });
      const rose = chance(rnd, 0.3);
      const col = wilted ? pick(rnd, P.wilted) : tint(pick(rnd, rose ? P.rose : P.mum), range(rnd, 0.85, 1.1));
      const r = rose ? range(rnd, 0.022, 0.03) : range(rnd, 0.03, 0.045);
      const hm = blob(b, lod === 0 ? 2 : 1, top, v3(r, r * 0.7, r), (d) => 1 + (rose ? 0 : 0.12 * Math.sin(d.x * 20) * Math.sin(d.z * 20)), 0);
      b.paint(hm, (_p, nn) => mul(col, 0.7 + 0.3 * clamp01(nn.y + 0.3)));
      b.setSway(hm, () => 1);
      setSolid(hm);
      if (lod === 0 && chance(rnd, 0.5)) card(b, pts[1]!, v3(-Math.sin(a), 0, Math.cos(a)), v3(Math.cos(a), 0.6, Math.sin(a)).normalize(), 0.03 / 0.36, 0.07, { uv: cellUV(Cell.Broadleaf), color: wilted ? P.wilted[1]! : hex(0x3e5228), sway: [0.5, 0.7], normal: UP });
    });
  }
  if (!inVase) {
    const wm = lathe(b, [[0.0005, -0.05], [0.07, 0.12], [0.075, 0.16]], lod === 0 ? 8 : 4);
    b.paint(wm, () => pick(rnd, P.wrap));
    setSolid(wm);
    b.transform(fm, xf);
  }
  b.shade({ v: 0, i: 0 }, (p) => 0.55 + 0.45 * smoothstep(0, 0.06, p.y));
  return { geometry: b.build(), material: foliageMaterial() };
}

// ---------------------------------------------------------------- flag

export interface FlagOptions {
  /** band colors as sRGB hex, hoist to fly (vertical) or top to bottom (horizontal) */
  bands?: number[];
  /** relative band widths */
  widths?: number[];
  horizontal?: boolean;
}

/** Small grave-marker flag on a dowel. Cloth aSway: 0 at the hoist, 1 at the fly.
 *  Default is a generic red-white-red vertical tri-band; set your own bands. */
export function graveFlag(seed: number, lod: LOD, opts: FlagOptions = {}): AssetResult {
  const rnd = makeRnd(seed, 6600);
  const bands = opts.bands ?? [0xa8261e, 0xd6d2ca, 0xa8261e];
  const widths = opts.widths ?? (bands.length === 3 ? [0.25, 0.5, 0.25] : bands.map(() => 1 / bands.length));
  const b = new MeshBuilder();
  const solid = solidUV();
  const pole = range(rnd, 0.45, 0.65), fw = 0.3, fh = 0.2;
  const lean = gauss(rnd) * 0.08;
  const dm = tube(b, [v3(0, -0.1, 0), v3(0, pole, 0)], { radial: lod === 2 ? 3 : 4, radius: () => 0.005 });
  b.paint(dm, () => hex(0x3a3a38));
  b.setSway(dm, (p) => clamp01(p.y / pole) * 0.15);
  for (let k = dm.v; k < b.vertexCount; k++) { b.uvs[k * 2] = solid.u0; b.uvs[k * 2 + 1] = (solid.v0 + solid.v1) / 2; }
  const nu = lod === 0 ? 8 : lod === 1 ? 4 : 1, nv = lod === 0 ? 4 : lod === 1 ? 2 : 1;
  const ph = rnd() * 6, amp = range(rnd, 0.01, 0.025), sag = range(rnd, 0.02, 0.06);
  const pos = (u: number, v: number): Vec3 => v3(u * fw, pole - fh + v * fh - u * u * sag, Math.sin(u * Math.PI * 2.3 + ph) * amp * u);
  let acc = 0;
  for (let bi = 0; bi < bands.length; bi++) {
    const w = widths[bi]!;
    const [u0, u1, v0, v1] = opts.horizontal ? [0, 1, 1 - acc - w, 1 - acc] : [acc, acc + w, 0, 1];
    acc += w;
    const col = hex(bands[bi]!);
    const cu = Math.max(1, Math.round(nu * (u1 - u0))), cv = Math.max(1, Math.round(nv * (v1 - v0)));
    const m = b.mark();
    for (let i = 0; i <= cu; i++) for (let j = 0; j <= cv; j++) {
      const u = u0 + (u1 - u0) * (i / cu), v = v0 + (v1 - v0) * (j / cv);
      b.vert(pos(u, v), v3(0, 0, 1), solid.u0, (solid.v0 + solid.v1) / 2, mul(col, 0.9 + 0.1 * Math.cos(u * 7 + ph)), u);
    }
    for (let i = 0; i < cu; i++) for (let j = 0; j < cv; j++) {
      const a = m.v + i * (cv + 1) + j;
      b.quad(a, a + cv + 1, a + cv + 2, a + 1);
    }
    b.smoothNormals(m);
  }
  b.transform({ v: 0, i: 0 }, new THREE.Matrix4().makeRotationZ(lean).premultiply(new THREE.Matrix4().makeRotationY(rnd() * Math.PI * 2)));
  return { geometry: b.build(), material: foliageMaterial() };
}
