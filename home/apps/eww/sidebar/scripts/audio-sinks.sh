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

print_sinks() {
  pactl --format=json list sinks \
    | jq -c --unbuffered \
      --argjson blocklist "$blocklist_json" \
      '[.[] | select(.index != null) | select((($blocklist | length) == 0) or (($blocklist | index(.description)) == null)) | {name, description, state}]'
}

# print current sinks once at startup
print_sinks

# then subscribe to PulseAudio events and re-print on any sink change
pactl subscribe \
  | grep --line-buffered "on sink" \
  | while read -r _ _ _ _ _ _; do
      # whenever you see “on sink” (new, remove, change), re-list
      print_sinks
    done
