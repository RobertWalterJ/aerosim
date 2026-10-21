import * as THREE from 'three';

/** Uniforms shared by every wind-animated / rotor-washed / backlit surface. */
export const FoliageUniforms = {
  uTime: { value: 0 },
  uWind: { value: new THREE.Vector3(2, 0, 1) },       // canopy-level wind (m/s)
  uDrone: { value: new THREE.Vector4(0, -999, 0, 3.5) }, // xyz drone position, w = downwash radius
  uWash: { value: 0 },                                  // downwash strength 0..1
};

/**
 * Backlit two-sided transmission. Spec: pow(max(0, dot(-V, L)), 4) * warm chartreuse/gold transmission.
 * Injected into the directional-light loop so CSM shadowing is already applied to directLight.color.
 */
export function patchSSS(sh: any, tint: string, strength = 1.0): void {
  const chunk: string = THREE.ShaderChunk.lights_fragment_begin;
  const a = chunk.indexOf('NUM_DIR_LIGHTS > 0');
  const b = chunk.indexOf('NUM_RECT_AREA_LIGHTS', a);
  if (a < 0 || b < 0) return;
  const patched = chunk.slice(0, a) + chunk.slice(a, b).split('RE_Direct( directLight').join('RE_Direct_F( directLight') + chunk.slice(b);
  const FN = `
vec3 gFoliage = vec3(0.0);
void RE_Direct_F( const in IncidentLight dl, const in vec3 gp, const in vec3 gn, const in vec3 gv, const in vec3 gc, const in PhysicalMaterial m, inout ReflectedLight rl ) {
  gFoliage += dl.color * ( 0.75 * pow( max( 0.0, dot( -gv, dl.direction ) ), 4.0 ) + 0.35 * max( 0.0, dot( -gn, dl.direction ) ) );
  RE_Direct_Physical( dl, gp, gn, gv, gc, m, rl );
}`;
  sh.fragmentShader = sh.fragmentShader
    .replace('#include <lights_physical_pars_fragment>', '#include <lights_physical_pars_fragment>\n' + FN)
    .replace('#include <lights_fragment_begin>', patched)
    .replace('#include <lights_fragment_end>', `#include <lights_fragment_end>\nreflectedLight.directDiffuse += gFoliage * diffuseColor.rgb * ${tint} * ${strength.toFixed(3)} * 0.55;`);
}

const WIND_VERT = /* glsl */`
uniform float uTime; uniform vec3 uWind; uniform vec4 uDrone; uniform float uWash;
attribute vec3 aWind; // x: phase, y: branch flex, z: leaf flutter
vec3 foliageDisp(vec3 wp, vec3 local){
  float s = length(uWind.xz) + 0.4;
  vec2 d = normalize(uWind.xz + vec2(0.001));
  float gust = 0.55 + 0.45*sin(dot(wp.xz, d)*0.045 - uTime*0.9*(0.6+0.1*s) + 0.7*sin(wp.x*0.013 + uTime*0.21));
  float h = max(local.y, 0.0);
  // 1: trunk sway (0.3 Hz) ~ height^2, 2: branch (1.1 Hz), 3: leaf flutter (4.5 Hz)
  float t1 = sin(uTime*1.9 + wp.x*0.13 + wp.z*0.09) * h*h * 0.00075 * s * gust;
  float t2 = sin(uTime*6.8 + aWind.x*6.28 + wp.x*0.5) * aWind.y * 0.07 * s * gust;
  float t3 = sin(uTime*28.0 + aWind.x*40.0 + wp.z*3.0) * aWind.z * 0.025 * (0.3 + s*0.35) * gust;
  vec3 disp = vec3(d.x, 0.0, d.y) * (t1 * 2.0 + t2 * 1.2) + vec3(t3, t3*0.7, -t3);
  disp.y += (t2 + t3) * 0.2;
  // rotor-downwash: radial push and flatten inside the 3.5 m sphere
  vec3 rv = wp - uDrone.xyz; float rd = length(rv);
  float wk = smoothstep(uDrone.w, 0.2, rd) * uWash;
  disp += (normalize(vec3(rv.x, 0.0, rv.z) + 1e-4) * 0.5 + vec3(0.0,-0.35,0.0)) * wk * (0.25 + aWind.y + aWind.z*0.6);
  return disp;
}`;

/** Wind sway + downwash for instanced meshes whose instances are yawed/uniformly scaled. */
export function patchWind(sh: any, instanced: boolean): void {
  sh.uniforms.uTime = FoliageUniforms.uTime; sh.uniforms.uWind = FoliageUniforms.uWind; sh.uniforms.uDrone = FoliageUniforms.uDrone; sh.uniforms.uWash = FoliageUniforms.uWash;
  sh.vertexShader = sh.vertexShader
    .replace('#include <common>', '#include <common>\n' + WIND_VERT)
    .replace('#include <begin_vertex>', instanced ? `#include <begin_vertex>
{ mat4 im = instanceMatrix; vec3 wp = (modelMatrix * im * vec4(transformed, 1.0)).xyz; vec3 wd = foliageDisp(wp, transformed * 1.0);
  mat3 r3 = mat3(im); float sc2 = max(dot(r3[0], r3[0]), 1e-4); transformed += (transpose(r3) * wd) / sc2; }` : `#include <begin_vertex>
{ vec3 wp = (modelMatrix * vec4(transformed, 1.0)).xyz; transformed += foliageDisp(wp, transformed); }`);
}

export interface FoliageMatOpts { map?: THREE.Texture; normalMap?: THREE.Texture; alphaTest?: number; tint?: string; sss?: number; wind?: boolean; instanced?: boolean; roughness?: number; vertexColors?: boolean; side?: THREE.Side }
export function makeFoliageMaterial(o: FoliageMatOpts): THREE.MeshStandardMaterial {
  const m = new THREE.MeshStandardMaterial({
    map: o.map, ...(o.normalMap ? { normalMap: o.normalMap } : {}), alphaTest: o.alphaTest ?? 0, side: o.side ?? THREE.DoubleSide, roughness: o.roughness ?? 0.72, metalness: 0,
    vertexColors: o.vertexColors ?? true, transparent: false,
  });
  m.onBeforeCompile = (sh) => {
    if (o.wind !== false) patchWind(sh, o.instanced !== false);
    if (o.sss) patchSSS(sh, `vec3(${o.tint ?? '0.62,0.78,0.12'})`, o.sss);
  };
  // custom depth for alpha-tested + wind-moved shadow casters
  if (o.map && o.alphaTest) {
    const dm = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: o.map, alphaTest: o.alphaTest });
    dm.onBeforeCompile = (sh) => { if (o.wind !== false) patchWind(sh, o.instanced !== false); };
    (m as any).customDepthMaterial = dm;
  }
  return m;
}
