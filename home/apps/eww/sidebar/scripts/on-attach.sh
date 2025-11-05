#!/run/current-system/sw/bin/bash

set -euo pipefail

monitor_name="${1:-}"

if [ -z "$monitor_name" ]; then
  echo "eww-on-attach: missing monitor argument" >&2
  exit 1
fi

# Ensure Hyprland is ready before talking to it.
while ! hyprctl monitors >/dev/null 2>&1; do
  sleep 0.1
done

config_dir="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}/.config/eww/sidebar"
window_id="bar_${monitor_name}"

# Some Hyprland hooks run with a reduced environment. Make sure XDG_RUNTIME_DIR is set so eww
# reuses the existing daemon socket instead of spawning a fresh one per monitor event.
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
  runtime_path="$(loginctl show-user "$(id -un)" -p RuntimePath --value 2>/dev/null || true)"
  if [ -n "$runtime_path" ]; then
    export XDG_RUNTIME_DIR="$runtime_path"
  fi
fi

# Start (or restart) the daemon if it's not reachable yet.
if ! eww --config "$config_dir" ping >/dev/null 2>&1; then
  eww daemon --config "$config_dir"
  # Give the daemon a brief moment to create the socket so the following open succeeds.
  sleep 0.5
fi

# Idempotently ensure the bar for this monitor exists.
eww --config "$config_dir" close "$window_id" >/dev/null 2>&1 || true
eww --config "$config_dir" open "$window_id"
