{lib, pkgs, ...}: let
  rotateDisplays = pkgs.writeScript "blackmoon-sddm-displays" ("#!${pkgs.python3}/bin/python3\n" +
    builtins.replaceStrings ["@xrandr@"] ["${pkgs.xrandr}/bin/xrandr"]
      (builtins.readFile ./rotate-displays.py));
in {
  # Physical EDIDs and rotation are Blackmoon-only, independent of shared appearance.
  services.xserver.displayManager.setupCommands = lib.mkAfter ''
    ${rotateDisplays}
  '';
}
