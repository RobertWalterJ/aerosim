// Shared materials for the environment asset families. Foliage goes through
// makeFoliageMaterial (wind, rotor downwash, backlit translucency); stone and
// wood reuse the project's makeGranite and makeBark canvas textures.
import * as THREE from 'three';
import { cachedMaterial } from './AssetCore';
import { foliageAtlas } from '../textures/AssetTextures';
import { makeFoliageMaterial } from '../FoliageMaterials';
import { makeGranite, makeBark } from '../ProceduralTextures';

/**
 * Foliage cards and blades carry authored "volume" normals (biased up and
 * away from the plant centre). three.js flips normals on back faces of
 * DoubleSide materials, which turns those back faces black; this lights both
 * faces with the authored normal. Chains any existing onBeforeCompile.
 */
export function withSharedFaceNormals<T extends THREE.Material>(m: T): T {
  const prev = m.onBeforeCompile.bind(m);
  m.onBeforeCompile = (shader, renderer) => {
    prev(shader, renderer);
    shader.fragmentShader = shader.fragmentShader.replace('#include <normal_fragment_begin>',
      THREE.ShaderChunk.normal_fragment_begin.replace('normal *= faceDirection;', ''));
  };
  const prevKey = m.customProgramCacheKey.bind(m);
  m.customProgramCacheKey = () => prevKey() + '|sharedFaceNormals';
  return m;
}

/**
 * Alpha-cutout foliage (grasses, flowers, hedges, fallen leaves, bouquets,
 * flags). instanced = true for InstancedMesh use (the wind shader reads
 * instanceMatrix), false for plain meshes.
 */
export function foliageMaterial(instanced = true): THREE.MeshStandardMaterial {
  return cachedMaterial('foliage:' + instanced, () => {
    const m = makeFoliageMaterial({ map: foliageAtlas(), alphaTest: 0.45, sss: 1.3, tint: '1.0,0.78,0.32', roughness: 0.82, vertexColors: true, instanced, side: THREE.DoubleSide });
    m.name = 'env-foliage';
    return withSharedFaceNormals(m);
  });
}

/**
 * Adds per-vertex polish (attribute aPolish, 0 = honed or weathered, 1 =
 * polished face) to the material's roughness. Chains onBeforeCompile.
 */
export function withPolish(m: THREE.MeshStandardMaterial, polishedRoughness = 0.16): THREE.MeshStandardMaterial {
  const prev = m.onBeforeCompile.bind(m);
  m.onBeforeCompile = (shader, renderer) => {
    prev(shader, renderer);
    shader.vertexShader = 'attribute float aPolish;\nvarying float vPolish;\n' +
      shader.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\n\tvPolish = aPolish;');
    shader.fragmentShader = 'varying float vPolish;\n' +
      shader.fragmentShader.replace('#include <roughnessmap_fragment>',
        `#include <roughnessmap_fragment>\n\troughnessFactor = mix(roughnessFactor, ${polishedRoughness.toFixed(3)}, vPolish);`);
  };
  const prevKey = m.customProgramCacheKey.bind(m);
  m.customProgramCacheKey = () => prevKey() + '|polish';
  return m;
}

/** Granite, marble, fieldstone, rock (project granite texture, uv in meters x 2). */
export function stoneMaterial(): THREE.MeshStandardMaterial {
  return cachedMaterial('stone', () => {
    const g = makeGranite(512, 'grey', 31);
    const m = new THREE.MeshStandardMaterial({ name: 'env-stone', vertexColors: true, map: g.map, normalMap: g.normalMap, roughness: 0.82, metalness: 0 });
    m.normalScale.set(0.45, 0.45);
    // granite map is coloured; keep only its luminance detail by tinting it toward white
    m.color.setScalar(1.25);
    return withPolish(m);
  });
}

/** Dead wood, bark, stumps, twigs (project bark texture). */
export function woodMaterial(): THREE.MeshStandardMaterial {
  return cachedMaterial('wood', () => {
    const b = makeBark(512, 'grey');
    const m = new THREE.MeshStandardMaterial({ name: 'env-wood', vertexColors: true, map: b.map, normalMap: b.normalMap, roughness: 0.92, metalness: 0 });
    m.color.setScalar(1.6);
    return m;
  });
}

/** Painted and rusted wrought iron. Paint and rust are dielectric: metalness 0. */
export function ironMaterial(): THREE.MeshStandardMaterial {
  return cachedMaterial('iron', () => new THREE.MeshStandardMaterial({ name: 'env-iron', vertexColors: true, roughness: 0.7, metalness: 0, side: THREE.DoubleSide }));
}

/** Moss, soil and other ground patches (opaque, polygon offset against the terrain). */
export function groundMaterial(): THREE.MeshStandardMaterial {
  return cachedMaterial('ground', () => new THREE.MeshStandardMaterial({
    name: 'env-ground', vertexColors: true, roughness: 0.97, metalness: 0, polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -2,
  }));
}
