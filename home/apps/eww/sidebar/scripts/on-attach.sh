#!/run/current-system/sw/bin/bash

# Wait for Hyprland to be ready
while ! hyprctl monitors > /dev/null 2>&1; do
  sleep 0.1
done

# Open the bar for this monitor
eww --config ~/.config/eww/sidebar open bar_''${1}
