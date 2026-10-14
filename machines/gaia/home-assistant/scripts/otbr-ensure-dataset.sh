set -u

if [ -z "${MATTER_THREAD_DATASET_HEX:-}" ]; then
  echo "otbr-ensure-dataset: MATTER_THREAD_DATASET_HEX not set; skipping"
  exit 0
fi

is_attached_state() {
  case "$1" in
    child|router|leader) return 0 ;;
    *) return 1 ;;
  esac
}

podman_otctl() {
  local container
  container="$(
    podman ps \
      --filter ancestor=@otbrImage@ \
      --format '{{.Names}}' \
      | head -n1
  )"
  if [ -z "$container" ]; then
    return 1
  fi
  podman exec "$container" ot-ctl "$@" 2>/dev/null
}

with_retry() {
  local attempts max_attempts
  max_attempts=${OTBR_CTL_MAX_ATTEMPTS:-30}
  attempts=0
  while [ "$attempts" -lt "$max_attempts" ]; do
    if "$@"; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  return 1
}

if ! with_retry podman_otctl state >/dev/null; then
  echo "otbr-ensure-dataset: ot-ctl not reachable after retries; will retry on next timer run"
  exit 0
fi

state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
if is_attached_state "$state"; then
  # Do not rewrite dataset while attached; it can force re-attach churn.
  echo "otbr-ensure-dataset: state=$state, skipping dataset reseed"
  echo "otbr-ensure-dataset: final_state=$state"
  exit 0
fi

desired="$(printf '%s' "$MATTER_THREAD_DATASET_HEX" | tr 'A-F' 'a-f')"
active="$(podman_otctl dataset active -x | grep -E '^[0-9a-fA-F]+$' | head -n1 | tr 'A-F' 'a-f' || true)"

if [ -z "$active" ] || [ "$active" != "$desired" ]; then
  echo "otbr-ensure-dataset: setting active dataset"
  if ! with_retry podman_otctl dataset set active "$MATTER_THREAD_DATASET_HEX" >/dev/null; then
    echo "otbr-ensure-dataset: unable to set dataset right now; will retry on next timer run"
    exit 0
  fi
fi

state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
if ! is_attached_state "$state"; then
  echo "otbr-ensure-dataset: state=$state, starting Thread"
  with_retry podman_otctl ifconfig up >/dev/null || true
  with_retry podman_otctl thread start >/dev/null || true
fi

# Give OTBR time to attach after startup/restart so boot-time checks
# don't report transient detached states.
attach_wait_sec="${OTBR_ATTACH_WAIT_SEC:-45}"
waited=0
final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
while ! is_attached_state "$final_state" && [ "$waited" -lt "$attach_wait_sec" ]; do
  sleep 1
  waited=$((waited + 1))
  final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
done

echo "otbr-ensure-dataset: final_state=$final_state"
