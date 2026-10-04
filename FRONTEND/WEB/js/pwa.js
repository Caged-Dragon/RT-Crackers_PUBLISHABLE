(function () {
  'use strict';

  const DISMISS_KEY = 'rt_pwa_install_dismissed_v2';
  let deferredPrompt = null;
  let registration = null;
  let promptInProgress = false;

  const isStandalone = () =>
    window.matchMedia('(display-mode: standalone)').matches ||
    window.matchMedia('(display-mode: fullscreen)').matches ||
    window.navigator.standalone === true;

  function makeUI() {
    if (document.getElementById('pwaInstallBar')) return;

    const bar = document.createElement('div');
    bar.id = 'pwaInstallBar';
    bar.className = 'pwa-install-bar';
    bar.setAttribute('role', 'dialog');
    bar.setAttribute('aria-label', 'Install RTCrackers');
    bar.innerHTML = `
      <div class="pwa-install-glow" aria-hidden="true"></div>
      <img class="pwa-install-icon" src="assets/icons/icon-192.png" alt="">
      <div class="pwa-install-copy">
        <strong>Install RTCrackers</strong>
        <span>Get an app-like experience with quick access from your device.</span>
      </div>
      <div class="pwa-install-actions">
        <button class="pwa-dismiss-btn" id="pwaDismiss" type="button">Later</button>
        <button class="pwa-install-btn" id="pwaInstall" type="button">Install</button>
      </div>`;

    document.body.appendChild(bar);

    document.getElementById('pwaDismiss').addEventListener('click', () => {
      localStorage.setItem(DISMISS_KEY, String(Date.now()));
      bar.classList.remove('show');
    });

    document.getElementById('pwaInstall').addEventListener('click', async () => {
      if (!deferredPrompt || promptInProgress) return;
      promptInProgress = true;

      try {
        // IMPORTANT: prompt() is called directly from the user's click.
        await deferredPrompt.prompt();
        const result = await deferredPrompt.userChoice;
        deferredPrompt = null;
        bar.classList.remove('show');
        if (result?.outcome === 'accepted') {
          localStorage.removeItem(DISMISS_KEY);
          showStatus('Installing RTCrackers…');
        }
      } catch (error) {
        console.warn('PWA install prompt could not be opened:', error);
      } finally {
        promptInProgress = false;
      }
    });
  }

  function showInstallPrompt() {
    if (isStandalone() || !deferredPrompt) return;
    makeUI();

    const dismissedAt = Number(localStorage.getItem(DISMISS_KEY) || 0);
    if (dismissedAt && Date.now() - dismissedAt < 7 * 24 * 60 * 60 * 1000) return;

    requestAnimationFrame(() => {
      document.getElementById('pwaInstallBar')?.classList.add('show');
    });
  }

  function showStatus(message) {
    let el = document.getElementById('pwaStatus');
    if (!el) {
      el = document.createElement('div');
      el.id = 'pwaStatus';
      el.className = 'pwa-status';
      document.body.appendChild(el);
    }
    el.textContent = message;
    el.classList.add('show');
    clearTimeout(el._timer);
    el._timer = setTimeout(() => el.classList.remove('show'), 2800);
  }

  let refreshing = false;

  async function register() {
    if (!('serviceWorker' in navigator)) return;
    try {
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        if (refreshing) return;
        refreshing = true;
        window.location.reload();
      });

      registration = await navigator.serviceWorker.register('./sw.js', { scope: './' });

      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          if (worker.state === 'installed' && navigator.serviceWorker.controller) {
            makeUI();
            const bar = document.getElementById('pwaInstallBar');
            if (!bar) return;
            bar.innerHTML = `<div class="pwa-install-copy"><strong>New RTCrackers version available</strong><span>Refresh to use the latest website.</span></div><div class="pwa-install-actions"><button class="pwa-install-btn" id="pwaUpdate" type="button">Update</button></div>`;
            bar.classList.add('show');
            document.getElementById('pwaUpdate').onclick = () => registration.waiting?.postMessage({ type: 'SKIP_WAITING' });
          }
        });
      });
    } catch (error) {
      console.warn('PWA service worker registration failed:', error);
    }
  }

  function initNetworkStatus() {
    window.addEventListener('offline', () => showStatus('You are offline. Previously visited pages remain available.'));
    window.addEventListener('online', () => showStatus('Back online. RTCrackers will load fresh data.'));
  }

  // Capture the install event and consume it from the custom Install button.
  // This is the standards-compliant flow: preventDefault() is paired with prompt()
  // from a real user gesture, so Chromium does not report the unused-event warning.
  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredPrompt = event;
    if (isStandalone()) return;
    makeUI();
    const bar = document.getElementById('pwaInstallBar');
    const button = document.getElementById('pwaInstall');
    if (!bar || !button) return;
    button.textContent = 'Install';
    button.onclick = async () => {
      if (!deferredPrompt || promptInProgress) return;
      promptInProgress = true;
      try {
        await deferredPrompt.prompt();
        const result = await deferredPrompt.userChoice;
        deferredPrompt = null;
        bar.classList.remove('show');
        if (result?.outcome === 'accepted') showStatus('Installing RTCrackers…');
      } catch (error) {
        console.warn('PWA install prompt could not be opened:', error);
      } finally {
        promptInProgress = false;
      }
    };
    const dismissedAt = Number(localStorage.getItem(DISMISS_KEY) || 0);
    if (!dismissedAt || Date.now() - dismissedAt >= 7 * 24 * 60 * 60 * 1000) {
      requestAnimationFrame(() => bar.classList.add('show'));
    }
  });

  function maybeShowIOSInstallHelp() {
    const ua = navigator.userAgent || '';
    const isIOS = /iPad|iPhone|iPod/.test(ua) && !window.MSStream;
    if (!isIOS || isStandalone() || localStorage.getItem(DISMISS_KEY)) return;

    makeUI();
    const bar = document.getElementById('pwaInstallBar');
    if (!bar) return;
    bar.innerHTML = `<div class="pwa-install-copy"><strong>Add RTCrackers to your Home Screen</strong><span>Tap Share in Safari, then choose “Add to Home Screen”.</span></div><div class="pwa-install-actions"><button class="pwa-dismiss-btn" id="pwaDismissIOS" type="button">Later</button></div>`;
    bar.classList.add('show');
    document.getElementById('pwaDismissIOS').onclick = () => {
      localStorage.setItem(DISMISS_KEY, String(Date.now()));
      bar.classList.remove('show');
    };
  }

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    document.getElementById('pwaInstallBar')?.classList.remove('show');
    showStatus('RTCrackers was installed successfully.');
  });

  function init() {
    register();
    initNetworkStatus();
    setTimeout(maybeShowIOSInstallHelp, 1200);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init, { once: true });
  else init();
})();
