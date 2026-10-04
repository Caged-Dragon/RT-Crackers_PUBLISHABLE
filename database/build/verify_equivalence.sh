#!/usr/bin/env bash
# Builds the original single file and this split project into two scratch databases,
# then diffs schema and seed data (timestamps masked). Needs psql + pg_dump and a server URL:
#   BASE_URL=postgresql://user:pass@host:5432  ORIGINAL=/path/rt_crackers_schema.sql  bash build/verify_equivalence.sh
set -euo pipefail
: "${BASE_URL:?}"; : "${ORIGINAL:?}"
cd "$(dirname "$0")/.."
for d in rtc_orig rtc_split; do psql "$BASE_URL/postgres" -qc "DROP DATABASE IF EXISTS $d" -c "CREATE DATABASE $d"; done
psql "$BASE_URL/rtc_orig"  -q -v ON_ERROR_STOP=1 -f "$ORIGINAL"
psql "$BASE_URL/rtc_split" -q -v ON_ERROR_STOP=1 -f 99_DEPLOYMENT/001_Schema_build.sql
psql "$BASE_URL/rtc_split" -q -v ON_ERROR_STOP=1 -f 99_DEPLOYMENT/002_Master_seed_data.sql
mask(){ sed -E -e "s/'[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+'/'TS'/g" -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+/TS/g' | grep -v -e '^--' -e restrict; }
for k in schema-only data-only; do
  diff <(pg_dump "$BASE_URL/rtc_orig"  --$k --no-owner --column-inserts 2>/dev/null | mask) \
       <(pg_dump "$BASE_URL/rtc_split" --$k --no-owner --column-inserts 2>/dev/null | mask) \
    && echo "$k: IDENTICAL"
done
