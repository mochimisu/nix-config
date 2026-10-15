{ lib, pkgs, ... }:
let
  palette = lib.importJSON ./app-palette.json;

ewwProcs = pkgs.writeShellScriptBin "eww-procs" ''
#!/usr/bin/env bash
# Emits: {"total":618,"running":2,"top1":{"name":"foo","cpu":"17.0"}, ...}

normalize_top() {
  local label="$1"
  local cpu="$2"
  ${pkgs.jq}/bin/jq -cn --arg name "$label" --arg cpu "$cpu" '{name: $name, cpu: $cpu}'
}

cpu_capacity=$(( $(${pkgs.coreutils}/bin/nproc --all) * 100 ))
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
    top_json="$top_json,\"top$idx\":$(normalize_top "$comm" "$cpu")"
    idx=$((idx + 1))
  done <<EOF_TOP
$ps_output
EOF_TOP

  while [ "$idx" -le 7 ]; do
    top_json="$top_json,\"top$idx\":{\"name\":\"\",\"cpu\":\"\"}"
    idx=$((idx + 1))
  done

  printf '{"total":%d,"running":%d,"capacity":%d%s}\n' "$total" "$running" "$cpu_capacity" "$top_json"

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
      (overlay :hexpand true
        (graph :value value :max max :time-range "90s" :class class
          :hexpand true :vexpand false :thickness 1 :line-style "round")
        (box :orientation "h" :space-evenly true :valign "end" :class "graph-ticks"
          :tooltip "90-second history; ticks divide time into 30-second intervals"
          (box :class "graph-tick") (box :class "graph-tick") (box))))
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
      (label :text text :class "left-value" :xalign 1.0))
    (defwidget mid-label [text]
      (label
        :text text
        :class "mid-label"
        :xalign 0.0
      ))
    (defwidget mid-value [text]
      (label :text text :class "mid-value" :xalign 1.0))
    (defwidget left-row [label value ?unit ?subtext]
      (box
        :orientation "h"
        :class "row"
        :space-evenly false
        (left-label :text label)
        (left-value :text value)
        (label :text unit :class "metric-unit" :xalign 0.0)
        (label :text subtext
          :class "left-subtext"
          :halign "start"
          :xalign 0.0)
        (box
         :hexpand true
         :vexpand false
         :width 105
         (children))))
    (defwidget mid-row [label value unit ?detail]
      (box
        :orientation "h"
        :class "row"
        :tooltip "''${label}: ''${detail != "" ? detail : value} ''${unit}"
        :space-evenly false
          (mid-label :text label)
          (mid-value :text value)
          (label :text unit :class "metric-unit cooling-unit" :xalign 0.0)
          (box
            :hexpand true
            :vexpand false
            :width 105
            (children))))


    (defwidget process-row [process]
      (box :orientation "h" :space-evenly false :class "process-row"
        :tooltip "''${process.name}: ''${process.cpu}% CPU (ps lifetime average). 100% = one logical CPU; track full scale = ''${procs.capacity}% across all logical CPUs."
        (label :text {process.name} :tooltip {process.name} :class "process-name"
          :xalign 0.0 :hexpand false :truncate true :limit-width 16 :width 120)
        (label :text {process.cpu} :class "process-cpu" :xalign 1.0)
        (label :text "%" :class "process-unit" :xalign 0.0)
        (progress :value {process.cpu / procs.capacity * 100}
          :orientation "h" :hexpand true :valign "center" :class "process-track")))

    (defwidget sys-info []
      (box
        :orientation "h"
        :height 112
        :hexpand true
        :vexpand false
        :space-evenly false
        (box
          :orientation "v"
          :vexpand false
          :space-evenly false
          :class "column left"
          :hexpand true
          :valign "start"
          (label :text "01 COMPUTE" :class "section-heading" :xalign 0.0)
          (left-row :label "Up" :value uptime)
          (left-row :label "CPU" :value "''${round(EWW_CPU.avg, 1)}" :unit "%"
            (history-graph :value "''${EWW_CPU.avg}" :max 100 :class "cpu-history history-graph"))
          (left-row :label "RAM" :value "''${round(EWW_RAM.used_mem_perc, 1)}" :unit "%"
            :subtext "''${round(EWW_RAM.used_mem / 1073741824, 1)} / ''${round(EWW_RAM.total_mem / 1073741824, 0)} GB"
            (history-graph :value "''${EWW_RAM.used_mem_perc}" :max 100 :class "ram-history history-graph"))
          (left-row :label "Swap" :value "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / EWW_RAM.total_swap, 0)}" :unit "%" :subtext "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / 1073741824, 1)}/''${round(EWW_RAM.total_swap / 1073741824, 0)} GB")
          (left-row :label "Disk" :value "''${round(EWW_DISK["/"].used_perc, 0)}" :unit "%" :subtext "''${round(EWW_DISK["/"].used / 1073741824, 0)} / ''${round(EWW_DISK["/"].total / 1073741824, 0)} GB")
          (left-row :label "Net" :value "↓ ''${net.down}" :subtext "↑ ''${net.up}")
        )
        (box
          :orientation "v"
          :vexpand false
          :space-evenly false
          :class "column mid"
          :hexpand true
          :valign "start"
          (label :text "02 COOLING" :class "section-heading" :xalign 0.0)
          (mid-row :label "CPU" :value "''${round(EWW_TEMPS.CORETEMP_PACKAGE_ID_0,0)}" :unit "°C" :detail "''${EWW_TEMPS.CORETEMP_PACKAGE_ID_0}"
            (history-graph :value "''${EWW_TEMPS.CORETEMP_PACKAGE_ID_0}" :max 120 :class "cpu-temp-history history-graph"))
          (mid-row :label "GPU" :value "''${sensors.gpu_temp}" :unit "°C"
            (history-graph :value "''${sensors.gpu_temp}" :max 120 :class "gpu-temp-history history-graph"))
          (mid-row :label "Water" :value "''${round(EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP,0)}" :unit "°C" :detail "''${EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP}"
            (history-graph :value "''${EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP}" :max 60 :class "water-temp-history history-graph"))
          (mid-row :label "Flow" :value "''${sensors.flow_rate}" :unit "dL/h"
            (history-graph :value "''${sensors.flow_rate}" :max 1000 :class "flow-rate-history history-graph"))
          (mid-row :label "Fan" :value "''${sensors.fan_speed}" :unit "RPM"
            (history-graph :value "''${sensors.fan_speed}" :max 5000 :class "fan-speed-history history-graph"))
          (mid-row :label "Pump" :value "''${sensors.pump_speed}" :unit "RPM"
            (history-graph :value "''${sensors.pump_speed}" :max 5000 :class "pump-speed-history history-graph"))
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand false
          :space-evenly false
          :class "column proc-col"
          (label :text "03 PROCESSES" :class "section-heading" :xalign 0.0)
          (box
            :orientation "h"
            :class "process-summary"
            :space-evenly false
            (label :text "Procs" :class "process-summary-label" :xalign 0.0)
            (label :text "''${procs.total} / ''${procs.running}" :class "process-summary-value" :xalign 0.0))
          (process-row :process {procs.top1})
          (process-row :process {procs.top2})
          (process-row :process {procs.top3})
          (process-row :process {procs.top4})
          (process-row :process {procs.top5})
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand false
          :space-evenly false
          :class "column clock-col"
          :valign "start"
          (label :text "LOCAL TIME" :class "section-heading" :xalign 1.0)
          (label :text "''${formattime(EWW_TIME, '%I:%M %p')}" :class "time" :xalign 1.0 :hexpand true)
          (label :text "''${formattime(EWW_TIME, '%A, %B %d')}" :class "date" :xalign 1.0 :hexpand true)
        )))

    (defwindow sysmon
      :namespace "blackmoon-sysmon"
      :focusable "none"
      :exclusive true
      :monitor "DP-1"
      :geometry (geometry :x "0px" :y "0px" :width "100%" :height "112px" :anchor "bottom center")
      :stacking "fg"
      :windowtype "dock"
      :wm-ignore false
      (sys-info))
  '';

  home.file.".config/eww/sysmon/eww.scss".text = ''
      .sysmon {
        background-color: rgba(24, 29, 33, 0.6);
        box-shadow: inset 0 1px 0 rgba(99,198,192,0.25);
        color: rgba(255, 255, 255, 1.0);
        font-family: "Montserrat Bold";
        font-size: 19px;
        padding: 0 2px;
      }

      .column {
        padding: 4px 12px 3px 12px;
        border-left: 1px solid rgba(255,255,255,0.12);
      }
      
      .left {
        min-width: 300px;
        margin: 0 6px;
        border-left: 0;
        font-size: 11px;
      }

      .mid {
        min-width: 300px;
        margin: 0 6px;
        font-size: 11px;
      }

      .proc-col {
        min-width: 340px;
      }

      .clock-col {
        min-width: 300px;
      }

      .mid-value { min-width: 58px; }

      .left-value { min-width: 88px; }

      .left-label,
      .mid-label {
       font-weight: bold;
       color: #b9bec2;
      }

      .left-value,
      .mid-value
       {
        font-family: "Cascadia Code";
        font-size: 12px;
        font-weight: bold;
        color: rgba(255,255,255,1);
      }

      .left-label {
        min-width: 48px;
      }

      .mid-label {
        min-width: 48px;
      }

      .history-graph {
        min-height: 0;
        margin: 2px 0 2px 8px;
        color: rgba(235,238,240,0.9);
        background-color: rgba(235,238,240,0.055);
      }

      .graph-ticks { margin: 2px 0 2px 8px; min-height: 3px; }
      .graph-tick { border-right: 1px solid rgba(255,255,255,0.18); }
      .process-track { margin-left: 12px; }
      .process-track trough { min-width: 0; min-height: 2px; border: 0; border-radius: 0; background: rgba(255,255,255,0.04); }
      .process-track progress { min-width: 0; min-height: 2px; border: 0; border-radius: 0; background: rgba(255,255,255,0.23); }
      .section-heading {
        font-family: "Montserrat Semi-Bold";
        font-weight: bold;
        font-size: 9px;
        letter-spacing: 1.5px;
        color: #b9bec2;
        margin-bottom: 3px;
      }
      .row { min-height: 14px; }
      .metric-unit {
        font-size: 10px;
        color: #92999e;
        min-width: 12px;
        padding-left: 3px;
        padding-right: 6px;
      }
      .cooling-unit { min-width: 28px; }


      .left-subtext {
        font-family: "Cascadia Code";
        font-size: 10px;
        color: #b9bec2;
        min-width: 79px;
      }

      .process-summary {
        font-family: "Cascadia Code";
        font-size: 12px;
        margin-bottom: 0;
      }

      .process-summary-label {
        color: #b9bec2;
        min-width: 52px;
      }

      .process-summary-value {
        color: ${palette.text};
      }

      .process-row { font-size: 11px; min-height: 14px; }
      .process-name {
        font-family: "Montserrat";
        font-size: 11px;
        font-weight: 500;
        color: ${palette.text};
      }
      .process-cpu {
        font-family: "Cascadia Code";
        font-size: 11px;
        min-width: 58px;
        color: ${palette.text};
      }
      .process-unit {
        font-size: 10px;
        color: #92999e;
        padding-left: 3px;
      }

      .time {
        font-family: "Montserrat Medium";
        font-size: 52px;
      }

      .date {
        color: #b9bec2;
        font-size: 16px;
      }
    '';

  # Higher order reserves the full-width bottom edge before the vertical sidebar,
  # independent of startup/reload order. The sidebar then ends above these 112px.
  wayland.windowManager.hyprland.settings.layer_rule = [{
    name = "blackmoon-sysmon-layout";
    match.namespace = "^(blackmoon-sysmon)$";
    order = 20;
    blur = true;
    ignore_alpha = 0;
  }];

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
