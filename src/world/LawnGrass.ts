// Short mown lawn: color model, tileable ground-detail textures and a
// near-field blade-card tuft for instancing within ~25 m of the camera.
//
// Wind: aSway = height above ground / tuft height (0..1).
import {
  MeshBuilder, TRI_BUDGET, type AssetResult, type LOD, type RGB, v3, mix, tint, smoothstep, ribbon, withinBudget,
} from './assetkit/AssetCore';
import { makeRnd, range, irange, gauss, chance, type Rnd } from './assetkit/AssetRng';
import { solidUV, lawnTextures, LAWN_PALETTE, type LawnPalette, type LawnTextureSet } from './textures/AssetTextures';
import { foliageMaterial } from './assetkit/AssetMaterials';

export { lawnTextures, LAWN_PALETTE };
export type { LawnPalette, LawnTextureSet };

/**
 * Lawn color model. tone 0 = blue-green (shaded, fertile), 1 = yellow-green;
 * drought 0..1 pushes toward straw; returns linear albedo.
 */
export function lawnColor(tone: number, drought: number, rnd: Rnd, pal: LawnPalette = LAWN_PALETTE): RGB {
  let c = mix(pal.blueGreen, pal.yellowGreen, tone);
  c = mix(c, chance(rnd, 0.5) ? pal.drought : pal.straw, drought * range(rnd, 0.6, 1));
  if (chance(rnd, 0.05)) c = mix(c, pal.straw, 0.75); // dead blade
  return tint(c, range(rnd, 0.85, 1.12), range(rnd, -0.03, 0.03));
}

/**
 * Patch of mown grass blades ~0.3 m across, 4-8 cm tall, a few clover
 * leaves at LOD0. Seed picks tone and drought so 8+ seeds give distinct
 * yellow-green / blue-green / drought-yellowed variants.
 */
export function lawnTuft(seed: number, lod: LOD): AssetResult {
  const rnd = makeRnd(seed, 2000);
  const b = new MeshBuilder();
  const uv = solidUV();
  const v = Math.abs(seed) % 8;
  const tone = (v % 4) / 3 * 0.8 + range(rnd, 0, 0.2);
  const drought = v >= 6 ? range(rnd, 0.4, 0.8) : range(rnd, 0, 0.2);
  const size = 0.3, H = range(rnd, 0.04, 0.075);
  const blades = lod === 0 ? irange(rnd, 70, 110) : lod === 1 ? irange(rnd, 30, 45) : 16;
  const segs = lod === 0 ? 3 : lod === 1 ? 2 : 1;
  const wMul = lod === 0 ? 1 : lod === 1 ? 1.6 : 2.6;
  const budget = TRI_BUDGET[lod] - 2;
  for (let i = 0; i < blades; i++) {
    const ok = withinBudget(b, budget, () => {
      const x = range(rnd, -size / 2, size / 2), z = range(rnd, -size / 2, size / 2);
      const az = rnd() * Math.PI * 2;
      const h = H * range(rnd, 0.55, 1.15);
      const tilt0 = range(rnd, 0.05, 0.45), tilt1 = tilt0 + range(rnd, 0.1, 0.8);
      const pts = [v3(x, 0, z)];
      const p = v3(x, 0, z);
      for (let s = 1; s <= segs; s++) {
        const t = (s - 0.5) / segs, tilt = tilt0 + (tilt1 - tilt0) * t;
        p.x += Math.sin(tilt) * Math.cos(az) * (h / segs); p.y += Math.cos(tilt) * (h / segs); p.z += Math.sin(tilt) * Math.sin(az) * (h / segs);
        pts.push(p.clone());
      }
      const c = lawnColor(tone + gauss(rnd) * 0.15, drought, rnd);
      const cut = chance(rnd, 0.7); // mower-cut tips are blunt and slightly bleached
      const w0 = range(rnd, 0.0025, 0.004) * wMul;
      ribbon(b, pts, {
        width: (t) => w0 * (cut ? 1 - t * 0.3 : 1 - t * 0.85),
        side: () => v3(-Math.sin(az), 0, Math.cos(az)),
        twist: gauss(rnd) * 0.8,
        color: (t) => cut ? mix(c, mix(c, LAWN_PALETTE.straw, 0.2), smoothstep(0.8, 1, t)) : c,
        sway: (_t, s) => s / H,
        uv, normalBias: v3(0, 1, 0), normalBiasAmt: 0.6,
      });
    });
    if (!ok) break;
  }
  if (lod === 0) {
    for (let k = 0; k < irange(rnd, 0, 3); k++) {
      const cx = range(rnd, -0.1, 0.1), cz = range(rnd, -0.1, 0.1), y = H * range(rnd, 0.3, 0.7);
      for (let l = 0; l < 3; l++) {
        withinBudget(b, budget, () => {
          const a = rnd() * 0.3 + (l * Math.PI * 2) / 3, r = 0.008;
          const clover = tint(LAWN_PALETTE.clover, range(rnd, 0.9, 1.1));
          const pts = [v3(cx, y, cz), v3(cx + Math.cos(a) * r * 2, y + 0.002, cz + Math.sin(a) * r * 2)];
          ribbon(b, pts, {
            width: (t) => r * 1.8 * Math.sin(Math.PI * (0.15 + t * 0.85)), side: () => v3(-Math.sin(a), 0, Math.cos(a)),
            color: () => clover, sway: () => y / H, uv, normalBias: v3(0, 1, 0), normalBiasAmt: 0.8,
          });
        });
      }
    }
  }
  b.shade({ v: 0, i: 0 }, (p) => 0.45 + 0.55 * smoothstep(0, H, p.y));
  return { geometry: b.build(), material: foliageMaterial() };
}
