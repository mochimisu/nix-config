{ pkgs, ... }:
{
  home.packages = with pkgs; [
    walker
  ];
  wayland.windowManager.hyprland.settings = {
    "$menu" = "walker --modules applications";
    "$menuAll" = "walker";
    "exec-once" = [
      "walker --gapplication-service"
    ];
  };
}
