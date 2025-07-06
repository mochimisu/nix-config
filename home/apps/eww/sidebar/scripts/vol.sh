#!/run/current-system/sw/bin/bash
set -euo pipefail

print_default_sink_volume() {
  # 1. find the default sink’s name
  default_sink=$(pactl info | awk -F': ' '/^Default Sink:/ {print $2}')

  # 2. ask PulseAudio/PipeWire for that sink’s volume, return the first % value
  #    (all channels are normally identical; we only need one)
  pactl get-sink-volume "$default_sink" \
    | awk -F'/ *' '/Volume:/ {print $2 + 0; exit}'
}

print_default_sink_volume

# Any “change” event on *a* sink will trigger; we re-query the default sink each time.
pactl subscribe \
  | grep --line-buffered --regexp='Event .* on sink' \
  | while read -r _; do
      print_default_sink_volume
    done

