#!/usr/bin/env bash
set -eu

shopt -s globstar nullglob
files=(ado/**/*.ado ado/**/*.mata cert/**/*.do)
if [ "${#files[@]}" -gt 0 ]; then
  sed -i -E 's/\t/    /g; s/[ ]+(\r?)$/\1/' "${files[@]}"
fi
