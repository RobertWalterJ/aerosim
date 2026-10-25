// FREESTYLE: a 5-inch true-X FPV quad, 750 g all-up with a 4S 1300 mAh pack.
// 225 mm motor-to-motor wheelbase, 5 mm chamfered carbon arms, 2306-class
// motors, tri-blade bullnose props, 30.5 mm FC/ESC stack, VTX with lollipop
// antenna, action camera on a TPU mount, FPV camera tilted 25 degrees.
// Units m, Y up, forward -Z, origin at the centre of mass.
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import {
  Batch, MassModel, loft, lathe, cylinder, box, plate, cable, band, socketHead, hexNut, standoff, zipTie, motor2306,
  propBlades, propHub, blurDisc, solidityProfile, makeLed, ledGeometry, assemble, paint, prep, xf, v3, lin, mixRGB, accentColor, colorToRGB,
  type Lod, type DroneVariant, type DroneBuild, type PropSpec, type V3, type LedSpec, type RotorSpec, type RGB,
} from './parts';
import { freestyleMaterials } from './materials';
import { blurAlpha, PCB_UV, type UVRect } from './textures';

export interface FreestyleVariant extends DroneVariant {
  /** spin per rotor (+1 CCW seen from above). Default follows the brief: 0 and 2 CCW. */
  spin?: readonly number[];
}
export const FREESTYLE_SPIN_DEFAULT = [1, -1, 1, -1] as const;

export const FREESTYLE_DIMS = { wheelbase: 0.225, armD: 0.225 / 2 / Math.SQRT2, propRadius: 0.0635, armTop: 0.0075, propPlane: 0.0075 + 0.0223 };

export const FREESTYLE_PROP: PropSpec = {
  radius: FREESTYLE_DIMS.propRadius, rootRadius: 0.0068, hubRadius: 0.0066, hubHeight: 0.0074, blades: 3, pitch: 4.3 * 0.0254,
  chord: (x) => 0.0095 + 0.0062 * Math.sin(Math.PI * Math.min(1, 0.2 + x * 0.85)),
  thickness: (x) => 0.14 - 0.07 * x, camber: 0.05, sweep: (x) => 0.006 * x * x, coning: 0.02, tip: 'bull',
};

const CARBON_M = 0.26; // meters covered by each half of the carbon texture

/** Planar carbon UVs: half 0 = top plate (with decal), half 1 = arms and bottom plate. */
function carbonUV(g: THREE.BufferGeometry, half: 0 | 1): THREE.BufferGeometry {
  prep(g);
  const P = g.getAttribute('position'), N = g.getAttribute('normal'), U = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < P.count; i++) {
    const x = P.getX(i), y = P.getY(i), z = P.getZ(i);
    const ax = Math.abs(N.getX(i)), ay = Math.abs(N.getY(i)), az = Math.abs(N.getZ(i));
    let a: number, b: number;
    if (ay >= ax && ay >= az) { a = x; b = -z; } else if (ax >= az) { a = z; b = y * 4; } else { a = x; b = y * 4; }
    U.setXY(i, 0.5 * (a / CARBON_M + 0.5) + 0.5 * half, 0.5 + b / CARBON_M);
  }
  return g;
}

function uvRect(g: THREE.BufferGeometry, r: UVRect, x0: number, x1: number, z0: number, z1: number): THREE.BufferGeometry {
  prep(g);
  const P = g.getAttribute('position'), N = g.getAttribute('normal'), U = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < P.count; i++) {
    if (Math.abs(N.getY(i)) < 0.7) { U.setXY(i, r.u0 + 0.01, r.v0 + 0.01); continue; }
    const u = (P.getX(i) - x0) / (x1 - x0), v = 1 - (P.getZ(i) - z0) / (z1 - z0);
    U.setXY(i, r.u0 + (r.u1 - r.u0) * u, r.v0 + (r.v1 - r.v0) * v);
  }
  return g;
}

function roundedRect(w: number, d: number, r: number): THREE.Shape {
  const s = new THREE.Shape();
  const x0 = -w / 2, y0 = -d / 2;
  s.moveTo(x0 + r, y0); s.lineTo(x0 + w - r, y0); s.absarc(x0 + w - r, y0 + r, r, -Math.PI / 2, 0, false);
  s.lineTo(x0 + w, y0 + d - r); s.absarc(x0 + w - r, y0 + d - r, r, 0, Math.PI / 2, false);
  s.lineTo(x0 + r, y0 + d); s.absarc(x0 + r, y0 + d - r, r, Math.PI / 2, Math.PI, false);
  s.lineTo(x0, y0 + r); s.absarc(x0 + r, y0 + r, r, Math.PI, Math.PI * 1.5, false);
  return s;
}
function hole(cx: number, cy: number, r: number): THREE.Path {
  const p = new THREE.Path();
  p.absarc(cx, cy, r, 0, Math.PI * 2, true);
  return p;
}
function slot(cx: number, cy: number, w: number, d: number): THREE.Path {
  const p = new THREE.Path();
  const r = Math.min(w, d) / 2;
  p.moveTo(cx - w / 2 + r, cy - d / 2);
  p.absarc(cx - w / 2 + r, cy, r, -Math.PI / 2, -Math.PI * 1.5, true);
  p.lineTo(cx + w / 2 - r, cy + d / 2);
  p.absarc(cx + w / 2 - r, cy, r, Math.PI / 2, -Math.PI / 2, true);
  return p;
}

/** One arm along +X from the root to the motor pad, with M3 holes (16 x 16) and a shaft relief. */
function armShape(lod: Lod): THREE.Shape {
  const r0 = 0.016, r1 = FREESTYLE_DIMS.wheelbase / 2, w0 = 0.0135, w1 = 0.0112, pr = 0.0155;
  const s = new THREE.Shape();
  const xa = r1 - Math.sqrt(pr * pr - (w1 / 2) ** 2);
  s.moveTo(r0, -w0 / 2);
  s.lineTo(xa, -w1 / 2);
  const a0 = Math.atan2(-w1 / 2, xa - r1);
  s.absarc(r1, 0, pr, a0, -a0, false); // around the motor pad, through the arm tip
  s.lineTo(r0, w0 / 2);
  s.lineTo(r0, -w0 / 2);
  if (lod === 0) {
    for (const [dx, dy] of [[0.008, 0.008], [-0.008, 0.008], [0.008, -0.008], [-0.008, -0.008]] as const) s.holes.push(hole(r1 + dx, dy, 0.0016));
    s.holes.push(hole(r1, 0, 0.0042));
    s.holes.push(slot(0.055, 0, 0.022, 0.0042)); // lightening slot
  }
  return s;
}

export function buildFreestyleDrone(variant: FreestyleVariant = {}, lod: Lod = 0): DroneBuild {
  const accent = accentColor(variant.accent, 'hotPink');
  const A = colorToRGB(accent);
  const wear = Math.max(0, Math.min(1, variant.wear ?? 0.35));
  const seed = variant.seed ?? 1;
  const spin = variant.spin ?? FREESTYLE_SPIN_DEFAULT;
  const d = FREESTYLE_DIMS.armD;
  const corners: [number, number][] = [[1, -1], [1, 1], [-1, 1], [-1, -1]]; // FR, RR, RL, FL
  const M = freestyleMaterials({
    accent, wear, seed,
    carbon: { seed, wear, accent, meters: CARBON_M, scuffs: [...corners.map(([sx, sz]) => [sx * d, sz * d] as [number, number]), [0, 0]], sticker: 'NIGHTJAR 5', stickerAt: [0, 0.052] },
  });
  const mass = new MassModel();
  const B = new Batch(mass);
  const W: RGB = [1, 1, 1];
  const STEEL = lin(0xc2c5c8), BLACK = lin(0x121214), RED = lin(0xa01818), YELLOW = lin(0xd9a400);
  const yArm0 = 0.0025, yArm1 = FREESTYLE_DIMS.armTop, yTop0 = 0.0375, yTop1 = 0.040;
  const segs = lod === 0 ? 20 : 8;

  // ---- frame: bottom plate, four 5 mm arms, top plate
  {
    const bs = roundedRect(0.042, 0.13, 0.008);
    if (lod === 0) { bs.holes.push(slot(0, -0.03, 0.014, 0.004)); bs.holes.push(slot(0, 0.03, 0.014, 0.004)); }
    B.add('carbon', carbonUV(plate(bs, 0.0025, 0.0004, 0, lod === 0 ? 8 : 3), 1), undefined, W, 0.03);
    const ts = roundedRect(0.042, 0.116, 0.008);
    if (lod === 0) for (const sx of [-1, 1]) ts.holes.push(slot(sx * 0.0185, 0.012, 0.003, 0.022));
    B.add('carbon', carbonUV(plate(ts, 0.0025, 0.0004, yTop0, lod === 0 ? 8 : 3), 0), undefined, W, 0.025);
    corners.forEach(([sx, sz]) => {
      const g = plate(armShape(lod), yArm1 - yArm0, 0.0006, yArm0, lod === 0 ? 10 : 4);
      // shape x runs along the arm; rotate the +X axis onto the arm diagonal
      g.applyMatrix4(new THREE.Matrix4().makeRotationY(Math.atan2(-sz, sx)));
      B.add('carbon', carbonUV(g, 1), undefined, W, 0.016);
    });
  }
  // ---- standoffs (anodised accent) with button-head screws top and bottom
  const stand: [number, number][] = [[0.0155, -0.040], [-0.0155, -0.040], [0.0155, 0.034], [-0.0155, 0.034]];
  for (const [x, z] of stand) {
    B.add('accentAlu', standoff(yArm1, yTop0, lod), xf(v3(x, 0, z)), W, 0.0025);
    if (lod === 0) {
      B.add('bareMetal', socketHead(0.003, lod, STEEL, true), xf(v3(x, yTop1, z)), STEEL);
      B.add('bareMetal', socketHead(0.003, lod, STEEL, true), xf(v3(x, 0, z), new THREE.Euler(Math.PI, 0, 0)), STEEL);
    }
  }
  // arm clamp bolts under the bottom plate
  if (lod === 0) for (const [sx, sz] of corners) for (const r of [0.019, 0.03]) {
    const p = v3(sx, 0, sz).normalize().multiplyScalar(r);
    B.add('bareMetal', socketHead(0.003, lod, mixRGB(STEEL, BLACK, 0.6), true), xf(v3(p.x, 0, p.z), new THREE.Euler(Math.PI, 0, 0)), undefined);
  }

  // ---- motors (static parts) and their screws
  const motors: V3[] = [];
  corners.forEach(([sx, sz]) => {
    const c = v3(sx * d, yArm1, sz * d);
    const mp = motor2306(lod, A, lin(0xb4622a), A);
    mp.fixed.forEach((g, k) => B.add(mp.fixedMat[k]!, g, xf(c), undefined, k === 0 ? 0.012 : 0));
    if (lod === 0) for (const [dx, dz] of [[0.008, 0.008], [-0.008, 0.008], [0.008, -0.008], [-0.008, -0.008]] as const) {
      const p = v3(dx, 0, dz).applyAxisAngle(v3(0, 1, 0), Math.atan2(-sz, sx));
      B.add('bareMetal', socketHead(0.003, lod, mixRGB(STEEL, BLACK, 0.7)), xf(v3(c.x + p.x, yArm0, c.z + p.z), new THREE.Euler(Math.PI, 0, 0)));
    }
    motors.push(v3(sx * d, FREESTYLE_DIMS.propPlane, sz * d));
  });

  // ---- FC / ESC stack (30.5 x 30.5 on rubber grommets)
  const board = (y: number, r: UVRect): void => {
    const g = box(0.036, 0.0016, 0.036, xf(v3(0, y, 0)));
    B.add('pcb', uvRect(g, r, -0.018, 0.018, -0.018, 0.018), undefined, W, 0.007);
  };
  board(0.0125, PCB_UV.esc);
  board(0.0205, PCB_UV.fc);
  for (const [x, z] of [[0.01525, 0.01525], [-0.01525, 0.01525], [0.01525, -0.01525], [-0.01525, -0.01525]] as const) {
    B.add('rubber', cylinder(0.0024, 0.005, lod === 0 ? 12 : 6, yArm1), xf(v3(x, 0, z)), lin(0x2a2a2c));
    B.add('rubber', cylinder(0.0024, 0.0062, lod === 0 ? 12 : 6, 0.0133), xf(v3(x, 0, z)), lin(0x2a2a2c));
    if (lod === 0) B.add('bareMetal', hexNut(0.0028, 0.0024, STEEL), xf(v3(x, 0.0214, z)));
  }
  if (lod === 0) {
    // components: MCU, gyro, MOSFETs, capacitors, USB, boot button
    B.add('plastic', box(0.0075, 0.0012, 0.0075, xf(v3(0, 0.0219, 0))), undefined, lin(0x161618));
    B.add('plastic', box(0.003, 0.001, 0.003, xf(v3(0.009, 0.0218, -0.008))), undefined, lin(0x1c1c1e));
    B.add('bareMetal', box(0.008, 0.003, 0.006, xf(v3(-0.019, 0.0228, 0.004))), undefined, STEEL);
    for (let k = 0; k < 12; k++) B.add('plastic', box(0.0045, 0.0011, 0.005, xf(v3(-0.0115 + (k % 6) * 0.0046, 0.0138, k < 6 ? -0.009 : 0.009))), undefined, lin(0x202022));
    for (let k = 0; k < 6; k++) B.add('plastic', box(0.0018, 0.0014, 0.0012, xf(v3(0.011 - (k % 3) * 0.003, 0.0139, k < 3 ? -0.0145 : 0.0145))), undefined, lin(0x7a6a4a));
  }
  // ---- main power: capacitor, XT60 pigtail and battery leads
  const capPos = v3(-0.016, yArm1 + 0.006, 0.038);
  B.add('plastic', cylinder(0.005, 0.02, segs, -0.01), xf(capPos, new THREE.Euler(Math.PI / 2, 0, 0.4)), lin(0x141416), 0.006);
  if (lod === 0) B.add('plastic', cylinder(0.0052, 0.003, segs, 0.007), xf(capPos, new THREE.Euler(Math.PI / 2, 0, 0.4)), lin(0x9a9aa0));
  const xt = v3(0.006, 0.047, 0.068);
  for (const [k, col] of [[0, RED], [1, BLACK]] as const) {
    B.add('rubber', cable([v3(0.004 - k * 0.006, 0.0136, 0.016), v3(0.003 - k * 0.006, 0.025, 0.045), xt.clone().add(v3(-0.003 + k * 0.004, -0.002, 0.004))], 0.0018, lod), undefined, col, 0.008);
    B.add('rubber', cable([v3(0.004 - k * 0.006, 0.058, 0.0485), v3(0.006 - k * 0.006, 0.058, 0.06), xt.clone().add(v3(-0.003 + k * 0.004, 0.002, -0.004))], 0.0016, lod), undefined, col);
  }
  B.add('plastic', prep(new RoundedBoxGeometry(0.0158, 0.0081, 0.0165, lod === 0 ? 2 : 1, 0.0012)), xf(xt, new THREE.Euler(0.3, 0, 0)), YELLOW, 0.008);
  B.add('plastic', prep(new RoundedBoxGeometry(0.0158, 0.0081, 0.012, lod === 0 ? 2 : 1, 0.0012)), xf(xt.clone().add(v3(0, 0.003, -0.012)), new THREE.Euler(0.3, 0, 0)), mixRGB(YELLOW, BLACK, 0.15));

  // ---- battery: pad, 4S 1300 mAh pack, rubber strap with metal buckle
  const bz = 0.012, bL = 0.073, bW = 0.035, bH = 0.033, by0 = yTop1 + 0.0015;
  B.add('rubber', box(0.03, 0.0015, 0.07, xf(v3(0, yTop1 + 0.00075, bz))), undefined, lin(0x2c2c2e), 0.004);
  const bs = { hw: bW / 2, top: bH / 2, bot: bH / 2, r: 0.0045 };
  B.add('lipo', loft([v3(0, by0 + bH / 2, bz - bL / 2), v3(0, by0 + bH / 2, bz + bL / 2)], [bs, bs], lod === 0 ? 36 : 14, { capStart: true, capEnd: true }), undefined, W, 0.19);
  {
    const yT = by0 + bH + 0.0007, xs = bW / 2 + 0.0008;
    const loop = [v3(0.019, yTop0 - 0.0008, 0), v3(xs, by0 + 0.004, 0), v3(xs, yT - 0.004, 0), v3(0.014, yT, 0), v3(-0.014, yT, 0), v3(-xs, yT - 0.004, 0), v3(-xs, by0 + 0.004, 0), v3(-0.019, yTop0 - 0.0008, 0), v3(0, yTop0 - 0.0012, 0)];
    for (const dz of [-0.018, 0.022]) {
      const g = band(loop.map((p) => p.clone().add(v3(0, 0, bz + dz))), 0.016, 0.0012, true, v3(0, 0, 1), lod === 0 ? 64 : 20);
      B.add('rubber', g, undefined, (p) => (p.y > yT - 0.002 && Math.abs(p.x) < 0.012 ? A : lin(0x1a1a1c)), 0.004);
      if (lod === 0) B.add('bareMetal', box(0.012, 0.0024, 0.018, xf(v3(-0.006, yT + 0.0012, bz + dz))), undefined, lin(0x8a8d90));
    }
  }

  // ---- action camera on a TPU mount, tilted 25 degrees up
  {
    const tilt = 25 * Math.PI / 180;
    const base = v3(0, yTop1, -0.041);
    B.add('tpu', prep(new RoundedBoxGeometry(0.034, 0.006, 0.03, lod === 0 ? 2 : 1, 0.002)), xf(base.clone().add(v3(0, 0.003, 0))), W, 0.006);
    for (const sx of [-1, 1]) B.add('tpu', prep(new RoundedBoxGeometry(0.004, 0.024, 0.026, lod === 0 ? 2 : 1, 0.0015)), xf(base.clone().add(v3(sx * 0.033, 0.016, 0)), new THREE.Euler(tilt, 0, 0)), W);
    B.add('tpu', box(0.07, 0.004, 0.026, xf(base.clone().add(v3(0, 0.0055, 0)), new THREE.Euler(tilt * 0.3, 0, 0))), undefined, W);
    const cam = new THREE.Matrix4().compose(base.clone().add(v3(0, 0.028, 0.002)), new THREE.Quaternion().setFromEuler(new THREE.Euler(tilt, 0, 0)), v3(1, 1, 1));
    B.add('plastic', prep(new RoundedBoxGeometry(0.062, 0.044, 0.032, lod === 0 ? 3 : 1, 0.004)), cam, lin(0x1c1c1e), 0.15);
    const front = (g: THREE.BufferGeometry, x: number, y: number, z: number): THREE.BufferGeometry => g.applyMatrix4(new THREE.Matrix4().makeTranslation(x, y, z)).applyMatrix4(cam);
    B.add('plastic', front(box(0.024, 0.024, 0.004), -0.012, 0.004, -0.017), undefined, lin(0x101012));
    B.add('glass', front(prep(new THREE.CylinderGeometry(0.0085, 0.0085, 0.006, segs).rotateX(Math.PI / 2)), -0.012, 0.004, -0.02), undefined, W);
    B.add('glass', front(box(0.018, 0.016, 0.001), 0.015, 0.006, -0.0162), undefined, W);
    B.add('plastic', front(cylinder(0.0035, 0.0018, segs, 0), 0.018, 0.022, -0.004), undefined, lin(0x8a1414));
  }
  // ---- FPV camera between the front standoffs, tilted 25 degrees, with TPU side plates
  {
    const tilt = 25 * Math.PI / 180;
    const cc = v3(0, 0.024, -0.046);
    const cam = new THREE.Matrix4().compose(cc, new THREE.Quaternion().setFromEuler(new THREE.Euler(tilt, 0, 0)), v3(1, 1, 1));
    B.add('plastic', prep(new RoundedBoxGeometry(0.019, 0.019, 0.019, lod === 0 ? 2 : 1, 0.002)).applyMatrix4(cam), undefined, lin(0x18181a), 0.01);
    const lensB = lathe([[0.0072, 0], [0.0072, 0.005], [0.0068, 0.0055], [0.0068, 0.009], [0.0055, 0.0095]], segs);
    lensB.applyMatrix4(new THREE.Matrix4().makeRotationX(-Math.PI / 2)).applyMatrix4(new THREE.Matrix4().makeTranslation(0, 0, -0.0095)).applyMatrix4(cam);
    B.add('plastic', lensB, undefined, lin(0x202022));
    const glass = lathe([[0.0001, 0.0102], [0.003, 0.0101], [0.0055, 0.0096]], segs);
    glass.applyMatrix4(new THREE.Matrix4().makeRotationX(-Math.PI / 2)).applyMatrix4(new THREE.Matrix4().makeTranslation(0, 0, -0.0095)).applyMatrix4(cam);
    B.add('glass', glass, undefined, W);
    for (const sx of [-1, 1]) B.add('tpu', box(0.002, 0.03, 0.026, xf(v3(sx * 0.0133, 0.0225, -0.044))), undefined, W, 0.003);
  }
  // ---- VTX with heat sink, coax and lollipop antenna in a TPU mount
  {
    const vy = 0.0265, vz = 0.036;
    const g = box(0.03, 0.0016, 0.03, xf(v3(0, vy, vz)));
    B.add('pcb', uvRect(g, PCB_UV.vtx, -0.015, 0.015, vz - 0.015, vz + 0.015), undefined, W, 0.008);
    B.add('blackAnodized', box(0.024, 0.0025, 0.024, xf(v3(0, vy + 0.002, vz))), undefined, W);
    const fins = lod === 0 ? 7 : 3;
    for (let k = 0; k < fins; k++) B.add('blackAnodized', box(0.0012, 0.005, 0.024, xf(v3(-0.0108 + k * (0.0216 / (fins - 1)), vy + 0.0055, vz))), undefined, W);
    const mount = v3(0, yTop1, 0.054);
    B.add('tpu', prep(new RoundedBoxGeometry(0.016, 0.01, 0.01, lod === 0 ? 2 : 1, 0.002)), xf(mount.clone().add(v3(0, 0.005, 0))), W, 0.003);
    const tip = mount.clone().add(v3(0, 0.05, 0.035));
    B.add('rubber', cable([v3(0.008, vy + 0.001, vz + 0.012), v3(0.004, 0.034, 0.05), mount.clone().add(v3(0, 0.008, 0)), tip], 0.0011, lod), undefined, lin(0x2a2a2c), 0.003);
    const dome = lathe([[0.0011, 0], [0.004, 0.002], [0.0085, 0.006], [0.0092, 0.0095], [0.007, 0.0135], [0.003, 0.0155], [0.0001, 0.0158]], segs);
    B.add('plastic', dome, xf(tip, new THREE.Euler(0.61, 0, 0)), lin(0x9aa0a6), 0.002);
  }
  // ---- receiver antennas in tubes zip-tied to the rear arms, ESC wires along every arm
  corners.forEach(([sx, sz]) => {
    const dir = v3(sx, 0, sz).normalize();
    const along = (r: number, y: number): V3 => dir.clone().multiplyScalar(r).setY(y);
    const ang = Math.atan2(-sz, sx);
    if (lod === 0) {
      // three motor phase wires as a single sleeved bundle on top of the arm
      B.add('rubber', cable([v3(sx * 0.016, 0.0133, sz * 0.016), along(0.03, yArm1 + 0.0018), along(0.06, yArm1 + 0.0016), along(0.093, yArm1 + 0.0016), along(0.1, yArm1 + 0.003)], 0.0017, lod), undefined, lin(0x161618), 0.003);
      const zt = zipTie(0.0065, 0.0042, lod);
      zt.applyMatrix4(new THREE.Matrix4().makeRotationY(Math.PI / 2)).applyMatrix4(new THREE.Matrix4().makeRotationY(ang)).applyMatrix4(new THREE.Matrix4().makeTranslation(...along(0.07, (yArm0 + yArm1) / 2 + 0.001).toArray()));
      B.add('rubber', zt);
    }
    if (sz > 0) {
      const off = v3(-sz, 0, sx).normalize().multiplyScalar(0.0045);
      B.add('rubber', cable([v3(0, 0.022, 0.02), along(0.035, yArm1 + 0.004).add(off), along(0.075, yArm1 + 0.003).add(off)], 0.0008, lod), undefined, lin(0x202022), 0.001);
      B.add('plastic', cable([along(0.06, yArm1 + 0.003).add(off), along(0.085, yArm1 + 0.003).add(off)], 0.0014, lod), undefined, lin(0xe0e0dc));
      if (lod === 0) {
        const zt = zipTie(0.0065, 0.0048, lod);
        zt.applyMatrix4(new THREE.Matrix4().makeRotationY(Math.PI / 2)).applyMatrix4(new THREE.Matrix4().makeRotationY(ang)).applyMatrix4(new THREE.Matrix4().makeTranslation(...along(0.082, (yArm0 + yArm1) / 2 + 0.0015).toArray()));
        B.add('rubber', zt);
      }
    }
  });

  // ---- LEDs: tail strips on the rear arms, FC status, VTX status
  const leds: LedSpec[] = [];
  for (const [name, sx] of [['tailRight', 1], ['tailLeft', -1]] as const) {
    const p = v3(sx, 0, 1).normalize().multiplyScalar(0.088).setY(yArm1);
    leds.push({ handle: makeLed(name, accent.getHex(), 0.5), geometry: prep(ledGeometry(0.004, 0.012, 0.0018, lod)).applyMatrix4(xf(p, new THREE.Euler(0, Math.atan2(sx, 1), 0))) });
  }
  leds.push({ handle: makeLed('fcStatus', 0x2a6bff, 0.5), geometry: prep(ledGeometry(0.0016, 0.001, 0.0008, lod)).applyMatrix4(xf(v3(0.012, 0.0213, 0.012))) });
  leds.push({ handle: makeLed('vtxStatus', 0xff2010, 0.8), geometry: prep(ledGeometry(0.0016, 0.001, 0.0008, lod)).applyMatrix4(xf(v3(0.012, 0.0274, 0.048))) });

  // ---- rotors: spinning bell, magnets, bearing, shaft, nut; tri-blade props
  const propBase = A;
  const alpha = blurAlpha('freestyle', solidityProfile(FREESTYLE_PROP, 0.003));
  const rotors: RotorSpec[] = motors.map((pos, i) => {
    const dir = (spin[i]! > 0 ? 1 : -1) as 1 | -1;
    const mp = motor2306(lod, A, lin(0xb4622a), A);
    const hub = mergeGeometries(mp.spinning.map((g) => prep(g)), false)!;
    hub.translate(0, -0.0223, 0);
    const blades = propBlades(FREESTYLE_PROP, lod, dir, propBase, wear, seed * 17 + i, i * 0.4);
    const sharp = mergeGeometries([blades, propHub(FREESTYLE_PROP, lod, mixRGB(propBase, BLACK, 0.15), 0.0025)], false)!;
    mass.addPoint(0.021 + 0.0045, pos.clone().add(v3(0, -0.01, 0)), v3(0.028, 0.02, 0.028));
    return { pos, hub, sharp, blur: blurDisc(0.003, FREESTYLE_PROP.radius, lod === 0 ? 72 : 24), blurAlpha: alpha, propColor: accent.clone() };
  });

  return assemble({
    name: 'freestyle', lod, batch: B, materials: M, rotors, spin, hubMat: 'bell', propMat: 'prop', leds, mass, totalMass: 0.75, propRadius: FREESTYLE_PROP.radius,
    ao: lod === 0 ? { voxel: 0.0011, maxDist: 0.02, strength: 1.15, rays: 14 } : { voxel: 0.0025, maxDist: 0.02, strength: 1.0, rays: 8 },
  });
}

/** Spec entry point: buildDrone(variant, lod) for the freestyle airframe. */
export function buildDrone(variant: FreestyleVariant = {}, lod: Lod = 0): DroneBuild {
  return buildFreestyleDrone(variant, lod);
}
