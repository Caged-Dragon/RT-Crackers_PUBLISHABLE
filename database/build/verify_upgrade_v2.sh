#!/usr/bin/env bash
# Builds base + upgrade v2 two ways (original single files vs this split project) in scratch databases,
# then diffs schema and seed data (timestamps masked). Needs psql + pg_dump and a server URL:
#   BASE_URL=postgresql://user:pass@host:5432 ORIGINAL_BASE=/path/rt_crackers_schema.sql \
#   ORIGINAL_V2=/path/rt_crackers_upgrade_v2.sql bash build/verify_upgrade_v2.sh
set -euo pipefail
: "${BASE_URL:?}"; : "${ORIGINAL_BASE:?}"; : "${ORIGINAL_V2:?}"
cd "$(dirname "$0")/.."
for d in rtc_v2_orig rtc_v2_split; do psql "$BASE_URL/postgres" -qc "DROP DATABASE IF EXISTS $d" -c "CREATE DATABASE $d"; done
psql "$BASE_URL/rtc_v2_orig"  -q -v ON_ERROR_STOP=1 -f "$ORIGINAL_BASE" -f "$ORIGINAL_V2"
psql "$BASE_URL/rtc_v2_split" -q -v ON_ERROR_STOP=1 -f 99_DEPLOYMENT/001_Schema_build.sql -f 99_DEPLOYMENT/002_Master_seed_data.sql \
                                                     -f 99_DEPLOYMENT/006_Upgrade_v2_build.sql
mask(){ sed -E -e "s/'[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:.]+'/'TS'/g" -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+/TS/g' | grep -v -e '^--' -e restrict; }
for k in schema-only data-only; do
  diff <(pg_dump "$BASE_URL/rtc_v2_orig"  --$k --no-owner --column-inserts 2>/dev/null | mask) \
       <(pg_dump "$BASE_URL/rtc_v2_split" --$k --no-owner --column-inserts 2>/dev/null | mask) \
    && echo "$k: IDENTICAL"
done
