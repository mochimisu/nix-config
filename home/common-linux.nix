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
    configType = "lua";
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  };

  programs.waybar.enable = true;
}
