{lib, pkgs, config, ...}: let
  cfg = config.variables.desktopStyle.launcher;
  # An absent provider yields a neutral header; no global Skwd dependency.
  skwd = if cfg.wallpaperPackage == null then "" else "${cfg.wallpaperPackage}/bin/skwd-helm";
  configDir = "${config.xdg.configHome}/quickshell/phone-launcher";
  context = pkgs.writeScript "sekai-launcher-context" ("#!${pkgs.python3}/bin/python3\n" + builtins.replaceStrings
    ["@hyprctl@" "@skwd@"]
    ["${config.wayland.windowManager.hyprland.package}/bin/hyprctl" skwd]
    (builtins.readFile ./context.py));
  quickshell = pkgs.writeShellScript "sekai-quickshell" ''
    export QML_IMPORT_PATH="${pkgs.qt6.qtmultimedia}/lib/qt-6/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
    export QT_PLUGIN_PATH="${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
    # Qt's basic loop advances animations on a ~16 ms timer even on high-Hz outputs.
    # Keep explicit software-renderer/user overrides; do not force a refresh rate.
    if [ "''${QT_QUICK_BACKEND:-}" != software ]; then
      # Use elapsed time so 120/175 Hz output changes preserve animation duration.
      export QSG_USE_SIMPLE_ANIMATION_DRIVER="''${QSG_USE_SIMPLE_ANIMATION_DRIVER:-1}"
      export QSG_RENDER_LOOP="''${QSG_RENDER_LOOP:-threaded}"
    fi
    exec ${pkgs.quickshell}/bin/qs "$@"
  '';
  launcher = pkgs.writeShellScriptBin "sekai-launcher" (builtins.replaceStrings
    ["@qs@" "@flock@" "@config@" "@sleep@"]
    ["${quickshell}" "${pkgs.util-linux}/bin/flock" (lib.escapeShellArg configDir) "${pkgs.coreutils}/bin/sleep"]
    (builtins.readFile ./launcher.sh));
in {
  config = lib.mkIf cfg.enable {
    home.packages = [launcher];
    systemd.user.services.sekai-launcher = {
      Unit = {
        Description = "Persistent phone launcher";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${quickshell} -n -p ${lib.escapeShellArg configDir}";
        # Desktop apps launched from the phone can inherit this cgroup.
        # A launcher-only restart must not terminate those applications.
        KillMode = "process";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
    home.file = {
      ".config/quickshell/phone-launcher/Search.js".source = ./Search.js;
      ".config/quickshell/phone-launcher/Status.qml".source = ./Status.qml;
      ".config/quickshell/phone-launcher/HomeControls.qml".source = ./HomeControls.qml;
      ".config/quickshell/phone-launcher/shell.qml".source = pkgs.replaceVars ./shell.qml {inherit context;};
      ".config/quickshell/phone-launcher/Presentation.qml".source = ./Presentation.qml;
      ".config/quickshell/phone-launcher/Phone.qml".source = ./Phone.qml;
      ".config/quickshell/phone-launcher/AppDetail.qml".source = ./AppDetail.qml;
    };
    # The shared Super+Space binding invokes menu; run/clipboard menus stay Rofi.
    wayland.windowManager.hyprland.settings.menu._var = lib.mkForce "${launcher}/bin/sekai-launcher";
    wayland.windowManager.hyprland.settings.bind = [{
      _args = [
        "SUPER + ALT + space"
        (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${launcher}/bin/sekai-launcher")'')
      ];
    }];
  };
}
