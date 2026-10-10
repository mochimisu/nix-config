# One small Comet app declaration: packages, desktop entries and Steam requests.
{config, lib, pkgs, inputs, ...}: let
  travelMode = pkgs.writeShellScriptBin "comet-travel-mode" ''
    unset LD_LIBRARY_PATH LD_PRELOAD QT_PLUGIN_PATH QML2_IMPORT_PATH
    exec ${pkgs.python3.withPackages (ps: [ps.tkinter])}/bin/python3 ${./travel-mode.py} --client-source ${./caffeine.py} "$@"
  '';
  apps = {
    travel = {
      name = "Travel Mode";
      package = travelMode;
      binary = "comet-travel-mode";
      desktopId = "comet-travel-mode";
      icon = "preferences-system";
    };
    chromium = {
      name = "Chromium";
      package = pkgs.chromium.override {enableWideVine = true;};
      binary = "chromium";
      desktopId = "chromium-browser";
      icon = "chromium";
      cleanEnvironment = true;
    };
    vacuumtube = {name = "VacuumTube"; flatpakAppId = "rocks.shy.VacuumTube";};
    kodi = {name = "Kodi"; flatpakAppId = "tv.kodi.Kodi";};
    hyprland = {
      name = "Hyprland Desktop";
      command = "${config.home.profileDirectory}/bin/comet-hyprland";
      desktopId = "comet-hyprland";
      icon = "desktop";
    };
    # For a Nix app: vlc = {name = "VLC"; package = pkgs.vlc; binary = "vlc";};
  };
  launcherPath = key: "${config.home.homeDirectory}/.local/bin/comet-apps/${key}";
  desktopId = key: app: app.desktopId or (app.flatpakAppId or "comet-media-${key}");
  command = app:
    if app ? flatpakAppId then ["/usr/bin/flatpak" "run" "--user" app.flatpakAppId]
    else if app ? package then ["${app.package}/bin/${app.binary or (lib.getName app.package)}"]
    else [app.command];
  nativeFlatpak = pkgs.runCommand "steamos-flatpak" {} ''
    mkdir -p "$out/bin"
    ln -s /usr/bin/flatpak "$out/bin/flatpak"
  '';
  python = pkgs.python3.withPackages (ps: [ps.vdf]);
  manifest = pkgs.writeText "comet-steam-apps.json" (builtins.toJSON (
    lib.mapAttrsToList (key: app: {
      inherit key;
      inherit (app) name;
      appId = app.flatpakAppId or null;
      executable = launcherPath key;
      desktop = "${config.xdg.dataHome}/applications/${desktopId key app}.desktop";
    }) apps
  ));
  register = pkgs.writeShellScriptBin "comet-steam-apps" ''
    exec ${python}/bin/python ${./steam-apps.py} ${manifest} "$@"
  '';
in {
  imports = [(args: import "${inputs.flatpaks}/modules/home-manager.nix" (args // {
    pkgs = pkgs // {flatpak = nativeFlatpak;};
  }))];
  assertions = lib.mapAttrsToList (key: app: {
    assertion = builtins.length (builtins.filter (field: builtins.hasAttr field app) ["flatpakAppId" "package" "command"]) == 1;
    message = "Comet app ${key} must specify exactly one of flatpakAppId, package or command.";
  }) apps;
  services.flatpak = {
    enable = true;
    packages = map (app: {appId = app.flatpakAppId; origin = "flathub";})
      (builtins.filter (app: app ? flatpakAppId) (builtins.attrValues apps));
    uninstallUnmanaged = false;
    uninstallUnused = false;
    update.onActivation = false;
    update.auto.enable = false;
    restartOnFailure.enable = false;
  };
  home.packages = [register] ++ map (app: app.package)
    (builtins.filter (app: app ? package) (builtins.attrValues apps));
  home.file = lib.mapAttrs' (key: app: lib.nameValuePair ".local/bin/comet-apps/${key}" {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      ${lib.optionalString (app.cleanEnvironment or false) ''
        # Steam's bundled libraries must not shadow the Nix application's ones.
        unset LD_LIBRARY_PATH LD_PRELOAD QT_PLUGIN_PATH QML2_IMPORT_PATH
      ''}
      ${lib.optionalString (key == "vacuumtube") ''
        # The installed app has no singleton lock. Two Electron instances can
        # contend for the same persistent browser profile. Keep one + launch.
        exec 9>"''${XDG_RUNTIME_DIR:-/run/user/$UID}/comet-vacuumtube.lock"
        ${pkgs.util-linux}/bin/flock -n 9 || exit 0
        if /usr/bin/flatpak ps --columns=application | ${pkgs.gnugrep}/bin/grep -Fxq rocks.shy.VacuumTube; then
          echo "VacuumTube is already running; use its existing window."
          exit 0
        fi
      ''}
      ${if key == "vacuumtube" then ''
        ${pkgs.python3}/bin/python3 ${./vacuumtube-input.py} "$@"
      '' else ''
        exec ${lib.escapeShellArgs (command app ++ (app.args or []))} "$@"
      ''}
    '';
  }) apps;
  xdg.configFile."comet/steam-apps.json".source = manifest;
  xdg.desktopEntries = lib.mapAttrs' (key: app: lib.nameValuePair (desktopId key app) {
    name = lib.mkDefault app.name;
    exec = lib.mkForce (launcherPath key);
    icon = lib.mkDefault (app.icon or (app.flatpakAppId or key));
    terminal = lib.mkDefault (app.terminal or false);
    categories = lib.mkDefault ["Utility"];
  }) apps;
  # Steam's running environment excludes ~/.nix-profile/share/applications.
  xdg.dataFile = lib.mapAttrs' (key: app: lib.nameValuePair "applications/${desktopId key app}.desktop" {
    source = "${config.home.path}/share/applications/${desktopId key app}.desktop";
  }) apps;
}
