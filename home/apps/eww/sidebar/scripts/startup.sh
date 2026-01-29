#!/run/current-system/sw/bin/bash

set -euo pipefail

# Ensure Hyprland is ready before talking to it.
while ! hyprctl monitors >/dev/null 2>&1; do
  sleep 0.1
done

config_dir="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}/.config/eww/sidebar"

# Some Hyprland hooks run with a reduced environment. Make sure XDG_RUNTIME_DIR is set so eww
# reuses the existing daemon socket instead of spawning a fresh one per event.
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  runtime_path="$(loginctl show-user "$(id -un)" -p RuntimePath --value 2>/dev/null || true)"
  if [ -n "$runtime_path" ]; then
    export XDG_RUNTIME_DIR="$runtime_path"
  fi
fi

# Start (or wait for) the daemon so open calls don't race the socket creation.
if ! eww --config "$config_dir" ping >/dev/null 2>&1; then
  eww daemon --config "$config_dir" >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if eww --config "$config_dir" ping >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
fi

if [ "$#" -eq 0 ]; then
  exit 0
fi

for monitor in "$@"; do
  window_id="bar_${monitor}"
  eww --config "$config_dir" open "$window_id" >/dev/null 2>&1 || true
done
