# Native Flatpak apps and additive Steam Library registration, as on Comet.
{config, pkgs, inputs, ...}: let
  vacuumtube = pkgs.writeTextFile {
    name = "cove-vacuumtube";
    destination = "/bin/cove-vacuumtube";
    executable = true;
    text = ''#!/bin/sh
    unset LD_LIBRARY_PATH LD_PRELOAD QT_PLUGIN_PATH QML2_IMPORT_PATH
    exec 9>"''${XDG_RUNTIME_DIR:-/run/user/$UID}/cove-vacuumtube.lock"
    ${pkgs.util-linux}/bin/flock -n 9 || exit 0
    if /usr/bin/flatpak ps --columns=application | ${pkgs.gnugrep}/bin/grep -Fxq rocks.shy.VacuumTube; then
      echo "VacuumTube is already running; use its existing window."
      exit 0
    fi
    # Preserve the existing Flatpak profile and Steam's display/session variables.
    /usr/bin/flatpak run --user rocks.shy.VacuumTube "$@"
  '';
  };
  nativeFlatpak = pkgs.runCommand "steamos-flatpak" {} ''
    mkdir -p "$out/bin"
    ln -s /usr/bin/flatpak "$out/bin/flatpak"
  '';
  apps = [
    {
      key = "mpv";
      name = "mpv";
      appId = null;
      executable = "${config.home.profileDirectory}/bin/cove-mpv";
      desktop = "${config.xdg.dataHome}/applications/cove-mpv.desktop";
    }
    {
      key = "vacuumtube";
      name = "VacuumTube";
      appId = "rocks.shy.VacuumTube";
      executable = "${config.home.profileDirectory}/bin/cove-vacuumtube";
      desktop = "${config.xdg.dataHome}/applications/cove-vacuumtube.desktop";
    }
  ];
  manifest = pkgs.writeText "cove-steam-apps.json" (builtins.toJSON apps);
  python = pkgs.python3.withPackages (ps: [ps.vdf]);
  register = pkgs.writeShellScriptBin "cove-steam-apps" ''
    exec ${python}/bin/python ${../comet/steam-apps.py} ${manifest} "$@"
  '';
in {
  imports = [(args: import "${inputs.flatpaks}/modules/home-manager.nix" (args // {
    pkgs = pkgs // {flatpak = nativeFlatpak;};
  }))];
  services.flatpak = {
    enable = true;
    packages = [{appId = "rocks.shy.VacuumTube"; origin = "flathub";}];
    uninstallUnmanaged = false;
    uninstallUnused = false;
    update.onActivation = false;
    update.auto.enable = false;
    restartOnFailure.enable = false;
  };
  home.packages = [vacuumtube register];
  xdg.desktopEntries.cove-vacuumtube = {
    name = "VacuumTube";
    exec = "${config.home.profileDirectory}/bin/cove-vacuumtube";
    icon = "rocks.shy.VacuumTube";
    categories = ["AudioVideo"];
  };
  xdg.dataFile."applications/cove-vacuumtube.desktop".source =
    "${config.home.path}/share/applications/cove-vacuumtube.desktop";
}
