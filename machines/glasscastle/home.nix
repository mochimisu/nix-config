{
  variables.keyboardLayout = "dvorak";
  wayland.windowManager.hyprland.settings = {
    monitors = {
      monitor = "eDP-1,2880x1920x120,0x0,1.5";
    };
  };
  # move these to common nix
  wayland.windowManager.hyprland.enable = true;
  programs.waybar.enable = true;
}
