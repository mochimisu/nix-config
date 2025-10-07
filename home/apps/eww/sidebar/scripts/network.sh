#!/run/current-system/sw/bin/bash
set -euo pipefail

print_status() {
  local ssid
  ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2; exit}')
  if [[ -n "$ssid" ]]; then
    printf '{"ssid":"%s","eth":null}\n' "$ssid"
    return
  fi

  local eth
  eth=$(nmcli -t -f DEVICE,TYPE,STATE dev status | awk -F: '$2=="ethernet" && $3=="connected"{print $1; exit}')
  if [[ -n "$eth" ]]; then
    printf '{"ssid":null,"eth":"%s"}\n' "$eth"
    return
  fi

  printf '{"ssid":null,"eth":null}\n'
}

print_status

nmcli -t device monitor |
  while IFS= read -r _; do
    print_status
  done
