{ config, pkgs, ...}:
let
  turquoiseTree = builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/p9/wallhaven-p9gr2p.jpg";
    sha256 = "sha256:0xxh9v1fzf72ha9g5wrd963vrjahlh0xs25q1rwbyzw9hvl9llbv";
  };
  dusk = builtins.fetchurl {
    url = "https://w.wallhaven.cc/full/6k/wallhaven-6k1dj7.jpg";
    sha256 = "sha256:1qz2wzpc7ylhrca9r3yfrm5jf56as3lrlwhi092myg17zgmgmcbi";
  };
in
{
  home.file.".config/hypr/turqouiseTree.jpg".source = turquoiseTree;
  home.file.".config/hypr/dusk.jpg".source = dusk;
  home.file.".config/hypr/hyprpaper.conf".source = pkgs.writeText "hyprpaper.conf" ''
    preload = ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
    preload = ${config.home.homeDirectory}/.config/hypr/dusk.jpg
    wallpaper = eDP-1, ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
    wallpaper = DP-1, ${config.home.homeDirectory}/.config/hypr/dusk.jpg
    wallpaper = DP-3, ${config.home.homeDirectory}/.config/hypr/dusk.jpg
    wallpaper = HDMI-A-1, ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
    '';
}

