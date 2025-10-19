{ config, lib, ... }:
let
  isGui = config.variables.isGui or true;
in {
  programs.kitty = lib.mkIf isGui {
    enable = true;
    font = {
      name = "Cascadia Code";
      size = 10;
    };
    settings = {
      background_opacity = 0.6;
    };
  };
}
