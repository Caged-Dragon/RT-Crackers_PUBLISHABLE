# Performance Report

## Improvements implemented

- Product listing is paginated.
- Cart catalog resolution batches products, variants and inventory rather than performing one query per line.
- Inventory availability is aggregated in SQL.
- Order inventory locks are acquired in deterministic `(product_id, variant_id)` order to reduce deadlock risk.
- Nginx uses upstream keepalive and static asset caching.
- Media responses can be cached for one day.
- API containers use Gunicorn/Uvicorn workers instead of a single development Uvicorn process.
- PostgreSQL connection pools have configurable size, overflow, timeout and recycle settings.
- Redis is retained for Celery broker/result backend and background jobs.
- Prometheus metrics are exposed at `/metrics` for customer/admin APIs.

## N+1 review

The cart repository was explicitly written to batch products/variants/inventory. Order detail and product services were reviewed for obvious per-item query loops; no high-risk catalog N+1 pattern was identified in the critical purchase path.

## Caching

The authoritative cart, price, inventory and order state remains in PostgreSQL. Redis should be used for ephemeral/cache workloads only; do not cache inventory or checkout totals without a short TTL and invalidation strategy.

## Remaining performance validation

Real performance numbers cannot be responsibly claimed without a production-like database and traffic profile. Before launch:

1. Load test 50–100 concurrent shoppers.
2. Test product listing at 95th/99th percentile latency.
3. Test 20–50 simultaneous attempts to purchase the last inventory unit.
4. Verify no duplicate orders or negative stock.
5. Monitor PostgreSQL pool saturation, slow queries and Redis memory.
6. Set alerts for 5xx rate, `/ready` failures, Celery queue depth and database connections.


## Final enhancement pass
- Static assets are served with cache headers through Nginx.
- PWA shell/runtime caching is separated from `/api/` requests so API responses are not accidentally cached by the service worker.
- Release checks use `cache: no-store` to avoid stale update metadata.
