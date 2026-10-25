// MINI: an original 249 g folding camera quad (fictional brand "AeroLite"),
// modelled unfolded. Spec targets (within 3 %): flying footprint including
// 3-inch props 290 x 370 mm, height 62 mm, body plus gimbal 145 mm long.
// Units m, Y up, forward -Z, origin at the centre of mass.
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import {
  Batch, MassModel, loft, lathe, cylinder, box, panHead, propBlades, propHub, blurDisc, solidityProfile, makeLed, ledGeometry,
  assemble, paint, prep, xf, v3, lin, accentColor, type Lod, type DroneVariant, type DroneBuild, type PropSpec, type Section, type V3, type LedSpec, type RotorSpec,
} from './parts';
import { miniMaterials } from './materials';
import { MINI_DECALS, blurAlpha, type UVRect } from './textures';

export type MiniShell = 'lightGrey' | 'white' | 'charcoal';
export interface MiniVariant extends DroneVariant {
  shell?: MiniShell;
  /** spin per rotor (+1 CCW seen from above). Default follows the brief: 0 and 2 CCW. */
  spin?: readonly number[];
}

const SHELLS: Record<MiniShell, number> = { lightGrey: 0xbdbfc1, white: 0xd9d9d6, charcoal: 0x4a4c50 };
export const MINI_SPIN_DEFAULT = [1, -1, 1, -1] as const;

/** Geometry constants (design frame, before the centre-of-mass shift). */
export const MINI_DIMS = {
  propRadius: 0.0381,
  motorFront: { x: 0.1469, y: 0.0295, z: -0.1028 },
  motorRear: { x: 0.1469, y: 0.0145, z: 0.111 },
  legBottom: -0.0298,
};

const sec = (hw: number, top: number, bot: number, r: number): Section => ({ hw, top, bot, r });

export const MINI_PROP: PropSpec = {
  radius: MINI_DIMS.propRadius, rootRadius: 0.0075, hubRadius: 0.0072, hubHeight: 0.0042, blades: 2, pitch: 0.0762,
  chord: (x) => 0.0066 + 0.0052 * Math.sin(Math.PI * Math.min(1, 0.25 + x * 0.9)),
  thickness: (x) => 0.12 - 0.06 * x, camber: 0.045, sweep: (x) => 0.004 * x * x, coning: 0.03, tip: 'round',
};

function decalQuad(r: UVRect, w: number, h: number, m: THREE.Matrix4): THREE.BufferGeometry {
  const g = new THREE.PlaneGeometry(w, h);
  const uv = g.getAttribute('uv') as THREE.BufferAttribute;
  for (let i = 0; i < uv.count; i++) uv.setXY(i, r.u0 + (r.u1 - r.u0) * uv.getX(i), r.v0 + (r.v1 - r.v0) * uv.getY(i));
  g.applyMatrix4(m);
  return prep(g);
}

export function buildMiniDrone(variant: MiniVariant = {}, lod: Lod = 0): DroneBuild {
  const shell = new THREE.Color().setHex(SHELLS[variant.shell ?? 'lightGrey'], THREE.SRGBColorSpace);
  const accent = accentColor(variant.accent, 'orange');
  const wear = Math.max(0, Math.min(1, variant.wear ?? 0.15));
  const seed = variant.seed ?? 1;
  const spin = variant.spin ?? MINI_SPIN_DEFAULT;
  const M = miniMaterials({ shell, accent, wear, seed });
  const mass = new MassModel();
  const B = new Batch(mass);
  const around = lod === 0 ? 40 : 16;
  const W = [1, 1, 1] as [number, number, number];
  const DARK = lin(0x2b2d30), BLACK = lin(0x141416), GUN = lin(0x3e4044), STEEL = lin(0x9a9da1), AMBER = lin(0xb5701f);

  // ---- body: front shell (textured) and the darker battery
  const front: [number, Section][] = [
    [-0.0640, sec(0.021, 0.010, 0.010, 0.008)], [-0.0600, sec(0.026, 0.014, 0.014, 0.010)], [-0.0520, sec(0.030, 0.018, 0.020, 0.012)],
    [-0.0400, sec(0.032, 0.020, 0.022, 0.014)], [-0.0200, sec(0.033, 0.021, 0.023, 0.014)], [0.0000, sec(0.033, 0.022, 0.023, 0.014)], [0.0215, sec(0.033, 0.022, 0.023, 0.014)],
  ];
  B.add('shell', loft(front.map(([z]) => v3(0, 0, z)), front.map(([, s]) => s), around, { capStart: true }), undefined, W, 0.065);
  const batt: [number, Section][] = [
    [0.0225, sec(0.0318, 0.0208, 0.0218, 0.013)], [0.040, sec(0.0312, 0.0202, 0.0212, 0.013)], [0.052, sec(0.029, 0.019, 0.020, 0.012)], [0.057, sec(0.026, 0.017, 0.018, 0.011)], [0.060, sec(0.021, 0.013, 0.014, 0.009)],
  ];
  B.add('darkPlastic', loft(batt.map(([z]) => v3(0, 0, z)), batt.map(([, s]) => s), around, { capEnd: true }), undefined, lin(0x3a3c40), 0.082);
  // rubber gasket ring at the battery joint
  B.add('rubber', loft([v3(0, 0, 0.0214), v3(0, 0, 0.0226)], [sec(0.0334, 0.0224, 0.0234, 0.014), sec(0.0334, 0.0224, 0.0234, 0.014)], around), undefined, BLACK);
  mass.addPoint(0.03, v3(0, 0, -0.01), v3(0.05, 0.03, 0.07)); // flight controller, radios, IMU
  if (lod === 0) {
    // battery side latches and rear power button
    for (const s of [-1, 1]) B.add('darkPlastic', prep(new RoundedBoxGeometry(0.002, 0.006, 0.011, 2, 0.0008)), xf(v3(s * 0.0316, 0.002, 0.031)), lin(0x2a2c30));
    B.add('darkPlastic', cylinder(0.0024, 0.0012, 16), xf(v3(0.009, 0.006, 0.0605), new THREE.Euler(Math.PI / 2, 0, 0)), lin(0x2a2c30));
    // grip ribs on the battery flanks
    for (const s of [-1, 1]) for (let k = 0; k < 5; k++) B.add('darkPlastic', box(0.0006, 0.012, 0.0012), xf(v3(s * 0.0314, -0.002, 0.041 + k * 0.0028)), lin(0x2e3034));
  }
  // decals: top wordmark, belly manufacturing label, battery print, serial plate, battery level window, nose arrow
  B.add('decals', decalQuad(MINI_DECALS.wordmark, 0.032, 0.008, xf(v3(0, 0.0207, -0.028), new THREE.Euler(-Math.PI / 2, 0, 0))));
  B.add('decals', decalQuad(MINI_DECALS.label, 0.030, 0.030, xf(v3(0, -0.0232, 0.006), new THREE.Euler(Math.PI / 2, 0, 0))));
  B.add('decals', decalQuad(MINI_DECALS.battery, 0.034, 0.017, xf(v3(0, 0.0204, 0.040), new THREE.Euler(-Math.PI / 2, 0, 0))));
  B.add('decals', decalQuad(MINI_DECALS.levelLeds, 0.012, 0.004, xf(v3(-0.004, 0.006, 0.0602))));
  if (lod === 0) {
    B.add('decals', decalQuad(MINI_DECALS.serial, 0.012, 0.012, xf(v3(0.012, -0.0232, -0.03), new THREE.Euler(Math.PI / 2, 0, 0))));
    B.add('decals', decalQuad(MINI_DECALS.arrow, 0.006, 0.006, xf(v3(0, 0.0205, -0.05), new THREE.Euler(-Math.PI / 2, 0, 0))));
  }
  // vision sensors: forward pair on the nose, downward pair and ToF on the belly
  for (const s of [-1, 1]) {
    B.add('sensorGlass', cylinder(0.0031, 0.0016, lod === 0 ? 18 : 8), xf(v3(s * 0.0115, 0.004, -0.0632), new THREE.Euler(Math.PI / 2, 0, 0)), W);
    B.add('darkPlastic', cylinder(0.0039, 0.0012, lod === 0 ? 18 : 8), xf(v3(s * 0.0115, 0.004, -0.0626), new THREE.Euler(Math.PI / 2, 0, 0)), BLACK);
    B.add('sensorGlass', cylinder(0.0028, 0.0012, lod === 0 ? 18 : 8), xf(v3(s * 0.0095, -0.0236, -0.014)), W);
  }
  B.add('sensorGlass', box(0.0065, 0.001, 0.0032, xf(v3(0, -0.0233, 0.0))), undefined, W);

  // ---- arms, hinges, motor housings, antenna legs
  const leds: LedSpec[] = [];
  const ledDefs: [string, number][] = [['frontRight', 0xff2a1a], ['rearRight', 0x20ff40], ['rearLeft', 0x20ff40], ['frontLeft', 0xff2a1a]];
  const motors: V3[] = [];
  const corners: [number, number][] = [[1, -1], [1, 1], [-1, 1], [-1, -1]]; // rotor order: FR, RR, RL, FL
  corners.forEach(([sx, sz], i) => {
    const isFront = sz < 0;
    const md = isFront ? MINI_DIMS.motorFront : MINI_DIMS.motorRear;
    const mx = sx * md.x, mz = md.z;
    const hinge = isFront ? v3(sx * 0.0305, 0.006, -0.040) : v3(sx * 0.0265, -0.013, 0.030);
    const housingTop = md.y - 0.0105, housingY0 = housingTop - 0.020;
    const armEnd = v3(mx, housingY0 + 0.010, mz).sub(hinge).setY(0).normalize().multiplyScalar(-0.009).add(v3(mx, housingY0 + 0.010, mz));
    const mid = hinge.clone().lerp(armEnd, 0.5).add(v3(0, 0.0015, 0));
    B.add('shellPlain', loft([hinge, mid, armEnd], [sec(0.0058, 0.0042, 0.0042, 0.0042), sec(0.0054, 0.004, 0.004, 0.004), sec(0.005, 0.0038, 0.0038, 0.0038)], lod === 0 ? 16 : 8, { capEnd: true }), undefined, W, 0.004);
    // hinge knuckle with a visible seam ring and a tiny Phillips screw
    B.add('shellPlain', cylinder(0.0062, 0.014, lod === 0 ? 24 : 10, hinge.y - 0.007), xf(v3(hinge.x, 0, hinge.z)), W);
    B.add('darkPlastic', cylinder(0.00628, 0.0005, lod === 0 ? 24 : 10, hinge.y - 0.0002), xf(v3(hinge.x, 0, hinge.z)), BLACK);
    if (lod === 0) B.add('metal', panHead(0.0016, lod), xf(v3(hinge.x, hinge.y + 0.007, hinge.z)), STEEL);
    // motor housing cup
    const cup = lathe([[0.0001, housingY0], [0.0094, housingY0], [0.0105, housingY0 + 0.002], [0.0105, housingTop - 0.0005], [0.0098, housingTop], [0.0086, housingTop]], lod === 0 ? 32 : 12);
    B.add('shellPlain', cup, xf(v3(mx, 0, mz)), W, 0.008);
    // landing leg with the antenna inside, rubber foot
    const legTop = v3(mx, housingY0 + 0.001, mz + 0.002 * (isFront ? -1 : 1)), legBot = v3(mx, MINI_DIMS.legBottom + 0.0012, mz + 0.004 * (isFront ? -1 : 1));
    B.add('shellPlain', loft([legTop, legTop.clone().lerp(legBot, 0.5), legBot], [sec(0.0019, 0.006, 0.004, 0.0015), sec(0.0016, 0.0046, 0.0032, 0.0013), sec(0.0013, 0.003, 0.002, 0.001)], lod === 0 ? 12 : 6, { up: v3(0, 0, -1), capEnd: true }), undefined, W, 0.001);
    B.add('rubber', prep(new THREE.SphereGeometry(0.0021, lod === 0 ? 10 : 6, lod === 0 ? 8 : 4)), xf(legBot.clone().setY(MINI_DIMS.legBottom + 0.0021)), BLACK);
    // arm LED lens under the housing, facing out of the arm end
    const [name, col] = ledDefs[i]!;
    const h = makeLed(name, col, 0.6);
    leds.push({ handle: h, geometry: prep(ledGeometry(0.0045, 0.0028, 0.0014, lod)).applyMatrix4(xf(v3(mx - sx * 0.002, housingY0 - 0.0002, mz + (isFront ? -0.0065 : 0.0065)), new THREE.Euler(Math.PI, 0, 0))) });
    motors.push(v3(mx, md.y, mz));
  });

  // ---- gimbal mount: damper plate and balls (static), flex cable from the body
  B.add('darkPlastic', box(0.016, 0.0016, 0.007, xf(v3(0, 0.0045, -0.0625))), undefined, lin(0x2a2c30));
  if (lod === 0) for (const [x, z] of [[-0.006, -0.060], [0.006, -0.060], [-0.006, -0.065], [0.006, -0.065]] as const) B.add('rubber', prep(new THREE.SphereGeometry(0.0019, 10, 8)), xf(v3(x, 0.0028, z)), lin(0x2a2a2c));
  B.add('flex', prep(new THREE.BoxGeometry(0.006, 0.0004, 0.012)), xf(v3(0.006, 0.0, -0.0625), new THREE.Euler(0.9, 0, 0)), AMBER);

  // ---- gimbal (3-axis): yaw -> roll -> pitch, each pivot individually accessible
  const Py = v3(0, 0.0015, -0.0655), Pr = v3(0, -0.016, -0.0655), Pp = v3(0, -0.016, -0.0765);
  const yaw = new THREE.Object3D(); yaw.name = 'gimbalYaw'; yaw.position.copy(Py);
  const roll = new THREE.Object3D(); roll.name = 'gimbalRoll'; roll.position.copy(Pr.clone().sub(Py));
  const pitch = new THREE.Object3D(); pitch.name = 'gimbalPitch'; pitch.position.copy(Pp.clone().sub(Pr));
  yaw.add(roll); roll.add(pitch);
  const gs = lod === 0 ? 28 : 10;
  const gim = (parts: THREE.BufferGeometry[], origin: V3): THREE.BufferGeometry => {
    const g = mergeGeometries(parts.map((p) => prep(p)), false)!;
    g.translate(-origin.x, -origin.y, -origin.z);
    return g;
  };
  // yaw: motor disc under the chin and the hanging yaw arm
  const yawParts = [
    paint(cylinder(0.0062, 0.004, gs, Py.y - 0.004), BLACK).applyMatrix4(xf(v3(Py.x, 0, Py.z))),
    paint(lathe([[0.0001, Py.y - 0.0041], [0.0045, Py.y - 0.0041], [0.0046, Py.y - 0.0046], [0.0001, Py.y - 0.0046]], gs), GUN).applyMatrix4(xf(v3(Py.x, 0, Py.z))),
    paint(box(0.009, 0.015, 0.0026, xf(v3(0, -0.0085, -0.0642))), BLACK),
  ];
  // roll: motor disc behind the camera and the side arm out to the pitch motor
  const rollParts = [
    paint(cylinder(0.0058, 0.0035, gs, 0), BLACK).applyMatrix4(xf(Pr.clone().setZ(Pr.z + 0.0005), new THREE.Euler(Math.PI / 2, 0, 0))),
    paint(lathe([[0.0001, 0], [0.004, 0], [0.0041, 0.0004], [0.0001, 0.0004]], gs), GUN).applyMatrix4(xf(Pr.clone().setZ(Pr.z + 0.0005), new THREE.Euler(-Math.PI / 2, 0, 0))),
    paint(box(0.0145, 0.004, 0.003, xf(v3(-0.0072, Pr.y, Pr.z - 0.0005))), BLACK),
    paint(box(0.003, 0.004, 0.0118, xf(v3(-0.0145, Pr.y, Pr.z - 0.0059))), BLACK),
  ];
  // pitch: camera housing, pitch motor disc, lens barrel with ND ring, front element, flex loop
  const camW = 0.022, camH = 0.0175, camD = 0.0185;
  const camParts = [
    paint(prep(new RoundedBoxGeometry(camW, camH, camD, lod === 0 ? 3 : 1, 0.0035)), lin(0x1a1b1d)).applyMatrix4(xf(Pp)),
    paint(cylinder(0.0052, 0.003, gs, 0), BLACK).applyMatrix4(xf(v3(Pp.x - camW / 2 - 0.0015, Pp.y, Pp.z), new THREE.Euler(0, 0, Math.PI / 2))),
    paint(lathe([[0.0001, 0], [0.0037, 0], [0.0038, 0.0004], [0.0001, 0.0004]], gs), GUN).applyMatrix4(xf(v3(Pp.x - camW / 2 - 0.0031, Pp.y, Pp.z), new THREE.Euler(0, 0, Math.PI / 2))),
    // lens barrel (1/2.3" sensor class) with knurled ND filter ring
    paint(lathe([[0.0062, 0], [0.0062, 0.0012], [0.0058, 0.0016], [0.0058, 0.0026], [0.0063, 0.0028], [0.0063, 0.0044], [0.0057, 0.0046], [0.0046, 0.0046]], gs), (p) => (p.y > 0.0027 ? lin(0x2c2e31) : lin(0x111214))).applyMatrix4(xf(v3(Pp.x, Pp.y, Pp.z - camD / 2 + 0.0002), new THREE.Euler(-Math.PI / 2, 0, 0))),
  ];
  if (lod === 0) {
    for (let k = 0; k < 24; k++) {
      const a = (k / 24) * Math.PI * 2;
      camParts.push(paint(box(0.0005, 0.0004, 0.0015), lin(0x3a3c40)).applyMatrix4(xf(v3(Pp.x + Math.cos(a) * 0.0063, Pp.y + Math.sin(a) * 0.0063, Pp.z - camD / 2 - 0.0034), new THREE.Euler(0, 0, a))));
    }
    // flex ribbon from the camera back up into the roll arm
    camParts.push(paint(prep(new THREE.BoxGeometry(0.0055, 0.0003, 0.008)), AMBER).applyMatrix4(xf(v3(0.004, Pp.y + camH / 2 - 0.001, Pp.z + camD / 2 + 0.002), new THREE.Euler(1.2, 0, 0))));
  }
  const lensG = lathe([[0.0001, 0.0049], [0.0024, 0.0048], [0.0038, 0.0045], [0.0046, 0.0041]], lod === 0 ? 32 : 12);
  lensG.applyMatrix4(xf(v3(Pp.x, Pp.y, Pp.z - camD / 2 + 0.0002), new THREE.Euler(-Math.PI / 2, 0, 0)));
  const gm = (g: THREE.BufferGeometry, mat: THREE.Material, name: string): THREE.Mesh => { const m = new THREE.Mesh(g, mat); m.name = name; m.castShadow = true; m.receiveShadow = true; return m; };
  const gYaw = gm(gim(yawParts, Py), M.gimbal!, 'gimbalYawParts');
  const gRoll = gm(gim(rollParts, Pr), M.gimbal!, 'gimbalRollParts');
  const gCam = gm(gim(camParts, Pp), M.gimbal!, 'camera');
  const gLens = gm(gim([paint(lensG, [1, 1, 1])], Pp), M.lens!, 'lens');
  yaw.add(gYaw); roll.add(gRoll); pitch.add(gCam, gLens);
  mass.addPoint(0.03, Pp.clone().add(v3(0, 0.004, 0.004)), v3(0.025, 0.025, 0.025));

  // ---- rotors
  const propBase = lin(0x2b2c2f);
  const alpha = blurAlpha('mini', solidityProfile(MINI_PROP, 0.003));
  const rotors: RotorSpec[] = motors.map((pos, i) => {
    const dir = (spin[i]! > 0 ? 1 : -1) as 1 | -1;
    const blades = propBlades(MINI_PROP, lod, dir, propBase, wear, seed * 13 + i, i * 0.7);
    // CW props carry an accent ring near the root so they are easy to tell apart
    if (dir < 0) paint(blades, (p) => { const r = Math.hypot(p.x, p.z); return r > 0.0105 && r < 0.0125 ? [accent.r, accent.g, accent.b] : propBase; });
    const parts = [blades, propHub(MINI_PROP, lod, propBase, 0.0012)];
    if (lod === 0) for (const s of [-1, 1]) parts.push(panHead(0.0014, lod, STEEL).applyMatrix4(xf(v3(s * 0.0086, MINI_PROP.hubHeight / 2, 0).applyAxisAngle(v3(0, 1, 0), i * 0.7))));
    const sharp = mergeGeometries(parts, false)!;
    // spinning motor bell top below the prop (rotor-local, prop plane at y = 0)
    const top = -0.0105;
    const hub = lathe([[0.0001, top], [0.0088, top], [0.0092, top + 0.0005], [0.0092, top + 0.0035], [0.0086, top + 0.0045], [0.0034, top + 0.0055], [0.0034, -MINI_PROP.hubHeight / 2], [0.0001, -MINI_PROP.hubHeight / 2]], lod === 0 ? 32 : 12);
    paint(hub, GUN);
    mass.addPoint(0.0085, pos.clone().add(v3(0, -0.012, 0)), v3(0.018, 0.016, 0.018));
    return { pos, hub, sharp, blur: blurDisc(0.003, MINI_PROP.radius, lod === 0 ? 64 : 24), blurAlpha: alpha, propColor: new THREE.Color(propBase[0], propBase[1], propBase[2]) };
  });

  const build = assemble({
    name: 'mini', lod, batch: B, materials: M, rotors, spin, hubMat: 'metal', propMat: 'prop',
    gimbal: { root: yaw, pivots: { yaw, pitch, roll }, meshes: [gYaw, gRoll, gCam, gLens] },
    leds, mass, totalMass: 0.249, propRadius: MINI_PROP.radius,
    ao: lod === 0 ? { voxel: 0.0012, maxDist: 0.012, strength: 1.1, rays: 14 } : { voxel: 0.0025, maxDist: 0.014, strength: 1.0, rays: 8 },
  });
  return build;
}

/** Spec entry point: buildDrone(variant, lod) for the mini airframe. */
export function buildDrone(variant: MiniVariant = {}, lod: Lod = 0): DroneBuild {
  return buildMiniDrone(variant, lod);
}
