// CPU profile of the built benchmark (build with --profile for names):
// self and total time by function over the timed run.
//   node tool/profile_web.mjs [baseUrl] [query] [top]
import { createRequire } from 'module';
import { execSync } from 'child_process';
const require = createRequire(import.meta.url);
const { chromium } = require(`${execSync('npm root -g').toString().trim()}/playwright`);
const base = process.argv[2] ?? 'http://localhost:5201/';
const query = process.argv[3] ?? 'seconds=8&speed=8&bundle=petri_bench_full';
const top = Number(process.argv[4] ?? 45);
const args = ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader'];
if (process.env.HTTPS_PROXY) args.push(`--proxy-server=${process.env.HTTPS_PROXY}`, '--proxy-bypass-list=localhost;127.0.0.1');
const browser = await chromium.launch({ args });
const page = await browser.newPage({ locale: 'en-US', viewport: { width: 1440, height: 900 } });
const cdp = await page.context().newCDPSession(page);
await cdp.send('Profiler.enable');
await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
let started = false;
const done = new Promise((resolve) => page.on('console', async (m) => {
  const t = m.text();
  if (t.startsWith('[bench-result]')) resolve(t);
}));
await page.goto(`${base}?${query}`);
await page.waitForTimeout(3200);
await cdp.send('Profiler.start');
const line = await done;
const { profile } = await cdp.send('Profiler.stop');
console.log(line);
const byId = new Map(profile.nodes.map((n) => [n.id, n]));
const self = new Map(), total = new Map();
const counts = new Map();
for (const s of profile.samples) counts.set(s, (counts.get(s) ?? 0) + 1);
const parent = new Map();
for (const n of profile.nodes) for (const c of n.children ?? []) parent.set(c, n.id);
const name = (n) => `${n.callFrame.functionName || '(anon)'} ${n.callFrame.url.split('/').pop()}:${n.callFrame.lineNumber}`;
let all = 0;
for (const [id, c] of counts) {
  all += c;
  const n = byId.get(id);
  self.set(name(n), (self.get(name(n)) ?? 0) + c);
  const seen = new Set();
  for (let p = id; p != null; p = parent.get(p)) {
    const nm = name(byId.get(p));
    if (seen.has(nm)) continue;
    seen.add(nm);
    total.set(nm, (total.get(nm) ?? 0) + c);
  }
}
const pct = (c) => (100 * c / all).toFixed(1).padStart(5);
console.log('--- total');
for (const [k, v] of [...total].sort((a, b) => b[1] - a[1]).slice(0, top)) console.log(pct(v), k);
console.log('--- self');
for (const [k, v] of [...self].sort((a, b) => b[1] - a[1]).slice(0, 30)) console.log(pct(v), k);
await browser.close();
