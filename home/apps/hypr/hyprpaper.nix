{ config, pkgs, ...}:
let
  wallpaperImage = builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/p9/wallhaven-p9gr2p.jpg";
    sha256 = "sha256:0xxh9v1fzf72ha9g5wrd963vrjahlh0xs25q1rwbyzw9hvl9llbv";
  };
in
{
  home.file.".config/hypr/wallpaper.jpg".source = wallpaperImage;
  home.file.".config/hypr/hyprpaper.conf".source = pkgs.writeText "hyprpaper.conf" ''
    preload = ${config.home.homeDirectory}/.config/hypr/wallpaper.jpg
    wallpaper = eDP-1, ${config.home.homeDirectory}/.config/hypr/wallpaper.jpg
    '';
}

