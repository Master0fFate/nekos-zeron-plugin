// Development test only. Node is not needed to install or use the plugin.
// Runs the shipped exporter with a fake browser. Platform WebView downloads
// and real canvas conversion still require a desktop integration test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../export_page.luau'), 'utf8');
const script = source.split('<script>')[1].split('</script>')[0];
const blobs = new Map(), messages = [], clicks = [], conversions = [];
let id = 0, status = 200, length = null, drawn = false, white = false;
let body = Uint8Array.from([82,73,70,70,4,0,0,0,87,69,66,80,0,1,2,3]);
class FakeURL extends URL {
  static createObjectURL(blob) { const url = 'blob:fixture/' + ++id; blobs.set(url, blob); return url; }
  static revokeObjectURL(url) { blobs.delete(url); }
}
class FakeImage {
  naturalWidth = 640; naturalHeight = 480;
  set src(url) { assert(blobs.has(url)); queueMicrotask(() => this.onload()); }
}
const window = {zgx:{postMessage:value => messages.push(value)}};
const context = vm.createContext({window,URL:FakeURL,Blob,Uint8Array,AbortController,Image:FakeImage,setTimeout,clearTimeout,
  fetch:async (url, options) => {
    assert.equal(options.credentials,'omit'); assert.equal(options.redirect,'error');
    return {ok:status===200,status,headers:{get:name => name==='content-length'?length:'image/webp'},
      body:new ReadableStream({start(controller){controller.enqueue(body);controller.close();}})};
  },
  document:{body:{appendChild(){}},createElement:tag => {
    if(tag==='a') return {click(){clicks.push({url:this.href,name:this.download,blob:blobs.get(this.href)});},remove(){}};
    assert.equal(tag,'canvas');
    return {getContext:() => ({set fillStyle(value){assert.equal(value,'#fff');},fillRect(){white=true;},drawImage(){drawn=true;}}),
      toBlob(callback,type,quality){conversions.push({type,quality,white,drawn});callback(new Blob(['converted fixture'],{type}));}};
  }},
});
vm.runInContext(script,context);
const run = async (token,format='original',url='https://cdn.nekosapi.com/example.webp') => {
  await window.nekosExport({token,format,url,id:'sample/1'}); return messages.at(-1);
};
(async () => {
  let result=await run(1);
  assert.equal(result.kind,'prepared'); assert.equal(result.name,'nekos-sample_1.webp');
  assert.equal(clicks.length,0); window.nekosCommit(999); assert.equal(clicks.length,0);
  window.nekosCommit(1); assert.equal(clicks.length,1);
  assert.deepEqual(new Uint8Array(await clicks[0].blob.arrayBuffer()),body);
  assert.equal(conversions.length,0); // Original WebP is not converted.
  for(const [token,format] of [[2,'png'],[3,'jpeg']]) {
    result=await run(token,format); assert.equal(result.kind,'prepared');
    window.nekosCommit(token); assert.equal(clicks.at(-1).blob.type,'image/'+format);
    assert.equal(conversions.at(-1).drawn,true);
  }
  assert.equal(conversions.at(-1).white,true);
  body=Uint8Array.from([255,216,255,42]); const count=conversions.length;
  result=await run(4,'jpeg'); assert.equal(conversions.length,count);
  window.nekosCommit(4); assert.deepEqual(new Uint8Array(await clicks.at(-1).blob.arrayBuffer()),body);
  status=429; assert.match((await run(5)).error,/HTTP 429/);
  status=200; length=50*1024*1024; assert.match((await run(6)).error,/40 MiB/);
  length=null; body=new Uint8Array(41*1024*1024); assert.match((await run(7)).error,/40 MiB/);
  assert.match((await run(8,'original','https://example.org/a.webp')).error,/Unsupported image address/);
  assert.match((await run(9,'original','https://user:password@cdn.nekosapi.com/a.webp')).error,/Unsupported image address/);
  window.nekosCancel(); assert.equal(blobs.size,0);
  const manifest=JSON.parse(fs.readFileSync(path.join(__dirname,'../zeron-plugin.json'),'utf8'));
  assert(!manifest.permissions.includes('commands')); assert(!manifest.commands);
  assert(manifest.permissions.includes('panel.tabs'));
  console.log('Passed original WebP bytes, format selection, mocked canvas flow, download commit, failures, limits, and no process grants.');
})().catch(error => {console.error(error);process.exitCode=1;});
