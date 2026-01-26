{
  ...
}: {
  variables.keyboardLayout = "qwerty";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:63:00.0/hwmon/hwmon6/temp1_input";
  };
  variables.ewwSidebarFontSize = "18px";
  variables.ewwSidebarIconSize = "24";
  variables.touchscreen = {
    enable = true;
    enableHyprgrass = true;
    enableScroll = true;
    onScreenKeyboard = false;
  };
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
    gesture = [
      "3, left, dispatcher, workspace, e-1"
      "3, right, dispatcher, workspace, e+1"
    ];
  };
  imports = [
    ../../home/common-linux.nix
    ../../home/apps/touchscreen.nix
  ];
  home.shellAliases = {
  };
}
