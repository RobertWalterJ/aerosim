// Drone and vehicle checks for tests/assets.test.ts: triangle counts, draw
// calls, bounding boxes, spec dimensions, rotor/gimbal/LED contract.
import * as THREE from 'three';
import { buildMiniDrone, MINI_DIMS } from '../src/world/drones/MiniDrone';
import { buildFreestyleDrone, FREESTYLE_DIMS } from '../src/world/drones/FreestyleDrone';
import type { DroneBuild } from '../src/world/drones/parts';
import { vehicle, VEHICLE_STYLES } from '../src/world/Vehicles';
import { TRI_BUDGET } from '../src/world/assetkit/AssetCore';
import { buildPilot } from '../src/world/PilotFigure';

const near = (v: number, target: number, tol = 0.03): boolean => Math.abs(v - target) / target <= tol;
const mm = (v: number): string => (v * 1000).toFixed(1);

export async function run(): Promise<number> {
  let fails = 0;
  const fail = (m: string): void => { fails++; console.log('  FAIL ' + m); };

  console.log('\n=== drones (budgets: LOD0 < 40000 tris, LOD1 < 6000 tris, static draw calls < 12)');
  const check = (name: string, b: DroneBuild, lod: 0 | 1, spec: (bb: THREE.Box3, b: DroneBuild) => void): void => {
    b.root.updateMatrixWorld(true);
    const bb = new THREE.Box3().setFromObject(b.root);
    const s = bb.getSize(new THREE.Vector3());
    console.log(`${name} LOD${lod}: ${b.stats.triangles} tris, draw calls static ${b.stats.staticDrawCalls} + rotors/gimbal ${b.stats.dynamicDrawCalls} + LEDs ${b.stats.ledDrawCalls}; bbox ${mm(s.x)} x ${mm(s.y)} x ${mm(s.z)} mm; mass ${(b.physics.massKg * 1000).toFixed(0)} g; COM(design) ${b.physics.comDesign.toArray().map(mm).join(', ')} mm`);
    console.log(`   inertia (kg m2) Ixx ${b.physics.inertia[0].toExponential(2)} Iyy ${b.physics.inertia[1].toExponential(2)} Izz ${b.physics.inertia[2].toExponential(2)}; motors ${b.physics.motorPositions.map((p) => '(' + p.toArray().map(mm).join(',') + ')').join(' ')}`);
    if (b.stats.triangles >= (lod === 0 ? 40000 : 6000)) fail(`${name} LOD${lod}: ${b.stats.triangles} triangles over budget`);
    if (b.stats.staticDrawCalls >= 12) fail(`${name} LOD${lod}: ${b.stats.staticDrawCalls} static draw calls`);
    if (b.rotors.length !== 4) fail(`${name}: rotors.length = ${b.rotors.length}`);
    b.rotors.forEach((r, i) => {
      if (!r.getObjectByName('bladesSharp') || !r.getObjectByName('bladesBlur')) fail(`${name}: rotor ${i} missing bladesSharp/bladesBlur`);
      const blur = r.getObjectByName('bladesBlur') as THREE.Mesh;
      if (!(blur.material as THREE.Material).transparent) fail(`${name}: blur disc ${i} not transparent`);
    });
    // rotor order 0 FR, 1 RR, 2 RL, 3 FL (forward is -Z, right is +X)
    const mp = b.physics.motorPositions;
    const order = [[1, -1], [1, 1], [-1, 1], [-1, -1]];
    order.forEach(([sx, sz], i) => { if (Math.sign(mp[i]!.x) !== sx || Math.sign(mp[i]!.z) !== sz) fail(`${name}: rotor ${i} in the wrong quadrant`); });
    let transparent = 0;
    b.root.traverse((o) => { const m = (o as THREE.Mesh).material as THREE.Material | undefined; if (m && !Array.isArray(m) && m.transparent && o.name !== 'bladesBlur') transparent++; });
    if (transparent) fail(`${name}: ${transparent} transparent meshes besides blur discs`);
    for (const l of b.leds) { l.set(undefined, 9); if (l.intensity !== 6) fail(`${name}: LED ${l.name} intensity not clamped`); l.set(undefined, 1); }
    spec(bb, b);
  };
  for (const lod of [0, 1] as const) {
    const t0 = performance.now();
    const mini = buildMiniDrone({ seed: 3, wear: 0.3 }, lod);
    const t1 = performance.now();
    check('MINI', mini, lod, (_bb, b) => {
      const R = b.physics.propRadius, mp = b.physics.motorPositions;
      const footW = (mp[0]!.x - mp[3]!.x) + 2 * R, footL = (mp[1]!.z - mp[0]!.z) + 2 * R;
      const bb = new THREE.Box3().setFromObject(b.root), H = bb.max.y - bb.min.y;
      console.log(`   flying footprint ${mm(footL)} x ${mm(footW)} mm (spec 290 x 370), height ${mm(H)} mm (spec 62), prop ${mm(2 * R)} mm (3 in)`);
      if (!near(footL, 0.29) || !near(footW, 0.37)) fail('MINI footprint off spec by more than 3 %');
      if (!near(H, 0.062)) fail(`MINI height ${mm(H)} mm off spec`);
      if (!b.gimbal) fail('MINI has no gimbal pivots');
      void MINI_DIMS;
    });
    console.log(`   built in ${(t1 - t0).toFixed(0)} ms`);
    const t2 = performance.now();
    const fs = buildFreestyleDrone({ seed: 3, wear: 0.5, accent: 'lime' }, lod);
    const t3 = performance.now();
    check('FREESTYLE', fs, lod, (_bb, b) => {
      const mp = b.physics.motorPositions, wb = mp[0]!.distanceTo(mp[2]!);
      console.log(`   wheelbase ${mm(wb)} mm (spec 225), prop ${mm(2 * b.physics.propRadius)} mm (5 in)`);
      if (!near(wb, FREESTYLE_DIMS.wheelbase)) fail(`FREESTYLE wheelbase ${mm(wb)} mm off spec`);
      if (!near(2 * b.physics.propRadius, 0.127)) fail('FREESTYLE prop diameter off spec');
    });
    console.log(`   built in ${(t3 - t2).toFixed(0)} ms`);
  }
  for (const a of ['hotPink', 'orange'] as const) buildFreestyleDrone({ accent: a, seed: 9, wear: 1 }, 1);

  console.log('\n=== vehicles (budgets LOD0 < 6000, LOD1 < 1200, LOD2 < 200)');
  VEHICLE_STYLES.forEach((st, i) => {
    const counts = ([0, 1, 2] as const).map((lod) => {
      const v = vehicle(i * 17 + 3, lod, { style: i });
      const t = v.geometry.index!.count / 3;
      if (t > TRI_BUDGET[lod]) fail(`${st.name} LOD${lod}: ${t} tris over budget`);
      if (lod === 0) {
        const s = v.geometry.boundingBox!.getSize(new THREE.Vector3());
        if (!near(s.z, st.L, 0.05) || !near(s.x, st.W, 0.12)) fail(`${st.name}: bbox ${mm(s.x)} x ${mm(s.z)} vs ${mm(st.W)} x ${mm(st.L)}`);
      }
      v.geometry.dispose();
      return t;
    });
    console.log(`${st.name.padEnd(26)} ${String(counts[0]).padStart(5)} ${String(counts[1]).padStart(5)} ${String(counts[2]).padStart(4)}  (${st.region}, ${st.L.toFixed(2)} m)`);
  });
  console.log('\n=== pilot (budgets LOD0 < 8000, LOD1 < 1500 tris, 6 draw calls)');
  for (const lod of [0, 1] as const) {
    const p = buildPilot(lod);
    p.root.updateMatrixWorld(true);
    const bb = new THREE.Box3().setFromObject(p.root), s = bb.getSize(new THREE.Vector3());
    console.log(`pilot LOD${lod}: ${p.triangles} tris, ${p.drawCalls} draw calls, height ${mm(bb.max.y)} mm, width ${mm(s.x)} mm, feet at ${mm(bb.min.y)} mm`);
    if (p.triangles >= (lod === 0 ? 8000 : 1500)) fail(`pilot LOD${lod}: ${p.triangles} tris over budget`);
    if (!near(bb.max.y, 1.8, 0.03)) fail(`pilot height ${mm(bb.max.y)} mm (spec 1800)`);
    if (Math.abs(bb.min.y) > 0.01) fail('pilot feet not on the ground');
    if (p.drawCalls > 6) fail('pilot draw calls');
  }
  // Blender-built pilot (public/models/pilot.glb): size, triangles, skin and the bones the game drives
  const fs = await import('fs');
  const glbPath = new URL('../public/models/pilot.glb', import.meta.url);
  if (!fs.existsSync(glbPath)) fail('public/models/pilot.glb missing');
  else {
    const buf = fs.readFileSync(glbPath); const len = buf.readUInt32LE(12);
    const json = JSON.parse(buf.subarray(20, 20 + len).toString('utf8'));
    let tris = 0; for (const m of json.meshes) for (const pr of m.primitives) tris += (pr.indices !== undefined ? json.accessors[pr.indices].count : json.accessors[pr.attributes.POSITION].count) / 3;
    const bones = (json.nodes as { name: string }[]).map((n) => n.name);
    console.log(`pilot.glb: ${(buf.length / 1048576).toFixed(2)} MB, ${tris} tris, ${json.meshes.length} meshes, ${json.skins?.[0]?.joints?.length ?? 0} joints, ${json.images?.length ?? 0} images`);
    if (buf.length > 4 * 1048576) fail('pilot.glb larger than 4 MB');
    if (tris > 60000) fail('pilot.glb over 60000 triangles');
    for (const b of ['head', 'neck_01']) if (!bones.includes(b)) fail('pilot.glb has no ' + b + ' bone');
    if (!(json.materials as { name: string }[]).some((m) => m.name === 'rc_screen')) fail('pilot.glb has no rc_screen material');
  }
  return fails;
}
