{
  config,
  lib,
  pkgs,
  ...
}: let
  mangoHudVars = config.variables.mangohud or {};
  showCpuTemp = mangoHudVars.cpuTemp or true;
  extraConfig = mangoHudVars.extraConfig or "";
in
{
  programs.mangohud = {
    enable = true;
  };
  home.file.".config/MangoHud/MangoHud.conf".source = pkgs.writeText "MangoHud.conf" ''
    horizontal
    hud_no_margin
    font_size=16
    background_alpha=0
    toggle_hud=F8

    ${lib.optionalString showCpuTemp "cpu_temp"}
    ${extraConfig}
    battery
    '';
}
