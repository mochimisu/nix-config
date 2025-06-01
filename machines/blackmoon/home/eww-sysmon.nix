{ lib, pkgs, ... }:
let

ewwProcs = pkgs.writeShellScriptBin "eww-procs" ''
#!/usr/bin/env bash
# ~/bin/eww-procs.sh
# JSON: {"total":618,"running":2,"top1":"foo: 17%","top2":"bar: 16%",…}

while true; do
  # one single ps, already without the header
  mapfile -t ps_lines < <(ps -eo stat,comm,%cpu --sort=-%cpu --no-headers)

  total=''${#ps_lines[@]}
  running=0
  tops=()

  for line in "''${ps_lines[@]}"; do
    # read collapses *any* whitespace, so leading blanks don’t hurt
    read -r stat comm cpu <<< "''$line"

    [[ ''$stat == R* ]] && ((running++))

    if ((''${#tops[@]} < 7)); then
      tops+=("''$(printf "%-15s: %s%%" "''$comm" "''$cpu")")
    fi
  done

  # pad to exactly seven keys for predictable labels
  while ((''${#tops[@]} < 7)); do tops+=(""); done

  printf '{"total":%d,"running":%d' "''$total" "''$running"
  for i in {1..7}; do
    printf ',"top%d":"%s"' "''$i" "''${tops[''$((i-1))]}"
  done
  printf '}\n'

  sleep 2
done


'';
ewwSensors = pkgs.writeShellScriptBin "eww-sensors" ''
#!/usr/bin/env bash
# Emits: {"gpu_temp":44,"flow_rate":382,"fan_speed":937,"pump_speed":2725}

while true; do
  raw=''$(sensors 2>/dev/null)          # one single probe; silence warnings

  # ----- GPU temperature ----------------------------------------------------
  # use nvidia-smi
  if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_temp=''$(nvidia-smi --query-gpu=temperature.gpu \
                           --format=csv,noheader,nounits 2>/dev/null | head -n1)
  else
    gpu_temp="<unknown>"
  fi

  # ----- Flow-rate, fan RPM, pump RPM ---------------------------------------
  # Use AWK section delimiters to stay within the right hwmon block.
  flow_rate=''$(awk '
    /highflownext-hid-3-/ {inblock=1}
    inblock && /Flow \[dL\/h]/ {
      gsub(/[[:space:]dL\/h]/,"",''$3); print ''$3; exit
    }' <<< "''$raw")

  fan_speed=''$(awk '
    /nct6798-isa-0290/ {inblock=1}
    inblock && /fan3/  {gsub(/[[:space:]RPM]/,"",''$2); print ''$2; exit}' <<< "''$raw")

  pump_speed=''$(awk '
    /nct6798-isa-0290/ {inblock=1}
    inblock && /fan6/  {gsub(/[[:space:]RPM]/,"",''$2); print ''$2; exit}' <<< "''$raw")

  printf '{"gpu_temp":%s,"flow_rate":%s,"fan_speed":%s,"pump_speed":%s}\n' \
         "''${gpu_temp:-null}" "''${flow_rate:-null}" \
         "''${fan_speed:-null}" "''${pump_speed:-null}"

  sleep 2
done
'';
in
{
  programs.eww = {
    enable = lib.mkDefault true;
  };

  home.file.".config/eww/sysmon/eww.yuck".text = ''
    (defpoll uptime
      :interval "1s"
      "awk '{t=$1; d=int(t/86400); h=int((t%86400)/3600); m=int((t%3600)/60); printf \"%dd %dh %dm\", d,h,m}' /proc/uptime")
    (defpoll time
      :interval "1s"
      `date +%H:%M:%S`)
    (defwidget cpu-graph []
      (graph
        :value "''${EWW_CPU.avg}"
        :max 100
        :time-range "30s"
      ))
    (defwidget ram-graph []
      (graph
        :value "''${EWW_RAM.used_mem_perc}"
        :max 100
        :time-range "30s"
      ))
    (defpoll swap
      :interval "30s"
      "free -h | awk '/^Swap/ {print $3 \"/\" $2}'")
    (defpoll swap-perc
      :interval "30s"
      "free | awk '/^Swap/ {printf \"%.0f\", $3/$2 * 100.0}'")
    (deflisten procs "bash ${ewwProcs}/bin/eww-procs")
    (deflisten sensors "bash ${ewwSensors}/bin/eww-sensors")
    (defwidget cpu-temp-graph []
      (graph
        :value "''${EWW_TEMPS.CORETEMP_PACKAGE_ID_0}"
        :max 120
        :time-range "30s"
        :class "cpu-temp-graph graph"
        :hexpand true
        :vexpand true
        :width "100%"
        :height "100%"
      ))
    (defwidget gpu-temp-graph []
      (graph
        :value "''${sensors.gpu_temp}"
        :max 120
        :time-range "30s"
        :class "gpu-temp-graph graph"
      ))
    (defwidget water-temp-graph []
      (graph
        :value "''${EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP}"
        :max 60
        :time-range "30s"
        :class "water-temp-graph graph"
      ))
    (defwidget flow-rate-graph []
      (graph
        :value "''${sensors.flow_rate}"
        :max 1000
        :time-range "30s"
        :class "flow-rate-graph graph"
      ))
    (defwidget fan-speed-graph []
      (graph
        :value "''${sensors.fan_speed}"
        :max 5000
        :time-range "30s"
        :class "fan-speed-graph graph"
      ))
    (defwidget pump-speed-graph []
      (graph
        :value "''${sensors.pump_speed}"
        :max 5000
        :time-range "30s"
        :class "pump-speed-graph graph"
      ))

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
         :vexpand true
         :width 200
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
            :vexpand true
            :width 200
            (children))))


    (defwidget sys-info []
      (box
        :orientation "h"
        :space-evenly false
        :vexpand true
        (box
          :orientation "v"
          :vexpand true
          :space-evenly false
          :class "left"
          :halign "start"
          :hexpand true
          :valign "end"
          (left-row :label "Up" :value uptime)
          (left-row :label "CPU" :value "''${round(EWW_CPU.avg, 1)}%" (cpu-graph))
          (left-row :label "RAM" :value "''${round(EWW_RAM.used_mem_perc, 1)}%" :subtext "''${round(EWW_RAM.used_mem / 1073741824, 1)} / ''${round(EWW_RAM.total_mem / 1073741824, 0)} GB" (ram-graph))
          (left-row :label "Swap" :value "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / EWW_RAM.total_swap, 0)}%" :subtext "''${round((EWW_RAM.total_swap - EWW_RAM.free_swap) / 1073741824, 1)}/''${round(EWW_RAM.total_swap / 1073741824, 0)} GB")
          (left-row :label "Disk" :value "''${round(EWW_DISK["/"].used_perc, 0)}%" :subtext "''${round(EWW_DISK["/"].used / 1073741824, 0)} / ''${round(EWW_DISK["/"].total / 1073741824, 0)} GB")
          (left-row :label "Net" :value "↑''${round(EWW_NET.eno2.NET_UP / 104856, 1)} ↓''${round(EWW_NET.eno2.NET_DOWN / 1048576, 1)}" :subtext "MB/s")
          (left-row :label "Procs" :value "''${procs.total} / ''${procs.running}")
        )
        (box
          :orientation "v"
          :vexpand true
          :space-evenly false
          :class "mid"
          :valign "end"
          (mid-row :label "CPU" :value "''${round(EWW_TEMPS.CORETEMP_PACKAGE_ID_0,0)}°C" (cpu-temp-graph))
          (mid-row :label "GPU" :value "''${sensors.gpu_temp}°C" (gpu-temp-graph))
          (mid-row :label "Water" :value "''${round(EWW_TEMPS.HIGHFLOWNEXT_COOLANT_TEMP,0)}°C" (water-temp-graph))
          (mid-row :label "Flow" :value "''${sensors.flow_rate} dL/h" (flow-rate-graph))
          (mid-row :label "Fan" :value "''${sensors.fan_speed} RPM" (fan-speed-graph))
          (mid-row :label "Pump" :value "''${sensors.pump_speed} RPM" (pump-speed-graph))
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand true
          :space-evenly false
          :class "right"
          (label :text "''${formattime(EWW_TIME, '%I:%M %p')}" :class "time" :xalign 1.0 :hexpand true)
          (label :text "''${formattime(EWW_TIME, '%A, %B %d, %Y')}" :class "date" :xalign 1.0 :hexpand true)
          (box
            :orientation "v"
            :class "processes"
            (label :text "''${procs.top1}" :xalign 1.0)
            (label :text "''${procs.top2}" :xalign 1.0)
            (label :text "''${procs.top3}" :xalign 1.0)
            (label :text "''${procs.top4}" :xalign 1.0)
            (label :text "''${procs.top5}" :xalign 1.0)
            (label :text "''${procs.top6}" :xalign 1.0)
          )
        )))

    (defwindow sysmon
      :monitor 0
      :geometry (geometry :x "0px" :y "0px" :width "1920px" :height "480px" :anchor "top left")
      :stacking "fg"
      :windowtype "desktop"
      :wm-ignore false
      (sys-info))
  '';

  home.file.".config/eww/sysmon/eww.scss".text = ''
      .sysmon {
        background-color: rgba(30, 30, 46, 0.5);
        color: rgba(255, 255, 255, 1.0);
        font-family: "Montserrat Bold";
        font-size: 36px;
        padding: 0 10px;
      }
      
      .left {
        min-width: 480px;
        margin: 0 20px;
      }

      .mid {
        min-width: 480px;
        margin: 0 20px;
      }

      .right {
        min-width: 600px;
      }

      .mid-value {
        min-width: 200px;
      }

      .left-value {
        min-width: 130px;
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
        min-width: 120px;
      }

      .mid-label {
        min-width: 120px;
      }

      .left-subtext {
        font-size: 24px;
        color: rgba(255,255,255,0.7);
        min-width: 150px;
      }

      .processes {
        font-family: "Cascadia Code";
        margin-top: 40px;
      }

      .time {
        font-family: "Montserrat Medium";
        font-size: 100px;
      }
    '';

  # Autostart bar when Hyprland launches
  wayland.windowManager.hyprland.settings."exec-once" = [
    "eww daemon --config ~/.config/eww/sysmon && eww --config ~/.config/eww/sysmon open sysmon" 
  ];
}
