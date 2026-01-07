{ config, pkgs, variables, ...}:
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
  imports = [ ../../../vars.nix ];

  home.file.".config/hypr/turquoiseTree.jpg".source = turquoiseTree;
  home.file.".config/hypr/dusk.jpg".source = dusk;
  home.file.".config/hypr/black.png".source = ./black.png;
  home.file.".config/hypr/hyprpaper.conf".source = pkgs.writeText "hyprpaper.conf" ''
    wallpaper {
      monitor = eDP-1
      path = ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
    }
    wallpaper {
      monitor = DP-1
      path = ${config.home.homeDirectory}/.config/hypr/dusk.jpg
    }
    wallpaper {
      monitor = DP-3
      path = ${config.home.homeDirectory}/.config/hypr/dusk.jpg
    }
    wallpaper {
      monitor = HDMI-A-1
      path = ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
    }
    ${variables.hyprpaper-config or ""}
    '';
}
