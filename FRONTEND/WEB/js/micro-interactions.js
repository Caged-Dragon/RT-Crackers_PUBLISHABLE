/* RTCrackers — premium micro interactions; visual only, no business logic. */
(function () {
  'use strict';
  const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  function ripple(event) {
    if (reduce) return;
    const target = event.target.closest?.('.btn, .cart-btn, .rt-appearance-options button, button, [role="button"]');
    if (!target || target.disabled || target.closest('[data-no-ripple]')) return;
    if (target.tagName === 'BUTTON' && target.type === 'submit' && target.closest('form')?.dataset.noRipple) return;
    const rect = target.getBoundingClientRect();
    const dot = document.createElement('span');
    dot.className = 'rt-ripple';
    dot.style.left = `${event.clientX - rect.left}px`;
    dot.style.top = `${event.clientY - rect.top}px`;
    target.appendChild(dot);
    dot.addEventListener('animationend', () => dot.remove(), { once: true });
  }

  function press(event) {
    const target = event.target.closest?.('.btn, .cart-btn, button, .cat-tile, .product-card');
    if (!target || target.disabled) return;
    target.classList.add('rt-pressed');
    window.setTimeout(() => target.classList.remove('rt-pressed'), 180);
  }

  function headerState() {
    const header = document.querySelector('.site-header');
    if (!header) return;
    const update = () => header.classList.toggle('rt-scrolled', window.scrollY > 14);
    update();
    window.addEventListener('scroll', update, { passive: true });
  }

  function pageMotion() {
    document.body.classList.add('rt-page-ready');
    document.addEventListener('click', (event) => {
      const link = event.target.closest('a[href]');
      if (!link || reduce || link.target === '_blank' || link.hasAttribute('download')) return;
      const href = link.getAttribute('href');
      if (!href || href.startsWith('#') || href.startsWith('mailto:') || href.startsWith('tel:') || href.startsWith('javascript:')) return;
      try {
        const url = new URL(href, location.href);
        if (url.origin !== location.origin) return;
        if (url.pathname === location.pathname && url.search === location.search) return;
        event.preventDefault();
        document.body.classList.add('rt-page-leaving');
        setTimeout(() => { location.href = url.href; }, 190);
      } catch (_) {}
    });
  }

  function keyboardFeedback() {
    document.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      const target = event.target.closest?.('button, .btn, [role="button"]');
      if (!target) return;
      target.classList.add('rt-pressed');
      setTimeout(() => target.classList.remove('rt-pressed'), 150);
    });
  }

  function init() {
    document.addEventListener('pointerdown', ripple, { passive: true });
    document.addEventListener('pointerdown', press, { passive: true });
    keyboardFeedback();
    headerState();
    pageMotion();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
