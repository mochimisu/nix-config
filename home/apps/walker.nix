{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    walker
  ];
  wayland.windowManager.hyprland.settings = {
    menu._var = lib.mkForce "walker --modules applications";
    menuAll._var = lib.mkForce "walker";
    on = [
      {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("walker --gapplication-service")
            end
          '')
        ];
      }
    ];
  };
}
