# Player, app-local graphics drivers and remote-friendly file browser.
{config, lib, pkgs, ...}: let
  player = pkgs.mpv.override {scripts = [pkgs.mpvScripts.uosc];};
  mpv = pkgs.writeTextFile {
    name = "cove-mpv";
    destination = "/bin/cove-mpv";
    executable = true;
    text = ''#!/bin/sh
    unset LD_LIBRARY_PATH LD_PRELOAD QT_PLUGIN_PATH QML2_IMPORT_PATH
    unset VK_ICD_FILENAMES GBM_BACKENDS_PATH
    # Resolve drivers from the same Nix package set as mpv, only for this app.
    export VK_DRIVER_FILES=${pkgs.mesa}/share/vulkan/icd.d/radeon_icd.x86_64.json
    export __EGL_VENDOR_LIBRARY_FILENAMES=${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
    export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
    export LIBVA_DRIVERS_PATH=${pkgs.mesa}/lib/dri LIBVA_DRIVER_NAME=radeonsi
    # The native shell must clear Steam's preload before any Nix interpreter runs.
    case ":''${XDG_CURRENT_DESKTOP:-}:" in
      *:gamescope:*)
        # Only this app uses the matching WSI layer; SteamOS owns the compositor.
        export VK_ADD_IMPLICIT_LAYER_PATH=${pkgs.gamescope-wsi}/share/vulkan/implicit_layer.d
        export ENABLE_GAMESCOPE_WSI=1 ENABLE_HDR_WSI=1
        export GAMESCOPE_WAYLAND_DISPLAY="''${GAMESCOPE_WAYLAND_DISPLAY:-gamescope-0}"
        set -- --gpu-api=vulkan --gpu-context=x11vk --target-colorspace-hint=yes "$@"
        ;;
      *)
        # Plain RADV presentation stalls in Plasma; radeonsi + VA-API passed.
        set -- --gpu-api=opengl --target-colorspace-hint=auto "$@"
        ;;
    esac
    exec ${player}/bin/mpv --idle=yes --force-window=yes --fullscreen --hwdec=auto "$@"
  '';
  };
in {
  imports = [
    (import ../../home/mpv-browser.nix {
      directory = "${config.home.homeDirectory}/Videos";
      fallback = config.home.homeDirectory;
    })
  ];
  home.packages = [player mpv pkgs.ffmpeg];
  xdg.configFile."mpv/scripts/cove-remote.lua".source = ./remote-controls.lua;
  xdg.configFile."mpv/input.conf".text = lib.mkAfter ''
    ESC script-binding cove_remote/menu
    ENTER cycle pause
    KP_ENTER cycle pause
    LEFT seek -10 relative+exact
    RIGHT seek 10 relative+exact
    UP script-binding cove_remote/menu
    DOWN script-binding uosc/subtitles
  '';

  xdg.desktopEntries.cove-mpv = {
    name = "mpv";
    exec = "${config.home.profileDirectory}/bin/cove-mpv";
    icon = "mpv";
    categories = ["AudioVideo"];
    settings."X-Steam-Controller-Template" = "Desktop";
  };
  xdg.dataFile."applications/cove-mpv.desktop".source =
    "${config.home.path}/share/applications/cove-mpv.desktop";
}
