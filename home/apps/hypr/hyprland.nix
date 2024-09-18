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


      bind = [
        # Switch workspaces with mod + [0-9]
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to a workspace with mod + SHIFT + [0-9]
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Example special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mod + scroll
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # fullscreen toggle
        "$mod, return, fullscreen"

        # float
        "$mod, f, togglefloating"

        #lock
        "$mod, L, exec, hyprlock"

        # will switch to a submap called resize
        # bind = $mod CONTROL, R, submap, resize

        # will start a submap called "resize"
        # submap=resize

        # sets repeatable binds for resizing the active window
        # binde=,right,resizeactive,40 0
        # binde=,left,resizeactive,-40 0
        # binde=,up,resizeactive,0 -40
        # binde=,down,resizeactive,0 40

        # use reset to go back to the global submap
        # bind=,escape,submap,reset 

        # will reset the submap, meaning end the current one and return to the global one
        # submap=reset

        # keybinds further down will be global again...

        "$mod, apostrophe, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, G, exec, $fileManager"
        "$mod, V, togglefloating,"
        "$mod, R, exec, $menu"
        "$mod SHIFT, R, exec, $menuAll"
        "$mod, U, pseudo, # dwindle"
        "$mod, P, togglesplit, # dwindle"

        # Move focus with mod + arrow keys
        "$mod, a, movefocus, l"
        "$mod, e, movefocus, r"
        "$mod, comma, movefocus, u"
        "$mod, o, movefocus, d"
        "$mod SHIFT, a, swapwindow, l"
        "$mod SHIFT, e, swapwindow, r"
        "$mod SHIFT, comma, swapwindow, u"
        "$mod SHIFT, o, swapwindow, d"
        "$mod CONTROL, a, movewindow, l"
        "$mod CONTROL, e, movewindow, r"
        "$mod CONTROL, comma, movewindow, u"
        "$mod CONTROL, o, movewindow, d"

        ",XF86MonBrightnessDown,exec,brightnessctl set 5%-"
        ",XF86MonBrightnessUp,exec,brightnessctl set +5%"
        ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_SINK@ 5%-"
        ",XF86AudioRaiseVolume,exec,wpctl set-volume @DEFAULT_SINK@ 5%+"
        ",XF86AudioMute,exec,wpctl set-mute @DEFAULT_SINK@ toggle"

      ];
      bindm = [
        # Move/resize windows with mod + LMB/RMB and dragging
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

    };
  };
}
