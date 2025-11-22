#!/run/current-system/sw/bin/bash
set -euo pipefail

battery_path="/org/freedesktop/UPower/devices/battery_BAT0"

print_status() {
  upower -i "$battery_path" | awk '
/state/ { state = $2 }
/percentage/ {
  gsub(/%/, "", $2)
  percent = $2
}
/time to empty/ { time = $4 " " $5 }
/energy-rate/ { rate = $2 }
/icon-name/ { icon = $2 }
END {
  printf("{\"state\": \"%s\", \"percent\": %s, \"time\": \"%s\", \"rate\": \"%s\", \"icon-name\": \"%s\"}\n", state, percent, time, rate, icon)
}'
}

print_status

upower --monitor-detail | while IFS= read -r line; do
  case $line in
    *"$battery_path"*) print_status ;;
  esac
done
