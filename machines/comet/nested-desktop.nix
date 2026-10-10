# A desktop window inside Valve's VR session, never a replacement login session.
{config, pkgs, lib, ...}: let
  terminal = pkgs.writeShellScriptBin "comet-terminal" ''
    # Native Qt must resolve its own SteamOS libraries.
    unset LD_LIBRARY_PATH QT_PLUGIN_PATH QML2_IMPORT_PATH
    unset GBM_BACKENDS_PATH LIBGL_DRIVERS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
    export QT_QPA_PLATFORM=wayland DISABLE_GAMESCOPE_WSI=1
    exec /usr/bin/konsole --separate -p tabtitle='Comet Hyprland Desktop' "$@"
  '';
  fitWindow = pkgs.writeText "comet-fit-nested-window.js" ''
    function fit(window) {
      if (window.resourceClass !== "aquamarine") return;
      window.noBorder = true;
      window.setMaximize(false, false);
      window.frameGeometry = window.output.geometry;
    }
    for (const window of workspace.windowList()) fit(window);
    workspace.windowAdded.connect(fit);
  '';
  child = pkgs.writeShellScript "comet-nested-hyprland" ''
    set -eu
    test -n "''${WAYLAND_DISPLAY:-}"
    export XDG_CONFIG_HOME="$COMET_CONFIG_HOME"
    export PATH="${terminal}/bin:$HOME/.nix-profile/bin:$PATH"
    export XDG_DATA_DIRS="$HOME/.nix-profile/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    export XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland
    # Steam's VR cursor is 256px; desktop clients need a normal local size.
    export XCURSOR_SIZE=24 HYPRCURSOR_SIZE=24
    export XCURSOR_THEME=breeze_cursors HYPRCURSOR_THEME=breeze_cursors
    export HYPRLAND_NO_SD_VARS=1 HYPRLAND_NO_SD_NOTIFY=1 HYPRLAND_NO_RT=1
    # Require Wayland nesting: no seat daemon or physical display acquisition.
    export LIBSEAT_BACKEND=seatd SEATD_SOCK="$XDG_RUNTIME_DIR/no-seatd.sock"
    export AQ_DRM_DEVICES=/dev/null
    # Use Valve's graphics stack without replacing Nix libc/libinput/Qt.
    export LD_LIBRARY_PATH="$COMET_GRAPHICS_LIB"
    export GBM_BACKENDS_PATH=/usr/lib/gbm LIBGL_DRIVERS_PATH=/usr/lib/dri
    export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
    export DISABLE_GAMESCOPE_WSI=1
    unset QT_QPA_PLATFORM
    # Wait for a mapped output before resizing. Initial forced fullscreen can
    # stall the nested backend; fitting the mapped window was verified live.
    (
      for attempt in $(${pkgs.coreutils}/bin/seq 1 100); do
        instance="$(${pkgs.hyprland}/bin/hyprctl instances -j 2>/dev/null | ${pkgs.jq}/bin/jq -r '.[0].instance // empty')"
        if [ -n "$instance" ] && ${pkgs.hyprland}/bin/hyprctl -i "$instance" monitors -j 2>/dev/null | ${pkgs.jq}/bin/jq -e 'length > 0' >/dev/null; then
          # Native Qt resolves only its own libraries; D-Bus is still private.
          unset LD_LIBRARY_PATH QT_PLUGIN_PATH QML2_IMPORT_PATH
          id="$(/usr/bin/qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript ${fitWindow} comet-fit-nested)"
          /usr/bin/qdbus6 org.kde.KWin "/Scripting/Script$id" org.kde.kwin.Script.run
          exit
        fi
        ${pkgs.coreutils}/bin/sleep 0.1
      done
      echo "Timed out waiting to fit the nested desktop" >&2
    ) &
    # Snapshot the generated config so rebuilds affect only the next launch.
    ${pkgs.coreutils}/bin/cp ${config.xdg.configHome}/hypr/hyprland.lua "$XDG_RUNTIME_DIR/hyprland.lua"
    # The official watchdog inherits this private session and graphics shim.
    # Disable its automatic nixGL wrapping; Valve's drivers are supplied above.
    exec ${pkgs.hyprland}/bin/start-hyprland --no-nixgl \
      --path ${pkgs.hyprland}/bin/Hyprland -- \
      --config "$XDG_RUNTIME_DIR/hyprland.lua"
  '';
  session = pkgs.writeShellApplication {
    name = "comet-hyprland-session";
    runtimeInputs = [pkgs.coreutils pkgs.util-linux];
    text = builtins.replaceStrings ["@child@"] ["${child}"]
      (builtins.readFile ./nested-desktop.sh);
  };
  launcher = pkgs.writeShellApplication {
    name = "comet-hyprland";
    text = ''
      case "''${1:-}" in
        --stop)
          exec /usr/bin/systemctl --user stop comet-hyprland.service
          ;;
        --test)
          exec /usr/bin/systemd-run --user --collect --service-type=exec \
            --unit=comet-hyprland --property=KillMode=control-group \
            --property=TimeoutStopSec=5 --property=RuntimeMaxSec=40 \
            ${session}/bin/comet-hyprland-session
          ;;
        "")
          exec /usr/bin/systemd-run --user --collect --service-type=exec \
            --unit=comet-hyprland --property=KillMode=control-group \
            --property=TimeoutStopSec=5 ${session}/bin/comet-hyprland-session
          ;;
        *)
          echo "Usage: comet-hyprland [--test|--stop]" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  imports = [
    ../../home/desktop.nix
    ../../home/apps/hypr/hyprpaper.nix
    ../../home/apps/hypr/hyprland.nix
    ../../home/apps/hypr/hyprland-binds-common.nix
    ../../home/apps/hypr/hyprland-binds-qwerty.nix
    ../../home/apps/hypr/hyprland-binds-dvorak.nix
  ];
  variables.nestedDesktop = true;
  variables.keyboardLayout = "qwerty";
  home.packages = [launcher terminal pkgs.hyprpaper pkgs.wl-clipboard pkgs.cliphist];
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = null;
    configType = "lua";
    systemd.enable = false;
    settings = {
      monitor = [{ output = "WAYLAND-1"; mode = "preferred"; position = "0x0"; scale = 1; }];
      config.general.allow_tearing = lib.mkForce false;
      config.input.kb_layout = "us";
      config.misc.disable_hyprland_logo = true;
      terminal._var = lib.mkForce "comet-terminal";
    };
  };
  # Never ask the shared user manager to reload a live compositor on activation.
  xdg.configFile."hypr/hyprland.lua".onChange = lib.mkForce "";
  # The already-running Steam session does not search the Nix profile's share.
  # Publish just this entry in the standard per-user discovery directory.
  xdg.dataFile."applications/comet-hyprland.desktop".source =
    "${config.home.path}/share/applications/comet-hyprland.desktop";
  # Steam's PATH omits Nix, so use an absolute command in its + menu.
  xdg.desktopEntries.comet-hyprland = {
    name = "Hyprland Desktop";
    comment = "Nested desktop in Steam Frame; Plasma remains available";
    exec = "${launcher}/bin/comet-hyprland";
    icon = "desktop";
    terminal = false;
    categories = ["Utility"];
    settings."X-Steam-Controller-Template" = "Desktop";
  };
}
