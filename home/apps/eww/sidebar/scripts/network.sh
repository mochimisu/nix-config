#!/run/current-system/sw/bin/bash

# try Wi-Fi first
ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
if [[ -n "$ssid" ]]; then
  echo "{\"ssid\":\"$ssid\",\"eth\":null}"
  exit
fi

# then Ethernet
eth=$(nmcli -t -f DEVICE,TYPE,STATE dev status \
      | awk -F: '$2=="ethernet" && $3=="connected"{print $1}')
if [[ -n "$eth" ]]; then
  echo "{\"ssid\":null,\"eth\":\"$eth\"}"
  exit
fi

# neither
echo "{\"ssid\":null,\"eth\":null}"
