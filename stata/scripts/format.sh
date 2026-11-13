#!/usr/bin/env bash
set -eu

find ado cert -type f \( -name '*.ado' -o -name '*.do' \) -print0 |
  xargs -0 -r sed -i -E 's/\t/    /g; s/[ ]+(\r?)$/\1/'
