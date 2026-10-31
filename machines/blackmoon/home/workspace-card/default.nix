{config, pkgs, lib, osConfig, ...}: let
  configDir = "${config.xdg.configHome}/quickshell/workspace-card";
  runner = pkgs.writeShellScript "sekai-workspace-card" ''
    if [ "''${QT_QUICK_BACKEND:-}" != software ]; then
      export QSG_USE_SIMPLE_ANIMATION_DRIVER="''${QSG_USE_SIMPLE_ANIMATION_DRIVER:-1}"
      export QSG_RENDER_LOOP="''${QSG_RENDER_LOOP:-threaded}"
    fi
    exec ${pkgs.quickshell}/bin/qs -n -p ${lib.escapeShellArg configDir}
  '';
in {
  xdg.configFile."quickshell/workspace-card/shell.qml".source = pkgs.replaceVars ./shell.qml {
    hostnameJson = builtins.toJSON (lib.toUpper osConfig.networking.hostName);
    paletteJson = builtins.readFile ../../../../home/theme/sekai-palette.json;
  };
  # QML owns the full entrance/exit; avoid a second compositor fade and ghost tail.
  wayland.windowManager.hyprland.settings.layer_rule = [{
    name = "sekai-workspace-card-motion";
    match.namespace = "^sekai-workspace-card$";
    no_anim = true;
  }];
  systemd.user.services.sekai-workspace-card = {
    Unit = {
      Description = "Sekai workspace title cards";
      After = ["graphical-session-pre.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${runner}";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
