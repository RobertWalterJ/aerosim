// Registry of every procedural environment asset family (used by
// tests/assets.test.ts and EnvironmentInstancer). Each entry builds with
// default options: build(seed, lod) -> { geometry, material, collider? }.
import type { AssetResult, LOD } from './assetkit/AssetCore';
import { meadowClump, MEADOW_VARIANTS } from './MeadowGrass';
import { lawnTuft } from './LawnGrass';
import { hedge, shrub } from './HedgesShrubs';
import { ironFence, ironGate, stoneWall } from './FencesWalls';
import { leafDrift, nutScatter, twigs, fallenBranch, mossPatch, soilPatch } from './GroundClutter';
import { headstone, willowMarker, urnMonument, crossMonument, angelMonument, kerbedPlot, bouquet, graveFlag } from './MemorialDetails';
import { deadTree, snag, hollowStump, rockOutcrop } from './SnagsRocks';

export type { AssetResult, LOD };

export interface AssetEntry {
  name: string;
  family: string;
  build: (seed: number, lod: LOD) => AssetResult;
  /** number of designed variants (seeds 0..n-1 cover them all) */
  variants: number;
  /** intentionally buried below y = 0 by up to this many meters */
  buried?: number;
}

export const ENV_ASSETS: readonly AssetEntry[] = [
  { family: 'meadow', name: 'meadowClump', build: meadowClump, variants: MEADOW_VARIANTS.length },
  { family: 'lawn', name: 'lawnTuft', build: lawnTuft, variants: 8 },
  { family: 'hedges', name: 'hedge', build: hedge, variants: 2 },
  { family: 'hedges', name: 'shrub', build: shrub, variants: 4 },
  { family: 'fences', name: 'ironFence', build: ironFence, variants: 4 },
  { family: 'fences', name: 'ironGate', build: ironGate, variants: 4 },
  { family: 'fences', name: 'stoneWall', build: stoneWall, variants: 4 },
  { family: 'clutter', name: 'leafDrift', build: leafDrift, variants: 4 },
  { family: 'clutter', name: 'nutScatter', build: nutScatter, variants: 3 },
  { family: 'clutter', name: 'twigs', build: twigs, variants: 4 },
  { family: 'clutter', name: 'fallenBranch', build: fallenBranch, variants: 4 },
  { family: 'clutter', name: 'mossPatch', build: mossPatch, variants: 4 },
  { family: 'clutter', name: 'soilPatch', build: soilPatch, variants: 4 },
  { family: 'memorials', name: 'headstone', build: headstone, variants: 8 },
  { family: 'memorials', name: 'willowMarker', build: willowMarker, variants: 4 },
  { family: 'memorials', name: 'urnMonument', build: urnMonument, variants: 4 },
  { family: 'memorials', name: 'crossMonument', build: crossMonument, variants: 3 },
  { family: 'memorials', name: 'angelMonument', build: angelMonument, variants: 3 },
  { family: 'memorials', name: 'kerbedPlot', build: kerbedPlot, variants: 4 },
  { family: 'memorials', name: 'bouquet', build: bouquet, variants: 4 },
  { family: 'memorials', name: 'graveFlag', build: graveFlag, variants: 2 },
  { family: 'snags', name: 'deadTree', build: deadTree, variants: 4 },
  { family: 'snags', name: 'snag', build: snag, variants: 4 },
  { family: 'snags', name: 'hollowStump', build: hollowStump, variants: 4 },
  { family: 'snags', name: 'rockOutcrop', build: rockOutcrop, variants: 4, buried: 2 },
];
