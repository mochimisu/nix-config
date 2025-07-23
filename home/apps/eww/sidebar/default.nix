{
  lib,
  pkgs,
  config,
  ...
}: let
  sidebarScreens =
    if pkgs.stdenv.isLinux && builtins.hasAttr "ewwSidebarScreens" config.variables
    then config.variables.ewwSidebarScreens
    else ["0"];
  configDir = "~/.config/eww/sidebar";
  barCommands =
    lib.map (
      screen: "eww --config ${configDir} open bar_${screen}"
    )
    sidebarScreens;
  startupCommand = ''
    eww daemon --config ${configDir} && \
    ${builtins.concatStringsSep " && " barCommands}'';
  onAttachScript = "${pkgs.writeShellScriptBin "eww-on-attach" (builtins.readFile ./scripts/on-attach.sh)}/bin/eww-on-attach";
  cavaBin = "${pkgs.writeShellScriptBin "eww-cava" (builtins.readFile ./scripts/cava.sh)}/bin/eww-cava";
  networkBin = "${pkgs.writeShellScriptBin "eww-network" (builtins.readFile ./scripts/network.sh)}/bin/eww-network";
  batteryBin = "${pkgs.writeShellScriptBin "eww-battery" (builtins.readFile ./scripts/battery.sh)}/bin/eww-battery";
  audioSinksBin = "${pkgs.writeShellScriptBin "eww-audio-sinks" (builtins.readFile ./scripts/audio-sinks.sh)}/bin/eww-audio-sinks";
  volBin = "${pkgs.writeShellScriptBin "eww-volume" (builtins.readFile ./scripts/vol.sh)}/bin/eww-volume";
  toggleWindow = "EWW_CONFIG=${configDir} ${pkgs.writeShellScriptBin "eww-toggle-window" (builtins.readFile ./scripts/toggle-window.sh)}/bin/eww-toggle-window";
in {
  programs.eww = {
    enable = lib.mkIf pkgs.stdenv.isLinux true;
  };

  home.packages = with pkgs;
    lib.optionals pkgs.stdenv.isLinux [
      cava
      hyprland-workspaces
      hyprland-activewindow
      hyprland-monitor-attached
    ];

  home.file.".config/eww/sidebar/eww.yuck".source = pkgs.replaceVars ./eww.yuck {
    generatedWidgets = ''
      ; Also just define bar_0, bar_1, etc. for each screen.
      ${builtins.concatStringsSep "\n" (
        lib.map (screen: ''
          (defwindow bar_${screen}
            :exclusive true
            :monitor "${screen}"
            :windowtype "dock"
            :geometry (geometry :x "0%"
                        :y "0%"
                        :width "20px"
                        :height "100%"
                        :anchor "right center"
                        )
            (bar :monitor "${screen}"))
        '')
        sidebarScreens
      )}
    '';
    inherit cavaBin networkBin batteryBin audioSinksBin volBin toggleWindow;
    iconSize = config.variables.ewwSidebarIconSize or "16";
  };

  home.file.".config/eww/sidebar/eww.scss".source = pkgs.replaceVars ./eww.scss {
    fontSize = config.variables.ewwSidebarFontSize or "13px";
  };

  wayland.windowManager.hyprland.settings."exec-once" = [
    startupCommand
    "hyprland-monitor-attached ${onAttachScript}"
  ];
}
