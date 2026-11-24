        set -u

        state_dir="/var/lib/matter-thread-watchdog"
        last_restart_file="$state_dir/last-restart-epoch"
        bad_checks_file="$state_dir/consecutive-bad-checks"
        mkdir -p "$state_dir"

        offline_threshold="${THREAD_WATCHDOG_OFFLINE_THRESHOLD:-5}"
        recovery_after_checks="${THREAD_WATCHDOG_RECOVERY_AFTER_CHECKS:-10}"
        hard_recovery_after_checks="${THREAD_WATCHDOG_HARD_RECOVERY_AFTER_CHECKS:-30}"
        cooldown_sec="${THREAD_WATCHDOG_RESTART_COOLDOWN_SEC:-3600}"
        settle_sec="${THREAD_WATCHDOG_OTBR_SETTLE_SEC:-900}"
        alert_email="${MATTER_ALERT_EMAIL:-home@bwang.dev}"
        alert_from="${MATTER_ALERT_FROM:-home@bwang.dev}"
        ot_state=""
        otbr_container=""

        restart_matter_clients() {
          systemctl try-restart \
            matter-keepalive.service || true
        }

        recover_zbt2() {
          force_arg="${1:-}"
          if [ -n "$force_arg" ]; then
            MATTER_THREAD_RECOVER_FROM_WATCHDOG=1 matter-thread-zbt2-recover "$force_arg"
          else
            MATTER_THREAD_RECOVER_FROM_WATCHDOG=1 matter-thread-zbt2-recover
          fi
        }

# Optional early soft recovery for a confirmed Thread RCP hang.
# Uses only current-boot/current-OTBR journal provenance and the healthy
# snapshot's shared OMR prefix. All marker state is volatile and root-owned.
thread_fast_common_routes() {
  ip -j -6 route show 2>/dev/null | jq -er '
    [ .[] | select(.dev == "wpan0" and (.dst // "" | test("^fd[0-9a-f:]+/64$"))) | .dst ] as $local
    | [ .[] | select(.dev == "enp5s0" and .protocol == "ra"
        and (.gateway // "" | startswith("fe80:"))
        and (.dst as $dst | $local | index($dst))) | .dst ] | unique
    | if length == 1 then .[0] else empty end'
}

thread_fast_alternate_exists() {
  ip -j -6 route show 2>/dev/null | jq -e --arg prefix "$1" '
    any(.[]; .dst == $prefix and .dev == "enp5s0" and .protocol == "ra"
      and (.gateway // "" | startswith("fe80:")) and (.expires // 0) >= 60)' >/dev/null
}

thread_fast_alternate_live() {
  local prefix="$1" gateway gateways
  gateways="$(ip -j -6 route show 2>/dev/null | jq -er --arg prefix "$prefix" '
    [ .[] | select(.dst == $prefix and .dev == "enp5s0" and .protocol == "ra"
      and (.gateway // "" | startswith("fe80:")) and (.expires // 0) >= 60)
      | .gateway ] | unique | .[:3][]')" || return 1
  while IFS= read -r gateway; do
    [[ "$gateway" =~ ^fe80:[0-9a-f:]+$ ]] || continue
    timeout 2s ping -6 -n -c 1 -W 1 -I enp5s0 "$gateway" >/dev/null 2>&1 && return 0
  done <<<"$gateways"
  return 1
}

thread_fast_ctl_response() {
  # Any successful control reply, including detached/disabled, excludes a hard hang.
  local response
  response="$(timeout --kill-after=1s 3s podman exec "$otbr_container" ot-ctl state 2>/dev/null)" || return 1
  grep -qx 'Done' <<<"${response//$'\r'/}"
}

thread_fast_recover() (
  local run_dir="${RUNTIME_DIRECTORY:-/run/matter-thread-watchdog-fast}"
  local prefix event now invocation token previous last age
  [ -d "$run_dir" ] || return 1
  exec 9>"$run_dir/gate.lock"
  flock -n 9 || return 1

  # Prime a same-prefix alternate-route witness while local Thread is healthy;
  # wpan0 typically vanishes after an RCP abort. Avoid redundant state writes.
  case "$ot_state" in
    child|router|leader)
      if ! prefix="$(thread_fast_common_routes)"; then
        # A healthy controller with no unambiguous shared prefix invalidates
        # the old witness; never reuse a prefix after a topology change.
        [ ! -e "$run_dir/verified-omr" ] || rm -f "$run_dir/verified-omr"
        return 1
      fi
      previous="$(cat "$run_dir/verified-omr" 2>/dev/null || true)"
      [ "$prefix" = "$previous" ] || printf '%s\n' "$prefix" >"$run_dir/verified-omr"
      return 1 ;;
    "") ;;
    *) return 1 ;;
  esac
  [ -n "$otbr_container" ] || return 1
  [ -n "$otbr_age_sec" ] && [ "$otbr_age_sec" -ge "$settle_sec" ] || return 1
  prefix="$(cat "$run_dir/verified-omr" 2>/dev/null)" || return 1
  [[ "$prefix" =~ ^fd[0-9a-f:]+/64$ ]] || return 1
  thread_fast_alternate_exists "$prefix" || return 1

  invocation="$(systemctl show -P InvocationID podman-otbr.service 2>/dev/null)" || return 1
  [[ "$invocation" =~ ^[0-9a-f]{32}$ && "$invocation" != 00000000000000000000000000000000 ]] || return 1
  event="$(journalctl -b _SYSTEMD_INVOCATION_ID="$invocation" CONTAINER_NAME="$otbr_container" SYSLOG_IDENTIFIER=otbr \
      --grep='HandleRcpTimeout.*RadioSpinelNoResponse' --since '135 seconds ago' -n 1 --no-pager -o json 2>/dev/null \
    | jq -er '.__MONOTONIC_TIMESTAMP | tonumber | floor')" || return 1
  now="$(awk '{printf "%.0f", $1*1000000}' /proc/uptime)" || return 1
  [[ "$event" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]] || return 1
  age=$((now - event))
  [ "$age" -ge 0 ] && [ "$age" -le 135000000 ] && [ "$event" -ge "$active_usec" ] || return 1

  token="$invocation:$event"
  if [ -r "$run_dir/last-attempt" ]; then
    read -r previous last <"$run_dir/last-attempt" || true
  fi
  [ "$token" != "${previous:-}" ] || return 1
  [[ "${last:-}" =~ ^[0-9]+$ ]] || last=0
  [ "$last" -eq 0 ] || [ "$((now - last))" -ge 900000000 ] || return 1

  # Two bounded control failures inside one timer tick. A responsive REST
  # endpoint also vetoes recovery (any HTTP reply means the server is alive).
  thread_fast_ctl_response && return 1
  sleep 2
  thread_fast_ctl_response && return 1
  if curl --silent --noproxy "*" --max-time 2 --output /dev/null http://127.0.0.1:8081/node; then return 1; fi
  thread_fast_alternate_live "$prefix" || return 1
  [ "$(systemctl show -P InvocationID podman-otbr.service 2>/dev/null)" = "$invocation" ] || return 1

  printf '%s %s\n' "$token" "$now" >"$run_dir/last-attempt" || return 1
  echo "matter-thread-watchdog: early targeted ZBT-2 recovery: fresh RCP hang, two failed control probes, REST down, alternate OMR route present"
  if recover_zbt2; then
    echo "$now_epoch" >"$last_restart_file"
    rm -f "$bad_checks_file"
    return 0
  fi
  echo "matter-thread-watchdog: early targeted recovery did not complete; leaving existing recovery thresholds"
  return 0
)

        find_otbr_container() {
          podman ps \
            --filter ancestor=@otbrImage@ \
            --format '{{.Names}}' \
            | head -n1
        }

        bad_reason=""
        otbr_container="$(find_otbr_container || true)"
        if [ -z "$otbr_container" ]; then
          bad_reason="otbr container missing"
        fi

        if [ -n "$otbr_container" ]; then
          ot_state="$(timeout --kill-after=1s 5s podman exec "$otbr_container" ot-ctl state 2>/dev/null | head -n1 | tr -d '\r' || true)"
        fi
        if [ -z "$ot_state" ]; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; ot-ctl unreachable"
          else
            bad_reason="ot-ctl unreachable"
          fi
        elif [ "$ot_state" != "child" ] && [ "$ot_state" != "router" ] && [ "$ot_state" != "leader" ]; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; ot-state=$ot_state"
          else
            bad_reason="ot-state=$ot_state"
          fi
        fi

        # Catch known RCP transport failures even when the service still looks active.
        if journalctl -u podman-otbr.service --since "30 sec ago" --no-pager 2>/dev/null | grep -q "RadioSpinelNoResponse"; then
          if [ -n "$bad_reason" ]; then
            bad_reason="$bad_reason; rcp-timeout"
          else
            bad_reason="rcp-timeout"
          fi
        fi

        now_epoch="$(date +%s)"
        last_restart=0
        if [ -f "$last_restart_file" ]; then
          last_restart="$(cat "$last_restart_file" 2>/dev/null || echo 0)"
        fi
        elapsed="$((now_epoch - last_restart))"
        otbr_age_sec=""
        active_usec="$(systemctl show -P ActiveEnterTimestampMonotonic podman-otbr.service 2>/dev/null || echo 0)"
        uptime_usec="$(awk '{ printf "%d", $1 * 1000000 }' /proc/uptime 2>/dev/null || echo 0)"
        if [ -n "$active_usec" ] && [ "$active_usec" -gt 0 ] && [ "$uptime_usec" -gt "$active_usec" ]; then
          otbr_age_sec="$(( (uptime_usec - active_usec) / 1000000 ))"
        fi
        if thread_fast_recover; then
          exit 0
        fi

        offline_thread_nodes=0
        if command -v matter-health >/dev/null 2>&1; then
          offline_thread_nodes="$(
            matter-health 2>/dev/null \
              | awk -F '\t' '
                  NR==1 { next }
                  $2=="False" && $5 ~ /(Inovelli|Meross|IKEA of Sweden|SmartWings|Aqara|Nanoleaf)/ { c++ }
                  END { print c+0 }
                '
          )"
          if [ "$offline_thread_nodes" -ge "$offline_threshold" ]; then
            if [ -n "$bad_reason" ]; then
              bad_reason="$bad_reason; offline_thread_nodes=$offline_thread_nodes"
            else
              echo "matter-thread-watchdog: Matter nodes degraded (offline_thread_nodes=$offline_thread_nodes) but OTBR state is $ot_state; not restarting Thread"
              rm -f "$bad_checks_file"
              exit 0
            fi
          fi
        fi

        if [ -z "$bad_reason" ]; then
          rm -f "$bad_checks_file"
          echo "matter-thread-watchdog: healthy"
          exit 0
        fi

        bad_checks=0
        if [ -f "$bad_checks_file" ]; then
          bad_checks="$(cat "$bad_checks_file" 2>/dev/null || echo 0)"
        fi
        bad_checks="$((bad_checks + 1))"
        echo "$bad_checks" > "$bad_checks_file"

        force_recover=0
        # Only bypass cooldown when RCP timeout is happening right now *and*
        # ot-ctl is currently unreachable for several checks in a row. This
        # avoids cycling the radio while OTBR/Matter are still recovering from
        # a recent restart and rebuilding operational addresses.
        if [ "$bad_checks" -ge "$recovery_after_checks" ] && printf '%s' "$bad_reason" | grep -q "rcp-timeout" && printf '%s' "$bad_reason" | grep -q "ot-ctl unreachable"; then
          force_recover=1
        fi

        # Two-stage recovery:
        # Initial bad checks -> observe only. Matter.js and OTBR can take a few
        # minutes to settle after a border-router restart or OMR prefix change.
        # Recovery check -> OTBR restart only.
        # Later checks -> hard recovery (USB cycle + OTBR restart), cooldown-gated.
        if [ "$bad_checks" -lt "$recovery_after_checks" ]; then
          echo "matter-thread-watchdog: bad state observed ($bad_reason), waiting for confirmation ($bad_checks/$recovery_after_checks)"
          exit 0
        fi

        if [ -n "$otbr_age_sec" ] && [ "$otbr_age_sec" -lt "$settle_sec" ]; then
          echo "matter-thread-watchdog: bad state observed ($bad_reason), but OTBR restarted ${otbr_age_sec}s ago; allowing settle window ${settle_sec}s"
          exit 0
        fi

        if [ "$bad_checks" -eq "$recovery_after_checks" ]; then
          echo "matter-thread-watchdog: targeted ZBT-2 recovery from bad state: $bad_reason"
          echo "$now_epoch" > "$last_restart_file"
          if ! recover_zbt2; then
            echo "matter-thread-watchdog: targeted ZBT-2 recovery refused without fallback route; forcing because bad state was confirmed"
            recover_zbt2 --force
          fi
          rm -f "$bad_checks_file"
          exit 0
        fi

        if [ "$bad_checks" -lt "$hard_recovery_after_checks" ] && [ "$force_recover" -ne 1 ]; then
          echo "matter-thread-watchdog: bad state persists ($bad_reason) but hard recovery waits for $hard_recovery_after_checks checks; currently $bad_checks"
          exit 0
        fi

        if [ "$elapsed" -lt "$cooldown_sec" ] && [ "$force_recover" -ne 1 ]; then
          echo "matter-thread-watchdog: bad state persists ($bad_reason) but hard-recovery cooldown active (${elapsed}s < ${cooldown_sec}s)"
          exit 0
        fi

        echo "$now_epoch" > "$last_restart_file"
        echo "matter-thread-watchdog: hard recovery from bad state: $bad_reason"
        thread_dev_by_id="/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_DCB4D9123AF0-if00"
        thread_dev_fallback=""
        for candidate in /dev/ttyACM*; do
          if [ -e "$candidate" ]; then
            thread_dev_fallback="$candidate"
            break
          fi
        done
        usb_reset_done=0
        tty_real=""
        if [ -e "$thread_dev_by_id" ]; then
          tty_real="$(readlink -f "$thread_dev_by_id" 2>/dev/null || true)"
        elif [ -n "$thread_dev_fallback" ]; then
          tty_real="$(readlink -f "$thread_dev_fallback" 2>/dev/null || true)"
        fi
        if [ -n "$tty_real" ]; then
          tty_name="$(basename "$tty_real" 2>/dev/null || true)"
          if [ -n "$tty_name" ] && [ -e "/sys/class/tty/$tty_name/device" ]; then
            usb_node="$(readlink -f "/sys/class/tty/$tty_name/device" 2>/dev/null || true)"
            while [ -n "$usb_node" ] && [ "$usb_node" != "/" ]; do
              if [ -w "$usb_node/authorized" ]; then
                # Only cycle the USB *device* node (e.g. .../3-4), never an
                # interface node (e.g. .../3-4:1.0). Cycling an interface can
                # leave cdc_acm unbound with no ttyACM device.
                usb_base="$(basename "$usb_node" 2>/dev/null || true)"
                if printf '%s' "$usb_base" | @gnugrep@/bin/grep -q ':'; then
                  usb_node="$(dirname "$usb_node")"
                  continue
                fi
                echo "matter-thread-watchdog: cycling USB device at $usb_node"
                echo 0 > "$usb_node/authorized" || true
                sleep 1
                echo 1 > "$usb_node/authorized" || true
                usb_reset_done=1
                break
              fi
              usb_node="$(dirname "$usb_node")"
            done
          fi
        fi
        if [ "$usb_reset_done" -ne 1 ]; then
          echo "matter-thread-watchdog: USB reset path not found; continuing with OTBR restart"
        fi
        recover_zbt2 --force
        rm -f "$bad_checks_file"

        if [ -n "$alert_email" ]; then
          subject="[gaia] Matter/Thread watchdog recovery triggered"
          body="Host: $(hostname)
Time: $(date -Iseconds)
Reason: $bad_reason
OfflineThreadNodes: $offline_thread_nodes
Action: hard recovery (cycled Thread USB when possible, restarted podman-otbr); started label timers."

          if command -v sendmail >/dev/null 2>&1; then
            {
              printf 'From: %s\n' "$alert_from"
              printf 'To: %s\n' "$alert_email"
              printf 'Subject: %s\n' "$subject"
              printf '\n%s\n' "$body"
            } | sendmail -t || true
          elif command -v mail >/dev/null 2>&1; then
            printf '%s\n' "$body" | mail -s "$subject" -r "$alert_from" "$alert_email" || true
          else
            echo "matter-thread-watchdog: alert email requested but no sendmail/mail binary found"
          fi
        fi
