{config, lib, pkgs, ...}: let
  p = lib.importJSON ../../home/theme/sekai-palette.json;
  settings = pkgs.writeText "sekai-sddm.conf" (lib.generators.toINI {} {
    General = {
      Font = "Montserrat";
      HostName = lib.toUpper config.networking.hostName;
      VirtualKeyboardEnabled = if config.variables.touchscreen.sddmKeyboard then "true" else "false";
      Ink = p.ink; Muted = p.muted; Surface = p.surface;
      Mint = p.mint; Lavender = p.lavender; Pink = p.pink; Urgent = p.urgent;
    };
  });
  theme = pkgs.runCommand "sddm-sekai-blackmoon" {} ''
    mkdir -p $out/share/sddm/themes/sekai-blackmoon
    cp ${./sddm/Main.qml} $out/share/sddm/themes/sekai-blackmoon/Main.qml
    cp ${./sddm/metadata.desktop} $out/share/sddm/themes/sekai-blackmoon/metadata.desktop
    cp ${./sddm/VirtualKeyboard.qml} $out/share/sddm/themes/sekai-blackmoon/VirtualKeyboard.qml
    cp ${settings} $out/share/sddm/themes/sekai-blackmoon/theme.conf
  '';
in {
  config = lib.mkIf config.desktopStyle.greeter.enable {
    catppuccin.sddm.enable = false;
    services.displayManager.sddm.theme = "sekai-blackmoon";
    environment.systemPackages = [theme];
  };
}
