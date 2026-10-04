# Remaining Blockers

These are the items that cannot be truthfully marked complete from the uploaded source alone.

1. **Real infrastructure validation:** this audit environment has no Docker binary and cannot install Python packages from the public package index. CI/deployment infrastructure must execute the runtime checks.
2. **Real PostgreSQL/Redis validation:** the supplied project does not include production credentials, so database connectivity, Alembic execution and Celery/Redis startup could not be performed against the real environment.
3. **80%+ test coverage:** the repository contains a small existing test suite relative to the 400+ Python files. The critical business paths are hardened, but an honest whole-codebase 80% coverage claim cannot be made yet.
4. **TLS/DNS:** certificate issuance, DNS records and domain ownership require access to the registrar/DNS provider and hosting account.
5. **Provider configuration:** SMTP/SMS/storage credentials must be supplied and tested in staging.
6. **Existing-data compatibility:** before applying the new inventory movement unique index, check production for historical duplicates.
7. **Multi-instance rate limiting:** the application limiter is per process. For multiple replicas, add a shared Redis/gateway limiter if strict global request quotas are required.


## Remaining infrastructure-dependent validation
- A real staging PostgreSQL/Redis deployment is still required to execute migrations and transaction/concurrency tests against the actual database.
- TLS/DNS and transactional email delivery must be verified on the chosen hosting provider.
- Full browser/device behavioural coverage and measured 80%+ whole-codebase coverage are not honestly claimable from static/local execution alone; the current customer test suite reports 5 passing tests and static compilation passes.
