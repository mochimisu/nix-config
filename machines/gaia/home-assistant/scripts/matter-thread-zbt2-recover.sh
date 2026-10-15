set -euo pipefail

force=0
if [ "${1:-}" = "--force" ]; then
  force=1
fi
from_watchdog="${MATTER_THREAD_RECOVER_FROM_WATCHDOG:-0}"
timer_paused=0

restore_watchdog_timer() {
  if [ "$timer_paused" -eq 1 ]; then
    systemctl start matter-thread-watchdog.timer || true
  fi
}
trap restore_watchdog_timer EXIT

m3_route_pattern='^fd[0-9a-f:]+::/64 via fe80::[0-9a-f:]+ dev enp5s0 proto ra'
if ! ip -6 route show | grep -E "$m3_route_pattern" >/dev/null; then
  echo "matter-thread-zbt2-recover: no alternate Thread ULA route via enp5s0; M3 fallback is not visible" >&2
  echo "matter-thread-zbt2-recover: refusing to bounce ZBT-2 without --force" >&2
  if [ "$force" -ne 1 ]; then
    exit 1
  fi
fi

echo "matter-thread-zbt2-recover: alternate Thread routes before recovery:"
ip -6 route show | grep -E "$m3_route_pattern" || true

echo "matter-thread-zbt2-recover: pausing watchdog and restarting only ZBT-2 OTBR"
if [ "$from_watchdog" = "1" ]; then
  systemctl stop matter-thread-watchdog.timer || true
else
  systemctl stop matter-thread-watchdog.timer matter-thread-watchdog.service || true
fi
timer_paused=1
systemctl restart podman-otbr.service

echo "matter-thread-zbt2-recover: re-seeding/checking dataset and preferring ZBT-2 as router"
systemctl start otbr-ensure-dataset.service
systemctl start otbr-prefer-zbt2-router.service

echo "matter-thread-zbt2-recover: restarting local Matter listeners, not Matter.js server"
systemctl try-restart matter-keepalive.service || true
systemctl start matter-apply-node-labels.service matter-apply-ha-names.service || true
systemctl start matter-thread-watchdog.timer

echo "matter-thread-zbt2-recover: route state after recovery:"
ip -6 route show | grep -E '(^fd[0-9a-f:]+::/64 .* (dev enp5s0|dev wpan0))' || true
systemctl --no-pager --full status podman-otbr.service | sed -n '1,18p'
