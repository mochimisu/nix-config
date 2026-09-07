{
  osConfig,
  ...
}: {
  imports = [
    ./apps/hypr
    ./apps/mangohud.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    package = osConfig.programs.hyprland.package;
    # UWSM owns graphical-session.target. HM's startup stop/start hook would
    # propagate a stop into UWSM and terminate the compositor during login.
    systemd.enable = !osConfig.programs.hyprland.withUWSM;
  };

  programs.waybar.enable = true;
}
