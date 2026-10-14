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
          ot_state="$(podman exec "$otbr_container" ot-ctl state 2>/dev/null | head -n1 | tr -d '\r' || true)"
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
