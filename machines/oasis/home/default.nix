{
  config,
  pkgs,
  ...
}: {
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:c4:00.0/hwmon/hwmon9/temp1_input";
  };
  variables.hyprpaper-config = ''
    wallpaper {
      monitor = DP-2
      path = ${config.home.homeDirectory}/.config/hypr/black.png
    }
  '';
  variables.ewwSidebarFontSize = "24px";
  variables.ewwSidebarIconSize = "32";
  variables.ewwSidebarScreens = [
    "eDP-1"
    "DP-1"
  ];
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,2560x1600@180,0x0,1.25"
        # XReal glasses, 2048=2560/1.25
        "DP-1,1920x1080@120,2048x0,1"
      ];
    };

    bind = [
      "$mod, F2, exec, ~/.config/hypr/xreal-toggle.sh"
    ];

    "exec-once" = [
      "mangohud steam -silent"
      "iio-hyprland"
      "protonvpn-app"
    ];

    plugin = {
      "touch_gestures" = {
        "hyprgrass-bind" = [
          ",swipe:4:d,exec,pkill wvkbd-mobintl"
          ",swipe:4:u,exec,wvkbd-mobintl -L 300"
        ];
      };
    };
  };
  wayland.windowManager.hyprland.plugins = [
    pkgs.hyprlandPlugins.hyprgrass
  ];

  imports = [
    ../../../home/common-linux.nix
    ./fastfetch.nix
  ];

  # custom full remapped keyboard
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };

  home.file.".config/hypr/xreal-toggle.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      set -eu

      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/xreal-main-active"

      if [ -f "''${STATE_FILE}" ]; then
        hyprctl --batch "keyword monitor eDP-1,2560x1600@180,0x0,1.25; keyword monitor DP-1,1920x1080@120,2048x0,1"
        rm -f "''${STATE_FILE}"
        exit 0
      fi

      hyprctl --batch "keyword monitor DP-1,1920x1080@120,0x0,1; keyword monitor eDP-1,2560x1600@180,1920x0,1.25"
      touch "''${STATE_FILE}"
    '';
  };
}
