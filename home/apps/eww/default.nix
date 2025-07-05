{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./sidebar
  ];
  programs.eww = {
    enable = true;
  };
}
