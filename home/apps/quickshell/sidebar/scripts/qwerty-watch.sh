#!/run/current-system/sw/bin/bash
set -euo pipefail

qwerty_bin="@qwertyBin@"

while true; do
  if ! "$qwerty_bin"; then
    printf 'other\n'
  fi
  sleep 1
done
