#!/run/current-system/sw/bin/bash

set -euo pipefail

hostname="$(hostname -s 2>/dev/null || hostname)"
blocklist_json='[]'

if [[ "${hostname,,}" == "blackmoon" ]]; then
  blocklist_json=$(
    cat <<'EOF'
["AD102 High Definition Audio Controller Digital Stereo (HDMI)","USB Audio Front Headphones","USB Audio Speakers","RZ19-0229 Gaming Microphone Analog Stereo"]
EOF
  )
fi

wait_for_pulse() {
  # Retry until PulseAudio/PipeWire is accepting connections.
  until pactl info >/dev/null 2>&1; do
    sleep 1
  done
}

collect_sinks_json() {
  pactl --format=json list sinks 2>/dev/null \
    | jq -c --unbuffered \
      --argjson blocklist "$blocklist_json" \
      '[.[] | select(.index != null)
            | (.description // .name) as $desc
            | select((($blocklist | length) == 0) or (($blocklist | index($desc)) == null))
            | {name, description: $desc, state}]'
}

emit_sinks() {
  local sinks_json

  while true; do
    if sinks_json="$(collect_sinks_json)"; then
      printf '%s\n' "$sinks_json"
      return 0
    fi

    sleep 1
  done
}

# Ensure the audio server is reachable before we start emitting data.
wait_for_pulse
emit_sinks

while true; do
  wait_for_pulse

  if ! pactl subscribe 2>/dev/null | while IFS= read -r line; do
    [[ "$line" == *"on sink"* ]] || continue
    emit_sinks
  done; then
    sleep 1
  fi
done
