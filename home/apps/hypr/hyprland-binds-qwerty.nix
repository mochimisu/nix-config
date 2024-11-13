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
      "$mod, r, pseudo, # dwindle"
      "$mod, f, togglesplit, # dwindle"

      # Move focus with mainMod + arrow keys
      "$mod, a, movefocus, l"
      "$mod, d, movefocus, r"
      "$mod, w, movefocus, u"
      "$mod, s, movefocus, d"
      "$mod SHIFT, a, swapwindow, l"
      "$mod SHIFT, d, swapwindow, r"
      "$mod SHIFT, w, swapwindow, u"
      "$mod SHIFT, s, swapwindow, d"
      "$mod CONTROL, a, movewindow, l"
      "$mod CONTROL, d, movewindow, r"
      "$mod CONTROL, w, movewindow, u"
      "$mod CONTROL, s, movewindow, d"
      "$mod, up, movefocus, u"
      "$mod, left, movefocus, l"
      "$mod, right, movefocus, r"
      "$mod, down, movefocus, d"
      ];
    input = {
      kb_options = "ctrl:nocaps";
    };
  };
}
