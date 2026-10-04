# RT Crackers Frontend Wiring

- Default theme: bright Red Thunder / RT Crackers visual language derived from the supplied banner and product artwork.
- Dark theme: user-selectable only; stored as `rtc-theme` and never auto-selected by the browser.
- Shared runtime: `runtime/rtc-runtime.js`.
- Shared theme: `runtime/theme.css`.
- API configuration can be supplied before the runtime script with `window.RT_CONFIG = { customerApi, adminApi, platformApi }`.
- Customer API: `/api/v1`; Admin API: `/api/v1/admin`; CMS reads: `/api/v1/cms`.
- Authentication is intended to use HttpOnly cookies from the patched backend; no access/refresh token is persisted by the frontend runtime.
- Customer-facing returns/refunds pages and links are removed from the active storefront.
- CMS-managed pages: `about`, `shipping`, `privacy-policy`, `terms-and-conditions`; home sections/FAQs/policies are editable through `/admin/content`.
- Supplied banner is used on the canonical home page and supplied sparklers artwork is available under `assets/branding/`.
