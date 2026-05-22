{
  pkgs,
  lib,
  config,
  ...
}: let
  waybarCava = pkgs.waybar.overrideAttrs (_: {
    # Currently broken
    # mesonFlags = (oldAttrs.mesonFlags or []) ++ [ "-Dcava=enabled" ];
    # buildInputs = (oldAttrs.buildInputs or []) ++ [pkgs.libcava];
  });
  toggleApp = pkgs.writeShellScriptBin "toggle-app" ''
    #!/usr/bin/env bash

    if [ -z "$1" ]; then
      echo "Usage: toggle-app <application_name>"
      exit 1
    fi

    APP_NAME="$1"
    KILL_PATTERN="''${2:-$1}"

    if pgrep "$KILL_PATTERN" > /dev/null; then
      pkill "$KILL_PATTERN"
    else
      "$APP_NAME" &>/dev/null &
    fi
  '';
in {
  home.packages = with pkgs;
    lib.mkIf pkgs.stdenv.isLinux [
      pwvucontrol
      karlender
    ];
  programs.waybar = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    package = waybarCava;

    settings = {
      mainBar =
        {
          layer = "top";
          output = "!HDMI-A-1";
          height = 20;
          spacing = 0;

          "modules-left" =
            [
              "hyprland/workspaces"
              "memory"
              "cpu"
              "temperature#cpu"
            ]
            ++ (
              if builtins.hasAttr "waybarModulesLeft" config.variables
              then ["temperature#gpu" "temperature#water"]
              else []
            );
          "modules-center" = ["hyprland/window"];
          "modules-right" = [
            "cava"
            "pulseaudio"
            "network"
            "bluetooth"
            "tray"
            "battery"
            "clock"
          ];

          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = false;
            warp-on-scroll = false;
            format = "{name}: {icon}";
            format-icons = {
              urgent = "";
              active = "";
              default = "";
            };
          };

          tray = {spacing = 5;};

          clock = {
            format = "{:%I:%M %p}";
            "tooltip-format" = "<tt>{calendar}</tt>";
            on-click = "${toggleApp}/bin/toggle-app karlender";
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
            "format-icons" = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
            "on-click" = "${toggleApp}/bin/toggle-app pvwucontrol";
          };

          cpu = {
            format = "{usage}%";
            tooltip = false;
          };
          memory = {format = "{}% ";};

          "temperature#cpu" = {
            "hwmon-path-abs" = "/sys/devices/platform/coretemp.0/hwmon";
            "input-filename" = "temp1_input";
            "critical-threshold" = 80;
            "format-critical" = "{temperatureC}°C {icon}";
            format = "{temperatureC}°C {icon}";
            "format-icons" = [""];
          };

          network = {
            "format-wifi" = "";
            "format-ethernet" = "";
            "tooltip-format" = "{ifname} via {gwaddr}";
            "format-linked" = "(No IP)";
            "format-disconnected" = "D/C ⚠";
          };

          battery = {
            # bat = "ps-controller-battery-58:10:31:1d:a2:43";
            bat =
              if builtins.hasAttr "waybarBattery" config.variables
              then config.variables.waybarBattery
              else "BAT0";
            interval = 60;
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{capacity}% {icon}";
            "format-icons" = ["" "" "" "" ""];
            "max-length" = 25;
          };

          bluetooth = {
            format = " {status}";
            "format-connected" = " {num_connections}";
            "format-disabled" = "";
            "tooltip-format" = "{controller_alias}\t{controller_address}";
            "tooltip-format-connected" = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
            "on-click" = "${toggleApp}/bin/toggle-app blueman-manager blueman-manage";
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
              default = ["" "" ""];
            };
            "on-click" = "${toggleApp}/bin/toggle-app pwvucontrol";
          };
        }
        // (
          if builtins.hasAttr "waybarSettings" config.variables
          then config.variables.waybarSettings
          else {}
        );
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

      .modules-left,
      .modules-center,
      .modules-right {
        padding-top: 1px;
      }

      .modules-left > * >.module,
      .modules-center > * >.module,
      .modules-right > * >.module {
        margin: 0 0.5rem;
      }

      #workspaces > * {
        padding: 0;
      }
    '';
  };

  wayland.windowManager.hyprland.settings = {
    # Start waybar on login
    on = [
      {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("waybar")
            end
          '')
        ];
      }
    ];

    # blur waybar
    layer_rule = [
      {
        name = "waybar-blur";
        match.namespace = "^(waybar)$";
        blur = true;
      }
    ];

    window_rule = [
      # pwvucontrol to top right
      {name = "pwvucontrol-float"; match.class = "^(com.saivert.pwvucontrol)$"; float = true;}
      {name = "pwvucontrol-size"; match.class = "^(com.saivert.pwvucontrol)$"; size = "700 600";}
      {name = "pwvucontrol-move"; match.class = "^(com.saivert.pwvucontrol)$"; move = "100%-700 30";}
      # blueman to top right
      {name = "blueman-float"; match.class = "^(.blueman-manager-wrapped)$"; float = true;}
      {name = "blueman-size"; match.class = "^(.blueman-manager-wrapped)$"; size = "500 600";}
      {name = "blueman-move"; match.class = "^(.blueman-manager-wrapped)$"; move = "100%-510 30";}
      # karlender to top right
      {name = "karlender-float"; match.class = "^(codes.loers.Karlender)$"; float = true;}
      {name = "karlender-size"; match.class = "^(codes.loers.Karlender)$"; size = "400 500";}
      {name = "karlender-move"; match.class = "^(codes.loers.Karlender)$"; move = "100%-400 30";}
    ];
  };
}
