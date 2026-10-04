# Database Audit

## Existing schema assessment

The supplied SQL corpus contains approximately:

- 223 SQL files
- 244 `CREATE TABLE` statements
- 382 foreign-key declarations
- 516 check constraints
- 257 index declarations
- 121 trigger declarations

This is a substantial relational design and should be preserved rather than replaced.

## Referential integrity

Foreign keys are widely used across authentication, catalog, inventory, cart, orders, COD, shipping, reviews, marketing and audit tables. Delete behavior is generally explicit (`RESTRICT`, `SET NULL`, etc.) and appropriate for transactional data.

## Inventory

The existing schema already enforces:

- `quantity_on_hand >= 0`
- `0 <= reserved_quantity <= quantity_on_hand`
- unique inventory identity per product/variant
- movement type/sign validation
- append-only movement application trigger
- product stock synchronization trigger

Production hardening adds an idempotency unique index for order-related sale/cancel/return movements and keeps cancellation under row locks in the admin service.

## Orders / COD

The schema already constrains `payment_methods.method_code = 'COD'`. Production hardening additionally:

- deactivates non-COD methods,
- adds a direct-SQL COD-only order trigger,
- retains the existing COD transaction amount/status checks.

## Indexing

The project already contains dedicated index scripts for authentication, products, orders, inventory, analytics and system tables. Application repositories use pagination and batched catalog queries rather than loading complete tables for customer pages.

## Transactions / concurrency

Customer order placement uses one transactional unit for:

1. cart lock,
2. server-side repricing,
3. inventory row locks in deterministic order,
4. stock recheck,
5. coupon lock/revalidation,
6. order + order items,
7. inventory sale movements,
8. COD transaction/invoice/tracking,
9. cart conversion,
10. commit.

Cancellation locks the order and inventory rows before recording restock movements.

## Remaining DB work before launch

- Execute `009_Production_hardening.sql` on staging first.
- Run `010_Production_verification.sql` and archive its output.
- Inspect existing data for duplicate inventory movements before applying the new unique index if the database already contains historical duplicates.
- Run `EXPLAIN (ANALYZE, BUFFERS)` on the top product listing, cart catalog, order listing and admin dashboard queries against production-like data.
- Confirm managed PostgreSQL backup/PITR and restore procedure.
