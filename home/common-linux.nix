{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./apps/hypr
    ./apps/mangohud.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
  };

  programs.waybar.enable = true;
}
