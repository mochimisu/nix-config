{ pkgs, config, ... }:

let
  waybarCava = pkgs.waybar.overrideAttrs (oldAttrs: {
    mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dcava=enabled" ];
    buildInputs = (oldAttrs.buildInputs or []) ++ [ pkgs.libcava ];
  });
in
{
  programs.waybar = {
    enable  = true;
    package = waybarCava;

    settings = {
      mainBar = {
        layer = "top";
        output = "!HDMI-A-1";
        height = 20;
        spacing = 0;

        "modules-left" = [ 
          "hyprland/workspaces"
          "memory" "cpu" "temperature#cpu" 
        ] ++ (if builtins.hasAttr "waybarModulesLeft" config.variables then [ "temperature#gpu" "temperature#water" ] else []);
        "modules-center" = [ "hyprland/window" ];
        "modules-right" = [
            "cava" "pulseaudio" "network"
            "bluetooth" "tray" "battery" "clock"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
          warp-on-scroll = false;
          format = "{name}: {icon}";
          format-icons = {
            urgent = "◉";
            active = "●";
            default = "○";
          };
        };

        tray = { spacing = 5; };

        clock = {
          format = "{:%I:%M %p}";
          "tooltip-format" = "<tt>{calendar}</tt>";
          on-click = "mode";
          calendar = {
            format = {
              today = "<b><u>{}</u></b>";
            };
          };
        };

        cava = {
          framerate = 60;
          autosens = 1;
          bars = 6;
          lower_cutoff_freq = 1;
          higher_cutoff_freq = 10000;
          method = "pulse";
          source = "auto";
          stereo = true;
          reverse = false;
          bar_delimiter = 0;
          monstercat = true;
          waves = false;
          noise_reduction = 0.1;
          input_delay = 0;
          "format-icons" = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
          actions = { "on-click-right" = "mode"; };
        };

        cpu = { format = "{usage}%"; tooltip = false; };
        memory = { format = "{}% "; };

        "temperature#cpu" = {
          "hwmon-path-abs" = "/sys/devices/platform/coretemp.0/hwmon";
          "input-filename" = "temp1_input";
          "critical-threshold" = 80;
          "format-critical" = "{temperatureC}°C {icon}";
          format = "{temperatureC}°C {icon}";
          "format-icons" = [ "" ];
        };

        network = {
          "format-wifi" = "";
          "format-ethernet" = "";
          "tooltip-format" = "{ifname} via {gwaddr}";
          "format-linked" = "(No IP)";
          "format-disconnected"= "D/C ⚠";
        };

        battery = {
          # bat = "ps-controller-battery-58:10:31:1d:a2:43";
          bat = if builtins.hasAttr "waybarBattery" config.variables then config.variables.waybarBattery else "BAT0";
          interval = 60;
          states = { warning = 30; critical = 15; };
          format = "{capacity}% {icon}";
          "format-icons" = [ "" "" "" "" "" ];
          "max-length" = 25;
        };

        bluetooth = {
          format = " {status}";
          "format-connected" = " {num_connections}";
          "format-disabled" = "";
          "tooltip-format" = "{controller_alias}\t{controller_address}";
          "tooltip-format-connected" = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
          "on-click" = "blueman-manager";
        };

        pulseaudio = {
          format = "{volume}% {icon} {format_source}";
          "format-bluetooth" = "{volume}% {icon} {format_source}";
          "format-bluetooth-muted" = " {icon} {format_source}";
          "format-muted" = " {format_source}";
          "format-source" = "";
          "format-source-muted" = "";
          "format-icons" = {
            headphone = "";
            "hands-free" = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          "on-click" = "pavucontrol";
        };
      } // (if builtins.hasAttr "waybarSettings" config.variables then config.variables.waybarSettings else {});
    };

  style = ''
* {
  min-height: 0;
}

window#waybar {
  background-color: rgba(30, 30, 46, 0.25);
  font-family: "Montserrat Bold";
  font-size: 13px;
}

.modules-right > * >.module,
.modules-left > * >.module {
  margin: 0 0.5rem;
}
'';
  };

  wayland.windowManager.hyprland.settings = {
    # Start waybar on login
    "exec-once" = [
      "waybar"
    ];

    # blur waybar
    layerrule = [
      "blur, ^(waybar)$"
    ];
  };
}

