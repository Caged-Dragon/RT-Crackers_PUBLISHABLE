(function(){
  'use strict';
  const nav=[['index.html','Home'],['products.html','Products'],['about.html','About'],['policy.html','Policies'],['feedback.html','Feedback'],['contact.html','Contact'],['my-orders.html','My Orders']];
  const path=(location.pathname.split('/').pop()||'index.html').toLowerCase();
  const active=p=>path===p;
  const linkHtml=nav.map(([p,l])=>`<a href="${p}" class="${active(p)?'active':''}">${l}</a>`).join('');
  const header=document.createElement('header'); header.className='rt-shell-header rt-customer-shell';
  header.innerHTML=`<div class="shell-inner"><a class="rt-shell-brand" href="index.html" aria-label="RTCrackers home"><span class="emblem">🎆</span><span><strong>RTCRACKERS</strong><small>RTCrackers</small></span></a><nav class="rt-shell-nav" aria-label="Customer navigation">${linkHtml}</nav><div class="rt-shell-actions"><a class="rt-shell-action icon" href="order.html" title="Cart / Order" aria-label="Cart / Order">🛒</a><a class="rt-shell-action primary desktop-only" href="account.html" id="customerAccountShellLink">Account</a></div><button class="rt-shell-menu" type="button" aria-label="Open menu" aria-expanded="false">☰</button></div><div class="rt-shell-mobile">${linkHtml}<a href="account.html">Account</a><a href="order.html">Cart / Order</a></div>`;
  const footer=document.createElement('footer'); footer.className='rt-shell-footer rt-customer-shell';
  footer.innerHTML=`<div class="footer-main"><div><div class="footer-brand">RTCRACKERS</div><p>RTCrackers — premium fireworks and festive celebrations from Sivakasi.</p></div><div><h3>Explore</h3><a href="products.html">All Products</a><a href="about.html">About Us</a><a href="contact.html">Contact</a></div><div><h3>Customer</h3><a href="account.html">My Account</a><a href="my-orders.html">My Orders</a><a href="feedback.html">Feedback</a></div><div><h3>Information</h3><a href="policy.html">Policies & Safety</a><a href="offline.html">Offline</a><a href="admin.html">Admin Login</a></div></div><div class="footer-bottom"><span>© <span class="rt-shell-year"></span> RTCrackers.</span><span>Celebrate responsibly. Follow all applicable safety guidance.</span></div>`;
  function mount(){
    document.head.insertAdjacentHTML('beforeend','<link rel="stylesheet" href="components/shell.css?v=20261003">');
    const oldHeader=document.querySelector('.site-header'); const oldFooter=document.querySelector('.site-footer');
    if(oldHeader) oldHeader.replaceWith(header); else document.body.prepend(header);
    if(oldFooter) oldFooter.replaceWith(footer); else document.body.appendChild(footer);
    const menu=header.querySelector('.rt-shell-menu'), mobile=header.querySelector('.rt-shell-mobile');
    menu.addEventListener('click',()=>{const open=mobile.classList.toggle('open');menu.setAttribute('aria-expanded',String(open));});
    footer.querySelector('.rt-shell-year').textContent=new Date().getFullYear();
    document.documentElement.classList.add('customer-shell-active');
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',mount); else mount();
})();
