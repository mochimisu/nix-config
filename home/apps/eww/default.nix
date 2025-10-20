{
  lib,
  pkgs,
  config,
  ...
}: let
  variables = config.variables or {};
  isLinuxGui = pkgs.stdenv.isLinux && (variables.isGui or true);
in {
  imports = [
    ./sidebar
  ];
  programs.eww = lib.mkIf isLinuxGui {
    enable = true;
  };
}
