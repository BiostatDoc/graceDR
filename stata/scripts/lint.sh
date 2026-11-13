#!/usr/bin/env bash
set -u

files="$(find ado cert -type f \( -name '*.ado' -o -name '*.do' \) | sort)"
if [ -z "$files" ]; then
  echo "No Stata files found to lint." >&2
  exit 1
fi

lint_do="$(mktemp -d)/lint_files.do"
: > "$lint_do"
while IFS= read -r file; do
  echo "lint \"$(cygpath -m "$(realpath "$file")")\", linemax(99)" >> "$lint_do"
done <<< "$files"

status=0
bash scripts/run_stata.sh "$lint_do" > lint_output.txt || status=1

problem_rows='^[A-Za-z].*:[[:space:]]+([1-9][0-9]*|Yes)[[:space:]]*$'
if [ "$status" -ne 0 ] || grep -qE "$problem_rows" lint_output.txt; then
  cat lint_output.txt >&2
  echo "stata_linter found problems or failed." >&2
  exit 1
fi
