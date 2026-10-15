{config, pkgs, ...}: let
  style = config.variables.desktopStyle;
  anyStyle = style.apps.enable || style.shell.enable || style.launcher.enable || style.mediaFeedback.enable;
in {
  imports = [./apps.nix ./shell.nix ./media-feedback.nix ../apps/quickshell/phone-launcher];
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
