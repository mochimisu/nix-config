{
  variables.keyboardLayout = "dvorak";
  variables.hyprpanel = {
    cpuTempSensor = "/sys/class/thermal/thermal_zone0/temp";
  };

  wayland.windowManager.hyprland.settings = {
    monitor = [
      {
        output = "eDP-1";
        mode = "2880x1920@120";
        position = "0x0";
        scale = 1.5;
      }
      {
        output = "DP-2";
        mode = "3440x1440@120";
        position = "-580x-1440";
        scale = 1;
      }
    ];
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
    "fw-fan" = "sudo ectool fanduty";
    "fw-fan-auto" = "sudo ectool autofanctrl";
  };

  # custom full remapped keyboard
  
  wayland.windowManager.hyprland.settings.config.input = {
    kb_layout = "custom";
    kb_variant = "dvorak-custom";
  };
}
