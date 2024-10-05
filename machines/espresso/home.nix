{
  variables.keyboardLayout = "qwerty";
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
    general = {
      allow_tearing = "true";
    };
    misc = {
      vfr = "true";
    };
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
  };
}
