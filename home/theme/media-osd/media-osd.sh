# Short-lived client of the existing Mako server; no background service.
icons="@icons@"
kind=${1:?volume or brightness}; action=${2:-show}
case "$kind:$action" in
  volume:up|volume:down|volume:mute|volume:show|brightness:up|brightness:down|brightness:show) ;;
  *) echo 'Unsupported media action' >&2; exit 2 ;;
esac
exec 9>"${XDG_RUNTIME_DIR:?}/sekai-media-osd.lock"
flock -w 2 9 || exit 0
notify() {
  notify-send --app-name='Media controls' --category="sekai.$kind" --urgency=normal \
    --expire-time=1600 --hint=boolean:transient:true \
    --hint="string:x-canonical-private-synchronous:sekai-$kind" "$@"
}
unavailable() {
  notify --icon="$icons/dialog-information.svg" "$1" "$2" || true
  exit 1
}
if [[ "$kind" == volume ]]; then
  case "$action" in
    up) wpctl set-volume --limit 1.5 @DEFAULT_SINK@ 5%+ || unavailable 'Audio unavailable' 'No usable output device.' ;;
    down) wpctl set-volume @DEFAULT_SINK@ 5%- || unavailable 'Audio unavailable' 'No usable output device.' ;;
    mute) wpctl set-mute @DEFAULT_SINK@ toggle || unavailable 'Audio unavailable' 'No usable output device.' ;;
  esac
  state=$(wpctl get-volume @DEFAULT_SINK@) || unavailable 'Audio unavailable' 'No usable output device.'
  value=$(awk '{printf "%.0f", $2 * 100}' <<< "$state")
  [[ "$value" =~ ^[0-9]+$ ]] || exit 1
  icon=audio-volume-high; label="Volume · $value%"; progress=$value
  if [[ "$state" == *MUTED* ]]; then icon=audio-volume-muted; label='Volume · muted'; progress=0; fi
else
  # Explicit backlight class avoids accidentally changing keyboard LEDs.
  maximum=$(brightnessctl --class=backlight max 2>/dev/null) || unavailable 'Brightness unavailable' 'No supported backlight device.'
  if [[ ! "$maximum" =~ ^[0-9]+$ ]] || (( maximum <= 0 )); then
    unavailable 'Brightness unavailable' 'No supported backlight device.'
  fi
  case "$action" in
    up) brightnessctl --class=backlight set +5% >/dev/null || unavailable 'Brightness unavailable' 'Could not change the backlight.' ;;
    down) brightnessctl --class=backlight set 5%- >/dev/null || unavailable 'Brightness unavailable' 'Could not change the backlight.' ;;
  esac
  current=$(brightnessctl --class=backlight get) || unavailable 'Brightness unavailable' 'Could not read the backlight.'
  [[ "$current" =~ ^[0-9]+$ ]] || exit 1
  value=$(( (current * 100 + maximum / 2) / maximum ))
  icon=display-brightness; label="Brightness · $value%"; progress=$value
fi
(( progress > 100 )) && progress=100
notify --icon="$icons/$icon.svg" --hint="int:value:$progress" "$label"
