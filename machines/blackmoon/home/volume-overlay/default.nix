{config, pkgs, lib, ...}: let
  configDir = "${config.xdg.configHome}/quickshell/volume-overlay";
  hook = pkgs.writeScript "sekai-volume-notification" ("#!${pkgs.python3}/bin/python3\n" + builtins.replaceStrings
    ["@makoctl@" "@hyprctl@" "@qs@" "@config@"]
    ["${pkgs.mako}/bin/makoctl" "${config.wayland.windowManager.hyprland.package}/bin/hyprctl" "${pkgs.quickshell}/bin/qs" configDir]
    (builtins.readFile ./notify.py));
in {
  config = lib.mkIf config.variables.desktopStyle.mediaFeedback.enable {
    xdg.configFile."quickshell/volume-overlay/shell.qml".source = pkgs.replaceVars ./shell.qml {
      paletteJson = builtins.readFile ../../../../home/theme/app-palette.json;
    };
    xdg.configFile."quickshell/volume-overlay/notify.py".source = hook;
    # Keep the existing media client and its synchronous replacement semantics.
    # Error messages do not match and remain ordinary, readable notifications.
    services.mako.settings."category=sekai.volume summary~=\"^Volume · ([0-9]+%|muted)$\"" = {
      invisible = true;
      on-notify = "exec ${configDir}/notify.py \"$id\"";
    };
    systemd.user.services.sekai-volume-overlay = {
      Unit = {
        Description = "Blackmoon volume sparkle overlay";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs -n -p ${lib.escapeShellArg configDir}";
        Restart = "on-failure";
        RestartSec = 1;
        Environment = ["QSG_USE_SIMPLE_ANIMATION_DRIVER=1" "QSG_RENDER_LOOP=threaded"];
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
