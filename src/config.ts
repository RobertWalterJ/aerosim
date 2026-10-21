export interface Airframe {
  id: 'mini' | 'freestyle';
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
export const AIRFRAMES = { mini: MINI, freestyle: FREESTYLE };

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
}
export const QUALITY: Record<Quality, QualityPreset> = {
  low:    { renderHeight: 540,  shadowMap: 1024, cascades: 3, grassNear: 30000,  grassMid: 40000,  nearTrees: 500,  farTrees: 6000,   msaa: 0, bloom: true },
  medium: { renderHeight: 810,  shadowMap: 2048, cascades: 4, grassNear: 80000,  grassMid: 100000, nearTrees: 1200, farTrees: 25000,  msaa: 2, bloom: true },
  high:   { renderHeight: 1080, shadowMap: 4096, cascades: 4, grassNear: 120000, grassMid: 150000, nearTrees: 2200, farTrees: 60000,  msaa: 4, bloom: true },
  ultra:  { renderHeight: 1440, shadowMap: 4096, cascades: 4, grassNear: 200000, grassMid: 250000, nearTrees: 3000, farTrees: 100000, msaa: 4, bloom: true },
};
