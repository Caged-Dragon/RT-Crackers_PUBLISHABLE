#!/usr/bin/env bash
# Regenerates build/rt_crackers_upgrade_v3_full.sql from 21_UPGRADE_V3/ (same order as 99_DEPLOYMENT/007_Upgrade_v3_build.sql).
set -euo pipefail
cd "$(dirname "$0")/.."
out=build/rt_crackers_upgrade_v3_full.sql
printf 'BEGIN;\n\n' > "$out"
for f in 21_UPGRADE_V3/0*.sql; do cat "$f" >> "$out"; printf '\n' >> "$out"; done
printf '\nCOMMIT;\n' >> "$out"
echo "wrote $out ($(wc -l < "$out") lines)"
