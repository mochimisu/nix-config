{
  variables.keyboardLayout = "qwerty";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,preferred,0x0,1.6,transform,3"
      ];
    };
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
  };
}
