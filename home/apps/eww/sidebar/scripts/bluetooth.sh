#!/run/current-system/sw/bin/bash
set -euo pipefail

if ! command -v bluetoothctl >/dev/null 2>&1; then
  printf '0\n'
  exit 0
fi

count_connected() {
  bluetoothctl devices Connected 2>/dev/null | awk 'NF {c++} END {print c+0}'
}

print_count() {
  local count
  count=$(count_connected || printf '0')
  printf '%s\n' "$count"
}

print_count

bluetoothctl --monitor |
  while IFS= read -r line; do
    [[ $line == *"Connected:"* ]] || continue
    print_count
  done || true
