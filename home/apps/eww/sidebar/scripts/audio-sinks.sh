#!/run/current-system/sw/bin/bash

# print current sinks once at startup
pactl --format=json list sinks \
  | jq -c --unbuffered '[.[] | select(.index != null) | {
      name,
      description,
      state
    }]'

# then subscribe to PulseAudio events and re-print on any sink change
pactl subscribe \
  | grep --line-buffered "on sink" \
  | while read -r _ _ _ _ event _; do
      # whenever you see “on sink” (new, remove, change), re-list
      pactl --format=json list sinks \
        | jq -c --unbuffered '[.[] | select(.index != null) | {
            name,
            description,
            state
          }]'
    done

