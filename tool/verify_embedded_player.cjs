// Provider-fixture transport test. No remote playback or certificate changes.
// Build from v2/example:
// flutter build web --release --no-web-resources-cdn --no-wasm-dry-run \
//   -t ../test/browser/embedded_player_fixture.dart
// Serve example/build/web, then PLAYWRIGHT_MODULE=/path/to/playwright \
//   node v2/tool/verify_embedded_player.cjs http://127.0.0.1:5194/
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');const assert=require('assert/strict');
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROME_EXECUTABLE||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--single-process','--no-zygote','--enable-unsafe-swiftshader']});const page=await browser.newPage();const base=process.argv[2]||'http://127.0.0.1:5194/';
const errors=[];page.on('pageerror',e=>errors.push(e.message));let loads=0;await page.route('https://www.youtube.com/embed/**',async route=>{loads++;await route.fulfill({contentType:'text/html',body:`<!doctype html><script>window.received=[];addEventListener('message',event=>{try{received.push(JSON.parse(event.data));}catch(_){}});</script>`});});
await page.goto(base);await page.waitForSelector('iframe');const frame=page.frames().find(f=>f.url().startsWith('https://www.youtube.com/embed/'));assert(frame,'iframe should be a real platform view');await page.waitForTimeout(600);
const controls=async()=>await frame.evaluate(()=>received.filter(m=>m.event==='command'));
assert.deepEqual(await controls(),[]);
await page.evaluate(()=>dispatchEvent(new MessageEvent('message',{origin:'https://www.youtube.com',source:window,data:JSON.stringify({event:'onReady'})})));await page.waitForTimeout(100);assert.deepEqual(await controls(),[],'sibling/wrong window must not unlock commands');
await frame.evaluate(origin=>parent.postMessage(JSON.stringify({event:'onReady'}),origin),new URL(base).origin);await page.waitForTimeout(200);
assert((await controls()).some(m=>m.func==='seekTo'&&m.args[0]===1.25));assert((await controls()).some(m=>m.func==='pauseVideo'));
const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(e=>e.click());await page.getByRole('button',{name:'Toggle',exact:true}).click();await page.waitForTimeout(200);assert((await controls()).some(m=>m.func==='playVideo'));assert.equal(loads,1,'playing updates must preserve the iframe');
await page.getByRole('button',{name:'Seek',exact:true}).click();await page.waitForTimeout(200);assert((await controls()).some(m=>m.func==='seekTo'&&m.args[0]===3.5));assert.equal(loads,1,'seeks must preserve the iframe');
await page.getByRole('button',{name:'Source',exact:true}).click();await page.waitForTimeout(300);assert.equal(loads,2,'source changes should reload iframe');assert.deepEqual(errors,[]);console.log('PASS: web iframe creation, origin/source gate, queued controls, play/seek without reload, source reload (provider fixture, not remote playback)');await browser.close();})().catch(e=>{console.error(e);process.exit(1)});
