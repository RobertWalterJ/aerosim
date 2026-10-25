// Dev helper: screenshot the asset gallery. node tests/gshot.mjs "<query+hash>" out.png
import { chromium } from 'playwright-core';
import fs from 'fs';
const q = process.argv[2] || '#drones';
const out = process.argv[3] || 'tests/out/gallery.png';
const exe = fs.readdirSync('/opt/pw-browsers').filter(d=>d.startsWith('chromium-'))[0];
const b = await chromium.launch({ executablePath: `/opt/pw-browsers/${exe}/chrome-linux/chrome`, args:['--use-angle=swiftshader','--use-gl=angle','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--no-sandbox'] });
const p = await b.newPage({ viewport:{width:1100,height:700} });
p.on('pageerror', e => console.log('[pageerror]', String(e).slice(0,800)));
p.on('console', m => { if (m.type()==='error') console.log('[console]', m.text().slice(0,400)); });
await p.goto('http://127.0.0.1:5173/tests/gallery.html' + q, { waitUntil: 'commit', timeout: 300000 });
await p.waitForFunction(()=>window.__aerosim === true, null, {timeout:300000});
await p.waitForTimeout(500);
console.log(await p.textContent('#info'));
await p.screenshot({ path: out, timeout: 300000 });
await b.close();
