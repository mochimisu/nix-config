{
  lib,
  pkgs,
  config,
  ...
}: let
  isGui = config.variables.isGui or true;
in {
  imports = [
    ./sidebar
  ];
  programs.eww = lib.mkIf (pkgs.stdenv.isLinux && isGui) {
    enable = true;
  };
}
