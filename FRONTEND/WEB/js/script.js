/* =========================================================
   RTCRACKERS — script.js
   Handles: nav, product rendering, search/filter/sort,
   order cart, browser cart storage, shipping calc, form validation,
   WhatsApp / email order-request generation.
   ========================================================= */

(async function () {
  "use strict";

  // Wait for Supabase products/categories/company settings and auth state.
  if (window.RTAdmin && window.RTAdmin.ready) {
    try { await window.RTAdmin.ready; } catch (e) { console.error(e); }
  }
  if (window.RTAdmin && window.RTAdmin.authReady) {
    try { await window.RTAdmin.authReady; } catch (e) { console.error(e); }
  }

  /* ---------------- Company / policy constants ----------------
     Sourced from the supplied Product List Final.xlsx and the site's
     published policy content, with Admin Dashboard changes layered
     on top from Supabase company_details/company_policies. */
  const adminCompany = (window.RTAdmin && window.RTAdmin.getCompanyOverrides()) || {};
  const adminPolicy = (window.RTAdmin && window.RTAdmin.getPolicyOverrides()) || {};

  const COMPANY = Object.assign({
    name: "RTCrackers",
    brand: "RTCrackers",
    addressFactory: "22, Sivan Sannathi Road, Parasakthi Colony, Sivakasi - 626123",
    addressAdmin: "14, Rajendra Prasath Street, Manali, Chennai - 600068",
    phoneProductList: "7358633576",
    phonePolicy: "7358737658",
    whatsapp: "7299941355",
    whatsappDisplay: "72999 41355",
    email: "sales@rtcrackers.com",
    website: "www.rtcrackers.com"
  }, adminCompany);

  // Where "order placed" notifications are sent via the email/WhatsApp
  // order-request buttons. This is a temporary/demo address — swap it
  // for the real one whenever you're ready (see README).
  const ORDER_NOTIFY_EMAIL = String(adminCompany.email || "").trim();

  const POLICY = Object.assign({
    minOrderValue: 2000,
    flatShippingFee: 250,
    freeDeliveryThreshold: 10000,
    chennaiKumbakonamFlat: 250, // per policy: applies to ALL Chennai/Kumbakonam orders
    cancellationWindowHrs: 24,
    cancellationFeePct: 25,
    refundDays: 15,
    maxDeliveryAttempts: 2
  }, adminPolicy);

  const STORAGE_KEY = "rt_crackers_order_v1";

  /* ---------------- Utility ---------------- */
  const $ = (sel, ctx) => (ctx || document).querySelector(sel);
  const $all = (sel, ctx) => Array.from((ctx || document).querySelectorAll(sel));

  const inr = (n) => {
    try {
      return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(n);
    } catch (e) {
      return "₹" + n;
    }
  };

  function toast(msg) {
    let el = $("#toast");
    if (!el) {
      el = document.createElement("div");
      el.id = "toast";
      el.className = "toast";
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add("show");
    clearTimeout(el._t);
    el._t = setTimeout(() => el.classList.remove("show"), 2600);
  }

  /* ---------------- Cart storage ---------------- */
  function loadCart() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return { items: {}, delivery: {} };
      const parsed = JSON.parse(raw);
      return { items: parsed.items || {}, delivery: parsed.delivery || {} };
    } catch (e) {
      return { items: {}, delivery: {} };
    }
  }

  function saveCart(cart) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(cart));
    } catch (e) {
      console.error("Could not save order request locally:", e);
    }
  }

  let cart = loadCart();

  function cartCount() {
    return Object.values(cart.items).reduce((sum, q) => sum + q, 0);
  }

  function cartLines() {
    const lines = [];
    Object.keys(cart.items).forEach((id) => {
      const qty = cart.items[id];
      if (qty <= 0) return;
      const product = (window.products || []).find((p) => String(p.id) === String(id));
      if (product) lines.push({ product, qty });
    });
    return lines;
  }

  function cartSubtotal() {
    return cartLines().reduce((sum, l) => sum + l.product.price * l.qty, 0);
  }

  function addToCart(id, qty) {
    qty = qty || 1;
    const key = String(id);
    cart.items[key] = (cart.items[key] || 0) + qty;
    saveCart(cart);
    refreshCartUI();
    toast("Added to your order request");
  }

  function setQty(id, qty) {
    const key = String(id);
    if (qty <= 0) {
      delete cart.items[key];
    } else {
      cart.items[key] = qty;
    }
    saveCart(cart);
    refreshCartUI();
  }

  function removeFromCart(id) {
    delete cart.items[String(id)];
    saveCart(cart);
    refreshCartUI();
    toast("Removed from order request");
  }

  function clearCart() {
    cart = { items: {}, delivery: cart.delivery };
    saveCart(cart);
    refreshCartUI();
    toast("Order request cleared");
  }

  function refreshCartUI() {
    $all(".cart-count").forEach((el) => (el.textContent = cartCount()));
    if (typeof window.onCartChange === "function") window.onCartChange();
  }

  /* ---------------- Shipping logic ----------------
     Policy source (Policy.docx):
     - Chennai & Kumbakonam: flat Rs.250 shipping on ALL orders (door-to-door).
     - Rest of Tamil Nadu: delivered to nearest transporter godown; the
       transporter fee is paid directly by the customer on collection and
       is NOT calculated by this website (amount not specified by policy).
     - Minimum order value: Rs.2000 after discount.
     - Free delivery is stated for orders >= Rs.10,000, but the policy also
       states the Rs.250 Chennai/Kumbakonam flat fee applies to ALL orders
       in those locations — so for Chennai/Kumbakonam the Rs.250 fee is
       shown regardless of order value, and the discrepancy is surfaced
       to the customer rather than silently resolved.                     */
  function computeShipping(location, subtotal) {
    const result = { fee: 0, label: "", note: "" };

    if (location === "chennai" || location === "kumbakonam") {
      result.fee = POLICY.chennaiKumbakonamFlat;
      result.label = "Flat shipping (Chennai / Kumbakonam)";
      if (subtotal >= POLICY.freeDeliveryThreshold) {
        result.note = "Policy note: orders of ₹10,000+ qualify for free delivery, but the policy also states a flat ₹250 shipping fee applies to ALL Chennai/Kumbakonam orders. We are showing the ₹250 flat fee per that specific rule — please confirm with RTCrackers if you believe free delivery should apply.";
      }
    } else if (location === "other") {
      result.fee = 0;
      result.label = "Transporter fee (payable directly by you)";
      result.note = "Your order will be delivered to the nearest transporter warehouse/godown. Transporter delivery charges are payable directly by you while collecting the parcel — this amount is not fixed by RTCrackers' policy and is not calculated on this website.";
    } else {
      result.fee = 0;
      result.label = "Select a delivery location to see shipping";
    }
    return result;
  }

  /* ---------------- Reference number ---------------- */
  function generateRefNumber() {
    const year = new Date().getFullYear();
    const rand = Math.floor(10000 + Math.random() * 89999);
    return `RT-ORD-${year}-${rand}`;
  }

  /* ---------------- Mobile nav ---------------- */
  function initNav() {
    const btn = $(".hamburger");
    const nav = $(".mobile-nav");
    if (btn && nav) {
      btn.type = "button";
      btn.setAttribute("aria-controls", nav.id || "mobile-nav");
      nav.id = nav.id || "mobile-nav";
      btn.setAttribute("aria-expanded", "false");
      let backdrop = $(".mobile-nav-backdrop");
      if (!backdrop) {
        backdrop = document.createElement("div");
        backdrop.className = "mobile-nav-backdrop";
        backdrop.setAttribute("aria-hidden", "true");
        document.body.appendChild(backdrop);
      }
      const close = () => {
        nav.classList.remove("open");
        backdrop.classList.remove("open");
        btn.classList.remove("is-open");
        btn.setAttribute("aria-expanded", "false");
        btn.setAttribute("aria-label", "Open menu");
        document.body.classList.remove("menu-open");
      };
      const open = () => {
        nav.classList.add("open");
        backdrop.classList.add("open");
        btn.classList.add("is-open");
        btn.setAttribute("aria-expanded", "true");
        btn.setAttribute("aria-label", "Close menu");
        document.body.classList.add("menu-open");
      };
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        nav.classList.contains("open") ? close() : open();
      });
      backdrop.addEventListener("click", close);
      $all(".mobile-nav a").forEach((a) => a.addEventListener("click", close));
      document.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
      window.addEventListener("resize", () => { if (window.innerWidth > 768) close(); }, { passive: true });
      window.addEventListener("pageshow", close);
    }
    const path = window.location.pathname.split("/").pop() || "index.html";
    $all("[data-nav]").forEach((a) => {
      if (a.getAttribute("data-nav") === path) a.classList.add("active");
    });
  }

  /* ---------------- Accordion (policy page) ---------------- */
  function initAccordion() {
    $all(".accordion-head").forEach((head) => {
      head.addEventListener("click", () => {
        const item = head.closest(".accordion-item");
        item.classList.toggle("open");
      });
    });
  }

  /* ---------------- Product listing (products.html) ---------------- */
  function renderProductCard(p) {
    const qty = cart.items[String(p.id)] || 0;
    const priceStr = inr(p.price);
    const tracked = p.stock_quantity != null;
    const stock = tracked ? Number(p.stock_quantity) : null;
    const outOfStock = tracked && stock <= 0;
    const stockLabel = !tracked ? "Available" : (stock <= 0 ? "Out of stock" : (stock <= 5 ? `Only ${stock} left` : "In stock"));
    return `
      <div class="product-card${outOfStock ? ' is-out-of-stock' : ''}" data-id="${p.id}" data-name="${p.name.toLowerCase()}" data-category="${p.category.toLowerCase()}">
        <div class="product-thumb">
          ${p.image ? `<img src="${p.image}" alt="${p.name}" loading="lazy" style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;" onerror="this.remove()">` : ""}
          <span class="spark-mark" aria-hidden="true">✨</span>
          <span class="brand-tag">RTCrackers</span>
        </div>
        <div class="product-body">
          <span class="product-cat">${p.category}</span>
          <span class="product-name">${p.name}</span>
          <span class="product-size">${p.size ? "Pack: " + p.size : "Per box"}</span>
          <span class="product-stock ${outOfStock ? "stock-out" : stock !== null && stock <= 5 ? "stock-low" : "stock-ok"}">${stockLabel}</span>
          <span class="product-price">${priceStr} <small>/ box</small></span>
          ${qty > 0
        ? `<div class="qty-stepper" data-id="${p.id}">
                   <button type="button" class="qty-minus" aria-label="Decrease quantity">−</button>
                   <span class="qty-val">${qty}</span>
                   <button type="button" class="qty-plus" aria-label="Increase quantity">+</button>
                 </div>`
        : outOfStock ? `<button type="button" class="btn btn-outline btn-sm btn-block add-btn" data-id="${p.id}" disabled>Out of stock</button>` : `<button type="button" class="btn btn-primary btn-sm btn-block add-btn" data-id="${p.id}">Add to Order</button>`
      }
        </div>
      </div>`;
  }

  function productByIdGlobal(id){return (window.products||[]).find(p=>Number(p.id)===Number(id));}

  function initProductsPage() {
    const grid=$("#productGrid"); if(!grid)return;
    const searchInput=$("#productSearch"), sortSelect=$("#sortSelect"), filterBar=$("#filterBar"), resultsCount=$("#resultsCount");
    const minPrice=$("#minPrice"), maxPrice=$("#maxPrice"), ratingFilter=$("#ratingFilter"), featuredOnly=$("#featuredOnly"), bestsellerOnly=$("#bestsellerOnly"), newOnly=$("#newOnly");
    let activeCategory="all", sortMode="default", query="";
    if(filterBar&&window.categories){const chips=["All",...window.categories];filterBar.innerHTML=chips.map(c=>`<button type="button" class="filter-chip${c==='All'?' active':''}" data-cat="${escapeHtml(c.toLowerCase())}">${escapeHtml(c)}</button>`).join('');filterBar.onclick=e=>{const chip=e.target.closest('.filter-chip');if(!chip)return;$all('.filter-chip',filterBar).forEach(c=>c.classList.remove('active'));chip.classList.add('active');activeCategory=chip.dataset.cat;render()};}
    const rerender=()=>render();
    [minPrice,maxPrice,ratingFilter,featuredOnly,bestsellerOnly,newOnly].forEach(el=>el?.addEventListener(el?.type==='checkbox'?'change':'input',rerender));
    sortSelect?.addEventListener('change',e=>{sortMode=e.target.value;render()});
    function getFiltered(){let list=(window.products||[]).slice();if(activeCategory!=='all')list=list.filter(p=>String(p.category).toLowerCase()===activeCategory);if(query)list=list.filter(p=>(`${p.name} ${p.category} ${(p.keywords||[]).join(' ')}`).toLowerCase().includes(query));const min=Number(minPrice?.value),max=Number(maxPrice?.value),rating=Number(ratingFilter?.value||0);if(Number.isFinite(min)&&min>0)list=list.filter(p=>Number(p.price)>=min);if(Number.isFinite(max)&&max>0)list=list.filter(p=>Number(p.price)<=max);if(rating)list=list.filter(p=>Number(p.rating||0)>=rating);if(featuredOnly?.checked)list=list.filter(p=>p.featured);if(bestsellerOnly?.checked)list=list.filter(p=>p.bestseller);if(newOnly?.checked)list=list.filter(p=>p.new_arrival);switch(sortMode){case'price-asc':list.sort((a,b)=>a.price-b.price);break;case'price-desc':list.sort((a,b)=>b.price-a.price);break;case'name-asc':list.sort((a,b)=>a.name.localeCompare(b.name));break;case'rating-desc':list.sort((a,b)=>(b.rating||0)-(a.rating||0));break;case'newest':list.sort((a,b)=>Number(b.id)-Number(a.id));break;case'discount':list.sort((a,b)=>((b.mrp||b.price)-b.price)-((a.mrp||a.price)-a.price));break;default:list.sort((a,b)=>a.id-b.id)}return list}
    function render(){const list=getFiltered();if(resultsCount)resultsCount.textContent=`Showing ${list.length} of ${(window.products||[]).length} products`;grid.innerHTML=list.length?list.map(renderProductCard).join(''):`<div class="empty-state" style="grid-column:1/-1;"><div class="big">🔍</div><h3>No products match</h3><p>Try another keyword, price range or category.</p><button class="btn btn-outline" id="resetFilters">Reset filters</button></div>`}
    grid.addEventListener('click',e=>{const reset=e.target.closest('#resetFilters');if(reset){if(searchInput)searchInput.value='';if(minPrice)minPrice.value='';if(maxPrice)maxPrice.value='';if(ratingFilter)ratingFilter.value='0';[featuredOnly,bestsellerOnly,newOnly].forEach(x=>{if(x)x.checked=false});activeCategory='all';$all('.filter-chip',filterBar||document).forEach(c=>c.classList.toggle('active',c.dataset.cat==='all'));render();return}const add=e.target.closest('.add-btn');if(add){addToCart(add.dataset.id,1);render();return}const minus=e.target.closest('.qty-minus'),plus=e.target.closest('.qty-plus');if(minus||plus){const step=e.target.closest('.qty-stepper'),id=step.dataset.id,current=cart.items[String(id)]||0,product=productByIdGlobal(id),max=product?.stock_quantity==null?Infinity:Number(product.stock_quantity);if(plus&&current>=max)return;setQty(id,minus?current-1:current+1);render()}});
    searchInput?.addEventListener('input',e=>{query=e.target.value.trim().toLowerCase();render()});
    const params=new URLSearchParams(location.search),urlCat=params.get('category'),urlQ=params.get('q');if(urlQ&&searchInput){searchInput.value=urlQ;query=urlQ.trim().toLowerCase()}if(urlCat&&filterBar){const chip=$all('.filter-chip',filterBar).find(c=>c.dataset.cat===urlCat.toLowerCase());if(chip)chip.click();else render()}else render();window.onCartChange=render;
  }

  /* ---------------- Featured products (home page) ---------------- */
  function initFeatured() {
    const el = $("#featuredGrid");
    if (!el || !window.products) return;
    const picks = window.products.filter((p) =>
      ["Sparklers", "Flower Pots", "Gift Boxes", "Rockets", "Kids Special", "Fancy Fountains", "Sound Crackers", "Rang Dance"].includes(p.category)
    );
    const chosen = [];
    const seenCat = new Set();
    for (const p of picks) {
      if (!seenCat.has(p.category)) {
        chosen.push(p);
        seenCat.add(p.category);
      }
      if (chosen.length >= 8) break;
    }
    el.innerHTML = chosen.map(renderProductCard).join("");
    el.addEventListener("click", (e) => {
      const addBtn = e.target.closest(".add-btn");
      if (addBtn) {
        addToCart(addBtn.getAttribute("data-id"), 1);
        el.innerHTML = chosen.map(renderProductCard).join("");
      }
      const minus = e.target.closest(".qty-minus");
      const plus = e.target.closest(".qty-plus");
      if (minus || plus) {
        const stepper = e.target.closest(".qty-stepper");
        const id = stepper.getAttribute("data-id");
        const current = cart.items[String(id)] || 0;
        setQty(id, minus ? current - 1 : current + 1);
        el.innerHTML = chosen.map(renderProductCard).join("");
      }
    });
  }

  /* ---------------- Category tiles (home page) ---------------- */
  function initCategoryTiles() {
    const el = $("#categoryGrid");
    if (!el || !window.categories) return;
    const emojiMap = {
      "Sparklers": "🎇", "Ground Chakkars": "🌀", "Flower Pots": "🌸", "Kids Special": "🧒",
      "Sound Crackers": "💥", "Chorsa & Giant Crackers": "🧨", "Festival Garlands": "🎉",
      "Rockets": "🚀", "Fancy Wheels": "🎡", "Fancy Fountains": "⛲", "Fancy Novelties": "✨",
      "Multiple Aerials": "🎆", "Multiple Multi Colours": "🌈", "Rang Park": "🎢",
      "Fancy Week": "🗓️", "Rang Dhara": "🌊", "Rang Flora": "🌺", "Rang Music": "🎵",
      "Rang Dance": "💃", "Rang Game": "🎮", "Gift Boxes": "🎁"
    };
    el.innerHTML = window.categories
      .map((c) => {
        const count = window.products.filter((p) => p.category === c).length;
        return `<a class="cat-tile" href="products.html?category=${encodeURIComponent(c.toLowerCase())}">
          <span class="cat-emoji">${(window.categoryEmoji && window.categoryEmoji[c]) || emojiMap[c] || "🎆"}</span>
          <span class="cat-name">${c}</span>
          <span class="cat-count">${count} products</span>
        </a>`;
      })
      .join("");
  }

  /* ---------------- Order page (cart + checkout) ---------------- */
  function initOrderPage() {
    const orderList = $("#orderList");
    if (!orderList) return;

    const emptyState = $("#orderEmptyState");
    const orderForm = $("#orderForm");
    const subtotalEl = $("#sumSubtotal");
    const shippingEl = $("#sumShipping");
    const shippingLabelEl = $("#sumShippingLabel");
    const totalEl = $("#sumTotal");
    const shippingNoteEl = $("#shippingNote");
    const minWarning = $("#minOrderWarning");
    const submitBtn = $("#submitOrderBtn");
    const waBtn = $("#waOrderBtn");
    const emailBtn = $("#emailOrderBtn");
    const pincodeResult = $("#pincodeResult");
    const couponInput = $("#couponCode");
    const couponStatus = $("#couponStatus");
    const applyCouponBtn = $("#applyCouponBtn");
    let appliedCoupon = "";
    let couponDiscount = 0;
    let offerDiscount = 0;
    let freeDeliveryOffer = false;
    let reviewReady = false;

    function setCheckoutStep(step){
      $all("#checkoutStepper span").forEach((el,i)=>el.classList.toggle("active",i<=step));
    }

    async function loadSavedAddresses(){
      const select=$("#savedAddressSelect"); if(!select) return;
      try{
        const session=await window.RTAdmin?.supabaseSession?.();
        if(!session?.data?.session?.user || session.data.session.user.is_anonymous) return;
        const r=await fetch("/api/features/addresses",{headers:{Authorization:`Bearer ${session.data.session.access_token}`}});
        const j=await r.json();
        (j.items||[]).forEach(a=>{const o=document.createElement("option");o.value=a.id;o.textContent=`${a.label} — ${a.recipient_name} · ${a.pincode}`;o.dataset.address=JSON.stringify(a);select.appendChild(o)});
        const def=(j.items||[]).find(a=>a.is_default); if(def) select.value=def.id;
      }catch{}
      select.addEventListener("change",()=>{const o=select.selectedOptions[0];if(!o?.dataset.address)return;const a=JSON.parse(o.dataset.address);[["fullName",a.recipient_name],["phoneNumber",a.phone],["emailAddress",window.RTAdmin?.currentUser?.()?.email||""],["deliveryAddress",[a.address_line1,a.address_line2,a.landmark].filter(Boolean).join(", ")],["city",a.city],["district",a.district],["postOffice",a.post_office||""],["state",a.state],["pincode",a.pincode]].forEach(([id,v])=>{const el=$("#"+id);if(el)el.value=v||""});const pin=$("#pincodeCheckBtn");if(pin)pin.click();setCheckoutStep(1)});
    }

    async function loadOfferProgress(){
      const host=$("#offerProgress"); if(!host)return;
      try{const j=await fetch("/api/features/offers").then(r=>r.json());const offers=(j.items||[]).filter(o=>o.min_order>0).slice(0,3);const subtotal=cartSubtotal();host.innerHTML=offers.length?offers.map(o=>{const left=Math.max(0,Number(o.min_order)-subtotal);return `<div class="offer-progress-row"><strong>${escapeHtml(String(o.name||"Offer"))}</strong><span>${left?`Add ${inr(left)} more`:`Offer unlocked`}</span></div>`}).join(""):"";}catch{host.innerHTML=""}
    }

    let selectedLocation = cart.delivery.location || "";
    let verifiedPincode = String(cart.delivery.pincode || "");
    let verifiedPincodeRecord = cart.delivery.pincodeRecord || null;
    let pincodeNeedsApproval = false;
    let governmentPincodeVerification = null;

    async function loadOfferQuote(){
      try{
        const items=cartLines().map(l=>({product_id:Number(l.product.id),quantity:Number(l.qty)}));
        const session=await window.RTAdmin?.supabaseSession?.();
        const headers={'Content-Type':'application/json'}; if(session?.data?.session?.access_token)headers.Authorization=`Bearer ${session.data.session.access_token}`;
        const r=await fetch('/api/features/offers/quote',{method:'POST',headers,body:JSON.stringify({subtotal:cartSubtotal(),location:selectedLocationRadio(),items})});
        const j=await r.json(); offerDiscount=Number(j.discount||0); freeDeliveryOffer=!!j.free_delivery;
      }catch{offerDiscount=0;freeDeliveryOffer=false}
    }

    function selectedLocationRadio() {
      const r = $all('input[name="deliveryLocation"]').find((x) => x.checked);
      return r ? r.value : "";
    }

    function renderLines() {
      const lines = cartLines();
      if (!lines.length) {
        orderList.style.display = "none";
        emptyState.style.display = "block";
        if (orderForm) orderForm.style.display = "none";
        $("#orderSummary").style.display = "none";
        return;
      }
      orderList.style.display = "flex";
      emptyState.style.display = "none";
      if (orderForm) orderForm.style.display = "block";
      $("#orderSummary").style.display = "block";

      orderList.innerHTML = lines
        .map(
          (l) => `
        <div class="order-line" data-id="${l.product.id}">
          <div class="order-line-info">
            <div class="name">${escapeHtml(l.product.name)}</div>
            <div class="meta">${l.product.size ? escapeHtml(l.product.size) + " · " : ""}${inr(l.product.price)} each</div>
            <div class="qty-stepper" data-id="${l.product.id}" style="max-width:120px;margin-top:8px;">
              <button type="button" class="qty-minus" aria-label="Decrease quantity">−</button>
              <span class="qty-val">${l.qty}</span>
              <button type="button" class="qty-plus" aria-label="Increase quantity">+</button>
            </div>
          </div>
          <div class="subtotal">${inr(l.product.price * l.qty)}</div>
          <button type="button" class="remove-btn" data-id="${l.product.id}">Remove</button><button type="button" class="save-later-btn" data-id="${l.product.id}" data-qty="${l.qty}">Save for later</button>
        </div>`
        )
        .join("");

      updateSummary();
    }

    function updateSummary() {
      const subtotal = cartSubtotal();
      const loc = selectedLocationRadio();
      const shipping = computeShipping(loc, subtotal);
      loadOfferQuote().then(()=>{ const effectiveShipping=(loc === "other" ? 0 : (freeDeliveryOffer ? 0 : shipping.fee)); totalEl.textContent=inr(Math.max(0,subtotal+effectiveShipping-couponDiscount-offerDiscount)); const offerEl=$("#offerProgress"); if(offerEl && offerDiscount) offerEl.innerHTML=`<div class="offer-progress-row"><strong>Offer applied</strong><span>−${inr(offerDiscount)}${freeDeliveryOffer?" + free delivery":""}</span></div>`; });

      subtotalEl.textContent = inr(subtotal);
      shippingLabelEl.textContent = shipping.label || "Shipping";
      shippingEl.textContent = loc === "other" ? "Pay at collection" : inr(shipping.fee);
      totalEl.textContent = inr(Math.max(0, subtotal + (loc === "other" ? 0 : (freeDeliveryOffer ? 0 : shipping.fee)) - couponDiscount - offerDiscount));

      if (shipping.note) {
        shippingNoteEl.textContent = shipping.note;
        shippingNoteEl.style.display = "block";
      } else {
        shippingNoteEl.style.display = "none";
      }

      const valid = (subtotal - couponDiscount - offerDiscount) >= POLICY.minOrderValue;
      if (!valid) {
        minWarning.classList.add("show");
      } else {
        minWarning.classList.remove("show");
      }
      if (submitBtn) submitBtn.disabled = !valid;
      if (waBtn) waBtn.disabled = !valid;
      if (emailBtn) emailBtn.disabled = !valid;

      cart.delivery.location = loc;
      saveCart(cart);
      loadOfferProgress();
      setCheckoutStep(loc ? 2 : 0);
    }

    orderList.addEventListener("click", async (e) => {
      const saveLaterBtn = e.target.closest(".save-later-btn");
      if(saveLaterBtn){
        try{const session=await window.RTAdmin?.supabaseSession?.(); if(!session?.data?.session?.user || session.data.session.user.is_anonymous){location.href='login.html?redirect=order.html';return;} const r=await fetch('/api/features/saved-for-later/'+saveLaterBtn.dataset.id,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.data.session.access_token}`},body:JSON.stringify({quantity:Number(saveLaterBtn.dataset.qty||1)})});const j=await r.json();if(!r.ok||j.ok===false)throw Error(j.error||'Could not save item');removeFromCart(saveLaterBtn.dataset.id);renderLines();toast('Saved for later.');}catch(err){toast(err.message)}
        return;
      }
      const removeBtn = e.target.closest(".remove-btn");
      if (removeBtn) {
        removeFromCart(removeBtn.getAttribute("data-id"));
        renderLines();
        return;
      }
      const minus = e.target.closest(".qty-minus");
      const plus = e.target.closest(".qty-plus");
      if (minus || plus) {
        const stepper = e.target.closest(".qty-stepper");
        const id = stepper.getAttribute("data-id");
        const current = cart.items[String(id)] || 0;
        setQty(id, minus ? current - 1 : current + 1);
        renderLines();
      }
    });

    const clearBtn = $("#clearOrderBtn");
    if (clearBtn) {
      clearBtn.addEventListener("click", () => {
        if (confirm("Clear all items from your order request?")) {
          clearCart();
          renderLines();
        }
      });
    }

    // Delivery location radios
    $all('input[name="deliveryLocation"]').forEach((radio) => {
      radio.addEventListener("change", () => {
        $all(".loc-option").forEach((o) => o.classList.remove("selected"));
        radio.closest(".loc-option").classList.add("selected");
        const otherFields = $("#otherLocationFields");
        if (otherFields) otherFields.style.display = radio.value === "other" ? "block" : "none";
        updateSummary();
      });
      if (radio.value === selectedLocation) {
        radio.checked = true;
        radio.closest(".loc-option").classList.add("selected");
        const otherFields = $("#otherLocationFields");
        if (otherFields) otherFields.style.display = radio.value === "other" ? "block" : "none";
      }
    });

    // Pincode availability check against the Supabase delivery_pincodes table.
    const pincodeBtn = $("#pincodeCheckBtn");
    const pincodeLookupInput = $("#pincodeInput");
    if (pincodeBtn) {
      pincodeBtn.addEventListener("click", async () => {
        const val = pincodeLookupInput.value.trim();
        pincodeBtn.disabled = true;
        pincodeBtn.textContent = "Checking...";
        try {
          const result = await window.RTAdmin.checkDeliveryPincode(val);
          if (!result.ok) {
            verifiedPincode = ""; verifiedPincodeRecord = null; pincodeNeedsApproval = false; governmentPincodeVerification = null;
            if (pincodeResult) { pincodeResult.textContent = result.error || "Could not verify this pincode."; pincodeResult.className = "pincode-result show info"; }
            return;
          }
          if (result.found && !result.available) {
            verifiedPincode = ""; verifiedPincodeRecord = null; pincodeNeedsApproval = false; governmentPincodeVerification = null;
            if (pincodeResult) { pincodeResult.textContent = "This pincode exists in the RTCrackers database but delivery is currently unavailable."; pincodeResult.className = "pincode-result show info"; }
            toast("Delivery is unavailable for this pincode."); return;
          }
          if (!result.found && result.governmentVerified) {
            const record = result.data || {};
            verifiedPincode = record.pincode;
            verifiedPincodeRecord = {...record, delivery_available:true, source:result.source};
            pincodeNeedsApproval = true;
            governmentPincodeVerification = result;
            $("#pincode").value = record.pincode || val;
            $("#postOffice").value = record.post_office || "";
            $("#city").value = record.post_office || "";
            $("#district").value = record.district || "";
            $("#state").value = record.state || "Tamil Nadu";
            if (pincodeResult) { pincodeResult.innerHTML = `<strong>✓ Government postal data verified</strong><br>${escapeHtml(record.post_office || "")}, ${escapeHtml(record.district || "")}, ${escapeHtml(record.state || "")}<br><span>This pincode is not yet in our delivery database. Your completed order will be sent to administrators for confirmation before an order is created.</span>`; pincodeResult.className = "pincode-result show info"; }
            toast("Pincode verified. Administrator confirmation will be required."); return;
          }
          if (!result.found || !result.available) {
            verifiedPincode = ""; verifiedPincodeRecord = null; pincodeNeedsApproval = false; governmentPincodeVerification = null;
            if (pincodeResult) { pincodeResult.textContent = result.message || "This pincode could not be verified."; pincodeResult.className = "pincode-result show info"; }
            return;
          }
          const record = result.data;
          verifiedPincode = record.pincode; verifiedPincodeRecord = record; pincodeNeedsApproval = false; governmentPincodeVerification = null;
          $("#pincode").value = record.pincode;
          $("#postOffice").value = record.post_office || "";
          $("#city").value = record.post_office || "";
          $("#district").value = record.district || "";
          $("#state").value = record.state || "Tamil Nadu";

          if (pincodeResult) {
            pincodeResult.innerHTML = `<strong>✓ Delivery available</strong><br>${escapeHtml(record.post_office)}, ${escapeHtml(record.district)}, ${escapeHtml(record.state)}<br>Estimated delivery: ${record.estimated_delivery_days || "3-5"} days`;
            pincodeResult.className = "pincode-result show success";
          }
          toast("Delivery available — address details filled.");
        } catch (e) {
          console.error(e);
          verifiedPincode = "";
          verifiedPincodeRecord = null;
          if (pincodeResult) {
            pincodeResult.textContent = "Could not check the pincode. Please try again.";
            pincodeResult.className = "pincode-result show info";
          }
        } finally {
          pincodeBtn.disabled = false;
          pincodeBtn.textContent = "Check Availability";
        }
      });
    }

    // If the customer changes the lookup pincode, require a fresh verification.
    if (pincodeLookupInput) {
      pincodeLookupInput.addEventListener("input", () => {
        const val = pincodeLookupInput.value.replace(/\D/g, "").slice(0, 6);
        pincodeLookupInput.value = val;
        if (val !== verifiedPincode) {
          verifiedPincode = "";
          verifiedPincodeRecord = null;
          if (pincodeResult) {
            pincodeResult.textContent = val ? "Click Check Availability to verify this pincode." : "";
            pincodeResult.className = val ? "pincode-result show info" : "pincode-result";
          }
        }
      });
    }

    const mainPincodeInput = $("#pincode");
    if (mainPincodeInput) {
      mainPincodeInput.addEventListener("input", () => {
        mainPincodeInput.value = mainPincodeInput.value.replace(/\D/g, "").slice(0, 6);
        if (mainPincodeInput.value !== verifiedPincode) {
          verifiedPincode = "";
          verifiedPincodeRecord = null;
        }
      });
    }

    // Phone validation helper (Indian numbers)
    function isValidIndianPhone(v) {
      return /^[6-9]\d{9}$/.test(v.replace(/\D/g, "").slice(-10));
    }

    function validateForm() {
      let ok = true;
      const required = ["fullName", "phoneNumber", "deliveryAddress", "city", "district", "pincode"];
      required.forEach((id) => {
        const input = $("#" + id);
        const group = input.closest(".form-group");
        if (!input.value.trim()) {
          group.classList.add("invalid");
          $(".form-error", group).classList.add("show");
          ok = false;
        } else {
          group.classList.remove("invalid");
          $(".form-error", group).classList.remove("show");
        }
      });

      const phoneInput = $("#phoneNumber");
      if (phoneInput.value.trim() && !isValidIndianPhone(phoneInput.value)) {
        phoneInput.closest(".form-group").classList.add("invalid");
        $(".form-error", phoneInput.closest(".form-group")).classList.add("show");
        $(".form-error", phoneInput.closest(".form-group")).textContent = "Enter a valid 10-digit Indian mobile number.";
        ok = false;
      }

      const emailInput = $("#emailAddress");
      if (emailInput.value.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailInput.value.trim())) {
        emailInput.closest(".form-group").classList.add("invalid");
        $(".form-error", emailInput.closest(".form-group")).classList.add("show");
        ok = false;
      }

      const pincodeInput = $("#pincode");
      if (pincodeInput.value.trim() && !/^\d{6}$/.test(pincodeInput.value.trim())) {
        pincodeInput.closest(".form-group").classList.add("invalid");
        $(".form-error", pincodeInput.closest(".form-group")).classList.add("show");
        ok = false;
      }

      if (!selectedLocationRadio()) {
        toast("Please select a delivery location");
        ok = false;
      }

      const currentPincode = $("#pincode").value.trim();
      if (!verifiedPincode || currentPincode !== verifiedPincode || !verifiedPincodeRecord) {
        toast("Please check and confirm that your pincode is serviceable.");
        ok = false;
      }

      if (cartSubtotal() < POLICY.minOrderValue) {
        ok = false;
      }

      return ok;
    }

    function buildOrderPayload() {
      const subtotal = cartSubtotal();
      const loc = selectedLocationRadio();
      const shipping = computeShipping(loc, subtotal);
      const locLabels = { chennai: "Chennai", kumbakonam: "Kumbakonam", other: "Other Tamil Nadu" };
      return {
        ref: "",
        clientOrderKey: (crypto && crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + "-" + Math.random()),
        name: $("#fullName").value.trim(),
        phone: $("#phoneNumber").value.trim(),
        email: $("#emailAddress") ? $("#emailAddress").value.trim() : "",
        address: $("#deliveryAddress").value.trim(),
        city: $("#city").value.trim(),
        district: $("#district").value.trim(),
        pincode: $("#pincode").value.trim(),
        postOffice: $("#postOffice") ? $("#postOffice").value.trim() : "",
        state: $("#state") ? $("#state").value.trim() : "Tamil Nadu",
        location: locLabels[loc] || loc,
        locationRaw: loc,
        notes: $("#additionalNotes") ? $("#additionalNotes").value.trim() : "",
        couponCode: appliedCoupon || "",
        lines: cartLines(),
        subtotal,
        shippingFee: loc === "other" ? null : shipping.fee,
        shippingLabel: shipping.label,
        discountAmount: couponDiscount + offerDiscount,
        total: Math.max(0, subtotal + (loc === "other" ? 0 : (freeDeliveryOffer ? 0 : shipping.fee)) - couponDiscount - offerDiscount)
      };
    }

    function buildWhatsAppMessage(order) {
      const lines = order.lines.map((l) => `${l.product.name} × ${l.qty}`).join("\n");
      const shippingLine =
        order.shippingFee === null
          ? "Shipping: Payable directly to transporter on collection"
          : `Shipping: ${inr(order.shippingFee)}`;
      return `RTCrackers Order Request

Reference: ${order.ref}

Customer: ${order.name}
Phone: ${order.phone}

Delivery Location: ${order.location}
Address: ${order.address}, ${order.city}, ${order.district} - ${order.pincode}

Products:
${lines}

Subtotal: ${inr(order.subtotal)}
${shippingLine}
Estimated Total: ${inr(order.total)}${order.shippingFee === null ? " + transporter fee" : ""}

This is an order request and requires confirmation from RTCrackers.`;
    }

    function buildEmailBody(order) {
      return buildWhatsAppMessage(order);
    }

    async function showConfirmation(order) {
      if (!window.RTAdmin || !window.RTAdmin.saveOrder) {
        toast("Order service is not available. Please refresh and try again.");
        return;
      }
      submitBtn.disabled = true;
      submitBtn.textContent = "Submitting…";
      const result = await window.RTAdmin.saveOrder(order);
      if (!result || result.ok === false) {
        submitBtn.disabled = false;
        submitBtn.textContent = "Submit Order Request";
        toast(result?.error || "Could not submit your order. Please try again.");
        return;
      }
      // The database is authoritative for the order reference.
      if (result.ref) order.ref = result.ref;
      if (result.pendingApproval) {
        $("#orderFormWrap").style.display = "none";
        const confirmBox = $("#orderConfirmation");
        confirmBox.style.display = "block";
        $("#refNumberDisplay").textContent = result.ref || "Pending approval";
        const detail = confirmBox.querySelector("[data-confirmation-detail]");
        if (detail) detail.textContent = "Your order details were received and verified against postal data. An administrator must approve this new delivery pincode before an order is created. If rejected, no order will be created.";
        clearCart(); setCheckoutStep(4); return;
      }
      $("#orderFormWrap").style.display = "none";
      const confirmBox = $("#orderConfirmation");
      confirmBox.style.display = "block";
      $("#refNumberDisplay").textContent = order.ref || "Created";
      confirmBox.scrollIntoView({ behavior: "smooth" });
      const waLink = $("#waSendLink");
      if (waLink) waLink.href = `https://wa.me/91${COMPANY.whatsapp}?text=${encodeURIComponent(buildWhatsAppMessage(order))}`;
      const emailLink = $("#emailSendLink");
      if (emailLink && ORDER_NOTIFY_EMAIL) emailLink.href = `mailto:${ORDER_NOTIFY_EMAIL}?subject=${encodeURIComponent("RTCrackers Order " + order.ref)}&body=${encodeURIComponent(buildEmailBody(order))}`;
      clearCart();
      setCheckoutStep(4);
    }

    if (applyCouponBtn) applyCouponBtn.addEventListener("click", async () => {
      const code=(couponInput?.value||'').trim(); if(!code){appliedCoupon=''; if(couponStatus)couponStatus.textContent='Enter a coupon code.';return;}
      try{const session=await window.RTAdmin?.supabaseSession?.(); if(!session?.user || session.user.is_anonymous){if(couponStatus)couponStatus.textContent='Log in to use coupons.';return;} const r=await fetch('/api/features/coupon/validate',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${session.access_token}`},body:JSON.stringify({code,subtotal:cartSubtotal(),location:selectedLocationRadio()})}); const j=await r.json(); if(!r.ok||j.ok===false)throw Error(j.error||'Coupon could not be applied.'); appliedCoupon=code; couponDiscount=Number(j.discount||0); updateSummary(); if(couponStatus)couponStatus.textContent=`✓ ${j.message||'Coupon applied'}`; setCheckoutStep(3);}catch(err){appliedCoupon='';couponDiscount=0;updateSummary();if(couponStatus)couponStatus.textContent=err.message;}
    });

    if (orderForm) {
      orderForm.addEventListener("submit", async (e) => {
        e.preventDefault();
        if (!validateForm()) { toast("Please check the highlighted fields"); return; }
        const order = buildOrderPayload();
        if(!reviewReady){
          const box=$("#reviewStep"); const host=$("#checkoutReviewContent");
          if(box&&host){host.innerHTML=`<div class="review-grid"><div><strong>${order.lines.length} product line(s)</strong><p>${order.lines.map(l=>`${escapeHtml(l.product.name)} × ${Number(l.qty)}`).join("<br>")}</p></div><div><strong>Delivery</strong><p>${escapeHtml(order.name)}<br>${escapeHtml(order.address)}, ${escapeHtml(order.city)}, ${escapeHtml(order.district)} - ${escapeHtml(order.pincode)}</p></div><div><strong>Payment</strong><p>Cash on Delivery</p></div><div><strong>Total</strong><p class="review-total">${inr(order.total)}</p>${couponDiscount?`<small>Discount: −${inr(couponDiscount)}</small>`:""}</div></div>`;box.hidden=false;box.scrollIntoView({behavior:"smooth",block:"center"});}
          reviewReady=true; submitBtn.textContent="Confirm & Submit Order"; setCheckoutStep(3); return;
        }
        await showConfirmation(order);
      });
    }

    if (waBtn) {
      waBtn.addEventListener("click", () => {
        if (!validateForm()) {
          toast("Please fill in delivery details first");
          return;
        }
        const order = buildOrderPayload();
        window.open(`https://wa.me/91${COMPANY.whatsapp}?text=${encodeURIComponent(buildWhatsAppMessage(order))}`, "_blank");
      });
    }

    if (emailBtn) {
      emailBtn.addEventListener("click", () => {
        if (!validateForm()) {
          toast("Please fill in delivery details first");
          return;
        }
        const order = buildOrderPayload();
        window.location.href = `mailto:${ORDER_NOTIFY_EMAIL}?subject=${encodeURIComponent(
          "RTCrackers Order Request"
        )}&body=${encodeURIComponent(buildEmailBody(order))}`;
      });
    }

    // Optional: prefill delivery details for a logged-in customer (never required)
    const loggedInUser = window.RTAdmin && window.RTAdmin.currentUser && window.RTAdmin.currentUser();
    if (loggedInUser) {
      if ($("#fullName") && !$("#fullName").value) $("#fullName").value = loggedInUser.name || "";
      if ($("#phoneNumber") && !$("#phoneNumber").value) $("#phoneNumber").value = loggedInUser.phone || "";
      if ($("#emailAddress") && !$("#emailAddress").value) $("#emailAddress").value = loggedInUser.email || "";
    }

    renderLines();
    loadSavedAddresses();
    window.onCartChange = renderLines;
  }

  /* ---------------- Contact / footer fill-ins ---------------- */
  function fillManagedAboutSection() {
    const about = String(COMPANY.aboutSection || "").trim();
    $all("[data-about-section]").forEach((section) => {
      const copy = section.querySelector("[data-about-copy]");
      if (!copy || !about) { section.hidden = true; return; }
      copy.textContent = about;
      section.hidden = false;
    });
  }

  function fillCompanyInfo() {
    $all("[data-company-phone-plist]").forEach((el) => (el.textContent = COMPANY.phoneProductList));
    $all("[data-company-phone-policy]").forEach((el) => (el.textContent = COMPANY.phonePolicy));
    $all("[data-company-whatsapp]").forEach((el) => (el.textContent = COMPANY.whatsappDisplay));
    $all("[data-company-email]").forEach((el) => (el.textContent = COMPANY.email));
    $all("[data-company-logo]").forEach((el) => {
      if (COMPANY.logoUrl) { el.src = COMPANY.logoUrl; el.style.display = "block"; }
      else { el.style.display = "none"; }
    });
    $all("a[data-whatsapp-link]").forEach(
      (el) => (el.href = `https://wa.me/91${COMPANY.whatsapp}`)
    );
    $all("a[data-email-link]").forEach((el) => (el.href = `mailto:${COMPANY.email}`));
    $all("a[data-phone-link]").forEach((el) => (el.href = `tel:+91${COMPANY.phoneProductList}`));
  }

  /* ---------------- Admin-managed home banners ---------------- */
  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  function renderHomeBanners(banners) {
    const section = $("#homeBanners");
    const list = $("#homeBannerList");
    if (!section || !list) return;
    if (!banners || !banners.length) {
      section.hidden = true;
      list.innerHTML = "";
      return;
    }

    list.innerHTML = banners.map((b) => {
      const type = String(b.file_type || "").toLowerCase();
      const url = escapeHtml(b.file_url);
      let media = "";
      if (type.startsWith("image/")) {
        media = `<img class="rt-banner-media rt-banner-image" src="${url}" alt="${escapeHtml(b.title)}" loading="eager">`;
      } else if (type.startsWith("video/")) {
        media = `<video class="rt-banner-media rt-banner-video" src="${url}" autoplay muted loop playsinline controls preload="metadata"></video>`;
      } else if (type === "application/pdf") {
        media = `<iframe class="rt-banner-pdf" src="${url}" title="${escapeHtml(b.title)}"></iframe>`;
      } else {
        media = `<div class="rt-banner-file"><div style="font-size:42px;">📁</div><h3>${escapeHtml(b.title)}</h3><a class="btn btn-primary rt-banner-open" href="${url}" target="_blank" rel="noopener">Open / Download</a></div>`;
      }
      const content = b.link_url
        ? `<a href="${escapeHtml(b.link_url)}" target="_blank" rel="noopener" style="display:block;">${media}</a>`
        : media;
      const caption = b.description
        ? `<div class="rt-banner-caption"><h3>${escapeHtml(b.title)}</h3><p>${escapeHtml(b.description)}</p></div>`
        : "";
      return `<article class="rt-banner">${content}${caption}</article>`;
    }).join("");
    section.hidden = false;
  }

  async function initHomeBanners() {
    if (!$("#homeBanners") || !window.RTAdmin?.getActiveBanners) return;
    try {
      const banners = await window.RTAdmin.getActiveBanners();
      renderHomeBanners(banners.filter(b => b.placement === "home_top"));
    } catch (e) {
      console.warn("Home banners could not be loaded:", e);
    }
  }

  /* ---------------- Init ---------------- */
  function init() {
    refreshCartUI();
    initNav();
    initAccordion();
    fillCompanyInfo();
    fillManagedAboutSection();
    initHomeBanners();
    initFeatured();
    initCategoryTiles();
    initProductsPage();
    initOrderPage();

    const year = $("#currentYear");
    if (year) year.textContent = new Date().getFullYear();
  }

  // The awaits above (Supabase data + auth state) can easily take longer
  // than DOMContentLoaded — so check readyState instead of only listening
  // for an event that may have already fired.
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // Expose minimal API for inline handlers if ever needed
  window.RTCrackers = { addToCart, removeFromCart, clearCart, inr };
})();