{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./sidebar
  ];
  programs.eww = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
  };
}
