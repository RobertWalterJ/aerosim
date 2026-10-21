import * as THREE from 'three';

/**
 * Falling snow: one Points object whose flakes live in a box that follows the camera. Each flake's position
 * is computed on the GPU from a fixed random seed and the clock, so there is no per-flake work on the CPU.
 * Flakes drift with the wind and fall faster and thicker in heavy snow.
 */
export class SnowFall {
  readonly points: THREE.Points;
  private u = {
    uCam: { value: new THREE.Vector3() }, uTime: { value: 0 }, uOff: { value: new THREE.Vector3() },
    uBox: { value: new THREE.Vector3(46, 28, 46) }, uDensity: { value: 0 }, uSize: { value: 60 }, uBright: { value: 5 },
  };

  /** count: flakes in the box. renderHeight: pixel height the scene is drawn at (flake size scales with it). */
  constructor(count: number, renderHeight: number) {
    const g = new THREE.BufferGeometry();
    const seed = new Float32Array(count * 4); for (let i = 0; i < seed.length; i++) seed[i] = Math.random();
    g.setAttribute('aSeed', new THREE.BufferAttribute(seed, 4));
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(count * 3), 3)); // unused, but Points needs it
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e9);
    this.u.uSize.value = 60 * renderHeight / 540;
    const m = new THREE.ShaderMaterial({
      uniforms: this.u, transparent: true, depthWrite: false,
      vertexShader: /* glsl */`
        attribute vec4 aSeed; uniform vec3 uCam, uOff, uBox; uniform float uTime, uDensity, uSize; varying float vA;
        void main(){
          vec3 raw = aSeed.xyz * uBox + uOff * (0.8 + 0.4 * aSeed.w);
          raw.x += sin(uTime * 0.9 + aSeed.w * 40.0) * 0.6; raw.z += cos(uTime * 0.7 + aSeed.w * 31.0) * 0.6;
          vec3 local = mod(raw - uCam, uBox) - 0.5 * uBox;
          vec4 mv = viewMatrix * vec4(uCam + local, 1.0);
          float d = -mv.z; float on = step(aSeed.w, uDensity);
          gl_PointSize = on * clamp(uSize * (0.6 + 0.8 * fract(aSeed.w * 13.0)) / max(d, 1.0), 2.5, 14.0);
          vA = on * smoothstep(0.4, 1.6, d) * (1.0 - smoothstep(0.3 * uBox.x, 0.5 * uBox.x, length(local.xz)));
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: /* glsl */`
        uniform float uBright; varying float vA;
        void main(){
          float r = length(gl_PointCoord - 0.5) * 2.0; float a = (1.0 - smoothstep(0.35, 1.0, r)) * vA;
          if (a < 0.02) discard;
          gl_FragColor = vec4(vec3(0.93, 0.96, 1.0) * uBright, a * 0.9);
        }`,
    });
    this.points = new THREE.Points(g, m); this.points.frustumCulled = false; this.points.renderOrder = 10; this.points.visible = false;
  }

  private fall = 1.2;

  /** level: 0 = off, 1 = light, 2 = heavy. */
  setLevel(level: number) {
    this.points.visible = level > 0;
    this.u.uDensity.value = level === 1 ? 0.4 : level >= 2 ? 1 : 0;
    this.fall = level >= 2 ? 2.2 : 1.2;
  }

  /** Call once per frame with the camera position, the frame time and the wind vector (m/s). */
  update(cam: THREE.Vector3, dt: number, wind: ArrayLike<number>) {
    if (!this.points.visible) return;
    this.u.uCam.value.copy(cam); this.u.uTime.value += dt;
    this.u.uOff.value.x += wind[0]! * 0.8 * dt; this.u.uOff.value.z += wind[2]! * 0.8 * dt; this.u.uOff.value.y -= this.fall * dt;
  }
}
