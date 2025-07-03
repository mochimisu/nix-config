{
  pkgs,
  config,
  ...
}: {
  programs.hyprlock = {
    enable = true;
  };
  home.file.".config/hypr/hyprlock.conf".source = pkgs.writeText "hyprlock.conf" ''
    general {
      ignore_empty_input = false
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

    label {
      monitor =
      text = $TIME
      text_align =
      color = rgb(235, 188, 186)
      font_size = 50
      font_family = IBM Plex
      rotate = 0.000000
      shadow_passes = 0
      shadow_size = 3
      shadow_color = rgba(0, 0, 0, 1.0)
      shadow_boost = 1.200000

      position = 0, 80
      halign = center
      valign = center
    }
  '';
}
