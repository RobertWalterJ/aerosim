// PBR materials for the drone models. Every material uses vertex colors for
// baked AO and per-part tint, so one material serves many parts and the
// static airframe stays within its draw-call budget. Values are documented in
// docs/assets/drones.md.
import * as THREE from 'three';
import { carbonFrame, brushedNormal, knurlNormal, pcbTexture, miniShellTextures, miniDecals, lipoTexture, studioEnv, type CarbonOptions } from './textures';

const phys = (o: THREE.MeshPhysicalMaterialParameters): THREE.MeshPhysicalMaterial => new THREE.MeshPhysicalMaterial({ vertexColors: true, metalness: 0, ...o });

/** Coated optical glass: dark, glossy, iridescent AR coating, studio env reflections (no transmission). */
export function lensMaterial(name: string): THREE.MeshPhysicalMaterial {
  return phys({
    name, color: 0x06070a, roughness: 0.04, clearcoat: 1, clearcoatRoughness: 0.02,
    iridescence: 1, iridescenceIOR: 1.8, iridescenceThicknessRange: [260, 420], envMap: studioEnv(), envMapIntensity: 1.4, specularIntensity: 1,
  });
}

/** Translucent motion-blur disc; one per rotor so each can be faded independently. */
export function blurMaterial(color: THREE.Color, alpha: THREE.Texture, name: string): THREE.MeshStandardMaterial {
  const m = new THREE.MeshStandardMaterial({ name, color, alphaMap: alpha, transparent: true, opacity: 1, depthWrite: false, side: THREE.DoubleSide, roughness: 0.55, metalness: 0 });
  m.userData['baseOpacity'] = 1;
  return m;
}

export interface MiniLook { shell: THREE.Color; accent: THREE.Color; wear: number; seed: number; }

export function miniMaterials(v: MiniLook): Record<string, THREE.Material> {
  const shellTex = miniShellTextures(v.shell, v.wear, v.seed);
  const decals = miniDecals(v.accent, v.seed);
  const brushed = brushedNormal();
  return {
    shell: phys({ name: 'mini-shell', map: shellTex.map, normalMap: shellTex.normalMap, normalScale: new THREE.Vector2(0.6, 0.6), roughness: 0.62, clearcoat: 0.05, clearcoatRoughness: 0.6, sheen: 0.15, sheenRoughness: 0.8 }),
    shellPlain: phys({ name: 'mini-shell-plain', color: v.shell, roughness: 0.6, clearcoat: 0.05, clearcoatRoughness: 0.6 }),
    darkPlastic: phys({ name: 'mini-dark-plastic', roughness: 0.5, clearcoat: 0.25, clearcoatRoughness: 0.4 }),
    gimbal: phys({ name: 'mini-gimbal', roughness: 0.32, clearcoat: 1, clearcoatRoughness: 0.08 }),
    metal: phys({ name: 'mini-metal', metalness: 1, roughness: 0.34, anisotropy: 0.6, normalMap: brushed, normalScale: new THREE.Vector2(0.3, 0.3) }),
    rubber: phys({ name: 'mini-rubber', roughness: 0.88 }),
    sensorGlass: phys({ name: 'mini-sensor-glass', color: 0x08090b, roughness: 0.06, clearcoat: 1, clearcoatRoughness: 0.03, envMap: studioEnv(), envMapIntensity: 1.1 }),
    decals: new THREE.MeshPhysicalMaterial({ name: 'mini-decals', map: decals, alphaTest: 0.5, roughness: 0.45, clearcoat: 0.3, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }),
    flex: phys({ name: 'mini-flex', roughness: 0.35, clearcoat: 0.7, clearcoatRoughness: 0.2 }),
    lens: lensMaterial('mini-lens'),
    prop: phys({ name: 'mini-prop', roughness: 0.38, clearcoat: 0.5, clearcoatRoughness: 0.25 }),
  };
}

export interface FreestyleLook { accent: THREE.Color; wear: number; seed: number; carbon: CarbonOptions; }

export function freestyleMaterials(v: FreestyleLook): Record<string, THREE.Material> {
  const carbon = carbonFrame(v.carbon);
  const brushed = brushedNormal();
  return {
    carbon: phys({
      name: 'fs-carbon', vertexColors: true, map: carbon.map, normalMap: carbon.normalMap, normalScale: new THREE.Vector2(0.5, 0.5), roughnessMap: carbon.roughnessMap, roughness: 1,
      anisotropy: 0.8, anisotropyMap: carbon.anisotropyMap, clearcoat: 0.35, clearcoatRoughness: 0.3,
    }),
    accentAlu: phys({ name: 'fs-anodized-accent', color: v.accent, metalness: 1, roughness: 0.3, anisotropy: 0.7, normalMap: brushed, normalScale: new THREE.Vector2(0.25, 0.25) }),
    bareMetal: phys({ name: 'fs-bare-metal', metalness: 1, roughness: 0.32, anisotropy: 0.4, normalMap: brushed, normalScale: new THREE.Vector2(0.2, 0.2) }),
    blackAnodized: phys({ name: 'fs-black-anodized', color: 0x1b1b1d, metalness: 1, roughness: 0.42 }),
    pcb: phys({ name: 'fs-pcb', map: pcbTexture(v.accent, v.seed), roughness: 0.45, clearcoat: 0.6, clearcoatRoughness: 0.2 }),
    plastic: phys({ name: 'fs-plastic', roughness: 0.5, clearcoat: 0.25, clearcoatRoughness: 0.35 }),
    tpu: phys({ name: 'fs-tpu', color: v.accent, roughness: 0.72, sheen: 0.4, sheenRoughness: 0.7, sheenColor: v.accent }),
    rubber: phys({ name: 'fs-rubber', roughness: 0.85 }),
    lipo: phys({ name: 'fs-lipo', map: lipoTexture(v.accent, v.wear, v.seed), roughness: 0.38, clearcoat: 0.8, clearcoatRoughness: 0.15 }),
    glass: lensMaterial('fs-lens'),
    bell: phys({ name: 'fs-motor-bell', metalness: 1, roughness: 0.3, anisotropy: 0.5, normalMap: knurlNormal(), normalScale: new THREE.Vector2(0.8, 0.8) }),
    prop: phys({ name: 'fs-prop', roughness: 0.32, clearcoat: 0.6, clearcoatRoughness: 0.2 }),
  };
}
