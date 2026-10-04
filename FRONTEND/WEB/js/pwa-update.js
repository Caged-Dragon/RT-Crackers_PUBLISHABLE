/* RTCrackers PWA release/update controller.
 * Updates are NEVER activated automatically. The installed release remains active
 * until the user explicitly chooses Update in the prompt.
 */
(() => {
  'use strict';
  const KEY='rtcrackers.accepted_release';
  const API='/api/v1/platform/release';
  let registration=null;
  const getAccepted=()=>localStorage.getItem(KEY);
  const setAccepted=v=>{ if(v) localStorage.setItem(KEY,v); };
  function promptUpdate(release){
    if(document.getElementById('rtc-release-prompt')) return;
    const el=document.createElement('aside');
    el.id='rtc-release-prompt';
    el.setAttribute('role','dialog');
    el.innerHTML=`<div class="rtc-release-card">
      <strong>${escapeHtml(release.name||'RTCrackers update available')}</strong>
      <p>${escapeHtml(release.message||'A verified update is ready. Your current version will stay active until you choose to update.')}</p>
      <div class="rtc-release-actions"><button id="rtc-release-later">Keep current</button><button id="rtc-release-update">Update</button></div>
    </div>`;
    document.body.appendChild(el);
    el.querySelector('#rtc-release-later').onclick=()=>el.remove();
    el.querySelector('#rtc-release-update').onclick=async()=>{
      setAccepted(release.version);
      el.querySelector('#rtc-release-update').disabled=true;
      if(registration?.waiting){
        registration.waiting.postMessage({type:'SKIP_WAITING',version:release.version});
        return;
      }
      location.reload();
    };
  }
  function escapeHtml(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  async function checkRelease(){
    try{
      const r=await fetch(`${API}?accepted=${encodeURIComponent(getAccepted()||'')}`,{cache:'no-store'});
      if(!r.ok)return;
      const release=await r.json();
      if(!release?.version)return;
      if(!getAccepted()) setAccepted(release.version);
      else if(release.version!==getAccepted()) promptUpdate(release);
      window.RTCrackersRelease=release;
    }catch(_){}
  }
  async function init(){
    if('serviceWorker' in navigator){
      try{
        registration=await navigator.serviceWorker.register('/sw.js',{updateViaCache:'none'});
        registration.addEventListener('updatefound',()=>registration.update().catch(()=>{}));
        navigator.serviceWorker.addEventListener('controllerchange',()=>location.reload());
      }catch(_){}
    }
    await checkRelease();
    setInterval(checkRelease,5*60*1000);
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init,{once:true}); else init();
})();
