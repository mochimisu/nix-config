#!/run/current-system/sw/bin/bash
set -euo pipefail

hyprland-activewindow _ | while IFS= read -r line; do
  clients="$(hyprctl -j clients 2>/dev/null || printf '[]')"

  jq -c --unbuffered --argjson clients "$clients" '
    def by_keys:
      to_entries
      | map(
          .key as $monitorKey
          | (.value + {
              fullscreen: any($clients[]; ((.fullscreen // 0) != 0) and ((.monitor | tostring) == ($monitorKey | tostring)))
            }) as $monitor
          | [
              {key: ($monitorKey | tostring), value: $monitor},
              (if $monitor.name != null then {key: ($monitor.name | tostring), value: $monitor} else empty end)
            ]
        )
      | flatten
      | from_entries;

    by_keys
  ' <<<"$line"
done
