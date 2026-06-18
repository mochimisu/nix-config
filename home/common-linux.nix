{
  osConfig,
  ...
}: {
  imports = [
    ./apps/hypr
    ./apps/mangohud.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    package = osConfig.programs.hyprland.package;
  };

  programs.waybar.enable = true;
}
