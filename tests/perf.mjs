// Headless performance probe: boot time, draw calls and triangles per quality
// preset, with and without the procedural environment assets.
// Usage: node tests/perf.mjs [baseUrl]   (run `npx vite preview` first)
// Note: headless Chromium uses software GL, so frame rates are not meaningful;
// draw calls, triangles and instance counts are.
import { chromium } from 'playwright-core';
import fs from 'fs';
const base = process.argv[2] || 'http://127.0.0.1:4173/';
const exe = fs.readdirSync('/opt/pw-browsers').filter(d => d.startsWith('chromium-'))[0];
const b = await chromium.launch({ executablePath: `/opt/pw-browsers/${exe}/chrome-linux/chrome`, args: ['--use-angle=swiftshader', '--use-gl=angle', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--no-sandbox'] });
const rows = [];
for (const q of ['low', 'medium', 'high', 'ultra']) for (const env of [0, 1]) {
  const p = await b.newPage({ viewport: { width: 640, height: 360 } });
  const t0 = Date.now();
  await p.goto(`${base}?quality=${q}&env=${env}&w=640&h=360&capture=1&teleport=150,150,-22,-60,-20`, { timeout: 600000 });
  await p.waitForFunction(() => window.__aerosim, null, { timeout: 600000 });
  const boot = (Date.now() - t0) / 1000;
  await p.waitForTimeout(4000);
  const r = await p.evaluate(() => { const a = window.__aerosim; const i = a.renderer.info; i.autoReset = false; i.reset(); const t = performance.now(); a.renderer.render(a.scene, a.camera); const ms = performance.now() - t; const out = { calls: i.render.calls, tris: i.render.triangles, sceneRenderMs: Math.round(ms), geos: i.memory.geometries, tex: i.memory.textures, env: a.envAssets ? a.envAssets.stats : null }; i.autoReset = true; return out; });
  rows.push({ quality: q, env, boot, ...r });
  console.log(JSON.stringify(rows[rows.length - 1]));
  await p.close();
}
await b.close();
