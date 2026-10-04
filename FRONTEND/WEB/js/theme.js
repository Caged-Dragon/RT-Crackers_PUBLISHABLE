/*
 * RTCrackers appearance + site theme manager
 * Appearance modes: light | dark | system
 * Site theme colours continue to come from Supabase's site_theme table.
 */
(function () {
  const fallback = {
    name: 'RT Festive', primary: '#e63946', secondary: '#f3722c', accent: '#ffbf3f',
    accent2: '#8338ec', dark: '#0a0f24', dark2: '#1c2650', surface: '#fffdfa',
    surface2: '#f2f1ec', text_color: '#14162a', success: '#2e7d4f'
  };

  const APPEARANCE_KEY = 'rt-crackers-appearance';
  const validModes = ['light', 'dark', 'system'];
  const media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function getStoredAppearance() {
    try {
      const value = localStorage.getItem(APPEARANCE_KEY);
      return validModes.includes(value) ? value : 'system';
    } catch (_) {
      return 'system';
    }
  }

  function resolveAppearance(mode) {
    return mode === 'system' ? (media && media.matches ? 'dark' : 'light') : mode;
  }

  function updateThemeColor(resolved) {
    let meta = document.querySelector('meta[name="theme-color"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'theme-color';
      document.head.appendChild(meta);
    }
    meta.content = resolved === 'dark' ? '#0b1020' : '#fffdfa';
  }

  function applyAppearance(mode, persist) {
    mode = validModes.includes(mode) ? mode : 'system';
    const resolved = resolveAppearance(mode);
    const root = document.documentElement;

    root.dataset.rtAppearance = mode;
    root.dataset.rtResolvedAppearance = resolved;
    root.style.colorScheme = resolved;
    updateThemeColor(resolved);

    if (persist !== false) {
      try { localStorage.setItem(APPEARANCE_KEY, mode); } catch (_) {}
    }

    document.querySelectorAll('[data-rt-appearance-option]').forEach((button) => {
      const active = button.dataset.rtAppearanceOption === mode;
      button.classList.toggle('active', active);
      button.setAttribute('aria-pressed', String(active));
    });

    const label = document.querySelector('[data-rt-appearance-label]');
    if (label) label.textContent = mode.charAt(0).toUpperCase() + mode.slice(1);
  }

  function createAppearanceControl() {
    if (document.querySelector('.rt-appearance-control')) return;

    const control = document.createElement('div');
    control.className = 'rt-appearance-control';
    control.setAttribute('aria-label', 'Appearance theme');
    control.innerHTML = `
      <span class="rt-appearance-title" data-rt-appearance-label>System</span>
      <div class="rt-appearance-options" role="group" aria-label="Choose appearance">
        <button type="button" data-rt-appearance-option="light" aria-label="Use light theme" title="Light">☀️</button>
        <button type="button" data-rt-appearance-option="dark" aria-label="Use dark theme" title="Dark">🌙</button>
        <button type="button" data-rt-appearance-option="system" aria-label="Follow system theme" title="System">💻</button>
      </div>`;

    document.body.appendChild(control);
    control.addEventListener('click', (event) => {
      const button = event.target.closest('[data-rt-appearance-option]');
      if (!button) return;
      applyAppearance(button.dataset.rtAppearanceOption, true);
    });
  }

  function blend(a, b, p) {
    try {
      const x = parseInt(a.slice(1), 16), y = parseInt(b.slice(1), 16);
      const rr = Math.round((x >> 16) * (1 - p) + (y >> 16) * p);
      const gg = Math.round(((x >> 8) & 255) * (1 - p) + ((y >> 8) & 255) * p);
      const bb = Math.round((x & 255) * (1 - p) + (y & 255) * p);
      return '#' + [rr, gg, bb].map(v => v.toString(16).padStart(2, '0')).join('');
    } catch (_) { return '#d8dae4'; }
  }

  function apply(t) {
    t = Object.assign({}, fallback, t || {});
    const r = document.documentElement.style;
    const m = {
      primary: '--warm-red', secondary: '--warm-orange', accent: '--gold-400',
      accent2: '--brand-violet', dark: '--navy-950', dark2: '--navy-700',
      surface: '--cream', surface2: '--grey-100', text_color: '--ink', success: '--success'
    };

    // The Supabase site_theme row is the source of truth for the visual system.
    // The legacy variables above are retained for existing components, while
    // the appearance layer below consumes the same database values for both
    // light and dark presentation. Nothing in dark mode needs a separate
    // hard-coded palette.
    Object.keys(m).forEach(k => r.setProperty(m[k], t[k]));
    r.setProperty('--gold-500', t.accent);
    r.setProperty('--brand-blue', t.primary);
    r.setProperty('--brand-green', t.success);
    r.setProperty('--navy-900', t.dark);
    r.setProperty('--navy-800', t.dark2);
    r.setProperty('--navy-600', t.dark2);
    r.setProperty('--grey-300', blend(t.surface2, t.text_color, .18));
    r.setProperty('--grey-600', blend(t.text_color, t.surface, .55));
    r.setProperty('--white', '#ffffff');
    r.setProperty('--danger', t.primary);
    r.setProperty('--brand-gradient', 'linear-gradient(120deg,' + t.primary + ',' + t.secondary + ',' + t.accent + ')');
    r.setProperty('--brand-gradient-cool', 'linear-gradient(135deg,' + t.primary + ',' + t.accent2 + ')');
    r.setProperty('--brand-gradient-full', 'linear-gradient(100deg,' + t.primary + ',' + t.secondary + ',' + t.accent + ',' + t.success + ')');

    // Database-driven appearance tokens. These are deliberately derived from
    // the site_theme row so an admin theme change propagates everywhere.
    r.setProperty('--rt-theme-primary', t.primary);
    r.setProperty('--rt-theme-secondary', t.secondary);
    r.setProperty('--rt-theme-accent', t.accent);
    r.setProperty('--rt-theme-accent2', t.accent2);
    r.setProperty('--rt-theme-dark', t.dark);
    r.setProperty('--rt-theme-dark2', t.dark2);
    r.setProperty('--rt-theme-surface', t.surface);
    r.setProperty('--rt-theme-surface2', t.surface2);
    r.setProperty('--rt-theme-text', t.text_color);
    r.setProperty('--rt-theme-success', t.success);
    r.setProperty('--rt-theme-dark-text', '#ffffff');
    r.setProperty('--rt-theme-dark-muted', blend('#ffffff', t.dark2, .28));
    r.setProperty('--rt-theme-dark-border', blend('#ffffff', t.dark2, .78));
    r.setProperty('--rt-theme-dark-input', blend(t.dark, t.dark2, .42));
    r.setProperty('--rt-theme-dark-soft', blend(t.dark2, t.dark, .32));
    r.setProperty('--rt-theme-dark-heading', '#ffffff');

    document.documentElement.dataset.rtSiteTheme = t.name || 'custom';
    document.documentElement.dataset.rtThemeLoaded = 'true';
  }

  async function load() {
    apply(fallback);
    try {
      if (window.rtSupabase) {
        const { data, error } = await window.rtSupabase
          .from('site_theme')
          .select('id,name,primary,secondary,accent,accent2,dark,dark2,surface,surface2,text_color,success')
          .eq('id', 1).maybeSingle();
        if (!error && data) apply(data);
      }
    } catch (_) {}
  }

  // Apply immediately so the page does not remain in the wrong mode while loading.
  applyAppearance(getStoredAppearance(), false);

  document.addEventListener('DOMContentLoaded', () => {
    createAppearanceControl();
    applyAppearance(getStoredAppearance(), false);
  });

  if (media) {
    const onSystemChange = () => {
      if (getStoredAppearance() === 'system') applyAppearance('system', false);
    };
    if (media.addEventListener) media.addEventListener('change', onSystemChange);
    else if (media.addListener) media.addListener(onSystemChange);
  }

  window.RTTheme = {
    apply,
    load,
    fallback,
    getAppearance: getStoredAppearance,
    setAppearance: applyAppearance,
    resolveAppearance
  };

  load();
})();
