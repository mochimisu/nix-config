#!/run/current-system/sw/bin/bash
set -euo pipefail

state_file="@pttStateFile@"

if [ -z "$state_file" ]; then
  printf 'disabled\n'
  while sleep 60; do
    printf 'disabled\n'
  done
fi

while true; do
  if [ -f "$state_file" ]; then
    tr -d '[:space:]' < "$state_file"
    printf '\n'
  else
    printf 'disabled\n'
  fi
  sleep 0.5
done
