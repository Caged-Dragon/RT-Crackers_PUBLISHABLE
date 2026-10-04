(() => {
  const cfg = window.RTC_MAIL_CONFIG || {};
  const api = window.RTCMailAPI;
  const page = location.pathname.toLowerCase();

  const routes = {
    inbox: "/FRONTEND/EMAIL/PAGES/inbox.html",
    sent: "/FRONTEND/EMAIL/PAGES/sent.html",
    drafts: "/FRONTEND/EMAIL/PAGES/drafts.html",
    starred: "/FRONTEND/EMAIL/PAGES/starred.html",
    archived: "/FRONTEND/EMAIL/PAGES/archived.html",
    trash: "/FRONTEND/EMAIL/PAGES/trash.html",
    search: "/FRONTEND/EMAIL/PAGES/search.html",
    compose: "/FRONTEND/EMAIL/PAGES/compose.html",
    message: "/FRONTEND/EMAIL/PAGES/message.html",
    mailboxes: "/FRONTEND/EMAIL/PAGES/mailboxes.html",
    settings: "/FRONTEND/EMAIL/PAGES/settings.html"
  };

  function notify(text, error=false) {
    document.querySelectorAll(".rtc-mail-api-error").forEach(x => x.remove());
    const el = document.createElement("div");
    el.className = error ? "rtc-mail-api-error" : "rtc-mail-live-badge";
    el.textContent = text;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), error ? 6000 : 2400);
  }

  function localizeAssets() {
    document.querySelectorAll("img[src*='googleusercontent.com/aida']").forEach(img => {
      img.src = cfg.logo || "/ASSETS/LOGO.jpeg";
    });
    document.querySelectorAll("img[src*='googleusercontent.com/aida-public']").forEach(img => {
      img.src = cfg.logo || "/ASSETS/LOGO.jpeg";
    });
  }

  function wirePaths() {
    document.querySelectorAll("[data-path]").forEach(el => {
      const p = (el.getAttribute("data-path") || "").toLowerCase();
      let key = null;
      if (p.includes("inbox")) key = "inbox";
      else if (p.includes("sent") || p.includes("outbox")) key = "sent";
      else if (p.includes("draft")) key = "drafts";
      else if (p.includes("starred")) key = "starred";
      else if (p.includes("archived")) key = "archived";
      else if (p.includes("trash")) key = "trash";
      else if (p.includes("search")) key = "search";
      else if (p.includes("compose")) key = "compose";
      else if (p.includes("mailbox")) key = "mailboxes";
      else if (p.includes("settings")) key = "settings";
      if (key && routes[key]) {
        el.setAttribute("href", routes[key]);
      }
    });
  }

  function getMailboxId() {
    return Number(localStorage.getItem("rtc-mailbox-id") || cfg.defaultMailboxId || 0) || null;
  }

  async function ensureMailbox() {
    if (!api) return null;
    let id = getMailboxId();
    if (id) return id;
    const boxes = await api.mailboxes();
    if (boxes && boxes.length) {
      id = Number(boxes[0].id);
      localStorage.setItem("rtc-mailbox-id", String(id));
      return id;
    }
    return null;
  }

  function displayValue(value) {
    return value == null ? "" : String(value);
  }

  function makeRow(item) {
    const sender = displayValue(item.from_address || item.to_address || "Unknown");
    const initials = sender.replace(/<.*?>/g, "").trim().split(/[\s@._-]+/).filter(Boolean).slice(0,2).map(x => x[0]).join("").toUpperCase() || "?";
    const row = document.createElement("div");
    row.className = `email-row group relative flex items-start gap-space-sm px-space-md py-space-sm ${item.is_read ? "bg-white" : "bg-orange-50/50 border-l-4 border-l-tag-notifications"} hover:bg-orange-50/70 transition-colors cursor-pointer`;
    row.dataset.emailId = item.id;
    row.innerHTML = `
      <div class="pt-0.5 flex flex-col items-center gap-2 select-none">
        <button class="star-btn ${item.is_starred ? "text-amber-500" : "text-secondary"} hover:scale-110 transition-transform" type="button">
          <span class="material-symbols-outlined text-[20px]" style="font-variation-settings:'FILL' ${item.is_starred ? 1 : 0};">star</span>
        </button>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between gap-space-xs mb-0.5">
          <div class="flex items-center gap-space-xs min-w-0">
            <span class="w-6 h-6 rounded-full bg-tag-support text-on-primary flex items-center justify-center font-label-sm text-label-sm font-bold flex-shrink-0">${initials}</span>
            <span class="font-title-sm text-title-sm ${item.is_read ? "font-medium" : "font-bold"} text-on-surface truncate">${escapeHtml(sender)}</span>
          </div>
          <span class="font-label-sm text-label-sm text-secondary">${formatDate(item.created_at)}</span>
        </div>
        <div class="font-title-sm text-title-sm ${item.is_read ? "font-medium" : "font-bold"} text-on-surface truncate mb-0.5">${escapeHtml(item.subject || "(No subject)")}</div>
        <p class="font-body-sm text-body-sm text-secondary line-clamp-2">${escapeHtml(item.to_address || "")}</p>
      </div>
    `;
    row.querySelector(".star-btn").addEventListener("click", async e => {
      e.stopPropagation();
      try { await api.star(item.id, !item.is_starred); notify(item.is_starred ? "Star removed" : "Conversation starred"); }
      catch (err) { notify(err.message, true); }
    });
    row.addEventListener("click", async () => {
      try { await api.read(item.id, true); localStorage.setItem("rtc-mail-open-message", String(item.id)); location.href = routes.message; }
      catch (err) { notify(err.message, true); }
    });
    return row;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#039;" }[c]));
  }

  function formatDate(v) {
    if (!v) return "";
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return String(v);
    return d.toLocaleString("en-IN", { day:"2-digit", month:"short", hour:"2-digit", minute:"2-digit" });
  }

  async function hydrateInbox() {
    if (!/inbox/i.test(page) && page !== "/") return;
    const id = await ensureMailbox();
    if (!id) { notify("No active mailbox is configured.", true); return; }
    const items = await api.inbox(id);
    const existing = [...document.querySelectorAll(".email-row")];
    if (!existing.length) return;
    const parent = existing[0].parentElement;
    existing.forEach(x => x.remove());
    items.forEach(item => parent.appendChild(makeRow(item)));
  }

  async function hydrateMessage() {
    if (!/message/i.test(page)) return;
    const id = Number(localStorage.getItem("rtc-mail-open-message") || 0);
    if (!id) return;
    const data = await api.message(id);
    const title = document.querySelector("h1, h2");
    if (title && data.subject) title.textContent = data.subject;
    const bodyTargets = document.querySelectorAll("[data-email-body], .email-body, article");
    if (bodyTargets.length && (data.body_html || data.body_text)) {
      bodyTargets[bodyTargets.length - 1].innerHTML = data.body_html || `<pre style="white-space:pre-wrap">${escapeHtml(data.body_text || "")}</pre>`;
    }
  }

  async function hydrateCompose() {
    if (!/compose/i.test(page)) return;
    const id = await ensureMailbox();
    if (!id) return;
    const form = document.querySelector("form");
    if (!form || form.dataset.rtcBound) return;
    form.dataset.rtcBound = "1";
    form.addEventListener("submit", async e => {
      e.preventDefault();
      const inputs = [...form.querySelectorAll("input, textarea")];
      const byName = n => form.querySelector(`[name="${n}"]`) || inputs.find(x => (x.placeholder || "").toLowerCase().includes(n));
      const to = (byName("to")?.value || "").split(",").map(x => x.trim()).filter(Boolean);
      const subject = byName("subject")?.value || "";
      const body = form.querySelector("textarea")?.value || "";
      try {
        await api.send({ mailbox_id:id, to, cc:[], bcc:[], subject, body_text:body, body_html:null });
        notify("Email sent successfully.");
      } catch (err) { notify(err.message, true); }
    });
  }

  async function boot() {
    localizeAssets();
    wirePaths();
    try {
      await ensureMailbox();
      await hydrateInbox();
      await hydrateMessage();
      await hydrateCompose();
      if (/inbox/i.test(page)) notify("RTC Crackers Mail connected");
    } catch (err) {
      notify(err.message || "Mail service unavailable", true);
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
