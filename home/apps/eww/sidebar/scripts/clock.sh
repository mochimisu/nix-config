#!/run/current-system/sw/bin/bash
set -euo pipefail

print_clock() {
  read -r hour minute ampm date <<<"$(date '+%I %M %p %m/%d')"
  ampm=${ampm,,}
  printf '{"hour":"%s","minute":"%s","ampm":"%s","date":"%s"}\n' "$hour" "$minute" "$ampm" "$date"
}

print_clock

while sleep 1; do
  print_clock
done
