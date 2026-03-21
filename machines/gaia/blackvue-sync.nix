{pkgs, ...}: let
  blackvueAddress = "192.168.1.208";
  blackvueDestination = "/earth/blackvue";
  blackvueStatusFile = "/earth/home-assistant/blackvue-status.json";

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
      fi

      write_status() {
        STATUS_FILE="$status_file" \
        LAST_ATTEMPT="$last_attempt" \
        LAST_SUCCESS="$last_success" \
        CONNECTED="$connected" \
        SYNC_STATUS="$sync_status" \
        PENDING_COUNT="$pending_count" \
        LAST_ERROR="$last_error" \
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

      if pending_count="$(probe_pending_count 2>&1)"; then
        connected=true
        if [ "$pending_count" -eq 0 ]; then
          sync_status="up_to_date"
        else
          sync_status="pending"
        fi
      else
        connected=false
        sync_status="disconnected"
        pending_count=-1
        last_error="$pending_count"
        write_status
        echo "$last_error" >&2
        exit 0
      fi

      write_status
      sync_status="syncing"
      write_status

      sync_log="$(${pkgs.coreutils}/bin/mktemp)"
      trap '${pkgs.coreutils}/bin/rm -f "$sync_log"' EXIT

      if ${blackvuesync}/bin/blackvuesync "$address" \
        --destination "$destination" \
        --grouping daily \
        --keep 90d \
        --max-used-disk 90 \
        --retry-failed-after 1h 2>&1 | tee "$sync_log"; then
        last_success="$(${pkgs.coreutils}/bin/date --iso-8601=seconds)"
        last_error=""

        if pending_after="$(probe_pending_count 2>&1)"; then
          connected=true
          pending_count="$pending_after"
          if [ "$pending_count" -eq 0 ]; then
            sync_status="up_to_date"
          else
            sync_status="pending"
          fi
        else
          connected=false
          pending_count=-1
          sync_status="disconnected"
          last_error="$pending_after"
        fi

        write_status
        exit 0
      fi

      rc=$?
      connected=true
      sync_status="error"
      last_error="$(${pkgs.python3}/bin/python3 - "$sync_log" <<'PY'
import sys

with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
    lines = [line.strip() for line in f if line.strip()]

summary = " | ".join(lines[-10:])
print(summary[:4000])
PY
)"
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
      Unit = "blackvuesync.service";
    };
  };

  services.home-assistant.config = {
    command_line = [
      {
        sensor = {
          name = "BlackVue Sync Status";
          unique_id = "gaia_blackvue_sync_status";
          command = "if [ -f ${blackvueStatusFile} ]; then cat ${blackvueStatusFile}; else printf '%s\\n' '{\"connected\": false, \"sync_status\": \"unknown\", \"last_attempt\": null, \"last_success\": null, \"last_error\": null, \"pending_count\": -1}'; fi";
          value_template = "{{ value_json.sync_status if value_json is defined else 'unknown' }}";
          json_attributes = [
            "connected"
            "last_attempt"
            "last_success"
            "last_error"
            "pending_count"
          ];
          scan_interval = 60;
        };
      }
    ];
  };
}
