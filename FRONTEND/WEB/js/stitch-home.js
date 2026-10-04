(() => {
  "use strict";

  // Stitch-style home search preserves the existing products page and query API.
  const search = document.getElementById("homeSearch");
  const searchButton = document.getElementById("homeSearchButton");
  if (search && searchButton) {
    const sync = () => {
      const q = search.value.trim();
      searchButton.href = q ? `products.html?q=${encodeURIComponent(q)}` : "products.html";
    };
    search.addEventListener("input", sync);
    search.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        sync();
        window.location.href = searchButton.href;
      }
    });
  }

  // Add a small live countdown to the promo strip without touching backend data.
  // It intentionally uses a rolling 72-hour window rather than claiming a real
  // promotion deadline that is not supplied by the application data.
  const timerKey = "rt_home_promo_started_v1";
  let started = Number(localStorage.getItem(timerKey) || 0);
  if (!started || Date.now() - started > 72 * 60 * 60 * 1000) {
    started = Date.now();
    localStorage.setItem(timerKey, String(started));
  }
})();
