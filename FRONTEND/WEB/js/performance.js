/* RTCRACKERS — adaptive 60/90/120/144Hz-friendly rendering layer */
(function(){
  'use strict';
  const root=document.documentElement;
  let raf=0, resizeRaf=0;
  const reduce=matchMedia('(prefers-reduced-motion: reduce)');
  const fastUpdate=matchMedia('(update: fast)');

  function measure(){
    const vv=window.visualViewport;
    const w=Math.round(vv?.width||innerWidth), h=Math.round(vv?.height||innerHeight);
    root.style.setProperty('--rt-vw',w+'px');
    root.style.setProperty('--rt-vh',h+'px');
    root.style.setProperty('--rt-dpr',Math.min(devicePixelRatio||1,2));
    root.style.setProperty('--rt-frame-ms',fastUpdate.matches?'7ms':'16.67ms');
    root.dataset.motion=reduce.matches?'reduced':'full';
    root.dataset.device=w<600?'phone':w<1024?'tablet':'desktop';
  }
  function scheduleMeasure(){if(resizeRaf)return;resizeRaf=requestAnimationFrame(()=>{resizeRaf=0;measure()})}
  measure();
  addEventListener('resize',scheduleMeasure,{passive:true});
  addEventListener('orientationchange',scheduleMeasure,{passive:true});
  visualViewport?.addEventListener('resize',scheduleMeasure,{passive:true});
  reduce.addEventListener?.('change',measure);
  fastUpdate.addEventListener?.('change',measure);

  // One shared RAF loop for visual work; avoids several scroll handlers competing.
  const scrollState={y:scrollY,dy:0,velocity:0};
  addEventListener('scroll',()=>{scrollState.y=scrollY},{passive:true});
  function frame(){
    const next=scrollState.y;
    scrollState.dy=next-(scrollState.last??next);
    scrollState.velocity=scrollState.dy;
    scrollState.last=next;
    root.style.setProperty('--rt-scroll-y',next+'px');
    root.style.setProperty('--rt-scroll-velocity',Math.min(24,Math.abs(scrollState.velocity)));
    raf=requestAnimationFrame(frame);
  }
  raf=requestAnimationFrame(frame);
  document.addEventListener('visibilitychange',()=>{if(document.hidden){cancelAnimationFrame(raf);raf=0}else if(!raf)raf=requestAnimationFrame(frame)},{passive:true});

  // Give the browser permission to skip rendering of far-off sections.
  function optimize(){
    document.querySelectorAll('section,article,.card,.product-card,.adm-panel').forEach(el=>{
      if(!el.style.contentVisibility) el.style.contentVisibility='auto';
      if(!el.style.containIntrinsicSize) el.style.containIntrinsicSize='auto 420px';
    });
    document.querySelectorAll('img').forEach(img=>{
      if(!img.loading) img.loading='lazy';
      if(!img.decoding) img.decoding='async';
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',optimize,{once:true});else optimize();
})();
