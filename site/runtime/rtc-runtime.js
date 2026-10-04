
(() => {
  'use strict';
  const root = document.documentElement;
  const cfg = Object.assign({
    customerApi: '/api/v1',
    adminApi: '/api/v1/admin',
    platformApi: '/api/v1',
    whatsapp: '918124100501',
    phone: '917358737658',
    email: 'sales@rtcrackers.com',
    logo: '../assets/branding/LOGO.jpeg',
    banner: '../assets/branding/rtcrackers-home-banner.jpeg',
    productImage: '../assets/branding/electric-sparklers-10cm.jpeg'
  }, window.RT_CONFIG || {});
  const currentDir = location.pathname.replace(/\\/g,'/');
  const isAdmin = /(^|\/)admin([\/?]|$)/i.test(currentDir) || /admin_/i.test(document.title);
  const store = {
    get theme(){ return localStorage.getItem('rtc-theme') || 'light'; },
    set theme(v){ localStorage.setItem('rtc-theme',v); }
  };
  function applyTheme(){
    root.classList.toggle('dark', store.theme === 'dark');
    document.querySelectorAll('.rtc-theme-bar button').forEach(b => b.classList.toggle('active', b.dataset.theme === store.theme));
  }
  function addThemeBar(){
    if(document.querySelector('.rtc-theme-bar')) return;
    const bar=document.createElement('div'); bar.className='rtc-theme-bar';
    bar.innerHTML='<button type="button" data-theme="light">Light</button><button type="button" data-theme="dark">Dark</button>';
    bar.addEventListener('click',e=>{ const b=e.target.closest('button'); if(!b)return; store.theme=b.dataset.theme; applyTheme(); });
    document.body.appendChild(bar); applyTheme();
  }
  function setLogo(){
    document.querySelectorAll('img[alt="LOGO.jpeg"], img[src*="googleusercontent.com/aida"]').forEach(img=>{
      if(img.alt === 'LOGO.jpeg' || /aida\/AEt|aida-public/.test(img.src)) img.src=cfg.logo;
    });
  }
  const routeFiles = {"/":"customer_page_1_home_storefront_rtcrackers/code.html","/shop":"shop_all_products_red_thunder_crackers/code.html","/categories":"categories_red_thunder_crackers/code.html","/offers":"offers_deals_red_thunder_crackers/code.html","/product":"customer_page_3_product_details_red_thunder_crackers/code.html","/cart":"customer_page_4_shopping_cart_red_thunder_crackers/code.html","/checkout":"customer_page_5_checkout_red_thunder_crackers/code.html","/order-confirmation":"customer_page_6_order_confirmation_receipt_rtcrackers/code.html","/login":"customer_page_7_login_sign_in_red_thunder_crackers/code.html","/signup":"customer_registration_rtcrackers/code.html","/forgot-password":"forgot_reset_password_rtcrackers/code.html","/account":"my_account_dashboard_rtcrackers/code.html","/account/orders":"page_16_my_orders_rtcrackers/code.html","/account/orders/tracking":"order_details_tracking_rtcrackers/code.html","/account/wishlist":"my_wishlist_saved_gear_rtcrackers/code.html","/account/addresses":"page_24_saved_addresses_rtcrackers/code.html","/account/payments":"page_26_saved_payments_rtcrackers/code.html","/account/profile":"page_25_profile_personal_information_rtcrackers/code.html","/account/notifications":"page_27_notifications_preferences_rtcrackers/code.html","/account/settings":"page_28_account_settings_privacy_rtcrackers/code.html","/support":"page_29_help_support_center_rtcrackers/code.html","/faq":"page_20_faq_help_center_rtcrackers/code.html","/contact":"page_19_contact_us_rtcrackers/code.html","/about":"page_31_about_us_our_story_rtcrackers/code.html","/shipping":"page_32_shipping_delivery_information_rtcrackers/code.html","/privacy-policy":"customer_page_26_privacy_policy_rtcrackers/code.html","/terms-and-conditions":"customer_page_27_terms_conditions_red_thunder_crackers/code.html","/404":"customer_page_28_404_error_recovery_rtcrackers/code.html","/maintenance":"customer_page_29_maintenance_offline_experience_rtcrackers/code.html","/admin":"primary_admin_complete_command_center_rtcrackers/code.html","/admin/content":"admin_content_manager_rtcrackers/code.html","/admin/products":"admin_page_2_product_management_rtcrackers/code.html","/admin/categories":"page_3_category_management_rtcrackers_admin/code.html","/admin/inventory":"admin_page_17_inventory_management_stock_control_rtcrackers/code.html","/admin/orders":"admin_page_7_order_management_rtcrackers/code.html","/admin/orders/pending":"admin_page_8_pending_orders_processing_queue_rtcrackers/code.html","/admin/orders/processing":"admin_page_9_processing_orders_rtcrackers/code.html","/admin/orders/shipped":"admin_page_10_shipped_orders_tracking_rtcrackers/code.html","/admin/orders/delivered":"admin_page_11_delivered_orders_delivery_history_rtcrackers/code.html","/admin/orders/cancelled":"admin_page_12_cancelled_orders_cancellation_management_rtcrackers/code.html","/admin/customers":"admin_page_18_customer_management_customer_details_rtcrackers/code.html","/admin/support":"admin_page_19_customer_support_tickets_conversations_management_rtcrackers/code.html","/admin/coupons":"admin_page_20_coupons_discounts_promotional_campaign_management_rtcrackers/code.html","/admin/pricing":"admin_page_21_product_pricing_price_rules_dynamic_pricing_management_rtcrackers/code.html","/admin/reports":"admin_page_22_reports_analytics_business_intelligence_dashboard_rtcrackers/code.html","/admin/settings":"admin_page_23_settings_configuration_system_administration_rtcrackers/code.html","/admin/profile":"admin_page_24_admin_profile_account_security_personal_preferences_rtcrackers/code.html","/search":"customer_page_2_product_listing_category_search_red_thunder_crackers/code.html","/admin/payments":"admin_page_15_payments_transaction_management_rtcrackers/code.html","/admin/shipping":"admin_page_16_shipping_delivery_management_rtcrackers/code.html","/admin/reviews":"admin_page_6_product_reviews_ratings_management_rtcrackers/code.html","/admin/inventory/legacy":"admin_page_5_inventory_management_rtcrackers/code.html"};
  const routes = {
    home:'/', shop:'/shop', products:'/shop', search:'/search', categories:'/categories', offers:'/offers', 'offers-deals':'/offers',
    'about-us':'/about', about:'/about', contact:'/contact', 'contact-us':'/contact', faq:'/faq', faqs:'/faq',
    'shipping-policy':'/shipping', 'shipping-information':'/shipping', 'shipping-info':'/shipping', 'shipping-delivery':'/shipping',
    'privacy-policy':'/privacy-policy', 'terms-conditions':'/terms-and-conditions', 'terms-and-conditions':'/terms-and-conditions',
    cart:'/cart', wishlist:'/account/wishlist', account:'/account', dashboard:'/account', orders:'/account/orders', 'all-orders':'/account/orders',
    'track-order':'/account/orders/tracking', 'order-tracking':'/account/orders/tracking', support:'/support', 'help-center':'/support',
    signup:'/signup', register:'/signup', login:'/login', 'forgot-password':'/forgot-password', checkout:'/checkout',
    'order-confirmation':'/order-confirmation', 'order-success':'/order-confirmation',
    addresses:'/account/addresses', payments:'/account/payments', profile:'/account/profile', notifications:'/account/notifications', settings:'/account/settings',
    cms:'/admin/content', pages:'/admin/content', banners:'/admin/content', 'content-manager':'/admin/content',
    admin:'/admin', dashboard:'/admin', 'command-center':'/admin', products_admin:'/admin/products', inventory:'/admin/inventory', customers:'/admin/customers', reports:'/admin/reports', payments:'/admin/payments', shipping:'/admin/shipping', product_reviews:'/admin/reviews', 'product-reviews':'/admin/reviews'
  };
  function pageUrl(path){
    if(!path) return '#';
    if(/^https?:/i.test(path)) return path;
    const route=routes[path] || (path.startsWith('/') ? path : null);
    if(route){
      if(window.RT_PRETTY_ROUTES) return route;
      const file = routeFiles[route];
      if(file){ return new URL('../'+file, location.href).href; }
      return route;
    }
    return '#';
  }
  function wireNavigation(){
    document.querySelectorAll('[data-path]').forEach(a=>{
      const p=a.getAttribute('data-path'); const u=pageUrl(p); if(u && u!=='#') a.setAttribute('href',u);
      a.addEventListener('click',e=>{ const target=pageUrl(p); if(target && target!=='#' && !/^https?:/i.test(target)){ e.preventDefault(); location.href=target; } });
    });
    document.querySelectorAll('a[href="#"]').forEach(a=>{
      if(a.dataset.path) return;
      const t=(a.textContent||'').trim().toLowerCase();
      const guess=t.includes('whatsapp')?'https://wa.me/'+cfg.whatsapp:null;
      if(guess) a.href=guess;
    });
  }
  async function api(base, endpoint, opts={}){
    const res=await fetch((base||'')+endpoint,{credentials:'include',...opts,headers:{'Accept':'application/json','Content-Type':'application/json',...(opts.headers||{})}});
    if(!res.ok){ let body={}; try{body=await res.json();}catch{}; const err=new Error(body.message||body.detail||`API request failed (${res.status})`); err.status=res.status; throw err; }
    const text=await res.text(); return text?JSON.parse(text):null;
  }
  async function customerApi(endpoint,opts){ return api(cfg.customerApi,endpoint,opts); }
  async function adminApi(endpoint,opts){ return api(cfg.adminApi,endpoint,opts); }
  async function platformApi(endpoint,opts){ return api(cfg.platformApi,endpoint,opts); }
  function notify(msg,kind='info'){
    let n=document.getElementById('rtc-runtime-toast');
    if(!n){n=document.createElement('div');n.id='rtc-runtime-toast';n.style.cssText='position:fixed;right:16px;top:18px;z-index:100000;max-width:360px;padding:12px 14px;border-radius:10px;background:#fff;border:1px solid #ead9ad;box-shadow:0 12px 30px rgba(0,0,0,.16);font:600 13px/1.4 Inter,sans-serif;color:#10224b';document.body.appendChild(n)}
    n.textContent=msg; n.style.borderColor=kind==='error'?'#e31b16':'#ead9ad'; clearTimeout(n._t); n._t=setTimeout(()=>n.remove(),3500);
  }
  async function refreshCartBadge(){
    try{
      const data=await customerApi('/cart/count'); const count=data?.item_count ?? data?.data?.item_count ?? 0;
      document.querySelectorAll('[data-cart-count], .relative .bg-primary-container').forEach(el=>{ if(el.textContent.trim().match(/^\d+$/)) el.textContent=String(count); });
    }catch(_){/* guest cart endpoint may be unavailable before first visit */}
  }
  async function injectHomeBanner(){
    const home = /customer_page_1_home_storefront|home_red_thunder_crackers/.test(currentDir) || location.pathname==='/' || document.title.includes('Premium Pyrotechnics');
    if(!home || document.querySelector('.rtc-home-banner')) return;
    let banner=cfg.banner;
    try{ const r=await platformApi('/cms/home'); const hero=(r?.data||[]).find(x=>x.section_key==='hero' && x.is_active!==false); const u=hero?.content_json?.image_url; if(u) banner=u; }catch(_){}
    const main=document.querySelector('main'); if(!main) return;
    const wrap=document.createElement('a'); wrap.className='rtc-home-banner'; wrap.href=pageUrl('shop'); wrap.setAttribute('aria-label','Shop RT Crackers fireworks');
    wrap.innerHTML=`<img src="${banner}" alt="RT Crackers Red Thunder fireworks catalogue banner">`;
    main.insertBefore(wrap,main.firstElementChild);
  }
  function wireWhatsApp(){
    document.querySelectorAll('a[href*="wa.me"], [data-whatsapp]').forEach(el=>{el.href='https://wa.me/'+cfg.whatsapp;});
    document.querySelectorAll('a[href^="tel:"]').forEach(el=>{ if(/98765|98450|94432|1800|842-GEAR/i.test(el.textContent||'')) el.href='tel:+91'+cfg.phone.replace(/^91/,''); el.textContent='+91 73587 37658'; });
  }
  async function hydrateCms(){
    const slugMap={'/about':'about','/shipping':'shipping','/privacy-policy':'privacy-policy','/terms-and-conditions':'terms-and-conditions'};
    const key=slugMap[location.pathname]; if(!key) return;
    try{
      const r=await platformApi('/cms/pages/'+encodeURIComponent(key)); const d=r?.data; if(!d)return;
      const title=document.querySelector('[data-cms-title]'); if(title && d.title) title.textContent=d.title;
      const content=document.querySelector('[data-cms-content]'); if(content && d.content_html) content.innerHTML=d.content_html;
    }catch(_){/* static fallback remains */}
  }
  function sanitizeCustomerContent(){
    if(isAdmin) return;
    document.querySelectorAll('a[data-path="returns-and-refunds"],a[data-path="returns-refunds"],a[data-path="returns"],a[data-path="returns-portal"],a[data-path="refunds"]').forEach(a=>a.closest('li')?.remove() || a.remove());
    document.querySelectorAll('[data-path="returns-and-refunds"],[data-path="returns-refunds"],[data-path="returns"],[data-path="returns-portal"],[data-path="refunds"]').forEach(el=>el.remove());
    const nodes=[...document.querySelectorAll('body *')];
    nodes.forEach(el=>{
      if(el.children.length===0 && /return|refund/i.test(el.textContent||'')){
        const t=(el.textContent||'').trim();
        if(/return|refund/i.test(t) && !/Return to|returning to|return key|return false/i.test(t)) el.textContent=t.replace(/refunds?/gi,'').replace(/returns?/gi,'').replace(/\s{2,}/g,' ').trim();
      }
    });
  }
  async function bindLogin(){
    const form=document.getElementById('passwordLoginForm'); if(!form)return;
    window.triggerAuthMock=async()=>{
      const email=(document.getElementById('userIdentifier')?.value||'').trim(); const password=document.getElementById('userPassword')?.value||'';
      if(!email || !password) return notify('Enter your email and password.','error');
      try{ await customerApi('/auth/login',{method:'POST',body:JSON.stringify({email,password})}); notify('Signed in successfully.'); setTimeout(()=>location.href=pageUrl('account'),350); }
      catch(e){ notify(e.message||'Sign in failed.','error'); }
    };
  }
  async function bindRegistration(){
    const form=document.getElementById('registration-form'); if(!form)return;
    form.onsubmit=async e=>{
      e.preventDefault();
      const q=id=>document.getElementById(id)?.value||'';
      const data={email:q('email'),password:q('password'),phone:q('phone'),first_name:q('first-name'),last_name:q('last-name')||null};
      try{await customerApi('/auth/register',{method:'POST',body:JSON.stringify(data)}); notify('Account created. Please verify your email.'); setTimeout(()=>location.href=pageUrl('account'),500);}catch(err){notify(err.message||'Registration failed.','error');}
    };
  }
  async function bindAddToCart(){
    const productId=document.body.dataset.productId || document.querySelector('[data-product-id]')?.dataset.productId;
    const add=async(pid,qty=1)=>{ if(!pid){notify('Product is not connected to a catalog record yet.','error');return;} try{await customerApi('/cart/items',{method:'POST',body:JSON.stringify({product_id:Number(pid),quantity:qty})}); await refreshCartBadge(); notify('Product added to cart.');}catch(e){notify(e.message||'Could not add to cart.','error');} };
    window.handleAddToCart=()=>add(productId,Math.max(1,Number(document.querySelector('#quantityInput')?.value||document.querySelector('#qty')?.value||1)));
    window.quickAddToCart=(name)=>{notify(`${name||'Product'} needs a catalog product ID before it can be added.`,'error');};
    window.handleBuyNow=async()=>{await window.handleAddToCart(); setTimeout(()=>location.href=pageUrl('cart'),350);};
  }
  function addSyncBadge(){
    if(document.querySelector('.rtc-sync-badge')) return;
    const b=document.createElement('div'); b.className='rtc-sync-badge'; b.textContent='RTCrackers live storefront'; document.body.appendChild(b);
  }
  async function adminContentEditor(){
    if(!isAdmin || !/admin_content_manager/.test(currentDir)) return;
    const rootEl=document.getElementById('rtc-cms-app'); if(!rootEl)return;
    const kinds=['pages','home-sections','faqs','policies']; let current='pages';
    const state={items:[],selected:null};
    const render=()=>{rootEl.innerHTML=`<div class="grid md:grid-cols-[260px_1fr] gap-6"><aside class="bg-white rounded-2xl border p-4"><h2 class="font-bold text-lg mb-4">Content types</h2>${kinds.map(k=>`<button data-kind="${k}" class="w-full text-left px-3 py-2 rounded-lg mb-1 ${k===current?'bg-red-600 text-white':'hover:bg-amber-50'}">${k}</button>`).join('')}</aside><section class="bg-white rounded-2xl border p-5"><div class="flex items-center justify-between gap-3 mb-4"><div><h2 class="font-bold text-xl">${current}</h2><p class="text-sm text-slate-500">Edit live content stored in the CMS database.</p></div><button id="cms-refresh" class="px-3 py-2 rounded-lg bg-slate-900 text-white">Refresh</button></div><div id="cms-list" class="space-y-2"></div><div id="cms-editor" class="mt-5"></div></section></div>`; rootEl.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{current=b.dataset.kind;load()}); rootEl.querySelector('#cms-refresh').onclick=load; };
    async function load(){render(); try{state.items=await adminApi('/cms/'+current); if(!Array.isArray(state.items)) state.items=state.items?.items||[]; const list=rootEl.querySelector('#cms-list'); list.innerHTML=state.items.map((x,i)=>`<button data-i="${i}" class="w-full text-left p-3 rounded-lg border hover:border-red-400"><div class="font-semibold">${escapeHtml(x.title||x.question||x.policy_key||x.section_key||('Record '+(i+1)))}</div><div class="text-xs text-slate-500">ID ${x.page_id||x.faq_id||x.policy_id||x.section_id||'—'}</div></button>`).join('')||'<p class="text-slate-500">No records yet.</p>'; list.querySelectorAll('[data-i]').forEach(b=>b.onclick=()=>edit(state.items[Number(b.dataset.i)])); }catch(e){rootEl.querySelector('#cms-list').innerHTML=`<p class="text-red-600">${escapeHtml(e.message||'Admin authentication or API unavailable.')}</p>`}}
    function edit(x){const ed=rootEl.querySelector('#cms-editor'); const id=x.page_id||x.faq_id||x.policy_id||x.section_id; ed.innerHTML=`<div class="border-t pt-5"><h3 class="font-bold mb-3">Edit record #${id}</h3><textarea id="cms-json" class="w-full min-h-72 p-3 border rounded-xl font-mono text-sm">${escapeHtml(JSON.stringify(x,null,2))}</textarea><div class="mt-3 flex gap-2"><button id="cms-save" class="px-4 py-2 rounded-lg bg-red-600 text-white">Save</button><button id="cms-cancel" class="px-4 py-2 rounded-lg border">Cancel</button></div></div>`; ed.querySelector('#cms-save').onclick=async()=>{try{const obj=JSON.parse(ed.querySelector('#cms-json').value); const payload={...obj}; delete payload.page_id;delete payload.faq_id;delete payload.policy_id;delete payload.section_id;delete payload.created_at;delete payload.updated_at; const id=x.page_id||x.faq_id||x.policy_id||x.section_id; await adminApi(`/cms/${current}/${id}`,{method:'PATCH',body:JSON.stringify({data:payload})}); notify('CMS record saved.');load();}catch(e){notify(e.message||'Save failed.','error')}}; ed.querySelector('#cms-cancel').onclick=()=>ed.innerHTML='';}
    function escapeHtml(s){return String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));}
    load();
  }
  function money(v){ return new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:2}).format(Number(v||0)); }
  function q(name){ return new URLSearchParams(location.search).get(name); }
  async function hydrateCatalog(){
    const grid=document.getElementById('product-card-grid'); if(!grid) return;
    try{
      const params=new URLSearchParams({page:'1',page_size:'24',sort:'newest'}); const data=await customerApi('/products?'+params.toString());
      const items=data?.items||data?.data?.items||[]; if(!items.length) return;
      grid.innerHTML=items.map(p=>`<article class="group relative bg-surface-container rounded-xl overflow-hidden shadow-lg flex flex-col"><a href="${pageUrl('product')}?slug=${encodeURIComponent(p.slug)}" class="block"><div class="aspect-[4/3] bg-surface-container-high overflow-hidden"><img class="w-full h-full object-cover" loading="lazy" src="${escapeAttr(p.primary_image||cfg.productImage)}" alt="${escapeAttr(p.name)}"></div><div class="p-4"><div class="text-xs uppercase tracking-widest text-secondary">${escapeHtml(p.category_name||'Fireworks')}</div><h3 class="font-semibold mt-1">${escapeHtml(p.name)}</h3><div class="mt-2 text-secondary font-bold">${money(p.selling_price)} <span class="text-xs text-on-surface-variant line-through">${money(p.mrp)}</span></div></div></a><button class="m-4 mt-0 py-2 rounded bg-primary-container text-white font-bold" data-live-add="${p.product_id}">ADD TO CART</button></article>`).join('');
      grid.querySelectorAll('[data-live-add]').forEach(b=>b.addEventListener('click',async()=>{try{await customerApi('/cart/items',{method:'POST',body:JSON.stringify({product_id:Number(b.dataset.liveAdd),quantity:1})});await refreshCartBadge();notify('Product added to cart.');}catch(e){notify(e.message||'Could not add to cart.','error')}}));
    }catch(e){ console.warn('catalog hydration failed',e); }
  }
  function escapeHtml(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
  function escapeAttr(v){return escapeHtml(v);}
  async function hydrateProduct(){
    if(!/customer_page_3_product_details|\/product$/.test(location.pathname)) return;
    const id=q('slug')||q('id')||q('product_id'); if(!id) return;
    try{
      const p=await customerApi('/products/'+encodeURIComponent(id));
      document.body.dataset.productId=p.product_id;
      document.querySelectorAll('h1,h2').forEach(el=>{if(/Thunder|Rocket|Peony|Product/i.test(el.textContent||'') && el.textContent.length>8) el.textContent=p.name});
      const price=[...document.querySelectorAll('*')].find(el=>el.children.length===0 && /₹/.test(el.textContent||'')); if(price) price.textContent=money(p.selling_price);
      const imgs=document.querySelectorAll('img'); if(imgs[1]&&p.primary_image) imgs[1].src=p.primary_image;
    }catch(e){console.warn('product hydration failed',e)}
  }
  async function hydrateCart(){
    if(!/customer_page_4_shopping_cart/.test(location.pathname)) return;
    try{
      const c=await customerApi('/cart'); const items=c?.items||[];
      let box=document.getElementById('rtc-live-cart'); if(!box){box=document.createElement('section');box.id='rtc-live-cart';box.className='mx-auto max-w-5xl p-5 my-6 rounded-2xl bg-white border shadow-lg';document.querySelector('main')?.prepend(box);}
      box.innerHTML=`<div class="flex items-center justify-between gap-3 mb-4"><h2 class="text-xl font-bold">Your live cart</h2><strong>${money(c?.summary?.total_before_shipping||0)}</strong></div>`+(items.length?items.map(i=>`<div class="flex items-center gap-4 py-3 border-b"><img src="${escapeAttr(i.image||cfg.productImage)}" class="w-16 h-16 rounded object-cover" alt=""><div class="flex-1"><div class="font-semibold">${escapeHtml(i.name)}</div><div class="text-sm">${money(i.unit_price)} × ${i.quantity}</div></div><button data-cart-remove="${escapeAttr(i.line_key)}" class="text-red-600">Remove</button></div>`).join(''):`<p class="text-slate-500">Your cart is empty.</p>`)+`<div class="pt-4 flex justify-end"><a href="${pageUrl('checkout')}" class="px-5 py-3 rounded bg-primary-container text-white font-bold">Proceed to COD checkout</a></div>`;
      box.querySelectorAll('[data-cart-remove]').forEach(b=>b.onclick=async()=>{await customerApi('/cart/items/'+encodeURIComponent(b.dataset.cartRemove),{method:'DELETE'});hydrateCart();refreshCartBadge()});
    }catch(e){ if(e.status===401) notify('Please sign in to continue to checkout.','error'); }
  }
  async function hydrateCheckout(){
    if(!/customer_page_5_checkout/.test(location.pathname)) return;
    let box=document.getElementById('rtc-live-checkout'); if(!box){box=document.createElement('section');box.id='rtc-live-checkout';box.className='mx-auto max-w-5xl p-5 my-6 rounded-2xl bg-white text-slate-900 border shadow-xl';document.querySelector('main')?.prepend(box);}
    try{
      const addresses=await customerApi('/addresses');
      if(!addresses.length){box.innerHTML='<h2 class="text-xl font-bold">Delivery address required</h2><p class="mt-2">Add a saved address before placing a COD order.</p><a class="inline-block mt-4 px-4 py-2 rounded bg-primary-container text-white" href="'+pageUrl('addresses')+'">Manage addresses</a>';return;}
      const def=addresses.find(a=>a.is_default)||addresses[0];
      box.innerHTML=`<h2 class="text-xl font-bold mb-4">Live Cash on Delivery checkout</h2><form id="rtc-checkout-form" class="space-y-4"><label class="block"><span class="font-semibold">Delivery address</span><select id="rtc-address" class="mt-1 w-full border rounded p-3">${addresses.map(a=>`<option value="${a.address_id}" ${a.address_id===def.address_id?'selected':''}>${escapeHtml(a.address_label)} — ${escapeHtml(a.house_no)}, ${escapeHtml(a.street)}, ${escapeHtml(a.city)} ${escapeHtml(a.postal_code)}</option>`).join('')}</select></label><div id="rtc-shipping" class="text-sm"></div><div class="rounded-lg border p-3"><label class="flex gap-2 items-center"><input type="radio" checked disabled> <span><strong>Cash on Delivery</strong> — pay the confirmed order total in cash at delivery.</span></label></div><textarea id="rtc-notes" maxlength="500" class="w-full border rounded p-3" placeholder="Delivery notes (optional)"></textarea><div id="rtc-checkout-message" class="text-sm"></div><button class="w-full py-3 rounded bg-primary-container text-white font-bold" type="submit">PLACE COD ORDER</button></form>`;
      const loadQuote=async()=>{const aid=Number(document.getElementById('rtc-address').value); const r=await customerApi('/checkout/shipping-options?address_id='+aid); const options=(r.options||[]).filter(x=>x.available); document.getElementById('rtc-shipping').innerHTML=options.length?`Shipping: <select id="rtc-method" class="border rounded p-2 ml-2">${options.map(x=>`<option value="${escapeAttr(x.method_code)}">${escapeHtml(x.method_name)} — ${money(x.charge)}</option>`).join('')}</select>`:'No delivery option is available for this address.';};
      await loadQuote(); document.getElementById('rtc-address').onchange=loadQuote;
      document.getElementById('rtc-checkout-form').onsubmit=async e=>{e.preventDefault(); const msg=document.getElementById('rtc-checkout-message'); try{const body={shipping_address_id:Number(document.getElementById('rtc-address').value),shipping_method:document.getElementById('rtc-method')?.value||'STD',payment_method:'COD',notes:document.getElementById('rtc-notes').value||null}; const summary=await customerApi('/checkout/summary',{method:'POST',body:JSON.stringify(body)}); if(!summary.can_place_order) throw new Error((summary.blocking_issues||['Checkout validation failed']).join(' ')); const order=await customerApi('/orders',{method:'POST',body:JSON.stringify(body)}); msg.textContent='Order '+(order.order_number||order.order_id)+' placed successfully. Pay COD on delivery.'; setTimeout(()=>location.href=pageUrl('order-confirmation')+'?order='+encodeURIComponent(order.order_number||order.order_id),700);}catch(err){msg.textContent=err.message||'Unable to place order.';msg.className='text-sm text-red-600';}};
    }catch(e){ if(e.status===401){box.innerHTML='<p class="text-red-600 font-semibold">Please sign in before checkout.</p><a class="inline-block mt-3 px-4 py-2 rounded bg-primary-container text-white" href="'+pageUrl('login')+'">Sign in</a>';} else {box.innerHTML='<p class="text-red-600">Checkout is temporarily unavailable. Please try again.</p>';}}
  }
  function patchLocalLinks(){
    document.querySelectorAll('a[href="#"]').forEach(a=>{const t=(a.textContent||'').trim(); if(/order now|whatsapp business/i.test(t)) a.href='https://wa.me/'+cfg.whatsapp;});
  }
  function boot(){
    addThemeBar(); setLogo(); wireNavigation(); wireWhatsApp(); patchLocalLinks(); injectHomeBanner(); sanitizeCustomerContent(); addSyncBadge();
    refreshCartBadge(); hydrateCms(); bindLogin(); bindRegistration(); bindAddToCart(); hydrateCatalog(); hydrateProduct(); hydrateCart(); hydrateCheckout(); adminContentEditor();
    window.RTApi={customerApi,adminApi,platformApi,notify};
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot); else boot();
})();
