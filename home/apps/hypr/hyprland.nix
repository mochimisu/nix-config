{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$menuAll" = "wofi --show run";

      "exec-once" = [
        "sleep 1 && waybar"
        "hyprpaper"
        "nm-applet"
        "blueman-applet"
        "${pkgs.polkit-kde-agent}/libexec/polkit-kde-authentication-agent-1"
        "swaync"
        "hypridle"
      ];

      monitors = {
        monitor = "eDP-1,2880x1920x120,0x0,1.5";
      };

      input = {
        follow_mouse = "1";
        sensitivity = "0";
        accel_profile = "flat";

        kb_layout = "custom";
        kb_variant = "dvorak-custom";
        touchpad = {
          natural_scroll = "true";
        };
      };

      general = {
        gaps_in = "5";
          gaps_out = "0";
          border_size = "2";
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
          allow_tearing = "true";
      };

      decoration = {
        rounding = "10";
          blur = {
            enabled = "false";
            size = "3";
            passes = "1";
            vibrancy = "0.1696";
          };
        drop_shadow = "false";
        shadow_range = "4";
        shadow_render_power = "3";
        "col.shadow" = "rgba(1a1a1aee)";
      };

      misc = {
        vfr = "true";
      };

      animations = {
        enabled = "true";
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
# See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        pseudotile = "true"; # master switch for pseudotiling. Enabling is bound to mod + P in the keybinds section below
        preserve_split = "true"; # you probably want this
      };

      cliphist = {
          exec-once = [
            "wl-paste --type text --watch cliphist store" #Stores only text data
            "wl-paste --type image --watch cliphist store" #Stores only image data
          ];
          bind = "SUPER, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy";
      };
    };
  };
}
