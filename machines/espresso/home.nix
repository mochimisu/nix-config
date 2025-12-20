{
  config,
  pkgs,
  ...
}: {
  variables.keyboardLayout = "qwerty";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:63:00.0/hwmon/hwmon6/temp1_input";
  };
  variables.ewwSidebarFontSize = "18px";
  variables.ewwSidebarIconSize = "24";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,preferred,0x0,1.6,transform,3"
      ];
    };
    input = {
      touchdevice = {
        transform = 3;
      };
    };
    "exec-once" = [
      "mangohud steam"
    ];
    plugin = {
      "touch_gestures" = {
        "hyprgrass-bind" = [
          ",swipe:3:l,exec,hyprctl dispatch workspace e-1"
          ",swipe:3:r,exec,hyprctl dispatch workspace e+1"
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
  home.shellAliases = {
  };
}
