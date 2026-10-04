(function () {
  'use strict';

  // Device-aware layout foundation. CSS remains responsible for layout;
  // this file exposes the exact live viewport dimensions as CSS variables.
  const root = document.documentElement;

  function updateViewport() {
    const vv = window.visualViewport;
    const width = Math.max(1, Math.round(vv?.width || window.innerWidth));
    const height = Math.max(1, Math.round(vv?.height || window.innerHeight));
    const dpr = Math.max(1, window.devicePixelRatio || 1);

    root.style.setProperty('--rt-vw', width + 'px');
    root.style.setProperty('--rt-vh', height + 'px');
    root.style.setProperty('--rt-dpr', String(dpr));
    root.style.setProperty('--rt-safe-top', 'env(safe-area-inset-top, 0px)');
    root.style.setProperty('--rt-safe-right', 'env(safe-area-inset-right, 0px)');
    root.style.setProperty('--rt-safe-bottom', 'env(safe-area-inset-bottom, 0px)');
    root.style.setProperty('--rt-safe-left', 'env(safe-area-inset-left, 0px)');

    const shortSide = Math.min(width, height);
    const density = width < 360 ? 'compact' : width < 600 ? 'mobile' : width < 1024 ? 'tablet' : 'desktop';
    root.dataset.deviceWidth = density;
    root.dataset.orientation = width >= height ? 'landscape' : 'portrait';
    root.style.setProperty('--rt-motion-scale', Math.min(1.12, Math.max(.58, shortSide / 760)).toFixed(3));
  }

  updateViewport();
  window.addEventListener('resize', updateViewport, { passive: true });
  window.addEventListener('orientationchange', () => setTimeout(updateViewport, 80), { passive: true });
  window.visualViewport?.addEventListener('resize', updateViewport, { passive: true });

  if ('ResizeObserver' in window) {
    const observer = new ResizeObserver(updateViewport);
    observer.observe(document.documentElement);
  }
})();
