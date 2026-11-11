// Deterministic local media transport for reserved test hosts. Byte-range
// responses are necessary for Chromium to expose a nonzero seekable range.
const fs=require('fs');
async function fulfillMedia(route,file,contentType){
 const bytes=fs.readFileSync(file),total=bytes.length,headers={'access-control-allow-origin':'*','access-control-expose-headers':'Content-Range,Accept-Ranges,Content-Length','accept-ranges':'bytes','cache-control':'no-store','content-type':contentType};
 const range=route.request().headers()['range'];
 if(!range)return route.fulfill({status:200,headers:{...headers,'content-length':String(total)},body:bytes});
 const match=/^bytes=(\d*)-(\d*)$/.exec(range);let start,end;
 if(match&&(match[1]||match[2])){start=match[1]?Number(match[1]):Math.max(0,total-Number(match[2]));end=match[1]&&match[2]?Math.min(total-1,Number(match[2])):total-1;}
 if(start==null||start<0||start>=total||end<start)return route.fulfill({status:416,headers:{...headers,'content-range':`bytes */${total}`},body:''});
 return route.fulfill({status:206,headers:{...headers,'content-range':`bytes ${start}-${end}/${total}`,'content-length':String(end-start+1)},body:bytes.subarray(start,end+1)});
}
module.exports={fulfillMedia};
