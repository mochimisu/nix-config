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
      path = ${config.home.homeDirectory}/.config/hypr/turquoiseTree.jpg
      brightness = 0.5
    }

    input-field {
      monitor =
      size = 250, 50
      outline_thickness = 3
      dots_size = 0.33
      dots_spacing = 0.15
      dots_center = true
      outer_color = rgb(5e81ac)
      inner_color = rgb(2e3440)
      font_color = rgb(d8dee9)
      placeholder_text = <i>Password...</i>
      position = 0, -20
    }

    label {
      monitor =
      text = $TIME
      color = rgb(ebbcba)
      font_size = 50
      font_family = IBM Plex
      rotate = 0.000000
      shadow_passes = 0
      shadow_size = 3
      shadow_color = rgba(000000ff)
      shadow_boost = 1.200000

      position = 0, 80
      halign = center
      valign = center
    }
  '';
}
