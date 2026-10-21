import { chromium } from 'playwright-core';
import fs from 'fs';
const url = process.argv[2] || 'http://127.0.0.1:5173/?quality=low&w=960&h=540&teleport=0,160,60,150,-15';
const out = process.argv[3] || 'tests/out/shot.png';
const exe = fs.readdirSync('/opt/pw-browsers').filter(d=>d.startsWith('chromium-'))[0];
const b = await chromium.launch({ executablePath: `/opt/pw-browsers/${exe}/chrome-linux/chrome`,
  args:['--use-angle=swiftshader','--use-gl=angle','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--no-sandbox'] });
const p = await b.newPage({ viewport:{width:960,height:540} });
p.on('console', m => { const t=m.text(); if (m.type()==='error'||m.type()==='warning'||/error/i.test(t)) console.log('[console]', m.type(), t.slice(0,1500)); });
p.on('pageerror', e => console.log('[pageerror]', String(e).slice(0,1500)));
await p.goto(url);
try { await p.waitForFunction(()=>window.__aerosim, null, {timeout:150000}); console.log('hook ready'); } catch(e){ console.log('no hook'); }
await p.waitForTimeout(15000);
await p.screenshot({ path: out });
await b.close();
