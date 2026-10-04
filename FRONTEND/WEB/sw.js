const CACHE_VERSION='rtcrackers-pwa-v1';
const SHELL_CACHE=`${CACHE_VERSION}-shell`, RUNTIME_CACHE=`${CACHE_VERSION}-runtime`;
const APP_SHELL=['/','/index.html','/products.html','/product.html','/order.html','/account.html','/login.html','/my-orders.html','/offline.html','/manifest.webmanifest','/css/style.css','/css/pwa.css','/css/pwa-update.css','/js/app.js','/js/pwa-update.js'];
self.addEventListener('install',e=>e.waitUntil(caches.open(SHELL_CACHE).then(c=>c.addAll(APP_SHELL).catch(()=>{})).then(()=>{})));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>![SHELL_CACHE,RUNTIME_CACHE].includes(k)).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
const same=r=>new URL(r.url).origin===self.location.origin;
self.addEventListener('fetch',e=>{
 const r=e.request;
 if(r.method!=='GET'||!same(r)) return;
 if(new URL(r.url).pathname.startsWith('/api/')) return;
 if(r.mode==='navigate'){
  e.respondWith(fetch(r).then(res=>{const c=res.clone();e.waitUntil(caches.open(RUNTIME_CACHE).then(x=>x.put(r,c)).catch(()=>{}));return res;}).catch(()=>caches.match(r).then(x=>x||caches.match('/offline.html'))));
 }else{
  e.respondWith(fetch(r).then(res=>{if(res.ok){const c=res.clone();e.waitUntil(caches.open(RUNTIME_CACHE).then(x=>x.put(r,c)).catch(()=>{}));}return res;}).catch(()=>caches.match(r)));
 }
});
self.addEventListener('message',e=>{if(e.data?.type==='SKIP_WAITING') self.skipWaiting();});
