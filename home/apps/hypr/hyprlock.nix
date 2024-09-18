{ pkgs, config, ... }:
{
  home.file.".config/hypr/hyprlock.conf".source = pkgs.writeText "hyprlock.conf" ''
  general {
    grace = 1
  }

  background {
      monitor = 
      path = ${config.home.homeDirectory}/.config/hypr/wallpaper.jpg
      brightness = 0.5
  }

  input-field {
      monitor = 
      size = 250, 50
      outline_thickness = 3
      dots_size = 0.33
      dots_spacing = 0.15
      dots_center = true
      outer_color = #5e81ac
      inner_color = #2e3440
      font_color = #d8dee9
      placeholder_text = <i>Password...</i>
      position = "0, -20"
  }
    '';
}
