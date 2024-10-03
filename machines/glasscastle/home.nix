{
  variables.keyboardLayout = "dvorak";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,2880x1920@120,0x0,1.5"
        "DP-2,3440x1440@120,-580x-1440,1"
      ];
    };
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
    "fw-fan" = "sudo ectool fanduty";
    "fw-fan-auto" = "sudo ectool autofanctrl";
  };
}
