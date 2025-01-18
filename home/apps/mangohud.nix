{ pkgs, ... }:
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

    cpu_temp
    battery
    '';
}
