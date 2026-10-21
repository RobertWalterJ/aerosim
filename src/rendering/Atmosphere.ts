import * as THREE from 'three';
import { Sky } from 'three/examples/jsm/objects/Sky.js';
import { CSM } from 'three/examples/jsm/csm/CSM.js';
import { WORLD, QualityPreset } from '../config';
import { DEG } from '../util/math';

/** Blackbody colour temperature -> linear RGB (Tanner Helland fit), normalised to max 1. */
export function kelvinToLinearRGB(K: number): THREE.Color {
  const t = K / 100; let r: number, g: number, b: number;
  r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
  g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
  b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
  const c = new THREE.Color(); c.setRGB(Math.min(r, 255) / 255, Math.min(g, 255) / 255, Math.min(b, 255) / 255, THREE.SRGBColorSpace);
  const m = Math.max(c.r, c.g, c.b); c.multiplyScalar(1 / m); return c;
}

/**
 * Sky + sun + cascaded shadows + image-based skylight + analytic height-fog aerial perspective.
 * Photometric intent: direct sun 4000 K (65 klux scale), skylight dome ~8000 K, grazing sun elevation 10-20 deg.
 */
export class Atmosphere {
  sky: Sky; envSky: Sky;
  sunDir = new THREE.Vector3();
  csm: CSM; hemi: THREE.HemisphereLight;
  fog: THREE.Fog;
  sunColor = kelvinToLinearRGB(4000);
  sunIntensity = 10.5;
  elevation = WORLD.sunElevationDeg; azimuth = WORLD.sunAzimuthDeg;
  private pmrem: THREE.PMREMGenerator; private envRT?: THREE.WebGLRenderTarget; private envScene = new THREE.Scene();
  private fogChunkSun = '';

  constructor(private scene: THREE.Scene, private camera: THREE.PerspectiveCamera, private renderer: THREE.WebGLRenderer, q: QualityPreset) {
    this.sky = this.makeSky(true); scene.add(this.sky);
    this.envSky = this.makeSky(false); this.envScene.add(this.envSky);
    this.pmrem = new THREE.PMREMGenerator(renderer);
    // Cascaded shadow maps (practical split scheme)
    this.csm = new CSM({
      maxFar: 700, cascades: q.cascades, mode: 'practical', parent: scene, shadowMapSize: q.shadowMap,
      lightDirection: new THREE.Vector3(-1, -0.3, -1).normalize(), camera, lightIntensity: this.sunIntensity, lightNear: 1, lightFar: 3000, shadowBias: -0.00025,
    });
    this.csm.fade = true;
    this.csm.lights.forEach(l => { l.color.copy(this.sunColor); l.shadow.normalBias = 0.03; l.castShadow = true; });
    this.hemi = new THREE.HemisphereLight(0x000000, 0x7a6a3a, 0.9); // warm ground bounce
    this.hemi.color.setRGB(0, 0, 0); scene.add(this.hemi);
    this.fog = new THREE.Fog(0xa7bdd6, 0.00012, 0.0062); scene.fog = this.fog;
    this.setSun(this.azimuth, this.elevation, true);
  }

  private makeSky(disk: boolean): Sky {
    const sky = new Sky(); sky.scale.setScalar(9000);
    const u = sky.material.uniforms;
    u['turbidity'].value = 2.8; u['rayleigh'].value = 1.9; u['mieCoefficient'].value = 0.0045; u['mieDirectionalG'].value = 0.86;
    sky.material.fragmentShader = sky.material.fragmentShader
      .replace('void main() {', 'uniform float uDisk;\nvoid main() {')
      .replace('L0 += ( vSunE * 19000.0 * Fex ) * sundisk;', 'L0 += ( vSunE * 19000.0 * Fex ) * sundisk * uDisk;');
    u['uDisk'] = { value: disk ? 1 : 0 };
    return sky;
  }

  /** Sun azimuth in compass degrees (0 = N = -z, 90 = E = +x). */
  setSun(azDeg: number, elDeg: number, force = false): void {
    this.azimuth = azDeg; this.elevation = THREE.MathUtils.clamp(elDeg, 4, 40);
    const az = azDeg * DEG, el = this.elevation * DEG;
    this.sunDir.set(Math.sin(az) * Math.cos(el), Math.sin(el), -Math.cos(az) * Math.cos(el)).normalize();
    for (const s of [this.sky, this.envSky]) s.material.uniforms['sunPosition'].value.copy(this.sunDir);
    // lower sun -> warmer & dimmer
    const kel = 3300 + 1200 * THREE.MathUtils.smoothstep(this.elevation, 5, 22);
    this.sunColor = kelvinToLinearRGB(kel);
    const I = this.sunIntensity * (0.55 + 0.45 * THREE.MathUtils.smoothstep(this.elevation, 3, 18));
    this.csm.lightDirection.copy(this.sunDir).negate();
    this.csm.lights.forEach(l => { l.color.copy(this.sunColor); l.intensity = I / this.csm.lights.length * 1.0 * (this.csm.lights.length > 1 ? 1 : 1); });
    this.applyFogChunks();
    if (force || true) this.rebuildEnv();
  }

  private rebuildEnv(): void {
    this.envRT?.dispose();
    this.envRT = this.pmrem.fromScene(this.envScene, 0, 0.1, 20000);
    this.scene.environment = this.envRT.texture; this.scene.environmentIntensity = 1.0;
  }

  /** Patch three's global fog chunks: exponential height fog + forward (Mie) scattering toward the sun. */
  private applyFogChunks(): void {
    const sd = this.sunDir;
    const S = `vec3(${sd.x.toFixed(4)},${sd.y.toFixed(4)},${sd.z.toFixed(4)})`;
    if (this.fogChunkSun === S) return; this.fogChunkSun = S;
    THREE.ShaderChunk.fog_pars_vertex = `#ifdef USE_FOG\nvarying float vFogDepth;\nvarying vec3 vFogWorld;\n#endif`;
    THREE.ShaderChunk.fog_vertex = `#ifdef USE_FOG\nvFogDepth = -mvPosition.z;\nvFogWorld = cameraPosition + transpose(mat3(viewMatrix)) * mvPosition.xyz;\n#endif`;
    THREE.ShaderChunk.fog_pars_fragment = `#ifdef USE_FOG\nuniform vec3 fogColor;\nvarying float vFogDepth;\nvarying vec3 vFogWorld;\nuniform float fogNear;\nuniform float fogFar;\n#endif`;
    THREE.ShaderChunk.fog_fragment = `#ifdef USE_FOG
 { vec3 fv = vFogWorld - cameraPosition; float fd = length(fv); vec3 frd = fv/max(fd,1e-4);
   float ak = fogFar*fv.y; float integ = abs(ak) > 1e-3 ? (1.0-exp(-ak))/ak : 1.0;
   float tau = fogNear * exp(-fogFar*(cameraPosition.y - 70.0)) * fd * integ;
   float ff = 1.0 - exp(-min(tau, 12.0));
   float sunA = pow(max(dot(frd, ${S}), 0.0), 7.0);
   vec3 fcol = fogColor * (1.0 + 2.6*sunA*vec3(1.0,0.60,0.30));
   gl_FragColor.rgb = mix(gl_FragColor.rgb, fcol, ff); }
#endif`;
  }

  /** Mark every program as dirty so the new fog chunk is picked up (call after setSun when scene is populated). */
  refreshMaterials(): void { this.scene.traverse((o: any) => { const m = o.material; if (m) (Array.isArray(m) ? m : [m]).forEach((mm: THREE.Material) => mm.needsUpdate = true); }); }

  update(): void {
    this.camera.updateMatrixWorld();
    this.csm.update();
    this.sky.position.copy(this.camera.position);
    // fog colour follows sun elevation (lower sun -> warmer, darker haze)
    const e = THREE.MathUtils.smoothstep(this.elevation, 4, 30);
    this.fog.color.setRGB(0.34 + 0.06 * e, 0.40 + 0.08 * e, 0.52 + 0.06 * e).multiplyScalar(0.8 + 0.4 * e);
  }
  setSize(): void { this.csm.updateFrustums(); }
}
