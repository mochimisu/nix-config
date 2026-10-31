{config, lib, pkgs, ...}: let
  style = config.variables.desktopStyle;
  nativeHyprland = pkgs.stdenv.hostPlatform.isLinux && config.variables.isGui
    && config.wayland.windowManager.hyprland.enable
    && !config.targets.genericLinux.enable && !config.variables.nestedDesktop;
in {
  imports = [./volume-overlay ./notifications.nix];
  variables.desktopStyle.kirakira = {
    menus.enable = lib.mkDefault (style.kirakira.enable && nativeHyprland && style.shell.enable);
    volume.enable = lib.mkDefault (style.kirakira.enable && nativeHyprland && style.mediaFeedback.enable);
    notifications.enable = lib.mkDefault (style.kirakira.enable && style.notifications.enable
      && pkgs.stdenv.hostPlatform.isLinux && config.variables.isGui && config.services.mako.enable);
  };
  assertions = [
    { assertion = !(style.kirakira.menus.enable || style.kirakira.volume.enable) || nativeHyprland;
      message = "Kirakira menus and volume require a native Linux Hyprland GUI home."; }
    { assertion = !style.kirakira.volume.enable || style.mediaFeedback.enable;
      message = "Kirakira volume requires the existing media feedback client."; }
    { assertion = !style.kirakira.notifications.enable || config.services.mako.enable;
      message = "Kirakira notification animation requires an existing Mako owner."; }
  ];
}
