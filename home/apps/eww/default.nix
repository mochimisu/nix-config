{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./sidebar.nix
  ];
  programs.eww = {
    enable = true;
  };
}
