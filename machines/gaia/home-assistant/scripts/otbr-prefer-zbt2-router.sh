set -u

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
  echo "otbr-prefer-zbt2-router: ot-ctl not reachable; will retry later"
  exit 0
fi

# These commands are best-effort across OTBR image versions. They are
# harmless when unsupported and useful when the CLI exposes them.
podman_otctl routereligible enable >/dev/null || true
podman_otctl routerupgradethreshold 32 >/dev/null || true
podman_otctl routerselectionjitter 1 >/dev/null || true

state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
if [ "$state" = "child" ]; then
  podman_otctl state router >/dev/null || true
fi

# Gaia has seen repeated TREL ack timeouts against the Aqara M3 even
# with excellent 15.4 RSSI. Prefer the direct Thread radio path when
# this OpenThread build supports toggling TREL from ot-ctl.
if [ "${OTBR_DISABLE_TREL:-1}" = "1" ]; then
  podman_otctl trel disable >/dev/null || true
fi

final_state="$(podman_otctl state | head -n1 | tr -d '\r' || true)"
echo "otbr-prefer-zbt2-router: state=$final_state"
