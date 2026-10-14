{lib, pkgs, osConfig ? null, ...}: let
  enabled = osConfig != null && (osConfig.networking.hostName or "") == "blackmoon";
  launcher = pkgs.writeShellScriptBin "sekai-launcher" (builtins.replaceStrings
    ["@qs@" "@flock@" "@config@"]
    ["${pkgs.quickshell}/bin/qs" "${pkgs.util-linux}/bin/flock" "${./.}"]
    (builtins.readFile ./launcher.sh));
in {
  config = lib.mkIf enabled {
    home.packages = [launcher];
    home.file = {
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
