// Dev-only asset gallery (not part of the build): /tests/gallery.html#drones | #vehicles | #env
// Optional ?cam=x,y,z,tx,ty,tz&spin=rev_per_s
import * as THREE from 'three';
import { Pilot } from '../src/world/PilotFigure';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { buildMiniDrone } from '../src/world/drones/MiniDrone';
import { buildFreestyleDrone } from '../src/world/drones/FreestyleDrone';
import { vehicle, VEHICLE_STYLES } from '../src/world/Vehicles';
import { ENV_ASSETS } from '../src/world/EnvironmentAssets';

const params = new URLSearchParams(location.search);
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x9fb6cf);
scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 1.0;
const sun = new THREE.DirectionalLight(0xffe2bd, 2.6);
sun.position.set(-4, 3, 2); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
const sc = sun.shadow.camera as THREE.OrthographicCamera; sc.left = -8; sc.right = 8; sc.top = 8; sc.bottom = -8; sun.shadow.bias = -0.0003; sun.shadow.normalBias = 0.002;
scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(80, 80).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x5f6440, roughness: 1 }));
ground.receiveShadow = true; scene.add(ground);
const cam = (params.get('cam') ?? '0.45,0.25,0.55,0,0.04,0').split(',').map(Number);
const camera = new THREE.PerspectiveCamera(40, innerWidth / innerHeight, 0.005, 500);
camera.position.set(cam[0]!, cam[1]!, cam[2]!); camera.lookAt(cam[3]!, cam[4]!, cam[5]!);
const info = document.getElementById('info')!;
const what = location.hash.slice(1) || 'drones';
const t0 = performance.now();
let text = '';
if (what === 'drones') {
  const mini = buildMiniDrone({ seed: 2, wear: 0.25 }, Number(params.get('lod') ?? 0) as 0 | 1);
  mini.root.position.set(-0.22, 0.032, 0); scene.add(mini.root);
  const fs = buildFreestyleDrone({ seed: 2, wear: 0.45, accent: (params.get('accent') as 'lime') ?? 'hotPink' }, Number(params.get('lod') ?? 0) as 0 | 1);
  fs.root.position.set(0.2, 0.06, 0); scene.add(fs.root);
  const rps = Number(params.get('spin') ?? 0);
  for (const b of [mini, fs]) {
    b.rotors.forEach((r, i) => {
      r.rotation.y = i * 0.9;
      const blur = r.getObjectByName('bladesBlur') as THREE.Mesh, sharp = r.getObjectByName('bladesSharp')!;
      if (rps > 20) { blur.visible = true; (blur.material as THREE.MeshStandardMaterial).opacity = 1; sharp.visible = false; }
    });
    for (const l of b.leds) l.set(undefined, 3);
    if (b.gimbal) b.gimbal.pitch.rotation.x = Number(params.get('gp') ?? -0.25);
  }
  text = `mini ${mini.stats.triangles} tris, freestyle ${fs.stats.triangles} tris`;
} else if (what === 'pilot') {
  const lod = Number(params.get('lod') ?? 0) as 0 | 1;
  const pl = new Pilot(lod); scene.add(pl.group);
  pl.place(0, 0, 0, Number(params.get('h') ?? 0));
  const tgt = (params.get('look') ?? '0,6,-12').split(',').map(Number);
  for (let i = 0; i < 60; i++) pl.update(new THREE.Vector3(tgt[0], tgt[1], tgt[2]), 0.1);
  text = `pilot LOD${lod} ${pl.build.triangles} tris, ${pl.build.drawCalls} draw calls`;
} else if (what === 'vehicles') {
  VEHICLE_STYLES.forEach((s, i) => {
    const v = vehicle(i * 17 + 3, Number(params.get('lod') ?? 0) as 0 | 1 | 2, { style: i });
    const m = new THREE.Mesh(v.geometry, v.material);
    m.position.set((i % 5) * 2.6 - 5.2, 0, Math.floor(i / 5) * 6.5 - 3.2); m.rotation.y = 0.5;
    scene.add(m);
    void s;
  });
  text = 'vehicles';
} else {
  ENV_ASSETS.forEach((a, i) => {
    const r = a.build(1, 0);
    const m = new THREE.Mesh(r.geometry, r.material);
    m.position.set((i % 6) * 3 - 7.5, 0, Math.floor(i / 6) * 3 - 6);
    scene.add(m);
  });
  text = 'env assets';
}
scene.traverse((o) => { if ((o as THREE.Mesh).isMesh && o !== ground) { o.castShadow = true; o.receiveShadow = true; } });
renderer.render(scene, camera);
info.textContent = `${what} | ${text} | ${(performance.now() - t0).toFixed(0)} ms`;
(window as unknown as { __aerosim: boolean }).__aerosim = true;
