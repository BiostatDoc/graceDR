#!/usr/bin/env bash
set -u

if [ "$#" -ne 1 ]; then
  echo "usage: run_stata.sh <do-file>" >&2
  exit 2
fi

stata_exe="${STATA_EXE:-C:/Program Files/StataNow19/StataMP-64.exe}"
if [ ! -f "$stata_exe" ]; then
  echo "Stata not found at $stata_exe. Set STATA_EXE to the Stata executable." >&2
  exit 2
fi

do_file="$(cygpath -w "$(realpath "$1")")"
stata_exe_win="$(cygpath -w "$stata_exe")"
work_dir="$(cygpath -w "$PWD")"
export GRACEDR_STATA_DIR="$(cygpath -m "$PWD")"
log_file="$(basename "$1" .do).log"
rm -f "$log_file"

powershell -NoProfile -Command "Start-Process -FilePath '$stata_exe_win' \
  -ArgumentList '/e','do','\"$do_file\"' -Wait -WorkingDirectory '$work_dir'"

if [ ! -f "$log_file" ]; then
  echo "Stata wrote no log file $log_file" >&2
  exit 1
fi

sed -n '/^\. do /,$p' "$log_file"

if grep -qE '^r\([0-9]+\);' "$log_file"; then
  echo "Stata reported an error in $1" >&2
  exit 1
fi
