{config, lib, pkgs, ...}: let
  style = config.variables.desktopStyle;
  linuxGui = pkgs.stdenv.hostPlatform.isLinux && config.variables.isGui;
  externalDesktop = config.targets.genericLinux.enable || config.variables.nestedDesktop;
  nativeHyprland = linuxGui && config.wayland.windowManager.hyprland.enable && !externalDesktop;
  anyStyle = style.apps.enable || style.notifications.enable || style.shell.enable || style.launcher.enable || style.mediaFeedback.enable;
in {
  imports = [./kirakira ./apps.nix ./notifications.nix ./shell.nix ./media-feedback.nix ../apps/quickshell/phone-launcher];
  # Capability defaults do not install a compositor, greeter, or notification owner.
  variables.desktopStyle = {
    apps.enable = lib.mkDefault linuxGui;
    apps.desktopIntegration.enable = lib.mkDefault (linuxGui && config.gtk.enable && !externalDesktop);
    notifications.enable = lib.mkDefault (linuxGui && config.services.mako.enable);
    shell.enable = lib.mkDefault nativeHyprland;
    launcher.enable = lib.mkDefault nativeHyprland;
    mediaFeedback.enable = lib.mkDefault (nativeHyprland && config.services.mako.enable);
  };
  assertions = [
    { assertion = !anyStyle || (pkgs.stdenv.hostPlatform.isLinux && config.variables.isGui);
      message = "Desktop style features require a Linux GUI home."; }
    { assertion = !(style.shell.enable || style.launcher.enable) || config.wayland.windowManager.hyprland.enable;
      message = "Shell styling and the phone launcher require Hyprland."; }
    { assertion = !style.mediaFeedback.enable || config.services.mako.enable;
      message = "Media feedback requires the existing Mako notification owner."; }
    { assertion = !style.launcher.enable || !config.variables.nestedDesktop;
      message = "The phone launcher needs renderer/session validation before nested desktop use."; }
  ];
}
