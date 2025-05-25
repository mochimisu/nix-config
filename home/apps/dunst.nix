{ config, lib, pkgs, ... }:
let
  inherit (config.catppuccin) flavor accent sources;
  palette = (lib.importJSON "${sources.palette}/palette.json").${flavor}.colors;
in
{
  services.dunst = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    follow = "mouse";
    settings = {
      global = {
        font               = "Montserrat 12";
        frame_width        = 2;
        frame_color        = palette.${accent}.hex;
        separator_height   = 2;
        separator_color    = "frame";
        padding            = 16;
        horizontal_padding = 20;
        offset             = "10x50";
        origin             = "top-right";
        transparency       = 12;
        corner_radius      = 6;
      };

      urgency_low = {
        background = palette.surface0.hex;
        foreground = palette.text.hex;
        timeout    = 6;
      };

      urgency_normal = {
        background = palette.surface1.hex;
        foreground = palette.text.hex;
        frame_color = palette.blue.hex;
        timeout     = 10;
      };

      urgency_critical = {
        background  = palette.red.hex;
        foreground  = palette.crust.hex;
        frame_color = palette.red.hex;
        timeout     = 0;
      };
    };
  };

  # on startup
  wayland.windowManager.hyprland.settings."exec-once" = [
    "dunst"
  ];
}
