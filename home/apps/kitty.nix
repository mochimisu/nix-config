{ config, lib, pkgs, ... }:
let
  variables = config.variables or {};
  isLinuxGui = pkgs.stdenv.isLinux && (variables.isGui or true);
in {
  programs.kitty = lib.mkIf isLinuxGui {
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
