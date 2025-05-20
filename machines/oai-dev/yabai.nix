{
  # wip. disable for now
  services.yabai = {
    enable = false;
    enableScriptingAddition = true;     # Enables yabai's scripting addition (requires root privileges)
      config = {
        layout = "bsp";
        window_gap = 6;
# ...other yabai settings
      };
  };

  services.skhd = {
    enable = true;               # Enable the skhd daemon
      skhdConfig = ''
      # wasd but dvorak
      alt - a : yabai -m window --focus west
      alt - o : yabai -m window --focus south
      alt - , : yabai -m window --focus north
      alt - e : yabai -m window --focus east

      alt - p : yabai -m window --toggle split
      alt - u : yabai -m space --balance

      # default
      alt - r : yabai -m space --rotate 90
      alt - y : yabai -m space --mirror y-axis
      
      # workspace nav
      alt - 1 : yabai -m space --focus 1
      alt - 2 : yabai -m space --focus 2
      alt - 3 : yabai -m space --focus 3
      alt - 4 : yabai -m space --focus 4
      alt - 5 : yabai -m space --focus 5
      alt - 6 : yabai -m space --focus 6
      alt - 7 : yabai -m space --focus 7
      alt - 8 : yabai -m space --focus 8
      alt - 9 : yabai -m space --focus 9
# Move window to Space 1 and focus it
      shift + alt - 1 : yabai -m window --space 1 --focus
      shift + alt - 2 : yabai -m window --space 2 --focus
      shift + alt - 3 : yabai -m window --space 3 --focus
      shift + alt - 4 : yabai -m window --space 4 --focus
      shift + alt - 5 : yabai -m window --space 5 --focus
      shift + alt - 6 : yabai -m window --space 6 --focus
      shift + alt - 7 : yabai -m window --space 7 --focus
      shift + alt - 8 : yabai -m window --space 8 --focus
      shift + alt - 9 : yabai -m window --space 9 --focus

# ...add more keybindings as desired
      '';
  };
}
