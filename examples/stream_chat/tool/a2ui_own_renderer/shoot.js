const {chromium} = require('playwright'); const fs = require('fs'); const path = require('path');
const D = process.argv[2], O = process.argv[3];
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({viewport: {width: 390, height: 700}, deviceScaleFactor: 1});
  const logs = []; p.on('console', (m) => { if (m.type() === 'error') logs.push(m.text().slice(0, 200)); });
  p.on('pageerror', (e) => logs.push('pageerror ' + String(e).slice(0, 200)));
  await p.goto('file://' + path.resolve('index.html'));
  const out = {};
  for (const f of fs.readdirSync(D).filter((f) => f.endsWith('.a2ui.jsonl')).sort()) {
    const cell = f.replace('.a2ui.jsonl', '');
    // The model's last answer: the retry's when there was one.
    let src = f; const retry = cell + '.a2ui.retry1.jsonl'; if (fs.existsSync(path.join(D, retry))) src = retry;
    const meta = JSON.parse(fs.readFileSync(path.join(D, src), 'utf8').split('\n')[0]).meta;
    const messages = []; let bad = 0;
    for (const line of meta.text.split('\n')) { const t = line.trim(); if (!t.startsWith('{')) continue; try { messages.push(JSON.parse(t)); } catch (e) { bad++; } }
    logs.length = 0;
    const asWritten = await p.evaluate((m) => window.renderA2ui(m), messages);
    // The published v1.0 schemas spell a component's checks and accessibility with an @; this renderer release
    // reads them without. Renamed for a second try, and counted.
    const renamed = new Set();
    const strip = (v, top) => {
      if (Array.isArray(v)) return v.map((x) => strip(x, top));
      if (v && typeof v === 'object') {
        const o = {};
        for (const [k, x] of Object.entries(v)) {
          if (top && (k === '@checks' || k === '@accessibility')) { renamed.add(k); o[k.slice(1)] = strip(x, false); }
          else o[k] = strip(x, k === 'components');
        }
        return o;
      }
      return v;
    };
    const fixed = messages.map((m) => strip(m, false));
    const r = renamed.size ? await p.evaluate((m) => window.renderA2ui(m), fixed) : asWritten;
    await p.screenshot({path: path.join(O, cell + '.png'), fullPage: true});
    out[cell] = {...r, asWrittenErrors: asWritten.errors, asWrittenElements: asWritten.elements, renamed: [...renamed],
                 messages: messages.length, badLines: bad, console: logs.slice(0, 4), source: src};
  }
  fs.writeFileSync(path.join(O, 'results.json'), JSON.stringify(out, null, 1));
  await b.close();
})();
