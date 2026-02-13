#!/run/current-system/sw/bin/bash
set -euo pipefail

hyprland-activewindow _ | jq -c --unbuffered 'to_entries | map([{(.key | tostring): .value}, (if .value.name != null then {(.value.name): .value} else empty end)]) | flatten | add'
