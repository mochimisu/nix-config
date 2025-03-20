{
  imports = [
    ./apps/hypr
    ./apps/mangohud.nix
  ];
  wayland.windowManager.hyprland.enable = true;
  programs.waybar.enable = true;
}
