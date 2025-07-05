#!/run/current-system/sw/bin/bash

upower -i /org/freedesktop/UPower/devices/battery_BAT0 | awk '
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

