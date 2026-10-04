# Platform release governance

Run `001_platform_release_governance.sql` once against the existing PostgreSQL database.

It is additive and does not reset business data. The admin panel uses draft -> verify -> publish. A failed verification never becomes the public release. The PWA prompts users before accepting a newer release.
