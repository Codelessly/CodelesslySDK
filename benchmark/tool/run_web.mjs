// Opens the built benchmark (build/web, served at baseUrl) in headless
// Chromium and prints its "[bench-result]" line.
//   python3 -m http.server 5200 --directory build/web &
//   node tool/run_web.mjs [baseUrl] [query]
import { createRequire } from 'module';
import { execSync } from 'child_process';

const require = createRequire(import.meta.url);
const { chromium } = require(`${execSync('npm root -g').toString().trim()}/playwright`);
const base = process.argv[2] ?? 'http://localhost:5200/';
const query = process.argv[3] ?? 'seconds=10&speed=30';
const args = ['--no-sandbox', '--enable-gpu-rasterization', '--ignore-gpu-blocklist', '--use-gl=angle', '--use-angle=swiftshader'];
if (process.env.HTTPS_PROXY) args.push(`--proxy-server=${process.env.HTTPS_PROXY}`, '--proxy-bypass-list=localhost;127.0.0.1');
const browser = await chromium.launch({ args });
const page = await browser.newPage({ locale: 'en-US', viewport: { width: 1440, height: 900 } });
const done = new Promise((resolve) => {
  page.on('console', (m) => {
    const t = m.text();
    if (t.startsWith('[bench-result]')) resolve(t);
    else if (m.type() === 'error') console.error(t);
  });
});
page.on('pageerror', (e) => console.error('pageerror', e.message));
await page.goto(`${base}?${query}`);
const line = await Promise.race([done, new Promise((r) => setTimeout(() => r('[bench-result] timeout'), 90000))]);
console.log(line);
await browser.close();
