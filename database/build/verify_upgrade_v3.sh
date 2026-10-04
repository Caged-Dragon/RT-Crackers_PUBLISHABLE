#!/usr/bin/env bash
# Proves the split project and the single build file give the same database.
# Builds base + v2 once, then applies V3 two ways (psql master script vs build/rt_crackers_upgrade_v3_full.sql) and diffs schema + data.
#   BASE_URL=postgresql://user:pass@host:5432 bash build/verify_upgrade_v3.sh
set -euo pipefail
: "${BASE_URL:?}"
cd "$(dirname "$0")/.."
bash build/build_upgrade_v3.sh
psql "$BASE_URL/postgres" -qc "DROP DATABASE IF EXISTS rtc_v3_base" -c "CREATE DATABASE rtc_v3_base"
psql "$BASE_URL/rtc_v3_base" -q -v ON_ERROR_STOP=1 -f build/rt_crackers_full.sql -f build/rt_crackers_upgrade_v2_full.sql
for d in rtc_v3_split rtc_v3_single; do psql "$BASE_URL/postgres" -qc "DROP DATABASE IF EXISTS $d" -c "CREATE DATABASE $d TEMPLATE rtc_v3_base"; done
psql "$BASE_URL/rtc_v3_split"  -q -f 99_DEPLOYMENT/007_Upgrade_v3_build.sql
psql "$BASE_URL/rtc_v3_single" -q -v ON_ERROR_STOP=1 -f build/rt_crackers_upgrade_v3_full.sql
mask(){ sed -E -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9:.]+/TS/g' | grep -v -e '^--' -e restrict; }
for k in schema-only data-only; do
  diff <(pg_dump "$BASE_URL/rtc_v3_split"  --$k --no-owner --column-inserts 2>/dev/null | mask) \
       <(pg_dump "$BASE_URL/rtc_v3_single" --$k --no-owner --column-inserts 2>/dev/null | mask) \
    && echo "$k: IDENTICAL"
done
