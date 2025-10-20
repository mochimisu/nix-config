{
  lib,
  pkgs,
  config,
  ...
}: let
  variables = config.variables or {};
  isLinuxGui = pkgs.stdenv.isLinux && (variables.isGui or true);
  sidebarScreens =
    if pkgs.stdenv.isLinux && builtins.hasAttr "ewwSidebarScreens" variables
    then variables.ewwSidebarScreens
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
  clockBin = "${pkgs.writeShellScriptBin "eww-clock" (builtins.readFile ./scripts/clock.sh)}/bin/eww-clock";
  networkBin = "${pkgs.writeShellScriptBin "eww-network" (builtins.readFile ./scripts/network.sh)}/bin/eww-network";
  batteryBin = "${pkgs.writeShellScriptBin "eww-battery" (builtins.readFile ./scripts/battery.sh)}/bin/eww-battery";
  bluetoothBin = "${pkgs.writeShellScriptBin "eww-bluetooth" (builtins.readFile ./scripts/bluetooth.sh)}/bin/eww-bluetooth";
  audioSinksBin = "${pkgs.writeShellScriptBin "eww-audio-sinks" (builtins.readFile ./scripts/audio-sinks.sh)}/bin/eww-audio-sinks";
  volBin = "${pkgs.writeShellScriptBin "eww-volume" (builtins.readFile ./scripts/vol.sh)}/bin/eww-volume";
  toggleWindow = "EWW_CONFIG=${configDir} ${pkgs.writeShellScriptBin "eww-toggle-window" (builtins.readFile ./scripts/toggle-window.sh)}/bin/eww-toggle-window";
in {
  programs.eww.enable = isLinuxGui;

  home = lib.mkIf isLinuxGui {
    packages = with pkgs; [
      cava
      hyprland-workspaces
      hyprland-activewindow
      hyprland-monitor-attached
    ];

    file = {
      ".config/eww/sidebar/eww.yuck".source = pkgs.replaceVars ./eww.yuck {
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
        inherit cavaBin clockBin networkBin batteryBin bluetoothBin audioSinksBin volBin toggleWindow;
        iconSize = variables.ewwSidebarIconSize or "16";
      };

      ".config/eww/sidebar/eww.scss".source = pkgs.replaceVars ./eww.scss {
        fontSize = variables.ewwSidebarFontSize or "13px";
      };
    };
  };

  wayland.windowManager.hyprland = lib.mkIf isLinuxGui {
    settings."exec-once" = [
      startupCommand
      "hyprland-monitor-attached ${onAttachScript}"
    ];
  };
}
