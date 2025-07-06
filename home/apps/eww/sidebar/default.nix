{
  lib,
  pkgs,
  config,
  ...
}: let
  sidebarScreens =
    if builtins.hasAttr "ewwSidebarScreens" config.variables
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
  toggleWindow = "EWW_CONFIG=${configDir} ${pkgs.writeShellScriptBin "eww-toggle-window" (builtins.readFile ./scripts/toggle-window.sh)}/bin/eww-toggle-window";
in {
  programs.eww = {
    enable = true;
  };

  home.packages = with pkgs; [
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
    inherit cavaBin networkBin batteryBin audioSinksBin toggleWindow;
    # Variables that should be not replaced
    DEFAULT_AUDIO_SINK = null;
  };

  home.file.".config/eww/sidebar/eww.scss".source = pkgs.replaceVars ./eww.scss {};

  wayland.windowManager.hyprland.settings."exec-once" = [
    startupCommand
    "hyprland-monitor-attached ${onAttachScript}"
  ];
}
