/* RTCrackers — Advanced Frontend Interaction Layer */
(function () {
  'use strict';

  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => Array.from(root.querySelectorAll(s));

  function scrollProgress() {
    const bar = document.createElement('div');
    bar.className = 'rt-scroll-progress';
    bar.setAttribute('aria-hidden', 'true');
    document.body.appendChild(bar);
    const update = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = max > 0 ? `${Math.min(100, Math.max(0, window.scrollY / max * 100))}%` : '0%';
      $('.site-header')?.classList.toggle('is-scrolled', window.scrollY > 12);
    };
    window.addEventListener('scroll', update, { passive: true });
    update();
  }

  function revealSections() {
    const targets = $$('.section, .hero-grid > *, .rt-banner, .card, .cat-tile, .product-card, .step, .notice-box, .order-card, .form-card');
    if (!('IntersectionObserver' in window)) return;
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const el = entry.target;
        if (entry.isIntersecting) {
          el.classList.remove('is-leaving');
          requestAnimationFrame(() => el.classList.add('is-visible'));
        } else if (el.classList.contains('is-visible')) {
          el.classList.remove('is-visible');
          el.classList.add('is-leaving');
        }
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: .08 });
    targets.forEach((el, i) => {
      if (!el.classList.contains('rt-reveal')) {
        el.classList.add('rt-reveal');
        el.style.transitionDelay = `${Math.min(i % 5, 4) * 45}ms`;
      }
      observer.observe(el);
    });
  }

  function ripple() {
    document.addEventListener('click', e => {
      const button = e.target.closest('.btn, .cart-btn, .filter-chip, .rt-compare-btn, .rt-icon-btn');
      if (!button || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
      const rect = button.getBoundingClientRect();
      const r = document.createElement('span');
      r.className = 'rt-ripple';
      r.style.left = `${e.clientX - rect.left}px`;
      r.style.top = `${e.clientY - rect.top}px`;
      button.appendChild(r);
      setTimeout(() => r.remove(), 700);
    });
  }

  function optimizeImages() {
    $$('img').forEach(img => {
      if (!img.hasAttribute('loading') && !img.closest('.site-header, .hero')) img.loading = 'lazy';
      img.decoding = 'async';
    });
  }

  function backToTop() {
    const b = document.createElement('button');
    b.className = 'rt-back-top';
    b.type = 'button';
    b.setAttribute('aria-label', 'Back to top');
    b.textContent = '↑';
    document.body.appendChild(b);
    const update = () => b.classList.toggle('show', window.scrollY > 650);
    window.addEventListener('scroll', update, { passive: true });
    update();
    b.addEventListener('click', () => window.scrollTo({ top: 0, behavior: 'smooth' }));
  }

  function commandPalette() {
    const links = [
      ['⌕', 'Search products', 'Focus product search', () => { const input = $('#productSearch'); if (input) { input.focus(); input.scrollIntoView({ behavior: 'smooth', block: 'center' }); } else location.href = 'products.html'; }],
      ['▦', 'Browse products', 'Open the complete catalogue', () => location.href = 'products.html'],
      ['🛒', 'Order request', 'Review your current order', () => location.href = 'order.html'],
      ['♡', 'Wishlist', 'Open your saved products', () => location.href = 'account.html#wishlist'],
      ['◎', 'My orders', 'Track previous orders', () => location.href = 'my-orders.html'],
      ['◉', 'Account', 'Profile and saved addresses', () => location.href = 'account.html']
    ];
    const wrap = document.createElement('div');
    wrap.className = 'rt-command';
    wrap.innerHTML = `<div class="rt-command-card" role="dialog" aria-modal="true" aria-label="Quick navigation"><input class="rt-command-input" autocomplete="off" placeholder="Search RTCrackers…" aria-label="Quick navigation search"><div class="rt-command-list"></div></div>`;
    document.body.appendChild(wrap);
    const input = $('.rt-command-input', wrap), list = $('.rt-command-list', wrap);
    const render = q => {
      const query = q.trim().toLowerCase();
      list.innerHTML = links.filter(x => !query || `${x[1]} ${x[2]}`.toLowerCase().includes(query)).map((x, i) => `<button class="rt-command-item" data-command="${i}"><span aria-hidden="true">${x[0]}</span><span>${x[1]}<small>${x[2]}</small></span></button>`).join('');
    };
    render('');
    const close = () => { wrap.classList.remove('open'); input.value = ''; render(''); };
    const open = () => { wrap.classList.add('open'); input.focus(); render(''); };
    input.addEventListener('input', () => render(input.value));
    list.addEventListener('click', e => { const item = e.target.closest('[data-command]'); if (!item) return; const action = links[Number(item.dataset.command)][3]; close(); action(); });
    wrap.addEventListener('click', e => { if (e.target === wrap) close(); });
    document.addEventListener('keydown', e => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); open(); }
      if (e.key === '/' && !/input|textarea|select/i.test(document.activeElement?.tagName || '')) { e.preventDefault(); open(); }
      if (e.key === 'Escape') close();
    });
  }

  function decorateSearch() {
    const input = $('#productSearch');
    if (!input || input.dataset.rtShortcut) return;
    input.dataset.rtShortcut = 'true';
    input.setAttribute('aria-keyshortcuts', '/');
    input.placeholder = 'Search products, categories…';
  }

  function init() {
    document.documentElement.dataset.rtAdvancedUi = 'true';
    scrollProgress();
    revealSections();
    ripple();
    optimizeImages();
    backToTop();
    commandPalette();
    decorateSearch();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
