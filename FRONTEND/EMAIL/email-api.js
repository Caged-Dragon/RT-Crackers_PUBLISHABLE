(() => {
  const cfg = window.RTC_MAIL_CONFIG || { apiBase: "/api/v1/email" };

  async function request(path, options = {}) {
    const response = await fetch(`${cfg.apiBase}${path}`, {
      credentials: "include",
      ...options,
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        ...(options.headers || {})
      }
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      const error = new Error(body.detail || body.message || `Mail API error (${response.status})`);
      error.status = response.status;
      throw error;
    }
    return body;
  }

  const api = {
    mailboxes: () => request("/mailboxes"),
    inbox: (id, params = "") => request(`/inbox/${id}${params}`),
    sent: (id, params = "") => request(`/outbox/${id}${params}`),
    starred: (id, params = "") => request(`/starred/${id}${params}`),
    archived: (id, params = "") => request(`/archived/${id}${params}`),
    trash: (id, params = "") => request(`/trash/${id}${params}`),
    drafts: (id, params = "") => request(`/drafts/${id}${params}`),
    search: (id, q) => request(`/search/${id}?q=${encodeURIComponent(q)}`),
    message: (id) => request(`/messages/${id}`),
    send: (payload) => request("/send", { method: "POST", body: JSON.stringify(payload) }),
    draft: (payload) => request("/drafts", { method: "POST", body: JSON.stringify(payload) }),
    read: (id, value = true) => request(`/messages/${id}/${value ? "read" : "unread"}`, { method: "POST" }),
    star: (id, value = true) => request(`/messages/${id}/${value ? "star" : "unstar"}`, { method: "POST" }),
    archive: (id, value = true) => request(`/messages/${id}/${value ? "archive" : "unarchive"}`, { method: "POST" }),
    trashMessage: (id, value = true) => request(`/messages/${id}/${value ? "trash" : "restore"}`, { method: "POST" })
  };

  window.RTCMailAPI = api;
})();
