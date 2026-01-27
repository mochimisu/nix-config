{...}: {
  wayland.windowManager.hyprland = {
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      # "$menu" = "rofi-toggle -show drun";
      # "$menuAll" = "rofi-toggle";

      "exec-once" = [
        "gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg"
        "hyprpaper"
        "nm-applet"
        "sleep 2 && blueman-applet"
        "sleep 2 && blueman-tray"
        "systemctl --user start hyprpolkitagent"

        "hypridle"
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
        gaps_in = "3";
        gaps_out = "0";
        border_size = "2";
        "col.active_border" = "rgba(ffffffff)";
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
        shadow = {
          enabled = false;
        };
      };

      misc = {
        force_default_wallpaper = 0;
      };
      # Keep FFXIV running when unfocused or on another monitor.
      windowrule = [
        "idle_inhibit always, match:class ^(ffxiv_dx11.exe|ffxiv.exe)$"
      ];
      env = [
        "XDG_SESSION_TYPE,wayland"
        "NIXOS_OZONE_WL=1"
        "WLR_NO_HARDWARE_CURSORS=1"
        # Get dark mode in GTK4
        "ADW_DISABLE_PORTAL=1"
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
        bind = "SUPER, V, exec, cliphist list | rofi --dmenu | cliphist decode | wl-copy";
      };
    };
  };
}
