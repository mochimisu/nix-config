{config, lib, pkgs, ...}: let
  p = lib.importJSON ../../../home/theme/sekai-palette.json;
  # Reuse the desktop's pinned static fallback; accessible before user login.
  wallpaper = config.home-manager.users.brandon.home.file.".config/hypr/dusk.jpg".source;
  settings = pkgs.writeText "sekai-sddm.conf" (lib.generators.toINI {} {
    General = {
      Background = toString wallpaper;
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
  environment.systemPackages = [theme];
}
