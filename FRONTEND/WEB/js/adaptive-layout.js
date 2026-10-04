/*
 * RTCrackers — Runtime Layout Engine
 * -----------------------------------
 * This is intentionally NOT a mobile/tablet/laptop breakpoint system.
 * It continuously measures the actual rendered space available to each
 * component and derives columns, spacing, navigation visibility and drawer
 * widths from that space. A resize, split-screen change, orientation change,
 * browser zoom, PWA viewport change or embedded container resize is handled
 * by the same engine.
 */
(function () {
  'use strict';

  const root = document.documentElement;
  const body = document.body;
  const raf = window.requestAnimationFrame || ((fn) => setTimeout(fn, 16));
  let queued = false;

  const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
  const px = (n) => `${Math.round(n * 10) / 10}px`;

  function viewport() {
    const vv = window.visualViewport;
    return {
      width: Math.max(1, vv?.width || window.innerWidth),
      height: Math.max(1, vv?.height || window.innerHeight),
      dpr: Math.max(1, window.devicePixelRatio || 1)
    };
  }

  function setVars(v) {
    const gutter = clamp(v.width * 0.018, 10, 34);
    const scale = clamp(Math.min(v.width / 1180, v.height / 760), 0.72, 1.18);
    root.style.setProperty('--rt-vw', px(v.width));
    root.style.setProperty('--rt-vh', px(v.height));
    root.style.setProperty('--rt-dpr', String(v.dpr));
    root.style.setProperty('--rt-runtime-gutter', px(gutter));
    root.style.setProperty('--rt-runtime-gap', px(clamp(v.width * 0.014, 8, 24)));
    root.style.setProperty('--rt-runtime-scale', scale.toFixed(3));
    root.style.setProperty('--rt-runtime-page-max', `${Math.max(680, Math.min(1800, v.width - gutter * 2))}px`);
    root.style.setProperty('--rt-safe-top', 'env(safe-area-inset-top, 0px)');
    root.style.setProperty('--rt-safe-right', 'env(safe-area-inset-right, 0px)');
    root.style.setProperty('--rt-safe-bottom', 'env(safe-area-inset-bottom, 0px)');
    root.style.setProperty('--rt-safe-left', 'env(safe-area-inset-left, 0px)');
  }

  function childrenCount(el) {
    return Array.from(el.children).filter(c => {
      const s = getComputedStyle(c);
      return s.display !== 'none' && s.visibility !== 'hidden';
    }).length;
  }

  function minWidthFor(el) {
    const explicit = Number(el.dataset.rtMinWidth || 0);
    if (explicit > 0) return explicit;
    const c = el.classList;
    if (c.contains('stitch-product-grid') || c.contains('product-grid') || c.contains('rt-related-grid')) return 190;
    if (c.contains('stitch-category-grid')) return 175;
    if (c.contains('hero-trust')) return 145;
    if (c.contains('footer-grid')) return 180;
    if (c.contains('info-grid')) return 220;
    if (c.contains('steps')) return 155;
    if (c.contains('loc-options')) return 190;
    if (c.contains('account-kpis')) return 150;
    if (c.contains('form-grid') || c.contains('grid-form') || c.contains('bulk-grid')) return 270;
    if (c.contains('hero-grid') || c.contains('editorial-grid') || c.contains('order-layout') || c.contains('account-grid')) return 420;
    return 220;
  }

  function applyGrid(el) {
    const width = el.clientWidth;
    const count = childrenCount(el);
    if (!width || count < 1) return;
    const min = minWidthFor(el);
    const gap = parseFloat(getComputedStyle(el).gap) || 16;
    const cols = clamp(Math.floor((width + gap) / (min + gap)), 1, count);
    el.classList.add('rt-runtime-grid');
    el.style.setProperty('--rt-runtime-cols', String(cols));

    // Hero/editorial/order/account layouts are two-column only when their
    // content can physically coexist. The calculation is based on measured
    // container width, never on a device category.
    if (el.matches('.hero-grid,.editorial-grid,.order-layout,.account-grid')) {
      const wanted = cols >= 2 ? 2 : 1;
      el.style.setProperty('--rt-runtime-cols', String(wanted));
    }
  }

  function applyFlexFit(el) {
    const width = el.clientWidth;
    if (!width) return;
    const children = Array.from(el.children).filter(c => getComputedStyle(c).display !== 'none');
    if (!children.length) return;
    const total = children.reduce((sum, c) => sum + Math.max(0, c.getBoundingClientRect().width), 0);
    const gap = parseFloat(getComputedStyle(el).gap) || 0;
    const needed = total + gap * Math.max(0, children.length - 1);
    if (needed > width + 2) el.classList.add('rt-runtime-wrap');
    else el.classList.remove('rt-runtime-wrap');
  }

  function adaptShell() {
    document.querySelectorAll('.rt-shell-header').forEach(header => {
      const inner = header.querySelector('.shell-inner');
      const nav = header.querySelector('.rt-shell-nav');
      const menu = header.querySelector('.rt-shell-menu');
      const actions = header.querySelector('.rt-shell-actions');
      if (!inner || !nav || !menu) return;

      // Temporarily measure the real content without hiding navigation.
      nav.classList.remove('rt-runtime-hidden');
      menu.classList.remove('rt-runtime-visible');
      actions?.classList.remove('rt-runtime-tight');

      const needed = Array.from(inner.children).reduce((sum, child) => {
        if (child === nav) return sum + nav.scrollWidth;
        return sum + child.getBoundingClientRect().width;
      }, 0) + 28;
      const available = inner.clientWidth;

      if (needed > available) {
        nav.classList.add('rt-runtime-hidden');
        menu.classList.add('rt-runtime-visible');
        actions?.classList.add('rt-runtime-tight');
      }
    });

    // Legacy header navigation uses the same measured-fit rule.
    document.querySelectorAll('.site-header').forEach(header => {
      const container = header.querySelector('.container');
      const nav = header.querySelector('.main-nav');
      const burger = header.querySelector('.hamburger');
      const actions = header.querySelector('.header-actions');
      if (!container || !nav || !burger) return;
      nav.style.display = '';
      burger.style.display = '';
      const available = container.clientWidth;
      const childrenWidth = Array.from(container.children).reduce((s, c) => s + c.getBoundingClientRect().width, 0);
      if (childrenWidth > available + 2) {
        nav.style.display = 'none';
        burger.style.display = 'inline-flex';
        actions?.classList.add('rt-runtime-tight');
      }
    });
  }

  function adaptAdmin() {
    const layout = document.querySelector('.adm-layout');
    const left = document.getElementById('admLeftSide');
    const right = document.getElementById('admRightSide');
    const content = layout?.querySelector('.adm-content');
    if (!layout || !left || !right || !content) return;

    layout.classList.add('rt-admin-runtime');
    const available = layout.clientWidth;
    const gap = clamp(available * 0.012, 8, 16);
    const intrinsicContent = Array.from(content.children).reduce((m, el) => Math.max(m, el.scrollWidth || 0), 0);
    const minContent = Math.max(320, Math.min(760, intrinsicContent || available * 0.42));
    const expanded = clamp(available * 0.18, 180, 224);
    root.style.setProperty('--rt-admin-expanded', px(expanded));
    root.style.setProperty('--rt-admin-gap', px(gap));

    [left, right].forEach(side => {
      const expandedState = !side.classList.contains('is-collapsed');
      side.classList.toggle('rt-runtime-collapsed', !expandedState);
      side.classList.toggle('rt-runtime-expanded', expandedState);
    });

    const leftW = left.classList.contains('is-collapsed') ? 48 : expanded;
    const rightW = right.classList.contains('is-collapsed') ? 48 : expanded;
    const required = leftW + rightW + gap * 2 + minContent;

    // Intrinsic runtime decision: if the three regions cannot coexist at their
    // measured sizes, turn expanded drawers into overlays. No device category
    // or fixed viewport breakpoint is used.
    layout.classList.toggle('rt-admin-drawer-overlay', available < required);

    // If the content itself is extremely narrow, stack the drawers around the
    // content rather than shrinking the content into an unusable column.
    const stacked = available < (minContent + 96);
    layout.classList.toggle('rt-admin-stacked', stacked);
    if (stacked) layout.classList.remove('rt-admin-drawer-overlay');
  }

  function adaptImagesAndMedia() {
    document.querySelectorAll('img,video,iframe').forEach(el => {
      if (el.closest('.rt-intro')) return;
      el.style.maxInlineSize = '100%';
      el.style.blockSize = el.tagName === 'IMG' ? 'auto' : el.style.blockSize;
    });
  }

  function run() {
    queued = false;
    const v = viewport();
    setVars(v);

    const gridSelectors = [
      '.grid-2','.grid-3','.grid-4','.product-grid','.stitch-product-grid',
      '.stitch-category-grid','.info-grid','.footer-grid','.rt-related-grid',
      '.steps','.loc-options','.form-row','.account-kpis','.form-grid',
      '.grid-form','.bulk-grid','.hero-trust','.hero-grid','.editorial-grid',
      '.order-layout','.account-grid','.review-grid','.rt-box-builder'
    ];
    document.querySelectorAll(gridSelectors.join(',')).forEach(applyGrid);
    document.querySelectorAll('.hero-actions,.editorial-actions,.header-actions,.rt-shell-actions,.promo-inner,.promo-actions,.add-row').forEach(applyFlexFit);
    adaptShell();
    adaptAdmin();
    adaptImagesAndMedia();
  }

  function schedule() {
    if (queued) return;
    queued = true;
    raf(run);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', schedule, { once: true });
  else schedule();

  window.addEventListener('resize', schedule, { passive: true });
  window.addEventListener('orientationchange', schedule, { passive: true });
  window.visualViewport?.addEventListener('resize', schedule, { passive: true });

  if ('ResizeObserver' in window) {
    const ro = new ResizeObserver(schedule);
    ro.observe(document.documentElement);
    ro.observe(document.body);
  }

  // Content can be inserted after API responses. Re-measure without polling.
  if ('MutationObserver' in window) {
    const mo = new MutationObserver((records) => {
      if (records.some(r => r.addedNodes.length || r.removedNodes.length)) schedule();
    });
    mo.observe(document.body, { childList: true, subtree: true });
  }
})();
