#!/run/current-system/sw/bin/bash
set -euo pipefail

hostname="$(hostname -s 2>/dev/null || hostname)"
blocklist=()

if [[ "${hostname,,}" == "blackmoon" ]]; then
  blocklist=(
    "AD102 High Definition Audio Controller Digital Stereo (HDMI)"
    "USB Audio Front Headphones"
    "USB Audio Speakers"
    "RZ19-0229 Gaming Microphone Analog Stereo"
  )
fi

wait_for_pulse() {
  until pactl info >/dev/null 2>&1; do
    sleep 1
  done
}

blocklist_text() {
  local item

  for item in "${blocklist[@]}"; do
    printf '%s\n' "$item"
  done
}

volume_for_sink() {
  local sink="$1"

  pactl get-sink-volume "$sink" \
    | awk '
        /Volume:/ {
          max = 0;
          for (i = 1; i <= NF; i++) {
            if ($i ~ /^[0-9]+%$/) {
              value = $i + 0;
              if (value > max) {
                max = value;
              }
            }
          }
          print max;
          exit;
        }
      '
}

running_visible_sink() {
  local blocklist_data

  blocklist_data="$(blocklist_text)"

  pactl list sinks \
    | awk -v blocklist_data="$blocklist_data" '
        BEGIN {
          split(blocklist_data, blocklisted, "\n");
        }

        function is_blocklisted(description, i) {
          for (i in blocklisted) {
            if (description == blocklisted[i]) {
              return 1;
            }
          }

          return 0;
        }

        function emit_if_match() {
          if (state == "RUNNING" && name != "" && !is_blocklisted(description)) {
            print name;
            emitted = 1;
            exit;
          }
        }

        /^Sink #[0-9]+/ {
          emit_if_match();
          state = "";
          name = "";
          description = "";
          next;
        }

        /^[[:space:]]*State:/ {
          state = $2;
          next;
        }

        /^[[:space:]]*Name:/ {
          name = $2;
          next;
        }

        /^[[:space:]]*Description:/ {
          description = $0;
          sub(/^[[:space:]]*Description:[[:space:]]*/, "", description);
          next;
        }

        END {
          if (!emitted) {
            emit_if_match();
          }
        }
      '
}

default_sink_volume() {
  local default_sink volume

  default_sink=$(pactl info | awk -F': ' '/^Default Sink:/ {print $2}')

  if [[ -n "${default_sink:-}" ]]; then
    volume="$(volume_for_sink "$default_sink")"

    if [[ -n "${volume:-}" ]]; then
      printf '%s\n' "$volume"
      return 0
    fi
  fi

  if command -v wpctl >/dev/null 2>&1; then
    volume=$(
      wpctl get-volume @DEFAULT_SINK@ 2>/dev/null \
        | awk '/^Volume:/ {printf "%d\n", ($2 * 100) + 0.5; exit}'
    )

    if [[ -n "${volume:-}" ]]; then
      printf '%s\n' "$volume"
      return 0
    fi
  fi
}

print_current_volume() {
  local sink volume

  sink="$(running_visible_sink)"
  if [[ -n "${sink:-}" ]]; then
    volume="$(volume_for_sink "$sink")"

    if [[ -n "${volume:-}" ]]; then
      printf '%s\n' "$volume"
      return 0
    fi
  fi

  default_sink_volume
}

while true; do
  wait_for_pulse
  print_current_volume || true

  # Any sink/server change can affect the default sink or its volume, so re-query.
  if ! pactl subscribe 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *" on sink"* || "$line" == *" on server"* ]] || continue
    print_current_volume || true
  done; then
    sleep 1
  fi
done
