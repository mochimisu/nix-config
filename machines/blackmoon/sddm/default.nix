{lib, pkgs, ...}: let
  rotateDisplays = pkgs.writeScript "blackmoon-sddm-displays" ("#!${pkgs.python3}/bin/python3\n" +
    builtins.replaceStrings ["@xrandr@"] ["${pkgs.xrandr}/bin/xrandr"]
      (builtins.readFile ./rotate-displays.py));
  p = lib.importJSON ../../../home/theme/sekai-palette.json;
  settings = pkgs.writeText "sekai-sddm.conf" (lib.generators.toINI {} {
    General = {
      Font = "Montserrat";
      Ink = p.ink; Muted = p.muted; Surface = p.surface;
      Mint = p.mint; Lavender = p.lavender; Pink = p.pink; Urgent = p.urgent;
    };
  });
  theme = pkgs.runCommand "sddm-sekai-blackmoon" {} ''
    mkdir -p $out/share/sddm/themes/sekai-blackmoon
    cp ${./Main.qml} $out/share/sddm/themes/sekai-blackmoon/Main.qml
    cp ${./metadata.desktop} $out/share/sddm/themes/sekai-blackmoon/metadata.desktop
    cp ${settings} $out/share/sddm/themes/sekai-blackmoon/theme.conf
  '';
in {
  # Host import is the opt-in. No authentication or display-server changes.
  catppuccin.sddm.enable = false;
  services.displayManager.sddm.theme = "sekai-blackmoon";
  # Runs only when the X11 greeter starts; never rotates the Wayland session.
  services.xserver.displayManager.setupCommands = lib.mkAfter ''
    ${rotateDisplays}
  '';
  environment.systemPackages = [theme];
}
