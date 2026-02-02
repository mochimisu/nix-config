{
  pkgs,
  config,
  lib,
  ...
}: let
  moonWallpaper = builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/l8/wallhaven-l8mlyy.jpg";
    sha256 = "sha256:1571r0sz1qfz9xdqqkbpzfx8wx22azrhmsmdj14km427qcyiiap6";
  };
in {
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    hiddenMonitors = ["0"];
    cpuTempSensor = "/dev/highflow_next/temp1_input";
  };
  variables.ewwPttStateFile = "${config.home.homeDirectory}/.local/state/hypr-ptt/state";
  home.file.".config/hypr/moon.jpg".source = moonWallpaper;
  variables.hyprpaper-config = ''
    wallpaper {
      monitor = DP-3
      path = ${config.home.homeDirectory}/.config/hypr/moon.jpg
    }
  '';

  imports = [
    ../../../home/common-linux.nix
    ./eww-sysmon.nix
    ./fastfetch.nix
  ];

  home.packages = with pkgs; [
    wlr-randr
    nvidia-vaapi-driver
  ];

  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "DP-1,2560x1440@120,3440x-560,1,transform,1"
        "DP-3,3440x1440@175,0x0,1"
        "HDMI-A-1,480x1920@60,4880x1400,1,transform,1"
      ];
      workspace = [
        "1, monitor:DP-3, default:true"
        "2, monitor:DP-1, default:true"
        "3, monitor:DP-3, default:true"
        "10, monitor:HDMI-A-1, default:true"
      ];
    };

    windowrule = [
      "workspace 2 silent, match:class ^(steam)$"
      "workspace 2 silent, match:class ^(discord)$"
      "render_unfocused 1, match:class ^(Monster Hunter Wilds)$"
      "monitor DP-3 tile, match:class ^(ffxiv_dx11.exe)$"
    ];

    input = {
      kb_layout = "us,us";
      kb_variant = "dvorak,";
    };

    "exec-once" = [
      # "discordcanary"
      # "vesktop"
      "discord"
      # set DP-3 as primary
      "wlr-randr --output DP-3 --primary"
      # set Xwayland primary so Proton/Wine sees DP-3 as primary
      "DISPLAY=:1 xrandr --output DP-3 --primary"
      # todo moon profile
      "openrgb --profile /home/brandon/.config/OpenRGB/moon.orp"
      "mangohud steam -silent"
    ];

    # nvidia stuff, move to shared
    nvidia = {
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        "NIXOS_OZONE_WL=1"
      ];
    };

    opengl = {
      nvidia_anti_flicker = 0;
    };

    # misc = {
    #   # potentially reducing flicker in electron apps
    #   # vrr = "0";
    #   # vfr = "0" means every single frame is rendered, not great
    #   # but allows nvidia_anti_flicker to be set to 0
    #   # vfr = 0;
    # };
    cursor = {
      default_monitor = "DP-3";
    };
    bind = [
      "$mod, F2, exec, ~/.config/hypr/gamemode2.sh"
      "$mod, F3, exec, ~/.config/hypr/toggle-ptt.sh"
      ", mouse:275, exec, ~/.config/hypr/ptt-mouse.sh press"
    ];
    bindr = [
      ", mouse:275, exec, ~/.config/hypr/ptt-mouse.sh release"
    ];
  };
  home.file.".config/hypr/gamemode2.sh" = {
    executable = true;
    text = ''
      HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
      if [ "$HYPRGAMEMODE" = 1 ] ; then
          hyprctl --batch "\
              keyword animations:enabled 0;\
              keyword decoration:drop_shadow 0;\
              keyword decoration:blur:enabled 0;\
              keyword general:gaps_in 0;\
              keyword general:gaps_out 0;\
              keyword general:border_size 1;\
              keyword decoration:rounding 0;\
              keyword monitor DP-1,2560x1440@120,3440x-560,1,transform,1;\
              keyword monitor DP-3,3440x1440@175,0x0,1;\
              keyword monitor HDMI-A-1,480x1920@60,4880x1200,1,transform,1"
          exit
      fi
      hyprctl reload
    '';
  };
  home.file.".config/hypr/ptt-mouse.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-ptt/state"

      state="enabled"
      if [ -f "$state_file" ]; then
        state=$(tr -d '[:space:]' <"$state_file")
      fi

      if [ "$state" != "enabled" ]; then
        exit 0
      fi

      case "''${1:-}" in
        press)
          pactl set-source-mute @DEFAULT_SOURCE@ 0
          ;;
        release)
          pactl set-source-mute @DEFAULT_SOURCE@ 1
          ;;
      esac
    '';
  };
  home.file.".config/hypr/toggle-ptt.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_file="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-ptt/state"
      mkdir -p "$(dirname "$state_file")"

      current="enabled"
      if [ -f "$state_file" ]; then
        current=$(tr -d '[:space:]' <"$state_file")
      fi

      if [ "$current" = "enabled" ]; then
        echo "disabled" >"$state_file"
        pactl set-source-mute @DEFAULT_SOURCE@ 0
      else
        echo "enabled" >"$state_file"
      fi
    '';
  };

  # additional waybar modules
  variables.waybarModulesLeft = [
    "temperature#gpu"
    "temperature#water"
  ];
  variables.waybarSettings = {
    "temperature#gpu" = {
      "hwmon-path-abs" = "/sys/devices/pci0000:00/0000:00:1d.0/0000:72:00.0/nvme/nvme1";
      "input-filename" = "temp1_input";
      "critical-threshold" = 80;
      "format-critical" = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      "format-icons" = ["🖥"];
    };

    "temperature#water" = {
      "hwmon-path-abs" = "/sys/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10.2/1-10.2.4/1-10.2.4:1.1/0003:0C70:F012.000B/hwmon";
      "input-filename" = "temp1_input";
      "critical-threshold" = 40;
      "format-critical" = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      "format-icons" = ["󰖌"];
    };
  };
  variables.waybarBattery = "ps-controller-battery-58:10:31:1d:a2:43";

  # eww sidebar settings
  variables.ewwSidebarScreens = [
    "DP-3"
    "DP-1"
  ];

  # dunst/mako settings, show on DP-1
  services.dunst.settings.global = {
    monitor = "DP-1";
    follow = lib.mkForce "none";
  };
  services.mako.settings = {
    output = "DP-1";
  };
}
