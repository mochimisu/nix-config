{ lib, ... }:
{
  programs.eww = {
    enable = lib.mkDefault true;
  };

  home.file.".config/eww/sysmon/eww.yuck".text = ''
    (defpoll uptime
      :interval "1s"
      "awk '{t=$1; d=int(t/86400); h=int((t%86400)/3600); m=int((t%3600)/60); printf \"%dd %dh %dm\n\", d,h,m}' /proc/uptime")
    (defpoll cpu-ghz
      :interval "1s"
      "grep \"cpu MHz\" /proc/cpuinfo | awk '{print $4}' | awk '{sum+=$1} END {printf \"%.2f\", sum/NR/1000}'")
    (defpoll time
      :interval "1s"
      `date +%H:%M:%S`)
    (defpoll cpu
      :interval "1s"
      "top -bn1 | grep 'Cpu(s)' | awk '{print $2 + $4}'")
    (defwidget cpu-graph []
      (graph
        :value cpu
        :max 100
        :time-range "30s"
      ))
    (defpoll ram
      :interval "5s"
      "free -h | awk '/^Mem/ {print $3 \"/\" $2}'")
    (defpoll ram-perc
      :interval "5s"
      "free | awk '/^Mem/ {printf \"%.0f\", $3/$2 * 100.0}'")
    (defwidget ram-graph []
      (graph
        :value ram-perc
        :max 100
        :time-range "30s"
      ))
    (defpoll disk
      :interval "30s"
      "df -h / | awk 'NR==2 {print $3 \"/\" $2}'")
    (defpoll disk-perc
      :interval "30s"
      "df / | awk 'NR==2 {printf \"%.0f\", $3/$2 * 100.0}'")
    (defpoll swap
      :interval "30s"
      "free -h | awk '/^Swap/ {print $3 \"/\" $2}'")
    (defpoll swap-perc
      :interval "30s"
      "free | awk '/^Swap/ {printf \"%.0f\", $3/$2 * 100.0}'")
    (defpoll num-processes
      :interval "5s"
      "ps -e | wc -l")
    (defpoll running-processes
      :interval "5s"
      "ps -eo stat | grep -c '^R'")
    (defpoll processes
      :interval "1s"
       `ps -eo pid,comm,%cpu --sort=-%cpu | head -n 7 | tail -n +2 | awk '{printf "%15s: %s%%\\n", $2, $3}'`)
    (defpoll cpu-temp
      :interval "5s"
      "sensors coretemp-isa-0000 | awk '/Package id 0/ {print $4}' | sed 's/+//;s/°C//'")
    (defwidget cpu-temp-graph []
      (graph
        :value cpu-temp
        :max 120
        :time-range "30s"
        :class "cpu-temp-graph graph"
        :hexpand true
        :vexpand true
        :width "100%"
        :height "100%"
      ))
    (defpoll gpu-temp
      :interval "5s"
      "sensors nvme-pci-7200 | awk '/Composite/ {print $2}' | sed 's/+//;s/°C//'")
    (defwidget gpu-temp-graph []
      (graph
        :value gpu-temp
        :max 120
        :time-range "30s"
        :class "gpu-temp-graph graph"
      ))
    (defpoll water-temp
      :interval "5s"
      "sensors highflownext-hid-3-\\* | awk '/Coolant temp/ {print $3}' | sed 's/+//;s/°C//'")
    (defwidget water-temp-graph []
      (graph
        :value water-temp
        :max 60
        :time-range "30s"
        :class "water-temp-graph graph"
      ))
    (defpoll flow-rate
      :interval "5s"
      "sensors highflownext-hid-3-\\* | awk '/Flow \\[dL\\/h\\]/ {print $3}' | sed 's/ dL\\/h//;s/ //g'")
    (defwidget flow-rate-graph []
      (graph
        :value flow-rate
        :max 1000
        :time-range "30s"
        :class "flow-rate-graph graph"
      ))
    (defpoll fan-speed
      :interval "5s"
      "sensors nct6798-isa-0290 | awk '/fan3/ {print $2}' | sed 's/ RPM//;s/ //g'")
    (defwidget fan-speed-graph []
      (graph
        :value fan-speed
        :max 5000
        :time-range "30s"
        :class "fan-speed-graph graph"
      ))
    (defpoll pump-speed
      :interval "5s"
      "sensors nct6798-isa-0290 | awk '/fan6/ {print $2}' | sed 's/ RPM//;s/ //g'")
    (defwidget pump-speed-graph []
      (graph
        :value pump-speed
        :max 5000
        :time-range "30s"
        :class "pump-speed-graph graph"
      ))
    (deflisten current-time :interval "1s"
      `date '+%-I:%M %p'`)
    (deflisten current-date :interval "1s"
      `date '+%A, %B %d, %Y'`)

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
          (left-row :label "CPU" :value "''${cpu}%" :subtext "''${cpu-ghz}GHz" (cpu-graph))
          (left-row :label "RAM" :value "''${ram-perc}%" :subtext ram (ram-graph))
          (left-row :label "Swap" :value "''${swap-perc}%" :subtext swap (ram-graph))
          (left-row :label "Disk" :value "''${disk-perc}%" :subtext disk)
          (left-row :label "Net" :value "↑''${round(EWW_NET.eno2.NET_UP / 104856, 1)} ↓''${round(EWW_NET.eno2.NET_DOWN / 1048576, 1)}" :subtext "MB/s")
          (left-row :label "Procs" :value "''${num-processes} / ''${running-processes}")
        )
        (box
          :orientation "v"
          :vexpand true
          :space-evenly false
          :class "mid"
          :valign "end"
          (mid-row :label "CPU" :value "''${cpu-temp}°C" (cpu-temp-graph))
          (mid-row :label "GPU" :value "''${gpu-temp}°C" (gpu-temp-graph))
          (mid-row :label "Water" :value "''${water-temp}°C" (water-temp-graph))
          (mid-row :label "Flow" :value "''${flow-rate} dL/h" (flow-rate-graph))
          (mid-row :label "Fan" :value "''${fan-speed} RPM" (fan-speed-graph))
          (mid-row :label "Pump" :value "''${pump-speed} RPM" (pump-speed-graph))
        )
        (box
          :orientation "v"
          :vexpand false
          :hexpand true
          :space-evenly false
          :class "right"
          (label :text current-time :class "time" :xalign 1.0 :hexpand true)
          (label :text current-date :class "date" :xalign 1.0 :hexpand true)
          (label :text processes
            :class "processes"
            :xalign 1.0
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
