#!/run/current-system/sw/bin/bash
set -euo pipefail

pipe="/tmp/eww-cava.fifo"
config_file="/tmp/eww-cava.conf"

cleanup() {
  rm -f "$pipe" "$config_file"
  if [[ -n "${cava_pid:-}" ]]; then
    kill "$cava_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

[[ -p $pipe ]] && rm -f "$pipe"
mkfifo "$pipe"

cat >"$config_file" <<CFG
[general]
bars = 12
framerate = 24
[output]
method = raw
raw_target = $pipe
data_format = ascii
ascii_max_range = 7
[smoothing]
monstercat = true
waves = false
noise_reduction = 0.15
CFG

cava -p "$config_file" &
cava_pid=$!

bars=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")
prev=""
while IFS= read -r line; do
  line=${line//;/}
  out=""
  for ((i = 0; i < ${#line}; i++)); do
    digit=${line:i:1}
    out+="${bars[digit]:- }"
  done
  [[ $out == "$prev" ]] && continue
  printf '%s\n' "$out"
  prev="$out"
done <"$pipe"
