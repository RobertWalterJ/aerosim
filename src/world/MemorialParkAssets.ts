import * as THREE from 'three';
import { mulberry32 } from '../util/noise';
import { makeGranite, makeInscription, makeClapboard, makeShingles, makeBark, PBRSet } from './ProceduralTextures';
import type { ValleyTerrain } from './ValleyTerrain';
import type { Colliders } from './Colliders';

/** rescale a geometry's UVs to metres so tiled textures keep a constant texel density */
function worldUV(g: THREE.BufferGeometry, tile = 1): THREE.BufferGeometry {
  const p = g.attributes.position, n = g.attributes.normal, uv = new Float32Array(p.count * 2);
  for (let i = 0; i < p.count; i++) {
    const nx = Math.abs(n.getX(i)), ny = Math.abs(n.getY(i)), nz = Math.abs(n.getZ(i));
    if (ny >= nx && ny >= nz) { uv[i * 2] = p.getX(i) / tile; uv[i * 2 + 1] = p.getZ(i) / tile; }
    else if (nx >= nz) { uv[i * 2] = p.getZ(i) / tile; uv[i * 2 + 1] = p.getY(i) / tile; }
    else { uv[i * 2] = p.getX(i) / tile; uv[i * 2 + 1] = p.getY(i) / tile; }
  }
  g.setAttribute('uv', new THREE.BufferAttribute(uv, 2)); return g;
}
function mat(set: PBRSet, rough: number, normalScale = 0.6, extra: { color?: number } = {}): THREE.MeshStandardMaterial {
  const m = new THREE.MeshStandardMaterial({ map: set.map, normalMap: set.normalMap, roughness: rough, metalness: 0, ...extra });
  m.normalScale.set(normalScale, normalScale); return m;
}
const place = (m: THREE.Object3D, x: number, y: number, z: number, ry = 0) => { m.position.set(x, y, z); m.rotation.y = ry; return m; };

export class MemorialParkAssets {
  group = new THREE.Group();
  exclusions: [number, number, number, number][] = [];
  signTargets: THREE.Vector3[] = [];
  monumentPos = new THREE.Vector3(0, 0, 8);
  chapelPos = new THREE.Vector3();
  headstones = 0;

  constructor(private T: ValleyTerrain, private C: Colliders) {
    const rng = mulberry32(555);
    const graniteGrey = makeGranite(512, 'grey', 11), granitePink = makeGranite(512, 'pink', 12), graniteBlack = makeGranite(512, 'black', 13);
    this.memorial(graniteGrey, granitePink);
    this.obelisks(rng, [graniteGrey, graniteBlack, granitePink]);
    this.headstoneFields(rng);
    this.lampsBenchesSigns(rng);
    this.chapel();
    this.gate(graniteGrey);
  }

  private ground(x: number, z: number) { return this.T.height(x, z); }

  private memorial(grey: PBRSet, pink: PBRSet) {
    const [cx, cz] = [this.monumentPos.x, this.monumentPos.z], y0 = this.ground(cx, cz) - 0.1;
    const steps = [[6.0, 0.17], [4.9, 0.17], [3.8, 0.17]];
    const mGrey = mat(grey, 0.62, 0.5), mPink = mat(pink, 0.16, 0.25);
    let y = y0;
    for (const [w, h] of steps) { const g = worldUV(new THREE.BoxGeometry(w, h + 0.1, w).translate(0, h / 2 - 0.05, 0), 1.2); const m = new THREE.Mesh(g, mGrey); place(m, cx, y, cz); m.castShadow = m.receiveShadow = true; this.group.add(m); y += h; }
    // plinth with inscription faces
    const inscr = makeInscription(['IN MEMORY OF', 'THE FALLEN', 'OF THIS PARISH', '', '1914 — 1918', '1939 — 1945'], 256, 512, 'pink', 14);
    const plinth = new THREE.Mesh(worldUV(new THREE.BoxGeometry(2.5, 1.9, 2.5).translate(0, 0.95, 0), 1.2), mat(pink, 0.16, 0.25));
    place(plinth, cx, y, cz); plinth.castShadow = plinth.receiveShadow = true; this.group.add(plinth);
    const faceMat = new THREE.MeshStandardMaterial({ map: inscr.map, normalMap: inscr.normalMap, roughness: 0.2, metalness: 0 }); faceMat.normalScale.set(1.2, 1.2);
    for (let f = 0; f < 4; f++) { const pl = new THREE.Mesh(new THREE.PlaneGeometry(1.5, 1.2), faceMat); pl.position.set(0, 1.0, 1.255); const gr = new THREE.Group(); gr.add(pl); gr.rotation.y = f * Math.PI / 2; place(gr, cx, y, cz, f * Math.PI / 2); gr.children[0].position.set(0, 1.0, 1.255); gr.rotation.y = f * Math.PI / 2; this.group.add(gr); }
    y += 1.9;
    const cap = new THREE.Mesh(worldUV(new THREE.BoxGeometry(2.0, 0.35, 2.0).translate(0, 0.17, 0), 1.2), mPink); place(cap, cx, y, cz); cap.castShadow = true; this.group.add(cap); y += 0.35;
    const H = 7.6, shaftG = new THREE.CylinderGeometry(0.34, 0.62, H, 4, 1).rotateY(Math.PI / 4).translate(0, H / 2, 0); worldUV(shaftG, 1.4);
    const shaft = new THREE.Mesh(shaftG, mPink); place(shaft, cx, y, cz); shaft.castShadow = shaft.receiveShadow = true; this.group.add(shaft);
    const tip = new THREE.Mesh(worldUV(new THREE.ConeGeometry(0.34, 0.8, 4).rotateY(Math.PI / 4).translate(0, 0.4, 0), 1.2), mPink); place(tip, cx, y + H, cz); tip.castShadow = true; this.group.add(tip);
    this.C.addCyl({ x: cx, z: cz, r: 3.0, y0: y0, y1: y0 + 0.55, kind: 'monument' });
    this.C.addCyl({ x: cx, z: cz, r: 1.2, y0: y0, y1: y + H + 0.8, kind: 'monument' });
    this.exclusions.push([cx - 3.4, cz - 3.4, cx + 3.4, cz + 3.4]);
  }

  private obelisks(rng: () => number, grans: PBRSet[]) {
    const spots: [number, number][] = [[-62, -55], [58, -48], [70, 70], [-84, 66], [-30, -80], [28, 96], [-100, -10]];
    spots.forEach(([x, z], i) => {
      const g = grans[i % 3], h = 3.2 + rng() * 2.6, w0 = 0.42 + h * 0.035, y0 = this.ground(x, z) - 0.05;
      const mt = mat(g, i % 3 === 0 ? 0.55 : 0.18, 0.5);
      const parts: THREE.BufferGeometry[] = [
        worldUV(new THREE.BoxGeometry(w0 * 2.7, 0.3, w0 * 2.7).translate(0, 0.15, 0), 1), worldUV(new THREE.BoxGeometry(w0 * 2.1, 0.4, w0 * 2.1).translate(0, 0.5, 0), 1),
        worldUV(new THREE.CylinderGeometry(w0 * 0.55, w0, h, 4).rotateY(Math.PI / 4).translate(0, 0.7 + h / 2, 0), 1.2), worldUV(new THREE.ConeGeometry(w0 * 0.55, w0 * 1.2, 4).rotateY(Math.PI / 4).translate(0, 0.7 + h + w0 * 0.6, 0), 1.2),
      ];
      const m = new THREE.Mesh(mergeGeos(parts), mt); place(m, x, y0, z, rng() * 0.5); m.castShadow = m.receiveShadow = true; this.group.add(m);
      this.C.addCyl({ x, z, r: w0 * 1.1, y0, y1: y0 + h + 1.5, kind: 'monument' }); this.exclusions.push([x - w0 * 1.5, z - w0 * 1.5, x + w0 * 1.5, z + w0 * 1.5]);
    });
  }

  private shapeHeadstone(kind: number, w: number, h: number): THREE.Shape {
    const s = new THREE.Shape();
    if (kind === 0) { s.moveTo(-w / 2, 0); s.lineTo(w / 2, 0); s.lineTo(w / 2, h - w / 2); s.absarc(0, h - w / 2, w / 2, 0, Math.PI, false); s.lineTo(-w / 2, 0); }
    else if (kind === 1) { const c = 0.07; s.moveTo(-w / 2, 0); s.lineTo(w / 2, 0); s.lineTo(w / 2, h - c); s.lineTo(w / 2 - c, h); s.lineTo(-w / 2 + c, h); s.lineTo(-w / 2, h - c); s.lineTo(-w / 2, 0); }
    else if (kind === 2) { s.moveTo(-w / 2, 0); s.lineTo(w / 2, 0); s.lineTo(w / 2, h * 0.72); s.quadraticCurveTo(w * 0.28, h * 0.92, 0, h); s.quadraticCurveTo(-w * 0.28, h * 0.92, -w / 2, h * 0.72); s.lineTo(-w / 2, 0); }
    else { const a = w * 0.17; s.moveTo(-a, 0); s.lineTo(a, 0); s.lineTo(a, h * 0.58); s.lineTo(w / 2, h * 0.58); s.lineTo(w / 2, h * 0.58 + a * 2); s.lineTo(a, h * 0.58 + a * 2); s.lineTo(a, h); s.lineTo(-a, h); s.lineTo(-a, h * 0.58 + a * 2); s.lineTo(-w / 2, h * 0.58 + a * 2); s.lineTo(-w / 2, h * 0.58); s.lineTo(-a, h * 0.58); s.lineTo(-a, 0); }
    return s;
  }

  private headstoneFields(rng: () => number) {
    const defs = [
      { kind: 0, w: 0.62, h: 0.95, hue: 'grey' as const, lines: ['JOHN HENRY', 'WHITMORE', '1841 — 1903', 'AT REST'], rough: 0.5 },
      { kind: 1, w: 0.78, h: 0.7, hue: 'pink' as const, lines: ['ELIZABETH', 'beloved wife', '1856 — 1919'], rough: 0.2 },
      { kind: 2, w: 0.66, h: 1.05, hue: 'black' as const, lines: ['THE FAMILY', 'OF R. CALDER', '1822 — 1894'], rough: 0.14 },
      { kind: 3, w: 0.8, h: 1.2, hue: 'grey' as const, lines: ['MARY ANN', '1867 — 1921', 'PEACE'], rough: 0.55 },
    ];
    const sections: { x0: number; z0: number; x1: number; z1: number; rows: number; face: number }[] = [
      { x0: 24, z0: -88, x1: 102, z1: -26, rows: 0, face: 0 }, { x0: -108, z0: -78, x1: -34, z1: -30, rows: 0, face: 0 },
      { x0: 24, z0: 28, x1: 100, z1: 96, rows: 0, face: Math.PI / 2 }, { x0: -104, z0: 18, x1: -30, z1: 92, rows: 0, face: Math.PI / 2 },
      { x0: -44, z0: -26, x1: -8, z1: 4, rows: 0, face: 0 },
    ];
    const per = defs.map(() => [] as THREE.Matrix4[]);
    for (const s of sections) for (let z = s.z0; z < s.z1; z += 2.9) for (let x = s.x0; x < s.x1; x += 3.1) {
      const px = x + (rng() - 0.5) * 0.35, pz = z + (rng() - 0.5) * 0.3;
      if (rng() < 0.2 || this.T.distToPath(px, pz) < 3.0 || Math.hypot(px - 0, pz - 8) < 15) continue;
      if (this.nearTree(px, pz)) continue;
      const k = Math.floor(rng() * 4), y = this.ground(px, pz) - 0.03 - rng() * 0.03;
      const m = new THREE.Matrix4(), q = new THREE.Quaternion().setFromEuler(new THREE.Euler((rng() - 0.5) * 0.04, s.face + (rng() - 0.5) * 0.08, (rng() - 0.5) * 0.05)); const sc = 0.88 + rng() * 0.28;
      m.compose(new THREE.Vector3(px, y, pz), q, new THREE.Vector3(sc, sc * (0.9 + rng() * 0.2), sc)); per[k].push(m);
      this.C.addCyl({ x: px, z: pz, r: 0.42, y0: y, y1: y + defs[k].h * sc, kind: 'small' });
    }
    defs.forEach((d, k) => {
      const geo = new THREE.ExtrudeGeometry(this.shapeHeadstone(d.kind, d.w, d.h), { depth: 0.13, bevelEnabled: true, bevelThickness: 0.012, bevelSize: 0.012, bevelSegments: 2, curveSegments: 14 });
      geo.translate(0, 0, -0.065); geo.computeVertexNormals();
      // normalised UVs for the inscription face
      const p = geo.attributes.position, n = geo.attributes.normal, uv = new Float32Array(p.count * 2);
      for (let i = 0; i < p.count; i++) { if (Math.abs(n.getZ(i)) > 0.5) { uv[i * 2] = (p.getX(i) + d.w / 2) / d.w; uv[i * 2 + 1] = p.getY(i) / d.h; } else { uv[i * 2] = p.getZ(i) * 3 + 0.3; uv[i * 2 + 1] = p.getY(i) / d.h; } }
      geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
      const ins = makeInscription(d.lines, 256, 512, d.hue, 20 + k);
      const mt = new THREE.MeshStandardMaterial({ map: ins.map, normalMap: ins.normalMap, roughness: d.rough, metalness: 0 }); mt.normalScale.set(1.3, -1.3);
      const im = new THREE.InstancedMesh(geo, mt, Math.max(1, per[k].length)); per[k].forEach((m, i) => im.setMatrixAt(i, m)); im.count = per[k].length;
      im.castShadow = im.receiveShadow = true; im.frustumCulled = false; this.group.add(im); this.headstones += per[k].length;
    });
  }
  private nearTree(x: number, z: number): boolean { const p: number[] = [0, 0, 0]; return this.C.hit(x, 1.0, z, 1.4, p); }

  private lampsBenchesSigns(rng: () => number) {
    const iron = new THREE.MeshStandardMaterial({ color: 0x1c2b22, roughness: 0.42, metalness: 0.85 });
    const pts: [number, number][] = [[2.0, 0.0], [0.34, 0], [0.30, 0.25], [0.2, 0.45], [0.12, 0.9], [0.08, 1.4], [0.075, 3.0], [0.1, 3.18], [0.06, 3.28]];
    const poleG = new THREE.LatheGeometry(pts.map(([r, y]) => new THREE.Vector2(r === 2.0 ? 0.001 : r, y)), 14);
    const lantG = new THREE.CylinderGeometry(0.28, 0.17, 0.5, 6, 1, true).translate(0, 3.55, 0);
    const capG = new THREE.ConeGeometry(0.34, 0.26, 6).translate(0, 3.93, 0);
    const glass = new THREE.MeshStandardMaterial({ color: 0xd9e6d9, roughness: 0.08, metalness: 0, transparent: true, opacity: 0.55, side: THREE.DoubleSide });
    const loop = this.T.polylines[0]; const lamps: THREE.Vector3[] = [], benches: { p: THREE.Vector3; r: number }[] = [];
    let acc = 0, accB = 0;
    for (let i = 1; i < loop.length - 1; i++) {
      const step = Math.hypot(loop[i][0] - loop[i - 1][0], loop[i][1] - loop[i - 1][1]); acc += step; accB += step;
      const tx = loop[i + 1][0] - loop[i - 1][0], tz = loop[i + 1][1] - loop[i - 1][1], L = Math.hypot(tx, tz) || 1, nx = -tz / L, nz = tx / L;
      if (acc > 36) { acc = 0; const x = loop[i][0] + nx * 2.6, z = loop[i][1] + nz * 2.6; if (!this.nearTree(x, z)) lamps.push(new THREE.Vector3(x, this.ground(x, z), z)); }
      if (accB > 58) { accB = 0; const x = loop[i][0] - nx * 2.7, z = loop[i][1] - nz * 2.7; if (!this.nearTree(x, z)) benches.push({ p: new THREE.Vector3(x, this.ground(x, z), z), r: Math.atan2(nx, nz) }); }
    }
    const lampMesh = new THREE.InstancedMesh(poleG, iron, lamps.length), lantMesh = new THREE.InstancedMesh(lantG, glass, lamps.length), capMesh = new THREE.InstancedMesh(capG, iron, lamps.length);
    const m = new THREE.Matrix4();
    lamps.forEach((p, i) => { m.makeTranslation(p.x, p.y - 0.02, p.z); lampMesh.setMatrixAt(i, m); lantMesh.setMatrixAt(i, m); capMesh.setMatrixAt(i, m); this.C.addCyl({ x: p.x, z: p.z, r: 0.12, y0: p.y, y1: p.y + 4.1, kind: 'small' }); });
    for (const im of [lampMesh, lantMesh, capMesh]) { im.castShadow = true; im.frustumCulled = false; this.group.add(im); }
    // benches
    const wood = new THREE.MeshStandardMaterial({ map: makeBark(256, 'brown').map, color: 0x9a6a3a, roughness: 0.8 });
    const seat = new THREE.BoxGeometry(1.7, 0.05, 0.22), parts: THREE.BufferGeometry[] = [];
    for (let k = 0; k < 4; k++) parts.push(seat.clone().translate(0, 0.45, -0.2 + k * 0.1 * 1.6 * 0.5 + 0.0)); 
    for (let k = 0; k < 3; k++) parts.push(new THREE.BoxGeometry(1.7, 0.1, 0.03).rotateX(-0.25).translate(0, 0.62 + k * 0.14, -0.32));
    const benchG = mergeGeos(parts), legG = mergeGeos([new THREE.BoxGeometry(0.05, 0.45, 0.5).translate(-0.8, 0.22, -0.05), new THREE.BoxGeometry(0.05, 0.45, 0.5).translate(0.8, 0.22, -0.05), new THREE.BoxGeometry(0.05, 0.5, 0.04).rotateX(-0.25).translate(-0.8, 0.7, -0.33), new THREE.BoxGeometry(0.05, 0.5, 0.04).rotateX(-0.25).translate(0.8, 0.7, -0.33)]);
    const bm = new THREE.InstancedMesh(benchG, wood, benches.length), lm = new THREE.InstancedMesh(legG, iron, benches.length);
    benches.forEach((b, i) => { m.compose(b.p, new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), b.r), new THREE.Vector3(1, 1, 1)); bm.setMatrixAt(i, m); lm.setMatrixAt(i, m); this.C.addCyl({ x: b.p.x, z: b.p.z, r: 0.9, y0: b.p.y, y1: b.p.y + 0.8, kind: 'small' }); });
    for (const im of [bm, lm]) { im.castShadow = im.receiveShadow = true; im.frustumCulled = false; this.group.add(im); }
    // 2 cm metal signposts
    const signs: { x: number; z: number; text: string; rot: number }[] = [{ x: 7, z: 20, text: 'MEMORIAL →', rot: 0.2 }, { x: -9, z: 4, text: '← LOWER GARDENS', rot: -0.3 }, { x: 132, z: -16, text: 'CHAPEL →', rot: 0.4 }, { x: 95, z: 31, text: '← EAST GATE', rot: 0.1 }, { x: 14, z: -48, text: 'OVERLOOK ↑', rot: 1.5 }];
    const pole = new THREE.CylinderGeometry(0.01, 0.01, 2.4, 8).translate(0, 1.2, 0);
    for (const s of signs) {
      const y = this.ground(s.x, s.z);
      const cv = document.createElement('canvas'); cv.width = 512; cv.height = 128; const c = cv.getContext('2d')!;
      c.fillStyle = '#143d2c'; c.fillRect(0, 0, 512, 128); c.strokeStyle = '#e9ecdf'; c.lineWidth = 6; c.strokeRect(6, 6, 500, 116); c.fillStyle = '#eef0e4'; c.font = 'bold 54px Helvetica, Arial, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(s.text, 256, 68);
      const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
      const plate = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.16, 0.012), [iron, iron, iron, iron, new THREE.MeshStandardMaterial({ map: t, roughness: 0.4, metalness: 0.2 }), new THREE.MeshStandardMaterial({ map: t, roughness: 0.4, metalness: 0.2 })]);
      const g = new THREE.Group(); const pm = new THREE.Mesh(pole, new THREE.MeshStandardMaterial({ color: 0x6e7378, roughness: 0.35, metalness: 0.9 })); plate.position.set(0.33, 2.15, 0.0); g.add(pm, plate);
      pm.castShadow = plate.castShadow = true; place(g, s.x, y, s.z, s.rot); this.group.add(g);
      this.C.addCyl({ x: s.x, z: s.z, r: 0.03, y0: y, y1: y + 2.4, kind: 'small' }); this.signTargets.push(new THREE.Vector3(s.x, y + 2.15, s.z));
    }
  }

  private chapel() {
    const cx = 188, cz = -74, yaw = 0.55; const y0 = this.ground(cx, cz);
    this.chapelPos.set(cx, y0, cz);
    const clap = makeClapboard(512), shingle = makeShingles(512), stone = makeGranite(512, 'grey', 99);
    const wall = mat(clap, 0.78, 0.7), roof = mat(shingle, 0.75, 0.8), found = mat(stone, 0.85, 0.6);
    const trim = new THREE.MeshStandardMaterial({ color: 0xe8e4d8, roughness: 0.7 });
    const glassM = new THREE.MeshStandardMaterial({ color: 0x1d2b3a, roughness: 0.05, metalness: 0.0 });
    const door = new THREE.MeshStandardMaterial({ color: 0x3b1f14, roughness: 0.6 });
    const g = new THREE.Group();
    const W = 7.0, Ln = 11.0, wh = 3.4, ridge = 3.0;
    const fnd = new THREE.Mesh(worldUV(new THREE.BoxGeometry(W + 0.5, 0.9, Ln + 0.5).translate(0, 0.0, 0), 1.0), found); fnd.position.y = 0.0; g.add(fnd);
    const walls = new THREE.Mesh(worldUV(new THREE.BoxGeometry(W, wh, Ln).translate(0, wh / 2 + 0.45, 0), 1.0), wall); g.add(walls);
    // gable ends
    const gs = new THREE.Shape(); gs.moveTo(-W / 2, 0); gs.lineTo(W / 2, 0); gs.lineTo(0, ridge); gs.lineTo(-W / 2, 0);
    for (const sgn of [-1, 1]) { const gg = new THREE.Mesh(worldUV(new THREE.ExtrudeGeometry(gs, { depth: 0.08, bevelEnabled: false }), 1.0), wall); gg.position.set(0, wh + 0.45, sgn * Ln / 2 - (sgn > 0 ? 0 : 0.08)); g.add(gg); }
    // roof planes
    const slope = Math.atan2(ridge, W / 2), rl = Math.hypot(W / 2, ridge) + 0.6;
    for (const sgn of [-1, 1]) { const r = new THREE.Mesh(worldUV(new THREE.BoxGeometry(rl, 0.1, Ln + 1.0), 1.0), roof); r.rotation.z = -sgn * slope; r.position.set(sgn * (W / 4 - 0.1), wh + 0.45 + ridge / 2 + 0.05, 0); g.add(r); }
    // corner trim + windows
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const c = new THREE.Mesh(new THREE.BoxGeometry(0.14, wh, 0.14), trim); c.position.set(sx * W / 2, wh / 2 + 0.45, sz * Ln / 2); g.add(c); }
    const ws = new THREE.Shape(); ws.moveTo(-0.38, 0); ws.lineTo(0.38, 0); ws.lineTo(0.38, 1.4); ws.quadraticCurveTo(0.3, 1.85, 0, 2.0); ws.quadraticCurveTo(-0.3, 1.85, -0.38, 1.4); ws.lineTo(-0.38, 0);
    const winG = new THREE.ShapeGeometry(ws), frameG = new THREE.ExtrudeGeometry(ws, { depth: 0.05, bevelEnabled: false });
    for (const sx of [-1, 1]) for (let i = 0; i < 4; i++) {
      const z = -Ln / 2 + 1.6 + i * 2.6; const frame = new THREE.Mesh(frameG, trim), glass = new THREE.Mesh(winG, glassM);
      frame.scale.set(1.18, 1.08, 1); frame.position.set(sx * (W / 2 + 0.02), 1.15, z); frame.rotation.y = sx * Math.PI / 2; glass.position.set(sx * (W / 2 + 0.065), 1.18, z); glass.rotation.y = sx * Math.PI / 2; g.add(frame, glass);
    }
    // door
    const dg = new THREE.Mesh(new THREE.BoxGeometry(1.5, 2.5, 0.08), door); dg.position.set(0, 1.7, Ln / 2 + 0.01); g.add(dg);
    // bell tower over the front
    const tw = 2.6, th = 3.2; const tower = new THREE.Mesh(worldUV(new THREE.BoxGeometry(tw, th, tw).translate(0, th / 2, 0), 1.0), wall); tower.position.set(0, wh + 0.45 + ridge * 0.6, Ln / 2 - tw / 2 - 0.3); g.add(tower);
    const belf = new THREE.Mesh(worldUV(new THREE.BoxGeometry(tw - 0.4, 1.8, tw - 0.4).translate(0, 0.9, 0), 1.0), wall); belf.position.copy(tower.position).add(new THREE.Vector3(0, th, 0)); g.add(belf);
    const spire = new THREE.Mesh(worldUV(new THREE.ConeGeometry((tw - 0.2) * 0.75, 4.2, 4).rotateY(Math.PI / 4).translate(0, 2.1, 0), 1.0), roof); spire.position.copy(belf.position).add(new THREE.Vector3(0, 1.8, 0)); g.add(spire);
    const crossV = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.8, 0.06), trim), crossH = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.06, 0.06), trim);
    crossV.position.copy(spire.position).add(new THREE.Vector3(0, 4.5, 0)); crossH.position.copy(crossV.position).add(new THREE.Vector3(0, 0.15, 0)); g.add(crossV, crossH);
    g.traverse(o => { if ((o as THREE.Mesh).isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    g.position.set(cx, y0 + 0.45, cz); g.rotation.y = yaw; this.group.add(g);
    // footprint collider approximated by AABB of rotated rect + exclusions
    const ca = Math.cos(yaw), sa = Math.sin(yaw); const ex = (W / 2 + 0.3) * Math.abs(ca) + (Ln / 2 + 0.3) * Math.abs(sa), ez = (W / 2 + 0.3) * Math.abs(sa) + (Ln / 2 + 0.3) * Math.abs(ca);
    this.C.addBox({ x0: cx - ex, z0: cz - ez, x1: cx + ex, z1: cz + ez, y0: y0 - 1, y1: y0 + 14.5, kind: 'building' });
    this.exclusions.push([cx - ex - 0.4, cz - ez - 0.4, cx + ex + 0.4, cz + ez + 0.4]);
    // storage shed
    const sx = 138, sz = -128, sy = this.ground(sx, sz);
    const shed = new THREE.Group();
    shed.add(new THREE.Mesh(worldUV(new THREE.BoxGeometry(3.4, 2.5, 4.6).translate(0, 1.25, 0), 1.0), mat(clap, 0.8, 0.6, { color: 0x6f7f68 })));
    const sr = new THREE.Mesh(worldUV(new THREE.BoxGeometry(3.9, 0.1, 5.2), 1.0), roof); sr.rotation.x = 0.1; sr.position.y = 2.62; shed.add(sr);
    shed.traverse(o => { if ((o as THREE.Mesh).isMesh) { o.castShadow = o.receiveShadow = true; } }); place(shed, sx, sy, sz, -0.3); this.group.add(shed);
    this.C.addBox({ x0: sx - 2.8, z0: sz - 2.8, x1: sx + 2.8, z1: sz + 2.8, y0: sy - 1, y1: sy + 3, kind: 'building' }); this.exclusions.push([sx - 3.2, sz - 3.2, sx + 3.2, sz + 3.2]);
  }

  private gate(grey: PBRSet) {
    const m = mat(grey, 0.6, 0.5), ix = 244, iz = 44;
    for (const dz of [-3.6, 3.6]) {
      const y = this.ground(ix, iz + dz);
      const parts = [worldUV(new THREE.BoxGeometry(1.0, 0.5, 1.0).translate(0, 0.25, 0), 1), worldUV(new THREE.BoxGeometry(0.72, 2.3, 0.72).translate(0, 1.65, 0), 1), worldUV(new THREE.BoxGeometry(0.9, 0.18, 0.9).translate(0, 2.9, 0), 1), worldUV(new THREE.ConeGeometry(0.5, 0.5, 4).rotateY(Math.PI / 4).translate(0, 3.23, 0), 1)];
      const mesh = new THREE.Mesh(mergeGeos(parts), m); mesh.position.set(ix, y, iz + dz); mesh.castShadow = mesh.receiveShadow = true; this.group.add(mesh);
      this.C.addCyl({ x: ix, z: iz + dz, r: 0.55, y0: y, y1: y + 3.5, kind: 'monument' });
    }
  }
}

export function mergeGeos(list: THREE.BufferGeometry[]): THREE.BufferGeometry {
  let nPos = 0, nIdx = 0; const gs = list.map(g => g.index ? g : g.toNonIndexed());
  const hasIdx = list.every(g => g.index);
  const pos: number[] = [], nor: number[] = [], uv: number[] = [], idx: number[] = [];
  let off = 0;
  for (const g of gs) {
    const p = g.attributes.position, n = g.attributes.normal, u = g.attributes.uv;
    for (let i = 0; i < p.count; i++) { pos.push(p.getX(i), p.getY(i), p.getZ(i)); nor.push(n.getX(i), n.getY(i), n.getZ(i)); uv.push(u ? u.getX(i) : 0, u ? u.getY(i) : 0); }
    if (g.index) for (let i = 0; i < g.index.count; i++) idx.push(g.index.getX(i) + off); else for (let i = 0; i < p.count; i++) idx.push(off + i);
    off += p.count; nPos += p.count; nIdx += g.index ? g.index.count : p.count;
  }
  void hasIdx; void nPos; void nIdx;
  const out = new THREE.BufferGeometry(); out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); out.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); out.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); out.setIndex(idx); return out;
}
