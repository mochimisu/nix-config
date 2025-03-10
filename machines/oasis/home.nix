{
  variables.keyboardLayout = "dvorak";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = [
        "eDP-1,2560x1600@180,0x0,1.25"
      ];
    };
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
