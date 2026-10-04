(function(){
  'use strict';
  const $=s=>document.querySelector(s);
  const A=window.RTAdmin;
  function result(el,msg,ok){el.innerHTML='<div class="info-banner" style="margin-top:0;'+(ok?'':'background:#fff4e5;border-color:#f0c987;color:#7a4c00')+'">'+String(msg).replace(/[<>]/g,'')+'</div>';}
  async function init(){
    if(!A) return;
    try{ await A.authReady; }catch(e){}
    try{
      const orders=await A.getOrdersForCurrentUser();
      const sel=$('#rtOrder');
      if(sel){
        orders.filter(o=>['Delivered','Collected'].includes(o.status)).forEach(o=>{const op=document.createElement('option');op.value=o.id;op.textContent=(o.ref||o.id)+' — '+(o.status||'Completed');sel.appendChild(op);});
      }
    }catch(e){console.warn('Feedback order list unavailable',e);}
    const u=A.currentUser?.();
    if(u){ if($('#rtName'))$('#rtName').value=u.email?.split('@')[0]||''; if($('#rtEmail'))$('#rtEmail').value=u.email||''; if($('#cdName'))$('#cdName').value=u.email?.split('@')[0]||''; if($('#cdEmail'))$('#cdEmail').value=u.email||''; }
    $('#rtFeedbackForm')?.addEventListener('submit',e=>submit(e,'rt_crackers','rt'));
    $('#cdFeedbackForm')?.addEventListener('submit',e=>submit(e,'caged_dragon','cd'));
  }
  async function submit(e,brand,prefix){
    e.preventDefault(); const f=e.currentTarget; const btn=f.querySelector('button[type=submit]'); btn.disabled=true;
    const r=await A.submitFeedback({brand,orderId:$('#'+prefix+'Order')?.value||null,name:$('#'+prefix+'Name').value,email:$('#'+prefix+'Email').value,rating:$('#'+prefix+'Rating').value,category:$('#'+prefix+'Category').value,subject:$('#'+prefix+'Subject').value,message:$('#'+prefix+'Message').value});
    btn.disabled=false; result($('#'+prefix+'Result'),r.ok?'Thank you. Your feedback has been submitted for review.':(r.error||'Could not submit feedback.'),r.ok); if(r.ok) f.reset();
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();
