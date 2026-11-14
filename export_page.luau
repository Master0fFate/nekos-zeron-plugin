-- Built-in zgx web view only. No process, package, or third-party script.
return [==[
<!doctype html><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; connect-src https://cdn.nekosapi.com https://s3.nyeki.dev; img-src blob:; style-src 'unsafe-inline'">
<style>html,body{margin:0;background:transparent}</style>
<script>
(() => {
  'use strict';
  let pending = null, controller = null, objectURL = null;
  const send = value => window.zgx.postMessage(value);
  const clean = () => {
    if (controller) controller.abort();
    if (objectURL) URL.revokeObjectURL(objectURL);
    controller = null; objectURL = null; pending = null;
  };
  window.nekosCancel = clean;
  window.nekosCommit = token => {
    if (!pending || pending.token !== token || !objectURL) return;
    const link = document.createElement('a');
    link.href = objectURL; link.download = pending.name;
    document.body.appendChild(link); link.click(); link.remove();
  };
  window.nekosExport = async data => {
    clean();
    const token = data.token;
    controller = new AbortController();
    const timer = setTimeout(() => controller && controller.abort(), 15000);
    try {
      const url = new URL(data.url);
      if (url.protocol !== 'https:' || url.username || url.password ||
          !['cdn.nekosapi.com', 's3.nyeki.dev'].includes(url.hostname)) throw Error('Unsupported image address.');
      const response = await fetch(url.href, {credentials:'omit', redirect:'error', signal:controller.signal});
      if (!response.ok) throw Error('Image server returned HTTP ' + response.status + '.');
      const max = 40 * 1024 * 1024;
      if (Number(response.headers.get('content-length')) > max) throw Error('Image exceeds 40 MiB.');
      const reader = response.body.getReader(), chunks = [];
      let size = 0;
      for (;;) {
        const part = await reader.read();
        if (part.done) break;
        size += part.value.length;
        if (size > max) { await reader.cancel(); throw Error('Image exceeds 40 MiB.'); }
        chunks.push(part.value);
      }
      let blob = new Blob(chunks, {type:response.headers.get('content-type') || 'application/octet-stream'});
      const head = new Uint8Array(await blob.slice(0,12).arrayBuffer());
      const type = head[0]===0x89 && head[1]===0x50 && head[2]===0x4e && head[3]===0x47 ? 'png'
        : head[0]===0xff && head[1]===0xd8 && head[2]===0xff ? 'jpeg'
        : head[0]===0x52 && head[1]===0x49 && head[8]===0x57 && head[9]===0x45 ? 'webp'
        : head[0]===0x47 && head[1]===0x49 && head[2]===0x46 ? 'gif' : null;
      let format = data.format;
      if (!['original','png','jpeg'].includes(format)) throw Error('Unsupported output format.');
      if (format !== 'original' && format !== type) {
        objectURL = URL.createObjectURL(blob);
        const img = new Image();
        await new Promise((resolve,reject) => { img.onload=resolve; img.onerror=()=>reject(Error('Image could not be decoded.')); img.src=objectURL; });
        if (img.naturalWidth * img.naturalHeight > 40000000) throw Error('Image exceeds 40 megapixels.');
        const canvas = document.createElement('canvas');
        canvas.width=img.naturalWidth; canvas.height=img.naturalHeight;
        const context = canvas.getContext('2d');
        if (!context) throw Error('Image conversion is unavailable in this web view.');
        if (format === 'jpeg') { context.fillStyle='#fff'; context.fillRect(0,0,canvas.width,canvas.height); }
        context.drawImage(img,0,0);
        blob = await new Promise((resolve,reject) => canvas.toBlob(value => value ? resolve(value) : reject(Error('Image conversion failed.')), 'image/'+format, 0.95));
        if (blob.type !== 'image/'+format) throw Error('This output format is not supported.');
        URL.revokeObjectURL(objectURL); objectURL=null;
      }
      clearTimeout(timer);
      const extension = format === 'original' ? type || (['avif','bmp','png','jpg','jpeg','webp','gif'].includes((url.pathname.split('.').pop()||'').toLowerCase()) ? url.pathname.split('.').pop().toLowerCase() : 'img') : format;
      const name = 'nekos-' + String(data.id).replace(/[^a-zA-Z0-9_-]/g,'_').slice(0,40) + '.' + (extension==='jpeg'?'jpg':extension);
      objectURL=URL.createObjectURL(blob);
      pending={token,name};
      send({kind:'prepared',token,url:objectURL,name});
    } catch(error) {
      send({kind:'error',token,error:error.name==='AbortError'?'Image request timed out.':String(error.message || error)});
      clean();
    } finally { clearTimeout(timer); }
  };
})();
</script>
]==]
