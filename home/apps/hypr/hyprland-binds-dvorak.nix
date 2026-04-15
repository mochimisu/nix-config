{
  lib,
  variables,
  ...
}: {
  imports = [../../../vars.nix];
  wayland.windowManager.hyprland.settings = lib.mkIf (variables.keyboardLayout == "dvorak") {
    bind = [
      "$mod, apostrophe, exec, $terminal"
      "$mod, C, killactive,"
      "$mod SHIFT, M, exit,"
      "$mod, G, exec, $fileManager"
      "$mod, V, togglefloating,"
      "$mod, U, layoutmsg, promote"
      "$mod, P, layoutmsg, colresize +conf"
      "$mod SHIFT, P, layoutmsg, colresize -conf"
      "$mod CONTROL, P, layoutmsg, colresize +0.1"
      "$mod CONTROL SHIFT, P, layoutmsg, colresize -0.1"
      "$mod, tab, layoutmsg, fit active"
      "$mod SHIFT, tab, layoutmsg, fit visible"
      "$mod CONTROL, tab, layoutmsg, fit all"

      # Move focus with mod + arrow keys
      "$mod, a, layoutmsg, focus l"
      "$mod, e, layoutmsg, focus r"
      "$mod, comma, movefocus, u"
      "$mod, o, movefocus, d"
      "$mod SHIFT, a, layoutmsg, swapcol l"
      "$mod SHIFT, e, layoutmsg, swapcol r"
      "$mod SHIFT, comma, swapwindow, u"
      "$mod SHIFT, o, swapwindow, d"
      "$mod CONTROL, a, movewindow, l"
      "$mod CONTROL, e, movewindow, r"
      "$mod CONTROL SHIFT, a, layoutmsg, move -col"
      "$mod CONTROL SHIFT, e, layoutmsg, move +col"
      "$mod CONTROL, comma, movewindow, u"
      "$mod CONTROL, o, movewindow, d"
    ];
  };
}
