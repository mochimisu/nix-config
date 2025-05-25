{ pkgs, config, ... }:
let
  # Pull in external helpers for workspace parsing and cava visualizer
  hyprctl = pkgs.writeShellApplication {
    name = "eww-hypr-workspaces";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      #! /usr/bin/env bash
      hyprctl -j workspaces | jq -c '[ .[] | {id, name, active} ]'
    '';
  };

  # Helper for temperatures using 'sensors'
  tempScript = pkgs.writeShellApplication {
    name = "eww-temp";
    runtimeInputs = [ pkgs.lm_sensors pkgs.coreutils ];
    text = ''
      #! /usr/bin/env bash
      sensors -j | jq '."coretemp-isa-0000".temp1_input'
    '';
  };

in {
  programs.eww = {
    enable = true;
  };

  home.packages = [ hyprctl tempScript ];

  # Deploy the bar definition and styling
  home.file.".config/eww/bar/eww.yuck" = {
    text = ''
      ;; dynamic state variables updated from helper scripts
      (defvar workspaces "[]")
      ;(defvar cava "")

      ;; local polls
      (defpoll mem   :interval 5  "free --mebi | awk '/Mem:/ { printf \"%.0f\", $3/$2*100 }'")
      (defpoll cpu   :interval 2  "grep -o '^[^ ]*' /proc/loadavg")
      (defpoll temp  :interval 5  "eww-temp")
      (defpoll clock :interval 60 "date '+%I:%M %p'")
      (defpoll bat   :interval 30 "cat /sys/class/power_supply/BAT0/capacity")
      (defpoll net   :interval 5  "ip route get 8.8.8.8 | awk '{print $5}'")
      (defpoll pulse :interval 2  "pamixer --get-volume")
      (defpoll bt    :interval 10 "bash -c 'bluetoothctl info | grep \"Connected: yes\" >/dev/null && echo  || echo \"\"'")

      ;; workspace buttons

      ;; main bar assembly
      (defwidget bar []
        (box :orientation "h" :space-evenly "false" :class "bar"
          ;; left modules
          (box :class "modules-left" :orientation "h" :spacing 10
            ;(ws)
            (label :text (str mem  "% "))
            (label :text (str cpu  "%"))
            (label :text (str temp "°C ")))

          ;; center window‑title
          (box :hexpand "true" :halign "center"
            (label :text "{{window_title}}"))
 
          ;; right modules
          (box :class "modules-right" :orientation "h" :spacing 10
            ;(label :text cava)
            (label :text (str pulse "% "))
            (label :text net)
            (label :text bt)
            (label :text (str bat "% "))
            (label :text clock))))

      (defwindow bar
        :class "bar"
        :monitor 2
        :x 0
        :y 0
        :width "100%"
        :height 30
        :on-close "destroy"
        (bar))
    '';
  };

  home.file.".config/eww/bar/eww.scss" = {
    text = ''
      .bar {
        background-color: rgba(30, 30, 46, 0.5);
        padding: 4px 10px;
        font-family: "Montserrat Bold";
        font-size: 13px;
      }
      .modules-left .active {
        color: #89b4fa;
      }
      .workspaces button {
        background: transparent;
        border: none;
        padding: 0 6px;
      }
    '';
  };

  # Autostart bar when Hyprland launches
  wayland.windowManager.hyprland.settings."exec-once" = [
    "eww daemon --config ~/.config/eww/bar && eww --config ~/.config/eww/bar open bar" 
    # "eww-cava-widget &"
  ];
}
