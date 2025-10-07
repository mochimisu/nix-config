{ lib, config, pkgs, ... }:

let
  # Grab everything Catppuccin exposes
  inherit (config.catppuccin) flavor accent sources;
  # `palette` now equals the colour set for your chosen flavour
  palette = (lib.importJSON "${sources.palette}/palette.json").${flavor}.colors;
in
{

  services.mako = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    
    settings =  {
      "anchor" = "top-right";
      "margin" = "10,50";                   # y,x from anchor
      "font" = "Montserrat 12";
      "background-color" = "${palette.surface0.hex}cc";
      "text-color" = palette.text.hex;
      "border-size" = 2;
      "border-radius" = 6;
      "border-color" = palette.${accent}.hex;
      "progress-color" = palette.blue.hex;
      "urgency=low" = {
        "background-color" = "${palette.surface0.hex}cc";
        "text-color" = palette.text.hex;
      };

      "urgency=critical" = {
        "background-color" = palette.red.hex;
        "text-color" = palette.crust.hex;
        "border-color" = palette.red.hex;
        "border-size" = 3;
      };
    };
  };

  # on startup
  wayland.windowManager.hyprland.settings."exec-once" = [
    "mako"
  ];
}
