{lib, pkgs, osConfig ? null, ...}: let
  enabled = osConfig != null && (osConfig.networking.hostName or "") == "blackmoon";
  launcher = pkgs.writeShellScriptBin "sekai-launcher" ''
    exec ${pkgs.quickshell}/bin/qs -n -c phone-launcher
  '';
in {
  config = lib.mkIf enabled {
    home.packages = [launcher];
    home.file = {
      ".config/quickshell/phone-launcher/shell.qml".source = ./shell.qml;
      ".config/quickshell/phone-launcher/Presentation.qml".source = ./Presentation.qml;
      ".config/quickshell/phone-launcher/Phone.qml".source = ./Phone.qml;
    };
    # Keep Super+Space and Super+Shift+Space on Rofi during the trial.
    wayland.windowManager.hyprland.settings.bind = [{
      _args = [
        "SUPER + ALT + space"
        (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${launcher}/bin/sekai-launcher")'')
      ];
    }];
  };
}
