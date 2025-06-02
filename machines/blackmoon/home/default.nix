{ pkgs, config, lib, ... }:
let
  moonWallpaper =  builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/l8/wallhaven-l8mlyy.jpg";
    sha256 = "sha256:1571r0sz1qfz9xdqqkbpzfx8wx22azrhmsmdj14km427qcyiiap6";
  };
in
{
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    hiddenMonitors = ["0"];
    cpuTempSensor = "/dev/highflow_next/temp1_input";
  };
  home.file.".config/hypr/moon.jpg".source = moonWallpaper;
  variables.hyprpaper-config = ''
    preload = ${config.home.homeDirectory}/.config/hypr/moon.jpg
    wallpaper = DP-3, ${config.home.homeDirectory}/.config/hypr/moon.jpg
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
        "DP-1,2560x1440@120,-2560x0,1"
        "DP-3,3440x1440@175,0x0,1"
        "HDMI-A-1,480x1920@60,3440x1400,1,transform,1"
      ];
      workspace = [
        "1, monitor:DP-3, default:true"
        "2, monitor:DP-1, default:true"
        "3, monitor:DP-3, default:true"
        "10, monitor:HDMI-A-1, default:true"
      ];
      defaultwindows = {
        windowrule = [
          "workspace 2 silent, class:^(steam)$"
          "workspace 2 silent, class:^(discord)$"
          "workspace 2 silent, class:^(vesktop)$"
          "renderunfocused, class:^(Monster Hunter Wilds)$"
          "monitor DP-3 tile, class:^(ffxiv_dx11.exe)$" 
        ];
      };
    };

    input = {
      kb_layout = "us,us";
      kb_variant = "dvorak,";
    };

    "exec-once" = [
      # "discordcanary"
      "vesktop"
      # set DP-3 as primary
      "wlr-randr --output DP-3 --primary"
      # todo moon profile
      "openrgb --profile /home/brandon/.config/OpenRGB/moon.orp"
      "mangohud steam -silent"
      "mangohud heroic"
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

    debug = {
      # whole screen is re-rendered every frame, but reduces flickering
      damage_tracking = 0;
    };

    opengl = {
      nvidia_anti_flicker = 0;
    };
    render = {
      # both needed to be disabled to prevent stutter frames in ff14
      explicit_sync = 0;
      explicit_sync_kms = 0;
    };
    misc = {
      # potentially reducing flicker in electron apps
      # vrr = "0";
      # vfr = "0" means every single frame is rendered, not great
      # but allows nvidia_anti_flicker to be set to 0
      # vfr = 0;
    };
    cursor = {
      default_monitor= "DP-1";
    };
    bind = [
      "$mod, F2, exec, ~/.config/hypr/gamemode2.sh"
      ", mouse:275, exec, pactl set-source-mute @DEFAULT_SOURCE@ 0"
    ];
    bindr = [
      ", mouse:275, exec, pactl set-source-mute @DEFAULT_SOURCE@ 1"
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
          keyword monitor DP-1,2560x1440@120,-3000x0,1;\
          keyword monitor DP-3,3440x1440@175,0x0,1;\
          keyword monitor HDMI-A-1,480x1920@60,4000x1200,2,transform,1"
      exit
  fi
  hyprctl reload
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
      "format-icons" = [ "🖥" ];
    };

    "temperature#water" = {
      "hwmon-path-abs" = "/sys/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10.2/1-10.2.4/1-10.2.4:1.1/0003:0C70:F012.000B/hwmon";
      "input-filename" = "temp1_input";
      "critical-threshold" = 40;
      "format-critical" = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      "format-icons" = [ "󰖌" ];
    };
  };
  variables.waybarBattery = "ps-controller-battery-58:10:31:1d:a2:43";

  # dunst/mako settings, show on DP-1
  services.dunst.settings.global = {
    monitor = "DP-1";
    follow = lib.mkForce "none";
  };
  services.mako.settings = {
    output = "DP-1";
  };
    
}
