(function () {
  "use strict";
  const reduced = window.matchMedia?.("(prefers-reduced-motion: reduce)").matches;
  if (reduced) return;

  let observer = null;
  let raf = 0;

  function setupProgress() {
    let bar = document.getElementById("rtScrollProgress");
    if (!bar) {
      bar = document.createElement("div");
      bar.id = "rtScrollProgress";
      bar.setAttribute("aria-hidden", "true");
      document.body.appendChild(bar);
    }
    function update() {
      raf = 0;
      const doc = document.documentElement;
      const max = Math.max(1, doc.scrollHeight - window.innerHeight);
      bar.style.transform = `scaleX(${Math.min(1, Math.max(0, window.scrollY / max))})`;
    }
    window.addEventListener("scroll", () => { if (!raf) raf = requestAnimationFrame(update); }, { passive: true });
    window.addEventListener("resize", update, { passive: true });
    update();
  }

  function candidates() {
    return [...document.querySelectorAll("main section, main .section, main .card, main .notice-box, main .category-card, main .product-card, main .grid > *, main .section-head, .rt-banner")]
      .filter(el => el.dataset.rtMotion !== "off" && !el.closest(".site-footer,[data-no-scroll-animation]") && (el.textContent.trim() || el.querySelector("img,video,canvas")));
  }

  function prepare(elements) {
    let i = 0;
    elements.forEach(el => {
      if (el.dataset.rtAnimateReady) return;
      const pattern = i++ % 4;
      el.dataset.rtAnimate = ["left", "up", "right", "up"][pattern];
      el.dataset.rtAnimateReady = "1";
      if (el.matches(".grid > *, .card, .notice-box, .category-card, .product-card, .rt-banner")) {
        el.classList.add(`rt-motion-delay-${(i % 5) + 1}`);
      }
      if (el.matches(".card, .category-card, .product-card, .rt-banner")) el.classList.add("rt-motion-tilt");
    });
  }

  function init() {
    setupProgress();
    const initial = candidates();
    prepare(initial);

    observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("rt-motion-visible");
        entry.target.classList.remove("rt-motion-leaving");
        observer.unobserve(entry.target);
      });
    }, { rootMargin: "0px 0px -12% 0px", threshold: .04 });

    initial.forEach(el => observer.observe(el));

    const mutation = new MutationObserver(() => {
      const fresh = candidates().filter(el => !el.dataset.rtAnimateReady);
      prepare(fresh);
      fresh.forEach(el => observer.observe(el));
    });
    mutation.observe(document.body, { childList: true, subtree: true });

    // Device-sized pointer interaction. Disabled for coarse pointers so mobile
    // devices do not get heavy mouse effects.
    if (window.matchMedia?.("(pointer:fine)").matches) {
      document.addEventListener("pointermove", event => {
        const card = event.target.closest?.(".rt-motion-tilt");
        if (!card) return;
        const r = card.getBoundingClientRect();
        const x = (event.clientX - r.left) / r.width;
        const y = (event.clientY - r.top) / r.height;
        card.style.setProperty("--rt-tilt-y", `${(x - .5) * 8}deg`);
        card.style.setProperty("--rt-tilt-x", `${(y - .5) * -8}deg`);
        card.style.setProperty("--rt-glow-x", `${x * 100}%`);
        card.style.setProperty("--rt-glow-y", `${y * 100}%`);
      }, { passive: true });
      document.addEventListener("pointerout", event => {
        const card = event.target.closest?.(".rt-motion-tilt");
        if (!card) return;
        if (!card.contains(event.relatedTarget)) {
          card.style.setProperty("--rt-tilt-x", "0deg");
          card.style.setProperty("--rt-tilt-y", "0deg");
        }
      }, { passive: true });
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init, { once:true });
  else init();

  window.RTMotion = { refresh() {
    if (!observer) return;
    const fresh = candidates().filter(el => !el.dataset.rtAnimateReady);
    prepare(fresh); fresh.forEach(el => observer.observe(el));
  }};
})();
