/* RTCrackers Python/FastAPI authentication adapter. */
(() => {
  'use strict';
  const API='/api/v1';
  const json=async(url,opt={})=>{
    const r=await fetch(url,{credentials:'same-origin',headers:{'Content-Type':'application/json',...(opt.headers||{})},...opt});
    let data={}; try{data=await r.json()}catch(_){}
    if(!r.ok) throw new Error(data.detail||data.message||data.error||'Request failed');
    return data;
  };
  const RTAdmin={
    ready:Promise.resolve(),
    authReady:Promise.resolve(),
    getCompanyOverrides:()=>({name:'RTCrackers',brand:'RTCrackers'}),
    getPolicyOverrides:()=>({}),
    supabaseSession:async()=>null,
    async me(){return json(`${API}/profile/me`).catch(()=>null)},
    async login(email,password){return json(`${API}/auth/login`,{method:'POST',body:JSON.stringify({email,password})});},
    async register(v){return json(`${API}/auth/register`,{method:'POST',body:JSON.stringify(v)});},
    async logout(){return json(`${API}/auth/logout`,{method:'POST',body:JSON.stringify({all_devices:false})});}
  };
  window.RTAdmin=RTAdmin;
  const bind=()=>{
    const lf=document.getElementById('loginForm');
    if(lf&&!lf.dataset.rtcBound){lf.dataset.rtcBound='1';lf.addEventListener('submit',async e=>{
      e.preventDefault(); const btn=lf.querySelector('[type=submit]');
      try{if(btn)btn.disabled=true;await RTAdmin.login(document.getElementById('loginEmail')?.value||'',document.getElementById('loginPassword')?.value||'');location.href=new URLSearchParams(location.search).get('mode')==='admin'?'/admin.html':'/account.html';}
      catch(err){alert(err.message)} finally{if(btn)btn.disabled=false;}
    });}
    const sf=document.getElementById('signupForm');
    if(sf&&!sf.dataset.rtcBound){sf.dataset.rtcBound='1';sf.addEventListener('submit',async e=>{
      e.preventDefault();const btn=sf.querySelector('[type=submit]');
      try{if(btn)btn.disabled=true;const name=(document.getElementById('signupName')?.value||'').trim().split(/\s+/);await RTAdmin.register({first_name:name.shift()||'Customer',last_name:name.join(' ')||null,email:document.getElementById('signupEmail')?.value||'',phone:document.getElementById('signupPhone')?.value||'',password:document.getElementById('signupPassword')?.value||''});location.href='/account.html';}
      catch(err){alert(err.message)} finally{if(btn)btn.disabled=false;}
    });}
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',bind,{once:true});else bind();
})();