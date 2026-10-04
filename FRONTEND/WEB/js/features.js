/* RTCrackers — complete customer feature layer. */
(function(){
  'use strict';
  const $=(s,c=document)=>c.querySelector(s); const $$=(s,c=document)=>[...c.querySelectorAll(s)];
  const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const inr=n=>`₹${Number(n||0).toLocaleString('en-IN',{maximumFractionDigits:0})}`;
  const compareKey='rt_compare_v2';
  const readCompare=()=>{try{return JSON.parse(localStorage.getItem(compareKey)||'[]').map(Number).filter(Number.isFinite)}catch{return[]}};
  const saveCompare=x=>localStorage.setItem(compareKey,JSON.stringify([...new Set(x)].slice(0,4)));
  async function syncCompare(ids){try{if(window.RTAuth?.isGuest?.())return; await api('/comparison',{method:'PUT',body:JSON.stringify({product_ids:ids})})}catch(e){console.warn('Comparison sync skipped:',e.message)}}
  async function loadCompare(){try{const j=await api('/comparison');if(Array.isArray(j.product_ids))saveCompare(j.product_ids);else if(Array.isArray(j.items))saveCompare(j.items.map(x=>Number(x.product_id)));}catch{}}
  async function session(){try{const r=await window.RTAdmin?.supabaseSession?.();return r?.data?.session||r?.session||null}catch{return null}}
  async function api(path,opts={}){const s=await session();const h=Object.assign({'Content-Type':'application/json'},opts.headers||{});if(s?.access_token)h.Authorization=`Bearer ${s.access_token}`;const r=await fetch(`/api/features${path}`,{...opts,headers:h});const j=await r.json().catch(()=>({}));if(!r.ok||j.ok===false)throw new Error(j.error||'Request failed');return j}
  function toast(m){let x=$('#toast');if(!x){x=document.createElement('div');x.id='toast';x.className='toast';document.body.appendChild(x)}x.textContent=m;x.classList.add('show');clearTimeout(x._rt);x._rt=setTimeout(()=>x.classList.remove('show'),2800)}
  function addToOrder(id,qty=1){try{const raw=JSON.parse(localStorage.getItem('rt_crackers_order_v1')||'{"items":{},"delivery":{}}');raw.items=raw.items||{};raw.items[String(id)]=(Number(raw.items[String(id)])||0)+qty;localStorage.setItem('rt_crackers_order_v1',JSON.stringify(raw));window.dispatchEvent(new CustomEvent('rt-cart-changed'));toast('Added to cart');}catch(e){toast('Could not add to cart')}}
  function injectCardTools(card){if(card.querySelector('.rt-feature-tools'))return;const id=Number(card.dataset.id);const tools=document.createElement('div');tools.className='rt-feature-tools';tools.innerHTML=`<button type="button" class="rt-icon-btn rt-wish" data-id="${id}" aria-label="Add to wishlist">♡</button><button type="button" class="rt-compare-btn" data-id="${id}">Compare</button><a class="rt-detail-link" href="product.html?id=${encodeURIComponent(id)}">Details</a>`;card.querySelector('.product-body')?.prepend(tools)}
  function setupCards(){ $$('.product-card').forEach(injectCardTools) }
  async function toggleWishlist(id,btn){try{const s=await session();if(!s?.user||s.user.is_anonymous)return location.href='login.html?redirect='+encodeURIComponent(location.href);const current=btn.classList.contains('active');if(current){await api(`/wishlist/${id}`,{method:'DELETE'});btn.classList.remove('active');btn.textContent='♡';toast('Removed from wishlist')}else{await api(`/wishlist/${id}`,{method:'POST'});btn.classList.add('active');btn.textContent='♥';toast('Added to wishlist')}}catch(e){toast(e.message)}}
  function toggleCompare(id){let ids=readCompare();if(ids.includes(id))ids=ids.filter(x=>x!==id);else{if(ids.length>=4)return toast('You can compare up to 4 products');ids.push(id)}saveCompare(ids);syncCompare(ids);renderCompareBar();toast(ids.includes(id)?'Added to comparison':'Removed from comparison')}
  function productById(id){return (window.products||[]).find(p=>Number(p.id)===Number(id))}
  function renderCompareBar(){let ids=readCompare(),old=$('#rtCompareBar');if(!ids.length){old?.remove();return}if(!old){old=document.createElement('div');old.id='rtCompareBar';old.className='rt-compare-bar';document.body.appendChild(old)}old.innerHTML=`<strong>${ids.length}/4 selected</strong><button class="btn btn-primary btn-sm" id="rtOpenCompare">Compare now</button><a class="btn btn-outline btn-sm" href="products.html#compare">Browse</a><button class="btn btn-outline btn-sm" id="rtClearCompare">Clear</button>`}
  function openCompare(){const ids=readCompare(),products=ids.map(productById).filter(Boolean);if(!products.length)return toast('Select products first');let m=$('#rtCompareModal');if(!m){m=document.createElement('div');m.id='rtCompareModal';m.className='rt-modal';document.body.appendChild(m)}const fields=[['Price',p=>inr(p.price)],['MRP',p=>p.mrp?inr(p.mrp):'—'],['Category',p=>esc(p.category)],['Pack size',p=>esc(p.size||'—')],['Rating',p=>p.rating?`★ ${esc(p.rating)} (${p.review_count||0})`:'New'],['Stock',p=>p.stock_quantity==null?'Available':(p.stock_quantity>0?`${p.stock_quantity} available`:'Out of stock')],['Featured',p=>p.featured?'Yes':'—'],['Bestseller',p=>p.bestseller?'Yes':'—'],['New arrival',p=>p.new_arrival?'Yes':'—'],['Specifications',p=>`<pre class="rt-compare-pre">${esc(JSON.stringify(p.specifications||{},null,2))}</pre>`],['Safety',p=>esc(p.safety_information||'See product packaging and local safety guidance.')]];
    m.innerHTML=`<div class="rt-modal-card rt-compare-card" role="dialog" aria-modal="true"><button class="rt-modal-close" id="rtCloseCompare" aria-label="Close">×</button><div class="eyebrow">Product comparison</div><h2>Compare up to 4 products</h2><div class="rt-compare-scroll"><table><thead><tr><th>Feature</th>${products.map(p=>`<th><img class="rt-compare-img" src="${esc(p.image||'')}" alt="${esc(p.name)}" onerror="this.style.display='none'"><strong>${esc(p.name)}</strong><button class="btn btn-sm btn-primary rt-compare-add" data-id="${p.id}">Add to order</button></th>`).join('')}</tr></thead><tbody>${fields.map(([k,f])=>`<tr><th>${k}</th>${products.map(p=>`<td>${f(p)}</td>`).join('')}</tr>`).join('')}</tbody></table></div></div>`;m.classList.add('open');$('#rtCloseCompare',m).onclick=()=>m.remove();$$('.rt-compare-add',m).forEach(b=>b.onclick=()=>addToOrder(Number(b.dataset.id),1))}
  async function loadWishlistState(){try{const s=await session();if(!s?.user||s.user.is_anonymous)return;const j=await api('/wishlist');const ids=new Set((j.items||[]).map(x=>Number(x.product_id)));$$('.rt-wish').forEach(b=>{if(ids.has(Number(b.dataset.id))){b.classList.add('active');b.textContent='♥'}})}catch{}}
  function setupGlobalClicks(){document.addEventListener('click',e=>{const w=e.target.closest('.rt-wish');if(w){e.preventDefault();toggleWishlist(Number(w.dataset.id),w);return}const c=e.target.closest('.rt-compare-btn');if(c){e.preventDefault();toggleCompare(Number(c.dataset.id));return}if(e.target.closest('#rtOpenCompare'))openCompare();if(e.target.closest('#rtClearCompare')){saveCompare([]);renderCompareBar()}if(e.target.closest('.rt-add-order'))addToOrder(Number(e.target.closest('.rt-add-order').dataset.id),1)})}
  function setupDiscovery(){
    const input=$('#productSearch');
    if(!input||input.dataset.suggestReady)return;
    input.dataset.suggestReady='1';
    const host=input.closest('.search-box')||input.parentElement;
    host.style.position='relative';
    const box=document.createElement('div'); box.className='rt-suggestions'; box.setAttribute('role','listbox');
    host.appendChild(box);
    let timer=null, active=-1, latest=[];
    const close=()=>{box.classList.remove('show');active=-1};
    const render=(items,q)=>{
      latest=items||[]; active=-1;
      if(!latest.length){box.innerHTML=`<div class="rt-search-empty">No matching products found for <strong>${esc(q)}</strong></div>`;box.classList.add('show');return}
      box.innerHTML=latest.slice(0,8).map((p,i)=>`<a href="product.html?id=${encodeURIComponent(p.id)}" role="option" data-index="${i}"><strong>${esc(p.name)}</strong><small>${esc(p.categories?.name||p.category||'Product')} · ${inr(p.price)}${p.rating?` · ★ ${esc(p.rating)}`:''}</small></a>`).join('');
      box.classList.add('show');
    };
    const search=async q=>{
      try{const j=await api(`/search?q=${encodeURIComponent(q)}`);render(j.products||[],q)}
      catch{const needle=q.toLowerCase();render((window.products||[]).filter(p=>(p.name+' '+p.category+' '+(p.keywords||[]).join(' ')).toLowerCase().includes(needle)).slice(0,8),q)}
    };
    input.addEventListener('input',()=>{clearTimeout(timer);const q=input.value.trim();if(q.length<2){box.innerHTML='';close();return}timer=setTimeout(()=>search(q),160)});
    input.addEventListener('keydown',e=>{
      if(!box.classList.contains('show'))return;
      const count=latest.slice(0,8).length;
      if(e.key==='ArrowDown'){e.preventDefault();active=(active+1)%count;box.querySelectorAll('a').forEach((a,i)=>a.classList.toggle('active',i===active));}
      if(e.key==='ArrowUp'){e.preventDefault();active=(active-1+count)%count;box.querySelectorAll('a').forEach((a,i)=>a.classList.toggle('active',i===active));}
      if(e.key==='Enter'&&active>=0){e.preventDefault();box.querySelectorAll('a')[active]?.click();}
      if(e.key==='Escape'){e.preventDefault();close();input.focus();}
    });
    document.addEventListener('click',e=>{if(!host.contains(e.target))close()});
  }
  async function setupFestivalBox(){const host=$('[data-festival-box]');if(!host)return;let budget=5000;host.innerHTML=`<div class="rt-box-card"><div class="eyebrow">Build your own combo</div><h2>Festival Box</h2><p>Choose a budget, add eligible products and complete the box in one click.</p><div class="rt-box-budgets">${[1000,2500,5000,10000,25000].map(v=>`<button data-budget="${v}" class="btn btn-outline ${v===budget?'active':''}">${inr(v)}</button>`).join('')}</div><div class="rt-box-builder"><div><h3>Eligible products</h3><div id="rtBoxCatalog" class="rt-box-catalog"></div></div><div><h3>Your box</h3><div id="rtBoxItems"></div></div></div><div class="rt-box-summary"><strong>Budget: <span id="rtBoxBudget">${inr(budget)}</span></strong><span>Total: <span id="rtBoxTotal">₹0</span></span><span>Remaining: <span id="rtBoxRemaining">${inr(budget)}</span></span></div><button class="btn btn-primary" id="rtBoxCart">Add complete box to cart</button></div>`;
    const catalog=()=>((window.products||[]).filter(p=>p.festival_box_eligible!==false&&p.active!==false)).slice(0,80);
    function renderCatalog(){const list=catalog();$('#rtBoxCatalog').innerHTML=list.map(p=>`<div class="rt-box-product"><div><strong>${esc(p.name)}</strong><small>${esc(p.category)} · ${inr(p.price)}</small></div><button class="btn btn-sm btn-outline rt-box-add" data-id="${p.id}">Add</button></div>`).join('')||'<p>No eligible products available.</p>'}
    async function load(){try{const j=await api(`/box?budget=${budget}`);$('#rtBoxItems').innerHTML=(j.items||[]).map(x=>`<div class="rt-box-line"><div><strong>${esc(x.products?.name||'Product')}</strong><small>${inr(x.products?.price)} each</small></div><div class="rt-box-controls"><button data-box-minus="${x.product_id}">−</button><span>${x.quantity}</span><button data-box-plus="${x.product_id}">+</button><button data-remove-box="${x.product_id}" class="btn btn-sm btn-outline">Remove</button></div></div>`).join('')||'<p class="rt-muted">Add products from the catalog to build your box.</p>';$('#rtBoxBudget').textContent=inr(budget);$('#rtBoxTotal').textContent=inr(j.total);$('#rtBoxRemaining').textContent=inr(Math.max(0,budget-j.total));renderCatalog()}catch(e){$('#rtBoxItems').innerHTML=`<p class="rt-muted">${esc(e.message)} — sign in to use Festival Box.</p>`;renderCatalog()}}
    host.addEventListener('click',async e=>{try{const b=e.target.closest('[data-budget]');if(b){budget=Number(b.dataset.budget);$$('[data-budget]',host).forEach(x=>x.classList.toggle('active',x===b));return load()}const a=e.target.closest('.rt-box-add');if(a){await api('/box',{method:'POST',body:JSON.stringify({product_id:Number(a.dataset.id),quantity:1,budget})});return load()}const rem=e.target.closest('[data-remove-box]');if(rem){await api(`/box/${rem.dataset.removeBox}`,{method:'DELETE'});return load()}const plus=e.target.closest('[data-box-plus]'),minus=e.target.closest('[data-box-minus]');if(plus||minus){const id=Number((plus||minus).dataset[plus?'boxPlus':'boxMinus']);const current=(await api(`/box?budget=${budget}`)).items.find(x=>Number(x.product_id)===id);const qty=Math.max(1,Number(current?.quantity||1)+(plus?1:-1));await api('/box',{method:'POST',body:JSON.stringify({product_id:id,quantity:qty,budget})});return load()}if(e.target.id==='rtBoxCart'){const j=await api(`/box?budget=${budget}`);if(!j.items?.length)return toast('Add at least one product');if(Number(j.total)>budget)return toast('Your box is over budget');const raw=JSON.parse(localStorage.getItem('rt_crackers_order_v1')||'{"items":{},"delivery":{}}');raw.items=raw.items||{};(j.items||[]).forEach(x=>raw.items[String(x.product_id)]=(Number(raw.items[String(x.product_id)])||0)+Number(x.quantity||1));localStorage.setItem('rt_crackers_order_v1',JSON.stringify(raw));toast('Complete Festival Box added to cart');setTimeout(()=>location.href='order.html',350)}}catch(err){toast(err.message)}});renderCatalog();load()}

  async function refreshNotificationBadge(){
    try{
      const s=await session(); if(!s?.user || s.user.is_anonymous) return;
      const j=await api('/notifications'); const unread=(j.items||[]).filter(n=>!n.is_read).length;
      document.querySelectorAll('a[href="account.html"],a[href="/account"]').forEach(a=>{
        let badge=a.querySelector('.rt-notification-badge');
        if(unread>0){ if(!badge){badge=document.createElement('span');badge.className='rt-notification-badge';a.appendChild(badge)} badge.textContent=unread>99?'99+':String(unread); }
        else badge?.remove();
      });
    }catch{}
  }
  function initNotificationBadge(){refreshNotificationBadge();window.addEventListener('focus',refreshNotificationBadge);setInterval(refreshNotificationBadge,60000);}

  function productDetail(){
    const id=Number(new URLSearchParams(location.search).get('id'));const host=$('#productDetail');if(!id||!host)return;const p=productById(id);
    if(!p){host.innerHTML='<div class="empty-state"><h2>Product not found</h2><a class="btn btn-primary" href="products.html">Back to products</a></div>';return}
    let recent=[];try{recent=JSON.parse(localStorage.getItem('rt_recent_products')||'[]').map(Number).filter(x=>x!==id).slice(0,5)}catch{};recent=[id,...recent];localStorage.setItem('rt_recent_products',JSON.stringify(recent.slice(0,6)));
    const related=(window.products||[]).filter(x=>Number(x.id)!==id&&x.category===p.category).slice(0,4);
    const tracked=p.stock_quantity!=null, stock=tracked?Number(p.stock_quantity):null, out=tracked&&stock<=0, stockLabel=!tracked?'Available':(out?'Out of stock':stock<=5?`Only ${stock} left`:'In stock');
    const specs=p.specifications&&typeof p.specifications==='object'?Object.entries(p.specifications):[];
    host.innerHTML=`<div class="rt-product-detail"><div class="rt-product-gallery">${p.image?`<img src="${esc(p.image)}" alt="${esc(p.name)}" loading="lazy" decoding="async">`:'<div class="rt-product-placeholder">Product</div>'}</div><div><span class="eyebrow">${esc(p.category)}</span><h1>${esc(p.name)}</h1><p class="rt-rating">${p.rating?`★ ${esc(p.rating)} · ${p.review_count||0} reviews`:'New product'} · <strong class="${out?'stock-out':'stock-ok'}">${stockLabel}</strong></p><p class="rt-price">${inr(p.price)} <small>${p.mrp&&p.mrp>p.price?`<s>${inr(p.mrp)}</s> · `:''}${p.size?esc(p.size):'Per box'}</small></p><p>${esc(p.description||'Premium product.')}</p><div class="rt-detail-actions"><button class="btn btn-primary" id="rtDetailAdd" ${out?'disabled':''}>${out?'Out of stock':'Add to cart'}</button><button class="btn btn-outline" id="rtDetailWish">♡ Wishlist</button><button class="btn btn-outline" id="rtDetailCompare">Compare</button></div><div class="rt-delivery-mini"><strong>Delivery availability</strong><p>Server-side PIN validation runs again when the order is submitted.</p><a class="btn btn-sm btn-outline" href="order.html#delivery">Check delivery</a></div><div class="rt-specs"><h3>Specifications & Safety</h3>${specs.length?`<table class="rt-spec-table"><tbody>${specs.map(([k,v])=>`<tr><th>${esc(k)}</th><td>${esc(typeof v==='object'?JSON.stringify(v):v)}</td></tr>`).join('')}</tbody></table>`:'<p class="rt-muted">No specifications published.</p>'}<div class="rt-safety"><strong>Safety information</strong><p>${esc(p.safety_information||'Follow the product packaging and local safety guidance.')}</p></div></div></div></div><section class="rt-related"><div class="eyebrow">More to explore</div><h2>More products</h2><div class="rt-related-grid">${related.map(x=>`<article class="rt-mini-product"><a href="product.html?id=${x.id}">${x.image?`<img src="${esc(x.image)}" alt="${esc(x.name)}" loading="lazy">`:''}<strong>${esc(x.name)}</strong><span>${inr(x.price)}</span></a><button class="btn btn-sm btn-primary rt-add-order" data-id="${x.id}" ${x.stock_quantity!=null&&Number(x.stock_quantity)<=0?'disabled':''}>${x.stock_quantity!=null&&Number(x.stock_quantity)<=0?'Out of stock':'Add'}</button></article>`).join('')||'<p class="rt-muted">No related products.</p>'}</div></section>`;
    $('#rtDetailAdd').onclick=()=>{addToOrder(id,1);setTimeout(()=>location.href='order.html',250)};$('#rtDetailWish').onclick=()=>toggleWishlist(id,$('#rtDetailWish'));$('#rtDetailCompare').onclick=()=>toggleCompare(id);loadReviewPanel(id);
  }
  async function loadReviewPanel(id){
    const host=$('#productReviews');
    if(!host)return;
    try{
      const j=await api(`/reviews/${id}`);
      host.innerHTML=(j.items||[]).length
        ? (j.items||[]).map(x=>`<article class="rt-review"><div><strong>${'★'.repeat(Number(x.rating))}${'☆'.repeat(5-Number(x.rating))}</strong> <span>${x.verified_purchase?'✓ Verified purchase':''}</span></div><h4>${esc(x.title||'Customer review')}</h4><p>${esc(x.comment||'')}</p><small>${new Date(x.created_at).toLocaleDateString('en-IN')}</small></article>`).join('')
        : '<p class="rt-muted">No approved reviews yet.</p>';
      const s=await session();
      if(!s?.user||s.user.is_anonymous)return;
      const r=await api('/reviewable-products');
      const item=(r.items||[]).find(x=>Number(x.product?.id)===id);
      if(!item)return;
      host.insertAdjacentHTML('beforeend',`<div class="rt-review-form"><h3>Write your review</h3><form id="rtReviewForm"><input type="hidden" id="rtReviewOrder" value="${esc(item.order_id)}"><label>Rating <select id="rtReviewRating"><option value="5">5 ★</option><option value="4">4 ★</option><option value="3">3 ★</option><option value="2">2 ★</option><option value="1">1 ★</option></select></label><input id="rtReviewTitle" placeholder="Review title" maxlength="120"><textarea id="rtReviewComment" placeholder="Tell other customers about this product" maxlength="2000" required></textarea><button class="btn btn-primary">Submit review</button></form></div>`);
      $('#rtReviewForm').onsubmit=async e=>{
        e.preventDefault();
        try{
          await api('/reviews',{method:'POST',body:JSON.stringify({product_id:id,rating:Number($('#rtReviewRating').value),title:$('#rtReviewTitle').value,comment:$('#rtReviewComment').value,order_id:$('#rtReviewOrder').value})});
          toast('Review submitted for moderation');
          e.target.remove();
        }catch(err){toast(err.message)}
      };
    }catch(e){host.innerHTML='<p class="rt-muted">Reviews are temporarily unavailable.</p>'}
  }
  async function festivalCountdown(){try{const j=await api('/festival');const f=j.item;if(!f)return;let box=$('#rtFestivalCountdown');if(!box){box=document.createElement('section');box.id='rtFestivalCountdown';box.className='section-tight';box.innerHTML='<div class="container"><div class="rt-box-card"><span class="eyebrow">Festival Sale</span><h2 id="rtFestivalName"></h2><p id="rtFestivalDesc"></p><div id="rtCountdown" class="rt-countdown"></div></div></div>';document.body.insertBefore(box,document.body.firstChild)}$('#rtFestivalName').textContent=f.name;$('#rtFestivalDesc').textContent=f.description||'';if(f.banner){box.style.backgroundImage=`linear-gradient(135deg,rgba(7,15,36,.88),rgba(52,25,69,.88)),url('${String(f.banner).replace(/'/g,'%27')}')`;box.style.backgroundSize='cover';box.style.backgroundPosition='center'}const theme=f.theme||{};const root=document.documentElement;[['primary','--festival-primary'],['secondary','--festival-secondary'],['accent','--festival-accent'],['background','--festival-background']].forEach(([k,v])=>{if(theme[k])root.style.setProperty(v,theme[k])});const end=new Date(f.end_at||Date.now()).getTime();const tick=()=>{const d=Math.max(0,end-Date.now());const days=Math.floor(d/86400000),h=Math.floor(d%86400000/3600000),m=Math.floor(d%3600000/60000),sec=Math.floor(d%60000/1000);$('#rtCountdown').textContent=`${days}d ${String(h).padStart(2,'0')}h ${String(m).padStart(2,'0')}m ${String(sec).padStart(2,'0')}s`;if(d<=0){box.remove();return}setTimeout(tick,1000)};tick()}catch{}}
  document.addEventListener('DOMContentLoaded',()=>{setupGlobalClicks();setupDiscovery();loadCompare();renderCompareBar();setupCards();loadWishlistState();setupFestivalBox();festivalCountdown();initNotificationBadge();setTimeout(productDetail,350);const obs=new MutationObserver(()=>{setupCards();loadWishlistState()});obs.observe(document.body,{childList:true,subtree:true});});
})();
