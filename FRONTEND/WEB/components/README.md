# RTCrackers Role-Based Header & Footer

This folder contains two reusable website shells:

- `customer-shell.js` — customer/store header + footer
- `admin-shell.js` — administrator header + footer
- `shell.css` — shared responsive styling

## Customer pages
Load:
```html
<script src="components/customer-shell.js?v=20261003"></script>
```

The script automatically replaces an existing `.site-header` / `.site-footer`, preserving the page body and existing business logic.

## Admin pages
Load:
```html
<script src="components/admin-shell.js?v=20261003"></script>
```

The admin shell is intended for the dashboard and other administrative pages. Do not load both shells on the same page.

## Login pages
For `admin.html` / `admin-register.html`, keep the existing centered authentication card. Add `class="admin-auth-page"` to `<body>` if the page should remain a standalone auth screen without the shell around it.
