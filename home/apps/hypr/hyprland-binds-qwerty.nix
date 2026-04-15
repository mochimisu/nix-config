{ lib, variables, ... }: {
  imports = [ ../../../vars.nix ];
  wayland.windowManager.hyprland.settings = lib.mkIf (variables.keyboardLayout == "qwerty") {
    bind = [
      "$mod, q, exec, $terminal"
      "$mod, C, killactive,"
      "$mod, M, exit,"
      "$mod, G, exec, $fileManager"
      "$mod, l, togglefloating,"
      "$mod, o, exec, $menu"
      "$mod SHIFT, o, exec, $menuAll"
      "$mod, r, layoutmsg, promote"
      "$mod, f, layoutmsg, colresize +conf"
      "$mod SHIFT, f, layoutmsg, colresize -conf"
      "$mod CONTROL, f, layoutmsg, colresize +0.1"
      "$mod CONTROL SHIFT, f, layoutmsg, colresize -0.1"
      "$mod, tab, layoutmsg, fit active"
      "$mod SHIFT, tab, layoutmsg, fit visible"
      "$mod CONTROL, tab, layoutmsg, fit all"

      # Move focus with mainMod + movement keys
      "$mod, a, layoutmsg, focus l"
      "$mod, d, layoutmsg, focus r"
      "$mod, w, movefocus, u"
      "$mod, s, movefocus, d"
      "$mod SHIFT, a, layoutmsg, swapcol l"
      "$mod SHIFT, d, layoutmsg, swapcol r"
      "$mod SHIFT, w, swapwindow, u"
      "$mod SHIFT, s, swapwindow, d"
      "$mod CONTROL, a, movewindow, l"
      "$mod CONTROL, d, movewindow, r"
      "$mod CONTROL SHIFT, a, layoutmsg, move -col"
      "$mod CONTROL SHIFT, d, layoutmsg, move +col"
      "$mod CONTROL, w, movewindow, u"
      "$mod CONTROL, s, movewindow, d"
      "$mod, up, movefocus, u"
      "$mod, left, layoutmsg, focus l"
      "$mod, right, layoutmsg, focus r"
      "$mod, down, movefocus, d"
      ];
    input = {
      kb_options = "ctrl:nocaps";
    };
  };
}
