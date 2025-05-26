{ lib, variables, ... }:
{
  imports = [ ../../../vars.nix ];
  wayland.windowManager.hyprland.settings = lib.mkIf (variables.keyboardLayout == "dvorak") {
    bind = [
      "$mod, apostrophe, exec, $terminal"
      "$mod, C, killactive,"
      "$mod, M, exit,"
      "$mod, G, exec, $fileManager"
      "$mod, V, togglefloating,"
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
      "$mod, n, exec, dunstctl history | jq -r '.data[][] | \"\\(.appname.data): \\(.summary.data) - \\(.body.data)\"' | rofi -dmenu -p \"Notifications\""
    ];
  };
}
