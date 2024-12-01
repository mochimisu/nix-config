{
  variables.keyboardLayout = "qwerty";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/devices/pci0000:00/0000:00:08.1/0000:63:00.0/hwmon/hwmon6/temp1_input";
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
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
  };
}
