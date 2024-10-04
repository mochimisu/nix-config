{
  variables.keyboardLayout = "qwerty";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
      ];
    };
  };
  imports = [
    ../../home/common-linux.nix
  ];
  home.shellAliases = {
  };
}
