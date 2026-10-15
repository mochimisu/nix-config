{lib, pkgs, config, osConfig ? null, ...}: let
  enabled = osConfig != null && (osConfig.networking.hostName or "") == "blackmoon";
  configDir = "${config.xdg.configHome}/quickshell/phone-launcher";
  launcher = pkgs.writeShellScriptBin "sekai-launcher" (builtins.replaceStrings
    ["@qs@" "@flock@" "@config@" "@sleep@"]
    ["${pkgs.quickshell}/bin/qs" "${pkgs.util-linux}/bin/flock" (lib.escapeShellArg configDir) "${pkgs.coreutils}/bin/sleep"]
    (builtins.readFile ./launcher.sh));
in {
  config = lib.mkIf enabled {
    home.packages = [launcher];
    systemd.user.services.sekai-launcher = {
      Unit = {
        Description = "Persistent phone launcher";
        After = ["graphical-session-pre.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs -n -p ${lib.escapeShellArg configDir}";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
    home.file = {
      ".config/quickshell/phone-launcher/Search.js".source = ./Search.js;
      ".config/quickshell/phone-launcher/Status.qml".source = ./Status.qml;
      ".config/quickshell/phone-launcher/HomeControls.qml".source = ./HomeControls.qml;
      ".config/quickshell/phone-launcher/shell.qml".source = ./shell.qml;
      ".config/quickshell/phone-launcher/Presentation.qml".source = ./Presentation.qml;
      ".config/quickshell/phone-launcher/Phone.qml".source = ./Phone.qml;
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
