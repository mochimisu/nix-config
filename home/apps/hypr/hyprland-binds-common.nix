{...}: {
  wayland.windowManager.hyprland.settings = {
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

      # launcher
      "$mod, space, exec, $menu"
      "$mod SHIFT, space, exec, $menuAll"

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

      "$mod, F1, exec, ~/.config/hypr/gamemode.sh"

      ",XF86MonBrightnessDown,exec,brightnessctl set 5%-"
      ",XF86MonBrightnessUp,exec,brightnessctl set +5%"
      ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_SINK@ 5%-"
      ",XF86AudioRaiseVolume,exec,wpctl set-volume @DEFAULT_SINK@ 5%+"
      ",XF86AudioMute,exec,wpctl set-mute @DEFAULT_SINK@ toggle"
      ",XF86KbdLightOnOff,exec,brightnessctl --device \*kbd_backlight\* set +1"
      "SHIFT,XF86KbdLightOnOff,exec,brightnessctl --device \*kbd_backlight\* set 1-"
    ];

    bindm = [
      # Move/resize windows with mod + LMB/RMB and dragging
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
    ];
  };

  home.file.".config/hypr/gamemode.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env sh
      HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
      if [ "$HYPRGAMEMODE" = 1 ] ; then
          hyprctl --batch "\
              keyword animations:enabled 0;\
              keyword decoration:drop_shadow 0;\
              keyword decoration:blur:enabled 0;\
              keyword general:gaps_in 0;\
              keyword general:gaps_out 0;\
              keyword general:border_size 1;\
              keyword decoration:rounding 0"
          exit
      fi
      hyprctl reload
    '';
  };
}
