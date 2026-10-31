{config, lib, ...}: let
  p = (import ./palettes.nix {inherit lib;}).shell;
  rgba = color: alpha: "rgba(${lib.removePrefix "#" color}${alpha})";
in {
  config = lib.mkIf config.variables.desktopStyle.shell.enable {
    wayland.windowManager.hyprland.settings = {
      config = {
        general = {
          gaps_in = lib.mkForce 4;
          gaps_out = lib.mkForce 0;
          border_size = lib.mkForce 2;
          # Lua gradients use a table; the legacy multi-color string is invalid.
          col.active_border = lib.mkForce {
            colors = [(rgba p.teal "ff") (rgba p.lavenderEdge "ff")];
            angle = 45;
          };
          col.inactive_border = lib.mkForce (rgba p.inactive "99");
        };
        decoration = {
          rounding = lib.mkForce 12;
          shadow = {
            enabled = lib.mkForce true;
            range = 14;
            render_power = 3;
            color = rgba p.shadow "35";
          };
        };
      };
      layer_rule = [{
        name = "blackmoon-notification-blur";
        match.namespace = "^(notifications)$";
        blur = true;
        ignore_alpha = 0;
      }];
      curve = lib.mkForce {
        _args = ["sekaiEase" {type = "bezier"; points = [[0.22 1.0] [0.36 1.0]];}];
      };
      # Visible, quick settling without overshoot; the phone layer keeps its own animation.
      animation = lib.mkForce [
        {leaf = "windows"; enabled = true; speed = 3.2; bezier = "sekaiEase"; style = "popin 88%";}
        {leaf = "windowsIn"; enabled = true; speed = 3.2; bezier = "sekaiEase"; style = "popin 88%";}
        {leaf = "windowsMove"; enabled = true; speed = 3.8; bezier = "sekaiEase";}
        {leaf = "windowsOut"; enabled = true; speed = 2; bezier = "default"; style = "popin 94%";}
        {leaf = "border"; enabled = true; speed = 3; bezier = "default";}
        {leaf = "borderangle"; enabled = false; speed = 1; bezier = "default";}
        {leaf = "fade"; enabled = true; speed = 3; bezier = "default";}
        {leaf = "fadeIn"; enabled = true; speed = 2.2; bezier = "default";}
        {leaf = "fadeOut"; enabled = true; speed = 1.8; bezier = "default";}
        {leaf = "workspaces"; enabled = true; speed = 4; bezier = "sekaiEase"; style = "slidefade 30%";}
      ];
    };

  };
}
