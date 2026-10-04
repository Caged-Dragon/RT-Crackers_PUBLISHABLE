/* RTCrackers — Industrial Frontend UX helpers. No business logic. */
(function () {
  'use strict';
  const init = () => {
    document.documentElement.dataset.rtIndustrialUi = 'true';

    if (!document.querySelector('.rt-skip-link')) {
      const skip = document.createElement('a');
      skip.className = 'rt-skip-link';
      skip.href = '#main';
      skip.textContent = 'Skip to main content';
      skip.style.cssText = 'position:fixed;left:12px;top:12px;z-index:4000;padding:10px 14px;border-radius:10px;background:var(--rt-theme-accent,#d6a84f);color:var(--rt-theme-dark,#071426);font-weight:800;transform:translateY(-160%);transition:transform .18s ease';
      skip.addEventListener('focus', () => { skip.style.transform = 'translateY(0)'; });
      skip.addEventListener('blur', () => { skip.style.transform = 'translateY(-160%)'; });
      document.body.prepend(skip);
    }

    const main = document.querySelector('main');
    if (main && !main.id) main.id = 'main';

    document.querySelectorAll('img').forEach(img => {
      if (!img.alt) img.alt = 'RTCrackers';
      if (!img.hasAttribute('decoding')) img.decoding = 'async';
    });

    document.querySelectorAll('form').forEach(form => {
      if (form.dataset.rtUxBound) return;
      form.dataset.rtUxBound = '1';
      form.addEventListener('submit', () => {
        const submit = form.querySelector('button[type="submit"]');
        if (!submit || submit.disabled) return;
        submit.dataset.originalLabel = submit.textContent;
        submit.disabled = true;
        submit.setAttribute('aria-busy', 'true');
        setTimeout(() => {
          submit.disabled = false;
          submit.removeAttribute('aria-busy');
        }, 8000);
      });
    });
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
