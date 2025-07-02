{
  lib,
  pkgs,
  config,
  ...
}: let
  sidebarScreens =
    if builtins.hasAttr "ewwSidebarScreens" config.variables
    then config.variables.ewwSidebarScreens
    else ["0"];
  barCommands =
    lib.map (
      screen: "eww --config ~/.config/eww/sidebar open bar_${screen}"
    )
    sidebarScreens;
  startupCommand = ''
    eww daemon --config ~/.config/eww/sidebar && \
    ${builtins.concatStringsSep " && " barCommands}'';
  onAttachScript = pkgs.writeShellScriptBin "eww-on-attach" ''
    #! /run/current-system/sw/bin/bash

    # Wait for Hyprland to be ready
    while ! hyprctl monitors > /dev/null 2>&1; do
      sleep 0.1
    done

    # Open the bar for this monitor
    eww --config ~/.config/eww/sidebar open bar_''${1}
  '';
  ewwCava = pkgs.writeShellScriptBin "eww-cava" ''
    #! /run/current-system/sw/bin/bash

    bar="▁▂▃▄▅▆▇█"
    dict="s/;//g;"

    # creating "dictionary" to replace char with bar
    i=0
    while [ $i -lt ''${#bar} ]
    do
        dict="''${dict}s/$i/''${bar:$i:1}/g;"
        i=$((i=i+1))
    done

    # make sure to clean pipe
    pipe="/tmp/cava.fifo"
    if [ -p $pipe ]; then
        unlink $pipe
    fi
    mkfifo $pipe

    # write cava config
    config_file="/tmp/waybar_cava_config"
    echo "
    [general]
    bars = 12
    [output]
    method = raw
    raw_target = $pipe
    data_format = ascii
    ascii_max_range = 7
    [smoothing]
    monstercat = true
    waves = false
    noise_reduction = 0.1
    " > $config_file

    # run cava in the background
    cava -p $config_file &

    # reading data from fifo
    while read -r cmd; do
        echo $cmd | sed $dict
    done < $pipe

  '';

  ewwNetwork = pkgs.writeShellScriptBin "eww-network" ''
    #! /run/current-system/sw/bin/bash

    # try Wi-Fi first
    ssid=$(nmcli -t -f active,ssid dev wifi | awk -F: '$1=="yes"{print $2}')
    if [[ -n "$ssid" ]]; then
      echo "{\"ssid\":\"$ssid\",\"eth\":null}"
      exit
    fi

    # then Ethernet
    eth=$(nmcli -t -f DEVICE,TYPE,STATE dev status \
          | awk -F: '$2=="ethernet" && $3=="connected"{print $1}')
    if [[ -n "$eth" ]]; then
      echo "{\"ssid\":null,\"eth\":\"$eth\"}"
      exit
    fi

    # neither
    echo "{\"ssid\":null,\"eth\":null}"

  '';
  ewwBattery = pkgs.writeShellScriptBin "eww-battery" ''
    #! /run/current-system/sw/bin/bash

    upower -i /org/freedesktop/UPower/devices/battery_BAT0 | awk '
    /state/ { state = $2 }
    /percentage/ {
      gsub(/%/, "", $2)
      percent = $2
    }
    /time to empty/ { time = $4 " " $5 }
    /energy-rate/ { rate = $2 }
    /icon-name/ { icon = $2 }
    END {
      printf("{\"state\": \"%s\", \"percent\": %s, \"time\": \"%s\", \"rate\": \"%s\", \"icon-name\": \"%s\"}\n", state, percent, time, rate, icon)
    }'
  '';
in {
  programs.eww = {
    enable = true;
  };

  home.packages = with pkgs; [
    cava
    hyprland-workspaces
    hyprland-activewindow
    hyprland-monitor-attached
  ];

  home.file.".config/eww/sidebar/eww.yuck".text = ''
    (defwindow bar [screen]
      :exclusive true
      :monitor screen
      :windowtype "dock"
      :geometry (geometry :x "0%"
                  :y "0%"
                  :width "20px"
                  :height "100%"
                  :anchor "right center"
                  )
      (bar :monitor screen))
    ; Also just define bar_0, bar_1, etc. for each screen
    ${builtins.concatStringsSep "\n" (
      lib.map (screen: ''
        (defwindow bar_${screen}
          :exclusive true
          :monitor "${screen}"
          :windowtype "dock"
          :geometry (geometry :x "0%"
                      :y "0%"
                      :width "20px"
                      :height "100%"
                      :anchor "right center"
                      )
          (bar :monitor "${screen}"))
      '')
      sidebarScreens
    )}

    (defwidget bar [monitor]
      (centerbox :orientation "v"
        (top :monitor monitor)
        (center :monitor monitor)
        (bottom :monitor monitor)))

    ; Top
    (defwidget top [monitor]
      (box :orientation "v" :vexpand true :spacing 0 :space-evenly false
        (workspace :monitor monitor)
        ))

    (deflisten all-workspaces "hyprland-workspaces _ | jq -c --unbuffered 'to_entries | map([{(.key | tostring): .value}, (if .value.name != null then {(.value.name): .value} else empty end)]) | flatten | add'")
    (defwidget workspace [monitor]
      (box
        :orientation "v"
        (for workspace in {all-workspaces[monitor].workspaces}
          (button
            :class "workspace-button ''${workspace.active ? "active" : ""}"
            :onclick "hyprctl dispatch workspace ''${workspace.id}"
            {workspace.active ? "-''${workspace.name}-" : "''${workspace.name}"}))))

    ; Center
    (defwidget center [monitor]
      (box :orientation "v"
        (window :monitor monitor)))
    (deflisten windows "hyprland-activewindow _ | jq -c --unbuffered 'to_entries | map([{(.key | tostring): .value}, (if .value.name != null then {(.value.name): .value} else empty end)]) | flatten | add'")
    (defwidget window [monitor]
      (box
        (label :text "''${windows[${"'"}''${monitor}'].title}" :angle -90)
      ))

    ; Bottom
      (defwidget bottom [monitor]
        (box :orientation "v" :valign "end" :spacing 6 :space-evenly false
          (systray :orientation "v" :icon-size 16 :spacing 2 :class "systray")
          (bluetooth)
          (net-indicator)
          (vol)
          (cava)
          (battery)
          (clock)
          ))

    (defwidget bluetooth []
      (box :class "bluetooth" :spacing 0 :space-evenly false
        (label :text "" :class "bluetooth-icon")
        (label :text "''${num-bluetooth-devices}" :class "bluetooth-count")))

    (deflisten net-status
      :interval 5
      "bash ${ewwNetwork}/bin/eww-network")

    (defwidget net-indicator []
      (box :tooltip {net-status["eth"] != "" ? "Ethernet: ''${net-status['eth']}" :
        net-status['ssid'] != "" ? "Wi-Fi: ''${net-status['ssid']}" :
          "No network connection"}
        :class "network-indicator"
        :halign "center"
        :valign "center"
        :spacing 0
        (label :text
          {net-status["eth"] != "" ? "" :
          net-status['ssid'] != "" ? "" :
          "⚠"})))

    (defwidget vol []
      (box :vexpand false :hexpand false
        (circular-progress
          :value {volume*100}
          :width 20
          :height 20
          :thickness 2
          :clockwise false
          :start-at 75
          :tooltip "Volume: ''${volume*100}%"
        (label :text "" :class "volume-icon"))))


    (defpoll volume :interval "1s"
      "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}' | sed 's/%//g' || echo 0")

    (defpoll num-bluetooth-devices :interval "10s"
      "bluetoothctl devices Connected | wc -l || echo 0")

    (deflisten cava "bash ${ewwCava}/bin/eww-cava")
    (defwidget cava []
      (scroll :hscroll true
              :vscroll false
              :class "cava"
              (transform :scale-x "16%"
                   cava)))


    (defpoll battery :interval "10s" "${ewwBattery}/bin/eww-battery")
    (defwidget battery []
      (box :class "battery"
           :halign "center"
           :valign "end"
           :orientation "h"
           :space-evenly false
           :spacing -2
           :tooltip {
            "''${battery.state} - ''${battery.percent}% - ''${battery.rate}W"
           }
           (box :class "battery-icon"
                (label :text {
                  battery.state == "changing" ?
                    (battery.percent < 10 ? "󰢟" :
                    battery.percent < 20 ? "󰢜" :
                    battery.percent < 30 ? "󰂆" :
                    battery.percent < 40 ? "󰂇" :
                    battery.percent < 50 ? "󰂈" :
                    battery.percent < 60 ? "󰢝" :
                    battery.percent < 70 ? "󰂉" :
                    battery.percent < 80 ? "󰢞" :
                    battery.percent < 90 ? "󰂊" :
                    battery.percent < 100 ? "󰂋" : "󱐋") :
                  battery.state == "discharging" || battery.state == "pending-discharge" ?
                  (battery.percent < 10 ? "󰂎" :
                    battery.percent < 20 ? "󰁺" :
                    battery.percent < 30 ? "󰁻" :
                    battery.percent < 40 ? "󰁼" :
                    battery.percent < 50 ? "󰁽" :
                    battery.percent < 60 ? "󰁾" :
                    battery.percent < 70 ? "󰁿" :
                    battery.percent < 80 ? "󰂀" :
                    battery.percent < 90 ? "󰂁" :
                    battery.percent < 100 ? "󰂂" :
                    battery.percent == 100 ? "󰁹" : "󰂃") :
                  battery.state == "fully-charged" || battery.state == "pending-charge" ? "󱟢" :
                  battery.state == "empty" ? "󱃍" :
                  ""}))
           (box :class "battery-percentage"
                (label :text "''${battery.percent}" :angle -90))))



    (defpoll hour :interval "1s"
      "date '+%I'")
    (defpoll minute :interval "1s"
      "date '+%M'")
    (defpoll ampm :interval "1s"
      "date '+%p' | tr '[:upper:]' '[:lower:]'")
    (defpoll date :interval "1s"
      "date '+%m/%d'")
    (defwidget clock []
      (box :class "clock"
           :halign "center"
           :valign "end"
           :orientation "v"
           :space-evenly false
           :spacing -2
           (box :class "clock-hour"
           hour)
           (box :class "clock-minute"
           minute)
           (box :class "clock-ampm"
           ampm)
           (box :class "clock-date"
           date)))
  '';

  home.file.".config/eww/sidebar/eww.scss".text = ''
    * {
    all: unset;
    min-height: 0;
    font-family: "Montserrat Bold";
    font-size: 13px;
    }

    .clock-hour > label,
    .clock-minute > label {
    font-size: 16px;
    font-weight: bold;
    }

    .clock-date > label {
    font-size: 8px;
    margin-top: 4px;
    }

    .workspace-button.active {
    font-weight: bold;
    }

    .cava {
    padding-left: 2px;
    }

    .volume-icon, .bluetooth-icon, .network-icon, .battery-icon {
    font-size: 16px;
    }

    .bluetooth-count {
    font-size: 11px;
    }

    tooltip,
    .systray > widget > window > menu {
      background-color: rgba(0, 0, 0, 0.6);
      border-radius: 8px;
      padding: 2px 0;
      border: 1px solid rgba(255, 255, 255, 0.5);
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    }

    .systray > widget > window >menu > menuitem {

      padding: 2px 6px;
    }

    .systray > widget > window > menu > menuitem:hover {
      background-color: rgba(255,255,255,0.05);
    }

    .clock-ampm > label {
      font-size: 8px;
      margin-left: 8px;
      margin-top: -2px;
    }

    .battery-icon > label{
      font-size: 20px;
    }

    .battery-percentage > label{
      font-size: 11px;
      font-weight: bold;
    }

  '';

  wayland.windowManager.hyprland.settings."exec-once" = [
    startupCommand
    "hyprland-monitor-attached onAttachScript"
  ];
}
