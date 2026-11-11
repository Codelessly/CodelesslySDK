// PLAYWRIGHT_MODULE=... MEDIA_FIXTURE=/path/to/harbor.mp4 node media_probe_smoke.cjs [URL]
const fs=require('fs'),{chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--no-sandbox','--single-process','--no-zygote','--disable-dev-shm-usage','--enable-unsafe-swiftshader']});
 const page=await browser.newPage();await page.goto(process.argv[2]||'http://127.0.0.1:5197');
 await page.waitForFunction(()=>typeof cutroomProbePicked==='function');
 await page.evaluate(()=>{window.probeUrls={created:[],revoked:[]};const create=URL.createObjectURL.bind(URL),revoke=URL.revokeObjectURL.bind(URL);URL.createObjectURL=(b)=>{const u=create(b);probeUrls.created.push(u);return u};URL.revokeObjectURL=(u)=>{probeUrls.revoked.push(u);return revoke(u)};});
 const encoded=fs.readFileSync(process.env.MEDIA_FIXTURE).toString('base64');
 const good=await page.evaluate(async value=>JSON.parse(await cutroomProbePicked('picked.mp4',value,'video/mp4')),encoded);
 if(good.url||!(good.durationSeconds>0)||good.width<=0||good.height<=0)throw Error('Missing metadata or leaked URL '+JSON.stringify(good));
 const bad=await page.evaluate(async()=>JSON.parse(await cutroomProbePicked('broken.mp4','AAEC','video/mp4')));if(!bad.error)throw Error('Invalid bytes accepted');
 const urls=await page.evaluate(()=>probeUrls);if(urls.created.length!==2||urls.revoked.length!==2||urls.created.some(u=>!urls.revoked.includes(u)))throw Error('Blob URL leak '+JSON.stringify(urls));
 console.log('PASS: picked-byte metadata preflight, decode rejection, no returned URL and blob cleanup',JSON.stringify(good));await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
