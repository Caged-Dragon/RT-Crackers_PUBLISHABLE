(async function(){
  const $=s=>document.querySelector(s); let sb=null;
  try{
    const c=await fetch('/api/config').then(r=>r.json());
    if(c.supabaseUrl&&c.supabasePublishableKey){
      const s=document.createElement('script'); s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'; document.head.appendChild(s);
      await new Promise((ok,fail)=>{s.onload=ok;s.onerror=fail});
      sb=window.supabase.createClient(c.supabaseUrl,c.supabasePublishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
    }
  }catch{}
  window.RTAuth={client:sb};
  const loginForm=$('#loginForm');
  if(loginForm){
    if(!sb){$('#authMsg').textContent='Supabase authentication is not configured in this local environment. Add the variables from .env.example to enable account features.';return;}
    loginForm.addEventListener('submit',async e=>{
      e.preventDefault(); const email=$('#email').value.trim(),password=$('#password').value; $('#loginBtn').disabled=true;
      try{const {error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;location.href='/account'}catch(err){$('#authMsg').textContent=err.message}finally{$('#loginBtn').disabled=false}
    });
  }
  const logout=$('#logout');
  if(logout) logout.onclick=async()=>{await sb?.auth.signOut();location.href='/'};
  const sessionInfo=$('#sessionInfo');
  if(sessionInfo){
    const u=(await sb?.auth.getUser())?.data?.user;
    if(!u) sessionInfo.innerHTML='<p class="muted">No active account session.</p>';
    else sessionInfo.innerHTML=`<div class="notice success">Signed in as <strong>${String(u.email||'').replace(/[<>]/g,'')}</strong></div>`;
  }
  const ordersList=$('#ordersList');
  if(ordersList){
    const token=(await sb?.auth.getSession())?.data?.session?.access_token;
    if(!token){ordersList.innerHTML='<div class="panel">Please sign in to view your orders.</div>';return;}
    const r=await fetch('/api/orders/mine',{headers:{Authorization:`Bearer ${token}`}}); const j=await r.json();
    ordersList.innerHTML=r.ok&&j.orders?.length?j.orders.map(o=>`<div class="panel" style="margin-bottom:12px"><strong>${String(o.ref||o.id).replace(/[&<>"\']/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","\'":"&#39;" }[c]))}</strong><p class="muted">${new Date(o.createdAt||Date.now()).toLocaleString('en-IN')} · ${o.status||'Submitted'} · ₹${Number(o.total||0).toLocaleString('en-IN')}</p></div>`).join(''):'<div class="panel"><p class="muted">No orders found.</p></div>';
  }
})();
