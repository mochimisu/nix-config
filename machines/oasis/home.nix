{ config, ... }:
{
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
        # XReal glasses
        "DP-2,1920x1080@60,2560x0,1"
      ];
    };

    "exec-once" = [
      "mangohud steam -silent"
      "heroic"
    ];
  };
  imports = [
    ../../home/common-linux.nix
  ];

  # custom full remapped keyboard
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };
}
