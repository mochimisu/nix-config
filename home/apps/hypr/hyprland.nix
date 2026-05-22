{lib, ...}: let
  lua = lib.generators.mkLuaInline;
in {
  wayland.windowManager.hyprland = {
    settings = {
      mod._var = "SUPER";
      terminal._var = "kitty";
      fileManager._var = "thunar";
      # "$menu" = "rofi-toggle -show drun";
      # "$menuAll" = "rofi-toggle";

      on = [
        {
          _args = [
            "hyprland.start"
            (lua ''
              function()
                hl.exec_cmd("gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg")
                hl.exec_cmd("hyprpaper")
                hl.exec_cmd("nm-applet")
                hl.exec_cmd("sleep 2 && blueman-applet")
                hl.exec_cmd("sleep 2 && blueman-tray")
                hl.exec_cmd("systemctl --user start hyprpolkitagent")
                hl.exec_cmd("hypridle")
                hl.exec_cmd("walker --gapplication-service")
                hl.exec_cmd("wl-paste --type text --watch cliphist store")
                hl.exec_cmd("wl-paste --type image --watch cliphist store")
              end
            '')
          ];
        }
      ];

      config = {
        debug = {
          # disable_logs = "false";
        };

        input = {
          follow_mouse = 1;
          sensitivity = 0;
          accel_profile = "flat";

          touchpad = {
            natural_scroll = true;
          };
        };

        general = {
          gaps_in = 3;
          gaps_out = 0;
          border_size = 2;
          col = {
            active_border = "rgba(ffffffff)";
            inactive_border = "rgba(00000000)";
          };
          layout = "dwindle";
          allow_tearing = true;
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 5;
            passes = 1;
            vibrancy = 0.1696;
            ignore_opacity = true;
          };
          shadow = {
            enabled = false;
          };
        };

        dwindle = {
          preserve_split = true;
        };

        misc = {
          force_default_wallpaper = 0;
        };

        cursor = {
          no_hardware_cursors = true;
        };

        animations = {
          enabled = true;
        };

        xwayland = {
          force_zero_scaling = true;
        };
      };

      # Keep FFXIV running when unfocused or on another monitor.
      window_rule = [
        {
          name = "ffxiv-idle-inhibit";
          match.class = "^(ffxiv_dx11.exe|ffxiv.exe)$";
          idle_inhibit = "always";
        }
      ];

      env = [
        {_args = ["XDG_SESSION_TYPE" "wayland"];}
        {_args = ["NIXOS_OZONE_WL" "1"];}
        {_args = ["WLR_NO_HARDWARE_CURSORS" "1"];}
        # Get dark mode in GTK4
        {_args = ["ADW_DISABLE_PORTAL" "1"];}
      ];

      curve = {
        _args = [
          "myBezier"
          {
            type = "bezier";
            points = [
              [0.05 0.9]
              [0.1 1.05]
            ];
          }
        ];
      };

      animation = [
        {leaf = "windows"; enabled = true; speed = 7; bezier = "myBezier";}
        {leaf = "windowsOut"; enabled = true; speed = 7; bezier = "default"; style = "popin 80%";}
        {leaf = "border"; enabled = true; speed = 10; bezier = "default";}
        {leaf = "borderangle"; enabled = true; speed = 8; bezier = "default";}
        {leaf = "fade"; enabled = true; speed = 7; bezier = "default";}
        {leaf = "workspaces"; enabled = true; speed = 6; bezier = "default";}
      ];

      bind = [
        {
          _args = [
            (lua "mod .. \" + V\"")
            (lua "hl.dsp.exec_cmd(\"cliphist list | rofi --dmenu | cliphist decode | wl-copy\")")
          ];
        }
      ];
    };
  };
}
