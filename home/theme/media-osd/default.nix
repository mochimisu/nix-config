{pkgs}: pkgs.writeShellApplication {
  name = "sekai-media-osd";
  runtimeInputs = [pkgs.wireplumber pkgs.brightnessctl pkgs.libnotify pkgs.gawk pkgs.gnugrep pkgs.util-linux];
  text = builtins.replaceStrings ["@icons@"] ["${./icons}"] (builtins.readFile ./media-osd.sh);
}
