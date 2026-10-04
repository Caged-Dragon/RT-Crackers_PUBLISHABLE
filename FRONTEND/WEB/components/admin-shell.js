(function(){
  'use strict';
  const nav=[['admin-dashboard.html','Dashboard'],['admin-dashboard.html?tab=orders','Order Tracking'],['admin-dashboard.html#products','Products'],['admin-dashboard.html#customers','Customers'],['admin-dashboard.html#settings','Settings']];
  const path=(location.pathname.split('/').pop()||'admin.html').toLowerCase();
  const isDash=path==='admin-dashboard.html';
  const header=document.createElement('header'); header.className='rt-shell-header rt-admin-shell';
  header.innerHTML=`<div class="shell-inner"><a class="rt-shell-brand" href="admin-dashboard.html"><span class="emblem">⚙</span><span><strong>RT ADMIN</strong><small>RTCrackers Control Center</small></span></a><span class="rt-admin-badge">Administrator</span><nav class="rt-shell-nav" aria-label="Admin navigation">${nav.map(([p,l])=>`<a href="${p}" class="${isDash&&l==='Dashboard'?'active':''}">${l}</a>`).join('')}</nav><div class="rt-shell-actions"><a class="rt-shell-action desktop-only" href="index.html">View Store</a><a class="rt-shell-action primary" href="admin.html" id="adminLogoutShell">Sign Out</a></div><button class="rt-shell-menu" type="button" aria-label="Open admin menu" aria-expanded="false">☰</button></div><div class="rt-shell-mobile">${nav.map(([p,l])=>`<a href="${p}">${l}</a>`).join('')}<a href="index.html">View Store</a><a href="admin.html">Sign Out</a></div>`;
  const footer=document.createElement('footer'); footer.className='rt-shell-footer rt-admin-shell';
  footer.innerHTML=`<div class="footer-main"><div><div class="footer-brand">RT ADMIN</div><p>Secure administration interface for managing RTCrackers products, orders, customers, delivery settings and site content.</p></div><div><h3>Management</h3><a href="admin-dashboard.html#products">Products</a><a href="admin-dashboard.html#orders">Orders</a><a href="admin-dashboard.html#customers">Customers</a></div><div><h3>Operations</h3><a href="admin-dashboard.html?tab=orders">Order Tracking</a><a href="admin-dashboard.html#delivery">Delivery</a><a href="admin-dashboard.html#feedback">Feedback</a><a href="admin-dashboard.html#settings">Settings</a></div><div><h3>Quick Access</h3><a href="index.html">Customer Store</a><a href="admin.html">Admin Login</a><a href="admin-register.html">Admin Registration</a></div></div><div class="footer-bottom"><span>© <span class="rt-shell-year"></span> RTCrackers Admin.</span><span>Restricted administrative area.</span></div>`;
  function mount(){
    document.head.insertAdjacentHTML('beforeend','<link rel="stylesheet" href="components/shell.css?v=20261003">');
    const oldHeader=document.querySelector('.site-header'); const oldFooter=document.querySelector('.site-footer');
    if(oldHeader) oldHeader.replaceWith(header); else if(!document.body.classList.contains('admin-auth-page')) document.body.prepend(header);
    if(oldFooter) oldFooter.replaceWith(footer); else if(!document.body.classList.contains('admin-auth-page')) document.body.appendChild(footer);
    const menu=header.querySelector('.rt-shell-menu'), mobile=header.querySelector('.rt-shell-mobile');
    menu.addEventListener('click',()=>{const open=mobile.classList.toggle('open');menu.setAttribute('aria-expanded',String(open));});
    footer.querySelector('.rt-shell-year').textContent=new Date().getFullYear();
    document.documentElement.classList.add('admin-shell-active');
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',mount); else mount();
})();
