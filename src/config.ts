export interface Airframe {
  id: 'mini' | 'freestyle' | 'race' | 'cinewhoop' | 'cinema';
  name: string;
  mass: number; armD: number;              // armD: motor offset along x and z (X-config)
  I: [number, number, number];             // Ixx (pitch), Iyy (yaw), Izz (roll)
  R: number; sigma: number; a: number; Cd0: number; nBlades: number; Jr: number; kH: number;
  twr: number; omegaMax: number; tauUp: number; tauDown: number; motorEff: number;
  cells: number; capacityAh: number; rInt: number;
  dragCd: [number, number, number]; dragA: [number, number, number]; // body x,y,z
  hasGimbal: boolean; camTilt: number; camOffset: [number, number, number];
  ratesRc: number; ratesSuper: number; ratesExpo: number;
  gain: { rateP: number; rateI: number; rateD: number; yawP: number; attP: number };
  limits: { N: ModeLimits; S: ModeLimits };
}
export interface ModeLimits { vH: number; bank: number; vUp: number; vDown: number; yawRate: number; kv: number; }

export const MINI: Airframe = {
  id: 'mini', name: 'Gimbal Mini (249 g, 3S)',
  mass: 0.249, armD: 0.0675, I: [6.5e-4, 1.2e-3, 6.5e-4],
  R: 0.0585, sigma: 0.13, a: 5.0, Cd0: 0.02, nBlades: 2, Jr: 2.5e-6, kH: 0.01,
  twr: 2.6, omegaMax: 2000, tauUp: 0.045, tauDown: 0.028, motorEff: 0.78,
  cells: 3, capacityAh: 1.3, rInt: 0.06,
  dragCd: [1.0, 1.1, 0.9], dragA: [0.0075, 0.02, 0.011],
  hasGimbal: true, camTilt: 0, camOffset: [0, -0.012, -0.07],
  ratesRc: 0.55, ratesSuper: 0.55, ratesExpo: 0.25,
  gain: { rateP: 24, rateI: 14, rateD: 0.012, yawP: 18, attP: 9 },
  limits: {
    N: { vH: 12, bank: 25 * Math.PI / 180, vUp: 4, vDown: 3, yawRate: 1.2, kv: 2.2 },
    S: { vH: 20, bank: 38 * Math.PI / 180, vUp: 8, vDown: 6, yawRate: 2.0, kv: 1.2 },
  },
};
export const FREESTYLE: Airframe = {
  id: 'freestyle', name: '5-inch Freestyle (750 g, 4S)',
  mass: 0.75, armD: 0.0795, I: [2.6e-3, 4.6e-3, 2.6e-3],
  R: 0.0635, sigma: 0.21, a: 5.0, Cd0: 0.02, nBlades: 3, Jr: 8e-6, kH: 0.01,
  twr: 8, omegaMax: 2900, tauUp: 0.022, tauDown: 0.012, motorEff: 0.8,
  cells: 4, capacityAh: 1.5, rInt: 0.03,
  dragCd: [1.1, 1.2, 1.0], dragA: [0.006, 0.02, 0.009],
  hasGimbal: false, camTilt: 25 * Math.PI / 180, camOffset: [0, 0.01, -0.06],
  ratesRc: 0.9, ratesSuper: 0.72, ratesExpo: 0.2,
  gain: { rateP: 45, rateI: 30, rateD: 0.008, yawP: 35, attP: 10 },
  limits: {
    N: { vH: 14, bank: 25 * Math.PI / 180, vUp: 6, vDown: 4, yawRate: 1.6, kv: 2.6 },
    S: { vH: 25, bank: 38 * Math.PI / 180, vUp: 12, vDown: 8, yawRate: 2.4, kv: 1.4 },
  },
};
export const RACE: Airframe = {
  id: 'race', name: 'Race quad (600 g, 6S)',
  mass: 0.6, armD: 0.0795, I: [2.2e-3, 4.0e-3, 2.2e-3],
  R: 0.0635, sigma: 0.21, a: 5.0, Cd0: 0.02, nBlades: 3, Jr: 8e-6, kH: 0.01,
  twr: 12, omegaMax: 3200, tauUp: 0.015, tauDown: 0.009, motorEff: 0.82,
  cells: 6, capacityAh: 1.1, rInt: 0.025,
  dragCd: [0.9, 1.0, 0.8], dragA: [0.005, 0.016, 0.007],
  hasGimbal: false, camTilt: 35 * Math.PI / 180, camOffset: [0, 0.01, -0.06],
  ratesRc: 0.95, ratesSuper: 0.75, ratesExpo: 0.15,
  gain: { rateP: 50, rateI: 32, rateD: 0.009, yawP: 38, attP: 11 },
  limits: {
    N: { vH: 18, bank: 30 * Math.PI / 180, vUp: 8, vDown: 6, yawRate: 2.0, kv: 2.8 },
    S: { vH: 35, bank: 45 * Math.PI / 180, vUp: 16, vDown: 10, yawRate: 3.0, kv: 1.6 },
  },
};
export const CINEWHOOP: Airframe = {
  id: 'cinewhoop', name: 'Cinewhoop (350 g, 4S, ducted)',
  mass: 0.35, armD: 0.055, I: [1.0e-3, 1.8e-3, 1.0e-3],
  R: 0.038, sigma: 0.35, a: 5.0, Cd0: 0.025, nBlades: 3, Jr: 3e-6, kH: 0.01,
  twr: 3.4, omegaMax: 2600, tauUp: 0.035, tauDown: 0.022, motorEff: 0.72,
  cells: 4, capacityAh: 1.2, rInt: 0.05,
  dragCd: [1.4, 1.5, 1.3], dragA: [0.012, 0.03, 0.016],
  hasGimbal: false, camTilt: 10 * Math.PI / 180, camOffset: [0, 0, -0.06],
  ratesRc: 0.6, ratesSuper: 0.5, ratesExpo: 0.3,
  gain: { rateP: 30, rateI: 18, rateD: 0.010, yawP: 22, attP: 9 },
  limits: {
    N: { vH: 8, bank: 20 * Math.PI / 180, vUp: 3, vDown: 2.5, yawRate: 1.0, kv: 2.4 },
    S: { vH: 14, bank: 32 * Math.PI / 180, vUp: 6, vDown: 4, yawRate: 1.8, kv: 1.4 },
  },
};
export const CINEMA: Airframe = {
  id: 'cinema', name: 'Cinema drone (1.4 kg, 6S, gimbal)',
  mass: 1.4, armD: 0.13, I: [9e-3, 1.6e-2, 9e-3],
  R: 0.12, sigma: 0.11, a: 5.0, Cd0: 0.02, nBlades: 2, Jr: 4e-5, kH: 0.01,
  twr: 2.4, omegaMax: 1500, tauUp: 0.07, tauDown: 0.05, motorEff: 0.8,
  cells: 6, capacityAh: 5, rInt: 0.03,
  dragCd: [1.0, 1.1, 0.9], dragA: [0.02, 0.05, 0.03],
  hasGimbal: true, camTilt: 0, camOffset: [0, -0.03, -0.12],
  ratesRc: 0.45, ratesSuper: 0.4, ratesExpo: 0.3,
  gain: { rateP: 18, rateI: 10, rateD: 0.02, yawP: 14, attP: 7 },
  limits: {
    N: { vH: 14, bank: 25 * Math.PI / 180, vUp: 5, vDown: 3.5, yawRate: 1.0, kv: 2.0 },
    S: { vH: 22, bank: 35 * Math.PI / 180, vUp: 8, vDown: 6, yawRate: 1.6, kv: 1.2 },
  },
};
export const AIRFRAMES = { mini: MINI, freestyle: FREESTYLE, race: RACE, cinewhoop: CINEWHOOP, cinema: CINEMA };
export type AirframeId = keyof typeof AIRFRAMES;

export const WORLD = {
  size: 4000,             // metres, centred on origin
  heightRes: 2048,        // baked heightmap resolution
  homeEast: -20, homeSouth: 40,
  home: { x: -18, z: 36, clearR: 12 },  // take-off pad: no trees, grass or clutter within clearR so the drone can climb straight up
  sunAzimuthDeg: 238, sunElevationDeg: 14,  // grazing late-afternoon sun
  windRefSpeed: 6.5, windRefHeight: 30, windDirDeg: 250, // wind blowing FROM
};

export type Quality = 'low' | 'medium' | 'high' | 'ultra';
export interface QualityPreset {
  renderHeight: number; shadowMap: number; cascades: number; grassNear: number; grassMid: number;
  nearTrees: number; farTrees: number; msaa: number; bloom: boolean;
  env: EnvQuality;
}
/** Procedural environment assets (EnvironmentInstancer) and drone model detail per preset. */
export interface EnvQuality {
  density: number;      // instance count multiplier (meadow, clutter, shrubs, rocks)
  lodScale: number;     // multiplies every LOD switch and cull distance
  variants: number;     // fraction of designed variants used (fewer = fewer draw calls)
  shadows: 'large' | 'all';  // 'large': only walls, fences, hedges, snags, rocks, vehicles cast shadows
  droneLod: 0 | 1;      // chase-camera drone model detail
}
export const QUALITY: Record<Quality, QualityPreset> = {
  low:    { renderHeight: 540,  shadowMap: 1024, cascades: 3, grassNear: 30000,  grassMid: 40000,  nearTrees: 500,  farTrees: 6000,   msaa: 0, bloom: true, env: { density: 0.3, lodScale: 0.6, variants: 0.4, shadows: 'large', droneLod: 1 } },
  medium: { renderHeight: 810,  shadowMap: 2048, cascades: 4, grassNear: 80000,  grassMid: 100000, nearTrees: 1200, farTrees: 25000,  msaa: 2, bloom: true, env: { density: 0.55, lodScale: 0.8, variants: 0.6, shadows: 'large', droneLod: 0 } },
  high:   { renderHeight: 1080, shadowMap: 4096, cascades: 4, grassNear: 120000, grassMid: 150000, nearTrees: 2200, farTrees: 60000,  msaa: 4, bloom: true, env: { density: 0.8, lodScale: 1.0, variants: 0.85, shadows: 'all', droneLod: 0 } },
  ultra:  { renderHeight: 1440, shadowMap: 4096, cascades: 4, grassNear: 200000, grassMid: 250000, nearTrees: 3000, farTrees: 100000, msaa: 4, bloom: true, env: { density: 1.0, lodScale: 1.3, variants: 1.0, shadows: 'all', droneLod: 0 } },
};
