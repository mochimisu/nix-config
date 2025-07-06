#!/usr/bin/env bash
WIN="$1"

# If we have a EWW_CONFIG environment variable, use it.
if [ -z "$EWW_CONFIG" ]; then
  EWW_CONFIG="$HOME/.config/eww"
fi

if eww --config $EWW_CONFIG active-windows | grep -q "^$WIN:"; then
  eww --config "$EWW_CONFIG" close "$WIN"
else
  eww --config "$EWW_CONFIG" open "$@"
fi
