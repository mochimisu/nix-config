{ lib, pkgs, ... }:
let

ewwProcs = pkgs.writeShellScriptBin "eww-procs" ''
#!/usr/bin/env bash
# Emits: {"total":618,"running":2,"top1":"foo: 17%", ...}

normalize_top() {
  local label="$1"
  local cpu="$2"
  printf "%-15.15s: %s%%" "$label" "$cpu"
}

while true; do
  ps_output=$(ps -eo stat=,pcpu=,comm= --sort=-pcpu | awk '
    {
      stat = $1
      cpu = $2
      sub(/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "")
      printf "%s|%s|%s\n", stat, cpu, $0
    }')
  total=$(printf '%s\n' "$ps_output" | wc -l)
  running=$(printf '%s\n' "$ps_output" | awk -F'|' '{ if ($1 ~ /^R/) run++ } END { printf "%d", run + 0 }')

  top_json=""
  idx=1
  while IFS= read -r line && [ "$idx" -le 7 ]; do
    IFS='|' read -r stat cpu comm <<< "$line"
    [ -z "$stat" ] && continue
    top_json="$top_json,\"top$idx\":\"$(normalize_top "$comm" "$cpu")\""
    idx=$((idx + 1))
  done <<EOF_TOP
$ps_output
EOF_TOP

  while [ "$idx" -le 7 ]; do
    top_json="$top_json,\"top$idx\":\"\""
    idx=$((idx + 1))
  done

  printf '{"total":%d,"running":%d%s}\n' "$total" "$running" "$top_json"

  sleep 5
done

'';


ewwSensors = pkgs.writeShellScriptBin "eww-sensors" ''
#!/usr/bin/env bash
# Emits: {"gpu_temp":44,"flow_rate":382,"fan_speed":937,"pump_speed":2725}

LC_ALL=C
gpu_refresh_loops=4   # refresh GPU temp roughly every ~24s (4 * sleep interval)
gpu_counter=0
gpu_temp=null
sensors_timeout=0.4
nvidia_timeout=0.4

normalize() {
  local value="$1"
  value="''${value#+}"
  if [[ $value =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf '%s' "$value"
  else
    printf 'null'
  fi
}

while true; do
  if raw=$(timeout "$sensors_timeout" sensors 2>/dev/null); then
    :
  else
    raw=""
  fi

  mapfile -t sensor_vals < <(awk '
    BEGIN {
      flow = ""; fan = ""; pump = "";
      in_high = 0; in_nct = 0;
    }
    /highflownext-hid-3-/ { in_high = 1; next }
    in_high && NF == 0 { in_high = 0 }
    in_high && /Flow \[dL\/h]/ {
      if (match($0, /:[[:space:]]+([0-9]+(\.[0-9]+)?)/, m)) flow = m[1]
    }
    /nct6798-isa-0290/ { in_nct = 1; next }
    in_nct && NF == 0 { in_nct = 0 }
    in_nct && /fan3/ {
      if (match($0, /:[[:space:]]+([0-9]+(\.[0-9]+)?)/, m)) fan = m[1]
    }
    in_nct && /fan6/ {
      if (match($0, /:[[:space:]]+([0-9]+(\.[0-9]+)?)/, m)) pump = m[1]
    }
    END { printf "%s\n%s\n%s\n", flow, fan, pump }
  ' <<< "$raw")

  flow_rate="''${sensor_vals[0]}"
  fan_speed="''${sensor_vals[1]}"
  pump_speed="''${sensor_vals[2]}"

  flow_rate=$(normalize "$flow_rate")
  fan_speed=$(normalize "$fan_speed")
  pump_speed=$(normalize "$pump_speed")

  if (( gpu_counter <= 0 )); then
    if command -v nvidia-smi >/dev/null 2>&1; then
      gpu_readout=$(timeout "$nvidia_timeout" nvidia-smi --query-gpu=temperature.gpu \
                                --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '[:space:]')
      gpu_temp=$(normalize "$gpu_readout")
    else
      gpu_temp=null
    fi
    gpu_counter=$gpu_refresh_loops
  fi
  ((gpu_counter--))

  printf '{"gpu_temp":%s,"flow_rate":%s,"fan_speed":%s,"pump_speed":%s}\n' \
         "$gpu_temp" "$flow_rate" "$fan_speed" "$pump_speed"

  sleep 6
done
'';

ewwNet = pkgs.writeShellScriptBin "eww-net" ''
#!/usr/bin/env bash

format_rate() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN {
    if (b >= 1048576) printf "%.1fM", b / 1048576;
    else if (b >= 1024) printf "%.0fK", b / 1024;
    else printf "%dB", b;
  }'
}

read_totals() {
  local rx=0 tx=0 iface state
  for iface in /sys/class/net/*; do
    iface="''${iface##*/}"
    case "$iface" in
      lo|docker*|podman*|veth*|br-*|virbr*|tailscale*) continue ;;
    esac
    state="$(cat "/sys/class/net/$iface/operstate" 2>/dev/null || true)"
    [ "$state" = "up" ] || continue
    rx=$((rx + $(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)))
    tx=$((tx + $(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)))
  done
  printf '%s %s\n' "$rx" "$tx"
}

read -r prev_rx prev_tx < <(read_totals)
while true; do
  sleep 1
  read -r rx tx < <(read_totals)
  down=$((rx - prev_rx))
  up=$((tx - prev_tx))
  [ "$down" -ge 0 ] || down=0
  [ "$up" -ge 0 ] || up=0
  printf '{"down":"%s","up":"%s"}\n' "$(format_rate "$down")" "$(format_rate "$up")"
  prev_rx="$rx"
  prev_tx="$tx"
done
'';
in
{
  programs.eww = {
    enable = lib.mkDefault true;
  };

  home.file.".config/eww/sysmon/eww.yuck".text = ''
    (defpoll uptime
      :interval "5s"
      "awk '{t=$1; d=int(t/86400); h=int((t%86400)/3600); m=int((t%3600)/60); printf \"%dd %dh %dm\", d,h,m}' /proc/uptime")
    (defwidget history-graph [value max class]
      (graph
        :value value
        :max max
        :time-range "90s"
        :class class
        :hexpand true
        :vexpand false
        :thickness 2
      ))
    (defpoll swap
      :interval "120s"
      "free -h | awk '/^Swap/ {print $3 \"/\" $2}'")
    (defpoll swap-perc
      :interval "120s"
      "free | awk '/^Swap/ {printf \"%.0f\", $3/$2 * 100.0}'")
    (deflisten procs "bash ${ewwProcs}/bin/eww-procs")
    (deflisten sensors "bash ${ewwSensors}/bin/eww-sensors")
    (deflisten net "bash ${ewwNet}/bin/eww-net")

    (defwidget left-label [text]
      (label
        :text text
        :class "left-label"
        :xalign 0.0
      ))
    (defwidget left-value [text]
      (label :text text :class "left-value" :xalign 0.0))
    (defwidget mid-label [text]
      (label
        :text text
        :class "mid-label"
        :xalign 0.0
      ))
    (defwidget mid-value [text]
      (label :text text :class "mid-value" :xalign 0.0))
    (defwidget left-row [label value ?subtext]
      (box
        :orientation "h"
        :class "row"
        :space-evenly false
        (left-label :text label)
        (left-value :text value)
        (label :text subtext
          :class "left-subtext"
          :halign "start"
          :xalign 0.0)
        (box
         :hexpand true
         :vexpand false
         :width 105
         (children))))
    (defwidget mid-row [label value]
      (box
        :orientation "h"
        :class "row"
        :space-evenly false
          (mid-label :text label)
          (mid-value :text value)
          (box
            :hexpand true
            :vexpand false
            :width 105
            (children))))


    (defwidget sys-info []
      (box
        :orientation "h"
        :width 1416
        :height 112
        :hexpand false
        :vexpand false
        :space-evenly false
        (box
          :orientation "v"
          :vexpand false
          :space-evenly false
          :class "column left"
          :halign "start"
          :hexpand true
          :valign "start"
          (left-row :label "Up" :value uptime)
          (left-row :label "CPU" :value "''${round(EWW_CPU.avg, 1)}%"
            (history-graph :value "''${EWW_CPU.avg}" :max 100 :class "cpu-history history-graph"))
          (left-row :label "RAM" :value "''${round(EWW_RAM.used_mem_perc, 1)}%"
            :subtext "''${round(EWW_RAM.used_mem / 1073741824, 1)} / ''${round(EWW_RAM.total_mem / 1073741824, 0)} GB"
            (history-graph :value "''${EWW_RAM.used_mem_perc}" :max 100 :class "ram-history history-graph"))
          (left-row :label "Swap" :value "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / EWW_RAM.total_swap, 0)}%" :subtext "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / 1073741824, 1)}/''${round(EWW_RAM.total_swap / 1073741824, 0)} GB")
          (left-row :label "Disk" :value "''${round(EWW_DISK["/"].used_perc, 0)}%" :subtext "''${round(EWW_DISK["/"].used / 1073741824, 0)} / ''${round(EWW_DISK["/"].total / 1073741824, 0)} GB")
          (left-row :label "Net" :value "↓ ''${net.down}" :subtext "↑ ''${net.up}")
        )
        (box
          :orientation "v"
          :vexpand false
          :space-evenly false
          :class "column mid"
          :valign "start"
          (mid-row :label "CPU" :value "''${round(EWW_TEMPS.CORETEMP_PACKAGE_ID_0,0)}°C"
            (history-graph :value "''${EWW_TEMPS.CORETEMP_PACKAGE_ID_0}" :max 120 :class "cpu-temp-history history-graph"))
          (mid-row :label "GPU" :value "''${sensors.gpu_temp}°C"
            (history-graph :value "''${sensors.gpu_temp}" :max 120 :class "gpu-temp-history history-graph"))
          (mid-row :label "Water" :value "''${round(EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP,0)}°C"
            (history-graph :value "''${EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP}" :max 60 :class "water-temp-history history-graph"))
          (mid-row :label "Flow" :value "''${sensors.flow_rate} dL/h"
            (history-graph :value "''${sensors.flow_rate}" :max 1000 :class "flow-rate-history history-graph"))
          (mid-row :label "Fan" :value "''${sensors.fan_speed} RPM"
            (history-graph :value "''${sensors.fan_speed}" :max 5000 :class "fan-speed-history history-graph"))
          (mid-row :label "Pump" :value "''${sensors.pump_speed} RPM"
            (history-graph :value "''${sensors.pump_speed}" :max 5000 :class "pump-speed-history history-graph"))
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand true
          :space-evenly false
          :class "column proc-col"
          (box
            :orientation "h"
            :class "process-summary"
            :space-evenly false
            (label :text "Procs" :class "process-summary-label" :xalign 0.0)
            (label :text "''${procs.total} / ''${procs.running}" :class "process-summary-value" :xalign 0.0))
          (label :text "''${procs.top1}" :class "process-line" :xalign 0.0)
          (label :text "''${procs.top2}" :class "process-line" :xalign 0.0)
          (label :text "''${procs.top3}" :class "process-line" :xalign 0.0)
          (label :text "''${procs.top4}" :class "process-line" :xalign 0.0)
          (label :text "''${procs.top5}" :class "process-line" :xalign 0.0)
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand true
          :space-evenly false
          :class "column clock-col"
          :valign "start"
          (label :text "''${formattime(EWW_TIME, '%I:%M %p')}" :class "time" :xalign 1.0 :hexpand true)
          (label :text "''${formattime(EWW_TIME, '%A, %B %d')}" :class "date" :xalign 1.0 :hexpand true)
        )))

    (defwindow sysmon
      :exclusive true
      :monitor "DP-1"
      :geometry (geometry :x "0px" :y "0px" :width "1416px" :height "112px" :anchor "bottom center")
      :stacking "fg"
      :windowtype "dock"
      :wm-ignore false
      (sys-info))
  '';

  home.file.".config/eww/sysmon/eww.scss".text = ''
      .sysmon {
        background-color: rgba(30, 30, 46, 0.5);
        color: rgba(255, 255, 255, 1.0);
        font-family: "Montserrat Bold";
        font-size: 19px;
        padding: 0 2px;
      }

      .column {
        padding: 3px 8px 0 8px;
        border-left: 1px solid rgba(255,255,255,0.12);
      }
      
      .left {
        min-width: 252px;
        margin: 0 6px;
        border-left: 0;
        font-size: 15px;
      }

      .mid {
        min-width: 252px;
        margin: 0 6px;
        font-size: 15px;
      }

      .proc-col {
        min-width: 360px;
      }

      .clock-col {
        min-width: 300px;
      }

      .mid-value {
        min-width: 105px;
      }

      .left-value {
        min-width: 69px;
      }

      .left-label,
      .mid-label {
       color: rgba(255,255,255,0.5);
      }

      .left-value,
      .mid-value
       {
        font-weight: bold;
        color: rgba(255,255,255,1);
      }

      .left-label {
        min-width: 63px;
      }

      .mid-label {
        min-width: 63px;
      }

      .graph.history-graph {
        min-height: 20px;
        padding: 1px 0;
        opacity: 0.9;
      }

      .graph.cpu-history { color: rgba(202,153,255,0.9); }
      .graph.ram-history { color: rgba(249,226,175,0.95); }
      .graph.cpu-temp-history { color: rgba(250,179,135,0.95); }
      .graph.gpu-temp-history { color: rgba(137,220,235,0.95); }
      .graph.water-temp-history { color: rgba(116,199,236,0.95); }
      .graph.flow-rate-history { color: rgba(166,218,149,0.95); }
      .graph.fan-speed-history { color: rgba(245,194,231,0.95); }
      .graph.pump-speed-history { color: rgba(148,226,213,0.95); }

      .cpu-bar progress,
      .cpu-bar progressbar progress { background-color: rgba(202,153,255,0.85); }

      .ram-bar progress,
      .ram-bar progressbar progress { background-color: rgba(249,226,175,0.9); }

      .cpu-temp-bar progress,
      .cpu-temp-bar progressbar progress { background-color: rgba(250,179,135,0.9); }

      .gpu-temp-bar progress,
      .gpu-temp-bar progressbar progress { background-color: rgba(137,220,235,0.9); }

      .water-temp-bar progress,
      .water-temp-bar progressbar progress { background-color: rgba(116,199,236,0.9); }

      .flow-rate-bar progress,
      .flow-rate-bar progressbar progress { background-color: rgba(166,218,149,0.9); }

      .fan-speed-bar progress,
      .fan-speed-bar progressbar progress { background-color: rgba(245,194,231,0.9); }

      .pump-speed-bar progress,
      .pump-speed-bar progressbar progress { background-color: rgba(148,226,213,0.9); }

      .left-subtext {
        font-size: 12px;
        color: rgba(255,255,255,0.7);
        min-width: 79px;
      }

      .process-summary {
        font-size: 16px;
        margin-bottom: 2px;
      }

      .process-summary-label {
        color: rgba(255,255,255,0.5);
        min-width: 52px;
      }

      .process-summary-value {
        color: rgba(255,255,255,0.92);
      }

      .process-line {
        font-family: "Cascadia Code";
        font-size: 13px;
        color: rgba(255,255,255,0.82);
      }

      .time {
        font-family: "Montserrat Medium";
        font-size: 62px;
      }

      .date {
        font-size: 21px;
      }
    '';

  # Autostart bar when Hyprland launches
  wayland.windowManager.hyprland.settings.on = [
    {
      _args = [
        "hyprland.start"
        (lib.generators.mkLuaInline ''
          function()
            hl.exec_cmd("eww daemon --config ~/.config/eww/sysmon && eww --config ~/.config/eww/sysmon close sysmon; eww --config ~/.config/eww/sysmon open sysmon")
          end
        '')
      ];
    }
  ];
}
