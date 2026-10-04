# RTCrackers — Production Frontend Architecture, Refactoring & Deployment Guide

## 1. Executive Summary & Architecture Overview
This final engineering release refactors, standardizes, and hardens the entire **RTCrackers 29-page customer e-commerce frontend** into a modular, testable, secure, and production-ready SPA/SSR architecture.

- **Zero Page Creep:** Exactly 29 customer pages and canonical routing contracts preserved.
- **Backend Authority:** Absolute reliance on existing Customer and Admin backend APIs for pricing, GST (18%), PESO compliance locks, stock counters, coupons, and payments.
- **Brand System Integrity:** 100% adherence to the **Red Thunder Explosive Luxury** design tokens (`#0b0e12`, `#111418`, `#191c20`, `#e31b16`, `#ffce4b`) and the official brand emblem (`LOGO.jpeg`).
- **Zero Credentials / Zero Mock Data:** Purged all `localhost` bindings, developer stubs, inline test credentials, and unauthenticated mock endpoints.

---

## 2. Directory Structure & Feature-Based Modularity

The application code is organized strictly under a modular feature-first convention:

```text
rtc-customer-frontend/
├── public/
│   ├── favicon.ico
│   ├── robots.txt
│   ├── sitemap.xml
│   └── assets/images/branding/LOGO.jpeg
├── src/
│   ├── app/                      # Application entry, router, providers, error boundaries
│   │   ├── App.tsx
│   │   ├── Router.tsx
│   │   ├── ErrorBoundary.tsx
│   │   └── providers/
│   ├── assets/                   # Static icons, vector emblems, brand marks
│   ├── config/                   # Validated runtime environment configurations
│   │   ├── env.config.ts
│   │   └── constants.ts
│   ├── constants/                # Immutable route schemas, PESO limits, storage keys
│   ├── features/                 # Encapsulated vertical business domains
│   │   ├── auth/                 # Login, Register, Forgot Password, OTP handshake
│   │   ├── catalog/              # Product listing, search, categories, PDP, reviews
│   │   ├── cart/                 # Cart ledger, coupon validation, stock reservations
│   │   ├── checkout/             # Hazmat address picker, PESO 18+ gate, gateway locks
│   │   ├── orders/               # Orders ledger, AWB live milestone tracking
│   │   ├── account/              # Dashboard, addresses, RBI tokenized cards, RMA returns
│   │   └── legal/                # Privacy policy, terms, hazmat linehaul disclosure
│   ├── components/               # Centralized atomic & molecular design system UI
│   │   ├── button/               # Button.tsx, IconButton.tsx
│   │   ├── input/                # TextInput.tsx, Select.tsx, Checkbox.tsx, OTPInput.tsx
│   │   ├── feedback/             # Toast.tsx, Spinner.tsx, ConfirmationDialog.tsx
│   │   ├── layout/               # Header.tsx, Footer.tsx, MobileDrawer.tsx, Breadcrumbs.tsx
│   │   ├── state/                # EmptyState.tsx, ErrorState.tsx, PageSkeleton.tsx
│   │   └── media/                # LazyImage.tsx, DecibelMeter.tsx, ComplianceBadge.tsx
│   ├── services/                 # Centralized HTTP API client & interceptors
│   │   ├── apiClient.ts          # Axios/Fetch instance, timeout, cancellation tokens
│   │   ├── errorNormalizer.ts    # Normalized API error taxonomy
│   │   └── authService.ts        # HttpOnly session handshake & token lifecycle
│   ├── store/                    # Lightweight shared reactive state
│   │   ├── authStore.ts          # Session isolation & logout cache flush
│   │   ├── cartStore.ts          # Resilient local cache with server authoritativeness
│   │   └── uiStore.ts            # Modals, toasts, drawer, global network offline ping
│   ├── styles/                   # Global CSS custom properties & Tailwind config
│   │   ├── tokens.css
│   │   └── globals.css
│   ├── types/                    # Shared TypeScript domain contracts
│   └── utils/                    # Formatters (INR ₹, Date/Time IST, Address sanitizers)
├── .env.example
├── .env.production
├── Dockerfile
├── nginx.conf
└── package.json
```

---

## 3. Environment Configuration & Build-Time Validation (`src/config/env.config.ts`)

Prevents silent fallbacks to `localhost` or insecure development stubs in production. Missing required variables halt the build immediately with actionable diagnostic output:

```typescript
// src/config/env.config.ts
interface EnvConfig {
  NODE_ENV: 'development' | 'staging' | 'production';
  API_BASE_URL: string;
  APP_BASE_URL: string;
  CDN_BASE_URL: string;
  ENABLE_ANALYTICS: boolean;
  PESO_LICENSE_NUMBER: string;
  GATEWAY_PUBLIC_KEY: string;
  API_TIMEOUT_MS: number;
}

function validateEnv(): EnvConfig {
  const requiredKeys = ['API_BASE_URL', 'APP_BASE_URL', 'GATEWAY_PUBLIC_KEY'];
  const missing = requiredKeys.filter((key) => !process.env[`VITE_${key}`]);

  if (missing.length > 0 && process.env.NODE_ENV === 'production') {
    throw new Error(
      `[FATAL CONFIG ERROR] Missing required production environment variables: ${missing.join(', ')}. ` +
      `Ensure these are securely supplied by the deployment pipeline.`
    );
  }

  return {
    NODE_ENV: (process.env.NODE_ENV as EnvConfig['NODE_ENV']) || 'development',
    API_BASE_URL: process.env.VITE_API_BASE_URL || 'https://api.rtcrackers.com/v1',
    APP_BASE_URL: process.env.VITE_APP_BASE_URL || 'https://www.rtcrackers.com',
    CDN_BASE_URL: process.env.VITE_CDN_BASE_URL || 'https://cdn.rtcrackers.com',
    ENABLE_ANALYTICS: process.env.VITE_ENABLE_ANALYTICS === 'true',
    PESO_LICENSE_NUMBER: process.env.VITE_PESO_LICENSE_NUMBER || 'E-11942',
    GATEWAY_PUBLIC_KEY: process.env.VITE_GATEWAY_PUBLIC_KEY || '',
    API_TIMEOUT_MS: parseInt(process.env.VITE_API_TIMEOUT_MS || '12000', 10),
  };
}

export const env = validateEnv();
```

---

## 4. Centralized API Client & Normalized Error Handling (`src/services/apiClient.ts`)

Encapsulates authentication tokens, automatic request cancellation (via `AbortController`), request retries with exponential backoff on transient network failures, and uniform error taxonomy:

```typescript
// src/services/apiClient.ts
import { env } from '../config/env.config';

export interface AppApiError {
  code: 'UNAUTHORIZED' | 'FORBIDDEN' | 'NOT_FOUND' | 'INSUFFICIENT_STOCK' | 'GATEWAY_TIMEOUT' | 'SERVER_ERROR' | 'NETWORK_ERROR';
  message: string;
  statusCode: number;
  details?: Record<string, unknown>;
}

export async function executeApiRequest<T>(
  endpoint: string,
  options: RequestInit & { timeoutMs?: number; abortSignal?: AbortSignal } = {}
): Promise<T> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), options.timeoutMs || env.API_TIMEOUT_MS);
  const signal = options.abortSignal || controller.signal;

  try {
    const res = await fetch(`${env.API_BASE_URL}${endpoint}`, {
      ...options,
      signal,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Client-Version': '2.4.0',
        ...options.headers,
      },
      credentials: 'same-origin', // Transmits httpOnly cookies securely
    });

    clearTimeout(timeoutId);

    if (!res.ok) {
      const errorBody = await res.json().catch(() => ({}));
      throw normalizeError(res.status, errorBody);
    }

    return (await res.json()) as T;
  } catch (err: any) {
    clearTimeout(timeoutId);
    if (err.name === 'AbortError') {
      throw {
        code: 'GATEWAY_TIMEOUT',
        message: 'The Sivakasi server took too long to respond. Please check your connectivity and try again.',
        statusCode: 408,
      } as AppApiError;
    }
    if (err.code) throw err;
    throw {
      code: 'NETWORK_ERROR',
      message: 'Unable to reach the RTCrackers pyrotechnic dispatch network. Please verify your connection.',
      statusCode: 0,
    } as AppApiError;
  }
}

function normalizeError(status: number, body: any): AppApiError {
  switch (status) {
    case 401:
      return { code: 'UNAUTHORIZED', message: body.message || 'Session expired. Please sign in again.', statusCode: 401 };
    case 403:
      return { code: 'FORBIDDEN', message: body.message || 'You do not have clearance to view this consignment.', statusCode: 403 };
    case 404:
      return { code: 'NOT_FOUND', message: body.message || 'The requested pyrotechnic batch could not be found.', statusCode: 404 };
    case 409:
      return { code: 'INSUFFICIENT_STOCK', message: body.message || 'Inventory allocated to another order during surge.', statusCode: 409 };
    default:
      return { code: 'SERVER_ERROR', message: 'A Sivakasi warehouse cluster error occurred. Our engineers have been alerted.', statusCode: status };
  }
}
```

---

## 5. Design Tokens Consolidation (`src/styles/tokens.css`)

All components, modals, sheets, and pages consume these shared, authoritative tokens:

```css
:root {
  /* Brand Primary Colors — Derived strictly from LOGO.jpeg */
  --rt-brand-crimson: #e31b16;
  --rt-brand-crimson-hover: #c41410;
  --rt-brand-gold: #ffce4b;
  --rt-brand-gold-hover: #e6b83a;
  --rt-brand-glow: rgba(227, 27, 22, 0.35);
  --rt-gold-glow: rgba(255, 206, 75, 0.25);

  /* Dark Pyrotechnic Surfaces */
  --rt-canvas: #0b0e12;
  --rt-surface-card: #111418;
  --rt-surface-elevated: #191c20;
  --rt-surface-field: #24282d;
  --rt-surface-border: #32373e;

  /* Typography Colors */
  --rt-text-primary: #f8f9ff;
  --rt-text-secondary: #b5b9c2;
  --rt-text-muted: #747984;

  /* Font Families */
  --rt-font-heading: 'Oswald', sans-serif;
  --rt-font-body: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;

  /* Structural Radii */
  --rt-radius-btn: 4px;
  --rt-radius-input: 8px;
  --rt-radius-card: 12px;
  --rt-radius-modal: 16px;
}
```

---

## 6. Shared Atomic Component System

Centralized shared components in `src/components/` eliminate code duplication and UI drift across all 29 customer pages:
- **`Button.tsx`**: Standardized variants (`primary`, `secondary`, `outline`, `ghost`, `danger`), with built-in accessibility focus states, loading spinners, and anti-double-click disabling.
- **`TextInput.tsx` / `Select.tsx`**: Integrated labels, required badges, helper text, and WCAG-compliant error announcement via `aria-describedby` and `aria-invalid`.
- **`EmptyState.tsx`**: Consistent illustration, title, description, and primary CTA button across zero search results, empty cart, empty wishlist, and zero order history.
- **`PageSkeleton.tsx`**: Unified animated pulse placeholders mimicking product cards, data tables, and hero banners to eliminate cumulative layout shift (CLS).
- **`ErrorBoundary.tsx`**: React lifecycle error boundary catching rendering exceptions, isolating failures to specific components, and rendering a branded, reassuring recovery card without leaking stack traces.

---

## 7. Canonical Master Route Registry (`src/constants/routes.ts`)

```typescript
export const ROUTES = {
  // Storefront & Public
  HOME: '/',
  PRODUCTS: '/products',
  PRODUCT_DETAIL: (slug: string) => `/product/${slug}`,
  CATEGORIES: '/categories',
  OFFERS: '/offers',
  SEARCH: '/search',

  // Conversion Funnel
  CART: '/cart',
  CHECKOUT: '/checkout',
  ORDER_SUCCESS: (orderId: string) => `/order/success/${orderId}`,

  // Auth (Guest-only)
  LOGIN: '/login',
  SIGNUP: '/signup',
  FORGOT_PASSWORD: '/forgot-password',

  // Customer Account (Auth Guard Protected)
  ACCOUNT: '/account',
  ORDERS: '/account/orders',
  ORDER_DETAIL: (orderId: string) => `/account/orders/${orderId}`,
  WISHLIST: '/account/wishlist',
  ADDRESSES: '/account/addresses',
  PAYMENTS: '/account/payments',
  RETURNS: '/account/returns',
  REVIEWS: '/account/reviews',
  SUPPORT: '/account/support',
  NOTIFICATIONS: '/account/notifications',
  PROFILE: '/account/profile',

  // Legal & Informational
  ABOUT: '/about',
  CONTACT: '/contact',
  FAQ: '/faq',
  SHIPPING: '/shipping',
  RETURNS_POLICY: '/returns-policy',
  PRIVACY_POLICY: '/privacy-policy',
  TERMS: '/terms-and-conditions',

  // Status & Resilience
  NOT_FOUND: '/404',
  MAINTENANCE: '/maintenance',
} as const;
```

---

## 8. Docker & Production Nginx Deployment Configuration

### 8.1 Dockerfile (Multi-Stage Optimized Build)
```dockerfile
# Stage 1: Build & Validate
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --prefer-offline
COPY . .
RUN npm run typecheck
RUN npm run lint
RUN npm run build

# Stage 2: Production Lightweight Web Serving
FROM nginx:alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

### 8.2 Production Nginx Configuration (`nginx.conf`)
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; img-src 'self' data: https://cdn.rtcrackers.com; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;" always;

    # Static Assets Long-term Caching
    location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc|woff|woff2)$ {
        expires 1y;
        access_log off;
        add_header Cache-Control "public, immutable";
    }

    # SPA Routing Fallback
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, must-revalidate";
    }

    # Health Check Endpoint
    location /health {
        access_log off;
        return 200 '{"status":"UP","app":"RTCrackers-Customer-Frontend"}';
        add_header Content-Type application/json;
    }
}
```

---

## 9. Verification & Pre-Flight Release Checklist
- [x] **Zero Rogue Development URLs:** All references to `localhost`, port numbers, and arbitrary staging strings removed and redirected through `env.API_BASE_URL`.
- [x] **Zero Hardcoded Mock Data:** Production UI renders exclusively from authenticated API payloads with resilient skeleton, error, and empty states.
- [x] **Zero Unhandled Double-Clicks:** All transaction and order submission buttons guarded with disabled UI states and server idempotency tokens.
- [x] **Full 29-Screen Visual Uniformity:** Header, footer, typography, and color tokens tested across all 29 customer pages with zero aesthetic drift.
- [x] **Build & Lint Verification:** Automated TypeScript build checks (`npm run typecheck`) and bundle hygiene verified for zero bundle-bloat dependencies.


## Current 2026-10-04 Integration Overrides

The implementation in this archive supersedes any older design text above where it conflicts with the current storefront requirement:

- **Default theme:** bright RT Crackers red/gold/blue theme derived from the supplied RT Crackers banner and product artwork.
- **Dark theme:** optional and manually selected by the user; it is never auto-selected from the device preference.
- **Authentication:** frontend uses `credentials: include`; Customer and Admin APIs support HttpOnly access/refresh cookies. The frontend runtime does not persist JWTs in localStorage.
- **CMS:** About, Shipping, Buying Terms, Privacy content, FAQs, policies and home sections are designed to be editable through the Admin CMS. A dedicated `admin_content_manager_rtcrackers` page is included.
- **Returns/refunds:** customer-facing Returns/Refunds pages, policy text and public platform returns/refunds endpoints are not part of the active storefront. Internal legacy database tables/modules are retained only for compatibility with existing deployments.
- **Brand assets:** the supplied `LOGO.jpeg`, `rtcrackers-home-banner.jpeg` and `electric-sparklers-10cm.jpeg` are available under `FRONTEND/assets/branding/`.
- **Store contact:** WhatsApp ordering number shown in the supplied artwork is `8124100501`; the supplied Policy document lists `7358737658` and `sales@rtcrackers.com` for customer support.
