{pkgs, ...}: let
  blackvueAddress = "192.168.1.208";
  blackvueDestination = "/earth/blackvue";
  blackvueStatusFile = "/earth/blackvue/.blackvue-status.json";

  blackvuesyncScript = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/acolomba/blackvuesync/main/blackvuesync.py";
    hash = "sha256-KmpGWXYkLhI/tLeUmNb+/LiNUFYdK7cwd2WJ9CQG0Zc=";
  };

  blackvuesync = pkgs.writeShellApplication {
    name = "blackvuesync";
    runtimeInputs = [pkgs.python3];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${blackvuesyncScript} "$@"
    '';
  };

  blackvuesyncWithStatus = pkgs.writeShellApplication {
    name = "blackvuesync-with-status";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnused
      pkgs.python3
    ];
    text = ''
      set -euo pipefail

      address='${blackvueAddress}'
      destination='${blackvueDestination}'
      status_file='${blackvueStatusFile}'
      keep_days=90

      last_attempt="$(${pkgs.coreutils}/bin/date --iso-8601=seconds)"
      last_success=""
      connected=false
      sync_status="unknown"
      pending_count=-1
      last_error=""
      latest_synced_footage=""
      sync_speed_mib_s=""
      probe_error="$(${pkgs.coreutils}/bin/mktemp)"
      sync_log=""

      # shellcheck disable=SC2329
      cleanup() {
        ${pkgs.coreutils}/bin/rm -f "$probe_error"
        if [ -n "$sync_log" ]; then
          ${pkgs.coreutils}/bin/rm -f "$sync_log"
        fi
      }

      trap cleanup EXIT

      if [ -f "$status_file" ]; then
        last_success="$(${pkgs.python3}/bin/python3 - "$status_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
else:
    print(data.get("last_success") or "")
PY
)"
        pending_count="$(${pkgs.python3}/bin/python3 - "$status_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("-1")
else:
    value = data.get("pending_count")
    print("-1" if value is None else value)
PY
)"
        latest_synced_footage="$(${pkgs.python3}/bin/python3 - "$status_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
else:
    print(data.get("latest_synced_footage") or "")
PY
)"
        sync_speed_mib_s="$(${pkgs.python3}/bin/python3 - "$status_file" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print("")
else:
    value = data.get("sync_speed_mib_s")
    print("" if value is None else value)
PY
)"
      fi

      write_status() {
        STATUS_FILE="$status_file" \
        LAST_ATTEMPT="$last_attempt" \
        LAST_SUCCESS="$last_success" \
        CONNECTED="$connected" \
        SYNC_STATUS="$sync_status" \
        PENDING_COUNT="$pending_count" \
        LAST_ERROR="$last_error" \
        LATEST_SYNCED_FOOTAGE="$latest_synced_footage" \
        SYNC_SPEED_MIB_S="$sync_speed_mib_s" \
        ${pkgs.python3}/bin/python3 - <<'PY'
import json
import os
import tempfile

status_file = os.environ["STATUS_FILE"]
directory = os.path.dirname(status_file)
os.makedirs(directory, exist_ok=True)

payload = {
    "connected": os.environ["CONNECTED"].lower() == "true",
    "sync_status": os.environ["SYNC_STATUS"],
    "last_attempt": os.environ["LAST_ATTEMPT"],
    "last_success": os.environ["LAST_SUCCESS"] or None,
    "pending_count": int(os.environ["PENDING_COUNT"]),
    "last_error": os.environ["LAST_ERROR"] or None,
    "latest_synced_footage": os.environ["LATEST_SYNCED_FOOTAGE"] or None,
    "sync_speed_mib_s": (
        None if os.environ["SYNC_SPEED_MIB_S"] == "" else float(os.environ["SYNC_SPEED_MIB_S"])
    ),
}

fd, tmp_path = tempfile.mkstemp(dir=directory, prefix=".blackvue-status.", text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(payload, f, sort_keys=True)
        f.write("\n")
    os.chmod(tmp_path, 0o644)
    os.replace(tmp_path, status_file)
finally:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
PY
      }

      normalize_offline_error() {
        local raw
        raw="$1"
        case "$raw" in
          *"Could not connect to server"*|*"Connection timed out"*|*"Failed to connect to "*|*"timed out"*|*"No route to host"*|*"Network is unreachable"*|*"Host is unreachable"*|*"Connection refused"*)
            printf '%s\n' "offline"
            ;;
          *)
            printf '%s\n' "$raw"
            ;;
        esac
      }

      probe_pending_count() {
        local vod_file
        vod_file="$(${pkgs.coreutils}/bin/mktemp)"
        trap '${pkgs.coreutils}/bin/rm -f "$vod_file"' RETURN

        ${pkgs.curl}/bin/curl -fsS --max-time 10 "http://$address/blackvue_vod.cgi" > "$vod_file"

        ${pkgs.python3}/bin/python3 - "$vod_file" "$destination" "$keep_days" <<'PY'
import datetime as dt
import os
import re
import sys

vod_path, destination, keep_days = sys.argv[1], sys.argv[2], int(sys.argv[3])
cutoff_date = dt.date.today() - dt.timedelta(days=keep_days)
recording_re = re.compile(
    r"^n:/Record/(?P<filename>(?P<base>\d{8}_\d{6})_[A-Z][A-Z][LS]?\.mp4),s:\d+$"
)

pending = 0
with open(vod_path, "r", encoding="utf-8") as f:
    for raw_line in f:
        line = raw_line.strip()
        match = recording_re.match(line)
        if match is None:
          continue

        base = match.group("base")
        file_date = dt.date(
            int(base[0:4]),
            int(base[4:6]),
            int(base[6:8]),
        )
        if file_date < cutoff_date:
            continue

        filename = match.group("filename")
        group = f"{base[0:4]}-{base[4:6]}-{base[6:8]}"
        local_path = os.path.join(destination, group, filename)
        if not os.path.exists(local_path):
            pending += 1

print(pending)
PY
      }

      status_metrics() {
        ${pkgs.python3}/bin/python3 - "$destination" <<'PY'
import os
import re
import sys

destination = sys.argv[1]
recording_re = re.compile(r"^\d{8}_\d{6}_[A-Z][A-Z][LS]?\.mp4$")
latest = None
total_size = 0

for root, _, files in os.walk(destination):
    for filename in files:
        if not recording_re.match(filename):
            continue
        path = os.path.join(root, filename)
        try:
            size = os.path.getsize(path)
        except OSError:
            continue

        total_size += size
        if latest is None or filename > latest:
            latest = filename

print(latest or "")
print(total_size)
PY
      }

      metrics_bootstrap="$(status_metrics)"
      latest_bootstrap="$(printf '%s\n' "$metrics_bootstrap" | ${pkgs.gnused}/bin/sed -n '1p')"
      if [ -z "$latest_synced_footage" ] && [ -n "$latest_bootstrap" ]; then
        latest_synced_footage="$latest_bootstrap"
      fi

      if pending_count="$(probe_pending_count 2>"$probe_error")"; then
        connected=true
        if [ "$pending_count" -eq 0 ]; then
          sync_status="up_to_date"
        else
          sync_status="pending"
        fi
      else
        connected=false
        sync_status="offline"
        last_error="$(${pkgs.coreutils}/bin/tr '\n' ' ' < "$probe_error" | ${pkgs.gnused}/bin/sed 's/  */ /g; s/ $//')"
        if [ -z "$last_error" ]; then
          last_error="failed to reach BlackVue dashcam"
        fi
        last_error="$(normalize_offline_error "$last_error")"
        write_status
        echo "$last_error" >&2
        exit 0
      fi

      write_status
      sync_status="syncing"
      write_status

      sync_log="$(${pkgs.coreutils}/bin/mktemp)"
      metrics_before="$(status_metrics)"
      latest_before="$(printf '%s\n' "$metrics_before" | ${pkgs.gnused}/bin/sed -n '1p')"
      size_before="$(printf '%s\n' "$metrics_before" | ${pkgs.gnused}/bin/sed -n '2p')"
      sync_started_epoch="$(${pkgs.coreutils}/bin/date +%s)"

      if ${blackvuesync}/bin/blackvuesync "$address" \
        --destination "$destination" \
        --grouping daily \
        --keep 90d \
        --max-used-disk 90 \
        --retry-failed-after 1h 2>&1 | tee "$sync_log"; then
        last_success="$(${pkgs.coreutils}/bin/date --iso-8601=seconds)"
        last_error=""
        sync_finished_epoch="$(${pkgs.coreutils}/bin/date +%s)"
        metrics_after="$(status_metrics)"
        latest_after="$(printf '%s\n' "$metrics_after" | ${pkgs.gnused}/bin/sed -n '1p')"
        size_after="$(printf '%s\n' "$metrics_after" | ${pkgs.gnused}/bin/sed -n '2p')"

        if [ -n "$latest_after" ]; then
          latest_synced_footage="$latest_after"
        elif [ -n "$latest_before" ]; then
          latest_synced_footage="$latest_before"
        fi

        sync_speed_mib_s="$(${pkgs.python3}/bin/python3 - "$size_before" "$size_after" "$sync_started_epoch" "$sync_finished_epoch" <<'PY'
import sys

size_before = int(sys.argv[1] or "0")
size_after = int(sys.argv[2] or "0")
started = int(sys.argv[3] or "0")
finished = int(sys.argv[4] or "0")
elapsed = max(finished - started, 1)
delta = max(size_after - size_before, 0)
speed = delta / elapsed / (1024 * 1024)
print(f"{speed:.2f}")
PY
)"

        if pending_after="$(probe_pending_count 2>"$probe_error")"; then
          connected=true
          pending_count="$pending_after"
          if [ "$pending_count" -eq 0 ]; then
            sync_status="up_to_date"
          else
            sync_status="pending"
          fi
        else
          connected=false
          sync_status="offline"
          last_error="$(${pkgs.coreutils}/bin/tr '\n' ' ' < "$probe_error" | ${pkgs.gnused}/bin/sed 's/  */ /g; s/ $//')"
          if [ -z "$last_error" ]; then
            last_error="sync completed but the dashcam was unreachable for the post-sync probe"
          fi
          last_error="$(normalize_offline_error "$last_error")"
        fi

        write_status
        exit 0
      fi

      rc=$?
      connected=true
      last_error="$(${pkgs.python3}/bin/python3 - "$sync_log" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
    lines = [line.strip() for line in f if line.strip()]

summary = " | ".join(lines[-10:])
print(summary[:4000])
PY
)"
      if normalized_error="$(normalize_offline_error "$last_error")" && [ "$normalized_error" = "offline" ]; then
        connected=false
        sync_status="offline"
        last_error="offline"
      else
        sync_status="error"
      fi
      write_status
      exit "$rc"
    '';
  };
in {
  environment.systemPackages = [
    blackvuesync
    blackvuesyncWithStatus
  ];

  systemd.tmpfiles.rules = [
    "d /earth/blackvue 0775 brandon users - -"
  ];

  systemd.services.blackvuesync = {
    description = "Sync BlackVue recordings from dashcam";
    restartIfChanged = false;
    stopIfChanged = false;
    unitConfig.X-OnlyManualStart = true;
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = "${pkgs.systemd}/bin/systemctl start --no-block blackvuesync-worker.service";
    };
  };

  systemd.services.blackvuesync-worker = {
    description = "Run BlackVue recordings sync from dashcam";
    restartIfChanged = false;
    stopIfChanged = false;
    unitConfig.X-OnlyManualStart = true;
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      WorkingDirectory = blackvueDestination;
      Nice = 10;
      ExecStart = "${blackvuesyncWithStatus}/bin/blackvuesync-with-status";
    };
  };

  systemd.timers.blackvuesync = {
    enable = true;
    wantedBy = ["timers.target"];
    timerConfig = {
      OnActiveSec = "15min";
      OnUnitActiveSec = "15min";
      Unit = "blackvuesync.service";
    };
  };

  services.home-assistant.config = {
    command_line = [
      {
        sensor = {
          name = "BlackVue Sync Status";
          unique_id = "gaia_blackvue_sync_status";
          command = "if [ -f ${blackvueStatusFile} ]; then ${pkgs.coreutils}/bin/cat ${blackvueStatusFile}; else printf '%s\\n' '{\"connected\": false, \"sync_status\": \"unknown\", \"last_attempt\": null, \"last_success\": null, \"last_error\": null, \"pending_count\": -1, \"latest_synced_footage\": null, \"sync_speed_mib_s\": null}'; fi";
          value_template = "{{ value_json.sync_status if value_json is defined else 'unknown' }}";
          json_attributes = [
            "connected"
            "last_attempt"
            "last_success"
            "last_error"
            "pending_count"
            "latest_synced_footage"
            "sync_speed_mib_s"
          ];
          scan_interval = 60;
        };
      }
    ];
  };
}
