{pkgs, ...}: let
  palette = builtins.fromJSON (builtins.readFile ../../../home/theme/app-palette.json);
  hex = builtins.substring 1 6;
  theme = pkgs.runCommand "blackmoon-grub-theme" {
    nativeBuildInputs = [pkgs.python3];
  } ''
    python ${./build-theme.py} ${../../../home/theme/app-palette.json} ${./theme.txt} $out
  '';
in {
  # Only imported by Blackmoon. Keep the shared loader/recovery policy intact.
  catppuccin.grub.enable = false;
  catppuccin.tty.enable = false;
  boot.loader.grub = {
    inherit theme;
    splashImage = "${theme}/background.png";
    backgroundColor = palette.background;
  };

  # Linux virtual consoles have a fixed 16-color palette. Preserve the current
  # keyboard map, kernel font and diagnostic verbosity; colors apply in initrd
  # too through NixOS's generated vt.default_* kernel arguments.
  console.colors = map hex [
    palette.background palette.red "#a4c49a" "#d9c28f"
    "#91b6cf" palette.lavender palette.teal palette.text
    palette.raised "#ff9cab" "#bddbb3" "#efdab0"
    "#b2d0e4" "#d0c7ec" "#8fded7" palette.text
  ];
}
