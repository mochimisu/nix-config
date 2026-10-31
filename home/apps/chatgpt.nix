# Shared Linux desktop policy; the package remains owned by the app catalog.
{config, lib, pkgs, ...}: let
  enabled = pkgs.stdenv.hostPlatform.isLinux && config.variables.isGui;
  chatgpt = pkgs.callPackage ../../pkgs/chatgpt/package.nix {};
  externalDesktop = config.targets.genericLinux.enable;
in {
  # Also applies to manual launches; inverse flags can override these defaults.
  xdg.configFile."chatgpt-nix/window-options.json" = lib.mkIf enabled {
    text = builtins.toJSON {startMinimized = true; disableMini = true;};
  };

  # UWSM owns the native graphical-session target and imports its environment.
  systemd.user.services.chatgpt = lib.mkIf (enabled && !externalDesktop) {
    Unit = {
      Description = "ChatGPT (start hidden)";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${lib.getExe chatgpt} --start-minimized";
      Restart = "no";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  # SteamOS owns its session services. Use its desktop autostart mechanism,
  # without a second nested-Hyprland launch that would reveal the existing app.
  xdg.configFile."autostart/chatgpt.desktop" = lib.mkIf (enabled && externalDesktop) {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=ChatGPT
      Comment=Start ChatGPT hidden in the background
      Exec=${lib.getExe chatgpt} --start-minimized
      Icon=chatgpt
      Terminal=false
      StartupNotify=false
    '';
  };
}
