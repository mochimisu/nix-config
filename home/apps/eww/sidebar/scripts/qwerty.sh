#!/run/current-system/sw/bin/bash
set -euo pipefail

get_opt() {
  hyprctl getoption "$1" 2>/dev/null | awk 'NR==1 {
    if (match($0, /[=:] /)) { print substr($0, RSTART+RLENGTH); exit }
    print $2
  }'
}

trim() {
  printf '%s' "$1" | tr -d '[:space:]'
}

normalize_variant() {
  case "$1" in
    ""|"null"|"none")
      printf ","
      ;;
    *)
      printf "%s" "$1"
      ;;
  esac
}

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "other"
  exit 0
fi

current_layout="$(trim "$(get_opt input:kb_layout)")"
current_variant="$(normalize_variant "$(trim "$(get_opt input:kb_variant)")")"

is_qwerty=0
case "$current_layout" in
  us|us,us)
    case "$current_variant" in
      ""|",") is_qwerty=1 ;;
    esac
    ;;
  *)
    ;;
esac

if [ "$is_qwerty" -eq 1 ]; then
  echo "qwerty"
else
  echo "other"
fi
