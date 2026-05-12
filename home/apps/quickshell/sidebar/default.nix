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

  pttStateFile = variables.ewwPttStateFile or "";

  mkScript = name: path:
    "${pkgs.writeShellScriptBin name (builtins.readFile path)}/bin/${name}";

  workspacesBin = mkScript "qs-workspaces" ./scripts/workspaces.sh;
  windowsBin = mkScript "qs-windows" ./scripts/windows.sh;

  clockBin = mkScript "qs-clock" ../../eww/sidebar/scripts/clock.sh;
  networkBin = mkScript "qs-network" ../../eww/sidebar/scripts/network.sh;
  batteryBin = mkScript "qs-battery" ../../eww/sidebar/scripts/battery.sh;
  audioSinksBin = mkScript "qs-audio-sinks" ../../eww/sidebar/scripts/audio-sinks.sh;
  volBin = mkScript "qs-volume" ../../eww/sidebar/scripts/vol.sh;
  cavaBin = mkScript "qs-cava" ../../eww/sidebar/scripts/cava.sh;
  qwertyBin = mkScript "qs-qwerty" ../../eww/sidebar/scripts/qwerty.sh;

  qwertyWatchBin =
    "${pkgs.writeShellScriptBin "qs-qwerty-watch" (pkgs.replaceVars ./scripts/qwerty-watch.sh {
      inherit qwertyBin;
    })}/bin/qs-qwerty-watch";

  pttWatchBin =
    "${pkgs.writeShellScriptBin "qs-ptt-watch" (pkgs.replaceVars ./scripts/ptt-watch.sh {
      inherit pttStateFile;
    })}/bin/qs-ptt-watch";

  namedSidebarScreens = builtins.filter (screen: builtins.match "[0-9]+" screen == null) sidebarScreens;
  requiredScreensJson = builtins.toJSON namedSidebarScreens;
  hyprctlBin = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  startupScript = pkgs.writeShellScript "quickshell-sidebar-start" ''
    set -eu

    required='${requiredScreensJson}'
    i=0
    while [ "$i" -lt 100 ]; do
      monitors="$(${hyprctlBin} -j monitors 2>/dev/null || echo '[]')"
      if printf '%s\n' "$monitors" | ${pkgs.jq}/bin/jq -e --argjson required "$required" '
        ($required | length) == 0 or
        ([.[].name] as $names | all($required[]; . as $requiredName | $names | index($requiredName)))
      ' >/dev/null; then
        break
      fi
      i=$((i + 1))
      sleep 0.1
    done

    exec ${pkgs.quickshell}/bin/qs -n -d -c sidebar
  '';
  startupCommand = "${startupScript}";
in {
  home = lib.mkIf isLinuxGui {
    packages = with pkgs; [
      quickshell
      cava
      jq
      hyprland-workspaces
      hyprland-activewindow
    ];

    file = {
      ".config/quickshell/sidebar/shell.qml".source = pkgs.replaceVars ./shell.qml {
        sidebarScreensJson = builtins.toJSON sidebarScreens;
        fontSize = variables.ewwSidebarFontSize or "13px";
        iconSize = variables.ewwSidebarIconSize or "16";
        inherit pttStateFile;

        inherit workspacesBin windowsBin;
        inherit clockBin networkBin batteryBin audioSinksBin;
        inherit volBin cavaBin qwertyWatchBin pttWatchBin;
      };
    };
  };

  wayland.windowManager.hyprland = lib.mkIf isLinuxGui {
    settings."exec-once" = lib.mkAfter [
      startupCommand
    ];
  };
}
