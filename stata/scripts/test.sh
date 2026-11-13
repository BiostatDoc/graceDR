#!/usr/bin/env bash
set -u

status=0
for file in cert/certify_*.do; do
  echo "== $file"
  bash scripts/run_stata.sh "$file" || status=1
done
exit "$status"
