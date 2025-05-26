{ config, pkgs, ... }:
{
  import = [
    ./fastfetch.nix
  ];
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:c4:00.0/hwmon/hwmon9/temp1_input";
  };
  variables.hyprpaper-config = ''
    wallpaper = DP-2, ${config.home.homeDirectory}/.config/hypr/black.png
    '';
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,2560x1600@180,0x0,1.25"
        # XReal glasses, 2048=2560/1.25
        "DP-1,1920x1080@60,2048x0,1"
      ];
    };

    "exec-once" = [
      "mangohud steam -silent"
      "heroic"
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
    ../../home/common-linux.nix
  ];

  # custom full remapped keyboard
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };
}
