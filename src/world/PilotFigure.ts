// The pilot: a man in his late thirties standing at the launch spot with a
// screen-type RC transmitter, head (and, past a limit, his whole body)
// turning to follow the drone. Built procedurally from lathed, tapered and
// deformed primitives with vertex colours; 1.80 m tall, origin between the
// feet on the ground, facing -Z. See docs/assets/pilot.md.
import * as THREE from 'three';
import { mergeGeometries, mergeVertices } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

export interface PilotLook {
  skin?: number; hair?: number; jacket?: number; shirt?: number; jeans?: number; shoes?: number;
}
/** Default look: deep brown skin, short black hair with a low fade, short boxed beard, olive field jacket. */
export const PILOT_LOOK: Required<PilotLook> = {
  skin: 0x5a3828, hair: 0x15110f, jacket: 0x4b5338, shirt: 0x8f8f8a, jeans: 0x283248, shoes: 0xd9d8d2,
};

type MatKey = 'skin' | 'cloth' | 'plastic';
type ColFn = (p: THREE.Vector3, n: THREE.Vector3) => THREE.Color;
const V = (x = 0, y = 0, z = 0): THREE.Vector3 => new THREE.Vector3(x, y, z);
const C = (hex: number): THREE.Color => new THREE.Color(hex);

class Parts {
  geos: Record<MatKey, THREE.BufferGeometry[]> = { skin: [], cloth: [], plastic: [] };
  add(g: THREE.BufferGeometry, key: MatKey, col: THREE.Color | ColFn, m?: THREE.Matrix4): void {
    let geo = g.index ? g.toNonIndexed() : g;
    if (g.index) g.dispose();
    if (m) geo.applyMatrix4(m);
    geo.deleteAttribute('uv');
    const pos = geo.getAttribute('position'), nor = geo.getAttribute('normal');
    const c = new Float32Array(pos.count * 3), p = V(), n = V();
    for (let i = 0; i < pos.count; i++) {
      p.fromBufferAttribute(pos, i); n.fromBufferAttribute(nor, i);
      const k = typeof col === 'function' ? col(p, n) : col;
      c[i * 3] = k.r; c[i * 3 + 1] = k.g; c[i * 3 + 2] = k.b;
    }
    geo.setAttribute('color', new THREE.BufferAttribute(c, 3));
    this.geos[key].push(geo);
  }
  build(mats: Record<MatKey, THREE.Material>): THREE.Mesh {
    const keys = (['skin', 'cloth', 'plastic'] as MatKey[]).filter((k) => this.geos[k].length);
    const merged = keys.map((k) => mergeGeometries(this.geos[k], false)!);
    const g = mergeGeometries(merged, true)!;
    merged.forEach((m) => m.dispose());
    for (const k of keys) this.geos[k].forEach((x) => x.dispose());
    return new THREE.Mesh(g, keys.map((k) => mats[k]));
  }
}

/** tapered tube between a and b (radius r1 at a, r2 at b) with a ball at a */
function limb(P: Parts, a: THREE.Vector3, b: THREE.Vector3, r1: number, r2: number, seg: number, key: MatKey, col: THREE.Color | ColFn, ballA = true): void {
  const d = b.clone().sub(a), len = d.length();
  const g = new THREE.CylinderGeometry(r2, r1, len, seg, 1, true);
  const q = new THREE.Quaternion().setFromUnitVectors(V(0, 1, 0), d.normalize());
  P.add(g, key, col, new THREE.Matrix4().compose(a.clone().lerp(b, 0.5), q, V(1, 1, 1)));
  if (ballA) P.add(new THREE.SphereGeometry(r1, seg, Math.max(4, seg >> 1)), key, col, new THREE.Matrix4().makeTranslation(a.x, a.y, a.z));
}
function ellipsoid(P: Parts, c: THREE.Vector3, r: THREE.Vector3, seg: number, key: MatKey, col: THREE.Color | ColFn, rot?: THREE.Euler): void {
  const m = new THREE.Matrix4().compose(c, new THREE.Quaternion().setFromEuler(rot ?? new THREE.Euler()), r);
  P.add(new THREE.SphereGeometry(1, seg, Math.max(4, seg >> 1)), key, col, m);
}
function rbox(P: Parts, size: THREE.Vector3, m: THREE.Matrix4, key: MatKey, col: THREE.Color | ColFn): void {
  P.add(new THREE.BoxGeometry(size.x, size.y, size.z), key, col, m);
}

/** Head shape in unit-sphere coordinates -> metres (head-local, pivot at the top of the neck). */
function headShape(u: THREE.Vector3, inflate = 0): THREE.Vector3 {
  let { x, y, z } = u;
  // z < 0 is the face. Jaw and chin taper, flatter face, rounder back of the skull.
  const jaw = y < 0 ? 1 - 0.2 * Math.min(1, -y * 1.2) : 1;
  x *= jaw;
  if (z < 0) z *= 0.92 + 0.08 * Math.max(0, y);
  if (z > 0) z *= 1.04;
  if (y < -0.55 && z < 0) z -= 0.06 * (-y - 0.55); // chin forward
  const s = 1 + inflate;
  if (y > 0) y *= 0.95;
  return V(x * 0.079 * s, y * 0.116 * s + 0.085, z * 0.1 * s);
}

/** Sphere shell deformed by headShape, keeping only triangles whose three unit vertices pass keep(). */
function headShell(seg: number, inflate: number, keep: (u: THREE.Vector3) => boolean): THREE.BufferGeometry {
  const s = new THREE.SphereGeometry(1, seg, Math.round(seg * 0.75)).toNonIndexed();
  const pos = s.getAttribute('position');
  const out: number[] = []; const u = [V(), V(), V()];
  for (let i = 0; i < pos.count; i += 3) {
    for (let k = 0; k < 3; k++) u[k]!.fromBufferAttribute(pos, i + k);
    if (!u.every(keep)) continue;
    for (let k = 0; k < 3; k++) { const p = headShape(u[k]!, inflate); out.push(p.x, p.y, p.z); }
  }
  s.dispose();
  const raw = new THREE.BufferGeometry(); raw.setAttribute('position', new THREE.Float32BufferAttribute(out, 3));
  const g = mergeVertices(raw, 1e-5); raw.dispose(); g.computeVertexNormals();
  return g;
}

export interface PilotBuild { root: THREE.Group; body: THREE.Group; head: THREE.Group; triangles: number; drawCalls: number; }

export function buildPilot(lod: 0 | 1 = 0, look: PilotLook = {}): PilotBuild {
  const L = { ...PILOT_LOOK, ...look };
  const skin = C(L.skin), hair = C(L.hair), jacket = C(L.jacket), shirt = C(L.shirt), jeans = C(L.jeans), shoes = C(L.shoes);
  const skinDark = skin.clone().multiplyScalar(0.72), lip = skin.clone().lerp(C(0x3a2220), 0.45);
  const S = lod === 0 ? 14 : 7;
  const mats: Record<MatKey, THREE.Material> = {
    skin: new THREE.MeshPhysicalMaterial({ name: 'pilot-skin', vertexColors: true, roughness: 0.52, sheen: 0.25, sheenRoughness: 0.6, sheenColor: new THREE.Color(0x8a5a40), clearcoat: 0.08, clearcoatRoughness: 0.5 }),
    cloth: new THREE.MeshStandardMaterial({ name: 'pilot-cloth', vertexColors: true, roughness: 0.92 }),
    plastic: new THREE.MeshPhysicalMaterial({ name: 'pilot-plastic', vertexColors: true, roughness: 0.42, clearcoat: 0.4, clearcoatRoughness: 0.3 }),
  };
  const B = new Parts(), H = new Parts();

  // ---- legs (jeans) and shoes; weight slightly on the right leg
  for (const sx of [-1, 1]) {
    const hip = V(0.098 * sx, 0.93, 0), knee = V(0.112 * sx, 0.51, sx > 0 ? -0.012 : 0.01), ankle = V(0.125 * sx, 0.09, sx > 0 ? 0.0 : 0.03);
    limb(B, hip, knee, 0.083, 0.058, S, 'cloth', jeans);
    limb(B, knee, ankle, 0.056, 0.043, S, 'cloth', (p) => (p.y < 0.13 ? jeans.clone().multiplyScalar(0.8) : jeans));
    const toeOut = sx * 0.12;
    ellipsoid(B, V(0.128 * sx, 0.05, ankle.z - 0.06), V(0.052, 0.048, 0.135), S, 'cloth', (p) => (p.y < 0.022 ? C(0x6d6a66) : shoes), new THREE.Euler(0, -toeOut, 0));
  }
  ellipsoid(B, V(0, 0.95, 0.005), V(0.178, 0.105, 0.122), S, 'cloth', jeans); // pelvis

  // ---- torso: open field jacket over a grey t-shirt
  const prof: [number, number][] = [[0.86, 0.19], [0.96, 0.183], [1.1, 0.176], [1.25, 0.192], [1.37, 0.2], [1.45, 0.19], [1.5, 0.15], [1.53, 0.075]];
  const torso = new THREE.LatheGeometry(prof.map(([y, r]) => new THREE.Vector2(r, y)), lod === 0 ? 20 : 9);
  B.add(torso, 'cloth', (p) => {
    const front = p.z < -0.03, gap = 0.032 + 0.03 * Math.max(0, p.y - 1.2) * 3;
    if (front && Math.abs(p.x) < gap && p.y > 0.98) return shirt;
    if (front && Math.abs(p.x) < gap + 0.008 && p.y > 0.98) return jacket.clone().multiplyScalar(0.55); // zip edges
    if (p.y < 0.9) return jacket.clone().multiplyScalar(0.8); // hem band
    return jacket;
  }, new THREE.Matrix4().makeScale(1, 1, 0.64));
  // chest pockets and collar
  for (const sx of [-1, 1]) rbox(B, V(0.085, 0.07, 0.012), new THREE.Matrix4().makeTranslation(0.09 * sx, 1.3, -0.122), 'cloth', jacket.clone().multiplyScalar(0.85));
  B.add(new THREE.TorusGeometry(0.068, 0.02, 6, lod === 0 ? 16 : 8), 'cloth', jacket, new THREE.Matrix4().compose(V(0, 1.525, 0.006), new THREE.Quaternion().setFromEuler(new THREE.Euler(Math.PI / 2 - 0.25, 0, 0)), V(1.08, 1, 1)));
  limb(B, V(0, 1.5, 0.008), V(0, 1.63, 0.012), 0.061, 0.056, S, 'skin', skin, false); // neck

  // ---- transmitter (screen-type RC) held at chest height, tilted up toward the face
  const rcM = new THREE.Matrix4().compose(V(0, 1.1, -0.31), new THREE.Quaternion().setFromEuler(new THREE.Euler(0.95, 0, 0)), V(1, 1, 1));
  const at = (x: number, y: number, z: number): THREE.Vector3 => V(x, y, z).applyMatrix4(rcM);
  const rc = (g: THREE.BufferGeometry, local: THREE.Matrix4, col: THREE.Color | ColFn): void => B.add(g, 'plastic', col, rcM.clone().multiply(local));
  const dark = C(0x232427), screen = C(0x0c1420);
  rc(new THREE.BoxGeometry(0.16, 0.026, 0.1), new THREE.Matrix4(), (_p, n) => (n.y > 0.9 ? dark.clone().multiplyScalar(1.3) : dark));
  rc(new THREE.BoxGeometry(0.118, 0.004, 0.068), new THREE.Matrix4().makeTranslation(0, 0.0145, -0.008), screen);
  for (const sx of [-1, 1]) {
    rc(new THREE.SphereGeometry(1, S, S >> 1), new THREE.Matrix4().compose(V(0.083 * sx, -0.012, 0.022), new THREE.Quaternion(), V(0.024, 0.026, 0.05)), dark);
    if (lod === 0) {
      rc(new THREE.CylinderGeometry(0.006, 0.0075, 0.012, 8), new THREE.Matrix4().makeTranslation(0.066 * sx, 0.018, 0.034), dark.clone().multiplyScalar(0.7));
      rc(new THREE.BoxGeometry(0.014, 0.003, 0.085), new THREE.Matrix4().compose(V(0.05 * sx, 0.04, -0.07), new THREE.Quaternion().setFromEuler(new THREE.Euler(-1.15, 0, sx * 0.12)), V(1, 1, 1)), dark);
    }
  }
  // ---- arms: sleeves to the wrists, hands wrapped round the grips, thumbs on the sticks
  for (const sx of [-1, 1]) {
    const sh = V(0.19 * sx, 1.455, 0.01), el = V(0.215 * sx, 1.185, -0.045), wr = at(0.098 * sx, -0.02, 0.06);
    ellipsoid(B, sh.clone().add(V(-0.012 * sx, -0.01, 0)), V(0.064, 0.058, 0.064), S, 'cloth', jacket);
    limb(B, sh, el, 0.058, 0.05, S, 'cloth', jacket, false);
    limb(B, el, wr, 0.05, 0.041, S, 'cloth', (p) => (p.distanceTo(wr) < 0.03 ? jacket.clone().multiplyScalar(0.7) : jacket));
    ellipsoid(B, at(0.09 * sx, -0.016, 0.03), V(0.028, 0.03, 0.05), S, 'skin', (_p, n) => (n.y < -0.5 ? skin.clone().lerp(C(0x8a6250), 0.25) : skin)); // palm round the grip
    ellipsoid(B, at(0.066 * sx, 0.026, 0.03), V(0.011, 0.01, 0.026), Math.max(6, S >> 1), 'skin', skin, new THREE.Euler(0, sx * 0.5, 0)); // thumb
    if (sx < 0 && lod === 0) B.add(new THREE.TorusGeometry(0.037, 0.006, 5, 12), 'plastic', C(0x1a1a1a), new THREE.Matrix4().compose(wr.clone().lerp(el, 0.12), new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), el.clone().sub(wr).normalize()), V(1, 1, 1)));
  }

  // ---- head (separate group, pivot at the top of the neck). Hair, fade, beard and lips are painted
  // into the skin with smooth masks (no stair-stepped shell edges); thin shells only add volume.
  const hs = lod === 0 ? 32 : 12;
  const g2 = (dx: number, dy: number, sx: number, sy: number): number => Math.exp(-(dx * dx) / sx - (dy * dy) / sy);
  const sm = (a: number, b: number, x: number): number => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  const hairMask = (u: THREE.Vector3): number => sm(0.18, 0.3, u.y + 0.3 * Math.max(0, u.z) - 0.28 * Math.max(0, -u.z) + 0.1 * Math.abs(u.x));
  const fadeMask = (u: THREE.Vector3): number => sm(-0.15, 0.2, u.y) * sm(-0.5, -0.2, u.z) * (1 - sm(0.75, 0.95, -u.z));
  const lipMask = (u: THREE.Vector3): number => g2(u.x, (u.y + 0.39), 0.07, 0.004) * sm(-0.7, -0.85, u.z);
  const beardMask = (u: THREE.Vector3): number => {
    const jaw = sm(-0.08, -0.22, u.y) * sm(0.35, 0.1, u.z);               // lower face and jaw line
    const side = sm(0.78, 0.9, Math.abs(u.x)) * sm(0.15, 0.0, u.y) * sm(0.3, 0.05, u.z) * sm(-0.55, -0.35, u.z); // sideburns
    const cheekClear = 1 - g2(Math.abs(u.x) - 0.45, u.y + 0.08, 0.04, 0.01) * 0.9; // keep the upper cheeks clear
    return Math.max(jaw * cheekClear, side) * (1 - lipMask(u) * 1.6);
  };
  const toUnit = (p: THREE.Vector3): THREE.Vector3 => V(p.x / 0.079, (p.y - 0.085) / 0.116, p.z / 0.1).normalize();
  const beardCol = hair.clone().lerp(skin, 0.12), scalp = skin.clone().lerp(hair, 0.6);
  H.add(headShell(hs, 0, () => true), 'skin', (p) => {
    const u = toUnit(p);
    const eyes = Math.max(g2(u.x - 0.4, u.y - 0.13, 0.03, 0.012), g2(u.x + 0.4, u.y - 0.13, 0.03, 0.012)) * sm(-0.4, -0.7, u.z);
    let c = skin.clone().lerp(skinDark, eyes * 0.7 + sm(-0.6, -0.95, u.y) * 0.5);
    c.lerp(lip, Math.min(1, lipMask(u) * 1.3));
    c.lerp(scalp, fadeMask(u) * 0.85);
    c.lerp(beardCol, Math.max(0, Math.min(1, beardMask(u))));
    c.lerp(hair, hairMask(u));
    return c;
  });
  H.add(headShell(hs, 0.014, (u) => hairMask(u) > 0.97 && u.y > 0.5), 'cloth', hair);           // hair volume on top
  H.add(headShell(hs, 0.018, (u) => beardMask(u) > 0.9 && u.y < -0.3), 'skin', beardCol);       // beard volume
  // nose, ears
  ellipsoid(H, V(0, 0.07, -0.093), V(0.0145, 0.026, 0.018), Math.max(6, hs >> 2), 'skin', skin.clone().lerp(skinDark, 0.55), new THREE.Euler(0.3, 0, 0));
  for (const sx of [-1, 1]) {
    ellipsoid(H, V(0.013 * sx, 0.054, -0.1), V(0.009, 0.0075, 0.009), Math.max(5, hs >> 3), 'skin', skinDark); // nostril wings
    ellipsoid(H, V(0.079 * sx, 0.088, 0.006), V(0.012, 0.03, 0.02), Math.max(6, hs >> 2), 'skin', skinDark.clone().lerp(skin, 0.6));
  }
  if (lod === 0) for (const sx of [-1, 1]) {
    ellipsoid(H, V(0.032 * sx, 0.1, -0.084), V(0.0115, 0.0065, 0.006), 10, 'plastic', C(0xc9c2b6)); // eye white
    ellipsoid(H, V(0.032 * sx, 0.1, -0.0905), V(0.0058, 0.0058, 0.003), 8, 'plastic', C(0x1a0f0a)); // iris
    rbox(H, V(0.028, 0.0045, 0.006), new THREE.Matrix4().compose(V(0.033 * sx, 0.116, -0.0875), new THREE.Quaternion().setFromEuler(new THREE.Euler(0.2, sx * 0.25, sx * -0.12)), V(1, 1, 1)), 'cloth', hair.clone().multiplyScalar(1.4)); // brows
  }

  const root = new THREE.Group(); root.name = 'pilot';
  const body = new THREE.Group(); body.name = 'pilot-body';
  const bodyMesh = B.build(mats); body.add(bodyMesh);
  const head = new THREE.Group(); head.name = 'pilot-head'; head.position.set(0, 1.592, 0.008); head.rotation.order = 'YXZ';
  const headMesh = H.build(mats); head.add(headMesh);
  body.add(head); root.add(body);
  for (const m of [bodyMesh, headMesh]) { m.castShadow = true; m.receiveShadow = true; }
  const tri = (m: THREE.Mesh): number => m.geometry.getAttribute('position').count / 3;
  return { root, body, head, triangles: tri(bodyMesh) + tri(headMesh), drawCalls: (bodyMesh.material as THREE.Material[]).length + (headMesh.material as THREE.Material[]).length };
}

/** The pilot in the world: stands behind the launch point and watches the drone.
 * Starts as the light procedural figure; loadDetailed() swaps in the Blender-built model
 * (public/models/pilot.glb) for close range and keeps the procedural one as the far LOD. */
export class Pilot {
  readonly build: PilotBuild;
  private yaw = 0; private hy = 0; private hp = 0; private idle = Math.random() * 10;
  private lod = new THREE.LOD();
  private detailed: THREE.Object3D | null = null;
  private bones: { neck: THREE.Bone; head: THREE.Bone; neckRest: THREE.Quaternion; headRest: THREE.Quaternion } | null = null;
  private turn = new THREE.Group();
  constructor(lod: 0 | 1 = 0, look?: PilotLook) {
    this.build = buildPilot(lod, look);
    // procedural figure lives inside a turntable group so both LODs share the body yaw
    this.build.root.remove(this.build.body); this.turn.add(this.build.body);
    this.lod.addLevel(this.turn, 0);
    this.build.root.add(this.lod);
  }
  get group(): THREE.Group { return this.build.root; }
  /** Place on the ground at (x, y, z) facing heading h (radians, the simulator's heading convention). */
  place(x: number, y: number, z: number, h: number): void {
    this.build.root.position.set(x, y, z); this.yaw = h; this.hy = 0; this.hp = 0; this.applyYaw();
  }
  /** Load the detailed GLB; resolves false if it is missing (the procedural figure stays). */
  async loadDetailed(url: string, farSwitch = 45): Promise<boolean> {
    try {
      const { GLTFLoader } = await import('three/examples/jsm/loaders/GLTFLoader.js');
      const gltf = await new GLTFLoader().loadAsync(url);
      const model = gltf.scene;
      model.rotation.y = Math.PI; // exported facing +Z; the simulator faces -Z
      const holder = new THREE.Group(); holder.add(model);
      model.traverse((o) => {
        const m = o as THREE.Mesh;
        if (!m.isMesh) return;
        m.castShadow = true; m.receiveShadow = true;
        const mat = m.material as THREE.MeshStandardMaterial;
        const name = (mat.name || '').toLowerCase();
        if (name.includes('body') && mat.map) {
          // skin: a little sheen and soft coat in place of subsurface scattering
          const skin = new THREE.MeshPhysicalMaterial({ name: mat.name, map: mat.map, roughness: 0.52, sheen: 0.35, sheenRoughness: 0.55, sheenColor: new THREE.Color(0x9a6a50), clearcoat: 0.06, clearcoatRoughness: 0.45 });
          m.material = skin;
        } else if (name.startsWith('beard_shell')) {
          mat.side = THREE.FrontSide; mat.roughness = 0.65;
        } else if (name.includes('glasses_acetate')) {
          m.material = new THREE.MeshPhysicalMaterial({ name: mat.name, color: 0xf3eee6, roughness: 0.06, transparent: true, opacity: 0.42, depthWrite: false, clearcoat: 1, clearcoatRoughness: 0.03, specularIntensity: 1 });
        } else if (name.includes('glasses_lens')) {
          m.material = new THREE.MeshPhysicalMaterial({ name: mat.name, color: 0xffffff, roughness: 0.02, transparent: true, opacity: 0.1, depthWrite: false, iridescence: 1, iridescenceIOR: 1.35, iridescenceThicknessRange: [250, 420], specularIntensity: 1 });
          m.renderOrder = 2;
        }
      });
      let neck: THREE.Bone | null = null, head: THREE.Bone | null = null;
      model.traverse((o) => { if ((o as THREE.Bone).isBone) { if (o.name === 'neck_01') neck = o as THREE.Bone; if (o.name === 'head') head = o as THREE.Bone; } });
      if (neck && head) this.bones = { neck, head, neckRest: (neck as THREE.Bone).quaternion.clone(), headRest: (head as THREE.Bone).quaternion.clone() };
      this.detailed = holder;
      // LOD: detailed model near, procedural figure far
      this.lod.levels.length = 0; this.lod.children.length = 0;
      this.lod.addLevel(holder, 0); this.lod.addLevel(this.turn, farSwitch);
      this.applyYaw();
      return true;
    } catch (e) { console.warn('pilot model unavailable, keeping the procedural figure', e); return false; }
  }
  /** the transmitter screen material (for a live camera feed) */
  screenMaterial(): THREE.MeshStandardMaterial | null {
    let found: THREE.MeshStandardMaterial | null = null;
    this.detailed?.traverse((o) => { const m = (o as THREE.Mesh).material as THREE.MeshStandardMaterial | undefined; if (m && !Array.isArray(m) && m.name === 'rc_screen') found = m; });
    return found;
  }
  private applyYaw(): void { this.turn.rotation.y = this.yaw; if (this.detailed) this.detailed.rotation.y = this.yaw; }
  private q = new THREE.Quaternion(); private axis = new THREE.Vector3(); private pq = new THREE.Quaternion();
  /** rotate a bone about a body-space axis on top of its rest orientation */
  private boneTurn(b: THREE.Bone, rest: THREE.Quaternion, yaw: number, pitch: number): void {
    b.parent!.getWorldQuaternion(this.pq).invert();
    const bodyQ = this.q.setFromAxisAngle(this.axis.set(0, 1, 0), this.yaw);
    const up = new THREE.Vector3(0, 1, 0).applyQuaternion(this.pq);
    const right = new THREE.Vector3(1, 0, 0).applyQuaternion(bodyQ).applyQuaternion(this.pq);
    const qy = new THREE.Quaternion().setFromAxisAngle(up, yaw), qp = new THREE.Quaternion().setFromAxisAngle(right, pitch);
    b.quaternion.copy(qy).multiply(qp).multiply(rest);
  }
  /** Turn head (and body past ~55 degrees) toward the drone. */
  update(target: THREE.Vector3, dt: number, camera?: THREE.Camera): void {
    const b = this.build, p = b.root.position;
    const dx = target.x - p.x, dz = target.z - p.z, dy = target.y - (p.y + 1.7);
    const dist = Math.hypot(dx, dz);
    const want = dist > 0.5 ? Math.atan2(-dx, -dz) : this.yaw;
    const wrap = (a: number): number => Math.atan2(Math.sin(a), Math.cos(a));
    let rel = wrap(want - this.yaw);
    if (Math.abs(rel) > 0.95) this.yaw = wrap(this.yaw + Math.sign(rel) * Math.min(Math.abs(rel) - 0.6, 1.4 * dt));
    this.applyYaw();
    rel = wrap(want - this.yaw);
    const k = 1 - Math.exp(-dt * 5);
    this.hy += (Math.max(-1.1, Math.min(1.1, rel)) - this.hy) * k;
    const pitch = Math.atan2(dy, Math.max(dist, 0.3));
    this.hp += (Math.max(-0.35, Math.min(0.85, pitch)) - this.hp) * k;
    this.idle += dt;
    b.head.rotation.y = this.hy; b.head.rotation.x = this.hp;
    b.body.position.y = Math.sin(this.idle * 1.3) * 0.0025;
    if (this.bones && this.detailed) {
      this.detailed.updateMatrixWorld(true);
      // the neck takes 40 % of the turn, the head the rest; pitch is positive up
      this.boneTurn(this.bones.neck, this.bones.neckRest, this.hy * 0.4, this.hp * 0.35);
      this.bones.neck.updateMatrixWorld(true);
      this.boneTurn(this.bones.head, this.bones.headRest, this.hy * 0.6, this.hp * 0.65);
    }
    if (camera) this.lod.update(camera);
  }
}
