{ pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "walker --modules applications";
      "$menuAll" = "walker";

      "exec-once" = [
        "hyprpaper"
        "nm-applet"
        "sleep 2 && blueman-applet"
        "sleep 2 && blueman-tray"
        "systemctl --user start hyprpolkitagent"
        "kwalletd5"
        "hypridle"
        # disable power button being handled by logind
        "systemd-inhibit --who=\"Hyprland config\" --why=\"wlogout keybind\" --what=handle-power-key --mode=block sleep infinity & echo $! > /tmp/.hyprland-systemd-inhibit"
        "walker --gapplication-service"
      ];
      "exec-shutdown" = [
        "kill -9 \"$(cat /tmp/.hyprland-systemd-inhibit)"
      ];
      
      debug = {
        # disable_logs = "false";
      };

      input = {
        follow_mouse = "1";
        sensitivity = "0";
        accel_profile = "flat";

        touchpad = {
          natural_scroll = "true";
        };
      };

      general = {
        gaps_in = "5";
        gaps_out = "0";
        border_size = "2";
        # "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        # "col.inactive_border" = "rgba(595959aa)";
        "col.active_border" = "rgba(ffffffaa)";
        "col.inactive_border" = "rgba(00000000)";
        layout = "dwindle";
        allow_tearing = "true";
      };

      decoration = {
        rounding = "10";
          blur = {
            enabled = "true";
            size = "5";
            passes = "1";
            vibrancy = "0.1696";
            ignore_opacity = "true";
          };
        # drop_shadow = "false";
        # shadow_range = "4";
        # shadow_render_power = "3";
        # "col.shadow" = "rgba(1a1a1aee)";
      };

      misc = {
        force_default_wallpaper = 0;
      };
      env = [
        "XDG_SESSION_TYPE,wayland"
        "NIXOS_OZONE_WL=1"
        "WLR_NO_HARDWARE_CURSORS=1"
      ];
      cursor = {
        no_hardware_cursors = "true";
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

      xwayland = {
        force_zero_scaling = "true";
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
